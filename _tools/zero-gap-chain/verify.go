package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"

	"github.com/vasic-digital/continuum/pkg/chain"
	"github.com/vasic-digital/continuum/pkg/model"
)

// Invariant ids (data-model.md "Adapter invariants T013/T014 MUST test").
// The upstream verifier NEVER reads the sidecar (research.md T001: changing
// `outcome` in a sidecar line still gave `chain verify` rc 0), so these checks
// are this adapter's to make — the chain walk itself stays upstream's.
const (
	InvByteRule   = "I1-byte-rule"
	InvCount      = "I2-line-count"
	InvBinding    = "I3-positional-binding"
	InvSeq        = "I4-chain-seq"
	InvUnique     = "I5-artifact-path-unique"
	InvDupFields  = "I6-duplicated-fields-agree"
	InvSchema     = "I7-schema"
	InvPathFormat = "I8-artifact-path-format"
	InvOutcome    = "I9-unstable-means-outcome-2"
	InvChainBytes = "I10-chain-byte-rule"
)

var artifactPat = regexp.MustCompile(`^sha256:[0-9a-f]{64}$`)

// Finding names one violated adapter invariant, at a 1-based line position.
type Finding struct {
	Invariant string
	Line      int
	Detail    string
}

// Report is the result of a COMPLETED walk. A walk that cannot complete returns
// an error instead — never an empty (clean-looking) report.
type Report struct {
	Records  int
	Findings []Finding
}

var errUndetermined = errors.New("could not determine")

