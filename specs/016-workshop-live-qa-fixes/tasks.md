---

description: "Task list for Workshop Live-QA Fix Batch"
---

# Tasks: Workshop Live-QA Fix Batch

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended, given 8 largely-independent stories spanning three languages) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`)
> syntax for tracking.

**Input**: Design documents from `specs/016-workshop-live-qa-fixes/` (spec.md, plan.md,
research.md, data-model.md, contracts/, quickstart.md)

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ — all present.

**Tests**: INCLUDED. The plan's Execution Strategy requires strict TDD for US1, US2, US5, US6; the
other stories are bug fixes against a live, user-facing platform and get regression tests for the
same reason every other fix in this project does — a fix with no failing-then-passing test is not
demonstrated to be a fix.

**Organization**: Tasks are grouped by user story (priority order from spec.md: US1/US2 = P1,
US3/US4/US5/US6 = P2, US7/US8 = P3), each independently implementable and testable, per
plan.md's Parallel Execution Opportunities.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

**Review coverage (`/speckit-analyze` D2):** the constitution's *Independent review* principle
requires review on every change, not only `[REVIEW]`-marked tasks. `[REVIEW]` below marks the 3
tasks needing an EXTRA, named scrutiny gate (highest blast-radius changes) on top of the baseline
every task already gets. That baseline differs by execution method: subagent-driven-development
(this plan's recommended method) reviews every task by default — "Never skip the task review" is
that skill's own rule — so full coverage holds automatically. If this plan is instead executed
natively (superpowers:executing-plans), its own single end-of-branch review is the ONLY review
point unless a reviewer step is manually added per task — in that case, full constitution
compliance requires treating every task as if `[REVIEW]`-marked, not only the 3 named here.

- **[P]**: can run in parallel with sibling tasks — different files, no dependency
- **[TDD]**: strict RED-GREEN-REFACTOR required (per plan.md's TDD Requirements)
- **[REVIEW]**: requires independent review before merge (per plan.md's Review Gates)
- **[SUBAGENT]**: dispatchable to a parallel subagent (per plan.md's Parallel Execution
  Opportunities)
- **[Story]**: which user story (US1–US8) this task belongs to

## Path Conventions

Single existing web-service project, reused as-is (plan.md's Structure Decision):
`workshop/platform/frontend/src/app/`, `workshop/platform/backend/`, `workshop/pipeline/`,
`workshop/curriculum/chapter-04/`. Exact file paths are given where plan.md/research.md's
hypotheses already point to a specific layer; for tasks whose investigation step has not yet run,
the fix sub-task's exact path is recorded as **a finding of its own investigation step**, not
assumed here — this is a deliberate adaptation of writing-plans' "exact paths" requirement to an
investigate-then-fix batch, consistent with the constitution's *Reproduce Before Repairing*
principle this plan is built around.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the live system is in a known, buildable, testable state before any
investigation starts — no new scaffolding is needed (existing stack, per plan.md).

- [ ] T001 Confirm the `workshop` service is running and healthy: `bash workshop/scripts/status.sh`
      (expect `RUNNING`), then `GET /api/health` (authenticated, per this project's existing seed
      test-account convention) and record the `build` stamp as this batch's starting baseline.
- [ ] T002 [P] Confirm the three test suites run clean on the current `main` HEAD before any change
      lands, as the pre-fix baseline: `cd workshop/platform/backend && go test ./...`;
      `cd workshop/platform/frontend && npm run test:unit`;
      `cd workshop && PYTHONPATH=$PWD/pipeline/extract pipeline/venv/bin/pytest pipeline/extract -q`.
      Record pass/fail counts — any pre-existing failure is OUT of scope for this batch and must not
      be conflated with a regression introduced here.
- [ ] T003 `GET /api/index/status` (authenticated) and record the current live generation number and
      whether crossref derivation has completed for it — this is a direct prerequisite for US6's
      investigation (T019) and must not be re-derived per-task.

**Checkpoint**: Baseline recorded — pre-existing suite state and live generation/crossref state are
known before any fix work starts.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: None of this batch's 8 stories share a blocking infrastructure dependency — each is a
self-contained fix in an existing, already-working system (per plan.md's Structure Decision: no new
scaffolding). This phase is intentionally empty; proceed directly to the user stories once Phase 1
is complete.

**Checkpoint**: Phase 1 complete — all 8 user stories may now start, in parallel where plan.md's
Parallel Execution Opportunities allow.

---

## Phase 3: User Story 1 — Practice questions can be answered and are recorded (Priority: P1) 🎯 MVP

**Goal**: A learner can select an answer on a multiple-choice practice question, submit it
successfully, and see that submission reflected after a reload (spec.md FR-011 through FR-014).

**Independent Test**: quickstart.md's "US1" scenario — open
`/practice/01M1GWW49GNKYBEXFFCNRWM1T0`, select, submit, retry-if-needed, reload, confirm the result
persists.

### Investigation for User Story 1

- [ ] T004 [TDD] [US1] Reproduce the reported symptom live against the EXACT area reported
      (`01M1GWW49GNKYBEXFFCNRWM1T0`, per research.md's explicit warning not to substitute a
      different area), with browser dev tools / network inspection open. Record: (a) does a click on
      an answer option change any client-side state at all; (b) if selection works, does a real
      submission reach the server and what response comes back. This is step 1 of research.md's US1
      investigation approach — its output determines whether T005–T008 target one defect or two.

### Tests for User Story 1

- [ ] T005 [TDD] [P] [US1] Write a failing Angular test asserting that clicking a multiple-choice
      option updates the component's selected-option state and the rendered "selected" visual class
      — in the practice-question component's own spec file (exact path confirmed by T004). Run it;
      confirm it FAILS against current behavior if T004 found selection itself broken, or confirm it
      already PASSES (and skip to T006) if T004 found selection working.
- [ ] T006 [TDD] [P] [US1] Write a failing Go test on the practice-answer submission endpoint
      asserting: a well-formed submission (question_id + selected_option) returns an acknowledged
      result (correct/incorrect/withheld), not a "not recorded" failure, under normal conditions —
      exact endpoint/package path confirmed by T004. Run it; confirm it FAILS if T004 found a real
      backend acknowledgment gap, or document that it already passes if T004's hypothesis (selection
      failure is the sole root cause) is confirmed.
- [ ] T007 [TDD] [P] [US1] Write a failing test for the "Send again" retry path: a retried submission
      with the SAME question_id + selected_option succeeds under normal conditions (contracts/
      practice-answer-interaction.md's idempotency clause) rather than deterministically repeating
      the same failure.
- [ ] T007b [TDD] [P] [US1] **Edge case** (spec.md): write a test asserting a genuine
      environmental submission failure (e.g. the progress-recording service simulated as
      unreachable) renders a message DISTINGUISHABLE from the "An answer was not recorded" text this
      batch fixes — once T009/T010 land, a learner must be able to tell a real outage from a
      recurrence of this bug.
- [ ] T008 [TDD] [US1] Write a failing test for read-back: after a successful submission, a
      page reload/revisit (or the equivalent API read) still returns that submission's result
      (FR-014) — not reset to unsubmitted.

### Implementation for User Story 1

- [ ] T009 [SUBAGENT] [US1] Fix the root cause found in T004 — if frontend selection is broken, fix
      the event binding / state update in the practice-question component so T005 passes; if the
      component already worked, skip this task and record why in the ledger (per T004's finding).
- [ ] T010 [REVIEW] [US1] Fix the backend acknowledgment path (only if T004/T006 found a genuine
      server-side gap distinct from the selection bug) so T006 passes. **Review gate**: per plan.md's
      Review Gates, this endpoint touches every learner's every practice attempt — independent review
      required before merge regardless of how small the diff is.
- [ ] T011 [US1] Fix the "Send again" retry path so T007 passes — this may require no code change at
      all if T009/T010 alone resolve it (a retry of a now-working submission naturally succeeds);
      confirm with the test either way.
- [ ] T012 [US1] Fix the read-back path so T008 passes, if the investigation found persistence itself
      (not just submission) broken.
- [ ] T013 [US1] Run T005–T008 again; confirm all pass (GREEN). Run the full frontend and backend
      suites (T002's commands) to confirm no regression elsewhere.
- [ ] T014 [US1] Live-verify per quickstart.md's US1 scenario against the exact reported area, with
      a fresh `scripts/restart.sh` first (constitution: *A Restart Runs What Was Built*) — paste the
      real HTTP responses/UI confirmation, not a code-level pass alone.
- [ ] T015 [US1] Commit (explicit paths, not a blanket add) with a message naming the root cause found
      in T004, referencing spec.md's FR-011–FR-014.

**Checkpoint**: User Story 1 fully functional and live-verified — the platform's core assessment
loop works end to end.

---

## Phase 4: User Story 2 — Completed lessons/sections show as already-completed on return (Priority: P1)

**Goal**: An area page renders every previously completed lesson/section as checked immediately on
load (spec.md FR-009, FR-010, FR-017).

**Independent Test**: quickstart.md's "US2" scenario.

### Investigation for User Story 2

- [ ] T016 [TDD] [P] [SUBAGENT] [US2] Reproduce live: mark a lesson complete on
      `01M1GWW49GNKYBEXFFCNRWM1T0`, confirm the write persisted via the already-working dedicated
      `/progress` page, then reload the SAME area page and confirm the checkmark is actually missing.
      Trace the area page's own data-loading code to find where it reads (or fails to read)
      completion state — per research.md, this is hypothesized to be a DIFFERENT code path than the
      already-fixed progress page, not a regression of it; confirm or refute with evidence.

### Tests for User Story 2

- [ ] T017 [TDD] [P] [US2] Write a failing test (Angular component test, or Go handler test,
      depending on T016's finding) asserting: given a lesson with `completed = true`, the area page's
      render output includes the checked/completed state for that lesson, with no additional
      interaction — exact file confirmed by T016. Run it; confirm FAIL.
- [ ] T017b [TDD] [P] [US2] Write a companion test for the false-positive direction (FR-010): given a
      lesson with `completed = false`, the same render path does NOT mark it checked. Run it; confirm
      it currently passes (this direction is not reported broken) so a future regression here is
      caught.
- [ ] T017c [TDD] [P] [US2] **Edge case** (spec.md): write a test asserting a brand-new learner with
      zero completed lessons on an area sees NO lesson rendered as checked — the all-false-positives
      degenerate case of T017b, worth its own assertion since it is the actual first-visit state
      every learner starts from.

### Implementation for User Story 2

- [ ] T018 [US2] Fix the area page's completion-state read path (file confirmed by T016) so T017
      passes without breaking T017b.
- [ ] T018b [US2] Add the accessible-label / keyboard-reachable / non-color-only treatment to the
      completion checkmark per FR-017 and data-model.md's Lesson/section completion state validation
      rule, if not already present.
- [ ] T019 [US2] Run T017/T017b again; confirm GREEN. Run the frontend/backend suites to confirm no
      regression, specifically including the already-fixed dedicated `/progress` page's own tests (do
      not let this fix touch that surface's passing behavior).
- [ ] T020 [US2] Live-verify per quickstart.md's US2 scenario, fresh restart first, pasted evidence.
- [ ] T021 [US2] Commit, explicit paths, referencing FR-009/FR-010/FR-017.

**Checkpoint**: User Stories 1 AND 2 (both P1) independently functional and live-verified — the MVP
bar for this batch is met.

---

## Phase 5: User Story 3 — Chapter recordings visible where they exist (Priority: P2)

**Goal**: Every chapter with a real recording shows it on the landing page; the text-only chapter
shows the designed "no recording" indicator (spec.md FR-001, FR-002, FR-017).

**Independent Test**: quickstart.md's "US3" scenario.

### Investigation for User Story 3

- [ ] T022 [P] [SUBAGENT] [US3] Inspect the landing page recordings section's data source (network
      request) to determine whether it returns all chapters' metadata (frontend-only rendering bug)
      or only chapter 01's (backend query bug) — per research.md's hypothesis, start here before
      assuming either layer.

### Tests for User Story 3

- [ ] T023 [TDD] [P] [US3] Write a failing test asserting the recordings-listing data source (or
      component, depending on T022's finding) returns/renders an entry for every chapter in the
      content library, not only chapter 01 — exact file confirmed by T022.
- [ ] T024 [TDD] [P] [US3] Write a failing test asserting a chapter with `recording_state =
      none_by_design` (the text-only chapter) renders the designed "no recording" indicator with an
      accessible label (FR-002, FR-017), not an empty gap.
- [ ] T024b [TDD] [P] [US3] **Edge case** (spec.md): write a test asserting a chapter with
      `recording_state = processing` (mid-archive/extract) renders neither the `available` entry nor
      the `none_by_design` indicator, but a distinct, honest in-progress state — a chapter must never
      be misrepresented as either fully available or permanently absent while still processing.

### Implementation for User Story 3

- [ ] T025 [US3] Fix the root cause found in T022 so T023 passes.
- [ ] T026 [US3] Implement the "no recording" indicator component (if it does not already exist) so
      T024 passes.
- [ ] T027 [US3] Run T023/T024 again; confirm GREEN.
- [ ] T028 [US3] Live-verify per quickstart.md's US3 scenario — INCLUDING clicking through from an
      `available` chapter's listing entry into its actual recording route (the *Published Means
      Served* cross-check in contracts/chapter-recordings-listing.md), fresh restart first, pasted
      evidence.
- [ ] T029 [US3] Commit, explicit paths, referencing FR-001/FR-002/FR-017.

**Checkpoint**: US3 independently functional and live-verified.

---

## Phase 6: User Story 4 — Transcription pages never show placeholder/build-missing text (Priority: P2)

**Goal**: Zero occurrences of "Not in this build" anywhere in rendered transcript content
(spec.md FR-003, FR-004).

**Independent Test**: quickstart.md's "US4" scenario.

### Investigation for User Story 4

- [ ] T030 [P] [SUBAGENT] [US4] Search both `workshop/platform/frontend/src/` and
      `workshop/platform/backend/` (and `workshop/pipeline/` if a generated sidecar field could be
      the source) for the literal string "Not in this build" to find its source directly, and
      determine the condition under which it renders instead of real content, and on which
      chapters/segments it currently appears (a full sweep, per FR-003's zero-tolerance framing).

### Tests for User Story 4

- [ ] T031 [TDD] [P] [US4] Write a failing test asserting the found condition (T030) no longer
      renders the literal placeholder string, and instead renders the platform's existing honest
      "content unavailable" presentation (FR-004) — exact file confirmed by T030.
- [ ] T031b [TDD] [P] [US4] **Edge case** (spec.md): write a test asserting that while a chapter's
      transcription is actively being reprocessed, its segments render as "reprocessing in progress"
      (or this platform's existing equivalent in-progress state), never as the build-missing
      placeholder this story removes.

### Implementation for User Story 4

- [ ] T032 [US4] Fix the source found in T030 so T031 passes.
- [ ] T033 [US4] Run T031 again; confirm GREEN. Run a full sweep (automatable: grep the rendered
      output / a scripted crawl of every chapter's transcript page) confirming zero remaining
      occurrences across every chapter, not just the one reproduced in T030.
- [ ] T034 [US4] Live-verify per quickstart.md's US4 scenario, fresh restart first, pasted evidence
      (the full-sweep result from T033, not a single-page spot-check).
- [ ] T035 [US4] Commit, explicit paths, referencing FR-003/FR-004.

**Checkpoint**: US4 independently functional and live-verified.

---

## Phase 7: User Story 5 — Transcription uncertainty is the exception, not the norm (Priority: P2)

**Goal**: Per-chapter "Transcriber unsure" flag rate drops by at least 50%, without reducing segment
count, and remaining flags correspond to genuinely hard-to-transcribe audio (spec.md FR-005,
SC-003 — quantified by this feature's own 2026-10-01 clarification).

**Independent Test**: quickstart.md's "US5" scenario.

### Investigation for User Story 5

- [ ] T036 [P] [SUBAGENT] [US5] Measure the CURRENT per-chapter flagged-uncertain segment rate as the
      baseline (this is also useful as evidence for T002's pre-existing-state record). For a sample
      of currently-flagged segments across multiple chapters, listen to the underlying audio and
      judge whether a reasonable listener would consider each one genuinely hard to transcribe or
      whether the engine's output was already correct despite the flag — this determines whether the
      fix is a threshold-tuning change or requires an actual re-transcription pass.

### Tests for User Story 5

- [ ] T037 [TDD] [US5] Write a failing test asserting the measured per-chapter flagged-uncertain rate,
      after the fix, is at least 50% lower than T036's baseline for every chapter, with segment count
      held constant (SC-003) — this test necessarily runs against real reprocessed output, not a
      mock, per plan.md's TDD Requirements for this story.

### Implementation for User Story 5

- [ ] T038 [US5] Apply the fix determined by T036 (calibration-threshold adjustment and/or a
      re-transcription pass) — per the constitution's *A Statistic a Fix Can Overshoot Requires a
      Two-Sided Check*, if this is a threshold change, it MUST be checked in both directions: confirm
      the reduction does not silently accept segments a reasonable listener would judge genuinely
      wrong as "confident".
- [ ] T039 [US5] Run T037 again; confirm GREEN (≥50% reduction, segment count unchanged, per-chapter).
- [ ] T040 [US5] For the segments STILL flagged uncertain after the fix, spot-check a sample by
      listening to the audio — confirm they are genuinely hard to transcribe (FR-005's "only
      genuinely hard-to-transcribe audio" clause), not a new set of borderline-clear cases introduced
      by the fix itself (the two-sided check from T038, verified).
- [ ] T041 [US5] Live-verify per quickstart.md's US5 scenario, fresh restart first, pasted
      per-chapter before/after figures.
- [ ] T042 [US5] Commit, explicit paths, referencing FR-005/SC-003.

**Checkpoint**: US5 independently functional and live-verified. Long-running (re-transcription) —
started early per plan.md's Parallel Execution Opportunities so its wall-clock overlaps other work.

---

## Phase 8: User Story 6 — "Where else this points" shows genuinely related content (Priority: P2)

**Goal**: Every cross-reference entry is genuinely topically related; an honest empty state renders
when none exist (spec.md FR-006, FR-007, SC-004).

**Independent Test**: quickstart.md's "US6" scenario.

**Dependency**: requires T003's recorded generation/crossref-derivation state before starting
(research.md: *Source Is Not Served* — do not reuse the earlier-same-day verification as current
evidence).

### Investigation for User Story 6

- [ ] T043 [US6] Using T003's recorded state: if crossref derivation has NOT completed for the
      current live generation, this is very likely sufficient explanation on its own — wait for
      derivation to complete and re-check `/api/index/status` before proceeding to T044, rather than
      assuming a code defect. If derivation HAS completed, proceed directly to T044.
- [ ] T044 [P] [SUBAGENT] [US6] Sample cross-reference lists across multiple chapters, INCLUDING
      chapter 03 and chapter 04 content specifically (new since the original same-day scoping fix,
      per research.md). For each sampled passage, tally target kind and flag any bare glossary term
      or internal bookkeeping row — use a sample large enough to speak to recall, not only precision
      (constitution: *A Screen's Precision Is Not Its Recall*). Determine: genuine regression, the
      same scoping gap re-appearing for chapter 03/04 specifically, or (per T043) a
      derivation-timing artifact.

### Tests for User Story 6

- [ ] T045 [TDD] [US6] Write a failing test (mirroring the scoping-fix test shipped earlier the same
      day for the sibling code path, per research.md) asserting the crossref candidate population
      for a representative passage excludes bare glossary-term and bookkeeping-row targets — exact
      file confirmed by T044's root-cause finding.
- [ ] T045b [TDD] [US6] **Edge case** (spec.md): write a test asserting that a passage with zero
      genuinely related cross-references, after the scoping fix, renders an honest empty state —
      confirm the fix does not re-admit a weak/irrelevant match just to avoid an empty list (FR-007).

### Implementation for User Story 6

- [ ] T046 [REVIEW] [US6] Fix the scoping gap found in T044 so T045 passes. **Review gate**: per
      plan.md's Review Gates, this touches crossref derivation/scoping code that was already changed
      once the same day — review against that earlier fix, not layered blindly on top of it.
- [ ] T047 [US6] Run T045 again; confirm GREEN.
- [ ] T048 [US6] Live-verify per quickstart.md's US6 scenario — a sample large enough for an honest
      recall statement, across chapter 03/04 specifically, fresh restart first, pasted evidence
      (target-kind tally, score ranges, zero-bogus-target confirmation).
- [ ] T049 [US6] Commit, explicit paths, referencing FR-006/FR-007/SC-004.

**Checkpoint**: US6 independently functional and live-verified.

---

## Phase 9: User Story 7 — Progress screen labels are never truncated into partial words (Priority: P3)

**Goal**: Every progress-screen first-column label renders in full at supported viewport widths
(spec.md FR-008, SC-005).

**Independent Test**: quickstart.md's "US7" scenario.

- [ ] T050 [P] [SUBAGENT] [US7] Locate the progress screen's first-column component and inspect its
      current CSS (a fixed width with `overflow: hidden` and no responsive wrapping is the most
      likely shape, per research.md).
- [ ] T051 [TDD] [P] [US7] Write a failing test (a rendered-text-content assertion, or a visual
      regression test if this project's suite supports one) asserting the first-column label renders
      as the complete word/phrase at a representative narrow viewport width.
- [ ] T052 [US7] Fix the CSS/layout (wrap, responsive width, or truncate-with-full-text-available) so
      T051 passes, across the viewport range named in spec.md's acceptance scenario (typical desktop
      and mobile).
- [ ] T053 [US7] Run T051 again; confirm GREEN.
- [ ] T054 [US7] Live-verify per quickstart.md's US7 scenario at multiple real viewport widths, fresh
      restart first, pasted evidence/screenshot.
- [ ] T055 [US7] Commit, explicit paths, referencing FR-008/SC-005.

**Checkpoint**: US7 independently functional and live-verified.

---

## Phase 10: User Story 8 — Chapter 4 content is clear, conclusive, third-person prose (Priority: P3)

**Goal**: Every chapter 4 section is a clear, concluded, third-person statement traceable to the
source conversation (spec.md FR-015, FR-016, SC-009).

**Independent Test**: quickstart.md's "US8" scenario.

**Note**: this story's final acceptance is a human readability/accuracy pass (plan.md's Human
Checkpoint 4), not a fully automatable success criterion — T058's mechanical check is a necessary
but not sufficient gate.

- [ ] T056 [P] [SUBAGENT] [US8] Read chapter 4's current section content and its full source
      transcript side by side to identify which specific sections are the clearest instances of
      "thrashy"/first-person fragments, scoping the rewrite precisely (research.md). Confirm the
      existing text-only-chapter section-generation code path (introduced the same day) so the
      rewrite is produced consistently with how other sections are structured, not as a one-off hand
      edit.
- [ ] T057 [TDD] [US8] Write a mechanical pre-check test asserting no chapter 4 section's rendered
      content contains a first-person "I " token (a necessary-but-not-sufficient automated check per
      research.md/plan.md's note that "clear" and "concluded" require human judgment).
- [ ] T057b [TDD] [US8] **Edge case** (spec.md): write a test asserting that a source span with no
      clear third-person-summarizable conclusion (e.g. small talk) is OMITTED from section content
      entirely, not force-summarized into a misleading statement — confirm against at least one real
      small-talk span identified in T056.
- [ ] T058 [US8] Regenerate/rewrite the sections identified in T056, each traceable to its
      `source_span` (data-model.md's Chapter 4 section validation rule), in third person, omitting
      any source span with no clear third-person-summarizable conclusion (spec.md Edge Cases) rather
      than force-summarizing it — staying inside the content-boundary discipline already established
      for this private chapter (no verbatim private-conversation content copied into any new
      public-facing artifact; this feature creates none).
- [ ] T059 [US8] Run T057 again; confirm GREEN (mechanical check only).
- [ ] T060 [REVIEW] [US8] **Human checkpoint** (plan.md's Human Checkpoint 4): read every rewritten
      section end to end against the source conversation for actual clarity, conclusiveness, and
      traceability — the acceptance gate T057 cannot fully automate.
- [ ] T061 [US8] Live-verify per quickstart.md's US8 scenario, fresh restart first.
- [ ] T062 [US8] Commit, explicit paths, referencing FR-015/FR-016/SC-009.

**Checkpoint**: All 8 user stories now independently functional and live-verified.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Final, whole-batch confirmation that nothing regressed across the 8 independent fixes.

- [ ] T063 [P] Run the full backend/frontend/pipeline suites one more time together (quickstart.md's
      "Full-batch regression check" commands) and confirm the pass counts are at or above T002's
      baseline, with zero new failures.
- [ ] T064 Run the relevant `platform/gates/verify-*.sh` checks this batch's changes touch (at
      minimum: anything covering practice/progress endpoints, crossref derivation, and transcript
      rendering) — a SKIP/COULD-NOT-RUN result is reported as such, never rounded up to a pass, per
      this project's own Honest Instruments convention.
- [ ] T065 Fresh `scripts/restart.sh`, confirm `scripts/status.sh` RUNNING/healthy, and re-run
      quickstart.md's 8 per-story scenarios one final time end to end against the single final build,
      pasting the build stamp from `/api/health` once for the whole batch.
- [ ] T066 Update `specs/016-workshop-live-qa-fixes/checklists/requirements.md` if any finding during
      implementation revealed a spec gap not caught during `/speckit-clarify` (expected: none, but
      checked rather than assumed).
- [ ] T067 **[/speckit-analyze D1]** Update `CONTINUATION.md` at the `workshop` repository root
      describing this batch's 8 fixes (per the constitution's *Comprehensive Documentation*
      principle — a MUST, mechanically enforced by `scripts/continuation-check.sh`), in the SAME
      commit as T065's final live-verification evidence — not a separate, later commit.

**Checkpoint**: Batch complete — all 8 stories live-verified together on one final build.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately.
- **Foundational (Phase 2)**: empty for this batch — no blocking shared infrastructure.
- **User Stories (Phases 3–10)**: each depends only on Phase 1's baseline recording, per plan.md's
  Parallel Execution Opportunities:
  - US1 (Phase 3) and US2 (Phase 4): independent, parallel-dispatchable.
  - US3 (Phase 5), US4 (Phase 6), US7 (Phase 9): independent, parallel-dispatchable — no shared
    files, narrowly scoped.
  - US5 (Phase 7) and US8 (Phase 10): independent of each other and everything else; both
    long-running (re-transcription, content rewrite) — start early.
  - US6 (Phase 8): depends on T003's recorded generation/derivation state before its own
    investigation (T043) can proceed meaningfully; otherwise independent of the other 7 stories.
- **Polish (Phase 11)**: depends on all 8 user-story phases being complete.

### Within Each User Story

- Investigation before tests (the exact file/root-cause a test targets is often only known after the
  investigation task runs — this is the batch's core adaptation of standard TDD ordering to an
  investigate-then-fix shape).
- Tests MUST be written and FAIL before implementation (per plan.md's TDD Requirements; not optional
  for US1/US2/US5/US6, and used for every other story's regression coverage too).
- Implementation before live verification.
- Live verification before commit.

### Parallel Opportunities

- T002 and T003 (Phase 1) can run in parallel.
- Phase 3 (US1) and Phase 4 (US2) can be dispatched to parallel subagents once Phase 1 completes.
- Phases 5, 6, 9 (US3, US4, US7) can be dispatched to parallel subagents — no shared files.
- Phases 7 and 10 (US5, US8) can be dispatched to parallel subagents, started early for their
  wall-clock cost.
- Phase 8 (US6) can start in parallel with the others but its own T043→T044 sequence is internally
  blocking (derivation-completion check before sampling).
- Within each story, `[P]`-marked investigation/test tasks for different files run in parallel; the
  fix task that depends on a given investigation's finding does not start until that investigation
  task completes.

---

## Parallel Example: Phase 1 → Phases 3–10 fan-out

```text
# Phase 1 (sequential, fast):
T001 → T002 [P] + T003 [P] (parallel)

