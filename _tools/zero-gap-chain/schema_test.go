package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func validLine(t *testing.T) []byte {
	t.Helper()
	b, err := MarshalSidecarLine(sampleSidecar())
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	return b
}

func TestSchema_ValidLineAccepted(t *testing.T) {
	if v := mustSchema(t).ValidateLine(validLine(t)); len(v) != 0 {
		t.Fatalf("a valid line was refused: %v", v)
	}
}

func TestSchema_Refusals(t *testing.T) {
	s := mustSchema(t)
	good := validLine(t)
	cases := map[string][]byte{
		"missing required":      bytes.Replace(good, []byte(`"check_id":"c1",`), nil, 1),
		"unknown field":         bytes.Replace(good, []byte(`{"chain_seq"`), []byte(`{"extra":1,"chain_seq"`), 1),
		"argv as joined string": bytes.Replace(good, []byte(`"argv":["/bin/echo","a \"quoted\" <b>&c"]`), []byte(`"argv":"/bin/echo x"`), 1),
		"empty argv":            bytes.Replace(good, []byte(`"argv":["/bin/echo","a \"quoted\" <b>&c"]`), []byte(`"argv":[]`), 1),
		"outcome out of enum":   bytes.Replace(good, []byte(`"outcome":0`), []byte(`"outcome":3`), 1),
		"digest not 64 hex":     bytes.Replace(good, []byte(`"stdout_digest":"`), []byte(`"stdout_digest":"Z`), 1),
		"bad item id":           bytes.Replace(good, []byte(`"item_id":"ATM-101"`), []byte(`"item_id":"atm-1"`), 1),
		"negative bytes":        bytes.Replace(good, []byte(`"stdout_bytes":1`), []byte(`"stdout_bytes":-1`), 1),
		"exit as string":        bytes.Replace(good, []byte(`"exit_status":0`), []byte(`"exit_status":"0"`), 1),
		"exit not integer":      bytes.Replace(good, []byte(`"exit_status":0`), []byte(`"exit_status":0.5`), 1),
		"bool as string":        bytes.Replace(good, []byte(`"stream_truncated":false`), []byte(`"stream_truncated":"false"`), 1),
		"ts not date-time":      bytes.Replace(good, []byte(`"ts":"2026-09-25T10:00:00Z"`), []byte(`"ts":"yesterday"`), 1),
		"population enum":       bytes.Replace(good, []byte(`"population_kind":"source"`), []byte(`"population_kind":"vibes"`), 1),
		"verdict_role enum":     bytes.Replace(good, []byte(`"verdict_role":"author"`), []byte(`"verdict_role":"judge"`), 1),
		"not an object":         []byte(`[1,2]`),
		"not json":              []byte(`{"chain_seq":`),
		"two values":            append(append([]byte{}, good...), []byte(` {}`)...),
		// a reader keeps only the LAST duplicate, so the bound bytes would say
		// outcome 0 while a decoder reads outcome 2 (mutation M20 survived until this)
		"duplicate key": bytes.Replace(good, []byte(`"outcome":0`), []byte(`"outcome":0,"outcome":2`), 1),
	}
	for name, line := range cases {
		if bytes.Equal(line, good) {
			t.Fatalf("%s: the mutation did not change the line — the case tests nothing", name)
		}
		if v := s.ValidateLine(line); len(v) == 0 {
			t.Errorf("%s: accepted %s", name, line)
		}
	}
}

// A schema keyword the interpreter does not understand must refuse to load:
// silently ignoring it would accept records the contract forbids.
func TestSchema_UnsupportedKeywordFailsClosed(t *testing.T) {
	b, err := os.ReadFile(schemaPath)
	if err != nil {
		t.Fatal(err)
	}
	mut := strings.Replace(string(b), `"minItems": 1,`, `"minItems": 1, "uniqueItems": true,`, 1)
	if mut == string(b) {
		t.Fatal("mutation anchor not found in the schema — the case tests nothing")
	}
	p := filepath.Join(t.TempDir(), "s.json")
	if err := os.WriteFile(p, []byte(mut), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadSchema(p); err == nil {
		t.Fatal("a schema carrying an unsupported keyword loaded — the validator would silently skip it")
	}
	if _, err := LoadSchema(filepath.Join(t.TempDir(), "absent.json")); err == nil {
		t.Fatal("an absent schema loaded")
	}
}
