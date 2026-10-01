# Data Model: Adaptive Assessment and Real-Time Scoring

**Input**: spec.md's Key Entities section; research §5 (`workshop/docs/research/education-platform/
adaptive-assessment-and-scoring.md`), whose sketch this document turns into a complete, concrete
schema — grounded in `pkg/crossref/crossref.go`'s own `CREATE TABLE IF NOT EXISTS` idiom and
`pkg/authstore/authstore.go`'s own `Open(dir)`/`migrate()` idiom (both read in full for this plan;
see plan.md's "Storage placement decision" and "Package placement decision" for why `pkg/authstore`
is the closer analog).

All four entities below live in the new `pkg/scoring` package and its dedicated `scoring.db` SQLite
file — never the index database, and never inside `pkg/assessment`.

## 1. Entities

### 1.1 `ResponseLogEntry` — the append-only audit trail

The **sole source of truth** every derived `AbilityScore` and `ItemDifficultyState` number is
computed from. Every other value in this feature is re-derivable from this table; nothing here is
re-derivable from anything else.

```go
// Package scoring — platform/backend/pkg/scoring/model.go

// ResponseLogEntry is one scored activity. It is minted and inserted exactly
// once. Every field is UNEXPORTED — this is the actual, compiler-enforced
// mechanism behind "never changed after construction", not merely a
// convention: `ResponseLogEntry{Correct: true}` and `entry.correct = true`
// BOTH FAIL TO COMPILE from any package other than pkg/scoring, because Go's
// own field-visibility rule makes an unexported field genuinely
// inaccessible from outside its declaring package — a stronger guarantee
// than "no setter method happens to exist" (an exported-field struct with no
// setter can still be constructed and mutated via a composite literal or
// direct field assignment; an unexported-field one cannot, from outside).
// The only exported surface is a set of read-only accessor methods below,
// and the only way to obtain a *populated* value at all — inside or outside
// this package — is through Store.RecordResponse's return value (a freshly
// inserted entry, or a replayed one per §11.4.253). The storage layer
// additionally refuses an UPDATE or DELETE against its table at the SQLite
// level (see §5.1's DDL and its accompanying trigger) — the "Rule Enforced
// by Nothing Is Not a Rule" Constitution Check row is closed at BOTH the
// Go-API layer (rung 1: unexported fields, no setters) AND the storage layer
// (rung 5: the trigger) — two DIFFERENT guarantees against two DIFFERENT
// threats (an in-process caller vs. a raw SQL statement), not one standing in
// for the other.
type ResponseLogEntry struct {
	id       passage.PID // minted via the same *passage.Minter every other
	                       // knowledge kind in this codebase uses
	session  string       // the same opaque X-Session identity ProgressStore
	                       // and pkg/learning.SessionStore already use
	area     passage.PID  // the owning knowledge area (FR-013's per-area score)
	question passage.PID  // the assessment.Question.ID this entry scores

	at      time.Time
	correct bool

	// servedDifficulty, abilityBefore and abilityAfter are the EXACT inputs
	// and output of the §3.2 update formula that produced this entry — never
	// re-derived from the question's CURRENT ItemDifficultyState, because
	// that value drifts (§1.4 below). This is the "Source Is Not Served"
	// Constitution Check row made concrete: a historical entry describes
	// what was actually served, not what is true of the item today.
	servedDifficulty float64
	abilityBefore    float64
	abilityAfter     float64
	kFactor          float64

	// downgradeTriggered and reason are NEVER omitted, correct or incorrect,
	// downgrade or not — every entry carries a reason string (FR-002).
	downgradeTriggered bool
	reason             string

	// source distinguishes which surface produced this entry (User Story 1
	// Acceptance Scenario 4: both surfaces feed ONE log).
	source ResponseSource

	// servingToken is the §11.4.253 idempotency key: the UNIQUE, NOT NULL
	// value minted by GET .../questions/next and consumed exactly once by
	// this entry's insertion. See §5.1's DDL and plan.md's "Idempotency and
	// the served-question problem".
	servingToken string
}

