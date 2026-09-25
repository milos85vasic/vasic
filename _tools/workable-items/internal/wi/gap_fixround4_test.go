package wi

// Fix round 4 (round-3 independent re-review): F1 partial schema, F2 special
// files, F3 RED reuse, F4 streaming hash, F5 backdated citing rows, F6 honesty
// notice. Written before the fixes and observed failing first; the cases that
// already passed are named as guards in the report, never claimed as RED.

import (
	"errors"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"testing"
	"time"
)

// bounded runs fn and fails the test — instead of hanging the suite — when it
// has not returned within limit (F2: a regression must FAIL, not hang).
func bounded(t *testing.T, limit time.Duration, fn func()) {
	t.Helper()
	done := make(chan struct{})
	go func() { fn(); close(done) }()
	select {
	case <-done:
	case <-time.After(limit):
		t.Fatalf("HUNG: the call did not return within %s (a FIFO or other special file blocked it)", limit)
	}
}

func mkfifo(t *testing.T, repo, rel string) string {
	t.Helper()
	p := filepath.Join(repo, rel)
	os.MkdirAll(filepath.Dir(p), 0o755)
	if err := syscall.Mkfifo(p, 0o600); err != nil {
		t.Fatalf("mkfifo %s: %v", p, err)
	}
	return rel
}

// mksocket places a unix socket at rel (a second kind of special file that
// open(2) refuses with ENXIO rather than blocking). It is bound at a SHORT
// path first — sun_path is 108 bytes and a t.TempDir() under a long test
// name exceeds it — and the socket inode is renamed into place.
func mksocket(t *testing.T, repo, rel string) string {
	t.Helper()
	p := filepath.Join(repo, rel)
	os.MkdirAll(filepath.Dir(p), 0o755)
	short, err := os.MkdirTemp(os.TempDir(), "zg")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(short) })
	l, err := net.Listen("unix", filepath.Join(short, "s"))
	if err != nil {
		t.Fatalf("unix socket: %v", err)
	}
	t.Cleanup(func() { l.Close() })
	if err := os.Rename(filepath.Join(short, "s"), p); err != nil {
		t.Fatalf("moving the socket to %s: %v", p, err)
	}
	return rel
}

// ── F1: a PARTIALLY migrated register is exit 2 naming the missing DDL ────

func TestF1EachSingleDroppedGapColumnIsPartialNotUnmigrated(t *testing.T) {
	for _, c := range GapColumns {
		t.Run(c.Name, func(t *testing.T) {
			path := buildRegister(t, true, "golden-good.sql")
			applySQL(t, path, `ALTER TABLE items DROP COLUMN `+c.Name)
			db := openFixture(t, path)
			_, err := ValidateGap(db, GapOptions{AsOf: fixtureAsOf, Root: fixtureRoot(t, false), Roster: fixtureRoster()})
			want := "ALTER TABLE items ADD COLUMN " + c.Name + " " + c.Type + ";"
			if err == nil || errors.Is(err, ErrNotMigrated) || !strings.Contains(err.Error(), want) {
				t.Fatalf("dropped %s: want a PARTIAL-schema error naming %q, got %v", c.Name, want, err)
			}
			// The CLI: validate is 2 (never 0 'OK'), summary is 2, both naming the DDL.
			repo := gapRepo(t)
			if rc, out := gapRun(t, repo, path, "summary"); rc != 2 || !strings.Contains(out, want) {
				t.Fatalf("gap summary on a register lacking %s: want rc 2 naming %q, got %d\n%s", c.Name, want, rc, out)
			}
		})
	}
}

func TestF1MissingVerdictsTableWithGapColumnsIsPartial(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `DROP TABLE item_verdicts`)
	db := openFixture(t, path)
	_, err := ValidateGap(db, GapOptions{AsOf: fixtureAsOf, Root: fixtureRoot(t, false), Roster: fixtureRoster()})
	if err == nil || errors.Is(err, ErrNotMigrated) || !strings.Contains(err.Error(), "CREATE TABLE IF NOT EXISTS item_verdicts") {
		t.Fatalf("gap columns without item_verdicts: want a PARTIAL-schema error naming the CREATE TABLE, got %v", err)
	}
}

