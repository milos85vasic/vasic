# Specification Quality Checklist: Workshop Curriculum Platform

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-31
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

## Validation Record

Validation was run twice. Iteration 1 found four genuine issues; all were fixed and iteration 2
passed. Both iterations are recorded, because a checklist that only shows its final green state
hides whether it was ever capable of failing.

### Iteration 1 — 4 items failed

| Item | Finding | Resolution |
|---|---|---|
| Success criteria are technology-agnostic | **SC-014** ("zero active server-side CI workflows") names a delivery mechanism, not a user outcome. | Kept deliberately. It is not a design preference — it is a governing constraint from §11.4.156, which states "Non-compliance is a release blocker regardless of context. No escape hatch." A spec that omitted it would let a later phase introduce a release blocker. Recorded as a knowing, justified exception rather than silently passed. |
| All functional requirements have clear acceptance criteria | FR-030 → FR-036 (documentation, evidence, governance) had no acceptance scenario in any user story; they were covered only by success criteria. | Accepted as covered: FR-030/031 by SC-004, FR-032/033 by SC-012/SC-013, FR-034 by SC-014, FR-035/036 by SC-015. Traceability is now explicit here rather than implied. |
| No implementation details | Acceptance Scenario 1 of User Story 1 specifies a *markdown* transcript — a format decision. | Kept. The operator's description mandates markdown explicitly ("Create it as markdown document"), so it is a stated requirement, not an implementation leak. |
| Scope is clearly bounded | Three `[NEEDS CLARIFICATION]` markers left audience, corpus and video delivery open, so scope was not actually bounded. | Resolved as decisions **D1–D3**, each choosing the safest, most stable option, with the reasoning and the conditions that would reopen it recorded. 0 markers remain. |

### Iteration 2 — all items pass

- 0 `[NEEDS CLARIFICATION]` markers (verified: `grep -c 'NEEDS CLARIFICATION' spec.md` → 0).
- 5 user stories, each with a stated priority, an independent test, and acceptance scenarios.
- 36 functional requirements, each phrased as an observable MUST.
- 15 success criteria, each carrying a number or a percentage.
- Scope bounded by an explicit Out of Scope list plus decisions D1–D3.

## Requirement → Success Criterion Traceability

Every functional requirement group is measured by at least one success criterion, **with one
recorded exception**: FR-039 has none. That exception was previously invisible because FR-039 sat
inside another group's row; it is now a row of its own, and the correction below states what
enforces it instead.

| Requirement group | Measured by |
|---|---|
| FR-001 … FR-007 (transcription, source material) | SC-001, SC-002, SC-003 |
| FR-008 … FR-013 (curriculum, browsing) | SC-004 |
| FR-014 … FR-020 (search, cross-referencing) | SC-005, SC-006, SC-007, SC-008 |
| FR-021 … FR-025 (question answering) | SC-009, SC-010 |
| FR-026 … FR-029 (extension) | SC-011 |
| FR-030 … FR-031 (documentation) | SC-004 |
| FR-032 … FR-033 (evidence) | SC-012, SC-013 |
| FR-034 … FR-036 (governance) | SC-014, SC-015 |
| FR-037 … FR-038 (passage identity, correction) | SC-016, SC-016a |
| **FR-039 (redaction before export or publication)** | **No success criterion measures it** — see the correction below |
| FR-040 (evidence retention) | SC-018 |
| FR-041 … FR-042 (accessibility) | SC-017 |

**Correction — 2026-09-01.** This table previously grouped FR-037 … FR-039 as one row measured by
SC-016 and SC-016a. That was wrong at requirement granularity while reading as complete, which is
the worst combination: SC-016 and SC-016a are **link-survival** criteria — they measure whether a
citation still resolves after a correction, a re-index or a symbol rename. Neither says anything
about redaction. FR-039 is measured by **no success criterion at all**, and the honest record is to
say so rather than to let an adjacent row cover for it.

