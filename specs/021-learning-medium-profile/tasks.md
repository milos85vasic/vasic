# Tasks: Learning-Medium Profile and Best-Method Recommendation

**Input**: Design documents from `specs/021-learning-medium-profile/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/` (4 files), `quickstart.md` (all present)

**Tests**: INCLUDED and test-first. Every implementation task is preceded by a RED task whose oracle is named.
Execution markers map 1:1 onto `/speckit.superspec.execute`'s vocabulary.

**Organization**: grouped by user story. US1 is split into **US1a (pure algorithm — buildable today)** and
**US1b (integration — BLOCKED on spec 013)** so progress is not hostage to another spec.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]** parallel-safe (different files, no same-phase dependency) · **[TDD]** strict RED→GREEN→REFACTOR ·
  **[REVIEW]** independent review (Opus, effort xhigh, verdict file with `finding_layer`) before dependents start ·
  **[SUBAGENT]** safe to delegate · **[HOOK]** touches a file owned by the orchestrator (exact lines stated; the
  stream does not edit the host file) · **[BLOCKED:xxx]** cannot start; reason named · **[OD-n]** waits for an
  operator decision.
- Story labels: `SETUP`, `FOUND`, `US1`–`US5`, `POLISH`.

## Path conventions

Backend `workshop/platform/backend/`; frontend `workshop/platform/frontend/src/app/features/medium/`;
oracle `workshop/pipeline/`; gates `workshop/platform/gates/`; docs `workshop/docs/features/learning-medium/`.
**Content boundary**: nothing from `workshop/chapters/**` or transcripts is quoted into any file; counts and paths only.

---

## Phase 1: Setup

- [ ] T001 [SETUP] Record the baseline: checked-task counts of specs 011/013/015 (`grep -cE '^- \[x\]'` on each
      `tasks.md`), workshop `HEAD`, `GET /api/health` build stamp, `ulimit -u` and thread headroom (§11.4.263 / §12.12).
      Write `specs/021-learning-medium-profile/evidence/setup-baseline.json` and its `sha256`. Expected (2026-10-20):
      013 = 0/52, 015 = 0/46.
- [ ] T002 [P] [SETUP] Confirm the conventions this plan cites exist and the capability does not: via CodeGraph /
      semantic search (not blind grep) confirm `sessionOf`, `writeJSON`, `writeError`, `writeUnavailable` in
      `platform/backend/internal/api/lessons.go` + `api.go`; confirm no `medium`/learning-style symbol under
      `platform/backend` or `platform/frontend/src`; confirm `ExpectedScore` is not yet present (013 unbuilt). Record
      each result with path:line in `research.md` §0.
- [ ] T003 [P] [SETUP] **Research R-1 (§11.4.150, deep multi-angle web research).** Establish, with primary-source
      citations (title, venue, year) written into `research.md` §1: (a) the state of evidence on matching instruction
      to a learner "style"; (b) evidence for/against feedback that reports performance with a format relative to an
      expectation; (c) fairness/feedback-effect risks of showing learners an inferred preference (self-fulfilling
      narrowing); (d) privacy-engineering guidance for learner-analytics profiles. Label HYPOTHESIS → FINDING per
      claim. If (a) or (c) contradicts FR-017 or the advisory-only stance, amend the spec before T016.
- [x] T004 [P] [SETUP] **Research R-2.** Determine, from spec 013's contract/implementation (`contracts/practice-submit.md`
      and, once it exists, `pkg/scoring`), exactly how `flashcard` and `short` answers are graded and what `correct`
      is written for an ungraded outcome (curriculum-kit marks `short` `Graded=false`,
      `submodules/curriculum-kit/pkg/curriculum/assess.go:213-220`). Record in `data-model.md` §1.2 and
      `research.md` §5. **Decision gate:** if an ungraded outcome is logged as `correct=false`, STOP and raise it to
      013's owner — the medium statistics would be biased; the `GradedBy` provenance request in
      `contracts/response-source-interface.md` becomes mandatory.
      **[DONE - evidence: path platform/backend/cmd/workshop-server/wire_medium.go (scoringSource reads scoring.response_log; GradedBy provenance decided from the writers, comment cites T004) / commit 905bf091 (ancestor of main); ticked by 026 Wave 1 on 2026-10-24]**
- [x] T005 [P] [SETUP] **Research R-3.** Check whether `platform/backend/pkg/scoring` exists; if so list the exported
      read methods and indexes and record the exact `ResponsesForSession` addition and any `(session, at)` index
      needed; if not, mark T028–T034 `[BLOCKED:013]` in this file with the date. Never infer 013's API from its
      drafts.
      **[DONE - evidence: platform/backend/pkg/scoring/ (18 files incl. read_responses.go) read by scoringSource in wire_medium.go / commit 905bf091 (ancestor of main); ticked by 026 Wave 1 on 2026-10-24]**
