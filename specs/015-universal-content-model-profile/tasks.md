---
description: "Task breakdown for the universal content model (position-anchored citations) and learner profile page"
---

# Tasks: Universal Content Model (Position-Anchored Citations) and Learner Profile Page

**Input**: [spec.md](spec.md) · [plan.md](plan.md) · [data-model.md](data-model.md) ·
[contracts/location-anchor.md](contracts/location-anchor.md) ·
[contracts/profile-endpoints.md](contracts/profile-endpoints.md) ·
[quickstart.md](quickstart.md)

**Tests**: spec.md's Success Criteria are verification-bearing (SC-002's
"verified by re-running the existing validator suite", SC-004/SC-007's
explicit pagination/data-source proofs), so test tasks are included
throughout, not optional here.

## Task Format

```
[ID] [P] [TDD] [REVIEW] [SUBAGENT] [Story] Description with file path
```

`[P]` parallelizable (different files, no dependency) · `[TDD]` RED-GREEN-REFACTOR,
write the failing test before the implementation · `[REVIEW]` human/operator gate
before the work is considered accepted · `[SUBAGENT]` delegable to a subagent
without losing context the coordinator must keep.

## Global constraints (from plan.md — every task below inherits these)

- Phase A work lands inside `submodules/curriculum-kit`, which stays
  **project-not-aware**: no `workshop`-shaped vocabulary in `LocationAnchor`
  or its validator messages, matching `VideoAnchor`'s existing discipline.
- Zero new persisted write-side state anywhere in this feature (FR-013).
  Every Phase B handler reads `learning-progress.json` /
  `progress.json` through the existing `pkg/learning.SessionStore` /
  `internal/api.ProgressStore` — no new store, no new file.
- `CK013`'s existing finding and message text MUST NOT change, in wording or
  behavior (FR-003/SC-002) — this is load-bearing enough to get its own gate
  task (T014) rather than being assumed as a side effect of adding new rules.
- No new frontend charting dependency (FR-017): hand-rolled inline SVG only,
  unless a separately recorded decision supersedes the default.
- `account_age` is `null` on the wire for every caller until
  `pkg/authstore.User` gains a `CreatedAt` field and the two existing
  `SELECT`s (`UserByUsername`/`UserByTokenHash`) are extended to read it —
  **this is a small, in-scope, read-side addition, corrected from an
  earlier "out of scope" reading of FR-013**: the `auth_user` table's
  `created_at` column already exists and is already populated on every
  insert (`authstore.go:47,159-166`); only the Go struct field and the two
  `SELECT`s are missing. FR-013 forbids new **persisted write-side** state,
  not a read of state already persisted. See T023a below and
  `data-model.md`'s "Honest gap" note. Once T023a lands, `account_age`
  stays `null` only for an anonymous, `X-Session`-only caller with no
  account row at all.

## Path conventions