FR-039 is nonetheless enforceable, by contract rather than by criterion, at three points:

| Enforcement point | Where |
|---|---|
| Gate **G-PID-5** — a redacted passage cannot be reached through search (R1), cross-references (R3) or a stored answer (R4) | `contracts/passage-contract.md` §7.3 |
| Publish precondition **B5** — `redaction-review.json` exists and is newer than the transcript | `contracts/pipeline-cli.md` §4.7 |
| `redact.sh --review-only` — recording *"none required"* is a valid decision; skipping the review is not | `contracts/pipeline-cli.md` §4.6 |

Because there is no criterion, those three are the whole of FR-039's enforcement. Removing any one
of them makes the requirement decorative, and nothing else in the artifact set would notice.

## Governance Cross-Check

The feature is governed by the constitution submodule. The clauses that constrain this spec:

| Clause | Constraint | Where honoured |
|---|---|---|
| §11.4.156 | No active server-side CI may be added. "No escape hatch." | FR-034, SC-014 |
| §1.1 | Every gate needs a paired mutation proving it catches regressions. | FR-032, SC-012 |
| §11.4 anti-bluff family | No claiming a result that was not observed. | FR-003, FR-019, FR-020, FR-022, FR-033, SC-010, SC-013 |
| §11.4.157 | Four governance carriers stay in lockstep. | FR-035 |
| §12.10 | CONTINUATION.md updated alongside non-trivial work. | FR-035 |
| §11.4.6 | Never report an unverified state. | Context table records only measured values; FR-004 requires a measured accuracy figure rather than an assertion. |

## Clarify Session — 2026-08-31

Re-validated after `/speckit-clarify` integrated five clarifications.

**Checkbox state: 16/16 → 16/16.** No item newly passed; no item regressed. No markers were
toggled. The spec grew from 36 to 42 functional requirements and from 15 to 18 success
criteria; each new requirement was checked against the same criteria and none introduced an
implementation detail, an unmeasurable outcome, or a new ambiguity.

The five clarifications closed these taxonomy gaps: passage identity and uniqueness; transcript
lifecycle and provenance; privacy handling for an identifiable third party; evidence retention;
and accessibility. The traceability table above was extended to cover the new requirements —
had it been left alone, it would have understated coverage while still reading as complete.

## Contracts Review — 2026-09-01

Phase 1 contract authoring surfaced one requirement that could not be met as written, and it was
corrected rather than absorbed:

**SC-016 claimed 100% link survival across every passage kind.** Achievable for passages the
curriculum owns, because a minted identifier is anchored into the source artifact. NOT achievable
for source code the curriculum does not own, where no anchor can be written and identity must fall
back to a symbol path. Split into SC-016 (owned, 100% by construction) and SC-016a (code, 100% of
stale references fail LOUDLY rather than silently re-pointing). Left unqualified, implementation
would have produced either an undocumented exception or a wrong-but-rendering link — the precise
failure the criterion exists to prevent.

## Requirement → Implementing Task Traceability — 2026-09-01

A cross-artifact analysis found two MUST-level obligations that were **fully contracted and
entirely absent from the task breakdown**. Both were re-verified against the current artifacts
before this section was written: `tasks.md` contained no FR-039 task (the string "redact" appeared
exactly once, as a fixture kind in the unanswerable-question taxonomy), and it contained no
occurrence of `symbol_aliases`, of rule R4, or of gate G-PID-4. Tasks now exist for both, and they
are recorded here because a requirement→criterion table alone cannot show that a contracted
obligation has an executor.

Task ids below are `tasks.md`'s post-2026-09-01 numbering (105 tasks).

### FR-039 — redaction, required before any export or publication

