package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/vasic-digital/continuum/pkg/chain"
	"github.com/vasic-digital/continuum/pkg/model"
)

// Store layout. The chain file is exactly what `continuum-integrity` reads; the
// sidecar is the rich record. Appenders and readers serialise on an flock of
// the store directory itself (lockStore).
const (
	chainFile   = "chain.jsonl"
	sidecarFile = "sidecar.jsonl"
)

// Closed sets carried into the chain record. The schema leaves these two as
// free strings; the constitution does not (§11.4.240(F) independence tiers,
// §11.4.226 evidence classes), so they are enforced here.
var (
	tiers    = set("instance", "model", "capability")
	classes  = set("runtime", "artifact", "source")
	hex64Pat = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// AppendRequest is everything one evidence record needs. Raw comes from the
// constitution recorder; Argv and Cwd from the adapter that ran the command.
type AppendRequest struct {
	StoreDir         string
	Schema           *Schema
	Session          string
	Cwd              string
	Argv             []string
	Raw              RawFields
	StreamRef        string
	RedactedOverride bool // the adapter's own re-scan redacted a stream the recorder missed
	ItemID           string
	CheckID          string
	PopulationKind   string
	VerdictRole      string
	IndependenceTier string
	EvidenceClass    string
	FpBefore         string
	FpAfter          string
	CheckVerdict     int // the CHECK's own three-valued result (0 holds, 1 violated, 2 undetermined)
	ExecRowsPath     string
	LockTimeout      time.Duration // bounded wait for the exclusive lock (default 120 s; a timeout seals nothing)
}

// AppendResult reports what was sealed.
type AppendResult struct {
	Seq          int64
	ArtifactPath string
	Outcome      int
	SidecarLine  []byte
	Record       chain.Record
}

var errRefused = errors.New("append refused")

func refuse(f string, a ...any) error {
	return fmt.Errorf("%w: %s", errRefused, fmt.Sprintf(f, a...))
}

// Preflight decides whether a store may be extended — and, run by the adapter
// BEFORE the wrapped check executes, whether the check may run at all (review
// finding 11: a store that cannot take the record must not execute the check).
// An absent store (neither file) is a fresh store and is accepted.
func Preflight(dir string, schema *Schema) error {
	cp, sp := filepath.Join(dir, chainFile), filepath.Join(dir, sidecarFile)
	_, ce := os.Stat(cp)
	_, se := os.Stat(sp)
	if errors.Is(ce, os.ErrNotExist) && errors.Is(se, os.ErrNotExist) {
		return nil
	}
	rep, err := VerifyStore(dir, schema)
	if err != nil {
		return refuse("the existing store cannot be verified, so it will not be extended: %v", err)
	}
	if len(rep.Findings) > 0 {
		return refuse("the existing store violates %d adapter invariant(s) (first: %s line %d: %s); run --verify, it will not be extended",
			len(rep.Findings), rep.Findings[0].Invariant, rep.Findings[0].Line, rep.Findings[0].Detail)
	}
	cb, err := os.ReadFile(cp)
	if err != nil {
		return refuse("reading chain: %v", err)
	}
	recs, err := chain.Decode(cb)
	if err != nil {
		return refuse("decoding chain: %v", err)
	}
	if v := chain.Verify(recs); v.Verdict != chain.PASS {
		return refuse("the existing chain does not verify (%s): %+v", v.Verdict, v.Findings)
	}
	return nil
}

// Append seals one record into the store, under an exclusive lock:
//
//  1. the existing store must verify clean (upstream chain.Verify + every
//     adapter invariant) — extending a tampered store would seal the tamper
//     under a fresh, valid link;
//  2. outcome = the check's own verdict, forced to 2 whenever the state
//     fingerprints differ (an unstable run carries no verdict);
//  3. the sidecar line is rendered, schema-validated, and hashed;
//  4. the chain record is produced by upstream chain.ExecRow.ToRecord, which
//     parses exit_status as a canonical decimal STRING and records argv[0] as
//     `command` (Command is left empty on purpose); prev_digest is upstream
//     chain.Digest of the last record, "" at genesis;
//  5. sidecar line then chain line are appended and fsynced. A crash between
//     the two leaves an UNBOUND trailing sidecar line, which VerifyStore reports
//     (I2) and the next Append refuses to extend — loud, never silent.
func Append(req AppendRequest) (AppendResult, error) {
	if err := validateRequest(req); err != nil {
		return AppendResult{}, err
	}
	if err := os.MkdirAll(req.StoreDir, 0o755); err != nil {
		return AppendResult{}, refuse("creating store %s: %v", req.StoreDir, err)
	}
	wait := req.LockTimeout
	if wait <= 0 {
		wait = 120 * time.Second
	}
	release, err := lockStore(req.StoreDir, true, wait)
	if err != nil {
		return AppendResult{}, refuse("%v", err)
	}
	defer release()

	chainPath := filepath.Join(req.StoreDir, chainFile)
	sidePath := filepath.Join(req.StoreDir, sidecarFile)
	if err := Preflight(req.StoreDir, req.Schema); err != nil {
		return AppendResult{}, err
	}
	for _, p := range []string{chainPath, sidePath} {
		if _, err := os.Stat(p); errors.Is(err, os.ErrNotExist) {
			if err := os.WriteFile(p, nil, 0o644); err != nil {
				return AppendResult{}, refuse("creating %s: %v", p, err)
			}
		}
	}
	cb, err := os.ReadFile(chainPath)
	if err != nil {
		return AppendResult{}, refuse("reading chain: %v", err)
	}
	recs, err := chain.Decode(cb)
	if err != nil {
		return AppendResult{}, refuse("decoding chain: %v", err)
	}
	prev, seq := chain.GenesisPrev, int64(1)
	if n := len(recs); n > 0 {
		if prev, err = chain.Digest(recs[n-1]); err != nil {
			return AppendResult{}, refuse("digesting the chain head: %v", err)
		}
		seq = recs[n-1].Seq + 1
	}

	outcome := req.CheckVerdict
	if req.FpBefore != req.FpAfter {
		outcome = 2
	}
	row := chain.ExecRow{
		Ts: req.Raw.Ts, Cwd: req.Cwd, Command: "", Argv: req.Argv,
		ExitStatus: req.Raw.ExitStatus,
	}
	// A first ToRecord call only to learn the parsed exit status; the real one
	// below carries the artifact_path, which depends on the sidecar line.
	probe, err := row.ToRecord(chain.ExecRecordFields{Seq: seq, EvidenceClass: req.EvidenceClass})
	if err != nil {
		return AppendResult{}, refuse("%v", err)
	}
	sc := Sidecar{
		ChainSeq: seq, Ts: req.Raw.Ts, Cwd: req.Cwd, Argv: req.Argv,
		ExitStatus: probe.ExitStatus, DurationMs: req.Raw.DurationMs,
		StdoutDigest: req.Raw.StdoutDigest, StderrDigest: req.Raw.StderrDigest,
		StdoutBytes: req.Raw.StdoutBytes, StderrBytes: req.Raw.StderrBytes,
		StreamRef: req.StreamRef, StreamTruncated: req.Raw.Truncated,
		StreamRedacted: req.Raw.Redacted || req.RedactedOverride,
		ItemID:         req.ItemID, CheckID: req.CheckID,
		FpBefore: req.FpBefore, FpAfter: req.FpAfter,
		PopulationKind: req.PopulationKind, Outcome: outcome,
		VerdictRole: req.VerdictRole, IndependenceTier: req.IndependenceTier,
		EvidenceClass: req.EvidenceClass,
	}
	line, err := MarshalSidecarLine(sc)
	if err != nil {
		return AppendResult{}, refuse("%v", err)
	}
	if v := req.Schema.ValidateLine(line); len(v) > 0 {
		return AppendResult{}, refuse("the record violates the evidence contract: %v", v)
	}
	ap := ArtifactPathFor(line)
	rec, err := row.ToRecord(chain.ExecRecordFields{
		Seq: seq, ArtifactPath: ap, EvidenceClass: req.EvidenceClass,
		AuthorSessionID: req.Session, IndependenceTier: req.IndependenceTier, PrevDigest: prev,
	})
	if err != nil {
		return AppendResult{}, refuse("%v", err)
	}
	cl, err := model.Canonical(rec)
	if err != nil {
		return AppendResult{}, refuse("canonicalising the chain record: %v", err)
	}
	// The execution row goes FIRST: the command ran whether or not the seal
	// below succeeds, so a row without a chain record is the true
	// "ran but unrecorded" state upstream's union rule exists to catch.
	if req.ExecRowsPath != "" {
		er, err := execRowLine(req)
		if err != nil {
			return AppendResult{}, refuse("building the execution row: %v", err)
		}
		if err := appendLineCreate(req.ExecRowsPath, er); err != nil {
			return AppendResult{}, refuse("appending the execution row: %v", err)
		}
	}
	if err := appendLine(sidePath, line); err != nil {
		return AppendResult{}, refuse("appending the sidecar line: %v", err)
	}
	if err := appendLine(chainPath, cl); err != nil {
		return AppendResult{}, refuse("appending the chain record AFTER the sidecar line was written — the store now holds one unbound sidecar line (reported by --verify as I2): %v", err)
	}
	return AppendResult{Seq: seq, ArtifactPath: ap, Outcome: outcome, SidecarLine: line, Record: rec}, nil
}

// execRowLine renders a STRICT-JSON FR-045 row with upstream's own ExecRow
// type (review finding 5): the exact argv and cwd, the recorder's parsed tail,
// the FINAL stream_ref and the EFFECTIVE redaction flag. The recorder's raw row
// cannot serve here — it is not JSON whenever argv carries a quote, tab or
// newline, and it points at the private incoming directory. The line is
// decoded back through upstream DecodeExecRows before it is written.
func execRowLine(req AppendRequest) ([]byte, error) {
	row := chain.ExecRow{
		Ts: req.Raw.Ts, Cwd: req.Cwd, Command: req.Argv[0], Argv: req.Argv,
		ExitStatus:      req.Raw.ExitStatus,
		DurationMs:      strconv.FormatInt(req.Raw.DurationMs, 10),
		StdoutDigest:    req.Raw.StdoutDigest,
		StderrDigest:    req.Raw.StderrDigest,
		StdoutBytes:     strconv.FormatInt(req.Raw.StdoutBytes, 10),
		StderrBytes:     strconv.FormatInt(req.Raw.StderrBytes, 10),
		StreamRef:       req.StreamRef,
		StreamTruncated: strconv.FormatBool(req.Raw.Truncated),
		StreamRedacted:  strconv.FormatBool(req.Raw.Redacted || req.RedactedOverride),
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(row); err != nil {
		return nil, err
	}
	l := bytes.TrimRight(buf.Bytes(), "\n")
	if _, err := chain.DecodeExecRows(l); err != nil {
		return nil, fmt.Errorf("upstream DecodeExecRows refuses the row it would be given: %v", err)
	}
	return l, nil
}

func appendLineCreate(path string, line []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o600)
	if err != nil {
		return err
	}
	f.Close()
	return appendLine(path, line)
}

func appendLine(path string, line []byte) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return err
	}
	if _, err := f.Write(append(bytes.Clone(line), '\n')); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

