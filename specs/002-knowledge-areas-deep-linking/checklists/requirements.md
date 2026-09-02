# Specification Quality Checklist: Knowledge Areas & Bidirectional Deep Linking

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-01
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Every success criterion names its measurement method
- [x] Success criteria are technology-agnostic (with three recorded, justified exceptions)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded (three open clarifications, each with its scope impact stated)
- [x] Dependencies and assumptions identified
- [ ] No `[NEEDS CLARIFICATION]` markers remain — **3 remain, deliberately**

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria or a named success criterion
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No content boundary is crossed in either direction

## Counts

| Metric | Value |
|---|---|
| Functional requirements | **74** |
| Success criteria | **40** |
| User stories | **7** |
| `[NEEDS CLARIFICATION]` markers | **3** |
| Resolved decisions recorded | **4** |
| Assumptions recorded | **16** |

Counts are produced by enumerating the markers in `spec.md`, not by reading them off this table.
Re-derive:

```bash
rg -o '^\- \*\*FR-[0-9]+[a-z]?\*\*' spec.md | wc -l
rg -o '^\- \*\*SC-[0-9]+[a-z]?\*\*' spec.md | wc -l
rg -c 'NEEDS CLARIFICATION' spec.md
```

## Validation Record

Validation was run twice. Iteration 1 found six genuine issues; all six were addressed and
iteration 2 passed, except for the three clarification markers, which are deliberate. Both
iterations are recorded, because a checklist that shows only its final green state hides whether it
was ever capable of failing.

### Iteration 1 — 6 items failed

| Item | Finding | Resolution |
|---|---|---|
| Requirements are testable | An earlier draft asserted **"word-level timings: absent"** in the starting-state table. Measurement disproved it: a per-chapter word sidecar holds 15,610 word records with individual start and end times. Every precision requirement written against the false premise was therefore capped one level too coarse. | The claim is **withdrawn explicitly** in the spec under its own heading rather than quietly edited, per the repository's rule that a retracted figure is retracted visibly. FR-021 and SC-009 were rewritten to carry both precisions and to require each link to state which one it used. |
| Scope is clearly bounded | An earlier draft treated the workshop's taxonomy as starting from nothing. It does not: **5 areas already exist as prose**, in an adapted form of the reference skeleton, with no machine-readable representation. A spec that ignores them would have specified duplicating documents that already exist. | Added FR-008a: the existing prose areas are **promoted**, not ignored, duplicated or overwritten, and any disagreement between them and extraction is surfaced for a decision. Added to the starting-state table. |
| Requirements are unambiguous | "Search must say where a hit occurs" was written without noticing that the platform **already advertises a match-offset list and always leaves it empty**. Left as written, the requirement could have been signed off as already met by a field that is structurally incapable of carrying an answer. | FR-029 now names the condition directly: the field is either populated or removed, and its absence stated. The measured fact is in the starting-state table under its own row. |
| No implementation details | FR-021 names a "word-timing sidecar" and SC-015b forbids links "keyed on a timestamp" — both closer to design than to user value. | **Kept, as knowing exceptions.** The first is the only honest way to state a precision requirement, because the two precisions have genuinely different availability and conflating them is the defect the requirement exists to prevent. The second is a correctness constraint with a measured basis: the passage identifier survives correction and insertion and a timestamp does not, so a time-keyed graph rots silently while continuing to render. Recorded here rather than passed over. |
| Success criteria are technology-agnostic | **SC-030** ("zero active server-side CI workflows") names a delivery mechanism rather than a user outcome. | **Kept deliberately**, on the same basis feature 001 recorded: it is not a preference but a governing constraint whose violation is a release blocker with no exemption. Omitting it would let a later phase introduce one. |
| All functional requirements have acceptance criteria | The governance and evidence requirements (FR-053 to FR-059) appear in no user story's acceptance scenarios; they are covered only by success criteria. | **Accepted as covered, with the traceability made explicit** rather than implied: FR-053 by SC-027, FR-054 by SC-028, FR-055 by SC-027 and the evidence location it names, FR-056 by SC-030, FR-057 by SC-029, FR-058 by the platform's existing reuse criteria, FR-059 by SC-013 and the server-unity verifier it describes. |

### Iteration 2 — pass, with three markers deliberately left

The three `[NEEDS CLARIFICATION]` markers are **not** defects. Each is a question that materially
changes the size and the risk of the work, cannot be settled from evidence in the tree, and would
be answered wrongly by a default:

1. **Prose authorship of area materials.** The three options differ by an order of magnitude in
   scope, and the host has no generative model, so the choice is not academic.
2. **Whether "in videos" includes on-screen content.** Optical character recognition would add a
   second ingestion pipeline with its own accuracy obligation. The engine is present on the host, so
   the environment does not force the answer.
3. **Whether the answering defect is closed in this feature.** The measured fabrication rate on
   unanswerable questions and the undefended topically-related-but-non-answering case are real and
   open. The one option the spec forecloses is describing them as solved.

Everything else the description left unstated was decided rather than deferred, and each decision
records what was chosen, why it is the safest option, and what would reopen it — four under
**Resolved Decisions** and sixteen under **Assumptions**.

## Content boundary — checked in both directions

This specification lives in a **public** repository. Two boundaries apply and both were checked:

- **Outbound**: no transcript text, participant name, chapter title, chapter material or recording
  filename appears anywhere in this directory. Content is referenced by identifier, by count, or by
  measured property only. Verified by scanning this directory for the known-sensitive patterns; 0
  matches.
- **Inbound**: the reference module is a separate **private** repository. No content, question,
  model answer or fixture of its is reproduced here or specified for reproduction into the
  workshop — FR-004 and FR-004a state the rule and SC-029a measures it.

## Notes

- Check items off as completed: `[x]`
- The unchecked item is unchecked on purpose. It is not a to-do.