func TestF1VerdictsTableLackingTheDigestColumnIsPartial(t *testing.T) {
	// A round-2 register (7-column item_verdicts) — or one DROP COLUMN — is
	// the case the reviewer reproduced: the gate must not switch OFF.
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `ALTER TABLE item_verdicts DROP COLUMN evidence_sha256;
DELETE FROM item_verdicts WHERE item_id='VSC-004';
UPDATE items SET research_ref=NULL WHERE atm_id='VSC-004';`)
	db := openFixture(t, path)
	_, err := ValidateGap(db, GapOptions{AsOf: fixtureAsOf, Root: fixtureRoot(t, false), Roster: fixtureRoster()})
	if err == nil || errors.Is(err, ErrNotMigrated) || !strings.Contains(err.Error(), VerdictDigestDDL) {
		t.Fatalf("item_verdicts without evidence_sha256: want a PARTIAL-schema error naming %q, got %v", VerdictDigestDDL, err)
	}
	if rc, out := gapRun(t, gapRepo(t), path, "close", "--id", "VSC-001", "--red-evidence", "x", "--green-evidence", "y",
		"--verdict-ref", "z", "--fixer", "a", "--check-author", "b"); rc != 2 || !strings.Contains(out, VerdictDigestDDL) {
		t.Fatalf("gap close on a partially migrated register: want rc 2 naming the DDL, got %d\n%s", rc, out)
	}
}

func TestF1GapHistoryRowsWithNoSchemaArePartial(t *testing.T) {
	path := buildRegister(t, false, "legacy-register.sql")
	applySQL(t, path, `INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path)
        VALUES ('VSC-001','Opened','AI','2026-09-25','zero-gap:opened sweep_class=SC-x','ev/x.json')`)
	db := openFixture(t, path)
	_, err := ValidateGap(db, GapOptions{AsOf: fixtureAsOf, Root: fixtureRoot(t, false), Roster: fixtureRoster()})
	if err == nil || errors.Is(err, ErrNotMigrated) {
		t.Fatalf("zero-gap history rows on a register with no schema: want a PARTIAL-schema error, got %v", err)
	}
	for _, want := range []string{"ALTER TABLE items ADD COLUMN kind TEXT;", "ALTER TABLE items ADD COLUMN first_seen_fingerprint TEXT;", "CREATE TABLE IF NOT EXISTS item_verdicts"} {
		if !strings.Contains(err.Error(), want) {
			t.Fatalf("the error does not name %q: %v", want, err)
		}
	}
}

// Control: a register with NO gap column, NO item_verdicts and NO zero-gap
// history row is still 'unmigrated' (ErrNotMigrated) — the NOTE path survives.
func TestF1ATrulyUnmigratedRegisterIsStillNotMigrated(t *testing.T) {
	db := openFixture(t, buildRegister(t, false, "legacy-register.sql"))
	if _, err := ValidateGap(db, GapOptions{AsOf: fixtureAsOf, Root: fixtureRoot(t, false), Roster: fixtureRoster()}); !errors.Is(err, ErrNotMigrated) {
		t.Fatalf("want ErrNotMigrated, got %v", err)
	}
}

// ── F2: special files must be refused, never waited on ────────────────────

func TestF2GapCloseWithAFIFORedEvidenceIsRefusedNotHung(t *testing.T) {
	k := prepareClose(t)
	fifo := mkfifo(t, k.repo, "ev/red.fifo")
	before := fileSHA(t, k.db)
	var rc int
	var out string
	bounded(t, 20*time.Second, func() { rc, out = gapRun(t, k.repo, k.db, withArg(k.args(), "--red-evidence", fifo)...) })
	if rc != 1 || !strings.Contains(out, "not a regular file") {
		t.Fatalf("FIFO as --red-evidence: want rc 1 'not a regular file', got %d\n%s", rc, out)
	}
	if fileSHA(t, k.db) != before {
		t.Fatal("a refused close modified the register")
	}
}

