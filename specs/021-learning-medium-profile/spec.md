# Feature Specification: Learning-Medium Profile and Best-Method Recommendation

**Feature Branch**: `021-learning-medium-profile`

**Created**: 2026-10-20

**Status**: Draft

**Input**: Jordan client requirements document (`workshop/docs/research/clients/jordan/client-requirements-and-context.md`),
requirement **REQ-1** (per-participant learning-medium signal) and **REQ-4** (best-method detection and
routing). Gap analysis of 2026-10-20 recorded that **no spec covers either**: spec 012 defers "best learning
medium per student" as out of scope, spec 013 models one ability number per area and no medium, specs
014/015 do not mention it.

**Builds on** (extends, never duplicates):
- `specs/013-adaptive-assessment-scoring` — the append-only `ResponseLogEntry` log and the Elo expected-score
  function. This feature READS that log; it adds no second response store.
- `specs/015-universal-content-model-profile` — the `/profile` page conventions (session identity via
  `sessionOf`, read-only aggregation endpoints, hand-rolled SVG charts, 200/4xx/503 discipline). This feature
  adds a sibling route and sibling endpoints; it does not edit 015's files.
- `specs/011-multi-provider-llm-providers` — **not used**. This feature contains no model call by design (FR-008).

## Research Summary *(informational — not a requirement)*

Measured against the code on 2026-10-20 (all paths relative to `workshop/`):

- There is **no learning-medium or learning-style mechanism anywhere in platform code**. The only vocabulary that
  could seed one is the closed question-kind set `mcq` / `short` / `flashcard`
  (`platform/backend/pkg/assessment/question.go:51-53`) and the closed lesson-material kinds
  `illustration` / `diagram` / `scheme` / `graph` / `video` / `document`
  (`submodules/curriculum-kit/pkg/curriculum/model.go:32-43`).
- The per-learner outcome records that exist **today** are thin: `Position` stores only the *latest* reading
  position per chapter (`platform/backend/internal/api/progress.go:33-38`); `ckit.Progress` stores lesson state
  without timestamps plus timestamped graded-assessment `Attempt`s
  (`submodules/curriculum-kit/pkg/curriculum/progress.go:33-68`); the existing assessment progress type is
  unwired (`platform/backend/pkg/assessment/progress.go:43-56`). **None of these can support a per-medium
  comparison.** The medium signal is therefore **blocked on spec 013's response log** for any outcome-based
  evidence (13's `ResponseLogEntry` records session, area, question, time, correctness, served difficulty and
  ability-before — everything this feature needs — see `specs/013-adaptive-assessment-scoring/data-model.md` §1.1).
- Only **machine-gradable** questions give a trustworthy success/failure: the curriculum-kit marker sets
  `Graded=false` for every `KindShort` question (`submodules/curriculum-kit/pkg/curriculum/assess.go:213-220`).
  Flashcard grading semantics in spec 013's submit path are **UNCONFIRMED** (task T004 settles it before the
  algorithm's evidence rule is frozen).
- Spec 013's expected-score function (`ExpectedScore(theta, d, D)` base-10 logistic, `D = 1.5`,
  `specs/013-adaptive-assessment-scoring/data-model.md` §3) makes a **difficulty-adjusted** comparison possible
  without any new modelling: *observed minus expected* per response.

Design consequence, stated up front: the feature measures **how a learner performs with each format compared with
what their own ability and the item difficulty predicted**, and says "no clear preference" or "not enough evidence"
far more often than it names a winner. It does not type people ("you are a visual learner"); see `research.md` §1
for why (the matching-style-to-instruction claim is contested in the literature — a research task, R-1, will cite
primary sources rather than assert it).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A learner sees which question formats are working for them, with the evidence (Priority: P1)

A signed-in learner who has answered practice and graded questions opens a "How I learn best" page. For each
question format they have used (multiple choice, short answer, flashcard) they see how many answers the platform
has on record, how many could be machine-marked, and how their results compare with what their ability and the
question difficulty predicted. The page names a format only when the evidence supports it; otherwise it says
plainly that there is not enough evidence, or that no format stands out. Every statement links to a count the
learner can verify.

