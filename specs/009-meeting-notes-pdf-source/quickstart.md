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
python3 -m pytest pipeline/extract/test_meeting_notes.py -v   # baseline: today's suite, must be green before starting
```

## Scenario 1: Chapter 01's real, currently-unused PDF becomes its meeting-notes source

```bash
ls "chapters/01/Milos teaching Rami AI workflows - 2026_08_27 09_57 CEST - Notes by Gemini.PDF"
python3 pipeline/extract/run_pipeline.py --stage meeting-notes --chapter 01
# Inspect: the minted items for chapter 01 in curriculum/passages.jsonl now cite
# a pdf_notes_section pid, not a transcript_segment pid.
grep '"chapter_scope": *"01"' curriculum/passages.jsonl | grep '"kind": *"kg_meeting_note"' | head -3
```
Expected: at least one `kg_meeting_note` (and, content permitting, the other
three kinds) citing a `pdf_notes_section` passage for chapter 01.

## Scenario 2: Determinism

```bash
python3 pipeline/extract/run_pipeline.py --stage meeting-notes --chapter 01 > /tmp/run1.log
cp curriculum/passages.jsonl /tmp/passages-run1.jsonl
python3 pipeline/extract/run_pipeline.py --stage meeting-notes --chapter 01 > /tmp/run2.log
diff /tmp/passages-run1.jsonl curriculum/passages.jsonl
```
Expected: `diff` produces no output (byte-identical).

## Scenario 3: Transcript-only chapters are unaffected

```bash
git stash   # if any WIP, ensure a clean baseline diff is meaningful
cp curriculum/passages.jsonl /tmp/passages-before.jsonl
python3 pipeline/extract/run_pipeline.py --stage meeting-notes --chapter 02.01
diff <(grep '"chapter_scope": *"02.01"' /tmp/passages-before.jsonl) \
     <(grep '"chapter_scope": *"02.01"' curriculum/passages.jsonl)
```
Expected: no diff for chapter 02.01's own rows (unchanged from before this
feature), confirming no regression for a transcript-only chapter.

## Scenario 4: Redaction gate withholds a roster-named / PII-bearing item

```bash
python3 -m pytest pipeline/extract/test_meeting_notes_pdf.py -k redaction -v
python3 -m pytest pipeline/extract/test_meeting_notes.py -k redaction -v
```
Expected: fixture-based tests demonstrating a roster name and, for the
PDF-sourced path only, an email/phone pattern each cause withholding, and a
name-free/PII-free fixture is NOT withheld.

## Scenario 5: Chapter 02.02 goes from raw video to real meeting notes

```bash
ls chapters/02.02/*.mp4
# (Task-level implementer fills in the exact ASR invocation here once the
# existing chapter-02/02.01 ingestion mechanism is located — see plan.md's
# Project Structure note.)
python3 pipeline/extract/run_pipeline.py --stage meeting-notes --chapter 02.02
grep '"chapter_scope": *"02.02"' curriculum/passages.jsonl | grep '"kind": *"kg_meeting_note"'
```
Expected: chapter 02.02 no longer reports `state: "unwritten"` for any of the
four entity kinds; at least the transcript-derivation half of the pipeline
runs against real, freshly-transcribed content.

## Full regression

```bash
python3 -m pytest pipeline/extract/ -v
```
Expected: every test passes, including the pre-existing suite (no regression)
and the new PDF-sourced / redaction-gate tests added by this feature.
