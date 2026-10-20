# Specification Quality Checklist: UX Research Wave

**Purpose**: validate completeness and quality before implementation
**Created**: 2026-10-20 | **Feature**: [spec.md](../spec.md)

## Content quality

- [x] Every research proposal has an explicit disposition (in / deferred / rejected / out) with a reason
- [x] Stories are user-value statements, each independently testable
- [x] Private research content paraphrased by id; no chapter/transcript quotes
- [x] Platform facts cite file:line; unknowns marked UNCONFIRMED
- [x] MMR kept out per spec 017 and the operator brief; reconsideration routed to spec 026

## Requirement completeness

- [x] FR-001..FR-021 testable; mapped to tasks (below)
- [x] Success criteria measurable (corpus of recorded streams, axe counts, round-trip counts, baseline JSON)
- [x] Edge cases: auth header vs EventSource, dropped stream, withheld events, reduced motion, shortcut collisions
- [x] Rejected patterns from the research (§3) captured as a constraint (FR-018)
- [x] Dependencies explicit (spec 024 for observability of US1; spec 013 for persistence)
- [x] Open operator decisions D1-D7 listed with defaults

## Test/evidence discipline

- [x] Every implementation task preceded by a RED task with a named oracle
- [x] Deterministic tests (recorded streams, fake clocks, stubbed browser APIs)
- [x] LIVE verification per story: result.json + sha256 manifest, paired mutation
- [x] UI-visible acceptance step per story
- [x] Manual/guide/FAQ + four diagram-class tasks; export + independent validation tasks
- [x] Independent review tasks (Opus xhigh) per story and for the whole feature

## Traceability

| FR | Tasks | FR | Tasks |
|---|---|---|---|
| FR-001/002/003 | T009-T014, T015-T030 | FR-013 | T057-T063 |
| FR-004/006 | T016, T020, T025 | FR-014 | T064-T072 |
| FR-005 | T017, T021, T027 | FR-015 | T073-T082 |
| FR-007/008 | T031-T041 | FR-016 | T083-T091 |
| FR-009/010 | T042-T048 | FR-017 | T092-T099 |
| FR-011 | T048-T049 | FR-018/019 | T027, T017, T100-T117 |
| FR-012 | T050-T051 | FR-020/021 | T009-T010, T100-T109 |

## Notes

- Task ranges were generated from `tasks.md` (117 tasks: Setup T001-T008, Foundational T009-T014, US1 T015-T030,
  US2 T031-T041, US3 T042-T056, US4 T057-T063, US5 T064-T072, US6 T073-T082, US7 T083-T091, US8 T092-T099,
  Polish T100-T117).
