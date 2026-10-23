package wi

import (
	"encoding/json"
	"strings"
	"testing"
)

// T063 (spec 010; FR-014, FR-017): a record that claims population_kind=wire
// MUST carry a wire-capture digest (an HTTP response or socket capture); a
// source-only or process measurement MUST NOT pose as wire evidence, and MUST
// NOT carry a capture digest it did not capture.

func goodRecordMap(t *testing.T) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal([]byte(fuzzGoodRecord), &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func parseMap(m map[string]any) error {
	b, _ := json.Marshal(m)
	_, err := ParseEvidenceRecord(b)
	return err
}

func TestWireRecordWithoutACaptureDigestIsRejected(t *testing.T) {
	m := goodRecordMap(t)
	m["population_kind"] = "wire"
	err := parseMap(m)
	if err == nil {
		t.Fatal("a wire record with no capture digest was accepted (FR-017)")
	}
	if !strings.Contains(err.Error(), "wire_capture_digest") {
		t.Fatalf("rejection does not name the missing field: %v", err)
	}
}

func TestWireRecordWithACaptureDigestAndKindIsAccepted(t *testing.T) {
	m := goodRecordMap(t)
	m["population_kind"] = "wire"
	m["wire_capture_digest"] = strings.Repeat("d", 64)
	m["wire_capture_kind"] = "http_response"
	if err := parseMap(m); err != nil {
		t.Fatalf("control: a well-formed wire record was refused: %v", err)
	}
	m["wire_capture_kind"] = "socket"
	if err := parseMap(m); err != nil {
		t.Fatalf("control: socket capture refused: %v", err)
	}
}

func TestWireCaptureFieldsAreMalformedWhenWrong(t *testing.T) {
	for name, mut := range map[string]func(m map[string]any){
		"digest-not-hex":     func(m map[string]any) { m["wire_capture_digest"] = "xyz" },
		"digest-upper":       func(m map[string]any) { m["wire_capture_digest"] = strings.Repeat("D", 64) },
		"kind-outside-set":   func(m map[string]any) { m["wire_capture_kind"] = "log_line" },
		"kind-missing":       func(m map[string]any) { delete(m, "wire_capture_kind") },
		"digest-all-zeroes?": func(m map[string]any) { m["wire_capture_digest"] = strings.Repeat("0", 64) },
	} {
		m := goodRecordMap(t)
		m["population_kind"] = "wire"
		m["wire_capture_digest"] = strings.Repeat("d", 64)
		m["wire_capture_kind"] = "http_response"
		mut(m)
		if err := parseMap(m); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestNonWireRecordMayNotClaimACapture(t *testing.T) {
	for _, kind := range []string{"source", "process"} {
		m := goodRecordMap(t)
		m["population_kind"] = kind
		m["wire_capture_digest"] = strings.Repeat("d", 64)
		m["wire_capture_kind"] = "http_response"
		if err := parseMap(m); err == nil {
			t.Errorf("%s record carrying a wire capture was accepted: it would pass as running-product evidence", kind)
		}
	}
}
