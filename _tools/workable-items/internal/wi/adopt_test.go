package wi

// Feature 010, task "gap adopt" (contracts/register-cli.md amendment; the
// confirmed tooling gap recorded in progress.yml "Migration dry-run
// plan-migrate DONE" item 4 and ratified in "Operator ratifications
// 2026-09-26"). `gap adopt` is the mirror image of `gap add`: instead of
// INSERTing a new row it UPDATEs an EXISTING non-gap row in place, setting
// it.gap=true and filling the 14 zero-gap columns. Every register here is a
// fixture copy in t.TempDir(); the tracked docs/workable_items.db is never
// opened.

import (
	"bytes"
	"database/sql"
	"strings"
	"sync/atomic"
	"testing"
)

// legacyRegister builds a migrated register carrying the two legacy
// (pre-feature-010) items legacy-register.sql ships: VSC-001 (Completed, in
// Fixed) and VSC-002 (Queued, in Issues, not a gap item). VSC-001 doubles as
// the "other row" neighbour for the isolation test below (golden-good.sql's
// own VSC-001..VSC-006 cannot be layered on top: they collide on atm_id with
// legacy-register.sql's rows, which is the fixture's own back-compat point —
// see its file comment).
func legacyRegister(t *testing.T) string {
	t.Helper()
	return buildRegister(t, true, "legacy-register.sql")
}

var adoptArgs = []string{"adopt", "--id", "VSC-002",
	"--kind", "unfinished-promise", "--severity", "medium", "--category", "data-integrity",
	"--title", "adopted: legacy queued task needs a measurable target",
	"--root-cause", "The item was opened before the zero-gap columns existed and carries no kind, category or plan.",
	"--proposed-fix", "Backfill the gap columns in place with `gap adopt` and give it a dated plan.",
	"--closure-criteria", "the item closes through `gap close` like any other gap item",
	"--anchor", "_tests/fixtures/zero-gap/registers/legacy-register.sql:11",
	"--owner", "agent-owner",
	"--evidence", fixtureRel + "/evidence/legacy-completion.md",
	"--plan-due", "2026-12-31", "--as-of", fixtureAsOf}

// ── happy path ───────────────────────────────────────────────────────────