- [ ] T006 [P] [SETUP] **Research R-4 (Source Is Not Served).** On the SERVED frontend bundle (`platform/web`, built
      2026-10-07 per the gap analysis) and on source, confirm whether the practice questions response carries each
      question's `kind` and how the practice component builds its deck; record bundle hash vs. source HEAD. This sets
      how large the T044 `[HOOK]` edit is.
- [x] T007 [SETUP] Verify the Wave-0 hook split exists: `grep -n 'hook:medium' platform/backend/cmd/workshop-server/main.go`
      and the matching one-line hooks in `app.routes.ts` and `core/vocabulary.ts`. **If absent: STOP and request the
      orchestrator; do not edit those files** (architecture plan §2.2). Record result.
      **[DONE - evidence: hook present in a different shape than the task text: platform/backend/cmd/workshop-server/wire_hooks.go field `medium mediumConfig` and `registerMediumRoutes(d)` at line 112; no literal `hook:medium` line exists in main.go (aggregators replaced it, same as 026 T018 note); ticked by 026 Wave 1 on 2026-10-24]**
- [ ] T008 [REVIEW] [SETUP] Independent review of `contracts/privacy-and-failure-scenarios.md`: every FR with a
      privacy or fail-closed consequence maps to a scenario P-n with a named test, oracle and paired mutation;
      reviewer is a different agent than the spec author (§11.4.239: the map exists before code).

**Checkpoint**: research recorded, hooks confirmed (or requested), scenario map accepted. No code yet.

---

## Phase 2: Foundational (blocks every story)

- [x] T009 [TDD] [FOUND] RED then GREEN: `pkg/medium/medium.go` closed `Medium` vocabulary, `Valid`, `IsQuestion`,
      `FromKind`. Test `TestFromKindCoversEveryKind` in `pkg/medium/medium_test.go` — oracle: the literal list
      `mcq, short, flashcard` copied from `pkg/assessment/question.go:51-53` *in the test*, so a future fourth kind
      fails the build rather than silently dropping out of the profile. Run, see FAIL, implement, see PASS.
      EVIDENCE (S16, 2026-10-21): pkg/medium TestFromKindCoversEveryKind; RED=build failure then PASS (evidence/s16/go-tests.txt) (worktree branch s16-021-medium, evidence/s16/).
- [x] T010 [TDD] [FOUND] `pkg/medium/config.go` `Config` + `Validate()` and defaults per
      `contracts/medium-signal-algorithm.md` §1. Test `TestBootRefusesBadThresholds` (P-12) in `config_test.go` —
      oracle: a table of invalid configs, each expecting an error naming the offending key (`NMin=0`, `GapMin<=0`,
      `ZLeaning>=ZPreferred`, `MaxObs<100`, `D<=0`). RED first.
      EVIDENCE (S16, 2026-10-21): TestBootRefusesBadThresholds 15 cases; paired mutant M11 caught (evidence/s16/mutations.txt) (worktree branch s16-021-medium, evidence/s16/).
- [x] T011 [TDD] [FOUND] `pkg/medium/vocab.go`: `SignalState`, `ReasonCode`, `UnavailableCode` constants and
      `DisjointVocabularies()`. Test `TestVocabulariesAreDisjoint` (FR-018, contract §7) in `vocab_test.go` —
      oracle: the three literal lists in `contracts/medium-endpoints.md` §7. RED first.
      EVIDENCE (S16, 2026-10-21): TestVocabulariesAreDisjoint; DEVIATION: contract list has leaning<leaning_by_evidence and preferred<preferred_by_evidence prefix pairs, pinned by a test; prefix rule applied to the 503 codes (worktree branch s16-021-medium, evidence/s16/).
- [x] T012 [P] [SUBAGENT] [FOUND] **Independent oracle.** A DIFFERENT agent than the Go implementer writes
      `pipeline/medium_reference.py` (stdlib only, run with `python3 -I`) implementing
      `contracts/medium-signal-algorithm.md` from the contract text alone, plus
      `platform/backend/pkg/medium/testdata/medium/golden_worked_example.json` (the 8 rows of `data-model.md` §3) and
      `golden_worked_example.expected.json`, and `pipeline/tests/test_medium_reference.py` asserting the
      hand-computed figures to 4 dp (E=1.1658/1.9326, V=0.5797/0.7453, m=0.4586/0.0169, z=1.535). Record the author
      agent id in the task log (Producer ≠ Oracle, §11.4.249).
      EVIDENCE (S16, 2026-10-21): oracle authored by a separate subagent from the contract text only; sha256 in evidence/s16/oracle-sha256.txt; 15 python tests OK. Spec defect: data-model figures se(mcq)=0.1904 and m(flashcard)=0.0169 are not exact (0.1903 / 0.0168) (worktree branch s16-021-medium, evidence/s16/).
