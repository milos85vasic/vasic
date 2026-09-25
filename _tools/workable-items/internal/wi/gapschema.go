package wi

// Feature 010 (zero-gap verified closure), task T006: the ADDITIVE schema
// migration behind `gap migrate`.
//
// §11.4.93 fixes the canonical tables, so every change here is additive: new
// NULLable columns on `items` (plus reopens_count with a 0 default) and one new
// add-on table, `item_verdicts`, in the same pattern as `item_provenance`. No
// canonical column, CHECK or table is altered or dropped. The canonical binary
// (submodules/constitution/scripts/workable-items) keeps reading and validating
// the database; that is asserted by TestMigratedDBStillPassesTheCanonicalValidator.

import (
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strings"
)

// GapColumn is one additive column on the canonical items table.
type GapColumn struct{ Name, Type string }

// GapColumns is the additive column set, in the order data-model.md lists it.
// Types are the declared SQLite types; reopens_count carries its default in the
// type clause because ALTER TABLE ADD COLUMN takes the default there.
var GapColumns = []GapColumn{
	{"kind", "TEXT"},
	{"category", "TEXT"},
	{"disposition", "TEXT"},
	{"classification_reason", "TEXT"},
	{"classification_owner", "TEXT"},
	{"classification_recheck", "TEXT"},
	{"plan_due", "TEXT"},
	{"research_ref", "TEXT"},
	{"measurable_target", "TEXT"},
	{"recurrence_of", "TEXT"},
	{"reopens_count", "INTEGER DEFAULT 0"},
	{"cycle", "TEXT"},
	{"sweep_class", "TEXT"},
	{"first_seen_fingerprint", "TEXT"},
}

// itemVerdictsColumns is the exact column list of item_verdicts (data-model.md
// "IndependentVerdict"). An existing table of any other shape is refused rather
// than silently reused.
var itemVerdictsColumns = []string{"item_id", "role", "actor", "actor_kind", "on_date", "outcome", "evidence_path", "evidence_sha256"}

// itemVerdictsColumnsR2 is the 7-column shape `gap migrate` created before fix
// round 3; it is extended additively with evidence_sha256.
var itemVerdictsColumnsR2 = itemVerdictsColumns[:7]

// VerdictDigestDDL adds the round-3 digest column (FR-016 for the register:
// the sha256 of the verdict's evidence at the time it was recorded).
const VerdictDigestDDL = "ALTER TABLE item_verdicts ADD COLUMN evidence_sha256 TEXT;"

// ItemVerdictsDDL creates the add-on verdict table. The CHECK sets are the ones
// data-model.md defines; NOT NULL on every column is this implementation's
// addition (a verdict row with no actor or no outcome would be unattributable).
const ItemVerdictsDDL = `CREATE TABLE IF NOT EXISTS item_verdicts (
    item_id       TEXT    NOT NULL,
    role          TEXT    NOT NULL CHECK (role IN ('verifier','reviewer')),
    actor         TEXT    NOT NULL,
    actor_kind    TEXT    NOT NULL CHECK (actor_kind IN ('agent','script')),
    on_date       TEXT    NOT NULL,
    outcome       INTEGER NOT NULL CHECK (outcome IN (0,1,2)),
    evidence_path TEXT    NOT NULL,
    evidence_sha256 TEXT
);`

// MigrateResult reports what a migration did (or, in dry-run, would do).
type MigrateResult struct{ Statements []string }

// ErrNotMigrated is returned by gap operations on a register that `gap migrate`
// has not extended yet.
var ErrNotMigrated = errors.New("the register carries no zero-gap schema — run `gap migrate` first")

