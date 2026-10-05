# Phase 1 Data Model: Exhaustive RAG Expansion + Textbook Ingestion + Jordan Correction

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

This document defines entities new to this feature and the extensions it makes to existing
entities. Existing entities (`Passage`, `KnownKinds`, `LocationAnchor`, `Material`) are described
only to the extent this feature touches them; their full current definitions live in
`workshop/platform/backend/internal/passagestore/domain.go` and
`specs/015-universal-content-model-profile/data-model.md`.

## 1. Textbook (new entity)

Represents one ingested textbook source document.

| Field | Type | Notes |
|---|---|---|
| `id` | string (content-hash-derived) | Mirrors the `knowledge-mint` content-hash-keyed pattern already used for correction tracking (`cmd/knowledge-mint/main.go`), so a textbook re-ingested after a path rename is still recognized as the same source. |
| `title` | string | From TOC/metadata when available, else filename (books-for-bots fallback chain, §5 of research.md). |
| `source_path` | string | Relative path under `workshop/textbooks/<dir>/` (e.g. `ai_001/`). |
| `license_basis` | enum | Closed vocabulary matching spec 012's own FR-005 open question — **this feature does not resolve that vocabulary**; it reuses whatever closed set spec 012 settles on. If spec 012 is still open when this field is implemented, use a provisional single value `unverified` and flag it, never invent a new vocabulary unilaterally. |
| `chapter_count` | int | Derived at ingestion time from the TOC-resolution fallback chain. |
| `ingested_generation` | int | The embedding generation this textbook's passages were first embedded into (FK into the existing `embeddings` table's `generation` column). |

**Validation rules**: `source_path` MUST resolve to an existing file under `workshop/textbooks/`
at ingestion time (FR-003's license gate: ingestion refuses to proceed for a file with no
determinable `license_basis`, three-valued — proceed / refuse-with-reason / undetermined — never a
silent skip). Re-ingestion of the same `source_path` MUST be idempotent (FR-007): a second run
produces zero new passages when the source content is byte-identical, matching the tiered-match
guarantee from `research.md` §5.

## 2. Passage — extended with content-type classification (FR-009)

**CORRECTED 2026-10-05, post-`/speckit-clarify`**: the original version of this section described
`content_type` as derived from `kind` via a fixed 1:1 mapping — directly contradicting the
resolved clarification that content-type MUST be an explicit stamp the ingesting script supplies,
never inferred from `kind`. See `contracts/content-type-classification-contract.md`'s own
correction note for the full reasoning. The content below is the corrected, authoritative version.

The existing `KnownKinds` set (5 base kinds: `transcript_segment`, `doc_section`, `code`,
`diagram`, `screen_text`; 5 `kg_*` kinds: `kg_area`, `kg_term`, `kg_lesson_section`,
`kg_question`, `kg_mention`) is **unchanged in membership** — this feature adds a new kind,
`textbook_section`, and a new cross-cutting dimension orthogonal to kind.

| Field (new) | Type | Notes |
|---|---|---|
| `content_type` | enum: `{transcript, meeting_notes, authored_lesson, textbook, code, diagram, screen_text, knowledge_graph}` | A coarser, first-class classification than `kind`, generalizing the ad-hoc population used by `Semantic.WithPopulation` (`pkg/search/semantic.go:122`). **REQUIRED on every passage write — supplied explicitly by the ingesting pipeline/script, never computed from `kind`.** `ValidateRecord` checks the supplied value is a member of the writing `kind`'s ALLOWED set (contracts/content-type-classification-contract.md); for most kinds that allowed set has exactly one member, but `doc_section` allows `{meeting_notes, authored_lesson}` — a genuine either/or the kind alone cannot resolve, which is precisely why this field cannot be derived. |
| `location` | `*LocationAnchor` (reused from spec 015, see below) | Set for `textbook_section` passages exactly as it is already set for `KindDocument` passages — this feature does not invent a new anchor shape, it extends the existing one's applicability. |

**New kind**: `textbook_section` is added to `KnownKinds`, with allowed `content_type` set
`{textbook}` (singleton — every textbook passage, regardless of which textbook, carries
`content_type = textbook`; textbook ingestion never writes to any other kind). `ValidateRecord`'s
existing invariants (kind membership, human-only speaker attribution, media-backed-kind field
requirements) extend to cover it: `textbook_section` is NOT a media-backed kind (no audio/video
timestamp requirement, unlike `transcript_segment`), and carries no speaker attribution (it is
document-derived, like `doc_section`).

**Signature change (Foundational, reviewed)**: `DocumentObservation(chapterSlug, text, kind, ref)`
is extended to `DocumentObservation(chapterSlug, text, kind, contentType, ref)`. Every existing
caller (meeting-notes pipeline, authored-lesson pipeline) MUST be updated in the same change to
supply its own correct `content_type` — see
`contracts/content-type-classification-contract.md`'s "Foundational, reviewed" subsection for the
full migration contract and why a missed caller fails loudly rather than silently.

