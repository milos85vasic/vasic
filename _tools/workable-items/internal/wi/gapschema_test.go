package wi

// T006 — additive schema migration `gap migrate`.

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// wantGapColumns is the column set data-model.md and tasks.md T006 name, spelled
// out here independently of GapColumns so a silent edit to one is caught by the other.
var wantGapColumns = map[string]string{
	"kind": "TEXT", "category": "TEXT", "disposition": "TEXT",
	"classification_reason": "TEXT", "classification_owner": "TEXT", "classification_recheck": "TEXT",
	"plan_due": "TEXT", "research_ref": "TEXT", "measurable_target": "TEXT",
	"recurrence_of": "TEXT", "reopens_count": "INTEGER", "cycle": "TEXT",
	"sweep_class": "TEXT", "first_seen_fingerprint": "TEXT",
}

func fileSHA(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	s := sha256.Sum256(b)
	return hex.EncodeToString(s[:])
}

func schemaDump(t *testing.T, db *sql.DB) string {
	t.Helper()
	rows, err := db.Query(`SELECT type||' '||name||' '||COALESCE(sql,'') FROM sqlite_master ORDER BY type, name`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	var b strings.Builder
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			t.Fatal(err)
		}
		b.WriteString(s + "\n")
	}
	return b.String()
}

func rawOpen(t *testing.T, path string) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func TestMigrateAddsExactlyTheFourteenGapColumns(t *testing.T) {
	path := buildRegister(t, false, "legacy-register.sql")
	db := rawOpen(t, path)
	res, err := Migrate(db, false)
	if err != nil {
		t.Fatal(err)
	}
	rows, err := db.Query(`SELECT name, type, COALESCE(dflt_value,'') FROM pragma_table_info('items')`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	got := map[string]string{}
	dflt := map[string]string{}
	for rows.Next() {
		var n, ty, d string
		if err := rows.Scan(&n, &ty, &d); err != nil {
			t.Fatal(err)
		}
		got[n], dflt[n] = ty, d
	}
	for name, ty := range wantGapColumns {
		if got[name] != ty {
			t.Errorf("column %s: want type %s, got %q", name, ty, got[name])
		}
	}
	if len(got) != 23+14 {
		t.Errorf("items has %d columns after migration, want 37 (23 canonical + 14 gap)", len(got))
	}
	if dflt["reopens_count"] != "0" {
		t.Errorf("reopens_count default: want 0, got %q", dflt["reopens_count"])
	}
	if len(GapColumns) != 14 {
		t.Errorf("GapColumns has %d entries, want 14", len(GapColumns))
	}
	if len(res.Statements) != 15 {
		t.Errorf("first migration ran %d statement(s), want 15 (14 ALTER + 1 CREATE TABLE)", len(res.Statements))
	}
}

func TestMigrateCreatesItemVerdictsWithItsChecks(t *testing.T) {
	db := rawOpen(t, buildRegister(t, true))
	rows, err := db.Query(`SELECT name FROM pragma_table_info('item_verdicts') ORDER BY cid`)
	if err != nil {
		t.Fatal(err)
	}
	var cols []string
	for rows.Next() {
		var n string
		rows.Scan(&n)
		cols = append(cols, n)
	}
	rows.Close()
	want := "item_id,role,actor,actor_kind,on_date,outcome,evidence_path,evidence_sha256" // round 3 (I3): + evidence_sha256
	if strings.Join(cols, ",") != want {
		t.Fatalf("item_verdicts columns: want %s, got %s", want, strings.Join(cols, ","))
	}
	ok := `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','verifier','a','agent','2026-09-25',0,'e')`
	if _, err := db.Exec(ok); err != nil {
		t.Fatalf("a well-formed verdict row was refused: %v", err)
	}
	for name, bad := range map[string]string{
		"role outside {verifier,reviewer}":  `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','author','a','agent','2026-09-25',0,'e')`,
		"actor_kind outside {agent,script}": `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','verifier','a','human','2026-09-25',0,'e')`,
		"outcome outside {0,1,2}":           `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','verifier','a','agent','2026-09-25',3,'e')`,
	} {
		if _, err := db.Exec(bad); err == nil {
			t.Errorf("CHECK did not refuse: %s", name)
		}
	}
}

func TestMigrateTwiceChangesNothingOnTheSecondRun(t *testing.T) {
	path := buildRegister(t, false, "legacy-register.sql")
	db := rawOpen(t, path)
	if _, err := Migrate(db, false); err != nil {
		t.Fatal(err)
	}
	dump1 := schemaDump(t, db)
	db.Close()
	sha1 := fileSHA(t, path)

	db2 := rawOpen(t, path)
	res, err := Migrate(db2, false)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Statements) != 0 {
		t.Fatalf("second migration ran %d statement(s), want 0: %v", len(res.Statements), res.Statements)
	}
	if dump2 := schemaDump(t, db2); dump2 != dump1 {
		t.Fatalf("schema changed on the second run:\n--- first\n%s--- second\n%s", dump1, dump2)
	}
	db2.Close()
	if sha2 := fileSHA(t, path); sha2 != sha1 {
		t.Fatalf("database file bytes changed on the second (no-op) run: %s -> %s", sha1, sha2)
	}
}

