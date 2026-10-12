package wi

// VSC-363: the six input-validation cases the T008 fix rounds deferred. Each test was written
// before its fix and observed failing first (the report of the fixing session pastes the RED run).

import (
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
)

// Case 1: a file that resolves but cannot be hashed must not be recorded with a NULL digest.
func TestVSC363EmptyEvidenceDigestIsRefused(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	rev := writeText(t, repo, "ev/VSC-001-review.md", "review of VSC-001: accepted\n")
	if err := os.Chmod(filepath.Join(repo, rev), 0); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(filepath.Join(repo, rev), 0o600) })
	before := fileSHA(t, db)
	rc, out := gapRun(t, repo, db, "verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D",
		"--actor-kind", "agent", "--outcome", "0", "--evidence", rev, "--on", fixtureAsOf)
	if rc == 0 {
		t.Fatalf("a reviewer verdict whose evidence could not be hashed was recorded (rc 0):\n%s", out)
	}
	if fileSHA(t, db) != before {
		t.Fatal("the refused verdict modified the register")
	}
}

// Case 2: a history row stamped after the end of --as-of is a V-G9 finding.
func TestVSC363FutureDatedHistoryRowIsAFinding(t *testing.T) {
	k := prepareClose(t)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("close: rc %d\n%s", rc, out)
	}
	gapCleanIn(t, k.repo, k.db)
	applySQL(t, k.db, `UPDATE item_history SET created_at='2030-01-01 00:00:00' WHERE atm_id='VSC-001' AND event_type='Updated' AND reason LIKE 'zero-gap:red-evidence%'`)
	r, _ := LoadRoster(k.repo)
	rep := validateGapIn(t, k.repo, k.db, clockAsOf, r)
	if !hasDetail(rep, "V-G9", "VSC-001", "after the end of --as-of") {
		t.Fatalf("a history row dated 2030 went undetected: rc %d %v", rep.ExitCode(), rep.Findings)
	}
}

// Case 3: a reviewer verdict dated before the GREEN run it reviews is a V-G3 finding.
func TestVSC363ReviewerOnDateBeforeGreenIsAFinding(t *testing.T) {
	k := prepareClose(t)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("close: rc %d\n%s", rc, out)
	}
	gapCleanIn(t, k.repo, k.db)
	applySQL(t, k.db, `UPDATE item_verdicts SET on_date='2026-09-24' WHERE item_id='VSC-001' AND role='reviewer'`)
	r, _ := LoadRoster(k.repo)
	rep := validateGapIn(t, k.repo, k.db, clockAsOf, r)
	if !hasDetail(rep, "V-G3", "VSC-001", "before the day of the GREEN run") {
		t.Fatalf("a reviewer dated before the GREEN went undetected: rc %d %v", rep.ExitCode(), rep.Findings)
	}
}

// Case 4: duplicate JSON keys (case-insensitive) are refused, the last value never silently wins.
func TestVSC363DuplicateJSONKeysAreRefused(t *testing.T) {
	repo := gapRepo(t)
	rel := writeRecord(t, repo, "ev/dup.json", map[string]any{"item_id": "VSC-001", "outcome": 0})
	b, err := os.ReadFile(filepath.Join(repo, rel))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ParseEvidenceRecord(b); err != nil {
		t.Fatalf("control: a well-formed record was refused: %v", err)
	}
	for name, mutate := range map[string]func(string) string{
		"exact duplicate":     func(s string) string { return strings.Replace(s, "{", `{"outcome":1,`, 1) },
		"case-only duplicate": func(s string) string { return strings.Replace(s, "{", `{"Outcome":1,`, 1) },
	} {
		if _, err := ParseEvidenceRecord([]byte(mutate(string(b)))); err == nil || !strings.Contains(err.Error(), "duplicate JSON key") {
			t.Errorf("%s: want a duplicate-key refusal, got %v", name, err)
		}
	}
}

// Case 5: the loser of a parallel close is a refusal (rc 1), not an environment fault (rc 2).
func TestVSC363ParallelCloseLoserIsRefusedNotFaulted(t *testing.T) {
	k := prepareClose(t)
	old := closePreBeginHook
	t.Cleanup(func() { closePreBeginHook = old })
	var once int32
	var inner int
	closePreBeginHook = func() {
		if atomic.CompareAndSwapInt32(&once, 0, 1) {
			inner, _ = gapRun(t, k.repo, k.db, k.args()...) // the winner commits first
		}
	}
	rc, out := gapRun(t, k.repo, k.db, k.args()...)
	if inner != 0 {
		t.Fatalf("the winner's close failed: rc %d", inner)
	}
	if rc != 1 || !strings.Contains(out, "closed concurrently") {
		t.Fatalf("the loser: want rc 1 naming a concurrent close, got rc %d\n%s", rc, out)
	}
}

// Case 6: a parent directory swapped for a symlink between the symlink resolution and the open
// must be refused (O_NOFOLLOW alone protects only the final path component).
func TestVSC363ParentSwapAfterResolutionIsRefused(t *testing.T) {
	dir := t.TempDir()
	real1 := filepath.Join(dir, "a")
	other := filepath.Join(dir, "elsewhere")
	for _, d := range []string{real1, other} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(real1, "f.txt"), []byte("inside\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(other, "f.txt"), []byte("outside\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	old := openRegularHook
	t.Cleanup(func() { openRegularHook = old })
	openRegularHook = func(resolved string) {
		// the window: replace the parent directory with a symlink to another tree
		os.Rename(real1, real1+".moved")
		os.Symlink(other, real1)
	}
	f, _, err := openRegular(filepath.Join(real1, "f.txt"))
	if err == nil {
		b := make([]byte, 16)
		n, _ := f.Read(b)
		f.Close()
		t.Fatalf("a path whose parent was swapped for a symlink was opened and read %q", string(b[:n]))
	}
}