// Read-only accessors — the ONLY exported surface ResponseLogEntry has. There
// is deliberately no exported setter paired with any of these: a caller that
// wants a DIFFERENT value writes a NEW entry through Store.RecordResponse
// (FR-003 — "a correction is a new entry, never an edit"); it does not, and
// structurally cannot, mutate this one.
func (e ResponseLogEntry) ID() passage.PID          { return e.id }
func (e ResponseLogEntry) Session() string          { return e.session }
func (e ResponseLogEntry) Area() passage.PID        { return e.area }
func (e ResponseLogEntry) Question() passage.PID    { return e.question }
func (e ResponseLogEntry) At() time.Time            { return e.at }
func (e ResponseLogEntry) Correct() bool            { return e.correct }
func (e ResponseLogEntry) ServedDifficulty() float64 { return e.servedDifficulty }
func (e ResponseLogEntry) AbilityBefore() float64   { return e.abilityBefore }
func (e ResponseLogEntry) AbilityAfter() float64    { return e.abilityAfter }
func (e ResponseLogEntry) KFactor() float64         { return e.kFactor }
func (e ResponseLogEntry) DowngradeTriggered() bool { return e.downgradeTriggered }
func (e ResponseLogEntry) Reason() string           { return e.reason }
func (e ResponseLogEntry) Source() ResponseSource   { return e.source }
func (e ResponseLogEntry) ServingToken() string     { return e.servingToken }

// ResponseSource is the closed vocabulary for FR-002's "from the new
// practice-bank submit endpoint and from the existing graded end-of-area
// assessment submit endpoint alike." Unlike ResponseLogEntry/AbilityScore,
// ResponseSource stays a plain exported string type: it carries no numeric
// or referential invariant that an out-of-package literal could violate —
// Valid() is the closed-vocabulary check, and a caller constructing
// ResponseSource("bogus") produces a value that is simply invalid per
// Valid(), never one that corrupts stored state (Store.RecordResponse
// rejects an invalid Source before writing anything).
type ResponseSource string

const (
	SourcePractice ResponseSource = "practice"
	SourceGraded   ResponseSource = "graded"
)

func (s ResponseSource) Valid() bool { return s == SourcePractice || s == SourceGraded }
```

**Enforcement mechanism for the claim above — real, not aspirational, and not
invented for this feature.** This codebase already has exactly this pattern:
`pkg/search/envelope_test.go`'s `TestUpstreamTextCannotBeAssignedToASnippet`
(§2.4 there) quarantines `UpstreamText` by making it un-convertible to the one
string type a caller might try to smuggle it into, documents the compile-time
guarantee as a code comment (*"This is the assertion: UpstreamText has no
string conversion, so `Hit{Snippet: u}` does not compile. What can be checked
at run time is that the ONLY accessor is named after the only legal
destination."*), and pairs it with a runtime check of the one accessor that
does exist. `pkg/scoring/model_test.go` follows the identical convention for
`ResponseLogEntry` and `AbilityScore`: a code comment stating the two
composite-literal/field-assignment forms that fail to compile from outside the
package (this is NOT re-verified by an automated negative-compilation harness
on every test run — no such harness exists in this codebase, and building one
would be new infrastructure this feature does not need), paired with a real
runtime assertion that every accessor method returns exactly the value a real
`Store.RecordResponse` call populated it with. See tasks.md's T010b for the
task that writes this.

**A correction is a new entry, never an edit (FR-003).** There is deliberately no
`CorrectsEntry *passage.PID` field in Phase 1 — the spec's own Assumptions section defers a
repeat-attempt/gaming detector, and a compensating-entry convention is exactly the shape that
detector would eventually need to reconcile against; adding the field before the detector's design
exists would be guessing its shape. `response_log`'s own columns (`session`, `question_id`, `at`)
already carry what FR-015 requires for that future detector to be built "without requiring a schema
change to the log itself" — the point is proven by the schema below, not by a field reserved today
for a mechanism that does not exist yet.

### 1.2 `AbilityScore` — the current, fast-read number

```go
// AbilityScore is the CURRENT 0-10 ability value for one (session, area)
// pair — a direct O(1) read, never a scan-and-fold over response_log.
//
// THE ONLY WAY TO PRODUCE A VALUE OF THIS TYPE IS THROUGH Store.RecordResponse
// OR Store.CurrentAbility. Every field is UNEXPORTED, so a caller OUTSIDE
// pkg/scoring has no composite-literal or field-assignment path to populate
// or mutate Ability at all: `scoring.AbilityScore{Ability: 999}` and
// `score.ability = 999` both FAIL TO COMPILE outside this package — Go's own
// field-visibility rule doing real work, not an API-shape convention a caller
// could route around. This closes FR-006's invariant at two DIFFERENT rungs
// for two DIFFERENT sub-claims, and the two must not be conflated: rung 1
// (unexported fields) closes "no external constructor exists" — genuinely,
// by the type system, not by discipline; rung 5 (`clamp`, inside elo.go's
// `UpdateAbility`, the one function that ever computes a new Ability value)
// closes "the value produced is actually in [0, 10]" — a bounded float has no
// rung-1 representation in Go, so this half is necessarily a runtime check.
// The only exported surface is a set of read-only accessor methods below.
type AbilityScore struct {
	session      string
	area         passage.PID
	ability      float64     // 0-10, 10 = strongest (spec.md's own scale)
	attemptCount int         // FR-016: the confidence signal accompanying
	                          // every read
	updatedAt    time.Time
	lastEntry    passage.PID // the ResponseLogEntry.ID that produced this
	                          // value — FR-007's audit link, one join away
}