func TestMigratePreservesEveryExistingValue(t *testing.T) {
	path := buildRegister(t, false, "legacy-register.sql")
	db := rawOpen(t, path)
	before := dumpRows(t, db, `SELECT atm_id,type,status,title,description,current_location,body_md,created_at FROM items ORDER BY atm_id`)
	if _, err := Migrate(db, false); err != nil {
		t.Fatal(err)
	}
	after := dumpRows(t, db, `SELECT atm_id,type,status,title,description,current_location,body_md,created_at FROM items ORDER BY atm_id`)
	if before != after {
		t.Fatalf("existing values changed:\n%s\n---\n%s", before, after)
	}
	var n int
	db.QueryRow(`SELECT count(*) FROM items WHERE reopens_count = 0 AND kind IS NULL AND disposition IS NULL AND cycle IS NULL`).Scan(&n)
	if n != 2 {
		t.Fatalf("want both legacy rows to read reopens_count=0 and NULL gap columns, got %d", n)
	}
}

func dumpRows(t *testing.T, db *sql.DB, q string) string {
	t.Helper()
	rows, err := db.Query(q)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	cols, _ := rows.Columns()
	var b strings.Builder
	for rows.Next() {
		vals := make([]sql.NullString, len(cols))
		ptrs := make([]any, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			t.Fatal(err)
		}
		for _, v := range vals {
			b.WriteString(v.String + "\x1f")
		}
		b.WriteString("\n")
	}
	return b.String()
}

func TestMigratedDBStillPassesTheCanonicalValidator(t *testing.T) {
	path := buildRegister(t, false, "legacy-register.sql")
	rc, out, skipped := canonicalValidate(t, path)
	if skipped {
		t.Skip("SKIPPED (not passed): " + out)
	}
	if rc != 0 {
		t.Fatalf("control: the UNMIGRATED legacy fixture must validate under the canonical tool first, got rc %d:\n%s", rc, out)
	}
	db := rawOpen(t, path)
	if _, err := Migrate(db, false); err != nil {
		t.Fatal(err)
	}
	db.Close()
	rc, out, _ = canonicalValidate(t, path)
	if rc != 0 {
		t.Fatalf("canonical validator refused the MIGRATED database: rc %d\n%s", rc, out)
	}
	if !strings.Contains(out, "2 items") {
		t.Fatalf("canonical validator did not read the 2 legacy items: %s", out)
	}
}

