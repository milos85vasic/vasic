# Quickstart: PDF-Sourced Meeting Notes with Redaction Gate

Runnable validation scenarios proving this feature works end-to-end. Run from
`$VASIC_ROOT/workshop` unless noted. Every command below is expected to be
run for real, with real output pasted into the implementing task's report —
per this repository's anti-bluff discipline, "ran the plan" is not evidence;
the command's actual output is.

**Correction history, so this file is trusted rather than re-guessed at
again**: an earlier revision of this file called
`run_chapter_meeting_notes('01')` with a bare chapter-id string and grepped
for a `"chapter_scope"` JSONL field. Neither is real — found and reported by
Phase 4's implementer (T015), after the controller had introduced both errors
while "fixing" a *different*, also-real problem Phase 3 found (the CLI flags
below). The real function signature and the real JSONL schema, confirmed by
directly running them (Phase 3's T013, Phase 4's T015), are used below.

## Prerequisites

```bash
command -v pdftotext                                    # already present, per umbrella CLAUDE.md
pipeline/venv/bin/python -c 'import faster_whisper; print(faster_whisper.__version__)'
git -C pipeline/engines/whisper.cpp describe --tags 2>/dev/null || echo "whisper.cpp check separately"
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/test_meeting_notes.py -v   # baseline: today's suite, must be green before starting
```

## The real invocation pattern

`run_pipeline.py` has no `--stage`/`--chapter` CLI flags (its real CLI is
`--no-resume`/`--no-author`/`--no-meeting-notes`/`--author`/`--review` only —
found by Phase 3's T013). Every scenario below instead calls the real
function `run_pipeline.py`'s own wrapper calls,
`meeting_notes.run_chapter_meeting_notes`, whose real signature is:

```python
run_chapter_meeting_notes(
    chapter: ChapterRef, passages: list[Passage], out_dir: Path | str,
    sync_fn, registry_path: Path | str, chapters_root: Path | str | None = None,
) -> ChapterMeetingNotesResult
```

— not a bare chapter-id string (found by Phase 4's T015). `ChapterRef`
objects come from `discover_chapters(passages)`; `sync_fn` is the real
`minting.sync_areas` (never a fake — this pipeline's own established
discipline, per `TestRealBridgeMinting`, is to prove against the real
`go run ./cmd/knowledge-mint` bridge, not a stub). A shared helper, used by
every scenario below:

```bash
cat > /tmp/run_chapter.py <<'PYEOF'
import sys
from corpus import load_passages
from meeting_notes import discover_chapters, run_chapter_meeting_notes
from minting import sync_areas

scope, registry_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
passages = load_passages(registry_path)
chapters, findings = discover_chapters(passages)
chapter = next(c for c in chapters if c.scope == scope)
result = run_chapter_meeting_notes(
    chapter, passages, out_dir, sync_areas, registry_path,
    chapters_root="chapters",
)
print(result)
PYEOF
```

Also corrected: the real JSONL schema has no `"chapter_scope"` field.
`transcript_segment`/`doc_section` rows carry a top-level `"scope"` field; the
four `kg_*` kinds carry `"scope": null` and embed the chapter id inside
`source_ref.path` instead, shaped `"<short_kind>:<chapter_scope>:<citation_pid>:<ordinal>"`
(e.g. `"meeting_note:02.01:...:0"`) — confirmed by direct inspection (Phase
4's T015). Every grep below matches on the field that's actually present for
that row kind.

## Scenario 1: Chapter 01's real, currently-unused PDF becomes its meeting-notes source

```bash
ls "chapters/01/Milos teaching Rami AI workflows - 2026_08_27 09_57 CEST - Notes by Gemini.PDF"
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python /tmp/run_chapter.py 01 curriculum/passages.jsonl curriculum/chapter-01/knowledge
# Inspect: the minted kg_* items for chapter 01 now cite a pdf_notes_section
# pid via source_ref.path, not a transcript_segment pid.
grep '"path": *"meeting_note:01:' curriculum/passages.jsonl | head -3
```
Expected: `segments_processed=0` (confirms the PDF path was taken, not the
transcript path, per FR-002) and at least one minted item (next-points, todos,
or open-questions — content-dependent) citing a `pdf_notes_section` passage
for chapter 01. Running this against the REAL `curriculum/passages.jsonl`
mints real content into the served registry — Phase 3's own verification used
a scratch registry copy instead, matching this repository's own
`TestRealBridgeMinting` precedent for exactly this reason; run against a
scratch copy first if you want to inspect without committing to the real
registry (see Phase 3/4's own reports for the scratch-copy pattern).

## Scenario 2: Determinism

```bash
cp curriculum/passages.jsonl /tmp/passages-run1.jsonl
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python /tmp/run_chapter.py 01 curriculum/passages.jsonl curriculum/chapter-01/knowledge
diff /tmp/passages-run1.jsonl curriculum/passages.jsonl
```
Expected: `diff` produces no output (byte-identical) — a second run against an
already-populated registry mints `minted_new=0` (per Phase 3's own real,
scratch-registry-verified evidence).

## Scenario 3: Transcript-only chapters are unaffected

```bash
git stash   # if any WIP, ensure a clean baseline diff is meaningful
cp curriculum/passages.jsonl /tmp/passages-before.jsonl
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python /tmp/run_chapter.py 02.01 curriculum/passages.jsonl curriculum/chapter-02.01/knowledge
diff <(grep '"scope": *"02.01"' /tmp/passages-before.jsonl) \
     <(grep '"scope": *"02.01"' curriculum/passages.jsonl)
diff <(grep '"path": *"meeting_note:02.01:\|"path": *"todo:02.01:\|"path": *"open_question:02.01:\|"path": *"next_point:02.01:' /tmp/passages-before.jsonl) \
     <(grep '"path": *"meeting_note:02.01:\|"path": *"todo:02.01:\|"path": *"open_question:02.01:\|"path": *"next_point:02.01:' curriculum/passages.jsonl)
```
Expected: no diff for chapter 02.01's own rows of either shape (unchanged from
before this feature), confirming no regression for a transcript-only chapter
— exactly what Phase 4's T015 proved via a real old-code/new-code comparison.

## Scenario 4: Redaction gate withholds a roster-named / PII-bearing item

```bash
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/test_meeting_notes_pdf.py -k redaction -v
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/test_meeting_notes.py -k redaction -v
```
Expected: fixture-based tests demonstrating a roster name and, for the
PDF-sourced path only, an email/phone pattern each cause withholding, and a
name-free/PII-free fixture is NOT withheld.

## Scenario 5: Chapter 02.02 goes from raw video to real meeting notes

```bash
ls chapters/02.02/*.mp4
# T001's resolved mechanism (see plan.md): ffmpeg -> run_faster_whisper.py -> scripts/ingest.sh 02.02
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python /tmp/run_chapter.py 02.02 curriculum/passages.jsonl curriculum/chapter-02.02/knowledge
grep '"scope": *"02.02"' curriculum/passages.jsonl | head -3
```
Expected: chapter 02.02 no longer reports `state: "unwritten"` for any of the
four entity kinds; at least the transcript-derivation half of the pipeline
runs against real, freshly-transcribed content.

## Full regression

```bash
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/ -v
```
Expected: every test passes, including the pre-existing suite (no regression)
and the new PDF-sourced / redaction-gate tests added by this feature.
