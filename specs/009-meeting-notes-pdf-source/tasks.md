---
description: "Task list for feature 009: PDF-Sourced Meeting Notes with Redaction Gate"
---

# Tasks: PDF-Sourced Meeting Notes with Redaction Gate

**Input**: Design documents from `specs/009-meeting-notes-pdf-source/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [data-model.md](data-model.md), [contracts/pipeline-stage.md](contracts/pipeline-stage.md)

**Global Constraints** (from plan.md's Technical Context and Constitution Check — every task's requirements implicitly include these):

- All work happens inside the private `workshop` submodule (`$VASIC_ROOT/workshop`); no content is copied into the public umbrella repository.
- No new third-party dependency — `pdftotext`, `faster-whisper`, and `whisper.cpp` are already installed and already used elsewhere in this pipeline.
- Determinism is mandatory: any extraction function must produce byte-identical output on repeated runs against unchanged input (FR-005).
- The redaction check (FR-007/FR-008) applies to each item's own final rendered text, never only to the source document as a whole ("Source Is Not Served").
- No silent fallback: a PDF-extraction failure is a terminal, reported state for that PDF, never a silent switch to transcript-based extraction (FR-009).
- Every "this was verified" claim in a task report MUST be backed by real, pasted command output — this plan's sibling HelixQA integration plan (`.superpowers/sdd/2026-09-18-helixqa-integration/progress.md`) already recorded one instance this session of an unsubstantiated "measured live" claim that had to be corrected after the fact. Do not repeat that pattern here.
- `workshop`'s `WORKSHOP_HTTP_BIND` stays loopback-only; nothing in this feature needs it exposed, and nothing in this feature is authorized to change it.
- **Scope note (speckit-analyze remediation, finding F1)**: FR-010 ("the existing disclosure-judgements.jsonl ruling mechanism applies unchanged") is deliberately NOT given its own dedicated task — it is covered by reuse (T017/T019 call the same withheld-item convention every other withheld item in this pipeline already uses), and demonstrating the existing ruling-flip mechanism works is out of scope for this feature since the mechanism itself is unmodified.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup (Research)

**Purpose**: Resolve the one genuine unknown this plan carries forward (plan.md's Project Structure note) before any user story is implemented.

- [ ] **T001 [P]** Locate the existing mechanism that turned `pipeline/transcripts/chapter-02.faster-whisper.json` and `chapter-02.01.faster-whisper.json` into `curriculum/passages.jsonl` `transcript_segment` rows for those two chapters (they are already ingested and already discoverable by `discover_chapters()` — something did this, even if not a dedicated script). Read `pipeline/extract/run_pipeline.py`'s stage list and `pipeline/extract/corpus.py` for an ingestion/import stage; if genuinely no such stage exists and ingestion was done by a one-off or manual step, report that precisely rather than guessing — this finding directly shapes Task T014 (Phase 6) and must not be invented.

**Checkpoint**: The ingestion mechanism for T014 is identified (found, or confirmed genuinely absent with a documented alternative) before Phase 6 begins. Phases 2-5 do not depend on this and may proceed in parallel with T001.

---

## Phase 2: Foundational — none

No infrastructure blocks every story here: User Story 1 needs no new shared scaffolding beyond the new module file itself (created as part of US1's own tasks), and User Story 4's redaction gate is sequenced after US1/US2 produce something to wrap, not before. This phase is intentionally empty.

---

## Phase 3: User Story 1 - PDF is the authoritative source when provided (Priority: P1) 🎯 MVP

**Goal**: Chapter 01's real, currently-unused notes PDF becomes the source of its meeting-notes content.

**Independent Test**: `python3 -m pytest pipeline/extract/test_meeting_notes_pdf.py -v` plus `quickstart.md`'s Scenario 1 and 2 against the real chapter 01 PDF.

- [ ] **T002 [TDD] [US1]** Read `pipeline/extract/meeting_notes.py` in full (specifically `extract_next_meeting_points`, `extract_todo_items`, `extract_meeting_notes`, `extract_open_questions`, and the `external_key` construction) to mirror its exact function signatures and cue-phrase-matching approach — this task's new module must reuse the SAME heuristics against PDF-extracted text, not invent parallel ones. Record the exact signatures found (do not guess them) in a short note at the top of the new test file created in T003, so later tasks in this feature can cite them without re-reading the source file each time.

- [ ] **T003 [TDD] [US1]** Create `workshop/pipeline/extract/test_meeting_notes_pdf.py` with a failing test for PDF discovery:

```python
import unittest
from pathlib import Path
from pipeline.extract import meeting_notes_pdf


