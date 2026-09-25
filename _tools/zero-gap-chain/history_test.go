package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/vasic-digital/continuum/pkg/chain"
)

func gitT(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_SYSTEM=/dev/null")
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
}

// historyRepo builds a git repo holding a 3-record store and returns the repo,
// the chain path, the anchor path and a writer that commits an anchor text.
func historyRepo(t *testing.T) (string, string, string, func(count int, head string)) {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git absent: the history verifier cannot be exercised (honest skip)")
	}
	repo := t.TempDir()
	gitT(t, repo, "init", "-q")
	gitT(t, repo, "config", "user.email", "t@example.invalid")
	gitT(t, repo, "config", "user.name", "t")
	store := filepath.Join(repo, "store")
	os.MkdirAll(store, 0o755)
	for i := 1; i <= 3; i++ {
		if _, err := Append(baseRequest(t, store, i)); err != nil {
			t.Fatal(err)
		}
	}
	anchor := filepath.Join(store, "anchor.json")
	commit := func(count int, head string) {
		t.Helper()
		body := fmt.Sprintf(`{"head_digest":"%s","entry_count":%d,"anchor_strength":"policy"}`+"\n", head, count)
		if err := os.WriteFile(anchor, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		gitT(t, repo, "add", "store/anchor.json")
		gitT(t, repo, "commit", "-q", "-m", fmt.Sprintf("anchor %d", count))
	}
	return repo, filepath.Join(store, chainFile), anchor, commit
}

