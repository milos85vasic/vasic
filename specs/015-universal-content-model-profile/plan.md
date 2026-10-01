# Implementation Plan: Universal Content Model (Position-Anchored Citations) and Learner Profile Page

**Branch**: `main` (no git branch created for this feature — an explicit simplification decision; spec.md records it)
**Date**: 2026-09-30
**Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/015-universal-content-model-profile/spec.md`

## Summary

Two independent phases on top of already-adopted infrastructure, built in
priority order:

1. **Extend `submodules/curriculum-kit`'s `Material` type with a second,
   page/location-anchored citation type (`LocationAnchor`)**, structurally
   parallel to the existing time-anchored `VideoAnchor`, so a `document`-kind
   Material can cite a page/section the same way a `video`-kind Material cites
   a time range. This closes the one real structural gap the prior research
   pass identified; everything else in the two-layer content model
   (`passagestore`'s `doc_section` kind, the `Catalog → Area → Lesson →
   Material → Assessment` shape, the `CK013` video-only-rejection guarantee)
   is already built and format-agnostic, confirmed by reading the real code
   rather than re-derived from the research document's prose.
2. **A learner profile page** (`workshop/platform/frontend`) backed by four
   new READ-ONLY HTTP endpoints (`workshop/platform/backend/internal/api`)
   that aggregate existing stores — `pkg/learning.SessionStore`
   (`ckit.Progress`: lesson states, assessment attempts) and the reading-
   position store (`internal/api.ProgressStore`) — into an activity timeline,
   per-area reports, and charts, with a "retake self-assessment" action that
   re-enters the existing `POST /api/areas/{area}/assessment/submit` flow.
   Zero new persisted state.

**This plan is grounded in the real current code, not in the research
document's summary of it.** Three load-bearing facts were confirmed by
reading `submodules/curriculum-kit/pkg/curriculum/model.go`,
`validate.go`, `progress.go`, `workshop/platform/backend/pkg/learning/wire.go`,
`workshop/platform/backend/internal/api/lessons.go`, `progress.go`,
`pkg/assessment/progress.go`, and `pkg/authstore/authstore.go`:

- `ckit.Material.Video *VideoAnchor` is the only anchor field on `Material`
  today; `CK013` (`CodeVideoOnNonVideo`) rejects a `VideoAnchor` on a
  non-`video` Material, and does so with a message this plan's new validator
  branches preserve verbatim for the unchanged case (FR-003/SC-002).
- **Neither of the two "assessment/progress" records this feature's activity
  endpoint would read from carries a per-row timestamp for a STATE
  TRANSITION.** `ckit.Progress.Lessons` is `map[ID]LessonState` — a snapshot,
  not a log; marking a lesson complete overwrites the map entry with no
  recorded "when". `pkg/assessment.Progress` (a separate, spec-002-era
  area/question_set/question progress record) is `{Session, ItemType, Item,
  Status, Grade, Streak}` — also no timestamp. The **only** two real,
  timestamped event sources in the current backend are `ckit.Attempt.At`
  (an assessment submission, already serialised as `at` by
  `AssessmentSubmitHandler`/`attemptObject` in `lessons.go`) and
  `internal/api.Position.At` (a reading-position `PUT`, in `progress.go`).
  This resolves spec.md's own named Assumption ("whether `pkg/assessment`'s
  existing `Progress` records already carry a per-row timestamp ... is an
  implementation detail to confirm at build time") with a concrete answer:
  **no, and the fix is not "add a timestamp to a snapshot map" — it is
  "build the activity timeline from the two sources that already log
  events, not from the one source that only logs current state."** See
  `data-model.md`'s Activity Timeline Entry section.
- `authstore.User` is `{ID, Username, PasswordHash, Role}` — **the Go struct
  and both `SELECT` statements (`UserByUsername`/`UserByTokenHash`) carry no
  `CreatedAt` field, but the underlying `auth_user` SQLite table already
  does**: its schema declares `created_at TEXT NOT NULL` (`authstore.go:47`)
  and both seed accounts already have it populated on every insert
  (`authstore.go:159-166`, `seed()`). **Correction, verified by
  reading `authstore.go` directly rather than inferring from the struct
  alone: this is a small, in-scope, READ-SIDE addition — add the struct
  field, add the column to the two existing `SELECT`s — not a schema
  migration, and FR-009's "account age" does NOT lack a backing data source
  in the current schema; it lacks only a Go-side read of a column the
  schema already writes.** This is recorded as a small, buildable task in
  `data-model.md` and `tasks.md`, not a deferred gap.

## Technical Context

**Language/Version**: Go 1.26.2 (backend, `workshop/platform/backend`, and
`submodules/curriculum-kit` which is its own Go module), TypeScript 5.x /
Angular 19 (frontend, `workshop/platform/frontend`)

**Primary Dependencies**: `submodules/curriculum-kit` (extended, not forked —
the Phase 1 work lands there per §11.4.74: this is the already-adopted,
project-not-aware seam), the existing `passagestore` (`doc_section` kind,
unchanged — no new `Kind` per FR-007), `pkg/learning.SessionStore`
(`ckit.Progress`), `internal/api.ProgressStore` (reading positions). No new
frontend charting library (FR-017) — hand-rolled inline SVG, consistent with
this codebase's existing minimal-dependency discipline (spec 004's
`platform/frontend/src/app/` has no chart dependency today either).

**Storage**: Files, unchanged. No new persisted store (FR-013/SC-004): the
profile endpoints are read-only aggregations over `learning-progress.json`
(`pkg/learning.SessionStore`) and `progress.json`
(`internal/api.ProgressStore`), the same two files `GET /api/progress` and
the learning routes already read.

**Testing**: Go `go test` in `curriculum-kit` (validator unit tests,
mirroring the existing `CK013` test shape) and in `workshop/platform/backend`
(handler tests, mirroring `lessons.go`'s own test files); Playwright for the
profile page (`workshop/platform/frontend`'s existing e2e harness).

**Target Platform**: Linux container (`podman`), served on the workshop
platform's existing bound port; frontend bundle staged into `platform/web/`
— unchanged deployment shape.

**Project Type**: Web service (Go backend) + single-page application
(Angular frontend) + one reusable library extension (`curriculum-kit`),
inside a private module (`workshop`) that must also clone standalone. Same
three-part shape spec 004 already established.

**Performance Goals**: Not applicable in the throughput sense — this is a
per-session, request-served read path over already-loaded in-memory/file-
backed stores, not a new indexing or batch workload. The activity-history
endpoint's own performance obligation is structural, not a number: it MUST
paginate (FR-010, SC-007), not that it must answer within a stated latency
budget this spec does not set.

**Constraints**: `curriculum-kit` stays project-not-aware (no
`workshop`-shaped vocabulary in the new `LocationAnchor` type or its
validator messages — same module-local rule the existing `VideoAnchor`
already honours); the content-boundary rule (no private `workshop/chapters/`
content quoted anywhere in the public umbrella, including this plan); zero
new persisted write-side state (FR-013); the existing `CK013` guarantee MUST
NOT regress (FR-003/SC-002, verified by re-running the existing validator
test suite, not by inspection).

**Scale/Scope**: One new anchor type plus ~4 new validator rule codes in
curriculum-kit (small, additive); one `MaterialObject` wire-shape extension
plus four new read-only HTTP handlers and one Angular route in the workshop
platform.

**NEEDS CLARIFICATION carried from spec.md, not resolved here**: FR-022
(whether per-material-type progress is ever blended into a single unified
score, or always presented per-format) is an explicitly open Phase-3 design
question the research did not resolve; this plan does not resolve it either
— Phase 3 (User Story 3) is correctly sequenced last precisely because it
needs real cross-format usage data to decide, not because the plan is
incomplete. Two NEW implementation-detail gaps this plan's own code reading
surfaced (the lesson-state-transition timestamp gap and the account-age data
gap) are resolved with a concrete design decision each in `data-model.md`,
not left open, because both have a real code-grounded answer today.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design —
see the note at the end of this section.*

Targeted against the two anchors spec.md's own author flagged as the ones
that matter for this feature, per instruction — not an exhaustive sweep.

| Anchor | Status | Notes |
|---|---|---|
| **§11.4.241 — illegal-state-unrepresentability** (types before runtime checks) | **PASS, with one honest gap named** | `VideoAnchor` achieves this partially by DOCUMENTATION and a RUNTIME check, not by an unrepresentable type: `Material.Video *VideoAnchor` is a plain optional pointer, and nothing in the Go type system stops a caller from also setting a second anchor field — `CK013`'s `CodeVideoOnNonVideo` is a runtime validator finding, not a compile-time impossibility. The new `Material.Location *LocationAnchor` field follows the **same** discipline the existing field already uses, because introducing a sum-type/tagged-union discipline for `Video`/`Location` alone, while every other optional field on `Material` (`Caption`, `Alt`) stays a plain pointer/plain string, would be an inconsistent, half-applied fix of a pre-existing pattern this feature did not introduce and is not scoped to fix. What this plan DOES add, matching the existing precedent exactly: a new validator rule (`CodeDualAnchor`) that rejects a Material carrying BOTH `Video` and `Location` at once (FR-004, edge case 3) — the runtime enforcement `CK013` already established as this module's chosen mechanism for "at most one anchor kind", applied symmetrically to the new second anchor. This is the SAME choice the existing code already made, not a weaker one invented for this feature. |
| **§11.4.74 — submodules-catalogue-first discovery; extend, don't reimplement** | **PASS** | `submodules/curriculum-kit` is the ALREADY-ADOPTED, already-recorded-in-`helix-deps.yaml` seam for exactly this model (`Catalog → Area → Lesson → Material → Assessment`), consumed today by `workshop/platform/backend/pkg/learning`. This plan proposes extending `curriculum-kit`'s own `pkg/curriculum/model.go` and `validate.go` — the same files `VideoAnchor`/`CK013` already live in — with a second anchor type and its validator rules, plus corresponding read-side additions in the CONSUMING project (`pkg/learning`, `internal/api`, the Angular frontend). It proposes **no** parallel content model, no second catalog loader (FR-006 is explicit: same `curriculum/learning/NN-<slug>.json` format, same loader), and no reimplementation of `curriculum-kit`'s availability/scoring mechanism inside `workshop/` — `pkg/learning`'s existing discipline (documented in `lessons.go`'s own header: "There is no such line in this file... `curriculum.AvailabilityOf` decides availability; `Submit` decides...") is preserved and extended, not bypassed. The profile endpoints read `ckit.Progress` through the SAME `pkg/learning.SessionStore` the learning routes already use — no second progress store, no second availability check. |

**No violation on either anchor.** The one honest gap under §11.4.241 (a
runtime check rather than a type-level impossibility) is an existing,
pre-feature property of `Material`'s design that this plan deliberately does
not silently "fix" by treating only the new field differently from its
sibling — see the Complexity Tracking note below for why that was considered
and rejected, not merely skipped.

**Post-design re-check**: unchanged. `data-model.md` and `contracts/` do not
introduce anything that moves either row — the validator design in
`data-model.md` is the same `CodeDualAnchor` runtime rule described above,
and the four HTTP contracts read existing stores through existing seams with
no new storage and no reimplemented availability/scoring logic.

## Project Structure

### Documentation (this feature)

```text
specs/015-universal-content-model-profile/
├── spec.md                        # Feature specification (already exists)
├── plan.md                        # This file
├── data-model.md                  # Phase 1 — LocationAnchor, validator rules, profile entities, gaps
├── contracts/
│   ├── location-anchor.md         # The curriculum-kit type + validator contract (Phase 1)
│   └── profile-endpoints.md       # The four FR-009–FR-012 HTTP contracts (Phase 2)
├── quickstart.md                  # Phase 1 — runnable end-to-end validation for both phases
└── tasks.md                       # /speckit-tasks output (not produced by this plan)
```

### Source Code (repository root)

```text
submodules/curriculum-kit/                 # Phase 1 — the reusable library, project-UNAWARE
├── pkg/curriculum/model.go                # MODIFY: add LocationAnchor type, Material.Location field
├── pkg/curriculum/validate.go             # MODIFY: extend material() with symmetric location rules,
│                                           #   new Options.KnownSections, new CK02x/CK90x codes
└── pkg/curriculum/validate_test.go        # MODIFY/NEW: mirror the existing CK013 test shape for the
                                            #   new rules, plus a regression test asserting CK013's
                                            #   existing finding/message is byte-for-byte unchanged

