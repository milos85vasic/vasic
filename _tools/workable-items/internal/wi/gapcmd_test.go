package wi

// T008 — the `gap` subcommands add, classify, verdict, close, reopen, link,
// apply-queue, freeze and summary (contracts/register-cli.md). Every register is
// a fixture copy in t.TempDir(); every repository root is a throwaway directory
// holding the good fixture roster plus the fixture evidence.

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// gapRepo is a throwaway repository root: roster-good plus the fixture evidence
// at the same repository-relative path the golden registers cite.
func gapRepo(t *testing.T) string {
	t.Helper()
	dst := rosterRepo(t, "roster-good")
	copyFixtureEvidence(t, dst)
	return dst
}

// writeRecord writes an evidence record derived from the fixture GREEN template
// with the given overrides, at repo-relative path rel, and returns rel.
func writeRecord(t *testing.T, repo, rel string, mods map[string]any) string {
	t.Helper()
	b, err := os.ReadFile(fixturePath(t, "evidence/VSC-004-green.json"))
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	json.Unmarshal(b, &m)
	for k, v := range mods {
		m[k] = v
	}
	out, _ := json.Marshal(m)
	p := filepath.Join(repo, rel)
	os.MkdirAll(filepath.Dir(p), 0o755)
	if err := os.WriteFile(p, out, 0o644); err != nil {
		t.Fatal(err)
	}
	return rel
}

func writeText(t *testing.T, repo, rel, body string) string {
	t.Helper()
	p := filepath.Join(repo, rel)
	os.MkdirAll(filepath.Dir(p), 0o755)
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return rel
}

func gapRun(t *testing.T, repo, db string, args ...string) (int, string) {
	t.Helper()
	full := append([]string{args[0], "--repo", repo, "--db", db}, args[1:]...)
	rc, out, errs := runGapCLI(t, full...)
	return rc, out + errs
}

func field(t *testing.T, dbPath, id, col string) string {
	t.Helper()
	db := rawOpen(t, dbPath)
	defer db.Close()
	var v sql.NullString
	if err := db.QueryRow(`SELECT CAST(`+col+` AS TEXT) FROM items WHERE atm_id=? ORDER BY current_location DESC LIMIT 1`, id).Scan(&v); err != nil {
		t.Fatalf("reading %s.%s: %v", id, col, err)
	}
	return v.String
}

func gapCleanIn(t *testing.T, repo, dbPath string) {
	t.Helper()
	r, err := LoadRoster(repo)
	if err != nil {
		t.Fatal(err)
	}
	db := openFixture(t, dbPath)
	rep, err := ValidateGap(db, GapOptions{AsOf: clockAsOf, Root: repo, Roster: r})
	if err != nil {
		t.Fatal(err)
	}
	if rep.ExitCode() != 0 {
		t.Fatalf("register no longer validates: rc %d findings=%v undet=%v", rep.ExitCode(), rep.Findings, rep.Undetermined)
	}
	rc, out, skipped := canonicalValidateIn(t, repo, dbPath)
	if skipped {
		t.Log("canonical validator SKIPPED (not passed): " + out)
		return
	}
	if rc != 0 {
		t.Fatalf("canonical validator refused the register: rc %d\n%s", rc, out)
	}
}

var addArgs = []string{"add", "--prefix", "VSC", "--type", "Bug", "--kind", "defect", "--severity", "high",
	"--category", "security", "--title", "a new finding from the example sweep",
	"--description", "The example sweep found a second gate that reports PASS over an empty population.",
	"--closure-criteria", "the gate returns rc 2 on an empty population", "--sweep-class", "SC-example",
	"--owner", "agent-owner", "--anchor", "scripts/zero-gap-class-example-3.sh:9",
	"--evidence", fixtureRel + "/evidence/sweep-finding.json", "--plan-due", "2026-12-31",
	"--fingerprint", strings.Repeat("e", 64), "--as-of", fixtureAsOf}

func withArg(args []string, flag, val string) []string {
	out := append([]string{}, args...)
	for i := range out {
		if out[i] == flag {
			out[i+1] = val
			return out
		}
	}
	return append(out, flag, val)
}

func withoutArg(args []string, flag string) []string {
	var out []string
	for i := 0; i < len(args); i++ {
		if args[i] == flag {
			i++
			continue
		}
		out = append(out, args[i])
	}
	return out
}