- [x] T013 [P] [FOUND] Static gate `platform/gates/verify-medium-no-model.sh` (three-valued: 0 clean / 1 finding /
      2 could-not-determine): fails if `go list -deps ./pkg/medium` contains `net/http`, `digital.vasic.rag`,
      `pkg/answer`, `pkg/entail`, `math/rand`, or if non-test files in `pkg/medium` reference `time.Now`. Paired
      `prove-medium-no-model.sh` injects each forbidden import into a throwaway copy and requires exit 1 for every
      one (§1.1). RED: write the prove script first and watch the gate not exist. Registry TSV row handed to the
      orchestrator.
      EVIDENCE (S16, 2026-10-21): verify/prove-medium-no-model.sh: 14/14 prove cases; registry TSV row handed to orchestrator (worktree branch s16-021-medium, evidence/s16/).
- [x] T014 [FOUND] `pkg/medium/source.go`: `ResponseSource`, `ResponseRow`, `QuestionKindLookup` per
      `contracts/response-source-interface.md`, plus test doubles in `source_fake_test.go` (a recording spy for P-4,
      a foreign-session injector for P-9, a failing source for P-3).
      EVIDENCE (S16, 2026-10-21): source.go + fakes. AMENDMENT: ResponseRow gains Session (needed for P-9) (worktree branch s16-021-medium, evidence/s16/).
- [ ] T015 [REVIEW] [FOUND] Independent review of T009–T014 against the contracts; confirm T013's prove script
      really fails per forbidden import.

**Checkpoint**: vocabulary, config, oracle, static gate, source interface exist. Stories may begin.

---

## Phase 3: User Story 1 — Which question formats work for me, with the evidence (P1) 🎯 MVP

### US1a — pure algorithm (UNBLOCKED)

#### Tests first ⚠️ (all `[TDD]`, all RED before T022)

- [x] T016 [TDD] [P] [SUBAGENT] [US1] `TestGoldenWorkedExample` in `pkg/medium/signal_test.go`: load the golden
      fixture, expect the exact states and figures of `data-model.md` §3 (mcq `preferred`, z = 1.535 with
      `NMin=3`), and the counter-example (`NMin=5` ⇒ both `insufficient_evidence`, no recommendation). Oracle:
      `golden_worked_example.expected.json` from T012. FAIL (no aggregator yet).
      EVIDENCE (S16, 2026-10-21): TestGoldenWorkedExample + n_min=5 counter-example vs oracle to 1e-9 (worktree branch s16-021-medium, evidence/s16/).
- [x] T017 [TDD] [P] [US1] `TestAggregateProperties` in `evidence_test.go`: generated fixtures (fixed seed in test
      code) assert `NTotal ≥ NGraded ≥ Observed`, refs sorted and unique, ungraded rows never in `Expected`/`Variance`,
      `NGraded==0 ⇒ MeanResid==StdError==0`. Oracle: the invariants in `data-model.md` §4.
      EVIDENCE (S16, 2026-10-21): TestAggregateProperties (40 seeds x scopes) (worktree branch s16-021-medium, evidence/s16/).
- [x] T018 [TDD] [P] [US1] `TestClassifyStates` in `signal_test.go`: one case per arrow of the state machine
      (contract §3) — `not_measurable` (short only), `insufficient_evidence` (n<NMin; <2 eligible), tie ⇒
      `no_clear_preference`, `g<GapMin` with large z ⇒ `no_clear_preference`, `leaning` band, `preferred`, zero-
      variance comparison ⇒ `z=0`, tie-break by medium name. Oracle: the contract table.
      EVIDENCE (S16, 2026-10-21): TestClassifyStates + TestClassifyTieBreakIsIndependentOfInputOrder (found by mutant M02 surviving) (worktree branch s16-021-medium, evidence/s16/).