# Once Phase 1 completes, dispatch in parallel:
Subagent A: Phase 3 (US1) — T004 through T015
Subagent B: Phase 4 (US2) — T016 through T021
Subagent C: Phase 5 (US3) — T022 through T029
Subagent D: Phase 6 (US4) — T030 through T035
Subagent E: Phase 7 (US5) — T036 through T042 (long-running, start first within its slot)
Subagent F: Phase 8 (US6) — T043 through T049 (blocked on T003's finding)
Subagent G: Phase 9 (US7) — T050 through T055
Subagent H: Phase 10 (US8) — T056 through T062 (long-running, start first within its slot)

# Once all 8 report complete:
Phase 11 (Polish) — T063 through T066, sequential whole-batch confirmation
```

---

## Implementation Strategy

### MVP First (User Stories 1 and 2 only)

1. Complete Phase 1: Setup.
2. Complete Phase 3: User Story 1 (practice interaction — the platform's core loop).
3. Complete Phase 4: User Story 2 (completion checkmarks).
4. **STOP and VALIDATE**: both P1 stories live-verified independently — this is the minimum bar a
   learner needs to actually use the platform meaningfully again.

### Incremental Delivery

1. Phase 1 → baseline recorded.
2. US1 + US2 (P1, parallel) → validate independently → this is the functional-blocker MVP.
3. US3 + US4 + US5 + US6 (P2, parallel where independent) → validate independently.
4. US7 + US8 (P3, parallel) → validate independently.
5. Phase 11 → whole-batch final confirmation on one build.

### Parallel Team / Subagent Strategy

With `subagent-driven-development` (recommended given 8 independent stories across three
languages):

1. One subagent (or the controller) completes Phase 1.
2. Once Phase 1 is done, dispatch up to 8 subagents in parallel, one per story, each working from
   its own Phase section above as its brief — research.md's per-story hypothesis is the starting
   context for each dispatch, not re-derived by each subagent from scratch.
3. Each story's fresh implementer is followed by a task reviewer for [REVIEW]-marked tasks (T010,
   T046, T060) specifically, per plan.md's Review Gates.
4. A final whole-branch review happens after Phase 11, per the standard subagent-driven-development
   closing step.

---

## Notes

- `[P]` tasks touch different files with no dependency between them.
- `[Story]` maps every task to its spec.md user story for traceability.
- Investigation tasks exist BEFORE test tasks in every story, deliberately — writing a test against
  an unconfirmed file/function would itself violate *Reproduce Before Repairing*.
- Every story's live-verification task requires a FRESH `scripts/restart.sh` and a pasted build
  stamp — a code-level test pass alone never closes a story in this batch (constitution: *A Restart
  Runs What Was Built*, *Source Is Not Served*, *Evidence-Based Claims*).
- Commit after each story, explicit paths, never a blanket `git add .` on this shared tree.
- Avoid: skipping an investigation task "because the root cause seems obvious" — research.md names
  at least one plausible alternative hypothesis per story specifically to guard against this.

## Self-Review (writing-plans discipline)

Performed against this file before handoff, per superpowers:writing-plans' required self-review:

- **Spec coverage**: every FR-001 through FR-017 and every SC-001 through SC-010 in spec.md maps to
  at least one task above (confirmed by walking spec.md's Requirements/Success Criteria sections
  against each story's task list).
- **Placeholder scan**: no "TBD"/"TODO"/"implement later"/"add appropriate error handling" patterns
  found. The recurring "exact file confirmed by T0XX" phrasing is a deliberate, explained adaptation
  (see the Path Conventions note above) for an investigate-then-fix batch, not an unfilled
  placeholder — every such task still states a concrete, testable assertion.
- **Type/terminology consistency**: field and state names (`selected_option`, `completed`,
  `recording_state`, `render_state`, etc.) are used consistently with data-model.md throughout.
- **Review Focus (edge cases)**: this pass found 6 of spec.md's named Edge Cases with no exercising
  task in the first draft — T007b (offline/connectivity distinguishable from the fixed bug), T017c
  (zero-completed new learner), T024b (mid-processing chapter state), T031b (reprocessing-in-progress
  transcript state), T045b (honest empty cross-reference state), T057b (omit, don't force-summarize,
  an unclear source span). All 6 are now added to their owning story, not left for Phase 11 to
  discover.