Repository-relative from the umbrella root. `submodules/curriculum-kit/` is
the PUBLIC, already-adopted reusable library (an independent git repository
mounted as a gitlink — **not** part of `workshop`'s own tree). `workshop/` is
the PRIVATE platform module.

---

## Phase 1: Setup / Foundational

**None beyond what `curriculum-kit` and the workshop platform already have.**
This feature extends existing files in both — `pkg/curriculum/model.go`,
`pkg/curriculum/validate.go`, `pkg/learning/wire.go`, and a new
`internal/api/profile.go` that reuses the existing `LearningDeps`-shaped
dependency wiring every other route already threads through (plan.md's
Structure Decision). There is no shared scaffolding to stand up first; Phase
A and Phase B tasks begin directly against the current tree.

---

## Phase A: User Story 1 — Location-anchored citations in `curriculum-kit` (Priority: P1) 🎯 MVP

**Goal**: A `document`-kind Material can cite a page/section location,
structurally parallel to how a `video`-kind Material already cites a time
range, with the existing `CK013` video-only-rejection guarantee provably
unchanged.

**Independent Test**: `quickstart.md` Steps 1–6 — author/load a
`document`-kind Material with a populated `LocationAnchor` through the
extended validator; confirm it resolves to an existing `doc_section` passage
and is served through the existing `GET /api/areas/{area}/materials` family
with no new endpoint or second catalog loader.

> **SUBMODULE NOTICE — read before dispatching any task in this phase.**
> Every task below that touches `submodules/curriculum-kit/pkg/curriculum/*`
> lands inside an **ADOPTED SUBMODULE** — an independent repository
> (`vasic-digital/curriculum-kit`) mounted as a gitlink into this umbrella,
> not a directory inside `workshop`'s own tree. It has its own governance,
> its own commit history, and its own release process. Changes here cannot
> be folded into a `workshop`-scoped commit the way a `workshop/platform/**`
> edit can; each lands as **its own commit (and, if that submodule's
> convention requires it, its own PR) inside the `curriculum-kit` repository
> itself**, then the umbrella's `helix-deps.yaml` `ref` and the gitlink SHA
> are bumped together in a separate umbrella-side change — the same two-step
> shape this umbrella's own carrier already documents for every owned
> submodule bump (`CLAUDE.md`'s "Owned submodules" section), and the same
> flagging spec 012's own task breakdown is expected to give
> `submodules/passage` for the identical reason: a submodule-touching task
> is not "just another file in this checkout."
>
> Tasks T002–T016 are marked `[SUBMODULE]` inline for this reason. Do NOT
> commit them directly against the umbrella's own history as if they were
> `workshop/` files.

### Baseline (load-bearing — capture before any change)

- [ ] **T001 [TDD] [US1]** Capture today's `CK013` behaviour as a byte-for-byte
  baseline, per `quickstart.md` Step 1, **before** any other task in this
  phase touches `validate.go` or `model.go`:

  ```bash
  cd submodules/curriculum-kit
  go test ./pkg/curriculum/... -v > /tmp/ck013-before.txt
  bash scripts/verify-curriculum.sh
  ```

  **Note: `-run TestValidate` (the command an earlier draft of this task
  used) is WRONG and must not be used — there is no `TestValidate` function
  in `validate_test.go`.** `-run` matches substrings of TEST names as a
  regexp, and `TestValidate` happens to match one unrelated function
  (`TestValidateDoesNotRequireALessonBody`) while matching NONE of the
  subtests of `TestEachRuleCatchesItsOwnDefect`, which is the test that
  actually exercises `CK013`/`CodeVideoOnNonVideo` (subtest name `"video
  anchor on a diagram"`, verified this session against
  `submodules/curriculum-kit/pkg/curriculum/validate_test.go`). The command
  above drops the `-run` filter entirely and captures the package's full
  `-v` output instead — verified this session to actually contain
  `TestEachRuleCatchesItsOwnDefect/video_anchor_on_a_diagram`, and safer
  against a future rename of that subtest than re-guessing a new `-run`
  pattern would be.

  Save `/tmp/ck013-before.txt` and today's exit code/counts — T014 diffs
  against this file. Without this baseline, "zero regression" (FR-003/SC-002)
  is an assertion, not a demonstration.

### `LocationAnchor` type and `Material` extension

- [ ] **T002 [US1] [SUBMODULE]** Add the `LocationAnchor` type to
  `submodules/curriculum-kit/pkg/curriculum/model.go`, field-for-field
  parallel to `VideoAnchor` per `data-model.md`'s definition
  (`SectionID ID`, `Locator string`, `PassageAnchor string`) — no
  `Start()`/`End()`/`Length()` helpers (no time dimension to convert).

- [ ] **T003 [US1] [SUBMODULE]** Add `Material.Location *LocationAnchor
  json:"location,omitempty"` alongside the existing `Video *VideoAnchor`
  field. `MaterialKind` itself is **unchanged** — no new kind (FR-005).

- [ ] **T004 [P] [US1] [SUBMODULE]** Add `Options.KnownSections
  map[ID]bool` to `validate.go`, parallel to the existing `KnownChapters`
  field (`nil` → every location Material produces `CK901`, never a silent
  pass).

### Validator rules (`pkg/curriculum/validate.go`) — TDD, one rule per pair

- [ ] **T005 [TDD] [US1] [SUBMODULE]** Write a failing test for `CK028`
  `CodeDocumentNoLocation` (mirrors `CK010` `CodeVideoNoRange`): a
  `document`-kind Material with a nil `Location`, or a `Location` whose
  `SectionID`/`Locator`/`PassageAnchor` is empty, produces this finding.
  Closes spec.md Edge Case 2 ("no citation at all").

- [ ] **T006 [US1] [SUBMODULE]** Implement `CK028` in `material()`. Run T005
  to confirm PASS.

- [ ] **T007 [TDD] [US1] [SUBMODULE]** Write a failing test for `CK029`
  `CodeLocationOnNonDocument` (mirrors `CK013` `CodeVideoOnNonVideo`): a
  Material of any kind other than `document` carrying a non-nil `Location`
  produces this finding.

- [ ] **T008 [US1] [SUBMODULE]** Implement `CK029`. Run T007 to confirm PASS.

- [ ] **T009 [TDD] [US1] [SUBMODULE]** Write a failing test for `CK030`
  `CodeDualAnchor` (new rule, FR-004 / spec.md Edge Case 3): a Material
  carrying **both** a non-nil `Video` and a non-nil `Location` at once,
  regardless of `Kind`, is rejected — message text per
  `contracts/location-anchor.md` Guarantee 4: `material of kind "<kind>"
  carries both a video anchor and a location anchor — a citation mechanism
  must be unambiguous`.

- [ ] **T010 [US1] [SUBMODULE]** Implement `CK030`. Run T009 to confirm PASS.

- [ ] **T011 [TDD] [US1] [SUBMODULE]** Write a failing test for `CK031`
  `CodeUnknownSection` (mirrors `CK024` `CodeUnknownChapter`): a
  `Location.SectionID` not present in a supplied non-nil
  `Options.KnownSections` produces this finding.

- [ ] **T012 [US1] [SUBMODULE]** Implement `CK031`. Run T011 to confirm PASS.

- [ ] **T013 [TDD] [US1] [SUBMODULE]** Write a test for `CK901`
  `CodeSectionsUnresolved` (mirrors `CK900` `CodeChaptersUnresolved`,
  **undetermined**, not a finding): no `Options.KnownSections` map supplied
  at all → every location Material reports this three-valued undetermined
  row, never a silent pass. Implement in the same pass (this mirrors an
  existing three-valued pattern rather than introducing new branching logic,
  so RED/GREEN collapse into one task here, unlike T005–T012).

### The no-regression gate (load-bearing — do not skip or fold into another task)

- [ ] **T014 [TDD] [REVIEW] [US1] [SUBMODULE]** **The `CK013` regression
  gate.** Re-run the exact command from T001 (no `-run` filter — see T001's
  note on why `-run TestValidate` is wrong) against the now-extended
  validator and diff byte-for-byte against the saved baseline:

  ```bash
  cd submodules/curriculum-kit
  go test ./pkg/curriculum/... -v > /tmp/ck013-after.txt
  diff /tmp/ck013-before.txt /tmp/ck013-after.txt
  ```

  **Pass condition**: every line naming `CK013` / `CodeVideoOnNonVideo` in
  the diff is byte-identical between before and after; the only permitted
  differences are new lines for the T005–T013 test cases. This is SC-002's
  actual verification mechanism — "the existing validator suite" re-run and
  diffed, not eyeballed or assumed from reading the new code. Also add
  `TestCK013UnchangedAfterLocationAnchor` (or equivalent) as a permanent
  regression test — and this permanent test MUST assert the actual
  `Finding.Message` TEXT equality for the `CK013` row (today:
  `fmt.Sprintf("material of kind %q carries a video anchor", m.Kind)`,
  `validate.go:280`, verified this session), not merely that the set of
  subtest/test names in a `-v` listing is unchanged. A bare name-diff would
  pass even if `CK013`'s message wording silently changed underneath an
  unrenamed test — this is stated here as an explicit task requirement, not
  left to "or equivalent" to cover implicitly. So a future change to this
  file cannot silently regress `CK013`'s behavior OR its message text
  again without a test failing. **This task is the explicit no-regression
  gate FR-003/SC-002 requires — it is not satisfied by T005–T013 passing on
  their own`, since those tests exercise the NEW rules, not the
  preservation of the OLD one.**

### Hardening

- [ ] **T015 [P] [US1] [SUBMODULE]** Extend `scripts/verify-curriculum.sh
  --prove-failure` (the §1.1 paired-mutation proof) with a
  `testdata/mutations/` fixture for each of `CK028`–`CK031`/`CK901`, per
  module-local rule 4. Each mutation must demonstrate the gate catches a
  seeded violation of that specific rule.

- [ ] **T016 [P] [US1] [SUBMODULE]** Full module sweep: `go vet ./...`,
  `go test -race ./...`, from `submodules/curriculum-kit`. Paste real
  output — no claim of "PASS" without it (this repository's anti-bluff
  discipline).

### Submodule landing

- [ ] **T017 [REVIEW] [SUBAGENT] [US1] [SUBMODULE-PROCESS]** Land T002–T016
  as commit(s) inside the `curriculum-kit` repository itself (its own
  history, its own review, per the SUBMODULE NOTICE above — **not** folded
  into an umbrella or `workshop` commit). Once landed and tagged/released
  per that repository's own convention, bump this umbrella's
  `helix-deps.yaml` `curriculum-kit` entry's `ref` and the
  `submodules/curriculum-kit` gitlink SHA together, in one umbrella-side
  change, mirroring every other owned-submodule bump this umbrella's own
  `CLAUDE.md` already documents. **Do not skip the two-step shape** — a
  gitlink bumped with a stale `helix-deps.yaml` `ref` is exactly what this
  umbrella's own C9 cascade check exists to catch.

### Consumer wiring (`workshop/platform/backend`, not the submodule)

- [ ] **T018 [P] [US1]** `workshop/platform/backend/pkg/learning/wire.go`:
  add the `DocumentSectionResolver` interface (parallel to `ChapterResolver`)
  and extend `MaterialObject` to emit a `"location"` key following the exact
  null-until-resolved discipline the existing `"video"` key already
  establishes, per `data-model.md`'s wire-shape section (`section_id`,
  `locator`, `passage_anchor`, `section_slug`/`href` null until resolved,
  `unresolved_reason` on a miss).

- [ ] **T019 [US1]** `workshop/platform/backend/pkg/learning/catalog.go`:
  confirm how `KnownChapters` is built at load time today, and build a
  parallel `KnownSections` registry the same way (do not invent a second
  wiring mechanism — read the existing chapter-registry construction before
  adding this).

- [ ] **T020 [TDD] [US1]** `go test ./pkg/learning/... -run
  TestMaterialObject -v` from `workshop/platform/backend`: a `document`-kind
  Material with a `Location` anchor emits the `"location"` key with
  `section_slug`/`href` resolving through a fixture `DocumentSectionResolver`
  and `"video": null`; a `video`-kind Material still emits `"location": null`
  with its existing `"video"` shape byte-for-byte unchanged (Acceptance
  Scenario 2 / SC-006 — no regression to existing video-anchored content).

- [ ] **T021 [P] [US1]** Write
  `workshop/platform/frontend/docs/document-links.md` — the location-anchor
  URL grammar, the FR-008 counterpart to the existing `time-links.md`
  (plausibly `/documents/<section-slug>/read?loc=<locator>[#p-<pid>]`, fixed
  by this document itself, not invented ad hoc in `wire.go`, per
  `data-model.md`'s own note).

### Independent verification

- [ ] **T022 [US1]** Run `quickstart.md` Step 5 for real: author one
  `document`-kind Material with a populated `Location` anchor in a
  `curriculum/learning/NN-<slug>.json` fixture, load it through the extended
  validator, and confirm it validates and its anchor resolves to an existing
  `doc_section` passage via `passagestore.Registry.Resolve` (Acceptance
  Scenario 1). Also author a `document`-kind Material with a stray
  `VideoAnchor` instead of `Location` and confirm the SAME `CK013` rejection
  the existing suite already demonstrates (Acceptance Scenario 3) — not a
  new or different rejection.

### Cross-spec dependency: spec 012 (document-ingestion-textbooks)

- [ ] **T023 [SUBAGENT] [US1] [CROSS-SPEC] [BLOCKED]** **Depends on spec
  012's `Attrs` passthrough, FR-021 in
  `specs/012-document-ingestion-textbooks/spec.md` (its own task T006a) —
  not yet implemented, so this task is BLOCKED, not merely pending.** Spec
  012 now has a real `plan.md`/`data-model.md`/`tasks.md` (the earlier
  "carries only `spec.md`" reading is superseded), but its `Attrs`
  passthrough is the specific, concrete gate: `docSection` carries no
  `attrs` field and `DocumentObservation` takes no parameter to set one
  today (confirmed by reading `main.go`/`domain.go` directly — see this
  spec's own `data-model.md` "Ingestion" section) — until FR-021/T006a
  lands, spec 012 cannot mint a `doc_section` passage whose `Attrs` carries
  the location metadata `LocationAnchor.PassageAnchor` (T002) is designed
  to cite. Spec 012 is a downstream **producer**: its ingestion pipeline is
  what actually writes `doc_section` passages for real textbook content.
  This specification deliberately does not design spec 012's ingestion
  pipeline (spec.md's own Assumptions: "without designing spec 012's
  ingestion pipeline itself") — this task's job, once spec 012's FR-021 has
  landed, is to confirm spec 012's minted `doc_section` passages (and
  whatever `Attrs` keys it chooses — `page`, `cfi`, `heading`, per
  `data-model.md`'s note that this feature does not name those keys) are
  genuinely resolvable through the `PassageAnchor` handle this feature
  defines, end to end — i.e. re-run T022's round-trip against a REAL
  spec-012-ingested passage instead of a fixture. This is a real
  cross-specification data dependency, not an assumption: until it is done,
  `LocationAnchor` has been exercised only against fixtures, never against
  its real intended producer.

**Checkpoint**: User Story 1 is independently complete and testable —
`curriculum-kit` supports location-anchored citations with `CK013` provably
unregressed (T014), and the workshop platform serves them through the
existing `MaterialObject` wire shape with no new endpoint.

---

## Phase B: User Story 2 — Learner profile page (Priority: P2)

**Goal**: A learner can view, from one page, their activity history, at
least one chart, per-area reports, and a working retake link — using only
four new read-only endpoints and zero new persisted state.

**Depends on**: Phase A landing at least T018–T020 (the `"location"` wire
key) is NOT a hard blocker for Phase B's own endpoints, which read
`ckit.Progress`/`Position` data that exists regardless of anchor type — but
Phase B's reports are under-complete until Phase A ships, per spec.md's own
stated priority rationale ("a profile page that reports on content whose
citations are video-only would under-report ... on any document-sourced ...
content"). Phase B may be implemented in parallel with Phase A's later tasks
(T018+) but its own Independent Test does not require Phase A to be merged.

**Independent Test**: `quickstart.md` Steps 7–8 — as a session with at least
one recorded area attempt and one recorded reading-position update, request
the profile page and confirm a non-empty merged activity history, at least
one chart, a per-area report section, and a working retake link, using only
the four new endpoints and no new persisted state.

### `authstore.CreatedAt` — small, in-scope prerequisite for `account_age` (FR-009)

- [ ] **T023a [TDD] [US2]** **`account_age`'s real data source — a small
  read-side addition, corrected from an earlier "out of scope"/FR-013
  reading (see `data-model.md`'s "Honest gap" note and `plan.md`'s
  Technical Context).** `workshop/platform/backend/pkg/authstore`'s
  `auth_user` table already declares `created_at TEXT NOT NULL`
  (`authstore.go:47`) and already populates it on every insert, including
  both seed accounts (`authstore.go:159-166`) — only the Go `User` struct
  and the two existing `SELECT`s lack it. Add a failing test in
  `pkg/authstore` asserting `UserByUsername` and `UserByTokenHash` both
  return a `User.CreatedAt` matching the row's real `created_at` column
  (parsed via `time.Parse(time.RFC3339, ...)`, the same format `seed()`
  already writes with). Then: add `CreatedAt time.Time` (or
  `` `json:"created_at"` `` string, per whatever this package's existing
  wire-shape convention for timestamps is — check `CreateSession`/
  `RevokeSession`'s own RFC3339 handling first, don't invent a second one)
  to the `User` struct, and extend both `SELECT id, username, password_hash,
  role FROM auth_user ...` (`authstore.go:172`) and `SELECT id, username,
  role FROM auth_session ... JOIN auth_user ...` (`authstore.go:227-228`)
  to also select `created_at`. Run the new test to confirm GREEN. **This
  introduces zero new persisted state (FR-013 is satisfied, not violated):
  the column already exists and is already written by `seed()` — this task
  only adds a read of it.**

### Backend — four read-only handlers (`workshop/platform/backend/internal/api/profile.go`, NEW)

- [ ] **T024 [P] [US2]** Implement `ProfileSummaryHandler` (FR-009,
  `GET /api/profile`): identity via `sessionOf(w, r)` exactly as
  `lessons.go` does, `account_age` computed from `User.CreatedAt` (T023a)
  for an authenticated caller — `null` only for an anonymous,
  `X-Session`-only caller with no account row at all, per the corrected
  Honest Gap in `data-model.md`, `completion.overall_percent` derived
  from `ckit.Completion(area, progress)` summed across every touched area,
  the same tally `LessonCompletionFromDeps` already computes per-area.
  `503` on `ReasonProgressStoreUnreadable`/`LegProgress` or
  `ReasonCurriculumUnreadable`/`LegCurriculum`, mirroring
  `LearningDeps.progressOf`'s existing failure mapping.

- [ ] **T025 [P] [US2]** Implement `ProfileActivityHandler` (FR-010,
  `GET /api/profile/activity`): merges exactly the two timestamped sources
  `data-model.md` identifies — `internal/api.Position.At` (reading-position
  updates) and `ckit.Attempt.At` (assessment attempts) — **not** a lesson
  state-transition snapshot, which carries no timestamp (see
  `data-model.md`'s explicit "what is NOT a timeline event source" note).
  Sort key `(at DESC, kind ASC, id ASC)` for deterministic same-timestamp
  ordering (spec.md's own Edge Case). `limit`/`cursor` query params, clamped
  not rejected, per this surface's existing `intParam` convention;
  `rejectUnknownParams` on an unrecognised key. `entries: []`, never `null`,
  on an empty session (FR-018's wire-level empty state).

- [ ] **T026 [P] [US2]** Implement `ProfileReportsHandler` (FR-011,
  `GET /api/profile/reports`): per-area rows built from
  `ckit.Completion`, `p.BestAttempt(as.ID)`, `len(p.AttemptsFor(as.ID))` —
  the SAME primitives `AssessmentHandler` already uses — restricted to
  areas the session has touched. `ability_scores: null`,
  `ability_scores_status: "not_enough_data"` as the **default** (FR-019's
  degrade-gracefully contract), since spec 013's data source does not exist
  yet (see T040's cross-spec dependency below).

- [ ] **T027 [P] [US2]** Implement `ProfileAreaHandler` (FR-012,
  `GET /api/profile/areas/{area}`): `{area}` validated identically to every
  other `{area}` path parameter (`passage.ParsePID`, `ErrMalformedPID`).
  Every field read verbatim from the same functions `AssessmentHandler`
  already calls (`availabilityObject`, `ckitCompletion`, `attemptObjects`,
  `p.BestAttempt`) — no new grading/scoring/gating logic (FR-016).
  `retake_href` points at the EXISTING `GET /api/areas/{area}/assessment` /
  `POST .../assessment/submit` flow; this endpoint does not itself accept a
  submission. `404` `ErrAreaNotFound` via the same `learningArea` resolution
  path every other `{area}`-scoped route uses (FR-020).

- [ ] **T028 [US2]** Wire all four handlers into the route table alongside
  the existing learning routes, threading the same `LearningDeps`-shaped
  dependencies (`*learning.SessionStore`, `*api.ProgressStore`,
  `*learning.Catalog`) every existing route already receives — no new
  progress store (FR-013). Depends on T024–T027.

### Backend tests

- [ ] **T029 [TDD] [US2]** `profile_test.go`: two cases, since T023a makes
  `account_age` depend on whether a real account exists, not just on
  activity. (a) `GET /api/profile` on a fresh, **anonymous**
  (`X-Session`-only, no account row) session → `200`,
  `completion.areas_touched: 0`, `account_age: null` (FR-018's empty state
  at the API layer — `null` here means "no account to report an age for").
  (b) `GET /api/profile` on a fresh **authenticated** session (an account
  that exists but has recorded zero activity) → `200`,
  `completion.areas_touched: 0`, `account_age` non-null and reflecting the
  fixture account's real `CreatedAt` — confirming T023a's addition is
  actually wired into this handler, not merely compiled.

- [ ] **T030 [TDD] [US2]** `profile_test.go`: `GET /api/profile/activity`
  with a stored reading position AND a stored assessment attempt in the
  fixture → both entries present, sorted `at` descending, with a
  deterministic tie-break verified by two fixture events sharing a
  timestamp (spec.md's own Edge Case, not merely the happy path).

- [ ] **T031 [TDD] [US2]** `profile_test.go`: `GET /api/profile/reports`
  with no spec-013 data source wired → `ability_scores_status:
  "not_enough_data"`, never an error (FR-019).

- [ ] **T032 [TDD] [US2]** `profile_test.go`: `GET /api/profile/areas/{area}`
  for an area with two recorded attempts → `attempts` length 2,
  `best_attempt` is the higher `marked_percent` one (mirrors
  `ckit.Progress.BestAttempt`'s own existing test coverage); and for an
  unpublished/removed area → `404` `ErrAreaNotFound` (FR-020).

### Frontend (`workshop/platform/frontend/src/app/profile/`, NEW)

- [ ] **T033 [P] [US2]** Angular route + `ProfileHeaderComponent`:
  identity/account-age (renders "not available" for `null`, never inferred),
  overall completion percentage.

- [ ] **T034 [US2]** `ActivityFeedComponent`: reverse-chronological merged
  timeline, cursor-based pagination against T025's endpoint (SC-007 —
  renders its first page without loading the full history at once).

- [ ] **T035 [US2]** Hand-rolled inline SVG chart component(s) (FR-017):
  at minimum enough to satisfy Acceptance Scenario 3 (a chart summarizing
  progress/scores across ≥2 areas). No `ngx-charts` or any other new
  charting dependency introduced by default.

- [ ] **T036 [US2]** Per-area reports section + "retake self-assessment"
  link per completed area (FR-015/FR-016): the link re-enters the EXISTING
  assessment submission flow — no new grading, scoring, or gating logic
  introduced on the frontend either.

- [ ] **T037 [US2]** Explicit, non-error empty state for each of the four
  sections (header, activity, charts, reports) independently (FR-018) — four
  separate empty-state renders, not one "page is not broken" fallback.

- [ ] **T038 [TDD] [US2]** `platform/frontend` Playwright
  `profile.spec.ts` covering spec.md's User Story 2 Acceptance Scenarios
  1–4: merged timeline render, working retake link (verified by confirming
  the SAME `POST /api/areas/{area}/assessment/submit` request shape the
  existing assessment-taking flow already issues), at-least-one-chart render
  with no new `package.json` dependency, and the zero-activity empty state
  across all four sections independently.

- [ ] **T039 [US2]** Confirm no new frontend charting dependency was
  introduced: `git diff package.json package-lock.json` shows no new
  entries (FR-017's verification step, not merely a design intent).

### Cross-spec dependency: spec 013 (adaptive-assessment-scoring)

- [ ] **T040 [SUBAGENT] [US2] [CROSS-SPEC]** **Depends on spec 013 landing a
  stable, read-only `AbilityScore`/`ResponseLogEntry` interface — as of this
  writing (2026-09-30), `specs/013-adaptive-assessment-scoring/` carries
  `spec.md`, `contracts/`, `data-model.md`, `plan.md`, and `quickstart.md`
  but its own spec.md still names an open
  `[NEEDS CLARIFICATION: per-area vs. single cross-curriculum score]`
  question, so the read shape this task would consume is not yet fixed —
  this task is **BLOCKED**, not merely pending.** T026's
  `ProfileReportsHandler` returns `ability_scores_status: "not_enough_data"`
  as its correct DEFAULT (FR-019) precisely so Phase B can ship without
  waiting on spec 013. Once spec 013 ships a stable interface: wire the real
  `ability_scores`/`ability_scores_status: "ok"` read into
  `ProfileReportsHandler` per `contracts/profile-endpoints.md`'s note that
  the real wire shape for that state is deliberately **not** defined by this
  specification (it is spec 013's data model, consumed read-only, never
  redefined here). This is a real cross-specification data dependency — the
  "correct default" in T026 is a designed placeholder, not a finished
  feature, until this task closes it.

**Checkpoint**: User Stories 1 AND 2 complete — this is the feature's
legitimate MVP point per spec.md's own priority ordering (Phase 1 + Phase 2).

---

## Phase C: User Story 3 — Cross-material-type unified reporting (Priority: P3)

**Explicitly deferred/exploratory.** Per spec.md's own stated rationale:
*"Building this before real cross-format usage data exists would mean
designing and shipping a report with nothing meaningful to show."* This
phase is not part of this feature's MVP exit criteria (quickstart.md's own
Step 9 records the same deferral). Listed here for traceability so a future
session knows exactly what remains and why it was not started, not as work
to dispatch now.

**Depends on**: Phase A (multi-format citations must exist, T001–T023) AND
real learner activity recorded across at least two distinct
material-source formats (one video-anchored, one location-anchored Material,
each contributing real progress/score data) — a precondition that cannot be
satisfied by any task in this file, since it requires genuine usage over
time, not a fixture.

- [ ] **T041 [US3]** Once real cross-format usage data exists (see
  Depends-on above), extend `ProfileReportsHandler` (T026) so each format's
  contribution to a report is individually attributable/traceable to its own
  citation/anchor (FR-021), while still offering a blended overall view
  where one is shown.

- [ ] **T042 [TDD] [US3]** Add a test confirming 100% of the data points a
  cross-format report draws on remain individually traceable back to their
  originating `Video`/`Location` anchor (SC-008) — re-run the check
  `quickstart.md` Step 9 names, for real, against real recorded activity.

- [ ] **T043 [P] [US3] [REVIEW]** Resolve FR-022's open
  `[NEEDS CLARIFICATION]` — whether per-material-type progress is ever
  blended into a single unified score, or always presented per-format. This
  is a genuine open design decision the source research did not resolve
  (spec.md's own Assumptions section); it requires an operator decision, not
  something derivable from code alone, and blocks any UI treatment that
  depends on the answer.

**Checkpoint**: All three user stories complete — not expected to close in
the same implementation pass as Phases A/B, by design.

---

## Phase D: Polish

- [ ] **T044 [P]** Run `quickstart.md` Step 10's full regression sweep:

  ```bash
  cd workshop && bash scripts/verify.sh
  cd platform/backend && go test ./...
  cd ../../../submodules/curriculum-kit && go test ./... && go test -race ./...
  ```

  Paste real output. No "PASS" claim anywhere in this feature's record
  without it, per this repository's anti-bluff discipline.

- [ ] **T045** Update `CONTINUATION.md` (§12.10) and whatever per-feature
  status doc this repository's own convention requires, noting Phase C's
  deliberate deferral and the two open cross-spec dependencies (T023, T040)
  by task ID, so a future session resumes from a precise state rather than
  re-deriving it.

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)**: empty — no blocker.
- **Phase A (US1)**: T001 (baseline) before T005–T013 (rule implementation)
  before T014 (the regression gate, which needs both the baseline AND the
  new rules to diff against). T002–T004 before T005–T013 (the rules need the
  type and field to exist). T017 (submodule landing) after T002–T016.
  T018–T021 (consumer wiring) depend on T017 having landed a real
  `curriculum-kit` release to pin against — **do not** wire the consumer
  against an unlanded submodule change. T022 depends on T018–T021. T023 is
  independently blocked on spec 012, not on any task in this file.
- **Phase B (US2)**: T024–T027 are `[P]` (four different logical handlers,
  though sharing one new file — see Parallel Execution Notes). T028 depends
  on all four. T029–T032 depend on T028 (need real routes to test against).
  T033–T037 (frontend) may start once T024–T027's response shapes are fixed
  (i.e., once the contracts in `contracts/profile-endpoints.md` are
  implemented, even before T028's final wiring) but T038's Playwright suite
  needs T028 live. T040 is independently blocked on spec 013.
- **Phase C (US3)**: depends on Phase A complete AND real cross-format usage
  data — the latter is not satisfiable by any task here.
- **Phase D (Polish)**: depends on Phases A and B (Phase C is explicitly not
  required to close first).

### Parallel execution notes

- T024–T027 target the SAME new file (`internal/api/profile.go`). Despite
  the `[P]` marker (different logical handlers, no data dependency between
  them), **dispatch them to one subagent as a small sequential batch, or
  sequence them explicitly, rather than four parallel subagents writing to
  one file** — the same file-conflict discipline spec 009's own tasks.md
  applies to its `meeting_notes.py` dispatch (T012/T014 there).
- T033–T037 (frontend components) target different new files under
  `profile/` and may genuinely run in parallel once the four endpoints'
  response shapes are fixed by `contracts/profile-endpoints.md` (already
  written) — they do not need to wait for T028's actual route wiring to
  begin against a mocked response.
- T002–T016 (Phase A, inside `submodules/curriculum-kit`) and T024–T039
  (Phase B, inside `workshop/`) touch **entirely disjoint repositories** and
  may be dispatched fully in parallel by different subagents — there is no
  file overlap and, per the Phase B dependency note above, no hard
  correctness dependency for Phase B's own Independent Test.
- T023 and T040 (the two cross-spec dependency tasks) are **not**
  parallelizable with anything — each is blocked on a different, external
  specification's own implementation timeline, not on any task in this
  file.

---

## Implementation Strategy

### MVP first

1. Complete Phase A (T001–T023) — closes the one real structural gap
   (`LocationAnchor`) every other story and every other in-flight spec
   touching content citations depends on.
2. Complete Phase B (T024–T040) — the feature's primary end-user-facing
   deliverable.
3. **STOP and validate**: run `quickstart.md` Steps 1–8 for real, with
   pasted output, before considering Phases A+B "done."
4. Phase C (T041–T043) resumes only once its stated precondition (real
   cross-format usage data) exists — do not attempt it early to "get ahead."
