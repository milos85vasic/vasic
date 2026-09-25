package wi

// Fix round 1 (independent review T009): C1, C2, I1, I2, I3 and the minors.
// Every case here was written before its fix and observed failing first.

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"testing"
)

func sortedRules(rep *Report) []string {
	r := gapRules(rep)
	sort.Strings(r)
	return r
}

// Golden-bad fixtures added in round 1; each must trip exactly its rule set.
func TestRound1GoldenBadFixturesTripExactlyTheirRules(t *testing.T) {
	cases := []struct {
		file  string
		base  []string
		rules []string
	}{
		{"V-G3-verifier-junk", []string{"golden-good.sql"}, []string{"V-G3"}},
		{"V-G3-verifier-early", []string{"golden-good.sql"}, []string{"V-G3"}},
		{"V-G3-reviewer-dir", []string{"golden-good.sql"}, []string{"V-G3"}},
		{"V-G3-research-dir", []string{"golden-good.sql"}, []string{"V-G3"}},
		{"V-G3-V-G9-reclose-stale", []string{"golden-good.sql"}, []string{"V-G3", "V-G9"}},
		{"V-G3-V-G9-multibad", []string{"golden-good.sql"}, []string{"V-G3", "V-G9"}},
		{"V-G6-meta-rewritten", []string{"golden-good.sql", "frozen-cycle.sql"}, []string{"V-G6"}},
	}
	for _, c := range cases {
		t.Run(c.file, func(t *testing.T) {
			files := append(append([]string{}, c.base...), "golden-bad/"+c.file+".sql")
			rep := validateGapFixture(t, buildRegister(t, true, files...), fixtureAsOf, fixtureRoster())
			if rep.ExitCode() != 1 {
				t.Fatalf("want rc 1, got %d: findings=%v undet=%v", rep.ExitCode(), rep.Findings, rep.Undetermined)
			}
			if got := sortedRules(rep); strings.Join(got, ",") != strings.Join(c.rules, ",") {
				t.Fatalf("want exactly %v, got %v: %v", c.rules, got, rep.Findings)
			}
		})
	}
}

// ── C1: the verifier's evidence is READ ────────────────────────────────────

func TestC1GapVerdictReadsTheVerifierEvidence(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	junk := writeText(t, repo, "ev/junk.txt", "this is not an evidence record\n")
	other := writeRecord(t, repo, "ev/other-item.json", map[string]any{"item_id": "VSC-002", "verdict_role": "verifier"})
	author := writeRecord(t, repo, "ev/author-role.json", map[string]any{"item_id": "VSC-001", "verdict_role": "author"})
	failing := writeRecord(t, repo, "ev/failing.json", map[string]any{"item_id": "VSC-001", "verdict_role": "verifier", "outcome": 1})
	base := []string{"verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C",
		"--actor-kind", "agent", "--outcome", "0", "--on", fixtureAsOf}
	for name, ev := range map[string]string{
		"junk text file":                  junk,
		"record for another item":         other,
		"record with verdict_role author": author,
		"record outcome 1 vs --outcome 0": failing,
		"a directory":                     fixtureRel + "/evidence",
	} {
		before := fileSHA(t, db)
		if rc, out := gapRun(t, repo, db, append(base, "--evidence", ev)...); rc != 1 {
			t.Fatalf("%s: want rc 1, got %d\n%s", name, rc, out)
		}
		if fileSHA(t, db) != before {
			t.Fatalf("%s: a refused verdict modified the register", name)
		}
	}
	dir := []string{"verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D",
		"--actor-kind", "agent", "--outcome", "0", "--on", fixtureAsOf, "--evidence", fixtureRel + "/evidence"}
	if rc, out := gapRun(t, repo, db, dir...); rc != 1 {
		t.Fatalf("reviewer evidence that is a directory: want rc 1, got %d\n%s", rc, out)
	}
}

// The reviewer's reproduction: a verifier row whose evidence is junk (written
// past `gap verdict`) must not let `gap close` succeed.
func TestC1GapCloseRefusesAVerifierRowWhoseEvidenceIsNotARecord(t *testing.T) {
	k := prepareClose(t)
	junk := writeText(t, k.repo, "ev/junk.txt", "not a record\n")
	applySQL(t, k.db, `UPDATE item_verdicts SET evidence_path='`+junk+`' WHERE item_id='VSC-001' AND role='verifier'`)
	before := fileSHA(t, k.db)
	if rc, out := gapRun(t, k.repo, k.db, withArg(k.args(), "--verdict-ref", junk)...); rc != 1 {
		t.Fatalf("junk verifier evidence: want rc 1, got %d\n%s", rc, out)
	}
	if fileSHA(t, k.db) != before {
		t.Fatal("a refused close modified the register")
	}
}

