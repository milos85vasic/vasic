package wi

// Feature 010, tasks T006 and T008: the `gap` subcommands of workable-items-vsc
// (contracts/register-cli.md). Exit codes: 0 condition holds, 1 violated,
// 2 could not determine — a 2 is never a pass and a finding outranks it.
//
// Every WRITE command applies its change inside one transaction, then runs the
// V-G rules (validate_gap.go) against that uncommitted transaction and commits
// only when the item it touched carries no finding and no undetermined row. The
// rules therefore exist exactly once: a command cannot commit a state the
// validator rejects, and a validator change reaches the commands automatically.
//
// §11.4.74 note: the canonical binary (submodules/constitution/scripts/
// workable-items) owns generic CRUD. These commands exist because the contract
// requires them and because the canonical `close` re-INSERTs the row with a
// fixed column list, which would silently drop every zero-gap column; closure
// here moves the row with an UPDATE so no column is lost, mirroring the
// canonical `reopen`, which does the same for the same reason.

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	rcOK    = 0
	rcFind  = 1
	rcUndet = 2
)

// defaultDBRel is the canonical register location (§11.4.93), repository-relative.
const defaultDBRel = "docs/workable_items.db"

// DefaultQueueRel is where the daily job appends reopen requests (research D12).
const DefaultQueueRel = ".remember/logs/zero-gap/reopen-queue.jsonl"

// nowFn is the clock used for created_at stamps and the future-record check;
// tests replace it.
var nowFn = func() time.Time { return time.Now().UTC() }

// futureDated: a record whose ts is after this host's clock (fix round 3,
// I1(d): ZERO skew). The round-2 five-minute allowance let a GREEN dated a few
// minutes ahead open a window in which older evidence counted again after a
// reopen; no test could justify keeping it on any path, so it is gone
// everywhere — the records are written by this host's clock.
func futureDated(rec *EvidenceRecord) bool { return rec.time.After(nowFn()) }

// freezeMidHook, when set, runs between the two state fingerprints of `gap
// freeze` — a test seam for the "register moved during the freeze" case.
var freezeMidHook func()

// adoptMidHook, when set, runs inside `gap adopt`'s write transaction, between
// the items UPDATE and the history/provenance inserts, and returning a
// non-nil error aborts the transaction — a test seam that proves the write is
// atomic: whatever the hook did to the transaction (including a genuine SQL
// constraint violation) is rolled back with everything else.
var adoptMidHook func(tx *sql.Tx) error

// adoptPreBeginHook, when set, runs right after `gap adopt`'s it.gap refusal
// check and immediately before its write transaction opens — the exact TOCTOU
// window the rev-adopt review exploited (loadItem runs before the write
// transaction begins, so a second process can read the same "not yet a gap
// item" snapshot before the first one commits). It is nil in production and
// exists purely as a test seam, matching adoptMidHook's pattern; see
// TestGapAdoptRaceRefusesConcurrentDoubleAdopt.
var adoptPreBeginHook func()

// adoptRaceWindow sleeps for WI_GAP_ADOPT_RACE_MS milliseconds (when that
// environment variable names a positive integer) at the same TOCTOU point as
// adoptPreBeginHook. It is inert in every normal invocation — the tracked
// wrapper scripts and the live register never set the variable — and exists
// solely so the race adoptPreBeginHook exercises with goroutines can also be
// reproduced with two real, independent OS processes racing on the same id;
// see TestGapAdoptRaceRefusesConcurrentDoubleAdopt's comment for the recipe.
func adoptRaceWindow() {
	if v := os.Getenv("WI_GAP_ADOPT_RACE_MS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			time.Sleep(time.Duration(n) * time.Millisecond)
		}
	}
}

