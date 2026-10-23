package wi

// Feature 010, task T062 (FR-020): `gap freeze` is gated by the record scanner
// scripts/zero-gap-scan-records.sh. The scanner is three-valued; a freeze is
// written only on rc 0. The scanner here is a stub shell script (a unit-test
// stand-in for the script's exit code); the real script has its own paired
// proof (`bash scripts/zero-gap-scan-records.sh --prove-failure`).

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const scanRel = "scripts/zero-gap-scan-records.sh"

// installScanStub writes an executable stub scanner that records its argv in
// <repo>/scan.args and exits with rc after printing body.
func installScanStub(t *testing.T, repo string, rc int, body string) {
	t.Helper()
	p := filepath.Join(repo, scanRel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	script := "#!/usr/bin/env bash\nprintf '%s\\n' \"$@\" > \"" + filepath.Join(repo, "scan.args") + "\"\n" +
		"printf '%s\\n' '" + body + "'\nexit " + string(rune('0'+rc)) + "\n"
	if err := os.WriteFile(p, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
}

func freezeRepo(t *testing.T) (string, string) {
	t.Helper()
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	applySQL(t, db, `UPDATE items SET cycle='2026-C9'`)
	return repo, db
}

func freezeJSON(repo string) string {
	return filepath.Join(repo, "docs/zero-gap/cycles/2026-C9/freeze.json")
}

func TestScanFindingRefusesTheFreezeAndWritesNothing(t *testing.T) {
	repo, db := freezeRepo(t)
	installScanStub(t, repo, 1, "FINDING guessing docs/zero-gap/x.md:3 hedge=probably")
	rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf)
	if rc != 1 {
		t.Fatalf("scan found a violation: want freeze rc 1, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "FINDING guessing") {
		t.Fatalf("the scanner's finding was not shown to the operator:\n%s", out)
	}
	if _, err := os.Stat(freezeJSON(repo)); !os.IsNotExist(err) {
		t.Fatal("a freeze with scan findings wrote freeze.json")
	}
	if got := field(t, db, "VSC-001", "cycle"); got != "2026-C9" {
		t.Fatalf("register touched: cycle=%q", got)
	}
}

func TestScanUndeterminedIsTwoAndWritesNothing(t *testing.T) {
	repo, db := freezeRepo(t)
	installScanStub(t, repo, 2, "COULD-NOT-INSPECT private: no private source")
	rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf)
	if rc != 2 {
		t.Fatalf("scan could not determine: want rc 2, got %d\n%s", rc, out)
	}
	if _, err := os.Stat(freezeJSON(repo)); !os.IsNotExist(err) {
		t.Fatal("an undetermined scan still wrote freeze.json")
	}
}

func TestScanAbsentIsTwoNotASilentSkip(t *testing.T) {
	repo, db := freezeRepo(t)
	if err := os.Remove(filepath.Join(repo, scanRel)); err != nil {
		t.Fatal(err)
	}
	rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf)
	if rc != 2 {
		t.Fatalf("no scanner present: want rc 2, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "zero-gap-scan-records.sh") {
		t.Fatalf("the missing gate is not named:\n%s", out)
	}
	if _, err := os.Stat(freezeJSON(repo)); !os.IsNotExist(err) {
		t.Fatal("a freeze with no scanner wrote freeze.json")
	}
}

func TestScanCleanFreezesAndReceivesTheRepoRoot(t *testing.T) {
	repo, db := freezeRepo(t)
	installScanStub(t, repo, 0, "VERDICT HOLDS (rc 0)")
	rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf)
	if rc != 0 {
		t.Fatalf("clean scan: want freeze rc 0, got %d\n%s", rc, out)
	}
	if _, err := os.Stat(freezeJSON(repo)); err != nil {
		t.Fatalf("freeze.json not written: %v", err)
	}
	b, err := os.ReadFile(filepath.Join(repo, "scan.args"))
	if err != nil {
		t.Fatalf("the scanner was never invoked: %v", err)
	}
	if !strings.Contains(string(b), "--root") || !strings.Contains(string(b), repo) {
		t.Fatalf("scanner not given --root <repo>: %q", b)
	}
}

func TestSkipScanNeedsAReasonAndIsPrinted(t *testing.T) {
	repo, db := freezeRepo(t)
	if rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf, "--skip-scan-records", ""); rc == 0 {
		t.Fatalf("an empty skip reason must not skip the gate: rc %d\n%s", rc, out)
	}
	rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf, "--skip-scan-records", "fixture without a scanner")
	if rc != 0 {
		t.Fatalf("explicit skip with a reason: rc %d\n%s", rc, out)
	}
	if !strings.Contains(out, "SCAN-RECORDS SKIPPED") || !strings.Contains(out, "fixture without a scanner") {
		t.Fatalf("a skipped gate must be loud and carry its reason:\n%s", out)
	}
}