func TestC1GapCloseRefusesAVerifierRecordThatDoesNotConfirmTheGreen(t *testing.T) {
	b := strings.Repeat("b", 64)
	for name, mods := range map[string]map[string]any{
		"verifier record older than GREEN":  {"ts": "2026-09-25T10:00:00Z"},
		"verifier record for another check": {"check_id": "CHK-other"},
	} {
		t.Run(name, func(t *testing.T) {
			k := prepareClose(t)
			m := map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001", "outcome": 0, "verdict_role": "verifier",
				"state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2026-09-25T11:30:00Z"}
			for kk, vv := range mods {
				m[kk] = vv
			}
			bad := writeRecord(t, k.repo, "ev/verifier-bad.json", m)
			applySQL(t, k.db, `DELETE FROM item_verdicts WHERE item_id='VSC-001' AND role='verifier'`)
			if rc, out := gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C",
				"--actor-kind", "agent", "--outcome", "0", "--evidence", bad, "--on", fixtureAsOf); rc != 0 {
				t.Fatalf("recording the verifier verdict: rc %d\n%s", rc, out)
			}
			if rc, out := gapRun(t, k.repo, k.db, withArg(k.args(), "--verdict-ref", bad)...); rc != 1 {
				t.Fatalf("want rc 1, got %d\n%s", rc, out)
			}
		})
	}
}

func TestC1AnEvidenceReferenceThatIsADirectoryIsNotEvidence(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `UPDATE item_history SET evidence_path='`+fixtureRel+`/evidence' WHERE atm_id='VSC-001'`)
	rep := validateGapFixture(t, path, fixtureAsOf, fixtureRoster())
	if !hasGapFinding(rep, "V-G1", "VSC-001") {
		t.Fatalf("a directory satisfied V-G1's evidence reference: %v", rep.Findings)
	}
}

// ── C2: re-closing on stale evidence ───────────────────────────────────────

func reopenVSC001(t *testing.T, k closeKit) string {
	t.Helper()
	// Round 2: the first close ran at the package clock (2026-09-27T00:00Z);
	// the failure is measured after it and the reopen runs after that.
	setClock(t, "2026-09-27T15:00:00Z")
	d := strings.Repeat("d", 64)
	fail := writeRecord(t, k.repo, "ev/VSC-001-fail.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 1, "exit_status": 1, "verdict_role": "verifier", "state_fingerprint_before": d, "state_fingerprint_after": d,
		"ts": "2026-09-27T14:00:00Z", "chain_seq": 40})
	if rc, out := gapRun(t, k.repo, k.db, "reopen", "--id", "VSC-001", "--evidence", fail, "--plan-due", "2026-12-31", "--as-of", fixtureAsOf); rc != 0 {
		t.Fatalf("reopen: rc %d\n%s", rc, out)
	}
	return fail
}

// The reviewer's exact sequence: close; reopen on a failing record at 14:00;
// close again with the ORIGINAL RED/GREEN (GREEN 11:00) and the old verdicts.
func TestC2ReCloseOnTheOriginalEvidenceIsRefused(t *testing.T) {
	k := prepareClose(t)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("first close: rc %d\n%s", rc, out)
	}
	reopenVSC001(t, k)
	before := fileSHA(t, k.db)
	rc, out := gapRun(t, k.repo, k.db, k.args()...)
	if rc != 1 {
		t.Fatalf("re-close on stale evidence: want rc 1, got %d\n%s", rc, out)
	}
	if fileSHA(t, k.db) != before {
		t.Fatal("a refused re-close modified the register")
	}
	if !strings.Contains(out, "V-G3") {
		t.Fatalf("the refusal does not name V-G3:\n%s", out)
	}
}

