package wi

import (
	"database/sql"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite" // pure-Go driver: no CGO, matching monetization/tools/repodb
)

// Open opens the workable-items database. It never creates the canonical
// schema: that is the canonical binary's job (§11.4.74 — the schema author is
// submodules/constitution/scripts/workable-items, and a second author would be
// a fork of the source of truth). Open only ensures the umbrella EXTENSION
// table exists, and refuses a database that has no canonical `items` table.
func Open(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	var n int
	err = db.QueryRow(`SELECT count(*) FROM sqlite_master WHERE type='table' AND name='items'`).Scan(&n)
	if err != nil {
		db.Close()
		return nil, fmt.Errorf("reading %s: %w", path, err)
	}
	if n == 0 {
		db.Close()
		return nil, fmt.Errorf("%s carries no `items` table — it was not created by the canonical "+
			"workable-items binary; create it with "+
			"`submodules/constitution/scripts/workable-items/bin/workable-items-linux add ...`", path)
	}
	if _, err := db.Exec(extensionDDL); err != nil {
		db.Close()
		return nil, fmt.Errorf("creating umbrella extension tables in %s: %w", path, err)
	}
	return db, nil
}

// extensionDDL is the UMBRELLA-LOCAL addition to the canonical §11.4.93 schema.
// It adds no column to any canonical table — a consumer that mutated the
// canonical schema would fork the source of truth and break the canonical
// binary's own round-trip. Everything here is additive and lives in tables the
// canonical binary neither reads nor writes.
const extensionDDL = `
CREATE TABLE IF NOT EXISTS sub_projects (
    prefix    TEXT PRIMARY KEY CHECK (length(prefix) = 3),
    path      TEXT NOT NULL UNIQUE,
    class     TEXT NOT NULL CHECK (class IN ('parent','owned','governance-source','third-party')),
    ratified  TEXT NOT NULL CHECK (ratified IN ('operator','proposed')),
    url       TEXT NOT NULL DEFAULT '',
    note      TEXT NOT NULL DEFAULT '',
    synced_at TEXT NOT NULL
);

-- item_provenance records, per item, WHERE the backfilled fact came from and
-- WHAT CLASS of evidence it is. §11.4.6 forbids reporting a state that was not
-- verified; this table is what makes each row's status auditable back to the
-- artefact that justified it, and what lets a reader tell a re-run verdict from
-- a document assertion without opening the item.
CREATE TABLE IF NOT EXISTS item_provenance (
    atm_id         TEXT PRIMARY KEY,
    source_kind    TEXT NOT NULL CHECK (source_kind IN ('operator-decision','spec-task','session-work')),
    source_path    TEXT NOT NULL,
    source_locator TEXT NOT NULL,
    evidence_class TEXT NOT NULL CHECK (evidence_class IN (
                       'document-assertion',   -- the source document states the outcome; not re-run here
                       'checkbox-state',       -- a tracked task list records the completion mark
                       'undetermined'          -- the source does not state an outcome
                   )),
    status_note    TEXT NOT NULL DEFAULT ''
);
`

