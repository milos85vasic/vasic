package wi

// Fixture corpus loader for feature 010 (task T010). Every zero-gap test builds
// its register from the checked-in SQL under _tests/fixtures/zero-gap/registers/
// into a database inside t.TempDir(). The tracked docs/workable_items.db is never
// opened by any test in this package.

import (
	"database/sql"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// testClock drives nowFn for every test in this package (fix round 2): the
// reopen cut, the future-record refusal and every created_at stamp depend on
// "now", so the tests fix it instead of reading the wall clock. The default is
// 2026-09-27T00:00:00Z — after every fixture record, so none is in the future.
var testClock atomic.Value

func TestMain(m *testing.M) {
	testClock.Store(mustTime("2026-09-27T00:00:00Z"))
	nowFn = func() time.Time { return testClock.Load().(time.Time) }
	os.Exit(m.Run())
}

func mustTime(s string) time.Time {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		panic(err)
	}
	return t
}

// setClock moves the package clock for the rest of one test.
func setClock(t *testing.T, s string) {
	t.Helper()
	old := testClock.Load()
	testClock.Store(mustTime(s))
	t.Cleanup(func() { testClock.Store(old) })
}

// touch sets a file's modification time (reviewer evidence is time-bound).
func touch(t *testing.T, repo, rel, s string) {
	t.Helper()
	ts := mustTime(s)
	if err := os.Chtimes(filepath.Join(repo, rel), ts, ts); err != nil {
		t.Fatal(err)
	}
}

// fixtureAsOf is the --as-of date the golden fixtures are clean at.
const fixtureAsOf = "2026-09-25"

// clockAsOf is the date of the package test clock: commands that close or
// re-close with records dated up to that day validate at it (round 3, I2:
// evidence dated after the end of the --as-of day is a finding).
const clockAsOf = "2026-09-27"

// fixtureRel is the fixture directory, relative to the repository root.
const fixtureRel = "_tests/fixtures/zero-gap/registers"

func repoRoot(t *testing.T) string {
	t.Helper()
	cwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	root, err := FindRepoRoot(cwd)
	if err != nil {
		t.Fatalf("locating the repository root from %s: %v", cwd, err)
	}
	return root
}

func fixturePath(t *testing.T, rel string) string {
	t.Helper()
	return filepath.Join(repoRoot(t), fixtureRel, rel)
}

func execSQLFile(t *testing.T, db *sql.DB, path string) {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("reading fixture %s: %v", path, err)
	}
	if _, err := db.Exec(string(b)); err != nil {
		t.Fatalf("applying fixture %s: %v", filepath.Base(path), err)
	}
}

// buildRegister creates <tempdir>/register.db from canonical-schema.sql, runs the
// additive migration when migrate is true, then applies each named fixture file
// (paths relative to the fixture directory) in order. It returns the DB path.
func buildRegister(t *testing.T, migrate bool, files ...string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "register.db")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	execSQLFile(t, db, fixturePath(t, "canonical-schema.sql"))
	if migrate {
		if _, err := Migrate(db, false); err != nil {
			t.Fatalf("gap migrate on the fixture: %v", err)
		}
	}
	for _, f := range files {
		execSQLFile(t, db, fixturePath(t, f))
	}
	return path
}

