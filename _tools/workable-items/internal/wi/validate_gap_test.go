package wi

// T007 — validator rules V-G1..V-G12 (contracts/register-cli.md), each with a
// RED test on a mutation of the golden-good register. The golden-good control
// (TestFixtureGoldenGoodIsCleanUnderEveryValidator) is what makes every case
// below meaningful: a validator that failed everything would pass these alone.

import (
	"database/sql"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// applySQL runs extra SQL against a built fixture register.
func applySQL(t *testing.T, path, stmts string) {
	t.Helper()
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if _, err := db.Exec(stmts); err != nil {
		t.Fatalf("applying mutation: %v\n%s", err, stmts)
	}
}

func hasGapFinding(rep *Report, rule, item string) bool {
	for _, f := range rep.Findings {
		if f.Rule == rule && (item == "" || f.ItemID == item) {
			return true
		}
	}
	return false
}

// Each golden-bad fixture must trip EXACTLY its own rule — no more (a mutation
// that trips several rules proves nothing about any one of them), no less.
func TestGoldenBadFixturesTripExactlyTheirOwnRule(t *testing.T) {
	cases := []struct {
		rule string
		base []string
	}{
		{"V-G1", []string{"golden-good.sql"}},
		{"V-G2", []string{"golden-good.sql"}},
		{"V-G3", []string{"golden-good.sql"}},
		{"V-G4", []string{"golden-good.sql"}},
		{"V-G5", []string{"golden-good.sql"}},
		{"V-G6", []string{"golden-good.sql", "frozen-cycle.sql"}},
		{"V-G7", []string{"golden-good.sql"}},
		{"V-G9", []string{"golden-good.sql"}},
		{"V-G10", []string{"golden-good.sql"}},
		{"V-G11", []string{"golden-good.sql"}},
		{"V-G12", []string{"golden-good.sql"}},
	}
	for _, c := range cases {
		t.Run(c.rule, func(t *testing.T) {
			files := append(append([]string{}, c.base...), "golden-bad/"+c.rule+".sql")
			rep := validateGapFixture(t, buildRegister(t, true, files...), fixtureAsOf, fixtureRoster())
			if rep.ExitCode() != 1 {
				t.Fatalf("want rc 1, got %d: findings=%v undet=%v", rep.ExitCode(), rep.Findings, rep.Undetermined)
			}
			if got := gapRules(rep); !reflect.DeepEqual(got, []string{c.rule}) {
				t.Fatalf("want exactly [%s], got %v: %v", c.rule, got, rep.Findings)
			}
		})
	}
}

// V-G8 is a roster rule: the negative fixture is a repository whose .gitmodules
// declares a submodule the roster omits; its control is the same repository
// with a complete roster.
func TestVG8RosterFixtureAndItsControl(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql")

	good, err := LoadRoster(rosterRepo(t, "roster-good"))
	if err != nil {
		t.Fatal(err)
	}
	if rep := validateGapFixture(t, path, fixtureAsOf, good); rep.ExitCode() != 0 {
		t.Fatalf("control roster: want rc 0, got %d: %v %v", rep.ExitCode(), rep.Findings, rep.Undetermined)
	}

	bad, err := LoadRoster(rosterRepo(t, "golden-bad/V-G8-roster"))
	if err != nil {
		t.Fatal(err)
	}
	rep := validateGapFixture(t, path, fixtureAsOf, bad)
	if got := gapRules(rep); !reflect.DeepEqual(got, []string{"V-G8"}) || rep.ExitCode() != 1 {
		t.Fatalf("want exactly [V-G8] at rc 1, got %v rc %d: %v", got, rep.ExitCode(), rep.Findings)
	}
	if !strings.Contains(rep.Findings[0].Detail, "submodules/unrostered") {
		t.Fatalf("V-G8 does not name the unrostered path: %v", rep.Findings[0])
	}
}

func TestVG8NoRosterIsUndeterminedNeverClean(t *testing.T) {
	rep := validateGapFixture(t, buildRegister(t, true, "golden-good.sql"), fixtureAsOf, nil)
	if rep.ExitCode() != 2 {
		t.Fatalf("no roster: want rc 2, got %d", rep.ExitCode())
	}
}

// Sub-conditions of each rule, each a single mutation on golden-good that must
// surface the named rule against the named item.
func TestGapRuleSubConditions(t *testing.T) {
	ev := "_tests/fixtures/zero-gap/registers/evidence/"
	cases := []struct {
		name, rule, item, sql string
	}{
		// V-G1 — type+status+id+kind+category+severity+owner+location+evidence
		{"severity outside the closed set", "V-G1", "VSC-001", `UPDATE items SET severity='urgent' WHERE atm_id='VSC-001'`},
		{"severity missing", "V-G1", "VSC-001", `UPDATE items SET severity=NULL WHERE atm_id='VSC-001'`},
		{"kind outside the closed set", "V-G1", "VSC-001", `UPDATE items SET kind='bug' WHERE atm_id='VSC-001'`},
		{"kind missing", "V-G1", "VSC-001", `UPDATE items SET kind=NULL WHERE atm_id='VSC-001'`},
		{"category missing", "V-G1", "VSC-001", `UPDATE items SET category=NULL WHERE atm_id='VSC-001'`},
		{"owner missing", "V-G1", "VSC-001", `UPDATE items SET assigned_to='' WHERE atm_id='VSC-001'`},
		{"location missing", "V-G1", "VSC-001", `UPDATE items SET forensic_anchor=NULL WHERE atm_id='VSC-001'`},
		{"no evidence reference", "V-G1", "VSC-001", `DELETE FROM item_history WHERE atm_id='VSC-001'`},
		{"defect typed as Task (research D3)", "V-G1", "VSC-001", `UPDATE items SET type='Task' WHERE atm_id='VSC-001'`},

		// V-G2 — classified ⇒ reason ∈ 4 + owner + recheck not elapsed
		{"classification reason outside the four", "V-G2", "VSC-002", `UPDATE items SET classification_reason='too-expensive' WHERE atm_id='VSC-002'`},
		{"classification owner missing", "V-G2", "VSC-002", `UPDATE items SET classification_owner=NULL WHERE atm_id='VSC-002'`},
		{"recheck date missing", "V-G2", "VSC-002", `UPDATE items SET classification_recheck=NULL WHERE atm_id='VSC-002'`},
		{"recheck date malformed", "V-G2", "VSC-002", `UPDATE items SET classification_recheck='next quarter' WHERE atm_id='VSC-002'`},
		{"classification fields on an open item", "V-G2", "VSC-001", `UPDATE items SET classification_reason='third-party' WHERE atm_id='VSC-001'`},

		// V-G3 — closed ⇒ RED+GREEN same check, verifier≠fixer, reviewer, author≠fixer, research
		{"no reviewer verdict", "V-G3", "VSC-004", `DELETE FROM item_verdicts WHERE role='reviewer'`},
		{"verifier is the fixer", "V-G3", "VSC-004", `UPDATE item_verdicts SET actor='agent-fixer-A' WHERE role='verifier'`},
		{"reviewer is the fixer", "V-G3", "VSC-004", `UPDATE item_verdicts SET actor='agent-fixer-A' WHERE role='reviewer'`},
		{"a verifier disagrees", "V-G3", "VSC-004", `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-004','verifier','agent-verifier-E','script','2026-09-25',1,'` + ev + `VSC-004-recheck-fail.json')`},
		{"review rejected", "V-G3", "VSC-004", `INSERT INTO item_verdicts (item_id,role,actor,actor_kind,on_date,outcome,evidence_path) VALUES ('VSC-004','reviewer','agent-reviewer-F','agent','2026-09-25',1,'` + ev + `VSC-004-review.md')`},
		{"check author is the fixer", "V-G3", "VSC-004", `UPDATE item_history SET reason='zero-gap:close fixer=agent-fixer-A check-author=agent-fixer-A verdict=` + ev + `VSC-004-verifier.json' WHERE event_type='Fixed'`},
		{"no closure record", "V-G3", "VSC-004", `UPDATE item_history SET reason='closed by hand' WHERE event_type='Fixed'`},
		{"verdict-ref names no verifier row", "V-G3", "VSC-004", `UPDATE item_history SET reason='zero-gap:close fixer=agent-fixer-A check-author=agent-author-B verdict=` + ev + `VSC-004-review.md' WHERE event_type='Fixed'`},
		{"research_ref missing", "V-G3", "VSC-004", `UPDATE items SET research_ref=NULL WHERE atm_id='VSC-004'`},
		{"research_ref does not resolve", "V-G3", "VSC-004", `UPDATE items SET research_ref='docs/research/does-not-exist.md' WHERE atm_id='VSC-004'`},
		{"GREEN is for a different check id", "V-G3", "VSC-004", `UPDATE item_history SET evidence_path='` + ev + `VSC-004-green-other-check.json' WHERE reason LIKE 'zero-gap:green-evidence%'`},
		{"hollow check: RED record passed (outcome 0)", "V-G3", "VSC-004", `UPDATE item_history SET evidence_path='` + ev + `VSC-004-red-hollow.json' WHERE reason LIKE 'zero-gap:red-evidence%'`},
		{"RED evidence names another item", "V-G3", "VSC-004", `UPDATE item_history SET evidence_path='` + ev + `VSC-001-reopen-fail.json' WHERE reason LIKE 'zero-gap:red-evidence%'`},
		{"RED evidence does not resolve", "V-G3", "VSC-004", `UPDATE item_history SET evidence_path='` + ev + `absent.json' WHERE reason LIKE 'zero-gap:red-evidence%'`},
		{"RED evidence is not an evidence record", "V-G3", "VSC-004", `UPDATE item_history SET evidence_path='` + ev + `VSC-004-research.md' WHERE reason LIKE 'zero-gap:red-evidence%'`},
		{"no RED evidence row at all", "V-G3", "VSC-004", `DELETE FROM item_history WHERE reason LIKE 'zero-gap:red-evidence%'`},
		{"no test_diary PASS", "V-G3", "VSC-004", `DELETE FROM test_diary`},

		// V-G4
		{"improvement with no target", "V-G4", "VSC-005", `UPDATE items SET measurable_target=NULL WHERE atm_id='VSC-005'`},

		// V-G5
		{"recurrence names no item", "V-G5", "VSC-006", `UPDATE items SET recurrence_of='VSC-999' WHERE atm_id='VSC-006'`},
		{"recurrence names itself", "V-G5", "VSC-006", `UPDATE items SET recurrence_of='VSC-006' WHERE atm_id='VSC-006'`},
		{"head closed while its recurrence is open (§11.4.214)", "V-G5", "VSC-006", `UPDATE items SET recurrence_of='VSC-004' WHERE atm_id='VSC-006'`},

		// V-G7 — closed disposition vocabulary, consistent with status
		{"disposition missing on a gap item", "V-G7", "VSC-001", `UPDATE items SET disposition=NULL WHERE atm_id='VSC-001'`},
		{"accepted-as-is as a classification reason", "V-G7", "VSC-002", `UPDATE items SET classification_reason='accepted as is' WHERE atm_id='VSC-002'`},
		{"closed disposition on a non-terminal status", "V-G7", "VSC-001", `UPDATE items SET disposition='closed' WHERE atm_id='VSC-001'`},
		{"open disposition on a terminal status", "V-G7", "VSC-004", `UPDATE items SET disposition='open', plan_due='2026-12-31' WHERE atm_id='VSC-004'`},
		{"operator reason without Operator-blocked", "V-G7", "VSC-003", `UPDATE items SET status='Queued' WHERE atm_id='VSC-003'`},
		{"third-party reason on Operator-blocked", "V-G7", "VSC-002", `UPDATE items SET status='Operator-blocked' WHERE atm_id='VSC-002'; INSERT INTO operator_block_details VALUES ('VSC-002','x','y','- wait for upstream — cost: none','op')`},
		{"Obsolete is not a disposition", "V-G7", "VSC-001", `UPDATE items SET status='Obsolete (→ Fixed.md)' WHERE atm_id='VSC-001'`},

		// V-G10
		{"plan date malformed", "V-G10", "VSC-001", `UPDATE items SET plan_due='soon' WHERE atm_id='VSC-001'`},
		{"plan date elapsed", "V-G10", "VSC-001", `UPDATE items SET plan_due='2026-09-24' WHERE atm_id='VSC-001'`},

		// V-G11 — every Operator-blocked item: decision, options, cost of each
		{"no operator_block_details row", "V-G11", "VSC-003", `DELETE FROM operator_block_details`},
		{"decision needed is blank", "V-G11", "VSC-003", `UPDATE operator_block_details SET what='  '`},
		{"no option listed", "V-G11", "VSC-003", `UPDATE operator_block_details SET unblock_condition='the operator decides'`},
		{"second option has no cost", "V-G11", "VSC-003", `UPDATE operator_block_details SET unblock_condition='- install it — cost: one install
- use a container instead'`},
		{"non-gap Operator-blocked item is covered too", "V-G11", "VSC-007", `INSERT INTO items (atm_id,type,status,title,description,current_location) VALUES ('VSC-007','Task','Operator-blocked','legacy blocked item','A legacy item blocked on the operator with no details recorded anywhere.','Issues')`},
	}
	for _, c := range cases {
		t.Run(c.rule+"/"+c.name, func(t *testing.T) {
			path := buildRegister(t, true, "golden-good.sql")
			applySQL(t, path, c.sql)
			rep := validateGapFixture(t, path, fixtureAsOf, fixtureRoster())
			if !hasGapFinding(rep, c.rule, c.item) {
				t.Fatalf("want %s against %s, got findings=%v undet=%v", c.rule, c.item, rep.Findings, rep.Undetermined)
			}
			if rep.ExitCode() != 1 {
				t.Fatalf("want rc 1, got %d", rep.ExitCode())
			}
		})
	}
}

// V-G6: adding an item to a frozen cycle is caught as well as removing one.
func TestVG6AnItemAddedToAFrozenCycleIsCaught(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql")
	applySQL(t, path, `
INSERT INTO items (atm_id,type,status,severity,title,description,forensic_anchor,assigned_to,current_location,
  kind,category,disposition,plan_due,measurable_target,sweep_class,cycle)
SELECT 'VSC-007',type,status,severity,title||' (copy)',description,forensic_anchor,assigned_to,current_location,
  kind,category,disposition,plan_due,measurable_target,sweep_class,cycle FROM items WHERE atm_id='VSC-005';
INSERT INTO item_history (atm_id,event_type,by,on_date,reason,evidence_path)
SELECT 'VSC-007',event_type,by,on_date,reason,evidence_path FROM item_history WHERE atm_id='VSC-005';`)
	rep := validateGapFixture(t, path, fixtureAsOf, fixtureRoster())
	if got := gapRules(rep); !reflect.DeepEqual(got, []string{"V-G6"}) {
		t.Fatalf("want exactly [V-G6], got %v: %v", got, rep.Findings)
	}
	if !hasGapFinding(rep, "V-G6", "VSC-007") {
		t.Fatalf("V-G6 does not name the added item: %v", rep.Findings)
	}
}

func TestVG6ATamperedFreezeRecordIsCaught(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql")
	// The member list is edited to match the new membership but its digest is not.
	applySQL(t, path, `UPDATE items SET cycle=NULL WHERE atm_id='VSC-005';
UPDATE meta SET value=replace(value,'"VSC-005",','') WHERE key='zero_gap_freeze:2026-C1';`)
	rep := validateGapFixture(t, path, fixtureAsOf, fixtureRoster())
	if !hasGapFinding(rep, "V-G6", "") {
		t.Fatalf("a freeze record whose member list no longer matches its own digest was accepted: %v", rep.Findings)
	}
}

func TestVG6AnUnreadableFreezeRecordIsUndetermined(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql")
	applySQL(t, path, `UPDATE meta SET value='{not json' WHERE key='zero_gap_freeze:2026-C1'`)
	rep := validateGapFixture(t, path, fixtureAsOf, fixtureRoster())
	if rep.ExitCode() != 2 {
		t.Fatalf("want rc 2 for an unreadable freeze record, got %d: %v %v", rep.ExitCode(), rep.Findings, rep.Undetermined)
	}
}

// --as-of drives every date rule: the SAME database is clean at 2026-09-25 and
// violates V-G2 (recheck) and V-G10 (plan) at 2027-01-01, with no mutation.
func TestAsOfDrivesTheDateRules(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql")
	if rep := validateGapFixture(t, path, fixtureAsOf, fixtureRoster()); rep.ExitCode() != 0 {
		t.Fatalf("control at %s: want rc 0, got %d: %v", fixtureAsOf, rep.ExitCode(), rep.Findings)
	}
	rep := validateGapFixture(t, path, "2027-01-01", fixtureRoster())
	got := gapRules(rep)
	if !reflect.DeepEqual(got, []string{"V-G10", "V-G2"}) {
		t.Fatalf("at 2027-01-01 want [V-G10 V-G2], got %v: %v", got, rep.Findings)
	}
	// The recheck/plan day itself is not elapsed.
	if rep := validateGapFixture(t, path, "2026-12-31", fixtureRoster()); rep.ExitCode() != 0 {
		t.Fatalf("on the due date itself nothing has elapsed; got %v", rep.Findings)
	}
}

func TestAsOfMustBeAnISODate(t *testing.T) {
	db := openFixture(t, buildRegister(t, true, "golden-good.sql"))
	for _, bad := range []string{"", "25/09/2026", "2026-13-01", "today"} {
		if _, err := ValidateGap(db, GapOptions{AsOf: bad, Root: repoRoot(t), Roster: fixtureRoster()}); err == nil {
			t.Errorf("--as-of %q was accepted", bad)
		}
	}
}

// SC-006: an unchanged state gives the same verdict on every repeat.
func TestValidateGapIsDeterministic(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `UPDATE items SET severity='urgent', plan_due=NULL WHERE atm_id='VSC-001'; DELETE FROM test_diary;`)
	first, _ := json.Marshal(validateGapFixture(t, path, fixtureAsOf, fixtureRoster()))
	for i := 0; i < 4; i++ {
		again, _ := json.Marshal(validateGapFixture(t, path, fixtureAsOf, fixtureRoster()))
		if string(again) != string(first) {
			t.Fatalf("run %d differs:\n%s\n%s", i+2, first, again)
		}
	}
}

