# Feature Specification: PDF-Sourced Meeting Notes with Redaction Gate

**Feature Branch**: `009-meeting-notes-pdf-source`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "Extend workshop's meeting-notes extraction pipeline so meeting notes are populated from a chapter's provided notes PDF when one exists (treated as authoritative), or from a fully-analyzed transcript when no PDF is provided (existing behavior). Discovery convention: a file matching `* - Notes by *.[Pp][Dd][Ff]` beside a chapter's recording is that chapter's notes PDF. When no PDF and no transcript exist (chapter 02.02), run the already-installed local ASR pipeline to produce and ingest a real transcript first, then extract from it. Both sourcing paths must pass extracted text through the existing redaction gate before minting. Scoped to the private `workshop` submodule only."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A chapter with a real notes PDF gets its meeting notes from that PDF (Priority: P1)

An operator has recorded a teaching session and received a notes document (e.g. AI-generated meeting notes exported to PDF) alongside the recording. Today, that PDF sits unused — `chapters/01/...Notes by Gemini.PDF` has never been processed. The operator wants the platform's meeting-notes, TODO, open-questions, and next-meeting sections for that chapter to reflect what the PDF actually says, not a mechanical re-derivation from the raw transcript.

**Why this priority**: This is the literal, explicit request and the only path that has a real, ready-to-process example sitting in the repository today (chapter 01). It delivers value with zero additional prerequisite work (no ASR run needed).

**Independent Test**: Run the pipeline against chapter 01. Confirm its minted `kg_meeting_note`/`kg_todo`/`kg_open_question`/`kg_next_point` rows are sourced from the PDF's text (not the transcript), each citing a PDF-section anchor, and that re-running produces the same rows byte-for-byte (deterministic).

**Acceptance Scenarios**:

1. **Given** a chapter directory containing a recording and a file matching `* - Notes by *.[Pp][Dd][Ff]`, **When** the meeting-notes pipeline stage runs for that chapter, **Then** all four entity kinds are minted from the PDF's extracted text, each citing a PDF-section pseudo-passage identifying that PDF and the extracted section.
2. **Given** the same chapter and PDF, **When** the pipeline stage runs twice with no other change, **Then** both runs mint byte-identical output (deterministic extraction, no re-ordering or re-numbering).
3. **Given** a chapter with both a PDF and an existing transcript, **When** the pipeline stage runs, **Then** the PDF is used and the transcript is not (PDF is authoritative when present).
4. **Given** a chapter directory containing more than one file matching the notes-PDF pattern (e.g., notes exported from two different tools), **When** the pipeline stage runs, **Then** every matching PDF is processed independently, each minting its own items citing that specific PDF as their anchor — no file is silently skipped or treated as superseded by another.

---

### User Story 2 - A chapter with only a transcript keeps working exactly as before (Priority: P1)

An operator relies on chapters that have already been processed from their transcripts (e.g. chapter 02.01) and must not see their existing meeting-notes content change or disappear because a PDF-sourcing capability was added elsewhere.

**Why this priority**: Regression safety for already-shipped content is as critical as the new capability — this is existing, currently-served output.

**Independent Test**: Run the pipeline against a transcript-only chapter before and after this change; confirm identical minted output for that chapter (byte-for-byte on content, allowing only for the addition of the new redaction-gate pass-through when the redacted set is empty).

**Acceptance Scenarios**:

1. **Given** a chapter directory with a transcript and no matching notes-PDF file, **When** the pipeline stage runs, **Then** extraction proceeds from the transcript exactly as it did before this feature, citing `transcript_segment` passages as before.
2. **Given** a transcript-only chapter whose extracted text contains no redaction-roster names, **When** the pipeline stage runs, **Then** every item that would have been minted before this feature is still minted (the redaction gate adds no false positives).

---

### User Story 3 - A chapter with neither a PDF nor a transcript gets a real transcript first, then real meeting notes (Priority: P2)

Chapter 02.02 exists only as a raw, unprocessed video recording. The operator wants it brought to the same fully-analyzed state as other chapters — not left permanently reporting "unwritten" — using the local ASR capability already installed and verified on this host.

