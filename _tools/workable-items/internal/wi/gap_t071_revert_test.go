package wi

// Feature 010, task T071 (FR-019, SC-009): the revert test. In a disposable
// repository a closed item's recorded check is made to fail again (its fix is
// reverted); the REAL scripts/zero-gap-daily.sh must flag it, queue a reopen
// request in the shape `gap apply-queue` reads, never touch the register, and
// the REAL `gap apply-queue` must then reopen the item. A control run with the
// fix in place queues nothing. The sealing adapter is a test double that runs
// the command and writes a sidecar record (the fixture failing record for a
// failing check); the real adapter has its own proof.

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func runShell(t *testing.T, dir string, env []string, name string, args ...string) (int, string) {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), env...)
	var buf bytes.Buffer
	cmd.Stdout, cmd.Stderr = &buf, &buf
	err := cmd.Run()
	rc := 0
	if err != nil {
		ee, ok := err.(*exec.ExitError)
		if !ok {
			t.Fatalf("%s: %v", name, err)
		}
		rc = ee.ExitCode()
	}
	return rc, buf.String()
}

func gitIn(t *testing.T, dir string, args ...string) {
	t.Helper()
	full := append([]string{"-c", "user.email=t@t", "-c", "user.name=t"}, args...)
	if rc, out := runShell(t, dir, nil, "git", full...); rc != 0 {
		t.Fatalf("git %v: rc %d\n%s", args, rc, out)
	}
}

func TestT071RevertedFixIsFlaggedQueuedAndReopened(t *testing.T) {
	for _, tool := range []string{"git", "rsync", "flock", "python3", "bash"} {
		if _, err := exec.LookPath(tool); err != nil {
			t.Fatalf("T071 needs %s on PATH: %v", tool, err)
		}
	}
	live := repoRoot(t)
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	// the job script and its library, copied verbatim from the repository under test
	for _, f := range []string{"zero-gap-daily.sh", "zero-gap-lib.sh"} {
		b, err := os.ReadFile(filepath.Join(live, "scripts", f))
		if err != nil {
			t.Fatal(err)
		}
		writeText(t, repo, "scripts/"+f, string(b))
	}
	writeText(t, repo, ".gitignore", ".remember/\n")
	writeText(t, repo, "fix.marker", "fixed\n")
	writeText(t, repo, "docs/zero-gap/checks/VSC-004.check", "check_id=revert-probe\npre_fix_ref=HEAD\ncmd=test -f fix.marker\n")
	fail, err := os.ReadFile(fixturePath(t, "evidence/VSC-004-recheck-fail.json"))
	if err != nil {
		t.Fatal(err)
	}
	var compact bytes.Buffer
	if err := json.Compact(&compact, fail); err != nil {
		t.Fatal(err)
	}
	failPath := writeText(t, repo, "adapter-fail-record.json", compact.String()+"\n")
	adapter := writeText(t, repo, "adapter.sh", `#!/usr/bin/env bash
store=""; while [ $# -gt 0 ]; do case "$1" in --store) store=$2; shift 2 ;; --) shift; break ;; *) shift ;; esac; done
mkdir -p "$store"; "$@"; rc=$?
if [ "$rc" = 1 ]; then cat "`+failPath+`" >>"$store/sidecar.jsonl"; fi
exit "$rc"
`)
	steps := writeText(t, repo, "steps.tsv", "noop\ttrue\n")
	gitIn(t, repo, "init", "-q")
	gitIn(t, repo, "add", "--", ".gitignore", "fix.marker", "docs", "scripts", "_tests", "adapter.sh", "adapter-fail-record.json", "steps.tsv", ".gitmodules", "helix-deps.yaml")
	gitIn(t, repo, "commit", "-q", "-m", "closed state")
	env := []string{"ZG_EVIDENCE=" + adapter, "ZG_DAILY_STEPS_FILE=" + steps, "ZG_DAILY_MAX_MEM_USED_PCT=99", "ZG_DAILY_MAX_LOAD_FACTOR=1000", "ZG_NOTIFY_CMD=true", "ZG_SCRATCH=" + t.TempDir()}
	daily := func() (int, string) {
		return runShell(t, repo, env, "bash", filepath.Join(repo, "scripts/zero-gap-daily.sh"), "--now", "--root", repo, "--state-dir", filepath.Join(repo, ".remember/logs/zero-gap"))
	}
	queue := filepath.Join(repo, ".remember/logs/zero-gap/reopen-queue.jsonl")
	dbBefore := fileSHA(t, db)

	// control: the fix is in place
	if rc, out := daily(); rc != 0 {
		t.Fatalf("control (fix in place): want rc 0, got %d\n%s", rc, out)
	}
	if _, err := os.Stat(queue); !os.IsNotExist(err) {
		t.Fatal("control run queued a reopen request")
	}

	// revert the fix, commit the revert, run again
	if err := os.Remove(filepath.Join(repo, "fix.marker")); err != nil {
		t.Fatal(err)
	}
	gitIn(t, repo, "add", "-u", "--", "fix.marker")
	gitIn(t, repo, "commit", "-q", "-m", "revert the fix")
	rc, out := daily()
	if rc != 1 {
		t.Fatalf("reverted fix: want daily rc 1 (RED), got %d\n%s", rc, out)
	}
	q, err := os.ReadFile(queue)
	if err != nil || !strings.Contains(string(q), `"item_id":"VSC-004"`) {
		t.Fatalf("no reopen request for VSC-004 was queued: %v %q", err, q)
	}
	if fileSHA(t, db) != dbBefore {
		t.Fatal("the daily run modified the register")
	}

	// the queue is applied by the real CLI, inside an explicit act
	rc, out = gapRun(t, repo, db, "apply-queue", "--as-of", "2026-09-26")
	if rc != 0 || field(t, db, "VSC-004", "status") != StatusReopened {
		t.Fatalf("apply-queue: want rc 0 and VSC-004 Reopened, got %d\n%s", rc, out)
	}
}
