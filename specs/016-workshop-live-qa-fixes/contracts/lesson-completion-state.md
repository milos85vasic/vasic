# Contract: Lesson/Section Completion State on Area-Page Load (US2)

The correct contract the fix must satisfy — not a verified description of the current
implementation.

## Area-page load

**Contract**: when an area page (`/areas/{area-id}`) loads, for every lesson/section it lists, its
rendered completion state MUST equal that lesson/section's actual persisted `completed` value for
the current learner — read fresh (or from a cache whose staleness does not outlive the completion
write it is meant to reflect), never from a load-time-only snapshot that predates a completion made
in an earlier visit.

- **Input**: a page load/reload of `/areas/{area-id}` by an authenticated learner.
- **Output**: each lesson/section item renders with a checkmark (or equivalent completed-state
  indicator) if and only if `completed = true` for that (learner, lesson) pair.
- **Failure mode this fix must close**: every lesson/section renders as not-completed on page load
  regardless of actual persisted state (US2's reported defect).

## Relationship to the existing dedicated progress page

**Contract**: this area-page read path and the dedicated `/progress` page's read path (already
fixed and verified working earlier the same day) MAY be backed by the same underlying completion
store, but each surface's own rendering code MUST independently read and respect it — fixing one
surface's cache/query/render bug does not fix the other's.

## What this contract does NOT claim

- It does not assert the two surfaces (area page, progress page) share implementation code — Phase
  0 research determines that.
- It does not change what counts as "completed" (no change to the completion-marking interaction
  itself) — only whether an already-completed state is correctly reflected on load.
