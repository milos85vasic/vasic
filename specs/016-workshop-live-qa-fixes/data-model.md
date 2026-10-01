# Phase 1 Data Model: Workshop Live-QA Fix Batch

This feature fixes defects in existing entities' read/write/render paths; it does not introduce new
persisted entities. Each entity below is the Key Entity from spec.md, expanded with the
fields/relationships/state transitions relevant to its specific defect, at the level of detail
needed for planning — not a full schema (the authoritative shape lives in the existing Go/TypeScript
types this feature's implementation phase will locate and correct).

## Chapter recording

**Represents**: A chapter's recorded video session, or its deliberate absence, as surfaced on the
landing screen.

| Field (conceptual) | Notes |
|---|---|
| `chapter_id` | e.g. `01`, `02`, `02.01`, `02.02`, `03`, `04` |
| `has_recording` | boolean — whether this chapter has an actual archived/extracted video |
| `recording_state` | one of: `available`, `processing`, `none_by_design` (see Edge Cases in spec.md — a mid-processing chapter must not collapse into either `available` or `none_by_design`) |
| `recording_entry` | thumbnail/player/link payload, present only when `recording_state = available` |

**Relationships**: one recording entry per chapter, surfaced in a list on the landing screen.

**State transitions**: `processing → available` (once archive/extract/index completes) or
`processing → none_by_design` is NOT a valid transition — a chapter's `none_by_design` status is
fixed at chapter-type authoring time (e.g. a text-only chapter), never reached by a processing
pipeline outcome.

**Validation rule (FR-001/FR-002)**: every chapter_id in the content library MUST map to exactly one
of the three `recording_state` values; no chapter may render with an undefined/empty state.

---

## Transcript segment

**Represents**: A single unit of a chapter's transcript.

| Field (conceptual) | Notes |
|---|---|
| `segment_id` | per-chapter, per-segment identifier (pid) |
| `text` | the transcribed content, or absent/placeholder when unavailable |
| `confidence` | the ASR engine's confidence score for this segment |
| `uncertain` | boolean, derived from `confidence` vs. the chapter's calibrated threshold |
| `render_state` | one of: `confident`, `flagged_uncertain`, `genuinely_unavailable` |

**Relationships**: many segments per chapter, ordered by position in the transcript.

**Validation rules**:
- **FR-003**: no segment's `text` MUST ever literally equal (or contain as its sole content) the
  internal placeholder string "Not in this build".
- **FR-004**: a segment in `genuinely_unavailable` state MUST render via the platform's existing
  honest "content unavailable" presentation, never a raw placeholder.
- **FR-005 / SC-003**: the proportion of segments in `flagged_uncertain` state, measured per
  chapter, MUST drop by at least 50% relative to the pre-fix baseline, without any segment being
  removed from the chapter to achieve the reduction (segment count held constant).

---

## Cross-reference entry

**Represents**: A listed connection from one passage to another passage, document, or term, shown
under "Where else this points".

| Field (conceptual) | Notes |
|---|---|
| `source_passage_id` | the passage this cross-reference list belongs to |
| `target_id` | the referenced passage/document/term |
| `target_kind` | e.g. `doc_section`, `transcript_segment`, `code`, `kg_term` |
| `relevance_basis` | what makes this a genuine connection — derived from video/transcript/summary content, not a coincidental text match |

**Relationships**: many cross-reference entries per source passage; zero is valid (FR-007).

**Validation rules**:
- **FR-006**: every listed `target_id` MUST be genuinely topically related to the source passage's
  actual content.
- **FR-007**: when no genuinely related content exists for a source passage, its cross-reference
  list MUST render as an honest empty state, not be padded with weak matches.
- **SC-004**: in a representative sample across multiple chapters, 0% of listed entries are bare
  glossary terms, internal bookkeeping rows, or otherwise topically unrelated.

---

## Lesson/section completion state

**Represents**: Whether a specific lesson or section within an area has been marked complete by the
learner, and whether that state is reflected on page load.

| Field (conceptual) | Notes |
|---|---|
| `area_id` | the area containing this lesson/section |
| `lesson_id` / `section_id` | the specific item |
| `completed` | boolean, persisted per-learner |
| `completed_at` | timestamp of completion, if completed |

**Relationships**: many lessons/sections per area; one completion record per (learner, lesson)
pair.

**Validation rules**:
- **FR-009**: on area-page load, every lesson/section whose `completed = true` MUST render in its
  checked/completed visual state immediately, with no additional learner interaction required.
- **FR-010**: no lesson/section with `completed = false` MUST render as checked (no false
  positives).
- **FR-017**: the completion checkmark MUST carry an accessible label and be distinguishable
  without relying on color alone (e.g. an icon/text change, not a border-color-only change).

---

## Practice answer submission

**Represents**: A learner's selected answer to a practice question, its submission/acknowledgement
state, and its recorded result.

| Field (conceptual) | Notes |
|---|---|
| `question_id` | the practice question this submission answers |
| `selected_option` | the option the learner selected, or absent if selection itself is broken (US1's suspected primary defect) |
| `submission_state` | one of: `not_submitted`, `pending_ack`, `acknowledged`, `failed` |
| `result` | one of: `correct`, `incorrect`, `withheld` (per the existing withheld-answer-key design), present only once `submission_state = acknowledged` |

**Relationships**: one submission per (learner, question) attempt; a retry ("Send again") creates a
new submission attempt against the same question.

**State transitions**:
```
not_submitted --[select option]--> not_submitted (selected_option set)
not_submitted --[submit]--> pending_ack
pending_ack --[server acknowledges]--> acknowledged
pending_ack --[server fails to acknowledge]--> failed
failed --[Send again]--> pending_ack (retry)
```

**Validation rules**:
- **FR-011**: selecting an option MUST transition `selected_option` from absent to set, and this
  MUST be visibly reflected in the UI — this is the transition currently suspected broken (US1).
- **FR-012**: under normal operating conditions, `pending_ack → acknowledged` MUST be the real
  outcome of a submission, not `pending_ack → failed`.
- **FR-013**: the `failed --[Send again]--> pending_ack --> acknowledged` path MUST actually
  succeed under normal operating conditions, not loop back to `failed` identically every time.
- **FR-014**: once a submission reaches `acknowledged`, a page reload/revisit MUST still show that
  submission's `result` — i.e. `acknowledged` state and its `result` MUST be durably persisted and
  re-readable, not only held in transient client state.

---

## Chapter 4 section

**Represents**: A unit of derived learning content for chapter 4, sourced from its underlying
conversation material.

| Field (conceptual) | Notes |
|---|---|
| `section_id` | per-chapter section identifier |
| `source_span` | the portion of chapter 4's source conversation this section is derived from |
| `content` | the rendered section text |
| `voice` | first-person (current, defective) or third-person (target) |

**Relationships**: many sections per chapter 4, each traceable to a `source_span`.

**Validation rules**:
- **FR-015**: `content` MUST be a clear, concluded statement traceable to `source_span` — not a
  disjointed/truncated fragment.
- **FR-016 / SC-009**: `voice` MUST be third-person for every section; no section may retain
  first-person "I ..." phrasing from the source conversation.
- A `source_span` with no clear third-person-summarizable conclusion (per spec.md Edge Cases, e.g.
  small talk) is omitted from section content entirely rather than force-summarized.