**Why this priority**: REQ-1 is the highest-ranked client requirement that no spec covers. It is also the
precondition for REQ-4: a recommendation without a defensible signal is a guess.

**Independent Test**: Seed a deterministic learner (fixture of response-log rows, no model call). Open
`GET /api/profile/medium` and the `/profile/medium` page; the numbers equal an independently computed reference
(Python oracle) and the page shows the same counts.

**Acceptance Scenarios**:

1. **Given** a learner with at least `n_min` machine-graded responses in each of two formats and a clear
   difference, **When** they open the page, **Then** the better format is labelled `preferred` or `leaning`
   (per thresholds), with observed correct, expected correct, count, and the gap.
2. **Given** a learner with fewer than `n_min` graded responses in a format, **When** they open the page,
   **Then** that format reports `insufficient_evidence` and **no format is recommended** from it.
3. **Given** a learner whose only data for a format is short-answer responses (never machine-marked),
   **When** they open the page, **Then** that format reports `not_measurable` and the page says why.
4. **Given** a learner with zero responses, **When** they open the page, **Then** an explicit "nothing recorded
   yet" state appears (HTTP 200, zero counts), not an error and not a blank.
5. **Given** the scoring store is unreadable, **When** the page loads, **Then** it shows a determined
   "unavailable" state with the reason, never an empty profile that reads as "no data".

---

### User Story 2 - A learner gets an explainable per-area recommendation and can override it or switch it off (Priority: P1)

For a knowledge area, the learner can ask "what should I try here?". The answer is one of: a recommended
format with the plain-language evidence behind it, "no recommendation yet" with the reason, or their own pinned
choice. The learner can pin a format, return to automatic, or turn the feature off entirely; the choice is
honoured on every surface and is stored only against their own session.

**Why this priority**: REQ-4 ("detection and routing") plus the privacy requirement that the person, not the
platform, has the last word.

**Independent Test**: Call `GET /api/profile/medium/recommendation?area=<slug>` for fixtures covering every
signal state; assert the response, the explanation payload and that `PUT .../preference` changes the answer on
the very next call.

**Acceptance Scenarios**:

1. **Given** a `preferred` format overall but insufficient area-level evidence, **When** the learner requests
   the area recommendation, **Then** the response says `scope: "overall"` — it never presents an overall
   result as area-specific.
2. **Given** the learner pinned `flashcard`, **When** they request any recommendation, **Then** the answer is
   `learner_pinned` with `flashcard`, regardless of the evidence, and the evidence is still shown.
3. **Given** mode `off`, **When** any medium endpoint is called, **Then** no derived signal or recommendation
   is returned (the state is `off_by_learner`), and nothing is computed for display.
4. **Given** any recommendation, **When** inspected, **Then** it contains the list of evidence references
   (response-log entry ids) it was computed from.

---

### User Story 3 - The recommendation is visible where the learner studies, and acting on it is one click (Priority: P2)