workshop/
├── platform/backend/
│   ├── pkg/learning/
│   │   ├── wire.go                        # MODIFY: MaterialObject() renders "location" alongside
│   │   │                                   #   "video", following the same null-until-resolved
│   │   │                                   #   pattern; new DocumentSectionResolver interface
│   │   │                                   #   parallel to ChapterResolver
│   │   └── catalog.go                     # MODIFY (if KnownSections needs building at load time,
│   │                                       #   parallel to however KnownChapters is built today —
│   │                                       #   confirm the existing chapter-registry wiring before
│   │                                       #   adding a second one)
│   └── internal/api/
│       ├── profile.go                     # NEW: FR-009–FR-012's four handlers (ProfileSummaryHandler,
│       │                                   #   ProfileActivityHandler, ProfileReportsHandler,
│       │                                   #   ProfileAreaHandler), reusing sessionOf/writeJSON/
│       │                                   #   writeError/writeUnavailable exactly as lessons.go does
│       └── profile_test.go                # NEW: handler tests, mirroring lessons_test.go's shape
├── platform/frontend/src/app/
│   └── profile/                           # NEW: Angular route + components (header, activity feed,
│                                           #   charts — hand-rolled inline SVG per FR-017, per-area
│                                           #   reports, retake links)
└── platform/frontend/docs/
    └── document-links.md                  # NEW: the location-anchor URL grammar, the FR-008
                                            #   counterpart to the existing time-links.md
