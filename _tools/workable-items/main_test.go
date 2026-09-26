package main

// CLI-level tests for the `validate --as-of` extension (feature 010, T007) and
// the `gap` dispatch (T008). Registers are built from the checked-in fixture
// corpus into temporary directories; docs/workable_items.db is never opened.

import (
	"database/sql"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
	"time"

	"digital.vasic/vasic/workableitems/internal/wi"
)

const fxRel = "_tests/fixtures/zero-gap/registers"

func realRoot(t *testing.T) string {
	t.Helper()
	cwd, _ := os.Getwd()
	root, err := wi.FindRepoRoot(cwd)
	if err != nil {
		t.Fatal(err)
	}
	return root
}

func copyTree(t *testing.T, src, dst string) {
	t.Helper()
	err := filepath.Walk(src, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, p)
		target := filepath.Join(dst, rel)
		if info.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return os.WriteFile(target, b, 0o644)
	})
	if err != nil {
		t.Fatal(err)
	}
}

// tempRepo is a throwaway repository root: the good fixture roster, plus the
// fixture evidence at the same repository-relative path the registers cite.
func tempRepo(t *testing.T) string {
	t.Helper()
	root := realRoot(t)
	dst := t.TempDir()
	fx := filepath.Join(root, fxRel)
	for src, rel := range map[string]string{
		"roster-good/gitmodules.fixture":       ".gitmodules",
		"roster-good/helix-deps.yaml.fixture":  "helix-deps.yaml",
		"roster-good/sub-projects.tsv.fixture": wi.RosterPath,
	} {
		b, err := os.ReadFile(filepath.Join(fx, src))
		if err != nil {
			t.Fatal(err)
		}
		p := filepath.Join(dst, rel)
		os.MkdirAll(filepath.Dir(p), 0o755)
		os.WriteFile(p, b, 0o644)
	}
	copyTree(t, filepath.Join(fx, "evidence"), filepath.Join(dst, fxRel, "evidence"))
	return dst
}

func buildDB(t *testing.T, migrate bool, files ...string) string {
	t.Helper()
	fx := filepath.Join(realRoot(t), fxRel)
	path := filepath.Join(t.TempDir(), "register.db")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	exec := func(f string) {
		b, err := os.ReadFile(filepath.Join(fx, f))
		if err != nil {
			t.Fatal(err)
		}
		if _, err := db.Exec(string(b)); err != nil {
			t.Fatalf("%s: %v", f, err)
		}
	}
	exec("canonical-schema.sql")
	if migrate {
		if _, err := wi.Migrate(db, false); err != nil {
			t.Fatal(err)
		}
	}
	for _, f := range files {
		exec(f)
	}
	return path
}

// capture runs the CLI with os.Stdout redirected.
func capture(t *testing.T, args ...string) (int, string) {
	t.Helper()
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	old := os.Stdout
	os.Stdout = w
	done := make(chan string)
	go func() { b, _ := io.ReadAll(r); done <- string(b) }()
	rc := run(args)
	w.Close()
	os.Stdout = old
	return rc, <-done
}

func TestValidateAsOfIsExplicitAndPrinted(t *testing.T) {
	repo := tempRepo(t)
	db := buildDB(t, true, "golden-good.sql")
	rc, out := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25")
	if rc != 0 {
		t.Fatalf("golden-good at 2026-09-25: want rc 0, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "as-of: 2026-09-25\n") {
		t.Fatalf("the as-of date is not printed:\n%s", out)
	}
	rc, out = capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2027-01-01")
	if rc != 1 || !strings.Contains(out, "V-G10") || !strings.Contains(out, "V-G2") {
		t.Fatalf("golden-good at 2027-01-01: want rc 1 with V-G2 and V-G10, got %d\n%s", rc, out)
	}
	rc, out = capture(t, "validate", "--repo", repo, "--db", db)
	today := time.Now().UTC().Format("2006-01-02") // fix round 1: the default is the UTC date
	if !strings.Contains(out, "as-of: "+today+" (default: today, UTC)") {
		t.Fatalf("default as-of is not printed as today (%s):\n%s", today, out)
	}
	_ = rc
	if rc, _ := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "tomorrow"); rc != 2 {
		t.Fatalf("an unparseable --as-of must be rc 2, got %d", rc)
	}
}

