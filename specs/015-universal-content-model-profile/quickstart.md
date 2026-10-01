# Quickstart: Universal Content Model (Position-Anchored Citations) and Learner Profile Page

Runnable validation steps for both phases. Every command is grounded in this
repository's real toolchain (`go test`, `curriculum-kit`'s own
`scripts/verify-curriculum.sh`, the workshop platform's gate suite) — none
of this was run during planning; these are the steps a future implementation
task actually executes.

## Phase 1 — Location Anchor (curriculum-kit)

### Step 1 — No-regression baseline (run BEFORE any change)

Capture today's `CK013` behaviour so the "zero regression" claim (FR-003 /
SC-002) is demonstrated, not asserted:

```bash
cd submodules/curriculum-kit
go test ./pkg/curriculum/... -v > /tmp/ck013-before.txt
bash scripts/verify-curriculum.sh           # record today's exit code + counts
```

**Do not use `-run TestValidate`** — there is no `TestValidate` function in
`validate_test.go`; `-run` matches it against an unrelated function
(`TestValidateDoesNotRequireALessonBody`) by substring while matching NONE
of `TestEachRuleCatchesItsOwnDefect`'s subtests, which is the test that
actually exercises `CK013`/`CodeVideoOnNonVideo` (subtest `"video anchor on
a diagram"`). Verified this session:
`go test ./pkg/curriculum/... -run 'TestEachRuleCatchesItsOwnDefect/video_anchor_on_a_diagram' -v`
passes and its output names that exact subtest; the command above instead
drops `-run` entirely and captures the whole package's `-v` output, which
still contains that line and is safer against a future rename.

### Step 2 — Add `LocationAnchor` and the validator rules

Implement per `data-model.md` and `contracts/location-anchor.md`: the new
type in `model.go`, the new `Options.KnownSections` field, and the extended
`material()` function in `validate.go` with the five new rule codes
(`CK028`–`CK031`, `CK901`).

### Step 3 — Regression check (the load-bearing one)

```bash
go test ./pkg/curriculum/... -v > /tmp/ck013-after.txt
diff /tmp/ck013-before.txt /tmp/ck013-after.txt
# Every line naming CK013 / CodeVideoOnNonVideo must be IDENTICAL.
# New lines are expected only for the new CK028–CK031/CK901 test cases.
```

This is SC-002's actual verification mechanism: "the existing validator
suite" re-run, diffed, not eyeballed. The permanent regression test added in
T014 (`TestCK013UnchangedAfterLocationAnchor` or equivalent) must assert
`Finding.Message` TEXT equality for the `CK013` row, not just that the set
of test/subtest names is unchanged — a bare name-diff would not catch a
silent change to `CK013`'s message wording.

### Step 4 — New-rule validation

```bash
go test ./pkg/curriculum/... -v -run 'TestLocation|TestDualAnchor|TestDocumentNoLocation'
go vet ./...
go test -race ./...
bash scripts/verify-curriculum.sh --prove-failure   # the §1.1 paired mutation proof, extended
                                                     # with a testdata/mutations/ fixture for each
                                                     # new rule code, per module-local rule 4
```

### Step 5 — Independent Test from spec.md User Story 1

Author one real (or fixture) `document`-kind Material with a populated
`Location` anchor in a `curriculum/learning/NN-<slug>.json` file, load it
through the extended validator, and confirm:

```bash
# Author a fixture entry, then:
go run ./cmd/validate-fixture -- curriculum/learning/NN-fixture.json   # or the project's own
                                                                          # equivalent loader entry
                                                                          # point, per whatever
                                                                          # pkg/learning.LoadCatalog
                                                                          # already exposes for a
                                                                          # single-file check
```

Acceptance Scenario 1 (spec.md): the Material validates and its anchor
resolves to an existing `doc_section` passage — verify by round-tripping
`Location.PassageAnchor` through the live passage registry
(`passagestore.Registry.Resolve`), exactly as `progress.go`'s
`liveVisiblePositions` already re-checks a stored `pid` against the SAME
registry.