// ── gap add ────────────────────────────────────────────────────────────────

func TestGapAddOpensAValidItem(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	rc, out := gapRun(t, repo, db, addArgs...)
	if rc != 0 || !strings.Contains(out, "VSC-007") {
		t.Fatalf("gap add: want rc 0 creating VSC-007, got %d\n%s", rc, out)
	}
	if d := field(t, db, "VSC-007", "disposition"); d != "open" {
		t.Fatalf("new item disposition: want open, got %q", d)
	}
	if s := field(t, db, "VSC-007", "status"); s != StatusQueued {
		t.Fatalf("new item status: want Queued, got %q", s)
	}
	gapCleanIn(t, repo, db)
}

func TestGapAddRefusesAnInvalidItemAndWritesNothing(t *testing.T) {
	cases := map[string][]string{
		"category outside the closed set": withArg(addArgs, "--category", "misc"),
		"severity outside the closed set": withArg(addArgs, "--severity", "urgent"),
		"kind outside the closed set":     withArg(addArgs, "--kind", "bug"),
		"defect typed Task":               withArg(addArgs, "--type", "Task"),
		"no owner":                        withoutArg(addArgs, "--owner"),
		"no location":                     withoutArg(addArgs, "--anchor"),
		"evidence does not resolve":       withArg(addArgs, "--evidence", "no/such/evidence.json"),
		"plan already elapsed":            withArg(addArgs, "--plan-due", "2026-09-01"),
		"no plan":                         withoutArg(addArgs, "--plan-due"),
		"description below the floor":     withArg(addArgs, "--description", "too short"),
		"improvement without a target":    withArg(withArg(addArgs, "--kind", "improvement"), "--type", "Task"),
		"prefix not in the roster":        withArg(addArgs, "--prefix", "ZZZ"),
	}
	for name, args := range cases {
		t.Run(name, func(t *testing.T) {
			repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
			before := fileSHA(t, db)
			rc, out := gapRun(t, repo, db, args...)
			if rc != 1 {
				t.Fatalf("want rc 1, got %d\n%s", rc, out)
			}
			if fileSHA(t, db) != before {
				t.Fatal("a refused add modified the register")
			}
		})
	}
}

func TestGapAddIntoAFrozenCycleIsRefused(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql")
	installFreezeFixture(t, repo)
	rc, out := gapRun(t, repo, db, withArg(addArgs, "--cycle", "2026-C1")...)
	if rc != 1 || !strings.Contains(out, "V-G6") {
		t.Fatalf("add into frozen cycle: want rc 1 naming V-G6, got %d\n%s", rc, out)
	}
	if rc, out := gapRun(t, repo, db, withArg(addArgs, "--cycle", "2026-C2")...); rc != 0 {
		t.Fatalf("add into the NEXT cycle must work: rc %d\n%s", rc, out)
	}
}

func TestGapCommandsOnAnUnmigratedRegisterAreTwo(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, false, "legacy-register.sql")
	for _, args := range [][]string{addArgs, {"summary"}, {"link", "--id", "VSC-001", "--of", "VSC-002"}} {
		if rc, out := gapRun(t, repo, db, args...); rc != 2 {
			t.Fatalf("%s on an unmigrated register: want rc 2, got %d\n%s", args[0], rc, out)
		}
	}
}

// ── gap classify ───────────────────────────────────────────────────────────

func TestGapClassifyThirdPartyKeepsQueued(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	rc, out := gapRun(t, repo, db, "classify", "--id", "VSC-006", "--reason", "third-party",
		"--owner", "upstream issue tracker", "--recheck", "2026-12-31", "--as-of", fixtureAsOf)
	if rc != 0 {
		t.Fatalf("classify third-party: rc %d\n%s", rc, out)
	}
	if field(t, db, "VSC-006", "disposition") != "classified" || field(t, db, "VSC-006", "status") != StatusQueued {
		t.Fatal("third-party classification must set disposition=classified and keep the exact status Queued")
	}
	if field(t, db, "VSC-006", "plan_due") != "" {
		t.Fatal("a classified item keeps no open-item plan date")
	}
	gapCleanIn(t, repo, db)
}