**Why this priority**: Delivers the explicit "fully analyzed properly transcription" requirement, but depends on User Story 2's extraction path already working correctly (it produces a transcript, then that transcript is processed by the existing/extended path) and is a longer-running, more operationally involved step than Stories 1-2.

**Independent Test**: Run the ASR-and-ingest step against chapter 02.02's raw video in isolation; confirm a real transcript with `transcript_segment` passages exists afterward and that `discover_chapters()` then finds chapter 02.02 as a normal transcript-bearing chapter.

**Acceptance Scenarios**:

1. **Given** a chapter directory with a recording, no PDF, and no existing transcript, **When** the ASR-and-ingest step runs against it, **Then** a real transcript is produced and ingested into that chapter's own `curriculum/chapter-<id>/` structure, with `transcript_segment` passages discoverable by the existing pipeline.
2. **Given** chapter 02.02 after the ASR step has run, **When** the meeting-notes pipeline stage runs, **Then** it discovers and processes chapter 02.02 via the transcript path (User Story 2's behavior), no longer reporting `state: "unwritten"`.

---

### User Story 4 - No meeting-notes content is ever served without a redaction check (Priority: P1)

An operator is aware that meeting-notes output today has no disclosure/redaction check of its own — raw extracted text (from either a transcript or, with this feature, a PDF) is stored and could be served verbatim, including any content naming a private individual by name. This must not get worse when a new sourcing path (PDF) is added, and the existing gap should close for the transcript path too.

**Why this priority**: A privacy/disclosure control is a correctness requirement, not a nice-to-have — this repository has an existing content-boundary incident (see the umbrella's own `CLAUDE.md` "Content boundary" section) making this the highest-consequence risk in this feature.

**Independent Test**: Feed a fixture PDF and a fixture transcript, each containing a roster-listed name, through the pipeline; confirm the resulting minted item's text has that name withheld/redacted rather than served verbatim, and that a disclosure-judgement record exists for the withheld item.

**Acceptance Scenarios**:

1. **Given** extracted text (from either source) that contains a name present in the participant roster used by `is_publishable_content`, **When** the item is about to be minted, **Then** the item is withheld from serving (not minted, or minted with `state: "withheld"` per this repository's existing withheld-item convention) rather than served with the name intact.
2. **Given** extracted text that contains no roster names and no PII pattern match, **When** the item is about to be minted, **Then** it is minted and served exactly as it would have been without this redaction gate (no unnecessary withholding).
3. **Given** a withheld item, **When** an operator later reviews it (mirroring the existing `disclosure-judgements.jsonl` ruling mechanism), **Then** an explicit ruling can flip it to served, exactly as today's mechanism already supports for other content.
4. **Given** PDF-sourced extracted text that contains an email address, phone number, or postal address pattern (even with no roster-name match), **When** the item is about to be minted, **Then** the item is withheld from serving — because PDF-sourced text (an AI-generated summary) is more likely to restate identifying details in free form than mechanical transcript cue-phrase extraction, this additional check applies to the PDF-sourced path specifically.

### Edge Cases

- What happens when the notes-PDF file exists but is corrupt, empty, or `pdftotext` cannot extract any text from it? → Reported as an extraction failure for that chapter (`state: "extraction_failed"`), never silently falls back to transcript-based extraction (a silent fallback would make "PDF is authoritative" true only some of the time, which is worse than a loud failure).
- What happens when a chapter has a notes-PDF file but the extracted text contains no recognizable cue-phrases for any of the four entity kinds? → No items are minted for that kind, exactly as the existing transcript path already handles chapters with no matching cue-phrases (an empty result is not an error).
- What happens when the ASR step is run against chapter 02.02 more than once? → Re-running produces the same transcript content (the ASR engine and model are already pinned to specific installed versions) and does not create duplicate `transcript_segment` passages (existing minting idempotency by content hash applies unchanged).
- What happens when the redaction gate's roster is updated after items have already been minted and served? → Out of scope for this feature; this repository's existing `redactions.jsonl` / `disclosure-judgements.jsonl` reversible-decision mechanism already handles applying a new judgement to already-minted content, and this feature does not change that mechanism.
- What happens when a filename technically matches the discovery pattern but is not actually a notes PDF (e.g. an unrelated PDF happens to be named `... - Notes by accident.pdf`)? → Out of scope for automatic detection; an operator naming a file to match this repository's own established convention (`chapters/01/...Notes by Gemini.PDF`) is treated as an explicit, intentional signal, matching how the existing transcript-discovery convention already trusts filesystem naming.
- What happens when a chapter has more than one file matching the notes-PDF pattern? → All matching files are processed (see FR-001a); this is a deliberate design decision, not an error condition — an operator with notes from two different tools (e.g. two different AI note-takers covering the same session) wants both sets of content available, not one silently discarded.
- What happens when two different notes PDFs for the same chapter produce items that describe the same real event in different words (e.g. both mention the same TODO, phrased differently)? → Out of scope for this feature; each PDF's items are minted independently with their own citation, and de-duplicating near-identical content across sources is not attempted (matching this repository's existing stance that a term/point's wording is not treated as a stable identity key — see `meeting_notes.py`'s own `external_key` design rationale, which keys on citation and ordinal, never on text).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pipeline MUST discover a chapter's notes PDF(s), when any exist, by matching every file beside that chapter's recording against the pattern `* - Notes by *.[Pp][Dd][Ff]` (case-insensitive extension).
- **FR-001a**: When more than one file matches for a chapter, the pipeline MUST process every matching file independently (not select one, not error) — each contributes its own items under its own citation.
- **FR-002**: When a chapter has at least one notes PDF, the pipeline MUST extract meeting-notes content (all four entity kinds: next-meeting points, open questions, meeting notes, TODO items) from each such PDF's text, and MUST NOT extract those same entity kinds from that chapter's transcript even if one also exists.
- **FR-003**: When a chapter has no notes PDF, the pipeline MUST extract meeting-notes content from that chapter's transcript exactly as it does today, unchanged.
- **FR-004**: Every PDF-sourced minted item MUST cite a stable anchor identifying the source PDF and the section/location within it the item was extracted from, in place of the `transcript_segment` citation the transcript path uses.
- **FR-005**: PDF-sourced extraction MUST be deterministic: re-running extraction against the same PDF file, with no other change, MUST mint byte-identical item text and citations.
- **FR-006**: When a chapter has neither a notes PDF nor an existing transcript, the pipeline MUST be able to run the already-installed local ASR pipeline against that chapter's raw recording to produce a transcript, and ingest that transcript so the chapter becomes discoverable by the existing transcript-based extraction path.
- **FR-007**: Before any item (from either sourcing path) is minted, its extracted text MUST be checked against this repository's existing disclosure/redaction predicate (`is_publishable_content` / `check_content`); an item whose text is judged non-publishable MUST be withheld from being served, using the existing withheld-item state convention rather than a new one.
- **FR-008**: The redaction check in FR-007 MUST be applied to each item's own final rendered text (the text that would actually be served), not only to the source document as a whole, so that an item combining or paraphrasing source text is still checked on what it actually contains.
- **FR-009**: A chapter whose notes-PDF extraction fails (corrupt file, no extractable text) MUST report an explicit failure state for that chapter and MUST NOT fall back to transcript-based extraction for that chapter.
- **FR-010**: The existing withheld-item review/override mechanism (the `disclosure-judgements.jsonl` ruling log) MUST apply unchanged to items withheld under FR-007, requiring no new review mechanism.
- **FR-011**: For PDF-sourced text specifically (not transcript-sourced text), the redaction gate MUST additionally check for common PII patterns (at minimum: email addresses, phone numbers) beyond the name-roster check in FR-007, and MUST withhold an item matching any such pattern. This is a narrower, pattern-based check (not a general PII/NLP detector) applied only to the sourcing path judged more likely to restate free-form identifying detail.

### Key Entities

- **Notes PDF**: A chapter-scoped document, discovered by filename convention, treated as the authoritative source of that chapter's meeting-notes content when present. Not the same as the existing gazetteer-only PDF processing (`pdf_notes.py`), which remains unchanged and continues to serve its existing, narrower role.
- **PDF-section citation anchor**: A new, stable identifier for "a location within a specific chapter's notes PDF," used as the citation target for PDF-sourced minted items, filling the role `transcript_segment` passages fill for transcript-sourced items.
- **kg_meeting_note / kg_todo / kg_open_question / kg_next_point**: The four existing entity kinds this feature mints into, unchanged in shape — only their possible source and citation type expand.
- **Disclosure judgement**: The existing reversible ruling record (`disclosure-judgements.jsonl`) that already governs whether a given piece of content may be served; this feature is a new producer of candidates for that mechanism, not a new mechanism.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Chapter 01's existing, currently-unused notes PDF is processed and its meeting-notes/TODO/open-questions/next-meeting content is derived from that PDF, verifiable by inspecting minted item citations.
- **SC-002**: Re-running PDF-sourced extraction against the same input produces identical output on 100% of runs (deterministic extraction, verified by repeated runs).
- **SC-003**: Every existing transcript-only chapter's previously-minted meeting-notes content is unchanged after this feature ships (zero regressions in already-served content).
- **SC-004**: Chapter 02.02 has real, transcript-derived meeting-notes content after this feature ships, where today it reports "unwritten" for all four entity kinds.
- **SC-005**: 100% of minted items (from either sourcing path) that contain a roster-listed name are withheld rather than served, verified against a fixture containing at least one known roster name.
- **SC-006**: Zero minted items that contain no roster-listed name and no PII pattern match are incorrectly withheld (no false-positive withholding), verified against the full existing transcript-sourced corpus re-run through the new redaction gate.
- **SC-007**: 100% of PDF-sourced minted items containing an email address or phone number pattern are withheld, verified against a fixture PDF containing at least one of each.
- **SC-008**: When a chapter has multiple matching notes-PDF files, 100% of them are processed and contribute items (zero silently skipped), verified against a fixture chapter with two matching files.

## Assumptions

- The existing participant-name roster used by `publication_policy.is_publishable_content` is complete enough to serve as the redaction gate's basis for this feature; expanding or correcting that roster is out of scope here.
- `pdftotext` (already confirmed present on this development host and already used by `pdf_notes.py`) is an acceptable, sufficiently reliable PDF-text-extraction mechanism for this feature; OCR-based extraction for image-only PDFs is out of scope.
- The already-installed local ASR stack (faster-whisper + whisper.cpp, confirmed working on this host) is sufficient for chapter 02.02's transcription; no new ASR engine or model needs to be installed.
- "Fully analyzed properly transcription" (the operator's phrasing) is satisfied by running the existing ASR pipeline exactly as it is already used for other chapters — this feature does not need to build a new or different transcription quality bar.
- This feature is scoped entirely to the private `workshop` submodule's own pipeline and content; it does not touch the public umbrella repository's own code or content, and no PDF or transcript content is copied out of `workshop` into any public path.
- The still-open, separately-tracked G5 redaction-propagation finding (redaction not re-applied to duplicate/near-duplicate content elsewhere in the corpus) is explicitly out of scope for this feature — FR-007/FR-008 close the "meeting-notes has no redaction check at all" gap for this feature's own new content, but do not attempt to fix G5's cross-content propagation gap.
- The PII pattern check added in FR-011 is intentionally narrow (email/phone patterns) rather than a general-purpose PII/NLP detector; expanding it further is a future decision, not part of this feature's scope.

## Brainstorm Log

**2026-09-18** — Edge-case deep-dive session (security/privacy and boundary-condition categories), conducted via `speckit-superspec-brainstorm`:

- **Security/privacy**: resolved that PDF-sourced text (being an AI-generated summary more likely to restate identifying detail in free form than mechanical transcript cue-phrase extraction) needs a redaction check beyond the existing name-roster mechanism. Added FR-011 (email/phone pattern check, PDF-sourced path only) and SC-007.
- **Boundary condition**: resolved that multiple notes-PDF files matching the discovery pattern for one chapter must ALL be processed independently (not treated as an error, not resolved by picking the newest) — an operator with notes from two different tools wants both available. Added FR-001a, User Story 1 acceptance scenario 4, a new edge case on cross-file duplication (explicitly out of scope), and SC-008.