func TestValidateGapOnAnUnmigratedRegisterSaysSo(t *testing.T) {
	db := openFixture(t, buildRegister(t, false, "legacy-register.sql"))
	_, err := ValidateGap(db, GapOptions{AsOf: fixtureAsOf, Root: repoRoot(t), Roster: fixtureRoster()})
	if !errors.Is(err, ErrNotMigrated) {
		t.Fatalf("want ErrNotMigrated, got %v", err)
	}
}

// Legacy (non-gap) items are outside V-G1..V-G10: after migration the legacy
// register has zero gap items, and says so rather than reporting them clean.
func TestLegacyItemsAreNotGapItems(t *testing.T) {
	rep := validateGapFixture(t, buildRegister(t, true, "legacy-register.sql"), fixtureAsOf, fixtureRoster())
	if rep.Items != 0 {
		t.Fatalf("legacy rows counted as gap items: %d", rep.Items)
	}
	if rep.ExitCode() != 0 {
		t.Fatalf("legacy register: want rc 0, got %d: %v %v", rep.ExitCode(), rep.Findings, rep.Undetermined)
	}
	if len(rep.Notes) == 0 || !strings.Contains(strings.Join(rep.Notes, "\n"), "0 gap item") {
		t.Fatalf("an empty gap population must be stated, not implied clean: notes=%v", rep.Notes)
	}
}

