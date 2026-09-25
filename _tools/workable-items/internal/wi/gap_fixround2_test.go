package wi

// Fix round 2 (scoped re-review): N1, N2, N3 and the two minors. Written
// before the fixes and observed failing first. The package clock is
// 2026-09-27T00:00:00Z unless a test moves it (fixtures_test.go TestMain).

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const ev = fixtureRel + "/evidence/"

// ── N1: the reopen cut ─────────────────────────────────────────────────────

// The reviewer's repro, step 1: `gap reopen` with a failing record dated long
// before the item's latest closure must be refused (apply-queue already skips it).
func TestN1ReopenRefusesAFailingRecordOlderThanTheLatestClosure(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	old := writeRecord(t, repo, "ev/VSC-004-fail-2020.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004",
		"outcome": 1, "exit_status": 1, "verdict_role": "verifier", "ts": "2020-01-01T00:00:00Z", "chain_seq": 50})
	before := fileSHA(t, db)
	if rc, out := gapRun(t, repo, db, "reopen", "--id", "VSC-004", "--evidence", old, "--plan-due", "2026-12-31", "--as-of", fixtureAsOf); rc != 1 || !strings.Contains(out, "latest closure") {
		t.Fatalf("reopen on a failing record older than the latest closure: want rc 1, got %d\n%s", rc, out)
	}
	if fileSHA(t, db) != before {
		t.Fatal("a refused reopen modified the register")
	}
}

func TestN1ReopenRefusesAFutureFailingRecord(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	future := writeRecord(t, repo, "ev/VSC-004-fail-2031.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004",
		"outcome": 1, "exit_status": 1, "verdict_role": "verifier", "ts": "2031-01-01T00:00:00Z", "chain_seq": 51})
	if rc, out := gapRun(t, repo, db, "reopen", "--id", "VSC-004", "--evidence", future, "--plan-due", "2026-12-31", "--as-of", fixtureAsOf); rc != 1 || !strings.Contains(out, "in the future") {
		t.Fatalf("reopen on a failing record dated in the future: want rc 1, got %d\n%s", rc, out)
	}
	writeQueue(t, repo, `{"item_id":"VSC-004","evidence":"`+future+`"}`)
	before := fileSHA(t, db)
	if rc, out := gapRun(t, repo, db, "apply-queue", "--as-of", fixtureAsOf); rc != 1 || !strings.Contains(out, "in the future") {
		t.Fatalf("apply-queue with a future-dated record: want rc 1, got %d\n%s", rc, out)
	}
	if fileSHA(t, db) != before {
		t.Fatal("a refused apply-queue modified the register")
	}
}

func TestN1CloseRefusesFutureDatedEvidence(t *testing.T) {
	k := prepareClose(t)
	b := strings.Repeat("b", 64)
	g := writeRecord(t, k.repo, "ev/VSC-001-green-2031.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2031-01-01T00:00:00Z", "chain_seq": 52})
	v := writeRecord(t, k.repo, "ev/VSC-001-verifier-2031.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2031-01-01T01:00:00Z", "chain_seq": 53})
	applySQL(t, k.db, `DELETE FROM item_verdicts WHERE item_id='VSC-001' AND role='verifier';
INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','verifier','agent-verifier-C','agent','2026-09-25',0,'`+v+`')`)
	rc, out := gapRun(t, k.repo, k.db, withArg(withArg(k.args(), "--green-evidence", g), "--verdict-ref", v)...)
	if rc != 1 || !strings.Contains(out, "in the future") {
		t.Fatalf("close on a future-dated GREEN (with a matching future verifier): want rc 1, got %d\n%s", rc, out)
	}
}

// directReclose appends, by direct DB edit, a re-closure of golden-good's
// VSC-004 whose RED/GREEN/close rows reuse the ORIGINAL files and whose verdict
// rows re-record the ORIGINAL verifier and review files under a later date.
func directReclose(t *testing.T, path string) {
	t.Helper()
	applySQL(t, path, `
INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES
 ('VSC-004','verifier','agent-verifier-C','agent','2026-09-27',0,'`+ev+`VSC-004-verifier.json'),
 ('VSC-004','reviewer','agent-reviewer-D','agent','2026-09-27',0,'`+ev+`VSC-004-review.md');
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES
 ('VSC-004','Updated','AI','2026-09-27','zero-gap:red-evidence check=CHK-vsc-004','`+ev+`VSC-004-red.json','2026-09-27 01:00:00'),
 ('VSC-004','Updated','AI','2026-09-27','zero-gap:green-evidence check=CHK-vsc-004','`+ev+`VSC-004-green.json','2026-09-27 01:00:00'),
 ('VSC-004','Fixed','AI','2026-09-27','zero-gap:close fixer=agent-fixer-A check-author=agent-author-B verdict=`+ev+`VSC-004-verifier.json','`+ev+`VSC-004-green.json','2026-09-27 01:00:00');`)
}

