package wi

// Feature 010, task "gap set-cycle" (contracts/register-cli.md; the confirmed
// tooling gap recorded in progress.yml "gap freeze BLOCKED (impl-freeze)": `gap
// freeze` selects cycleMembers via `items.cycle = ?`, but no existing CLI path
// stamps `cycle` onto a PRE-EXISTING gap item — only `gap add`'s INSERT accepts
// --cycle, and adopt/classify/close/reopen/link/apply-queue/verdict have no
// --cycle flag at all). `gap set-cycle` is that path: the discipline mirrors
// `gap adopt` exactly (adopt_test.go), since both are one-time, DB-guarded
// column-preserving UPDATEs racing the same TOCTOU window. Every register here
// is a fixture copy in t.TempDir(); the tracked docs/workable_items.db is
// never opened.

import (
	"bytes"
	"database/sql"
	"strings"
	"sync/atomic"
	"testing"
)

// ── RED-first proof (function absent / wrong item touched) ─────────────────

// TestGapSetCycleUnknownSubcommandIsRefused pins the RED state this
// implementation started from: before gapSetCycle existed, RunGap had no
// "set-cycle" entry in its dispatch table and refused it as an unknown
// subcommand (rc 2). It stays green now as a permanent regression guard that
// the dispatch wiring itself never regresses (a wrong/missing dispatch entry
// is exactly how "wrong item touched" bugs like this start: RunGap would
// silently fall through to the wrong handler, or to none at all).
func TestGapSetCycleUnknownSubcommandIsRefused(t *testing.T) {
	var out, errb bytes.Buffer
	rc := RunGap([]string{"set-cycl", "--id", "VSC-002", "--cycle", "1"}, &out, &errb)
	if rc != 2 {
		t.Fatalf("misspelled subcommand: want rc 2, got %d", rc)
	}
	if !strings.Contains(errb.String(), `unknown subcommand "set-cycl"`) {
		t.Fatalf("refusal does not name the bad subcommand:\n%s", errb.String())
	}
}

// ── fixtures ─────────────────────────────────────────────────────────────

// setCycleArgs stamps VSC-002 (adopted below as a gap item) with cycle "1".
var setCycleArgs = []string{"set-cycle", "--id", "VSC-002", "--cycle", "1", "--as-of", fixtureAsOf}

// adoptVSC002 adopts legacy VSC-002 (Queued, Issues, non-gap) as an ordinary
// gap item with cycle still NULL — adopt never touches cycle.
func adoptVSC002(t *testing.T, repo, db string) {
	t.Helper()
	if rc, out := gapRun(t, repo, db, adoptArgs...); rc != 0 {
		t.Fatalf("setup: adopting VSC-002: rc %d\n%s", rc, out)
	}
	if field(t, db, "VSC-002", "cycle") != "" {
		t.Fatal("setup: VSC-002 unexpectedly already has a cycle")
	}
}

// addVSC003 opens a second gap item, VSC-003, via `gap add` (legacy-register.sql's
// highest existing id is VSC-002, matching adopt_test.go's own comment), with
// cycle left NULL — addArgs does not pass --cycle.
func addVSC003(t *testing.T, repo, db string) {
	t.Helper()
	if rc, out := gapRun(t, repo, db, addArgs...); rc != 0 {
		t.Fatalf("setup: gap add VSC-003: rc %d\n%s", rc, out)
	}
	if field(t, db, "VSC-003", "cycle") != "" {
		t.Fatal("setup: VSC-003 unexpectedly already has a cycle")
	}
}

// addVSC004WithCycle opens a third gap item, VSC-004, already carrying cycle
// "9" at INSERT time (gap add's own --cycle flag) — the "already stamped, must
// be left alone by the bulk path" fixture.
func addVSC004WithCycle(t *testing.T, repo, db string) {
	t.Helper()
	args := append(append([]string{}, addArgs...), "--cycle", "9")
	if rc, out := gapRun(t, repo, db, args...); rc != 0 {
		t.Fatalf("setup: gap add VSC-004 --cycle 9: rc %d\n%s", rc, out)
	}
	if field(t, db, "VSC-004", "cycle") != "9" {
		t.Fatal("setup: VSC-004 was not opened with cycle 9")
	}
}