Acceptance Scenario 3: author a `document`-kind Material with a
`VideoAnchor` instead of `Location` and confirm the run produces the SAME
`CK013` rejection the existing suite already demonstrates for that case
(not a new or different rejection) — the assertion `CK013`'s existing
message text is unchanged.

### Step 6 — Wire-shape check (`pkg/learning`)

```bash
cd workshop/platform/backend
go build ./...
go test ./pkg/learning/... -run TestMaterialObject -v
```

Confirm `MaterialObject` on a `document`-kind Material with a `Location`
anchor emits the `"location"` key with `section_slug`/`href` resolving
through a fixture `DocumentSectionResolver`, and emits `"video": null` —
and that a `video`-kind Material still emits `"location": null` and its
existing `"video"` shape unchanged (Acceptance Scenario 2: existing
video-anchored content continues to serve identically — SC-006).

## Phase 2 — Learner Profile Page

### Step 7 — Handler tests (backend)

```bash
cd workshop/platform/backend
go test ./internal/api/... -run TestProfile -v
```

Cover, per `contracts/profile-endpoints.md`:

- `GET /api/profile` on a fresh session → `200`, `completion.areas_touched:
  0`, `account_age: null` (FR-018's empty state, at the API layer).
- `GET /api/profile/activity` merging a stored reading position AND a
  stored assessment attempt → both entries present, sorted `at` descending,
  deterministic tie-break when two fixture events share a timestamp
  (spec.md's Edge Case).
- `GET /api/profile/reports` with no spec-013 data source wired →
  `ability_scores_status: "not_enough_data"`, never an error (FR-019).
- `GET /api/profile/areas/{area}` for an area with two recorded attempts →
  `attempts` length 2, `best_attempt` is the higher `marked_percent` one
  (mirrors `ckit.Progress.BestAttempt`'s own existing test coverage).
- `GET /api/profile/areas/{area}` for an unpublished/removed area → `404`
  `ErrAreaNotFound` (FR-020), via the same `learningArea` path every other
  `{area}` route uses.

### Step 8 — Frontend (Angular, Playwright)

```bash
cd workshop/platform/frontend
npm ci
ng build
npx playwright test profile.spec.ts
```

Cover spec.md's User Story 2 Acceptance Scenarios directly:

1. A session with both a reading position and an area attempt renders one
   merged, reverse-chronological timeline (Scenario 1).
2. A completed area shows a working "retake self-assessment" link that
   re-enters the existing submission flow (Scenario 2) — verified by
   following the link and confirming the SAME `POST
   /api/areas/{area}/assessment/submit` request shape the existing
   assessment-taking flow already issues (no new endpoint, per FR-016).
3. A session with scores across ≥2 areas renders at least one chart, built
   with the existing hand-rolled inline SVG components — confirm no new
   `package.json` dependency was added (`git diff package.json
   package-lock.json` — FR-017).
4. A session with zero activity renders an explicit empty state in every
   section (header, activity, charts, reports) — four independent
   assertions, not one "page is not broken" check (FR-018).

### Step 9 — Cross-format check (User Story 3, once real usage exists)

This step is explicitly deferred per spec.md's own Priority rationale —
"Building this before real cross-format usage data exists would mean
designing and shipping a report with nothing meaningful to show" — and is
not part of this quickstart's Phase 1/Phase 2 exit criteria. Recorded here
so a future session knows where to resume: once both a video-anchored and a
location-anchored Material have real recorded learner activity, re-run
`GET /api/profile/reports` and confirm every contributing data point is
individually traceable back to its own `Video`/`Location` anchor (SC-008),
per FR-021.

### Step 10 — Full regression sweep

```bash
cd workshop
bash scripts/verify.sh
cd platform/backend && go test ./...
cd ../../../submodules/curriculum-kit && go test ./... && go test -race ./...
```

No claim of "PASS" for either phase is made anywhere in this plan's own
documents (per this repository's anti-bluff discipline) until these commands
have actually been run in a real implementation session and their output
captured — this quickstart is the runbook for that session, not a substitute
for running it.