- [x] T019 [TDD] [P] [US1] `TestDeterminism` (P-10) in `determinism_test.go`: the golden and a 500-row generated
      fixture in 100 shuffled orders × 3 repeats ⇒ byte-identical JSON; a second test fails if any map is iterated
      into output (sorted-key assertion). Oracle: the first run's bytes. Paired mutation recorded in T025.
      EVIDENCE (S16, 2026-10-21): TestDeterminism 100 shuffles x 3 x 2 fixtures; found+fixed an order-dependent duplicate rule; no-maps type walk (worktree branch s16-021-medium, evidence/s16/).
- [x] T020 [TDD] [P] [US1] `TestNonFiniteRowIsDropped` (P-11) and `TestUnmappedQuestionCounted`: NaN/Inf difficulty
      or ability and unknown question ids are dropped and counted in `unmapped`; aggregate stays finite; oracle: the
      reference computed (by T012's script) on the fixture without those rows.
      EVIDENCE (S16, 2026-10-21): TestNonFiniteRowIsDropped / TestUnmappedQuestionCounted (worktree branch s16-021-medium, evidence/s16/).
- [x] T021 [TDD] [P] [US1] `TestReaderAssertsSession` (P-9) and `TestWindowRelativeToData`: a row whose session
      differs from the caller makes the reader return `session_mismatch`; `WindowDays` anchors on the newest row's
      `At`, never `time.Now`. Oracle: injected foreign-row source from T014.
      EVIDENCE (S16, 2026-10-21): TestReaderAssertsSession / TestWindowRelativeToData (worktree branch s16-021-medium, evidence/s16/).

#### Implementation

- [x] T022 [US1] GREEN T016/T017/T020: `pkg/medium/evidence.go` — `Observe(rows, lookup, cfg)` → `[]Observation`
      (expected from the **stored** ability/difficulty, imported `D`), `Aggregate(obs, scope)` → `MediumEvidence`
      (sorted summation order per contract §5).
      EVIDENCE (S16, 2026-10-21): evidence.go (worktree branch s16-021-medium, evidence/s16/).
- [x] T023 [US1] GREEN T018/T019/T021: `pkg/medium/signal.go` — `Classify(evidence, cfg)` per contract §2 steps 5–8
      and the reader session assertion.
      EVIDENCE (S16, 2026-10-21): signal.go (worktree branch s16-021-medium, evidence/s16/).
- [x] T024 [US1] `pkg/medium/explain.go`: payload struct + fixed-template `text` (no model), 4 dp / 1 dp rounding at
      serialisation only. Golden text test `TestExplainTextIsStable` (oracle: expected string in the fixture).
      EVIDENCE (S16, 2026-10-21): explain.go; contract text sentence reproduced; TestExplainTextIsStable (worktree branch s16-021-medium, evidence/s16/).
- [ ] T025 [REVIEW] [US1] Independent review of the pure algorithm against the contract and the reference output, and
      a **mutation sanity pass**: flip `>=` to `>` on `GapMin`, drop the tie-break, iterate a map into output,
      treat ungraded as incorrect — each MUST make a named test fail; record the four results in the verdict file.
- [x] T026 [TDD] [SUBAGENT] [US1] `pkg/medium/sim_test.go` (test-only `math/rand`, fixed seed): the null and effect
      conditions of `research.md` §3 at 10/20/30/60 graded answers per medium, 1000 learners each; writes
      `specs/021-learning-medium-profile/evidence/simulation/sim-results.json` with the confusion matrix and the
      `z_preferred` curve. Test asserts SC-009 bounds (null ≥ 95% non-preference; effect ≥ 80% at 30/medium) — RED
      if the defaults miss, which is information, not a failure to hide.
      EVIDENCE (S16, 2026-10-21): sim_test.go seeded PCG; RED at the PROPOSED defaults (null non-preference 0.643 < 0.95) (worktree branch s16-021-medium, evidence/s16/).
- [x] T027 [US1] Run T026, paste the measured rates into `research.md` §3, and either confirm the proposed
      thresholds or retune them **in the contract and the config defaults together with the new evidence**. Raise
      **OD-1** to the operator with the numbers. No threshold is changed without a re-run.
      EVIDENCE (S16, 2026-10-21): thresholds RETUNED to z 1.96/2.58 in contract + config; measured table in research.md 3.1; null bound met (0.951), power bound at 30/format MISSED (0.377) - structurally infeasible together; OD-1 OPEN (worktree branch s16-021-medium, evidence/s16/).

**Checkpoint A** — pure algorithm complete, deterministic, oracle-verified, thresholds measured. Shippable as a
library; nothing user-visible yet.

### US1b — integration (BLOCKED:013 until spec 013 US1 checkpoint)

- [x] T028 [US1] [BLOCKED:013] `cmd/workshop-server/wire_medium.go`: `scoringSource` adapter implementing
      `ResponseSource` over `pkg/scoring` (session predicate **in SQL**), question-kind lookup from the assessment
      bank, `GradedBy` provenance per T004; request/land `pkg/scoring/read_responses.go` through 013's owner.
      TDD against a **real** temp-dir SQLite store populated through 013's own `RecordResponse` (no mock of the
      store): adapter-level isolation test (P-1) first, oracle = the seeded entry ids.
      **[DONE - evidence: platform/backend/cmd/workshop-server/wire_medium.go scoringSource (line 156) + wire_medium_scoring_test.go / commit 905bf091 (ancestor of main); ticked by 026 Wave 1 on 2026-10-24]**