// validate on a DIRECTLY EDITED register: a Reopened row whose failing record
// says 2020 must not move the cut before the latest closure.
func TestN1ValidatorCutIsNeverBeforeTheLatestClosure(t *testing.T) {
	root := fixtureRoot(t, false)
	writeRecord(t, root, "ev/VSC-004-fail-2020.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004",
		"outcome": 1, "exit_status": 1, "verdict_role": "verifier", "ts": "2020-01-01T00:00:00Z", "chain_seq": 50})
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES
 ('VSC-004','Reopened','AI','2026-09-26','captured-evidence-contradicts','ev/VSC-004-fail-2020.json','2026-09-26 13:00:00'),
 ('VSC-004','Updated','AI','2026-09-26','`+WatermarkPrefix+`','','2026-09-26 13:00:00');`)
	directReclose(t, path)
	rep := validateGapIn(t, root, path, fixtureAsOf, fixtureRoster())
	if !hasGapFinding(rep, "V-G3", "VSC-004") {
		t.Fatalf("a re-close on the original evidence after a reopen dated 2020 was accepted: %v", rep.Findings)
	}
}

// The cut is monotonic: a canonical Reopened row at 18:40 followed by a
// Reopened row whose record says 14:00 must not move it back to 14:00.
func TestN1ValidatorCutIsMonotonic(t *testing.T) {
	root := fixtureRoot(t, false)
	e := strings.Repeat("e", 64)
	writeRecord(t, root, "ev/VSC-004-fail-1400.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004",
		"outcome": 1, "exit_status": 1, "verdict_role": "verifier", "ts": "2026-09-26T14:00:00Z", "chain_seq": 53})
	writeRecord(t, root, "ev/VSC-004-green-1600.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004",
		"outcome": 0, "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-26T16:00:00Z", "chain_seq": 54})
	writeRecord(t, root, "ev/VSC-004-verifier-1630.json", map[string]any{"item_id": "VSC-004", "check_id": "CHK-vsc-004",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-26T16:30:00Z", "chain_seq": 55})
	writeText(t, root, "ev/VSC-004-review-1610.md", "a new review of VSC-004\n")
	touch(t, root, "ev/VSC-004-review-1610.md", "2026-09-26T16:10:00Z")
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path,created_at) VALUES
 ('VSC-004','Reopened','User','2026-09-26','end-user-report','`+ev+`sweep-finding.json','2026-09-26 18:40:00'),
 ('VSC-004','Reopened','AI','2026-09-26','captured-evidence-contradicts','ev/VSC-004-fail-1400.json','2026-09-26 13:00:00'),
 ('VSC-004','Updated','AI','2026-09-26','`+WatermarkPrefix+`','','2026-09-26 13:00:00'),
 ('VSC-004','Updated','AI','2026-09-26','zero-gap:red-evidence check=CHK-vsc-004','`+ev+`VSC-004-red.json','2026-09-26 19:00:00'),
 ('VSC-004','Updated','AI','2026-09-26','zero-gap:green-evidence check=CHK-vsc-004','ev/VSC-004-green-1600.json','2026-09-26 19:00:00'),
 ('VSC-004','Fixed','AI','2026-09-26','zero-gap:close fixer=agent-fixer-A check-author=agent-author-B verdict=ev/VSC-004-verifier-1630.json','ev/VSC-004-green-1600.json','2026-09-26 19:00:00');
INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES
 ('VSC-004','verifier','agent-verifier-C','agent','2026-09-26',0,'ev/VSC-004-verifier-1630.json'),
 ('VSC-004','reviewer','agent-reviewer-D','agent','2026-09-26',0,'ev/VSC-004-review-1610.md');
INSERT INTO test_diary (atm_id,date_time,tested_by,result,observations,action_taken,evidence_path)
 VALUES ('VSC-004','2026-09-26T16:05:00Z','AI-agent','PASS','run','none','ev/VSC-004-green-1600.json');`)
	rep := validateGapIn(t, root, path, fixtureAsOf, fixtureRoster())
	found := false
	for _, f := range rep.Findings {
		if f.Rule == "V-G3" && f.ItemID == "VSC-004" && strings.Contains(f.Detail, "GREEN evidence ev/VSC-004-green-1600.json") {
			found = true
		}
	}
	if !found {
		t.Fatalf("a GREEN measured at 16:00 counted after a reopen at 18:40: %v", rep.Findings)
	}
}