```

**Structure Decision**: Phase 1 lands entirely inside `curriculum-kit`'s
existing two files (`model.go`, `validate.go`) rather than a new file,
because the new type is a direct sibling of `VideoAnchor` and splitting it
out would separate two anchor types that must be read and reasoned about
together (the dual-anchor rejection rule needs both in view). Phase 2 lands
as a new `internal/api/profile.go` rather than growing `lessons.go` or
`progress.go` further — both are already substantial (1071 and 426 lines),
and the profile surface is a distinct read-only aggregation layer over both,
not a peer of either's own route family. `pkg/learning` gains no new
progress store: `profile.go`'s handlers take the same `LearningDeps`-shaped
dependencies (`*learning.SessionStore`, `*api.ProgressStore`,
`*learning.Catalog`) the existing routes already thread through, per FR-013.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No unjustified Constitution Check violations — table intentionally empty.

One deliberate non-fix is worth recording rather than silently declining:
§11.4.241 favors illegal-state-unrepresentability over a runtime check. A
tagged-union/sum-type encoding of `Material`'s anchor field (so "carries
both a video and a location anchor" is not constructible at all, rather than
constructible-and-rejected-at-validation-time) was considered and rejected
for THIS feature specifically because it would change `VideoAnchor`'s own
existing, already-shipped field shape (`Video *VideoAnchor` on every
`Material`) — a breaking change to every existing authored
`curriculum/learning/NN-<slug>.json` file and to `MaterialObject`'s existing
wire shape, for a design improvement that is not scoped to this feature and
that FR-003/SC-002 (zero regression to existing video-anchored content)
would make actively risky to bundle here. The runtime-rule approach
(`CodeDualAnchor`) delivers the SAME observable guarantee — a Material can
never carry two anchors — at zero risk to the existing guarantee this
feature is required not to regress.
