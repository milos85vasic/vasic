package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

// ── Review T015d F1: quoted / escaped / nested / token-only / look-alike ──────

func TestFix4_ArgvPolicyRefusesObfuscatedShapes(t *testing.T) {
	cases := map[string][]string{
		// (a) quoting and escaping inside a `bash -c` body
		"single-quoted flag":   {"bash", "-c", "curl '--password' zgy1 https://h.invalid"},
		"double-quoted flag":   {"bash", "-c", `curl "--password" zgy2 https://h.invalid`},
		"single-quoted -p":     {"bash", "-c", "sshpass '-p' zgy3 ssh h"},
		"backslash-escaped":    {"bash", "-c", `curl \--password zgy4 https://h.invalid`},
		"ansi-c hex escape":    {"bash", "-c", `curl $'--pass\x77ord' zgy5 https://h.invalid`},
		"ansi-c unicode":       {"bash", "-c", `curl $'--pass\u0077ord' zgy6 https://h.invalid`},
		"ansi-c octal":         {"bash", "-c", `curl $'--pass\167ord' zgy7 https://h.invalid`},
		"quoted NAME=":         {"bash", "-c", `export 'DB_PASS'=zgy8; run`},
		"quote inside name":    {"bash", "-c", `tool --pass''word zgy9`},
		"quote inside -p":      {"bash", "-c", `tool -''p zgy10`},
		"dollar-double-quoted": {"bash", "-c", `tool $"--token" zgy11`},
		// (b) a secret NAME=value nested inside a flag's value
		"--build-arg=TOKEN=":   {"docker", "build", "--build-arg=TOKEN=zgy12", "."},
		"--build-arg TOKEN=":   {"docker", "build", "--build-arg", "TOKEN=zgy13", "."},
		"--header=Cookie:":     {"curl", "--header=Cookie:s=zgy14", "https://h.invalid"},
		"--opt=a:b,token=":     {"tool", "--opt=a:b,token=zgy15"},
		"--env=DB_PASSWORD=":   {"tool", "--env=DB_PASSWORD=zgy16"},
		"--set=db.password=":   {"helm", "--set=db.password=zgy17"},
		"-e MYSQL_PWD=":        {"docker", "run", "-eMYSQL_PWD=zgy18", "img"},
		"query access_token":   {"curl", "https://h.invalid/x?access_token=zgy19"},
		"query token":          {"curl", "https://h.invalid/x?a=1&token=zgy20"},
		"query key":            {"curl", "https://h.invalid/x?key=zgy21"},
		"semicolon list":       {"tool", "--kv=a=1;secret=zgy22"},
		"username=..,password": {"tool", "--dsn=username=u,password=zgy23"},
		// (c) a token-only URL (userinfo without a colon)
		"token-only https":      {"git", "clone", "https://zgy24@github.invalid/x/y.git"},
		"token-only in script":  {"bash", "-c", "git clone https://zgy25@github.invalid/x/y.git"},
		"token-only ssh scheme": {"git", "clone", "ssh://zgy26@h.invalid/x"},
		// (d) look-alikes
		"-P X":               {"tool", "-P", "zgy27"},
		"-PX":                {"tool", "-Pzgy28"},
		"homoglyph cyrillic": {"tool", "--р\u0430ssword", "zgy29"}, // Cyrillic er + a
		"homoglyph in NAME=": {"tool", "TОKEN=zgy30"},              // Cyrillic O
		"fullwidth flag":     {"tool", "\uff0d\uff0dtoken", "zgy31"},
		"mixed-script flag":  {"tool", "--pаsswd", "zgy32"}, // Cyrillic a in an otherwise ASCII name
		"zero-width in name": {"tool", "--pass\u200bword", "zgy33"},
		"uppercase":          {"tool", "--PASSWORD", "zgy34"},
		"tab separator":      {"bash", "-c", "tool\t--password\tzgy35"},
	}
	for name, argv := range cases {
		refused, reason := ArgvPolicy(argv)
		if !refused {
			t.Errorf("%s: %q was NOT refused", name, argv)
			continue
		}
		if strings.Contains(reason, "zgy") {
			t.Errorf("%s: the refusal reason carries the value: %q", name, reason)
		}
	}
}

func TestFix4_ArgvPolicyAllowsControls(t *testing.T) {
	for _, argv := range [][]string{
		{"git", "clone", "ssh://git@github.invalid/x/y.git"},
		{"git", "clone", "https://git@github.invalid/x/y.git"},
		{"git", "log", "--format=%H:%s"},
		{"date", "-d", "12:30:00"},
		{"tool", `C:\tmp\x`},
		{"tool", "--label=env:prod,tier=web"},
		{"tool", "a=b,c=d;e=f"},
		{"curl", "https://h.invalid/x?page=2&sort=name"},
		{"docker", "build", "--build-arg=VERSION=1.2", "."},
		{"ls", "-la"}, {"cp", "-a", "x", "y"},
		{"bash", "-c", "echo 'it''s' \"fine\""},
		{"tool", "--größe=3"}, // Latin diacritics are not confusables: not a look-alike
		{"tool", "--файл=x"},  // a whole-script Cyrillic name mixes nothing
	} {
		if refused, reason := ArgvPolicy(argv); refused {
			t.Errorf("a legitimate command line was refused: %q (%s)", argv, reason)
		}
	}
}

