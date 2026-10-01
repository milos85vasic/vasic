# Data Model: Universal Content Model (Position-Anchored Citations) and Learner Profile Page

**Input**: `spec.md`'s Key Entities section, `plan.md`'s Technical Context,
and the real current types in `submodules/curriculum-kit/pkg/curriculum/`
and `workshop/platform/backend/`.

**Cross-reference note (spec 012) — current resolution, superseding the
provisional reading from when spec 012 had only a `spec.md`.** Spec 012 now
has a `plan.md` and a `data-model.md` (`specs/012-document-ingestion-textbooks/`),
read directly for this update rather than assumed. Two things are resolved,
and they resolve DIFFERENTLY:

- **Type ownership: confirmed, no conflict.** Spec 015 is the specification
  that names "universal content model" as its own stated scope (spec.md's
  "Why this specification exists" section), and spec 012's own
  `data-model.md` (its "Cross-reference: the Location Anchor type and spec
  015" section) independently reaches the same conclusion by reading THIS
  document: spec 015 owns the `LocationAnchor` type definition; spec 012
  does not define it, redefine it, or depend on it for any of its own
  Functional Requirements. **This document remains the authoritative
  definition of the location/page anchor type.**
- **Data channel: spec 012 is the producer this document depends on, via
  its new FR-021 — not yet implemented.** The `doc_section`/`Attrs`
  passthrough this document's "Ingestion" section below describes is NOT
  something that already worked on the `passagestore` side (see the
  correction in that section): it is spec 012's own new FR-021, an
  additive, optional `sections[].attrs` field passed through unchanged into
  `Observation.Attrs` via a new `DocumentObservationOption`. This is a real
  cross-specification dependency, tracked as task T023 in this
  specification's own `tasks.md` (marked BLOCKED, consistent with how that
  document already marks the spec 013 dependency) and as task T006a in
  spec 012's `tasks.md`.

## Phase 1 — Location Anchor (curriculum-kit)

### `LocationAnchor` (new type, `pkg/curriculum/model.go`)

Structurally parallel to the existing `VideoAnchor` (same file, lines 62–98
today). Every field-for-field parallel is deliberate and named below so a
future reader does not have to diff the two types to see the mapping.

```go
// LocationAnchor points at a LOCATION inside a document-sourced chapter or
// text-only lesson, and at the place in that document's passage record which
// the location corresponds to.
//
// It is the page/location-anchored counterpart to VideoAnchor: where a video
// material cites a TIME RANGE plus a transcript-segment reference, a document
// material cites a POSITION plus a doc_section passage reference. The two
// types are deliberately NOT unified into one "anchor" type with an optional
// time half and an optional position half — that would make "an anchor with
// neither a time nor a position" a representable, meaningless state, which is
// exactly the kind of gap this package's own validator (CK010/CK028) exists
// to refuse. Two closed, fully-populated-or-absent types, exactly as
// VideoAnchor already is one.
type LocationAnchor struct {
	// SectionID identifies the document/chapter section in the CONSUMER's own
	// catalogue of documents. This package does not model document files; it
	// refers to them, exactly as VideoAnchor.ChapterID refers to a video
	// chapter without this package modelling video files.
	SectionID ID `json:"sectionId"`
	// Locator is the position within that section — a page number, an EPUB
	// CFI, a heading anchor, or any other consumer-defined position string.
	// It is a string rather than a typed page number because "position within
	// a document" has no single universal representation across formats
	// (a PDF page number and an EPUB CFI are not commensurable), and forcing
	// one here would make this package format-aware in exactly the way its
	// own package doc forbids ("Nothing in this package may name a concept
	// belonging to a consuming application").
	Locator string `json:"locator"`
	// PassageAnchor is an opaque handle the consumer resolves against its own
	// passage store so a reader can be scrolled to, and the cited passage
	// highlighted. Parallel to VideoAnchor.TranscriptAnchor field-for-field,
	// including the reason it is a string rather than a structured reference:
	// a document corpus is re-ingested exactly as a transcript is re-run, and
	// a structured reference would rot the same way a line number would.
	PassageAnchor string `json:"passageAnchor"`
}
```

