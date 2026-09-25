package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"testing"

	"github.com/vasic-digital/continuum/pkg/chain"
)

func TestAppend_GenesisChainingAndBinding(t *testing.T) {
	dir := buildStore(t, 3)
	recs := decodeChain(t, dir)
	if len(recs) != 3 {
		t.Fatalf("chain holds %d records, want 3", len(recs))
	}
	if recs[0].PrevDigest != "" {
		t.Fatalf("genesis prev_digest = %q, want the empty string", recs[0].PrevDigest)
	}
	for i := 1; i < len(recs); i++ {
		d, err := chain.Digest(recs[i-1])
		if err != nil {
			t.Fatal(err)
		}
		if recs[i].PrevDigest != d {
			t.Fatalf("record %d prev_digest is not the upstream digest of record %d", i+1, i)
		}
	}
	if rep := chain.Verify(recs); rep.Verdict != chain.PASS {
		t.Fatalf("upstream chain.Verify on our store: %v %+v", rep.Verdict, rep.Findings)
	}
	lines := readLines(t, filepath.Join(dir, sidecarFile))
	if len(lines) != 3 {
		t.Fatalf("sidecar holds %d lines, want 3", len(lines))
	}
	for i := range recs {
		if recs[i].Seq != int64(i+1) {
			t.Fatalf("record %d seq = %d, want %d (upstream corpus numbers from 1)", i+1, recs[i].Seq, i+1)
		}
		if recs[i].ArtifactPath != ArtifactPathFor(lines[i]) {
			t.Fatalf("record %d artifact_path does not bind sidecar line %d", i+1, i+1)
		}
		var s Sidecar
		if err := json.Unmarshal(lines[i], &s); err != nil {
			t.Fatal(err)
		}
		if s.ChainSeq != recs[i].Seq {
			t.Fatalf("sidecar chain_seq %d != chain seq %d", s.ChainSeq, recs[i].Seq)
		}
	}
}

// The chain file must be exactly what the upstream verifier reads: nine fields,
// unknown fields refused by chain.Decode (DisallowUnknownFields).
func TestAppend_ChainFileIsVerifierNative(t *testing.T) {
	dir := buildStore(t, 2)
	for i, l := range readLines(t, filepath.Join(dir, chainFile)) {
		var m map[string]json.RawMessage
		if err := json.Unmarshal(l, &m); err != nil {
			t.Fatal(err)
		}
		if len(m) != 9 {
			t.Fatalf("chain line %d carries %d fields, want exactly 9: %s", i+1, len(m), l)
		}
	}
	decodeChain(t, dir) // fails the test on any unknown field
}

func TestAppend_CommandIsArgv0AndExitStatusParsed(t *testing.T) {
	dir := t.TempDir()
	req := baseRequest(t, dir, 1)
	req.Argv = []string{"/usr/bin/env", "a b", `c"d`}
	req.Raw.ExitStatus = "1"
	req.CheckVerdict = 1
	res, err := Append(req)
	if err != nil {
		t.Fatal(err)
	}
	if res.Record.Command != "/usr/bin/env" {
		t.Fatalf("command = %q, want argv[0]", res.Record.Command)
	}
	if res.Record.ExitStatus != 1 || res.Outcome != 1 {
		t.Fatalf("exit/outcome = %d/%d, want 1/1", res.Record.ExitStatus, res.Outcome)
	}
}

func TestAppend_NonCanonicalExitRefusedNotDefaulted(t *testing.T) {
	for _, bad := range []string{"007", "+0", "", "nope"} {
		dir := t.TempDir()
		req := baseRequest(t, dir, 1)
		req.Raw.ExitStatus = bad
		if _, err := Append(req); err == nil {
			t.Fatalf("exit_status %q accepted — a status the adapter had to interpret is one it could get wrong", bad)
		}
		if _, err := os.Stat(filepath.Join(dir, chainFile)); err == nil {
			if b, _ := os.ReadFile(filepath.Join(dir, chainFile)); len(b) > 0 {
				t.Fatalf("a refused append still wrote %d chain bytes", len(b))
			}
		}
	}
}

