package main

import "testing"

// FuzzValidateWireCapture: for any population/digest/kind the wire rule never panics and
// accepts a record only when the FR-017 shape holds (T063/T057).
func FuzzValidateWireCapture(f *testing.F) {
	f.Add("wire", hex64("a"), "http_response")
	f.Add("source", "", "")
	f.Add("wire", "", "")
	f.Add("process", hex64("b"), "socket")
	f.Fuzz(func(t *testing.T, pop, dig, kind string) {
		err := validateWireCapture(AppendRequest{PopulationKind: pop, WireCaptureDigest: dig, WireCaptureKind: kind})
		if err != nil {
			return
		}
		if pop == "wire" && !(hex64Pat.MatchString(dig) && (kind == "http_response" || kind == "socket")) {
			t.Fatalf("accepted a malformed wire capture: %q %q", dig, kind)
		}
		if pop != "wire" && (dig != "" || kind != "") {
			t.Fatalf("a %q record carried a capture", pop)
		}
	})
}