On a knowledge-area page and on the practice page the learner sees a small, dismissible hint ("flashcards have
gone better than expected for you on this area — see why"). The practice page offers a format selector that
filters the practice deck to the chosen question kind. The selector works whether or not a recommendation exists.

**Why this priority**: makes REQ-4's "routing" real for the learner without changing server-side question
selection (that is deferred, FR-011).

**Independent Test**: Playwright: with the seeded learner, the area page shows the hint; the practice page
selector filters the deck to flashcards; dismissing the hint persists for the session only.

**Acceptance Scenarios**:

1. **Given** a recommendation exists, **When** the area page loads, **Then** the hint shows the format and a
   "why" link to `/profile/medium`.
2. **Given** no recommendation exists, **When** the area page loads, **Then** no hint is shown and no empty
   placeholder appears.
3. **Given** the selector set to `flashcard`, **When** the deck loads, **Then** only flashcard-kind questions
   are shown; selecting "all" restores the full deck; an area with zero questions of that kind says so.

---

### User Story 4 - Learners may opt in to format-engagement signals (text, recording, transcript, visuals) (Priority: P3)

Outcome-based evidence only exists for questions. To say anything about *reading vs. watching vs. looking at
diagrams*, the platform would have to record engagement events it does not record today. This story adds that
capture **only after an explicit, revocable opt-in, default OFF**, and with a deliberately tiny event shape.

**Why this priority**: it is the only way to cover the "content format" half of REQ-1, but it is new personal
data and therefore last in line and consent-gated.

**Independent Test**: With consent off, the events endpoint refuses (and stores nothing); with consent on, it
accepts only the closed event shape; reset removes every stored event.

**Acceptance Scenarios**:

1. **Given** consent is off, **When** the client posts an engagement event, **Then** the server answers
   `403 consent_required` and persists nothing.
2. **Given** consent is on, **When** an event with a field outside the closed shape (free text, URL, passage text)
   is posted, **Then** it is rejected `400` and nothing is stored.
3. **Given** the learner revokes consent, **When** they confirm "delete my engagement events", **Then** the
   rows are gone and a subsequent read shows zero.
4. **Given** engagement exists for a format, **When** the medium page renders, **Then** it is shown as
   **activity** (how much time was spent), never as **performance** — time spent is not evidence of learning.

---

### User Story 5 - The server can bias question selection toward the learner's better format (Priority: P4) — BLOCKED

Server-side routing: spec 013's next-question selection takes an optional medium preference. **No implementation
tasks until (a) spec 013's `ServeNext` exposes an options seam and (b) the operator decides whether adaptive
serving may be influenced by an inferred preference at all** (OD-2). Recorded so the dependency is visible, as
spec 011 recorded its own blocked story.

### Edge Cases

- A learner answers the same question many times: each response is its own observation (013 keeps them);
  evidence counts attempts, not distinct questions; the page states the attempt count.
- All of a learner's graded evidence is in one format: no comparison is possible → `insufficient_evidence` for
  comparison, per-format numbers still shown.
- Ties and near-ties: a gap below the gap threshold is `no_clear_preference`, never the larger mean by default.
- Learner switches the area difficulty mid-way: the residual already conditions on difficulty and ability at
  the time of each response (values stored in the log, FR-003).
- Re-ingest of the corpus: the medium profile derives from the 013 store, which is outside the index database
  and survives re-ingest (013 plan, "Storage placement decision"); an area that no longer exists is reported
  under `retired_areas`, never silently dropped.
- Very long history: at most `MaxObservations` (default 5000) newest rows are read; `truncated: true` is returned
  when the cap bites. Never a silent partial.
- Two browser tabs change the preference concurrently: last write wins; the response carries `set_at`.
- Anonymous (`X-Session` only) learner: supported exactly as 015 supports it; consent and override are keyed by
  that session value and lost with it — stated in the UI.
- A learner with `off` mode and a stored override from before: `off` wins and is never silently reset.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST define a closed `Medium` vocabulary. Question mediums are exactly the values of
  `assessment.Kind` (`mcq`, `short`, `flashcard`). Format mediums (`lesson_text`, `recording`, `transcript`,
  `visual`, `document`) exist ONLY in the US4 engagement path. A value outside the set is rejected, never stored.
- **FR-002**: All evidence MUST come from the requesting learner's own recorded responses. No other learner's
  data, no cohort or population statistic, and no comparison to "other learners" may be read, computed or shown.
- **FR-003**: Performance evidence MUST be difficulty-adjusted: for each machine-graded response the residual
  `correct − expected` uses the `ability_before` and `served_difficulty` values already stored in the response
  log entry. The residual MUST NOT be recomputed from the item's *current* difficulty estimate (which drifts).
- **FR-004**: Only machine-graded outcomes count as performance evidence. Ungraded responses (every `short`
  today) and self-reported outcomes count as **activity** and never as success or failure. A medium with no
  machine-graded evidence by construction reports `not_measurable`.
- **FR-005**: The signal states are the closed set `insufficient_evidence`, `no_clear_preference`, `leaning`,
  `preferred`, `not_measurable`, `off_by_learner`. Classification MUST follow the thresholds in
  `contracts/medium-signal-algorithm.md` and be configuration-driven (`n_min`, `gap_min`, `z_leaning`,
  `z_preferred`); the shipped defaults are PROPOSED and carry the simulation evidence of SC-009.
- **FR-006**: When evidence is insufficient the system MUST NOT recommend a medium and MUST NOT fall back to a
  default medium. "No recommendation yet" is a first-class answer with a reason.
- **FR-007**: Every signal and recommendation MUST carry an explanation payload: counts, observed correct,
  expected correct, mean residual, standard error, the thresholds applied, and the evidence references (response
  entry ids). A reviewer MUST be able to reproduce the figure by hand from the payload (worked example in
  `data-model.md`).
- **FR-008**: The inference MUST be deterministic and model-free: identical inputs give byte-identical output
  independent of row order, wall clock and locale; no random numbers, no network, no LLM. Enforced by a static
  gate (SC-006) and a shuffle/repeat test (SC-002).
- **FR-009**: The learner MUST be able to set `auto` (default), `pinned(medium)` or `off`. The setting always
  wins over evidence, is applied on every medium endpoint, and is stored only against the learner's session.
- **FR-010**: Recommendations are per-area with an overall fallback. An area needs its own `n_min`; otherwise
  the response says `scope: "overall"`.
- **FR-011**: The recommendation is ADVISORY. This feature MUST NOT change which question the server serves
  next (that is User Story 5, blocked).
- **FR-012**: The learner MUST be able to delete everything this feature persists about them (preference,
  consent, engagement events). The response log belongs to spec 013 and is append-only (013 FR-003); the UI
  states that it is untouched, and an erasure-versus-audit policy for it is an operator decision (OD-4).
- **FR-013**: Identity is the platform's existing session identity (`sessionOf`). No endpoint of this feature
  returns data for any session other than the caller's — including for `admin` role (no per-learner admin view
  in this feature; see Blocked-on-client-identity).
