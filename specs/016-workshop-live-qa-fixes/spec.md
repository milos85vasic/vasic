# Feature Specification: Workshop Live-QA Fix Batch

**Feature Branch**: `016-workshop-live-qa-fixes`
**Created**: 2026-10-01
**Status**: Draft
**Input**: User description: "We MUST SYSTEMATICALLY INVESTIGATE AND FIX the following issues we have spotted during LIVE QA session: ISSUE, WORKSHOP: Landing screen, the recordings section, all chapters except Chapter 01 are empty! Chapters with no video shall show some properly designed indicator! Containers MUST HAVE the content! Next: In transcription page we are seeing warnings in transcription: "Not in this build"! This MUST BE fixed! Nothing can be missed! Next: Where else this points sections contain noise and thrash! Make this reasonable and common sense content obtained by processing the video content, transcription and document summary! Next: We are seeing this in transcription: "Transcriber unsure — the recogniser was unsure", we MUST improve processing so we are absolutely precise and sure regarding the meaning and the content of the conversations! Next: In progress screen first column is cutoff: "ched this" <--- Not a whole word! Next: Make sure all lessons, or sections which are already completed are checked when we open the page, example: http://127.0.0.1:8087/areas/01M1GWW49GNKYBEXFFCNRWM1T0. Next: We cant select anything on multi-choice questions (http://127.0.0.1:8087/practice/01M1GWW49GNKYBEXFFCNRWM1T0). Next: We are seeing this error: "An answer was not recorded — The progress service did not acknowledge the write, so this answer is not known to have been stored and is not counted in your progress. Your work is not lost — it just has not landed.", Send again button does not help! Next: Chapter 4 - All sections contain thrashy content. Everything MUST BE clear, concluded from the conversations which are part of materials for the particular chapter and all sentences preferably in 3rd person — not to be with the "I ..."."

## Clarifications

### Session 2026-10-01

- Q: What target reduction in "transcriber unsure" flags should count as success for SC-003? → A: Cut each chapter's flagged-uncertain segment rate by at least 50%
- Q: Do the new "no recording" indicator and lesson-completion checkmarks need to meet this platform's existing accessibility standard? → A: Yes — new indicators must follow the platform's existing accessibility pattern (accessible label, keyboard-reachable, not color-only)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Practice questions can be answered and are recorded (Priority: P1)

A learner opens a practice session for an area, selects an answer on a multiple-choice question, and submits it. Right now selecting an option does nothing, and even when a submission does go through the learner is shown "An answer was not recorded" with a "Send again" button that does not actually retry successfully — so no practice question can currently be completed at all.

**Why this priority**: This is a total, hard block on the core learning-assessment loop. No other practice-related fix matters if a learner cannot select or submit an answer at all. Without this, the practice feature is non-functional end to end.

**Independent Test**: Open any practice session, select an answer on a multiple-choice question, submit it, and reload the page — the selection is visibly selectable before submit, the submission succeeds without the "not recorded" error, and the recorded answer is reflected after a reload.

**Acceptance Scenarios**:

1. **Given** a learner is on a practice page for an area with multiple-choice questions, **When** they click/tap an answer option, **Then** the option visibly becomes selected and stays selected until they change it or submit.
2. **Given** a learner has selected an answer and clicks submit, **When** the submission is sent, **Then** the system acknowledges the write and the learner sees their actual result (correct/incorrect/withheld, as applicable) rather than a "not recorded" failure message.
3. **Given** a submission previously failed with "An answer was not recorded", **When** the learner clicks "Send again", **Then** the retry succeeds and the answer is actually stored, or — if it is expected to still fail under some real condition — the learner is shown a reason that is different from a silent repeat of the same generic failure.
4. **Given** an answer was successfully recorded, **When** the learner reloads or revisits the practice page, **Then** their previously recorded answer/result for that question is still reflected, not lost.

---

### User Story 2 - Completed lessons/sections show as already-completed on return (Priority: P1)

A learner completes a lesson or section, leaves the area page, and comes back later (e.g. by reloading `http://127.0.0.1:8087/areas/{area-id}`). Right now, previously completed items are not shown as checked/completed when the page is reopened, so the learner cannot tell what they have already finished.

**Why this priority**: Progress visibility is foundational trust in the platform — a learner who cannot see what they already completed will either redo work unnecessarily or lose confidence that their progress is being tracked at all, directly undermining the value of every other feature on the page.

**Independent Test**: Mark one or more lessons/sections complete on an area page, navigate away (or reload), return to the same area page, and confirm every previously completed item renders in its completed/checked state immediately, with no extra action needed.

**Acceptance Scenarios**:

