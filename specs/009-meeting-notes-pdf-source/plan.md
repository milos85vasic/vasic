# Implementation Plan: PDF-Sourced Meeting Notes with Redaction Gate

**Branch**: `009-meeting-notes-pdf-source` | **Date**: 2026-09-18 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/009-meeting-notes-pdf-source/spec.md`

## Summary

Extend `workshop/pipeline/extract/meeting_notes.py`'s per-chapter extraction so
a chapter's notes PDF (when present, by filename convention) is the
authoritative source for that chapter's meeting-notes/TODO/open-questions/
next-meeting content, with the existing transcript-based path as fallback and
a new ASR-and-ingest prerequisite for chapters with neither. Both sourcing
paths route through the existing `publication_policy` redaction predicate
before minting, with an additional narrow PII-pattern check for PDF-sourced
text specifically.

## Technical Context

**Language/Version**: Python 3 (matches the existing `pipeline/extract/` modules; no version change needed — same interpreter already runs `meeting_notes.py`, `taxonomy.py`, `publication_policy.py`).
**Primary Dependencies**: `pdftotext` (poppler-utils, already installed and already used by `pipeline/transcribe/pdf_notes.py`); the already-installed local ASR stack (faster-whisper 1.2.1 / CTranslate2 in `pipeline/venv`, and whisper.cpp v1.9.1 built CPU-only) for the chapter 02.02 prerequisite; no new third-party dependency is introduced.
**Storage**: Flat-file JSONL registries already used by this pipeline — `curriculum/passages.jsonl` (minted items via the existing `minting.sync_areas` bridge), `curriculum/disclosure-judgements.jsonl` (existing withheld-item ruling log, reused unchanged).
**Testing**: `pytest`, matching the existing `pipeline/extract/test_meeting_notes.py` and sibling `test_*.py` files' own convention (unittest-style test classes run via pytest).
**Target Platform**: Linux server-side batch pipeline (not a live service) — invoked as part of `run_pipeline.py`'s per-chapter stage sequence, same as today.
**Project Type**: Single Python package (`pipeline/extract/`) within the private `workshop` submodule; no new service, no new deployable.
**Performance Goals**: Not applicable in the throughput sense — this is a batch, per-chapter, run-on-demand pipeline stage (not request-served); the only relevant target is that ASR transcription of one ~1-hour chapter video completes in a bounded, human-observable time using the already-benchmarked local engines (no new performance floor is introduced by this feature).
**Constraints**: Fully offline/local (no external API calls — matches this pipeline's existing zero-network-dependency posture); must not touch the public umbrella repository or copy any private content out of `workshop` (constitution's content-boundary rule); must not weaken or bypass `WORKSHOP_HTTP_BIND` staying loopback-only while the separately-tracked G5 finding is open.

## Constitution Check

*GATE: Must pass before proceeding. Re-check after design phase.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Evidence-Based Claims | PASS | FR-005/SC-002 require deterministic re-extraction to be demonstrated by actually re-running it twice, not asserted; SC-001/004/005/007/008 are each phrased as directly re-runnable checks against real fixtures/chapters, not claims about design intent. |
| Honest Instruments | PASS | FR-009 requires a PDF-extraction failure to be reported as an explicit failure state, never silently downgraded to a fallback that would misrepresent which source actually produced the content. |
| Governance Fidelity | PASS | Reuses the existing `is_publishable_content`/`check_content` mechanism (FR-007) and the existing `disclosure-judgements.jsonl` ruling log (FR-010) rather than inventing a parallel redaction path — extends the governed mechanism instead of routing around it. |
| Isolation by Default | N/A | This feature has no live-service component; it is a batch extraction stage. Workshop's existing loopback-only binding is unaffected and not reopened by this work. |
| Comprehensive Documentation | PASS | This plan, the spec, and the eventual tasks.md are the documentation; no separate doc debt is created. |
| Environment Adaptability | NEEDS ATTENTION | The ASR prerequisite (User Story 3) depends on the specific local ASR stack already verified on THIS development host (`pipeline/venv`'s faster-whisper, whisper.cpp build). It has not been verified as reproducible on a different host. Scoped as a known limitation, not a violation: this pipeline stage already has this dependency today for every OTHER chapter's transcript (this feature does not introduce the dependency, it exercises it for one more chapter). |
| Published Means Served | PASS | FR-007/FR-010's withheld-item convention is the SAME one already used for other withheld content in this pipeline (existing `state: "withheld"` handling), which already satisfies this principle for other content; this feature does not introduce a new listing surface that could advertise a withheld item without saying so. |
| Source Is Not Served | PASS, and directly load-bearing | This principle is exactly why FR-008 requires the redaction check to run on each item's own FINAL RENDERED TEXT, not merely on the source PDF/transcript as a whole — a claim like "the source PDF contains no roster names" would be a claim about SOURCE, not about what gets MINTED and SERVED, and this spec explicitly forbids treating the two as equivalent. |
| Reproduce Before Repairing | PASS | Chapter 02.02's "unwritten" state (User Story 3) is being reproduced and fixed by running the real ASR pipeline against it, not by fabricating placeholder content or asserting a fix without evidence. |
| Never Mutate Shared State With a Whole-Tree Command | PASS | No task in this feature involves a whole-tree copy/move/rm; extraction reads existing files and appends to append-only JSONL registries via the existing minting bridge. |
| Quality Over Speed | PASS | User Story 3 (the ASR run) is explicitly lower priority (P2) than the core sourcing-path change (P1), so the longer-running, more operationally involved step does not block or rush the higher-value, faster-to-verify work. |

No unjustified violations. The one NEEDS ATTENTION (Environment Adaptability) is a pre-existing property of this pipeline stage's family, not a new one this feature introduces, and does not require the Complexity Tracking table below.

## Project Structure

### Documentation (this feature)

```text
specs/009-meeting-notes-pdf-source/
├── spec.md              # Feature specification
├── plan.md              # This file
├── data-model.md         # Entities and citation-anchor shape
├── contracts/
│   └── pipeline-stage.md # The extraction stage's own input/output contract
├── quickstart.md         # Runnable end-to-end validation guide
├── tasks.md              # Task breakdown (/speckit.superspec.tasks output)
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
workshop/
├── pipeline/
│   ├── extract/
│   │   ├── meeting_notes.py          # MODIFY: source-selection (PDF vs transcript), redaction gate call
│   │   ├── meeting_notes_pdf.py       # NEW: PDF discovery, pdftotext extraction, cue-phrase mining, PII pattern check
│   │   ├── run_pipeline.py            # MODIFY: chapter-02.02 ASR-and-ingest prerequisite step wiring
│   │   ├── publication_policy.py      # UNCHANGED: reused as-is (is_publishable_content / check_content)
│   │   ├── test_meeting_notes.py      # MODIFY: add PDF-sourced-fixture and redaction-gate test cases
│   │   └── test_meeting_notes_pdf.py  # NEW: unit tests for the new module in isolation
│   └── run_faster_whisper.py          # REUSE, no changes: existing, chapter-agnostic (`wav` in, `out` json) — already produced chapter-02/02.01's transcripts; chapter 02.02 needs an ffmpeg video→wav step before this, and the existing JSON→curriculum/chapter-XX/ ingestion mechanism (used for chapter-02/02.01) needs to be located and reused — a research item for tasks.md Task 1, not yet fully identified
├── chapters/
│   └── 02.02/                        # UNCHANGED input: raw video + sidecars, already present
└── curriculum/
    └── chapter-02.02/                 # NEW output directory: ingested transcript for chapter 02.02
