# Implementation Plan: Document Ingestion for Textbooks (EPUB / PDF / FB2 / Other Formats)

**Branch**: `012-document-ingestion-textbooks` (no git branch created — per this
repository's simplification convention for concurrently-drafted specs, this
document was authored directly into the already-reserved
`specs/012-document-ingestion-textbooks/` directory on `main`, matching how
spec 015 was authored) | **Date**: 2026-09-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/012-document-ingestion-textbooks/spec.md`

## Summary

Extend the workshop curriculum platform's existing text-document ingestion
path — `pipeline/md_sections.py` → `ingest-transcript -docs` → `index-embed`
→ FTS5/semantic search → `/passage/{pid}` — to also accept EPUB textbooks
(Phase 1), then PDF/FB2/DOCX/HTML (Phase 2), then OCR and extraction-failure
self-reporting (Phase 3). The research
(`workshop/docs/research/education-platform/document-ingestion-architecture.md`)
establishes, with file:line citations, that everything at or below
`ingest-transcript -docs` is already format-agnostic; the only genuinely new
code this feature requires is a format-specific extractor that emits the
exact `{chapter_slug, source_file, sections[].{text, path, line_start,
line_end, kind}}` shape `md_sections.py` already produces. A real,
assertion-verified proof-of-concept
(`workshop/docs/research/education-platform/poc/epub_extract_poc.py`)
demonstrates the EPUB half of that mechanism end to end using only the Python
standard library. This plan formalizes Phase 1: a production
`pipeline/epub_sections.py` module following the POC's mechanism but built on
`ebooklib` rather than hand-rolled stdlib XML parsing, gated by a mandatory,
explicitly-recorded license/permission check (FR-005) before any content is
minted.

## Technical Context

**Language/Version**: Python 3.14 for the new pipeline stage —
`workshop/pipeline/venv/bin/python --version` measured **3.14.4** this
session (`pipeline/requirements.txt`'s own header records 3.14.6 as of
2026-09-01; the difference is a host patch-level drift, not a blocker — no
package in this plan requires a specific patch release). This is the same
interpreter that already runs `md_sections.py`, `run_faster_whisper.py` and
every other `pipeline/` stage; no new interpreter or venv is introduced. Go
**1.26.2** (`workshop/platform/backend/go.mod`) is the existing backend's
version but is **unmodified by this feature** — FR-004/FR-011/FR-012 and the
research's own §1.4/§3.1 architecture analysis are explicit that
`ingest-transcript -docs` needs no new flag and no code change to accept a
textbook's sidecar; this plan introduces zero new Go code.

**Primary Dependencies**:
- **`ebooklib`** (PyPI: `EbookLib`) — **NEW**, not yet installed (confirmed
  `ModuleNotFoundError` against `pipeline/venv/bin/python` this session, same
  finding the research recorded). The research's EPUB section (§2.1) states
  the production recommendation explicitly and unhedged: *"The recommendation
  is still `ebooklib` for production"* — TOC/NCX handling, EPUB2-vs-EPUB3
  navigation differences and cover/metadata extraction are real, recurring
  edge cases a hand-rolled parser would otherwise have to rediscover one book
  at a time. The research's Phase 1 breakdown (§6) frames the stdlib-vs-
  `ebooklib` choice as one that must be **explicitly recorded**, not silently
  defaulted — this plan makes that explicit recording: **`ebooklib` is the
  Phase 1 production dependency.** The POC's stdlib-only `zipfile` +
  `xml.etree.ElementTree` approach remains valuable as the *proof that the
  mechanism is understood* (container → OPF → spine → XHTML → sections); it
  is not carried into production code.
- **`defusedxml`** — **NEW**, not yet installed (confirmed
  `ModuleNotFoundError` this session). Required by FR-008 for any
  EPUB/OPF/XHTML content that did not originate from operator-curated,
  pre-vetted files — the research's own security-hook finding (§5.6), applied
  as a Phase 1 requirement rather than a nice-to-have. `ebooklib` itself uses
  `lxml` or stdlib `ElementTree` internally depending on installation extras;
  this plan's own OPF/spine/XHTML parsing (wherever it does not delegate
  fully to `ebooklib`) uses `defusedxml.ElementTree` in place of the bare
  stdlib module.
- Both new dependencies MUST be added to `pipeline/requirements.txt` under
  its own documented, already-established discipline: `--only-binary=:all:`,
  pinned exact versions, with the measured wheel tags recorded in a comment
  exactly as the file's existing header does for `faster-whisper`/
  `ctranslate2` — this is a direct instance of §11.4.246's hermetic-build
  requirement (every dependency version-pinned and installed from a
  provenance-attested source, no silent source build), not a new discipline
  invented for this feature.
- **Reused, unmodified**: `pipeline/md_sections.py`'s `MIN_CHARS` stub
  threshold and three-tier idempotency pattern (inline anchor → exact text
  match → position-range match), reused by value (same constants, same
  priority order) rather than imported, mirroring how the POC already
  mirrors it; `platform/backend/cmd/ingest-transcript`'s `-docs` flag
  (existing Go binary, zero changes); `platform/backend/cmd/index-embed`
  (existing, confirmed kind-agnostic).

**Storage**: Flat-file JSONL registry already used by this pipeline —
`curriculum/passages.jsonl` (minted via the existing `ingest-transcript`
sync mechanism). No new storage, no new registry, no new `passagestore.Kind`
(FR-020's constraint, and the research's own §3.2 finding that `doc_section`
already has full headroom).

**Testing**: `pytest`, matching the existing `pipeline/` convention
(`pipeline/test_build_transcript.py` is the direct sibling-file precedent at
the `pipeline/` root, where `epub_sections.py` itself lives — not
`pipeline/extract/`, which is a different stage family for curated
area-authoring, not raw document ingestion).

**Target Platform**: Linux server-side batch pipeline (not a live service) —
invoked standalone or wired into `pipeline/extract/run_pipeline.py`-adjacent
tooling at the operator's discretion; this plan does not require wiring it
into `run_pipeline.py`'s existing seven-stage sequence, since textbook
ingestion is operator-triggered per textbook, not per-chapter.

**Project Type**: Single Python module (`pipeline/epub_sections.py`) within
the private `workshop` submodule; no new service, no new deployable, no
frontend change (FR-011's "no new frontend route" requirement is satisfied by
the existing `/passage/{pid}` route already serving `doc_section` content).

**Performance Goals**: Not applicable in the throughput sense — batch,
run-on-demand, one textbook at a time. SC-006 does require "no measurable
search-latency regression attributable to the addition of textbook content,"
which this plan treats as a verification step (re-run the existing search-
latency check before/after a real textbook ingestion), not a new performance
target.

**Constraints**: Fully offline/local at ingestion time (no external API
calls — `ebooklib` and `defusedxml` are both pure local libraries once
installed, matching this pipeline's existing zero-network-dependency
posture); must not touch the public umbrella repository; must not commit any
copyrighted textbook's full text to the public umbrella (it lives, as every
other `workshop` corpus artifact does, inside the private `workshop`
submodule's `curriculum/` tree — this is the existing content-boundary
posture, not a new one this feature introduces); the one-time `pip install`
of the two new pinned dependencies is an environment-setup step, tracked as a
Phase 1 task, not performed by this plan itself.

**Scale/Scope**: Phase 1 is EPUB-only, one format, sized to the research's
own POC (a 3-chapter, 6-section synthetic sample) plus at least one real,
licensed EPUB textbook fixture per SC-001/SC-002/SC-003.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Anti-bluff (§11.4 / §11.4.5 / §11.4.69 / §11.4.107) | PASS | SC-001 through SC-009 are each phrased as directly re-runnable checks against real fixtures (a real licensed EPUB, a fixture with no recorded license), not claims about design intent — matching spec 009's own precedent. |
| No-guessing mandate (§11.4.6) | PASS, with an open item carried forward, not resolved here | FR-005 (accepted license/permission values) and FR-020 (whether/how textbook structure ever promotes into `kg_area`/`kg_lesson_section`) are explicitly marked `[NEEDS CLARIFICATION]` in spec.md. This plan does **not** silently resolve either — see Phase 0's carried-forward clarifications below. Everything else this plan states as a decision (the `ebooklib` choice, the `textbook-<slug>` scope pattern, the sidecar shape) is either directly cited to the research's own file:line evidence or to code read this session, never asserted from memory. |
| Reproducible + hermetic builds (§11.4.246) | ACTION REQUIRED, tracked as a Phase 1 task | Two new dependencies (`ebooklib`, `defusedxml`) must be added to `pipeline/requirements.txt` under its own `--only-binary=:all:`, pinned-version, measured-wheel-tag discipline before this feature ships — neither is installed in `pipeline/venv` today (confirmed this session). This is a normal instance of an existing discipline, not a new one, and is not yet done. |
| Copyright / content-licensing gate | **NO DIRECT CONSTITUTION ANCHOR EXISTS — verified, not assumed** | `grep -in 'copyright' submodules/constitution/Constitution.md` returns **zero** matches. `grep -in 'licens' ...` returns matches that are exclusively about software licenses (SPDX headers, `LICENSE`/`NOTICE` files, "does not license [permit]..." in an unrelated figurative sense) — none address third-party content copyright, redistribution, or a takedown/DMCA-shaped gate. FR-005's License Record requirement is therefore a **project-specific requirement this spec introduces**, not derived from or in tension with any numbered constitution anchor. Nothing here should be cited as implementing an anchor that does not exist. |
| Content boundary (workshop/CLAUDE.md module rule 6; umbrella `scripts/verify-content-boundary.sh`) | N/A — distinct concern, no conflict | That rule protects `workshop`'s own PRIVATE recorded-session content from leaking into the PUBLIC `vasic` umbrella. This feature ingests externally-sourced, licensed textbook text into `workshop`'s own (already-private) `curriculum/passages.jsonl` registry — the same boundary transcript content already respects. No textbook content is proposed to cross into the public umbrella by this feature. |
| Dead/unwired-code investigate-before-remove (§11.4.124) | N/A | This feature adds code; it removes none. |
| Governance fidelity / reuse-before-reimplement (§11.4.74) | PASS | Every downstream stage (`ingest-transcript -docs`, `index-embed`, the passage registry, `/passage/{pid}`) is reused unmodified, per the research's own §1.4/§1.5 citations; the only new code is the format-specific extractor §2.1/§4 of the research names as genuinely new. |
| Never mutate shared state with a whole-tree command | PASS | `epub_sections.py` reads one EPUB file and writes one sidecar JSON; `ingest-transcript -docs` appends to the registry via its existing anchor-based sync, never a whole-tree rewrite. |
| Comprehensive documentation | PASS | This plan, spec.md, data-model.md, contracts/, and quickstart.md are the documentation; tasks.md (a later SpecKit step, not produced here) will carry the task-level breakdown. |
| Isolation by default | N/A | No live-service component; this is a batch pipeline stage, identical in shape to spec 009's PDF-notes extractor. |

No unjustified Constitution Check violations. The one ACTION REQUIRED item
(dependency pinning) is ordinary Phase 1 setup work, not a design violation,
and does not require the Complexity Tracking table below.

## Project Structure

### Documentation (this feature)

```text
specs/012-document-ingestion-textbooks/
├── spec.md               # Feature specification (already exists, formalized this session)
├── plan.md               # This file
├── data-model.md         # Entities, and the spec-015 Location Anchor cross-reference
├── contracts/
│   └── epub-ingestion-stage.md   # The extraction stage's own input/output contract
└── quickstart.md         # Runnable end-to-end validation guide, POC-grounded
```

(No `research.md` is written as a separate Phase 0 artifact: the formalized
research this plan draws on already exists in full at
`workshop/docs/research/education-platform/document-ingestion-architecture.md`,
cited throughout this plan and data-model.md by section number — writing a
second, shorter research document would duplicate it rather than add
information. `tasks.md` is a later SpecKit step, not produced by this plan.)

### Source Code (repository root)

```text
workshop/
├── pipeline/
│   ├── epub_sections.py         # NEW: Phase 1 EPUB extractor, ebooklib-based,
│   │                             #      following md_sections.py's contract exactly
│   │                             #      (MIN_CHARS stub filtering, three-tier
│   │                             #      idempotent anchor carry-forward, identical
│   │                             #      {chapter_slug, source_file, sections[]} output)
│   ├── test_epub_sections.py    # NEW: unit tests (fixture EPUBs: well-formed,
│   │                             #      malformed-XHTML, DRM-wrapped, no-license)
│   ├── md_sections.py           # REUSE, UNMODIFIED: the contract/pattern reference
│   │                             #      this new module follows (not imported as a
│   │                             #      library — its constants/strategy are
│   │                             #      reimplemented for EPUB's different source
│   │                             #      shape, exactly as the POC already does)
│   └── requirements.txt         # MODIFY: add `ebooklib` + `defusedxml`, pinned,
│                                 #      `--only-binary=:all:`, measured wheel tags
│                                 #      recorded in a comment (matches existing header
│                                 #      discipline)
├── platform/
│   └── backend/
│       └── cmd/
│           └── ingest-transcript/   # REUSE, UNMODIFIED: `-docs` flag already
│                                     #      consumes epub_sections.py's exact output
│                                     #      shape; no new flag, no Go code change
├── docs/research/education-platform/
│   ├── document-ingestion-architecture.md   # REUSE, UNMODIFIED: the research this
│   │                                          #      plan formalizes
│   └── poc/epub_extract_poc.py               # REUSE, UNMODIFIED, read-only reference:
│                                               #      the mechanism epub_sections.py
│                                               #      productionizes; stays a scratch
│                                               #      POC, is not wired into pipeline/
└── curriculum/
    └── textbook-<slug>/             # NEW per-textbook output directory: the sidecar
                                      #      JSON and any operator-recorded License
                                      #      Record live here, mirroring
                                      #      curriculum/chapter-<id>/'s existing shape
```

**Structure Decision**: `epub_sections.py` lives at `pipeline/` (sibling to
`md_sections.py`), not under `pipeline/extract/` (sibling to
`meeting_notes.py`/`meeting_notes_pdf.py`), because it belongs to the same
family as `md_sections.py` — a raw-document-to-`doc_section`-sidecar
extractor consumed directly by `ingest-transcript -docs` — not to the
curated-area-authoring family `pipeline/extract/` hosts (`promote.py`,
`minting.py`, `run_pipeline.py`'s seven named stages). This mirrors the
research's own §1.3/§1.7 distinction between the two layers, and keeps a
textbook ingestion run a standalone, operator-triggered invocation rather
than a new stage wired into `run_pipeline.py`'s per-chapter sequence (a
textbook is not a chapter and has no chapter-shaped `ChapterID`, per FR-006).

## Complexity Tracking

*No unjustified Constitution Check violations — table intentionally empty.*
