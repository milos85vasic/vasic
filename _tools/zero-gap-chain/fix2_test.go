package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

// Review T015b I2: verify/preflight read the store WITHOUT the lock, so the
// state an append passes through (sidecar n+1, chain n) read as a violation.
// The in-progress append is REAL: the exclusive store lock is held (the same
// lock Append takes) while the sidecar is one line ahead.
func holdMidAppend(t *testing.T, dir string) (restore func()) {
	t.Helper()
	release, err := lockStore(dir, true, 5*time.Second)
	if err != nil {
		t.Fatalf("taking the append lock: %v", err)
	}
	sc := filepath.Join(dir, sidecarFile)
	before, _ := os.ReadFile(sc)
	ls := readLines(t, sc)
	writeLines(t, sc, append(ls, ls[0])) // what an append looks like between its two writes
	return func() {
		os.WriteFile(sc, before, 0o644) // the "append" completes (rolled back to consistent)
		release()
	}
}

func TestFix2_VerifyWaitsForAnInProgressAppend(t *testing.T) {
	dir := buildStore(t, 2)
	restore := holdMidAppend(t, dir)
	done := make(chan int, 1)
	go func() {
		var o, e bytes.Buffer
		done <- run([]string{"verify", "--store", dir, "--schema", schemaPath}, &o, &e)
	}()
	select {
	case rc := <-done:
		restore()
		t.Fatalf("verify returned rc %d while the append lock was held (a half-written store read as a verdict)", rc)
	case <-time.After(700 * time.Millisecond):
	}
	restore()
	select {
	case rc := <-done:
		if rc != 0 {
			t.Fatalf("after the append completed, verify rc %d, want 0", rc)
		}
	case <-time.After(10 * time.Second):
		t.Fatal("verify did not finish within 10 s of the lock being released")
	}
}

func TestFix2_PreflightWaitsForAnInProgressAppend(t *testing.T) {
	dir := buildStore(t, 2)
	restore := holdMidAppend(t, dir)
	done := make(chan int, 1)
	go func() {
		var o, e bytes.Buffer
		done <- run([]string{"preflight", "--store", dir, "--schema", schemaPath}, &o, &e)
	}()
	select {
	case rc := <-done:
		restore()
		t.Fatalf("preflight returned rc %d at once instead of waiting for the append", rc)
	case <-time.After(700 * time.Millisecond):
	}
	restore()
	select {
	case rc := <-done:
		if rc != 0 {
			t.Fatalf("after the append completed, preflight rc %d, want 0", rc)
		}
	case <-time.After(10 * time.Second):
		t.Fatal("preflight did not finish within 10 s of the lock being released")
	}
}

// A lock that is never released must not hang a reader forever.
func TestFix2_LockWaitIsBounded(t *testing.T) {
	dir := buildStore(t, 1)
	release, err := lockStore(dir, true, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	start := time.Now()
	if _, err := lockStore(dir, false, 300*time.Millisecond); err == nil {
		t.Fatal("a shared lock was granted while the exclusive lock was held")
	}
	if d := time.Since(start); d > 3*time.Second {
		t.Fatalf("the bounded wait took %s", d)
	}
}

// withRemote gives the history repo a bare "remote" and pushes to it.
func withRemote(t *testing.T, repo string) func() {
	t.Helper()
	bare := filepath.Join(t.TempDir(), "remote.git")
	if out, err := exec.Command("git", "init", "-q", "--bare", bare).CombinedOutput(); err != nil {
		t.Fatalf("bare: %v %s", err, out)
	}
	gitT(t, repo, "remote", "add", "origin", bare)
	gitT(t, repo, "push", "-q", "-u", "origin", "HEAD")
	return func() { gitT(t, repo, "push", "-q") }
}

// Review T015b I3: an AMENDED commit rewrites history no commit-to-parent edge
// can see. Only a copy held elsewhere (the remote-tracking branch) witnesses it.
func TestFix2_HistoryAmendAfterPushIsCaught(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	for _, f := range []string{chainFile, sidecarFile} {
		p := filepath.Join(filepath.Dir(ch), f)
		ls := readLines(t, p)
		writeLines(t, p, ls[:2])
	}
	os.WriteFile(an, []byte(`{"head_digest":"`+digestAt(t, ch, 2)+`","entry_count":2,"anchor_strength":"policy"}`+"\n"), 0o644)
	gitT(t, repo, "commit", "-q", "--amend", "--allow-empty", "-am", "anchor 3 (amended)")
	if r := VerifyAnchorHistory(ch, an); r.Verdict == HistHolds {
		t.Fatalf("an amended, lowered anchor read HOLDS: %v", r.Lines)
	}
}

func TestFix2_HistoryWitnessedByRemoteHolds(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	if r := VerifyAnchorHistory(ch, an); r.Verdict != HistHolds {
		t.Fatalf("pushed forward-only history: %s %v", r.Verdict, r.Lines)
	}
}

func TestFix2_HistoryWithoutUpstreamIsUnwitnessed(t *testing.T) {
	_, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	commit(3, digestAt(t, ch, 3))
	if r := VerifyAnchorHistory(ch, an); r.Verdict != HistUnwitnessed {
		t.Fatalf("history with no upstream must be UNWITNESSED, got %s %v", r.Verdict, r.Lines)
	}
}

func TestFix2_HistoryRemoteNotAncestorIsUnwitnessed(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	// Rewrite the pushed tip WITHOUT changing the anchor (a message-only
	// amend): the remote tip is no longer an ancestor of HEAD.
	gitT(t, repo, "commit", "-q", "--amend", "-m", "rewritten message")
	if r := VerifyAnchorHistory(ch, an); r.Verdict != HistUnwitnessed {
		t.Fatalf("remote tip not an ancestor of HEAD must be UNWITNESSED, got %s %v", r.Verdict, r.Lines)
	}
}