// SyncRoster writes the roster into the database, replacing it wholesale so the
// table can never carry a member the file has dropped.
func SyncRoster(db *sql.DB, r *Roster) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM sub_projects`); err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	for _, sp := range r.Members {
		if _, err := tx.Exec(
			`INSERT INTO sub_projects(prefix,path,class,ratified,url,note,synced_at) VALUES (?,?,?,?,?,?,?)`,
			sp.Prefix, sp.Path, string(sp.Class), sp.Ratified, sp.URL, sp.Note, now); err != nil {
			return fmt.Errorf("inserting %s: %w", sp.Prefix, err)
		}
	}
	return tx.Commit()
}

// Item is one row destined for the canonical `items` table.
type Item struct {
	ID              string
	Type            string
	Status          string
	Severity        string
	Title           string
	Description     string
	CurrentLocation string
	CreatedBy       string
	ForensicAnchor  string

	SourceKind    string
	SourcePath    string
	SourceLocator string
	EvidenceClass string
	StatusNote    string
}

// NextIDs allocates the next free NNN for each prefix, monotonically and
// without reusing a number the database has ever held (§11.4.54: never
// renumbered, never reused, never decremented, no gaps).
func NextIDs(db *sql.DB, prefixes []string) (map[string]int, error) {
	next := map[string]int{}
	for _, p := range prefixes {
		next[p] = 0
	}
	rows, err := db.Query(`SELECT DISTINCT atm_id FROM items`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		prefix, n, ok := SplitID(id)
		if !ok {
			continue
		}
		if cur, tracked := next[prefix]; tracked && n > cur {
			next[prefix] = n
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return next, nil
}

// SplitID parses "WSP-042" into ("WSP", 42, true).
func SplitID(id string) (string, int, bool) {
	prefix, num, ok := strings.Cut(id, "-")
	if !ok || !ValidPrefix(prefix) {
		return "", 0, false
	}
	n, err := strconv.Atoi(num)
	if err != nil || n <= 0 {
		return "", 0, false
	}
	return prefix, n, true
}

// FormatID renders a prefix and number in the canonical zero-padded form.
func FormatID(prefix string, n int) string { return fmt.Sprintf("%s-%03d", prefix, n) }

// InsertItems writes items and their provenance rows in one transaction. It is
// idempotent by (source_kind, source_path, source_locator): an item already
// backfilled from the same locator is left alone rather than duplicated, so a
// re-run cannot inflate the table.
func InsertItems(db *sql.DB, items []Item) (inserted, skipped int, err error) {
	tx, err := db.Begin()
	if err != nil {
		return 0, 0, err
	}
	defer tx.Rollback()

	existing := map[string]bool{}
	rows, err := tx.Query(`SELECT source_kind || '\x1f' || source_path || '\x1f' || source_locator FROM item_provenance`)
	if err != nil {
		return 0, 0, err
	}
	for rows.Next() {
		var k string
		if err := rows.Scan(&k); err != nil {
			rows.Close()
			return 0, 0, err
		}
		existing[k] = true
	}
	rows.Close()

	// doc_segments carries the ordered ledger db-to-md walks. An item with no
	// segment row is one the canonical binary's own validator reports as
	// "db-to-md would silently drop it" — so the segment is written here, in the
	// same transaction, rather than left for a later repair pass.
	nextSeq := map[string]int{"Issues": 0, "Fixed": 0}
	segRows, err := tx.Query(`SELECT document, COALESCE(MAX(seq), -1) FROM doc_segments GROUP BY document`)
	if err != nil {
		return 0, 0, err
	}
	for segRows.Next() {
		var doc string
		var max int
		if err := segRows.Scan(&doc, &max); err != nil {
			segRows.Close()
			return 0, 0, err
		}
		nextSeq[doc] = max + 1
	}
	segRows.Close()

	now := time.Now().UTC().Format("2006-01-02 15:04:05")
	for _, it := range items {
		key := it.SourceKind + `\x1f` + it.SourcePath + `\x1f` + it.SourceLocator
		if existing[key] {
			skipped++
			continue
		}
		body := RenderBody(it)
		if _, err := tx.Exec(`INSERT INTO items
            (atm_id,type,status,severity,title,description,forensic_anchor,
             created_by,current_location,body_md,created_at,last_modified)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
			it.ID, it.Type, it.Status, it.Severity, it.Title, it.Description,
			it.ForensicAnchor, it.CreatedBy, it.CurrentLocation, body, now, now); err != nil {
			return 0, 0, fmt.Errorf("inserting item %s: %w", it.ID, err)
		}
		if _, err := tx.Exec(`INSERT INTO doc_segments(document,seq,kind,atm_id) VALUES (?,?,'item',?)`,
			it.CurrentLocation, nextSeq[it.CurrentLocation], it.ID); err != nil {
			return 0, 0, fmt.Errorf("inserting doc_segment for %s: %w", it.ID, err)
		}
		nextSeq[it.CurrentLocation]++
		if _, err := tx.Exec(`INSERT INTO item_provenance
            (atm_id,source_kind,source_path,source_locator,evidence_class,status_note)
            VALUES (?,?,?,?,?,?)`,
			it.ID, it.SourceKind, it.SourcePath, it.SourceLocator, it.EvidenceClass, it.StatusNote); err != nil {
			return 0, 0, fmt.Errorf("inserting provenance for %s: %w", it.ID, err)
		}
		event := "Opened"
		switch it.Status {
		case StatusFixed:
			event = "Fixed"
		case StatusImplemented:
			event = "Implemented"
		case StatusCompleted:
			event = "Completed"
		case StatusObsolete:
			event = "Obsolete"
		}
		if _, err := tx.Exec(`INSERT INTO item_history
            (atm_id,event_type,by,on_date,reason,evidence_path)
            VALUES (?,?,?,?,?,?)`,
			// evidence_path must be a path that RESOLVES: the canonical
			// validator checks it on disk, and "well-formed but nothing is
			// there" is one of the bluff shapes §11.4.5 exists to catch. The
			// LOCATOR therefore travels in `reason`, not appended to the path.
			it.ID, event, "AI", time.Now().UTC().Format("2006-01-02"),
			"backfilled from "+it.SourceKind+" at "+it.SourceLocator, it.SourcePath); err != nil {
			return 0, 0, fmt.Errorf("inserting history for %s: %w", it.ID, err)
		}
		existing[key] = true
		inserted++
	}
	if err := tx.Commit(); err != nil {
		return 0, 0, err
	}
	return inserted, skipped, nil
}

