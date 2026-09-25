package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

// ── Review T015c I1: argv secret policy by NAME/SHAPE, per WORD ──────────────

func TestFix3_ArgvPolicyRefuses(t *testing.T) {
	cases := map[string][]string{
		"bash -c --password":      {"bash", "-c", "curl --password zgx1 https://h.invalid"},
		"bash -c sshpass -p":      {"bash", "-c", "sshpass -p zgx2 ssh h"},
		"--db-pass":               {"tool", "--db-pass", "zgx3"},
		"DB_PASS=":                {"env", "DB_PASS=zgx4", "tool"},
		"MYSQL_PWD=":              {"env", "MYSQL_PWD=zgx5", "mysql"},
		"-storepass":              {"keytool", "-storepass", "zgx6"},
		"-keypass":                {"keytool", "-keypass", "zgx7"},
		"curl -u admin:pw":        {"curl", "-u", "admin:zgx8", "https://h.invalid"},
		"--user a:b":              {"curl", "--user", "a:zgx9", "https://h.invalid"},
		"--user=a:b":              {"curl", "--user=a:zgx10"},
		"-uadmin:pw":              {"curl", "-uadmin:zgx11"},
		"Cookie: header":          {"curl", "-H", "Cookie: sid=zgx12"},
		"Set-Cookie: header":      {"printf", "Set-Cookie: sid=zgx13"},
		"--key":                   {"tool", "--key", "zgx14"},
		"--credentials":           {"tool", "--credentials", "zgx15"},
		"--access-key":            {"tool", "--access-key", "zgx16"},
		"X-Api-Key header":        {"curl", "-H", "X-Api-Key: zgx17"},
		"--pass":                  {"tool", "--pass", "zgx18"},
		"-p X":                    {"tool", "-p", "zgx19"},
		"-pX":                     {"tool", "-pzgx20"},
		"--password short":        {"tool", "--password", "zgx21"},
		"--token":                 {"tool", "--token", "zgx22"},
		"TOKEN=":                  {"TOKEN=zgx23"},
		"Authorization Bearer":    {"curl", "-H", "Authorization: Bearer zgx24"},
		"bearer lowercase":        {"bearer zgx25"},
		"URL credentials":         {"git", "clone", "https://u:zgx26@h.invalid/r"},
		"MY_API_KEY=":             {"MY_API_KEY=zgx27"},
		"--pwd":                   {"tool", "--pwd", "zgx28"},
		"--client-secret":         {"tool", "--client-secret", "zgx29"},
		"sh -c export DB_PASS=":   {"sh", "-c", "export DB_PASS=zgx30; run"},
		"quoted TOKEN= in script": {"sh", "-c", `echo "TOKEN=zgx31"`},
	}
	for name, argv := range cases {
		refused, reason := ArgvPolicy(argv)
		if !refused {
			t.Errorf("%s: %q was NOT refused", name, argv)
			continue
		}
		if strings.Contains(reason, "zgx") {
			t.Errorf("%s: the refusal reason carries the value: %q", name, reason)
		}
	}
}

func TestFix3_ArgvPolicyAllows(t *testing.T) {
	for _, argv := range [][]string{
		{"x", "--prove-failure"}, {"x", "--port=8080"}, {"x", "--output-dir", "d"}, {"x", "--bypass"},
		{"compass"}, {"curl", "https://example.invalid/x"}, {"a=b"}, {"sh", "-c", "exit 0"}, {"x", "--parse"},
		{"sort", "-u", "f"}, {"git", "push", "-u", "origin", "HEAD"}, {"x", "--user", "bob"},
		{"x", "--keyboard"}, {"x", "--sort-key", "k"}, {"x", "https://example.invalid/a:b@c"},
		{"ls", "-la"}, {"bash", "-c", "echo hello world"}, // `-P 8080` was a control until T015d: -P is now refused like -p
	} {
		if refused, reason := ArgvPolicy(argv); refused {
			t.Errorf("a legitimate command line was refused: %q (%s)", argv, reason)
		}
	}
}

