# Quickstart: PDF-Sourced Meeting Notes with Redaction Gate

Runnable validation scenarios proving this feature works end-to-end. Run from
`$VASIC_ROOT/workshop` unless noted. Every command below is expected to be
run for real, with real output pasted into the implementing task's report —
per this repository's anti-bluff discipline, "ran the plan" is not evidence;
the command's actual output is.

## Prerequisites

```bash
command -v pdftotext                                    # already present, per umbrella CLAUDE.md
pipeline/venv/bin/python -c 'import faster_whisper; print(faster_whisper.__version__)'
git -C pipeline/engines/whisper.cpp describe --tags 2>/dev/null || echo "whisper.cpp check separately"
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -m pytest pipeline/extract/test_meeting_notes.py -v   # baseline: today's suite, must be green before starting
```

## Scenario 1: Chapter 01's real, currently-unused PDF becomes its meeting-notes source

**Correction (found during Phase 3 implementation): `run_pipeline.py` has no
`--stage`/`--chapter` CLI flags** (its real CLI is `--no-resume`,
`--no-author`, `--no-meeting-notes`, `--author`/`--review` only). Call the
function `run_pipeline.py`'s own wrapper calls directly instead:

```bash
ls "chapters/01/Milos teaching Rami AI workflows - 2026_08_27 09_57 CEST - Notes by Gemini.PDF"
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -c "
from meeting_notes import run_chapter_meeting_notes
result = run_chapter_meeting_notes('01')
print(result)
"
# Inspect: the minted items for chapter 01 now cite a pdf_notes_section pid,
# not a transcript_segment pid (segments_processed should read 0).
grep '"chapter_scope": *"01"' curriculum/passages.jsonl | grep '"kind": *"kg_meeting_note"' | head -3
```
Expected: `segments_processed=0` (confirms the PDF path was taken, not the
transcript path, per FR-002) and at least one minted item (next-points, todos,
or open-questions — content-dependent) citing a `pdf_notes_section` passage
for chapter 01. Running this against the REAL `curriculum/passages.jsonl`
mints real content into the served registry — Phase 3's own verification used
a scratch registry copy instead, matching this repository's own
`TestRealBridgeMinting` precedent for exactly this reason.

## Scenario 2: Determinism

```bash
cp curriculum/passages.jsonl /tmp/passages-run1.jsonl
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -c "
from meeting_notes import run_chapter_meeting_notes
print(run_chapter_meeting_notes('01'))
"
diff /tmp/passages-run1.jsonl curriculum/passages.jsonl
```
Expected: `diff` produces no output (byte-identical) — a second run against an
already-populated registry mints `minted_new=0` (per Phase 3's own real,
scratch-registry-verified evidence).

## Scenario 3: Transcript-only chapters are unaffected

```bash
git stash   # if any WIP, ensure a clean baseline diff is meaningful
cp curriculum/passages.jsonl /tmp/passages-before.jsonl
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -c "
from meeting_notes import run_chapter_meeting_notes
run_chapter_meeting_notes('02.01')
"
diff <(grep '"chapter_scope": *"02.01"' /tmp/passages-before.jsonl) \
     <(grep '"chapter_scope": *"02.01"' curriculum/passages.jsonl)
```
Expected: no diff for chapter 02.01's own rows (unchanged from before this
feature), confirming no regression for a transcript-only chapter.

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
PYTHONPATH=".:pipeline/extract" pipeline/venv/bin/python -c "
from meeting_notes import run_chapter_meeting_notes
print(run_chapter_meeting_notes('02.02'))
"
grep '"chapter_scope": *"02.02"' curriculum/passages.jsonl | grep '"kind": *"kg_meeting_note"'
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