- [x] T029 [TDD] [US1] [BLOCKED:013] `internal/api/medium_test.go` RED: `GET /api/profile/medium` golden JSON
      (`contracts/medium-endpoints.md` §1); empty ⇒ 200 + `empty:true` (FR-015); store error ⇒ 503
      `scoring_store_unreadable` (P-3); nil source ⇒ `scoring_store_absent`; cap ⇒ `truncated:true` (FR-020);
      admin gets only own data (P-2); isolation both directions (P-1); `Cache-Control: no-store`.
      **[DONE - evidence: platform/backend/internal/api/medium_test.go exists on main; ticked by 026 Wave 1 on 2026-10-24]**
- [x] T030 [US1] [BLOCKED:013] `internal/api/medium.go` GET handler + `registerMedium(mux, deps)` in
      `wire_medium.go`; boot capability-matrix row; hand the one `// hook:medium` line to the orchestrator.
      **[DONE - evidence: platform/backend/internal/api/medium.go (`GET /api/profile/medium`, line 113) + registerMediumRoutes in wire_medium.go; ticked by 026 Wave 1 on 2026-10-24]**
- [ ] T031 [P] [US1] [BLOCKED:013] `platform/gates/verify-medium-isolation.sh` + `prove-medium-isolation.sh`: two
      learners × both directions × authenticated and `X-Session`, N ≥ 200 requests; prove script mutates a handler
      copy to ignore the session and requires the gate to FAIL (SC-003).
- [x] T032 [P] [TDD] [US1] `features/medium/medium.service.ts`, `medium-profile.component.ts`, `medium.vocabulary.ts`
      with Karma specs written first against the endpoint goldens (usable now with mocks): states, evidence counts,
      empty/unavailable states distinct (never "unavailable" rendered as "no data"), hand-rolled SVG residual bars,
      keyboard-accessible "Why?" disclosure, wording per FR-017.
      EVIDENCE (S16, 2026-10-21): features/medium service+profile+vocabulary, Karma 52/52, features/medium stmt cov 93.9% (worktree branch s16-021-medium, evidence/s16/).
- [x] T033 [US1] [HOOK] `features/medium/medium.routes.ts` (lazy child `profile/medium`). Hand the orchestrator the
      exact append line for `app.routes.ts` and the registration line for `core/vocabulary.ts` (and request that
      `prove-ui-vocabulary-mutation.sh` is re-run after it registers).
      **[DONE - evidence: platform/frontend/src/app/features/medium/medium.routes.ts + app.routes.medium.spec.ts / commit 905bf091 (route+nav mounted; ancestor of main); ticked by 026 Wave 1 on 2026-10-24]**
- [ ] T034 [REVIEW] [US1] Independent review of the integration slice and a live isolation run on an isolated
      throwaway server (architecture plan §2.2 item 6): build the stream's server to the scratch dir, run with a
      scratch `-state` and a copy of the registry, then `verify-medium-isolation.sh --base http://127.0.0.1:<port>`.

**Checkpoint B (US1 MVP)** — quickstart Scenarios 0, 1, 2, 5 pass on the isolated server.

---

## Phase 4: User Story 2 — Explainable recommendation, override, off, reset (P1)

- [x] T035 [TDD] [P] [US2] `pkg/medium/store_test.go` RED: preference CRUD; the `CHECK ((mode='pinned') =
      (medium IS NOT NULL))` constraint; idempotent PUT; `DeleteSession` removes only the caller's rows (P-8, oracle =
      per-session row counts before/after); store-open failure ⇒ `medium_store_unreadable`.
      EVIDENCE (S16, 2026-10-21): mediumstore tests (worktree branch s16-021-medium, evidence/s16/).
- [x] T036 [US2] `pkg/medium/store.go` — `Open(dir)` on `medium.db` (authstore idiom, `SetMaxOpenConns(1)`), DDL from
      `data-model.md` §2, `Get/Put/DeleteSession`. GREEN T035.
      EVIDENCE (S16, 2026-10-21): mediumstore.Open etc, 87.8% cov (worktree branch s16-021-medium, evidence/s16/).
