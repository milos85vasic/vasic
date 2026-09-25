package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/vasic-digital/continuum/pkg/chain"
	"github.com/vasic-digital/continuum/pkg/model"
)

// schemaPath is the contract this repository ships; tests validate against the
// real file, never a copy, so a drifting contract breaks the tests.
const schemaPath = "../../specs/010-zero-gap-verified-closure/contracts/evidence-record.schema.json"

func hex64(seed string) string {
	h := sha256.Sum256([]byte(seed))
	return hex.EncodeToString(h[:])
}

func mustSchema(t *testing.T) *Schema {
	t.Helper()
	s, err := LoadSchema(schemaPath)
	if err != nil {
		t.Fatalf("LoadSchema(%s): %v", schemaPath, err)
	}
	return s
}

// baseRequest is a fully-valid append request; tests mutate one field.
func baseRequest(t *testing.T, dir string, i int) AppendRequest {
	t.Helper()
	return AppendRequest{
		StoreDir: dir,
		Schema:   mustSchema(t),
		Session:  "test-session",
		Cwd:      "/srv/zg-fixture",
		Argv:     []string{"/bin/sh", "-c", "exit 0", "arg" + strconv.Itoa(i)},
		Raw: RawFields{
			Ts:           "2026-09-25T10:00:0" + strconv.Itoa(i%10) + "Z",
			ExitStatus:   "0",
			DurationMs:   int64(3 + i),
			StdoutDigest: hex64("out" + strconv.Itoa(i)),
			StderrDigest: hex64("err" + strconv.Itoa(i)),
			StdoutBytes:  int64(10 + i),
			StderrBytes:  0,
			StreamRef:    "/srv/zg-fixture/streams/run" + strconv.Itoa(i),
		},
		StreamRef:        "/srv/zg-fixture/streams/run" + strconv.Itoa(i),
		ItemID:           "ATM-" + strconv.Itoa(100+i),
		CheckID:          "check-" + strconv.Itoa(i),
		PopulationKind:   "source",
		VerdictRole:      "author",
		IndependenceTier: "instance",
		EvidenceClass:    "runtime",
		FpBefore:         hex64("fp"),
		FpAfter:          hex64("fp"),
		CheckVerdict:     0,
	}
}

// buildStore appends n healthy records and returns the store dir.
func buildStore(t *testing.T, n int) string {
	t.Helper()
	dir := t.TempDir()
	for i := 1; i <= n; i++ {
		if _, err := Append(baseRequest(t, dir, i)); err != nil {
			t.Fatalf("append %d: %v", i, err)
		}
	}
	return dir
}

func readLines(t *testing.T, path string) [][]byte {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	b = bytes.TrimSuffix(b, []byte("\n"))
	if len(b) == 0 {
		return nil
	}
	return bytes.Split(b, []byte("\n"))
}

func writeLines(t *testing.T, path string, lines [][]byte) {
	t.Helper()
	var buf bytes.Buffer
	for _, l := range lines {
		buf.Write(l)
		buf.WriteByte('\n')
	}
	if err := os.WriteFile(path, buf.Bytes(), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func decodeChain(t *testing.T, dir string) []chain.Record {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(dir, chainFile))
	if err != nil {
		t.Fatalf("read chain: %v", err)
	}
	recs, err := chain.Decode(b)
	if err != nil {
		t.Fatalf("decode chain: %v", err)
	}
	return recs
}

// writeChain re-chains records forward (recomputing every prev_digest with the
// upstream digest) and writes them in canonical bytes — what an attacker who
// understands the chain would do.
func writeChain(t *testing.T, dir string, recs []chain.Record) {
	t.Helper()
	prev := chain.GenesisPrev
	var buf bytes.Buffer
	for i := range recs {
		recs[i].PrevDigest = prev
		b, err := model.Canonical(recs[i])
		if err != nil {
			t.Fatal(err)
		}
		buf.Write(b)
		buf.WriteByte('\n')
		d, err := chain.Digest(recs[i])
		if err != nil {
			t.Fatal(err)
		}
		prev = d
	}
	if err := os.WriteFile(filepath.Join(dir, chainFile), buf.Bytes(), 0o644); err != nil {
		t.Fatal(err)
	}
}

func hasInvariant(fs []Finding, inv string) bool {
	for _, f := range fs {
		if f.Invariant == inv {
			return true
		}
	}
	return false
}
