# Contract: Textbook Ingestion Stage

**Implements**: FR-001–FR-007 | **Script**: `workshop/pipeline/pdf_textbook_sections.py` (NEW)
**Precedent, corrected**: see `research.md` §5 — `md_sections.py` has no PDF handling;
`transcribe/pdf_notes.py`'s `pdftotext -layout` convention is for meeting notes, not textbooks.

## Pipeline (3 steps, matching the pattern of `specs/012-.../contracts/epub-ingestion-stage.md`)

```text
1. pdf_textbook_sections.py <textbook.pdf> --out <sidecar.json>
     Extracts chapter/section structure + flat text + LocationAnchor offsets.
     Three-valued exit: 0 = extracted, 1 = extraction failure (reported, not silently skipped —
     FR-006), 2 = could not determine (e.g. unreadable PDF, no detectable structure).

2. ingest-transcript -docs <sidecar.json>
     Reuses the EXISTING ingestion CLI (not reimplemented) to call
     internal/passagestore.DocumentObservation(chapterSlug, text, kind="textbook_section", ref)
     for each section. NOTE: current DocumentObservation signature has NO Attrs parameter
     (confirmed domain.go:538-548) — any per-section metadata beyond kind/ref that this feature
     needs MUST either fit into the existing signature's ref/text shape or be proposed as a
     signature extension reviewed under this plan's Review Gates, not bolted on ad hoc.

3. index-embed -generation -1 -embed-model <bakeoff-selected-model>
     Reuses the EXISTING cmd/index-embed unchanged (research.md §4) — embeds the new textbook's
     passages into a new generation, never mixing into the live-serving generation until the
     bake-off decision (plan.md Human Checkpoint 1) is locked in.
```

## Input contract

- A single PDF file under `workshop/textbooks/<dir>/`, e.g. `workshop/textbooks/ai_001/<file>.pdf`.
- MUST be text-extractable (scanned-image-only PDFs with no text layer are a `license_basis`-
  independent extraction failure, exit 1, FR-006).

## Output contract

- One sidecar JSON per textbook, schema aligned with spec 012's `data-model.md` sidecar shape,
  extended with this feature's `LocationAnchor`-bearing `sections[]` array (byte/line offsets,
  not spec 012's still-open `attrs map[string]string` field — that field is NOT implemented by
  this feature; see spec 012's own FR-021 tracking).
- Idempotent: re-running step 1 on an unchanged PDF produces a byte-identical sidecar; re-running
  step 2 on an unchanged sidecar produces zero new passages (tiered match, `research.md` §5,
  adapted for PDF: tier 0 "inline anchor comment" is not portable from markdown, substituted with
  a content-hash sidecar-entry check as this script's own tier 0).

## Failure reporting contract (FR-006)

Every extraction failure (a page that fails to extract, a chapter boundary that cannot be
resolved by any step of the TOC→heading→title→filename fallback chain) MUST be written to a
failure report alongside the sidecar, never silently dropped — mirroring this project's
three-valued exit convention (0/1/2) at both the per-file and per-section granularity.

## Out of scope for this contract

- License-vocabulary resolution (`license_basis`'s closed enum) — deferred to spec 012's own
  FR-005 resolution; this script accepts whatever provisional value spec 012 currently defines.
- `kg_area` promotion of textbook-derived knowledge-graph entities — deferred to spec 012's own
  FR-020 open question; out of this feature's scope entirely (this feature's `textbook_section`
  kind is a base kind, not a `kg_*` kind).
