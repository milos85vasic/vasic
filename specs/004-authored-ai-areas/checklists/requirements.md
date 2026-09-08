# Specification Quality Checklist: Authored AI/IT Knowledge Areas with Lessons, Tests and Video Anchors

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-07
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Validation record

Two iterations were run. Both findings are recorded rather than silently fixed,
because the second one is the kind this project's constitution exists to catch.

**Iteration 1 — three findings, all fixed in the spec:**

1. *No implementation details* FAILED. The draft named HTTP status codes and a
   route shape (`/api/areas/{id}/lessons`) in the defect table and in FR-018.
   Both were rewritten as behaviour — "the detail route refuses" became "a
   visitor can reach a listed area and be told it does not exist", and FR-018
   now states the listing/openability equivalence without naming a transport.
2. *Success criteria are technology-agnostic* FAILED on the original SC-008,
   which specified a millisecond seek tolerance against a player API. Restated
   as "within 1 second of the referenced moment", which a person can check.
3. *Requirements are testable* FAILED on the original FR-021, which said the
   palette must be "vivid". Replaced with a countable floor — distinct hue
   families across principal surfaces — carried into SC-010.

**Iteration 2 — one finding, fixed:**

4. *Success criteria are measurable* FAILED on SC-002 as first written. It said
   "substantially all published areas are AI/IT-relevant". "Substantially" is
   the guessing language §11.4.6 forbids, and it would have let a 60% outcome be
   argued into a pass. It now reads 100%, against the measured 3.9% baseline,
   with the classification required to be recorded rather than asserted.

**One item deliberately not marked as a defect.** SC-015 ("spends no time
waiting on a page that has not told them what it is doing") is a qualitative
criterion. It is kept because the checklist asks for both quantitative and
qualitative measures, and it is checkable by observation even though it carries
no number.

## Deliberate boundary — what this spec does NOT contain

Recorded so a later reader does not mistake absence for oversight:

- **No area titles, question text, transcript excerpts or personal names.** This
  specification lives in a PUBLIC repository and describes content held in
  PRIVATE submodules. Every quantity is a count or a location; none is content.
  This is the standing content-boundary rule, not a stylistic choice.
- **No architecture, schema or endpoint design.** Those belong to `/speckit-plan`.
- **No task decomposition.** That belongs to `/speckit-tasks`.

## Re-validation after `/speckit-clarify` — 2026-09-07

**16/16 → 16/16 items passing. No item changed state, and no item regressed.**
The clarifications strengthened requirements that already passed rather than
repairing ones that failed, which is the expected shape when clarify runs after
a spec that validated clean.

What moved, per item:

- *Requirements are testable and unambiguous* — was passing; now stronger. Three
  requirements that were testable but under-determined gained a decided value:
  the area set is bounded (FR-005a/b), the assessment provenance rule is stated
  (FR-008a), and the pass threshold is required to exist and be visible
  (FR-008b).
- *Success criteria are measurable* — was passing; three criteria added
  (SC-016..SC-018), each a count with a floor.
- *Edge cases are identified* — was passing; the served-vs-on-disk case was
  promoted from an edge case to a numbered defect (D8) and a requirement
  (FR-023a), because it was **observed live** during this session rather than
  imagined.
- *Dependencies and assumptions identified* — was passing; three assumptions
  moved from "reasonable default" to "decided, with the measurement that decided
  it", and are annotated as such.

**HONEST BOUNDARY — how these five clarifications were resolved.**
`/speckit-clarify` is specified as an interactive loop that puts one question at
a time to the operator. **No operator answered any of them.** They were resolved
by applying the skill's own recommendation, and each recommendation was derived
from a measurement taken on this tree during this session — not from preference
and not from convention. This is recorded here rather than left implicit,
because a decision presented as the operator's when it was not is exactly the
kind of unearned claim the project constitution forbids.

Every one is overturnable, and the way to overturn it is to dispute the
evidence cited beneath it in the spec's Clarifications section. Q1 (the area set
is the 37 authored subjects, not an evidence ranking) and Q5 (the 70% pass
threshold) are the two most likely to want an operator's own answer: Q1 is a
curriculum-scope decision, and Q5 is a number with no measurement behind it —
its requirement is that a threshold is *stated and visible*, which is the part
the evidence supports.

## Notes

- All items pass. Ready for `/speckit-plan`.
- Two clarifications are flagged above as most likely to want operator override.
  Neither blocks planning: Q1 changes which areas are in scope, not the shape of
  the capability, and Q5 changes one declared number.