// Read-only accessors — the ONLY exported surface AbilityScore has. No
// exported setter is paired with any of these; see the type doc comment
// above for why that is a real, not merely conventional, closure.
func (a AbilityScore) Session() string        { return a.session }
func (a AbilityScore) Area() passage.PID      { return a.area }
func (a AbilityScore) Ability() float64       { return a.ability }
func (a AbilityScore) AttemptCount() int      { return a.attemptCount }
func (a AbilityScore) UpdatedAt() time.Time   { return a.updatedAt }
func (a AbilityScore) LastEntry() passage.PID { return a.lastEntry }
```

**Per-area, not cross-curriculum — the Phase 1 decision on spec.md's open Clarification 1.** The
spec explicitly leaves "per-area ability score vs. a single cross-curriculum number" as an
operator decision still pending (Clarifications Needed, item 1). Every acceptance scenario in
spec.md that exercises scoring, however, is phrased "in an area" (User Story 1's Independent Test:
"against one area's practice bank"; User Story 2's: "for one learner in one area"). This plan
therefore builds `AbilityScore` keyed by `(session, area)` as the Phase 1 shape — the literal
reading of every testable scenario the spec actually wrote — while keeping the column additive
enough that a future cross-curriculum aggregate is a new row shape (e.g. a NULL-area summary row,
or a separate read that folds the per-area rows), not a schema migration of the existing ones. The
open operator decision is restated, not resolved, by this choice; it is recorded here as a Phase 1
implementation decision, not as the clarification's answer. See spec.md's own Clarification 1 for
the unresolved question this does not close.

### 1.3 `ItemDifficultyState` — the crowd-calibrated item side

```go
// ItemDifficultyState is the batch-updated difficulty side of one question.
// Written ONLY by Store.RecalibrateBatch (the User Story 3 batch job) — NEVER
// synchronously in the request path that scores one learner's answer
// (research §3.4's load-bearing reason: shared global state must not
// contend on the hot path).
type ItemDifficultyState struct {
	Question           passage.PID
	DifficultySeed     float64   // from the authored label, §2 below
	DifficultyEstimate float64   // current, batch-updated value
	ResponseCount      int       // responses folded into DifficultyEstimate
	                              // so far — the item-side confidence signal,
	                              // symmetric to AbilityScore.AttemptCount
	UpdatedAt          time.Time
}
```

### 1.4 `ServedQuestion` — the serving/idempotency record (new; not in the research sketch)

Not named by the research document (which explicitly left "how a submission proves it was served"
as an open implementation question — research §6 does not mention it at all; it surfaces only once
FR-014 and §11.4.253 are read together, which this plan does in plan.md's "Idempotency and the
served-question problem"). This is the mechanism, not merely a note:

```go
// ServedQuestion is minted by GET .../questions/next and consumed exactly
// once by POST .../questions/{question}/submit. It is the FR-014
// "was this session actually served this question" check AND the §11.4.253
// idempotency key, in one mechanism — see plan.md for why one table answers
// both questions rather than two.
type ServedQuestion struct {
	Token            string // the idempotency key; UNIQUE NOT NULL in SQL
	Session          string
	Area             passage.PID
	Question         passage.PID
	ServedDifficulty float64
	ServedAt         time.Time
	ConsumedAt       *time.Time // nil until a submit consumes it
}
```

A token is honored for submission up to **24 hours** after serving (configurable,
`Config.ServingTokenTTL`) — long enough that a learner who leaves a practice session open overnight
is not unfairly refused, short enough that `served_question` does not grow unbounded (a background
sweep, or a `WHERE served_at > ?` filter on lookup, prunes expired unconsumed rows; expiry is a
FR-014 refusal, never scored, matching the platform's existing fail-closed discipline for a
malformed/replayed submission).

## 2. Difficulty-label seeding (FR-008, FR-009)

Seeded once, at the moment a question is first seen by `Store.RecalibrateBatch` or first served by
`Store.ServeNext` (whichever happens first — an `INSERT OR IGNORE` against `item_difficulty`,
matching `pkg/authstore`'s own idempotent-seed pattern, `authstore.go`'s `seed()` method):

| Authored label (`assessment.Difficulty`) | Seed (0-10 scale) |
|---|---|
| `easy` | 2.5 |
| `medium` | 5.0 |
| `hard` | 7.5 |
| (no label — e.g. a `curriculum-kit` graded-catalog question) | 5.0, explicitly "uncalibrated" |

This is research §3.1 step 1's mapping, unchanged — the POC does not exercise item-difficulty
seeding directly (it hand-authors a 17-item bank spanning 1.0-10.0), so this mapping is a design
choice carried from the research document's prose rather than POC-verified arithmetic; it is not
re-derived here.

**Cold-start fallback (FR-009, the "Gate's Population Is Part of Its Claim" Constitution Check
row).** `Store.ServeNext`'s cold-start branch (an area with zero prior `response_log` rows for this
session) selects the lowest-difficulty item across the union of the area's practice bank and the
`curriculum-kit` graded catalog. Because that population currently contains **zero** `easy`-labeled
items (research §2.1, §2.2 edge cases — 121 `medium`, 190 `hard`, 0 `easy` of 311), the real
lowest-difficulty item available today is a 5.0-seeded `medium` practice item or a 5.0-seeded
uncalibrated graded-catalog item, never a bare `medium`-or-harder pick reached without considering
the graded catalog at all — this is the literal FR-009 requirement, not an optimization.

**Two-tier selection — closing a real cold-start chicken-and-egg bug, not merely restating the
fallback above.** `item_difficulty` is seeded *lazily* (this section, above): a row for a given
question exists only once that question has been served by `ServeNext` or touched by
`RecalibrateBatch` at least once. On a genuinely fresh area — User Story 1's own first Acceptance
Scenario: a learner with zero prior history, in an area that has *never* been served to *anyone* —
`item_difficulty` holds **zero rows for that area**. A cold-start query scoped directly to
`item_difficulty WHERE area_id = ? ORDER BY difficulty_estimate ASC LIMIT 1` therefore finds nothing
to select: the table the query depends on has not been seeded yet, and nothing seeds it before this
query runs. Querying `item_difficulty` first and assuming it is already populated is wrong for
exactly the scenario FR-009 and User Story 1's first Acceptance Scenario name. The corrected
selection is two-tier, and both tiers are real, checkable SQL conditions — never inferred from a
zero-value difficulty, which would be indistinguishable from a genuinely-seeded 0.0:

1. **Tier 1 (the common case, once the area has been served to anyone before)**: `SELECT
   question_id, difficulty_estimate FROM item_difficulty WHERE area_id = ? ORDER BY
   difficulty_estimate ASC LIMIT 1` over the union of both content sources' already-seeded rows. If
   this returns a row, serve it — unchanged from the original decision.
2. **Tier 2 (the empty-result fallback — the actual fix)**: when tier 1's result set is empty (a
   real, checkable condition — `sql.ErrNoRows` / a zero-row result set, checked explicitly, never
   inferred), fall back **directly to the question bank's own authored difficulty label**
   (`assessment.Question.Difficulty`) rather than to `item_difficulty` at all: enumerate the area's
   practice-bank and graded-catalog questions, map each to its seed value from the table above purely
   from its *authored* label — no read of `item_difficulty` in this branch — and select the question
   with the lowest authored-label seed (ties broken deterministically; see tasks.md T018, which owns
   documenting the exact tiebreak rule and is not re-litigated here). This is exactly FR-009's "defined
   fallback source for a genuinely low-difficulty first item": the authored label *is* that fallback
   source, precisely because — unlike `item_difficulty` — it always exists regardless of how populated
   the derived, lazily-seeded table happens to be.

**The handoff back to tier 1 is coherent, not merely hoped-for — stated explicitly rather than left
implicit.** Tier 2's selected item is minted into a `served_question` row like every branch, and — per
this section's own lazy-seed rule (`INSERT OR IGNORE` against `item_difficulty`, already part of this
same `ServeNext` call, before the call returns) — gets its own `item_difficulty` row written as a
side effect of being served. So the *second* call to `ServeNext` for this same area (this session's
own next cold-start-shaped request, or a *different* session hitting the same never-before-served
area, since `item_difficulty` is crowd-shared state, not per-session) finds tier 1's query non-empty
and takes the ordinary path. The cold-start-population gap is therefore exactly one call wide per
area, by construction — never a standing hole a caller could hit twice for the same area.

## 3. The Elo update, as real arithmetic (grounded in the POC, not re-derived)

Reproduced and verified against `workshop/docs/research/education-platform/poc/adaptive_scoring_poc.py`'s
own captured output (`sample-output-30-attempts-seed42.txt`) — the K-factor values below were
back-solved from the trace's own printed `K` column and match to 3 decimal places (see
quickstart.md §1 for the reproduction command and the exact comparison).

```go
// Package scoring — elo.go. Pure functions, no I/O — the §11.4.245 oracle
// for these is the POC script's own captured trace (an independently
// executed reference implementation; DERIVED oracle strategy), never the
// code under test asserting on itself.