func TestC2ReCloseWithFreshEvidenceSucceeds(t *testing.T) {
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
	rev := writeText(t, k.repo, "ev/VSC-001-review2.md", "second review of VSC-001: accepted\n")
	touch(t, k.repo, rev, "2026-09-27T16:10:00Z")
	setClock(t, "2026-09-27T17:00:00Z")
	// Round 4 (F5): the verdicts are recorded on the day of the runs they
	// cite (clockAsOf); recording a 09-27 verification "on 09-25" is the
	// backdating the rule now refuses, and this test used to do it.
	for _, v := range [][]string{
		{"verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C", "--actor-kind", "agent", "--outcome", "0", "--evidence", ver, "--on", clockAsOf},
		{"verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D", "--actor-kind", "agent", "--outcome", "0", "--evidence", rev, "--on", clockAsOf},
	} {
		if rc, out := gapRun(t, k.repo, k.db, v...); rc != 0 {
			t.Fatalf("verdict: rc %d\n%s", rc, out)
		}
	}
	addDiary(t, k.db, green, "2026-09-27T16:05:00Z")
	args := withArg(withArg(withArg(k.args(), "--red-evidence", fail), "--green-evidence", green), "--verdict-ref", ver)
	if rc, out := gapRun(t, k.repo, k.db, args...); rc != 0 {
		t.Fatalf("re-close with fresh evidence: rc %d\n%s", rc, out)
	}
	gapCleanIn(t, k.repo, k.db)
}

// ── minor: the diary row is independent evidence, not written by close ─────

func TestGapCloseNeedsAnIndependentDiaryRowAndWritesNone(t *testing.T) {
	k := prepareClose(t)
	applySQL(t, k.db, `DELETE FROM test_diary WHERE atm_id='VSC-001'`)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 1 || !strings.Contains(out, "test_diary") {
		t.Fatalf("close with no independent diary PASS: want rc 1 naming test_diary, got %d\n%s", rc, out)
	}
	addDiary(t, k.db, k.green, "2026-09-25T11:05:00Z")
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("close with a diary row: rc %d\n%s", rc, out)
	}
	db := rawOpen(t, k.db)
	var n int
	db.QueryRow(`SELECT count(*) FROM test_diary WHERE atm_id='VSC-001'`).Scan(&n)
	if n != 1 {
		t.Fatalf("gap close wrote its own diary row: %d row(s) for VSC-001, want exactly the 1 recorded independently", n)
	}
}

// ── I1: determinism with several malformed fields ──────────────────────────

func TestI1MultiBadFieldVerdictIsIdenticalOnEveryRun(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql", "golden-bad/V-G3-V-G9-multibad.sql")
	root := fixtureRoot(t, true)
	first, _ := json.Marshal(validateGapIn(t, root, path, fixtureAsOf, fixtureRoster()))
	for i := 0; i < 19; i++ {
		again, _ := json.Marshal(validateGapIn(t, root, path, fixtureAsOf, fixtureRoster()))
		if !bytes.Equal(again, first) {
			t.Fatalf("run %d differs:\n%s\n%s", i+2, first, again)
		}
	}
	b, _ := os.ReadFile(fixturePath(t, "evidence/VSC-004-green-multibad.json"))
	_, e1 := ParseEvidenceRecord(b)
	for i := 0; i < 50; i++ {
		if _, e := ParseEvidenceRecord(b); e == nil || e.Error() != e1.Error() {
			t.Fatalf("ParseEvidenceRecord error text varies: %v vs %v", e1, e)
		}
	}
}

// ── I2: environment faults are 2, never 1; concurrent writers ──────────────

func TestI2AWriteToAReadOnlyRegisterIsTwo(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("SKIPPED (not passed): running as root, file permissions cannot make the register read-only")
	}
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	if err := os.Chmod(db, 0o444); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(db, 0o644) })
	if rc, out := gapRun(t, repo, db, addArgs...); rc != 2 {
		t.Fatalf("gap add on a read-only register: want rc 2 (could not write), got %d\n%s", rc, out)
	}
}

