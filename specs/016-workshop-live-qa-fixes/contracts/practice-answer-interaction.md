# Contract: Practice Answer Selection and Submission (US1)

This documents the CORRECT contract the fix must satisfy — i.e. the behavior FR-011 through FR-014
require — not a verified description of the current (broken) implementation. The exact current
endpoint shapes are confirmed during implementation (Phase 0 research / root-cause step), not
assumed here.

## Client-side selection

**Contract**: clicking/tapping a multiple-choice option on a practice question MUST update visible
UI state synchronously (no network round-trip required to show a selection) and MUST remain
selected until changed or submitted.

- **Input**: a user interaction event on one option of a rendered question.
- **Output**: that option's visual state changes to "selected"; any previously selected option (for
  a single-select question) reverts to unselected.
- **Failure mode this fix must close**: no visible state change occurs at all (US1's primary
  suspected defect).

## Submission

**Contract**: `POST` (or equivalent) a submission carrying `question_id` + `selected_option` to the
practice-answer endpoint.

- **Success response**: acknowledges the write and returns the learner's actual result —
  `correct` / `incorrect` / `withheld` (per the platform's existing anti-cheating withheld-answer
  design, confirmed working for questions where selection itself succeeds) — never a generic
  "not recorded" failure under normal operating conditions.
- **Failure response** (only under genuine environmental failure, e.g. the progress-recording
  service being actually down): a response the UI renders as "An answer was not recorded", with
  enough detail that a distinct real outage is distinguishable from this defect once fixed.
- **Idempotency**: resubmitting the same `question_id` + `selected_option` (the "Send again" path)
  MUST be safe to retry and, under normal operating conditions, MUST succeed rather than
  deterministically fail the same way every time.

## Read-back (persistence)

**Contract**: `GET` (or equivalent) a previously submitted answer's state for a given
`question_id` MUST return the same `result` that was returned at submission time, after a page
reload or revisit — not an empty/reset state.

## What this contract does NOT claim

- It does not assert which HTTP method, path, or payload shape the current implementation actually
  uses — that is confirmed by the implementer reading the real endpoint during the fix.
- It does not change the existing withheld-answer-key design (the ~98%-of-questions
  answer-withholding behavior already shipped and verified working) — only the broken
  selection/acknowledgment/retry path around it.
