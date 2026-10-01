# Feature Specification: Universal Content Model (Position-Anchored Citations) and Learner Profile Page

**Feature Branch**: `015-universal-content-model-profile` (no git branch created — per an explicit simplification decision for this feature, this document was authored directly into the already-reserved `specs/015-universal-content-model-profile/` directory on `main`)

**Created**: 2026-09-30

**Status**: Draft

**Input**: Formalization of completed research in `workshop/docs/research/education-platform/multi-provider-llm-and-content-model.md`, Part B ("Universal content model + user profile"). That research document also covers Part A, a multi-provider LLM abstraction, which is out of scope here and is formalized separately as spec 011-multi-provider-llm-providers. This specification covers only: (1) extending the already-adopted `curriculum-kit` content model so every material type — video chapters, text-only chapters, and future textbook ingestion (spec 012) — converges on the same `Area → Lesson → Material → Assessment` structure with first-class, format-appropriate citation anchoring; and (2) a learner-facing profile page (activity history, reports/charts, retake-self-assessment link).

## Why this specification exists

This is not greenfield design. A research pass already read the real code —
`platform/backend/internal/passagestore`, `submodules/curriculum-kit`, and
`platform/backend/pkg/learning`, `pkg/assessment`, `internal/api` — and found
that the two-layer system this feature needs is **already mostly built and
already format-agnostic**: `passagestore`'s `Kind` vocabulary already spans
more than video (`transcript_segment`, `doc_section`, `code`, `diagram`,
`screen_text`), and `curriculum-kit`'s served `Catalog → Area → Lesson →
Material → Assessment` model already defines a `document` `MaterialKind`
alongside `video`, with a validator (`CK013`) that **actively rejects** a
video-only assumption (a video-time-anchor on a non-video Material). The
research's core recommendation, and this specification's scope, is
deliberately narrow: **extend the one real gap** — `curriculum-kit`'s
`Material` type has exactly one anchor type today (`VideoAnchor`, time-based);
a textbook or text-only chapter needs a structurally parallel,
page/location-anchored counterpart — and build the profile page on top of
what the extended model and the parallel adaptive-scoring work (spec 013)
already provide, rather than inventing a second content model or a second
progress store.

Nothing in this document quotes private teaching-session content. It
describes code shape — type names, file locations, validator behavior — not
the recorded material itself, following the same convention this repository's
other specs touching the private `workshop` submodule already use (e.g.
specs/009-meeting-notes-pdf-source/spec.md).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A non-video Material can cite its source by page/location, exactly as a video Material cites its source by time (Priority: P1)

A content author or an ingestion pipeline (document ingestion, spec 012, or a
text-only-chapter authoring flow) is producing a `document`-kind `Material`
for an area's lesson. Today, `curriculum-kit`'s only citation-anchor type is
`VideoAnchor` — a time range plus a transcript-segment reference — and there
is no equivalent for "this material is citing page 14 of a textbook chapter"
or "this material is citing the third section of a text-only lesson." Without
this, every non-video Material either goes uncited or is forced into a
time-based anchor that does not describe it.

**Why this priority**: Every other user story in this specification builds on
this one. The profile page's per-area reports, and any future cross-format
reporting, are only as good as the citation fidelity of the content they
report on. Spec 012 (document ingestion) and any text-only-chapter authoring
work cannot produce first-class, deep-linkable content until this anchor type
exists, because it is genuinely the one structural gap the research
identified — not a re-derivation of work already done.

**Independent Test**: Author (or generate) a `document`-kind `Material` entry
in a `curriculum/learning/NN-<slug>.json` authoring file with the new
location anchor populated, load it through `curriculum-kit`'s existing
validator, and confirm it validates successfully, resolves to a `doc_section`
passage, and is served through the existing `GET /api/areas/{area}/materials`
family of endpoints with no new endpoint or second catalog loader required.

**Acceptance Scenarios**:

1. **Given** a `document`-kind `Material` with a page/section location anchor
   populated (chapter/section identifier, a location locator, and a passage
   reference), **When** the content model's validator runs, **Then** the
   Material passes validation and its anchor resolves to an existing
   `doc_section`-kind passage record.
2. **Given** a `video`-kind `Material` with its existing `VideoAnchor`
   populated, **When** the content model's validator runs after this feature
   ships, **Then** the Material continues to validate exactly as it did
   before this feature (no regression to existing video-anchored content).
3. **Given** a `document`-kind `Material` that is mistakenly given a
   `VideoAnchor` instead of the new location anchor, **When** the content
   model's validator runs, **Then** validation fails with the same kind of
   rejection `CK013` already produces for a video-anchor on a non-video
   Material today (the existing guarantee is preserved, not narrowed).
4. **Given** a served lesson containing a `document`-kind Material with a
   location anchor, **When** a client requests that lesson's materials,
   **Then** the response includes enough information (chapter/section
   identifier, locator, and passage reference) for a document-reader UI to
   seek to that location and highlight the cited passage — the same
   shape-of-purpose the existing `VideoAnchor` response already serves for
   video deep-linking.

---

### User Story 2 - A learner can view their own profile page: activity history, reports, and charts (Priority: P2)

A learner who has been working through areas and lessons wants a single place
to see what they have done, how they are doing, and to act on it — not
scattered across individual area pages with no aggregate view. They want a
reverse-chronological activity feed, a visual summary of their progress
(charts), a per-area breakdown (score, attempts, what is left to unlock a
retake), and a direct way to retake a self-assessment they have already
completed.

**Why this priority**: This is the feature's primary end-user-facing
deliverable. It is second priority, not first, because it depends on User
Story 1: a profile page that reports on content whose citations are
video-only would under-report, or fail to report at all, on any
document-sourced or text-only-chapter content a learner has actually
consumed.

**Independent Test**: As an authenticated-or-anonymous learner session with
at least one recorded area attempt and one recorded reading-position update,
request the profile page. Confirm it renders a non-empty activity history
combining both data sources, at least one chart, a per-area report section,
and a working "retake self-assessment" link for a completed area — using only
the four new read-side API endpoints and no new persisted state.

**Acceptance Scenarios**:

1. **Given** a learner session with recorded reading-position updates and
   recorded area/assessment progress, **When** the learner opens their
   profile page, **Then** the page renders a single reverse-chronological
   activity timeline merging both kinds of events.
2. **Given** a learner who has completed at least one area's assessment,
   **When** the learner views that area's entry on their profile page,
   **Then** a "retake self-assessment" link is present and, when followed,
   re-enters the existing assessment submission flow for that area with no
   new grading or gating logic introduced.
3. **Given** a learner with recorded scores across at least two areas,
   **When** the learner views the profile page's reports/charts section,
   **Then** at least one chart renders summarizing progress or scores across
   those areas, without the frontend adding a new charting library (per
   FR-017).
4. **Given** a learner session with zero recorded activity of any kind,
   **When** the learner opens their profile page, **Then** the page renders
   an explicit, non-error empty state for each section (header, activity,
   charts, reports) rather than an error or a broken/blank layout.

---

### User Story 3 - Cross-material-type unified reporting, once real usage spans formats (Priority: P3)

Once learners have real activity across more than one material-source format
(for example, a video-sourced lesson and a document-sourced lesson within the
same or different areas), the platform should be able to report on that
activity in a way that does not silently lose or flatten the per-format
detail — while also giving a learner a coherent overall picture rather than
requiring them to mentally reconcile separate, disconnected reports per
format.

**Why this priority**: This is explicitly the last phase. It consumes both
User Story 1 (the content model must already support multiple formats with
first-class citations) and, for its most useful state, the ability-score
history the parallel adaptive-scoring work (spec 013) is expected to produce.
Building this before real cross-format usage data exists would mean
designing and shipping a report with nothing meaningful to show.

**Independent Test**: With a learner who has genuine recorded activity across
at least two distinct material-source formats (e.g. one video-anchored and
one location-anchored Material, each contributing to progress/score data),
confirm the profile page's reporting surface can attribute and distinguish
that activity by source format, and confirm every video-sourced or
document-sourced data point that contributed is individually traceable back
to its own citation.

**Acceptance Scenarios**:

1. **Given** a learner with recorded progress on both a video-sourced and a
   document-sourced Material, **When** the profile page's reports are
   requested, **Then** each format's contribution is individually
   attributable (traceable to its own citation/anchor), regardless of whether
   a blended overall view is also shown.
2. **Given** a learner with recorded progress on only one material-source
   format, **When** the profile page's reports are requested, **Then** the
   report renders correctly for that single format with no error or
   placeholder implying a second format was expected.

### Edge Cases

- What happens when a document-sourced Material's location anchor points to a
  passage that no longer exists (e.g. the source document was re-ingested
  with a different section boundary)? → The citation resolution MUST report
  an explicit unresolved/broken-citation state rather than silently omitting
  the material or resolving to the wrong passage.
- What happens when a `document`-kind Material is authored with neither a
  `VideoAnchor` nor the new location anchor (no citation at all)? → This
  MUST be treated the same way the content model already treats any other
  structurally incomplete Material — a validation finding, not a silent
  accept.
- What happens when a `document`-kind Material is mistakenly authored with
  **both** a `VideoAnchor` and the new location anchor at once? → Validation
  MUST reject a Material carrying more than one anchor type; a citation
  mechanism must be unambiguous.
- What happens when a learner opens the profile page before the
  adaptive-scoring ability-score data source (spec 013) has any data for
  them? → The scores/charts section MUST render a clear "not enough data
  yet" state distinct from an error, never a broken chart or a silent gap.
- What happens when a learner follows a "retake self-assessment" link for an
  area that has since been unpublished or removed from the catalogue? → The
  action MUST fail with an explicit, learner-visible reason, using whatever
  existing "area not available" handling the catalogue already has, rather
  than a generic error.
- What happens when the activity-history feed has far more events than fit
  on one page? → The activity endpoint MUST paginate; the page MUST NOT
  attempt to render an unbounded feed in one response.
- What happens when two activity events (a reading-position update and a
  progress-status transition) share the same timestamp? → The merged
  timeline MUST produce a stable, deterministic ordering for same-timestamp
  events rather than an ordering that can vary between requests.
- What happens when a chart has too few data points to be meaningful (e.g.
  exactly one recorded score)? → The chart MUST render a valid, non-broken
  state for minimal data (e.g. a single point or a "just getting started"
  treatment) rather than erroring or rendering an empty/misleading axis.

## Requirements *(mandatory)*

### Functional Requirements

**Phase 1 — Universal content model (position-anchored citations)**

- **FR-001**: System MUST provide a new, page/location-anchored citation
  type in `curriculum-kit`'s `Material` model, structurally parallel to the
  existing time-anchored `VideoAnchor` type, carrying at minimum a
  chapter/section identifier, a location locator (e.g. page number or
  equivalent position string), and a reference to the passage record the
  anchor resolves to.
- **FR-002**: System MUST allow a citation on document-sourced content to
  resolve by page/section location, using the same resolution mechanism
  video citations use for time offsets — i.e. the new anchor type resolves
  to a passage-store record the same way `VideoAnchor`'s transcript anchor
  already does, with no second, parallel resolution mechanism.
- **FR-003**: System MUST continue to reject a `VideoAnchor` assigned to a
  non-`video` Material after this change ships — the existing `CK013`
  validator finding MUST continue to pass unmodified in its current form;
  this feature MUST NOT regress, relax, or bypass that guarantee.
- **FR-004**: System MUST extend the content model's anchor-validation family
  so that a Material carrying more than one anchor type at once (e.g. both a
  `VideoAnchor` and the new location anchor) is rejected as invalid,
  mirroring `CK013`'s existing precedent of rejecting a mismatched-anchor
  Material.
- **FR-005**: System MUST NOT require a `document`-kind Material to carry a
  `VideoAnchor`, and MUST NOT require a `video`-kind Material to carry the
  new location anchor — each `MaterialKind` uses the anchor type appropriate
  to its format, never the other's.
- **FR-006**: Authoring and ingestion pipelines (including spec 012's
  document ingestion and any text-only-chapter authoring flow) MUST be able
  to write `document`-kind Materials with the new location anchor into the
  same `curriculum/learning/NN-<slug>.json` authoring file format the
  existing catalog loader already reads, requiring no new file format and no
  second catalog loader.
- **FR-007**: System MUST NOT introduce a new `passagestore.Kind` to support
  document-sourced or text-only-chapter content; such content MUST ingest
  using the existing `doc_section` kind (or another existing kind, where
  more appropriate), using the passage store's existing open `Attrs` map for
  any format-specific metadata the new anchor type needs (e.g. page number,
  EPUB CFI, or chapter heading) rather than extending the closed `Kind`
  vocabulary.
- **FR-008**: A served lesson or material response MUST include, for a
  location-anchored Material, sufficient data for a client to seek a reader
  to the cited location, highlight the cited passage, and indicate its
  extent — the functional equivalent of what a `VideoAnchor` response
  already provides for seeking a player and scrolling a transcript.

**Phase 2 — Learner profile page**

- **FR-009**: System MUST expose a read-side API endpoint returning a
  learner's profile summary: identity, account age, and an overall
  completion percentage derived from existing per-area progress records.
- **FR-010**: System MUST expose a read-side API endpoint returning a
  learner's activity history as a single, reverse-chronological, paginated
  timeline merging reading-position updates and assessment/progress status
  transitions.
- **FR-011**: System MUST expose a read-side API endpoint returning a
  learner's per-area score/result history, structured for both chart
  rendering and per-area reporting.
- **FR-012**: System MUST expose a read-side API endpoint returning one
  area's full attempt/score history for a learner, sufficient to give
  context for a "retake self-assessment" action on that area.
- **FR-013**: None of the four endpoints in FR-009–FR-012 MUST introduce new
  persisted write-side state; each MUST read from existing progress,
  assessment, and (once available) adaptive-scoring stores rather than
  duplicating that data into a new store.
- **FR-014**: The profile page MUST render a single reverse-chronological
  activity history combining reading-position progress and
  assessment/progress status transitions, per FR-010.
- **FR-015**: The profile page MUST render per-area reports showing score,
  attempt count, and remaining requirements toward unlocking a retake (or
  equivalent completion-gating status), reusing existing per-area coverage
  and evidence data rather than re-deriving it independently.
- **FR-016**: The profile page MUST provide a "retake self-assessment"
  action per area the learner has already completed, that re-enters the
  existing assessment submission flow for that area, introducing no new
  grading, scoring, or gating logic.
- **FR-017**: Chart rendering on the profile page MUST default to hand-rolled
  inline SVG components, introducing no new frontend charting dependency,
  unless an explicit, documented decision supersedes this default because
  chart-type variety has outgrown what hand-rolled SVG can reasonably
  support (see Assumptions).
- **FR-018**: The profile page MUST render an explicit, non-error empty
  state for a learner with no recorded activity, for every section (header,
  activity, charts, reports) independently.
- **FR-019**: The profile page's scores/charts section MUST degrade
  gracefully — rendering a clear "not enough data yet" indicator, never an
  error or a broken chart — when the adaptive-scoring ability-score data
  source (spec 013) has no data yet for a given learner or area.
- **FR-020**: The "retake self-assessment" action MUST fail with an
  explicit, learner-visible reason when the target area is no longer
  available in the catalogue, rather than a generic error.

**Phase 3 — Cross-format reporting**

- **FR-021**: Once a learner has recorded activity across more than one
  material-source format (e.g. video-anchored and location-anchored), the
  profile page's reporting surface MUST be able to attribute and distinguish
  that activity by source format, at minimum for auditability — i.e. every
  data point contributing to a report MUST remain traceable back to the
  citation/anchor it came from.
- **FR-022**: System MUST [NEEDS CLARIFICATION: whether per-material-type
  progress is ever blended into a single unified score, or always
  presented per-format in the profile page's reports — the research names
  this as an explicitly open design question it did not resolve].

### Key Entities *(include if feature involves data)*

- **Location Anchor** (new, in `curriculum-kit`): A citation type for a
  `document`-kind Material, structurally parallel to `VideoAnchor`, carrying
  a chapter/section identifier, a location locator, and a passage reference.
  Resolves into an existing `doc_section`-kind passage record.
- **Material** (existing, extended): An authored unit of content within a
  Lesson, already typed by a closed `MaterialKind` vocabulary
  (`illustration`, `diagram`, `scheme`, `graph`, `video`, `document`). This
  feature adds a second anchor type a `document`-kind Material can carry,
  without changing `MaterialKind` itself.
- **Passage** (existing, in `passagestore`): The evidence/citation layer's
  searchable text unit, already typed by a closed `Kind` vocabulary
  (`transcript_segment`, `doc_section`, `code`, `diagram`, `screen_text`).
  This feature adds no new `Kind`.
- **Profile Summary**: A learner's identity, account age, and overall
  completion percentage — a read-side aggregation over existing per-area
  progress, not a new persisted record.
- **Activity Timeline Entry**: A single event in a learner's merged activity
  history — either a reading-position update or an assessment/progress
  status transition — with a timestamp, ordered deterministically.
- **Area Score/Attempt Record**: A learner's per-area result history (score,
  attempts, pass/fail, timestamp), read from the existing assessment store;
  not redefined by this feature.
- **Ability Score / Response Log Entry**: Data produced by the parallel
  adaptive-assessment-scoring feature (spec 013). This specification
  consumes that data as a read-only source for the profile page's
  scores/charts section once it exists; it does not define, redefine, or
  duplicate that data model.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A document-sourced or text-only-chapter Material can be cited
  by page/section location with citation fidelity structurally equivalent to
  what video Materials already have for time offsets (resolvable to a
  specific source passage, seekable, highlightable), demonstrated for at
  least one non-video content type end to end.
- **SC-002**: The content model's existing video-only-rejection validator
  behavior (`CK013`) continues to pass with zero regressions after this
  feature ships, verified by re-running the existing validator suite.
- **SC-003**: A learner can, from a single profile page, view their activity
  history, at least one chart, per-area reports, and use a working retake
  link — without navigating away from the page for any of these four
  elements.
- **SC-004**: All four new profile API endpoints operate using only existing
  data sources; zero new persisted data stores are introduced to deliver
  this feature.
- **SC-005**: A learner with no prior recorded activity sees an explicit,
  non-error empty state on every section of the profile page, verified for
  a fresh learner session.
- **SC-006**: 100% of previously-working video-material citation and
  deep-linking behavior continues to function unchanged after this feature
  ships, verified by re-testing existing video-anchored content.
- **SC-007**: A learner's activity-history feed, regardless of history size,
  renders its first page without the client needing to load the learner's
  entire history at once (pagination verified against a fixture with a
  history exceeding one page).
- **SC-008**: When usage data exists across at least two material-source
  formats for one learner, 100% of the data points a cross-format report
  draws on remain individually traceable back to their originating
  citation/anchor.

## Assumptions

- `submodules/curriculum-kit` is the correct and sole place to add the new
  location-anchor type — this is upstream work in the already-adopted,
  project-not-aware seam, not a workshop-local fork. Forking the content
  model locally instead would conflict with this umbrella's existing
  reuse-before-reimplement and anti-fork conventions.
- Spec 011 (multi-provider LLM providers) and spec 012 (document-ingestion
  textbooks) are separate, independently-scoped specifications. This
  specification does not duplicate either; it names the integration seam
  Phase 1 depends on (an ingestion pipeline writing `doc_section` passages
  plus a `document`-kind Material with the new anchor) without designing
  spec 012's ingestion pipeline itself.
- Spec 013 (adaptive-assessment-scoring)'s `AbilityScore`/`ResponseLogEntry`
  data model is assumed to land with a stable, read-only interface this
  feature's profile endpoints can consume once available. This specification
  does not define, redefine, or duplicate that data model, and the profile
  page is designed to degrade gracefully (FR-019) for as long as that data
  is unavailable.
- Whether `pkg/assessment`'s existing `Progress` records already carry a
  per-row timestamp sufficient for the activity-history endpoint (FR-010),
  or whether one needs to be added, is an implementation detail to confirm
  at build time, not a design decision this specification resolves.
- The Angular 19 frontend has no charting library today; hand-rolled inline
  SVG is the default per FR-017, consistent with this codebase's
  demonstrated minimal-dependency discipline elsewhere. `ngx-charts` remains
  an available fallback if chart-type variety grows beyond what hand-rolled
  SVG reasonably supports — introducing it is a deliberate, separately
  recorded decision, not a default.
- The profile page's learner-identity mechanism (anonymous per-browser
  session vs. authenticated account) follows whatever identity mechanism the
  platform uses generally at implementation time; this specification does
  not resolve or depend on the outcome of any in-flight
  anonymous-to-account migration, only on consuming whichever session
  identity is current.
- Exact chart types and metrics beyond the three the research names
  generically (a completion-over-time line, a per-area score bar chart, a
  streak calendar heat-map) are not fully specified here — see
  [NEEDS CLARIFICATION] in Edge Cases and FR-022's open question on blended
  vs. per-format scoring; both are genuine open design decisions, not
  oversights.