func TestGapClassifyOperatorActionBlocksWithOptionsAndCost(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	rc, out := gapRun(t, repo, db, "classify", "--id", "VSC-001", "--reason", "operator-decision",
		"--owner", "operator", "--recheck", "2026-12-31", "--as-of", fixtureAsOf,
		"--block-what", "decide whether the example gate may be retired",
		"--block-why", "retiring a gate is an operator decision",
		"--block-options", "- retire the gate — cost: one less check\n- fix the gate — cost: two hours")
	if rc != 0 {
		t.Fatalf("classify operator-decision: rc %d\n%s", rc, out)
	}
	if field(t, db, "VSC-001", "status") != StatusBlocked {
		t.Fatal("an operator reason must set status Operator-blocked")
	}
	gapCleanIn(t, repo, db)
}

func TestGapClassifyRefusals(t *testing.T) {
	base := []string{"classify", "--id", "VSC-001", "--reason", "third-party", "--owner", "upstream",
		"--recheck", "2026-12-31", "--as-of", fixtureAsOf}
	cases := map[string][]string{
		"reason outside the four":        withArg(base, "--reason", "too-expensive"),
		"accepted-as-is":                 withArg(base, "--reason", "accepted-as-is"),
		"recheck elapsed":                withArg(base, "--recheck", "2026-09-01"),
		"no owner":                       withoutArg(base, "--owner"),
		"operator reason with no option": withArg(base, "--reason", "operator-action"),
		"operator option without cost": append(withArg(base, "--reason", "operator-action"),
			"--block-what", "x", "--block-why", "y", "--block-options", "- just do it"),
		"a closed item": withArg(base, "--id", "VSC-004"),
	}
	for name, args := range cases {
		t.Run(name, func(t *testing.T) {
			repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
			before := fileSHA(t, db)
			if rc, out := gapRun(t, repo, db, args...); rc != 1 {
				t.Fatalf("want rc 1, got %d\n%s", rc, out)
			}
			if fileSHA(t, db) != before {
				t.Fatal("a refused classify modified the register")
			}
		})
	}
}

// ── gap verdict / close ────────────────────────────────────────────────────

type closeKit struct {
	repo, db                              string
	red, green, verdict, review, research string
}

// prepareClose readies VSC-001 (open in golden-good) for closure: RED and GREEN
// records for one check on two different states, a research record, and an
// independent verifier and reviewer verdict.
func prepareClose(t *testing.T) closeKit {
	t.Helper()
	k := closeKit{repo: gapRepo(t), db: buildRegister(t, true, "golden-good.sql")}
	// VSC-006 recurs VSC-001 in golden-good; a head is closed only after its open
	// recurrences (TestGapCloseOfAHeadWithAnOpenRecurrenceIsRefused), so the
	// closure fixture unlinks it.
	applySQL(t, k.db, `UPDATE items SET recurrence_of=NULL WHERE atm_id='VSC-006'`)
	a, b := strings.Repeat("a", 64), strings.Repeat("b", 64)
	k.red = writeRecord(t, k.repo, "ev/VSC-001-red.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 1, "exit_status": 1, "state_fingerprint_before": a, "state_fingerprint_after": a, "ts": "2026-09-25T09:00:00Z", "chain_seq": 10})
	k.green = writeRecord(t, k.repo, "ev/VSC-001-green.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2026-09-25T11:00:00Z", "chain_seq": 11})
	k.verdict = writeRecord(t, k.repo, "ev/VSC-001-verifier.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
		"outcome": 0, "verdict_role": "verifier", "state_fingerprint_before": b, "state_fingerprint_after": b, "ts": "2026-09-25T11:30:00Z", "chain_seq": 12})
	k.review = writeText(t, k.repo, "ev/VSC-001-review.md", "review of VSC-001: accepted\n")
	// The diary PASS row is INDEPENDENT evidence (what the canonical `diary add`
	// records); gap close no longer writes one for itself.
	addDiary(t, k.db, k.green, "2026-09-25T11:05:00Z")
	k.research = writeText(t, k.repo, "ev/VSC-001-research.md", "research record for VSC-001\n")
	for _, v := range [][]string{
		{"verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C", "--actor-kind", "agent", "--outcome", "0", "--evidence", k.verdict, "--on", fixtureAsOf},
		{"verdict", "--id", "VSC-001", "--role", "reviewer", "--actor", "agent-reviewer-D", "--actor-kind", "agent", "--outcome", "0", "--evidence", k.review, "--on", fixtureAsOf},
	} {
		if rc, out := gapRun(t, k.repo, k.db, v...); rc != 0 {
			t.Fatalf("recording a verdict: rc %d\n%s", rc, out)
		}
	}
	return k
}