No `Start()`/`End()`/`Length()` helpers, unlike `VideoAnchor`: those exist
because `VideoAnchor` stores milliseconds and needs a typed `time.Duration`
accessor for Go callers. `LocationAnchor` has no time dimension to convert,
so there is nothing for an equivalent helper to do.

### `Material` (existing type, extended)

```go
type Material struct {
	ID   ID           `json:"id"`
	Kind MaterialKind `json:"kind"`
	Title string      `json:"title"`
	Caption string    `json:"caption,omitempty"`
	URI string        `json:"uri"`
	Alt string        `json:"alt,omitempty"`
	// Video is set for, and only for, KindVideo. UNCHANGED.
	Video *VideoAnchor `json:"video,omitempty"`
	// Location is set for, and only for, KindDocument. NEW.
	Location *LocationAnchor `json:"location,omitempty"`
}
```

`MaterialKind` itself is **unchanged** — no new kind is added (FR-005 already
forbids requiring the new anchor from `video`-kind Materials, and spec.md's
Key Entities section is explicit: "without changing `MaterialKind` itself").
`KindDocument` already exists in the closed vocabulary
(`illustration`, `diagram`, `scheme`, `graph`, `video`, `document`).

### Validator rules (`pkg/curriculum/validate.go`)

New rule codes, continuing the existing `CK0NN` sequence (current highest is
`CK027`; `CK900` is the one existing undetermined code):

| Code | Severity | Mirrors | Condition |
|---|---|---|---|
| `CK028` `CodeDocumentNoLocation` | finding | `CK010` `CodeVideoNoRange` | A `document`-kind Material has no `Location` anchor, or the anchor's `SectionID`/`Locator`/`PassageAnchor` is empty. Closes spec.md's Edge Case 2 ("no citation at all"). |
| `CK029` `CodeLocationOnNonDocument` | finding | `CK013` `CodeVideoOnNonVideo` | A Material of any kind other than `document` carries a non-nil `Location` anchor. |
| `CK030` `CodeDualAnchor` | finding | — (new; FR-004, Edge Case 3) | A Material carries **both** a non-nil `Video` anchor and a non-nil `Location` anchor at once, regardless of `Kind`. |
| `CK031` `CodeUnknownSection` | finding | `CK024` `CodeUnknownChapter` | A `Location.SectionID` is not present in a supplied `Options.KnownSections` registry. |
| `CK901` `CodeSectionsUnresolved` | **undetermined** | `CK900` `CodeChaptersUnresolved` | No `Options.KnownSections` map was supplied at all — same three-valued discipline `CK900` already applies to an absent `KnownChapters`: absence of evidence is reported as absence of evidence, never as a silent pass. |

**`CK013`'s existing finding and message are unchanged, verbatim** (FR-003 /
SC-002). The validator's `material()` function grows a new case for
`KindDocument` alongside its existing `KindVideo` branch; the existing
`if m.Kind != KindVideo { if m.Video != nil { ... CodeVideoOnNonVideo ... } }`
branch is preserved exactly as written today — a `document`-kind Material
carrying a stray `VideoAnchor` still produces the same `CK013` finding with
the same message it does today, and a new regression test
(`TestCK013UnchangedAfterLocationAnchor` or equivalent) asserts this by
running the existing `CK013` fixture through the extended validator and
diffing the finding against today's captured output.

`Options` gains one new field, parallel to `KnownChapters`:

```go
type Options struct {
	KnownChapters map[ID]bool // UNCHANGED
	// KnownSections is the set of document/chapter section ids the CONSUMER
	// can resolve, exactly parallel to KnownChapters. Nil → every location
	// material produces an UNDETERMINED (CK901) row, never a silent pass.
	KnownSections map[ID]bool // NEW
}
```

### Ingestion: no new `passagestore.Kind` (FR-007); the `Attrs` passthrough is a spec 012 cross-spec dependency, NOT already-working today

