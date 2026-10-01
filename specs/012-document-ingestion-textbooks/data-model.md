# Data Model: Document Ingestion for Textbooks (EPUB / PDF / FB2 / Other Formats)

Derived from [spec.md](spec.md)'s Key Entities section and the research's
own `{text, path, line_start, line_end, kind}` shape
(`document-ingestion-architecture.md` §1.3, §1.4, §4). No new persistent
storage is introduced — every entity below is either a shape appended to the
existing `curriculum/passages.jsonl` registry via the existing
`ingest-transcript -docs` sync, or a discovery-time/operator-recorded
concept that is not minted as its own passage row.

## Textbook Source Document (discovery-time concept, not a minted entity)

The input file being ingested — EPUB in Phase 1; PDF, FB2, DOCX, HTML added
in Phase 2, per spec.md's Assumptions.

| Field | Type | Notes |
|---|---|---|
| `path` | string | The EPUB file's path, operator-provided. Not committed to the public umbrella; lives under `workshop/curriculum/textbook-<slug>/` or wherever the operator stages it, matching the private-content boundary the rest of `workshop`'s corpus already observes. |
| `slug` | string | Derived from the textbook's title/metadata (from the EPUB's OPF `<dc:title>`, per `read_opf()` in the POC) or operator-supplied; feeds the `textbook-<slug>` Registry Scope (FR-006). |
| `format` | string constant | `"epub"` in Phase 1; `"pdf"`, `"fb2"`, `"docx"`, `"html"` added in Phase 2 (FR-013–FR-016). |
| `license_record` | see below | Required before ingestion; its absence refuses the entire run (FR-005). |

## License Record (operator-recorded, gates ingestion; not itself a passage)

An explicit statement of a textbook's license/permission basis, recorded
**before** ingestion is attempted. FR-005 requires this field to be present
and refuses the run otherwise; it does **not** yet require this plan to
finalize the accepted-value enum — see "Carried-forward NEEDS CLARIFICATION"
below.