// addDiary records a test_diary PASS row the way the canonical `diary add` does.
func addDiary(t *testing.T, dbPath, evidence, when string) {
	t.Helper()
	// created_at is the write time on the SAME clock as every other stamp (the
	// canonical `diary add` writes datetime('now') on the host clock); a
	// real-clock default here would mix clocks with the fixed test clock.
	created := mustTime(when).Format("2006-01-02 15:04:05")
	applySQL(t, dbPath, `INSERT INTO test_diary (atm_id,date_time,tested_by,result,result_detail,observations,action_taken,evidence_path,created_at)
        VALUES ('VSC-001','`+when+`','AI-agent','PASS','check CHK-vsc-001 outcome 0','independent test run','none','`+evidence+`','`+created+`')`)
}

func (k closeKit) args() []string {
	return []string{"close", "--id", "VSC-001", "--red-evidence", k.red, "--green-evidence", k.green,
		"--verdict-ref", k.verdict, "--fixer", "agent-fixer-A", "--check-author", "agent-author-B",
		"--research-ref", k.research, "--as-of", clockAsOf}
}

func TestGapVerdictRefusesAnOrphanAndBadValues(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	// Fix round 1 (C1): the control's evidence must be a verifier RECORD for
	// VSC-001 itself; the earlier control cited VSC-004's record and is now,
	// correctly, refused.
	own := writeRecord(t, repo, "ev/VSC-001-verifier.json", map[string]any{"item_id": "VSC-001", "verdict_role": "verifier"})
	ok := []string{"verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-C", "--actor-kind", "agent",
		"--outcome", "0", "--evidence", own, "--on", fixtureAsOf}
	for name, args := range map[string][]string{
		"no such item (V-G12)":     withArg(ok, "--id", "VSC-999"),
		"role outside the set":     withArg(ok, "--role", "author"),
		"actor kind outside set":   withArg(ok, "--actor-kind", "human"),
		"outcome outside {0,1,2}":  withArg(ok, "--outcome", "5"),
		"evidence does not exist":  withArg(ok, "--evidence", "no/such.json"),
		"actor handle has a space": withArg(ok, "--actor", "two words"),
	} {
		before := fileSHA(t, db)
		if rc, out := gapRun(t, repo, db, args...); rc != 1 {
			t.Fatalf("%s: want rc 1, got %d\n%s", name, rc, out)
		}
		if fileSHA(t, db) != before {
			t.Fatalf("%s: a refused verdict modified the register", name)
		}
	}
	if rc, out := gapRun(t, repo, db, ok...); rc != 0 {
		t.Fatalf("control verdict refused: rc %d\n%s", rc, out)
	}
}

func TestGapCloseSucceedsOnlyWithEveryPrecondition(t *testing.T) {
	k := prepareClose(t)
	rc, out := gapRun(t, k.repo, k.db, k.args()...)
	if rc != 0 {
		t.Fatalf("gap close with every precondition: rc %d\n%s", rc, out)
	}
	if field(t, k.db, "VSC-001", "status") != StatusFixed || field(t, k.db, "VSC-001", "disposition") != "closed" ||
		field(t, k.db, "VSC-001", "current_location") != "Fixed" {
		t.Fatal("close did not move VSC-001 to Fixed/closed")
	}
	if field(t, k.db, "VSC-001", "category") != "false-evidence" {
		t.Fatal("close dropped a zero-gap column (the canonical delete+insert close does; this one must not)")
	}
	gapCleanIn(t, k.repo, k.db)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 1 {
		t.Fatalf("closing an already-closed item: want rc 1, got %d\n%s", rc, out)
	}
}

// A write may not create a finding on ANOTHER item either: closing a head while
// its recurrence is still open would leave V-G5 failing on the recurrence.
func TestGapCloseOfAHeadWithAnOpenRecurrenceIsRefused(t *testing.T) {
	k := prepareClose(t)
	applySQL(t, k.db, `UPDATE items SET recurrence_of='VSC-001' WHERE atm_id='VSC-006'`)
	before := fileSHA(t, k.db)
	rc, out := gapRun(t, k.repo, k.db, k.args()...)
	if rc != 1 || !strings.Contains(out, "V-G5") || !strings.Contains(out, "VSC-006") {
		t.Fatalf("closing a head with an open recurrence: want rc 1 naming V-G5 on VSC-006, got %d\n%s", rc, out)
	}
	if fileSHA(t, k.db) != before {
		t.Fatal("a refused close modified the register")
	}
}

