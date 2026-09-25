package main

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/vasic-digital/continuum/pkg/chain"
)

const iChainBytes = "I10-chain-byte-rule"

// Review finding 1: upstream decodes RECORDS, not bytes, so a chain file whose
// bytes are wrong still walks clean — and the next append glued a record onto
// the last line. The chain's own bytes are therefore an invariant.
func TestFix1_ChainByteRule(t *testing.T) {
	cf := func(d string) string { return filepath.Join(d, chainFile) }
	cases := map[string]func(t *testing.T, d string){
		"no final newline": func(t *testing.T, d string) {
			b, _ := os.ReadFile(cf(d))
			os.WriteFile(cf(d), bytes.TrimSuffix(b, []byte("\n")), 0o644)
		},
		"CRLF": func(t *testing.T, d string) {
			b, _ := os.ReadFile(cf(d))
			os.WriteFile(cf(d), bytes.Replace(b, []byte("\n"), []byte("\r\n"), 1), 0o644)
		},
		"trailing whitespace": func(t *testing.T, d string) {
			ls := readLines(t, cf(d))
			ls[1] = append(ls[1], ' ', ' ')
			writeLines(t, cf(d), ls)
		},
		"blank line": func(t *testing.T, d string) {
			b, _ := os.ReadFile(cf(d))
			os.WriteFile(cf(d), bytes.Replace(b, []byte("\n"), []byte("\n\n"), 1), 0o644)
		},
		"non-canonical spacing": func(t *testing.T, d string) {
			ls := readLines(t, cf(d))
			ls[0] = bytes.Replace(ls[0], []byte(`,"ts":`), []byte(`, "ts":`), 1)
			writeLines(t, cf(d), ls)
		},
	}
	for name, mut := range cases {
		t.Run(name, func(t *testing.T) {
			d := buildStore(t, 3)
			mut(t, d)
			if rep := verifyDir(t, d); !hasInvariant(rep.Findings, iChainBytes) {
				t.Fatalf("%s: %s not reported: %v", name, iChainBytes, rep.Findings)
			}
			before, _ := os.ReadFile(cf(d))
			if _, err := Append(baseRequest(t, d, 4)); err == nil {
				t.Fatalf("%s: appended onto a chain whose bytes are not canonical", name)
			}
			after, _ := os.ReadFile(cf(d))
			if !bytes.Equal(before, after) {
				t.Fatalf("%s: a refused append changed the chain bytes", name)
			}
		})
	}
}

// Review finding 11: the pre-flight a wrapped check must pass BEFORE it runs.
func TestFix1_Preflight(t *testing.T) {
	s := mustSchema(t)
	if err := Preflight(filepath.Join(t.TempDir(), "fresh"), s); err != nil {
		t.Fatalf("a fresh (absent) store must be usable: %v", err)
	}
	if err := Preflight(buildStore(t, 2), s); err != nil {
		t.Fatalf("a healthy store: %v", err)
	}
	unbound := buildStore(t, 2)
	ls := readLines(t, filepath.Join(unbound, sidecarFile))
	writeLines(t, filepath.Join(unbound, sidecarFile), append(ls, ls[0]))
	broken := buildStore(t, 2)
	recs := decodeChain(t, broken)
	// A field the sidecar does NOT duplicate, changed without re-linking: every
	// adapter invariant still holds, so ONLY the chain walk can refuse it
	// (mutation F11 survived while this case changed exit_status, which I6 sees).
	recs[0].AuthorSessionID = "forged"
	b1, _ := json.Marshal(recs[0])
	ls2 := readLines(t, filepath.Join(broken, chainFile))
	ls2[0] = b1
	writeLines(t, filepath.Join(broken, chainFile), ls2)
	half := t.TempDir()
	os.WriteFile(filepath.Join(half, chainFile), nil, 0o644)
	for name, d := range map[string]string{"unbound sidecar line": unbound, "broken link": broken, "one file only": half} {
		if err := Preflight(d, s); err == nil {
			t.Errorf("%s: pre-flight accepted a store the check must not run against", name)
		}
	}
}

// Review finding 5: the kept rows must be decodable by upstream DecodeExecRows,
// with the FINAL stream_ref and the effective redaction flag.
func TestFix1_ExecRowsAreUpstreamDecodable(t *testing.T) {
	dir := t.TempDir()
	rows := filepath.Join(t.TempDir(), "exec_rows.jsonl")
	for i := 1; i <= 3; i++ {
		r := baseRequest(t, dir, i)
		r.ExecRowsPath = rows
		if i == 2 {
			r.Argv = []string{"/bin/sh", "-c", "exit 0", `q"uote`, "t\tab", "new\nline"}
			r.RedactedOverride = true
		}
		if _, err := Append(r); err != nil {
			t.Fatal(err)
		}
	}
	b, err := os.ReadFile(rows)
	if err != nil {
		t.Fatal(err)
	}
	ers, err := chain.DecodeExecRows(b)
	if err != nil {
		t.Fatalf("upstream DecodeExecRows refused the kept rows: %v", err)
	}
	if len(ers) != 3 {
		t.Fatalf("%d rows, want 3", len(ers))
	}
	if strings.Join(ers[1].Argv, "|") != "/bin/sh|-c|exit 0|q\"uote|t\tab|new\nline" {
		t.Fatalf("argv not exact: %q", ers[1].Argv)
	}
	if ers[1].StreamRedacted != "true" || ers[1].StreamRef != "/srv/zg-fixture/streams/run2" || ers[1].ExitStatus != "0" {
		t.Fatalf("row 2 fields wrong: %+v", ers[1])
	}
	rep, _, err := chain.VerifyExecRows(decodeChain(t, dir), ers)
	if err != nil || rep.Verdict != chain.PASS {
		t.Fatalf("upstream union-rule seam: %v %+v", err, rep)
	}
}

func gitOut(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_SYSTEM=/dev/null")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// Review finding 10: a lowered anchor on a SIDE branch, merged with a result
// TREESAME to the main parent, is invisible to default history simplification.
func TestFix1_HistorySideBranchNotHidden(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(3, digestAt(t, ch, 3))
	main := gitOut(t, repo, "rev-parse", "--abbrev-ref", "HEAD")
	gitT(t, repo, "checkout", "-q", "-b", "side")
	commit(2, digestAt(t, ch, 2)) // the regression lives only on the side branch
	gitT(t, repo, "checkout", "-q", main)
	gitT(t, repo, "merge", "-q", "-s", "ours", "--no-edit", "side")
	if r := VerifyAnchorHistory(ch, an); r.Verdict != HistViolated {
		t.Fatalf("a side-branch regression merged TREESAME was hidden: %s %v", r.Verdict, r.Lines)
	}
}

// Golden-FALSE for the DAG walk: a legitimate branch that ADVANCES the anchor
// and is merged back must still hold.
func TestFix1_HistoryLegitimateBranchHolds(t *testing.T) {
	repo, ch, an, commit := historyRepo(t)
	commit(2, digestAt(t, ch, 2))
	main := gitOut(t, repo, "rev-parse", "--abbrev-ref", "HEAD")
	gitT(t, repo, "checkout", "-q", "-b", "side")
	commit(3, digestAt(t, ch, 3))
	gitT(t, repo, "checkout", "-q", main)
	gitT(t, repo, "merge", "-q", "--no-ff", "--no-edit", "side")
	withRemote(t, repo) // HOLDS needs a witness (review T015b I3)
	if r := VerifyAnchorHistory(ch, an); r.Verdict != HistHolds {
		t.Fatalf("a forward branch merge was refused: %s %v", r.Verdict, r.Lines)
	}
}
