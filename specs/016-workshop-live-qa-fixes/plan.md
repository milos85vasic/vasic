# Implementation Plan: Workshop Live-QA Fix Batch

**Branch**: `016-workshop-live-qa-fixes` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/016-workshop-live-qa-fixes/spec.md`

## Summary

A live manual-QA pass against the running `workshop` curriculum platform surfaced 8 distinct,
independently-testable defects spanning the landing page, transcript pages, cross-reference
derivation, progress tracking, practice-question interaction, and chapter 4's derived content
quality. This is a diagnose-and-fix batch against an existing, already-shipping system — not new
architecture. The primary technical approach is: reproduce each symptom against the live server
first (per this project's "Reproduce Before Repairing" principle — several of these reports
plausibly share a root cause with each other, or with fixes already shipped earlier the same day,
and must not be assumed), root-cause it in the owning layer (Angular frontend, Go backend, or the
Python transcription/knowledge-mint pipeline), fix at the source, and re-verify live against a
freshly restarted, freshly built server — never against cached source-level evidence.

## Technical Context

**Language/Version**: Go 1.26 (backend, `platform/backend`), TypeScript / Angular (frontend,
`platform/frontend`), Python 3.14 (`pipeline/` — ASR, knowledge-mint, crossref-adjacent extraction)
**Primary Dependencies**: existing workshop stack only — Angular standalone components, Go
`net/http` + the existing `internal/api`/`pkg/*` packages, faster-whisper/ctranslate2 for ASR,
Ollama for any LLM-assisted content work (chapter 4 rewrite). No new dependency is anticipated;
any genuinely new dependency is a plan deviation requiring its own justification.
**Storage**: `curriculum/passages.jsonl` + sidecar JSONL registries (existing, append-only /
redaction-aware), the server's SQLite-backed served index (rebuilt per generation), on-disk
chapter materials under `chapters/<NN>/` and `curriculum/chapter-<NN>/`
**Testing**: `go test ./...` (backend), Karma/Jasmine headless-Chrome (frontend,
`npm run test:unit`), `pytest` (pipeline, `pipeline/venv/bin/pytest`), Playwright e2e
(`platform/frontend/e2e/`), plus this project's existing `platform/gates/verify-*.sh` /
`prove-*.sh` paired-mutation gate suite
**Target Platform**: existing containerized Linux service (`workshop-curriculum_platform_1`,
podman), already running and reachable for live verification throughout this work
**Project Type**: web-service (existing three-tier app: Angular SPA + Go API + Python offline
pipeline) — not a new project type
**Performance Goals**: no new performance target; existing response-time/throughput behavior MUST
NOT regress as a side effect of any of these 8 fixes
**Constraints**: every fix MUST be verified against the live, restarted server (constitution:
*A Restart Runs What Was Built*, *Source Is Not Served*) — a code-level or unit-test-level PASS is
not sufficient evidence of a fix on its own; the chapter 4 content rewrite (US8) MUST stay inside
the content-boundary discipline already established for this private module (no new disclosure,
no verbatim private-conversation content copied into any public-facing artifact)

## Constitution Check

*GATE: Must pass before proceeding. Re-check after design phase.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Evidence-Based Claims | PASS | Every one of the 8 fixes requires live, pasted evidence before being marked done — quickstart.md's "Full-batch regression check" makes this explicit rather than implicit. |
| Honest Instruments | PASS | No new gate is introduced by this feature; existing three-valued gates (`platform/gates/*`) are reused for verification where applicable. |
| Reproduce Before Repairing | PASS (post-design) | research.md states, per story, a reproduction approach and an explicit alternative hypothesis considered and why deprioritized — notably US1 (selection-failure as the likely single root cause of both reported symptoms) and US2 (a different code path than the already-fixed progress page, not a regression of it). Confirming or refuting each hypothesis is an implementation-phase task, not asserted here as fact. |
| Source Is Not Served | PASS (post-design) | research.md's US6 entry and quickstart.md's prerequisite step both require checking the CURRENT live index generation before reusing the earlier-same-day crossref verification as evidence. |
| A Restart Runs What Was Built | PASS | quickstart.md requires a fresh `scripts/restart.sh` (never a bare podman restart) before any live re-verification, with the build stamp from `/api/health` quoted in every validation note, per this project's own existing convention. |
| A Screen's Precision Is Not Its Recall | PASS (post-design) | quickstart.md's US6 step 4 explicitly requires a sample large enough to speak to recall, not only precision, naming the principle directly. |
| The Content Boundary Is a Standing Invariant | PASS | US8 (chapter 4 rewrite) stays inside the already-private `workshop` module; no new public-facing artifact is created by this feature, and data-model.md's validation rule for chapter 4 sections requires traceability to source rather than invention. |
| Never Mutate Shared State With a Whole-Tree Command / Shared-Tree Discipline | PASS | No feature-specific risk beyond this project's standing rule; explicit-path staging applies as usual if the working tree is shared with concurrent work at implementation time. |
| Authored Curriculum / Published Means Served | PASS | `contracts/chapter-recordings-listing.md` explicitly cross-checks US3 against *Published Means Served* — a chapter listed as available must have its recording route actually resolve, not just its listing entry look correct. |
| A Capability With Measured Harm Ships Off | N/A | No capability default is changed by this feature. |

No unjustified violations, before or after design. Every row that opened as "NEEDS ATTENTION" in
the pre-design check is now closed out by a concrete artifact (research.md's hypothesis/alternative
pairs, or a specific quickstart.md step) rather than by assertion.

## Project Structure

### Documentation (this feature)

```text
specs/016-workshop-live-qa-fixes/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
├── contracts/            # Phase 1 output (API-contract-shaped findings)
├── checklists/
│   └── requirements.md
└── tasks.md              # /speckit-tasks output (not yet generated)
```

### Source Code (repository root)

This feature touches the EXISTING `workshop` submodule only; no new top-level module is created.

```text
workshop/
├── platform/frontend/src/app/
│   ├── features/curriculum/            # landing-page recordings carousel (US3)
│   ├── features/transcript/            # transcript page placeholder/uncertainty rendering (US4, US5)
│   ├── features/areas/                 # area page lesson/section completion checkmarks (US2)
│   ├── features/practice/              # multi-choice selection + answer submission (US1)
│   ├── features/progress/              # progress-screen first-column label truncation (US7)
│   └── core/ or shared/                # crossref ("Where else this points") rendering, if frontend-side (US6)
├── platform/backend/
│   ├── internal/api/                   # practice-answer submission endpoint, progress-write ack (US1)
│   ├── pkg/crossref/                   # crossref derivation/scoping (US6, if root cause is backend-side)
│   └── pkg/index/ or pkg/progress/     # lesson/section completion-state read path (US2)
├── pipeline/                           # ASR reprocessing / uncertainty calibration (US5), "Not in this build" source if pipeline-side (US4)
└── curriculum/chapter-04/              # chapter 4 section content rewrite (US8)

platform/frontend/e2e/                  # new/updated Playwright specs per user story
platform/backend/**/*_test.go           # new/updated Go tests per user story
pipeline/**/*test*.py                   # new/updated pytest tests for transcription-quality work
```

**Structure Decision**: Reuse the existing `workshop` submodule's established three-tier layout
exactly as-is. This is a fix batch against a shipping system, not new architecture — introducing
any new top-level directory or pattern would violate *Standalone Cloneable* and *Environment
Adaptability* for no benefit. Each user story's owning layer is identified above as a starting
hypothesis for Phase 0 research to confirm or correct (per *Reproduce Before Repairing*, the
actual owning file/function for each of the 8 symptoms is not assumed here — it is confirmed by
investigation before any fix is written).

## Execution Strategy

### TDD Requirements

- **Practice-question selection and submission (US1)**: strict RED-GREEN-REFACTOR. This is the
  platform's core assessment-interaction path; a regression here is a total feature outage, so a
  test MUST exist that fails against the current broken behavior before any fix lands.
- **Lesson/section completion-state read path (US2)**: strict TDD — false positives and false
  negatives are both real failure modes (FR-009/FR-010), and both need their own failing test.
- **Transcription uncertainty-rate reduction (US5)**: TDD at the measurement level — a test
  asserting the quantified before/after reduction (SC-003, ≥50%) must exist and run against real
  reprocessed output, not be asserted from a single manual read.
- **Crossref relevance (US6)**: TDD at the "no bare glossary/bookkeeping target" assertion level,
  mirroring the scoping fix already proven earlier the same day for a different code path.

### Parallel Execution Opportunities

- US1 (practice interaction) and US2 (completion checkmarks) touch different frontend features and
  different backend endpoints — independent, dispatchable in parallel once each is root-caused.
- US3 (landing-page recordings), US4 (transcript placeholder text), and US7 (progress-screen
  truncation) are independent, narrowly-scoped UI defects with no shared files — all three can
  proceed in parallel.
- US5 (transcription reprocessing) and US8 (chapter 4 rewrite) both touch the Python pipeline but
  operate on disjoint inputs (ASR confidence calibration vs. chapter-4-specific section content) —
  independent, but both are long-running (re-transcription, LLM-assisted rewrite) and should be
  started early so their wall-clock time overlaps with the faster UI fixes.
- US6 (crossref relevance) depends on knowing the CURRENT live index generation first (Phase 0
  research) before its fix can be scoped — not parallel with its own research step, but
  independent of every other story once that research is done.

### Human Checkpoints

1. After Phase 0 research — confirm the root-cause findings (especially whether US1's two symptoms
   collapse into one defect, and whether US6 is a regression, a reindex-timing gap, or genuinely
   new noise) before committing to fixes.
2. After each user story's fix — verify live against the acceptance scenarios in spec.md, with
   pasted evidence (not a code-level test pass alone).
3. After all 8 stories — full regression sweep (backend/frontend/pipeline test suites plus the
   relevant `platform/gates/` checks) before this branch is considered done.
4. Before chapter 4's rewritten content (US8) is treated as final — a human readability/accuracy
   pass against the source conversation, since LLM-assisted summarization quality is not fully
   machine-verifiable.

### Review Gates

- Practice-answer submission endpoint changes (US1): review before merging — this is the
  highest-blast-radius fix in the batch (every learner, every area).
- Any change to the crossref derivation/scoping code (US6): review before merging, since a prior
  scoping fix in this exact area shipped earlier the same day and a second change needs to be
  checked against it rather than layered blindly.
- Chapter 4's rewritten section content (US8): review against the content-boundary discipline
  before merging, per the Constitution Check above.

## Complexity Tracking

*No Constitution Check violations — this section is intentionally empty.*