func TestF2GapVerdictWithASpecialFileIsRefusedNotHung(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	fifo := mkfifo(t, repo, "ev/verdict.fifo")
	sock := mksocket(t, repo, "ev/verdict.sock")
	for _, role := range []string{"verifier", "reviewer"} {
		for name, p := range map[string]string{"fifo": fifo, "socket": sock} {
			var rc int
			var out string
			bounded(t, 20*time.Second, func() {
				rc, out = gapRun(t, repo, db, "verdict", "--id", "VSC-001", "--role", role, "--actor", "agent-x",
					"--actor-kind", "agent", "--outcome", "0", "--evidence", p, "--on", fixtureAsOf)
			})
			if rc != 1 || !strings.Contains(out, "not a") {
				t.Fatalf("%s %s: want rc 1 refusing the special file, got %d\n%s", role, name, rc, out)
			}
		}
	}
}

func TestF2ValidateWithACitedFileSwappedForASpecialFileIsAFindingNotAHang(t *testing.T) {
	for _, target := range []string{"green", "red", "verifier", "review", "research"} {
		for _, kind := range []string{"fifo", "socket"} {
			t.Run(target+"/"+kind, func(t *testing.T) {
				k := prepareClose(t)
				if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
					t.Fatalf("close: rc %d\n%s", rc, out)
				}
				rel := map[string]string{"green": k.green, "red": k.red, "verifier": k.verdict, "review": k.review, "research": k.research}[target]
				os.Remove(filepath.Join(k.repo, rel))
				if kind == "fifo" {
					mkfifo(t, k.repo, rel)
				} else {
					mksocket(t, k.repo, rel)
				}
				r, _ := LoadRoster(k.repo)
				var rep *Report
				bounded(t, 20*time.Second, func() { rep = validateGapIn(t, k.repo, k.db, clockAsOf, r) })
				if rep.ExitCode() != 1 || !hasGapFinding(rep, "V-G3", "VSC-001") {
					t.Fatalf("%s swapped for a %s: want rc 1 with a V-G3 finding, got %d %v %v", target, kind, rep.ExitCode(), rep.Findings, rep.Undetermined)
				}
			})
		}
	}
}

// ── F3: the FIRST closure's RED never supports a re-close ─────────────────

// freshReclose readies everything a re-close after reopenVSC001 needs — new
// GREEN, verifier, review and diary — and returns the close args with the
// given RED (the reopen's failing record is the legitimate one).
func freshReclose(t *testing.T, k closeKit, red string) []string {
	t.Helper()
	e := strings.Repeat("e", 64)
	green := writeRecord(t, k.repo, "ev/VSC-001-green2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-27T16:00:00Z", "chain_seq": 41})
	ver := writeRecord(t, k.repo, "ev/VSC-001-verifier2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-27T16:30:00Z", "chain_seq": 42})
	rev := writeText(t, k.repo, "ev/VSC-001-review2.md", "second review of VSC-001: accepted\n")
	touch(t, k.repo, rev, "2026-09-27T16:10:00Z")
	setClock(t, "2026-09-27T17:00:00Z")
	for _, v := range [][]string{
		{"verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C", "--actor-kind", "agent", "--outcome", "0", "--evidence", ver, "--on", clockAsOf},
		{"verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D", "--actor-kind", "agent", "--outcome", "0", "--evidence", rev, "--on", clockAsOf},
	} {
		if rc, out := gapRun(t, k.repo, k.db, v...); rc != 0 {
			t.Fatalf("verdict: rc %d\n%s", rc, out)
		}
	}
	addDiary(t, k.db, green, "2026-09-27T16:05:00Z")
	return withArg(withArg(withArg(k.args(), "--red-evidence", red), "--green-evidence", green), "--verdict-ref", ver)
}

