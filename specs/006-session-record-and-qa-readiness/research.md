# Phase 0 — Research

**Feature**: Session record per chapter + QA readiness · **Date**: 2026-09-08

Every decision was settled by a measurement taken on this tree, quoted with it.
Where a decision rests on judgement rather than measurement, that is said.

**No NEEDS CLARIFICATION entered this phase** — four were closed in the spec's
Clarifications section. What follows are the design decisions those did not
settle, plus three refuted hypotheses kept because each pointed the work in a
wrong direction before being killed.

---

## R1 — Where does the session record's data come from?

**Decision**: From `pipeline/extract/meeting_notes.py`, which already produced
all four sections into `curriculum/chapter-<slug>/knowledge/*.jsonl`. Build the
plan, the cumulative view, carry-forward and serving **around** it.

**Rationale.** The producer existed and was wired into the pipeline. The initial
brief said "0 matches inside `chapters/`", which was accurate and misleading —
the material lives under `curriculum/`. Forking the producer would have created
two extraction mechanisms for one record (§11.4.251) and, worse, two mechanisms
that could disagree about the same section.

**What was genuinely absent**: the plan, the cumulative view, carry-forward, the
empty-versus-unwritten distinction, and serving.

**Alternatives considered**: authoring the sections by hand (rejected — a
hand-maintained list drifts from what the pipeline produces); a second extractor
tuned for this feature (rejected — the fork).

---

## R2 — How is carry-forward computed so a point cannot vanish?

**Decision**: `plan(N) = unresolved points of plan(N−1) with slip+1` **plus**
chapter N−1's next-meeting points. Coverage is a recorded *input*, and **absence
of a decision resolves to `carried`**.

**Rationale, and it is the load-bearing design choice.** `Resolve` has **no
fourth branch**. A planned point is covered, carried, or dropped-with-a-reason;
there is no path by which it can be neither. **`vanished=0` therefore holds by
construction, not by diligence** — which is the only way it can hold across a
corpus nobody re-reads.

A drop recorded **without a reason is refused** and carries instead, so
"dropped" cannot become a quiet disposal route.

Ordering uses `curriculum.ChapterID.OrdinalPath`, which already exists. **A second
ordering is a second thing to disagree.**

**Measured**: 66 planned, 0 covered, 66 carried, 0 dropped, **0 vanished**; 436
items, 210 carried, max slip 2, one terminal outbox holding 42 points.

---

## R3 — Why is `covered: 0`, and why was a verdict refused?

**Decision**: `coverage_state: undecided`, and **no coverage verdict was
authored**.

**Rationale, in the deriving agent's own words**: judging coverage means matching
one heuristic extraction against another, and a text-match verdict would be *"a
guess wearing a decision's clothes"* — every downstream percentage would inherit
it.

The plan basis is weaker than an agenda and the record says so: it is a
**cue-phrase heuristic over ASR text** whose own docstring admits it misses
paraphrases. It is *what was said about the next session*, never *an agreed
agenda*.

**Chapter 01's plan is UNDETERMINED** — no predecessor, no recorded intent
anywhere. No plan was invented and **no coverage percentage is computed for it**.

**The operator has since asked for a machine PROPOSAL under review.** FR-007a is
what makes that compatible with the refusal rather than an override: a proposal
carries per-point evidence and confidence, is marked PROPOSED, and **the served
`coverage_state` must remain `undecided`** until a human confirms. A draft must
not move a published figure.

---

## R4 — Where do the four sections live on the wire?

**Decision**: **Both** — a `session_record` key on `GET /api/chapters/{id}`,
**and** three dedicated routes. The fourth is blocked.

**Rationale.** The embedded key was built first, deliberately avoiding
route-manifest churn, and it works: four sections, 126 carry-forward markers,
281 slip references, one outbox. But **four Angular components already existed**
for standalone routes, and the manifest carried four `NOT_BUILT` DEBT rows. The
data was reachable one way while the UI was built for another.

The operator chose to build the routes. The binding constraint is that both
surfaces **consume `pkg/sessionrecord`** rather than re-deriving — and the gate
must assert they agree, because *a route and a key that agree today are exactly
what drift*.

**`meeting-notes` is NOT built.** The manifest records that its withholding rule
**may not be guessed**, because one note is a content judgement left undecided
for the operator. FR-005a: a route built on a guessed withholding rule publishes
a judgement nobody made. That refusal is preserved, not routed around.

---

## R5 — REFUTED: "the platform is close to QA-ready"

**Refuted by an adversarial independent review, and recorded because the wrong
belief nearly shipped.**

Four headline claims were false against the running product:

| claimed | served |
|---|---|
| 30 areas with an assessment | **14** |
| 224 graded questions | **116** |
| lessons carry real content | **0 of 318** |
| four session sections served | **0** |

