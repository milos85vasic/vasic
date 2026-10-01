---
description: "Task list for feature 013: Adaptive Assessment and Real-Time Scoring"
---

# Tasks: Adaptive Assessment and Real-Time Scoring

**Input**: Design documents from `specs/013-adaptive-assessment-scoring/`
**Prerequisites**: [plan.md](plan.md) (required), [spec.md](spec.md) (required for user stories),
[data-model.md](data-model.md), [contracts/practice-next.md](contracts/practice-next.md),
[contracts/practice-submit.md](contracts/practice-submit.md),
[contracts/progress-extension.md](contracts/progress-extension.md), [quickstart.md](quickstart.md)

## Task Format

```
[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description with file path (FR-…, SC-…)
```

`[P]` parallelizable (different files, no dependency on a same-phase sibling) · `[TDD]` RED-GREEN-REFACTOR,
test written and observed to fail for the right reason before the implementation exists (§11.4.224) ·
`[REVIEW]` operator/independent-review gate before the next task may rely on it · `[SUBAGENT]` delegable
to a subagent without losing correctness (self-contained, file-scoped).

## Global constraints (from plan.md's Technical Context and Constitution Check — every task below implicitly includes these)

- All work happens inside the private `workshop` submodule, specifically `workshop/platform/backend/`
  (Go module `github.com/milos85vasic/workshop_curriculum/platform/backend`, Go 1.26.2). Do **not**
  modify anything outside `workshop/platform/backend/` for this feature (`cmd/workshop-server/main.go`
  is the one file outside `pkg/`/`internal/api/` this feature touches, and it is inside the same module).
  Nothing in this feature touches the public umbrella root.
- No new third-party dependency: `modernc.org/sqlite` v1.59.0 and `github.com/vasic-digital/passage`
  are already vendored in `go.mod`/`go.sum` (verified present this session).