func digestAt(t *testing.T, chainPath string, n int) string {
	t.Helper()
	b, _ := os.ReadFile(chainPath)
	recs, err := chain.Decode(b)
	if err != nil {
		t.Fatal(err)
	}
	d, err := chain.Digest(recs[n-1])
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func TestHistory_ForwardOnlyHolds(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	commit(3, digestAt(t, ch, 3))
	withRemote(t, repo) // HOLDS needs a witness (review T015b I3)
	if r := VerifyAnchorHistory(ch, an); r.Verdict != HistHolds {
		t.Fatalf("forward-only history reported %s: %v", r.Verdict, r.Lines)
	}
}

func TestHistory_Violations(t *testing.T) {
	t.Run("entry_count drops between commits", func(t *testing.T) {
		_, ch, an, commit := historyRepo(t)
		commit(3, digestAt(t, ch, 3))
		commit(2, digestAt(t, ch, 2)) // a valid, consistent anchor — but backwards
		r := VerifyAnchorHistory(ch, an)
		if r.Verdict != HistViolated || !strings.Contains(strings.Join(r.Lines, "\n"), "dropped") {
			t.Fatalf("regression not reported: %s %v", r.Verdict, r.Lines)
		}
	})
	t.Run("same count rewritten to another head", func(t *testing.T) {
		_, ch, an, commit := historyRepo(t)
		commit(2, digestAt(t, ch, 2))
		commit(2, hex64("forged"))
		if r := VerifyAnchorHistory(ch, an); r.Verdict != HistViolated {
			t.Fatalf("rewrite not reported: %s %v", r.Verdict, r.Lines)
		}
	})
	t.Run("an earlier head no longer matches the current chain", func(t *testing.T) {
		_, ch, an, commit := historyRepo(t)
		commit(2, hex64("an-older-truth"))
		commit(3, digestAt(t, ch, 3))
		if r := VerifyAnchorHistory(ch, an); r.Verdict != HistViolated {
			t.Fatalf("earlier head mismatch not reported: %s %v", r.Verdict, r.Lines)
		}
	})
	t.Run("chain now shorter than a committed anchor", func(t *testing.T) {
		_, ch, an, commit := historyRepo(t)
		commit(3, digestAt(t, ch, 3))
		b, _ := os.ReadFile(ch)
		lines := strings.SplitAfter(string(b), "\n")
		os.WriteFile(ch, []byte(strings.Join(lines[:2], "")), 0o644)
		if r := VerifyAnchorHistory(ch, an); r.Verdict != HistViolated {
			t.Fatalf("truncation below a committed anchor not reported: %s %v", r.Verdict, r.Lines)
		}
	})
	t.Run("anchor deleted in history", func(t *testing.T) {
		repo, ch, an, commit := historyRepo(t)
		commit(2, digestAt(t, ch, 2))
		gitT(t, repo, "rm", "-q", "store/anchor.json")
		gitT(t, repo, "commit", "-q", "-m", "drop anchor")
		commit(3, digestAt(t, ch, 3))
		if r := VerifyAnchorHistory(ch, an); r.Verdict != HistViolated {
			t.Fatalf("a deleted anchor in history was not reported: %s %v", r.Verdict, r.Lines)
		}
	})
	t.Run("working-tree anchor below the last commit", func(t *testing.T) {
		_, ch, an, commit := historyRepo(t)
		commit(3, digestAt(t, ch, 3))
		os.WriteFile(an, []byte(fmt.Sprintf(`{"head_digest":"%s","entry_count":2,"anchor_strength":"policy"}`+"\n", digestAt(t, ch, 2))), 0o644)
		if r := VerifyAnchorHistory(ch, an); r.Verdict != HistViolated {
			t.Fatalf("an uncommitted regression was not reported: %s %v", r.Verdict, r.Lines)
		}
	})
	t.Run("a committed anchor that is not an anchor record", func(t *testing.T) {
		repo, ch, an, commit := historyRepo(t)
		commit(2, digestAt(t, ch, 2))
		os.WriteFile(an, []byte("not json\n"), 0o644)
		gitT(t, repo, "commit", "-q", "-am", "junk")
		commit(3, digestAt(t, ch, 3))
		if r := VerifyAnchorHistory(ch, an); r.Verdict != HistViolated {
			t.Fatalf("a malformed committed anchor was not reported: %s %v", r.Verdict, r.Lines)
		}
	})
}

func TestHistory_NotApplicableAndUndetermined(t *testing.T) {
	dir := t.TempDir()
	store := filepath.Join(dir, "s")
	os.MkdirAll(store, 0o755)
	Append(baseRequest(t, store, 1))
	an := filepath.Join(store, "anchor.json")
	os.WriteFile(an, []byte(`{"head_digest":"`+hex64("x")+`","entry_count":1,"anchor_strength":"policy"}`+"\n"), 0o644)
	if r := VerifyAnchorHistory(filepath.Join(store, chainFile), an); r.Verdict != HistNotApplicable {
		t.Fatalf("an anchor outside any repository: %s %v", r.Verdict, r.Lines)
	}
	// Inside a repository but NOT tracked: a separate branch from "outside any
	// repository" (mutation M14 of the §1.1 run survived until this case existed).
	repoU, chU, anU, _ := historyRepo(t)
	os.WriteFile(anU, []byte(`{"head_digest":"`+digestAt(t, chU, 3)+`","entry_count":3,"anchor_strength":"policy"}`+"\n"), 0o644)
	if r := VerifyAnchorHistory(chU, anU); r.Verdict != HistNotApplicable {
		t.Fatalf("an untracked anchor inside a repository: %s %v", r.Verdict, r.Lines)
	}
	// Tracked (staged) in a repository with NO commit at all: git log would
	// exit 128 — that is "never committed", not "could not read".
	gitT(t, repoU, "add", "store/anchor.json")
	if r := VerifyAnchorHistory(chU, anU); r.Verdict != HistNotApplicable {
		t.Fatalf("a staged anchor in a commit-less repository: %s %v", r.Verdict, r.Lines)
	}
	// Staged, while OTHER files are committed: the repository has history,
	// the anchor has none.
	gitT(t, repoU, "rm", "-q", "--cached", "store/anchor.json")
	gitT(t, repoU, "add", "store/chain.jsonl")
	gitT(t, repoU, "commit", "-q", "-m", "chain only")
	gitT(t, repoU, "add", "store/anchor.json")
	if r := VerifyAnchorHistory(chU, anU); r.Verdict != HistNotApplicable {
		t.Fatalf("a staged-but-never-committed anchor: %s %v", r.Verdict, r.Lines)
	}
	_, ch, an2, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	os.Remove(ch)
	if r := VerifyAnchorHistory(ch, an2); r.Verdict != HistUndetermined {
		t.Fatalf("an unreadable chain must be undetermined, got %s %v", r.Verdict, r.Lines)
	}
}