func TestMigrateRefusesAnIncompatibleItemVerdictsTable(t *testing.T) {
	path := buildRegister(t, false)
	db := rawOpen(t, path)
	if _, err := db.Exec(`CREATE TABLE item_verdicts (item_id TEXT, verdict TEXT)`); err != nil {
		t.Fatal(err)
	}
	if _, err := Migrate(db, false); err == nil {
		t.Fatal("migration accepted a pre-existing item_verdicts table of a different shape")
	}
}

// ── CLI: `gap migrate` ────────────────────────────────────────────────────

func runGapCLI(t *testing.T, args ...string) (int, string, string) {
	t.Helper()
	var out, errb bytes.Buffer
	rc := RunGap(args, &out, &errb)
	return rc, out.String(), errb.String()
}

func TestGapMigrateCLIRunsAndIsIdempotent(t *testing.T) {
	path := buildRegister(t, false, "legacy-register.sql")
	rc, out, errs := runGapCLI(t, "migrate", "--db", path)
	if rc != 0 {
		t.Fatalf("first migrate: rc %d\n%s%s", rc, out, errs)
	}
	if !strings.Contains(out, "15 statement(s) applied") {
		t.Fatalf("first migrate did not report 15 statements: %s", out)
	}
	rc, out, errs = runGapCLI(t, "migrate", "--db", path)
	if rc != 0 || !strings.Contains(out, "0 statement(s) applied") {
		t.Fatalf("second migrate: want rc 0 and 0 statements, got rc %d\n%s%s", rc, out, errs)
	}
}

func TestGapMigrateDryRunPrintsTheDDLAndWritesNothing(t *testing.T) {
	path := buildRegister(t, false, "legacy-register.sql")
	before := fileSHA(t, path)
	rc, out, errs := runGapCLI(t, "migrate", "--dry-run", "--db", path)
	if rc != 0 {
		t.Fatalf("dry-run: rc %d\n%s%s", rc, out, errs)
	}
	for _, want := range []string{
		"ALTER TABLE items ADD COLUMN kind TEXT;",
		"ALTER TABLE items ADD COLUMN reopens_count INTEGER DEFAULT 0;",
		"ALTER TABLE items ADD COLUMN first_seen_fingerprint TEXT;",
		"CREATE TABLE IF NOT EXISTS item_verdicts",
		"CHECK (role IN ('verifier','reviewer'))",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("dry-run output lacks %q:\n%s", want, out)
		}
	}
	if after := fileSHA(t, path); after != before {
		t.Fatalf("--dry-run modified the database: %s -> %s", before, after)
	}
}

func TestGapMigrateCannotOpenIsTwo(t *testing.T) {
	dir := t.TempDir()
	missing := filepath.Join(dir, "absent.db")
	if rc, _, _ := runGapCLI(t, "migrate", "--db", missing); rc != 2 {
		t.Fatalf("missing DB: want rc 2, got %d", rc)
	}
	if _, err := os.Stat(missing); !os.IsNotExist(err) {
		t.Fatalf("migrate CREATED %s while reporting it could not open it", missing)
	}
	garbage := filepath.Join(dir, "garbage.db")
	os.WriteFile(garbage, []byte("this is not an sqlite database, it is plain text padding padding"), 0o644)
	if rc, _, _ := runGapCLI(t, "migrate", "--db", garbage); rc != 2 {
		t.Fatalf("garbage DB: want rc 2, got %d", rc)
	}
	empty := filepath.Join(dir, "noitems.db")
	e := rawOpen(t, empty)
	e.Exec(`CREATE TABLE unrelated (x INTEGER)`)
	e.Close()
	if rc, _, _ := runGapCLI(t, "migrate", "--db", empty); rc != 2 {
		t.Fatalf("DB without an items table: want rc 2, got %d", rc)
	}
	if rc, _, _ := runGapCLI(t, "migrate", "--dry-run", "--db", missing); rc != 2 {
		t.Fatalf("dry-run on a missing DB: want rc 2, got %d", rc)
	}
}