func openFixture(t *testing.T, path string) *sql.DB {
	t.Helper()
	db, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

// fixtureRoster is the roster the golden registers are written against.
func fixtureRoster() *Roster {
	return &Roster{Members: []SubProject{
		{Prefix: "VSC", Path: ".", Class: ClassParent, Ratified: "operator", Declared: true},
		{Prefix: "WSP", Path: "workshop", Class: ClassOwned, Ratified: "operator", Declared: true},
	}}
}

// rosterRepo materialises a fixture roster directory (gitmodules.fixture,
// helix-deps.yaml.fixture, sub-projects.tsv.fixture) as a throwaway repository
// root. The fixture files are not named .gitmodules on purpose: a nested
// .gitmodules inside the umbrella tree could be picked up by fleet scanners.
func rosterRepo(t *testing.T, fixtureDir string) string {
	t.Helper()
	dst := t.TempDir()
	copyFile := func(src, rel string) {
		b, err := os.ReadFile(fixturePath(t, filepath.Join(fixtureDir, src)))
		if err != nil {
			t.Fatal(err)
		}
		p := filepath.Join(dst, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, b, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	copyFile("gitmodules.fixture", ".gitmodules")
	copyFile("helix-deps.yaml.fixture", "helix-deps.yaml")
	copyFile("sub-projects.tsv.fixture", RosterPath)
	return dst
}

// canonicalValidate runs the constitution's own validator on dbPath with the
// repository root as working directory (it resolves evidence paths against its
// working directory). It returns skipped=true when the binary is absent; callers
// must t.Skip with that message — never treat an absent verifier as a pass.
func canonicalValidate(t *testing.T, dbPath string) (rc int, out string, skipped bool) {
	t.Helper()
	return canonicalValidateIn(t, fixtureRoot(t, false), dbPath)
}

// FreezeFixtureRel is where a test root carries the tracked twin of the
// frozen-cycle fixture's meta record.
const freezeFixtureRel = "docs/zero-gap/cycles/2026-C1/freeze.json"

// fixtureRoot is a SELF-CONTAINED throwaway repository root: the fixture
// evidence at the repository-relative path the registers cite and, when
// withFreeze, the tracked freeze.json of cycle 2026-C1. Nothing in it depends
// on any live file of this repository (fix round 1 minor: fixtures must not
// lean on specs/010.../tasks.md).
func fixtureRoot(t *testing.T, withFreeze bool) string {
	t.Helper()
	dst := t.TempDir()
	copyFixtureEvidence(t, dst)
	if withFreeze {
		installFreezeFixture(t, dst)
	}
	return dst
}

func copyFixtureEvidence(t *testing.T, dst string) {
	t.Helper()
	src := fixturePath(t, "evidence")
	entries, err := os.ReadDir(src)
	if err != nil {
		t.Fatal(err)
	}
	to := filepath.Join(dst, fixtureRel, "evidence")
	if err := os.MkdirAll(to, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, e := range entries {
		b, err := os.ReadFile(filepath.Join(src, e.Name()))
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(to, e.Name()), b, 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func installFreezeFixture(t *testing.T, dst string) {
	t.Helper()
	b, err := os.ReadFile(fixturePath(t, "frozen-cycle.freeze.json"))
	if err != nil {
		t.Fatal(err)
	}
	p := filepath.Join(dst, freezeFixtureRel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, b, 0o644); err != nil {
		t.Fatal(err)
	}
}

// canonicalValidateIn runs the canonical validator with dir as its working
// directory (a throwaway repository whose evidence the register cites).
func canonicalValidateIn(t *testing.T, dir, dbPath string) (rc int, out string, skipped bool) {
	t.Helper()
	root := repoRoot(t)
	bin := filepath.Join(root, "submodules/constitution/scripts/workable-items/bin/workable-items-linux")
	if _, err := os.Stat(bin); err != nil {
		return 0, "canonical validator binary absent at " + bin + ": " + err.Error(), true
	}
	cmd := exec.Command(bin, "validate", "--db", dbPath)
	cmd.Dir = dir
	b, err := cmd.CombinedOutput()
	var ee *exec.ExitError
	switch {
	case err == nil:
		return 0, string(b), false
	case errors.As(err, &ee):
		return ee.ExitCode(), string(b), false
	default:
		t.Fatalf("running the canonical validator: %v", err)
	}
	return 2, string(b), false
}

// runIn runs a command with dir as its working directory.
func runIn(dir, bin string, args ...string) (string, error) {
	cmd := exec.Command(bin, args...)
	cmd.Dir = dir
	b, err := cmd.CombinedOutput()
	return string(b), err
}

func gapRules(rep *Report) []string {
	seen := map[string]bool{}
	var out []string
	for _, f := range rep.Findings {
		if strings.HasPrefix(f.Rule, "V-G") && !seen[f.Rule] {
			seen[f.Rule] = true
			out = append(out, f.Rule)
		}
	}
	return out
}

// validateGapFixture validates in a self-contained fixture root that carries
// the tracked freeze.json of cycle 2026-C1 exactly when the register itself
// records that freeze (as `gap freeze` leaves a real repository).
func validateGapFixture(t *testing.T, dbPath string, asOf string, r *Roster) *Report {
	t.Helper()
	return validateGapIn(t, fixtureRoot(t, hasFreezeMeta(t, dbPath)), dbPath, asOf, r)
}

func hasFreezeMeta(t *testing.T, dbPath string) bool {
	t.Helper()
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	var n int
	db.QueryRow(`SELECT count(*) FROM meta WHERE key='zero_gap_freeze:2026-C1'`).Scan(&n)
	return n > 0
}

func validateGapIn(t *testing.T, root, dbPath string, asOf string, r *Roster) *Report {
	t.Helper()
	db := openFixture(t, dbPath)
	rep, err := ValidateGap(db, GapOptions{AsOf: asOf, Root: root, Roster: r})
	if err != nil {
		t.Fatalf("ValidateGap: %v", err)
	}
	return rep
}

// ── T010: the corpus itself ────────────────────────────────────────────────

func TestFixtureCanonicalSchemaCarriesNoGapColumn(t *testing.T) {
	db := openFixture(t, buildRegister(t, false))
	cols, err := itemColumns(db)
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range GapColumns {
		if cols[c.Name] {
			t.Fatalf("the pre-migration fixture already carries gap column %q", c.Name)
		}
	}
}

func TestFixtureGoldenGoodIsCleanUnderEveryValidator(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql")
	db := openFixture(t, path)

	base, err := Validate(db, fixtureRoster())
	if err != nil {
		t.Fatal(err)
	}
	if base.ExitCode() != 0 {
		t.Fatalf("umbrella base validator: want rc 0, got %d: %v %v", base.ExitCode(), base.Findings, base.Undetermined)
	}
	gap := validateGapFixture(t, path, fixtureAsOf, fixtureRoster())
	if gap.ExitCode() != 0 {
		t.Fatalf("gap validator: want rc 0, got %d: findings=%v undet=%v", gap.ExitCode(), gap.Findings, gap.Undetermined)
	}
	if gap.Items != 6 {
		t.Fatalf("gap validator saw %d gap item(s), want 6 — a validator that reads nothing is not clean", gap.Items)
	}
	rc, out, skipped := canonicalValidate(t, path)
	if skipped {
		t.Skip("SKIPPED (not passed): " + out)
	}
	if rc != 0 {
		t.Fatalf("canonical validator: want rc 0, got %d:\n%s", rc, out)
	}
}

func TestFixtureFrozenCycleIsClean(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql")
	gap := validateGapFixture(t, path, fixtureAsOf, fixtureRoster())
	if gap.ExitCode() != 0 {
		t.Fatalf("frozen-cycle fixture: want rc 0, got %d: %v %v", gap.ExitCode(), gap.Findings, gap.Undetermined)
	}
}