**The evidence machinery was never bluffing about what it measures.** It was
silent about what nothing measured: no gate checked bank-to-area reachability
across the population, no gate asserted a lesson body is non-empty, and the
server-unity gate exited **0** while printing four `NOT_BUILT` routes as recorded
debt — honest in its own output, but a "PASS" anyone could quote.

**Every one of the four sat in a blind spot.** That is why each fix ships the
missing gate alongside it, and why the constitution gained *A Gate's Population
Is Part of Its Claim*.

---

## R6 — REFUTED: "the catalog loader is broken"

The 13 unreachable banks looked like a loader defect. **It is not.**

`learning.Load` reads the catalog **once at process start**, deliberately and
documentedly. The server then answered *"this area's learning catalog carries no
end-of-area test"* — a claim about the **directory** — from a snapshot taken
hours earlier.

**The discriminating condition was time, not the areas and not the banks**: the
14 that worked had banks written at 07:13; the 13 that failed at 10:47; the
process started at 08:01.

**Fix: the snapshot may only assert what it licenses.** Staleness is four-valued
— `Fresh` / `Stale` / `StalenessUnknown` / `NoSource`. `NoSource` is separate on
purpose: an in-memory test catalog has no directory to have drifted from, so its
negatives still stand. A stale catalog returns **503** naming the changed files.

**Alternatives considered**: reload on every request (rejected — solves the
symptom at a cost the design deliberately avoided); watch the directory
(rejected — more machinery than the honesty requires).

---

## R7 — REFUTED: "the lesson bodies were lost"

They were **read, measured, and discarded** on every run.
`build_learning_catalog.py` parsed every section body, used it once for
`estimatedMinutes`, and never referenced it again.

**The reason is the interesting part: the shared library's `Lesson` had nowhere
to put it.** Its only text field was `Summary`, a one-line blurb the interface
renders as a muted paragraph. Writing a 4,563-word body with time links into a
field named `Summary` would have been a semantic lie, **so the builder correctly
dropped it rather than lying.**

**Therefore the fix belonged upstream**, in `curriculum-kit`, not in the
consumer — and a consumer-local field would have failed the **entire directory
load**, because `DecodeDocument` calls `DisallowUnknownFields()`.

`Body` is **optional** in the kit by deliberate choice: a materials-only lesson
is legitimate, so "every lesson must have a body" is a *consumer policy* the
library may not impose. A test records that choice so a future rule requiring one
must change a test that explains its absence.

**Measured**: 339 of 339 at source, **318 of 318 served**, median 328 words,
longest 4,563. Twelve lessons under 100 words were **left short** — converted,
not padded.

---

## R8 — How is the answer key kept off the wire?

**Decision**: A `QuestionForTaking` projection built as a map with **no answer
field at all** — not the domain type with fields omitted.

**Rationale.** The kit's `Question` carries `CorrectChoices`/`Explanation` with
`omitempty`, so **marshalling the type directly would ship the key** the moment a
question had one. Omission depends on every future field remembering to omit
itself; **absence does not**.

**And the lock was bypassable one route over.** The practice deck and the graded
bank are the same authored rows emitted twice — **224 of 224 match by prompt, 0
of 224 by id**. So gating `/practice` would have deleted a feature the contract
intends. The defect was the *disclosure*: answers are now withheld for graded
rows, and the withholding **says so** rather than silently omitting.

**Fail-closed on the R6 finding**: nil catalog, load error **or stale snapshot**
withholds every key, because a graded prompt the snapshot never saw would look
"graded nowhere" to a literal index and be published.

---

## R9 — What makes a QA document usable by someone who has never seen this?

**Decision**: Every scenario states its expected result **before** the tester
acts; every known limitation is disclosed **in advance**; the build identifier is
recorded.

**Rationale.** A step that says only "click X" makes the tester the oracle, and
they have no basis to be one. And **a tester must never discover a known
limitation as if it were a defect** — re-finding what we already know is the most
expensive way to spend a QA team's time.

**The documents must be regenerated, not patched** (FR-020a). Written at 12:30
against the pre-rebuild product, they describe 14 areas with tests and 0 lessons
with content; live is 27 and 318 of 318. **A stale expected-result column
manufactures false defects** and spends a tester's day disproving our own fixes.

---

## R10 — What does the client see, and what is disclosed?

**Decision**: Disclose three facts up front (FR-020b) — 39 areas served against
42 authored, 12 carrying no test with the reason, and every score indeterminate.

**Rationale.** Each has a good reason, and **the reasons demonstrate the
anti-bluff discipline rather than apologising for it**. A gap discovered live is
worse than one disclosed first. The alternative — demo only the 27 areas with
tests — is legitimate for a demo but leaves an undisclosed gap one click away in
a catalogue showing 39.
