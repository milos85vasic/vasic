package main

import (
	"strings"
	"testing"
)

// T063/FR-017 at the sealing adapter: a wire record must carry the digest of
// its capture and the kind of capture; no other population may claim one. The
// contract file is loaded by the REAL interpreter (not a copy), because the
// first cut of the T063 schema edit used `allOf`, which this interpreter
// refuses by design — every recording then failed pre-flight.

func TestRealContractLoads(t *testing.T) {
	if _, err := LoadSchema(schemaPath); err != nil {
		t.Fatalf("the repository's own evidence contract does not load in the interpreter that enforces it: %v", err)
	}
}

func appendOne(t *testing.T, mod func(*AppendRequest)) error {
	t.Helper()
	dir := t.TempDir()
	r := baseRequest(t, dir, 1)
	mod(&r)
	_, err := Append(r)
	return err
}

func TestWireRecordWithoutCaptureIsRefused(t *testing.T) {
	err := appendOne(t, func(r *AppendRequest) { r.PopulationKind = "wire" })
	if err == nil || !strings.Contains(err.Error(), "wire_capture_digest") {
		t.Fatalf("a wire record with no capture digest was sealed or refused for the wrong reason: %v", err)
	}
}

func TestWireRecordWithCaptureIsSealedAndCarriesIt(t *testing.T) {
	dir := t.TempDir()
	r := baseRequest(t, dir, 1)
	r.PopulationKind = "wire"
	r.WireCaptureDigest = hex64("capture")
	r.WireCaptureKind = "http_response"
	res, err := Append(r)
	if err != nil {
		t.Fatalf("a wire record with a capture digest was refused: %v", err)
	}
	if !strings.Contains(string(res.SidecarLine), `"wire_capture_digest":"`+hex64("capture")+`"`) ||
		!strings.Contains(string(res.SidecarLine), `"wire_capture_kind":"http_response"`) {
		t.Fatalf("the sealed sidecar line lacks the capture fields: %s", res.SidecarLine)
	}
}

func TestNonWireRecordMayNotClaimACapture(t *testing.T) {
	for _, pk := range []string{"source", "process"} {
		err := appendOne(t, func(r *AppendRequest) {
			r.PopulationKind = pk
			r.WireCaptureDigest = hex64("x")
			r.WireCaptureKind = "socket"
		})
		if err == nil {
			t.Fatalf("a %s record claiming a wire capture was sealed", pk)
		}
	}
}

func TestWireCaptureShapeIsEnforced(t *testing.T) {
	cases := map[string]func(*AppendRequest){
		"digest-not-hex": func(r *AppendRequest) { r.WireCaptureDigest = "xyz" },
		"digest-upper":   func(r *AppendRequest) { r.WireCaptureDigest = strings.ToUpper(hex64("a")) },
		"all-zero":       func(r *AppendRequest) { r.WireCaptureDigest = strings.Repeat("0", 64) },
		"kind-outside":   func(r *AppendRequest) { r.WireCaptureKind = "log_line" },
		"kind-missing":   func(r *AppendRequest) { r.WireCaptureKind = "" },
	}
	for name, mod := range cases {
		err := appendOne(t, func(r *AppendRequest) {
			r.PopulationKind = "wire"
			r.WireCaptureDigest = hex64("c")
			r.WireCaptureKind = "http_response"
			mod(r)
		})
		if err == nil {
			t.Fatalf("%s: a malformed wire capture was sealed", name)
		}
	}
}