func TestValidateOnAnUnmigratedRegisterNotesItAndKeepsItsVerdict(t *testing.T) {
	repo := tempRepo(t)
	db := buildDB(t, false, "legacy-register.sql")
	rc, out := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25")
	if rc != 0 {
		t.Fatalf("unmigrated legacy register: want rc 0 (base rules only), got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "NOTE") || !strings.Contains(out, "gap migrate") {
		t.Fatalf("the unevaluated V-G rules are not stated:\n%s", out)
	}
}

func TestValidateReportsAGapFindingThroughTheCLI(t *testing.T) {
	repo := tempRepo(t)
	db := buildDB(t, true, "golden-good.sql", "golden-bad/V-G12.sql")
	rc, out := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25")
	if rc != 1 || !strings.Contains(out, "FINDING  V-G12") {
		t.Fatalf("want rc 1 with a V-G12 FINDING line, got %d\n%s", rc, out)
	}
}

// Fix round 1 minor: --as-of defaults to the UTC date (as `gap` does), and the
// date used is printed. A local zone on the other side of the date line makes
// the local and UTC dates differ, so a local default is observable.
func TestValidateDefaultAsOfIsTheUTCDate(t *testing.T) {
	old := time.Local
	defer func() { time.Local = old }()
	offset := 13 * 3600
	if time.Now().UTC().Hour() < 12 {
		offset = -13 * 3600
	}
	time.Local = time.FixedZone("far", offset)
	if time.Now().Format("2006-01-02") == time.Now().UTC().Format("2006-01-02") {
		t.Skip("SKIPPED (not passed): could not construct a zone whose date differs from UTC")
	}
	repo := tempRepo(t)
	db := buildDB(t, true, "golden-good.sql")
	_, out := capture(t, "validate", "--repo", repo, "--db", db)
	want := "as-of: " + time.Now().UTC().Format("2006-01-02") + " (default: today, UTC)"
	if !strings.Contains(out, want) {
		t.Fatalf("want %q in the output:\n%s", want, out)
	}
}

// I4: the invocation scripts/verify-workable-items.sh G5 uses
// (`validate --repo <root> --db <db>`) accepts --as-of, and its verdict on the
// UNMIGRATED register is unchanged; on a MIGRATED register with a roster gap the
// verdict becomes 1 (V-G8) — the flip that must wait for T047.
func TestG5StyleInvocationAcceptsAsOfAndDocumentsTheFlip(t *testing.T) {
	repo := tempRepo(t)
	unmigrated := buildDB(t, false, "legacy-register.sql")
	rc, out := capture(t, "validate", "--repo", repo, "--db", unmigrated, "--as-of", "2026-09-25")
	if rc != 0 || !strings.Contains(out, "as-of: 2026-09-25\n") {
		t.Fatalf("G5-style validate on an unmigrated register: rc %d\n%s", rc, out)
	}
	gapRepo := tempRepo(t)
	b, _ := os.ReadFile(filepath.Join(realRoot(t), fxRel, "golden-bad/V-G8-roster/gitmodules.fixture"))
	os.WriteFile(filepath.Join(gapRepo, ".gitmodules"), b, 0o644)
	migrated := buildDB(t, true, "legacy-register.sql")
	rc, out = capture(t, "validate", "--repo", gapRepo, "--db", migrated, "--as-of", "2026-09-25")
	if rc != 1 || !strings.Contains(out, "FINDING  V-G8") {
		t.Fatalf("migrated register with a roster gap: want rc 1 with V-G8, got %d\n%s", rc, out)
	}
}

// I1: `validate` prints byte-identical output on 20 runs over a register whose
// evidence record has several malformed fields.
func TestI1ValidateOutputIsIdenticalOnTwentyRuns(t *testing.T) {
	repo := tempRepo(t)
	db := buildDB(t, true, "golden-good.sql", "golden-bad/V-G3-V-G9-multibad.sql")
	_, first := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25")
	for i := 0; i < 19; i++ {
		if _, again := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25"); again != first {
			t.Fatalf("run %d differs:\n--- first\n%s--- again\n%s", i+2, first, again)
		}
	}
}