// KFactor returns the update step size for a learner/item with n PRIOR
// recorded attempts (n=0 for a genuinely first attempt).
//
//	K(n) = KMin + (K0 - KMin) * exp(-n / DecayAttempts)
//
// Verified against the POC trace: K(0)=0.900, K(1)=0.759, K(2)=0.643 with
// K0=0.9, KMin=0.12, DecayAttempts=5 — exact to 3dp across all 30 printed
// attempts for all three simulated learners.
func KFactor(n int, cfg Config) float64 {
	return cfg.KMin + (cfg.K0-cfg.KMin)*math.Exp(-float64(n)/cfg.DecayAttempts)
}

// ExpectedScore is the probability the system currently expects a CORRECT
// response, given ability theta and item difficulty d, both on the 0-10
// scale, through a base-10 logistic with scale divisor D (research §3.2;
// POC's LOGISTIC_DIVISOR=1.5 is the SAME D used both by the system's own
// expected-score formula and by the POC's separate hidden-ability oracle —
// one formula, two uses, not two different meanings of D).
//
//	expected = 1 / (1 + 10^(-(theta - d) / D))
func ExpectedScore(theta, d, D float64) float64 {
	return 1 / (1 + math.Pow(10, -(theta-d)/D))
}

// UpdateAbility applies ONE scored response and returns the new ability
// estimate, clamped to [0, 10] (FR-006) — this is the ONLY function in this
// package that ever computes a new Ability value; AbilityScore's unexported
// fields (§1.2) are what make this the ONLY place such a value can reach a
// caller at all, per the §11.4.241 rung-1 (field visibility) + rung-5
// (clamp) discipline.
func UpdateAbility(theta, servedDifficulty float64, correct bool, priorAttempts int, cfg Config) (newTheta, k float64) {
	k = KFactor(priorAttempts, cfg)
	expected := ExpectedScore(theta, servedDifficulty, cfg.LogisticDivisor)
	actual := 0.0
	if correct {
		actual = 1.0
	}
	newTheta = theta + k*(actual-expected)
	return clamp(newTheta, 0, 10), k
}