class TestDiscoverNotesPdf(unittest.TestCase):
    def test_finds_a_matching_pdf(self):
        chapter_dir = Path(__file__).parent / "fixtures" / "chapter_with_pdf"
        found = meeting_notes_pdf.discover_notes_pdfs(chapter_dir)
        self.assertEqual(len(found), 1)
        self.assertTrue(found[0].name.endswith(" - Notes by Fixture Tool.pdf"))

    def test_finds_no_pdf_when_none_matches(self):
        chapter_dir = Path(__file__).parent / "fixtures" / "chapter_without_pdf"
        found = meeting_notes_pdf.discover_notes_pdfs(chapter_dir)
        self.assertEqual(found, [])

    def test_finds_multiple_matching_pdfs(self):
        chapter_dir = Path(__file__).parent / "fixtures" / "chapter_with_two_pdfs"
        found = meeting_notes_pdf.discover_notes_pdfs(chapter_dir)
        self.assertEqual(len(found), 2)
```

Create the three fixture directories under `pipeline/extract/fixtures/` referenced above: `chapter_with_pdf/` containing one file matching `* - Notes by *.pdf` (any real, tiny, single-page PDF you generate — reuse `pdf_notes.py`'s own `build_pdf_fixture()` helper, already used by its test suite, to build a minimal valid PDF byte-for-byte rather than hand-crafting PDF bytes), `chapter_without_pdf/` containing only an unrelated file, and `chapter_with_two_pdfs/` containing two files each matching the pattern with different tool names.

- [ ] **T004 [TDD] [US1]** Run the test to verify it fails with `ModuleNotFoundError` or `AttributeError` (the module and function do not exist yet):

```bash
cd $VASIC_ROOT/workshop
python3 -m pytest pipeline/extract/test_meeting_notes_pdf.py::TestDiscoverNotesPdf -v
```
Expected: FAIL, `ModuleNotFoundError: No module named 'pipeline.extract.meeting_notes_pdf'`.

- [ ] **T005 [TDD] [US1]** Create `workshop/pipeline/extract/meeting_notes_pdf.py` with the minimal `discover_notes_pdfs` implementation:

```python
"""meeting_notes_pdf.py — PDF-sourced meeting-notes extraction.

Companion to meeting_notes.py's transcript-sourced extraction (T-MEETING-NOTES).
When a chapter has one or more notes PDFs (discovered by filename convention),
each is treated as an authoritative source for that chapter's meeting-notes
content, per FR-002/FR-001a of specs/009-meeting-notes-pdf-source/spec.md.
"""
import re
from pathlib import Path

_NOTES_PDF_RE = re.compile(r".* - Notes by .*\.pdf$", re.IGNORECASE)


def discover_notes_pdfs(chapter_dir: Path) -> list[Path]:
    """Return every file in chapter_dir matching '* - Notes by *.pdf'
    (case-insensitive extension), sorted by name for deterministic ordering."""
    return sorted(
        p for p in chapter_dir.iterdir()
        if p.is_file() and _NOTES_PDF_RE.match(p.name)
    )
```

- [ ] **T006 [TDD] [US1]** Run the test again to verify it passes:

```bash
python3 -m pytest pipeline/extract/test_meeting_notes_pdf.py::TestDiscoverNotesPdf -v
```
Expected: PASS, all three cases.

- [ ] **T007 [TDD] [US1]** Add a failing test for deterministic text extraction via `pdftotext`, using the SAME `resolve_pdftotext()` binary-resolution helper `pdf_notes.py` already has (read it and reuse it — do not write a second copy):

```python
class TestExtractPdfText(unittest.TestCase):
    def test_extracts_text_deterministically(self):
        chapter_dir = Path(__file__).parent / "fixtures" / "chapter_with_pdf"
        pdf_path = meeting_notes_pdf.discover_notes_pdfs(chapter_dir)[0]
        text1 = meeting_notes_pdf.extract_pdf_text(pdf_path)
        text2 = meeting_notes_pdf.extract_pdf_text(pdf_path)
        self.assertEqual(text1, text2)
        self.assertIsInstance(text1, str)
        self.assertGreater(len(text1), 0)