- **FR-014**: When the scoring store is unreadable or absent, endpoints MUST return the platform's determined
  `503 unavailable` envelope with a reason code; never an empty-but-200 body.
- **FR-015**: A learner with zero recorded responses MUST receive HTTP 200 with zero counts and an explicit
  empty-state flag.
- **FR-016**: Engagement capture (US4) MUST be off by default, MUST require an explicit consent call, MUST
  accept only the closed event shape (`medium`, `area`, `duration_bucket`, `at`), and MUST be rate-limited and
  size-bounded. Engagement is never fed into the performance signal.
- **FR-017**: UI wording MUST describe performance with a format on the learner's own data and MUST NOT label
  the person (no "visual learner", no style types).
- **FR-018**: The state vocabulary, reason-code vocabulary and unavailable-code vocabulary MUST be mutually
  disjoint (a disjointness test mirrors `pkg/answer`'s `DisjointVocabularies`).
- **FR-019**: Boot invariants (constitution §11.4.254): the feature declares its capability-matrix row; with the
  scoring store absent the routes register but answer 503 `scoring_store_absent`; an invalid threshold
  configuration refuses to start.
- **FR-020**: At most `MaxObservations` newest rows are read; `truncated` is reported honestly.

### Key Entities

- **Medium**: closed vocabulary value (FR-001).
- **Observation** (derived, never stored): one response seen through the medium lens: session, area, medium,
  graded?, correct?, expected, residual, at, evidence ref.
- **MediumEvidence**: per (medium, scope) aggregate: `n_total`, `n_graded`, `observed`, `expected`, `mean_residual`,
  `std_error`.
- **MediumSignal**: per (medium, scope) state ∈ FR-005 set plus explanation.
- **Recommendation**: per area (or overall): chosen medium or none, reason code, scope, evidence refs, `overridden`.
- **Preference**: the learner's mode and optional pinned medium, `set_at`.
- **Consent / EngagementEvent**: US4 only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a golden fixture of ≥ 3 learners × ≥ 2 areas, every number returned by the algorithm equals an
  independently produced reference (Python script, separate author/agent, same fixture) to 1e-9, and the
  hand-worked example in `data-model.md` reproduces exactly.
- **SC-002**: The same fixture, fed in 100 random row orders and repeated 100 times, produces byte-identical JSON.
- **SC-003**: Cross-learner isolation: with two seeded learners, 0 of N requests (N ≥ 200, both directions,
  authenticated and `X-Session`) return any datum of the other; a mutated handler that ignores the session
  makes the test fail (paired mutation, constitution §1.1).
- **SC-004**: 100% of non-empty recommendations carry ≥ 1 evidence reference and the thresholds applied; 0
  recommendations are produced from `insufficient_evidence` (property test over generated fixtures).
- **SC-005**: 100% of override modes are honoured on the very next request across all endpoints (matrix test).
- **SC-006**: `go list -deps ./pkg/medium` contains none of `net/http`, `pkg/answer`, `pkg/entail`, `math/rand`,
  `time.Now` use outside the injected clock (static gate with paired mutation).
- **SC-007**: UI-visible: an operator can open `/profile/medium` for a seeded demo learner and see the three
  states (`preferred`, `no_clear_preference`, `insufficient_evidence`) rendered, plus the area-page hint and the
  practice selector (acceptance script in `quickstart.md`).
- **SC-008**: Reset removes 100% of persisted preference/consent/event rows for the session (row-count oracle).
- **SC-009**: Simulation (fixed seed, 1000 learners each): with **no** true format effect, ≥ 95% of simulated
  learners at 30 graded answers per format are classified `no_clear_preference` or `insufficient_evidence`
  (false-preference control); with a true +0.20 residual effect in one format, ≥ 80% reach `leaning` or
  `preferred` (power). If the shipped thresholds miss either bound, the thresholds are retuned and the evidence
  re-captured; the numbers are measured, not assumed.
- **SC-010**: Live verification writes `evidence/live/result.json` plus a sha256 manifest from the running stack
  (task T052), and the documentation set (manual, guide, FAQ, four diagrams) exists and is exported.

## Assumptions

- Spec 013 lands its response log and exposes (or accepts a small read-only addition for) per-session response
  rows; until it does, only the pure algorithm (US1a) is buildable and the integration tasks are BLOCKED.
- Flashcard outcomes are machine-graded or self-reported — settled in T004; the default here treats
  self-reported as activity only.
- The platform serves authenticated learners as in spec 015; anonymous `X-Session` use remains supported.
- Default thresholds (`n_min=8`, `gap_min=0.10`, `z_leaning=0.67`, `z_preferred=1.28`) are PROPOSED starting
  points to be validated by SC-009; they are not calibrated facts.

## Dependencies and Blockers

| Dependency | Needed for | Status (2026-10-20) |
|---|---|---|
| Spec 013 response log + read access (013 US1 checkpoint T025) | all evidence (US1, US2 integration) | 013 has 0/52 tasks done — **BLOCKED**; pure algorithm unblocked |
| Spec 015 `/profile` conventions and `sessionOf` | route/handler conventions, link from profile | 015 has 0/46 tasks done — convention-only dependency; no code needed from it |
| Spec 011 | none (no model call) | n/a |
| Wave-0 hook split of `main.go` / `app.routes.ts` / `core/vocabulary.ts` | registration of routes, flags, vocabulary | orchestrator-owned, **not yet performed** |
| Operator decisions OD-1…OD-5 (below) | thresholds, privacy policy, scope | open |

**Blocked on unresolved client identity (not invented here).** REQ-1 is phrased per *participant*, from feedback
whose originating organisations ("ACS consulting", "Valaeon", and the failed "Drall platform") the research
document records as UNCONFIRMED (its §6). Consequences that this spec deliberately does **not** guess at:
(a) whether an instructor/consultant is meant to see participants' signals — this feature is **learner-only**;
any teacher/consultant view needs a role-and-workspace model that does not exist (see stub spec 023) and a
privacy decision; (b) whether the client expects medium-level reporting per cohort — **not built**; (c) which
legal data-protection regime governs retention — **UNCONFIRMED**, operator/legal decision OD-4.

## Open operator decisions

- **OD-1** Accept or retune the PROPOSED thresholds after SC-009's measured evidence.
- **OD-2** May an inferred preference ever influence server-side serving (User Story 5)? Default: no.
- **OD-3** Ship US4 (engagement capture) at all, and if so is the opt-in default OFF (this spec's position)?
- **OD-4** Retention/erasure policy for the append-only response log versus a learner's request to be forgotten
  (013 FR-003 forbids mutation); applicable data-protection regime for the Jordan-based client is UNCONFIRMED.
- **OD-5** Instructor/consultant visibility of participants' signals (blocked on client identity and on a
  role/workspace model).