func TestI2ParallelAddsNeverExitOneAndLoseNothing(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	const n = 8
	rcs := make([]int, n)
	outs := make([]string, n)
	var wg sync.WaitGroup
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			var o, e bytes.Buffer
			args := append([]string{addArgs[0], "--repo", repo, "--db", db}, addArgs[1:]...)
			rcs[i] = RunGap(args, &o, &e)
			outs[i] = o.String() + e.String()
		}(i)
	}
	wg.Wait()
	ok := 0
	for i, rc := range rcs {
		if rc == 1 {
			t.Errorf("parallel add %d exited 1 (a finding) for an environment condition:\n%s", i, outs[i])
		}
		if rc == 0 {
			ok++
		}
	}
	h := rawOpen(t, db)
	var added int
	h.QueryRow(`SELECT count(*) FROM items WHERE atm_id > 'VSC-006' AND atm_id LIKE 'VSC-%'`).Scan(&added)
	if added != ok {
		t.Fatalf("%d add(s) reported success but %d row(s) exist — a lost or phantom update", ok, added)
	}
	var integrity string
	h.QueryRow(`PRAGMA integrity_check`).Scan(&integrity)
	if integrity != "ok" {
		t.Fatalf("integrity_check: %s", integrity)
	}
	h.Close()
	if ok == 0 {
		t.Fatalf("no parallel add succeeded; outputs: %v", outs)
	}
	t.Logf("%d of %d parallel adds exited 0; %d row(s) added; integrity_check ok", ok, n, added)
	gapCleanIn(t, repo, db)
}

// ── I3: the frozen-cycle record is cross-checked against the tracked file ───

func TestI3FreezeWithoutTheTrackedFileIsUndetermined(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql")
	rep := validateGapIn(t, fixtureRoot(t, false), path, fixtureAsOf, fixtureRoster())
	if rep.ExitCode() != 2 {
		t.Fatalf("frozen cycle with no tracked freeze.json: want rc 2, got %d: %v %v", rep.ExitCode(), rep.Findings, rep.Undetermined)
	}
	// ...and a membership change is still a finding, which outranks that 2.
	applySQL(t, path, `UPDATE items SET cycle=NULL WHERE atm_id='VSC-005'`)
	if rep := validateGapIn(t, fixtureRoot(t, false), path, fixtureAsOf, fixtureRoster()); rep.ExitCode() != 1 {
		t.Fatalf("membership change with no tracked file: want rc 1, got %d", rep.ExitCode())
	}
}

func TestI3ATrackedFreezeWhoseMetaRecordWasDeletedIsAFinding(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql")
	applySQL(t, path, `DELETE FROM meta WHERE key='zero_gap_freeze:2026-C1'; UPDATE items SET cycle=NULL WHERE atm_id='VSC-005'`)
	rep := validateGapIn(t, fixtureRoot(t, true), path, fixtureAsOf, fixtureRoster())
	if !hasGapFinding(rep, "V-G6", "") || rep.ExitCode() != 1 {
		t.Fatalf("a tracked freeze with no meta record was accepted: rc %d %v", rep.ExitCode(), rep.Findings)
	}
}

func TestI3GapFreezeRefusesWhenTheTrackedFileDisagrees(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql", "golden-bad/V-G6-meta-rewritten.sql")
	installFreezeFixture(t, repo)
	if rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C1", "--as-of", fixtureAsOf); rc != 1 {
		t.Fatalf("freeze over a meta record that disagrees with the tracked file: want rc 1, got %d\n%s", rc, out)
	}
}

// ── minor: an item closed by the canonical tool is named as such ───────────

func TestClosedOutsideGapCloseIsNamed(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `UPDATE items SET recurrence_of=NULL WHERE atm_id='VSC-006'`)
	root := fixtureRoot(t, false)
	bin := filepath.Join(repoRoot(t), "submodules/constitution/scripts/workable-items/bin/workable-items-linux")
	if _, err := os.Stat(bin); err != nil {
		t.Skip("SKIPPED (not passed): canonical binary absent: " + err.Error())
	}
	out, err := runIn(root, bin, "close", "VSC-001", "--db", path, "--status", "fixed", "--evidence", fixtureRel+"/evidence/sweep-finding.json")
	if err != nil {
		t.Fatalf("canonical close: %v\n%s", err, out)
	}
	rep := validateGapIn(t, root, path, fixtureAsOf, fixtureRoster())
	found := false
	for _, f := range rep.Findings {
		if f.ItemID == "VSC-001" {
			if f.Rule != "V-G3" || !strings.Contains(f.Detail, "closed outside `gap close`") {
				t.Fatalf("misleading finding for a canonically-closed item: %v", f)
			}
			found = true
		}
	}
	if !found {
		t.Fatalf("an item closed by the canonical tool was not reported: %v", rep.Findings)
	}
}