var actorRe = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._@:+-]*$`)
var cycleRe = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

// reopenReasons is the canonical §11.4.34 reopen vocabulary (the canonical
// binary's `reopen --why` closed set).
var reopenReasons = []string{"test-failed", "manual-testing-detected", "captured-evidence-contradicts",
	"end-user-report", "cycle-re-discovered", "design-reconsidered"}

// RunGap dispatches `workable-items-vsc gap <subcommand>`.
func RunGap(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "usage: workable-items-vsc gap <migrate|add|adopt|classify|verdict|close|reopen|link|apply-queue|freeze|summary> [flags]")
		fmt.Fprintln(stderr, HonestyNotice)
		return rcUndet
	}
	cmds := map[string]func([]string, io.Writer, io.Writer) int{
		"migrate": gapMigrate, "add": gapAdd, "adopt": gapAdopt, "classify": gapClassify, "verdict": gapVerdict,
		"close": gapClose, "reopen": gapReopen, "link": gapLink, "apply-queue": gapApplyQueue,
		"freeze": gapFreeze, "summary": gapSummary,
	}
	f, ok := cmds[args[0]]
	if !ok {
		fmt.Fprintf(stderr, "gap: unknown subcommand %q\n", args[0])
		return rcUndet
	}
	return f(args[1:], stdout, stderr)
}

// gapPaths resolves --repo and --db. The repository root is discovered by
// walking up from the working directory unless --repo is given; the database
// defaults to <root>/docs/workable_items.db. needRoot=false lets a caller that
// was given --db work outside a checkout.
func gapPaths(repo, db string, needRoot bool) (root, dbPath string, err error) {
	if repo != "" {
		if root, err = filepath.Abs(repo); err != nil {
			return "", "", err
		}
	} else if needRoot || db == "" {
		cwd, e := os.Getwd()
		if e != nil {
			return "", "", e
		}
		if root, err = FindRepoRoot(cwd); err != nil {
			return "", "", err
		}
	}
	if db != "" {
		dbPath, err = filepath.Abs(db)
		return root, dbPath, err
	}
	return root, filepath.Join(root, defaultDBRel), nil
}

func newFlags(name string, stderr io.Writer) (*flag.FlagSet, *string, *string) {
	fs := flag.NewFlagSet("gap "+name, flag.ContinueOnError)
	fs.SetOutput(stderr)
	repo := fs.String("repo", "", "repository root (default: discovered from the working directory)")
	db := fs.String("db", "", "register path (default: <repo>/"+defaultDBRel+")")
	return fs, repo, db
}

// gapEnv is an opened, migrated register plus the context the rules need.
type gapEnv struct {
	root, dbPath string
	db           *sql.DB
	opts         GapOptions
	out, errw    io.Writer
	// base holds the findings and undetermined rows the register carried
	// BEFORE this command, so a write is judged by what it changes.
	base      map[string]bool
	baseUndet map[string]bool
}

func findingKey(f Finding) string { return f.Rule + "\x1f" + f.ItemID + "\x1f" + f.Detail }

func (e *gapEnv) close() { e.db.Close() }

// openGap opens a migrated register for writing (or reading). It returns a
// non-zero rc (always 2: nothing about the register could be determined) when
// the paths, database, schema, roster or --as-of cannot be established.
func openGap(repo, dbFlag, asOf string, readOnly bool, out, errw io.Writer) (*gapEnv, int) {
	root, dbPath, err := gapPaths(repo, dbFlag, true)
	if err != nil {
		fmt.Fprintf(errw, "COULD NOT DETERMINE: %v\n", err)
		return nil, rcUndet
	}
	day := asOf
	if day == "" {
		day = nowFn().Format("2006-01-02")
	}
	if _, err := ParseAsOf(day); err != nil {
		fmt.Fprintf(errw, "COULD NOT DETERMINE: %v\n", err)
		return nil, rcUndet
	}
	db, err := OpenExisting(dbPath, readOnly)
	if err != nil {
		fmt.Fprintf(errw, "COULD NOT DETERMINE: %v\n", err)
		return nil, rcUndet
	}
	if err := requireMigrated(db); err != nil {
		db.Close()
		fmt.Fprintf(errw, "COULD NOT DETERMINE: %v\n", err)
		return nil, rcUndet
	}
	r, err := LoadRoster(root)
	if err != nil {
		db.Close()
		fmt.Fprintf(errw, "COULD NOT DETERMINE: reading the roster: %v\n", err)
		return nil, rcUndet
	}
	e := &gapEnv{root: root, dbPath: dbPath, db: db, out: out, errw: errw,
		opts: GapOptions{AsOf: day, Root: root, Roster: r}, base: map[string]bool{}, baseUndet: map[string]bool{}}
	if !readOnly {
		note := ""
		if asOf == "" {
			note = " (default: today, UTC)"
		}
		fmt.Fprintf(errw, "as-of: %s%s\n", day, note)
	}
	return e, rcOK
}

// begin opens the write transaction (BEGIN IMMEDIATE via the DSN, so two
// writers serialise on the lock instead of racing) and records, INSIDE it, the
// findings the register carried before this command's change. It returns a
// non-zero rc (2) when the transaction or the baseline cannot be established.
func (e *gapEnv) begin() (*sql.Tx, int) {
	tx, err := e.db.Begin()
	if err != nil {
		fmt.Fprintf(e.errw, "COULD NOT DETERMINE: starting the write transaction: %v\n", err)
		return nil, rcUndet
	}
	v, err := validateGapOn(tx, e.opts)
	if err != nil {
		tx.Rollback()
		fmt.Fprintf(e.errw, "COULD NOT DETERMINE: validating the register before the write: %v\n", err)
		return nil, rcUndet
	}
	e.base, e.baseUndet = map[string]bool{}, map[string]bool{}
	for _, f := range v.rep.Findings {
		e.base[findingKey(f)] = true
	}
	for _, u := range v.rep.Undetermined {
		e.baseUndet[u] = true
	}
	return tx, rcOK
}

// envFail reports an environment/driver fault (read-only file, lock timeout,
// I/O error) during a write: the command could not complete, which is a 2 —
// never a 1, because nothing about the register was found to be wrong.
func envFail(w io.Writer, what string, err error) int {
	fmt.Fprintf(w, "COULD NOT DETERMINE: %s: %v; nothing was written\n", what, err)
	return rcUndet
}

// resolveFile reports whether a repository-relative (or absolute) path names a
// non-empty regular file.
func (e *gapEnv) resolveFile(p string) error {
	full, err := Confine(e.root, p)
	if err != nil {
		return err
	}
	info, err := os.Stat(full)
	if err != nil {
		return fmt.Errorf("%s does not resolve: %w", p, err)
	}
	if !info.Mode().IsRegular() || info.Size() == 0 {
		return fmt.Errorf("%s is not a non-empty regular file", p)
	}
	return nil
}

// fileSHA256 hashes a confined, existing file; "" when it cannot be hashed.
func (e *gapEnv) fileSHA256(p string) string {
	full, err := Confine(e.root, p)
	if err != nil {
		return ""
	}
	d, err := fileDigest(full)
	if err != nil {
		return ""
	}
	return d
}

func (e *gapEnv) readRecord(p string) (*EvidenceRecord, error) {
	rec, _, err := e.readRecordDigest(p)
	return rec, err
}

// readRecordDigest reads a confined evidence record ONCE, returning the record
// and the sha256 of the bytes it parsed (F4: no re-read between parse and hash).
func (e *gapEnv) readRecordDigest(p string) (*EvidenceRecord, string, error) {
	full, err := Confine(e.root, p)
	if err != nil {
		return nil, "", err
	}
	return ReadEvidenceRecordDigest(full)
}

// HonestyNotice is printed by `gap close`, `gap summary` and a clean
// `validate` (fix round 4, F6): until T068 binds every counted record to the
// evidence chain, the timestamps, chain_seq values, actor names and digests the
// validator checks are written by the same register and tool it checks.
const HonestyNotice = "closed = structurally consistent + self-recorded digests; NOT independently proven until T068 chain binding"

// problemsAfter validates the uncommitted state in tx and returns what the
// write is answerable for: every finding on a target item, and every finding
// ANYWHERE that did not exist before the command (a write may not break a
// neighbour — for example closing a head while its recurrence is still open).
// Findings on a target whose rule is in ignore are returned as noted, not
// blocking. undet reports undetermined rows that are new or concern a target.
func (e *gapEnv) problemsAfter(tx *sql.Tx, targets []string, ignore ...string) (blocking, noted []Finding, undet []string, err error) {
	v, err := validateGapOn(tx, e.opts)
	if err != nil {
		return nil, nil, nil, err
	}
	for _, f := range v.rep.Findings {
		target := inSet(targets, f.ItemID)
		switch {
		case !target && e.base[findingKey(f)]:
			// pre-existing and unrelated: not this write's doing
		case target && inSet(ignore, f.Rule):
			noted = append(noted, f)
		default:
			blocking = append(blocking, f)
		}
	}
	for _, u := range v.rep.Undetermined {
		if !e.baseUndet[u] {
			undet = append(undet, u)
		}
	}
	for _, id := range targets {
		if v.undetIDs[id] > 0 && len(undet) == 0 {
			undet = append(undet, fmt.Sprintf("%d condition(s) of %s could not be checked", v.undetIDs[id], id))
		}
	}
	return blocking, noted, undet, nil
}

// commitIfClean commits tx only when problemsAfter reports nothing blocking and
// nothing undetermined. It returns the rc and the noted (ignored) findings.
func (e *gapEnv) commitIfClean(tx *sql.Tx, id, verb string, ignore ...string) (int, []Finding) {
	blocking, noted, undet, err := e.problemsAfter(tx, []string{id}, ignore...)
	if err != nil {
		fmt.Fprintf(e.errw, "COULD NOT DETERMINE: validating %s: %v\n", id, err)
		return rcUndet, nil
	}
	if len(blocking) > 0 {
		fmt.Fprintf(e.errw, "REFUSED: %s %s would leave %d finding(s); nothing was written:\n", verb, id, len(blocking))
		for _, f := range blocking {
			fmt.Fprintln(e.errw, "  FINDING  "+f.String())
		}
		return rcFind, nil
	}
	if len(undet) > 0 {
		fmt.Fprintf(e.errw, "COULD NOT DETERMINE: %s %s: %d condition(s) could not be checked; nothing was written:\n", verb, id, len(undet))
		for _, u := range undet {
			fmt.Fprintln(e.errw, "  UNDET    "+u)
		}
		return rcUndet, nil
	}
	if err := tx.Commit(); err != nil {
		fmt.Fprintf(e.errw, "COULD NOT DETERMINE: commit: %v\n", err)
		return rcUndet, nil
	}
	return rcOK, noted
}

// shaOr renders a digest for a history reason; "unavailable" never matches the
// validator's sha256 pattern, so a file that could not be hashed is a finding.
func shaOr(d string) string {
	if d == "" {
		return "unavailable"
	}
	return d
}

func nullable(s string) any {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return s
}

func stamp() string { return nowFn().Format("2006-01-02 15:04:05") }

// ── body helpers (mirroring the canonical binary's body shape) ─────────────

// renderGapBody mirrors the canonical renderItemBody block shape.
func renderGapBody(id, title, typ, severity, description, status, createdBy, assignedTo string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "## %s — %s\n\n", id, title)
	fmt.Fprintf(&b, "**Status:** %s\n", status)
	fmt.Fprintf(&b, "**Type:** %s\n", typ)
	if strings.TrimSpace(severity) != "" {
		fmt.Fprintf(&b, "**Severity:** %s\n", severity)
	}
	if strings.TrimSpace(createdBy) != "" {
		fmt.Fprintf(&b, "**Created-By:** %s\n", createdBy)
	}
	if strings.TrimSpace(assignedTo) != "" {
		fmt.Fprintf(&b, "**Assigned-To:** %s\n", assignedTo)
	}
	fmt.Fprintf(&b, "\n%s\n\n", description)
	return b.String()
}

// setBodyStatus rewrites the first `**Status:**` line and nothing else.
func setBodyStatus(body, status string) string {
	lines := strings.SplitAfter(body, "\n")
	for i, ln := range lines {
		if strings.HasPrefix(ln, "**Status:** ") {
			nl := ""
			if strings.HasSuffix(ln, "\n") {
				nl = "\n"
			}
			lines[i] = "**Status:** " + status + nl
			break
		}
	}
	return strings.Join(lines, "")
}

// upsertMeta replaces the first line starting with key, or inserts line right
// after the `**Type:**` line (the canonical appendEvidence position).
func upsertMeta(body, key, line string) string {
	lines := strings.SplitAfter(body, "\n")
	for i, ln := range lines {
		if strings.HasPrefix(ln, key) {
			lines[i] = line + "\n"
			return strings.Join(lines, "")
		}
	}
	var out strings.Builder
	done := false
	for _, ln := range lines {
		out.WriteString(ln)
		if !done && strings.HasPrefix(ln, "**Type:**") {
			out.WriteString(line + "\n")
			done = true
		}
	}
	if !done {
		out.WriteString(line + "\n")
	}
	return out.String()
}

func appendSeg(tx *sql.Tx, document, id string) error {
	var maxSeq sql.NullInt64
	if err := tx.QueryRow(`SELECT MAX(seq) FROM doc_segments WHERE document=?`, document).Scan(&maxSeq); err != nil {
		return err
	}
	next := 0
	if maxSeq.Valid {
		next = int(maxSeq.Int64) + 1
	}
	_, err := tx.Exec(`INSERT INTO doc_segments (document, seq, kind, atm_id, raw) VALUES (?,?,?,?,NULL)`, document, next, "item", id)
	return err
}

func moveSeg(tx *sql.Tx, from, to, id string) error {
	if _, err := tx.Exec(`DELETE FROM doc_segments WHERE document=? AND kind='item' AND atm_id=?`, from, id); err != nil {
		return err
	}
	return appendSeg(tx, to, id)
}

func history(tx *sql.Tx, id, event, onDate, reason, evidence string) error {
	_, err := tx.Exec(`INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES (?,?,?,?,?,?,?)`,
		id, event, "AI", onDate, nullable(reason), nullable(evidence), stamp())
	return err
}

// itemRow is the subset of one item row the commands read.
type itemRow struct {
	id, loc, typ, status, severity, title, description, createdBy, assignedTo, body string
	disposition, anchor, closureCriteria                                            string
	gap                                                                             bool
}

// loadItem reads an item by id. It prefers the Issues row when the id lives in
// both trackers; missing ⇒ (nil, nil).
func loadItem(q queryer, id string) (*itemRow, error) {
	rows, err := q.Query(`SELECT atm_id, current_location, type, status, COALESCE(severity,''), title, description,
        COALESCE(created_by,''), COALESCE(assigned_to,''), COALESCE(body_md,''), COALESCE(disposition,''),
        COALESCE(forensic_anchor,''), COALESCE(closure_criteria,''),
        (`+gapPredicate+`)
        FROM items WHERE atm_id = ? ORDER BY current_location DESC`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	if !rows.Next() {
		return nil, rows.Err()
	}
	var r itemRow
	if err := rows.Scan(&r.id, &r.loc, &r.typ, &r.status, &r.severity, &r.title, &r.description,
		&r.createdBy, &r.assignedTo, &r.body, &r.disposition, &r.anchor, &r.closureCriteria, &r.gap); err != nil {
		return nil, err
	}
	return &r, nil
}

func refuse(w io.Writer, problems []string) int {
	sort.Strings(problems)
	for _, p := range problems {
		fmt.Fprintln(w, "REFUSED: "+p)
	}
	return rcFind
}

// ── gap migrate ────────────────────────────────────────────────────────────

func gapMigrate(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("migrate", stderr)
	dry := fs.Bool("dry-run", false, "print the DDL that would run; write nothing")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	_, dbPath, err := gapPaths(*repo, *dbFlag, false)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	db, err := OpenExisting(dbPath, *dry)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	defer db.Close()
	res, err := Migrate(db, *dry)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: gap migrate: %v\n", err)
		return rcUndet
	}
	if *dry {
		fmt.Fprintf(stdout, "-- gap migrate --dry-run: %d statement(s) would run; nothing was written.\n", len(res.Statements))
		for _, s := range res.Statements {
			fmt.Fprintln(stdout, s)
		}
		return rcOK
	}
	fmt.Fprintf(stdout, "gap migrate: %d statement(s) applied to %s\n", len(res.Statements), dbPath)
	for _, s := range res.Statements {
		fmt.Fprintln(stdout, "  "+firstLine(s))
	}
	return rcOK
}

// ── gap add ────────────────────────────────────────────────────────────────

func gapAdd(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("add", stderr)
	prefix := fs.String("prefix", "VSC", "three-letter roster prefix of the sub-project the item is filed against")
	typ := fs.String("type", "", "Bug | Feature | Task (research D3)")
	kind := fs.String("kind", "", strings.Join(GapKinds, " | "))
	severity := fs.String("severity", "", strings.Join(GapSeverities, " | "))
	category := fs.String("category", "", "root-cause category (research D4 closed set)")
	title := fs.String("title", "", "one-line title")
	desc := fs.String("description", "", "description (§11.4.91 floor: ≥6 words or ≥40 chars)")
	crit := fs.String("closure-criteria", "", "what must be true to close it")
	sweep := fs.String("sweep-class", "manual", "sweep class that found it, or manual")
	target := fs.String("measurable-target", "", "required for kind=improvement (FR-025)")
	owner := fs.String("owner", "", "owner handle (items.assigned_to)")
	anchor := fs.String("anchor", "", "location of the defect (items.forensic_anchor)")
	evidence := fs.String("evidence", "", "path of the finding's captured evidence (repository-relative)")
	planDue := fs.String("plan-due", "", "dated plan YYYY-MM-DD (FR-006)")
	cycle := fs.String("cycle", "", "programme cycle id")
	fp := fs.String("fingerprint", "", "state fingerprint at discovery (64 hex)")
	createdBy := fs.String("created-by", "AI", "handle that opened the item")
	asOf := fs.String("as-of", "", "ISO date the date rules use (default: today)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, *asOf, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()

	var problems []string
	for name, v := range map[string]string{"--type": *typ, "--kind": *kind, "--severity": *severity,
		"--category": *category, "--title": *title, "--description": *desc, "--owner": *owner,
		"--anchor": *anchor, "--evidence": *evidence} {
		if strings.TrimSpace(v) == "" {
			problems = append(problems, name+" is required")
		}
	}
	if d := strings.TrimSpace(*desc); d != "" && len(d) < 40 && len(strings.Fields(d)) < 6 {
		problems = append(problems, "--description is below the §11.4.91 floor (≥6 words or ≥40 chars)")
	}
	sp, inRoster := e.opts.Roster.ByPrefix()[*prefix]
	switch {
	case !inRoster:
		problems = append(problems, fmt.Sprintf("prefix %q names no sub-project in %s", *prefix, RosterPath))
	case sp.Class == ClassThirdParty:
		problems = append(problems, fmt.Sprintf("prefix %q is a third-party sub-project; no item may be filed against it", *prefix))
	}
	if *evidence != "" {
		if err := e.resolveFile(*evidence); err != nil {
			problems = append(problems, "--evidence "+err.Error())
		}
	}
	if *cycle != "" && !cycleRe.MatchString(*cycle) {
		problems = append(problems, fmt.Sprintf("--cycle %q is not a plain identifier", *cycle))
	}
	if *fp != "" && !hex64Re.MatchString(*fp) {
		problems = append(problems, "--fingerprint is not 64 lowercase hex digits")
	}
	if len(problems) > 0 {
		return refuse(stderr, problems)
	}

	tx, brc := e.begin()
	if brc != rcOK {
		return brc
	}
	defer tx.Rollback()
	var max int
	rows, err := tx.Query(`SELECT DISTINCT atm_id FROM items`)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	for rows.Next() {
		var id string
		rows.Scan(&id)
		if p, n, ok := SplitID(id); ok && p == *prefix && n > max {
			max = n
		}
	}
	rows.Close()
	id := FormatID(*prefix, max+1)
	now := stamp()
	body := renderGapBody(id, *title, *typ, *severity, *desc, StatusQueued, *createdBy, *owner)
	if _, err := tx.Exec(`INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,closure_criteria,
        created_by,assigned_to,current_location,body_md,created_at,last_modified,
        kind,category,disposition,plan_due,measurable_target,sweep_class,cycle,first_seen_fingerprint,reopens_count)
        VALUES (?,?,?,?,?,?,?,?,?,?,'Issues',?,?,?,?,?,'open',?,?,?,?,?,0)`,
		id, *typ, StatusQueued, *severity, *title, *desc, *anchor, nullable(*crit), *createdBy, *owner, body, now, now,
		*kind, *category, nullable(*planDue), nullable(*target), nullable(*sweep), nullable(*cycle), nullable(*fp)); err != nil {
		return envFail(stderr, "inserting "+id, err)
	}
	if err := appendSeg(tx, "Issues", id); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if _, err := tx.Exec(`INSERT INTO item_provenance (atm_id,source_kind,source_path,source_locator,evidence_class,status_note)
        VALUES (?,?,?,?,?,?)`, id, "session-work", *evidence, "gap add sweep_class="+*sweep, "undetermined",
		"opened by `gap add` from a sweep finding; the finding's evidence is the source_path"); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if err := history(tx, id, "Opened", e.opts.AsOf, "zero-gap:opened sweep_class="+*sweep, *evidence); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if rc, _ := e.commitIfClean(tx, id, "gap add"); rc != rcOK {
		return rc
	}
	fmt.Fprintf(stdout, "gap add: created %s (%s, %s, %s/%s), open, plan due %s\n", id, *typ, *kind, *severity, *category, *planDue)
	return rcOK
}

// ── gap classify ───────────────────────────────────────────────────────────

func gapClassify(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("classify", stderr)
	id := fs.String("id", "", "item id")
	reason := fs.String("reason", "", strings.Join(GapClassificationReason, " | "))
	owner := fs.String("owner", "", "who can lift the classification")
	recheck := fs.String("recheck", "", "recheck date YYYY-MM-DD")
	what := fs.String("block-what", "", "operator reasons: the decision or action needed")
	why := fs.String("block-why", "", "operator reasons: why no alternative remains")
	options := fs.String("block-options", "", "operator reasons: one list line per option, each with \"cost: …\"")
	who := fs.String("block-who", "", "operator reasons: who acts (default: --owner)")
	asOf := fs.String("as-of", "", "ISO date the date rules use (default: today)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, *asOf, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	it, err := loadItem(e.db, *id)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	var problems []string
	switch {
	case it == nil:
		return refuse(stderr, []string{fmt.Sprintf("no item %q", *id)})
	case !it.gap:
		problems = append(problems, *id+" is not a gap item")
	case it.disposition == "closed":
		problems = append(problems, *id+" is closed; a closed item is not classified (reopen it first)")
	}
	if !inSet(GapClassificationReason, *reason) {
		problems = append(problems, fmt.Sprintf("--reason %q is not one of {%s}; \"accepted as is\" does not exist (FR-006)", *reason, strings.Join(GapClassificationReason, ", ")))
	}
	operator := *reason == "operator-decision" || *reason == "operator-action"
	if operator && (strings.TrimSpace(*what) == "" || strings.TrimSpace(*why) == "" || strings.TrimSpace(*options) == "") {
		problems = append(problems, "an operator reason needs --block-what, --block-why and --block-options (FR-009)")
	}
	if len(problems) > 0 {
		return refuse(stderr, problems)
	}
	status := StatusQueued
	if operator {
		status = StatusBlocked
	}
	tx, brc := e.begin()
	if brc != rcOK {
		return brc
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`UPDATE items SET disposition='classified', classification_reason=?, classification_owner=?,
        classification_recheck=?, plan_due=NULL, status=?, body_md=?, last_modified=? WHERE atm_id=? AND current_location=?`,
		*reason, nullable(*owner), nullable(*recheck), status, setBodyStatus(it.body, status), stamp(), it.id, it.loc); err != nil {
		return envFail(stderr, "writing the register", err)
	}
	if operator {
		w := *who
		if w == "" {
			w = *owner
		}
		if _, err := tx.Exec(`INSERT OR REPLACE INTO operator_block_details (atm_id,what,why_exhausted_alternatives,unblock_condition,who)
            VALUES (?,?,?,?,?)`, it.id, *what, *why, *options, nullable(w)); err != nil {
			return envFail(stderr, "writing the register", err)
		}
	}
	if err := history(tx, it.id, "Updated", e.opts.AsOf, fmt.Sprintf("zero-gap:classified reason=%s", *reason), ""); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if rc, _ := e.commitIfClean(tx, it.id, "gap classify"); rc != rcOK {
		return rc
	}
	fmt.Fprintf(stdout, "gap classify: %s classified %s (status %s), owner %s, recheck %s\n", it.id, *reason, status, *owner, *recheck)
	return rcOK
}

// ── gap adopt ──────────────────────────────────────────────────────────────
//
// `gap adopt` is the mirror image of `gap add`: `add` INSERTs a brand-new row;
// `adopt` UPDATEs an EXISTING non-gap row in place, setting it.gap=true and
// filling the 14 zero-gap columns (gapschema.go's GapColumns) so the item can
// be classified/verdicted/closed like any item `add` opened. It never changes
// atm_id, type, status or current_location — a pre-existing row's identity and
// lifecycle position are exactly what adoption preserves (plan-migrate finding
// 4, progress.yml: 18 register rows already exist and would otherwise need a
// duplicate id or a canonical `close` that wipes every gap column). It DOES
// update title/description/closure_criteria/forensic_anchor when the operator
// supplies better text at adoption time (a one-time backfill, not just a
// column fill) but leaves body_md untouched: no V-G rule or base rule reads
// body_md, and regenerating the Markdown heading is a job for a documented
// regeneration mechanism (§11.4.77), not for this command.
func gapAdopt(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("adopt", stderr)
	id := fs.String("id", "", "existing item id to adopt as a gap item (must not already be one)")
	kind := fs.String("kind", "", strings.Join(GapKinds, " | "))
	severity := fs.String("severity", "", strings.Join(GapSeverities, " | "))
	category := fs.String("category", "", "root-cause category (research D4 closed set)")
	title := fs.String("title", "", "one-line title (overwrites items.title)")
	rootCause := fs.String("root-cause", "", "root-cause narrative (folded into items.description)")
	proposedFix := fs.String("proposed-fix", "", "proposed-fix narrative (folded into items.description)")
	crit := fs.String("closure-criteria", "", "what must be true to close it (default: keep the item's existing value)")
	target := fs.String("measurable-target", "", "required for kind=improvement (FR-025)")
	anchor := fs.String("anchor", "", "location of the defect (items.forensic_anchor); default: keep the item's existing value")
	owner := fs.String("owner", "", "owner handle (items.assigned_to); default: keep the item's existing value — V-G1 needs a non-empty one either way")
	evidence := fs.String("evidence", "", "path of evidence supporting the adoption (repository-relative)")
	planDue := fs.String("plan-due", "", "dated plan YYYY-MM-DD (FR-006; required by V-G10 when --disposition=open)")
	disposition := fs.String("disposition", "open", "open | classified — adopt never closes an item")
	reason := fs.String("classification-reason", "", strings.Join(GapClassificationReason, " | ")+" (required iff --disposition=classified)")
	cowner := fs.String("classification-owner", "", "who can lift the classification (required iff classified)")
	recheck := fs.String("classification-recheck", "", "recheck date YYYY-MM-DD (required iff classified)")
	what := fs.String("block-what", "", "operator reasons: the decision or action needed")
	why := fs.String("block-why", "", "operator reasons: why no alternative remains")
	options := fs.String("block-options", "", "operator reasons: one list line per option, each with \"cost: …\"")
	who := fs.String("block-who", "", "operator reasons: who acts (default: --classification-owner)")
	asOf := fs.String("as-of", "", "ISO date the date rules use (default: today)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, *asOf, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	it, err := loadItem(e.db, *id)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	var problems []string
	switch {
	case it == nil:
		return refuse(stderr, []string{fmt.Sprintf("no item %q", *id)})
	case it.gap:
		problems = append(problems, *id+" is already a gap item; adopt is one-time — use classify/verdict/close to change it")
	}
	for name, v := range map[string]string{"--kind": *kind, "--severity": *severity, "--category": *category,
		"--title": *title, "--root-cause": *rootCause, "--proposed-fix": *proposedFix, "--closure-criteria": *crit} {
		if strings.TrimSpace(v) == "" {
			problems = append(problems, name+" is required")
		}
	}
	description := strings.TrimSpace(*rootCause)
	if pf := strings.TrimSpace(*proposedFix); pf != "" {
		if description != "" {
			description += "\n\n"
		}
		description += "Proposed fix: " + pf
	}
	if d := description; d != "" && len(d) < 40 && len(strings.Fields(d)) < 6 {
		problems = append(problems, "--root-cause/--proposed-fix together are below the §11.4.91 floor (≥6 words or ≥40 chars)")
	}
	if *evidence != "" {
		if err := e.resolveFile(*evidence); err != nil {
			problems = append(problems, "--evidence "+err.Error())
		}
	}
	if !inSet([]string{"open", "classified"}, *disposition) {
		problems = append(problems, fmt.Sprintf("--disposition %q is not open or classified; adopt never closes an item", *disposition))
	}
	operator := false
	if it != nil && *disposition == "classified" {
		if !inSet(GapClassificationReason, *reason) {
			problems = append(problems, fmt.Sprintf("--classification-reason %q is not one of {%s}", *reason, strings.Join(GapClassificationReason, ", ")))
		}
		operator = *reason == "operator-decision" || *reason == "operator-action"
		if operator && (strings.TrimSpace(*what) == "" || strings.TrimSpace(*why) == "" || strings.TrimSpace(*options) == "") {
			problems = append(problems, "an operator reason needs --block-what, --block-why and --block-options (FR-009)")
		}
	}
	// Adopt never changes status (it preserves atm_id/type/status/location), so
	// the requested disposition must already agree with the status the item
	// carries today — the same agreement V-G7 enforces after the write, stated
	// up front with a clear reason instead of a bare post-commit finding.
	if it != nil && len(problems) == 0 {
		switch *disposition {
		case "open":
			if !inSet(openStatuses, it.status) {
				problems = append(problems, fmt.Sprintf("%s has status %q, not an open status; adopt does not change status — fix the status first or use --disposition classified", *id, it.status))
			}
		case "classified":
			switch {
			case operator && it.status != StatusBlocked:
				problems = append(problems, fmt.Sprintf("classified %s must carry status Operator-blocked, not %q; adopt does not change status", *reason, it.status))
			case !operator && it.status != StatusQueued:
				problems = append(problems, fmt.Sprintf("classified %s must carry the exact status Queued, not %q; adopt does not change status", *reason, it.status))
			}
		}
	}
	if len(problems) > 0 {
		return refuse(stderr, problems)
	}

	// TOCTOU window: it.gap above was read before any write lock is held.
	// Widen it deliberately (test hook, or a real OS-process race via
	// WI_GAP_ADOPT_RACE_MS) so a second concurrent adopt of the same id can
	// land its own loadItem read here before this one's write commits.
	if adoptPreBeginHook != nil {
		adoptPreBeginHook()
	}
	adoptRaceWindow()

	tx, brc := e.begin()
	if brc != rcOK {
		return brc
	}
	defer tx.Rollback()

	newAnchor := it.anchor
	if strings.TrimSpace(*anchor) != "" {
		newAnchor = *anchor
	}
	newCrit := it.closureCriteria
	if strings.TrimSpace(*crit) != "" {
		newCrit = *crit
	}
	newOwner := it.assignedTo
	if strings.TrimSpace(*owner) != "" {
		newOwner = *owner
	}
	// AND kind IS NULL closes the TOCTOU window above at the database level
	// (§11.4.253): kind is one of the 14 additive zero-gap columns
	// (gapschema.go), gapPredicate's COALESCE treats a NULL kind (among
	// others) as "not yet a gap item", and gapAdopt is the only writer that
	// ever sets it — so an item this command's own it.gap check found clean
	// has kind IS NULL at that instant, and stays matchable by this UPDATE
	// only until some transaction (this one or a concurrent one) commits a
	// non-NULL kind for it. A concurrent adopt of the same id that already
	// committed its own UPDATE first flips kind to non-NULL, so this
	// transaction's UPDATE (serialised behind BEGIN IMMEDIATE per e.begin's
	// comment, so it sees that commit) touches zero rows instead of
	// re-applying a stale, already-superseded write.
	res, err := tx.Exec(`UPDATE items SET title=?, description=?, severity=?, forensic_anchor=?, closure_criteria=?,
        assigned_to=?, kind=?, category=?, disposition=?, classification_reason=?, classification_owner=?, classification_recheck=?,
        plan_due=?, measurable_target=?, sweep_class=COALESCE(sweep_class,'adopted'), reopens_count=COALESCE(reopens_count,0),
        last_modified=? WHERE atm_id=? AND current_location=? AND kind IS NULL`,
		*title, description, *severity, nullable(newAnchor), nullable(newCrit),
		newOwner, *kind, *category, *disposition, nullable(*reason), nullable(*cowner), nullable(*recheck),
		nullable(*planDue), nullable(*target), stamp(), it.id, it.loc)
	if err != nil {
		return envFail(stderr, "adopting "+it.id, err)
	}
	switch n, _ := res.RowsAffected(); {
	case n == 0:
		// Never partial-apply: nothing else in this transaction has run yet,
		// and the deferred tx.Rollback() above discards it untouched.
		return refuse(stderr, []string{fmt.Sprintf(
			"%s was adopted concurrently by another process between this command's check and its write (kind is no longer NULL); nothing was written — re-run to see its current state", it.id)})
	case n != 1:
		return envFail(stderr, "adopting "+it.id, fmt.Errorf("adopting %s touched %d rows", it.id, n))
	}
	if operator {
		w := *who
		if w == "" {
			w = *cowner
		}
		if _, err := tx.Exec(`INSERT OR REPLACE INTO operator_block_details (atm_id,what,why_exhausted_alternatives,unblock_condition,who)
            VALUES (?,?,?,?,?)`, it.id, *what, *why, *options, nullable(w)); err != nil {
			return envFail(stderr, "adopting "+it.id, err)
		}
	}
	if adoptMidHook != nil {
		if err := adoptMidHook(tx); err != nil {
			return envFail(stderr, "adopting "+it.id, err)
		}
	}
	// Preserve whatever provenance already exists (adoption is not a new
	// creation event); only an item with none gets one, and it names the
	// adoption itself as the source, not a fabricated original source.
	if _, err := tx.Exec(`INSERT OR IGNORE INTO item_provenance (atm_id,source_kind,source_path,source_locator,evidence_class,status_note)
        VALUES (?,?,?,?,?,?)`, it.id, "session-work", nullable(*evidence), "gap adopt", "undetermined",
		"adopted into the zero-gap register by `gap adopt`; no earlier provenance row existed"); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if err := history(tx, it.id, "Updated", e.opts.AsOf,
		fmt.Sprintf("zero-gap:adopted kind=%s category=%s severity=%s disposition=%s", *kind, *category, *severity, *disposition), *evidence); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if rc, _ := e.commitIfClean(tx, it.id, "gap adopt"); rc != rcOK {
		return rc
	}
	fmt.Fprintf(stdout, "gap adopt: %s adopted as a gap item (%s, %s/%s), disposition %s\n", it.id, *kind, *severity, *category, *disposition)
	return rcOK
}

// ── gap verdict ────────────────────────────────────────────────────────────

func gapVerdict(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("verdict", stderr)
	id := fs.String("id", "", "item id")
	role := fs.String("role", "", "verifier | reviewer")
	actor := fs.String("actor", "", "handle of the agent or script giving the verdict")
	kind := fs.String("actor-kind", "", "agent | script")
	outcome := fs.Int("outcome", -1, "0 holds · 1 violated (a disagreement) · 2 could not determine")
	evidence := fs.String("evidence", "", "path of the verdict's evidence (repository-relative)")
	on := fs.String("on", "", "date of the verdict YYYY-MM-DD (default: today)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, *on, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	var problems []string
	if it, err := loadItem(e.db, *id); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	} else if it == nil {
		problems = append(problems, fmt.Sprintf("no item %q; a verdict must name an existing item (V-G12)", *id))
	}
	if !inSet([]string{"verifier", "reviewer"}, *role) {
		problems = append(problems, fmt.Sprintf("--role %q is not verifier or reviewer", *role))
	}
	if !inSet([]string{"agent", "script"}, *kind) {
		problems = append(problems, fmt.Sprintf("--actor-kind %q is not agent or script", *kind))
	}
	if !actorRe.MatchString(*actor) {
		problems = append(problems, fmt.Sprintf("--actor %q is not a plain handle", *actor))
	}
	if *outcome < 0 || *outcome > 2 {
		problems = append(problems, fmt.Sprintf("--outcome %d is not 0, 1 or 2", *outcome))
	}
	// I3: the sha256 of the evidence as it is at verdict time — for a verifier
	// record, of the SAME bytes that were parsed (F4, one read).
	sha := ""
	if err := e.resolveFile(*evidence); err != nil {
		problems = append(problems, "--evidence "+err.Error())
	} else if *role == "verifier" {
		// C1: a verifier's evidence is the record of its OWN re-run of the
		// check, and it is read — a text file is not a verification.
		switch rec, d, err := e.readRecordDigest(*evidence); {
		case err != nil:
			problems = append(problems, "--evidence "+*evidence+" is not an evidence record: "+err.Error())
		case *rec.ItemID != *id:
			problems = append(problems, fmt.Sprintf("--evidence %s is recorded for %s, not %s", *evidence, *rec.ItemID, *id))
		case *rec.VerdictRole != "verifier":
			problems = append(problems, fmt.Sprintf("--evidence %s has verdict_role %q, not verifier", *evidence, *rec.VerdictRole))
		case *rec.Outcome != *outcome:
			problems = append(problems, fmt.Sprintf("--evidence %s has outcome %d but --outcome is %d", *evidence, *rec.Outcome, *outcome))
		case futureDated(rec):
			problems = append(problems, fmt.Sprintf("--evidence %s is dated %s, in the future", *evidence, *rec.TS))
		case recordDay(rec) > e.opts.AsOf:
			// F5: a verdict row cannot be dated before the run it records.
			problems = append(problems, fmt.Sprintf("--on %s is before the day the record %s was measured (%s); a verdict is never recorded on a day before its own run", e.opts.AsOf, *evidence, *rec.TS))
		default:
			sha = d
		}
	} else {
		sha = e.fileSHA256(*evidence)
	}
	if len(problems) > 0 {
		return refuse(stderr, problems)
	}
	if _, err := e.db.Exec(`INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path,evidence_sha256) VALUES (?,?,?,?,?,?,?,?)`,
		*id, *role, *actor, *kind, e.opts.AsOf, *outcome, *evidence, nullable(sha)); err != nil {
		return envFail(stderr, "writing the register", err)
	}
	fmt.Fprintf(stdout, "gap verdict: %s %s by %s (%s) outcome %d\n", *id, *role, *actor, *kind, *outcome)
	return rcOK
}

// ── gap close ──────────────────────────────────────────────────────────────

func gapClose(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("close", stderr)
	id := fs.String("id", "", "item id")
	red := fs.String("red-evidence", "", "evidence record of the check FAILING on the pre-fix state (outcome 1)")
	green := fs.String("green-evidence", "", "evidence record of the SAME check PASSING on the current state (outcome 0)")
	verdictRef := fs.String("verdict-ref", "", "evidence path of the independent verifier's item_verdicts row")
	fixer := fs.String("fixer", "", "handle of whoever made the fix")
	author := fs.String("check-author", "", "handle of whoever authored the closure check (≠ fixer, §11.4.240(C)(1))")
	research := fs.String("research-ref", "", "path of the §11.4.150 research record (default: the item's research_ref)")
	asOf := fs.String("as-of", "", "ISO date the date rules use (default: today)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, *asOf, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	it, err := loadItem(e.db, *id)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	var problems []string
	switch {
	case it == nil:
		return refuse(stderr, []string{fmt.Sprintf("no item %q", *id)})
	case !it.gap:
		problems = append(problems, *id+" is not a gap item")
	case it.disposition == "closed" || it.loc != "Issues":
		problems = append(problems, *id+" is already closed")
	}
	for name, v := range map[string]string{"--red-evidence": *red, "--green-evidence": *green,
		"--verdict-ref": *verdictRef, "--fixer": *fixer, "--check-author": *author} {
		if strings.TrimSpace(v) == "" {
			problems = append(problems, name+" is required")
		}
	}
	for name, v := range map[string]string{"--fixer": *fixer, "--check-author": *author} {
		if v != "" && !actorRe.MatchString(v) {
			problems = append(problems, fmt.Sprintf("%s %q is not a plain handle", name, v))
		}
	}
	if strings.ContainsAny(*verdictRef, " \t\n") {
		problems = append(problems, "--verdict-ref must be a single path")
	}
	// Each cited record is read ONCE, before the write transaction: the
	// check id and the sha256 written into the history rows come from the
	// same bytes (F4), and a special file — a FIFO would block open(2) while
	// the write lock was held — is refused before begin() (F2).
	type cited struct {
		rec *EvidenceRecord
		sha string
	}
	recs := map[string]cited{}
	for name, p := range map[string]string{"--red-evidence": *red, "--green-evidence": *green, "--verdict-ref": *verdictRef} {
		if p == "" {
			continue
		}
		rec, sha, err := e.readRecordDigest(p)
		switch {
		case err != nil && (strings.Contains(err.Error(), "1 MiB") || isEscape(err) || errors.Is(err, errNotRegular)):
			problems = append(problems, name+" "+err.Error())
		case err == nil && futureDated(rec):
			problems = append(problems, fmt.Sprintf("%s %s is dated %s, in the future (now %s)", name, p, *rec.TS, nowFn().Format(time.RFC3339)))
		case err == nil:
			recs[p] = cited{rec, sha}
		}
	}
	if len(problems) > 0 {
		return refuse(stderr, problems)
	}
	checkOf := func(p string) string {
		if c, ok := recs[p]; ok {
			return *c.rec.CheckID
		}
		return "?"
	}
	shaOf := func(p string) string { return shaOr(recs[p].sha) }
	researchPath := *research
	if researchPath == "" {
		var rr sql.NullString
		e.db.QueryRow(`SELECT research_ref FROM items WHERE atm_id=? AND current_location='Issues'`, it.id).Scan(&rr)
		researchPath = rr.String
	}
	if researchPath != "" {
		if err := e.resolveFile(researchPath); err != nil {
			return refuse(stderr, []string{"research_ref " + err.Error()})
		}
	}
	terminal := ClosureFor(it.typ)
	event := strings.Fields(terminal)[0] // Fixed | Implemented | Completed
	body := upsertMeta(setBodyStatus(it.body, terminal), "**Evidence:** ", "**Evidence:** "+*green)

	tx, brc := e.begin()
	if brc != rcOK {
		return brc
	}
	defer tx.Rollback()
	steps := []func() error{
		func() error {
			return history(tx, it.id, "Updated", e.opts.AsOf, "zero-gap:red-evidence check="+checkOf(*red)+" sha256="+shaOf(*red), *red)
		},
		func() error {
			return history(tx, it.id, "Updated", e.opts.AsOf, "zero-gap:green-evidence check="+checkOf(*green)+" sha256="+shaOf(*green), *green)
		},
		// No test_diary row is written here: the diary PASS V-G3 requires is
		// INDEPENDENT evidence of a test run (canonical `diary add`), and a
		// close that wrote its own would satisfy the rule by construction.
		func() error {
			res, err := tx.Exec(`UPDATE items SET status=?, current_location='Fixed', disposition='closed',
                research_ref=COALESCE(?, research_ref), classification_reason=NULL, classification_owner=NULL,
                classification_recheck=NULL, body_md=?, last_modified=? WHERE atm_id=? AND current_location='Issues'`,
				terminal, nullable(*research), body, stamp(), it.id)
			if err != nil {
				return err
			}
			if n, _ := res.RowsAffected(); n != 1 {
				return fmt.Errorf("moving %s to Fixed touched %d rows", it.id, n)
			}
			return nil
		},
		func() error { return moveSeg(tx, "Issues", "Fixed", it.id) },
		func() error {
			return history(tx, it.id, event, e.opts.AsOf,
				fmt.Sprintf("zero-gap:close fixer=%s check-author=%s verdict=%s research-sha256=%s", *fixer, *author, *verdictRef, shaOr(e.fileSHA256(researchPath))), *green)
		},
	}
	for _, s := range steps {
		if err := s(); err != nil {
			return envFail(stderr, "closing "+it.id, err)
		}
	}
	if rc, _ := e.commitIfClean(tx, it.id, "gap close"); rc != rcOK {
		return rc
	}
	fmt.Fprintf(stdout, "gap close: %s → %s (RED %s, GREEN %s, fixer %s, check author %s, verdict %s)\n",
		it.id, terminal, *red, *green, *fixer, *author, *verdictRef)
	fmt.Fprintln(stdout, HonestyNotice)
	return rcOK
}

// recordDay is the UTC date of a record's ts.
func recordDay(rec *EvidenceRecord) string { return rec.time.UTC().Format("2006-01-02") }

// ── gap reopen / apply-queue ───────────────────────────────────────────────

// reopenItem reopens a closed gap item inside tx. It validates the failing
// evidence first and returns a refusal message (not an error) when the
// request itself is invalid.
func (e *gapEnv) reopenItem(tx *sql.Tx, id, evidence, why, planDue string) (refusal string, err error) {
	it, err := loadItem(tx, id)
	if err != nil {
		return "", err
	}
	switch {
	case it == nil:
		return fmt.Sprintf("no item %q", id), nil
	case !it.gap:
		return id + " is not a gap item", nil
	case it.disposition != "closed":
		return fmt.Sprintf("%s is not closed (disposition %q); only a closed item is reopened", id, it.disposition), nil
	}
	if !inSet(reopenReasons, why) {
		return fmt.Sprintf("reason %q is outside the §11.4.34 set {%s}", why, strings.Join(reopenReasons, ", ")), nil
	}
	rec, err := e.readRecord(evidence)
	if err != nil {
		return fmt.Sprintf("evidence %s: %v", evidence, err), nil
	}
	if *rec.ItemID != id {
		return fmt.Sprintf("evidence %s is recorded for %s, not %s", evidence, *rec.ItemID, id), nil
	}
	if *rec.Outcome != 1 {
		return fmt.Sprintf("evidence %s has outcome %d; a reopen needs the recorded check FAILING (outcome 1)", evidence, *rec.Outcome), nil
	}
	if futureDated(rec) {
		return fmt.Sprintf("evidence %s is dated %s, in the future (now %s); a future-dated failure would make the item impossible to re-close",
			evidence, *rec.TS, nowFn().Format(time.RFC3339)), nil
	}
	// A failure measured before the latest closure says nothing about the
	// closed state (fix round 2, N1; apply-queue already skips such records).
	if closedAt, ok, err := latestClosure(tx, id); err != nil {
		return "", err
	} else if ok && !rec.time.After(closedAt) {
		return fmt.Sprintf("evidence %s (%s) is not later than %s's latest closure (%s); it cannot show the closed state failing",
			evidence, *rec.TS, id, closedAt.Format(time.RFC3339)), nil
	}
	// ...nor may it predate the latest GREEN this item ever cited (round 3,
	// I1(c)): a failure older than the passing run proves nothing about it.
	hist, err := loadHistory(tx)
	if err != nil {
		return "", err
	}
	var latestGreen time.Time
	for _, h := range hist[id] {
		if strings.HasPrefix(h.reason, "zero-gap:green-evidence") {
			if g, err := e.readRecord(h.evid); err == nil && g.time.After(latestGreen) {
				latestGreen = g.time
			}
		}
	}
	if !latestGreen.IsZero() && !rec.time.After(latestGreen) {
		return fmt.Sprintf("evidence %s (%s) is not later than %s's latest GREEN (%s); a failure older than the passing run proves nothing about it",
			evidence, *rec.TS, id, latestGreen.Format(time.RFC3339)), nil
	}
	detail := fmt.Sprintf("**Reopened-Details:** By: AI On: %s Reason: %s Evidence: %s", e.opts.AsOf, why, evidence)
	body := upsertMeta(setBodyStatus(it.body, StatusReopened), "**Reopened-Details:** ", detail)
	res, err := tx.Exec(`UPDATE items SET status=?, current_location='Issues', disposition='open',
        reopens_count=COALESCE(reopens_count,0)+1, plan_due=COALESCE(?, plan_due), body_md=?, last_modified=?
        WHERE atm_id=? AND current_location=?`, StatusReopened, nullable(planDue), body, stamp(), id, it.loc)
	if err != nil {
		return "", err
	}
	if n, _ := res.RowsAffected(); n != 1 {
		return fmt.Sprintf("reopening %s touched %d rows (is it present in both trackers?)", id, n), nil
	}
	if it.loc != "Issues" {
		if err := moveSeg(tx, it.loc, "Issues", id); err != nil {
			return "", err
		}
	}
	if _, err = tx.Exec(`INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES (?,?,?,?,?,?,?)`,
		id, "Reopened", "AI", e.opts.AsOf, why, evidence, stamp()); err != nil {
		return "", err
	}
	// Watermark: every verdict row the item holds NOW is stale for any later
	// closure (fix round 1, C2) — V-G3 counts only rows added after it.
	vs, err := loadVerdicts(tx)
	if err != nil {
		return "", err
	}
	var keys []string
	for _, vr := range vs[id] {
		keys = append(keys, verdictKey(vr))
	}
	return "", history(tx, id, "Updated", e.opts.AsOf, WatermarkPrefix+strings.Join(keys, ","), "")
}

func (e *gapEnv) noteV10(noted []Finding) {
	for _, f := range noted {
		fmt.Fprintf(e.out, "NOTE: %s — the reopened item needs a new dated plan; V-G10 reports it until one is set (gap reopen --plan-due)\n", f.String())
	}
}

func gapReopen(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("reopen", stderr)
	id := fs.String("id", "", "item id")
	evidence := fs.String("evidence", "", "evidence record of the recorded check now FAILING (outcome 1)")
	why := fs.String("why", "captured-evidence-contradicts", "§11.4.34 reason: "+strings.Join(reopenReasons, " | "))
	planDue := fs.String("plan-due", "", "new dated plan YYYY-MM-DD for the reopened item")
	asOf := fs.String("as-of", "", "ISO date recorded on the reopen and used by the date rules (default: today)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, *asOf, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	if strings.TrimSpace(*evidence) == "" {
		return refuse(stderr, []string{"--evidence is required"})
	}
	tx, brc := e.begin()
	if brc != rcOK {
		return brc
	}
	defer tx.Rollback()
	refusal, err := e.reopenItem(tx, *id, *evidence, *why, *planDue)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if refusal != "" {
		return refuse(stderr, []string{refusal})
	}
	// A reopen is a detection event and is never blocked by the missing plan it
	// creates: blocking it would hide a failing check (FR-019). V-G10 is NOTED.
	rc, noted := e.commitIfClean(tx, *id, "gap reopen", "V-G10")
	if rc != rcOK {
		return rc
	}
	fmt.Fprintf(stdout, "gap reopen: %s reopened (%s, evidence %s)\n", *id, *why, *evidence)
	e.noteV10(noted)
	return rcOK
}

// QueueEntry is one reopen request appended by the daily job.
type QueueEntry struct {
	ItemID   string `json:"item_id"`
	Evidence string `json:"evidence"`
	Why      string `json:"why,omitempty"`
	QueuedAt string `json:"queued_at,omitempty"`
}

// latestClosure returns the created_at of the item's latest closure history row.
func latestClosure(q queryer, id string) (time.Time, bool, error) {
	var s sql.NullString
	err := q.QueryRow(`SELECT MAX(created_at) FROM item_history WHERE atm_id=? AND event_type IN ('Fixed','Implemented','Completed')`, id).Scan(&s)
	if err != nil || !s.Valid {
		return time.Time{}, false, err
	}
	t, err := time.Parse("2006-01-02 15:04:05", s.String)
	if err != nil {
		return time.Time{}, false, fmt.Errorf("closure time %q of %s is unreadable", s.String, id)
	}
	return t, true, nil
}

func gapApplyQueue(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("apply-queue", stderr)
	queue := fs.String("queue", "", "reopen queue (default: <repo>/"+DefaultQueueRel+")")
	asOf := fs.String("as-of", "", "ISO date recorded on each reopen (default: today)")
	planDue := fs.String("plan-due", "", "dated plan to give every reopened item (optional)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, *asOf, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	qpath := *queue
	if qpath == "" {
		qpath = filepath.Join(e.root, DefaultQueueRel)
	}
	b, err := readRegular(qpath, maxAuxBytes)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: reading the reopen queue: %v\n", err)
		return rcUndet
	}
	var entries []QueueEntry
	var problems []string
	sc := bufio.NewScanner(bytes.NewReader(b))
	sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for n := 1; sc.Scan(); n++ {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		dec := json.NewDecoder(strings.NewReader(line))
		dec.DisallowUnknownFields()
		var q QueueEntry
		if err := dec.Decode(&q); err != nil || q.ItemID == "" || q.Evidence == "" {
			problems = append(problems, fmt.Sprintf("queue line %d is not a {item_id, evidence[, why, queued_at]} record", n))
			continue
		}
		if q.Why == "" {
			q.Why = "captured-evidence-contradicts"
		}
		entries = append(entries, q)
	}
	if len(problems) > 0 {
		return refuse(stderr, append(problems, "nothing was applied (the queue is applied all or nothing)"))
	}

	tx, brc := e.begin()
	if brc != rcOK {
		return brc
	}
	defer tx.Rollback()
	var reopened []string
	skipped := 0
	for i, q := range entries {
		it, err := loadItem(tx, q.ItemID)
		if err != nil {
			fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
			return rcUndet
		}
		if it != nil && it.gap && it.disposition != "closed" {
			fmt.Fprintf(stdout, "skip: queue entry %d — %s is already open (%s)\n", i+1, q.ItemID, it.status)
			skipped++
			continue
		}
		if it != nil {
			rec, rerr := e.readRecord(q.Evidence)
			closedAt, ok, cerr := latestClosure(tx, q.ItemID)
			if cerr != nil {
				fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", cerr)
				return rcUndet
			}
			if rerr == nil && futureDated(rec) {
				return refuse(stderr, []string{fmt.Sprintf("queue entry %d: evidence %s is dated %s, in the future", i+1, q.Evidence, *rec.TS),
					"nothing was applied (the queue is applied all or nothing)"})
			}
			if rerr == nil && ok && !rec.time.After(closedAt) {
				fmt.Fprintf(stdout, "skip: queue entry %d — evidence %s (%s) is stale: it predates %s's latest closure (%s)\n",
					i+1, q.Evidence, *rec.TS, q.ItemID, closedAt.Format(time.RFC3339))
				skipped++
				continue
			}
		}
		refusal, err := e.reopenItem(tx, q.ItemID, q.Evidence, q.Why, *planDue)
		if err != nil {
			fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
			return rcUndet
		}
		if refusal != "" {
			return refuse(stderr, []string{fmt.Sprintf("queue entry %d: %s", i+1, refusal), "nothing was applied (the queue is applied all or nothing)"})
		}
		reopened = append(reopened, q.ItemID)
	}
	blocking, noted, undet, err := e.problemsAfter(tx, reopened, "V-G10")
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if len(blocking) > 0 {
		var p []string
		for _, f := range blocking {
			p = append(p, "after reopening, "+f.String())
		}
		return refuse(stderr, append(p, "nothing was applied (the queue is applied all or nothing)"))
	}
	if len(undet) > 0 {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %d condition(s) could not be checked; nothing was applied\n", len(undet))
		return rcUndet
	}
	if err := tx.Commit(); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: commit: %v\n", err)
		return rcUndet
	}
	fmt.Fprintf(stdout, "gap apply-queue: %d reopened, %d skipped, from %s\n", len(reopened), skipped, qpath)
	e.noteV10(noted)
	return rcOK
}

// ── gap link ───────────────────────────────────────────────────────────────

func gapLink(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("link", stderr)
	id := fs.String("id", "", "the recurring item")
	of := fs.String("of", "", "the earlier record it recurs (FR-008)")
	asOf := fs.String("as-of", "", "ISO date the date rules use (default: today)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, *asOf, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	all, err := loadStatusByID(e.db)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	var problems []string
	if _, ok := all[*id]; !ok {
		problems = append(problems, fmt.Sprintf("no item %q", *id))
	}
	if _, ok := all[*of]; !ok {
		problems = append(problems, fmt.Sprintf("--of %q names no item", *of))
	}
	if *id == *of {
		problems = append(problems, "an item cannot recur itself")
	}
	if len(problems) == 0 {
		for cur, seen := *of, map[string]bool{}; cur != "" && !seen[cur]; cur = all[cur].recurrence {
			seen[cur] = true
			if cur == *id {
				problems = append(problems, fmt.Sprintf("linking %s to %s would close a recurrence cycle", *id, *of))
				break
			}
		}
	}
	if len(problems) > 0 {
		return refuse(stderr, problems)
	}
	tx, brc := e.begin()
	if brc != rcOK {
		return brc
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`UPDATE items SET recurrence_of=?, last_modified=? WHERE atm_id=?`, *of, stamp(), *id); err != nil {
		return envFail(stderr, "writing the register", err)
	}
	if err := history(tx, *id, "Updated", e.opts.AsOf, "zero-gap:link recurrence_of="+*of, ""); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if rc, _ := e.commitIfClean(tx, *id, "gap link"); rc != rcOK {
		fmt.Fprintln(stderr, "hint: a recurrence of a CLOSED head reopens the head first (gap reopen --id <head> --evidence <failing record>), §11.4.214")
		return rc
	}
	fmt.Fprintf(stdout, "gap link: %s recurs %s\n", *id, *of)
	return rcOK
}

// ── gap freeze ─────────────────────────────────────────────────────────────

// RegisterDigest is sha256 over the ordered export of every row in cycle: one
// line per row, fields joined by U+001F, rows ordered by (atm_id, location).
func RegisterDigest(q queryer, cycle string) (string, error) {
	rows, err := q.Query(`SELECT atm_id, current_location, type, status, COALESCE(severity,''), title, description,
        COALESCE(kind,''), COALESCE(category,''), COALESCE(disposition,''), COALESCE(classification_reason,''),
        COALESCE(classification_owner,''), COALESCE(classification_recheck,''), COALESCE(plan_due,''),
        COALESCE(research_ref,''), COALESCE(measurable_target,''), COALESCE(recurrence_of,''),
        CAST(COALESCE(reopens_count,0) AS TEXT), COALESCE(sweep_class,''), COALESCE(first_seen_fingerprint,'')
        FROM items WHERE cycle = ? ORDER BY atm_id, current_location`, cycle)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	h := sha256.New()
	cols, _ := rows.Columns()
	for rows.Next() {
		vals := make([]string, len(cols))
		ptrs := make([]any, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return "", err
		}
		h.Write([]byte(strings.Join(vals, "\x1f") + "\n"))
	}
	if err := rows.Err(); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// fileDigest streams the sha256 of a regular file from a handle openRegular
// has checked (fix round 4, F2/F4): a special file is refused, never waited on,
// and a 400 MB file costs a 32 KiB buffer rather than 400 MB of memory.
func fileDigest(path string) (string, error) {
	f, _, err := openRegular(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func gapFreeze(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("freeze", stderr)
	cycle := fs.String("cycle", "", "programme cycle id")
	outFlag := fs.String("out", "", "freeze.json path (default: <repo>/docs/zero-gap/cycles/<cycle>/freeze.json)")
	manifest := fs.String("sweep-manifest", "", "sweep manifest whose sha256 is recorded")
	chainHead := fs.String("chain-head", "", "evidence chain head digest to record (64 hex)")
	entries := fs.Int64("entry-count", -1, "evidence chain entry count to record")
	asOf := fs.String("as-of", "", "ISO date recorded as frozen_at (default: today)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	if !cycleRe.MatchString(*cycle) {
		return refuse(stderr, []string{fmt.Sprintf("--cycle %q is not a plain identifier", *cycle)})
	}
	if *chainHead != "" && !hex64Re.MatchString(*chainHead) {
		return refuse(stderr, []string{"--chain-head is not 64 lowercase hex digits"})
	}
	e, rc := openGap(*repo, *dbFlag, *asOf, false, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	out := *outFlag
	if out == "" {
		out = filepath.Join(e.root, "docs/zero-gap/cycles", *cycle, "freeze.json")
	}
	fingerprint := func() (string, error) {
		d, err := fileDigest(e.dbPath)
		if err != nil {
			return "", err
		}
		if *manifest != "" {
			m, err := fileDigest(*manifest)
			if err != nil {
				return "", err
			}
			d += m
		}
		return d, nil
	}
	before, err := fingerprint()
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: fingerprinting the register: %v\n", err)
		return rcUndet
	}
	members, err := cycleMembers(e.db, *cycle)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if len(members) == 0 {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: cycle %s has no items; an empty population is never frozen as complete\n", *cycle)
		return rcUndet
	}
	// The existing freeze is the TRACKED file when present (git keeps it),
	// else the register's meta record; when both exist they must agree
	// (fix round 1, I3).
	var meta, existing *FreezeRecord
	var raw string
	switch err := e.db.QueryRow(`SELECT value FROM meta WHERE key=?`, FreezeMetaPrefix+*cycle).Scan(&raw); {
	case errors.Is(err, sql.ErrNoRows):
	case err != nil:
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	default:
		meta = &FreezeRecord{}
		if err := json.Unmarshal([]byte(raw), meta); err != nil {
			fmt.Fprintf(stderr, "COULD NOT DETERMINE: the stored freeze of %s is unreadable: %v\n", *cycle, err)
			return rcUndet
		}
	}
	tracked := filepath.Join(e.root, FreezeFileRel(*cycle))
	file, ferr := readFreezeFile(tracked)
	switch {
	case ferr == nil:
		existing = file
	case errors.Is(ferr, os.ErrNotExist):
		existing = meta
	default:
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", ferr)
		return rcUndet
	}
	if file != nil && meta != nil && !sameFreeze(file, meta) {
		fmt.Fprintf(stderr, "REFUSED: the register's freeze record for cycle %s differs from the tracked %s; it was rewritten after the freeze (V-G6)\n", *cycle, FreezeFileRel(*cycle))
		return rcFind
	}
	if existing != nil && strings.Join(existing.Members, ",") != strings.Join(members, ",") {
		fmt.Fprintf(stderr, "REFUSED: cycle %s is frozen with %d item(s) and now holds %d; a frozen cycle's membership never changes (V-G6, FR-026)\n",
			*cycle, len(existing.Members), len(members))
		return rcFind
	}
	rec := existing
	if rec == nil {
		reg, err := RegisterDigest(e.db, *cycle)
		if err != nil {
			fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
			return rcUndet
		}
		rec = &FreezeRecord{Cycle: *cycle, FrozenAt: e.opts.AsOf, ItemCount: len(members), Members: members,
			MembersSHA256: membersDigest(members), RegisterSHA256: reg}
		if *chainHead != "" {
			rec.ChainHead = chainHead
		}
		if *entries >= 0 {
			rec.EntryCount = entries
		}
		if *manifest != "" {
			d, err := fileDigest(*manifest)
			if err != nil {
				fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
				return rcUndet
			}
			rec.SweepManifestSHA256 = &d
		}
	}
	if freezeMidHook != nil {
		freezeMidHook()
	}
	after, err := fingerprint()
	if err != nil || after != before {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: UNSTABLE — the register or sweep manifest changed while the freeze was computed; nothing was written\n")
		return rcUndet
	}
	compact, _ := json.Marshal(rec)
	pretty, _ := json.MarshalIndent(rec, "", "  ")
	pretty = append(pretty, '\n')
	if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	tmp := out + ".tmp"
	if err := os.WriteFile(tmp, pretty, 0o644); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	if meta == nil {
		if _, err := e.db.Exec(`INSERT INTO meta (key, value, last_modified) VALUES (?,?,?)`, FreezeMetaPrefix+*cycle, string(compact), stamp()); err != nil {
			os.Remove(tmp)
			fmt.Fprintf(stderr, "COULD NOT DETERMINE: recording the freeze: %v\n", err)
			return rcUndet
		}
	}
	if err := os.Rename(tmp, out); err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	verb := "frozen"
	if existing != nil {
		verb = "already frozen (unchanged membership); record re-written"
	}
	fmt.Fprintf(stdout, "gap freeze: cycle %s %s — %d item(s), members %s, register %s → %s\n",
		*cycle, verb, rec.ItemCount, rec.MembersSHA256[:12], rec.RegisterSHA256[:12], out)
	return rcOK
}

// ── gap summary ────────────────────────────────────────────────────────────

// loadRecall reads the recall column of docs/zero-gap/sweep-classes.tsv. A
// missing file yields an empty map (every class then reads UNKNOWN).
func loadRecall(root string) (map[string]string, error) {
	b, err := readRegular(filepath.Join(root, "docs/zero-gap/sweep-classes.tsv"), maxAuxBytes)
	if errors.Is(err, fs.ErrNotExist) {
		return map[string]string{}, nil
	}
	if err != nil {
		return nil, err
	}
	out := map[string]string{}
	idCol, recCol := -1, -1
	for _, line := range strings.Split(string(b), "\n") {
		if strings.TrimSpace(line) == "" || strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.Split(line, "\t")
		if idCol < 0 {
			for i, h := range f {
				switch strings.TrimSpace(h) {
				case "class_id":
					idCol = i
				case "recall":
					recCol = i
				}
			}
			if idCol < 0 || recCol < 0 {
				return nil, errors.New("sweep-classes.tsv has no class_id/recall header")
			}
			continue
		}
		if len(f) > idCol && len(f) > recCol {
			out[strings.TrimSpace(f[idCol])] = strings.TrimSpace(f[recCol])
		}
	}
	return out, nil
}

func gapSummary(args []string, stdout, stderr io.Writer) int {
	fs, repo, dbFlag := newFlags("summary", stderr)
	asJSON := fs.Bool("json", false, "print canonical JSON (sorted keys, byte-stable for an unchanged register)")
	if err := fs.Parse(args); err != nil {
		return rcUndet
	}
	e, rc := openGap(*repo, *dbFlag, "", true, stdout, stderr)
	if rc != rcOK {
		return rc
	}
	defer e.close()
	rows, err := loadGapRows(e.db)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	recall, err := loadRecall(e.root)
	if err != nil {
		fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
		return rcUndet
	}
	// One row per atm_id: the closed row when the id lives in both trackers.
	byID := map[string]gapRow{}
	for _, r := range rows {
		if prev, ok := byID[r.id]; ok && prev.disposition.String == "closed" {
			continue
		}
		byID[r.id] = r
	}
	bucket := func() map[string]int { return map[string]int{"closed": 0, "classified": 0, "open": 0, "total": 0} }
	counts := map[string]any{}
	total, unknown := 0, 0
	disp := map[string]int{"closed": 0, "classified": 0, "open": 0}
	byCat, byKind, bySev, perClass := map[string]map[string]int{}, map[string]map[string]int{}, map[string]map[string]int{}, map[string]map[string]int{}
	reasons := map[string]int{}
	add := func(m map[string]map[string]int, key, d string) {
		if key == "" {
			key = "(none)"
		}
		if m[key] == nil {
			m[key] = bucket()
		}
		m[key]["total"]++
		if _, ok := m[key][d]; ok {
			m[key][d]++
		}
	}
	for _, r := range byID {
		total++
		d := r.disposition.String
		if _, ok := disp[d]; ok {
			disp[d]++
		} else {
			unknown++
		}
		add(byCat, r.category.String, d)
		add(byKind, r.kind.String, d)
		add(bySev, r.severity, d)
		add(perClass, r.sweep.String, d)
		if d == "classified" {
			reasons[r.reason.String]++
		}
	}
	counts["total"], counts["closed"], counts["classified"], counts["open"] = total, disp["closed"], disp["classified"], disp["open"]
	counts["unknown_disposition"], counts["could_not_inspect"] = unknown, nil
	classes := map[string]any{}
	for k, m := range perClass {
		c := map[string]any{}
		for kk, vv := range m {
			c[kk] = vv
		}
		c["recall"] = "UNKNOWN"
		if v, ok := recall[k]; ok && v != "" {
			c["recall"] = v
		}
		classes[k] = c
	}
	doc := map[string]any{
		"schema":               "zero-gap-summary/1",
		"counts":               counts,
		"by_category":          byCat,
		"by_kind":              byKind,
		"by_severity":          bySev,
		"classified_by_reason": reasons,
		"per_class":            classes,
		"notes": []string{
			"every count is derived from the register rows (FR-024); nothing is typed",
			"could_not_inspect is null: uninspectable parts are listed by the sweep (FR-005) and are not register rows, so no count is invented here",
			HonestyNotice,
		},
	}
	if *asJSON {
		b, err := json.MarshalIndent(doc, "", "  ")
		if err != nil {
			fmt.Fprintf(stderr, "COULD NOT DETERMINE: %v\n", err)
			return rcUndet
		}
		stdout.Write(append(b, '\n'))
		return rcOK
	}
	fmt.Fprintf(stdout, "gap summary: total %d · closed %d · classified %d · open %d · unknown disposition %d · could-not-inspect: not stored in the register (sweep output, FR-005)\n",
		total, disp["closed"], disp["classified"], disp["open"], unknown)
	keys := make([]string, 0, len(classes))
	for k := range classes {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		c := classes[k].(map[string]any)
		fmt.Fprintf(stdout, "  class %-24s total %d · closed %d · classified %d · open %d · recall %v\n",
			k, c["total"], c["closed"], c["classified"], c["open"], c["recall"])
	}
	fmt.Fprintln(stdout, HonestyNotice)
	return rcOK
}