- New package `pkg/scoring` — never inside `pkg/assessment` (plan.md's "Package placement decision").
  `pkg/scoring` depends on `pkg/assessment` and `passage.PID`; never the reverse.
- New dedicated SQLite file `scoring.db`, opened the `pkg/authstore` way (a separate file from the
  server's data directory, `db.SetMaxOpenConns(1)`) — never the index/`pkg/crossref` database, so
  scoring history survives a content re-index (plan.md's "Storage placement decision").
- §11.4.224 (TDD for ALL work): every new behavior in `pkg/scoring`'s pure functions and the two new
  HTTP handlers' branches is written test-first, run first, and observed to fail for the right reason
  before the implementation exists. The POC script's captured trace
  (`workshop/docs/research/education-platform/poc/sample-output-30-attempts-seed42.txt`) is the
  §11.4.245 DERIVED oracle for the ability-update arithmetic — tests assert against ITS printed `K`
  and `delta` columns, never against the Go code's own output re-asserted on itself.
- §11.4.241 (illegal-state-unrepresentability, rung order TYPE → API SHAPE → LINT → PROPERTY-TEST →
  RUNTIME ASSERTION): `AbilityScore` and `ResponseLogEntry` have EVERY field unexported (data-model.md
  §1.1/§1.2) — a real rung-1 closure (Go's own field-visibility rule: a composite literal or field
  assignment from outside `pkg/scoring` fails to COMPILE, not merely "is undisciplined"), with
  read-only accessor methods as the only exported surface and no exported constructor outside
  `Store.RecordResponse`/`Store.RecordGradedResponse`/`Store.CurrentAbility`. `AbilityScore.Ability`'s
  [0,10] numeric bound is additionally enforced by a rung-5 runtime clamp inside `UpdateAbility` (Go
  has no rung-1 bounded-float type), so FR-006 closes two different sub-invariants at two different
  rungs, not one rung standing in for both — see data-model.md §1.2. `ResponseLogEntry` immutability
  (FR-003) is enforced at BOTH the Go-API layer (unexported fields, no setters — rung 1) **and** the
  SQLite layer (a
  `BEFORE UPDATE`/`BEFORE DELETE` trigger that `RAISE(ABORT, …)` — rung 5 backstop) — these are two
  DIFFERENT, separately-tested guarantees and tasks below test them as two separate tests, never one.
- §11.4.253 (idempotency under retry, DB-level durable uniqueness): the `served_question.token` →
  `response_log.serving_token UNIQUE NOT NULL` mechanism (plan.md's "Idempotency and the served-question
  problem", data-model.md §1.4/§5) is the single new piece of state this feature introduces beyond the
  three entities the source research named. A concurrent double-submit against the same token MUST be
  tested to prove exactly one `response_log` row results (the mutation named in plan.md's "Mutation-
  pairing owed" list).
- Every `[TDD]` task's "RED" step requires a pasted command + exit code/output in this file's own
  completion note when checked off — a claim of "tests exist" with no observed-to-fail evidence is a
  finding, not a pass (§11.4.5, §11.4.107, this project's own anti-bluff carrier).
- **NEEDS CLARIFICATION items carried forward from spec.md** (K-factor/logistic-divisor constants,
  downgrade threshold/magnitude, batch recalibration cadence, per-area-vs-cross-curriculum scoring,
  the zero-`easy`-items content-authoring response) are each handled per-task below with an explicit
  marker — **[CONFIGURABLE-DEFAULT]** (task implements a named `Config` field with the POC/plan's
  documented starting value, never a hardcoded literal, and the task's own code comment states the
  value is UNVALIDATED against real data) or **[BLOCKED-PENDING-OPERATOR-DECISION]** (the task cannot
  proceed past a stated point without an operator decision that is out of this feature's scope to make
  unilaterally). See "NEEDS CLARIFICATION disposition" at the end of this file for the full mapping.
- No git branch creation for this task (per the calling instruction). Commits, if any, are the
  implementer's own decision at execution time — tasks.md itself does not commit.

## Paths

All paths below are relative to `workshop/platform/backend/` unless stated otherwise. `workshop/` is
the PRIVATE submodule; this repository's own `specs/` tree is PUBLIC — findings and code excerpts
quoted here are structural/schema citations only, never chapter or transcript content (this feature's
own scope has none).

---

## Phase 1: Setup / Foundational (SQLite schema — blocks everything else)

**Purpose**: The `pkg/scoring` package skeleton and its SQLite schema (all five tables + the two
immutability triggers from data-model.md §5) must exist, opened and migrated, before any user story's
endpoint or pure function can be implemented or tested against a real store. This is the single
blocking prerequisite named in plan.md's Project Structure.

**⚠️ CRITICAL**: No User Story task below may begin until T008 (schema migration test passes against
a real SQLite file) is green.

- [ ] **T001 [P] [SUBAGENT]** Create `pkg/scoring/doc.go`: package doc comment stating what `pkg/scoring` owns
  (`ResponseLogEntry`, `AbilityScore`, `ItemDifficultyState`, `ServedQuestion` and their SQLite store),
  why it is separate from `pkg/assessment` (cite plan.md's "Package placement decision" by section
  name), and the dependency direction (`pkg/scoring` → `pkg/assessment`/`passage.PID`, never reverse).

- [ ] **T002 [P] [SUBAGENT]** Create `pkg/scoring/config.go` with the `Config` struct: `K0`, `KMin`,
  `DecayAttempts`, `LogisticDivisor`, `DowngradeStreak`, `DowngradeMagnitude`, `ItemK0`, `ItemKMin`,
  `ItemDecayResponses`, `BatchCadence`, `ServingTokenTTL` fields, plus a `DefaultConfig() Config`
  constructor. **[CONFIGURABLE-DEFAULT]**: every field gets the exact POC/plan-documented starting
  value (`K0=0.9`, `KMin=0.12`, `DecayAttempts=5`, `LogisticDivisor=1.5`, `DowngradeStreak=3`,
  `DowngradeMagnitude=1.5`, `ItemK0=0.2`, `ItemKMin=0.02`, `ItemDecayResponses=50`,
  `ServingTokenTTL=24h`, `BatchCadence=1h-or-500-responses`) — no literal appears anywhere else in
  `pkg/scoring`; every pure function and store method takes `Config` as a parameter. Each field's doc
  comment states, verbatim, whether it is POC-verified (ability-side: `K0`, `KMin`, `DecayAttempts`,
  `LogisticDivisor`, `DowngradeStreak`, `DowngradeMagnitude`) or **explicitly UNVALIDATED against real
  workshop-platform data** (item-side: `ItemK0`, `ItemKMin`, `ItemDecayResponses`, `BatchCadence`) —
  per data-model.md §3's own honesty distinction. This directly satisfies spec.md's "K-factor tuning"
  and "downgrade threshold/magnitude" and "batch cadence" NEEDS CLARIFICATION items by making all three
  overridable without a code change, per the item's own resolution instruction.

- [ ] **T003 [P] [TDD] [US: Foundational]** Write a failing test in `pkg/scoring/model_test.go`
  asserting that `ResponseSource("bogus").Valid()` returns `false` and `SourcePractice.Valid()` /
  `SourceGraded.Valid()` return `true`. Run it — expect `FAIL: undefined: ResponseSource` (module does
  not exist yet). Paste the real command + output in this task's completion note.

- [ ] **T004** Implement `pkg/scoring/model.go`: the four types exactly as data-model.md §1 specifies
  (`ResponseLogEntry`, `AbilityScore`, `ItemDifficultyState`, `ServedQuestion`, `ResponseSource` +
  `Valid()`) — **`ResponseLogEntry` and `AbilityScore` have EVERY field UNEXPORTED, with the
  read-only accessor methods data-model.md §1.1/§1.2 list as their only exported surface, and NO
  exported constructor outside `Store.RecordResponse`/`Store.CurrentAbility`** (this is the real
  §11.4.241 rung-1 closure data-model.md §1.1/§1.2 now specify, not merely a rung-2 convention: an
  unexported field genuinely cannot be set via a composite literal or field assignment from outside
  `pkg/scoring` — do not add an exported field or a convenience constructor later without re-reading
  data-model.md §1.1/§1.2's rationale first). `ItemDifficultyState` and `ServedQuestion` keep exported
  fields (data-model.md names no equivalent invariant for them requiring the same closure). Run T003's
  test — expect PASS.

- [ ] **T005 [TDD]** Write a failing test in `pkg/scoring/store_test.go` asserting `Store.Open(dir)`
  against a fresh temp directory creates `scoring.db` and that querying
  `sqlite_master` for all five expected table names (`served_question`, `response_log`,
  `ability_score`, `item_difficulty`, `recalibration_runs`) returns all five. Run it — expect
  `FAIL: undefined: Store`. Paste the real command + output.

- [ ] **T006** Implement `pkg/scoring/store.go`'s `Store` type and `Open(dir string) (*Store, error)`,
  applying the exact DDL from data-model.md §5 (all five `CREATE TABLE IF NOT EXISTS` statements, both
  indexes-per-table, and the two `response_log` triggers) via `db.Exec`, following `pkg/authstore.
  Open`'s own migration idiom (read `authstore.go` lines 42-91 first and mirror its shape:
  `sql.Open("sqlite", …)`, `db.SetMaxOpenConns(1)`, schema applied inside `Open`). Run T005 — expect
  PASS.

- [ ] **T007 [TDD] [REVIEW]** Write a failing test asserting the FR-003 storage-level immutability
  backstop fires: open a real `scoring.db` via `Store.Open`, insert one `response_log` row directly via
  SQL (bypassing any Go-level guard, to isolate what T006's triggers alone do), then attempt
  `UPDATE response_log SET correct = 1 WHERE id = ?` and separately `DELETE FROM response_log WHERE id
  = ?` against the raw `*sql.DB`, asserting **both** fail with an error whose message contains
  `"response_log is append-only"` (the trigger's own `RAISE(ABORT, …)` text from data-model.md §5).
  **This is deliberately a different test from the Go-API-level "no setter exists" check (see T010b,
  not T010 — T010 is `TestUpdateAbility`, the unrelated ability-arithmetic pure-function test; citing
  it here was a copy-paste error in an earlier revision of this file and is corrected) — this one
  proves the rung-5 SQLite backstop actually fires against a raw SQL statement that bypasses the Go
  API entirely, not merely that the Go API has no mutator method.** Run it against T006's
  schema — expect PASS immediately (the trigger already exists from T006), which is itself the
  intended RED-then-GREEN-in-one-step proof for a schema-level (not code-level) invariant: run the
  SAME test against a scratch copy of the schema with the two trigger statements commented out first,
  confirm it FAILS (the `UPDATE`/`DELETE` silently succeed), to prove the test is actually sensitive to
  the trigger's presence — this is the mutation proof plan.md's "Mutation-pairing owed" item 2
  requires. Paste both runs' real output (trigger present: PASS; trigger removed: FAIL as expected).

- [ ] **T008 [REVIEW]** **Checkpoint.** Run the full `pkg/scoring` test suite
  (`cd workshop/platform/backend && go test ./pkg/scoring/... -v`) and confirm all tests from T003-T007
  pass together against a single fresh `scoring.db`. Paste the real output. **No User Story task below
  may begin until this is green** — this is the literal "Foundational phase, blocks all user stories"
  gate the tasks-template's own Phase 2 convention names, applied here as the schema/skeleton rather
  than a separate infrastructure concern (this feature has no auth/routing/logging scaffolding of its
  own beyond this).

**Checkpoint**: `pkg/scoring`'s package skeleton, `Config`, the four types, and the full SQLite schema
(with both immutability triggers proven to actually fire, not merely declared) exist and are tested.
User Story 1 (Phase 2) may now begin.

---

## Phase 2: User Story 1 — A learner's ability score updates in real time from practice-bank answers (Priority: P1) 🎯 MVP

**Goal**: A learner can submit a practice-bank answer through a new endpoint, get one immutable
`ResponseLogEntry`, see their `AbilityScore` update synchronously, and the existing graded
`AssessmentSubmitHandler` feeds the same pipeline — closing FR-001 through FR-007, FR-014 through
FR-016 (the served-question/idempotency half) for the practice surface.

**Independent Test** (from spec.md): Submit a sequence of mixed correct/incorrect answers for one
session against one area's practice bank via the new submit endpoint; confirm each submission creates
one new immutable response-log row, the session's ability score changes in the mathematically expected
direction/magnitude after each, and the next question served is chosen near the updated estimate.

### Tests for User Story 1 (write first, observe RED, per §11.4.224)

- [ ] **T009 [P] [TDD] [SUBAGENT] [US1]** Write `pkg/scoring/elo_test.go`'s `TestKFactor`: table-driven, asserting
  `KFactor(0, cfg)`, `KFactor(1, cfg)`, `KFactor(2, cfg)` equal `0.900`, `0.759`, `0.643` to 3 decimal
  places, using `Config{K0: 0.9, KMin: 0.12, DecayAttempts: 5}` — **the exact values data-model.md §3
  states were back-solved from `sample-output-30-attempts-seed42.txt`'s own printed `K` column**. Before
  writing the assertions, actually re-run the POC per quickstart.md Part 1
  (`cd workshop && python3 docs/research/education-platform/poc/adaptive_scoring_poc.py --attempts 30
  --seed 42`) and copy the real printed `K` values for attempts 1-3 of Learner C (or whichever learner
  the trace shows at `n=0,1,2`) into the test as a code comment citing the exact re-run, rather than
  copying data-model.md's already-stated numbers uncritically — this is the §11.4.245 "oracle is
  independently executed, not merely cited" discipline applied for real, not assumed satisfied because
  data-model.md already did it once. Run the test — expect `FAIL: undefined: KFactor`. Paste the POC
  re-run output AND the Go test's real failing output.

- [ ] **T010 [P] [TDD] [SUBAGENT] [US1]** Write `pkg/scoring/elo_test.go`'s `TestUpdateAbility`: table-driven
  against the SAME POC trace's `delta` column (cold-start case: `theta=5.0`, a correct answer against
  `servedDifficulty=5.0`, `priorAttempts=0`, asserting `newTheta` matches the POC's own printed
  post-update ability to 3 decimal places) AND a clamp-boundary case (`theta=9.95`, several consecutive
  correct answers, asserting `newTheta` never exceeds `10.0` — FR-006). Run — expect
  `FAIL: undefined: UpdateAbility`. Paste output.

- [ ] **T010b [TDD] [SUBAGENT] [US1]** Write `pkg/scoring/model_test.go`'s
  `TestResponseLogEntryAndAbilityScoreHaveNoExternalConstructor` — **this is the real Go-API-layer
  "no setter/no external constructor exists" test data-model.md §1.1/§1.2 requires and T007's
  completion note points to** (T010 is a different, unrelated test — see the correction in T007's own
  note). This codebase already has the exact convention to follow:
  `pkg/search/envelope_test.go`'s `TestUpstreamTextCannotBeAssignedToASnippet` (its own §2.4 comment)
  quarantines a type by making the illegal conversion fail to compile, documents that compile-time
  guarantee as a code comment, and pairs it with a runtime check of the type's one legal accessor.
  Mirror that shape exactly, for both types: (1) a code comment stating, verbatim, that
  `scoring.ResponseLogEntry{Correct: true}` / `entry.correct = true` and
  `scoring.AbilityScore{Ability: 999}` / `score.ability = 999` each fail to compile from a package
  other than `pkg/scoring` (Go's own unexported-field rule — do **not** attempt to build an automated
  negative-compilation harness for this; none exists in this codebase and this task does not introduce
  one, matching `envelope_test.go`'s own documented-not-automated precedent); (2) a real runtime
  assertion, against a `ResponseLogEntry` and an `AbilityScore` obtained through a real
  `Store.RecordResponse` call (not a package-internal literal built solely for this test), that every
  accessor method listed in data-model.md §1.1/§1.2 (`ID()`, `Session()`, `Area()`, `Question()`,
  `At()`, `Correct()`, `ServedDifficulty()`, `AbilityBefore()`, `AbilityAfter()`, `KFactor()`,
  `DowngradeTriggered()`, `Reason()`, `Source()`, `ServingToken()` for `ResponseLogEntry`; `Session()`,
  `Area()`, `Ability()`, `AttemptCount()`, `UpdatedAt()`, `LastEntry()` for `AbilityScore`) returns
  exactly the value that call populated. Run — expect `FAIL: undefined: RecordResponse` (this test
  necessarily depends on T015's `RecordResponse` existing to obtain a real value; if T004's types exist
  but T015 does not yet, report the real compile/run error honestly rather than reordering this task).
  Paste real output; re-run and paste GREEN output once T004 and T015 are both implemented.

- [ ] **T011 [TDD] [US1]** Write `pkg/scoring/store_test.go`'s `TestRecordResponse_FirstSubmission`:
  against a fresh `Store`, manually insert one `served_question` row (simulating what `ServeNext` will
  mint, since `ServeNext` does not exist yet — this task's own test is scoped to `RecordResponse`
  alone, not the full request flow), call `Store.RecordResponse(token, correct=true, …)`, and assert:
  exactly one `response_log` row exists with the expected `ability_before`/`ability_after`/`k_factor`
  matching T010's pure-function output, `ability_score` has exactly one row for `(session, area)` with
  `attempt_count=1`, and `served_question.consumed_at` is now non-nil. Run — expect
  `FAIL: undefined: RecordResponse`. Paste output.

- [ ] **T012 [TDD] [US1] [REVIEW]** Write `pkg/scoring/store_test.go`'s
  `TestRecordResponse_ConcurrentDoubleSubmit`: against a fresh `Store` with one `served_question` row
  minted, launch two goroutines calling `Store.RecordResponse` with the **same** token concurrently
  (`sync.WaitGroup`, both started as close together as `go test -race` can arrange), and assert: after
  both return, exactly **one** `response_log` row exists for that token (`SELECT COUNT(*) FROM
  response_log WHERE serving_token = ?` = 1), both goroutines' returned `entry_id` are identical, and
  `ability_score.attempt_count` is exactly `1`, not `2`. **This is the §11.4.253 mutation-pairing proof
  plan.md's "Mutation-pairing owed" item 1 names — run this test with `go test -race -run
  TestRecordResponse_ConcurrentDoubleSubmit -count=20` (20 repetitions, since a race is not guaranteed
  to manifest on a single run) and paste the real output showing all 20 pass with `-race` finding no
  data race.** Run before T014 is implemented — expect `FAIL: undefined: RecordResponse` (same as
  T011, confirming both tests are genuinely RED before any implementation exists). Paste output.

- [ ] **T013 [P] [TDD] [US1]** Write `internal/api/questions_scoring_test.go`'s
  `TestSubmitHandler_MissingServingToken` and `TestSubmitHandler_TokenIssuedToDifferentSession`: two
  `httptest.NewRequest` cases against the not-yet-existent handler, asserting HTTP 400 with
  `error.code == "serving_token_invalid"` per contracts/practice-submit.md's documented 400 shape, and
  asserting **no** `response_log` row and **no** `ability_score` change resulted (FR-014's "MUST NOT
  default toward an outcome that benefits the learner's score"). Run — expect
  `FAIL: undefined: SubmitHandler` (or equivalent compile error). Paste output.

### Implementation for User Story 1

- [ ] **T014 [US1]** Implement `pkg/scoring/elo.go`'s `KFactor`, `ExpectedScore`, `UpdateAbility`,
  `clamp` exactly as data-model.md §3 specifies, no I/O. Run T009 and T010 — expect PASS. Run
  `go test ./pkg/scoring/... -run TestKFactor|TestUpdateAbility -v` and paste the real PASS output.

- [ ] **T015 [US1]** Implement, in `pkg/scoring/store.go`, the unexported shared helper
  `recordResponse(tx *sql.Tx, session, area, question string, correct bool, servedDifficulty float64,
  source ResponseSource, servingToken *string) (RecordResponseResult, error)` data-model.md §4
  specifies (computes `UpdateAbility` using `AttemptCount` read from the current `ability_score` row —
  or `0`/`5.0` cold start —, inserts `response_log` using `servingToken` if non-nil or a freshly minted
  `*passage.Minter` token otherwise to satisfy the `NOT NULL UNIQUE` constraint, upserts
  `ability_score`), and the exported `Store.RecordResponse(token string, correct bool, gradedAnswer …)
  (RecordResponseResult, error)` — the **practice-path** entry point: look up `served_question` by
  `token`; if `consumed_at` is already set, look up and **replay** the `response_log` row already keyed
  by that token's resulting `serving_token` rather than recomputing (§11.4.253); else validate the
  token (not expired per `Config.ServingTokenTTL`, session matches — FR-014), mark
  `served_question.consumed_at`, and call `recordResponse` with a non-nil `servingToken`, all inside
  one `*sql.Tx`. **Do not implement `Store.RecordGradedResponse` in this task — that is T023b, kept
  separate because it has a different trust contract (see data-model.md §4's "closes a real
  contradiction" note) and its own test.** Run T011 and T012 (the concurrency proof) —
  expect both PASS, with T012 run the full `-race -count=20` way. Paste real output for both.

- [ ] **T016 [US1] [TDD]** Write and then satisfy a failing test for the replay path specifically —
  `TestRecordResponse_ReplayAfterConsumed`: call `RecordResponse` once (real scoring happens), call it
  again with the exact same token, assert the second call's returned `entry_id`/`ability_after` are
  byte-identical to the first and that `response_log` still has exactly one row (not two) — this is
  distinct from T012's concurrency case (this one is sequential retries, e.g. a client that resent
  after a dropped response). Run RED first (expect it to fail if `RecordResponse`'s replay branch has a
  bug, or pass immediately if T015 already implemented it correctly — report honestly which happened,
  do not claim RED if the implementation already satisfies it). Paste real output.

- [ ] **T017 [US1]** Implement `Store.ServeNext(session, area string, cfg Config) (ServeResult, error)`
  in `pkg/scoring/store.go` per data-model.md §4's three-branch selection logic (cold start → downgrade
  override → normal adaptive pick) and §2's **two-tier** cold-start selection: **tier 1** — query
  `item_difficulty WHERE area_id = ? ORDER BY difficulty_estimate ASC LIMIT 1`; **tier 2** — only when
  tier 1 returns zero rows (a real, checked condition, e.g. `sql.ErrNoRows`), fall back to a query
  against the authored `assessment.Question.Difficulty` label directly (never against
  `item_difficulty`) over the union of the practice bank and graded catalog, per §2's label-mapping
  table. **This two-tier shape is not optional/cosmetic — a single unconditional query against
  `item_difficulty` is the cold-start chicken-and-egg bug data-model.md §2 documents and T018 tests
  for: on a genuinely never-served area, `item_difficulty` has zero rows and tier 1 alone returns
  nothing to select.** Whichever tier selects an item, mint one `served_question` row (data-model.md
  §1.4) via `INSERT`, and `INSERT OR IGNORE`-seed `item_difficulty` for the selected item per §2's
  label mapping (tier 2's own selection is exactly what performs this seeding — confirm this is wired
  so a second `ServeNext` call against the same area finds tier 1 non-empty; see T018's second case).
  This task requires reading `pkg/assessment/store.go` (the practice-bank loader) and
  `submodules/curriculum-kit`'s graded-catalog loader (cite the exact function found) to know how to
  enumerate both item populations — **do not assume a function signature; read the actual loader
  first and record what was found in this task's completion note**. **[CONFIGURABLE-DEFAULT]**: the
  downgrade-override branch uses `Config.DowngradeStreak`/`Config.DowngradeMagnitude`, never a literal
  `3`/`1.5` inline.

- [ ] **T018 [P] [TDD] [US1]** Write failing tests for `ServeNext`'s cold-start selection, covering
  **both** tiers data-model.md §2 now specifies — a single test exercising only the tie-break case
  would leave the chicken-and-egg bug (Fix 1) untested:
  (a) **Tier-1 selection / tie-break (the original case, now made explicit about which tier it
  exercises)**: against a `Store` seeded with only `medium`/`hard`-labeled practice items (no `easy`)
  and at least one uncalibrated graded-catalog item — with `item_difficulty` for this area ALREADY
  non-empty (both the graded-catalog item and at least one `medium` item already seeded into
  `item_difficulty`, so this exercises tier 1's `item_difficulty` query finding a row, never tier 2's
  authored-label fallback) — assert the cold-start pick's `served_difficulty` is the graded-catalog
  item's `5.0` (midpoint) seed, **not** a `medium` item's `5.0` from the practice bank picked
  arbitrarily by tie — or, if both sides tie at `5.0`, assert the selection is deterministic and
  documented (state which tiebreak rule was chosen and why in the completion note, since data-model.md
  does not specify one and this task must not invent a silent one).
  (b) **Tier-2 / genuinely empty `item_difficulty` table (the Fix 1 case — do not skip this)**: against
  a **freshly opened `Store`** whose `item_difficulty` table has **zero rows for any area** (not just
  missing `easy` labels — the table itself is empty, the literal scenario User Story 1's first
  Acceptance Scenario and data-model.md §2 name), call `ServeNext` for an area seeded with
  `medium`/`hard` practice items and at least one graded-catalog item, and assert: a real question is
  returned (not an error, not an empty/zero-value response) via the tier-2 authored-label fallback,
  its `served_difficulty` matches the lowest authored-label seed for that area, and a **second**
  `ServeNext` call for the **same area** (from any session) now finds `item_difficulty` non-empty for
  that area and takes the tier-1 path — assert this explicitly (e.g. by asserting the second call's
  internal selection came from `item_difficulty`, not by re-deriving the authored label) rather than
  merely asserting the second call also succeeds, which would not distinguish "tier 1 worked" from
  "tier 2 worked twice." This is the literal chicken-and-egg regression test: run it against a version
  of `ServeNext` with tier 2 removed (a single unconditional `item_difficulty` query) first and confirm
  it FAILS (error or empty result, not a served question) — paste that RED output — before confirming
  it PASSES against the real two-tier implementation.
  Run both — expect `FAIL: undefined: ServeNext`. Then implement/adjust T017 until both pass. Paste all
  RED and GREEN output (including the tier-2-removed mutation run for case (b)).

- [ ] **T019 [US1]** Implement `internal/api/questions_scoring.go`'s `SubmitHandler` (`POST
  /api/areas/{area}/questions/{question}/submit`) per contracts/practice-submit.md: decode the
  `serving_token`/`chosen`/`text` body (reusing `decodeSubmitBody`'s existing discipline from
  `internal/api/lessons.go` line 717 — read it first), grade server-side against the question's answer
  key (mirroring the existing grading path for `mcq`/`short`, or `ckit`'s where the question is also
  graded content — read `internal/api/lessons.go`'s existing grading call before writing a second one),
  call `Store.RecordResponse`, and render the 200/400 response shapes exactly as
  contracts/practice-submit.md documents (including the `"replay": true` field on a replayed call, and
  the embedded `next` object from a follow-up internal `ServeNext` call). Run T013 — expect PASS. Paste
  real output.

- [ ] **T020 [P] [US1]** Implement `internal/api/questions_scoring.go`'s `NextHandler` (`GET
  /api/areas/{area}/questions/next`) per contracts/practice-next.md: session-scoped via the existing
  `sessionOf` helper (`internal/api/lessons.go` line 311), calls `Store.ServeNext`, renders using the
  **existing** `questionWire` function (`internal/api/questions.go` line 290) for the `question` object
  so field names match `GET /api/areas/{area}/questions` exactly — never the answer key — plus the
  `serving`/`selection` objects. Implements the 404 (no eligible item) and 503 (bank/registry
  unreadable) branches per the contract, mirroring `writeUnavailable`'s existing shape
  (`internal/api/chapters.go` line 1135).

- [ ] **T021 [P] [TDD] [US1]** Write a failing contract-level test asserting `NextHandler`'s 200
  response never includes `answer`, `correct_index`, or `explanation` fields anywhere in the `question`
  object (the answer-withholding discipline contracts/practice-next.md names) — serialize the real
  response and assert those JSON keys are absent, not merely null. Run — expect FAIL against a stub, or
  confirm PASS if T020 already got this right by construction (report honestly which). Implement/fix
  until PASS. Paste real output.

- [ ] **T022 [US1]** Wire the two new routes into `cmd/workshop-server/main.go`: open `scoring.Store`
  alongside the existing `authstore.Open`/`api.NewProgressStore` calls (same data directory), register
  `GET /api/areas/{area}/questions/next` and `POST /api/areas/{area}/questions/{question}/submit`
  beside the existing questions/assessment route block (plan.md cites lines ~1444-1452 — re-read the
  current file to confirm the exact insertion point before editing, since line numbers drift). Build
  (`go build ./...`) and paste the real build output (expect a clean build, zero errors).

- [ ] **T023a [TDD] [US1]** Write a failing test, `TestRecordGradedResponse_NoTokenRequired`: call
  `Store.RecordGradedResponse(session, area, question, correct, gradedDifficulty, …)` **directly**, with
  no `served_question` row minted for this question at all (proving it genuinely requires no serving
  token, unlike `RecordResponse`), and assert: one `response_log` row is inserted with `source =
  'graded'` and a non-empty, internally-minted `serving_token`; `ability_score` is updated via the same
  `UpdateAbility` math T010's oracle values already pin down; and calling it twice with the same
  arguments produces **two** separate `response_log` rows (not a replay) — correctly distinct from
  `RecordResponse`'s token-keyed replay behavior, because there is no token to key a replay against;
  a graded resubmission is this path's caller's own concern, not this function's. Run — expect
  `FAIL: undefined: RecordGradedResponse`. Paste output.

- [ ] **T023b [US1]** Implement `Store.RecordGradedResponse(session, area, question string, correct
  bool, gradedDifficulty float64, …) (RecordResponseResult, error)` in `pkg/scoring/store.go`, per
  data-model.md §4's "closes a real contradiction" note: calls the SAME unexported `recordResponse`
  helper T015 implemented, with `servingToken = nil` (the helper mints a fresh internal token to
  satisfy `response_log.serving_token`'s `NOT NULL UNIQUE` constraint) and no `served_question` lookup
  at all — this is the entry point that makes "one shared scoring pipeline" true at the algorithm
  level for two entry points with genuinely different call signatures and trust contexts. Run T023a —
  expect PASS. Paste real output.

- [ ] **T023 [US1] [REVIEW]** Wire `AssessmentSubmitHandler` (`internal/api/lessons.go` line ~690) into
  the same scoring pipeline (User Story 1 Acceptance Scenario 4, FR-002's "from the new practice-bank
  submit endpoint and from the existing graded end-of-area assessment submit endpoint alike"): after
  `ckit.Submit` succeeds, for each `ckit.Result`'s per-question `QuestionOutcome`
  (`submodules/curriculum-kit/pkg/curriculum/assess.go` — read its real shape first), call
  `Store.RecordGradedResponse` with `Source: SourceGraded` — **not** `Store.RecordResponse`, which
  requires a serving token this path does not have (see T023a/T023b and data-model.md §4) — and **no
  serving-token requirement** — per plan.md's explicit reasoning that the graded path's own lesson-gate
  already proves entitlement and a second served-question check here would be the "second gate"
  `AssessmentSubmitHandler`'s own comments (lines ~797-800) warn against. Read those comments before
  writing this task's code, and quote the exact warning text found in this task's completion note as
  confirmation the reasoning still holds against the current code, not merely against plan.md's
  citation of it.

- [ ] **T024 [TDD] [US1] [REVIEW]** Write a failing integration test asserting that submitting a graded
  end-of-area assessment (via the EXISTING `AssessmentSubmitHandler` test harness/fixtures — reuse
  them, do not build a new fixture set) results in `response_log` rows with `source = 'graded'` for
  each per-question outcome, and that those rows are visible through the SAME `Store.CurrentAbility`
  read the practice path uses — i.e., **one shared pipeline, not two disconnected histories**
  (spec.md's Edge Case "Graded assessment and open practice interacting on the same question").
  **Additionally assert convergence at the algorithm level, not only at the read-visibility level**:
  construct one response through `Store.RecordResponse` (practice path, real token) and one through
  `Store.RecordGradedResponse` (graded path, no token) with IDENTICAL `(correct, servedDifficulty,
  priorAttempts)` inputs, and assert both produce the SAME `ability_after`/`k_factor` — proving the
  two entry points genuinely share `recordResponse`'s update logic rather than merely writing to the
  same table with independently-reimplemented math. Run RED first, then implement T023/T023b until
  GREEN. Paste both outputs.

- [ ] **T025 [US1] [REVIEW]** **Checkpoint.** Run `go test ./pkg/scoring/... ./internal/api/... -run
  'Scoring|Submit|Next|RecordResponse' -v` and paste the full real output. Then run quickstart.md
  §2.1-§2.4 for real against a locally built `workshop-server` (or the running
  `workshop-curriculum_platform_1` container, port-discovered — never hardcode 8087, per this project's
  own Environment Adaptability discipline already named in plan.md's Constitution Check) and paste the
  real `curl`/`jq` output for each step, including the concurrent-retry case (§2.4) showing identical
  `entry_id` and `attempt_count` incremented by exactly 1.

**Checkpoint**: User Story 1 is independently complete and testable — a learner can submit practice
answers, get one immutable log entry per submission, see their score update synchronously with no
staleness, and the graded assessment path feeds the same pipeline. This is a legitimate MVP point.

---

## Phase 3: User Story 2 — A struggling learner is automatically routed to easier content (Priority: P2)

**Goal**: After 3 genuinely consecutive wrong answers in an area, the next served question is
measurably easier than the normal adaptive pick, the triggering entry records why, a correct answer
resumes normal selection, and `GET /api/progress` exposes the current `AbilityScore` per area
(FR-011 through FR-013).

**Depends on**: Phase 2 (User Story 1) — the downgrade trigger is evaluated against response history
Phase 2's submit endpoint produces, and `ServeNext`'s downgrade branch (stubbed conceptually in T017,
completed for real here) needs `RecordResponse` to already exist.

**Independent Test** (from spec.md): Submit three consecutive incorrect answers for one learner in one
area; confirm the fourth served question is measurably easier than the normal nearest-to-ability pick,
the triggering entry carries `DowngradeTriggered` + a reason string, and a subsequent correct answer
resumes normal selection.

### Tests for User Story 2

- [ ] **T026 [P] [TDD] [SUBAGENT] [US2]** Write `pkg/scoring/elo_test.go`'s `TestDowngradeTriggered`: table-driven
  over spec.md's own edge case exactly — `[wrong, wrong, wrong]` (most-recent-first) → `true`;
  `[wrong, wrong, correct, wrong]`'s most-recent-3 slice `[wrong, correct, wrong]` → `false` (the
  "interrupted streak" edge case: wrong-wrong-correct-wrong has NOT met a 3-consecutive trigger,
  spec.md's own words); fewer than `DowngradeStreak` entries → `false`. Run — expect
  `FAIL: undefined: DowngradeTriggered`. Paste output.

- [ ] **T027 [P] [TDD] [SUBAGENT] [US2]** Write a failing test asserting `DowngradeReasonTemplate`, rendered with
  real values, produces a **non-empty** string naming the trigger condition (FR-011) and matches the
  POC's own exact wording from data-model.md §3's `DowngradeReasonTemplate` constant — assert the
  rendered string is byte-identical to the POC trace's own printed downgrade-reason line for a matching
  case (re-run the POC per quickstart.md, locate a downgrade event in its output — the sample trace
  shows Learner B with "downgrade events: 5" — and diff the wording). Run — expect FAIL. Implement
  `DowngradeReasonTemplate` usage (likely already present from data-model.md's literal constant — if
  T014 already added the constant, this task is confirming it renders correctly with real data, not
  adding new code; report which). Paste both POC excerpt and Go test output.

- [ ] **T028 [TDD] [US2] [REVIEW]** Write a failing integration test,
  `TestServeNext_DowngradeAfterThreeWrong`: seed a session with three consecutive incorrect
  `response_log` entries in one area (via three real `RecordResponse` calls through `ServeNext`+submit,
  not a raw SQL insert, so the test exercises the real path), call `ServeNext` a fourth time, and
  assert: `selection.rule == "downgrade"`, the served item's `difficulty_estimate` is measurably below
  what the normal nearest-to-`AbilityScore.Ability` pick would have returned (compute and assert the
  actual delta, not just "is lower"), and the resulting `served_question`/eventual `response_log` entry
  (once submitted) carries `DowngradeTriggered = true` with the T027 reason string. Run — expect FAIL
  (the downgrade branch in `ServeNext` from T017 was written against data-model.md's description but
  not yet exercised end-to-end with the real trigger function). Paste RED output.

- [ ] **T029 [TDD] [US2]** Write a failing test, `TestServeNext_DowngradeResetsAfterCorrect`: continuing
  from T028's seeded state, submit a correct answer to the downgrade-served question, then call
  `ServeNext` again and assert `selection.rule != "downgrade"` (FR-012 — a downgrade is a temporary
  routing change, not a persistent ceiling). Run — expect FAIL against the current `ServeNext`. Paste
  output.

### Implementation for User Story 2

- [ ] **T030 [US2]** Implement `elo.go`'s `DowngradeTriggered` and the `DowngradeReasonTemplate`
  rendering helper exactly as data-model.md §3 specifies (if not already fully wired by T014/T027).
  Run T026 and T027 — expect PASS. Paste output.

- [ ] **T031 [US2]** Complete `ServeNext`'s downgrade branch in `pkg/scoring/store.go`: read the
  session's last `Config.DowngradeStreak` `response_log` rows for the area (most-recent-first), call
  `DowngradeTriggered`, and when true select the item nearest
  `(currentAbility - Config.DowngradeMagnitude)` rather than `currentAbility` directly, per
  contracts/practice-next.md's documented selection logic. Run T028 and T029 — expect both PASS. Paste
  real output.

- [ ] **T032 [US2]** Implement `pkg/scoring/store.go`'s read helper `Store.AbilitySummaries(session
  string) (map[passage.PID]AbilitySummary, error)` returning, per area, the shape
  contracts/progress-extension.md's `ability_score` object needs (`ability`, `attempt_count`,
  `updated_at`, `last_downgrade_reason` — `nil` when the most recent entry for that area was not a
  downgrade).

- [ ] **T033 [P] [TDD] [US2]** Write a failing test for `internal/api/progress.go`'s extension:
  `TestProgressHandler_IncludesAbilityScore` — construct a `ProgressHandler` with a real
  `AbilityScoreSource` closure backed by a seeded `Store`, request `GET /api/progress`, and assert the
  response JSON's `ability_score` object matches contracts/progress-extension.md's documented shape
  exactly, field for field. Run — expect FAIL (`AbilityScoreSource` parameter does not exist on
  `ProgressHandler` yet). Paste output.

- [ ] **T034 [US2]** Modify `internal/api/progress.go`'s `ProgressHandler` to accept a new
  `AbilityScoreSource func(session string) (map[string]AbilityScoreSummary, error)` closure parameter,
  mirroring the **existing** `LessonCompletionSource` pattern byte-for-byte in shape (read lines
  277-299 first): `nil` is legitimate and simply omits the field (never a fabricated zero); a source
  failure does not fault the whole request. Extend the existing 404 condition
  (`len(positions) == 0 && len(lessonCompletion) == 0`, line ~357) to
  `&& len(abilityScore) == 0`, per contracts/progress-extension.md's documented rule. Run T033 —
  expect PASS. Paste output.

- [ ] **T035 [US2]** Wire the `AbilityScoreSource` closure (backed by T032's `Store.AbilitySummaries`)
  into `ProgressHandler`'s construction call in `cmd/workshop-server/main.go`, alongside the existing
  `LessonCompletionSource` wiring. Build and paste real output.

- [ ] **T036 [US2] [REVIEW]** **Checkpoint.** Run quickstart.md §2.5 (the downgrade walkthrough) for
  real: submit three consecutive wrong answers, confirm the 4th `GET …/next` call shows
  `selection.rule == "downgrade"` with a measurably lower `served_difficulty` than the 3rd call's
  ability would predict, then submit a correct answer and confirm the 5th call resumes
  `selection.rule == "adaptive"`. Also `curl` `GET /api/progress` and confirm `last_downgrade_reason`
  is populated for the downgrade entry and `null` afterward. Paste all real command output.

**Checkpoint**: User Stories 1 AND 2 both work independently. A struggling learner is routed to easier
content with an explicit, logged reason, and `GET /api/progress` is the one surface `014-gamification-
design-system` needs to read.

---

## Phase 4: User Story 3 — Item difficulty is crowd-calibrated from real response data (Priority: P3)

**Goal**: A periodic batch process recalibrates `ItemDifficultyState.DifficultyEstimate` from
accumulated `response_log` volume, with an update rate that shrinks as an item's own response count
grows, entirely off the synchronous request path (FR-008, FR-010).

**Depends on**: Phase 2 (User Story 1) for `response_log` data to recalibrate against. Independent of
Phase 3 (User Story 2) — no shared file, no shared behavior; genuinely parallel-dispatchable against
Phase 3 once Phase 2 is done, per the spec's own stated priority ordering (P3 is explicitly "does not
require Stories 1-2 to be *modified*," only to have already produced data).

**Independent Test** (from spec.md): Accumulate a batch of response-log entries against one question
(mixing outcomes from learners whose ability estimates bracket the question's seeded difficulty); run
the batch recalibration process; confirm `DifficultyEstimate` moves in the direction the aggregate
response pattern implies, and that live item selection reflects the updated value.

### Tests for User Story 3

- [ ] **T037 [P] [TDD] [SUBAGENT] [US3]** Write a failing test, `TestRecalibrateBatch_MovesTowardAggregatePattern`:
  seed `response_log` with ~20 responses against one question seeded at `difficulty_seed=5.0`, where
  learners with ability estimates well above 5.0 answered mostly correctly (implying the item is
  actually easier than seeded), call `Store.RecalibrateBatch(ctx)`, and assert
  `item_difficulty.difficulty_estimate` for that question has moved **down** from `5.0` — the exact
  directional assertion spec.md's Acceptance Scenario 1 names ("down if learners generally answered it
  correctly more often than their ability would predict"). **This directional assertion is,
  load-bearingly, the RED test that catches the item-side sign-convention bug data-model.md §3 names:
  a naive reuse of `UpdateAbility(theta=itemDifficulty, servedDifficulty=learnerAbility, correct=<the
  raw, un-inverted flag>)` moves the estimate UP for exactly this "learners mostly correct" scenario —
  the opposite of what this test asserts — so this test fails against that naive implementation and
  passes only once `RecalibrateBatch` inverts correctness (`correct=!correct`) per data-model.md §3's
  corrected formula. Do not weaken this to a "moved by some amount" assertion — the directionality is
  the entire point.** Run — expect `FAIL: undefined: RecalibrateBatch`. Paste output.

- [ ] **T038 [P] [TDD] [SUBAGENT] [US3]** Write a failing test, `TestRecalibrateBatch_UpdateShrinksWithVolume`
  (SC-007): recalibrate one question with a small response batch (e.g. 5 new responses) and a second
  question with a large accumulated `response_count` (e.g. 200 prior responses) against a
  comparably-sized new batch, and assert the SECOND question's `difficulty_estimate` moves by a
  strictly smaller absolute amount than the first's, for the same aggregate response pattern — the
  literal "update step measurably smaller... for a comparably-sized batch" SC-007 requires. Run —
  expect FAIL. Paste output.

- [ ] **T039 [TDD] [US3]** Write a failing test, `TestRecalibrateBatch_DoesNotBlockConcurrentSubmit`:
  start a long-running (or artificially delayed, via a test hook) `RecalibrateBatch` call in one
  goroutine, and concurrently call `Store.RecordResponse` in another against a **different** question,
  asserting the submit call's own latency/success is unaffected (no shared lock contention) — the
  literal SC-003's Acceptance Scenario 3 requirement ("that submission's own latency and correctness
  are unaffected by whether a batch recalibration is concurrently running"). Run — expect FAIL or, if
  SQLite's own `SetMaxOpenConns(1)` serializes this at the connection-pool level rather than blocking
  indefinitely, assert the submit call still completes within a stated bound (document the actual
  concurrency model found — SQLite's single-writer nature may make "fully unblocked" materially
  different from "bounded-wait" and this task's completion note must say honestly which was measured,
  not assume the more favorable reading). Paste real output.

### Implementation for User Story 3

- [ ] **T040 [US3]** Implement `Store.RecalibrateBatch(ctx context.Context) (RecalibrateSummary,
  error)` in `pkg/scoring/store.go` per data-model.md §4: read `response_log` rows newer than
  `recalibration_runs`'s own last-run watermark, fold each question's responses through the item-side
  `UpdateAbility`/`KFactor` shape (using `Config.ItemK0`/`ItemKMin`/`ItemDecayResponses` —
  **[CONFIGURABLE-DEFAULT]**, never a literal) — **calling `UpdateAbility` with `theta` and
  `servedDifficulty` SWAPPED (`theta=itemDifficulty`, `servedDifficulty=learnerAbility`) AND the
  response's own `correct` flag INVERTED (`correct=!correct`), exactly as data-model.md §3's
  "Item-difficulty update" section specifies and derives — do NOT pass the response's `correct` flag
  straight through; that moves the estimate in the wrong direction (verified algebraically in
  data-model.md §3 via the logistic identity `f(x)+f(-x)=1`, and caught by T037's directional
  assertion if gotten wrong)** —, `INSERT OR IGNORE`-seed any never-before-seen question
  into `item_difficulty` per §2's label mapping first, upsert `item_difficulty`, and record one
  `recalibration_runs` row. Run T037, T038 — expect both PASS. Paste real output.

- [ ] **T041 [US3]** Confirm (or, if needed, adjust) that `RecalibrateBatch`'s SQL uses no lock or
  table scope that would contend with `RecordResponse`'s own transaction beyond what SQLite's
  single-writer model already implies. Run T039 — expect PASS or the documented bounded-wait result.
  Paste real output and the honest concurrency-model finding from T039's completion note, cross-
  referenced here.

- [ ] **T042 [US3] [CONFIGURABLE-DEFAULT]** Wire a ticker inside `cmd/workshop-server/main.go` that
  calls `Store.RecalibrateBatch` on `Config.BatchCadence` (the proposed "hourly, or after N new
  responses, whichever is sooner" default from data-model.md §4 — **this specific cadence is spec.md's
  own NEEDS CLARIFICATION item and is implemented here as a configurable default, not a resolved
  answer**; the ticker reads `Config.BatchCadence` from the same `Config` struct T002 defined, so an
  operator can retune it without a code change). Build and paste real output.

- [ ] **T043 [P] [SUBAGENT] [US3]** Implement the seeding-on-first-sight fallback (`INSERT OR IGNORE`) so that a
  question encountered by `ServeNext` (T017) before any batch run has ever touched it is seeded per §2's
  label-mapping table (`easy→2.5`, `medium→5.0`, `hard→7.5`, no-label→`5.0` uncalibrated) rather than
  left with no `item_difficulty` row at all — cross-check this is already correctly wired from T017; if
  not, complete it here and cite which file/line changed.

- [ ] **T044 [US3] [REVIEW]** **Checkpoint.** Run `go test ./pkg/scoring/... -run Recalibrate -v` and
  paste full real output. Confirm via a real `sqlite3 scoring.db` query (or an equivalent Go one-off)
  that `item_difficulty` rows exist for every practice-bank question after one real `RecalibrateBatch`
  run against a populated `response_log`, and paste that query's real output.

**Checkpoint**: All three user stories are independently functional. Item difficulty self-corrects from
real response volume on a batch cadence, without ever touching the synchronous submit path's latency.

---

## Phase 5: Polish & Cross-Cutting

**Purpose**: Close the remaining owed items plan.md's Constitution Check named explicitly (not
silently dropped), and the feature's own acceptance-check-against-captured-data requirement (item 5 of
the calling instruction).

- [ ] **T045 [TDD] [REVIEW]** **The POC-convergence acceptance check (SC-003), against the REAL
  implementation, not unit tests.** Write and run an end-to-end simulation harness (Go test or a small
  script driving the real HTTP endpoints against a real `workshop-server`) that replays the same three
  simulated-learner profiles the POC demonstrates (Learner A: strong, true ability 8.5; Learner B:
  struggling, true ability 2.5; Learner C: average, true ability 5.0), using the SAME seed/attempt count
  (30 attempts, seed 42) and the SAME stochastic answer-generation rule the POC uses (read
  `adaptive_scoring_poc.py`'s own answer-simulation function and mirror it exactly — do not
  approximate it), submitting through the real `POST …/submit` endpoint for each simulated attempt.
  Assert the real implementation's final `AbilityScore.Ability` for each simulated learner lands within
  the POC's own captured error bounds (SC-003: "0.17-0.43 points of their hidden true ability over 30
  attempts") — **this is an acceptance check against captured real numbers, not a fresh unit test with
  invented tolerances.** Paste the real run's final ability/error/downgrade-count table (same shape as
  quickstart.md Part 1's own summary table) alongside the POC's original captured table for a direct,
  eyeball-verifiable comparison. If the real implementation's numbers diverge meaningfully from the
  POC's (e.g. because the real answer-grading path, real cold-start item selection against the actual
  content bank, or real clamping behavior differs subtly from the POC's simplified simulation), report
  the divergence honestly rather than adjusting the test's tolerance to hide it — a divergence here is a
  finding about whether the real implementation matches the designed algorithm, which is exactly what
  this check exists to surface.

- [ ] **T046 [P] [REVIEW]** Run `go test ./pkg/scoring/... ./internal/api/... -cover` for the full
  feature and paste the real coverage percentage, per plan.md's §11.4.224 "≥85% code-coverage floor"
  commitment (named at planning time, executed here). If below 85%, add the missing test(s) before
  checking this off, and paste the before/after coverage figures.

- [ ] **T047 [P] [SUBAGENT]** Update `CONTINUATION.md` (this repository's own §12.10-conformant resumption
  document) recording this feature's completion state, per plan.md's Constitution Check
  "Comprehensive Documentation" row, which explicitly names this as owed at implementation time rather
  than planning time.

- [ ] **T048 [REVIEW]** Run the full `quickstart.md` Part 1 and Part 2 (§2.1-§2.5) one final time
  end-to-end against the completed feature and paste all real output, confirming no step in the
  document is aspirational by the time this task is checked off.

- [ ] **T049** **[BLOCKED-PENDING-OPERATOR-DECISION]** Record, in this task's own completion note (no
  code change), the disposition of spec.md's two remaining open clarifications this feature's code
  cannot itself resolve: (a) **per-area vs. cross-curriculum ability score** — this feature ships the
  per-area shape (data-model.md §1.2's Phase 1 decision), and the task here is to flag to the operator,
  in writing, that `014-gamification-design-system` UI work should not begin locking in a score display
  shape until this is explicitly decided, per spec.md's own instruction; (b) **content-authoring
  response to the zero-`easy`-items gap** — this feature's code-level fallback (FR-009, implemented in
  T017/T018) is sufficient for this feature's own scope, but whether curriculum authors should
  retroactively label existing items `easy` or author new ones is explicitly out of this feature's
  ability to decide or implement. Neither blocks this feature's own closure; both block a DIFFERENT
  future feature's start, and this task exists so neither is silently forgotten.

**Checkpoint**: Feature complete. `tasks.md`'s own NEEDS CLARIFICATION disposition table below is the
single place a future reader checks before building on top of this feature's open questions.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Foundational)**: No dependency — BLOCKS all user stories (T008 is the hard gate).
- **Phase 2 (US1, P1)**: Depends on Phase 1. No dependency on Phase 3 or 4.
- **Phase 3 (US2, P2)**: Depends on Phase 1 AND Phase 2 (the downgrade trigger reads response history
  Phase 2's submit endpoint produces; `GET /api/progress`'s extension is additive to the existing route
  regardless of US1/US3).
- **Phase 4 (US3, P3)**: Depends on Phase 1 AND Phase 2 (recalibration reads `response_log` data Phase
  2 produces). **Independent of Phase 3** — no shared file, no shared runtime state — genuinely
  parallel-dispatchable against Phase 3 once Phase 2's checkpoint (T025) is green.
- **Phase 5 (Polish)**: Depends on all of Phases 2-4 being complete (T045's simulation exercises US1's
  submit path plus whatever of US2's downgrade behavior the simulated learners happen to trigger).

### Within Each Phase

- Tests (marked `[TDD]`) are written and observed to FAIL before their paired implementation task.
- Pure functions (`elo.go`) before the store methods that call them.
- Store methods before the HTTP handlers that call them.
- Handlers before the `main.go` wiring that registers them.
- Each phase's own `[REVIEW]`-marked checkpoint task closes it before the next phase's work is treated
  as safe to build on.

### File-overlap note for parallel dispatch

- T017 (`ServeNext`, US1) and T031 (`ServeNext`'s downgrade branch, US2) touch the **same function** in
  the **same file** (`pkg/scoring/store.go`) — **sequence T017 fully through T025 (US1's checkpoint)
  before starting T031**, or dispatch both to the same subagent as a sequential pair rather than two
  parallel subagents, matching this repository's own established convention (spec 009's tasks.md names
  the identical rule for its own single-file overlap).
- T032/T034/T035 (US2's `GET /api/progress` extension) and Phase 4's `pkg/scoring/store.go` additions
  (T040-T043) both touch `pkg/scoring/store.go` but add **independent methods**
  (`AbilitySummaries`/`RecalibrateBatch`) with no shared code path — these MAY be dispatched in
  parallel to different subagents once Phase 2's checkpoint is green, but whichever lands second should
  re-run `go build ./...` before its own checkpoint task, since both are editing the same file
  concurrently in the working tree.
- Every `[P]`-marked task elsewhere touches a file no sibling `[P]` task in the same phase touches.

---

## NEEDS CLARIFICATION disposition

Every item spec.md's "Clarifications Needed" section carries forward, and exactly how this task list
handles each (per the calling instruction: mark the dependent task blocked-pending-operator-decision,
or implement a configurable/overridable default with the open question noted in a code comment — never
silently hardcode an unvalidated number as settled):

| Spec.md clarification | Disposition | Where |
|---|---|---|
| Per-area ability score vs. single cross-curriculum number | **Implemented as per-area** (data-model.md §1.2's own Phase 1 decision, carried into this task list unchanged) — this is a real Phase 1 implementation choice, not a resolution of the open question. **[BLOCKED-PENDING-OPERATOR-DECISION]** for anything building a UI on top of it. | Data-model.md §1.2 (inherited); flagged for the operator in T049(a). |
| K-factor / logistic-divisor tuning constants | **[CONFIGURABLE-DEFAULT]** — every constant is a named `Config` field with the POC's documented value, doc-commented as POC-verified, never hardcoded in `elo.go`. | T002, T014. |
| Downgrade trigger threshold (3-in-a-row) and magnitude (1.5 points) | **[CONFIGURABLE-DEFAULT]** — `Config.DowngradeStreak`/`Config.DowngradeMagnitude`, same discipline as above. | T002, T030-T031. |
| Item-difficulty batch recalibration cadence | **[CONFIGURABLE-DEFAULT]** — `Config.BatchCadence`, explicitly doc-commented as **NOT** POC-verified (the POC never recalibrates), unlike the ability-side constants. | T002, T042. |
| Content-authoring response to the zero-`easy`-items gap | **Out of this feature's implementation scope by spec.md's own wording** ("a content/operator decision the source research names but does not resolve"). This feature implements only the required code-level fallback (FR-009). **[BLOCKED-PENDING-OPERATOR-DECISION]** for the content-authoring question itself. | FR-009's code fallback: T017-T018. Operator flag: T049(b). |
