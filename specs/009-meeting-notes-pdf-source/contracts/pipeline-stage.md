# Contract: Meeting-Notes Extraction Stage

This pipeline has no HTTP/RPC surface for this feature — it is a batch stage
invoked by `run_pipeline.py`. This document is the stage's own input/output
contract, the internal equivalent of an API contract for a batch component.

## Input

- A chapter directory under `chapters/<chapter_id>/` containing at least a
  recording, and optionally:
  - Zero or more files matching `* - Notes by *.[Pp][Dd][Ff]`.
  - An existing transcript, discoverable via the existing
    `discover_chapters()` mechanism (`transcript_segment` passages already
    present in `curriculum/passages.jsonl`).
- The existing participant-name roster consumed by `is_publishable_content`.

## Output

For each chapter processed, exactly one of:

1. **PDF-sourced** (one or more matching PDFs found): for each PDF, a set of
   `kg_meeting_note` / `kg_todo` / `kg_open_question` / `kg_next_point` items,
   each either minted normally or withheld (per the Redaction Check Result in
   `data-model.md`), each citing a `pdf_notes_section` passage.
2. **Transcript-sourced** (no PDF found, transcript exists): same four entity
   kinds, citing `transcript_segment` passages, same redaction check applied
   (without the PDF-specific PII-pattern check).
3. **Unwritten** (neither PDF nor transcript exists): no items minted; chapter
   reports `state: "unwritten"` for all four kinds, exactly as today.
4. **Extraction failed** (PDF found but unreadable): no items minted for that
   PDF; chapter reports `state: "extraction_failed"` for that PDF specifically
   — a different chapter or a different PDF for the same chapter is
   unaffected.

## Invariants (MUST hold on every run, verified by tasks.md's test tasks)

- **Determinism**: identical input state (same files, same roster, same code)
  MUST produce byte-identical output on every run (FR-005, SC-002).
- **Source exclusivity**: an item is sourced from exactly one place — a PDF's
  presence for a chapter suppresses transcript-based extraction for that
  chapter entirely (FR-002); it never merges or interleaves the two.
- **No unchecked item**: no item reaches `curriculum/passages.jsonl` in a
  servable state without having passed the redaction check on its own final
  text (FR-007/FR-008) — this is the single most important invariant this
  contract exists to state plainly, since it is the entire reason this
  feature exists rather than merely being "add PDF support."
- **No silent fallback**: `state: "extraction_failed"` is a terminal outcome
  for the affected PDF, never silently replaced by transcript-based output
  (FR-009).

## Backward Compatibility

Every chapter that has ONLY a transcript today (no notes PDF) MUST produce
identical output to what it produces today, except for the addition of the
redaction-check pass-through (which is a no-op — same output — for any
chapter whose existing content contains no roster/PII match, per SC-006).