```

- [ ] **T008 [TDD] [US1]** Implement `extract_pdf_text(pdf_path: Path) -> str` in `meeting_notes_pdf.py`, calling `pdftotext` via the same subprocess pattern `pdf_notes.py`'s `extract_pages()` uses (read it first — mirror its error handling for a missing/corrupt PDF, since T010 below tests that path). Run the test from T007 to confirm PASS.

- [ ] **T009 [TDD] [US1]** Add a failing test for the extraction-failure path (FR-009):

```python
class TestExtractionFailure(unittest.TestCase):
    def test_corrupt_pdf_raises_a_specific_error(self):
        chapter_dir = Path(__file__).parent / "fixtures" / "chapter_with_corrupt_pdf"
        chapter_dir.mkdir(exist_ok=True)
        corrupt = chapter_dir / "Session - Notes by Broken Tool.pdf"
        corrupt.write_bytes(b"not a real pdf")
        pdf_path = meeting_notes_pdf.discover_notes_pdfs(chapter_dir)[0]
        with self.assertRaises(meeting_notes_pdf.PdfExtractionError):
            meeting_notes_pdf.extract_pdf_text(pdf_path)
```

Implement the `PdfExtractionError` exception class and raise it from `extract_pdf_text` when `pdftotext` exits non-zero or produces no text, per FR-009's "no silent fallback" requirement. Run to confirm PASS, then run the FULL `test_meeting_notes_pdf.py` file to confirm nothing else broke.

- [ ] **T010 [TDD] [US1]** Add cue-phrase mining: a failing test asserting that `mine_pdf_sections(text: str) -> list[PdfSection]` (new dataclass `PdfSection` with `index: int` and `text: str` fields, per `data-model.md`'s PDF-Section Citation Anchor) splits extracted text into sections the SAME way `meeting_notes.py`'s existing cue-phrase functions expect to consume input (re-read T002's recorded signatures before writing this — the split granularity must match what `extract_meeting_notes` etc. can already operate on, since T011 reuses those functions directly rather than reimplementing cue-phrase matching for PDF text).

- [ ] **T011 [TDD] [US1]** Implement `mine_pdf_sections` and a top-level `extract_from_pdf(pdf_path: Path, chapter_scope: str) -> dict` that: extracts text (T008), splits into sections (T010), and calls `meeting_notes.py`'s existing `extract_next_meeting_points` / `extract_todo_items` / `extract_meeting_notes` / `extract_open_questions` against each section's text, producing items that cite a `pdf_notes_section` passage (per `data-model.md`) instead of a `transcript_segment`. Run the full test file; all tests PASS.

- [ ] **T011a [TDD] [US1]** *(added by speckit-analyze remediation, closing coverage gap E1 — SC-008 had no end-to-end test)* Add a failing integration-level test proving that when a chapter has TWO matching notes PDFs (reuse the `chapter_with_two_pdfs` fixture from T003), calling the per-chapter dispatch mints items from **both** PDFs independently, each citing its own distinct `pdf_notes_section` (different `source_path`). This is a genuinely different assertion from T003 (which only tests that `discover_notes_pdfs` *finds* 2 files) — T011a proves both files actually get processed and produce independent output, not just discovered. Implement whatever minimal per-chapter loop is needed to make it pass (this may already exist from T011's own `extract_from_pdf` being called once per discovered path — if so, this task is confirming existing behavior with a real test, not adding new code; say which in your report).

- [ ] **T012 [US1]** Wire `extract_from_pdf` into `meeting_notes.py`'s existing per-chapter dispatch: when `discover_notes_pdfs(chapter_dir)` returns one or more paths, call `extract_from_pdf` for each and skip transcript-based extraction for that chapter entirely (FR-002). Read `meeting_notes.py`'s existing chapter-processing loop (near `discover_chapters`) before editing, to insert this branch at the correct point without disturbing the existing transcript path's control flow. **Closing coverage gap E2 (speckit-analyze remediation): this task MUST explicitly catch `PdfExtractionError` per-PDF (T009's exception) at this dispatch level and report `state: "extraction_failed"` for that specific PDF (FR-009) — do not let the exception propagate uncaught, and do not let it fall through to transcript-based extraction for that chapter.** Add a task-level test (beyond T009's low-level unit test) proving that a chapter with one corrupt PDF and an otherwise-valid transcript still reports `extraction_failed` for that PDF and does NOT fall back to extracting from the transcript.

- [ ] **T013 [US1]** Run `quickstart.md`'s Scenario 1 and Scenario 2 for real against chapter 01's actual PDF (`chapters/01/Milos teaching Rami AI workflows - 2026_08_27 09_57 CEST - Notes by Gemini.PDF`). Paste the real command output (the `grep` results showing minted items citing a `pdf_notes_section`, and the `diff` from the determinism check showing no output) into this task's completion note.

**Checkpoint**: User Story 1 is independently complete and testable — chapter 01's real PDF now sources its meeting notes, deterministically, with no redaction gate yet (added in Phase 5).

---

## Phase 4: User Story 2 - Transcript-only chapters keep working exactly as before (Priority: P1)

**Goal**: Zero regression for chapters with only a transcript (e.g. chapter 02.01).

**Independent Test**: `quickstart.md`'s Scenario 3.

- [ ] **T014 [P] [US2]** Add a regression test to `pipeline/extract/test_meeting_notes.py` (the EXISTING test file, not the new one) asserting that a chapter with a transcript and no notes PDF still calls the existing extraction functions unchanged — a golden-file comparison against `curriculum/passages.jsonl`'s current chapter-02.01 rows is the simplest correct oracle here (read the existing test file's own fixture conventions first and match them).

- [ ] **T015 [US2]** Run `quickstart.md`'s Scenario 3 for real: capture `curriculum/passages.jsonl`'s chapter-02.01 rows before and after this feature's other changes (T002-T013 above) are applied, and confirm the `diff` is empty. Paste the real `diff` output (or its absence) into this task's completion note.

**Checkpoint**: Both P1 stories (US1, US2) are complete and independently verified — this is a legitimate MVP point.

---

## Phase 5: User Story 4 - No meeting-notes content is served without a redaction check (Priority: P1)

**Goal**: Close the existing gap — every item from either sourcing path is checked before being served.

**Depends on**: Phase 3 (US1) and Phase 4 (US2) both existing, since this phase wraps their output rather than replacing it.

**Independent Test**: `quickstart.md`'s Scenario 4.

- [ ] **T016 [TDD] [REVIEW]** Add a failing test in `test_meeting_notes_pdf.py` asserting that `extract_from_pdf` withholds an item whose final rendered text contains a roster name — read `publication_policy.py`'s `is_publishable_content(text, roster)` signature first and call it exactly as `publication_policy.py`'s own existing callers do (do not reinvent the roster-loading step; reuse `load_participant_roster()`).

- [ ] **T017 [TDD] [REVIEW]** Implement the redaction-gate call inside `extract_from_pdf` (T011's function): after mining each item's final text (FR-008 — the item's own rendered text, never the whole source document), call `is_publishable_content`; on a negative result, mint the item using this pipeline's EXISTING withheld-item state convention (read how `meeting_notes.py`'s transcript path already represents a withheld item, if it does one already for another reason, or how `taxonomy.py`'s redaction path represents one — reuse that shape exactly, do not invent a new `state` value). Run T016 to confirm PASS.

- [ ] **T018 [TDD] [REVIEW]** Add a failing test for FR-011's PII-pattern check (PDF-sourced path only): a fixture item containing an email address (e.g. `test@example.com`) or a phone-number-shaped string is withheld even with no roster-name match. Implement a narrow, explicitly-scoped pattern check (two patterns: email, phone — not a general PII/NLP detector, per the spec's own Assumptions) inside `extract_from_pdf` only (never applied to the transcript path, per FR-011's own wording). Run to confirm PASS.

- [ ] **T019 [TDD] [REVIEW]** Add the SAME redaction-gate call (T017's mechanism, without the PDF-only PII-pattern addition) to `meeting_notes.py`'s existing transcript-sourced extraction path, closing the gap for existing content too. Add a regression test proving a synthetic transcript-sourced item containing a roster name is now withheld where it previously would not have been.

- [ ] **T020 [US4]** Run `quickstart.md`'s Scenario 4 for real (both the new PDF-path redaction tests and the transcript-path ones). Then run SC-006's full-corpus check: re-run extraction against every EXISTING transcript-sourced chapter and confirm zero new withholdings (no false positives) by diffing the withheld-item count before and after. Paste real output for both.

**Checkpoint**: All three P1 stories (US1, US2, US4) complete. This is the feature's core deliverable — User Story 3 (below) is additive and lower priority.

---

## Phase 6: User Story 3 - Chapter 02.02 gets a real transcript, then real meeting notes (Priority: P2)

**Goal**: Chapter 02.02 stops reporting "unwritten."

**Depends on**: T001's research finding (Phase 1) for the exact ingestion mechanism to reuse.

**Independent Test**: `quickstart.md`'s Scenario 5.

- [ ] **T021 [US3]** Using T001's finding, produce a WAV extraction from `chapters/02.02/2026-09-09 20-45-25.mp4` (via `ffmpeg`, matching whatever invocation the chapter-02/02.01 precedent used, if T001 found one — otherwise the simplest correct extraction: mono, 16kHz, matching `run_faster_whisper.py`'s documented input expectations, read its docstring/argparse help first).

- [ ] **T022 [US3]** Run `pipeline/run_faster_whisper.py` against that WAV file, producing `pipeline/transcripts/chapter-02.02.faster-whisper.json`, exactly mirroring the existing chapter-02/02.01 invocation (read their real invocation from this repo's own history — `git log -p -- pipeline/transcripts/chapter-02.faster-whisper.json`'s introducing commit likely shows the command in its message, or `docs/`/`CALIBRATION.md` may document it — do not guess the model/compute-type flags).

- [ ] **T023 [US3]** Apply T001's identified ingestion mechanism to turn `chapter-02.02.faster-whisper.json` into `curriculum/chapter-02.02/` `transcript_segment` passages, discoverable by the existing `discover_chapters()`. If T001 found no existing reusable mechanism, this task's scope grows to writing the minimal ingestion step needed — treat that discovery as a BLOCKED-and-report condition first, since it changes this task's size significantly and should not be absorbed silently.

- [ ] **T024 [US3]** Run `quickstart.md`'s Scenario 5 for real: confirm chapter 02.02 is now discovered by `discover_chapters()`, run the meeting-notes pipeline stage against it, and confirm it no longer reports `state: "unwritten"` for any of the four entity kinds. Paste the real `grep` output into this task's completion note.

**Checkpoint**: All four user stories complete.

---

## Phase 7: Polish

- [ ] **T025 [P]** Run the full regression suite: `python3 -m pytest pipeline/extract/ -v`. Paste the real pass/fail summary.
- [ ] **T026** Update `docs/work-register.md` (this repository's own operator-facing findings log) noting this feature's completion and, per this plan's Constitution Check "Environment Adaptability" row, that the ASR prerequisite (Phase 6) depends on this specific host's already-installed local ASR stack.

---

## Dependencies

- Phase 1 (T001) has no dependency and may run in parallel with Phases 3-4.
- Phase 3 (US1) has no dependency on Phase 4 (US2) or vice versa — both are P1, both independently testable, genuinely parallel-dispatchable.
- Phase 5 (US4) depends on Phase 3 AND Phase 4 (it wraps both extraction paths' output).
- Phase 6 (US3) depends on Phase 1 (T001's research finding) and, for its own quickstart scenario to be meaningful, on Phase 3/4/5 already being in place (US3's output is processed by the SAME redaction-gated transcript path Phase 5 builds).
- Phase 7 depends on all prior phases.

## Parallel Execution Notes

Phase 3 (US1, T002-T013) and Phase 4 (US2, T014-T015) touch different code
paths (`meeting_notes_pdf.py` new module vs. a regression test added to the
existing `meeting_notes.py`/`test_meeting_notes.py`) and share no file except
`meeting_notes.py` itself, which T012 (US1's last step, wiring the dispatch)
and T014 (US2's test) both touch — **sequence T012 before T014 to avoid two
concurrent edits to the same file**, or dispatch them to the SAME subagent as
a small sequential pair rather than two parallel subagents, per
subagent-driven-development's own "never dispatch multiple implementation
subagents in parallel" rule when they share a file. T001 (Phase 1 research)
has no file overlap with either and may run fully in parallel with both.