| Field | Type | Notes |
|---|---|---|
| `basis` | string | Operator-recorded. Named examples from spec.md (not yet a finalized closed vocabulary): public domain, openly-licensed OER (e.g. CC-BY), explicit rights-holder permission. `[NEEDS CLARIFICATION: FR-005]` — the accepted-value list and any verification mechanism are not decided by this plan. |
| `recorded_by` | string | Operator identity, for audit purposes — mirrors how other operator-gated actions in this pipeline (e.g. `workshop` module rule 2's manifest-regeneration discipline) keep a record of who made a judgment call, not just that one was made. |
| `recorded_at` | ISO 8601 timestamp | When the basis was recorded. |

Distinct from, and never served by, the existing
`redactions.jsonl`/disclosure-judgement suppression mechanism, per spec.md's
own Key Entities note — that mechanism is a content-removal tool built for
withholding named third parties' private speech from the corpus, not a
copyright-compliance tool, and this feature does not repurpose it as one.

**Where this record lives is an implementation detail Phase 1 must still
pick** (a sidecar JSON file beside the EPUB, a field inside
`epub_sections.py`'s own sidecar output, or a small dedicated registry) —
not specified further here because spec.md itself does not mandate a
storage shape for it, only that its absence refuses ingestion.

## Extraction Sidecar (new, per-textbook; the single interface every downstream stage consumes)

The `epub_sections.py` extractor's JSON output. **Byte-for-byte the same
shape** `pipeline/md_sections.py` already produces and
`platform/backend/cmd/ingest-transcript`'s `-docs` flag already consumes —
verified this session against `main.go`'s `docPayload` decode shape and
against the POC's own captured output
(`document-ingestion-architecture.md` §4.1, §4.2).

```json
{
  "chapter_slug": "textbook-<slug>",
  "source_file": "<epub filename>",
  "sections": [
    {
      "text": "<heading>\n\n<body>",
      "path": "<epub filename>#<spine href>",
      "line_start": 0,
      "line_end": 2,
      "kind": "doc_section",
      "pid": "<ULID, once carried — written back by ingest-transcript after first sync>",
      "attrs": {"epub_cfi": "<optional, format-specific location metadata — not populated by Phase 1's EPUB extractor>"}
    }
  ]
}
```

| Field | Type | Notes |
|---|---|---|
| `chapter_slug` | string | `textbook-<slug>` — NOT a `ChapterID`-shaped value (FR-006). Reused verbatim as the field name `ingest-transcript` already decodes; the value's shape is what changes, not the field. |
| `source_file` | string | The EPUB's filename, recorded so a citation can name its origin. |
| `sections[].text` | string | Heading + body, heading-delimited per FR-003, stub-filtered at the same `MIN_CHARS = 120` threshold `md_sections.py` uses. |
| `sections[].path` | string | `"<epub filename>#<spine href>"` — mirrors the POC's `path_label` convention exactly (`epub_extract_poc.py:423`), giving every section a stable, human-readable origin string. |
| `sections[].line_start` / `line_end` | integer | **Block ordinals within the XHTML document, not text-file line numbers** — the same repurposing `ingest-transcript`'s own transcript-segment handling already documents (`main.go:363-375`: *"a segment has no line of its own to anchor. Identity travels instead through this payload's own 'pid' field"*) and the POC already applies to EPUB (`epub_extract_poc.py:326-334`). |
| `sections[].kind` | string constant | `"doc_section"` — no new `passagestore.Kind` is introduced (FR-020's constraint, and the research's §3.2 finding that this kind already has full headroom for prose with no timespan). |
| `sections[].pid` | string (ULID), once carried | Absent on first extraction; written back into this sidecar by `ingest-transcript` after a successful sync, then read back as the anchor on the next run — the exact mechanism `md_sections.py`'s own header documents and FR-007 requires this extractor to reuse unmodified. |
| `sections[].attrs` | `map[string]string`, optional (FR-021, NEW) | Absent today from every Phase 1 EPUB section and from every existing `md_sections.py`-produced sidecar. When a producer supplies it, `ingest-transcript -docs` passes it through **unchanged** into the minted passage's `Observation.Attrs` (`passagestore.DocumentObservation`, `internal/passagestore/domain.go:538`, verified this session: today's signature is `DocumentObservation(chapterSlug, text string, kind passage.Kind, ref passage.SourceRef) passage.Observation` — six named fields on `docSection` (`PID`/`Text`/`Path`/`LineStart`/`LineEnd`/`Kind`, `main.go:102-109`), **no** `Attrs` field, and no parameter on `DocumentObservation` through which one could be set; `passage.Observation.Attrs map[string]string` already exists as an open field on the type, just never populated from ingestion input). This field does not itself name which keys a producer should write (`page`, `epub_cfi`, `heading`, …) — that is each format extractor's own decision against its real source format, exactly as spec 015's `data-model.md` states for the consuming side. |

**Go signature change this FR requires, consistent with this codebase's own established convention** (`internal/passagestore/domain.go` already uses the functional-option pattern elsewhere in this package's sibling files — `pkg/embed/embed.go`'s `OllamaOption`/`WithTimeout`/`WithPrefix`, `submodules/passage/pkg/passage/registry.go`'s `SyncOption`/`WithKeyStrategy`, `pid.go`'s `MinterOption`/`WithClock` — rather than a positional-parameter change, because `DocumentObservation` has 9 existing call sites across `corpus.go`, `main.go` and 6 test files, and a new required positional parameter would break all of them for no reason):

```go
// docSection (main.go:102) gains one optional field:
type docSection struct {
	PID       string            `json:"pid,omitempty"`
	Text      string            `json:"text"`
	Path      string            `json:"path"`
	LineStart int               `json:"line_start"`
	LineEnd   int               `json:"line_end"`
	Kind      string            `json:"kind"`
	Attrs     map[string]string `json:"attrs,omitempty"` // NEW, FR-021
}

// DocumentObservation (internal/passagestore/domain.go:538) gains a variadic
// option, following this package's own file's neighboring convention:
type DocumentObservationOption func(*passage.Observation)

func WithAttrs(attrs map[string]string) DocumentObservationOption {
	return func(o *passage.Observation) { o.Attrs = attrs }
}

func DocumentObservation(chapterSlug, text string, kind passage.Kind,
	ref passage.SourceRef, opts ...DocumentObservationOption) passage.Observation {
	// ... unchanged body, then:
	// for _, opt := range opts { opt(&obs) }
}
```

Every existing call site (9, verified this session: `corpus.go:207`, `main.go:426`,
`suggest_unavailable_log_test.go:119`, `floor_population_test.go:78,80`,
`suggest_cache_test.go:42`, `catalog_test.go:603,606`, `filter_pushdown_test.go:94`)
continues to compile unmodified — `opts` is optional and absent Attrs stays the
zero-value `map[string]string(nil)` exactly as today.

## doc_section passage (existing, reused; no new fields, no new kind)

The passage-store record every extracted section mints into, via
`ingest-transcript -docs`. Already validated to carry no timespan
(`passagestore.domain.go:256-258`, cited in the research §3.2) and already
servable from `/passage/{pid}` and indexed into FTS5/semantic search
identically regardless of source format. This feature adds **zero** new
fields and **zero** new `Kind` values to this existing entity — it is simply
a new, format-specific *producer* of rows already shaped exactly like every
`doc_section` row `md_sections.py` already mints.

## Registry Scope (existing mechanism, new value pattern)

The citable corpus partition a textbook's sections mint under.

| Field | Type | Notes |
|---|---|---|
| value pattern | string | `textbook-<slug>` — validated by the existing generic `SafeSlug` allowlist (`curriculum.go:205-221`: letters/digits/`-_.`, ≤128 chars, no path separators), **not** by the stricter `ChapterIDGrammar` (`^[0-9]{2,}(\.[0-9]{2,})*$`). This is an existing validator already accepting this shape today, with zero validator changes required (FR-006, research §3.2). |

`/api/chapters` lists only true `ChapterID`-shaped scopes and therefore
correctly continues to exclude every `textbook-<slug>` scope from the
chapter listing (SC-005) — a textbook is never mistaken for a recorded
teaching session.

## Extraction Failure Report (Phase 3; not a persisted passage)

A per-run, explicit list of sections/pages/documents that produced no
usable text, reported alongside — never instead of — the count of
successfully ingested sections (FR-017, FR-018).

| Field | Type | Notes |
|---|---|---|
| `succeeded_count` | integer | Sections successfully extracted and minted this run. |
| `failures[]` | array of objects | One entry per document/page/section that produced no usable text. |
| `failures[].source` | string | The spine document, page, or section that failed. |
| `failures[].reason` | string | e.g. `"malformed XHTML"`, `"no text layer, OCR unavailable"`, `"DRM-protected, cannot parse"` — a named, specific reason, never a bare boolean. |

Not built in Phase 1 (this is explicitly Phase 3 scope, FR-017/FR-018/FR-019,
SC-008/SC-009); recorded here now so Phase 1's sidecar shape does not need a
breaking change to add it later — the shape above already has room for a
sibling `_failures` key at the sidecar's top level, following the exact
pattern the POC's own `_poc_spine_report` diagnostic key (stripped before
writing the real ingest payload) already demonstrates for "extra, non-`-docs`
-consumed diagnostic data living beside the real payload."

