---

description: "Task list for Workshop Live-QA Fix Batch"
---

# Tasks: Workshop Live-QA Fix Batch

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended, given 8 largely-independent stories spanning three languages) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`)
> syntax for tracking.

**Reconciliation (Reconciled by 026 on 2026-10-20, spec `026-spec-reconciliation`, decision D9)**: checkboxes below were reconciled against workshop HEAD `33e9760` source (not re-run). 41 tasks are ticked because the gap analysis proved them DONE with a commit or file cite (source present at HEAD; tests were not re-run by 026). NOT ticked and why: tasks whose only evidence is the git-ignored SDD ledger or `CONTINUATION.md` prose (T001-T003, T013, T059, T063, T066; T019 [frontend only], T027, T047 and T053 were ticked later by S6 with run evidence), every live-verify / human task (T004, T014, T016, T020, T028, T034, T040, T048, T060, T061), the PARTIAL ones and T045b (annotated in place). Spec FR status from the same analysis: FR-007 UNMET (top-20 always returned, no empty state), FR-006 PARTIAL (cosine, `min_score` 0), FR-012/FR-013/FR-014 PARTIAL (doc/code-cited first citations never write progress server-side; reload survival is `sessionStorage` only), all others MET in source. Sequencing (D10): 016-US1 (practice answer submit fix) merges BEFORE spec 013-US1 touches the same submit path (`internal/api/questions*.go`, `progress.go`). Open items carried: rebuild the frontend bundle (stale vs commits `eb691db`, `1d4cdfa`), rerun the two UNDETERMINED gates, T045b.

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
      *(Stream S2 on 2026-10-20: NOT re-run live (no authenticated live access from a worktree). The defect precondition was RE-MEASURED from data instead: 62 of 292 bank questions have a first citation with no transcript time span (55 doc_section, 7 code), evidence/s2/016-us1/measure-first-citation-kinds.out; the reproduction on the backend is TestPracticeAnswer_DefectPrecondition_TimelessCitationHasNoTimeAxis. Live reproduction UNCONFIRMED.))*

### Tests for User Story 1

- [x] T005 [TDD] [P] [US1] Write a failing Angular test asserting that clicking a multiple-choice
      option updates the component's selected-option state and the rendered "selected" visual class
      — in the practice-question component's own spec file (exact path confirmed by T004). Run it;
      confirm it FAILS against current behavior if T004 found selection itself broken, or confirm it
      already PASSES (and skip to T006) if T004 found selection working.
- [x] T006 [TDD] [P] [US1] Write a failing Go test on the practice-answer submission endpoint
      asserting: a well-formed submission (question_id + selected_option) returns an acknowledged
      result (correct/incorrect/withheld), not a "not recorded" failure, under normal conditions —
      exact endpoint/package path confirmed by T004. Run it; confirm it FAILS if T004 found a real
      backend acknowledgment gap, or document that it already passes if T004's hypothesis (selection
      failure is the sole root cause) is confirmed.
      *(Stream S2 on 2026-10-20: DONE, evidence: platform/backend/internal/api/practice_answers_test.go (named oracles in its header) tests a real answer endpoint, not the reading-position write. RED: evidence/s2/016-us1/016-red-backend.txt (build failure undefined api.PracticeAnswerDeps), GREEN: green-backend-api.txt; commit 4db130d on workshop worktree branch s2-016us1-013us1))*
- [x] T007 [TDD] [P] [US1] Write a failing test for the "Send again" retry path: a retried submission
      with the SAME question_id + selected_option succeeds under normal conditions (contracts/
      practice-answer-interaction.md's idempotency clause) rather than deterministically repeating
      the same failure.
- [x] T007b [TDD] [P] [US1] **Edge case** (spec.md): write a test asserting a genuine
      environmental submission failure (e.g. the progress-recording service simulated as
      unreachable) renders a message DISTINGUISHABLE from the "An answer was not recorded" text this
      batch fixes — once T009/T010 land, a learner must be able to tell a real outage from a
      recurrence of this bug.
- [x] T008 [TDD] [US1] Write a failing test for read-back: after a successful submission, a
      page reload/revisit (or the equivalent API read) still returns that submission's result
      (FR-014) — not reset to unsubmitted.
      *(Reconciled by 026 on 2026-10-20: PARTIAL: read-back uses browser `sessionStorage` only (`practice.component.ts:559-625`); no server-side persisted answer result across sessions.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W aebb8ca spec.ts:708,742,771.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: progress_practice_answer_test.go:66; spec.ts:579.)*
      *(Reconciled by 026 on 2026-10-20: DONE (weak): the Go test covers the reading-position write (`progress_practice_answer_test.go:41`), not an answer endpoint; left unticked.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W 3025ee9 practice.component.spec.ts:440,453,474.)*
      *(Stream S2 on 2026-10-20: DONE, evidence: server-side read-back across a reload and across a NEW browser session: backend TestPracticeAnswer_SurvivesReload, frontend 'FR-014 (NEW SESSION, sessionStorage gone)' in practice.component.spec.ts. RED frontend: 13 of 23 specs failing, evidence/s2/016-us1/016-red-frontend.log; GREEN 30/30; commit 4db130d))*

### Implementation for User Story 1

- [x] T009 [SUBAGENT] [US1] Fix the root cause found in T004 — if frontend selection is broken, fix
      the event binding / state update in the practice-question component so T005 passes; if the
      component already worked, skip this task and record why in the ledger (per T004's finding).
- [ ] T010 [REVIEW] [US1] Fix the backend acknowledgment path (only if T004/T006 found a genuine
      server-side gap distinct from the selection bug) so T006 passes. **Review gate**: per plan.md's
      Review Gates, this endpoint touches every learner's every practice attempt — independent review
      required before merge regardless of how small the diff is.
      *(Stream S2 on 2026-10-20: IMPLEMENTED, independent review PENDING (REVIEW-tagged, not self-certifiable). The 'backend acknowledgment gap' turned out to be that no answer endpoint existed at all: PUT/GET /api/areas/{area}/practice-answers (internal/api/practice_answers.go), commit 4db130d. NOTE for the reviewer: result is 'withheld' (never correct/incorrect) for gated-assessment rows so the endpoint is not an answer oracle (D9); wiring needs the one main.go line documented in cmd/workshop-server/wire_practice.go's header.))*
- [x] T011 [US1] Fix the "Send again" retry path so T007 passes — this may require no code change at
      all if T009/T010 alone resolve it (a retry of a now-working submission naturally succeeds);
      confirm with the test either way.
- [x] T012 [US1] Fix the read-back path so T008 passes, if the investigation found persistence itself
      (not just submission) broken.
      *(Stream S2 on 2026-10-20: DONE, evidence: the read-back path is the server record (GET .../practice-answers) restored by PracticeComponent.adoptServerAnswers; sessionStorage remains the same-tab path. 5/5 frontend mutants and 7/7 backend mutants caught (evidence/s2/016-us1/mutants_*.json); commit 4db130d))*
- [x] T013 [US1] Run T005–T008 again; confirm all pass (GREEN). Run the full frontend and backend
      suites (T002's commands) to confirm no regression elsewhere.
      *(Stream S2 on 2026-10-20: DONE, evidence: backend internal/api + cmd/workshop-server and frontend full suite. Frontend ng test: 600 SUCCESS (green-frontend-full.txt). Backend: internal/api ok (needs WORKSHOP_HTTP_DELTA_CONTRACT in a worktree, environmental); cmd/workshop-server failing set IDENTICAL to the Wave-0 baseline (22 auth/LAN tests that need the real seed password), nothing new fails; go vet has one pre-existing failure in pkg/authstore/ensure_user_test.go))*
- [ ] T014 [US1] Live-verify per quickstart.md's US1 scenario against the exact reported area, with
      a fresh `scripts/restart.sh` first (constitution: *A Restart Runs What Was Built*) — paste the
      real HTTP responses/UI confirmation, not a code-level pass alone.
      *(Stream S2 on 2026-10-20: NOT DONE: live verification needs the rebuilt+restarted stack, authenticated, and a main.go hook line this stream may not apply. UNCONFIRMED. A full-route-table test with the line applied via go test -overlay passes: evidence/s2/013-us1/green-routes-with-the-main-go-line-via-overlay.txt))*
- [x] T015 [US1] Commit (explicit paths, not a blanket add) with a message naming the root cause found
- [x] T015b [US1] *(S2 round 5, 2026-10-20, amendment recorded in contracts/practice-answer-interaction.md)* Replace the client-side restart marker by a SERVER-OWNED run pass: `POST .../practice-answers/restart`, `pass` on every record and in the GET/PUT replies, `409 pass_stale`. Evidence: `evidence/s2/review-fixes/round5/` in the workshop repository (RED -> GREEN, paired mutants, Karma 4 orders).
      in T004, referencing spec.md's FR-011–FR-014.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: 3025ee9, 164e2f8, aebb8ca, eacef82.)*
      *(Reconciled by 026 on 2026-10-20: PARTIAL: `sessionStorage` only (W 164e2f8).)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W eacef82 (record() skips timeless doc/code citations: practice.component.ts:838) + aebb8ca; NOTE this is a skip, not a recording.)*
      *(Reconciled by 026 on 2026-10-20: N/A per the gap analysis: no backend change was needed; the only review evidence is the git-ignored SDD ledger, so it is left unticked.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W 3025ee9 practice.component.ts (disabled-binding/pick guard decoupled from withheld key).)*
      *(Stream S2 on 2026-10-20: DONE, commit 4db130d on workshop worktree branch s2-016us1-013us1 naming the root cause; FR-011-FR-014 referenced))*

**S2 note (2026-10-20)**: BEHAVIOUR CHANGE: the practice deck no longer writes the READING POSITION (`POST /api/progress`) for transcript-cited questions; an answer is recorded via `PUT .../practice-answers/{q}` instead, so a practice answer no longer moves the Progress page's reading position. Anonymous-to-account migration does not carry practice answers (known limitation).

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

- [x] T017 [TDD] [P] [US2] Write a failing test (Angular component test, or Go handler test,
      depending on T016's finding) asserting: given a lesson with `completed = true`, the area page's
      render output includes the checked/completed state for that lesson, with no additional
      interaction — exact file confirmed by T016. Run it; confirm FAIL.
- [x] T017b [TDD] [P] [US2] Write a companion test for the false-positive direction (FR-010): given a
      lesson with `completed = false`, the same render path does NOT mark it checked. Run it; confirm
      it currently passes (this direction is not reported broken) so a future regression here is
      caught.
- [x] T017c [TDD] [P] [US2] **Edge case** (spec.md): write a test asserting a brand-new learner with
      zero completed lessons on an area sees NO lesson rendered as checked — the all-false-positives
      degenerate case of T017b, worth its own assertion since it is the actual first-visit state
      every learner starts from.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: area-lesson-completion.spec.ts:167.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: area-lesson-completion.spec.ts:155.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W b67af5f area-lesson-completion.spec.ts:139.)*

### Implementation for User Story 2

- [x] T018 [US2] Fix the area page's completion-state read path (file confirmed by T016) so T017
      passes without breaking T017b.
- [x] T018b [US2] Add the accessible-label / keyboard-reachable / non-color-only treatment to the
      completion checkmark per FR-017 and data-model.md's Lesson/section completion state validation
      rule, if not already present.
- [x] T019 [US2] Run T017/T017b again; confirm GREEN. Run the frontend/backend suites to confirm no
      regression, specifically including the already-fixed dedicated `/progress` page's own tests (do
      not let this fix touch that surface's passing behavior).
      *(S6: FRONTEND PASS - `npx ng test --watch=false --karma-config=<scratch>` full suite = TOTAL 591 SUCCESS (evidence/s6/fe-full.txt), incl. area-lesson-completion + progress specs. BACKEND UNDETERMINED (reviewer comparison base vs head: the same 31 backend tests fail on both sides; only pkg/authstore moved, from a test build error to the seed-password TestT502) - go test ./... gave 5 FAIL packages: pkg/authstore (test compile error ensure_user_test.go:44, FIXED in 5302e40; its T502 test still needs the real seed password), ~20 auth/login tests in cmd/workshop-server, internal/api, pkg/authhttp (need WORKSHOP_TEST_SEED_PASSWORD = the real password), TestGateKG1 (needs superproject specs), TestCorruptWindowStoreStopsTheBoot (passes alone, fails in the full run: order-dependent). evidence/s6/backend-full.txt)*
- [ ] T020 [US2] Live-verify per quickstart.md's US2 scenario, fresh restart first, pasted evidence.
- [x] T021 [US2] Commit, explicit paths, referencing FR-009/FR-010/FR-017.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: b67af5f.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: spec.ts:178 (real checkbox w/ label).)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: area-lessons.component.ts:446-463 (adoptServerView from server `state`), curriculum-model.ts:166-194.)*

**Checkpoint**: User Stories 1 AND 2 (both P1) independently functional and live-verified — the MVP
bar for this batch is met.

---

## Phase 5: User Story 3 — Chapter recordings visible where they exist (Priority: P2)

**Goal**: Every chapter with a real recording shows it on the landing page; the text-only chapter
shows the designed "no recording" indicator (spec.md FR-001, FR-002, FR-017).

**Independent Test**: quickstart.md's "US3" scenario.

### Investigation for User Story 3

- [x] T022 [P] [SUBAGENT] [US3] Inspect the landing page recordings section's data source (network
      request) to determine whether it returns all chapters' metadata (frontend-only rendering bug)
      or only chapter 01's (backend query bug) — per research.md's hypothesis, start here before
      assuming either layer.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W f13e644 message; ledger us3-report.md.)*

### Tests for User Story 3

- [x] T023 [TDD] [P] [US3] Write a failing test asserting the recordings-listing data source (or
      component, depending on T022's finding) returns/renders an entry for every chapter in the
      content library, not only chapter 01 — exact file confirmed by T022.
- [x] T024 [TDD] [P] [US3] Write a failing test asserting a chapter with `recording_state =
      none_by_design` (the text-only chapter) renders the designed "no recording" indicator with an
      accessible label (FR-002, FR-017), not an empty gap.
- [x] T024b [TDD] [P] [US3] **Edge case** (spec.md): write a test asserting a chapter with
      `recording_state = processing` (mid-archive/extract) renders neither the `available` entry nor
      the `none_by_design` indicator, but a distinct, honest in-progress state — a chapter must never
      be misrepresented as either fully available or permanently absent while still processing.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: chapter-rail.component.spec.ts:131; recording.go:525-578; recording_state_test.go:38-69.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: chapter-rail.component.spec.ts:100; component aria-label chapter-rail.component.ts:57.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W f13e644 chapters_recording_state_test.go (cmd/workshop-server), models.spec.ts.)*

### Implementation for User Story 3

- [x] T025 [US3] Fix the root cause found in T022 so T023 passes.
- [x] T026 [US3] Implement the "no recording" indicator component (if it does not already exist) so
      T024 passes.
- [x] T027 [US3] Run T023/T024 again; confirm GREEN.
      *(S6: 9 RecordingState Go tests PASS (evidence/s6/t027-recording-state.txt); chapter-rail spec inside the 591-SUCCESS frontend run (fe-full.txt).)*
- [ ] T028 [US3] Live-verify per quickstart.md's US3 scenario — INCLUDING clicking through from an
      `available` chapter's listing entry into its actual recording route (the *Published Means
      Served* cross-check in contracts/chapter-recordings-listing.md), fresh restart first, pasted
      evidence.
- [x] T029 [US3] Commit, explicit paths, referencing FR-001/FR-002/FR-017.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: f13e644.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: chapter-rail.component.ts:49-68.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: f13e644 (backend recording_state in recording.go; rail no longer index-0 only).)*

**Checkpoint**: US3 independently functional and live-verified.

---

## Phase 6: User Story 4 — Transcription pages never show placeholder/build-missing text (Priority: P2)

**Goal**: Zero occurrences of "Not in this build" anywhere in rendered transcript content
(spec.md FR-003, FR-004).

**Independent Test**: quickstart.md's "US4" scenario.

### Investigation for User Story 4

- [x] T030 [P] [SUBAGENT] [US4] Search both `workshop/platform/frontend/src/` and
      `workshop/platform/backend/` (and `workshop/pipeline/` if a generated sidecar field could be
      the source) for the literal string "Not in this build" to find its source directly, and
      determine the condition under which it renders instead of real content, and on which
      chapters/segments it currently appears (a full sweep, per FR-003's zero-tolerance framing).
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W 5b00c30; today grep: only spec file, plus genuine spoken words in chapter-02.02 transcript (passages.jsonl 1 hit, not placeholder).)*

### Tests for User Story 4

- [x] T031 [TDD] [P] [US4] Write a failing test asserting the found condition (T030) no longer
      renders the literal placeholder string, and instead renders the platform's existing honest
      "content unavailable" presentation (FR-004) — exact file confirmed by T030.
- [x] T031b [TDD] [P] [US4] **Edge case** (spec.md): write a test asserting that while a chapter's
      transcription is actively being reprocessed, its segments render as "reprocessing in progress"
      (or this platform's existing equivalent in-progress state), never as the build-missing
      placeholder this story removes.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W 5b00c30 passage-knowledge-gap-label.spec.ts:81,113.)*
      *(Reconciled by 026 on 2026-10-20: PARTIAL: only a "while loading" test (`passage-knowledge-gap-label.spec.ts:98`); no reprocessing-state test/UI.)* [superseded 2026-10-20 by S6 round-1 test: 503 + Retry state, never the placeholder (evidence/s6/fe-batch1.txt)]
      *(S6: passage-knowledge-gap-label.spec.ts has a new test (503 while the registry is rebuilt -> Retry state -> recovers to content; the placeholder phrase never appears); 34/34 SUCCESS (evidence/s6/fe-batch1.txt). The platform has no separate reprocessing status; the 503+Retry state is the existing in-progress presentation. Supersedes the 026 PARTIAL note.)*

### Implementation for User Story 4

- [x] T032 [US4] Fix the source found in T030 so T031 passes.
- [x] T033 [US4] Run T031 again; confirm GREEN. Run a full sweep (automatable: grep the rendered
      output / a scripted crawl of every chapter's transcript page) confirming zero remaining
      occurrences across every chapter, not just the one reproduced in T030.
      *(S6 (round 2, supersedes the round-1 figures below; independently reviewed GO at b607bfd): internal/placeholdersweep scans source 75 frontend / 198 backend / 109 pipeline files (0 hits, 0 walk errors) and DATA = every tracked curriculum/**/*.jsonl, *.json and *.md: 30 jsonl + 126 json + 10 md files = 62458 records, 0 whole-field hits, 0 malformed, 4 in-prose (genuine speech, counted, bound 12, never quoted). It FAILS on 0 files, any walk/read error, malformed lines/json, a missing registry, a whole-field value in jsonl/json/md, and prose above the bound (vacuity modes V1-V12 all verified failing; evidence/s6/t033-sweep-v3.txt, mutants-round2.txt). Known blind spots: symlinked directories are not followed, JSON object KEYS are not scanned, a wrapped value such as "[Not in this build]" counts as prose. NOT COVERED: the rendered/served pages and platform/web bundle (the live crawl, T034, is NOT done), runtime-built text.) Round-1 text kept for the record: internal/placeholdersweep asserts named coverage: source 75 frontend / 198 backend / 109 pipeline files scanned with 0 hits and 0 walk errors; data 30 jsonl + 5 transcript.segments.json = 62327 records, 0 whole-field hits, 0 malformed, 3 in-prose (genuine speech, count only, bound 12). It FAILS on 0 files, walk errors, malformed lines or a missing registry (4 mutants killed, evidence/s6/t033-mutants-v2.txt). NOT COVERED: the rendered/served pages and platform/web bundle (the live crawl, T034, is NOT done), runtime-built text.)*
- [ ] T034 [US4] Live-verify per quickstart.md's US4 scenario, fresh restart first, pasted evidence
      (the full-sweep result from T033, not a single-page spot-check).
- [x] T035 [US4] Commit, explicit paths, referencing FR-003/FR-004.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: 5b00c30.)*
      *(Reconciled by 026 on 2026-10-20: PARTIAL: no scripted crawl found in the repo.)* [superseded 2026-10-20 by S6 automated sweep (internal/placeholdersweep); the scripted crawl of served pages is still NOT done]
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: passage-knowledge.component.ts (hardcoded badge deleted, 5b00c30).)*

**Checkpoint**: US4 independently functional and live-verified.

---

## Phase 7: User Story 5 — Transcription uncertainty is the exception, not the norm (Priority: P2)

**Goal**: Per-chapter "Transcriber unsure" flag rate drops by at least 50%, without reducing segment
count, and remaining flags correspond to genuinely hard-to-transcribe audio (spec.md FR-005,
SC-003 — quantified by this feature's own 2026-10-01 clarification).

**Independent Test**: quickstart.md's "US5" scenario.

### Investigation for User Story 5

- [x] T036 [P] [SUBAGENT] [US5] Measure the CURRENT per-chapter flagged-uncertain segment rate as the
      baseline (this is also useful as evidence for T002's pre-existing-state record). For a sample
      of currently-flagged segments across multiple chapters, listen to the underlying audio and
      judge whether a reasonable listener would consider each one genuinely hard to transcribe or
      whether the engine's output was already correct despite the flag — this determines whether the
      fix is a threshold-tuning change or requires an actual re-transcription pass.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: 5e25ef7 message: 25.3-54.8% baseline per chapter.)*

### Tests for User Story 5

- [x] T037 [TDD] [US5] Write a failing test asserting the measured per-chapter flagged-uncertain rate,
      after the fix, is at least 50% lower than T036's baseline for every chapter, with segment count
      held constant (SC-003) — this test necessarily runs against real reprocessed output, not a
      mock, per plan.md's TDD Requirements for this story.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: pipeline/test_uncertain_rate_reduction.py (+registry parity, upper bound; eef689a).)*

### Implementation for User Story 5

- [x] T038 [US5] Apply the fix determined by T036 (calibration-threshold adjustment and/or a
      re-transcription pass) — per the constitution's *A Statistic a Fix Can Overshoot Requires a
      Two-Sided Check*, if this is a threshold change, it MUST be checked in both directions: confirm
      the reduction does not silently accept segments a reasonable listener would judge genuinely
      wrong as "confident".
- [x] T039 [US5] Run T037 again; confirm GREEN (≥50% reduction, segment count unchanged, per-chapter).
- [ ] T040 [US5] For the segments STILL flagged uncertain after the fix, spot-check a sample by
      listening to the audio — confirm they are genuinely hard to transcribe (FR-005's "only
      genuinely hard-to-transcribe audio" clause), not a new set of borderline-clear cases introduced
      by the fix itself (the two-sided check from T038, verified).
- [ ] T041 [US5] Live-verify per quickstart.md's US5 scenario, fresh restart first, pasted
      per-chapter before/after figures.
- [x] T042 [US5] Commit, explicit paths, referencing FR-005/SC-003.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: 5e25ef7, ff6e04e, e3f4be8, dcfdf7a, eef689a.)*
      *(Reconciled by 026 on 2026-10-20: PARTIAL: served-source verified (registry uncertain counts all >=70% below pre-fix), live API not re-checked.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: measured now: segments.json uncertain/total ch01 34/1055, ch02 96/1206, 02.01 3/42, 02.02 27/202, ch03 53/1100.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: build_transcript.py segment_uncertain(); CALIBRATION.md S9; two-sided sample in commit msg (threshold change, not re-transcription).)*

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
      *(Reconciled by 026 on 2026-10-20: PARTIAL: ledger report only; prebuilt crossrefs checked: targets transcript/doc_section/code, no glossary/bookkeeping targets.)* [superseded 2026-10-20 by S6 target-kind tally; task remains PARTIAL, see the S6 note]
      *(S6 (round 1): PARTIAL - NOT ticked. Established: all 692460 prebuilt gen-18 edges target only transcript_segment/doc_section/code (0 kg_* targets; scope 03 = 21360 edges, scope 04 = 280 edges), so there is no scoping regression for chapter 03/04, and the bundle is complete (every one of 34623 pids has 20 edges), so not a derivation-timing artifact. The residual defect is the unfloored min_score=0 tail (see T045b). NOT established: recall/relevance - no relevance labels exist, so the required recall-sized sample cannot be judged. Null-scope sources (518020 edges) are kg_* records, not unmatched. evidence/s6/t044-crossref-target-kind-tally-v2.txt)*

### Tests for User Story 6

- [x] T045 [TDD] [US6] Write a failing test (mirroring the scoping-fix test shipped earlier the same
      day for the sibling code path, per research.md) asserting the crossref candidate population
      for a representative passage excludes bare glossary-term and bookkeeping-row targets — exact
      file confirmed by T044's root-cause finding.
- [x] T045b [TDD] [US6] **Edge case** (spec.md): write a test asserting that a passage with zero
      genuinely related cross-references, after the scoping fix, renders an honest empty state —
      confirm the fix does not re-admit a weak/irrelevant match just to avoid an empty list (FR-007).
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: pkg/crossref/floor_population_test.go:154,191,241.)*
      *(Reconciled by 026 on 2026-10-20: ABSENT / UNMET: no such test; prebuilt crossrefs are exactly 20 per source with min_score 0, so the empty state is unreachable by data. Decision D7 (spec 026): no MMR; use a score floor + honest empty state here.)* [superseded 2026-10-20 by S6 mechanism/tests (floor, empty state); rollout of a floor value still NOT done]
      *(S6 (round 1): mechanism + tests done, ROLLOUT NOT DONE (shipped min_score is still 0; no default changed). pkg/crossref NullFloorSubsets (seeded, nearest-rank, finite-only; 7 mutants killed) + floor_empty_test (determined empty, no weak backfill; mutant killed) + crossrefs-empty-state.spec.ts. Measured on the gen-18 bundle with a source x target null (evidence/s6/t045b-floor-impact-v2.txt). RECOMMENDED DESIGN: per-source-kind floors at q=0.95 (sources emptied 124 of 34623 = 0.4%, edges kept 96.3%; kg_term 0.6301, transcript_segment 0.6808, doc_section 0.7217, code 0.7087) - needs a per-kind MinScore in Derive (not built); interim single floor 0.6391 (q=0.90, 0.7% emptied). A single q=0.95 floor 0.6683 empties 3.5% of sources, 1213/1214 of them kg_term, because kg_term cosines run lower. Precision bound against a null only; recall unmeasured. Operator decides quantile and regeneration. Supersedes the 026 ABSENT note.)*

### Implementation for User Story 6

- [x] T046 [REVIEW] [US6] Fix the scoping gap found in T044 so T045 passes. **Review gate**: per
      plan.md's Review Gates, this touches crossref derivation/scoping code that was already changed
      once the same day — review against that earlier fix, not layered blindly on top of it.
- [x] T047 [US6] Run T045 again; confirm GREEN.
      *(S6: go test ./pkg/crossref ok (incl. floor_population_test, G-XREF-24) (evidence/s6/fix-round-tests.txt).)*
- [ ] T048 [US6] Live-verify per quickstart.md's US6 scenario — a sample large enough for an honest
      recall statement, across chapter 03/04 specifically, fresh restart first, pasted evidence
      (target-kind tally, score ranges, zero-bogus-target confirmation).
- [x] T049 [US6] Commit, explicit paths, referencing FR-006/FR-007/SC-004.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: 22fde1d.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W 22fde1d carryforward.go:56 (6th condition population_key), crossref.go, main.go.)*

**Checkpoint**: US6 independently functional and live-verified.

---

## Phase 9: User Story 7 — Progress screen labels are never truncated into partial words (Priority: P3)

**Goal**: Every progress-screen first-column label renders in full at supported viewport widths
(spec.md FR-008, SC-005).

**Independent Test**: quickstart.md's "US7" scenario.

- [x] T050 [P] [SUBAGENT] [US7] Locate the progress screen's first-column component and inspect its
      current CSS (a fixed width with `overflow: hidden` and no responsive wrapping is the most
      likely shape, per research.md).
- [x] T051 [TDD] [P] [US7] Write a failing test (a rendered-text-content assertion, or a visual
      regression test if this project's suite supports one) asserting the first-column label renders
      as the complete word/phrase at a representative narrow viewport width.
- [x] T052 [US7] Fix the CSS/layout (wrap, responsive width, or truncate-with-full-text-available) so
      T051 passes, across the viewport range named in spec.md's acceptance scenario (typical desktop
      and mobile).
- [x] T053 [US7] Run T051 again; confirm GREEN.
      *(S6: progress-area-label-wrap.spec.ts inside 34/34 SUCCESS (fe-batch1.txt) and the 591-SUCCESS full run (fe-full.txt).)*
- [ ] T054 [US7] Live-verify per quickstart.md's US7 scenario at multiple real viewport widths, fresh
      restart first, pasted evidence/screenshot.
- [x] T055 [US7] Commit, explicit paths, referencing FR-008/SC-005.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: 7f9da22.)*
      *(Reconciled by 026 on 2026-10-20: PARTIAL: served bundle contains `overflow-wrap:anywhere`; no screenshot evidence at several widths.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: progress.component.ts:313 `white-space:normal;overflow-wrap:anywhere`.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: progress-area-label-wrap.spec.ts:126,137.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: progress.component.ts `.wk-gutter-cell .wk-tag`.)*

**Checkpoint**: US7 independently functional and live-verified.

---

## Phase 10: User Story 8 — Chapter 4 content is clear, conclusive, third-person prose (Priority: P3)

**Goal**: Every chapter 4 section is a clear, concluded, third-person statement traceable to the
source conversation (spec.md FR-015, FR-016, SC-009).

**Independent Test**: quickstart.md's "US8" scenario.

**Note**: this story's final acceptance is a human readability/accuracy pass (plan.md's Human
Checkpoint 4), not a fully automatable success criterion — T058's mechanical check is a necessary
but not sufficient gate.

- [x] T056 [P] [SUBAGENT] [US8] Read chapter 4's current section content and its full source
      transcript side by side to identify which specific sections are the clearest instances of
      "thrashy"/first-person fragments, scoping the rewrite precisely (research.md). Confirm the
      existing text-only-chapter section-generation code path (introduced the same day) so the
      rewrite is produced consistently with how other sections are structured, not as a one-off hand
      edit.
- [x] T057 [TDD] [US8] Write a mechanical pre-check test asserting no chapter 4 section's rendered
      content contains a first-person "I " token (a necessary-but-not-sufficient automated check per
      research.md/plan.md's note that "clear" and "concluded" require human judgment).
- [x] T057b [TDD] [US8] **Edge case** (spec.md): write a test asserting that a source span with no
      clear third-person-summarizable conclusion (e.g. small talk) is OMITTED from section content
      entirely, not force-summarized into a misleading statement — confirm against at least one real
      small-talk span identified in T056.
- [x] T058 [US8] Regenerate/rewrite the sections identified in T056, each traceable to its
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
- [x] T062 [US8] Commit, explicit paths, referencing FR-015/FR-016/SC-009.
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: 1a46788, 28cb569, e3f4be8.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: 1a46788 + rewrite_text_chapter_sections.py; reached registry via e3f4be8.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: test_chapter04_registry_omitted_spans_suppressed.py (28cb569), section_rewrites/04.json (4 rewrites, omissions).)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: pipeline/extract/test_chapter04_sections_voice.py; my scan: 0 first-person tokens in chapter-04 knowledge/*.jsonl and pid 01M3SPS... in registry.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: W 1a46788; ledger us8-report.md.)*

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
- [x] T066 Update `specs/016-workshop-live-qa-fixes/checklists/requirements.md` if any finding during
      implementation revealed a spec gap not caught during `/speckit-clarify` (expected: none, but
      checked rather than assumed).
- [ ] T067 **[/speckit-analyze D1]** Update `CONTINUATION.md` at the `workshop` repository root
      describing this batch's 8 fixes (per the constitution's *Comprehensive Documentation*
      principle — a MUST, mechanically enforced by `scripts/continuation-check.sh`), in the SAME
      commit as T065's final live-verification evidence — not a separate, later commit.
      *(Reconciled by 026 on 2026-10-20: RELOCATED: the CONTINUATION entry lives in the UMBRELLA `CONTINUATION.md:669+`, not the workshop root; amend the task path or mirror the note.)*
      *(Reconciled by 026 on 2026-10-20: DONE, evidence: CONTINUATION: 16/16.)*
      *(Reconciled by 026 on 2026-10-20: PARTIAL: final eight-scenario run on one build not pasted; US6 open.)*
      *(Reconciled by 026 on 2026-10-20: PARTIAL: 9/11 gates pass, 2 UNDETERMINED (`verify-answer-question`, `verify-served-correctness-indicator`).)*

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
