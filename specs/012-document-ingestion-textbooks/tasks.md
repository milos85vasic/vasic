---
description: "Task list for feature 012: Document Ingestion for Textbooks (EPUB / PDF / FB2 / Other Formats)"
---

# Tasks: Document Ingestion for Textbooks (EPUB / PDF / FB2 / Other Formats)

**Input**: Design documents from `specs/012-document-ingestion-textbooks/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [data-model.md](data-model.md), [contracts/epub-ingestion-stage.md](contracts/epub-ingestion-stage.md), [quickstart.md](quickstart.md)

**Global Constraints** (from plan.md's Technical Context and Constitution Check — every task's requirements implicitly include these):

- All new code lives inside the private `workshop` submodule (`$VASIC_ROOT/workshop`, `pipeline/` root, sibling to `md_sections.py` — not `pipeline/extract/`); no textbook content is copied into the public umbrella repository.
- Zero new Go code and zero new CLI flags on `ingest-transcript`/`index-embed` — every downstream stage is reused unmodified (FR-004, FR-011, FR-012).
- The License Record gate (FR-005) runs BEFORE any source-file byte is read, on every format, with no exception — this is "the single largest non-technical risk" per the research (plan.md, Constitution Check).
- Two new pinned dependencies (`ebooklib`, `defusedxml`) must be added to `pipeline/requirements.txt` under its existing `--only-binary=:all:` discipline (§11.4.246) before any Phase A code is written.
- `pipeline/md_sections.py`'s `MIN_CHARS = 120` stub threshold and three-tier idempotency strategy (inline anchor → exact text match → position-range match) are reused BY VALUE (same constants, same priority order), never imported as a library — mirroring how the POC already does this.
- Untrusted XML input (FR-008) is parsed with `defusedxml`, never bare `xml.etree.ElementTree`, for any OPF/XHTML/FB2/DOCX-package XML step not fully delegated to `ebooklib`.
- No new `passagestore.Kind` and no new registry storage — every section mints as an existing `doc_section` row under a `textbook-<slug>` Registry Scope (FR-006, FR-020).
- FR-020 (whether textbook structure is ever promoted into `kg_area`/`kg_lesson_section`) and the closed-vocabulary half of FR-005 are carried-forward `NEEDS CLARIFICATION` items per data-model.md — no task in this file resolves either; Phase C's research spike (T047) explicitly reports findings without deciding them.
- Every "this was verified" claim in a task's completion note MUST be backed by real, pasted command output — per this repository's anti-bluff discipline (constitution §11.4 family) and this spec's own quickstart.md framing ("'ran the plan' is not evidence — the command's actual output is").

## Format: `[ID] [P?] [Story] [Marker?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 (EPUB MVP, P1), US2 (PDF/FB2/DOCX/HTML, P2), US3 (OCR/failure-reporting/promotion hardening, P3)
- **[TDD]**: RED-GREEN-REFACTOR required — write the failing test first, confirm it fails for the right reason, implement, confirm it passes
- **[REVIEW]**: Code review required before the task/checkpoint is considered done (placed on user-story checkpoint-completing tasks and on the License Record gate, per its hard-requirement status)
- **[SUBAGENT]**: Self-contained enough to delegate to a subagent with no further context from the dispatcher

---

## Phase 1: Setup

**Purpose**: Get the two new dependencies this entire feature depends on installed and verified, per plan.md's confirmed `ModuleNotFoundError` findings.

- [ ] **T001 [P]** Add `ebooklib` (PyPI: `EbookLib`) and `defusedxml` to `pipeline/requirements.txt`, pinned to exact versions, under the file's existing `--only-binary=:all:` discipline. Follow the header-comment convention the file already uses for `faster-whisper`/`ctranslate2` (a dated "MEASURED ON THIS HOST" block recording the actual wheel tags served) — do not guess version numbers or wheel tags; measure them in T002 first, then record.

- [ ] **T002** Install the two new pinned dependencies into `pipeline/venv`:
  ```bash
  workshop/pipeline/venv/bin/python -m pip install --only-binary=:all: EbookLib==<pinned> defusedxml==<pinned>
  workshop/pipeline/venv/bin/python -c 'import ebooklib, defusedxml; print(ebooklib.__version__, defusedxml.__version__)'
  ```
  Expected: both import cleanly with no source build (watch for a compiler invocation, which would mean `--only-binary=:all:` failed to find a wheel). Paste the real installed versions and confirm no `ModuleNotFoundError` — this closes plan.md's two confirmed-absent findings. Update T001's requirements.txt comment with the actual measured wheel tags.

- [ ] **T003 [P] [SUBAGENT]** Run the baseline sibling-module suite to confirm the `pipeline/` test convention is green before starting:
  ```bash
  PYTHONPATH="." workshop/pipeline/venv/bin/python -m pytest workshop/pipeline/test_build_transcript.py -v
  ```
  Paste the real pass/fail summary (per quickstart.md's own Prerequisites section).

**Checkpoint**: Dependencies installed and verified; baseline green. Phase A cannot begin until T002 passes.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Ground every later task in what already exists, rather than guessing signatures or re-deriving conventions this feature must reuse, not reinvent.

**⚠️ CRITICAL**: No Phase A/B/C task may begin until T004-T006 are recorded (T006a is the `Attrs` passthrough prerequisite and may land in parallel — it gates spec 015's cross-spec dependency, not Phase A's EPUB extractor).

- [ ] **T004 [P]** Read `pipeline/md_sections.py` in full. Record, verbatim, in the docstring of the test file created in T007: the exact `MIN_CHARS = 120` constant, the three-tier idempotency strategy's exact priority order (inline `pid` anchor → exact text match → unambiguous position-range match), and the sidecar JSON shape it emits. This is the contract every new format module in this feature must match exactly, per FR-001.

- [ ] **T005 [P]** Read `docs/research/education-platform/poc/epub_extract_poc.py` in full, in particular its synthetic-EPUB-generation function and the `path_label` convention it uses (`epub_extract_poc.py:423`, per data-model.md). Extract/adapt this generator into a reusable test-fixture helper (e.g. `build_epub_fixture(chapters: list[...]) -> Path` in a new `pipeline/test_fixtures_epub.py` or equivalent shared test-support module) so every TDD task in Phase A reuses ONE fixture-generation approach rather than each writing its own from scratch — this is the repository's own explicit instruction for this feature ("reuse the real POC's synthetic-EPUB-generation approach as the test fixture, don't write a new one from scratch"). Do not modify `epub_extract_poc.py` itself; it stays a read-only reference (plan.md's Project Structure).

- [ ] **T006 [P]** Confirm `platform/backend/cmd/ingest-transcript/main.go`'s `docPayload` struct (`main.go:111`) field names and types by reading it directly — record the exact field list verbatim (no guessing) so T013/T014's sidecar-shape test can assert against real field names rather than an assumed shape. Also confirm `platform/backend/pkg/curriculum/curriculum.go`'s `SafeSlug` allowlist and `platform/backend/pkg/curriculum/chapterid.go`'s `ChapterIDGrammar` regex (both cited in data-model.md's Registry Scope section) by reading them, recording the exact regex/allowlist rules for reuse in T021's scope-validation test.

- [ ] **T006a [TDD]** **`Attrs` passthrough (FR-021) — a Go backend prerequisite, not a Phase A EPUB-extractor task.** Spec 015's Location Anchor design depends on this channel existing before Phase 2's PDF/FB2/DOCX/HTML extractors (or a future EPUB CFI enhancement) have anywhere to write page/CFI/heading metadata, so it belongs here in Foundational rather than under Phase A or Phase B specifically. Add a failing test in `platform/backend/internal/passagestore` asserting: given a `docSection`-equivalent payload carrying `attrs: {"epub_cfi": "epubcfi(/6/14!/4/2/2)"}`, decoding it and calling `DocumentObservation(..., WithAttrs(attrs))` (data-model.md's "Go signature change" section) produces an `Observation` whose `Attrs` map round-trips the key/value exactly; a payload with no `attrs` key produces an `Observation` with a nil/zero-value `Attrs`, byte-identical to today's behavior. Then implement the additive `docSection.Attrs` field, the `DocumentObservationOption`/`WithAttrs` functional option, and the `main.go:426` call-site change that passes `d.Attrs` through via `WithAttrs` only when non-empty. Run the new test to confirm GREEN, then re-run the existing `passagestore`/`ingest-transcript` suites to confirm the 9 pre-existing `DocumentObservation` call sites still compile and pass unmodified (data-model.md names all 9 by file:line).

**Checkpoint**: Contracts recorded from real source, not memory. Phase A can now begin.

---

## Phase A: User Story 1 — Ingest a licensed EPUB textbook into searchable curriculum content (Priority: P1) 🎯 MVP

**Goal**: A real, well-formed, licensed EPUB textbook becomes searchable `doc_section` content via `pipeline/epub_sections.py`, with zero new Go code.

**Independent Test**: `pipeline/venv/bin/python -m pytest pipeline/test_epub_sections.py -v` plus quickstart.md Scenarios 2, 3, 5.

### License gate (FR-005) — built and proven first, because it is the run-order-critical invariant

- [ ] **T007 [TDD] [US1]** Create `pipeline/test_epub_sections.py` with a failing test asserting the license gate runs BEFORE any EPUB byte is read: invoking `epub_sections.main()`/CLI entry point with no `--license-basis` against a path that does not even exist still exits `1` with zero bytes written to the output path — proving the check precedes file I/O, not merely that it eventually rejects a bad file. Include T004's recorded contract as a module-level docstring comment in this file.

- [ ] **T008 [TDD] [US1]** Implement the minimal `pipeline/epub_sections.py` module skeleton: argparse mirroring `md_sections.py`'s own CLI shape (`<textbook.epub> <out.json> --chapter-slug <slug> [--path <as-recorded>] --license-basis <basis>`, per contracts/epub-ingestion-stage.md) with `--license-basis` mandatory and checked first, before opening the input path. Run T007 to confirm GREEN.

### Spine order (FR-002, SC-002)

- [ ] **T009 [TDD] [US1]** Add a failing test using T005's fixture helper: build a synthetic EPUB whose OPF `<spine>` order is deliberately DIFFERENT from its manifest/directory/filename order (e.g. spine references `ch2.xhtml` before `ch1.xhtml` while the ZIP entries and manifest are alphabetical) and assert the extractor's section order follows the spine, not the directory listing.

- [ ] **T010 [TDD] [US1]** Implement OPF/spine parsing via `ebooklib` (reading `<manifest>` and `<spine>` per contracts/epub-ingestion-stage.md step 3) so reading order is spine `<itemref>` order exclusively. Run T009 to confirm GREEN.

### Heading-delimited sectioning + stub filtering (FR-003)

- [ ] **T011 [TDD] [US1]** Add a failing test reusing T005's helper to regenerate the POC's own well-formed 3-chapter/6-section synthetic EPUB shape and assert: a well-formed EPUB with 3 chapters produces exactly 3 XHTML spine documents, each split at `h1`-`h6` boundaries into exactly 2 sections, for **6 total `doc_section` sidecar entries** in correct spine order (ch1→ch2→ch3) — the same structural assertion the POC's own captured run already demonstrates (quickstart.md Scenario 1, "6 sections, correct spine order ch1->ch2->ch3").

- [ ] **T012 [TDD] [US1]** Implement heading-boundary sectioning (`h1`-`h6`) with the `MIN_CHARS = 120` stub-filter threshold reused by value from T004's recording. Run T011 to confirm GREEN.

### Sidecar output shape (FR-001, data-model.md)

- [ ] **T013 [TDD] [US1]** Add a failing test asserting the sidecar JSON's keys match `docPayload`'s real field names from T006 byte-for-byte: `chapter_slug`, `source_file`, and `sections[]` with `text`, `path` (`"<epub filename>#<spine href>"` per data-model.md's `path_label` convention), `line_start`/`line_end` (block ordinals, not text-file lines), and `kind: "doc_section"` — asserting exact key presence/absence, not merely that decoding succeeds.

- [ ] **T014 [TDD] [US1]** Implement the sidecar JSON writer matching T013's shape exactly. Run T013 to confirm GREEN.

### License Record gate, full-file enforcement (FR-005) — the hard requirement, not an afterthought

- [ ] **T015 [TDD] [US1] [REVIEW]** Add a failing test using a REAL, non-trivial multi-chapter EPUB fixture (not T007's not-even-opened path): with no `--license-basis`, the run refuses with exit `1` and **zero** passages/sidecar entries minted — verified by asserting the output file is absent or empty, never partially written. This is FR-005's core acceptance scenario (spec.md Acceptance Scenario 4, SC-003) and is marked `[REVIEW]` because this spec explicitly calls it a hard requirement, not an afterthought.

- [ ] **T016 [TDD] [US1] [REVIEW]** Implement the License Record's storage: write `basis`/`recorded_by`/`recorded_at` (data-model.md's License Record fields) into the extraction sidecar's own output as the Phase 1 storage-shape decision — data-model.md explicitly leaves this open ("an implementation detail Phase 1 must still pick"); record this choice in the module's own docstring so it is a stated decision, not a silent default. Run T015 to confirm GREEN. Independent review required before this task is considered done, per this feature's own instruction that the License Record gate get its own concrete, reviewed task.

### DRM detection (FR-009)

- [ ] **T017 [TDD] [US1]** Add a failing test: a fixture EPUB carrying a `META-INF/encryption.xml` entry (the real, detectable signal for Adobe ADEPT / most commercial DRM-wrapped EPUBs — build this fixture by adding that entry to T005's helper output, not by sourcing an actual DRM-protected file) is refused with an explicit reason naming DRM, and the extractor never attempts, implies, or falls through to any decryption step.

- [ ] **T018 [TDD] [US1]** Implement DRM detection: check for `META-INF/encryption.xml` presence in the EPUB ZIP before OPF parsing begins, refusing with a named reason (per contracts/epub-ingestion-stage.md's DRM detection step and FR-009). Run T017 to confirm GREEN.

### Untrusted-input-safe XML parsing (FR-008)

- [ ] **T019 [TDD] [US1]** Add a failing test asserting OPF/XHTML parsing in `epub_sections.py` goes through `defusedxml.ElementTree`, not bare `xml.etree.ElementTree` — construct a fixture with a billion-laughs-style entity-expansion payload in a spine XHTML document and assert the extractor safely refuses/rejects it rather than hanging or crashing.

- [ ] **T020 [TDD] [US1]** Implement `defusedxml.ElementTree` for any raw XML parsing step this module performs that is not fully delegated to `ebooklib` internals (FR-008). Run T019 to confirm GREEN.

### Registry Scope validation (FR-006, SC-005)

- [ ] **T021 [TDD] [US1]** Add a failing test using T006's recorded `SafeSlug`/`ChapterIDGrammar` rules: a `--chapter-slug` value of `textbook-<slug>` shape passes the same allowlist `SafeSlug` accepts (letters/digits/`-_.`, ≤128 chars, no path separators) but FAILS `ChapterIDGrammar`'s `^[0-9]{2,}(\.[0-9]{2,})*$` pattern — a pure-Python regex assertion against the rules recorded in T006, cited by file:line.

- [ ] **T022 [TDD] [US1]** Implement `--chapter-slug` validation in `epub_sections.py` requiring the `textbook-` prefix shape (FR-006). Run T021 to confirm GREEN.

### Idempotency (FR-007, SC-004)

- [ ] **T023 [TDD] [US1]** Add a failing test for the three-tier idempotent anchor-carry-forward: (a) re-running against an UNCHANGED EPUB with a prior sidecar present produces a byte-identical sidecar (same `pid`s, once carried) with zero new mints; (b) re-running against a LIGHTLY-EDITED copy (one section's text changed via a typo fix, same section position/identity) carries the SAME `pid` forward via the exact-text-match-then-position-range tier, rather than minting a duplicate.

- [ ] **T024 [TDD] [US1]** Implement the three-tier match (inline `pid` anchor → exact text match → unambiguous position-range match), reused by value from T004's recording of `md_sections.py`'s own strategy. Run T023 to confirm GREEN.

### Partial-failure handling (FR-010) — built here since it is load-bearing for Phase A's own real-fixture run, refined further in Phase C

- [ ] **T025 [TDD] [US1]** Add a failing test: an EPUB with one malformed-XHTML spine document among otherwise well-formed ones still processes the well-formed documents and names the failed one explicitly in the run's output (a minimal failure-naming mechanism — Phase C's T042/T043 later generalize this into the full Extraction Failure Report shape; this task only needs the run to not abort and to not silently drop the failure).

- [ ] **T026 [TDD] [US1]** Implement per-spine-document exception handling so one malformed document does not abort the whole run (FR-010). Run T025 to confirm GREEN.

### Verification against real content

- [ ] **T027 [US1]** Run `pipeline/venv/bin/python -m pytest pipeline/test_epub_sections.py -v` (full module). Paste the real pass/fail summary into this task's completion note.

- [ ] **T028 [US1] [REVIEW]** Run quickstart.md Scenario 3 for real end to end, against one real, well-formed, licensed EPUB textbook (e.g. a Project Gutenberg public-domain EPUB whose spine order differs from its own directory/filename listing, satisfying SC-002's specific fixture requirement) — **against a SCRATCH COPY of `curriculum/passages.jsonl` first**, per quickstart's own caution: `epub_sections.py` → `ingest-transcript -docs` → `index-embed` → `grep '"scope": *"textbook-<slug>"' passages.jsonl | wc -l`. Paste the real non-zero count.

- [ ] **T029 [US1]** Run quickstart.md Scenario 5 for real against the running `workshop-server`: confirm `/api/chapters` does NOT list the `textbook-<slug>` scope (FR-006, SC-005), while its sections remain reachable at `/passage/{pid}` (FR-011). Paste the real `curl`+`python3` output.

- [ ] **T030 [US1] [REVIEW]** Run quickstart.md Scenario 3's search-path check (SC-001, SC-006): confirm a search query matching text unique to one ingested section returns it via BOTH the lexical (FTS5) and semantic (embedding) paths, with no measurable search-latency regression attributable to the addition. This is User Story 1's checkpoint-completing task — `[REVIEW]` required before the MVP is considered done.

**Checkpoint**: User Story 1 (the literal MVP) is independently complete and testable — a real EPUB textbook is now searchable, citable `doc_section` content, gated by a working license check, with zero new Go code.

---

## Phase B: User Story 2 — Expand ingestion to PDF, FB2, DOCX and HTML textbooks (Priority: P2)

**Goal**: Each additional format reuses Phase A's proven shape (license gate, `textbook-<slug>` scope, sidecar contract, idempotency) and adds only its own format-specific extraction stage.

**Depends on**: Phase A (reuses its sidecar shape, license-gate pattern, and scope-validation logic by value — read `epub_sections.py` before writing any Phase B module).

**Independent Test**: One new `pytest` module per format, plus quickstart.md-equivalent one-fixture-per-format runs (SC-007).

### PDF (FR-013) — `pdftotext -layout`, the existing production convention

- [ ] **T031 [P] [TDD] [US2]** Read `pipeline/transcribe/pdf_notes.py`'s `resolve_pdftotext()` binary-resolution helper and its `pdftotext -layout` subprocess-invocation pattern in full — this is the EXISTING production convention FR-013 requires reuse of, not a new PDF library. Create `pipeline/test_pdf_sections.py` with a failing test: a text-layer (not scanned) PDF fixture, processed via that same subprocess pattern, produces sectioned `doc_section` output matching Phase A's sidecar contract exactly (chapter_slug/source_file/sections[] shape from T013).

- [ ] **T032 [TDD] [SUBAGENT] [US2]** Implement `pipeline/pdf_sections.py`: `pdftotext -layout` extraction reusing `pdf_notes.py`'s own resolver (do not write a second copy of it), blank-line-delimited paragraph sectioning with the `MIN_CHARS` stub filter (PDF has no native heading tags — true heading detection via font-size/layout cues is explicitly out of scope per plan.md's Assumptions and the edge-case list's multi-column-layout note; this is a documented Phase 2 limitation, not a silent gap), plus the license gate (T016's shape) and `textbook-<slug>` scope validation (T022's logic) reused by value. Run T031 to confirm GREEN.

- [ ] **T033 [US2]** Ingest one real, licensed, text-layer PDF textbook fixture end to end (mirroring T028's scratch-copy caution) and confirm its `doc_section` rows are indistinguishable in search behavior and citation route from Phase A's EPUB-sourced rows (SC-007). Paste real output.

### FB2 (FR-014) — native `<section>`/`<title>` hierarchy, no heading heuristic

- [ ] **T034 [P] [TDD] [US2]** Create `pipeline/test_fb2_sections.py` with a failing test: an FB2 fixture with a nested `<section>`/`<title>` hierarchy produces section boundaries that follow that native structure directly — asserting no heading-inference heuristic is applied (i.e. a `<section>` with no `<title>` still forms its own section, unlike a heading-text-matching approach would require).

- [ ] **T035 [TDD] [SUBAGENT] [US2]** Implement `pipeline/fb2_sections.py`, walking FB2's native XML hierarchy via `defusedxml.ElementTree` (FB2 is XML, so FR-008 applies here identically to EPUB's OPF/XHTML), reusing the license gate and scope-validation logic by value. Run T034 to confirm GREEN.

- [ ] **T036 [US2]** Ingest one real, licensed FB2 textbook fixture end to end; confirm SC-007 parity. Paste real output.

### DOCX (FR-016) — paragraph style, not the discarding regex-strip pattern

- [ ] **T037 [P] [TDD] [US2]** Confirm by search that no `_read_ooxml`-named regex-strip function exists anywhere under `pipeline/` in this repository (checked this session: zero matches) — if a differently-named structure-discarding OOXML reader IS found during implementation, this task's completion note MUST name it explicitly rather than silently assuming none exists. Create `pipeline/test_docx_sections.py` with a failing test: a DOCX fixture whose paragraphs carry `pStyle` values of `"Heading1"`/`"Heading2"` produces section boundaries at those paragraphs, preserving the structure rather than discarding it.

- [ ] **T038 [TDD] [SUBAGENT] [US2]** Implement `pipeline/docx_sections.py`, reading `word/document.xml`'s paragraph `pStyle` values via `defusedxml.ElementTree` (DOCX's package XML also warrants FR-008's hardened parser) to detect heading-styled paragraphs as section boundaries, reusing the license gate and scope validation by value. Run T037 to confirm GREEN.

- [ ] **T039 [US2]** Ingest one real, licensed DOCX textbook manuscript fixture end to end; confirm SC-007 parity. Paste real output.

### HTML (FR-015) — DOM headings, and the one format that gets real inline anchors

- [ ] **T040 [P] [TDD] [US2]** Confirm via `submodules/passage/pkg/passage/anchor.go`'s `SyntaxForPath` (lines 63-65, read this session) that `.html`/`.htm` ARE recognized for `SyntaxHTML` inline anchors — unlike EPUB's `.xhtml`, per spec.md's own edge case. Create `pipeline/test_html_sections.py` with a failing test: a standalone HTML fixture's real DOM heading elements determine section boundaries, AND after a first successful ingestion, an inline `<!-- pid: ... -->` anchor is written back into the `.html` source file itself (grep the source file for the literal marker after the run — this is a source-file mutation, not just a sidecar field).

- [ ] **T041 [TDD] [SUBAGENT] [US2]** Implement `pipeline/html_sections.py`: DOM heading-element walking for section boundaries, plus inline-anchor writeback reusing WHICHEVER existing inline-anchor-writing helper `md_sections.py` itself already uses for `.md` (`.md` is also `SyntaxHTML`-syntax per `anchor.go`'s same switch case — read `md_sections.py`'s own anchor-writeback code and reuse it directly rather than writing a second implementation), plus the license gate and scope validation by value. Run T040 to confirm GREEN.

- [ ] **T042 [US2]** Ingest one real, licensed standalone HTML textbook document fixture end to end; confirm the inline `<!-- pid: ... -->` anchor genuinely appears in the source file after ingestion (`grep '<!-- pid:' <file>`) and that SC-007 parity holds. Paste real output.

### Cross-format regression

- [ ] **T043 [US2] [REVIEW]** Run the full Phase B regression: `pytest pipeline/test_pdf_sections.py pipeline/test_fb2_sections.py pipeline/test_docx_sections.py pipeline/test_html_sections.py pipeline/test_epub_sections.py -v`, plus `pipeline/test_build_transcript.py`, confirming zero regression to Phase A's EPUB path or to `md_sections.py`'s own existing suite. Paste the real summary. This is User Story 2's checkpoint-completing task — `[REVIEW]` required.

**Checkpoint**: User Stories 1 AND 2 both independently functional — five formats (EPUB, PDF, FB2, DOCX, HTML), each producing `doc_section` content indistinguishable from any other's in search/citation behavior.

---

## Phase C: User Story 3 — Operators can trust extraction completeness and quality signals (Priority: P3)

**Goal**: Extraction runs report what they could NOT parse, not just a bare success count; scanned/image-only PDFs are refused with a named reason rather than silently producing near-empty output.

**Kept deliberately light/deferred**, per this feature's own instruction — the plan itself treats Phase 3 as exploratory quality/scale hardening layered on Phase A/B's already-working extraction paths, not a blocker to shipping them. FR-018's OCR-PROVISIONED half and FR-020's promotion question are explicitly **not** resolved by this phase.

**Depends on**: Phase A and Phase B (wraps their already-working extraction paths with reporting, rather than replacing anything).

**Independent Test**: quickstart.md Scenario 6.

- [ ] **T044 [TDD] [US3]** Add a failing test asserting the Extraction Failure Report shape (FR-017, data-model.md: `{succeeded_count: int, failures: [{source, reason}]}`) is emitted by EVERY format's extraction run, including when `failures` is empty — never a bare success count with the list silently omitted.

- [ ] **T045 [US3]** Implement a shared `_failures` sidecar key (reusing the POC's own `_poc_spine_report` diagnostic-key-stripped-before-ingest pattern, per data-model.md's explicit precedent) threaded through each of the five format modules (`epub_sections.py`, `pdf_sections.py`, `fb2_sections.py`, `docx_sections.py`, `html_sections.py`), generalizing Phase A's T025/T026 minimal failure-naming into this full shape. Run T044 to confirm GREEN across all five formats.

- [ ] **T046 [TDD] [US3]** Add a failing test for scanned/image-only PDF refusal (FR-018, first half only): a PDF fixture with no extractable text layer (e.g. an image-only page, `pdftotext -layout` returning empty/near-empty output) is refused with an explicit `"no text layer, OCR unavailable"` reason when no OCR toolchain is provisioned — probe for OCR availability with a `shutil.which`-style check (e.g. `tesseract`), never a hardcoded assumption about the host.

- [ ] **T047 [US3]** Implement the no-text-layer detection + refusal path in `pdf_sections.py` (FR-018's refusal half only). Run T046 to confirm GREEN. **Explicitly deferred, not implemented by this task**: OCR-provisioned ingestion (FR-018's second half — proceeding via OCR once a toolchain IS provisioned) and FR-019's OCR-derived visibility marking. State this explicitly in the completion note rather than letting it read as done.

- [ ] **T048 [TDD] [US3]** Extend T025/T026's malformed-document partial-failure handling (FR-010, edge case #1) to Phase B's formats: a multi-document/multi-section source in any format with one malformed unit still processes its well-formed siblings, naming the failed one in the T045 `_failures` report rather than aborting the run or silently dropping it. Run to confirm GREEN.

- [ ] **T049 [SUBAGENT] [US3]** Research spike (self-contained): survey whatever real fixture material is available (or the closest available proxy) for malformed-XHTML frequency, multi-column PDF prevalence, and FB2 encoding variance — per plan.md's own explicit note that "Phase 2/3 format work may require a small spike against real sample material before implementation commitments are finalized." Report findings using `UNCONFIRMED:`/measured framing, per §11.4.6's no-guessing mandate. **Do NOT resolve FR-020** (whether/how textbook structure should ever promote into `kg_area`/`kg_lesson_section`) — data-model.md's "Carried-forward NEEDS CLARIFICATION" section explicitly defers this decision; this task documents evidence toward that future decision, it does not make it.

- [ ] **T050 [US3]** Run quickstart.md Scenario 6 for real:
  ```bash
  PYTHONPATH="." workshop/pipeline/venv/bin/python -m pytest \
      pipeline/test_epub_sections.py -k "drm or malformed" -v
  ```
  Paste the real output demonstrating (a) DRM refusal with an explicit named reason and (b) malformed-document partial-failure handling.

**Checkpoint**: Extraction-completeness reporting exists across all five formats; scanned-PDF refusal is real and reasoned. OCR-provisioned ingestion, OCR-derived visibility marking, and the `kg_lesson_section` promotion question remain **explicitly open**, by design — not silently treated as done.

---

## Phase D: Cross-repository gap — `.xhtml` inline-anchor support in the adopted `passage` submodule

- [ ] **T051 [P] [SUBAGENT]** Document the `.xhtml` extension gap in `submodules/passage/pkg/passage/anchor.go`'s `SyntaxForPath` function (confirmed this session: its switch statement at lines 63-72 recognizes `.md`, `.markdown`, `.html`, `.htm`, `.svg` → `SyntaxHTML`; `.mmd`/`.mermaid` → `SyntaxMermaid`; `.puml`/`.plantuml` → `SyntaxPlantUML` — **`.xhtml` is absent from every case**). This is a low-risk, one-line, separately-landable addition (`case ".xhtml": return SyntaxHTML, true`, alongside the existing `.html`/`.htm` case, since XHTML uses the same `<!-- pid: ... -->` HTML-comment anchor syntax).

  **This task touches an ADOPTED SUBMODULE (`submodules/passage`, upstream `vasic-digital/passage`), NOT workshop's own code — this distinction is the entire point of this task and must not be glossed over.** Per this umbrella repository's own governance (CLAUDE.md, "Owned submodules" / §11.4.74 reuse-before-reimplement), a fix to consumed-submodule code requires **its own PR/process against that submodule's upstream repository** (`vasic-digital/passage` on GitHub) — a dedicated clone/branch/PR there, independent review, merge upstream, and only THEN a gitlink bump back in this umbrella (`helix-deps.yaml`'s `deps[].ref` updated in the SAME change as the gitlink, verified by `scripts/verify-manifest-pins.sh`/cascade check C9). **Do NOT edit `submodules/passage/` directly inside this workshop-tree task, and do NOT commit any change there from this feature's work.** This task's actual deliverable is: the written-up finding above (file, line numbers, exact missing case) plus the proposed one-line diff, handed to the operator as a note/patch for them to carry into the `passage` submodule's own repository — not a commit in this tree.

  **Why this fix is not required for Phase 1/2/3 of this feature to work correctly**: because `.xhtml` is absent today, EPUB's spine documents correctly fall back to sidecar-only anchoring (the `AnchorSidecar` path) per spec.md's own edge-case note — this is explicitly the **known-good** path already used in production for transcript segments, not a degraded one. Landing this submodule fix would only let a FUTURE revision of `epub_sections.py` opt into inline anchors for `.xhtml` sources if ever desired; no Phase A/B/C task in this file depends on it.

---

## Phase E: Polish & Cross-Cutting Concerns

- [ ] **T052 [P]** Confirm T001's `pipeline/requirements.txt` header comment carries the ACTUAL measured wheel tags from T002 (not placeholders), matching the file's existing `faster-whisper`/`ctranslate2` documentation discipline exactly.

- [ ] **T053 [P]** Run the full `pipeline/` regression suite:
  ```bash
  PYTHONPATH="." workshop/pipeline/venv/bin/python -m pytest pipeline/ -v
  ```
  Paste the real pass/fail summary, confirming zero regression to `md_sections.py` or any other existing `pipeline/` module.

- [ ] **T054** Record this feature's completion status in this repository's own operator-facing findings/work-register, explicitly distinguishing what shipped (Phase A EPUB MVP, Phase B's four additional formats, Phase C's failure-reporting + scanned-PDF-refusal-only path) from what remains deliberately open (FR-018's OCR-provisioned ingestion, FR-019's OCR-derived marking, FR-020's `kg_lesson_section` promotion decision, and FR-005's closed license-basis vocabulary) — per this repository's anti-bluff discipline, do not report "complete" without naming these exceptions explicitly.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately. BLOCKS Phase A (new deps must be installed first).
- **Foundational (Phase 2)**: Depends on Setup. BLOCKS Phase A, B, and C (every later task reuses one of T004/T005/T006's recorded contracts).
- **Phase A (US1)**: Depends on Foundational. Fully sequential within itself (every TDD pair shares `epub_sections.py`/`test_epub_sections.py`).
- **Phase B (US2)**: Depends on Phase A (reuses its license-gate/scope-validation/sidecar logic by value — read `epub_sections.py` first). The four format groups (PDF/FB2/DOCX/HTML) touch disjoint files and may run in parallel with each other.
- **Phase C (US3)**: Depends on Phase A AND Phase B (wraps all five formats' extraction paths with reporting).
- **Phase D**: Independent of A/B/C — a documentation/research task about a different repository's code. May run at any point once T019/T020 (Phase A's `defusedxml`/XML-parsing work) has established the XHTML-handling context, or in parallel with anything.
- **Phase E (Polish)**: Depends on all prior phases.

### User Story Dependencies

- **US1 (P1)**: No dependency on US2/US3 — genuinely the MVP, deployable alone.
- **US2 (P2)**: Depends on US1's proven shape (reuses its patterns by value) but is independently testable per format (SC-007 is format-by-format).
- **US3 (P3)**: Depends on US1 AND US2 existing (wraps both) — explicitly the lowest-priority, most-deferred phase.

### Parallel Opportunities

- T001 and T003 (Phase 1) may run in parallel.
- T004, T005, T006 (Phase 2) touch no shared files and may run fully in parallel.
- Within Phase B, the four format groups (T031-T033 PDF, T034-T036 FB2, T037-T039 DOCX, T040-T042 HTML) touch four entirely disjoint new files (`pdf_sections.py`/`fb2_sections.py`/`docx_sections.py`/`html_sections.py` and their four test files) and may be dispatched to four different subagents in parallel — marked `[P]` on each group's first task.
- T051 (Phase D) has no file overlap with any other phase and may run at any time.
- T052 and T053 (Phase E) touch different files and may run in parallel.

---

## Notes

- `[P]` tasks touch different files with no dependency on each other.
- `[TDD]` tasks MUST fail for the stated reason before their paired implementation task is written — do not skip confirming the RED state.
- `[REVIEW]` tasks (T015/T016 — the License Record gate; T030 — US1's checkpoint; T043 — US2's checkpoint) require independent review before being marked done, per this repository's universal code-review mandate; self-review precedes it and never substitutes for it.
- `[SUBAGENT]` tasks (T003, T032, T035, T038, T041, T049, T051) are self-contained enough to dispatch without further context from whoever assigns them.
- Every task whose completion note claims something was "verified" or "confirmed" MUST carry real, pasted command output from that session — not a restatement of what the plan expected to happen.
- FR-020 and the closed half of FR-005 are NOT resolved anywhere in this task list, by design — see Phase C's T049 and data-model.md's "Carried-forward NEEDS CLARIFICATION" section.