// ── fix round 4, F6: the honesty notice on a clean validate ───────────────

const f6Notice = "closed = structurally consistent + self-recorded digests; NOT independently proven until T068 chain binding"

// captureBoth runs the CLI with stdout AND stderr redirected.
func captureBoth(t *testing.T, args ...string) (int, string, string) {
	t.Helper()
	ro, wo, _ := os.Pipe()
	re, we, _ := os.Pipe()
	oldO, oldE := os.Stdout, os.Stderr
	os.Stdout, os.Stderr = wo, we
	doneO, doneE := make(chan string), make(chan string)
	go func() { b, _ := io.ReadAll(ro); doneO <- string(b) }()
	go func() { b, _ := io.ReadAll(re); doneE <- string(b) }()
	rc := run(args)
	wo.Close()
	we.Close()
	os.Stdout, os.Stderr = oldO, oldE
	return rc, <-doneO, <-doneE
}

func TestF6CleanValidatePrintsTheNoticeWithoutChangingTheVerdict(t *testing.T) {
	repo := tempRepo(t)
	db := buildDB(t, true, "golden-good.sql")
	rc, first := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25")
	if rc != 0 || !strings.Contains(first, "\n"+f6Notice+"\n") {
		t.Fatalf("clean validate: want rc 0 with the notice line, got %d\n%s", rc, first)
	}
	lines := strings.Split(strings.TrimRight(first, "\n"), "\n")
	if last := lines[len(lines)-1]; !strings.HasPrefix(last, "OK — ") {
		t.Fatalf("the verdict must stay the LAST line (scripts read tail -1), got %q", last)
	}
	for i := 0; i < 19; i++ {
		if _, again := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25"); again != first {
			t.Fatalf("run %d differs:\n--- first\n%s--- again\n%s", i+2, first, again)
		}
	}
	bad := buildDB(t, true, "golden-good.sql", "golden-bad/V-G12.sql")
	if rc, out := capture(t, "validate", "--repo", repo, "--db", bad, "--as-of", "2026-09-25"); rc != 1 || strings.Contains(out, f6Notice) {
		t.Fatalf("a FAILING validate is not 'clean' and carries no notice: rc %d\n%s", rc, out)
	}
	if rc, _, errs := captureBoth(t, "--help"); rc != 0 || !strings.Contains(errs, f6Notice) {
		t.Fatalf("--help: want rc 0 with the notice in the usage text, got %d\n%s", rc, errs)
	}
}

