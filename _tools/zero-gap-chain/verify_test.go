package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/vasic-digital/continuum/pkg/chain"
)

// Invariant ids — the names every finding MUST carry, so an operator reading a
// verdict knows WHICH contract broke (data-model.md "Adapter invariants").
const (
	iByteRule   = "I1-byte-rule"
	iCount      = "I2-line-count"
	iBinding    = "I3-positional-binding"
	iSeq        = "I4-chain-seq"
	iUnique     = "I5-artifact-path-unique"
	iDupFields  = "I6-duplicated-fields-agree"
	iSchema     = "I7-schema"
	iPathFormat = "I8-artifact-path-format"
	iOutcome    = "I9-unstable-means-outcome-2"
)

func verifyDir(t *testing.T, dir string) Report {
	t.Helper()
	rep, err := VerifyStore(dir, mustSchema(t))
	if err != nil {
		t.Fatalf("VerifyStore returned undetermined on a readable store: %v", err)
	}
	return rep
}

func TestVerify_HealthyAndEmptyStoresHold(t *testing.T) {
	rep := verifyDir(t, buildStore(t, 4))
	if len(rep.Findings) != 0 || rep.Records != 4 {
		t.Fatalf("healthy store: records=%d findings=%v", rep.Records, rep.Findings)
	}
	empty := t.TempDir()
	for _, f := range []string{chainFile, sidecarFile} {
		if err := os.WriteFile(filepath.Join(empty, f), nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if rep := verifyDir(t, empty); len(rep.Findings) != 0 || rep.Records != 0 {
		t.Fatalf("empty store: %+v", rep)
	}
}

// Each sidecar attack from data-model.md, applied to a copy of a healthy store.
func TestVerify_SidecarAttacks(t *testing.T) {
	type attack struct {
		name string
		want []string
		do   func(t *testing.T, dir string)
	}
	sc := func(dir string) string { return filepath.Join(dir, sidecarFile) }
	attacks := []attack{
		{"flip one byte", []string{iBinding}, func(t *testing.T, dir string) {
			ls := readLines(t, sc(dir))
			ls[1] = bytes.Replace(ls[1], []byte(`"duration_ms":5`), []byte(`"duration_ms":6`), 1)
			writeLines(t, sc(dir), ls)
		}},
		{"delete a line", []string{iCount, iBinding}, func(t *testing.T, dir string) {
			ls := readLines(t, sc(dir))
			writeLines(t, sc(dir), append(ls[:1:1], ls[2:]...))
		}},
		{"swap two lines", []string{iBinding}, func(t *testing.T, dir string) {
			ls := readLines(t, sc(dir))
			ls[0], ls[2] = ls[2], ls[0]
			writeLines(t, sc(dir), ls)
		}},
		{"duplicate a line", []string{iCount}, func(t *testing.T, dir string) {
			ls := readLines(t, sc(dir))
			writeLines(t, sc(dir), append(ls, ls[1]))
		}},
		{"add an unbound line", []string{iCount}, func(t *testing.T, dir string) {
			s := sampleSidecar()
			s.ChainSeq = 5
			l, _ := MarshalSidecarLine(s)
			writeLines(t, sc(dir), append(readLines(t, sc(dir)), l))
		}},
		{"replay a line under a new tail record", []string{iUnique, iSeq}, func(t *testing.T, dir string) {
			ls := readLines(t, sc(dir))
			writeLines(t, sc(dir), append(ls, ls[0]))
			recs := decodeChain(t, dir)
			nr := recs[0]
			nr.Seq = int64(len(recs) + 1)
			writeChain(t, dir, append(recs, nr)) // properly chained: chain-alone PASSes
		}},
		{"CRLF line ending", []string{iByteRule}, func(t *testing.T, dir string) {
			b, _ := os.ReadFile(sc(dir))
			os.WriteFile(sc(dir), bytes.Replace(b, []byte("\n"), []byte("\r\n"), 1), 0o644)
		}},
		{"no final newline", []string{iByteRule}, func(t *testing.T, dir string) {
			b, _ := os.ReadFile(sc(dir))
			os.WriteFile(sc(dir), bytes.TrimSuffix(b, []byte("\n")), 0o644)
		}},
		{"blank line", []string{iByteRule}, func(t *testing.T, dir string) {
			b, _ := os.ReadFile(sc(dir))
			os.WriteFile(sc(dir), bytes.Replace(b, []byte("\n"), []byte("\n\n"), 1), 0o644)
		}},
	}
	for _, a := range attacks {
		t.Run(a.name, func(t *testing.T) {
			dir := buildStore(t, 3)
			before := verifyDir(t, dir)
			if len(before.Findings) != 0 {
				t.Fatalf("control store not healthy: %v", before.Findings)
			}
			a.do(t, dir)
			rep := verifyDir(t, dir)
			for _, inv := range a.want {
				if !hasInvariant(rep.Findings, inv) {
					t.Fatalf("attack %q: invariant %s not reported; findings=%v", a.name, inv, rep.Findings)
				}
			}
		})
	}
}

// Rebind a mutated sidecar line: recompute its artifact_path in the chain and
// re-chain forward, so the positional binding HOLDS and only the named
// invariant can catch the change.
func rebindLine(t *testing.T, dir string, i int, newLine []byte) {
	t.Helper()
	ls := readLines(t, filepath.Join(dir, sidecarFile))
	ls[i] = newLine
	writeLines(t, filepath.Join(dir, sidecarFile), ls)
	recs := decodeChain(t, dir)
	recs[i].ArtifactPath = ArtifactPathFor(newLine)
	writeChain(t, dir, recs)
}

func TestVerify_ReboundInvariants(t *testing.T) {
	t.Run("outcome 0 recorded on an unstable run", func(t *testing.T) {
		dir := buildStore(t, 2)
		l := readLines(t, filepath.Join(dir, sidecarFile))[1]
		l = bytes.Replace(l, []byte(`"state_fingerprint_after":"`+hex64("fp")+`"`),
			[]byte(`"state_fingerprint_after":"`+hex64("moved")+`"`), 1)
		rebindLine(t, dir, 1, l)
		rep := verifyDir(t, dir)
		if !hasInvariant(rep.Findings, iOutcome) || hasInvariant(rep.Findings, iBinding) {
			t.Fatalf("want only %s, got %v", iOutcome, rep.Findings)
		}
	})
	t.Run("schema-invalid line", func(t *testing.T) {
		dir := buildStore(t, 2)
		l := readLines(t, filepath.Join(dir, sidecarFile))[0]
		rebindLine(t, dir, 0, bytes.Replace(l, []byte(`"outcome":0`), []byte(`"outcome":9`), 1))
		if rep := verifyDir(t, dir); !hasInvariant(rep.Findings, iSchema) {
			t.Fatalf("want %s, got %v", iSchema, rep.Findings)
		}
	})
	t.Run("chain_seq disagrees", func(t *testing.T) {
		dir := buildStore(t, 2)
		l := readLines(t, filepath.Join(dir, sidecarFile))[1]
		rebindLine(t, dir, 1, bytes.Replace(l, []byte(`"chain_seq":2`), []byte(`"chain_seq":7`), 1))
		if rep := verifyDir(t, dir); !hasInvariant(rep.Findings, iSeq) {
			t.Fatalf("want %s, got %v", iSeq, rep.Findings)
		}
	})
}

func TestVerify_DuplicatedFieldsMustAgree(t *testing.T) {
	muts := map[string]func(r *chain.Record){
		"ts":                func(r *chain.Record) { r.Ts = "2026-01-01T00:00:00Z" },
		"exit_status":       func(r *chain.Record) { r.ExitStatus = 9 },
		"evidence_class":    func(r *chain.Record) { r.EvidenceClass = "source" },
		"independence_tier": func(r *chain.Record) { r.IndependenceTier = "model" },
		"command":           func(r *chain.Record) { r.Command = "/bin/other" },
	}
	for name, m := range muts {
		t.Run(name, func(t *testing.T) {
			dir := buildStore(t, 2)
			recs := decodeChain(t, dir)
			m(&recs[1])
			writeChain(t, dir, recs) // re-chained: chain-alone PASSes
			rep := verifyDir(t, dir)
			if !hasInvariant(rep.Findings, iDupFields) {
				t.Fatalf("chain %s disagreeing with the sidecar was not reported: %v", name, rep.Findings)
			}
			found := false
			for _, f := range rep.Findings {
				if f.Invariant == iDupFields && strings.Contains(f.Detail, name) {
					found = true
				}
			}
			if !found {
				t.Fatalf("the finding does not name the field %q: %v", name, rep.Findings)
			}
		})
	}
}

func TestVerify_ArtifactPathFormat(t *testing.T) {
	for _, bad := range []string{"SHA256:", "sha256:" + strings.ToUpper(hex64("x")), "sha256:abc", hex64("x")} {
		dir := buildStore(t, 1)
		recs := decodeChain(t, dir)
		if strings.HasPrefix(bad, "SHA256:") {
			bad += hex64("x")
		}
		recs[0].ArtifactPath = bad
		writeChain(t, dir, recs)
		if rep := verifyDir(t, dir); !hasInvariant(rep.Findings, iPathFormat) {
			t.Fatalf("artifact_path %q not reported as malformed: %v", bad, rep.Findings)
		}
	}
}

// Could-not-determine states are errors, never an empty (clean) report.
func TestVerify_UndeterminedStates(t *testing.T) {
	absentSide := buildStore(t, 1)
	os.Remove(filepath.Join(absentSide, sidecarFile))
	absentChain := buildStore(t, 1)
	os.Remove(filepath.Join(absentChain, chainFile))
	torn := buildStore(t, 2)
	b, _ := os.ReadFile(filepath.Join(torn, chainFile))
	os.WriteFile(filepath.Join(torn, chainFile), b[:len(b)-20], 0o644)
	for name, dir := range map[string]string{
		"absent sidecar": absentSide, "absent chain": absentChain,
		"unwalkable chain": torn, "absent store": filepath.Join(t.TempDir(), "none"),
	} {
		if rep, err := VerifyStore(dir, mustSchema(t)); err == nil {
			t.Errorf("%s: reported a decided result %+v instead of undetermined", name, rep)
		}
	}
	if _, err := VerifyStore(buildStore(t, 1), nil); err == nil {
		t.Error("no schema: reported a decided result")
	}
}