- [x] T037 [TDD] [P] [US2] `recommend_test.go` RED: scope fallback `area → overall` labelled `scope_fallback_overall`;
      `pinned` wins and still attaches evidence; `off` ⇒ `off_by_learner` with a spy source recording **zero** reads
      (P-4); property `TestRecommendationNeverFromInsufficient` over generated fixtures (SC-004); every non-empty
      recommendation has ≥ 1 evidence ref and the thresholds applied.
      EVIDENCE (S16, 2026-10-21): recommend_test (fallback, pinned, off, SC-004 property) (worktree branch s16-021-medium, evidence/s16/).
- [x] T038 [US2] `pkg/medium/recommend.go` per contract §2 steps 8–10. GREEN T037.
      EVIDENCE (S16, 2026-10-21): recommend.go (worktree branch s16-021-medium, evidence/s16/).
- [x] T039 [TDD] [US2] `internal/api/medium_test.go` additions RED: `GET .../recommendation?area=` (unknown parameter
      ⇒ 400 `unknown_parameter`, unknown area ⇒ 404), `PUT .../preference` (400 for unknown mode, pinned-without-
      medium, medium-with-auto, format medium ⇒ `unsupported_pin_medium`), `DELETE /api/profile/medium` idempotent and
      reports `response_log: untouched`; override honoured on the very next call across all routes (SC-005 matrix).
      EVIDENCE (S16, 2026-10-21): internal/api/medium_test.go RED(build)->GREEN against a spy source; real-013 parts remain in T029/T030/T040 (worktree branch s16-021-medium, evidence/s16/).
- [x] T040 [US2] [BLOCKED:013] Handlers in `internal/api/medium.go` for the three routes. GREEN T039.
      **[DONE - evidence: platform/backend/internal/api/medium.go handlers for preference/consent/events routes (lines 116-120); ticked by 026 Wave 1 on 2026-10-24]**
- [x] T041 [P] [TDD] [US2] Frontend: `medium-recommendation.component.ts` (card with the plain-language reason and
      evidence count, "no recommendation yet — N more graded answers needed"), preference controls (auto / pin /
      off), "Reset my data" with an inline confirmation (no `window.confirm`), Karma specs first.
      EVIDENCE (S16, 2026-10-21): recommendation card + controls + inline reset confirm, Karma specs (worktree branch s16-021-medium, evidence/s16/).
- [ ] T042 [REVIEW] [US2] Independent review; re-run P-1…P-9 and the SC-005 matrix on the isolated server.

**Checkpoint (US2)** — quickstart Scenarios 2–3 pass.

---

## Phase 5: User Story 3 — Hint where I study, selector on the practice page (P2)

- [ ] T043 [TDD] [P] [US3] `platform/frontend/e2e/medium.spec.ts` RED (Playwright, `WORKSHOP_BASE_URL` of the
      isolated server): seeded learner sees the hint with a working "why" link; unseeded sees nothing (no empty
      placeholder); practice selector filters to one kind; zero-of-kind shows the explicit empty message; dismissal is
      session-only.
- [ ] T044 [US3] [HOOK] `features/medium/medium-hint.component.ts` (standalone, self-fetching) and a
      `medium-kind-filter.component.ts`; the **only** edits to existing files are a ≤ 10-line slot in the area page
      component and a ≤ 10-line selector in the practice component, with the exact lines stated in the hand-off.
      **Coordinate with the 013-US1/016-US1 practice-path stream** (architecture plan §2.2 item 5: semantic-conflict
      pair) — the filter is purely client-side over the already-fetched deck; no submit-path change.
- [ ] T045 [REVIEW] [US3] Independent review; Playwright green on chromium; screenshot evidence saved under
      `evidence/ui/` with sha256.

---

## Phase 6: User Story 4 — Opt-in format-engagement signals (P3) **[OD-3]**

*Do not start until the operator answers OD-3 (ship at all? default OFF).*

- [x] T046 [TDD] [OD-3] [US4] RED: P-5 (no consent ⇒ 403, 0 rows), P-6 (extra field ⇒ 400, 0 rows), P-7 (20 retries
      incl. concurrent ⇒ exactly 1 row, oracle `SELECT COUNT(*)`), body > 1 KiB ⇒ 413, rate limit ⇒ 429, reset scope
      (P-8 extended), `activity` endpoint never alters any performance state.
      EVIDENCE (S16, 2026-10-21): P-5/P-6/P-7 + 413 + 429 + activity independence tests (worktree branch s16-021-medium, evidence/s16/).