// A write is not blocked by an UNRELATED finding that already existed.
func TestGapWriteIsNotBlockedByAPreExistingUnrelatedFinding(t *testing.T) {
	k := prepareClose(t)
	applySQL(t, k.db, `UPDATE items SET severity='urgent' WHERE atm_id='VSC-005'`)
	if rc, out := gapRun(t, k.repo, k.db, k.args()...); rc != 0 {
		t.Fatalf("an unrelated pre-existing finding blocked the close: rc %d\n%s", rc, out)
	}
}

// The RED list of T008: close exits 1 unless each precondition holds.
func TestGapCloseRefusesWhenAnyPreconditionIsMissing(t *testing.T) {
	cases := []struct {
		name string
		prep func(t *testing.T, k *closeKit) []string
	}{
		{"GREEN for a different check id", func(t *testing.T, k *closeKit) []string {
			g := writeRecord(t, k.repo, "ev/g2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-other", "outcome": 0, "ts": "2026-09-25T11:00:00Z"})
			return withArg(k.args(), "--green-evidence", g)
		}},
		{"hollow check: RED passed", func(t *testing.T, k *closeKit) []string {
			a := strings.Repeat("a", 64)
			r := writeRecord(t, k.repo, "ev/r2.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001", "outcome": 0,
				"state_fingerprint_before": a, "state_fingerprint_after": a, "ts": "2026-09-25T09:00:00Z"})
			return withArg(k.args(), "--red-evidence", r)
		}},
		{"RED for another item", func(t *testing.T, k *closeKit) []string {
			return withArg(k.args(), "--red-evidence", fixtureRel+"/evidence/VSC-004-red.json")
		}},
		{"no verifier verdict", func(t *testing.T, k *closeKit) []string {
			applySQL(t, k.db, `DELETE FROM item_verdicts WHERE item_id='VSC-001' AND role='verifier'`)
			return k.args()
		}},
		{"verifier is the fixer", func(t *testing.T, k *closeKit) []string {
			return withArg(withArg(k.args(), "--fixer", "agent-verifier-C"), "--check-author", "agent-author-B")
		}},
		{"verifier disagrees", func(t *testing.T, k *closeKit) []string {
			// Fix round 1: a disagreeing verdict cites the verifier's own
			// FAILING record (its row is refused otherwise), and the rc of
			// recording it is now checked instead of ignored.
			a := strings.Repeat("a", 64)
			fail := writeRecord(t, k.repo, "ev/VSC-001-verifier-fail.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001",
				"outcome": 1, "verdict_role": "verifier", "state_fingerprint_before": a, "state_fingerprint_after": a, "ts": "2026-09-25T11:40:00Z"})
			if rc, out := gapRun(t, k.repo, k.db, "verdict", "--id", "VSC-001", "--role", "verifier", "--actor", "agent-verifier-E",
				"--actor-kind", "script", "--outcome", "1", "--evidence", fail, "--on", fixtureAsOf); rc != 0 {
				t.Fatalf("recording the disagreeing verdict: rc %d\n%s", rc, out)
			}
			return k.args()
		}},
		{"no review verdict", func(t *testing.T, k *closeKit) []string {
			applySQL(t, k.db, `DELETE FROM item_verdicts WHERE item_id='VSC-001' AND role='reviewer'`)
			return k.args()
		}},
		{"check authored by the fixer", func(t *testing.T, k *closeKit) []string {
			return withArg(k.args(), "--check-author", "agent-fixer-A")
		}},
		{"no research_ref", func(t *testing.T, k *closeKit) []string {
			return withoutArg(k.args(), "--research-ref")
		}},
		{"research_ref does not resolve", func(t *testing.T, k *closeKit) []string {
			return withArg(k.args(), "--research-ref", "ev/absent.md")
		}},
		{"verdict-ref names no verifier row", func(t *testing.T, k *closeKit) []string {
			return withArg(k.args(), "--verdict-ref", k.review)
		}},
		{"RED and GREEN on the same state", func(t *testing.T, k *closeKit) []string {
			a := strings.Repeat("a", 64)
			g := writeRecord(t, k.repo, "ev/g3.json", map[string]any{"item_id": "VSC-001", "check_id": "CHK-vsc-001", "outcome": 0,
				"state_fingerprint_before": a, "state_fingerprint_after": a, "ts": "2026-09-25T11:00:00Z"})
			return withArg(k.args(), "--green-evidence", g)
		}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			k := prepareClose(t)
			args := c.prep(t, &k)
			before := fileSHA(t, k.db)
			rc, out := gapRun(t, k.repo, k.db, args...)
			if rc != 1 {
				t.Fatalf("want rc 1, got %d\n%s", rc, out)
			}
			if fileSHA(t, k.db) != before {
				t.Fatal("a refused close modified the register")
			}
			if field(t, k.db, "VSC-001", "disposition") != "open" {
				t.Fatal("a refused close changed the item")
			}
		})
	}
}

