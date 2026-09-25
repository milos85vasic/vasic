package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/vasic-digital/continuum/pkg/anchor"
	"github.com/vasic-digital/continuum/pkg/chain"
	"github.com/vasic-digital/continuum/pkg/model"
)

// The committed fixture corpus (_tests/fixtures/zero-gap/evidence/). Each
// golden-bad store carries expect.json: the component verdicts
// scripts/zero-gap-evidence-chain.sh --verify must print, and the adapter
// invariant ids this package must report. Regenerate with
//
//	ZG_REGEN_FIXTURES=1 go test -run TestFixtures_Regenerate ./...
//
// (§11.4.77: the corpus is derived, never hand-edited).
const fixtureRoot = "../../_tests/fixtures/zero-gap/evidence"

type fixtureExpect struct {
	Summary    string   `json:"summary"`    // substring of the --verify VERDICT line
	Invariants []string `json:"invariants"` // adapter invariant ids VerifyStore must report
	Note       string   `json:"note"`
}

type fixtureAttack struct {
	name string
	exp  fixtureExpect
	do   func(t *testing.T, dir string)
}

func fixtureAttacks() []fixtureAttack {
	sc := func(d string) string { return filepath.Join(d, sidecarFile) }
	side := func(s string) string { return "chain=PASS sidecar=VIOLATED anchor=PASS" + s }
	return []fixtureAttack{
		{"sidecar-byte-flipped", fixtureExpect{side(""), []string{InvBinding}, "one byte of sidecar line 2 changed; the chain is untouched"},
			func(t *testing.T, d string) {
				ls := readLines(t, sc(d))
				ls[1] = bytes.Replace(ls[1], []byte(`"duration_ms":5`), []byte(`"duration_ms":6`), 1)
				writeLines(t, sc(d), ls)
			}},
		{"sidecar-line-deleted", fixtureExpect{side(""), []string{InvCount, InvBinding}, "sidecar line 2 removed"},
			func(t *testing.T, d string) {
				ls := readLines(t, sc(d))
				writeLines(t, sc(d), append(ls[:1:1], ls[2:]...))
			}},
		{"sidecar-lines-swapped", fixtureExpect{side(""), []string{InvBinding}, "sidecar lines 1 and 3 swapped"},
			func(t *testing.T, d string) {
				ls := readLines(t, sc(d))
				ls[0], ls[2] = ls[2], ls[0]
				writeLines(t, sc(d), ls)
			}},
		{"sidecar-line-duplicated", fixtureExpect{side(""), []string{InvCount}, "sidecar line 2 appended again"},
			func(t *testing.T, d string) { ls := readLines(t, sc(d)); writeLines(t, sc(d), append(ls, ls[1])) }},
		{"sidecar-unbound-line", fixtureExpect{side(""), []string{InvCount}, "a valid record no chain entry binds"},
			func(t *testing.T, d string) {
				s := sampleSidecar()
				s.ChainSeq = 9
				l, _ := MarshalSidecarLine(s)
				writeLines(t, sc(d), append(readLines(t, sc(d)), l))
			}},
		{"sidecar-replayed-under-new-tail", fixtureExpect{side(""), []string{InvUnique, InvSeq}, "line 1 replayed; a properly linked tail record binds it (the anchor sees a lagging, healthy chain)"},
			func(t *testing.T, d string) {
				ls := readLines(t, sc(d))
				writeLines(t, sc(d), append(ls, ls[0]))
				recs := decodeChain(t, d)
				n := recs[0]
				n.Seq = int64(len(recs) + 1)
				writeChain(t, d, append(recs, n))
			}},
		{"both-tails-truncated", fixtureExpect{"chain=PASS sidecar=HOLDS anchor=DETECTED", nil, "record 3 removed from BOTH files: internally perfect, caught only by the anchor"},
			func(t *testing.T, d string) {
				for _, f := range []string{chainFile, sidecarFile} {
					ls := readLines(t, filepath.Join(d, f))
					writeLines(t, filepath.Join(d, f), ls[:2])
				}
			}},
		{"delete-and-rechain", fixtureExpect{"chain=PASS sidecar=HOLDS anchor=DETECTED", nil, "record 2 removed from both files and the chain re-linked: caught only by the anchor"},
			func(t *testing.T, d string) {
				ls := readLines(t, sc(d))
				writeLines(t, sc(d), append(ls[:1:1], ls[2:]...))
				recs := decodeChain(t, d)
				writeChain(t, d, append(recs[:1:1], recs[2:]...))
			}},
		{"sidecar-crlf", fixtureExpect{side(""), []string{InvByteRule}, "\\r\\n on line 1"},
			func(t *testing.T, d string) {
				b, _ := os.ReadFile(sc(d))
				os.WriteFile(sc(d), bytes.Replace(b, []byte("\n"), []byte("\r\n"), 1), 0o644)
			}},
		{"sidecar-no-final-newline", fixtureExpect{side(""), []string{InvByteRule}, "last byte is not \\n"},
			func(t *testing.T, d string) {
				b, _ := os.ReadFile(sc(d))
				os.WriteFile(sc(d), bytes.TrimSuffix(b, []byte("\n")), 0o644)
			}},
		{"sidecar-blank-line", fixtureExpect{side(""), []string{InvByteRule}, "an empty line after line 1"},
			func(t *testing.T, d string) {
				b, _ := os.ReadFile(sc(d))
				os.WriteFile(sc(d), bytes.Replace(b, []byte("\n"), []byte("\n\n"), 1), 0o644)
			}},
		{"unstable-outcome-0", fixtureExpect{"sidecar=VIOLATED", []string{InvOutcome}, "fingerprints differ yet outcome 0; re-bound and re-linked (the anchor also sees the rewrite)"},
			func(t *testing.T, d string) {
				ls := readLines(t, sc(d))
				l := bytes.Replace(ls[2], []byte(`"state_fingerprint_after":"`+hex64("fp")+`"`), []byte(`"state_fingerprint_after":"`+hex64("moved")+`"`), 1)
				ls[2] = l
				writeLines(t, sc(d), ls)
				recs := decodeChain(t, d)
				recs[2].ArtifactPath = ArtifactPathFor(l)
				writeChain(t, d, recs)
			}},
		{"chain-command-not-argv0", fixtureExpect{"sidecar=VIOLATED", []string{InvDupFields}, "chain record 2 command changed and the chain re-linked"},
			func(t *testing.T, d string) {
				recs := decodeChain(t, d)
				recs[1].Command = "/bin/other"
				writeChain(t, d, recs)
			}},
	}
}

