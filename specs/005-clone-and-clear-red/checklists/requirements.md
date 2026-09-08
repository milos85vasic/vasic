# Specification Quality Checklist: A Repository That Clones, and a Fleet With No Unexplained Red

**Purpose**: Validate specification completeness and quality before planning
**Created**: 2026-09-08
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
- [x] Success criteria are technology-agnostic
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

Three iterations. Every finding is recorded rather than silently corrected.

**Iteration 1 — two findings, both fixed:**

1. *No implementation details* FAILED. The draft named a specific large-file
   storage mechanism and a specific hosting product as the remedy for R1. Both
   were removed: FR-002 now states the property ("MUST NOT be carried in the
   object store in a way that makes obtaining the repository fail") and leaves
   the mechanism to planning. Naming the remedy in the spec would have foreclosed
   the comparison that belongs in `/speckit-plan`.
2. *Requirements are testable* FAILED on the first FR-016, which said the palette
   must be "richer". Replaced with a countable property carried into SC-012.

**Iteration 2 — one finding, fixed:**

3. *Success criteria are measurable* FAILED on SC-002, first written as "the
   repository is substantially smaller". `Substantially` is the guessing language
   the constitution forbids and would have let any reduction be argued into a
   pass. It now states **under 250 MB against a 2,624.8 MB baseline** — a number
   chosen so a normal clone is unremarkable, and stated before any remedy was
   selected so the remedy cannot set its own target.

**Iteration 3 — one finding, fixed, and it is the one that matters most:**

4. *Requirements are unambiguous* FAILED on the first version of FR-010, which
   said reds must not be closed "inappropriately". That word decides nothing. It
   now forbids weakening the instrument and requires that **any threshold,
   bucket, allow-list or baseline change be justified by a principle stated
   independently of its effect on the resulting count** — which is checkable,
   because the justification either exists before the number or it does not.

## The load-bearing design decision in this spec

**Success is NOT "every gate green", and the spec says so twice.** SC-008 counts
*unexplained* reds, not reds. SC-011 splits areas that cannot carry an
assessment for a **structural** reason (must reach 0) from those the corpus
genuinely cannot support (reported honestly, expected to remain).

This was deliberate. A specification demanding all-green would be satisfied
fastest by exactly the moves the constitution forbids — lowering a floor,
allow-listing a row, re-baselining a count — and would turn the instruments into
decoration. The measured precedent is in this very tree: a palette gate's
"4 hue families" was three-quarters an artefact, and correcting it moved the
number **down** to 2. An all-green target would have made that correction look
like a regression and discouraged it.

## Deliberate boundary — what this spec does NOT contain

- **No area titles, question text, transcript excerpts or personal names.** This
  spec lives in a PUBLIC repository and describes work in PRIVATE submodules.
  Every quantity is a count or a location.
- **No remedy selection for R1.** Comparing large-file storage against
  out-of-repository hosting belongs to `/speckit-plan`, and both must be weighed
  against the standing prohibition on history rewriting.
- **No task decomposition.** That is `/speckit-tasks`.

## Notes

- All 16 items pass. Ready for `/speckit-clarify`.
- Strongest clarification candidates, in priority order: (a) where recorded
  material should live once it leaves the object store, and who may reach it;
  (b) whether the 387 baselined path occurrences are in scope or stay declared;
  (c) whether the 6 provider rows on hosts with no read-only adapter should get
  an adapter or stay permanently undetermined.
