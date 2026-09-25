package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"unicode/utf8"
)

// Sidecar is the feature-010 evidence record — the RICH half of the two-file
// store (data-model.md "EvidenceRecord — TWO files"). The upstream verifier
// refuses any field outside its nine, so everything feature 010 needs lives
// here, bound to the chain by artifact_path = "sha256:<hex of this line>".
//
// Field order is the on-disk byte order. The chain binds to the EXACT stored
// bytes (the pinned byte rule), so this order is part of the byte contract even
// though the JSON schema does not constrain it.
type Sidecar struct {
	ChainSeq         int64    `json:"chain_seq"`
	Ts               string   `json:"ts"`
	Cwd              string   `json:"cwd"`
	Argv             []string `json:"argv"`
	ExitStatus       int      `json:"exit_status"`
	DurationMs       int64    `json:"duration_ms"`
	StdoutDigest     string   `json:"stdout_digest"`
	StderrDigest     string   `json:"stderr_digest"`
	StdoutBytes      int64    `json:"stdout_bytes"`
	StderrBytes      int64    `json:"stderr_bytes"`
	StreamRef        string   `json:"stream_ref"`
	StreamTruncated  bool     `json:"stream_truncated"`
	StreamRedacted   bool     `json:"stream_redacted"`
	ItemID           string   `json:"item_id"`
	CheckID          string   `json:"check_id"`
	FpBefore         string   `json:"state_fingerprint_before"`
	FpAfter          string   `json:"state_fingerprint_after"`
	PopulationKind   string   `json:"population_kind"`
	Outcome          int      `json:"outcome"`
	VerdictRole      string   `json:"verdict_role"`
	IndependenceTier string   `json:"independence_tier"`
	EvidenceClass    string   `json:"evidence_class"`
}

var errNotUTF8 = errors.New("not valid UTF-8")

// MarshalSidecarLine renders the exact stored line bytes: compact JSON, no HTML
// escaping, no trailing newline.
//
// Invalid UTF-8 is REFUSED rather than encoded: encoding/json would silently
// replace the bytes with U+FFFD, and a record whose argv is not the argv that
// ran describes a different command while claiming to describe this one.
func MarshalSidecarLine(s Sidecar) ([]byte, error) {
	strs := append([]string{s.Ts, s.Cwd, s.StreamRef, s.ItemID, s.CheckID}, s.Argv...)
	for _, v := range strs {
		if !utf8.ValidString(v) {
			return nil, fmt.Errorf("sidecar field value %q is %w; JSON would alter it", v, errNotUTF8)
		}
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(s); err != nil {
		return nil, err
	}
	return bytes.TrimRight(buf.Bytes(), "\n"), nil
}

// ArtifactPathFor is the binding value the chain record carries for a sidecar
// line: "sha256:" + lowercase hex of the EXACT line bytes. The caller passes the
// line WITHOUT its terminating newline — the byte rule excludes it.
func ArtifactPathFor(line []byte) string {
	h := sha256.Sum256(line)
	return "sha256:" + hex.EncodeToString(h[:])
}