// ── gap reopen / link / apply-queue ────────────────────────────────────────

func TestGapReopenWithFailingEvidence(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	rc, out := gapRun(t, repo, db, "reopen", "--id", "VSC-004", "--evidence", fixtureRel+"/evidence/VSC-004-recheck-fail.json",
		"--plan-due", "2026-12-31", "--as-of", fixtureAsOf)
	if rc != 0 {
		t.Fatalf("reopen: rc %d\n%s", rc, out)
	}
	if field(t, db, "VSC-004", "status") != StatusReopened || field(t, db, "VSC-004", "disposition") != "open" ||
		field(t, db, "VSC-004", "current_location") != "Issues" || field(t, db, "VSC-004", "reopens_count") != "1" {
		t.Fatal("reopen did not set Reopened/open/Issues/reopens_count=1")
	}
	gapCleanIn(t, repo, db)
	if rc, out := gapRun(t, repo, db, "reopen", "--id", "VSC-004", "--evidence", fixtureRel+"/evidence/VSC-004-recheck-fail.json",
		"--as-of", fixtureAsOf); rc != 1 {
		t.Fatalf("reopening an item that is not closed: want rc 1, got %d\n%s", rc, out)
	}
}

func TestGapReopenRefusesEvidenceThatDoesNotFail(t *testing.T) {
	for name, ev := range map[string]string{
		"passing evidence":          fixtureRel + "/evidence/VSC-004-green.json",
		"evidence for another item": fixtureRel + "/evidence/VSC-001-reopen-fail.json",
		"evidence that is absent":   "no/such.json",
	} {
		repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
		before := fileSHA(t, db)
		if rc, out := gapRun(t, repo, db, "reopen", "--id", "VSC-004", "--evidence", ev, "--as-of", fixtureAsOf); rc != 1 {
			t.Fatalf("%s: want rc 1, got %d\n%s", name, rc, out)
		}
		if fileSHA(t, db) != before {
			t.Fatalf("%s: a refused reopen modified the register", name)
		}
	}
}

func TestGapLink(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	if rc, out := gapRun(t, repo, db, "link", "--id", "VSC-005", "--of", "VSC-001"); rc != 0 {
		t.Fatalf("link VSC-005 -> VSC-001: rc %d\n%s", rc, out)
	}
	if field(t, db, "VSC-005", "recurrence_of") != "VSC-001" {
		t.Fatal("link did not set recurrence_of")
	}
	gapCleanIn(t, repo, db)
	for name, args := range map[string][]string{
		"self":                                  {"link", "--id", "VSC-002", "--of", "VSC-002"},
		"unresolved id":                         {"link", "--id", "VSC-002", "--of", "VSC-999"},
		"cycle":                                 {"link", "--id", "VSC-001", "--of", "VSC-006"},
		"closed head (reopen first, §11.4.214)": {"link", "--id", "VSC-002", "--of", "VSC-004"},
	} {
		before := fileSHA(t, db)
		if rc, out := gapRun(t, repo, db, args...); rc != 1 {
			t.Fatalf("%s: want rc 1, got %d\n%s", name, rc, out)
		}
		if fileSHA(t, db) != before {
			t.Fatalf("%s: a refused link modified the register", name)
		}
	}
}

func writeQueue(t *testing.T, repo string, lines ...string) string {
	t.Helper()
	return writeText(t, repo, ".remember/logs/zero-gap/reopen-queue.jsonl", strings.Join(lines, "\n")+"\n")
}

