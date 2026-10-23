package wi

// Feature 010, task T068 (FR-016, FR-018): chain-bound closure evidence.
//
// Until this binding, "closed" meant structurally consistent and self-asserted:
// the evidence files, timestamps, chain_seq values and actor names the validator
// checks were written by the same register and tool it checks, so an unsigned
// verifier record could be forged by editing a copy of the GREEN. The binding
// closes that: for every cited RED/GREEN/verifier record, sha256 of the record's
// bytes (the sidecar line, one trailing newline excluded) MUST equal the
// artifact_path of the chain record whose seq equals the record's chain_seq, in
// a chain store that scripts/zero-gap-evidence-chain.sh --verify passes; and the
// verifier record's chain author_session_id MUST differ from the GREEN's.

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// ChainBinder is a loaded chain store plus the verdict of the chain verifier.
type ChainBinder struct {
	Dir string
	// VerifyRC is the exit status of `zero-gap-evidence-chain.sh --verify` for
	// this store: 0 holds, 1 an alteration was DETECTED, 2 could not determine.
	// Anything but 0 means no record can be bound (a chain that does not verify
	// proves nothing about what it contains).
	VerifyRC     int
	VerifyDetail string
	rows         map[int64]chainRow
}

type chainRow struct {
	ArtifactPath string `json:"artifact_path"`
	Session      string `json:"author_session_id"`
	Seq          int64  `json:"seq"`
}

// DefaultChainStoreRel is the untracked store the adapter writes.
const DefaultChainStoreRel = ".remember/logs/zero-gap/evidence"

// LoadChainBinder reads <dir>/chain.jsonl. VerifyRC starts at 2 (not verified):
// the caller sets it from the real verifier.
func LoadChainBinder(dir string) (*ChainBinder, error) {
	f, err := os.Open(filepath.Join(dir, "chain.jsonl"))
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return nil, fmt.Errorf("chain store %s has no chain.jsonl: nothing can be bound (an absent store is never an intact one)", dir)
		}
		return nil, err
	}
	defer f.Close()
	b := &ChainBinder{Dir: dir, VerifyRC: 2, rows: map[int64]chainRow{}}
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for n := 1; sc.Scan(); n++ {
		if len(bytes.TrimSpace(sc.Bytes())) == 0 {
			continue
		}
		var r chainRow
		if err := json.Unmarshal(sc.Bytes(), &r); err != nil {
			return nil, fmt.Errorf("chain.jsonl line %d is not a chain record: %v", n, err)
		}
		if _, dup := b.rows[r.Seq]; dup {
			return nil, fmt.Errorf("chain.jsonl holds seq %d twice", r.Seq)
		}
		b.rows[r.Seq] = r
	}
	return b, sc.Err()
}

// RecordDigest is the binding digest of a record file: "sha256:" + hex of the
// bytes with ONE trailing newline removed (the adapter stores the line without it).
func RecordDigest(raw []byte) string {
	raw = bytes.TrimSuffix(raw, []byte("\n"))
	h := sha256.Sum256(raw)
	return "sha256:" + hex.EncodeToString(h[:])
}

// Bind checks a record's bytes against the chain record at its chain_seq and
// returns that chain record's author session.
func (b *ChainBinder) Bind(raw []byte, seq int64) (session string, err error) {
	r, ok := b.rows[seq]
	if !ok {
		return "", fmt.Errorf("chain_seq %d is not in the chain (%d record(s))", seq, len(b.rows))
	}
	if got := RecordDigest(raw); got != r.ArtifactPath {
		return "", fmt.Errorf("record bytes %s do not match chain record %d artifact_path %s (edited, copied or forged)", got[:19], seq, truncDigest(r.ArtifactPath))
	}
	return r.Session, nil
}

func truncDigest(s string) string {
	if len(s) > 19 {
		return s[:19] + "…"
	}
	return s
}