func clamp(x, lo, hi float64) float64 {
	if x < lo {
		return lo
	}
	if x > hi {
		return hi
	}
	return x
}
```

**Item-difficulty update (User Story 3) reuses `UpdateAbility`/`KFactor` with the theta/difficulty
arguments SWAPPED — and, load-bearingly, with the correctness flag INVERTED.** The naive reading —
call `UpdateAbility(theta=itemDifficulty, servedDifficulty=learnerAbility, correct=<the same bool the
learner's own response recorded>, cfg=itemCfg)` — moves the item's difficulty estimate in the WRONG
DIRECTION. The correct call inverts correctness:

```
UpdateAbility(theta=itemDifficulty, servedDifficulty=learnerAbility, correct=!correct, cfg=itemCfg)
```

**Why the flip is right, not merely asserted.** `ExpectedScore` is a base-10 logistic satisfying the
identity `f(x) + f(-x) = 1`, so `ExpectedScore(itemDifficulty, ability, D) = 1 -
ExpectedScore(ability, itemDifficulty, D)` — the item's own "probability it wins" (the learner
answers it wrong) is exactly the complement of the learner's "probability of a correct answer"
against that same pairing. `UpdateAbility`'s `actual` term is `1` when its own `correct` argument is
`true`. For the *item* side, "the item wins" means *the learner was wrong* — the opposite event from
what the learner's own `correct` flag records — so the item-side call's `correct` argument must be
`!correct`, not `correct`, for `actual` to mean the right thing relative to the already-complemented
`expected` the identity above produces. Concretely: **a learner answering CORRECTLY against a
harder-than-them item implies the item might be EASIER than currently estimated — its difficulty
estimate should move DOWN on a correct answer, and UP on an incorrect one — which is the OPPOSITE
direction from the ability-side update's own rule** (where a correct answer moves the LEARNER's
estimate up). Reusing `UpdateAbility` unmodified, with `correct` passed straight through, would move
the item's estimate in the ability-side direction instead — up after the learner answers correctly,
down after they answer incorrectly — exactly backwards. The `!correct` flip is what makes the shared
formula correct for both sides of the same match, not a shortcut that happens to look plausible.