// ── N2: the verifier's evidence is a SEPARATE run ─────────────────────────

func TestN2TheGreenRecordCannotBeItsOwnVerifier(t *testing.T) {
	k := prepareClose(t)
	b := strings.Repeat("b", 64)
	// The repro: GREEN written with verdict_role verifier, then cited as the verifier's evidence.
	g := writeRecord(t, k.repo, "ev/VSC-001-green-as-verifier.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2026-09-25T11:00:00Z"})
	applySQL(t, k.db, `DELETE FROM item_verdicts WHERE item_id='VSC-001' AND role='verifier'`)
	gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C",
		"--actor-kind", "agent", "--outcome", "0", "--evidence", g, "--on", fixtureAsOf)
	applySQL(t, k.db, `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','verifier','agent-verifier-C','agent','2026-09-25',0,'`+g+`')`)
	args := withArg(withArg(k.args(), "--green-evidence", g), "--verdict-ref", g)
	if rc, out := gapRun(t, k.repo, k.db, args...); rc != 1 || !strings.Contains(out, "(N2)") {
		t.Fatalf("GREEN cited as its own verifier: want rc 1 naming N2, got %d\n%s", rc, out)
	}
}

func TestN2VerifierRecordMustNotCopyTheGreen(t *testing.T) {
	cases := map[string]func(k closeKit) string{
		"byte-identical copy of the GREEN at another path": func(k closeKit) string {
			b, _ := os.ReadFile(filepath.Join(k.repo, k.green))
			return writeText(t, k.repo, "ev/VSC-001-green-copy.json", string(b))
		},
		"same ts as the GREEN": func(k closeKit) string {
			b := strings.Repeat("b", 64)
			return writeRecord(t, k.repo, "ev/VSC-001-verifier-same-ts.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
				"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": b, "state_fingerprint_after": b,
				"ts": "2026-09-25T11:00:00Z", "chain_seq": 60})
		},
		"same chain_seq as the GREEN": func(k closeKit) string {
			b := strings.Repeat("b", 64)
			return writeRecord(t, k.repo, "ev/VSC-001-verifier-same-seq.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
				"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": b, "state_fingerprint_after": b,
				"ts": "2026-09-25T11:30:00Z", "chain_seq": 11}) // the GREEN's chain_seq (prepareClose)
		},
	}
	for name, mk := range cases {
		t.Run(name, func(t *testing.T) {
			k := prepareClose(t)
			v := mk(k)
			applySQL(t, k.db, `DELETE FROM item_verdicts WHERE item_id='VSC-001' AND role='verifier';
INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-001','verifier','agent-verifier-C','agent','2026-09-25',0,'`+v+`')`)
			rc, out := gapRun(t, k.repo, k.db, withArg(k.args(), "--verdict-ref", v)...)
			if rc != 1 {
				t.Fatalf("want rc 1, got %d\n%s", rc, out)
			}
			// The byte copy is a GUARD: round 1's role check already refuses a
			// GREEN (verdict_role author) cited as verifier evidence.
			if name != "byte-identical copy of the GREEN at another path" && !strings.Contains(out, "(N2)") {
				t.Fatalf("refused for another reason than the N2 rule:\n%s", out)
			}
		})
	}
}

// ── N3: reviewer evidence is time-bound and never reused ───────────────────