**Validation rule (population scoping, generalizing FR-009's intent)**: a retrieval request MAY
scope by `content_type` (the generalized `WithPopulation`, now a lookup against each passage's
own stored `content_type` value); the existing floor-domain-containment fix (excluding `kg_term`
et al. from being above-floor matches to unrelated queries) is preserved as the special case
`content_type != knowledge_graph` applied by default to non-knowledge-graph queries — this
feature's generalization MUST NOT regress that specific, already-shipped fix.

## 3. LocationAnchor (reused, not modified)

Defined in `specs/015-universal-content-model-profile/data-model.md`:

```go
type LocationAnchor struct {
    SectionID     string
    Locator       string // e.g. page/offset/line-range, format depends on source type
    PassageAnchor string
}
```

This feature's only change to this type's USE is extending which passages carry a non-nil
`Location`: previously only `KindDocument`; now also `textbook_section`. The `Locator` format for
a `textbook_section` passage follows the books-for-bots-inspired offset convention
(`research.md` §5): a byte/line offset pair into the extracted flat text, enabling the
"TOC→heading→title→filename" fallback chain to resolve a human-readable chapter/section label
from the anchor even when no TOC entry exists.

## 4. Reranking entities (FR-008)

**UPDATED 2026-10-05 per `/speckit-clarify` session on `spec.md`**: FR-008 now specifies a
three-tier fallback (fresh rerank → cached last-known-good → pre-rerank order), not the original
two-state ok/unavailable design. The shapes below are the current, authoritative version; see
`contracts/reranker-service-contract.md` for the full client-behavior contract.

```text
RerankRequest {
    query:       string
    candidates:  []Document      # the existing submodules/RAG/pkg/retriever.Document shape — unmodified
    top_k:       int
}

RerankResult {
    reranked:       []Document      # same Document shape — the final order/score served to the caller,
                                      # from whichever of the three tiers actually produced it
    outcome:        enum{reranked_fresh, served_from_cache, fallback_no_cache}  # three-valued, replaces
                                      # the earlier two-state backend_status field; NEVER a bare
                                      # success/failure boolean (Honest Instruments, plan.md Constitution Check)
    latency_ms:      int
}

RerankCacheEntry {              # NEW — the persistent last-known-good store
    query_hash:      string      # hash of the exact query text; primary key
    query_text:       string      # retained alongside the hash for diagnostics/debuggability
    result_json:      blob        # the serialized RerankResult.reranked from the write that created this entry
    cached_at:        timestamp
}
```

**Validation rule**: `outcome = served_from_cache` or `outcome = fallback_no_cache` MUST NEVER
cause the request to fail — FR-008 is explicit that a query must never fail outright because the
reranking stage is unavailable. The caller (query path in `cmd/workshop-server`) MUST be able to
distinguish all three `outcome` values in whatever it logs or returns, so a degraded state is
never indistinguishable from a successful one (Honest Instruments, unchanged from the original
design — only the number of distinguishable states grew from two to three).

**State transitions**: a successful rerank (`outcome = reranked_fresh`) **writes through** to
exactly one `RerankCacheEntry`, upserted by `query_hash` — this is the one piece of state this
feature's reranking stage persists (the original "State transitions: none" claim is corrected:
it was true of the original two-state design, not of the clarified three-tier one). No reranked
score is ever written to the `embeddings` or `passages` tables — the cache is a dedicated,
separate table (`rerank_cache`, see `contracts/reranker-service-contract.md`), never conflated
with the corpus's own passage/vector storage.

**Known limitation, stated honestly (not silently accepted)**: `RerankCacheEntry` is keyed by
`query_text` alone, not by the candidate document set that produced it. A cached entry can go
stale relative to the corpus without any signal that it has, if the corpus changes between the
cache write and a later cache-served read for the same query text. See
`contracts/reranker-service-contract.md`'s "Cache storage contract" for the full statement of
this limitation and why it is accepted as this feature's scope rather than solved here.

## 5. Embedding Generation / Bake-off tracking (FR-016)

```text
BakeoffResult {
    model_name:        string
    generation:        int        # the offline generation this candidate was embedded into
    evaluated_on:       population-descriptor   # e.g. "textbook/prose content, N passages" —
                                                  # explicit per plan.md's Constitution Check row
                                                  # "A Gate Cannot See a Displacement Larger Than
                                                  # Its Window": never implied, always stated
    metric_name:        string      # e.g. "nDCG@10", "recall@5" — whichever this feature's
                                      # evaluation harness computes
    metric_value:       float
    license:            string      # recorded per-candidate so a future switch decision has the
                                      # license fact already verified, not re-researched
    calibrated:         bool        # ALWAYS false for every candidate at bake-off time — a model
                                      # switch's calibration pass is explicitly out of scope for
                                      # the bake-off itself (plan.md Constraints)
}
```

**Validation rule**: a `BakeoffResult` row MUST carry a non-empty `evaluated_on` — an empty or
implied population field is itself a Constitution Check violation (see plan.md), not merely an
incomplete record.

## 6. ClientResearchProfile (pointer only — no content)

This entity exists in this document **only as a pointer**, per the Content Boundary note in
`research.md` §6. It is intentionally thin:

```text
ClientResearchProfile {
    client_country:      string   # "Jordan" (corrected from "Germany")
    research_path:       string   # "workshop/docs/research/clients/jordan/" — a PRIVATE path,
                                     # named here only as a location, never dereferenced for content
    correction_applied:   bool
    wave2_research_done:  bool
}
```

**No field of this entity may ever hold client-identifying text, company names, or verbatim
feedback.** Any implementation that would populate such a field here is a content-boundary
violation and must be redirected to a commit inside the private `workshop` submodule instead.