// RenderBody produces the Markdown item block the canonical binary's parser
// and db-to-md regeneration expect. The shape is taken from what the canonical
// `add` subcommand itself writes into body_md — heading, the four audit lines
// in Status/Type/Severity/Created-By order, a blank line, then the description
// — so a round-trip through the canonical tool sees a block of the same shape
// it authors.
func RenderBody(it Item) string {
	sev := it.Severity
	if sev == "" {
		sev = "unset"
	}
	by := it.CreatedBy
	if by == "" {
		by = "AI"
	}
	var b strings.Builder
	b.WriteString("## " + it.ID + " — " + it.Title + "\n\n")
	b.WriteString("**Status:** " + it.Status + "\n")
	b.WriteString("**Type:** " + it.Type + "\n")
	b.WriteString("**Severity:** " + sev + "\n")
	b.WriteString("**Created-By:** " + by + "\n\n")
	b.WriteString(it.Description + "\n")
	return b.String()
}

// Tally counts items grouped by an arbitrary column.
func Tally(db *sql.DB, column string) ([][2]string, error) {
	allowed := map[string]bool{"type": true, "status": true, "current_location": true, "severity": true}
	if !allowed[column] {
		return nil, fmt.Errorf("column %q is not a permitted grouping axis", column)
	}
	rows, err := db.Query(`SELECT ` + column + `, count(*) FROM items GROUP BY 1 ORDER BY 2 DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out [][2]string
	for rows.Next() {
		var k sql.NullString
		var n int
		if err := rows.Scan(&k, &n); err != nil {
			return nil, err
		}
		out = append(out, [2]string{k.String, strconv.Itoa(n)})
	}
	return out, rows.Err()
}

// TallyByPrefix counts items per sub-project prefix.
func TallyByPrefix(db *sql.DB) ([][2]string, error) {
	rows, err := db.Query(`SELECT atm_id FROM items`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	counts := map[string]int{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		p, _, ok := SplitID(id)
		if !ok {
			p = "(unparseable)"
		}
		counts[p]++
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	keys := make([]string, 0, len(counts))
	for k := range counts {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	out := make([][2]string, 0, len(keys))
	for _, k := range keys {
		out = append(out, [2]string{k, strconv.Itoa(counts[k])})
	}
	return out, nil
}