func TestGapApplyQueueReopensAndIsIdempotent(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	writeQueue(t, repo, `{"item_id":"VSC-004","evidence":"`+fixtureRel+`/evidence/VSC-004-recheck-fail.json"}`)
	rc, out := gapRun(t, repo, db, "apply-queue", "--as-of", "2026-09-26")
	if rc != 0 || field(t, db, "VSC-004", "status") != StatusReopened {
		t.Fatalf("apply-queue (default queue path): want rc 0 and VSC-004 Reopened, got %d\n%s", rc, out)
	}
	rc, out = gapRun(t, repo, db, "apply-queue", "--as-of", "2026-09-26")
	if rc != 0 || field(t, db, "VSC-004", "reopens_count") != "1" {
		t.Fatalf("second apply-queue must be a no-op: rc %d reopens=%s\n%s", rc, field(t, db, "VSC-004", "reopens_count"), out)
	}
}

func TestGapApplyQueueSkipsEvidenceOlderThanTheClosure(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	// VSC-004-red.json (ts 09:00) predates VSC-004's closure (12:00): it is stale.
	writeQueue(t, repo, `{"item_id":"VSC-004","evidence":"`+fixtureRel+`/evidence/VSC-004-red.json"}`)
	rc, out := gapRun(t, repo, db, "apply-queue", "--as-of", fixtureAsOf)
	if rc != 0 || field(t, db, "VSC-004", "disposition") != "closed" || !strings.Contains(out, "stale") {
		t.Fatalf("stale evidence must be skipped and reported: rc %d\n%s", rc, out)
	}
}

func TestGapApplyQueueIsAllOrNothing(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	writeQueue(t, repo,
		`{"item_id":"VSC-004","evidence":"`+fixtureRel+`/evidence/VSC-004-recheck-fail.json"}`,
		`{"item_id":"VSC-004","evidence":`)
	before := fileSHA(t, db)
	if rc, out := gapRun(t, repo, db, "apply-queue", "--as-of", fixtureAsOf); rc != 1 {
		t.Fatalf("a malformed queue line: want rc 1, got %d\n%s", rc, out)
	}
	if fileSHA(t, db) != before {
		t.Fatal("a refused queue applied part of itself")
	}
	if rc, _ := gapRun(t, repo, db, "apply-queue", "--queue", filepath.Join(repo, "absent.jsonl"), "--as-of", fixtureAsOf); rc != 2 {
		t.Fatalf("a missing queue file: want rc 2, got %d", rc)
	}
}

// ── gap freeze ─────────────────────────────────────────────────────────────

func TestGapFreezeWritesTheRecordAndV_G6HoldsIt(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	applySQL(t, db, `UPDATE items SET cycle='2026-C9'`)
	rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf)
	if rc != 0 {
		t.Fatalf("freeze: rc %d\n%s", rc, out)
	}
	path := filepath.Join(repo, "docs/zero-gap/cycles/2026-C9/freeze.json")
	b1, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("freeze.json not written at the default path: %v", err)
	}
	var fr FreezeRecord
	if err := json.Unmarshal(b1, &fr); err != nil || fr.ItemCount != 6 || fr.Cycle != "2026-C9" || len(fr.RegisterSHA256) != 64 {
		t.Fatalf("freeze.json malformed: %v %+v", err, fr)
	}
	gapCleanIn(t, repo, db)

	// Re-freezing an unchanged cycle is a no-op with identical bytes.
	if rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf); rc != 0 {
		t.Fatalf("re-freeze: rc %d\n%s", rc, out)
	}
	if b2, _ := os.ReadFile(path); string(b2) != string(b1) {
		t.Fatal("re-freezing an unchanged cycle changed freeze.json")
	}
	// After a membership change V-G6 fires and freeze refuses to paper over it.
	applySQL(t, db, `UPDATE items SET cycle=NULL WHERE atm_id='VSC-003'`)
	if rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf); rc != 1 {
		t.Fatalf("re-freeze after a membership change: want rc 1, got %d\n%s", rc, out)
	}
}

func TestGapFreezeOfAnEmptyCycleIsTwo(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	if rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C404", "--as-of", fixtureAsOf); rc != 2 {
		t.Fatalf("empty cycle: want rc 2, got %d\n%s", rc, out)
	}
}

