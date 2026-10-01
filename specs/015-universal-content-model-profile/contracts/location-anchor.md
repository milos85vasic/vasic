# Contract: `LocationAnchor` (curriculum-kit)

This is the Phase 1 producer contract: what `submodules/curriculum-kit`
guarantees to any consumer (this project's `pkg/learning`, and spec 012's
ingestion pipeline) once `LocationAnchor` lands. It is the FR-001–FR-008
counterpart to the existing, unwritten-down-because-it-didn't-need-to-be-yet
contract `VideoAnchor` already satisfies.

## Type contract

```go
package curriculum // github.com/vasic-digital/curriculum-kit/pkg/curriculum

type LocationAnchor struct {
	SectionID     ID     `json:"sectionId"`
	Locator       string `json:"locator"`
	PassageAnchor string `json:"passageAnchor"`
}

type Material struct {
	// ... existing fields unchanged ...
	Video    *VideoAnchor    `json:"video,omitempty"`    // unchanged
	Location *LocationAnchor `json:"location,omitempty"` // NEW
}
```

**Guarantee 1 — symmetry with `VideoAnchor` (FR-001).** Every field on
`VideoAnchor` that names "which chapter" (`ChapterID`), "where in it"
(`StartMillis`/`EndMillis`), and "what passage it resolves to"
(`TranscriptAnchor`) has a direct counterpart on `LocationAnchor`
(`SectionID`, `Locator`, `PassageAnchor` respectively) — see `data-model.md`
for the field-by-field mapping and the reasoning for each divergence (no
`Start()`/`End()`/`Length()` helpers; `Locator` is a string, not a typed
offset).

**Guarantee 2 — one resolution mechanism, not two (FR-002).** `PassageAnchor`
resolves against the SAME passage store `TranscriptAnchor` resolves against
today (an opaque handle a CONSUMER resolves, per both types' own doc
comments — this package "does not fetch it and makes no claim about what is
behind it", same as `Material.URI`). `curriculum-kit` adds no second
resolution path, no second passage registry, and no second "how do I turn
this handle into a link" mechanism.

**Guarantee 3 — `CK013` is unchanged (FR-003).** A `VideoAnchor` on a
non-`video` Material produces the exact same `CK013` finding, with the exact
same message text, that it does before this feature ships. This is asserted
by a regression test, not merely claimed — see `quickstart.md`.

**Guarantee 4 — at most one anchor, ever (FR-004).** A Material carrying both
`Video` and `Location` non-nil is rejected by a new finding (`CK030`
`CodeDualAnchor`), regardless of `Kind`. Message shape (mirroring `CK013`'s
own wording style):

> `material of kind "<kind>" carries both a video anchor and a location anchor — a citation mechanism must be unambiguous`

**Guarantee 5 — no cross-kind requirement (FR-005).** `ValidateWith` never
requires a `document`-kind Material to carry `Video`, and never requires a
`video`-kind Material to carry `Location`. (It DOES require a `document`-kind
Material to carry SOME anchor — see Guarantee 7 below, which is the new,
symmetric half of what `video` already required.)

**Guarantee 6 — no new authoring file format (FR-006).** `LocationAnchor`
decodes from, and is validated inside, the exact same
`curriculum/learning/NN-<slug>.json` `Document` shape the existing loader
(`curriculum-kit`'s `DecodeDocument`, per spec 004's plan) already reads. No
second catalog loader is introduced by this feature, in `curriculum-kit` or
in `pkg/learning`.

**Guarantee 7 — symmetric completeness requirement.** Exactly as a
`video`-kind Material with a nil or incomplete `Video` anchor produces
`CK010` `CodeVideoNoRange`, a `document`-kind Material with a nil or
incomplete `Location` anchor (empty `SectionID`, empty `Locator`, or empty
`PassageAnchor`) produces `CK028` `CodeDocumentNoLocation`. This closes
spec.md's Edge Case 2 ("a `document`-kind Material authored with neither a
`VideoAnchor` nor the new location anchor ... MUST be treated the same way
the content model already treats any other structurally incomplete
Material").

**Guarantee 8 — no new `passagestore.Kind` (FR-007).** `curriculum-kit`
itself never touches `passagestore` at all (it is project-not-aware and has
an empty `require` set — see `curriculum-kit/CLAUDE.md`'s module-local rule
1). This guarantee is really a constraint on the CONSUMER: `PassageAnchor`
is documented (in `data-model.md`) as expected to resolve to an existing
`passagestore.KindDocSection` record, with format metadata in that record's
existing `Attrs` map — not as a new `passagestore.Kind`.

**Guarantee 9 — served response carries seek/highlight/extent data
(FR-008).** This guarantee is discharged by the CONSUMER (`pkg/learning`'s
`MaterialObject`, per `data-model.md`'s wire-shape section), not by
`curriculum-kit` itself, which owns no transport. `curriculum-kit`'s part of
the guarantee is that `LocationAnchor` carries every field a renderer needs
to construct such a response: `SectionID` (which section to open),
`Locator` (where in it), `PassageAnchor` (what to highlight). Nothing about
"extent" (how much text the passage spans) is carried on `LocationAnchor`
itself — that is a property of the resolved `doc_section` passage record
(its own `Attrs`/span fields), exactly as `VideoAnchor`'s own extent comes
from `EndMillis - StartMillis`, a property of the anchor, while a video
material's TRANSCRIPT extent comes from the resolved
`transcript_segment` passage, not from `VideoAnchor` itself. The two are
therefore symmetric: `LocationAnchor` itself carries no independent
"how long is this passage" field either, matching `VideoAnchor`'s own design
(which DOES carry `EndMillis-StartMillis` because that IS the citation's
own extent, for a video range — a document citation's extent is a property
of the resolved passage, not of the anchor, because a page locator has no
natural "length").

## Validator contract (`ValidateWith`)

| Input | Output |
|---|---|
| `document`-kind Material, complete `Location`, `Options.KnownSections` containing its `SectionID` | No finding for this Material |
| `document`-kind Material, complete `Location`, `Options.KnownSections == nil` | `CK901` `CodeSectionsUnresolved` (undetermined, not a finding) |
| `document`-kind Material, complete `Location`, `Options.KnownSections` NOT containing its `SectionID` | `CK031` `CodeUnknownSection` (finding) |
| `document`-kind Material, nil `Location` | `CK028` `CodeDocumentNoLocation` (finding) |
| `document`-kind Material, `Location` with an empty field | `CK028` `CodeDocumentNoLocation` (finding) |
| `video`-kind Material, non-nil `Location` | `CK029` `CodeLocationOnNonDocument` (finding) |
| any non-`document`, non-`video` kind, non-nil `Location` | `CK029` `CodeLocationOnNonDocument` (finding) |
| any kind, both `Video` and `Location` non-nil | `CK030` `CodeDualAnchor` (finding) — in addition to whichever of the above also applies |
| `video`-kind Material, complete `Video`, nil `Location` (existing behaviour) | **unchanged**: no new finding |
| non-`video` kind carrying `Video` (existing `CK013` case) | **unchanged**: `CK013` `CodeVideoOnNonVideo`, same message |

`Report.Verdict()`'s existing three-valued precedence (finding outranks
undetermined) is unmodified — a catalog with both a `CK030` finding and a
`CK901` undetermined row on different Materials still verdicts `1`, never
`2`, exactly as today.