// Evidence that exists but cannot be read is UNDETERMINED (rc 2), and a
// finding elsewhere still outranks it.
func TestUnreadableEvidenceIsUndeterminedAndAFindingOutranksIt(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("SKIPPED (not passed): running as root, file permissions cannot make a file unreadable")
	}
	// Round 3 (M2): evidence must lie inside the repository root, so the
	// unreadable GREEN is made unreadable IN PLACE inside the test root.
	root := fixtureRoot(t, false)
	green := filepath.Join(root, fixtureRel, "evidence", "VSC-004-green.json")
	if err := os.Chmod(green, 0o000); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(green, 0o644) })
	path := buildRegister(t, true, "golden-good.sql")
	rep := validateGapIn(t, root, path, fixtureAsOf, fixtureRoster())
	if rep.ExitCode() != 2 {
		t.Fatalf("unreadable evidence: want rc 2, got %d: %v %v", rep.ExitCode(), rep.Findings, rep.Undetermined)
	}
	applySQL(t, path, `UPDATE items SET severity='urgent' WHERE atm_id='VSC-001'`)
	if rep := validateGapIn(t, root, path, fixtureAsOf, fixtureRoster()); rep.ExitCode() != 1 {
		t.Fatalf("a finding must outrank the undetermined row: got rc %d", rep.ExitCode())
	}
}