- [x] T047 [US4] [OD-3] Consent + event handlers using `DisallowUnknownFields`, `UNIQUE(session, idem_key)`, closed
      `duration_bucket`, per-session rate limit; tables already created by T036's migration. GREEN T046.
      EVIDENCE (S16, 2026-10-21): handlers + store (flag -medium-engagement, default OFF) (worktree branch s16-021-medium, evidence/s16/).
- [x] T048 [US4] [OD-3] Frontend: consent toggle (default off) with plain-language disclosure; fire-and-forget
      emitter service that never blocks navigation and sends nothing before consent; activity panel clearly labelled
      "time spent, not results". Karma + Playwright first.
      EVIDENCE (S16, 2026-10-21): consent toggle + emitter, Karma; e2e not run (worktree branch s16-021-medium, evidence/s16/).
- [ ] T048a [US5] [BLOCKED:013] [OD-2] **Server-side routing bias (FR-011).** Waits for (a) 013 `ServeNext` options
      seam and (b) operator decision OD-2. No implementation tasks; revisit the spec with the owner of 013's store.
      *(OBSOLETE, left unticked, annotated by 026 Wave 1 on 2026-10-24: `progress.yml` line 14 records `T048a (OD-2 = no)` and `spec.md` line 328 gives OD-2 default no; no dated ratification of OD-2 was located, and the [BLOCKED:013] label is stale because `pkg/scoring` is on main. Revisit only if OD-2 changes to yes.)*

---

## Phase 7: Polish and cross-cutting

- [ ] T049 [US1] [P] [POLISH] **Operator-visible acceptance (SC-007).** `workshop/scripts/seed-medium-demo.sh`
      (deterministic; submits real answers through the public API for learners `demo-medium-a/b/c` — covers
      `preferred`, `no_clear_preference`, `insufficient_evidence`; never edits a database directly; password only from
      `WORKSHOP_TEST_SEED_PASSWORD`). Produce a one-page walkthrough with screenshots of Scenario 1–4 and a pass/fail
      checklist the operator signs; saved with sha256 under `evidence/ui/`.
- [ ] T050 [POLISH] UI copy and accessibility review (FR-017): no label of the person anywhere; contrast, focus order,
      screen-reader text for states; an automated scan of the vocabulary file for forbidden terms
      ("visual learner", "learning style type", …) as a unit test with a paired mutation.
- [ ] T051 [P] [POLISH] Claim-vs-reality ledger rows (§11.4.266): one row per advertised capability ("explainable",
      "deterministic", "private to the learner", "no model") each with a passing challenge command; capability-matrix
      row doc. Run the ledger verifier, paste output.
- [ ] T052 [POLISH] **LIVE verification (machine evidence, §11.4.262).** `workshop/scripts/verify-medium-live.sh`
      (three-valued): against the running stack (orchestrator-run after merge; build stamp recorded), authenticates
      with the repo helper, creates two throwaway learners, submits a scripted answer set through the real endpoints,
      then asserts via HTTP: signals match the golden expectation, isolation both ways, override, reset. Writes
      `specs/021-learning-medium-profile/evidence/live/result.json` (verdict, build_id, source_dirty, per-check
      results with timings) and `MANIFEST.sha256` over every file in `evidence/live/`. Also records p95 latency of the
      GET at the default cap (target < 50 ms; a measurement, not a promise). `sha256sum -c` must pass.
- [x] T053 [P] [POLISH] User manual `workshop/docs/features/learning-medium/manual.md` (§11.4.257): what the page
      shows, every state, what "expected" means in plain words, privacy, limits (what it cannot know). Link from the
      README feature index via the orchestrator.
      EVIDENCE (S16, 2026-10-21): docs/features/learning-medium/manual.md (worktree branch s16-021-medium, evidence/s16/).
- [x] T054 [P] [POLISH] Task guides: `guide-read-my-profile.md`, `guide-override-or-turn-off.md`,
      `guide-reset-my-data.md`, `guide-practice-by-format.md`, plus operator guide `guide-operator-thresholds.md`
      (how OD-1 was decided; how to change thresholds safely; re-running the simulation).
      EVIDENCE (S16, 2026-10-21): 5 guides (worktree branch s16-021-medium, evidence/s16/).
- [x] T055 [P] [POLISH] FAQ `faq.md`: "Why does it say not enough evidence?", "Is this a learning-style test?",
      "Who can see this?", "Can I delete it?", "Why is short answer not measurable?", "Does it use AI?" — each
      answer cites the FR it rests on.
      EVIDENCE (S16, 2026-10-21): faq.md (worktree branch s16-021-medium, evidence/s16/).