func TestGapFreezeOnAMovingRegisterIsTwoAndWritesNothing(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	applySQL(t, db, `UPDATE items SET cycle='2026-C9'`)
	freezeMidHook = func() {
		applySQL(t, db, `UPDATE items SET title=title||' (edited concurrently)' WHERE atm_id='VSC-001'`)
	}
	defer func() { freezeMidHook = nil }()
	rc, out := gapRun(t, repo, db, "freeze", "--cycle", "2026-C9", "--as-of", fixtureAsOf)
	if rc != 2 {
		t.Fatalf("a register that moved during the freeze: want rc 2, got %d\n%s", rc, out)
	}
	if _, err := os.Stat(filepath.Join(repo, "docs/zero-gap/cycles/2026-C9/freeze.json")); !os.IsNotExist(err) {
		t.Fatal("an UNSTABLE freeze wrote freeze.json")
	}
}

// The checked-in frozen-cycle fixture must carry the digest `gap freeze`
// computes, so the fixture is a real freeze record rather than a hand value.
func TestFrozenCycleFixtureDigestIsTheComputedOne(t *testing.T) {
	db := openFixture(t, buildRegister(t, true, "golden-good.sql", "frozen-cycle.sql"))
	var raw string
	if err := db.QueryRow(`SELECT value FROM meta WHERE key='zero_gap_freeze:2026-C1'`).Scan(&raw); err != nil {
		t.Fatal(err)
	}
	var fr FreezeRecord
	if err := json.Unmarshal([]byte(raw), &fr); err != nil {
		t.Fatal(err)
	}
	got, err := RegisterDigest(db, "2026-C1")
	if err != nil {
		t.Fatal(err)
	}
	if fr.RegisterSHA256 != got {
		t.Fatalf("frozen-cycle.sql register_sha256 = %q, computed %q", fr.RegisterSHA256, got)
	}
}

// ── gap summary ────────────────────────────────────────────────────────────

func TestGapSummaryJSONIsDerivedAndByteStable(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	rc, out1 := gapRun(t, repo, db, "summary", "--json")
	if rc != 0 {
		t.Fatalf("summary: rc %d\n%s", rc, out1)
	}
	_, out2 := gapRun(t, repo, db, "summary", "--json")
	if out1 != out2 {
		t.Fatal("summary --json is not byte-stable on an unchanged register")
	}
	var m map[string]any
	if err := json.Unmarshal([]byte(out1), &m); err != nil {
		t.Fatalf("summary --json is not JSON: %v\n%s", err, out1)
	}
	re, _ := json.MarshalIndent(m, "", "  ")
	if string(re)+"\n" != out1 {
		t.Fatalf("summary --json keys are not sorted/canonical:\n%s", out1)
	}
	c := m["counts"].(map[string]any)
	for k, want := range map[string]float64{"total": 6, "closed": 1, "classified": 2, "open": 3} {
		if c[k] != want {
			t.Fatalf("counts.%s = %v, want %v\n%s", k, c[k], want, out1)
		}
	}
	pc := m["per_class"].(map[string]any)["SC-example"].(map[string]any)
	if pc["recall"] != "UNKNOWN" {
		t.Fatalf("recall with no sweep-classes.tsv must be UNKNOWN, got %v", pc["recall"])
	}
	writeText(t, repo, "docs/zero-gap/sweep-classes.tsv",
		"class_id\tpopulation\twindow\tentrypoint\tcorpus\trecall\tpopulation_kind\nSC-example\tx\tnone\tbash x\tc\t0.9\tsource\n")
	_, out3 := gapRun(t, repo, db, "summary", "--json")
	json.Unmarshal([]byte(out3), &m)
	if got := m["per_class"].(map[string]any)["SC-example"].(map[string]any)["recall"]; got != "0.9" {
		t.Fatalf("recall must come from sweep-classes.tsv, got %v", got)
	}
	// A change to the register changes the summary (it is derived, never typed).
	applySQL(t, db, `UPDATE items SET disposition='closed' WHERE atm_id='VSC-005'`)
	_, out4 := gapRun(t, repo, db, "summary", "--json")
	if out4 == out3 {
		t.Fatal("summary did not change when the register did")
	}
}

func TestGapSummaryTextNamesTheCounts(t *testing.T) {
	repo, db := gapRepo(t), buildRegister(t, true, "golden-good.sql")
	rc, out := gapRun(t, repo, db, "summary")
	if rc != 0 || !strings.Contains(out, "total 6") || !strings.Contains(out, "closed 1") {
		t.Fatalf("summary text: rc %d\n%s", rc, out)
	}
}

var _ = time.Now
