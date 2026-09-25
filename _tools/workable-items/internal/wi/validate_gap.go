package wi

// Feature 010, task T007: validator rules V-G1..V-G12 over the zero-gap
// register (contracts/register-cli.md, data-model.md "StateMachine").
//
// Scope. A "gap item" is an items row carrying at least one non-NULL zero-gap
// text column. Rows written before the migration (every column NULL) are
// legacy items: the base validator (validate.go) keeps covering them, and only
// the roster rule (V-G8), the Operator-blocked rule (V-G11) and the orphan
// verdict rule (V-G12) reach beyond gap items.
//
// Every date rule compares against GapOptions.AsOf (an ISO date), never the
// clock, so an unchanged database gives the same verdict on every repeat
// (SC-006). Evidence paths resolve against GapOptions.Root unless absolute.

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"syscall"
	"time"
)

// Closed sets (data-model.md, research D2/D4).
var (
	GapKinds = []string{"defect", "unfinished-promise", "weak-spot", "danger-zone", "improvement"}
	// GapCategories is in the rubric's primary-category order.
	GapCategories = []string{"security", "data-integrity", "false-evidence", "content-boundary", "availability",
		"build-freshness", "governance-drift", "docs-drift", "test-coverage", "ux-accessibility", "host-capability", "other"}
	GapSeverities           = []string{"critical", "high", "medium", "low"}
	GapDispositions         = []string{"open", "closed", "classified"}
	GapClassificationReason = []string{"operator-decision", "operator-action", "third-party", "documented-deviation"}
)

func inSet(set []string, v string) bool {
	for _, s := range set {
		if s == v {
			return true
		}
	}
	return false
}

// openStatuses are the non-terminal statuses an OPEN gap item may carry.
var openStatuses = []string{StatusQueued, StatusInProgress, StatusReadyTest, StatusInTesting, StatusReopened}

// GapOptions parameterises the V-G rules.
type GapOptions struct {
	AsOf   string  // ISO date YYYY-MM-DD; required
	Root   string  // repository root that relative evidence paths resolve against
	Roster *Roster // nil ⇒ V-G8 is undetermined
}

// ParseAsOf validates an --as-of value.
func ParseAsOf(s string) (string, error) {
	if _, err := time.Parse("2006-01-02", s); err != nil || len(s) != 10 {
		return "", fmt.Errorf("--as-of %q is not an ISO date (YYYY-MM-DD)", s)
	}
	return s, nil
}

func validDate(s string) bool {
	_, err := time.Parse("2006-01-02", s)
	return err == nil && len(s) == 10
}

// ── evidence records ───────────────────────────────────────────────────────

// EvidenceRecord is one zero-gap sidecar evidence record
// (contracts/evidence-record.schema.json). Decoding is strict: unknown fields
// are refused (additionalProperties:false) and every required field must be
// present.
type EvidenceRecord struct {
	TS                     *string  `json:"ts"`
	Cwd                    *string  `json:"cwd"`
	Argv                   []string `json:"argv"`
	ExitStatus             *int     `json:"exit_status"`
	DurationMS             *int64   `json:"duration_ms"`
	StdoutDigest           *string  `json:"stdout_digest"`
	StderrDigest           *string  `json:"stderr_digest"`
	StdoutBytes            *int64   `json:"stdout_bytes"`
	StderrBytes            *int64   `json:"stderr_bytes"`
	StreamRef              *string  `json:"stream_ref"`
	StreamTruncated        *bool    `json:"stream_truncated"`
	StreamRedacted         *bool    `json:"stream_redacted"`
	ItemID                 *string  `json:"item_id"`
	CheckID                *string  `json:"check_id"`
	StateFingerprintBefore *string  `json:"state_fingerprint_before"`
	StateFingerprintAfter  *string  `json:"state_fingerprint_after"`
	PopulationKind         *string  `json:"population_kind"`
	Outcome                *int     `json:"outcome"`
	VerdictRole            *string  `json:"verdict_role"`
	ChainSeq               *int64   `json:"chain_seq"`
	IndependenceTier       *string  `json:"independence_tier"`
	EvidenceClass          *string  `json:"evidence_class"`

	time time.Time
}

var (
	hex64Re  = regexp.MustCompile(`^[0-9a-f]{64}$`)
	itemIDRe = regexp.MustCompile(`^[A-Z]{3}-[0-9]{3,}$|^SWEEP$`)
)

// MaxEvidenceBytes caps an evidence record file (fix round 2): one sidecar
// record is well under a kilobyte, and reading an unbounded file into memory
// let a 150 MB "record" cost 584 MB.
const MaxEvidenceBytes = 1 << 20

func tooBig(path string, size int64) error {
	return fmt.Errorf("evidence record %s is %d bytes, larger than the 1 MiB cap (%d bytes)", path, size, MaxEvidenceBytes)
}

// errNotRegular marks a cited path that is not a regular file: a FIFO, socket,
// device or directory (fix round 4, F2).
var errNotRegular = errors.New("not a regular file")

func fileKind(m fs.FileMode) string {
	switch {
	case m.IsDir():
		return "a directory"
	case m&fs.ModeNamedPipe != 0:
		return "a named pipe (FIFO)"
	case m&fs.ModeSocket != 0:
		return "a socket"
	case m&fs.ModeDevice != 0:
		return "a device"
	case m&fs.ModeSymlink != 0:
		return "a symlink"
	}
	return "a special file"
}

// openRegular opens a file for reading so that nothing can make the tool wait
// (fix round 4, F2): the symlink chain is resolved first, the final open is
// O_NONBLOCK (a FIFO with no writer would otherwise block open(2) forever,
// and `gap close` held the write lock while it did) and O_NOFOLLOW (a symlink
// swapped in between the resolution and the open is refused, not followed),
// and the OPENED handle is fstat'ed: anything but a regular file is refused
// before a byte is read. Every hashing and record-reading path goes through it.
func openRegular(path string) (*os.File, os.FileInfo, error) {
	real, err := filepath.EvalSymlinks(path)
	if err != nil {
		return nil, nil, err
	}
	f, err := os.OpenFile(real, os.O_RDONLY|syscall.O_NONBLOCK|syscall.O_NOFOLLOW|syscall.O_CLOEXEC, 0)
	if err != nil {
		// ENXIO: a socket (open(2) refuses it); ELOOP: a symlink appeared
		// under O_NOFOLLOW between the resolution and the open.
		if errors.Is(err, syscall.ENXIO) || errors.Is(err, syscall.ELOOP) {
			return nil, nil, fmt.Errorf("%s is %s (%v), %w", path, "not openable as a file", err, errNotRegular)
		}
		return nil, nil, err
	}
	info, err := f.Stat()
	if err != nil {
		f.Close()
		return nil, nil, err
	}
	if !info.Mode().IsRegular() {
		f.Close()
		return nil, nil, fmt.Errorf("%s is %s, %w", path, fileKind(info.Mode()), errNotRegular)
	}
	return f, info, nil
}

