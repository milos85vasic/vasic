# Implementation Plan: Adaptive Assessment and Real-Time Scoring

**Branch**: `013-adaptive-assessment-scoring` | **Date**: 2026-09-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/013-adaptive-assessment-scoring/spec.md`, formalizing
the research and proof-of-concept at
`workshop/docs/research/education-platform/adaptive-assessment-and-scoring.md` (cited below by
section, e.g. "research §3.2") and its POC script
`workshop/docs/research/education-platform/poc/adaptive_scoring_poc.py` with captured output at
`workshop/docs/research/education-platform/poc/sample-output-30-attempts-seed42.txt`. `workshop/`
is PRIVATE and consumed here read-only, by path and schema citation only, per this repository's
content-boundary rule — no chapter/transcript content is quoted anywhere below.

## Summary

The open practice question bank currently has no submit endpoint at all — a learner answering a
practice question today produces zero server-side record (research §2.2). This feature adds: (1) a
new session-scoped submit endpoint that grades a practice-bank answer, writes it to an append-only
`ResponseLogEntry` log, and updates a fast-read `AbilityScore` synchronously using an Elo-style
update (research §3.2); (2) a new session-scoped "next question" endpoint that serves the item
nearest the learner's current ability, overridden to a measurably easier item after a run of 3
consecutive wrong answers (the downgrade mechanism, research §3.3); (3) wiring the existing
`AssessmentSubmitHandler` (graded end-of-area assessment) into the *same* scoring pipeline so the
platform has one shared scoring path, not two (User Story 1 Acceptance Scenario 4); (4) extending
`GET /api/progress` to also report `ability_score` per area; and (5) a periodic batch process that
crowd-calibrates each question's `ItemDifficultyState` from accumulated response volume (User
Story 3), kept off the synchronous request path for the load-bearing reason research §3.4 states
(global per-item state must not contend on every single learner's own scoring request).

The scoring algorithm itself — the Elo update law, the K-factor decay schedule, the downgrade
trigger and magnitude — is not invented here; it is the exact formula research §3.2-§3.3 specifies
and the POC at `workshop/docs/research/education-platform/poc/adaptive_scoring_poc.py` already
demonstrates against three simulated learners with captured, reproducible output (research §4).
This plan's job is to turn that demonstrated design into real storage, a real HTTP surface, and a
real wiring decision inside `platform/backend` — and to make the two mechanical decisions the
research document explicitly left open for this planning step: which existing Go package should
own the new types (§"Project Structure" below), and how a submission proves it was actually served
the question it claims to answer (§"Idempotency and the served-question problem" below).

## Technical Context

**Language/Version**: Go 1.26.2 (`workshop/platform/backend/go.mod` line 3) — no version change;
the new code lives inside the existing `platform/backend` module.

**Primary Dependencies**: `modernc.org/sqlite` v1.59.0 (`workshop/platform/backend/go.mod` line 48,
already vendored, pure-Go, no cgo — the same driver `pkg/authstore`, `pkg/index`, `pkg/search` and
`pkg/crossref` already use, imported as `_ "modernc.org/sqlite"` with `sql.Open("sqlite", …)`, see
`workshop/platform/backend/pkg/authstore/authstore.go` lines 16 and 88). `github.com/vasic-digital/
passage/pkg/passage` for `passage.PID` (the same 26-character ULID identifier type every other
knowledge-kind in this codebase already uses — `pkg/assessment/question.go` line 24 aliases it as
`assessment.ID`). No new third-party dependency is introduced.

**Storage**: A new, dedicated SQLite file (`scoring.db`), following the `pkg/authstore` pattern
rather than the `pkg/crossref`/`pkg/index` pattern — see "Storage placement decision" below for why.

**Testing**: Go's standard `testing` package, table-driven, matching every existing `pkg/assessment`
and `pkg/authstore` sibling `_test.go` file's own convention (no external test framework). Per
§11.4.224 (below), every behavior lands test-first with an observed RED run captured before the
implementation exists — not merely "tests exist."

**Target Platform**: Linux server, inside the existing `workshop-curriculum_platform_1` podman
container (§11.4.76, Containers Submodule) — no new deployable, no new container.

**Project Type**: Extension of a single existing Go web-service module (`platform/backend`); no new
service, no new frontend framework (the Angular frontend consumes the extended JSON contracts but
its own UI work is explicitly out of scope — spec.md Assumptions, and owned by the companion
`014-gamification-design-system` feature).

**Performance Goals**: No numeric throughput target is stated by the spec beyond SC-002's
"no observable delay" for a learner's own score read. Concretely: a submit request is bounded to
one SQLite transaction (one `SELECT` on `served_question`, one `INSERT` into `response_log`, one
`UPSERT` into `ability_score`) — the same "single-row, single-lock" shape `pkg/learning.SessionStore
.Mutate` already uses for lesson-completion state (`pkg/learning/progress.go` lines 121-156) and
that research §3.4 explicitly models the synchronous half of this feature on.

**Constraints**: Fully local — no external network call on the request path (matches this platform's
existing offline posture). Must not contend for a lock shared across learners: item-difficulty
recalibration (User Story 3) is explicitly a **batch** process, never a write inside a single
learner's submit transaction (research §3.4, and Constitution Check row "Isolation by Default"
below). Must survive a content re-index: `ResponseLogEntry`/`AbilityScore`/`ItemDifficultyState`
are learner history and calibration state, not derived content, and must not be wiped when the
passage registry is rebuilt — the same requirement `api.ProgressStore` and `pkg/authstore` already
satisfy by living outside the index database (`internal/api/progress.go` lines 38-48; `pkg/
authstore/authstore.go` line 1-5).

**Scale/Scope**: 311 practice questions across 40 area files today (research §2.1, freshly
recounted), 0 of them labeled `easy` — the cold-start fallback (FR-009) is therefore load-bearing
from day one, not a theoretical edge case. Single-instance deployment; `db.SetMaxOpenConns(1)`
(the `pkg/authstore` pattern, `authstore.go` line 93) is an adequate concurrency model for this
platform's expected load, the same judgment already made for the auth database.

## Storage placement decision

Two existing SQLite idioms exist in this codebase, and this feature deliberately picks the one the
research document's own §2.3/§5.4 did not force a choice between:

- **`pkg/crossref`'s idiom** (`crossref.go` lines 160-172, `RunsDDL`): the database is the **index**
  database, generation-scoped, and is rebuilt wholesale on every re-ingest. Right for *derived*
  data (a cross-reference IS a function of the corpus at a point in time).
- **`pkg/authstore`'s idiom** (`authstore.go` lines 42-59, `schema` + `Open(dir)`): a **separate**
  SQLite file, opened once at startup from the server's own data directory, that survives a
  re-index because it is not derived from the corpus at all.

`ResponseLogEntry`, `AbilityScore` and even `ItemDifficultyState` (whose *seed* comes from authored
content but whose *estimate* is learner-response-derived state that must accumulate across every
future re-ingest, not reset by one) are all the second kind. Using the index database would
silently wipe a learner's entire scoring history the next time the corpus is re-ingested — exactly
the class of defect research §2.3 documents as a **real, already-shipped** bug in this tree (the
`learning-progress.json` / `progress.json` two-store drift). This plan therefore follows the
`pkg/authstore` idiom: a new file, `scoring.db`, opened from the same server data directory
`api.NewProgressStore(cfg.indexDir)` and `authstore.Open(dir)` already use.

## Package placement decision

The research document's own §5.1-§5.3 sketch writes the three new types as `package assessment`,
"alongside the existing Progress type." This plan does not follow that sketch, per the task's own
instruction to verify against the package's real current contents before deciding.

Read in full for this plan: `pkg/assessment/question.go`, `progress.go`, `serve.go`, `store.go`,
`boundary.go`, `coverage.go`. Every file in that package is either (a) a pure data type with a
`Validate()` method and no I/O (`Question`, `Progress`), or (b) a **read-only** loader of authored
JSON content (`store.go` loads `curriculum/questions/*.json`; `serve.go` resolves citations against
the passage registry). **Nothing in `pkg/assessment` imports `database/sql` or owns a mutable
store.** Its own `Progress` type doc comment (`progress.go` lines 19-21, quoted in research §2.3)
names its HTTP wiring as "the explicit, undone half" of a *different*, still-unfinished task
(T082) — `pkg/assessment` is a content/type package, not a persistence package, in every file it
currently has.

**Decision: a new package, `pkg/scoring`.** This mirrors `pkg/authstore`'s own placement logic —
`authstore` is not inside the package whose content it authenticates access to; it is its own
small, focused package with its own SQLite file, because "what a thing IS" (a `Question`, a `User`)
and "how an activity against that thing is recorded and scored" are different responsibilities in
this codebase's existing style (`pkg/crossref` is likewise not inside `pkg/search`, though it reads
`pkg/search`'s `NeighbourSource` through an interface rather than importing it directly). `pkg/
scoring` depends on `pkg/assessment` (for `assessment.ID`/`assessment.Difficulty` when seeding from
an authored label) and on `passage.PID`, never the reverse — `pkg/assessment` gains zero new
imports and zero new responsibility from this feature.

## Idempotency and the served-question problem (§11.4.253)

Two requirements intersect and were not fully closed by the research document, which flagged both as
implementation-level design questions rather than resolving them:

1. **FR-014**: "a submission for a question the requesting session was not actually served … MUST
   be refused at the request boundary."
2. **§11.4.253**: "every retryable operation MUST BE IDEMPOTENT … enforced at the LOWEST LAYER …
   typically a DATABASE UNIQUENESS CONSTRAINT on a caller-supplied idempotency key, NEVER only an
   application-layer check-then-insert."

The existing codebase already solved an analogous problem for the *graded* assessment: D10's
per-session choice TOKENS (`pkg/learning/shuffle.go`'s `ResolveChoiceToken`) prove a submitted
choice ID was actually one *this session* was served, not copied from another session or the
catalog on disk (`internal/api/lessons.go` lines 721-731). But the **open practice bank's** `GET
/api/areas/{area}/questions` is explicitly **sessionless by design** (`internal/api/questions.go`
line 329: "This route is SESSIONLESS by design — a practice deck needs no login"), so there is
no existing per-session "you were served this" record to check a practice submission against.

**Decision, and it is the single new piece of server-side state this plan introduces beyond the
three entities the research document already named:** a `served_question` table records, per
serving event, `(session, question_id, served_difficulty, token, served_at, consumed_at)`. The new
`GET /api/areas/{area}/questions/next` endpoint (below) mints one row and returns its `token` to the
client. `POST /api/areas/{area}/questions/{question}/submit` requires that token in its body.

This single mechanism closes both requirements at once, and does so at the layer §11.4.253 demands:

- **FR-014 (served-question check)**: submit looks up the token; a missing, expired, already-
  consumed, or session/question-mismatched token is refused with 400 before any grading happens —
  fail-closed, matching the platform's own existing discipline for this class of problem
  (`GradedPromptIndex`'s fail-closed-on-unreadable-catalog, research §2.2).
- **§11.4.253 (idempotency)**: `response_log` carries a `UNIQUE NOT NULL` column on the same
  `serving_token`. The first successful submit inserts the response-log row and marks the token
  consumed in one transaction. A network-retried identical POST arrives with the *same* token,
  finds a `response_log` row already keyed by it, and **replays that stored result** (200, no
  second score computed) rather than erroring or double-scoring — the exact "second attempt
  refused/recognised as duplicate-already-succeeded = SUCCESS" shape §11.4.253 requires. **Stated
  honestly rather than overclaimed**: with `db.SetMaxOpenConns(1)` (data-model.md §5, mirroring
  `pkg/authstore`'s own convention), connection-pool serialization is the *primary practical*
  protection against a genuinely concurrent double-write in this deployment today. The database's
  own `UNIQUE` index is what makes the durability guarantee correct independent of that deployment
  detail, not by an application-level `SELECT`-then-`INSERT` race — and it is the mechanism that
  actually becomes load-bearing the moment `MaxOpenConns` is ever raised above 1 (two genuinely
  concurrent submits racing the same token: the loser's `INSERT` fails the constraint at the DB level
  and re-reads the winner's row — never a double-count). T012's `-race`-under-concurrency proof
  exercises this constraint specifically, not merely the single-writer pool.

data-model.md §5 gives the exact DDL and the transaction shape; contracts/practice-next.md and
contracts/practice-submit.md give the wire contract.

**Scope note, so this mechanism is not mistakenly read as universal:** the token described above is
the practice path's own entry point, `Store.RecordResponse`. The graded assessment path
(`AssessmentSubmitHandler`) has no serving token to present — it was never served a question through
`GET …/questions/next` — and is not required to fabricate one; it calls a second entry point,
`Store.RecordGradedResponse`, which shares the same core update logic through one unexported helper
but skips the token check because the graded path's own existing lesson-gate is its authorization
instead. See data-model.md §4 for the exact shape and why "one shared scoring pipeline" means shared
algorithm, not one identical call signature for both trust contexts.

## Constitution Check

*GATE: Must pass before Phase 1 design is relied on; re-checked here, not merely templated.*

Checked against this project's local constitution (`.specify/memory/constitution.md`, v1.5.0) and,
per this task's explicit instruction, against three universal anchors read from
`submodules/constitution/Constitution.md` directly rather than assumed.

### Local principles (real, targeted — not every principle in the file applies)

| Principle | Status | Notes |
|---|---|---|
| Evidence-Based Claims | PASS | SC-001 through SC-008 are each phrased as directly re-runnable checks (submit-then-read sequences, audit-link joins, a storage-level append-only constraint) rather than claims about design intent; the algorithm itself is not asserted correct, it is the exact one the POC already demonstrated with captured, reproducible output (research §4). |
| Honest Instruments | PASS | FR-016 (attempt count accompanies every ability read) is this principle applied to a learner-facing number: a low-evidence early-session estimate must never be presented with the same confidence as a converged one — the plan carries `AttemptCount` on every `AbilityScore` read specifically so a caller is never left guessing. |
| Isolation by Default (mutation-paired gates) | PASS, with an owed task | The `served_question.token` UNIQUE constraint and the `response_log` immutability are both gates in the sense this principle means; each needs a paired mutation (a concurrent double-submit; an attempted UPDATE/DELETE against `response_log`) proving it actually fails when broken. Not yet written — owed to tasks.md, named explicitly rather than left implicit. |
| Comprehensive Documentation | PASS | This plan, data-model.md, contracts/, and quickstart.md are the documentation; `CONTINUATION.md` update is owed at implementation time, per the same principle's own requirement, not at planning time. |
| Environment Adaptability | N/A, distinguished from a violation | The K-factor/logistic-divisor/downgrade-magnitude constants (spec's NEEDS CLARIFICATION items) are **pedagogical tuning values**, not host-environment assumptions (no path, port, model name, or hardware fact is frozen anywhere in this design) — this principle governs the latter, not the former. They are still made configurable (a `Config` struct, not hardcoded literals), which is the spec's own requirement (Clarifications Needed, item 2), for a different reason: future retuning against real data, not portability. |
| Published Means Served | PASS, directly designed for | `GET /api/areas/{area}/questions/next` must never recommend a question that `POST …/submit` will then refuse — the served-question token mechanism above is exactly this principle applied to a two-step interaction: what is advertised as "the next thing to answer" must be the thing the submit route will actually accept. |
| Standalone Cloneable | PASS | No new external dependency; `modernc.org/sqlite` is already vendored and declared in the existing module's own `go.mod`/`go.sum`. |
| Source Is Not Served | PASS, and load-bearing | `ResponseLogEntry.ServedDifficulty` is captured **as served at the moment of serving**, never re-derived from the item's current (possibly since-recalibrated) `ItemDifficultyState` — data-model.md §5.1 makes this a stored column, not a join, for exactly this reason: a historical score's provenance must describe what was actually served, not what the item's difficulty happens to read today. |
| A Snapshot Licenses Only Itself | PASS | The batch recalibration job (User Story 3) computes `ItemDifficultyState` from a bounded read of `response_log` since its last run; it is a snapshot, and no synchronous submit path is ever allowed to assert "this item's difficulty is now X" on the strength of a batch result that has not actually run yet — the two are architecturally separate writes (research §3.4), not a cache the request path could mistake for current truth. |
| A Gate's Population Is Part of Its Claim | PASS, directly addressed | The "population" a cold-start selection draws from is exactly the edge case spec.md names: 0 of 311 practice-bank items are labeled `easy` (research §2.1, §2.2 edge cases). FR-009's fallback to the graded catalog is this principle applied to item selection — the selection population must be justified (does an `easy`-difficulty item actually exist to serve?) before a cold-start pick is made, not assumed from the bank's nominal size. |
| A Rule Enforced by Nothing Is Not a Rule | PASS, with an owed task | FR-003's "never mutated or deleted" is enforced by (a) the application code path containing no `UPDATE`/`DELETE` statement against `response_log` anywhere, plus (b) a paired mutation test asserting an attempted mutation is rejected or structurally impossible — an unenforced code-review convention alone would not satisfy this principle, and is not what is planned. |
| A Capability With Measured Harm Ships Off | Considered, PASS | Unlike the workshop's LLM-answering capability (which this same constitution records shipping OFF by default after measured fabrication harm), a wrong or imprecise *ability score* has bounded harm: it never fabricates a false factual answer, only a numeric estimate the spec itself documents as honestly uncertain (research §6, "rock-solid" is about provenance, not precision). The scoring pipeline ships ON by default. The **downgrade routing magnitude/threshold are configurable** precisely so an operator who observes the untuned POC constants misbehaving on real data has a measurement-driven off-ramp, without needing a code change — the spirit of this principle even though the specific "ships off by default" clause does not apply to a low-harm capability. |
| Non-Readable Is Indistinguishable From Nonexistent | N/A, checked rather than assumed | `AbilityScore` is keyed by the same `X-Session` opaque string every other session-scoped store here already uses (`ProgressStore`, `pkg/learning.SessionStore`) — not an account, and this feature introduces no new authorization boundary or cross-session read path; a session cannot address another session's row because nothing here accepts a session identifier from anywhere but the request's own header. |
| The Content Boundary Is a Standing Invariant | PASS | This plan and its sibling documents quote `workshop/` only by path, schema, and count (per research document's own stated method note) — no chapter or transcript content appears anywhere below. |
| Quality Over Speed | PASS | TDD is the explicit execution discipline (see §11.4.224 below); nothing in this plan proposes a shortcut that trades correctness of the append-only log or the idempotency guarantee for implementation speed. |

### Universal anchors checked directly, as instructed (real quotes, not restated from memory)

**§11.4.224 — Test-first (TDD) for ALL work, ≥85% code-coverage floor, seven-canonical-test-type
breadth.** Read in full from `submodules/constitution/Constitution.md`. Clause (A): *"For EVERY work
product with an executable surface — a change, a new feature, an implementation, a wiring/
integration … the test is WRITTEN FIRST, RUN FIRST, and OBSERVED TO FAIL for the right reason before
the implementation exists."* This feature is squarely clause-(A) scope: every new behavior (the Elo
update arithmetic, the K-factor decay, the downgrade trigger, the served-question token check, the
batch recalibration shrink-rate) is **new, deterministic, pure-function-shaped logic with a clear
oracle** — the POC script IS that oracle for the ability-update formula (§11.4.245 below), and
data-model.md's DDL is the oracle for the storage-level immutability and uniqueness guarantees.
**Applied to this feature's execution strategy**: strict RED-GREEN-REFACTOR for `pkg/scoring`'s pure
functions (`UpdateAbility`, `DowngradeTriggered`, `RecalibrateItem`) and for the HTTP handlers' 400/
replay/fail-closed branches; the ≥85% floor and seven-type breadth (unit + integration against a
real SQLite file + an anti-bluff test proving the UNIQUE constraint, not just the app-level check,
actually rejects a duplicate) are tasks.md-level commitments, not yet executed at the planning
stage — named here so they are not silently dropped when tasks.md is written.

**§11.4.241 — Illegal-state-unrepresentability preference: types before API-shape before lint before
property-test before runtime-assertion.** Read in full: the anchor establishes *"a closed ordered
ladder (1) TYPE SYSTEM → (2) API SHAPE → (3) LINT → (4) PROPERTY-BASED TEST → (5) RUNTIME ASSERTION
for every load-bearing invariant; a defect preventable at rung N caught only at rung > N is a
finding."* Applied concretely to this feature's two hardest invariants:

- **"An ability estimate is always in [0, 10]" (FR-006).** FR-006 bundles two different
  sub-invariants, correctly assigned to two different rungs, not one rung standing in for both.
  "No code outside `pkg/scoring` can construct or mutate an `AbilityScore` at all" is closed at
  **rung 1, genuinely**: `AbilityScore`'s fields are unexported, so `AbilityScore{Ability: 999}` and
  `score.ability = 999` both fail to COMPILE from outside the package — this is Go's own
  field-visibility rule doing real work, not an API-shape convention a caller could route around
  (data-model.md §1.2). "The value `UpdateAbility` itself produces is actually in [0, 10]" has no
  rung-1 representation in Go (no bounded-float type), so THAT half is necessarily closed at rung 5
  (`clamp`, inside the one function — `UpdateAbility` — that ever computes a new `Ability`). The only
  exported surface on `AbilityScore` is a set of read-only accessor methods.
- **"A `ResponseLogEntry`, once written, is never mutated or deleted" (FR-003).** This is exactly the
  invariant class this anchor is written for. Rung 1, genuinely: the struct's fields are unexported,
  so no code outside `pkg/scoring` can construct, mutate, or field-assign a `ResponseLogEntry` at all
  — not merely "no setter method happens to exist" (an exported-field struct with no setter can still
  be populated via a composite literal; an unexported-field one cannot, from outside). Even inside
  `pkg/scoring`, only `Store.RecordResponse`/`Store.RecordGradedResponse`'s shared insert path ever
  populates one (data-model.md §1.1, §4). Rung 5 (the SQLite layer) is the actual durable enforcement
  against a DIFFERENT threat — a raw SQL statement that bypasses the Go API entirely — this plan
  explicitly does **not** rely on "the application just never calls UPDATE" as that guarantee (that is
  exactly the "Rule Enforced by Nothing" failure the local Constitution Check row above names) —
  data-model.md §5.1 documents the concrete storage-level mechanism, and the two rungs are tested
  separately (tasks.md T007 for rung 5, T010b for rung 1), never conflated into one test standing in
  for both.

**§11.4.253 — Idempotency under retry + DB-level durable uniqueness guard.** Quoted and applied in
full in "Idempotency and the served-question problem" above; not restated here.

No unjustified Constitution Check violations. Complexity Tracking below is empty for the same
reason.

## Project Structure

### Documentation (this feature)

```text
specs/013-adaptive-assessment-scoring/
├── spec.md              # Feature specification (already exists, source of truth for scope)
├── plan.md              # This file
├── data-model.md         # Phase 1 output: entities, DDL, Elo formula in Go-shaped pseudocode
├── contracts/
│   ├── practice-next.md      # GET  /api/areas/{area}/questions/next
│   ├── practice-submit.md    # POST /api/areas/{area}/questions/{question}/submit
│   └── progress-extension.md # GET  /api/progress ability_score addition
├── quickstart.md         # Phase 1 output: real validation steps, POC reproduction + manual API walk
└── tasks.md              # Phase 2 output (/speckit-tasks — NOT produced by this plan)
```

Phase 0 research is **already satisfied** by the existing, cited research document and its POC —
this plan does not duplicate it into a second `research.md`; every Technical Context and design
decision above cites the real research document section it draws from.

### Source Code (repository root)

```text
workshop/platform/backend/                        (PRIVATE submodule, consumed read-write for this
                                                     feature's own implementation — not the umbrella
                                                     root, which stays untouched by this feature)
├── pkg/
│   ├── scoring/                                   # NEW package (see "Package placement decision")
│   │   ├── doc.go                                  # package doc: what owns what, and why separate
│   │   │                                            # from pkg/assessment (cites this plan)
│   │   ├── model.go                                # ResponseLogEntry, AbilityScore,
│   │   │                                            # ItemDifficultyState, ServedQuestion types +
│   │   │                                            # Validate() — no unchecked constructors
│   │   ├── elo.go                                  # Pure functions: UpdateAbility, KFactor,
│   │   │                                            # ExpectedScore, clamp, DowngradeTriggered,
│   │   │                                            # DowngradeMagnitude — the §3.2/§3.3 formula,
│   │   │                                            # no I/O, directly unit-testable against the
│   │   │                                            # POC's own captured numbers
│   │   ├── store.go                                # SQLite-backed Store: Open(dir), schema DDL,
│   │   │                                            # ServeNext, RecordResponse (the practice-path
│   │   │                                            # idempotent transaction, token-keyed),
│   │   │                                            # RecordGradedResponse (the graded-path entry
│   │   │                                            # point, no token — see data-model.md §4 for why
│   │   │                                            # both exist and share one unexported helper),
│   │   │                                            # CurrentAbility, RecalibrateBatch
│   │   ├── config.go                                # Config: K0, KMin, DecayAttempts,
│   │   │                                            # LogisticDivisor, DowngradeStreak,
│   │   │                                            # DowngradeMagnitude, ItemK0, ItemKMin,
│   │   │                                            # ItemDecayResponses, BatchCadence — every
│   │   │                                            # tuning constant from a named field, never a
│   │   │                                            # literal in elo.go/store.go
│   │   └── *_test.go                                # table-driven, POC-numbers as golden oracle
│   │       │                                         # for elo_test.go (§11.4.245: oracle = DERIVED,
│   │       │                                         # the independently-executed POC script's own
│   │       │                                         # captured trace — not the code under test)
│   │       └── (mutation tests for the UNIQUE
│   │          constraint and response_log
│   │          immutability live here too)
│   └── assessment/                                  # UNCHANGED in shape — gains a small adapter
│       │                                             # (see internal/api/lessons.go below), no new
│       │                                             # exported type, no new database/sql import
│       └── progress.go                              # UNCHANGED — Progress stays what it is
│                                                      # (§2.7's per-item grade/streak); AbilityScore
│                                                      # is deliberately NOT folded into it (research
│                                                      # §5.4's own recommendation, followed here)
├── internal/api/
│   ├── questions_scoring.go                         # NEW: GET .../questions/next and
│   │                                                  # POST .../questions/{question}/submit
│   │                                                  # handlers — sibling to questions.go, same
│   │                                                  # QuestionsDeps-style deps struct, adds a
│   │                                                  # *scoring.Store field
│   ├── lessons.go                                    # MODIFY: AssessmentSubmitHandler's existing
│   │                                                  # ckit.Submit result (ckit.Result, carrying
│   │                                                  # per-question QuestionOutcome — curriculum-kit
│   │                                                  # submodule, submodules/curriculum-kit/pkg/
│   │                                                  # curriculum/assess.go) is additionally folded
│   │                                                  # into scoring.Store.RecordGradedResponse (NOT
│   │                                                  # RecordResponse — no serving token exists on
│   │                                                  # this path; see data-model.md §4), ONE call
│   │                                                  # per graded QuestionOutcome, after ckit.Submit
│   │                                                  # succeeds — User Story 1 Acceptance Scenario 4
│   └── progress.go                                   # MODIFY: ProgressHandler gains an
│                                                       # AbilityScoreSource closure parameter,
│                                                       # mirroring the EXISTING
│                                                       # LessonCompletionSource pattern
│                                                       # (progress.go lines 277-299) byte-for-byte
│                                                       # in shape — same nil-is-legitimate,
│                                                       # same source-failure-does-not-fault-the-
│                                                       # whole-request discipline
└── cmd/workshop-server/main.go                       # MODIFY: open scoring.Store alongside the
                                                        # existing authstore.Open/api.NewProgressStore
                                                        # calls; register the two new routes beside
                                                        # main.go's existing questions/assessment
                                                        # route block (lines ~1444-1452); wire the
                                                        # AbilityScoreSource closure into
                                                        # ProgressHandler's existing construction call
```

**Structure Decision**: `pkg/scoring` as a new, focused package (content-vs-activity separation, see
"Package placement decision"); its own dedicated `scoring.db` SQLite file (survives re-index, see
"Storage placement decision"); two new HTTP routes plus one small addition to an existing route
(`GET /api/progress`) and one wiring change to an existing handler
(`AssessmentSubmitHandler`) — no new service, no new deployable, no change to `pkg/assessment`'s
existing exported surface.

## Complexity Tracking

*No unjustified Constitution Check violations — table intentionally empty.*