// 3000 short arguments must be judged in well under 5 s (one process).
func TestFix3_ArgvPolicyIsFast(t *testing.T) {
	argv := make([]string, 3000)
	for i := range argv {
		argv[i] = "arg" + strconv.Itoa(i)
	}
	start := time.Now()
	if refused, reason := ArgvPolicy(argv); refused {
		t.Fatalf("3000 plain arguments refused: %s", reason)
	}
	if d := time.Since(start); d > time.Second {
		t.Fatalf("3000 arguments took %s", d)
	}
}

// ── Review T015c NEW: the witness must not be forgeable locally ──────────────

// pushedThenLowered builds: anchors 2,3 pushed to origin; then both tails
// truncated, the anchor lowered to 2 and the tip AMENDED (the T015b attack).
func pushedThenLowered(t *testing.T) (repo, ch, an string) {
	t.Helper()
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	for _, f := range []string{chainFile, sidecarFile} {
		p := filepath.Join(filepath.Dir(ch), f)
		writeLines(t, p, readLines(t, p)[:2])
	}
	os.WriteFile(an, []byte(`{"head_digest":"`+digestAt(t, ch, 2)+`","entry_count":2,"anchor_strength":"policy"}`+"\n"), 0o644)
	gitT(t, repo, "commit", "-q", "--amend", "--allow-empty", "-am", "anchor 3 (amended)")
	return repo, ch, an
}

func branchOf(t *testing.T, repo string) string {
	return strings.TrimSpace(gitOut(t, repo, "symbolic-ref", "--short", "HEAD"))
}

func TestFix3_WitnessForgedByUpdateRef(t *testing.T) {
	repo, ch, an := pushedThenLowered(t)
	gitT(t, repo, "update-ref", "refs/remotes/origin/"+branchOf(t, repo), "HEAD")
	if r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{}); r.Verdict == HistHolds {
		t.Fatalf("a locally forged remote-tracking ref made a lowered anchor HOLD: %v", r.Lines)
	}
}

func TestFix3_WitnessForgedByEvilUpstream(t *testing.T) {
	repo, ch, an := pushedThenLowered(t)
	evil := filepath.Join(t.TempDir(), "evil.git")
	if out, err := exec.Command("git", "init", "-q", "--bare", evil).CombinedOutput(); err != nil {
		t.Fatalf("%v %s", err, out)
	}
	gitT(t, repo, "remote", "add", "evil", evil)
	gitT(t, repo, "push", "-q", "evil", "HEAD")
	gitT(t, repo, "branch", "-u", "evil/"+branchOf(t, repo))
	if r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{}); r.Verdict == HistHolds {
		t.Fatalf("`branch -u evil/...` made a lowered anchor HOLD: %v", r.Lines)
	}
}

func TestFix3_WitnessUnreachableIsUnwitnessed(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	gitT(t, repo, "remote", "set-url", "origin", filepath.Join(t.TempDir(), "does-not-exist.git"))
	if r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{}); r.Verdict != HistUnwitnessed {
		t.Fatalf("an unreachable witness must be UNWITNESSED (the stale local ref is not evidence), got %s %v", r.Verdict, r.Lines)
	}
}

func TestFix3_WitnessDivergedIsUnwitnessed(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	withRemote(t, repo)
	// Another clone pushes a commit this repo lacks; this repo commits its own.
	other := filepath.Join(t.TempDir(), "other")
	url := strings.TrimSpace(gitOut(t, repo, "remote", "get-url", "origin"))
	if out, err := exec.Command("git", "clone", "-q", url, other).CombinedOutput(); err != nil {
		t.Fatalf("%v %s", err, out)
	}
	gitT(t, other, "-c", "user.email=o@example.invalid", "-c", "user.name=o", "commit", "-q", "--allow-empty", "-m", "theirs")
	gitT(t, other, "push", "-q")
	commit(3, digestAt(t, ch, 3))
	if r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{}); r.Verdict != HistUnwitnessed {
		t.Fatalf("a remote that diverged from HEAD must be UNWITNESSED, got %s %v", r.Verdict, r.Lines)
	}
}