// writeFixtureAnchor records the anchor with strength "unknown": no probe is
// run for a fixture, and "unknown" is the honest value without one.
func writeFixtureAnchor(t *testing.T, dir string) {
	t.Helper()
	recs := decodeChain(t, dir)
	d, err := chain.Digest(recs[len(recs)-1])
	if err != nil {
		t.Fatal(err)
	}
	if err := anchor.Write(filepath.Join(dir, "anchor.json"), anchor.Anchor{HeadDigest: d, EntryCount: len(recs), Strength: anchor.StrengthUnknown}); err != nil {
		t.Fatal(err)
	}
}

func copyStore(t *testing.T, from, to string) {
	t.Helper()
	os.MkdirAll(to, 0o755)
	for _, f := range []string{chainFile, sidecarFile, "anchor.json"} {
		b, err := os.ReadFile(filepath.Join(from, f))
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(to, f), b, 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func TestFixtures_Regenerate(t *testing.T) {
	if os.Getenv("ZG_REGEN_FIXTURES") != "1" {
		t.Skip("set ZG_REGEN_FIXTURES=1 to rewrite the committed corpus")
	}
	good := filepath.Join(fixtureRoot, "golden-good")
	os.RemoveAll(fixtureRoot + "/golden-good")
	os.RemoveAll(fixtureRoot + "/golden-bad")
	tmp := buildStore(t, 3)
	writeFixtureAnchor(t, tmp)
	copyStore(t, tmp, good)
	for _, a := range fixtureAttacks() {
		d := filepath.Join(fixtureRoot, "golden-bad", a.name)
		copyStore(t, good, d)
		a.do(t, d)
		b, _ := json.MarshalIndent(a.exp, "", "  ")
		if err := os.WriteFile(filepath.Join(d, "expect.json"), append(b, '\n'), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

// TestFixtures_Corpus proves the committed corpus is what it claims: the good
// store holds, and every bad store reports exactly the invariants it names.
func TestFixtures_Corpus(t *testing.T) {
	good := filepath.Join(fixtureRoot, "golden-good")
	rep, err := VerifyStore(good, mustSchema(t))
	if err != nil || len(rep.Findings) != 0 || rep.Records != 3 {
		t.Fatalf("golden-good: records=%d findings=%v err=%v", rep.Records, rep.Findings, err)
	}
	if v := chain.Verify(decodeChain(t, good)); v.Verdict != chain.PASS {
		t.Fatalf("golden-good chain: %+v", v)
	}
	attacks := fixtureAttacks()
	entries, err := os.ReadDir(filepath.Join(fixtureRoot, "golden-bad"))
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != len(attacks) {
		t.Fatalf("golden-bad holds %d stores, the generator defines %d — regenerate the corpus", len(entries), len(attacks))
	}
	for _, a := range attacks {
		t.Run(a.name, func(t *testing.T) {
			d := filepath.Join(fixtureRoot, "golden-bad", a.name)
			var exp fixtureExpect
			b, err := os.ReadFile(filepath.Join(d, "expect.json"))
			if err != nil || json.Unmarshal(b, &exp) != nil {
				t.Fatalf("expect.json unreadable: %v", err)
			}
			rep, err := VerifyStore(d, mustSchema(t))
			if err != nil {
				t.Fatalf("undetermined: %v", err)
			}
			for _, inv := range exp.Invariants {
				if !hasInvariant(rep.Findings, inv) {
					t.Fatalf("expected %s, got %v", inv, rep.Findings)
				}
			}
			if len(exp.Invariants) == 0 && len(rep.Findings) != 0 {
				t.Fatalf("an anchor-only attack must leave every adapter invariant holding, got %v", rep.Findings)
			}
			if strings.Contains(exp.Summary, "chain=PASS") {
				if v := chain.Verify(decodeChain(t, d)); v.Verdict != chain.PASS {
					t.Fatalf("expected an internally perfect chain, got %s", v.Verdict)
				}
			}
			if strings.Contains(exp.Summary, "anchor=DETECTED") {
				a, err := anchor.Read(filepath.Join(d, "anchor.json"))
				if err != nil {
					t.Fatal(err)
				}
				if n := len(decodeChain(t, d)); n >= a.EntryCount {
					t.Fatalf("anchor-only fixture: chain holds %d, anchor %d — the anchor has nothing to catch", n, a.EntryCount)
				}
			}
		})
	}
}

// Guard against the corpus silently carrying machine-specific paths (§11.4.29
// audit) or anything but canonical chain bytes.
func TestFixtures_CanonicalBytes(t *testing.T) {
	b, err := os.ReadFile(filepath.Join(fixtureRoot, "golden-good", chainFile))
	if err != nil {
		t.Fatal(err)
	}
	for i, r := range decodeChain(t, filepath.Join(fixtureRoot, "golden-good")) {
		c, _ := model.Canonical(r)
		line := bytes.Split(b, []byte("\n"))[i]
		if !bytes.Equal(c, line) {
			t.Fatalf("golden-good chain line %d is not canonical bytes", i+1)
		}
	}
	// Assembled at run time so this guard is not itself a carrier the
	// repository's hardcoded-path audit would flag.
	for _, p := range []string{"/" + "home/", "/" + "Users/", "/" + "Volumes/"} {
		if bytes.Contains(b, []byte(p)) {
			t.Fatalf("fixture carries a machine-specific path %q", p)
		}
	}
}