// OpenExisting opens an EXISTING register file. Unlike sql.Open it never
// creates a missing file (reporting "cannot open" while leaving an empty
// database behind would be a side effect of a failure). readOnly opens the file
// with mode=ro so a dry run cannot write.
func OpenExisting(path string, readOnly bool) (*sql.DB, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, fmt.Errorf("cannot open %s: %w", path, err)
	}
	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("cannot open %s: not a regular file", path)
	}
	// The driver strips a plain path's "?query"; a path that itself holds
	// '?' or '#' cannot be addressed safely this way.
	if strings.ContainsAny(path, "?#") {
		return nil, fmt.Errorf("cannot open %s: the path contains '?' or '#'", path)
	}
	// busy_timeout: a second writer waits for the lock instead of failing at
	// once with "database is locked"; _txlock=immediate: every write
	// transaction takes the write lock at BEGIN, so a baseline read inside it
	// cannot go stale before the write (fix round 1, I2).
	dsn := path + "?_pragma=busy_timeout(10000)&_txlock=immediate"
	if readOnly {
		dsn = "file:" + path + "?mode=ro&_pragma=busy_timeout(10000)"
	}
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM sqlite_master WHERE type='table' AND name='items'`).Scan(&n); err != nil {
		db.Close()
		return nil, fmt.Errorf("reading %s: %w", path, err)
	}
	if n == 0 {
		db.Close()
		return nil, fmt.Errorf("%s carries no `items` table", path)
	}
	if !readOnly {
		var ext int
		if err := db.QueryRow(`SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ('sub_projects','item_provenance')`).Scan(&ext); err != nil {
			db.Close()
			return nil, fmt.Errorf("reading %s: %w", path, err)
		}
		if ext < 2 {
			if _, err := db.Exec(extensionDDL); err != nil {
				db.Close()
				return nil, fmt.Errorf("creating umbrella extension tables in %s: %w", path, err)
			}
		}
	}
	return db, nil
}

func itemColumns(db queryer) (map[string]bool, error) {
	return tableColumns(db, "items")
}

type queryer interface {
	Query(query string, args ...any) (*sql.Rows, error)
	QueryRow(query string, args ...any) *sql.Row
}

func tableColumns(db queryer, table string) (map[string]bool, error) {
	rows, err := db.Query(`SELECT name FROM pragma_table_info(?)`, table)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	cols := map[string]bool{}
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			return nil, err
		}
		cols[n] = true
	}
	return cols, rows.Err()
}

func orderedColumns(db queryer, table string) ([]string, error) {
	rows, err := db.Query(`SELECT name FROM pragma_table_info(?) ORDER BY cid`, table)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

// plan computes the statements still needed. It reads only.
func plan(db queryer) ([]string, error) {
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM sqlite_master WHERE type='table' AND name='items'`).Scan(&n); err != nil {
		return nil, err
	}
	if n == 0 {
		return nil, errors.New("no `items` table — this is not a workable-items register")
	}
	cols, err := itemColumns(db)
	if err != nil {
		return nil, err
	}
	var stmts []string
	for _, c := range GapColumns {
		if !cols[c.Name] {
			stmts = append(stmts, fmt.Sprintf("ALTER TABLE items ADD COLUMN %s %s;", c.Name, c.Type))
		}
	}
	vcols, err := orderedColumns(db, "item_verdicts")
	if err != nil {
		return nil, err
	}
	switch {
	case len(vcols) == 0:
		stmts = append(stmts, ItemVerdictsDDL)
	case strings.Join(vcols, ",") == strings.Join(itemVerdictsColumnsR2, ","):
		stmts = append(stmts, VerdictDigestDDL)
	case strings.Join(vcols, ",") != strings.Join(itemVerdictsColumns, ","):
		return nil, fmt.Errorf("an item_verdicts table already exists with columns (%s), not (%s) — refusing to reuse or alter it",
			strings.Join(vcols, ","), strings.Join(itemVerdictsColumns, ","))
	}
	return stmts, nil
}

// Migrate applies the additive zero-gap schema. It is idempotent: a second run
// computes an empty plan and executes nothing, so the file is not written. With
// dryRun it returns the plan and executes nothing.
func Migrate(db *sql.DB, dryRun bool) (*MigrateResult, error) {
	stmts, err := plan(db)
	if err != nil {
		return nil, err
	}
	res := &MigrateResult{Statements: stmts}
	if dryRun || len(stmts) == 0 {
		return res, nil
	}
	tx, err := db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	for _, s := range stmts {
		if _, err := tx.Exec(s); err != nil {
			return nil, fmt.Errorf("%s: %w", firstLine(s), err)
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	left, err := plan(db)
	if err != nil {
		return nil, err
	}
	if len(left) != 0 {
		return nil, fmt.Errorf("migration left %d statement(s) unapplied", len(left))
	}
	return res, nil
}

// PartialSchemaError reports a register that carries SOME of the zero-gap
// schema (or zero-gap history rows) but not all of it (fix round 4, F1). It is
// deliberately not ErrNotMigrated: an unmigrated register is stated as such and
// scored by the base rules alone, while a partially migrated one — a round-2
// register, a DROP COLUMN, a dropped table — must be exit 2 naming the missing
// DDL, never a silent "no zero-gap schema" that switches every V-G rule off.
type PartialSchemaError struct {
	Present []string // what IS there
	Missing []string // the DDL still to run
}

func (e *PartialSchemaError) Error() string {
	heads := make([]string, len(e.Missing))
	for i, s := range e.Missing {
		heads[i] = firstLine(s)
	}
	return fmt.Sprintf("the register is PARTIALLY migrated: %s, but %d zero-gap DDL statement(s) are missing — run `gap migrate`; missing: %s",
		strings.Join(e.Present, ", "), len(e.Missing), strings.Join(heads, " "))
}

// schemaPresence describes which parts of the zero-gap schema — or its history
// rows — the register carries.
func schemaPresence(db queryer) ([]string, error) {
	cols, err := itemColumns(db)
	if err != nil {
		return nil, err
	}
	n := 0
	for _, c := range GapColumns {
		if cols[c.Name] {
			n++
		}
	}
	var present []string
	if n > 0 {
		present = append(present, fmt.Sprintf("%d of %d zero-gap columns on items", n, len(GapColumns)))
	}
	vcols, err := orderedColumns(db, "item_verdicts")
	if err != nil {
		return nil, err
	}
	if len(vcols) > 0 {
		present = append(present, fmt.Sprintf("an item_verdicts table (%d columns)", len(vcols)))
	}
	var rows int
	if err := db.QueryRow(`SELECT count(*) FROM item_history WHERE reason LIKE 'zero-gap:%'`).Scan(&rows); err != nil {
		return nil, err
	}
	if rows > 0 {
		present = append(present, fmt.Sprintf("%d zero-gap history row(s)", rows))
	}
	return present, nil
}

// requireMigrated returns nil when every gap column and the full item_verdicts
// table exist; ErrNotMigrated when NONE of the zero-gap schema and no zero-gap
// history row is present; and a *PartialSchemaError for anything in between.
func requireMigrated(db queryer) error {
	stmts, err := plan(db)
	if err != nil {
		return err
	}
	if len(stmts) == 0 {
		return nil
	}
	present, err := schemaPresence(db)
	if err != nil {
		return err
	}
	if len(present) == 0 {
		return ErrNotMigrated
	}
	return &PartialSchemaError{Present: present, Missing: stmts}
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}