// F1 at the CLI: a PARTIALLY migrated register is 2, never 'OK'.
func TestF1ValidateOnAPartiallyMigratedRegisterIsTwoNamingTheDDL(t *testing.T) {
	repo := tempRepo(t)
	db := buildDB(t, true, "golden-good.sql")
	raw, err := sql.Open("sqlite", db)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := raw.Exec(`ALTER TABLE item_verdicts DROP COLUMN evidence_sha256;
DELETE FROM item_verdicts WHERE item_id='VSC-004'; UPDATE items SET research_ref=NULL WHERE atm_id='VSC-004'`); err != nil {
		t.Fatal(err)
	}
	raw.Close()
	rc, out := capture(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25")
	if rc != 2 || !strings.Contains(out, "ALTER TABLE item_verdicts ADD COLUMN evidence_sha256 TEXT;") || strings.Contains(out, "OK — ") {
		t.Fatalf("partially migrated register: want rc 2 naming the missing DDL and no OK, got %d\n%s", rc, out)
	}
}

// ── T037: `report --by-module` is dispatched through the existing `report` ──

func TestReportByModuleThroughTheCLI(t *testing.T) {
	repo := tempRepo(t)
	good := buildDB(t, true, "golden-good.sql")
	want, err := os.ReadFile(filepath.Join(realRoot(t), fxRel, "module-page-golden-good.md"))
	if err != nil {
		t.Fatal(err)
	}
	rc, out := capture(t, "report", "--by-module", "--repo", repo, "--db", good, "--as-of", "2026-09-25")
	if rc != 0 || out != string(want) {
		t.Fatalf("golden-good via the CLI: want rc 0 and the golden page, got rc %d:\n%s", rc, out)
	}
	bad := buildDB(t, true, "golden-good.sql", "golden-bad/module-page.sql")
	if rc, out := capture(t, "report", "--by-module", "--repo", repo, "--db", bad, "--as-of", "2026-09-25"); rc != 1 ||
		!strings.Contains(out, "FINDING id/prefix-not-in-roster ZZZ-001") || !strings.Contains(out, "FINDING V-G3 VSC-004") ||
		!strings.Contains(out, "FINDING V-G1 VSC-005 — kind is missing") {
		t.Fatalf("golden-bad via the CLI: want rc 1 naming each problem, got rc %d:\n%s", rc, out)
	}
	legacy := buildDB(t, false, "legacy-register.sql")
	if rc, out := capture(t, "report", "--by-module", "--repo", repo, "--db", legacy, "--as-of", "2026-09-25"); rc != 2 || out != "" {
		t.Fatalf("unmigrated register via the CLI: want rc 2 and no page, got rc %d:\n%s", rc, out)
	}
	if rc, _ := capture(t, "report", "--repo", repo, "--db", legacy, "--as-of", "2026-09-25"); rc != 2 {
		t.Fatalf("--as-of without --by-module must be rc 2, got %d", rc)
	}
	// The plain tallies are unchanged by the new flag.
	if rc, out := capture(t, "report", "--repo", repo, "--db", legacy); rc != 0 || !strings.Contains(out, "BY STATUS") {
		t.Fatalf("plain report: want rc 0 with its tallies, got rc %d:\n%s", rc, out)
	}
}

func prefixed(s, p string) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if strings.HasPrefix(l, p) {
			out = append(out, l)
		}
	}
	sort.Strings(out)
	return out
}

// T037 fix round C1: `report --by-module` names exactly the findings `validate`
// names — on the golden-bad register and on one missing a provenance row.
func TestReportByModuleFindingsEqualValidateThroughTheCLI(t *testing.T) {
	cases := map[string]string{
		"golden-bad":         "",
		"provenance-missing": `DELETE FROM item_provenance WHERE atm_id = 'VSC-001'`,
	}
	for name, stmt := range cases {
		t.Run(name, func(t *testing.T) {
			repo := tempRepo(t)
			files := []string{"golden-good.sql"}
			if name == "golden-bad" {
				files = append(files, "golden-bad/module-page.sql")
			}
			db := buildDB(t, true, files...)
			if stmt != "" {
				h, err := sql.Open("sqlite", db)
				if err != nil {
					t.Fatal(err)
				}
				if _, err := h.Exec(stmt); err != nil {
					t.Fatal(err)
				}
				h.Close()
			}
			rrc, _, rerr := captureBoth(t, "report", "--by-module", "--repo", repo, "--db", db, "--as-of", "2026-09-25")
			vrc, vout, _ := captureBoth(t, "validate", "--repo", repo, "--db", db, "--as-of", "2026-09-25")
			if rrc != 1 || vrc != 1 {
				t.Fatalf("want rc 1 from both, got report %d validate %d", rrc, vrc)
			}
			got, want := prefixed(rerr, "FINDING  "), prefixed(vout, "FINDING  ")
			if len(want) == 0 || strings.Join(got, "\n") != strings.Join(want, "\n") {
				t.Fatalf("finding sets differ\n--- report ---\n%s\n--- validate ---\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
			}
		})
	}
}