// VerifyStore checks every adapter invariant BY POSITION: sidecar line i binds
// chain record i, never a set lookup (a set lookup would accept a swap).
func VerifyStore(dir string, schema *Schema) (Report, error) {
	if schema == nil {
		return Report{}, fmt.Errorf("%w: no evidence schema loaded", errUndetermined)
	}
	cb, err := os.ReadFile(filepath.Join(dir, chainFile))
	if err != nil {
		return Report{}, fmt.Errorf("%w: chain file unreadable (absent store?): %v", errUndetermined, err)
	}
	sb, err := os.ReadFile(filepath.Join(dir, sidecarFile))
	if err != nil {
		return Report{}, fmt.Errorf("%w: sidecar file unreadable: %v", errUndetermined, err)
	}
	recs, err := chain.Decode(cb)
	if err != nil {
		return Report{}, fmt.Errorf("%w: chain is not walkable: %v", errUndetermined, err)
	}
	rep := Report{Records: len(recs)}
	add := func(inv string, line int, f string, a ...any) {
		rep.Findings = append(rep.Findings, Finding{inv, line, fmt.Sprintf(f, a...)})
	}

	// I10 — the CHAIN's own bytes. Upstream decodes records, never bytes: a
	// chain missing its final newline, carrying CR, blank lines, trailing
	// whitespace or non-canonical spacing still walks clean, and an append onto
	// a missing final newline glues two records into one undecodable line
	// (review finding 1). Every non-blank line must be EXACTLY the canonical
	// bytes of the record it decodes to.
	if len(cb) > 0 {
		if cb[len(cb)-1] != '\n' {
			add(InvChainBytes, 0, "chain does not end with a newline (the next append would be glued onto the last record)")
		}
		ri := 0
		for i, l := range bytes.Split(bytes.TrimSuffix(cb, []byte("\n")), []byte("\n")) {
			if bytes.IndexByte(l, '\r') >= 0 {
				add(InvChainBytes, i+1, "chain line carries a carriage return")
			}
			if len(bytes.TrimSpace(l)) == 0 {
				add(InvChainBytes, i+1, "blank chain line")
				continue
			}
			if ri < len(recs) {
				canon, err := model.Canonical(recs[ri])
				if err != nil {
					return Report{}, fmt.Errorf("%w: canonicalising chain record %d: %v", errUndetermined, ri+1, err)
				}
				if !bytes.Equal(l, canon) {
					add(InvChainBytes, i+1, "chain line is not the canonical bytes of its record (spacing, key order or trailing whitespace)")
				}
			}
			ri++
		}
	}

	// I1 — the pinned byte rule.
	var lines [][]byte
	if len(sb) > 0 {
		if sb[len(sb)-1] != '\n' {
			add(InvByteRule, 0, "sidecar does not end with a newline (a torn or hand-edited write)")
		}
		lines = bytes.Split(bytes.TrimSuffix(sb, []byte("\n")), []byte("\n"))
	}
	for i, l := range lines {
		if bytes.IndexByte(l, '\r') >= 0 {
			add(InvByteRule, i+1, "line carries a carriage return (\\r is rejected; the hash covers the exact bytes)")
		}
		if len(l) == 0 {
			add(InvByteRule, i+1, "blank line (blank lines are rejected; they shift every later binding)")
		}
	}

	// I2 — equal counts.
	if len(lines) != len(recs) {
		add(InvCount, 0, "sidecar holds %d line(s) but the chain holds %d record(s)", len(lines), len(recs))
	}

	// I5 / I8 — over the whole chain.
	firstAt := map[string]int{}
	for i, r := range recs {
		if !artifactPat.MatchString(r.ArtifactPath) {
			add(InvPathFormat, i+1, "chain record seq %d artifact_path %q is not sha256: + 64 lowercase hex", r.Seq, r.ArtifactPath)
		}
		if j, seen := firstAt[r.ArtifactPath]; seen {
			add(InvUnique, i+1, "chain record seq %d binds the same sidecar bytes as record at line %d (a replayed line)", r.Seq, j)
		} else {
			firstAt[r.ArtifactPath] = i + 1
		}
	}

	// I3 / I4 / I6 / I7 / I9 — by position.
	n := len(lines)
	if len(recs) < n {
		n = len(recs)
	}
	for i := 0; i < n; i++ {
		l, r := lines[i], recs[i]
		if got := ArtifactPathFor(l); got != r.ArtifactPath {
			add(InvBinding, i+1, "sidecar line %d hashes to %s but chain record %d (seq %d) binds %s", i+1, short(got), i+1, r.Seq, short(r.ArtifactPath))
		}
		if v := schema.ValidateLine(l); len(v) > 0 {
			add(InvSchema, i+1, "%v", v)
			continue
		}
		var s Sidecar
		if err := json.Unmarshal(l, &s); err != nil {
			add(InvSchema, i+1, "does not decode as a sidecar record: %v", err)
			continue
		}
		if s.ChainSeq != r.Seq {
			add(InvSeq, i+1, "sidecar chain_seq %d != bound chain record seq %d", s.ChainSeq, r.Seq)
		}
		if s.Ts != r.Ts {
			add(InvDupFields, i+1, "ts: sidecar %q != chain %q", s.Ts, r.Ts)
		}
		if s.ExitStatus != r.ExitStatus {
			add(InvDupFields, i+1, "exit_status: sidecar %d != chain %d", s.ExitStatus, r.ExitStatus)
		}
		if s.EvidenceClass != r.EvidenceClass {
			add(InvDupFields, i+1, "evidence_class: sidecar %q != chain %q", s.EvidenceClass, r.EvidenceClass)
		}
		if s.IndependenceTier != r.IndependenceTier {
			add(InvDupFields, i+1, "independence_tier: sidecar %q != chain %q", s.IndependenceTier, r.IndependenceTier)
		}
		if len(s.Argv) == 0 || s.Argv[0] != r.Command {
			add(InvDupFields, i+1, "command: chain %q is not sidecar argv[0]", r.Command)
		}
		if s.FpBefore != s.FpAfter && s.Outcome != 2 {
			add(InvOutcome, i+1, "state fingerprint moved during the run yet outcome is %d (an unstable run carries no verdict; it must be 2)", s.Outcome)
		}
	}
	return rep, nil
}

func short(s string) string {
	if len(s) > 19 {
		return s[:19] + "…"
	}
	return s
}