This shares `UpdateAbility`/`KFactor`'s shape with a
**separate, smaller, faster-decaying config** — `Config.ItemK0`, `Config.ItemKMin`,
`Config.ItemDecayResponses` — matching research §3.1 step 3's requirement that an item's update
rate shrink with its OWN response count, not the learner's. **Honest boundary, stated per this
project's own Evidence-Based Claims principle rather than glossed over: unlike the ability-side
constants, the item-side constants are NOT POC-verified** — the POC implements ability updates only
(it hand-authors a static 17-item bank and never recalibrates it, research §4's own scope
statement). This plan proposes starting defaults (`ItemK0=0.2`, `ItemKMin=0.02`,
`ItemDecayResponses=50`) as a documented, configurable, and explicitly UNVALIDATED starting point —
consistent with spec.md's own NEEDS CLARIFICATION item on tuning constants, and with research §6's
warning that naive simultaneous two-sided Elo updating (both ability and item difficulty adapting
online from the same response stream) is a real, named failure mode, not a hypothetical one. These
defaults are a Phase 1 implementation choice, not a resolved clarification.

### Downgrade trigger and magnitude (User Story 2, FR-011/FR-012)

```go
// DowngradeTriggered reports whether the learner's last N responses in this
// area are ALL incorrect — a GENUINELY consecutive run, per spec.md's edge
// case ("wrong-wrong-correct-wrong has NOT met a 3-consecutive trigger").
// recent is ordered most-recent-first and is exactly cfg.DowngradeStreak
// entries (or fewer, in which case the streak cannot yet be met).
func DowngradeTriggered(recent []bool, cfg Config) bool {
	if len(recent) < cfg.DowngradeStreak {
		return false
	}
	for _, correct := range recent[:cfg.DowngradeStreak] {
		if correct {
			return false
		}
	}
	return true
}

// DowngradeReason renders FR-011's explicit, human-readable reason string,
// matching the POC's own exact wording (§4) so a reader of a production log
// and a reader of the POC's demonstration are reading the same sentence.
const DowngradeReasonTemplate = "downgrade: last %d attempts were all wrong -> " +
	"serving %.1f points easier than the normal nearest-to-ability pick, " +
	"to rebuild a run of correct answers before difficulty climbs again"
```

`Config.DowngradeStreak` defaults to 3, `Config.DowngradeMagnitude` to 1.5 points — the exact POC
values (research §3.3, §4) — both NEEDS-CLARIFICATION tuning constants per spec.md, both
configurable rather than hardcoded for the same reason as the K-factor constants above.

## 4. Where this plugs into the real platform

- `Store.ServeNext(session, area)`: cold start (§2 above) → normal nearest-`DifficultyEstimate`
  pick against the caller's current `AbilityScore` → downgrade override (`DowngradeTriggered` true
  over the session's last 3 `response_log` rows in this area) → mints and returns one
  `ServedQuestion` row.
- `Store.RecordResponse(token string, correct bool, gradedAnswer …) (RecordResponseResult, error)`:
  the practice-path idempotent transaction (§5.1). Looks up `served_question` by token; if already
  consumed, replays the `response_log` row it produced (§11.4.253 replay); else validates the token
  (FR-014), computes `UpdateAbility`, inserts `response_log`, upserts `ability_score`, marks
  `served_question.consumed_at`.
- `Store.RecordGradedResponse(session, area, question string, correct bool, gradedDifficulty float64,
  …) (RecordResponseResult, error)`: **the graded-path entry point — this closes a real contradiction
  an earlier revision of this document left standing, not merely adds a second convenience wrapper.**
  The claim that "one shared scoring pipeline" serves BOTH the practice-bank submit endpoint AND
  `AssessmentSubmitHandler` cannot be true of `Store.RecordResponse` alone, because that function's
  only described signature looks a response up **exclusively by `served_question.token`** — and the
  graded assessment path legitimately has no serving token to present (see the
  `AssessmentSubmitHandler` bullet below for why). `RecordGradedResponse` performs the SAME core
  update — `UpdateAbility`, the `response_log` insert, the `ability_score` upsert — through a shared
  unexported helper,
  `recordResponse(tx *sql.Tx, session, area, question string, correct bool, servedDifficulty float64,
  source ResponseSource, servingToken *string) (RecordResponseResult, error)`
  (`servingToken` is `nil` for the graded path, a real caller-supplied token for the practice path), so
  the algorithm-level "one pipeline" claim is genuinely true even though the two entry points have
  DIFFERENT call signatures for their DIFFERENT trust contexts: `RecordResponse` validates a token
  before calling the shared helper (FR-014's fail-closed check, §11.4.253's idempotency key);
  `RecordGradedResponse` skips that validation because it has a different, already-proven authorization
  (below) and calls the shared helper with `servingToken = nil`, in which case the shared helper mints
  a fresh internal token (the same `*passage.Minter` every other knowledge kind uses) to satisfy
  `response_log.serving_token`'s `NOT NULL UNIQUE` constraint — each graded `QuestionOutcome` still gets
  its own unique token, preventing an accidental double-insert of the *same* outcome, but presenting one
  is not the caller's responsibility on this path, because there is no prior serving event to reference
  it against.