`LocationAnchor.PassageAnchor` resolves to an **existing**
`passagestore.KindDocSection` (`"doc_section"`) record — the same kind
already declared in `workshop/platform/backend/internal/passagestore/domain.go`
(line 55) and already used, per `passagestore`'s own comment, for exactly
this purpose ("the validator ... actively rejects a video-only assumption").
No new `passagestore.Kind` is introduced by this feature — that half of this
section's claim stands unchanged.

**Correction, made while grounding this document in the real code rather
than in a prior draft's assumption:** format-specific metadata a location
anchor needs beyond what `doc_section` already carries (a page number, an
EPUB CFI, a chapter heading) is meant to go in the passage record's open
`Attrs map[string]string` field — the same mechanism `transcript_segment`
already uses for `AttrTEndS`/`AttrSpeaker` (domain.go lines 99–102) — but
**the field existing on `passage.Observation` is not the same thing as a
channel existing to POPULATE it from ingestion input, and this document
previously conflated the two.** Reading the real ingestion signatures
(`workshop/platform/backend/cmd/ingest-transcript/main.go`'s `docSection`
struct, six fields — `PID`/`Text`/`Path`/`LineStart`/`LineEnd`/`Kind`, no
`Attrs` — and `internal/passagestore/domain.go`'s
`DocumentObservation(chapterSlug, text string, kind passage.Kind, ref
passage.SourceRef) passage.Observation`, which takes no parameter through
which `Attrs` could be set) shows there is **no channel today**. The
`Observation.Attrs` field exists on the type and is simply left at its zero
value by every current ingestion path.

**This is now spec 012's own new FR-021** (`specs/012-document-ingestion-textbooks/spec.md`,
and its `data-model.md`'s "Extraction Sidecar" section), a cross-spec
dependency this specification depends on rather than something it can
assume already works: an additive, optional `sections[].attrs` field on the
Extraction Sidecar payload, passed through unchanged into
`Observation.Attrs` via a new `DocumentObservationOption`/`WithAttrs`
functional option — chosen over a new required positional parameter
specifically because `DocumentObservation` has 9 existing call sites that
must keep compiling unmodified. **Not yet implemented** — tracked as task
T006a in spec 012's `tasks.md` and as the BLOCKED task T023 in this
specification's own `tasks.md`. No `passagestore` code change is required
by *this* feature (015) directly; spec 012's ingestion pipeline (or a
future text-only-chapter authoring flow) is the producer that will write
these `Attrs` keys, once spec 012's FR-021 lands (note: this specification's
own `spec.md` separately defines an unrelated FR-021 of its own, about
blended per-format scoring — the two are different requirements in
different specs and the number collision is coincidental). This document
does not name the
exact `Attrs` key names (`page`, `cfi`, `heading`, or otherwise) — that
remains spec 012's ingestion-pipeline decision to make against its own real
source documents, consistent with this spec's own Assumptions section ("it
names the integration seam ... without designing spec 012's ingestion
pipeline itself").

### Wire shape (`pkg/learning/wire.go`, `MaterialObject`)

`MaterialObject` gains a `"location"` key, following the exact
null-until-resolved discipline the existing `"video"` key already
establishes (see `wire.go` lines 74–119):

```go
out["location"] = nil // default, mirrors out["video"] = nil above
// ... after the Kind == KindDocument / m.Location != nil check:
loc := map[string]any{
	"section_id":     string(l.SectionID),
	"locator":        l.Locator,
	"passage_anchor": l.PassageAnchor,
	// section_slug and href are null until RESOLVED, exactly as chapter_slug
	// and href are null until a video anchor's chapter resolves.
	"section_slug": nil,
	"href":         nil,
	"link_grammar": "platform/frontend/docs/document-links.md",
}
out["location"] = loc
if sections == nil { loc["unresolved_reason"] = "no section roster was supplied to the renderer"; return out }
slug, ok := sections.SectionSlugFor(string(l.SectionID))
if !ok { loc["unresolved_reason"] = "this server serves no document section with that id"; return out }
loc["section_slug"] = slug
loc["href"] = DocumentLink(slug, l.Locator, l.PassageAnchor) // new, parallel to TimeLink
```

A new `DocumentSectionResolver` interface, parallel to `ChapterResolver`:

```go
// DocumentSectionResolver maps a curriculum-kit LocationAnchor.SectionID onto
// a document section slug this server actually serves, and reports whether
// it could — parallel to ChapterResolver field-for-field.
type DocumentSectionResolver interface {
	SectionSlugFor(sectionID string) (string, bool)
}
```

The URL grammar itself (`DocumentLink`'s output shape, the counterpart to
`/chapters/<slug>/transcript?t=<seconds>&end=<seconds>[#p-<pid>]`) is an
implementation decision for the task that builds `platform/frontend/docs/
document-links.md` — plausibly
`/documents/<section-slug>/read?loc=<locator>[#p-<pid>]`, but that exact
grammar is not fixed by this design document; it is fixed by the contract
file itself, the same way `time-links.md` is `MaterialObject`'s producer
contract rather than something invented ad hoc in `wire.go`.

## Phase 2 — Learner Profile Page

### Profile Summary

Read-side aggregation, **not** a new persisted record (FR-013/SC-004).

```json
{
  "session_or_user": "<opaque progress key, same identity sessionOf() resolves>",
  "account_age": null,
  "completion_percent": 0
}
```

**Correction, found while grounding this document in the real schema (the
`authstore.go` file itself, not just the Go struct) — the claim this section
previously carried, that `account_age` has no backing data source and that
adding one is a schema migration excluded by FR-013, was WRONG:**