func TestAppend_OutcomeIsTwoWheneverFingerprintsDiffer(t *testing.T) {
	for _, verdict := range []int{0, 1, 2} {
		dir := t.TempDir()
		req := baseRequest(t, dir, 1)
		req.FpAfter = hex64("moved")
		req.CheckVerdict = verdict
		res, err := Append(req)
		if err != nil {
			t.Fatal(err)
		}
		if res.Outcome != 2 {
			t.Fatalf("verdict %d with drifted fingerprint recorded outcome %d, want 2 (UNSTABLE)", verdict, res.Outcome)
		}
	}
	dir := t.TempDir()
	req := baseRequest(t, dir, 1)
	req.CheckVerdict = 1
	if res, err := Append(req); err != nil || res.Outcome != 1 {
		t.Fatalf("stable fingerprint must keep the check's own verdict: outcome=%d err=%v", res.Outcome, err)
	}
}

func TestAppend_RefusesBadInputs(t *testing.T) {
	mut := map[string]func(*AppendRequest){
		"verdict out of range": func(r *AppendRequest) { r.CheckVerdict = 7 },
		"tier outside set":     func(r *AppendRequest) { r.IndependenceTier = "bogus" },
		"class outside set":    func(r *AppendRequest) { r.EvidenceClass = "vibes" },
		"empty session":        func(r *AppendRequest) { r.Session = "" },
		"empty argv":           func(r *AppendRequest) { r.Argv = nil },
		"bad fingerprint":      func(r *AppendRequest) { r.FpBefore = "abc" },
		"bad population":       func(r *AppendRequest) { r.PopulationKind = "air" },
		"invalid utf8 argv":    func(r *AppendRequest) { r.Argv = []string{"/bin/x", "\xff"} },
		"no schema":            func(r *AppendRequest) { r.Schema = nil },
		"empty stream ref":     func(r *AppendRequest) { r.StreamRef = "" },
	}
	for name, m := range mut {
		dir := t.TempDir()
		req := baseRequest(t, dir, 1)
		m(&req)
		if _, err := Append(req); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestAppend_RedactedOverrideRecorded(t *testing.T) {
	dir := t.TempDir()
	req := baseRequest(t, dir, 1)
	req.RedactedOverride = true
	if _, err := Append(req); err != nil {
		t.Fatal(err)
	}
	var s Sidecar
	if err := json.Unmarshal(readLines(t, filepath.Join(dir, sidecarFile))[0], &s); err != nil {
		t.Fatal(err)
	}
	if !s.StreamRedacted {
		t.Fatal("the adapter redacted a stream but the record says stream_redacted=false")
	}
}

// Extending a tampered store would seal the tamper under a fresh, valid link.
func TestAppend_RefusesInconsistentStore(t *testing.T) {
	dir := buildStore(t, 2)
	sc := filepath.Join(dir, sidecarFile)
	lines := readLines(t, sc)
	writeLines(t, sc, append(lines, lines[0]))
	before, _ := os.ReadFile(filepath.Join(dir, chainFile))
	if _, err := Append(baseRequest(t, dir, 3)); err == nil {
		t.Fatal("appended to a store whose sidecar holds an unbound line")
	}
	after, _ := os.ReadFile(filepath.Join(dir, chainFile))
	if !bytes.Equal(before, after) {
		t.Fatal("a refused append modified the chain")
	}
}

func TestAppend_ConcurrentAppendsAreSerialised(t *testing.T) {
	dir := t.TempDir()
	const n = 12
	var wg sync.WaitGroup
	errs := make(chan error, n)
	reqs := make([]AppendRequest, n)
	for i := range reqs {
		reqs[i] = baseRequest(t, dir, i+1)
	}
	for i := range reqs {
		wg.Add(1)
		go func(r AppendRequest) {
			defer wg.Done()
			if _, err := Append(r); err != nil {
				errs <- err
			}
		}(reqs[i])
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		t.Fatalf("concurrent append: %v", err)
	}
	rep, err := VerifyStore(dir, mustSchema(t))
	if err != nil || len(rep.Findings) != 0 || rep.Records != n {
		t.Fatalf("after %d concurrent appends: records=%d findings=%v err=%v", n, rep.Records, rep.Findings, err)
	}
	if v := chain.Verify(decodeChain(t, dir)); v.Verdict != chain.PASS {
		t.Fatalf("concurrent appends broke the chain: %+v", v)
	}
}