- `AssessmentSubmitHandler` (`internal/api/lessons.go` line 690): after `ckit.Submit` succeeds, for
  each `ckit.Result`'s per-question `QuestionOutcome` (curriculum-kit's own type,
  `submodules/curriculum-kit/pkg/curriculum/assess.go`), call `Store.RecordGradedResponse` — **not**
  `Store.RecordResponse`, and with **no serving-token requirement** — with `Source: SourceGraded` (the
  graded path's own `AvailabilityOf`/lesson-gate already proves this session was entitled to attempt
  this question — a second served-question check here would be the "second gate"
  `AssessmentSubmitHandler`'s own comments explicitly warn against introducing, `lessons.go` lines
  797-800; that existing lesson-gate stands in for the serving-token check as THIS path's
  authorization, exactly the way the practice path's token stands in for it on that path).
- `GET /api/progress` (`internal/api/progress.go`): gains an `AbilityScoreSource` closure,
  `func(session string) (map[string]AbilityScoreSummary, error)`, mirroring
  `LessonCompletionSource`'s exact shape (lines 277-299) — same nil-is-legitimate, same
  source-failure-does-not-fault-the-whole-request discipline.
- `Store.RecalibrateBatch(ctx)` (User Story 3): reads `response_log` rows newer than its own
  last-run watermark (a small `recalibration_runs(id INTEGER PRIMARY KEY, at TEXT, rows_read
  INTEGER)` table, the same "a run is recorded separately from its output" shape
  `pkg/crossref`'s `crossref_runs` table already uses, `crossref.go` lines 143-172), folds each
  question's responses through the item-side `UpdateAbility` call with theta/difficulty swapped AND
  correctness inverted (`UpdateAbility(theta=itemDifficulty, servedDifficulty=learnerAbility,
  correct=!correct, cfg=itemCfg)` — see §3's "Item-difficulty update" above for why the flip is
  required), and upserts `item_difficulty`. Called
  on a cadence (`Config.BatchCadence`, proposed default: hourly-or-every-500-new-responses,
  whichever is sooner, matching research §3.4's proposed cadence — itself a NEEDS CLARIFICATION
  item in spec.md, not resolved here) from a small ticker inside `cmd/workshop-server/main.go`, never
  from the request path.

## 5. SQLite DDL

In the same idiom as `pkg/crossref/crossref.go` lines 160-172 and `pkg/authstore/authstore.go`
lines 42-59 — `CREATE TABLE IF NOT EXISTS`, explicit indexes on every column this feature's own
query shapes need, opened with `db.SetMaxOpenConns(1)` (matching `authstore.go` line 93's judgment
for a single-writer workload).

```sql
-- served_question: the FR-014 "was this session served this" check AND the
-- §11.4.253 idempotency key, in one table (see plan.md).
CREATE TABLE IF NOT EXISTS served_question (
  token             TEXT PRIMARY KEY,
  session           TEXT NOT NULL,
  area_id           TEXT NOT NULL,
  question_id       TEXT NOT NULL,
  served_difficulty REAL NOT NULL,
  served_at         TEXT NOT NULL,
  consumed_at       TEXT
);
CREATE INDEX IF NOT EXISTS served_question_session ON served_question(session, area_id, served_at);

-- response_log: FR-003's append-only audit trail. No application code path
-- in this feature issues UPDATE or DELETE against this table (§11.4.241
-- rung 1); the trigger below is the rung-5 backstop that makes an
-- application-code mistake structurally impossible rather than merely
-- unintended — closing the "A Rule Enforced by Nothing Is Not a Rule"
-- Constitution Check row at the storage layer, not only by review.
CREATE TABLE IF NOT EXISTS response_log (
  id                  TEXT PRIMARY KEY,
  session             TEXT NOT NULL,
  area_id             TEXT NOT NULL,
  question_id         TEXT NOT NULL,
  at                  TEXT NOT NULL,
  correct             INTEGER NOT NULL,
  served_difficulty   REAL NOT NULL,
  ability_before      REAL NOT NULL,
  ability_after       REAL NOT NULL,
  k_factor            REAL NOT NULL,
  downgrade_triggered INTEGER NOT NULL,
  reason              TEXT NOT NULL,
  source              TEXT NOT NULL CHECK (source IN ('practice','graded')),
  -- The §11.4.253 idempotency key. UNIQUE and NOT NULL: a second INSERT
  -- attempting the same serving_token fails at the DB level, which is what
  -- makes the replay-on-retry behaviour a DURABLE guarantee rather than an
  -- application-level check-then-insert race — a structural backstop, not
  -- an overstated claim of being the sole active mechanism: with
  -- db.SetMaxOpenConns(1) (§5's own opening decision, mirroring
  -- pkg/authstore's convention), this SQLite connection handle is
  -- single-writer by construction, so connection-pool serialization is the
  -- PRIMARY practical protection against a genuinely concurrent double-write
  -- in THIS deployment today. The UNIQUE constraint is what makes the
  -- guarantee durable and correct regardless of that deployment detail — it
  -- becomes the actively load-bearing mechanism the moment MaxOpenConns is
  -- ever raised above 1 (a real possibility this schema must not assume
  -- away), and it is what T012's own `-race`-under-concurrency proof
  -- exercises, since a single-conn pool alone would not be distinguishable
  -- from a correct concurrent implementation by that test.
  serving_token       TEXT NOT NULL UNIQUE
);
CREATE INDEX IF NOT EXISTS response_log_session_area ON response_log(session, area_id, at);
CREATE INDEX IF NOT EXISTS response_log_question ON response_log(question_id, at);

-- The FR-003 immutability backstop (SQLite trigger syntax; enforced inside
-- scoring.db regardless of which code path ever attempts a write).
CREATE TRIGGER IF NOT EXISTS response_log_no_update
BEFORE UPDATE ON response_log
BEGIN
  SELECT RAISE(ABORT, 'response_log is append-only: ResponseLogEntry rows are never mutated (FR-003)');
END;
CREATE TRIGGER IF NOT EXISTS response_log_no_delete
BEFORE DELETE ON response_log
BEGIN
  SELECT RAISE(ABORT, 'response_log is append-only: ResponseLogEntry rows are never deleted (FR-003)');
END;

-- ability_score: the current, fast-read number. One row per (session, area).
CREATE TABLE IF NOT EXISTS ability_score (
  session       TEXT NOT NULL,
  area_id       TEXT NOT NULL,
  ability       REAL NOT NULL,
  attempt_count INTEGER NOT NULL,
  updated_at    TEXT NOT NULL,
  last_entry    TEXT NOT NULL,
  PRIMARY KEY (session, area_id)
);

-- item_difficulty: the batch-updated, crowd-calibrated side (User Story 3).
-- Written ONLY by the batch job — see §4 above for why no synchronous path
-- writes this table.
CREATE TABLE IF NOT EXISTS item_difficulty (
  question_id         TEXT PRIMARY KEY,
  area_id             TEXT NOT NULL,
  difficulty_seed     REAL NOT NULL,
  difficulty_estimate REAL NOT NULL,
  response_count      INTEGER NOT NULL DEFAULT 0,
  updated_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS item_difficulty_area_estimate ON item_difficulty(area_id, difficulty_estimate);

-- recalibration_runs: "a derivation ran" recorded separately from "a
-- derivation's output" — the same shape pkg/crossref's crossref_runs table
-- already uses (crossref.go lines 143-172) for the identical reason.
CREATE TABLE IF NOT EXISTS recalibration_runs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  at         TEXT NOT NULL,
  rows_read  INTEGER NOT NULL,
  items_touched INTEGER NOT NULL
);
```

**Mutation-pairing owed (Constitution Check row "Isolation by Default"), named so it is not
silently dropped from tasks.md:**

1. A test that opens two concurrent `RecordResponse` calls against the **same** `serving_token` and
   asserts exactly one `response_log` row exists afterward, with the second call observed to
   replay rather than error or double-write.
2. A test that attempts a direct `UPDATE response_log SET correct = 1 WHERE id = ?` against a real
   `scoring.db` and asserts it fails with the trigger's own `RAISE(ABORT, …)` message — proving the
   rung-5 backstop actually fires, not merely that the Go API has no setter.