// The exact re-record repro: after a legitimate reopen and fresh RED/GREEN/
// verifier/diary, the OLD review file is re-recorded under a later --on date.
func TestN3AnOldReviewReRecordedAfterAReopenIsNotFresh(t *testing.T) {
	k := prepareClose(t)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("first close: rc %d\n%s", rc, out)
	}
	fail := reopenVSC001(t, k)
	e := strings.Repeat("e", 64)
	green := writeRecord(t, k.repo, "ev/VSC-001-green2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-27T16:00:00Z", "chain_seq": 41})
	ver := writeRecord(t, k.repo, "ev/VSC-001-verifier2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-27T16:30:00Z", "chain_seq": 42})
	touch(t, k.repo, k.review, "2026-09-27T16:10:00Z") // even a fresh mtime must not launder a reused review
	setClock(t, "2026-09-27T17:00:00Z")
	for _, v := range [][]string{
		{"verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C", "--actor-kind", "agent", "--outcome", "0", "--evidence", ver, "--on", "2026-09-27"},
		{"verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D", "--actor-kind", "agent", "--outcome", "0", "--evidence", k.review, "--on", "2026-09-27"},
	} {
		gapRun(t, k.repo, k.db, v...)
	}
	addDiary(t, k.db, green, "2026-09-27T16:05:00Z")
	args := withArg(withArg(withArg(k.args(), "--red-evidence", fail), "--green-evidence", green), "--verdict-ref", ver)
	if rc, out := gapRun(t, k.repo, k.db, args...); rc != 1 || !strings.Contains(out, "byte-identical to evidence used before the latest reopen") {
		t.Fatalf("re-close with the OLD review re-recorded: want rc 1 naming the review, got %d\n%s", rc, out)
	}
}

func TestN3AReviewFileOlderThanTheCutIsNotFresh(t *testing.T) {
	k := prepareClose(t)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("first close: rc %d\n%s", rc, out)
	}
	fail := reopenVSC001(t, k)
	e := strings.Repeat("e", 64)
	green := writeRecord(t, k.repo, "ev/VSC-001-green2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-27T16:00:00Z", "chain_seq": 41})
	ver := writeRecord(t, k.repo, "ev/VSC-001-verifier2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": e, "state_fingerprint_after": e, "ts": "2026-09-27T16:30:00Z", "chain_seq": 42})
	rev := writeText(t, k.repo, "ev/VSC-001-review-stale.md", "a different text, but written before the reopen\n")
	touch(t, k.repo, rev, "2026-09-27T10:00:00Z")
	setClock(t, "2026-09-27T17:00:00Z")
	gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C", "--actor-kind", "agent", "--outcome", "0", "--evidence", ver, "--on", "2026-09-27")
	gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D", "--actor-kind", "agent", "--outcome", "0", "--evidence", rev, "--on", "2026-09-27")
	addDiary(t, k.db, green, "2026-09-27T16:05:00Z")
	args := withArg(withArg(withArg(k.args(), "--red-evidence", fail), "--green-evidence", green), "--verdict-ref", ver)
	if rc, out := gapRun(t, k.repo, k.db, args...); rc != 1 || !strings.Contains(out, "not after the latest reopen") {
		t.Fatalf("review file older than the reopen: want rc 1 naming the time bound, got %d\n%s", rc, out)
	}
}

// ── minors ─────────────────────────────────────────────────────────────────

func TestParseEvidenceRejectsTrailingContent(t *testing.T) {
	good, err := os.ReadFile(fixturePath(t, "evidence/VSC-004-green.json"))
	if err != nil {
		t.Fatal(err)
	}
	body := strings.TrimRight(string(good), "\n")
	if _, err := ParseEvidenceRecord([]byte(body + "\n  \n")); err != nil {
		t.Fatalf("control: trailing whitespace refused: %v", err)
	}
	for _, tail := range []string{"]junk", "}junk", "junk", " {}", "]", "}"} {
		if _, err := ParseEvidenceRecord([]byte(body + tail)); err == nil {
			t.Errorf("trailing %q after the record was accepted", tail)
		}
	}
}

func TestEvidenceLargerThanTheCapIsRefused(t *testing.T) {
	k := prepareClose(t)
	good, _ := os.ReadFile(filepath.Join(k.repo, k.green))
	big := strings.TrimRight(string(good), "\n") + strings.Repeat(" ", 2<<20) + "\n"
	rel := writeText(t, k.repo, "ev/VSC-001-green-big.json", big)
	if _, err := ReadEvidenceRecord(filepath.Join(k.repo, rel)); err == nil || !strings.Contains(err.Error(), "1 MiB") {
		t.Fatalf("a 2 MiB record: want an error naming the 1 MiB cap, got %v", err)
	}
	if rc, out := gapRun(t, k.repo, k.db, withArg(k.args(), "--green-evidence", rel)...); rc != 1 || !strings.Contains(out, "1 MiB") {
		t.Fatalf("close with an oversized GREEN: want rc 1 naming the cap, got %d\n%s", rc, out)
	}
}