func TestF3ReCloseReusingTheFirstClosuresRedIsRefused(t *testing.T) {
	for _, which := range []string{"same path", "byte copy"} {
		t.Run(which, func(t *testing.T) {
			k := prepareClose(t)
			if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
				t.Fatalf("first close: rc %d\n%s", rc, out)
			}
			reopenVSC001(t, k)
			red := k.red
			if which == "byte copy" {
				b, _ := os.ReadFile(filepath.Join(k.repo, k.red))
				red = writeText(t, k.repo, "ev/VSC-001-red-copy.json", string(b))
			}
			args := freshReclose(t, k, red)
			before := fileSHA(t, k.db)
			rc, out := gapRun(t, k.repo, k.db, args...)
			if rc != 1 || !strings.Contains(out, "RED evidence "+red+" was used in a previous closure") {
				t.Fatalf("re-close on the first closure's RED (%s): want rc 1 naming the reuse, got %d\n%s", which, rc, out)
			}
			if fileSHA(t, k.db) != before {
				t.Fatal("a refused re-close modified the register")
			}
		})
	}
}

// Control (guard): the reopen's own failing record IS the legitimate RED.
func TestF3ReCloseOnTheReopensFailureIsAccepted(t *testing.T) {
	k := prepareClose(t)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("first close: rc %d\n%s", rc, out)
	}
	fail := reopenVSC001(t, k)
	if rc, out := gapRun(t, k.repo, k.db, freshReclose(t, k, fail)...); rc != 0 {
		t.Fatalf("re-close on the reopen's failure: rc %d\n%s", rc, out)
	}
	gapCleanIn(t, k.repo, k.db)
}

// ── F4: hashing streams; parse and hash come from ONE read ────────────────

func TestF4HashingStreamsInsteadOfReadingTheWholeFile(t *testing.T) {
	const size = 256 << 20 // a sparse 256 MiB file costs no disk
	p := filepath.Join(t.TempDir(), "big.bin")
	f, err := os.Create(p)
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Truncate(size); err != nil {
		t.Fatal(err)
	}
	f.Close()
	runtime.GC()
	var before, after runtime.MemStats
	runtime.ReadMemStats(&before)
	d, err := fileDigest(p)
	if err != nil {
		t.Fatal(err)
	}
	runtime.ReadMemStats(&after)
	if d == "" {
		t.Fatal("no digest")
	}
	if alloc := after.TotalAlloc - before.TotalAlloc; alloc > 16<<20 {
		t.Fatalf("hashing a %d MiB file allocated %d MiB: it read the whole file into memory instead of streaming", size>>20, alloc>>20)
	}
}

// ── F5: a citing row created before its evidence was measured ─────────────

func TestF5ACitingRowCreatedBeforeItsEvidenceIsAFinding(t *testing.T) {
	cases := map[string]string{
		"GREEN row backdated":                               `UPDATE item_history SET created_at='2026-09-25 09:30:00' WHERE atm_id='VSC-001' AND reason LIKE 'zero-gap:green-evidence%'`,
		"closure row backdated (cites the verifier record)": `UPDATE item_history SET created_at='2026-09-25 09:30:00' WHERE atm_id='VSC-001' AND event_type='Fixed'`,
		"verifier row dated before its record":              `UPDATE item_verdicts SET on_date='2026-09-24' WHERE item_id='VSC-001' AND role='verifier'`,
	}
	for name, sqlText := range cases {
		t.Run(name, func(t *testing.T) {
			k := prepareClose(t)
			if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
				t.Fatalf("close: rc %d\n%s", rc, out)
			}
			gapCleanIn(t, k.repo, k.db)
			applySQL(t, k.db, sqlText)
			r, _ := LoadRoster(k.repo)
			rep := validateGapIn(t, k.repo, k.db, clockAsOf, r)
			if !hasDetail(rep, "V-G3", "VSC-001", "before the evidence it cites was measured") {
				t.Fatalf("%s went undetected: rc %d %v", name, rep.ExitCode(), rep.Findings)
			}
		})
	}
}

func TestF5GoldenBadBackdatedRowsTripsExactlyVG3(t *testing.T) {
	rep := validateGapFixture(t, buildRegister(t, true, "golden-good.sql", "golden-bad/V-G3-backdated-rows.sql"), fixtureAsOf, fixtureRoster())
	if rep.ExitCode() != 1 {
		t.Fatalf("want rc 1, got %d: %v %v", rep.ExitCode(), rep.Findings, rep.Undetermined)
	}
	if got := sortedRules(rep); strings.Join(got, ",") != "V-G3" {
		t.Fatalf("want exactly [V-G3], got %v: %v", got, rep.Findings)
	}
}