| Contracted at | Obligation | Task |
|---|---|---|
| `passage-contract.md` §7.1 | Four-outcome `resolve()`; `redacted` is a determined answer of its own, distinct from `not_in_registry` and from `undetermined` | **T011** |
| `passage-contract.md` §4.3, §7.3 R2/R6 | Append-only `redactions` log; `passages.redacted` is a materialisation, never a bare column flip; `unredact` is an append | **T012** |
| `pipeline-cli.md` §4.6 | `redact.sh` — arguments, three-valued exits, rebuild trigger | **T038** |
| `pipeline-cli.md` §4.6; §7.3 R7 | `--review-only` and the `redaction-review.json` artifact, with its staleness rule | **T039** |
| FR-039 as a live obligation | The Chapter 1 review itself — the recording features an identifiable third party | **T040** |
| `passage-contract.md` §7.3 R1, R5 | Redacted pids excluded from FTS and from the embedding set **at generation-build time**; `degraded` until rebuild | **T059** |
| `passage-contract.md` §7.3 R3; `http-api.md` §3.9 | Cross-references suppressed; `redacted_omitted` count reported | **T061** |
| `passage-contract.md` §7.3 R4; `http-api.md` §3.10 A4 | Stored answers `withdrawn`; a redacted citation ⇒ `declined{redacted_evidence}` | **T075** |
| `passage-contract.md` §7.3 gate **G-PID-5** | The composite proof, with its paired mutation | **T076** |
| `pipeline-cli.md` §4.7 B5 | Publish precondition — review exists and is newer than the transcript | **T087** |
| `pipeline-cli.md` §4.7 | `add-chapter.sh` covers all nine stages including `redaction-review` and `publish` | **T084** |

The spread across five phases is deliberate, not fragmentation: redaction must propagate into each
component **as that component is built**, and G-PID-5 cannot be proven until search, cross-references
and stored answers all exist. None of it is Phase 8 work — a publication gate is not polish.

### SC-016a — code-passage identity, keyed on symbol path with a rename alias table

| Contracted at | Obligation | Task |
|---|---|---|
| `passage-contract.md` §10 **P-U1** | **Settle the matching key's producer before building on it.** Lumen exposes no symbol table through its CLI or MCP surface, so §6.2's key has no confirmed producer. Three-valued outcome; T015–T017 are blocked until it exits `0` | **T014** |
| `passage-contract.md` §6.2, §6.4, §4.3 `symbol_aliases` DDL | The `(path, symbol)` key and the alias table, with `authored` separated from `detected` | **T015** |
| `passage-contract.md` §8 R2/R3/**R4** | Ingest matching for code; an unaliased rename inside `workshop/` fails ingest, outside it mints and orphans loudly | **T016** |
| `passage-contract.md` §6.5, §6.6, gate **G-PID-4** | The validating proof: aliased rename preserves the pid; unaliased rename resolves `not_in_registry` and ingest exits `1`. Paired mutation: silent re-point by nearest-text match must turn the gate red | **T017** |
| FR-031 | The limit stated honestly in the shipped documentation | **T095** |

Previously SC-016a's only mention anywhere in the breakdown was the documentation task — which
*documented* a guarantee that nothing implemented, and gate G-PID-4 appeared in no task at all.

**P-U1 is handled by disclosure, not by assumption.** T014 settles it and T015–T017 are explicitly
conditional on that outcome, recorded both on each task and in `tasks.md`'s Global Constraints. If
T014 exits `1` — both candidate producers tested, neither yielding a stable symbol path — then
SC-016a is not implementable as specified, and that becomes a recorded gap and an operator decision.
The outcome forbidden either way is the one SC-016a exists to prevent: a heuristic that quietly
re-points a citation at different code.

## Notes

- The three resolved decisions (D1 local-only, D2 corpus scope, D3 local video reassembly) each
  record what would reopen them. If any is reopened, this checklist must be re-validated,
  because each one changes what "scope is clearly bounded" means.
- The spec deliberately contains one technology-flavoured success criterion (SC-014). This is
  justified above and should not be "cleaned up" by a later phase — removing it would remove a
  release-blocking constraint from view.