func validateRequest(r AppendRequest) error {
	switch {
	case r.Schema == nil:
		return refuse("no evidence schema loaded")
	case r.StoreDir == "":
		return refuse("no store directory")
	case r.Session == "":
		return refuse("author_session_id is empty; the recorder row does not carry one and it will not be invented")
	case len(r.Argv) == 0:
		return refuse("empty argv: nothing was demonstrably executed")
	case r.StreamRef == "":
		return refuse("empty stream_ref: the full streams must be retrievable")
	case r.CheckVerdict < 0 || r.CheckVerdict > 2:
		return refuse("check verdict %d is not three-valued (0 holds, 1 violated, 2 undetermined)", r.CheckVerdict)
	case !tiers[r.IndependenceTier]:
		return refuse("independence_tier %q is not one of instance|model|capability", r.IndependenceTier)
	case !classes[r.EvidenceClass]:
		return refuse("evidence_class %q is not one of runtime|artifact|source", r.EvidenceClass)
	case !hex64Pat.MatchString(r.FpBefore) || !hex64Pat.MatchString(r.FpAfter):
		return refuse("state fingerprints must both be 64 lowercase hex (before=%q after=%q)", r.FpBefore, r.FpAfter)
	}
	return nil
}

// Environment through which a lock holder (zg-chain with-lock) hands its lock
// to its children (review T015c I2). The variable only NAMES a descriptor; the
// descriptor itself must be inherited, must be the store directory (same
// device and inode), and must still hold the lock (re-asserted, non-blocking),
// so a forged variable cannot skip the lock.
const (
	lockFDEnv   = "ZG_LOCK_FD"
	lockModeEnv = "ZG_LOCK_MODE"
	lockFDNum   = 9 // high, so shell code using fds 3-5 does not clobber it
)

