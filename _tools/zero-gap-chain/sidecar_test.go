package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"testing"
)

func sampleSidecar() Sidecar {
	return Sidecar{
		ChainSeq: 1, Ts: "2026-09-25T10:00:00Z", Cwd: "/srv/zg-fixture",
		Argv: []string{"/bin/echo", "a \"quoted\" <b>&c"}, ExitStatus: 0, DurationMs: 5,
		StdoutDigest: hex64("o"), StderrDigest: hex64("e"), StdoutBytes: 1, StderrBytes: 0,
		StreamRef: "/srv/zg-fixture/streams/r1", ItemID: "ATM-101", CheckID: "c1",
		FpBefore: hex64("fp"), FpAfter: hex64("fp"), PopulationKind: "source", Outcome: 0,
		VerdictRole: "author", IndependenceTier: "instance", EvidenceClass: "runtime",
	}
}

func TestMarshalSidecarLine_DeterministicCompactNoNewline(t *testing.T) {
	a, err := MarshalSidecarLine(sampleSidecar())
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	b, err := MarshalSidecarLine(sampleSidecar())
	if err != nil {
		t.Fatalf("marshal 2: %v", err)
	}
	if !bytes.Equal(a, b) {
		t.Fatalf("not deterministic:\n%s\n%s", a, b)
	}
	if bytes.ContainsAny(a, "\n\r") {
		t.Fatalf("line carries a newline/CR: %q", a)
	}
	if !bytes.HasPrefix(a, []byte(`{"chain_seq":1,"ts":`)) {
		t.Fatalf("field order not the declared byte order: %s", a)
	}
	var back Sidecar
	if err := json.Unmarshal(a, &back); err != nil || back.Argv[1] != sampleSidecar().Argv[1] {
		t.Fatalf("argv did not round-trip exactly: %v %q", err, back.Argv)
	}
}

func TestMarshalSidecarLine_RefusesInvalidUTF8(t *testing.T) {
	s := sampleSidecar()
	s.Argv = []string{"/bin/echo", "\xff\xfe"}
	if _, err := MarshalSidecarLine(s); err == nil {
		t.Fatal("invalid UTF-8 argv was accepted: JSON would silently replace the bytes, so the record would not describe what ran")
	}
	s = sampleSidecar()
	s.Cwd = "/srv/\xff"
	if _, err := MarshalSidecarLine(s); err == nil {
		t.Fatal("invalid UTF-8 cwd was accepted")
	}
}

func TestArtifactPathFor_FormatAndExcludesNewline(t *testing.T) {
	line := []byte(`{"x":1}`)
	h := sha256.Sum256(line)
	want := "sha256:" + hex.EncodeToString(h[:])
	if got := ArtifactPathFor(line); got != want {
		t.Fatalf("ArtifactPathFor = %q, want %q", got, want)
	}
	if ArtifactPathFor(append(line, '\n')) == want {
		t.Fatal("the trailing newline changed nothing — the byte rule (hash excludes \\n) cannot be distinguished")
	}
}
