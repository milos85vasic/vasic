# Contract: Landing-Page Chapter Recordings Listing (US3)

The correct contract the fix must satisfy — not a verified description of the current
implementation.

## Listing

**Contract**: the data source backing the landing screen's recordings section MUST return an entry
for EVERY chapter in the content library, each carrying enough information for the frontend to
render one of exactly three states (see data-model.md: `available`, `processing`,
`none_by_design`) — not only the first chapter.

- **Input**: the landing screen's load of its recordings section.
- **Output**: a complete list, one entry per chapter, each with a determinable recording state.
- **Failure mode this fix must close**: only chapter 01 renders a populated entry; every other
  chapter (regardless of whether it has a real recording) renders empty (US3's reported defect).

## Per-chapter rendering

**Contract**: for a chapter whose state is `available`, the rendered entry MUST be a working
recording entry (thumbnail/player/link), functionally equivalent to chapter 01's current entry —
not a degraded or partial version. For a chapter whose state is `none_by_design` (currently: the
text-only chapter introduced the same day), the rendered entry MUST be the purpose-built "no
recording" indicator (FR-002), carrying an accessible label (FR-017) — never an empty gap.

## Published Means Served (constitution cross-check)

Per this project's own *Published Means Served* principle: if the landing page's list includes a
chapter, that chapter's own recording route (wherever the "no recording" indicator or the player
links to / reads from) MUST actually resolve to the state the list implied — a chapter shown as
`available` on the landing page whose underlying recording route then 404s or refuses would violate
this principle in the same shape the constitution's own cited incident describes. The fix MUST be
verified end to end (list entry AND the route it points to), not only at the listing level.

## What this contract does NOT claim

- It does not assert whether the root cause is a frontend-only rendering bug, a backend query that
  only returns one chapter, or something else — Phase 0 research determines that.
- It does not require generating or fabricating a recording for the text-only chapter — its correct
  "served" state is the designed indicator, not a video.