// ── happy path ───────────────────────────────────────────────────────────

func TestGapSetCycleStampsAGapItem(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	adoptVSC002(t, repo, db)

	rc, out := gapRun(t, repo, db, setCycleArgs...)
	if rc != 0 {
		t.Fatalf("gap set-cycle: want rc 0, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "VSC-002") || !strings.Contains(out, "cycle 1") {
		t.Fatalf("stdout does not confirm the stamp:\n%s", out)
	}
	if g := field(t, db, "VSC-002", "cycle"); g != "1" {
		t.Fatalf("cycle = %q, want 1", g)
	}
	// Every other column untouched (kind, disposition, status, type).
	if g := field(t, db, "VSC-002", "kind"); g != "unfinished-promise" {
		t.Fatalf("kind = %q, want unchanged unfinished-promise", g)
	}
	if g := field(t, db, "VSC-002", "status"); g != StatusQueued {
		t.Fatalf("status = %q, want unchanged %q", g, StatusQueued)
	}
	if g := field(t, db, "VSC-002", "type"); g != "Task" {
		t.Fatalf("type = %q, want unchanged Task", g)
	}
	gapCleanIn(t, repo, db)
}

// ── refusals ─────────────────────────────────────────────────────────────

func TestGapSetCycleRefusesANonGapItem(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	// VSC-002 is legacy, not yet adopted: not a gap item.
	rc, out := gapRun(t, repo, db, setCycleArgs...)
	if rc != 1 {
		t.Fatalf("set-cycle on a non-gap item: want rc 1, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "VSC-002 is not a gap item") {
		t.Fatalf("refusal does not explain why:\n%s", out)
	}
	if field(t, db, "VSC-002", "cycle") != "" {
		t.Fatal("VSC-002.cycle was written despite the refusal")
	}
}

func TestGapSetCycleRefusesANonexistentID(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	rc, out := gapRun(t, repo, db, withArg(setCycleArgs, "--id", "VSC-999")...)
	if rc != 1 {
		t.Fatalf("set-cycle on a nonexistent id: want rc 1, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, `no item "VSC-999"`) {
		t.Fatalf("refusal does not name the missing id:\n%s", out)
	}
}

func TestGapSetCycleRefusesAnAlreadyCycledItem(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	adoptVSC002(t, repo, db)
	if rc, out := gapRun(t, repo, db, setCycleArgs...); rc != 0 {
		t.Fatalf("setup stamp: rc %d\n%s", rc, out)
	}
	rc, out := gapRun(t, repo, db, withArg(setCycleArgs, "--cycle", "2")...)
	if rc != 1 {
		t.Fatalf("re-stamp of an already-cycled item: want rc 1, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, `VSC-002 is already assigned to cycle "1"`) {
		t.Fatalf("refusal does not give the clear already-assigned message:\n%s", out)
	}
	if field(t, db, "VSC-002", "cycle") != "1" {
		t.Fatal("the re-stamp attempt overwrote the existing cycle despite the refusal")
	}
}

func TestGapSetCycleRefusesMissingOrMalformedCycle(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	adoptVSC002(t, repo, db)

	rc, out := gapRun(t, repo, db, withoutArg(setCycleArgs, "--cycle")...)
	if rc != 1 || !strings.Contains(out, "--cycle is required") {
		t.Fatalf("missing --cycle: want rc 1 naming it, got %d\n%s", rc, out)
	}

	rc, out = gapRun(t, repo, db, withArg(setCycleArgs, "--cycle", "has spaces")...)
	if rc != 1 || !strings.Contains(out, "is not a plain identifier") {
		t.Fatalf("malformed --cycle: want rc 1 naming it, got %d\n%s", rc, out)
	}
	if field(t, db, "VSC-002", "cycle") != "" {
		t.Fatal("VSC-002.cycle was written despite the refusal")
	}
}

func TestGapSetCycleRefusesMissingID(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	rc, out := gapRun(t, repo, db, withoutArg(setCycleArgs, "--id")...)
	if rc != 1 {
		t.Fatalf("missing --id (and no bulk flag): want rc 1, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "--id is required") {
		t.Fatalf("refusal does not explain why:\n%s", out)
	}
}

func TestGapSetCycleRefusesCombiningIDAndBulk(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	rc, out := gapRun(t, repo, db, append(append([]string{}, setCycleArgs...), "--gap-items-without-cycle")...)
	if rc != 1 {
		t.Fatalf("--id with --gap-items-without-cycle: want rc 1, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "mutually exclusive") {
		t.Fatalf("refusal does not name the conflict:\n%s", out)
	}
}

// ── isolation: set-cycle touches only its own row's cycle column ──────────

func TestGapSetCycleDoesNotTouchAnyOtherRowOrColumn(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	adoptVSC002(t, repo, db)
	addVSC003(t, repo, db)

	cols := []string{"type", "status", "severity", "title", "description", "kind", "category",
		"disposition", "classification_reason", "plan_due", "measurable_target", "forensic_anchor",
		"closure_criteria", "cycle"}
	otherIDs := []string{"VSC-001", "VSC-003"} // untouched neighbours: legacy non-gap + a second gap item
	before := map[string]map[string]string{}
	for _, id := range otherIDs {
		row := map[string]string{}
		for _, c := range cols {
			row[c] = field(t, db, id, c)
		}
		before[id] = row
	}
	// VSC-002's own non-cycle columns must also survive untouched.
	vscBefore := map[string]string{}
	for _, c := range cols {
		if c != "cycle" {
			vscBefore[c] = field(t, db, "VSC-002", c)
		}
	}

	if rc, out := gapRun(t, repo, db, setCycleArgs...); rc != 0 {
		t.Fatalf("gap set-cycle: rc %d\n%s", rc, out)
	}

	for _, id := range otherIDs {
		for _, c := range cols {
			if got, want := field(t, db, id, c), before[id][c]; got != want {
				t.Fatalf("stamping VSC-002 changed %s.%s: was %q, now %q", id, c, want, got)
			}
		}
	}
	for c, want := range vscBefore {
		if got := field(t, db, "VSC-002", c); got != want {
			t.Fatalf("stamping VSC-002.cycle changed its own %s: was %q, now %q", c, want, got)
		}
	}
	if field(t, db, "VSC-002", "cycle") != "1" {
		t.Fatal("VSC-002.cycle was not actually written")
	}
}

// ── bulk: --gap-items-without-cycle ─────────────────────────────────────

func TestGapSetCycleBulkStampsEveryCycleLessGapItem(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	adoptVSC002(t, repo, db)        // gap, cycle NULL
	addVSC003(t, repo, db)          // gap, cycle NULL
	addVSC004WithCycle(t, repo, db) // gap, cycle already "9" — must be left alone

	rc, out := gapRun(t, repo, db, "set-cycle", "--gap-items-without-cycle", "--cycle", "1", "--as-of", fixtureAsOf)
	if rc != 0 {
		t.Fatalf("bulk set-cycle: want rc 0, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "2 gap item(s)") {
		t.Fatalf("stdout does not report exactly 2 stamped:\n%s", out)
	}
	if g := field(t, db, "VSC-002", "cycle"); g != "1" {
		t.Fatalf("VSC-002.cycle = %q, want 1", g)
	}
	if g := field(t, db, "VSC-003", "cycle"); g != "1" {
		t.Fatalf("VSC-003.cycle = %q, want 1", g)
	}
	// Already-cycled item is untouched by the bulk pass.
	if g := field(t, db, "VSC-004", "cycle"); g != "9" {
		t.Fatalf("VSC-004.cycle = %q, want unchanged 9 (bulk must not re-stamp an already-cycled item)", g)
	}
	// Non-gap item is untouched.
	if g := field(t, db, "VSC-001", "cycle"); g != "" {
		t.Fatalf("VSC-001.cycle = %q, want still empty (not a gap item)", g)
	}
	gapCleanIn(t, repo, db)

	// Running it again finds nothing left to stamp.
	rc, out = gapRun(t, repo, db, "set-cycle", "--gap-items-without-cycle", "--cycle", "2", "--as-of", fixtureAsOf)
	if rc != 2 {
		t.Fatalf("bulk set-cycle with nothing left to stamp: want rc 2 (COULD NOT DETERMINE), got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "nothing to stamp") {
		t.Fatalf("refusal does not explain the empty population:\n%s", out)
	}
}

// TestGapSetCycleBulkIsAtomicOnPartialFailure forces a genuine SQL
// CHECK-constraint violation (item_history.event_type is a closed set) right
// after the FIRST target (VSC-002) has already been written inside the bulk
// transaction, and confirms the whole batch rolled back: VSC-002's already-run
// UPDATE left no trace, and the second target (VSC-003, never reached) is
// likewise untouched.
func TestGapSetCycleBulkIsAtomicOnPartialFailure(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	adoptVSC002(t, repo, db)
	addVSC003(t, repo, db)

	old := setCycleBulkMidHook
	t.Cleanup(func() { setCycleBulkMidHook = old })
	hit := 0
	setCycleBulkMidHook = func(tx *sql.Tx, id string) error {
		hit++
		if id != "VSC-002" {
			return nil // only fail after the FIRST target
		}
		_, err := tx.Exec(`INSERT INTO item_history (atm_id,event_type,by,on_date,created_at) VALUES (?,?,?,?,?)`,
			"VSC-002", "not-a-real-event-type", "AI", fixtureAsOf, stamp())
		if err == nil {
			t.Fatal("the deliberately invalid event_type did not violate the CHECK constraint")
		}
		return err
	}

	rc, out := gapRun(t, repo, db, "set-cycle", "--gap-items-without-cycle", "--cycle", "1", "--as-of", fixtureAsOf)
	if rc != 2 {
		t.Fatalf("bulk set-cycle with a mid-batch constraint violation: want rc 2 (COULD NOT DETERMINE), got %d\n%s", rc, out)
	}
	if hit != 1 {
		t.Fatalf("hook fired %d time(s), want exactly 1 (VSC-002 is processed first, alphabetically)", hit)
	}
	if field(t, db, "VSC-002", "cycle") != "" {
		t.Fatal("VSC-002.cycle was written despite the mid-batch failure: the batch was not atomic")
	}
	if field(t, db, "VSC-003", "cycle") != "" {
		t.Fatal("VSC-003.cycle was written despite the mid-batch failure (it should never even have been reached)")
	}

	// The population is still stampable afterwards: nothing was left
	// half-written by the rolled-back attempt.
	setCycleBulkMidHook = nil
	rc, out = gapRun(t, repo, db, "set-cycle", "--gap-items-without-cycle", "--cycle", "1", "--as-of", fixtureAsOf)
	if rc != 0 {
		t.Fatalf("bulk set-cycle after the rolled-back attempt: want rc 0, got %d\n%s", rc, out)
	}
	if field(t, db, "VSC-002", "cycle") != "1" || field(t, db, "VSC-003", "cycle") != "1" {
		t.Fatal("the retried bulk stamp did not actually write both items")
	}
}

// ── concurrency: the same §11.4.253 race gap adopt was fixed against ──────

// TestGapSetCycleRaceRefusesConcurrentDoubleStamp reproduces, on `gap
// set-cycle`, the exact TOCTOU shape rev-adopt's review found on `gap adopt`
// (progress.yml "gap adopt review rev-adopt" / "gap adopt race fix DONE"):
// the it.cycle=="" refusal check reads via loadItem BEFORE the write
// transaction begins, so two concurrent `gap set-cycle --id` calls on the
// same id could both pass that check and both attempt to commit. The fix is
// the identical shape: the UPDATE's WHERE clause carries `AND cycle IS NULL`
// and RowsAffected() is checked rather than trusted.
//
// This test drives the race with two goroutines and setCyclePreBeginHook — a
// real transaction-ordering hook, not a sleep-and-hope: the hook pauses the
// FIRST caller to reach it (right after that caller's own it.cycle=="" check
// has already read "no cycle yet") until the SECOND caller has run a
// complete, independent `gap set-cycle` (open its own transaction, UPDATE,
// commit) to completion. The first caller then resumes holding a stale
// it.cycle=="" read and attempts its own write.
//
// This exact race was ALSO reproduced with two REAL, independent OS
// processes racing the compiled binary (not just goroutines sharing one
// process and its scheduler):
//
//	go build -o /tmp/wi-vsc ./_tools/workable-items
//	export WI_GAP_SETCYCLE_RACE_MS=800   # widen the TOCTOU window
//	./wi-vsc gap set-cycle --repo <repo> --db <db> --id VSC-002 --cycle 1 --as-of 2026-09-25 &
//	./wi-vsc gap set-cycle --repo <repo> --db <db> --id VSC-002 --cycle 1 --as-of 2026-09-25 &
//	wait
//	sqlite3 <db> "SELECT reason FROM item_history WHERE atm_id='VSC-002' AND reason LIKE 'zero-gap:cycle-set%'"
//
// Confirmed: exactly one process printed "stamped with cycle 1" (rc 0), the
// other printed "assigned a cycle concurrently" (rc 1), and the query above
// returned exactly ONE matching row.
//
// Mutation (manually confirmed, not re-run automatically by this test):
// removing "AND cycle IS NULL" from the UPDATE's WHERE clause in gapcmd.go
// reproduces the RED result under this very test — both calls rc 0, 2 history
// rows — confirming the test actually exercises the guard rather than passing
// vacuously.
func TestGapSetCycleRaceRefusesConcurrentDoubleStamp(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	adoptVSC002(t, repo, db)

	oldHook := setCyclePreBeginHook
	t.Cleanup(func() { setCyclePreBeginHook = oldHook })

	reached := make(chan struct{})
	release := make(chan struct{})
	var first int32 // NOT sync.Once — see adopt_test.go's identical comment: Once.Do
	// would deadlock this test, since the first call's function only returns
	// after the second caller has run to completion.
	setCyclePreBeginHook = func() {
		if atomic.CompareAndSwapInt32(&first, 0, 1) {
			close(reached)
			<-release
		}
	}

	type outcome struct {
		rc  int
		out string
	}
	run := func() outcome {
		var out, errb bytes.Buffer
		full := []string{"set-cycle", "--repo", repo, "--db", db, "--id", "VSC-002", "--cycle", "1", "--as-of", fixtureAsOf}
		rc := RunGap(full, &out, &errb)
		return outcome{rc, out.String() + errb.String()}
	}

	results := make(chan outcome, 2)
	go func() { results <- run() }() // pauses inside the hook after its own it.cycle=="" check
	<-reached
	go func() {
		r := run() // runs to completion (own transaction, UPDATE, commit) unimpeded
		results <- r
		close(release) // only now does the paused caller resume with its stale read
	}()

	r1, r2 := <-results, <-results
	var winner, refused outcome
	switch {
	case r1.rc == 0 && r2.rc == 1:
		winner, refused = r1, r2
	case r1.rc == 1 && r2.rc == 0:
		winner, refused = r2, r1
	default:
		t.Fatalf("concurrent double stamp: want exactly one rc 0 and one rc 1, got rc=%d/%d\ncall A: %s\ncall B: %s",
			r1.rc, r2.rc, r1.out, r2.out)
	}
	if !strings.Contains(winner.out, "VSC-002 stamped with cycle 1") {
		t.Fatalf("the winning call's message does not confirm the stamp:\n%s", winner.out)
	}
	if !strings.Contains(refused.out, "assigned a cycle concurrently") {
		t.Fatalf("the refused call's message does not explain the race:\n%s", refused.out)
	}

	if g := field(t, db, "VSC-002", "cycle"); g != "1" {
		t.Fatalf("cycle = %q, want 1 (the winner's write, and only the winner's)", g)
	}
	rdb := rawOpen(t, db)
	defer rdb.Close()
	var n int
	if err := rdb.QueryRow(`SELECT COUNT(*) FROM item_history WHERE atm_id=? AND reason LIKE 'zero-gap:cycle-set%'`, "VSC-002").Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("zero-gap:cycle-set history rows for VSC-002 = %d, want exactly 1 (the one-time stamp survives the race)", n)
	}

	// The register is still clean afterwards.
	gapCleanIn(t, repo, db)
}