// Documented misses: the header lists these as NOT caught; the test pins the
// documentation to the behaviour, so a silent change in either is seen.
func TestFix4_ArgvPolicyDocumentedMisses(t *testing.T) {
	for _, argv := range [][]string{
		{"redis-cli", "-a", "zgy40"},             // name-less value: -a is ls/cp/rsync/git territory
		{"tool", "zgy41"},                        // bare value, no name or shape around it
		{"sh", "-c", "tool --password $(cat f)"}, // computed at run time: the argv holds only the text
		{"tool", "--pw"},                         // flag with NO value word: secret-shaped name, still refused? see below
	} {
		refused, reason := ArgvPolicy(argv)
		switch strings.Join(argv, " ") {
		case "tool --pw", "sh -c tool --password $(cat f)":
			if !refused {
				t.Errorf("%q must still be refused by NAME (the value is irrelevant): %s", argv, reason)
			}
		default:
			if refused {
				t.Errorf("%q is documented as NOT caught, yet was refused (%s): update the header or the test", argv, reason)
			}
		}
	}
}

// ── Review T015d F3: the witness fetch is an execution surface ───────────────

func hookScript(t *testing.T, path, marker string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("#!/bin/sh\n: > '"+marker+"'\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
}

// An ext:: remote runs an arbitrary program. git-remote-ext splits its command
// on SPACES with no shell quoting, so the helper is a spaceless script path
// (a quoted `sh -c '…'` never runs and would make this test pass vacuously —
// measured: "Syntax error: Unterminated quoted string").
func TestFix4_WitnessFetchRefusesExtRemoteHelper(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	withRemote(t, repo)
	m := t.TempDir()
	marker := filepath.Join(m, "ext-ran")
	helper := filepath.Join(m, "helper.sh")
	hookScript(t, helper, marker)
	gitT(t, repo, "config", "protocol.ext.allow", "always") // the repo's OWN config allows it
	gitT(t, repo, "remote", "set-url", "origin", "ext::"+helper)
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err == nil {
		t.Errorf("the witness fetch EXECUTED the ext:: remote helper (%s)", r.Verdict)
	}
	if r.Verdict == HistHolds {
		t.Errorf("an ext:: remote cannot witness anything, yet the verdict is HOLDS: %v", r.Lines)
	}
}

// Hooks: a reference-transaction hook fires on the ref write a fetch performs,
// from the repository's own hooks dir or from a hooks path smuggled through the
// GIT_CONFIG_* environment. Neither may run; the fetch itself must still work.
func pushedForwardOnly(t *testing.T) (repo, ch, an string) {
	t.Helper()
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	return repo, ch, an
}

func TestFix4_WitnessFetchRunsNoRepoHook(t *testing.T) {
	repo, ch, an := pushedForwardOnly(t)
	marker := filepath.Join(t.TempDir(), "hook")
	hookScript(t, filepath.Join(repo, ".git", "hooks", "reference-transaction"), marker)
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err == nil {
		t.Errorf("the witness fetch ran the repository's reference-transaction hook (%s)", r.Verdict)
	}
	if r.Verdict != HistHolds {
		t.Errorf("pushed forward-only history must HOLD with hooks pinned off: %s %v", r.Verdict, r.Lines)
	}
}

func TestFix4_WitnessFetchRunsNoEnvSmuggledHook(t *testing.T) {
	_, ch, an := pushedForwardOnly(t)
	m := t.TempDir()
	marker := filepath.Join(m, "envhook")
	envHooks := filepath.Join(m, "hooks")
	hookScript(t, filepath.Join(envHooks, "reference-transaction"), marker)
	t.Setenv("GIT_CONFIG_COUNT", "1")
	t.Setenv("GIT_CONFIG_KEY_0", "core.hooksPath")
	t.Setenv("GIT_CONFIG_VALUE_0", envHooks)
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err == nil {
		t.Errorf("a hooks path smuggled through GIT_CONFIG_* ran on the witness fetch (%s)", r.Verdict)
	}
	if r.Verdict != HistHolds {
		t.Errorf("pushed forward-only history must HOLD: %s %v", r.Verdict, r.Lines)
	}
}

func TestFix4_WitnessFetchIgnoresGitConfigGlobalRedirect(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	origin := strings.TrimSpace(gitOut(t, repo, "remote", "get-url", "origin"))
	// An EMPTY bare repo posing as origin through url.<evil>.insteadOf in a
	// global config smuggled through GIT_CONFIG_GLOBAL: the redirected fetch
	// finds no branch, so it would read UNWITNESSED — or, with a lowered
	// history there, HOLDS. Either way the witness would not be origin.
	evil := filepath.Join(t.TempDir(), "evil.git")
	if out, err := exec.Command("git", "init", "-q", "--bare", evil).CombinedOutput(); err != nil {
		t.Fatalf("%v %s", err, out)
	}
	gc := filepath.Join(t.TempDir(), "gitconfig")
	if err := os.WriteFile(gc, []byte("[url \""+evil+"\"]\n\tinsteadOf = "+origin+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("GIT_CONFIG_GLOBAL", gc)
	if r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{}); r.Verdict != HistHolds {
		t.Fatalf("GIT_CONFIG_GLOBAL in the environment redirected the witness fetch: %s %v", r.Verdict, r.Lines)
	}
}

func TestFix4_RedactURLQueryTokens(t *testing.T) {
	for in, want := range map[string]string{
		"https://h.invalid/x?access_token=abc&b=2": "https://h.invalid/x?access_token=<redacted>&b=2",
		"https://h.invalid/x?a=1&token=abc":        "https://h.invalid/x?a=1&token=<redacted>",
		"https://h.invalid/x?key=abc":              "https://h.invalid/x?key=<redacted>",
		"https://h.invalid/x?private_token=abc":    "https://h.invalid/x?private_token=<redacted>",
		"https://u:p@h.invalid/x?token=abc":        "https://<redacted>@h.invalid/x?token=<redacted>",
		"https://tok@h.invalid/x":                  "https://<redacted>@h.invalid/x",
		"https://h.invalid/x?page=2":               "https://h.invalid/x?page=2",
		"/srv/repo.git":                            "/srv/repo.git",
	} {
		if got := redactURL(in); got != want {
			t.Errorf("redactURL(%q) = %q, want %q", in, got, want)
		}
	}
}

// ── Review T015d F4: a forged ZG_LOCK_MODE must never convert (and drop) ─────

func flockNB(t *testing.T, dir string, how int) (*os.File, error) {
	t.Helper()
	f, err := os.Open(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := syscall.Flock(int(f.Fd()), how|syscall.LOCK_NB); err != nil {
		f.Close()
		return nil, err
	}
	return f, nil
}

func TestFix4_ForgedExclusiveModeDoesNotDropTheShellsSharedLock(t *testing.T) {
	dir := buildStore(t, 1)
	shell, err := flockNB(t, dir, syscall.LOCK_SH) // the "shell" holds SHARED on this descriptor
	if err != nil {
		t.Fatal(err)
	}
	defer shell.Close()
	other, err := flockNB(t, dir, syscall.LOCK_SH) // another reader, so a conversion to EX cannot succeed
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv(lockFDEnv, strconv.Itoa(int(shell.Fd())))
	t.Setenv(lockModeEnv, "exclusive") // FORGED: the descriptor holds SHARED
	l, ok, ierr := inheritedStoreLock(dir, false)
	if ok && ierr == nil && l != nil && l.exclusive {
		t.Errorf("a forged exclusive mode was believed on a descriptor that holds SHARED")
	}
	other.Close()
	// The shell's SHARED lock must still be there: an exclusive attempt on a
	// fresh descriptor must be refused.
	if f, err := flockNB(t, dir, syscall.LOCK_EX); err == nil {
		f.Close()
		t.Fatal("the shell's shared lock was DROPPED by the failed conversion: an exclusive lock was obtained while the shell still holds its descriptor")
	}
}

func TestFix4_HeldModeIsReadFromTheKernelNotTheEnvironment(t *testing.T) {
	dir := buildStore(t, 1)
	shell, err := flockNB(t, dir, syscall.LOCK_EX)
	if err != nil {
		t.Fatal(err)
	}
	defer shell.Close()
	t.Setenv(lockFDEnv, strconv.Itoa(int(shell.Fd())))
	t.Setenv(lockModeEnv, "exclusive") // agrees with the kernel: recognised, no flock issued
	l, ok, ierr := inheritedStoreLock(dir, true)
	if !ok || ierr != nil || l == nil || !l.exclusive {
		t.Fatalf("an EXCLUSIVE lock really held on the descriptor was not recognised from the kernel's view (ok=%v err=%v)", ok, ierr)
	}
	t.Setenv(lockModeEnv, "shared") // DISAGREES with the kernel: no legitimate holder exports that, so it is refused
	if _, ok, ierr := inheritedStoreLock(dir, true); !ok || ierr == nil {
		t.Fatalf("a ZG_LOCK_MODE that disagrees with the held flock must be refused, got ok=%v err=%v", ok, ierr)
	}
	// and a descriptor that holds NO lock is never accepted as inherited
	bare, _ := os.Open(dir)
	defer bare.Close()
	t.Setenv(lockFDEnv, strconv.Itoa(int(bare.Fd())))
	t.Setenv(lockModeEnv, "exclusive")
	if l, ok, ierr := inheritedStoreLock(dir, true); ok && ierr == nil && l != nil {
		t.Fatal("an unlocked descriptor was accepted as an inherited lock")
	}
	start := time.Now()
	if rel, err := lockStore(dir, false, 300*time.Millisecond); err == nil {
		rel()
		t.Fatal("a shared lock was obtained while the shell holds EXCLUSIVE")
	} else if time.Since(start) > 5*time.Second {
		t.Fatal("the bounded wait was not bounded")
	}
}