```

**Structure Decision**: New logic lives in a new sibling module
(`meeting_notes_pdf.py`) rather than growing `meeting_notes.py` further —
`meeting_notes.py` is already a substantial, single-purpose file (per this
project's own writing-plans guidance: prefer smaller, focused files; a file
that has grown large is a signal to split, not to keep growing). The existing
file gains only a thin source-selection dispatch (PDF present → call the new
module; else → existing behavior unchanged) plus the shared redaction-gate
call site, keeping the two extraction strategies independently testable.

## Execution Strategy

### TDD Requirements

- [x] `meeting_notes_pdf.py` (new module: PDF discovery, extraction, cue-phrase mining): strict RED-GREEN-REFACTOR — this is new, deterministic, pure-function-shaped logic with a clear fixture-driven oracle (a fixture PDF's known content), exactly the profile TDD suits best.
- [x] Redaction-gate integration (both sourcing paths): strict TDD — a security/privacy-relevant boundary where the failing-test-first discipline is the one that make FR-007/FR-008's "no item ships without being checked" guarantee verifiable rather than asserted.
- [ ] `run_asr_chapter.py` / ASR wiring: NOT strict TDD — this is an orchestration wrapper around an already-verified external engine (faster-whisper/whisper.cpp); its correctness is demonstrated by running it against real chapter 02.02 video (an integration/quickstart-level check), not by unit-testing the ASR engine's own transcription quality.

### Parallel Execution Opportunities

- [x] The new `meeting_notes_pdf.py` module (User Story 1) and the ASR-and-ingest step (User Story 3) have no shared files and no dependency on each other — one processes chapter 01's existing PDF, the other processes chapter 02.02's video. Independent, dispatchable in parallel.
- [x] The redaction-gate integration (User Story 4) depends on BOTH sourcing paths existing (it wraps the output of each), so it is sequenced AFTER User Stories 1 and 2's extraction logic exists, but its own unit tests (a redaction predicate applied to synthetic text) can be developed in parallel with either.
- [ ] User Story 2 (transcript path unchanged) is largely a non-change plus a regression-test addition; folded into the same task as the redaction-gate wiring rather than given its own parallel track, since its only real work is "add the same redaction call site the PDF path gets."

### Human Checkpoints

1. After the new `meeting_notes_pdf.py` module passes its own unit tests (fixture-PDF extraction, deterministic re-run) — verify against the REAL chapter 01 PDF before wiring it into the main pipeline stage.
2. After the redaction gate is wired into both paths — verify against the full existing transcript-sourced corpus (SC-006: zero new false-positive withholding) before proceeding to the ASR work.
3. After chapter 02.02's ASR-and-ingest step runs for real — verify the produced transcript is discoverable and chapter 02.02 no longer reports "unwritten" — before final polish/documentation.
4. Before this branch is considered done — run the full `pipeline/extract/` test suite plus this feature's own quickstart guide end-to-end, exactly as `docs/superpowers/plans/2026-09-18-helixqa-integration.md`'s own tasks require a live-evidence final check, never a report-only claim.

### Review Gates

- [x] The redaction-gate integration (touches a security/privacy-relevant boundary, per Constitution Check's "Source Is Not Served" and "Published Means Served" rows): review before merge.
- [x] The PII-pattern check added in FR-011 (new pattern-matching code, false-positive/false-negative risk): review before merge.
- [ ] The new `meeting_notes_pdf.py` module's cue-phrase mining logic: not a separate review gate — covered by the same task review the implementer's own commit gets under subagent-driven-development.

## Complexity Tracking

*No unjustified Constitution Check violations — table intentionally empty.*
