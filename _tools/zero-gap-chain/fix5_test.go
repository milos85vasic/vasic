package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// ── Review T014 N3: the witness fetch used to recurse into populated ─────────
// submodules, trigger auto-maintenance, and let THIS repository's (or a
// submodule's) own config execute an upload-pack helper during a
// local-transport fetch. Each test below was run BEFORE the fix in
// history.go (with the corresponding --no-* / -c / --upload-pack argument
// removed) to confirm it actually goes RED without it — see the final
// report's mutation table. Removing any one override here reproduces that
// RED state again.

// n3Fixture builds a pushed, forward-only, witnessable history repo (like
// pushedForwardOnly in fix4_test.go, but returning the bare "origin" path so
// a vector can be planted in the CLIENT repo's own .git/config for that
// remote).
func n3Fixture(t *testing.T) (repo, ch, an string) {
	t.Helper()
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	push := withRemote(t, repo)
	commit(3, digestAt(t, ch, 3))
	push()
	return repo, ch, an
}

// remote.<r>.uploadpack, for a LOCAL (file-transport) remote — exactly what
// this repository's own proofs and any local mirror are — is a program git
// spawns DIRECTLY on this host in place of the real git-upload-pack. It is
// this repository's (the witness FETCHER's) own config, not anything the
// remote side controls, and it never runs "on the remote's side" for this
// transport.
func TestN3_WitnessFetchOverridesConfiguredUploadPack(t *testing.T) {
	repo, ch, an := n3Fixture(t)
	marker := filepath.Join(t.TempDir(), "uploadpack-ran")
	helper := filepath.Join(t.TempDir(), "uploadpack.sh")
	if err := os.WriteFile(helper, []byte("#!/bin/sh\n: > '"+marker+"'\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	gitT(t, repo, "config", "remote.origin.uploadpack", helper)
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err == nil {
		t.Errorf("the witness fetch EXECUTED the configured remote.origin.uploadpack helper (%s): %v", r.Verdict, r.Lines)
	}
	if r.Verdict != HistHolds {
		t.Errorf("pushed forward-only history must still HOLD once the real git-upload-pack is used: %s %v", r.Verdict, r.Lines)
	}
}

// A plain `git fetch` invokes a configured core.fsmonitor hook even though
// nothing here reads the working tree (measured before this fix: the marker
// ran); so does the earlier `git ls-files` existence probe this function
// runs on the same repository before it ever reaches the witness fetch
// (measured separately: the marker ran from THAT call too, independently of
// gitFetch). Both call sites are now pinned; this end-to-end test exercises
// the whole verifier, not gitFetch in isolation, so a regression in either
// spot is caught here.
func TestN3_WitnessFetchDisablesConfiguredFsmonitor(t *testing.T) {
	repo, ch, an := n3Fixture(t)
	marker := filepath.Join(t.TempDir(), "fsmonitor-ran")
	helper := filepath.Join(t.TempDir(), "fsmonitor.sh")
	script := "#!/bin/sh\n: > '" + marker + "'\n" +
		`echo '{"version":2,"clock":"c:0:0","is_fresh_instance":true,"files":[]}'` + "\nexit 0\n"
	if err := os.WriteFile(helper, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	gitT(t, repo, "config", "core.fsmonitor", helper)
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err == nil {
		t.Errorf("the witness fetch ran the configured core.fsmonitor hook (%s): %v", r.Verdict, r.Lines)
	}
	if r.Verdict != HistHolds {
		t.Errorf("pushed forward-only history must still HOLD with fsmonitor disabled: %s %v", r.Verdict, r.Lines)
	}
}

// n3RepoWithPopulatedSubmodule builds a superproject with one real, populated
// submodule (its own separate remote), pushes both, and returns the
// superproject repo plus a function to plant a marker in the SUBMODULE's own
// .git/config (which the constitution forbids editing directly — this is a
// throwaway t.TempDir() fixture, not this repository's real submodules).
func n3RepoWithPopulatedSubmodule(t *testing.T) (repo, ch, an string) {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git absent")
	}
	root := t.TempDir()
	subOrigin := filepath.Join(root, "sub-origin.git")
	if out, err := exec.Command("git", "init", "-q", "--bare", subOrigin).CombinedOutput(); err != nil {
		t.Fatalf("sub-origin init: %v %s", err, out)
	}
	seed := filepath.Join(root, "sub-seed")
	if err := os.MkdirAll(seed, 0o755); err != nil {
		t.Fatal(err)
	}
	gitT(t, seed, "init", "-q")
	gitT(t, seed, "config", "user.email", "t@example.invalid")
	gitT(t, seed, "config", "user.name", "t")
	if err := os.WriteFile(filepath.Join(seed, "f"), []byte("hi\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gitT(t, seed, "add", "f")
	gitT(t, seed, "commit", "-q", "-m", "subinit")
	gitT(t, seed, "remote", "add", "origin", subOrigin)
	gitT(t, seed, "push", "-q", "-u", "origin", "HEAD")

	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	cmd := exec.Command("git", "-C", repo, "-c", "protocol.file.allow=always",
		"submodule", "add", "-q", subOrigin, "sub")
	cmd.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_SYSTEM=/dev/null")
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("submodule add: %v %s", err, out)
	}
	gitT(t, repo, "commit", "-q", "-m", "add submodule")
	commit(3, digestAt(t, ch, 3))
	push := withRemote(t, repo)
	push()
	return repo, ch, an
}

// An unfixed witness fetch recurses into every populated submodule (this
// repository owns 22) and re-runs the whole config-driven-execution vector
// set again there, against a config this task's caller does not control.
// --no-recurse-submodules must stop that, and the superproject's OWN witness
// must still succeed.
func TestN3_WitnessFetchDoesNotRecurseIntoSubmodules(t *testing.T) {
	repo, ch, an := n3RepoWithPopulatedSubmodule(t)
	marker := filepath.Join(t.TempDir(), "submodule-uploadpack-ran")
	helper := filepath.Join(t.TempDir(), "sub-uploadpack.sh")
	if err := os.WriteFile(helper, []byte("#!/bin/sh\n: > '"+marker+"'\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	gitT(t, filepath.Join(repo, "sub"), "config", "remote.origin.uploadpack", helper)
	// Force recursion the way an accident or a global default could: on-demand
	// (the git default) may skip recursion when no submodule pointer moved in
	// the fetched range; submodule.recurse=true forces it unconditionally, so
	// this reproduces the vector deterministically rather than depending on
	// on-demand's heuristic (measured: with this set and no --no-recurse-
	// submodules, the marker DOES run).
	gitT(t, repo, "config", "submodule.recurse", "true")
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err == nil {
		t.Errorf("the witness fetch RECURSED into the populated submodule and ran its configured uploadpack helper (%s): %v", r.Verdict, r.Lines)
	}
	if r.Verdict != HistHolds {
		t.Errorf("the superproject's own forward-only history must still HOLD with submodule recursion disabled: %s %v", r.Verdict, r.Lines)
	}
}

// A `url.<x>.insteadOf` rewrite can retarget the witness to a different URL,
// but the protocol allowlist (GIT_ALLOW_PROTOCOL, set unconditionally in
// fetchEnv) is checked against the RESOLVED URL, not the configured one — so
// retargeting origin to an ext:: helper must still be refused before the
// helper runs. This vector was already closed by the existing
// GIT_ALLOW_PROTOCOL restriction (review T015d F3); this test pins it under
// its N3 name so a future change to the allowlist mechanism is caught here
// too, not only in the direct-set-url case fix4_test.go already covers.
func TestN3_WitnessFetchInsteadOfCannotRetargetToExtHelper(t *testing.T) {
	repo, ch, an := n3Fixture(t)
	marker := filepath.Join(t.TempDir(), "ext-ran")
	helper := filepath.Join(t.TempDir(), "ext-helper.sh")
	if err := os.WriteFile(helper, []byte("#!/bin/sh\n: > '"+marker+"'\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	origin := gitOut(t, repo, "remote", "get-url", "origin")
	gitT(t, repo, "config", "protocol.ext.allow", "always") // the repo's OWN config allows it
	gitT(t, repo, "config", "url.ext::"+helper+".insteadOf", origin)
	r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err == nil {
		t.Errorf("an insteadOf rewrite to ext:: EXECUTED the helper (%s): %v", r.Verdict, r.Lines)
	}
	if r.Verdict == HistHolds {
		t.Errorf("an ext:: remote (however reached) cannot witness anything, yet the verdict is HOLDS: %v", r.Lines)
	}
}

// DOCUMENTED RESIDUAL (review T014 N3 ruling, progress.yml): core.sshCommand
// is deliberately NOT neutralised. Pinning it (e.g. to plain "ssh") would
// override a real operator's own ssh configuration (identity file, port,
// ProxyJump, ...) needed to legitimately reach the three real umbrella
// remotes over ssh — exactly the transport this fetch must keep working.
// This test pins the CURRENT, ACCEPTED behaviour (the marker DOES run) so a
// silent future change is visible here rather than discovered as a surprise;
// it is not asserting a defect.
func TestN3_WitnessFetchSshCommandResidualIsDocumentedNotClosed(t *testing.T) {
	repo, ch, an := n3Fixture(t)
	marker := filepath.Join(t.TempDir(), "sshcommand-ran")
	helper := filepath.Join(t.TempDir(), "sshcmd.sh")
	if err := os.WriteFile(helper, []byte("#!/bin/sh\n: > '"+marker+"'\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	gitT(t, repo, "config", "core.sshCommand", helper)
	gitT(t, repo, "remote", "set-url", "origin", "ssh://nosuchhost.invalid/x/y.git")
	_ = VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err != nil {
		t.Errorf("core.sshCommand did NOT run — the documented residual changed; update history.go's RESIDUAL comment and this test if it was deliberately closed")
	}
}

// DOCUMENTED RESIDUAL (review T014 N3 ruling; rev-n3 independent re-review
// required this test: a DNS failure alone never reaches git's credential
// subsystem, so the vector must be reproduced with genuine reachability).
// credential.helper (the https:// transport) is deliberately NOT neutralised
// for the same reason core.sshCommand is not: pinning it would override a
// real operator's own credential-helper configuration needed to legitimately
// reach the three real umbrella remotes over https. This test proves the
// vector is REAL rather than theoretical: a local TLS server answers every
// request with 401, which is what actually makes git invoke the configured
// credential.helper (a program that can be anything) to ask for
// credentials, retry, and only then give up — never reached by an
// unreachable-host test like the sshCommand one above.
func TestN3_WitnessFetchCredentialHelperResidualIsDocumentedNotClosed(t *testing.T) {
	repo, ch, an := n3Fixture(t)
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("WWW-Authenticate", `Basic realm="zero-gap-n3"`)
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer srv.Close()
	marker := filepath.Join(t.TempDir(), "credential-helper-ran")
	helper := filepath.Join(t.TempDir(), "cred.sh")
	// A minimal, valid `git credential fill` responder: read whatever git
	// sends on stdin, discard it, and answer with a username/password pair
	// so git can actually retry the request (and then fail again, since the
	// server always answers 401 — this test only cares that the helper ran).
	script := "#!/bin/sh\n: > '" + marker + "'\ncat >/dev/null\necho username=x\necho password=y\nexit 0\n"
	if err := os.WriteFile(helper, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	// http.sslVerify=false is this FIXTURE's own repo config (the local TLS
	// test server's certificate is self-signed); it is not something gitFetch
	// itself sets, so it exercises the residual exactly as a real repository
	// with a real credential.helper and a real https remote would.
	gitT(t, repo, "config", "http.sslVerify", "false")
	gitT(t, repo, "config", "credential.helper", helper)
	gitT(t, repo, "remote", "set-url", "origin", srv.URL+"/repo.git")
	_ = VerifyAnchorHistoryWith(ch, an, HistoryOptions{})
	if _, err := os.Stat(marker); err != nil {
		t.Errorf("credential.helper did NOT run against a real reachable 401 — the documented residual changed; update history.go's RESIDUAL comment and this test if it was deliberately closed")
	}
}

// gitFetchArgvCapture proves the actual command line gitFetch constructs
// carries every neutralising flag, by shimming PATH with a `git` wrapper
// that logs argv and then execs the real binary. This is the one vector
// (auto-maintenance) with no simple execution marker of its own, and it also
// doubles as a single assertion that no override was accidentally dropped.
func TestN3_GitFetchArgvIncludesAllNeutralisingFlags(t *testing.T) {
	realGit, err := exec.LookPath("git")
	if err != nil {
		t.Skip("git absent")
	}
	_, ch, an := n3Fixture(t)
	shimDir := t.TempDir()
	logPath := filepath.Join(shimDir, "argv.log")
	shim := "#!/bin/sh\n" +
		"printf '%s\\n' \"$*\" >> '" + logPath + "'\n" +
		"exec '" + realGit + "' \"$@\"\n"
	if err := os.WriteFile(filepath.Join(shimDir, "git"), []byte(shim), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", shimDir+string(os.PathListSeparator)+os.Getenv("PATH"))
	if r := VerifyAnchorHistoryWith(ch, an, HistoryOptions{}); r.Verdict != HistHolds {
		t.Fatalf("shimmed PATH broke a legitimate witness fetch: %s %v", r.Verdict, r.Lines)
	}
	b, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("no command was logged through the shimmed PATH: %v", err)
	}
	var fetchLine string
	for _, line := range strings.Split(string(b), "\n") {
		if strings.Contains(line, " fetch ") || strings.HasSuffix(line, " fetch") {
			fetchLine = line
			break
		}
	}
	if fetchLine == "" {
		t.Fatalf("no `git fetch` invocation was captured; log:\n%s", b)
	}
	for _, want := range []string{
		"core.hooksPath=/dev/null",
		"core.fsmonitor=false",
		"--no-recurse-submodules",
		"--no-auto-maintenance",
		"--upload-pack=git-upload-pack",
	} {
		if !strings.Contains(fetchLine, want) {
			t.Errorf("the witness fetch's argv is missing %q: %s", want, fetchLine)
		}
	}
}