// ruleG13 — V-G13 (T068): every RED/GREEN/verifier record a closed item cites is
// bound to the evidence chain, and the verifier's session differs from the
// GREEN's. Runs only when a ChainBinder is supplied.
func (v *gapValidator) ruleG13(r gapRow, hist []histRow, verdicts []verdictRow, diary []diaryRow) {
	const rule = "V-G13"
	if v.o.Chain == nil {
		return
	}
	b := v.o.Chain
	switch b.VerifyRC {
	case 0:
	case 1:
		v.find(rule, r.id, "the evidence chain store %s FAILED verification (an alteration was DETECTED): no cited record can be bound%s", b.Dir, detailSuffix(b.VerifyDetail))
		return
	default:
		v.undet(rule, r.id, "the evidence chain store %s could not be verified (rc %d): closure evidence cannot be bound, which is not a pass%s", b.Dir, b.VerifyRC, detailSuffix(b.VerifyDetail))
		return
	}
	cut, ok := v.cutFor(r.id, hist, verdicts, diary)
	if !ok {
		return
	}
	type cite struct{ label, path string }
	var cites []cite
	for i, h := range hist {
		if i <= cut.idx {
			continue
		}
		switch {
		case hasPrefixStr(h.reason, "zero-gap:red-evidence"):
			cites = append(cites, cite{"RED", h.evid})
		case hasPrefixStr(h.reason, "zero-gap:green-evidence"):
			cites = append(cites, cite{"GREEN", h.evid})
		}
	}
	newest, _ := newestVerdictPerRole(verdicts, cut, v.o.AsOf)
	if i, ok := newest["verifier"]; ok && cut.fresh(verdicts[i]) {
		cites = append(cites, cite{"verifier", verdicts[i].evid})
	}
	sessions := map[string]string{}
	for _, c := range cites {
		e := v.evidence(c.path)
		if e.rec == nil {
			continue // missing / invalid / unreadable: V-G3 already reports it
		}
		full, err := v.resolve(c.path)
		if err != nil {
			continue
		}
		raw, err := os.ReadFile(full)
		if err != nil || int64(len(raw)) > MaxEvidenceBytes {
			v.undet(rule, r.id, "%s evidence %s could not be read for binding", c.label, c.path)
			continue
		}
		sess, err := b.Bind(raw, *e.rec.ChainSeq)
		if err != nil {
			v.find(rule, r.id, "%s evidence %s is not bound to the evidence chain: %v", c.label, c.path, err)
			continue
		}
		if c.label == "GREEN" || c.label == "verifier" {
			sessions[c.label] = sess
		}
	}
	if g, ok := sessions["GREEN"]; ok {
		if vs, ok := sessions["verifier"]; ok && g == vs {
			v.find(rule, r.id, "the verifier record and the GREEN record were produced in the same session %q; a verification is a separate actor's run (FR-018)", g)
		}
	}
}

func detailSuffix(s string) string {
	if s == "" {
		return ""
	}
	return ": " + s
}

func hasPrefixStr(s, p string) bool { return len(s) >= len(p) && s[:len(p)] == p }

// chainVerifyFn runs the chain verifier for a store; replaced only by unit tests
// that need a fixed verdict (the real script has its own paired proof).
var chainVerifyFn = defaultChainVerify

func defaultChainVerify(root, store string) (int, string) {
	script := filepath.Join(root, "scripts", "zero-gap-evidence-chain.sh")
	if _, err := os.Stat(script); err != nil {
		return 2, "the chain verifier " + script + " is absent"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "bash", script, "--verify", store)
	cmd.Dir = root
	out, err := cmd.CombinedOutput()
	rc := 0
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			rc = ee.ExitCode()
		} else {
			rc = 2
		}
	}
	last := ""
	for _, l := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if strings.HasPrefix(l, "VERDICT") {
			last = l
		}
	}
	if last == "" {
		last = fmt.Sprintf("verifier exited %d without a VERDICT line", rc)
	}
	return rc, last
}

// ResolveChainBinder loads the store (default <root>/DefaultChainStoreRel) and
// runs the chain verifier over it. A returned rc of 0 means the binder is usable;
// 1 means the verifier DETECTED an alteration, 2 that nothing could be determined
// (absent store, unrunnable verifier, anchor not yet committed). msg explains.
func ResolveChainBinder(root, store string) (b *ChainBinder, rc int, msg string) {
	if store == "" {
		store = filepath.Join(root, DefaultChainStoreRel)
	}
	b, err := LoadChainBinder(store)
	if err != nil {
		return nil, 2, "evidence chain: " + err.Error()
	}
	b.VerifyRC, b.VerifyDetail = chainVerifyFn(root, store)
	if b.VerifyRC != 0 {
		return b, b.VerifyRC, fmt.Sprintf("evidence chain %s does not verify (rc %d): %s", store, b.VerifyRC, b.VerifyDetail)
	}
	return b, 0, ""
}