// RED and GREEN taken on the SAME state fingerprint with opposite outcomes is a
// non-deterministic check, not a fix.
func TestVG3RedAndGreenOnTheSameStateAreRefused(t *testing.T) {
	var rec map[string]any
	src, _ := os.ReadFile(fixturePath(t, "evidence/VSC-004-green.json"))
	json.Unmarshal(src, &rec)
	fp := strings.Repeat("a", 64) // the RED record's state
	rec["state_fingerprint_before"], rec["state_fingerprint_after"] = fp, fp
	b, _ := json.Marshal(rec)
	root := fixtureRoot(t, false) // round 3 (M2): evidence lives inside the root
	same := writeText(t, root, "ev/green-same-state.json", string(b))
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `UPDATE item_history SET evidence_path='`+same+`' WHERE reason LIKE 'zero-gap:green-evidence%'`)
	rep := validateGapIn(t, root, path, fixtureAsOf, fixtureRoster())
	if !hasGapFinding(rep, "V-G3", "VSC-004") {
		t.Fatalf("RED and GREEN on one state were accepted: %v", rep.Findings)
	}
}

func TestReadEvidenceRecordIsStrict(t *testing.T) {
	dir := t.TempDir()
	good, _ := os.ReadFile(fixturePath(t, "evidence/VSC-004-green.json"))
	if _, err := ReadEvidenceRecord(fixturePath(t, "evidence/VSC-004-green.json")); err != nil {
		t.Fatalf("control record refused: %v", err)
	}
	mutate := func(name string, f func(m map[string]any)) {
		var m map[string]any
		json.Unmarshal(good, &m)
		f(m)
		b, _ := json.Marshal(m)
		p := filepath.Join(dir, name+".json")
		os.WriteFile(p, b, 0o644)
		if _, err := ReadEvidenceRecord(p); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
	mutate("unknown-field", func(m map[string]any) { m["cwd_extra"] = "x" })
	mutate("missing-check-id", func(m map[string]any) { delete(m, "check_id") })
	mutate("outcome-3", func(m map[string]any) { m["outcome"] = 3 })
	mutate("unstable-state-with-verdict", func(m map[string]any) { m["state_fingerprint_after"] = strings.Repeat("f", 64) })
	mutate("bad-population", func(m map[string]any) { m["population_kind"] = "vibes" })
	mutate("bad-fingerprint", func(m map[string]any) { m["state_fingerprint_before"] = "xyz" })
	mutate("bad-ts", func(m map[string]any) { m["ts"] = "yesterday" })
}

// A gap item whose zero-gap columns are wiped — measured: the canonical
// binary's `close` re-INSERTs the row with a fixed column list and drops them
// all — must not silently fall out of the gap rules, and must be reported as
// what it is (closed outside `gap close`), not as a pile of misleading
// missing-field findings (fix round 1 minor).
func TestAGapItemWhoseColumnsWereWipedStaysInScope(t *testing.T) {
	path := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path, `UPDATE items SET kind=NULL, category=NULL, disposition=NULL, plan_due=NULL, sweep_class=NULL,
        first_seen_fingerprint=NULL, status='Fixed (→ Fixed.md)', current_location='Fixed' WHERE atm_id='VSC-001';
        UPDATE items SET recurrence_of=NULL WHERE atm_id='VSC-006'`)
	rep := validateGapFixture(t, path, fixtureAsOf, fixtureRoster())
	var mine []Finding
	for _, f := range rep.Findings {
		if f.ItemID == "VSC-001" {
			mine = append(mine, f)
		}
	}
	if len(mine) != 1 || mine[0].Rule != "V-G3" || !strings.Contains(mine[0].Detail, "closed outside `gap close`") {
		t.Fatalf("want exactly one V-G3 'closed outside gap close' finding for VSC-001, got %v", mine)
	}
	if rep.Items != 6 {
		t.Fatalf("gap item count: want 6, got %d", rep.Items)
	}
	// Wiped but NOT closed: named as wiped, under V-G1.
	path2 := buildRegister(t, true, "golden-good.sql")
	applySQL(t, path2, `UPDATE items SET kind=NULL, category=NULL, disposition=NULL, plan_due=NULL, sweep_class=NULL,
        first_seen_fingerprint=NULL WHERE atm_id='VSC-001'`)
	rep2 := validateGapFixture(t, path2, fixtureAsOf, fixtureRoster())
	mine = nil
	for _, f := range rep2.Findings {
		if f.ItemID == "VSC-001" {
			mine = append(mine, f)
		}
	}
	if len(mine) != 1 || mine[0].Rule != "V-G1" || !strings.Contains(mine[0].Detail, "wiped") {
		t.Fatalf("want exactly one V-G1 'wiped' finding for VSC-001, got %v", mine)
	}
}