func TestF5GapVerdictRefusesAnOnDateBeforeTheRecord(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	own := writeRecord(t, repo, "ev/VSC-001-verifier.json", map[string]any{"item_id": "VSC-001", "verdict_role": "verifier", "ts": "2026-09-25T11:30:00Z"})
	before := fileSHA(t, db)
	rc, out := gapRun(t, repo, db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C", "--actor-kind", "agent",
		"--outcome", "0", "--evidence", own, "--on", "2026-09-24")
	if rc != 1 || !strings.Contains(out, "before") {
		t.Fatalf("--on a day before the record's ts: want rc 1, got %d\n%s", rc, out)
	}
	if fileSHA(t, db) != before {
		t.Fatal("a refused verdict modified the register")
	}
}

// ── F6: the honesty notice ────────────────────────────────────────────────

// f6Notice is spelled out here, independently of the constant the code
// carries, so a silent edit to either is caught by the other.
const f6Notice = "closed = structurally consistent + self-recorded digests; NOT independently proven until T068 chain binding"

func TestF6NoticeOnCloseSummaryAndUsage(t *testing.T) {
	k := prepareClose(t)
	rc, out := gapRun(t, k.repo, k.db, k.args()...)
	if rc != 0 || !strings.Contains(out, "\n"+f6Notice+"\n") {
		t.Fatalf("gap close: want rc 0 with the notice line, got %d\n%s", rc, out)
	}
	if rc, out := gapRun(t, k.repo, k.db, "summary"); rc != 0 || !strings.Contains(out, "\n"+f6Notice+"\n") {
		t.Fatalf("gap summary: want rc 0 with the notice line, got %d\n%s", rc, out)
	}
	rc, j1 := gapRun(t, k.repo, k.db, "summary", "--json")
	if rc != 0 || !strings.Contains(j1, f6Notice) {
		t.Fatalf("gap summary --json: want rc 0 carrying the notice, got %d\n%s", rc, j1)
	}
	if _, j2 := gapRun(t, k.repo, k.db, "summary", "--json"); j2 != j1 {
		t.Fatal("summary --json is not byte-stable with the notice")
	}
	if rc, _, errs := runGapCLI(t); rc != 2 || !strings.Contains(errs, f6Notice) {
		t.Fatalf("gap usage: want the notice in the usage text, got rc %d\n%s", rc, errs)
	}
}

// F4 (guard, written after the streaming fix): the record and the digest a
// command records come from ONE read of the same bytes — the digest equals the
// sha256 of the file, and `gap close` writes exactly that digest into the
// history rows it creates (no second read between parse and hash).
func TestF4RecordAndDigestComeFromTheSameBytes(t *testing.T) {
	k := prepareClose(t)
	for _, rel := range []string{k.red, k.green, k.verdict} {
		rec, d, err := ReadEvidenceRecordDigest(filepath.Join(k.repo, rel))
		if err != nil || rec == nil {
			t.Fatalf("%s: %v", rel, err)
		}
		if want := fileSHA(t, filepath.Join(k.repo, rel)); d != want {
			t.Fatalf("%s: digest %s is not the file's sha256 %s", rel, d, want)
		}
	}
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("close: rc %d\n%s", rc, out)
	}
	db := rawOpen(t, k.db)
	for _, c := range []struct{ prefix, rel string }{{"zero-gap:red-evidence", k.red}, {"zero-gap:green-evidence", k.green}} {
		var reason string
		if err := db.QueryRow(`SELECT reason FROM item_history WHERE atm_id='VSC-001' AND reason LIKE ?`, c.prefix+"%").Scan(&reason); err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(reason, "sha256="+fileSHA(t, filepath.Join(k.repo, c.rel))) {
			t.Fatalf("%s row does not carry the file's sha256: %s", c.prefix, reason)
		}
	}
}