// readRegular reads a regular file of at most max bytes through openRegular.
func readRegular(path string, max int64) ([]byte, error) {
	f, info, err := openRegular(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	if info.Size() > max {
		return nil, fmt.Errorf("%s is %d bytes, larger than the %d-byte cap", path, info.Size(), max)
	}
	b, err := io.ReadAll(io.LimitReader(f, max+1))
	if err != nil {
		return nil, err
	}
	if int64(len(b)) > max {
		return nil, fmt.Errorf("%s grew past the %d-byte cap while it was read", path, max)
	}
	return b, nil
}

// ReadEvidenceRecordDigest reads a file holding exactly one evidence record and
// returns the record together with the sha256 of the SAME bytes it parsed (fix
// round 4, F4): one read, so the digest a command records can never belong to
// a different version of the file than the record it checked.
func ReadEvidenceRecordDigest(path string) (*EvidenceRecord, string, error) {
	f, info, err := openRegular(path)
	if err != nil {
		return nil, "", err
	}
	defer f.Close()
	if info.Size() > MaxEvidenceBytes {
		return nil, "", &recordError{tooBig(path, info.Size())}
	}
	b, err := io.ReadAll(io.LimitReader(f, MaxEvidenceBytes+1))
	if err != nil {
		return nil, "", err
	}
	if int64(len(b)) > MaxEvidenceBytes {
		return nil, "", &recordError{tooBig(path, int64(len(b)))}
	}
	sum := sha256.Sum256(b)
	rec, err := ParseEvidenceRecord(b)
	if err != nil {
		return nil, "", &recordError{err}
	}
	return rec, hex.EncodeToString(sum[:]), nil
}

// recordError marks a file that was read but is not a valid evidence record
// (as opposed to one that could not be read, which is undetermined).
type recordError struct{ err error }

func (e *recordError) Error() string { return e.err.Error() }
func (e *recordError) Unwrap() error { return e.err }

// ReadEvidenceRecord reads a file holding exactly one evidence record.
func ReadEvidenceRecord(path string) (*EvidenceRecord, error) {
	rec, _, err := ReadEvidenceRecordDigest(path)
	return rec, err
}

// ParseEvidenceRecord decodes and checks one record.
func ParseEvidenceRecord(b []byte) (*EvidenceRecord, error) {
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	var r EvidenceRecord
	if err := dec.Decode(&r); err != nil {
		return nil, fmt.Errorf("not an evidence record: %w", err)
	}
	// Exactly one value, then only whitespace: a second Decode must hit EOF.
	// (dec.More() is false before a stray ']' or '}', so it let "]junk" pass.)
	var extra json.RawMessage
	if err := dec.Decode(&extra); err != io.EOF {
		return nil, errors.New("not an evidence record: content follows the single JSON object")
	}
	missing := []string{}
	req := map[string]bool{
		"ts": r.TS != nil, "cwd": r.Cwd != nil, "argv": len(r.Argv) > 0, "exit_status": r.ExitStatus != nil,
		"duration_ms": r.DurationMS != nil, "stdout_digest": r.StdoutDigest != nil, "stderr_digest": r.StderrDigest != nil,
		"stdout_bytes": r.StdoutBytes != nil, "stderr_bytes": r.StderrBytes != nil, "stream_ref": r.StreamRef != nil,
		"stream_truncated": r.StreamTruncated != nil, "stream_redacted": r.StreamRedacted != nil, "item_id": r.ItemID != nil,
		"check_id": r.CheckID != nil, "state_fingerprint_before": r.StateFingerprintBefore != nil,
		"state_fingerprint_after": r.StateFingerprintAfter != nil, "population_kind": r.PopulationKind != nil,
		"outcome": r.Outcome != nil, "verdict_role": r.VerdictRole != nil, "chain_seq": r.ChainSeq != nil,
		"independence_tier": r.IndependenceTier != nil, "evidence_class": r.EvidenceClass != nil,
	}
	for k, ok := range req {
		if !ok {
			missing = append(missing, k)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return nil, fmt.Errorf("evidence record lacks required field(s): %s", strings.Join(missing, ", "))
	}
	t, err := time.Parse(time.RFC3339, *r.TS)
	if err != nil {
		return nil, fmt.Errorf("evidence record ts %q is not RFC 3339", *r.TS)
	}
	r.time = t
	// An ORDERED list, never a map: with several malformed fields a map range
	// reported a different one on each run (fix round 1, I1).
	var badHex []string
	for _, f := range []struct{ name, v string }{
		{"stdout_digest", *r.StdoutDigest}, {"stderr_digest", *r.StderrDigest},
		{"state_fingerprint_before", *r.StateFingerprintBefore}, {"state_fingerprint_after", *r.StateFingerprintAfter},
	} {
		if !hex64Re.MatchString(f.v) {
			badHex = append(badHex, f.name)
		}
	}
	if len(badHex) > 0 {
		return nil, fmt.Errorf("evidence record field(s) not 64 lowercase hex digits: %s", strings.Join(badHex, ", "))
	}
	if !itemIDRe.MatchString(*r.ItemID) {
		return nil, fmt.Errorf("evidence record item_id %q is malformed", *r.ItemID)
	}
	if strings.TrimSpace(*r.CheckID) == "" {
		return nil, errors.New("evidence record check_id is empty")
	}
	if !inSet([]string{"source", "process", "wire"}, *r.PopulationKind) {
		return nil, fmt.Errorf("evidence record population_kind %q is outside {source, process, wire}", *r.PopulationKind)
	}
	if *r.Outcome < 0 || *r.Outcome > 2 {
		return nil, fmt.Errorf("evidence record outcome %d is outside {0,1,2}", *r.Outcome)
	}
	if !inSet([]string{"author", "verifier"}, *r.VerdictRole) {
		return nil, fmt.Errorf("evidence record verdict_role %q is outside {author, verifier}", *r.VerdictRole)
	}
	if *r.DurationMS < 0 || *r.StdoutBytes < 0 || *r.StderrBytes < 0 || *r.ChainSeq < 0 {
		return nil, errors.New("evidence record carries a negative count")
	}
	// The schema's documented invariant: a verdict (0 or 1) needs a stable state.
	if *r.Outcome != 2 && *r.StateFingerprintBefore != *r.StateFingerprintAfter {
		return nil, fmt.Errorf("evidence record reports outcome %d over a state that moved during the check (before != after); only outcome 2 is honest there", *r.Outcome)
	}
	return &r, nil
}

// ── the validator ──────────────────────────────────────────────────────────

type gapRow struct {
	id, loc, typ, status, severity, anchor, owner              string
	kind, category, disposition, reason, cowner, recheck, plan sql.NullString
	research, target, recurrence, cycle, sweep, fingerprint    sql.NullString
	reopens                                                    sql.NullInt64
}

type histRow struct {
	id                           int64
	event, reason, evid, created string
	onDate                       string
}

type verdictRow struct {
	role, actor, kind, evid, onDate string
	sha                             string // evidence_sha256 recorded with the verdict ("" when absent)
	outcome                         int
}

type diaryRow struct{ when, evid, created string }

// evidenceResult caches one resolved evidence path.
type evidenceResult struct {
	rec     *EvidenceRecord
	missing bool  // the path does not resolve
	invalid error // resolves but is not a valid record
	undet   error // could not be read
}

type gapValidator struct {
	db    queryer
	o     GapOptions
	rep   *Report
	cache map[string]*evidenceResult
	// digests caches sha256 of referenced files (N2/N3 byte-identity rules).
	digests map[string]string
	// undetIDs counts undetermined rows per item, so a caller can scope a
	// verdict to one item (the gap write commands do).
	undetIDs map[string]int
}

func (v *gapValidator) find(rule, id, format string, a ...any) {
	v.rep.Findings = append(v.rep.Findings, Finding{Rule: rule, ItemID: id, Detail: fmt.Sprintf(format, a...)})
}

func (v *gapValidator) undet(rule, id, format string, a ...any) {
	v.undetIDs[id]++
	v.rep.Undetermined = append(v.rep.Undetermined, fmt.Sprintf("%-6s %-8s %s", rule, id, fmt.Sprintf(format, a...)))
}

// escapeError marks a path that leaves the repository root (fix round 3, M2).
type escapeError struct{ msg string }

func (e *escapeError) Error() string { return e.msg }

func within(root, p string) bool {
	rel, err := filepath.Rel(root, p)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

// Confine resolves a repository-relative evidence path and refuses it unless it
// stays inside root — lexically AND after symlink resolution. Absolute paths
// are refused: evidence is cited relative to the repository.
func Confine(root, p string) (string, error) {
	if filepath.IsAbs(p) {
		return "", &escapeError{fmt.Sprintf("%s is an absolute path; evidence must stay inside the repository root and be cited relative to it", p)}
	}
	rootAbs, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	full := filepath.Join(rootAbs, p)
	if !within(rootAbs, full) {
		return "", &escapeError{fmt.Sprintf("%s climbs out of the repository root", p)}
	}
	realRoot, err := filepath.EvalSymlinks(rootAbs)
	if err != nil {
		realRoot = rootAbs
	}
	if real, err := filepath.EvalSymlinks(full); err == nil && !within(realRoot, real) {
		return "", &escapeError{fmt.Sprintf("%s resolves through a symlink to a file outside the repository root", p)}
	}
	return full, nil
}

func (v *gapValidator) resolve(p string) (string, error) {
	if v.o.Root == "" {
		return "", fmt.Errorf("relative path %q and no repository root to resolve it against", p)
	}
	return Confine(v.o.Root, p)
}

func isEscape(err error) bool {
	var e *escapeError
	return errors.As(err, &e)
}

// sameBytes reports whether p's content digest is in set.
func (v *gapValidator) sameBytes(p string, set map[string]bool) bool {
	d, err := v.digest(p)
	return err == nil && d != "" && set[d]
}

// mtime returns a referenced file's modification time.
func (v *gapValidator) mtime(p string) (time.Time, error) {
	full, err := v.resolve(p)
	if err != nil {
		return time.Time{}, err
	}
	info, err := os.Stat(full)
	if err != nil {
		return time.Time{}, err
	}
	return info.ModTime(), nil
}

// fileState reports whether a referenced file exists: (true,nil) yes,
// (false,nil) it does not resolve, (_,err) could not be determined.
// A path outside the repository root does not resolve (M2).
func (v *gapValidator) fileState(p string) (bool, error) {
	full, err := v.resolve(p)
	if isEscape(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	info, err := os.Stat(full)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	// Only a non-empty REGULAR file is captured proof: a directory is not
	// (fix round 1, C1), nor is an empty capture (§11.4.69).
	return info.Mode().IsRegular() && info.Size() > 0, nil
}

// digest returns the sha256 of a referenced file, streamed from a handle
// openRegular has checked (no size bound is needed to hash); "" with nil error
// when the file does not exist; an errNotRegular-wrapping error for a special
// file (never waited on).
func (v *gapValidator) digest(p string) (string, error) {
	if d, ok := v.digests[p]; ok {
		return d, nil
	}
	full, err := v.resolve(p)
	if err != nil {
		return "", err
	}
	d, err := fileDigest(full)
	if errors.Is(err, fs.ErrNotExist) {
		v.digests[p] = ""
		return "", nil
	}
	if err != nil {
		return "", err
	}
	v.digests[p] = d
	return d, nil
}

func (v *gapValidator) evidence(p string) *evidenceResult {
	if r, ok := v.cache[p]; ok {
		return r
	}
	r := &evidenceResult{}
	full, rerr := v.resolve(p)
	switch {
	case isEscape(rerr):
		r.invalid = rerr
	case rerr != nil:
		r.undet = rerr
	default:
		rec, _, err := ReadEvidenceRecordDigest(full)
		var bad *recordError
		switch {
		case err == nil:
			r.rec = rec
		case errors.Is(err, fs.ErrNotExist):
			r.missing = true
		case errors.Is(err, errNotRegular):
			r.invalid = fmt.Errorf("%s is not a regular file (%v)", p, err)
		case errors.As(err, &bad):
			r.invalid = err
		default:
			r.undet = err
		}
	}
	v.cache[p] = r
	return r
}

// ValidateGap evaluates V-G1..V-G12. It returns ErrNotMigrated when the
// register carries no zero-gap schema, and an error for an invalid AsOf.
func ValidateGap(db *sql.DB, o GapOptions) (*Report, error) {
	v, err := validateGapOn(db, o)
	if err != nil {
		return nil, err
	}
	return v.rep, nil
}

func validateGapOn(db queryer, o GapOptions) (*gapValidator, error) {
	if _, err := ParseAsOf(o.AsOf); err != nil {
		return nil, err
	}
	if err := requireMigrated(db); err != nil {
		return nil, err
	}
	v := &gapValidator{db: db, o: o, rep: &Report{}, cache: map[string]*evidenceResult{}, digests: map[string]string{}, undetIDs: map[string]int{}}

	rows, err := loadGapRows(db)
	if err != nil {
		return nil, err
	}
	all, err := loadStatusByID(db)
	if err != nil {
		return nil, err
	}
	hist, err := loadHistory(db)
	if err != nil {
		return nil, err
	}
	verdicts, err := loadVerdicts(db)
	if err != nil {
		return nil, err
	}
	diary, err := loadDiaryPass(db)
	if err != nil {
		return nil, err
	}

	for _, r := range rows {
		v.rep.Items++
		if r.wiped() {
			// Every zero-gap column is NULL but the item's history says it is
			// a gap item: something outside the gap commands rewrote the row.
			// Measured cause: the canonical binary's `close` re-INSERTs a fixed
			// column list. Say THAT, not a pile of missing-field findings.
			if r.status == StatusFixed || r.status == StatusImplemented || r.status == StatusCompleted {
				v.find("V-G3", r.id, "closed outside `gap close`: status %q with every zero-gap column wiped (the canonical `close` re-inserts a fixed column list); none of the FR-007/018/022 closure evidence was checked — reopen it and close it with `gap close`", r.status)
			} else {
				v.find("V-G1", r.id, "every zero-gap column was wiped outside the gap commands (history still marks it a gap item); restore kind/category/disposition")
			}
			continue
		}
		v.ruleG1(r, hist[r.id])
		v.ruleG7(r)
		v.ruleG2(r)
		v.ruleG10(r)
		v.ruleG4(r)
		v.ruleG5(r, all)
		if r.disposition.String == "closed" {
			v.ruleG3(r, hist[r.id], verdicts[r.id], diary[r.id])
			v.ruleG9(r, hist[r.id])
		}
	}
	if v.rep.Items == 0 {
		v.rep.Notes = append(v.rep.Notes, "0 gap item(s) in the register: V-G1..V-G7, V-G9 and V-G10 had nothing to evaluate (this is a statement, not a clean result)")
	}
	if err := v.ruleG6(); err != nil {
		return nil, err
	}
	v.ruleG8()
	if err := v.ruleG11(); err != nil {
		return nil, err
	}
	if err := v.ruleG12(); err != nil {
		return nil, err
	}

	sort.SliceStable(v.rep.Findings, func(i, j int) bool {
		a, b := v.rep.Findings[i], v.rep.Findings[j]
		if a.Rule != b.Rule {
			return a.Rule < b.Rule
		}
		if a.ItemID != b.ItemID {
			return a.ItemID < b.ItemID
		}
		return a.Detail < b.Detail
	})
	sort.Strings(v.rep.Undetermined)
	return v, nil
}

// gapPredicate selects gap items: a row carrying any zero-gap column, OR a row
// whose history holds a `zero-gap:` event. The second arm keeps an item in
// scope after its columns are wiped (measured 2026-09-25: the canonical
// binary's `close` re-INSERTs the row with a fixed column list and drops every
// zero-gap column) so the item is reported, never silently reclassified legacy.
const gapPredicate = `(COALESCE(kind,category,disposition,classification_reason,classification_owner,
    classification_recheck,plan_due,research_ref,measurable_target,recurrence_of,cycle,sweep_class,
    first_seen_fingerprint) IS NOT NULL
    OR EXISTS (SELECT 1 FROM item_history zh WHERE zh.atm_id = items.atm_id AND zh.reason LIKE 'zero-gap:%'))`

// wiped reports a gap row whose zero-gap columns are all NULL.
func (r gapRow) wiped() bool {
	for _, c := range []sql.NullString{r.kind, r.category, r.disposition, r.reason, r.cowner, r.recheck, r.plan,
		r.research, r.target, r.recurrence, r.cycle, r.sweep, r.fingerprint} {
		if c.Valid {
			return false
		}
	}
	return true
}

func loadGapRows(db queryer) ([]gapRow, error) {
	q := `SELECT atm_id, current_location, COALESCE(type,''), COALESCE(status,''), COALESCE(severity,''),
        COALESCE(forensic_anchor,''), COALESCE(assigned_to,''),
        kind, category, disposition, classification_reason, classification_owner, classification_recheck,
        plan_due, research_ref, measurable_target, recurrence_of, cycle, sweep_class, first_seen_fingerprint,
        reopens_count
        FROM items WHERE ` + gapPredicate + ` ORDER BY atm_id, current_location`
	rows, err := db.Query(q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []gapRow
	for rows.Next() {
		var r gapRow
		if err := rows.Scan(&r.id, &r.loc, &r.typ, &r.status, &r.severity, &r.anchor, &r.owner,
			&r.kind, &r.category, &r.disposition, &r.reason, &r.cowner, &r.recheck, &r.plan,
			&r.research, &r.target, &r.recurrence, &r.cycle, &r.sweep, &r.fingerprint, &r.reopens); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

type itemRef struct {
	status, recurrence string
}

// loadStatusByID maps every atm_id (gap or legacy) to its status and link. An
// id present in both trackers resolves to its Issues row (the live one).
func loadStatusByID(db queryer) (map[string]itemRef, error) {
	rows, err := db.Query(`SELECT atm_id, current_location, status, COALESCE(recurrence_of,'') FROM items ORDER BY atm_id, current_location DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	m := map[string]itemRef{}
	for rows.Next() {
		var id, loc, st, rec string
		if err := rows.Scan(&id, &loc, &st, &rec); err != nil {
			return nil, err
		}
		m[id] = itemRef{status: st, recurrence: rec} // ORDER BY … DESC: Issues overwrites Fixed
	}
	return m, rows.Err()
}

func loadHistory(db queryer) (map[string][]histRow, error) {
	rows, err := db.Query(`SELECT id, atm_id, event_type, COALESCE(reason,''), COALESCE(evidence_path,''),
        COALESCE(created_at,''), COALESCE(on_date,'') FROM item_history ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	m := map[string][]histRow{}
	for rows.Next() {
		var h histRow
		var id string
		if err := rows.Scan(&h.id, &id, &h.event, &h.reason, &h.evid, &h.created, &h.onDate); err != nil {
			return nil, err
		}
		m[id] = append(m[id], h)
	}
	return m, rows.Err()
}

func loadVerdicts(db queryer) (map[string][]verdictRow, error) {
	rows, err := db.Query(`SELECT item_id, role, actor, actor_kind, outcome, evidence_path, on_date, COALESCE(evidence_sha256,'') FROM item_verdicts ORDER BY rowid`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	m := map[string][]verdictRow{}
	for rows.Next() {
		var id string
		var r verdictRow
		if err := rows.Scan(&id, &r.role, &r.actor, &r.kind, &r.outcome, &r.evid, &r.onDate, &r.sha); err != nil {
			return nil, err
		}
		m[id] = append(m[id], r)
	}
	return m, rows.Err()
}

// loadDiaryPass returns every PASS test_diary row that cites evidence.
func loadDiaryPass(db queryer) (map[string][]diaryRow, error) {
	rows, err := db.Query(`SELECT atm_id, date_time, evidence_path, COALESCE(created_at,'') FROM test_diary
        WHERE result='PASS' AND COALESCE(evidence_path,'') <> '' ORDER BY entry_id`)
	if err != nil {
		if strings.Contains(err.Error(), "no such table") {
			return map[string][]diaryRow{}, nil
		}
		return nil, err
	}
	defer rows.Close()
	m := map[string][]diaryRow{}
	for rows.Next() {
		var id string
		var d diaryRow
		if err := rows.Scan(&id, &d.when, &d.evid, &d.created); err != nil {
			return nil, err
		}
		m[id] = append(m[id], d)
	}
	return m, rows.Err()
}

// V-G1 — every gap item has type+status+id+kind+category+severity+owner+
// location+an evidence reference.
func (v *gapValidator) ruleG1(r gapRow, hist []histRow) {
	const rule = "V-G1"
	if _, _, ok := SplitID(r.id); !ok {
		v.find(rule, r.id, "identifier is not <THREE-UPPERCASE>-<positive integer>")
	}
	if !validType[r.typ] {
		v.find(rule, r.id, "type %q is outside {Bug, Feature, Task}", r.typ)
	}
	if !validStatus[r.status] {
		v.find(rule, r.id, "status %q is outside the closed set", r.status)
	}
	switch {
	case !r.kind.Valid || r.kind.String == "":
		v.find(rule, r.id, "kind is missing")
	case !inSet(GapKinds, r.kind.String):
		v.find(rule, r.id, "kind %q is outside {%s}", r.kind.String, strings.Join(GapKinds, ", "))
	case (r.kind.String == "defect" || r.kind.String == "danger-zone") && r.typ != TypeBug:
		v.find(rule, r.id, "kind %s is typed %s; research D3 types defects and danger zones Bug", r.kind.String, r.typ)
	}
	switch {
	case !r.category.Valid || r.category.String == "":
		v.find(rule, r.id, "category is missing")
	case !inSet(GapCategories, r.category.String):
		v.find(rule, r.id, "category %q is outside the closed set (research D4)", r.category.String)
	}
	switch {
	case r.severity == "":
		v.find(rule, r.id, "severity is missing")
	case !inSet(GapSeverities, r.severity):
		v.find(rule, r.id, "severity %q is outside {critical, high, medium, low}", r.severity)
	}
	if strings.TrimSpace(r.owner) == "" {
		v.find(rule, r.id, "owner (assigned_to) is missing")
	}
	if strings.TrimSpace(r.anchor) == "" {
		v.find(rule, r.id, "location (forensic_anchor) is missing")
	}
	has, cited, undetermined := false, 0, 0
	for _, h := range hist {
		if strings.TrimSpace(h.evid) == "" {
			continue
		}
		cited++
		ok, err := v.fileState(h.evid)
		if err != nil {
			undetermined++
		} else if ok {
			has = true
			break
		}
	}
	// Every Reopened row names a §11.4.34 reason and evidence that resolves
	// (round 3, M1): a reopen is a demotion and needs both.
	for _, h := range hist {
		if h.event != "Reopened" {
			continue
		}
		if !inSet(reopenReasons, h.reason) {
			v.find(rule, r.id, "Reopened row %d gives reason %q, outside the §11.4.34 set {%s}", h.id, h.reason, strings.Join(reopenReasons, ", "))
		}
		if ok, err := v.fileState(h.evid); err != nil {
			v.undet(rule, r.id, "Reopened row %d evidence %s could not be checked: %v", h.id, h.evid, err)
		} else if !ok {
			v.find(rule, r.id, "Reopened row %d evidence %q does not resolve to a non-empty regular file inside the repository root", h.id, h.evid)
		}
	}
	switch {
	case has:
	case undetermined > 0:
		v.undet(rule, r.id, "evidence reference(s) could not be checked")
	case cited == 0:
		v.find(rule, r.id, "no item_history row carries an evidence reference")
	default:
		v.find(rule, r.id, "no item_history evidence reference resolves to a non-empty regular file (%d cited)", cited)
	}
}

func normalizeWord(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(strings.ToLower(strings.TrimSpace(s)), " ", "-"), "_", "-")
}

// V-G7 — no accepted-as-is / unknown disposition, and the disposition agrees
// with the status (data-model.md StateMachine).
func (v *gapValidator) ruleG7(r gapRow) {
	const rule = "V-G7"
	for _, val := range []string{r.disposition.String, r.reason.String} {
		if strings.Contains(normalizeWord(val), "accepted-as-is") {
			v.find(rule, r.id, "%q: \"accepted as is\" is not a state (clarification 1, FR-006)", val)
			return
		}
	}
	d := r.disposition.String
	if !r.disposition.Valid || d == "" {
		v.find(rule, r.id, "disposition is missing; a gap item ends closed, classified or open (FR-006)")
		return
	}
	if !inSet(GapDispositions, d) {
		v.find(rule, r.id, "disposition %q is outside {open, closed, classified}", d)
		return
	}
	if r.status == StatusObsolete {
		v.find(rule, r.id, "status Obsolete is not a disposition for a gap item and does not substitute for classification")
		return
	}
	switch d {
	case "closed":
		if want := ClosureFor(r.typ); r.status != want {
			v.find(rule, r.id, "disposition closed but status %q (a %s closes as %q)", r.status, r.typ, want)
		}
	case "open":
		if !inSet(openStatuses, r.status) {
			v.find(rule, r.id, "disposition open but status %q is not an open status", r.status)
		}
	case "classified":
		switch r.reason.String {
		case "operator-decision", "operator-action":
			if r.status != StatusBlocked {
				v.find(rule, r.id, "classified %s must carry status Operator-blocked, not %q", r.reason.String, r.status)
			}
		case "third-party", "documented-deviation":
			if r.status != StatusQueued {
				v.find(rule, r.id, "classified %s must carry the exact status Queued, not %q", r.reason.String, r.status)
			}
		}
	}
}

// V-G2 — classified ⇒ reason ∈ the four + owner + recheck not elapsed; the
// classification columns are set only on classified items.
func (v *gapValidator) ruleG2(r gapRow) {
	const rule = "V-G2"
	if r.disposition.String != "classified" {
		if r.reason.Valid || r.cowner.Valid || r.recheck.Valid {
			v.find(rule, r.id, "classification columns are set on a %q item; they are required iff classified", r.disposition.String)
		}
		return
	}
	if strings.Contains(normalizeWord(r.reason.String), "accepted-as-is") {
		return // reported by V-G7
	}
	if !inSet(GapClassificationReason, r.reason.String) {
		v.find(rule, r.id, "classification reason %q is not one of {%s}", r.reason.String, strings.Join(GapClassificationReason, ", "))
	}
	if strings.TrimSpace(r.cowner.String) == "" {
		v.find(rule, r.id, "classification owner is missing")
	}
	switch {
	case !r.recheck.Valid || r.recheck.String == "":
		v.find(rule, r.id, "classification recheck date is missing")
	case !validDate(r.recheck.String):
		v.find(rule, r.id, "classification recheck %q is not an ISO date", r.recheck.String)
	case r.recheck.String < v.o.AsOf:
		v.find(rule, r.id, "classification recheck %s has elapsed at --as-of %s", r.recheck.String, v.o.AsOf)
	}
}

// V-G10 — every open item has a dated plan that has not elapsed.
func (v *gapValidator) ruleG10(r gapRow) {
	const rule = "V-G10"
	if r.disposition.String != "open" {
		return
	}
	switch {
	case !r.plan.Valid || strings.TrimSpace(r.plan.String) == "":
		v.find(rule, r.id, "open item has no dated plan (plan_due)")
	case !validDate(r.plan.String):
		v.find(rule, r.id, "plan_due %q is not an ISO date", r.plan.String)
	case r.plan.String < v.o.AsOf:
		v.find(rule, r.id, "plan_due %s has elapsed at --as-of %s", r.plan.String, v.o.AsOf)
	}
}

// V-G4 — kind='improvement' ⇒ a non-empty measurable target (FR-025).
func (v *gapValidator) ruleG4(r gapRow) {
	if r.kind.String == "improvement" && strings.TrimSpace(r.target.String) == "" {
		v.find("V-G4", r.id, "improvement item has no measurable target (FR-025)")
	}
}

// V-G5 — recurrence_of resolves, is acyclic and ends at a head; a head that is
// closed while its recurrence is open must be reopened (§11.4.214).
func (v *gapValidator) ruleG5(r gapRow, all map[string]itemRef) {
	const rule = "V-G5"
	if !r.recurrence.Valid || r.recurrence.String == "" {
		return
	}
	seen := map[string]bool{r.id: true}
	cur := r.recurrence.String
	for {
		ref, ok := all[cur]
		if !ok {
			v.find(rule, r.id, "recurrence chain reaches %q, which names no item", cur)
			return
		}
		if seen[cur] {
			v.find(rule, r.id, "recurrence chain cycles back to %s", cur)
			return
		}
		seen[cur] = true
		if ref.recurrence == "" {
			head := cur
			terminal := ref.status == StatusFixed || ref.status == StatusImplemented || ref.status == StatusCompleted
			if terminal && inSet(openStatuses, r.status) {
				v.find(rule, r.id, "head %s is closed (%s) while its recurrence is open; reopen the head (§11.4.214)", head, ref.status)
			}
			return
		}
		cur = ref.recurrence
	}
}

var closeReasonRe = regexp.MustCompile(`^zero-gap:close fixer=(\S+) check-author=(\S+) verdict=(\S+)(?: research-sha256=([0-9a-f]{64}))?$`)

// shaReasonRe extracts the sha256 a RED/GREEN history row recorded (I3).
var shaReasonRe = regexp.MustCompile(` sha256=([0-9a-f]{64})\b`)

// WatermarkPrefix starts the history row `gap reopen` writes right after its
// Reopened row: the digests of every verdict row the item held at that moment.
const WatermarkPrefix = "zero-gap:reopen-watermark stale="

// verdictKey identifies a verdict row by content (item_verdicts has no stable
// key of its own: a VACUUM may renumber rowids).
func verdictKey(vr verdictRow) string {
	h := sha256.Sum256([]byte(strings.Join([]string{vr.role, vr.actor, vr.kind, fmt.Sprint(vr.outcome), vr.evid, vr.onDate}, "\x1f")))
	return hex.EncodeToString(h[:8])
}

func parseStamp(s string) (time.Time, bool) {
	t, err := time.Parse("2006-01-02 15:04:05", s)
	return t, err == nil
}

// reopenCut is the item's latest Reopened row: evidence, verdicts and diary
// rows from before it cannot support a later closure (fix rounds 1-3).
type reopenCut struct {
	idx       int       // index in hist; -1 when never reopened
	at        time.Time // the cut time
	stale     map[string]bool
	watermark bool
	onDate    string
}

func maxTime(a time.Time, b time.Time) time.Time {
	if b.After(a) {
		return b
	}
	return a
}

// watermarkAfter returns the stale-key set of the watermark row that follows
// the Reopened row at index i (before any later Reopened row).
func watermarkAfter(hist []histRow, i int) (map[string]bool, bool) {
	for _, w := range hist[i+1:] {
		if w.event == "Reopened" {
			break
		}
		if strings.HasPrefix(w.reason, WatermarkPrefix) {
			set := map[string]bool{}
			for _, k := range strings.Split(strings.TrimPrefix(w.reason, WatermarkPrefix), ",") {
				if k != "" {
					set[k] = true
				}
			}
			return set, true
		}
	}
	return nil, false
}

// cutFor computes the reopen cut. It is MONOTONIC and, for each Reopened row in
// history order, never earlier than: the previous cut; that row's own failing
// record (when it belongs to this item) and created_at; the latest closure
// before it; AND the time of EVERY evidence record cited before it — RED,
// GREEN and verifier records in history and closure rows, the records of the
// verdict rows it makes stale, and the diary rows written before it (round 3,
// I1(a)): a closure citing evidence dated a few minutes ahead cannot leave a
// window in which older "fresh" evidence counts again.
func (v *gapValidator) cutFor(id string, hist []histRow, verdicts []verdictRow, diary []diaryRow) (reopenCut, bool) {
	c := reopenCut{idx: -1}
	recTime := func(p string) (time.Time, bool) {
		if p == "" {
			return time.Time{}, false
		}
		if e := v.evidence(p); e.rec != nil && *e.rec.ItemID == id {
			return e.rec.time, true
		}
		return time.Time{}, false
	}
	var cited time.Time
	for i, h := range hist {
		if h.event != "Reopened" {
			if t, ok := recTime(h.evid); ok {
				cited = maxTime(cited, t)
			}
			if m := closeReasonRe.FindStringSubmatch(h.reason); m != nil {
				if t, ok := recTime(m[3]); ok {
					cited = maxTime(cited, t)
				}
			}
			if h.event == "Fixed" || h.event == "Implemented" || h.event == "Completed" {
				if t, ok := parseStamp(h.created); ok {
					cited = maxTime(cited, t)
				}
			}
			continue
		}
		at := maxTime(c.at, cited)
		if t, ok := recTime(h.evid); ok {
			at = maxTime(at, t)
		}
		created, createdOK := parseStamp(h.created)
		if createdOK {
			at = maxTime(at, created)
		}
		stale, wm := watermarkAfter(hist, i)
		for _, vr := range verdicts {
			if (wm && stale[verdictKey(vr)]) || (!wm && vr.onDate <= h.onDate) {
				if t, ok := recTime(vr.evid); ok {
					at = maxTime(at, t)
				}
			}
		}
		for _, d := range diary {
			if createdOK && d.created != "" && d.created <= h.created {
				if t, err := time.Parse(time.RFC3339, d.when); err == nil {
					at = maxTime(at, t)
				}
			}
		}
		if at.IsZero() {
			v.undet("V-G3", id, "the time of the reopen at history row %d cannot be established", h.id)
			return c, false
		}
		c.idx, c.at, c.onDate = i, at, h.onDate
		c.stale, c.watermark = stale, wm
	}
	return c, true
}

// fresh reports whether a verdict row post-dates the cut. Without a watermark
// (a reopen made by another tool) only rows dated after the reopen day count.
func (c reopenCut) fresh(vr verdictRow) bool {
	switch {
	case c.idx < 0:
		return true
	case c.watermark:
		return !c.stale[verdictKey(vr)]
	default:
		return vr.onDate > c.onDate
	}
}

// asOfEnd is the first instant after the --as-of day (UTC).
func (v *gapValidator) asOfEnd() time.Time {
	t, _ := time.Parse("2006-01-02", v.o.AsOf)
	return t.Add(24 * time.Hour)
}

// checkDigest compares a file's current sha256 with the one recorded when it
// was cited (round 3, I3). It reports a finding when none was recorded, when
// the content changed (rewrite or symlink swap) or when the file is gone.
func (v *gapValidator) checkDigest(rule, id, label, p, recorded string) bool {
	if recorded == "" {
		v.find(rule, id, "%s %s: no sha256 was recorded when it was cited, so a later rewrite could not be detected (FR-016)", label, p)
		return false
	}
	cur, err := v.digest(p)
	switch {
	case isEscape(err) || errors.Is(err, errNotRegular):
		v.find(rule, id, "%s %s: %v", label, p, err)
		return false
	case err != nil:
		v.undet(rule, id, "%s %s could not be hashed: %v", label, p, err)
		return false
	case cur == "":
		v.find(rule, id, "%s %s no longer exists (recorded sha256 %s…)", label, p, recorded[:12])
		return false
	case cur != recorded:
		v.find(rule, id, "%s %s changed after it was cited: recorded sha256 %s…, now %s… (rewritten or swapped)", label, p, recorded[:12], cur[:12])
		return false
	}
	return true
}

type citedGreen struct {
	path string
	rec  *EvidenceRecord
}

// V-G3 — a closed item carries RED+GREEN evidence for the same check id, an
// independent verifier verdict whose evidence RECORD confirms that GREEN, a
// review verdict whose evidence is a regular file, a closure check authored by
// someone other than the fixer, a research record and an independent PASS
// test-diary row that certifies the GREEN (FR-007/018/022, §11.4.240(C)(1),
// §11.4.150, §11.4.149). Every cited file's sha256 recorded at citation time
// must still match (I3); nothing may be dated after the --as-of day (I2); after
// a reopen only evidence newer than the cut and never cited before it counts.
func (v *gapValidator) ruleG3(r gapRow, hist []histRow, verdicts []verdictRow, diary []diaryRow) {
	const rule = "V-G3"
	cut, ok := v.cutFor(r.id, hist, verdicts, diary)
	if !ok {
		return
	}
	end := v.asOfEnd()
	since := ""
	if cut.idx >= 0 {
		since = " since the latest reopen (" + cut.at.Format(time.RFC3339) + ")"
	}
	future := func(label, p string, t time.Time) bool {
		if t.After(end) || t.Equal(end) {
			v.find(rule, r.id, "%s %s is dated %s, after the end of --as-of %s", label, p, t.Format(time.RFC3339), v.o.AsOf)
			return true
		}
		return false
	}

	// Files cited before the cut: none may satisfy a later closure (I1(b)).
	// The RED of a re-close is banned too (round 4, F3): the first closure's
	// pre-fix failure says nothing about the state that failed AGAIN. The
	// one legitimate RED is the reopen's own failing record — the Reopened
	// row itself — so the RED ban set is built from the rows strictly before
	// it (and a byte copy of an earlier RED is still an earlier RED).
	priorPaths, priorDigests := map[string]bool{}, map[string]bool{}
	redPriorPaths, redPriorDigests := map[string]bool{}, map[string]bool{}
	if cut.idx >= 0 {
		var prior, redPrior []string
		for i, h := range hist[:cut.idx+1] {
			if h.evid != "" {
				prior = append(prior, h.evid)
				if i < cut.idx {
					redPrior = append(redPrior, h.evid)
				}
			}
			if m := closeReasonRe.FindStringSubmatch(h.reason); m != nil {
				prior = append(prior, m[3])
				redPrior = append(redPrior, m[3])
			}
		}
		for _, vr := range verdicts {
			if !cut.fresh(vr) {
				prior = append(prior, vr.evid)
				redPrior = append(redPrior, vr.evid)
			}
		}
		for _, p := range prior {
			priorPaths[p] = true
			if d, err := v.digest(p); err == nil && d != "" {
				priorDigests[d] = true
			}
		}
		for _, p := range redPrior {
			redPriorPaths[p] = true
			if d, err := v.digest(p); err == nil && d != "" {
				redPriorDigests[d] = true
			}
		}
	}
	reusedIn := func(label, p string, paths, digests map[string]bool) bool {
		if paths[p] {
			v.find(rule, r.id, "%s evidence %s was used in a previous closure of this item (same path); a re-close needs new evidence (I1)", label, p)
			return true
		}
		if v.sameBytes(p, digests) {
			v.find(rule, r.id, "%s evidence %s was used in a previous closure of this item (same bytes); a re-close needs new evidence (I1)", label, p)
			return true
		}
		return false
	}
	reused := func(label, p string) bool { return reusedIn(label, p, priorPaths, priorDigests) }

	// F5: a row cannot cite evidence that did not exist when the row was
	// written — every record a history row cites (its evidence_path and a
	// closure row's verdict= reference) must be measured no later than the
	// row's created_at. The commands enforce this at write time with zero
	// skew; a directly edited register must hold it too.
	for _, h := range hist {
		created, ok := parseStamp(h.created)
		if !ok {
			v.undet(rule, r.id, "history row %d has an unreadable created_at %q; whether it predates the evidence it cites cannot be established", h.id, h.created)
			continue
		}
		cites := []string{h.evid}
		if m := closeReasonRe.FindStringSubmatch(h.reason); m != nil {
			cites = append(cites, m[3])
		}
		for _, p := range cites {
			if p == "" {
				continue
			}
			if e := v.evidence(p); e.rec != nil && *e.rec.ItemID == r.id && e.rec.time.After(created) {
				v.find(rule, r.id, "history row %d (%s) was created at %s, before the evidence it cites was measured (%s at %s); a citing row cannot predate its evidence — the row was backdated (F5)",
					h.id, h.event, created.Format(time.RFC3339), p, e.rec.time.Format(time.RFC3339))
			}
		}
	}

	var fixer, author, verdictRef, researchSHA string
	for i := len(hist) - 1; i > cut.idx; i-- {
		if m := closeReasonRe.FindStringSubmatch(hist[i].reason); m != nil {
			fixer, author, verdictRef, researchSHA = m[1], m[2], m[3], m[4]
			break
		}
	}
	if fixer == "" {
		v.find(rule, r.id, "no `zero-gap:close fixer=… check-author=… verdict=…` closure record in item_history%s", since)
	} else if author == fixer {
		v.find(rule, r.id, "the closure check was authored by the fixer %s (§11.4.240(C)(1))", fixer)
	}

	switch ok, err := v.fileState(r.research.String); {
	case strings.TrimSpace(r.research.String) == "":
		v.find(rule, r.id, "closed item has no research_ref (§11.4.150)")
	case err != nil:
		v.undet(rule, r.id, "research_ref %s could not be checked: %v", r.research.String, err)
	case !ok:
		v.find(rule, r.id, "research_ref %s does not resolve to a non-empty regular file inside the repository root", r.research.String)
	case fixer != "":
		v.checkDigest(rule, r.id, "research_ref", r.research.String, researchSHA)
	}

	// RED/GREEN evidence for the same check id; GREEN must post-date the cut.
	var reds, greens []citedGreen
	redRows, greenRows := 0, 0
	evUndet := false
	for i, h := range hist {
		isRed := strings.HasPrefix(h.reason, "zero-gap:red-evidence")
		isGreen := strings.HasPrefix(h.reason, "zero-gap:green-evidence")
		// After a reopen only rows newer than the cut count — RED included
		// (F3): the first closure's RED row never pairs with a later GREEN.
		if !isRed && !isGreen || i <= cut.idx {
			continue
		}
		label := "GREEN"
		if isRed {
			label = "RED"
			redRows++
		} else {
			greenRows++
		}
		if isGreen && reused(label, h.evid) {
			continue
		}
		if isRed && reusedIn(label, h.evid, redPriorPaths, redPriorDigests) {
			continue
		}
		e := v.evidence(h.evid)
		recorded := ""
		if m := shaReasonRe.FindStringSubmatch(h.reason); m != nil {
			recorded = m[1]
		}
		switch {
		case e.undet != nil:
			evUndet = true
			v.undet(rule, r.id, "%s evidence %s could not be read: %v", label, h.evid, e.undet)
		case e.missing:
			v.find(rule, r.id, "%s evidence %s does not resolve", label, h.evid)
		case e.invalid != nil:
			v.find(rule, r.id, "%s evidence %s: %v", label, h.evid, e.invalid)
		case *e.rec.ItemID != r.id:
			v.find(rule, r.id, "%s evidence %s is recorded for %s, not %s", label, h.evid, *e.rec.ItemID, r.id)
		case isRed && *e.rec.Outcome != 1:
			v.find(rule, r.id, "RED evidence %s has outcome %d; the check must FAIL on the pre-fix state (a check that passes both ways is hollow)", h.evid, *e.rec.Outcome)
		case isGreen && *e.rec.Outcome != 0:
			v.find(rule, r.id, "GREEN evidence %s has outcome %d; the check must PASS on the current state", h.evid, *e.rec.Outcome)
		case isGreen && *e.rec.VerdictRole != "author":
			v.find(rule, r.id, "GREEN evidence %s has verdict_role %q; the GREEN is the author's run, the verifier's is a separate record (N2)", h.evid, *e.rec.VerdictRole)
		case isGreen && cut.idx >= 0 && !e.rec.time.After(cut.at):
			v.find(rule, r.id, "GREEN evidence %s (%s) predates the latest reopen (%s); a re-close needs evidence measured after the failure", h.evid, *e.rec.TS, cut.at.Format(time.RFC3339))
		case future(label+" evidence", h.evid, e.rec.time):
		case !v.checkDigest(rule, r.id, label+" evidence", h.evid, recorded):
		case isRed:
			reds = append(reds, citedGreen{h.evid, e.rec})
		default:
			greens = append(greens, citedGreen{h.evid, e.rec})
		}
	}
	if redRows == 0 {
		v.find(rule, r.id, "no RED (pre-fix) evidence recorded%s (FR-007)", since)
	}
	if greenRows == 0 {
		v.find(rule, r.id, "no GREEN (current) evidence recorded%s (FR-007)", since)
	}

	evPaths, evDigests := map[string]bool{}, map[string]bool{}
	for _, h := range hist {
		if strings.HasPrefix(h.reason, "zero-gap:red-evidence") || strings.HasPrefix(h.reason, "zero-gap:green-evidence") {
			evPaths[h.evid] = true
			if d, err := v.digest(h.evid); err == nil && d != "" {
				evDigests[d] = true
			}
		}
	}
	greenSeqs := map[string]map[int64]bool{}
	for _, g := range greens {
		if greenSeqs[*g.rec.CheckID] == nil {
			greenSeqs[*g.rec.CheckID] = map[int64]bool{}
		}
		greenSeqs[*g.rec.CheckID][*g.rec.ChainSeq] = true
	}
	pairedGreen := map[string]time.Time{}      // check id -> earliest GREEN of a valid pair
	pairedPath := map[string]*EvidenceRecord{} // GREEN path -> record, for the diary rule
	if len(reds) > 0 && len(greens) > 0 {
		sameState := false
		for _, rd := range reds {
			for _, gr := range greens {
				if *rd.rec.CheckID != *gr.rec.CheckID {
					continue
				}
				if *rd.rec.StateFingerprintAfter == *gr.rec.StateFingerprintBefore {
					sameState = true
					continue
				}
				if !rd.rec.time.Before(gr.rec.time) {
					continue
				}
				pairedPath[gr.path] = gr.rec
				if t, seen := pairedGreen[*gr.rec.CheckID]; !seen || gr.rec.time.Before(t) {
					pairedGreen[*gr.rec.CheckID] = gr.rec.time
				}
			}
		}
		if len(pairedGreen) == 0 && !evUndet {
			if sameState {
				v.find(rule, r.id, "RED and GREEN for the same check were taken on the SAME state fingerprint; opposite outcomes on one state are non-determinism, not a fix")
			} else {
				v.find(rule, r.id, "no RED/GREEN pair for the SAME check id with RED earlier than GREEN")
			}
		}
	}

	// Independent verifier (its evidence RECORD is read) and reviewer.
	okVerifier, okReviewer, refMatched := false, false, verdictRef == ""
	for _, vr := range verdicts {
		if !cut.fresh(vr) {
			continue
		}
		switch vr.role {
		case "verifier":
			if vr.outcome == 1 {
				v.find(rule, r.id, "verifier %s DISAGREES (outcome 1); a disagreement blocks closure (FR-018)", vr.actor)
			}
			if vr.actor == fixer && fixer != "" {
				v.find(rule, r.id, "verifier %s is the fixer; the verdict must come from a different actor (FR-018)", vr.actor)
				continue
			}
			if vr.outcome != 0 {
				continue
			}
			if reused("verifier", vr.evid) {
				continue
			}
			e := v.evidence(vr.evid)
			switch {
			case e.undet != nil:
				v.undet(rule, r.id, "verifier evidence %s could not be read: %v", vr.evid, e.undet)
				continue
			case e.missing:
				v.find(rule, r.id, "verifier evidence %s does not resolve", vr.evid)
				continue
			case e.invalid != nil:
				v.find(rule, r.id, "verifier evidence %s is not an evidence record: %v", vr.evid, e.invalid)
				continue
			}
			rec := e.rec
			gt, paired := pairedGreen[*rec.CheckID]
			switch {
			case *rec.ItemID != r.id:
				v.find(rule, r.id, "verifier evidence %s is recorded for %s", vr.evid, *rec.ItemID)
			case *rec.VerdictRole != "verifier":
				v.find(rule, r.id, "verifier evidence %s has verdict_role %q, not verifier", vr.evid, *rec.VerdictRole)
			case *rec.Outcome != 0:
				v.find(rule, r.id, "verifier evidence %s has outcome %d while the verdict row says 0", vr.evid, *rec.Outcome)
			case !validDate(vr.onDate):
				v.find(rule, r.id, "verifier verdict row is dated %q, not an ISO date", vr.onDate)
			case rec.time.UTC().Format("2006-01-02") > vr.onDate:
				// F5 for verdict rows (they carry a date, not a stamp): the
				// row cannot be dated before the day its record was measured.
				v.find(rule, r.id, "verifier verdict row is dated %s, before the evidence it cites was measured (%s at %s); a citing row cannot predate its evidence (F5)", vr.onDate, vr.evid, *rec.TS)
			case !paired && evUndet:
				v.undet(rule, r.id, "verifier evidence %s cannot be matched to a GREEN record that could not be read", vr.evid)
			case !paired:
				v.find(rule, r.id, "verifier evidence %s re-ran check %s, which has no RED/GREEN pair on this item", vr.evid, *rec.CheckID)
			case !rec.time.After(gt):
				v.find(rule, r.id, "verifier evidence %s (%s) is not later than the GREEN record it would confirm (%s); a verification is a separate, later run (N2)", vr.evid, *rec.TS, gt.Format(time.RFC3339))
			case evPaths[vr.evid]:
				v.find(rule, r.id, "verifier evidence %s is one of this item's own RED/GREEN records; a verification is a separate run (N2)", vr.evid)
			case greenSeqs[*rec.CheckID][*rec.ChainSeq]:
				v.find(rule, r.id, "verifier evidence %s carries the GREEN record's chain_seq %d; a verification is a separate run (N2)", vr.evid, *rec.ChainSeq)
			case v.sameBytes(vr.evid, evDigests):
				v.find(rule, r.id, "verifier evidence %s is byte-identical to a RED/GREEN record of this item (N2)", vr.evid)
			case future("verifier evidence", vr.evid, rec.time):
			case !v.checkDigest(rule, r.id, "verifier evidence", vr.evid, vr.sha):
			default:
				okVerifier = true
				if vr.evid == verdictRef {
					refMatched = true
				}
			}
		case "reviewer":
			if vr.outcome == 1 {
				v.find(rule, r.id, "reviewer %s rejected the fix (outcome 1) (FR-022)", vr.actor)
			}
			if vr.actor == fixer && fixer != "" {
				v.find(rule, r.id, "reviewer %s is the fixer; review must be independent (FR-022)", vr.actor)
				continue
			}
			if vr.outcome != 0 {
				continue
			}
			if ok, err := v.fileState(vr.evid); err != nil {
				v.undet(rule, r.id, "reviewer evidence %s could not be checked: %v", vr.evid, err)
			} else if !ok {
				v.find(rule, r.id, "reviewer evidence %s is not a non-empty regular file inside the repository root", vr.evid)
			} else if cut.idx >= 0 && (priorPaths[vr.evid] || v.sameBytes(vr.evid, priorDigests)) {
				v.find(rule, r.id, "reviewer evidence %s is byte-identical to evidence used before the latest reopen; a re-close needs a NEW review (N3)", vr.evid)
			} else if mt, err := v.mtime(vr.evid); err != nil {
				v.undet(rule, r.id, "reviewer evidence %s: %v", vr.evid, err)
			} else if cut.idx >= 0 && !mt.After(cut.at) {
				v.find(rule, r.id, "reviewer evidence %s was last written %s, not after the latest reopen (%s) (N3)", vr.evid, mt.UTC().Format(time.RFC3339), cut.at.Format(time.RFC3339))
			} else if v.checkDigest(rule, r.id, "reviewer evidence", vr.evid, vr.sha) {
				okReviewer = true
			}
		}
	}
	if !okVerifier && evUndet {
		v.undet(rule, r.id, "the verifier verdict cannot be confirmed while a RED/GREEN record is unreadable")
	} else if !okVerifier {
		v.find(rule, r.id, "no independent verifier verdict (outcome 0, actor other than the fixer, evidence record confirming the GREEN) in item_verdicts%s (FR-018)", since)
	}
	if !okReviewer {
		v.find(rule, r.id, "no review verdict (outcome 0, actor other than the fixer, regular-file evidence) in item_verdicts%s (FR-022)", since)
	}
	if fixer != "" && !refMatched && !evUndet {
		v.find(rule, r.id, "the closure's verdict reference %s names no valid verifier row of this item", verdictRef)
	}

	// The diary PASS row is independent evidence (canonical `diary add`; `gap
	// close` never writes one) that CERTIFIES a GREEN of this closure: it cites
	// that GREEN's file and is dated no earlier than it (round 3, M3).
	okDiary := false
	for _, d := range diary {
		g, cites := pairedPath[d.evid]
		if !cites {
			continue
		}
		t, err := time.Parse(time.RFC3339, d.when)
		if err != nil || t.Before(g.time) || (cut.idx >= 0 && !t.After(cut.at)) || !t.Before(end) {
			continue
		}
		if ok, err := v.fileState(d.evid); err == nil && ok {
			okDiary = true
			break
		}
	}
	if !okDiary && !evUndet {
		v.find(rule, r.id, "no test_diary PASS row that cites this closure's GREEN, dated no earlier than it%s and not after --as-of (§11.4.149; recorded independently, e.g. the canonical `diary add`)", since)
	}
}

// V-G9 — a closed item whose LATEST evidence, ordered by the time each record
// was MEASURED (Reopened rows included), is not a passing GREEN record; and no
// evidence may be dated after the end of the --as-of day (round 3, I2).
func (v *gapValidator) ruleG9(r gapRow, hist []histRow) {
	const rule = "V-G9"
	end := v.asOfEnd()
	type ev struct {
		at      time.Time
		i       int
		outcome int
		red     bool
		path    string
	}
	var evs []ev
	for i, h := range hist {
		isReopen := h.event == "Reopened"
		isEv := strings.HasPrefix(h.reason, "zero-gap:") && strings.Contains(h.reason, "-evidence")
		if !isReopen && !isEv {
			continue
		}
		e := v.evidence(h.evid)
		switch {
		case e.rec != nil:
			evs = append(evs, ev{e.rec.time, i, *e.rec.Outcome, strings.HasPrefix(h.reason, "zero-gap:red-evidence"), h.evid})
		case isReopen:
			// A reopen asserts a failure even when its evidence is no record.
			t, ok := parseStamp(h.created)
			if !ok {
				v.undet(rule, r.id, "a Reopened row's time cannot be established")
				return
			}
			evs = append(evs, ev{t, i, 1, false, h.evid})
		case e.undet != nil:
			v.undet(rule, r.id, "evidence %s could not be read, so the latest outcome cannot be established: %v", h.evid, e.undet)
			return
		default:
			v.find(rule, r.id, "evidence %s is not a readable evidence record and cannot be placed in time", h.evid)
		}
	}
	if len(evs) == 0 {
		return
	}
	latest := evs[0]
	for _, x := range evs {
		if !x.at.Before(end) {
			v.find(rule, r.id, "evidence %s is dated %s, after the end of --as-of %s", x.path, x.at.Format(time.RFC3339), v.o.AsOf)
		}
		if x.at.After(latest.at) || (x.at.Equal(latest.at) && x.i > latest.i) {
			latest = x
		}
	}
	switch {
	case latest.red:
		v.find(rule, r.id, "the latest evidence is the RED record %s; no GREEN record follows it", latest.path)
	case latest.outcome != 0:
		v.find(rule, r.id, "the latest evidence %s (%s) has outcome %d; the closed item's check no longer passes (reopen it)", latest.path, latest.at.Format(time.RFC3339), latest.outcome)
	}
}

// FreezeRecord is a cycle freeze (data-model.md CycleFreeze, plus the member
// list that makes V-G6 able to name what changed).
type FreezeRecord struct {
	ChainHead           *string  `json:"chain_head"`
	Cycle               string   `json:"cycle"`
	EntryCount          *int64   `json:"entry_count"`
	FrozenAt            string   `json:"frozen_at"`
	ItemCount           int      `json:"item_count"`
	Members             []string `json:"members"`
	MembersSHA256       string   `json:"members_sha256"`
	RegisterSHA256      string   `json:"register_sha256"`
	SweepManifestSHA256 *string  `json:"sweep_manifest_sha256"`
}

// FreezeMetaPrefix is the meta-table key prefix of a cycle freeze.
const FreezeMetaPrefix = "zero_gap_freeze:"

func membersDigest(members []string) string {
	h := sha256.New()
	for _, m := range members {
		h.Write([]byte(m + "\n"))
	}
	return hex.EncodeToString(h.Sum(nil))
}

func cycleMembers(db queryer, cycle string) ([]string, error) {
	rows, err := db.Query(`SELECT DISTINCT atm_id FROM items WHERE cycle = ? ORDER BY atm_id`, cycle)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// FreezeFileRel is where `gap freeze` writes the TRACKED copy of a cycle's
// freeze record, relative to the repository root.
func FreezeFileRel(cycle string) string {
	return filepath.Join("docs", "zero-gap", "cycles", cycle, "freeze.json")
}

// maxAuxBytes caps the auxiliary files the tool reads whole (freeze records,
// sweep-classes.tsv, the reopen queue).
const maxAuxBytes = 64 << 20

func readFreezeFile(path string) (*FreezeRecord, error) {
	b, err := readRegular(path, maxAuxBytes)
	if err != nil {
		return nil, err
	}
	var fr FreezeRecord
	if err := json.Unmarshal(b, &fr); err != nil {
		return nil, fmt.Errorf("%s is not a freeze record: %w", path, err)
	}
	return &fr, nil
}

func (fr *FreezeRecord) consistent() bool {
	return membersDigest(fr.Members) == fr.MembersSHA256 && len(fr.Members) == fr.ItemCount
}

func sameFreeze(a, b *FreezeRecord) bool {
	x, _ := json.Marshal(a)
	y, _ := json.Marshal(b)
	return bytes.Equal(x, y)
}

// V-G6 — no item-set change in a frozen cycle (FR-026). The DB meta record is
// cross-checked against the TRACKED docs/zero-gap/cycles/<cycle>/freeze.json
// (fix round 1, I3): a meta record rewritten consistently is still caught by
// the file git keeps, and a missing file makes the cross-check UNDETERMINED.
// Membership is judged against the tracked file when present, else the meta
// record, so a membership change is a finding even without the file.
func (v *gapValidator) ruleG6() error {
	const rule = "V-G6"
	rows, err := v.db.Query(`SELECT key, value FROM meta WHERE key LIKE ? ORDER BY key`, FreezeMetaPrefix+"%")
	if err != nil {
		return err
	}
	metaRaw := map[string]string{}
	for rows.Next() {
		var k, val string
		if err := rows.Scan(&k, &val); err != nil {
			rows.Close()
			return err
		}
		metaRaw[strings.TrimPrefix(k, FreezeMetaPrefix)] = val
	}
	rows.Close()
	cycles := map[string]bool{}
	for c := range metaRaw {
		cycles[c] = true
	}
	if v.o.Root != "" {
		matches, _ := filepath.Glob(filepath.Join(v.o.Root, "docs", "zero-gap", "cycles", "*", "freeze.json"))
		for _, m := range matches {
			cycles[filepath.Base(filepath.Dir(m))] = true
		}
	}
	names := make([]string, 0, len(cycles))
	for c := range cycles {
		names = append(names, c)
	}
	sort.Strings(names)

	for _, cycle := range names {
		var meta, file *FreezeRecord
		if raw, ok := metaRaw[cycle]; ok {
			var fr FreezeRecord
			if err := json.Unmarshal([]byte(raw), &fr); err != nil || fr.Cycle != cycle {
				v.undet(rule, "", "freeze record %s%s is unreadable or names another cycle", FreezeMetaPrefix, cycle)
			} else if !fr.consistent() {
				v.find(rule, "", "the register's freeze record for cycle %s is internally inconsistent (member list does not match its own digest/count) — it was altered after the freeze", cycle)
			} else {
				meta = &fr
			}
		}
		rel := FreezeFileRel(cycle)
		if v.o.Root == "" {
			v.undet(rule, "", "no repository root: the tracked %s cannot be read, so cycle %s's freeze cannot be cross-checked", rel, cycle)
		} else if fr, err := readFreezeFile(filepath.Join(v.o.Root, rel)); errors.Is(err, fs.ErrNotExist) {
			v.undet(rule, "", "the tracked %s is absent, so the register's freeze of cycle %s cannot be cross-checked", rel, cycle)
		} else if err != nil {
			v.undet(rule, "", "the tracked %s cannot be read: %v", rel, err)
		} else if fr.Cycle != cycle || !fr.consistent() {
			v.find(rule, "", "the tracked %s is internally inconsistent or names another cycle", rel)
		} else {
			file = fr
		}
		switch {
		case file != nil && meta == nil && metaRaw[cycle] == "":
			v.find(rule, "", "the tracked %s records a freeze of cycle %s that the register no longer holds", rel, cycle)
		case file != nil && meta != nil && !sameFreeze(file, meta):
			v.find(rule, "", "the register's freeze record for cycle %s differs from the tracked %s — it was rewritten after the freeze", cycle, rel)
		}
		auth := file
		if auth == nil {
			auth = meta
		}
		if auth == nil {
			continue
		}
		now, err := cycleMembers(v.db, cycle)
		if err != nil {
			return err
		}
		was := map[string]bool{}
		for _, m := range auth.Members {
			was[m] = true
		}
		is := map[string]bool{}
		for _, m := range now {
			is[m] = true
			if !was[m] {
				v.find(rule, m, "joined frozen cycle %s after its freeze; new discoveries belong to the next cycle (FR-026)", cycle)
			}
		}
		for _, m := range auth.Members {
			if !is[m] {
				v.find(rule, m, "left frozen cycle %s after its freeze; a frozen cycle's items are never dropped (FR-026)", cycle)
			}
		}
	}
	return nil
}

// V-G8 — every declared submodule carries a roster identifier.
func (v *gapValidator) ruleG8() {
	if v.o.Roster == nil {
		v.undet("V-G8", "", "no roster supplied — declared-submodule coverage cannot be checked")
		return
	}
	for _, p := range v.o.Roster.Undetermined {
		v.find("V-G8", "", "declared submodule %s carries no roster identifier in %s", p, RosterPath)
	}
}

var optionLineRe = regexp.MustCompile(`^\s*(?:[-*•]|\d+[.)])\s+\S`)
var costRe = regexp.MustCompile(`(?i)\bcost\s*:\s*\S`)

// V-G11 — every Operator-blocked item (gap or legacy) records the decision
// needed, the unblock options, and the cost of each (FR-009). Options are the
// list lines of operator_block_details.unblock_condition; each must carry
// "cost: <text>".
func (v *gapValidator) ruleG11() error {
	const rule = "V-G11"
	rows, err := v.db.Query(`SELECT i.atm_id, d.atm_id IS NOT NULL, COALESCE(d.what,''), COALESCE(d.unblock_condition,'')
        FROM items i LEFT JOIN operator_block_details d ON d.atm_id = i.atm_id
        WHERE i.status = ? ORDER BY i.atm_id`, StatusBlocked)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var id, what, cond string
		var has bool
		if err := rows.Scan(&id, &has, &what, &cond); err != nil {
			return err
		}
		if !has {
			v.find(rule, id, "Operator-blocked with no operator_block_details row (decision, options, cost)")
			continue
		}
		if strings.TrimSpace(what) == "" {
			v.find(rule, id, "operator_block_details.what (the decision needed) is blank")
		}
		options := 0
		for i, line := range strings.Split(cond, "\n") {
			if !optionLineRe.MatchString(line) {
				continue
			}
			options++
			if !costRe.MatchString(line) {
				v.find(rule, id, "unblock option on line %d carries no \"cost: …\"", i+1)
			}
		}
		if options == 0 {
			v.find(rule, id, "unblock_condition lists no option (one list line per option, each with \"cost: …\")")
		}
	}
	return rows.Err()
}

// V-G12 — every item_verdicts row names an existing item.
func (v *gapValidator) ruleG12() error {
	rows, err := v.db.Query(`SELECT item_id, role, actor FROM item_verdicts vv
        WHERE NOT EXISTS (SELECT 1 FROM items i WHERE i.atm_id = vv.item_id) ORDER BY item_id, role, actor`)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var id, role, actor string
		if err := rows.Scan(&id, &role, &actor); err != nil {
			return err
		}
		v.find("V-G12", id, "item_verdicts row (%s by %s) names no existing item", role, actor)
	}
	return rows.Err()
}