func TestFix3_WitnessExplicitRemoteMustBeConfigured(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	withRemote(t, repo)
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{Remote: "nosuch", RemoteExplicit: true})
	if r.Verdict != HistUndetermined {
		t.Fatalf("an explicit witness remote that is not configured must be refused (UNDETERMINED), got %s %v", r.Verdict, r.Lines)
	}
}

func TestFix3_WitnessNamesItsRemote(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if r.Verdict != HistHolds {
		t.Fatalf("pushed forward-only history: %s %v", r.Verdict, r.Lines)
	}
	if !strings.Contains(strings.Join(r.Lines, "\n"), `witness remote "origin"`) {
		t.Fatalf("the witness remote is not named in the output: %v", r.Lines)
	}
	if out := gitOut(t, repo, "for-each-ref", "refs/zero-gap/witness/"); strings.TrimSpace(out) == "" {
		t.Fatalf("the witness was not fetched into the private ref namespace")
	}
}

// ── Review T015c I2 minors ───────────────────────────────────────────────────

func TestFix3_AppendLockWaitIsBounded(t *testing.T) {
	dir := buildStore(t, 1)
	release, err := lockStore(dir, false, time.Second) // a stuck READER
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	before, _ := os.ReadFile(filepath.Join(dir, sidecarFile))
	req := baseRequest(t, dir, 2)
	req.LockTimeout = 300 * time.Millisecond
	done := make(chan error, 1)
	go func() { _, err := Append(req); done <- err }()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("Append sealed a record while another holder had the store lock")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Append waited without bound for the store lock")
	}
	if after, _ := os.ReadFile(filepath.Join(dir, sidecarFile)); !bytes.Equal(before, after) {
		t.Fatal("a timed-out Append wrote to the store")
	}
}

func TestFix3_HistoryRefusesWithoutTheLock(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	withRemote(t, repo)
	release, err := lockStore(filepath.Dir(ch), true, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	var o, e bytes.Buffer
	start := time.Now()
	rc := run([]string{"history", "--chain", ch, "--anchor", an, "--lock-timeout", "300ms"}, &o, &e)
	if rc != exitUndet {
		t.Fatalf("history ran without the store lock: rc %d, %s", rc, o.String())
	}
	if time.Since(start) > 5*time.Second {
		t.Fatal("history's lock wait was not bounded")
	}
}

// A process holding the lock may hand it to its children; a plain environment
// variable without the real descriptor must NOT skip the lock.
func TestFix3_InheritedLockIsHonouredForgedIsNot(t *testing.T) {
	dir := buildStore(t, 1)
	h, err := lockStore(dir, true, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer h()
	// forged: the env names a descriptor that is not the store directory
	other, _ := os.Open(t.TempDir())
	defer other.Close()
	t.Setenv("ZG_LOCK_FD", strconv.Itoa(int(other.Fd())))
	t.Setenv("ZG_LOCK_MODE", "exclusive")
	if _, err := lockStore(dir, false, 300*time.Millisecond); err == nil {
		t.Fatal("a forged ZG_LOCK_FD skipped the store lock")
	}
}

func buildBin(t *testing.T) string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "zg-chain")
	cmd := exec.Command("go", "build", "-o", bin, ".")
	cmd.Env = append(os.Environ(), "GOFLAGS=-mod=mod", "GOPROXY=off")
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}
	return bin
}

func TestFix3_ChildUnderExclusiveHolderUsesTheInheritedLock(t *testing.T) {
	bin := buildBin(t)
	dir := buildStore(t, 1)
	cmd := exec.Command(bin, "with-lock", "--store", dir, "--exclusive", "--timeout", "5s", "--",
		bin, "preflight", "--store", dir, "--schema", schemaPath, "--lock-timeout", "1s")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("preflight inside an exclusive holder could not use the inherited lock: %v\n%s", err, out)
	}
}