// storeLock is a held store lock: the open directory (handed to children by
// with-lock) and its release.
type storeLock struct {
	fd        int
	f         *os.File // nil for an inherited lock (no *os.File, so no finalizer closes it)
	exclusive bool
	release   func()
}

// lockStore takes an flock on the STORE DIRECTORY itself — exclusive for an
// append, shared for every reader (verify, preflight, history, anchor write;
// review T015b I2). Locking the directory rather than a lock file means a
// read-only store (the committed fixture corpus) is verified without creating
// anything in it. timeout <= 0 waits indefinitely; otherwise the wait is
// bounded and a lock not obtained in time is an error (the caller reports
// "could not determine", never a verdict on a half-written store).
func lockStore(dir string, exclusive bool, timeout time.Duration) (func(), error) {
	l, err := acquireStoreLock(dir, exclusive, timeout)
	if err != nil {
		return nil, err
	}
	return l.release, nil
}

func acquireStoreLock(dir string, exclusive bool, timeout time.Duration) (*storeLock, error) {
	if l, ok, err := inheritedStoreLock(dir, exclusive); ok {
		return l, err
	}
	d, err := os.Open(dir)
	if err != nil {
		return nil, fmt.Errorf("opening the store directory to lock it: %w", err)
	}
	how := syscall.LOCK_SH
	if exclusive {
		how = syscall.LOCK_EX
	}
	if timeout <= 0 {
		if err := syscall.Flock(int(d.Fd()), how); err != nil {
			d.Close()
			return nil, fmt.Errorf("locking %s: %w", dir, err)
		}
	} else {
		deadline := time.Now().Add(timeout)
		for {
			err := syscall.Flock(int(d.Fd()), how|syscall.LOCK_NB)
			if err == nil {
				break
			}
			if err != syscall.EWOULDBLOCK || time.Now().After(deadline) {
				d.Close()
				return nil, fmt.Errorf("the store lock on %s was not obtained within %s (another holder is in progress or stuck): %v", dir, timeout, err)
			}
			time.Sleep(20 * time.Millisecond)
		}
	}
	return &storeLock{fd: int(d.Fd()), f: d, exclusive: exclusive, release: func() {
		syscall.Flock(int(d.Fd()), syscall.LOCK_UN)
		d.Close()
	}}, nil
}