- [x] T056 [P] [POLISH] Diagram class 1 — **architecture** (Mermaid in `diagrams.md`, embedded in the manual):
      browser → API → `pkg/medium` → `ResponseSource` adapter → 013 store; `medium.db` side store. Truthful to the code.
      EVIDENCE (S16, 2026-10-21): diagrams.md (architecture) (worktree branch s16-021-medium, evidence/s16/).
- [x] T057 [P] [POLISH] Diagram class 2 — **data flow**: response → log → observation → evidence → signal →
      recommendation → UI, with the privacy boundary and what is persisted marked.
      EVIDENCE (S16, 2026-10-21): diagrams.md (data flow) (worktree branch s16-021-medium, evidence/s16/).
- [x] T058 [P] [POLISH] Diagram class 3 — **state machine**: per-medium signal states (contract §3) including
      `off_by_learner`.
      EVIDENCE (S16, 2026-10-21): diagrams.md (state machine) (worktree branch s16-021-medium, evidence/s16/).
- [x] T059 [P] [POLISH] Diagram class 4 — **sequence**: learner opens `/profile/medium` (auth, source read, classify,
      respond) and the 503 path.
      EVIDENCE (S16, 2026-10-21): diagrams.md (sequence); sources only, no export built (worktree branch s16-021-medium, evidence/s16/).
- [ ] T060 [POLISH] Exports: run the repository export build for the new docs (`scripts/build-exports.sh`; check its
      usage first — UNCONFIRMED arguments) so each doc has `.html/.pdf/.docx/.sections.json`; mermaid rendered, no raw
      source visible.
- [ ] T061 [REVIEW] [POLISH] Independent export validation (§11.4.168): a validator agent that did not generate the
      exports checks CONTENT, TEXT and full VISUAL layers (open the PDF; OCR is installed), verdict file saved.
- [ ] T062 [REVIEW] [POLISH] Whole-feature independent review (Opus, xhigh): every FR/SC to evidence; every P-n
      scenario run; mutation proofs re-run; content-boundary scan of the spec directory; verdict with
      `finding_layer` for each finding.
- [ ] T063 [POLISH] Full-suite retest on a clean baseline (§11.4.40, orchestrator), `verify-claim-ledger`, the
      zero-findings sweep if present (UNCONFIRMED whether `scripts/audit/zero_findings_sweep.sh` exists), and record
      remaining TRACKED findings.
- [ ] T064 [POLISH] Hand-off: write `specs/021-learning-medium-profile/progress.yml`, list the orchestrator-owned
      hook lines still pending, the gitlink bump note (workshop + `helix-deps.yaml` ref in one change), and the open
      operator decisions OD-1…OD-5 with the evidence attached to each.

---

## Dependencies & Execution Order

- Setup → Foundational → US1a → (US1b ‖ US2 pure parts) → US2 integration → US3 → US4 (OD-3) → Polish.
- **US1a, US2 pure parts (T035–T038), US2/US1 frontend with mocks (T032, T041) can all proceed before spec 013
  exists.** T028–T031, T034, T040 and every live scenario wait for 013's US1 checkpoint.
- T012 (oracle) must be authored by a different agent than T022–T024; T013's prove script must be written before
  its gate is accepted.
- T044 serialises with the 013/016 practice-path streams.
- T052 needs the orchestrator (live stack restart is orchestrator-only); T062 needs T052.

### Parallel opportunities

T003–T006; T009–T011 ‖ T012 ‖ T013; T016–T021; T026 ‖ T022–T025; T032 ‖ T041 ‖ backend work; T053–T059.

### MVP strategy

1. Setup + Foundational. 2. US1a to Checkpoint A (pure algorithm + measured thresholds → OD-1).
3. When 013 US1 lands: US1b to Checkpoint B, then US2. **Stop and validate** with quickstart Scenarios 0–3, 5.
4. US3 for context-of-use value; US4/US5 only on operator decisions.

### Subagent dispatch notes

Independent streams: T012 (oracle), T013 (gate), T016–T021 (six test files), T026 (simulator), T032/T041
(frontend). Reviewers (T008, T015, T025, T034, T042, T045, T061, T062) are always distinct agents from the
producers of the work they review and run on Opus at xhigh effort (model + effort stamped in each verdict).
Before fan-out: record `ulimit -u` / live-thread headroom and `free -m`; stage explicit paths only (no `git add .`);
run the mutation-marker grep before any commit (§11.4.84).