1. **Given** a lesson or section was previously marked complete, **When** the learner opens (or reloads) the area page containing it, **Then** that lesson/section is rendered as checked/completed without requiring the learner to re-open or re-interact with it.
2. **Given** an area has a mix of completed and not-yet-completed lessons/sections, **When** the page loads, **Then** only the genuinely completed ones are shown as checked — no false positives and no false negatives.

---

### User Story 3 - Chapter recordings are visible where they exist, and clearly absent where they don't (Priority: P2)

On the landing screen's recordings section, every chapter except Chapter 01 currently appears empty — even chapters that do have a real recorded session. A learner cannot tell whether a chapter's recording is missing because the content genuinely does not exist, or because something failed to load it.

**Why this priority**: This is the first thing a visitor sees, and it currently misrepresents the actual state of the content library — chapters that have real recordings look exactly the same as chapters that intentionally never had one, which erodes trust in the whole platform before a learner even picks a chapter.

**Independent Test**: Load the landing screen's recordings section and confirm that every chapter which has an actual recorded session shows its recording entry (thumbnail/player/link as designed), and every chapter that was never recorded (by design, e.g. a text-only chapter) shows a clear, purpose-built "no recording for this chapter" indicator instead of an empty space.

**Acceptance Scenarios**:

1. **Given** a chapter has a real, already-processed video recording, **When** the landing screen's recordings section renders, **Then** that chapter's recording entry is visible and functional (same as Chapter 01's today).
2. **Given** a chapter was never recorded (no video exists for it by design), **When** the landing screen's recordings section renders, **Then** that chapter shows an explicit, designed "no recording" indicator rather than an empty gap indistinguishable from a loading or data failure.
3. **Given** the recordings section has finished loading, **When** a learner scans the whole list, **Then** the total count of "has recording" vs "no recording" entries matches the actual content library — nothing with a real recording is silently missing.

---

### User Story 4 - Transcription pages never show placeholder/build-missing text (Priority: P2)

Transcription pages currently show a literal warning string, "Not in this build", in place of real transcript content for some segments. This is a visible implementation leak, not a real answer to the learner.

**Why this priority**: A placeholder string standing in for real content is worse than an honest "not available" state — it looks like a bug, breaks trust in the transcript as a reliable record of the session, and can appear anywhere in a transcript a learner is actively reading.

**Independent Test**: Walk every transcript page for every chapter end to end and confirm zero occurrences of "Not in this build" (or any other internal/build-only placeholder string) anywhere in rendered transcript content.

**Acceptance Scenarios**:

1. **Given** any transcript page for any chapter, **When** a learner reads through its full content, **Then** no segment renders the literal text "Not in this build" or any equivalent internal placeholder.
2. **Given** a segment's real content is for some reason genuinely unavailable, **When** that segment is rendered, **Then** it uses this platform's existing, honest "content unavailable" presentation (consistent with how other legitimately-missing content is already shown elsewhere), not a raw build-time string.

---

### User Story 5 - Transcription uncertainty is the exception, not the norm (Priority: P2)

Learners are currently seeing "Transcriber unsure — the recogniser was unsure" often enough that it undermines confidence in the transcript as an accurate record of what was said.

**Why this priority**: A transcript a learner cannot trust is a transcript they will stop using — this directly affects the credibility of the core learning artifact (the recorded session's written record) across every chapter.

**Independent Test**: Measure the proportion of transcript segments flagged "uncertain" per chapter before and after remediation; confirm at least a 50% reduction, with the remaining flagged segments genuinely corresponding to hard-to-transcribe audio (not a default/overly-conservative threshold).

**Acceptance Scenarios**:

1. **Given** a chapter's transcript has been reprocessed, **When** its uncertainty rate is measured, **Then** it is at least 50% lower than before, and any segment still flagged uncertain corresponds to audio that is genuinely difficult to make out (background noise, overlapping speech, very low confidence), not a borderline case that a reasonable listener would consider clear.
2. **Given** a segment is still flagged uncertain after reprocessing, **When** a learner reads it, **Then** the surrounding context (prior/next segments, chapter summary) is sufficient for the overall meaning of that part of the conversation to remain clear.

---

### User Story 6 - "Where else this points" shows genuinely related content (Priority: P2)

The cross-reference list under a passage (the "Where else this points" section) currently contains noise and clutter rather than reasonable, relevant connections.

**Why this priority**: A noisy cross-reference list actively misleads a learner trying to understand how ideas connect across the curriculum, and erodes confidence in every other derived-content feature on the same page.

**Independent Test**: Spot-check cross-reference lists across a representative sample of passages in multiple chapters and confirm every listed connection is a genuinely related passage/document/term — not a bare glossary entry, internal bookkeeping row, or otherwise unrelated match.

**Acceptance Scenarios**:

1. **Given** a passage with cross-references, **When** a learner opens "Where else this points", **Then** every listed entry is topically related to the passage's actual content, derived from the video, transcript, and/or document summary — not a coincidental text match.
2. **Given** a passage has no genuinely related content elsewhere, **When** "Where else this points" is rendered, **Then** it shows an honest empty/low-result state rather than padding the list with weak or irrelevant matches.

---

### User Story 7 - Progress screen labels are never truncated into partial words (Priority: P3)

The first column of the progress screen currently cuts a label off mid-word (e.g. rendering "ched this" instead of the full word/phrase), making it unreadable.

**Why this priority**: This is a pure, isolated display defect — important to fix for a professional, trustworthy UI, but it does not block any workflow the way the P1/P2 issues do.

**Independent Test**: Load the progress screen at a range of realistic viewport widths and confirm every label in the first column renders as complete text (via wrapping, truncation-with-visible-full-text-on-hover/tap, or a layout that simply fits), never a word cut off mid-character.

**Acceptance Scenarios**:

1. **Given** the progress screen is open at a typical desktop or mobile width, **When** the first column renders its labels, **Then** every word is shown in full — no label is cut off partway through a word.

---

### User Story 8 - Chapter 4 content is clear, conclusive, third-person prose (Priority: P3)

Chapter 4's sections currently read as "thrashy" (raw, disjointed, first-person conversational fragments) rather than clear, concluded summaries of what was actually discussed in that chapter's source conversation.

**Why this priority**: Content quality for one specific chapter's derived sections is lower-urgency than the platform-wide defects above, but still needs fixing so chapter 4 reaches the same bar as the platform's other content.

**Independent Test**: Read every section of chapter 4 end to end and confirm each one is a clear, concluded statement grounded in that chapter's actual source conversation, written in third person.

**Acceptance Scenarios**:

1. **Given** any section of chapter 4, **When** a learner reads it, **Then** the content is a clear, complete, concluded statement — not a disjointed or truncated fragment — and is traceable back to something actually discussed in that chapter's source conversation.
2. **Given** chapter 4's source material is a first-person conversation between its participants, **When** its sections are rendered as learning content, **Then** the sentences are written in third person (describing what was discussed or decided) rather than quoting first-person "I ..." statements verbatim.

---

### Edge Cases

- What happens when a chapter genuinely has a recording in progress (partially processed) rather than either "has recording" or "no recording"? The recordings section must not misrepresent a mid-processing chapter as either fully available or permanently absent.
- What happens when a learner submits a practice answer while offline or mid-connectivity-loss? The failure message shown must be distinguishable from the current "not recorded" bug once that bug is fixed, so a learner can tell a real network issue from a platform defect.
- What happens when an area page has zero completed lessons yet (a brand-new learner)? No lesson should incorrectly render as checked.
- What happens when transcription reprocessing for a chapter is still running? The transcript page must not show "Not in this build" as a stand-in for "reprocessing in progress."
- What happens when a passage's cross-reference list, after cleanup, has zero genuine matches? The section must render an honest empty state, not reintroduce noise just to avoid an empty list.
- What happens when chapter 4's source conversation includes a passage with no clear third-person-summarizable conclusion (e.g. small talk)? Such passages should be omitted from section content rather than force-summarized into a misleading statement.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The landing screen's recordings section MUST show a working recording entry for every chapter that has an actual recorded video session, not only Chapter 01.
- **FR-002**: The landing screen's recordings section MUST show a distinct, purpose-designed "no recording" indicator for any chapter that has no video by design, rather than leaving that chapter's entry empty or indistinguishable from a loading/failure state.
- **FR-003**: No transcript page, for any chapter, MUST render the literal internal placeholder text "Not in this build" (or an equivalent build-only string) in place of real transcript content.
- **FR-004**: Where a transcript segment's content is genuinely unavailable, the system MUST render this platform's existing, honest "content unavailable" presentation instead of a raw placeholder string.
- **FR-005**: The transcription pipeline MUST be reprocessed/improved so that the proportion of segments flagged "Transcriber unsure" is reduced by at least 50% per chapter, with remaining flags corresponding only to genuinely hard-to-transcribe audio.
- **FR-006**: The "Where else this points" cross-reference section MUST only list passages/documents/terms that are genuinely topically related to the source passage, derived from that passage's video, transcript, and/or document-summary content.
- **FR-007**: The "Where else this points" section MUST render an honest empty/low-result state when no genuinely related content exists, rather than including weak or irrelevant matches to avoid an empty list.
- **FR-008**: The progress screen's first-column labels MUST always render as complete words/phrases at supported viewport widths — never truncated mid-word.
- **FR-009**: An area page MUST render every previously completed lesson/section in its checked/completed state immediately on load, with no additional learner interaction required.
- **FR-010**: An area page MUST NOT render an incomplete lesson/section as checked (no false positives).
- **FR-011**: Users MUST be able to select an answer option on a multiple-choice practice question, with the selection visibly reflected in the UI.
- **FR-012**: Submitting a practice answer MUST be acknowledged by the progress-recording service under normal operating conditions, and the learner MUST see their actual result rather than a "not recorded" failure.
- **FR-013**: The "Send again" retry action on a failed answer submission MUST result in a successful recording under normal operating conditions (i.e. the retry path MUST actually work, not merely repeat the same failure).
- **FR-014**: A successfully recorded practice answer MUST still be reflected as recorded after the learner navigates away and returns, or reloads the page.
- **FR-015**: Every section of chapter 4 MUST present clear, concluded content that is traceable to something actually discussed in chapter 4's source conversation material, rather than disjointed or truncated fragments.
- **FR-016**: Chapter 4's section content MUST be written in third person, describing what was discussed or decided, rather than retaining first-person "I ..." phrasing from the source conversation.
- **FR-017**: The "no recording" indicator (FR-002) and lesson/section completion checkmarks (FR-009) MUST follow this platform's existing accessibility pattern — an accessible label, keyboard reachability, and a status that is not conveyed by color alone.

### Key Entities

- **Chapter recording**: A chapter's recorded video session (or its deliberate absence), as surfaced on the landing screen's recordings section.
- **Transcript segment**: A single unit of a chapter's transcript, which may be genuinely unavailable, flagged uncertain, or fully confident.
- **Cross-reference entry**: A listed connection from one passage to another passage, document, or term in the "Where else this points" section.
- **Lesson/section completion state**: Whether a specific lesson or section within an area has been marked complete by the learner, and whether that state is reflected on page load.
- **Practice answer submission**: A learner's selected answer to a practice question, its submission/acknowledgement state, and its recorded result.
- **Chapter 4 section**: A unit of derived learning content for chapter 4, sourced from its underlying conversation material.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of chapters with an actual recorded session show a working recording entry on the landing screen; 100% of chapters with no recording by design show the designed "no recording" indicator.
- **SC-002**: 0% of transcript segments across all chapters render the "Not in this build" placeholder (or equivalent) after remediation.
- **SC-003**: The proportion of transcript segments flagged "Transcriber unsure" drops by at least 50% per chapter (measured before vs. after) without reducing the chapter's actual segment count.
- **SC-004**: In a sample review of cross-reference lists across multiple chapters, 0% of listed entries are bare glossary terms, internal bookkeeping rows, or otherwise topically unrelated matches.
- **SC-005**: 0% of progress-screen first-column labels are truncated mid-word across supported viewport widths.
- **SC-006**: 100% of previously completed lessons/sections render as checked immediately on area-page load, across a representative sample of areas, with 0% false positives on not-yet-completed items.
- **SC-007**: 100% of attempted answer selections on multiple-choice practice questions are visibly reflected in the UI.
- **SC-008**: 100% of practice-answer submissions under normal operating conditions are acknowledged and recorded, with the "An answer was not recorded" failure no longer occurring under those conditions; the "Send again" retry succeeds when used.
- **SC-009**: 100% of chapter 4's sections read as clear, concluded, third-person statements traceable to the chapter's source conversation, with no first-person "I ..." phrasing remaining.
- **SC-010**: 100% of the new "no recording" indicators and completion checkmarks pass the platform's existing accessibility checks (accessible label present, reachable by keyboard, status distinguishable without relying on color).

## Assumptions

- Chapters confirmed to have a real, already-processed video recording (per this platform's own content pipeline) are expected to render correctly once the display defect is fixed; this is treated as a display/wiring issue for those chapters, not a data-completeness gap, unless investigation proves otherwise.
- At least one chapter in the current library is a text-only chapter with no video recording by design; for that chapter, the correct fix is the "no recording" indicator (FR-002), not sourcing or fabricating a video.
- "Absolutely precise and sure" transcription (as stated by the reporter) is treated as a directional target — a quantified reduction in incorrect/unnecessary uncertainty flags (at least 50% per chapter, per the 2026-10-01 clarification) plus elimination of placeholder content — rather than a literal zero-error guarantee, since automatic speech recognition cannot be perfect on genuinely difficult audio.
- "Normal operating conditions" in FR-012/FR-013/SC-008 excludes genuine environmental failures (e.g. the progress-recording service being fully down) — the requirement is that the system does not fail silently/incorrectly when the service is actually healthy, not that submissions survive every possible outage.
- The existing "content unavailable" presentation pattern already used elsewhere on this platform (for other legitimately-missing content) is assumed to be the correct, honest fallback to reuse for FR-004 rather than inventing a new presentation.