func alive(pid int) bool { return syscall.Kill(pid, 0) == nil }

func TestFix3_WithLockChildDiesWithAKilledHolder(t *testing.T) {
	bin := buildBin(t)
	dir := buildStore(t, 1)
	pidf := filepath.Join(t.TempDir(), "child.pid")
	holder := exec.Command(bin, "with-lock", "--store", dir, "--exclusive", "--",
		"/bin/sh", "-c", `echo $$ > "$1"; exec sleep 30`, "x", pidf)
	if err := holder.Start(); err != nil {
		t.Fatal(err)
	}
	var child int
	for i := 0; i < 100 && child == 0; i++ {
		b, _ := os.ReadFile(pidf)
		child, _ = strconv.Atoi(strings.TrimSpace(string(b)))
		time.Sleep(20 * time.Millisecond)
	}
	if child == 0 {
		holder.Process.Kill()
		t.Fatal("the child never started")
	}
	holder.Process.Kill() // SIGKILL the pid THIS test started
	holder.Wait()
	gone := false
	for i := 0; i < 100; i++ {
		if !alive(child) {
			gone = true
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if !gone {
		syscall.Kill(child, syscall.SIGKILL) // the child this test's holder started
		t.Fatal("the with-lock child kept running after its holder was SIGKILLed")
	}
	if rel, err := lockStore(dir, true, 2*time.Second); err != nil {
		t.Fatalf("the lock was not released once holder and child were gone: %v", err)
	} else {
		rel()
	}
}

func TestFix3_WithLockForwardsTERM(t *testing.T) {
	bin := buildBin(t)
	dir := buildStore(t, 1)
	ready := filepath.Join(t.TempDir(), "ready")
	holder := exec.Command(bin, "with-lock", "--store", dir, "--shared", "--",
		"/bin/sh", "-c", `trap 'exit 143' TERM; : > "$1"; while :; do sleep 0.05; done`, "x", ready)
	if err := holder.Start(); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 100; i++ {
		if _, err := os.Stat(ready); err == nil {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	holder.Process.Signal(syscall.SIGTERM)
	done := make(chan error, 1)
	go func() { done <- holder.Wait() }()
	select {
	case err := <-done:
		ee, ok := err.(*exec.ExitError)
		if !ok || ee.ExitCode() != 143 {
			t.Fatalf("with-lock did not forward TERM and return the child's 143: %v", err)
		}
	case <-time.After(5 * time.Second):
		holder.Process.Kill()
		t.Fatal("with-lock did not end after TERM")
	}
}

var _ = fmt.Sprintf

// lock-fd: the lock lives on the CALLING shell's descriptor after the helper
// exits, and dies with that shell (a SIGKILL releases it).
func TestFix3_LockFDBelongsToTheShell(t *testing.T) {
	bin := buildBin(t)
	dir := buildStore(t, 1)
	ready := filepath.Join(t.TempDir(), "ready")
	sh := exec.Command("/bin/bash", "-c", `exec {f}<"$1" && "$2" lock-fd --store "$1" --fd "$f" --exclusive --timeout 2s && : > "$3" && exec sleep 30`, "x", dir, bin, ready)
	if err := sh.Start(); err != nil {
		t.Fatal(err)
	}
	defer sh.Process.Kill()
	for i := 0; i < 200; i++ {
		if _, err := os.Stat(ready); err == nil {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if _, err := lockStore(dir, false, 300*time.Millisecond); err == nil {
		t.Fatal("the lock taken by lock-fd did not persist on the shell's descriptor")
	}
	sh.Process.Kill() // the pid THIS test started
	sh.Wait()
	rel, err := lockStore(dir, true, 2*time.Second)
	if err != nil {
		t.Fatalf("the lock outlived its SIGKILLed shell: %v", err)
	}
	rel()
}