---

## Cross-reference: the Location Anchor type and spec 015 — ownership resolved, not redefined here

Spec.md's own Assumptions section explicitly flags that "a page/location-
anchored citation type" is the one structural gap the research identifies,
and both spec 012's research and **spec 015**
(`specs/015-universal-content-model-profile/spec.md`) independently name the
same gap. **This section states the current, resolved division of labor —
not the provisional reading from when spec 015 had only a `spec.md`:**

**Type ownership — resolved, no conflict.** Spec 015 owns the `LocationAnchor`
type definition (`curriculum-kit`'s `pkg/curriculum/model.go`), confirmed by
reading spec 015's own `data-model.md` directly rather than inferring it from
`spec.md` alone. Spec 012 does not define it, redefine it, or depend on it for
any of its own Functional Requirements: every FR-001 through FR-021 in this
spec is scoped to the `ingest-transcript -docs` → `index-embed` → `doc_section`
passage → `/passage/{pid}` pipeline, which is **entirely downstream of, and
independent from,** `curriculum-kit`'s `Material`/lesson-authoring layer. A
textbook's `doc_section` sections are fully searchable and citable via
`/passage/{pid}` (SC-001, SC-005, SC-006) with **zero** involvement from
`curriculum-kit` — authoring a `document`-kind `Material` that cites one of
those sections via a Location Anchor is a separate, later, human-curation
action (spec 015's own scope, or a future lesson-authoring flow), not
something Phase 1 of spec 012 performs or requires.

**Data channel — resolved differently from the type: spec 012 is now the
producer spec 015 depends on, via this document's own new FR-021.** Where
spec 015's `data-model.md` once stated the `Attrs` passthrough as something
that "already" existed on the `passagestore` side, reading the real
`docSection`/`DocumentObservation` signatures (this document's own
"Extraction Sidecar" table, above) showed no channel existed at all —
`docSection` carried no `attrs` field and `DocumentObservation` took no
parameter to set one. **FR-021, above, is spec 012's answer**: an additive,
optional `sections[].attrs` field, passed through unchanged into
`Observation.Attrs` via a new `DocumentObservationOption`. This is a genuine
cross-specification dependency, not yet implemented (see T006a in this
spec's own `tasks.md`), and spec 015's `data-model.md`/`tasks.md` now mark
their own consuming task as BLOCKED on it landing, consistent with how that
specification already marks its other cross-spec dependency (spec 013) as
BLOCKED-until-landed.

**This feature's real role relative to spec 015**: it is the **first
concrete producer** of `doc_section` passages a Location Anchor could ever
point at from a non-video, textbook-sourced Material, and — once T006a
lands — the first concrete producer of the `Attrs` keys such an anchor's
format-specific location metadata would read. Spec 015's own Independent
Test for its User Story 1 names "document ingestion, spec 012, or a
text-only-chapter authoring flow" as the two expected producers. No
conflicting type definition is introduced; the one real coordination
dependency between the two specs' Phase 1 work is the `Attrs` passthrough
named above, tracked by FR-021/T006a here and by the corresponding BLOCKED
task in spec 015.

## Carried-forward NEEDS CLARIFICATION (not resolved by this plan)

Per spec.md, two items remain open and are **not** resolved here, per
§11.4.6's no-guessing mandate:

1. **FR-005** — the closed set of accepted License Record `basis` values and
   any verification mechanism beyond an operator's own recorded statement.
2. **FR-020** — whether, and how, a textbook's own chapter/section structure
   should ever be promoted into the curated `kg_area`/`kg_lesson_section`
   knowledge layer. The research's own §5.5 recommends option 1 (never
   promote automatically) for Phase 1 specifically because it requires zero
   new code and is a strict subset of what already works — this plan adopts
   that recommendation as Phase 1's default behavior (do nothing beyond
   minting `doc_section` rows), without treating the underlying design
   question as closed.