func TestGapAdoptOpensAnExistingItemAsAGapItem(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	rc, out := gapRun(t, repo, db, adoptArgs...)
	if rc != 0 {
		t.Fatalf("gap adopt: want rc 0, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "VSC-002") {
		t.Fatalf("gap adopt: stdout does not name VSC-002:\n%s", out)
	}
	if g := field(t, db, "VSC-002", "kind"); g != "unfinished-promise" {
		t.Fatalf("kind = %q, want unfinished-promise", g)
	}
	if g := field(t, db, "VSC-002", "disposition"); g != "open" {
		t.Fatalf("disposition = %q, want open", g)
	}
	if g := field(t, db, "VSC-002", "status"); g != StatusQueued {
		t.Fatalf("status = %q, want unchanged %q (adopt never changes status)", g, StatusQueued)
	}
	if g := field(t, db, "VSC-002", "type"); g != "Task" {
		t.Fatalf("type = %q, want unchanged Task (adopt never changes type)", g)
	}

	// `gap validate` (ValidateGap) sees it as a normal, clean gap item.
	gapCleanIn(t, repo, db)

	// `report --by-module` also sees it, placed under its VSC module, as an
	// ordinary open gap item — not under "Unplaced items", not a Register
	// problem.
	rrc, page, _ := runModuleReport(t, repo, db, fixtureAsOf)
	if rrc != 0 {
		t.Fatalf("report --by-module after adopt: want rc 0, got %d\n%s", rrc, page)
	}
	if !strings.Contains(page, "VSC-002") {
		t.Fatalf("report --by-module: page does not mention VSC-002:\n%s", page)
	}
	if strings.Contains(page, "Unplaced items") && strings.Contains(page[strings.Index(page, "Unplaced items"):], "VSC-002") {
		t.Fatalf("report --by-module: VSC-002 was placed under Unplaced items, not its module")
	}
}

// ── refusals ─────────────────────────────────────────────────────────────

func TestGapAdoptRefusesAnAlreadyGapItem(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	if rc, out := gapRun(t, repo, db, adoptArgs...); rc != 0 {
		t.Fatalf("setup adopt: rc %d\n%s", rc, out)
	}
	rc, out := gapRun(t, repo, db, adoptArgs...)
	if rc != 1 {
		t.Fatalf("double adopt: want rc 1 (REFUSED), got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "already a gap item") {
		t.Fatalf("double adopt: refusal does not explain why:\n%s", out)
	}
	// A double adopt must also refuse an ALREADY-gap item created by `gap add`,
	// not only one adopted a moment ago. legacy-register.sql's highest existing
	// atm_id is VSC-002, so `gap add --prefix VSC` opens VSC-003.
	if rc, out := gapRun(t, repo, db, addArgs...); rc != 0 {
		t.Fatalf("gap add setup: rc %d\n%s", rc, out)
	}
	if field(t, db, "VSC-003", "kind") == "" {
		t.Fatalf("setup: gap add did not open VSC-003 as expected")
	}
	rc, out = gapRun(t, repo, db, withArg(adoptArgs, "--id", "VSC-003")...)
	if rc != 1 || !strings.Contains(out, "already a gap item") {
		t.Fatalf("adopt of an add-created item: want rc 1 REFUSED already-gap, got %d\n%s", rc, out)
	}
}

func TestGapAdoptRefusesANonexistentID(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	rc, out := gapRun(t, repo, db, withArg(adoptArgs, "--id", "VSC-999")...)
	if rc != 1 {
		t.Fatalf("adopt of a nonexistent id: want rc 1, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, `no item "VSC-999"`) {
		t.Fatalf("refusal does not name the missing id:\n%s", out)
	}
}

func TestGapAdoptRefusesAMissingRequiredField(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	for _, flag := range []string{"--kind", "--severity", "--category", "--title", "--root-cause", "--proposed-fix", "--closure-criteria"} {
		t.Run(flag, func(t *testing.T) {
			rc, out := gapRun(t, repo, db, withoutArg(adoptArgs, flag)...)
			if rc != 1 {
				t.Fatalf("missing %s: want rc 1, got %d\n%s", flag, rc, out)
			}
			if !strings.Contains(out, flag+" is required") {
				t.Fatalf("missing %s: refusal does not name it:\n%s", flag, out)
			}
			if field(t, db, "VSC-002", "kind") != "" {
				t.Fatalf("missing %s: VSC-002 was written despite the refusal", flag)
			}
		})
	}
}

func TestGapAdoptRefusesAKindNeedingImprovementTargetWithNoTarget(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	args := withArg(adoptArgs, "--kind", "improvement")
	rc, out := gapRun(t, repo, db, args...)
	if rc != 1 {
		t.Fatalf("improvement with no target: want rc 1, got %d\n%s", rc, out)
	}
	if !strings.Contains(out, "V-G4") {
		t.Fatalf("refusal does not cite V-G4:\n%s", out)
	}
	if field(t, db, "VSC-002", "kind") != "" {
		t.Fatal("VSC-002 was written despite the V-G4 refusal")
	}
	// With a target it succeeds.
	args = append(withArg(args, "--kind", "improvement"), "--measurable-target", "100% of X pass Y")
	if rc, out := gapRun(t, repo, db, args...); rc != 0 {
		t.Fatalf("improvement with a target: want rc 0, got %d\n%s", rc, out)
	}
}

func TestGapAdoptRefusesAStatusDispositionMismatch(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	// VSC-001 is Completed/Fixed; --disposition open (the default) needs an
	// open status.
	rc, out := gapRun(t, repo, db, withArg(adoptArgs, "--id", "VSC-001")...)
	if rc != 1 || !strings.Contains(out, "adopt does not change status") {
		t.Fatalf("adopt of a closed legacy item as open: want rc 1 naming the status mismatch, got %d\n%s", rc, out)
	}
	if field(t, db, "VSC-001", "kind") != "" {
		t.Fatal("VSC-001 was written despite the refusal")
	}
}

// ── isolation: adopt touches only its own row ───────────────────────────

func TestGapAdoptDoesNotTouchAnyOtherRow(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	before := map[string]map[string]string{}
	otherIDs := []string{"VSC-001"} // legacy-register.sql's other item (Completed, in Fixed)
	cols := []string{"type", "status", "severity", "title", "description", "kind", "category",
		"disposition", "classification_reason", "plan_due", "measurable_target", "forensic_anchor", "closure_criteria"}
	for _, id := range otherIDs {
		row := map[string]string{}
		for _, c := range cols {
			row[c] = field(t, db, id, c)
		}
		before[id] = row
	}
	if rc, out := gapRun(t, repo, db, adoptArgs...); rc != 0 {
		t.Fatalf("gap adopt: rc %d\n%s", rc, out)
	}
	for _, id := range otherIDs {
		for _, c := range cols {
			if got, want := field(t, db, id, c), before[id][c]; got != want {
				t.Fatalf("adopting VSC-002 changed %s.%s: was %q, now %q", id, c, want, got)
			}
		}
	}
}

// ── atomicity ────────────────────────────────────────────────────────────

// TestGapAdoptIsAtomic forces a genuine SQL CHECK-constraint violation
// (item_history.event_type is a closed set) partway through the write
// transaction via adoptMidHook, between the items UPDATE and the
// history/provenance inserts, and confirms the whole write rolled back: the
// items UPDATE that already ran inside the same transaction left no trace.
func TestGapAdoptIsAtomic(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)
	old := adoptMidHook
	t.Cleanup(func() { adoptMidHook = old })
	adoptMidHook = func(tx *sql.Tx) error {
		_, err := tx.Exec(`INSERT INTO item_history (atm_id,event_type,by,on_date,created_at) VALUES (?,?,?,?,?)`,
			"VSC-002", "not-a-real-event-type", "AI", fixtureAsOf, stamp())
		if err == nil {
			t.Fatal("the deliberately invalid event_type did not violate the CHECK constraint")
		}
		return err
	}
	rc, out := gapRun(t, repo, db, adoptArgs...)
	if rc != 2 {
		t.Fatalf("adopt with a mid-write constraint violation: want rc 2 (COULD NOT DETERMINE), got %d\n%s", rc, out)
	}
	if field(t, db, "VSC-002", "kind") != "" {
		t.Fatal("VSC-002's gap columns were written despite the mid-write failure: the transaction was not atomic")
	}
	if field(t, db, "VSC-002", "disposition") != "" {
		t.Fatal("VSC-002.disposition was written despite the mid-write failure")
	}
	// The item is still adoptable afterwards: nothing was left half-written.
	adoptMidHook = nil
	if rc, out := gapRun(t, repo, db, adoptArgs...); rc != 0 {
		t.Fatalf("adopt after the rolled-back attempt: want rc 0, got %d\n%s", rc, out)
	}
}

// ── concurrency: the TOCTOU race rev-adopt found ────────────────────────

// TestGapAdoptRaceRefusesConcurrentDoubleAdopt reproduces, and then proves
// fixed, the CRITICAL §11.4.253 race rev-adopt's review found (progress.yml
// "gap adopt review rev-adopt"): the it.gap refusal check reads via loadItem
// BEFORE the write transaction begins, so two concurrent `gap adopt` calls on
// the same id could both pass that check and both commit — the register ended
// up with 2 "zero-gap:adopted" history rows for one id, breaking adopt's
// one-time invariant under real concurrency (the seeding scenario: 18 rows,
// possibly multiple concurrent agents).
//
// This test drives the race with two goroutines and adoptPreBeginHook — a
// real transaction-ordering hook, not a sleep-and-hope: the hook pauses the
// FIRST caller to reach it (right after that caller's own it.gap check has
// already read "not yet a gap item") until the SECOND caller has run a
// complete, independent `gap adopt` (open its own transaction, UPDATE,
// commit) to completion. The first caller then resumes holding a stale
// it.gap==false read and attempts its own write.
//
// This exact race was ALSO reproduced with two REAL, independent OS
// processes racing on the compiled binary (not just goroutines sharing one
// process and its scheduler), using a second, separately-gated widening seam
// (adoptRaceWindow / WI_GAP_ADOPT_RACE_MS, gapcmd.go) so the reproduction does
// not depend on Go's goroutine scheduler at all:
//
//	go build -o /tmp/wi-vsc ./_tools/workable-items
//	export WI_GAP_ADOPT_RACE_MS=800   # widen the TOCTOU window
//	./wi-vsc gap adopt --repo <repo> --db <db> --id VSC-002 <...same flags as adoptArgs...> &
//	./wi-vsc gap adopt --repo <repo> --db <db> --id VSC-002 <...same flags as adoptArgs...> &
//	wait
//	sqlite3 <db> "SELECT reason FROM item_history WHERE atm_id='VSC-002' AND reason LIKE 'zero-gap:%'"
//
// Confirmed RED against the pre-fix code (UPDATE with no column guard, plain
// RowsAffected()!=1 envFail): both real OS processes printed "gap adopt: ...
// adopted ..." at rc 0, and the query above returned 2 matching rows.
// Re-running the identical recipe against the fixed binary printed REFUSED
// "adopted concurrently" (rc 1) from exactly one process, "adopted" (rc 0)
// from the other, and the query returned exactly 1 row — the same GREEN this
// test asserts below via goroutines, for CI speed.
//
// Mutation (manually confirmed, not re-run automatically by this test):
// removing "AND kind IS NULL" from the UPDATE's WHERE clause in gapcmd.go
// reproduces the RED result above under this very test — both calls rc 0, 2
// history rows — confirming the test actually exercises the guard rather than
// passing vacuously.
func TestGapAdoptRaceRefusesConcurrentDoubleAdopt(t *testing.T) {
	repo, db := gapRepo(t), legacyRegister(t)

	oldHook := adoptPreBeginHook
	t.Cleanup(func() { adoptPreBeginHook = oldHook })

	reached := make(chan struct{})
	release := make(chan struct{})
	var first int32 // NOT sync.Once: Once.Do blocks every caller, including the
	// second, until the first call's function returns — which would deadlock
	// this test, since the first call's function only returns after the
	// second caller has run to completion. An atomic CAS lets the second
	// caller fall straight through instead of queuing behind the first.
	adoptPreBeginHook = func() {
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
		full := append([]string{"adopt", "--repo", repo, "--db", db}, adoptArgs[1:]...)
		rc := RunGap(full, &out, &errb)
		return outcome{rc, out.String() + errb.String()}
	}

	results := make(chan outcome, 2)
	go func() { results <- run() }() // pauses inside the hook after its own it.gap check
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
		t.Fatalf("concurrent double adopt: want exactly one rc 0 and one rc 1, got rc=%d/%d\ncall A: %s\ncall B: %s",
			r1.rc, r2.rc, r1.out, r2.out)
	}
	if !strings.Contains(winner.out, "VSC-002 adopted as a gap item") {
		t.Fatalf("the winning call's message does not confirm the adoption:\n%s", winner.out)
	}
	if !strings.Contains(refused.out, "adopted concurrently") {
		t.Fatalf("the refused call's message does not explain the race:\n%s", refused.out)
	}

	if g := field(t, db, "VSC-002", "kind"); g != "unfinished-promise" {
		t.Fatalf("kind = %q, want unfinished-promise (the winner's write, and only the winner's)", g)
	}
	rdb := rawOpen(t, db)
	defer rdb.Close()
	var n int
	if err := rdb.QueryRow(`SELECT COUNT(*) FROM item_history WHERE atm_id=? AND reason LIKE 'zero-gap:%'`, "VSC-002").Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("zero-gap:adopted history rows for VSC-002 = %d, want exactly 1 (adopt's one-time invariant survives the race)", n)
	}

	// The register is still clean afterwards: the race left it in a state
	// ValidateGap and the canonical validator both accept, not a half-adopted
	// or double-adopted one.
	gapCleanIn(t, repo, db)
}