// inheritedStoreLock honours a lock handed down by a holder. ok=false means
// "no valid inherited lock for THIS directory" and the caller locks normally
// (so a forged or unrelated variable changes nothing). ok=true with an error
// means a real inherited lock that cannot serve this request.
//
// The HELD mode is read from the kernel (heldFlockMode), never from the
// environment: ZG_LOCK_MODE only has to AGREE with it. No flock is ever
// issued on the inherited descriptor — a re-assert in a different mode is a
// conversion, and a failed conversion DROPS the holder's lock (review T015d
// F4: a forged ZG_LOCK_MODE=exclusive on a shared descriptor left the shell
// running unlocked).
func inheritedStoreLock(dir string, exclusive bool) (*storeLock, bool, error) {
	v := os.Getenv(lockFDEnv)
	mode := os.Getenv(lockModeEnv)
	if v == "" || (mode != "shared" && mode != "exclusive") {
		return nil, false, nil
	}
	fd, err := strconv.Atoi(v)
	if err != nil || fd < 3 {
		return nil, false, nil
	}
	var fst, dst syscall.Stat_t
	if syscall.Fstat(fd, &fst) != nil || syscall.Stat(dir, &dst) != nil ||
		fst.Mode&syscall.S_IFMT != syscall.S_IFDIR || fst.Dev != dst.Dev || fst.Ino != dst.Ino {
		return nil, false, nil
	}
	held, err := heldFlockMode(fd)
	if err != nil {
		return nil, true, err // named as inherited but unknowable: fail closed
	}
	if held == "" {
		return nil, false, nil // the descriptor holds nothing: a stale or forged variable; lock normally
	}
	if held != mode {
		return nil, true, fmt.Errorf("%s says %s but the inherited descriptor holds a %s flock (refused; the lock is never converted)", lockModeEnv, mode, held)
	}
	if exclusive && held != "exclusive" {
		return nil, true, fmt.Errorf("the inherited store lock is SHARED and cannot serve an exclusive request (never converted: a conversion can drop the lock)")
	}
	return &storeLock{fd: fd, exclusive: held == "exclusive", release: func() {}}, true, nil
}

// heldFlockMode reads the flock this process's descriptor holds from the
// kernel's own view, /proc/self/fdinfo/<fd> (a `lock:` line names only the
// locks of THIS open file description — measured: a second descriptor on the
// same directory shows none): "shared", "exclusive" or "" for none. An
// unreadable fdinfo (no /proc) is an error: the mode is then unknowable.
func heldFlockMode(fd int) (string, error) {
	b, err := os.ReadFile(fmt.Sprintf("/proc/self/fdinfo/%d", fd))
	if err != nil {
		return "", fmt.Errorf("cannot read the held lock mode of descriptor %d from /proc/self/fdinfo (refused, never guessed): %w", fd, err)
	}
	for _, line := range strings.Split(string(b), "\n") {
		if !strings.HasPrefix(line, "lock:") {
			continue
		}
		// "lock:\t1: FLOCK  ADVISORY  WRITE <pid> <maj:min:ino> 0 EOF"
		f := strings.Fields(strings.TrimPrefix(line, "lock:"))
		if len(f) >= 4 && f[1] == "FLOCK" {
			switch f[3] {
			case "READ":
				return "shared", nil
			case "WRITE":
				return "exclusive", nil
			}
		}
	}
	return "", nil
}