`workshop/platform/backend/pkg/authstore.User` is
`{ID int64, Username string, PasswordHash string, Role string}` — no
`CreatedAt` field, correct as far as it goes. But the **database already has
the data**: `authstore.go`'s `schema` constant declares
`CREATE TABLE IF NOT EXISTS auth_user (... created_at TEXT NOT NULL,
last_login TEXT)` (`authstore.go:44-47`), and `seed()`'s
`INSERT INTO auth_user(username, password_hash, role, created_at)` populates
it on every insert (`authstore.go:159-166`), including both mandated seed
accounts. The gap is narrower than previously stated:
the Go `User` struct has no `CreatedAt` field, and neither
`UserByUsername` nor `UserByTokenHash` selects the column
(`authstore.go:172`, `authstore.go:227-228` both read only
`id, username, password_hash, role` / `id, username, role`). **This is a
small, in-scope, READ-SIDE addition — add the struct field, add the column
to the two existing `SELECT`s — not a schema migration, and it is NOT
excluded by FR-013**: FR-013 forbids introducing new **persisted** state
("none of the four endpoints ... MUST introduce new persisted write-side
state"), and reading an already-persisted, already-populated column
introduces no new persisted state at all.

An anonymous (pre-auth, `X-Session`-only) caller genuinely has no account
record — only an opaque client-chosen string — so `account_age` correctly
stays `null` for that caller regardless of this fix; that half of the
original gap was accurate and is unchanged.

**Design decision, corrected:** once this small addition lands, `account_age`
is computed from `CreatedAt` for every AUTHENTICATED caller and remains
`null` only for an anonymous, `X-Session`-only caller with no account row —
`null` is the correct wire value describing "no account to report an age
for," not a permanent stand-in for "this server cannot compute account age
at all." Before this fix lands, `account_age` is `null` for every caller,
authenticated or not, and the field is still named on the wire (FR-009
requires it) rather than silently omitted, per this codebase's own
established convention (`MaterialObject`'s `chapter_slug`/`href`: "null...
distinguishable from a link that happens to be wrong"). `completion_percent`
**is** derivable today: the same aggregation `LessonCompletionFromDeps`
(`lessons.go`) already performs per-area, summed and weighted across
`d.Catalog.Areas`.

### Activity Timeline Entry

**Design decision, grounded in the timestamp gap `plan.md` names:** the
activity-history endpoint (FR-010) merges the **two** event sources that
actually carry a per-event timestamp today, not three:

1. **Reading-position updates** — `internal/api.Position` (`ChapterSlug`,
   `PID`, `TSeconds`, `At` — `progress.json`, read via
   `internal/api.ProgressStore.Get`). Each stored position already IS one
   event with a real timestamp (the `PUT` time).
2. **Assessment attempts** — `ckit.Attempt` (`AssessmentID`, `At`, `Percent`,
   `MarkedPercent`, `Passed`, `Determinate` — `learning-progress.json`,
   read via `pkg/learning.SessionStore.Get` → `ckit.Progress.AttemptsFor`).
   Each recorded attempt already IS one event with a real timestamp (the
   submission time `AssessmentSubmitHandler` stamps via `nowUTC()`).

**What is explicitly NOT a timeline event source, and why:** a lesson
state transition (`not-started` → `in-progress` → `complete`,
`ckit.Progress.Lessons map[ID]LessonState`) is a **snapshot field**, not a
logged event — there is no historical record of when a lesson's state last
changed, only what it currently is. Spec.md's own FR-010 wording ("merging
reading-position updates and assessment/progress status transitions") is
satisfied by reading "assessment/progress status transitions" as "assessment
ATTEMPT events" (which genuinely transition and are genuinely timestamped),
not as "lesson-completion transitions" (which are not). A wire shape:

```json
{
  "kind": "reading_position",
  "at": "2026-09-30T12:00:00Z",
  "chapter_slug": "02",
  "pid": "01J...",
  "t_seconds": 512.0
}
```

```json
{
  "kind": "assessment_attempt",
  "at": "2026-09-30T12:05:00Z",
  "area_id": "01J...",
  "assessment_id": "01J...",
  "percent": 84,
  "marked_percent": 84,
  "passed": true,
  "determinate": true
}
```

Merged, sorted descending by `at`, paginated (SC-007). **Deterministic
same-timestamp ordering** (spec.md Edge Case): sort key is `(at DESC, kind
ASC, id ASC)` — `kind` before `id` so the tie-break is itself deterministic
and does not depend on map iteration order (`ckit.Progress.Attempts` is a
Go map; `lessons.go`'s own `attemptObjects` already sorts its slice by `at`
for exactly this reason — this endpoint extends that same discipline to a
merged, two-source stream).

### Area Score/Attempt Record

Read directly from `ckit.Progress.AttemptsFor(areaID's assessment ID)` —
**not redefined**, per spec.md's Key Entities section. `FR-011`'s per-area
chart/report structure and `FR-012`'s single-area detail both project this
existing `[]ckit.Attempt` plus `ckit.Completion(area, progress)` (lesson
tallies) and `ckit.AvailabilityOf(area, progress)` (retake gating state) —
all three already exist and are already used by `AssessmentHandler` in
`lessons.go`. No new scoring, grading, or availability logic (FR-016).

### Ability Score / Response Log Entry (spec 013)

**Not defined here.** Consumed, once it exists, as an opaque read-only
source per spec.md's own Assumptions ("This specification does not define,
redefine, or duplicate that data model"). The profile reports endpoint
(FR-011) queries it defensively: absence of a spec-013 data source is a
determined "not enough data yet" state (FR-019), never an error — the same
`nil`-source-degrades-to-omitted-field discipline `LessonCompletionSource`
already establishes in `internal/api/progress.go` ("A completion-source
failure is deliberately NOT escalated to a 503 for the whole route").

## Key entity summary table

| Entity | New / Existing | Backing store | This feature's scope |
|---|---|---|---|
| `LocationAnchor` | **New** | n/a (value type on `Material`) | Defined here, Phase 1 |
| `Material.Location` | **New field** | `curriculum/learning/NN-<slug>.json` (authoring file, unchanged format) | Defined here, Phase 1 |
| `Passage` (`doc_section` kind) | Existing | `curriculum/passages.jsonl` | Consumed unchanged, no new `Kind` |
| Profile Summary | **New** (read-side aggregation) | `learning-progress.json` + `progress.json`; `account_age` has **no** source yet | Defined here, Phase 2 |
| Activity Timeline Entry | **New** (read-side merge) | `progress.json` (`Position.At`) + `learning-progress.json` (`Attempt.At`) | Defined here, Phase 2 |
| Area Score/Attempt Record | Existing (`ckit.Attempt`) | `learning-progress.json` | Consumed unchanged |
| Ability Score / Response Log Entry | Existing (spec 013, external) | spec 013's store (not this feature's) | Consumed defensively, not defined |
