package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReadCNAME(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "CNAME")
	if got := readCNAME(p, "fallback.example"); got != "fallback.example" {
		t.Errorf("missing file: got %q", got)
	}
	_ = os.WriteFile(p, []byte("  digital.vasic.dev \n"), 0o644)
	if got := readCNAME(p, "fallback.example"); got != "digital.vasic.dev" {
		t.Errorf("trimmed: got %q", got)
	}
	_ = os.WriteFile(p, []byte("\n"), 0o644)
	if got := readCNAME(p, "fallback.example"); got != "fallback.example" {
		t.Errorf("empty: got %q", got)
	}
}

func TestVasicDigitalDomainDefault(t *testing.T) {
	if got := sites["vasic.digital"].Domain; got != "digital.vasic.dev" {
		t.Errorf("fallback domain = %q", got)
	}
	if sites["vasic.digital"].Key != "vasic.digital" {
		t.Errorf("site key must stay internal vasic.digital")
	}
}
