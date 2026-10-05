# Contract: Reranker Service

**Implements**: FR-008 | **New package**: `workshop/platform/backend/pkg/rerank` (Go client)
**Backend**: `llama-server --reranking` running `bge-reranker-v2-m3-GGUF` (research.md §1, §0)

**Composition point — CORRECTED 2026-10-05** (was: "slots into `pkg/pipeline.Builder` fluently,
ahead of `MMRReranker`"): that composition point does not exist. `digital.vasic.rag/pkg/pipeline`
is never imported anywhere in `workshop`'s backend, and `MMRReranker` is called nowhere in
production — see `research.md` §0 for the full correction. `pkg/rerank.Client`'s type satisfies
`submodules/RAG/pkg/reranker.Reranker`'s method shape (so it is type-compatible with that
interface, useful if a future caller wants it), but it is invoked **directly from
`(*Service).split`** (`workshop/platform/backend/pkg/search/service.go`), as a second,
mutually-exclusive window-reorder mode alongside the existing `reorderWindow`
(`pkg/search/rerank_window.go`) — see `plan.md`'s corrected Constraints and Project Structure.

## Interface implemented

```go
// submodules/RAG/pkg/reranker, existing, unmodified
type Reranker interface {
    Rerank(ctx context.Context, query string, docs []retriever.Document) ([]retriever.Document, error)
}
```

## Backend HTTP contract (llama-server `--reranking` endpoint)

**CONFIRMED against a real running instance, 2026-10-05**, during `/speckit.superspec.execute`
Phase 1 (Setup, T001): `llama-server` v8681 (Debian build), model
`gpustack/bge-reranker-v2-m3-GGUF` (`Q8_0`, 606 MB, 567.75 M params), smoke-tested with a 3-document
query — the model correctly ranked the RAG-relevant document highest, an off-topic sentence lowest.

```text
POST /rerank
{
  "query": "<query text>",
  "documents": ["<doc 1 text>", "<doc 2 text>", ...],
  "top_n": <int, optional>
}

200 OK (REAL response, verbatim):
{
  "model": "bge-reranker-v2-m3-Q8_0.gguf",
  "object": "list",
  "usage": {"prompt_tokens": 94, "total_tokens": 94},
  "results": [
    {"index": 0, "relevance_score": -5.4627075195312500},
    {"index": 2, "relevance_score": -8.7905158996582030},
    {"index": 1, "relevance_score": -11.035554885864258}
  ]
}
```

**Two facts the originally-assumed shape got wrong, now corrected**: (1) the response wraps
`results` inside `model`/`object`/`usage` fields — a client MUST NOT assume `results` is the only
top-level key; (2) `relevance_score` is **not** bounded to `[0,1]` as the placeholder example
implied — it is an unbounded, model-native logit-like score (observed range here: -5.46 to
-11.04) where **higher (less negative) means more relevant**; `pkg/rerank.Client` MUST sort by
this value directly, never assume a probability-like 0–1 scale.

## Client contract (`pkg/rerank.Client`)

**UPDATED 2026-10-05 per `/speckit-clarify` session on `spec.md`** (FR-008's three-tier fallback
— fresh rerank → cached last-known-good → pre-rerank order — replaces this contract's original
two-state ok/unavailable design). The table below is the current, authoritative version.

| Method | Behavior |
|---|---|
| `Rerank(ctx, query, docs) ([]Document, error)` | Satisfies `reranker.Reranker`. On success: re-orders/re-scores `docs` using `relevance_score` as the new `Document.Score`, and **writes through** to `RerankCacheEntry` (data-model.md §4) keyed by the exact query text, before returning. Returns `(reranked, nil)`. |
| Backend unreachable / timeout | Looks up `RerankCacheEntry` for the exact query text. **Cache hit**: returns `(cachedResult, ErrRerankServedFromCache)` — never silently indistinguishable from a fresh rerank (Honest Instruments). **Cache miss**: returns `(docs, ErrRerankUnavailableNoCache)` — the pre-rerank order from `(*Service).fuse` (RRF-fused; corrected 2026-10-05 — not "RRF/MMR-fused", MMR is not in this path), unchanged. Neither path returns `(nil, err)` or a silently-empty slice, and **neither path returns a bare `error`** — the query MUST NOT fail (FR-008). |
| Backend returns malformed/empty response | Same two-branch cache lookup as "unreachable/timeout" above — a malformed response is treated identically to an unreachable backend for fallback purposes, with its own distinct error value (`ErrRerankMalformed...`) preserved for logging/diagnostics. |
| Empty candidate set | Returns `(docs, nil)` immediately, no backend call, no cache lookup — not an error, a no-op. |

### Cache storage contract

- **Mechanism**: a new SQLite table, `rerank_cache(query_hash TEXT PRIMARY KEY, query_text TEXT, result_json BLOB, cached_at TIMESTAMP)`, in the SAME database `cmd/workshop-server` already opens — no new storage engine (plan.md's Storage constraint), and persistence survives a server restart, which matters because a reranker outage can coincide with a deploy/restart.
- **Write**: every successful `Rerank` call upserts its own entry, keyed by a hash of the exact query text. One entry per distinct query text; a later successful rerank of the same query text overwrites the earlier cached entry (the cache always holds the MOST RECENT success, hence "last-known-good").
- **Read**: only consulted on backend failure (unreachable/timeout/malformed) — never consulted, and never influences ranking, on a successful call. This is the "cache is a fallback, not a source of truth" invariant from `data-model.md`'s updated Reranking Stage entity description.
- **Staleness, stated honestly**: the cache is keyed by query TEXT only, not by the candidate document set that produced it. If the underlying corpus has changed since the cached entry was written (new content ingested, a passage removed), the cached reranking could be scoring a candidate set that no longer matches what the pre-rerank leg returns today. This is a known, accepted limitation of "last-known-good by exact query text" as specified — not silently glossed over. A future refinement (keying by query+candidate-set signature) is out of this feature's scope.
- **Eviction**: no explicit TTL/size bound is mandated by this contract; the task breakdown MUST decide a bounded eviction policy (e.g. LRU by `cached_at`, or a row-count cap) so the table cannot grow unboundedly — tracked as a task, not left to arbitrary implementer discretion.

## Health check

`cmd/reranker-probe` (NEW, mirrors `_tools/containers/cmd/runtime-probe`'s pattern) — a standalone
CLI that calls the backend's health/readiness and exits 0 (ready) / 1 (backend reachable but not
ready) / 2 (backend unreachable). `cmd/workshop-server`'s own startup MAY call this probe's logic
to decide whether to advertise reranking as available, but MUST still handle a mid-session
backend failure via the client contract above, not only at startup.

## Non-goals

- No reranked score is ever persisted (data-model.md §4, State transitions: none).
- This contract does not cover batching strategy for large candidate sets beyond respecting
  whatever `top_n`/batch-size limit the pinned `llama-server` build documents — that is an
  implementation detail for the task breakdown, not a contract-level decision.
