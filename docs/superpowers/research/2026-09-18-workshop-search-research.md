# Research: Workshop Search Surface (for future HelixQA brainstorming)

Read-only investigation, 2026-09-18. Input for the "Search" sub-project of the
exhaustive-HelixQA-coverage effort. All paths relative to `workshop/`.

## 1. Real routes

**`/search` and `/ask` are ONE frontend component, not two.**
`app.routes.ts` (~lines 99-108): both routes load
`features/inquiry/inquiry.component.ts` (`InquiryComponent`, 1812 lines),
differing only by route `data: { mode: 'auto' }` vs `{ mode: 'answer' }`. No
`features/search/` directory exists. The component renders two permanently-
labelled panes on one page: `data-mode="answer"` (out of scope — that's the
Ask/Q&A sub-project) and `data-mode="search"`
(`data-testid="search-pane"`) — the actual lexical/semantic lookup half.

Two more routes exist because `/api/search` used to emit unusable
`deep_link: ""` for non-transcript kinds: `passage/:pid` →
`features/passage/passage.component.ts`; `term/:term` →
`features/passage/term.component.ts`.

**Backend routes are registered separately from `main.go`'s main table**, by
`internal/api/router.go`'s `Register()` (called at `main.go:1100`, before the
`LoopbackOnly` wrap):

| Route | Handler | Location |
|---|---|---|
| `GET /api/search` | `SearchHandler` | `router.go:41` |
| `GET /api/suggest` | `SuggestHandler` | `router.go:44` |
| `GET /api/passages` | `PassagesCollectionHandler` | `router.go:47` |
| `GET /api/passages/{pid}` | `PassageHandler` | `router.go:48` |
| `GET /api/passages/{pid}/crossrefs` | `CrossRefsHandler` | `router.go:59` |
| `GET /api/index/status` | `IndexStatusHandler` | `router.go:64` |
| `GET /api/terms`, `/api/terms/{term}` | (in `main.go`) | `main.go:1385-1386` |

Retrieval engine: `pkg/search/` (40+ files — service.go, lexical.go,
semantic.go, lumen.go, envelope.go).

**`GET /api/search` params** (allow-listed, unknown param → 400): `q`
(required, non-empty, ≤8192 bytes else 413), `limit` (1-100, default 20),
`timeout_ms` (500-15000, default 5000), `mode`
(`fused`/`lexical`/`semantic`/`code`), `kinds` (closed vocabulary, unknown
name → 400; known-but-empty kind → `unavailable/kind_not_indexed`, not a
rejection), `chapter`, `area`.

**No pagination exists anywhere** — a real, undocumented gap: a query with
>100 matches has no way to retrieve results past the first page.

**Response shape**: shared `Envelope` type (`status`, `q`, `legs`, `reason`,
`degraded`, `corpus`, `filters`, `generation`, `took_ms`), array field named
per endpoint (`results`/`suggestions`/`crossrefs`). Each `Hit`: `pid`, `kind`,
`chapter_slug`, `title`, `snippet`, `highlights(+support)`, `locus`,
`t_start_s`/`t_end_s`, `source_ref`, `score`, `above_floor(+support)`, `leg`,
`provenance`, `uncertain`, `href`, `deep_link`.

## 2. What's searchable / ranking

`indexed_kinds` is advertised dynamically, checked TWO independent ways
before a kind is listed: (a) does the index actually have ≥1 row of this
kind (three-valued, fails open on undetermined); (b) would a reader actually
be SERVED one (the publication gate can withhold every row of an otherwise-
populated kind — measured: `kg_*` kinds have 226 real rows but kind-scoped
search always returns zero, so they're excluded from `indexed_kinds`
entirely rather than advertised-but-always-empty). No audio/video kind
exists — media is reached via transcript passages, never searched directly.

Four retrieval legs, fused by `mode`: `lexical` (SQLite FTS5, bm25),
`semantic` (embedding cosine similarity, own relevance floor), `lumen`
(code-semantics, nil-able/skippable), `catalog` (taxonomy area/term/question
rows — NOT bm25-comparable to the passage corpus, hence a
`Ranking.Comparable`/`Groups`/`Policy` mechanism exists specifically to stop
a client sorting two incompatible scales as one list).

Lexical query construction quotes every token as an FTS5 literal, last token
gets a `*` prefix-match suffix, tokenization splits on non-alphanumeric —
this doubles as the injection defense (§3).

## 3. Edge cases — the envelope decision ladder is the single most important thing to test

**Empty query** → 400 `empty_query`, never a 200 with empty results.

**Zero results**, `NewEnvelope`'s priority-ordered decision ladder
(`envelope.go:540-698`):
1. Named total failure → `unavailable`
2. Any results → `ok`
3. Zero results AND no enabled leg ran at all → `unavailable/no_leg_executed`
4. Zero results AND every `kinds=` filter value has zero indexed entries →
   `unavailable/kind_not_indexed` (this arm exists specifically because the
   server used to answer `200 no_match` for a genuinely-unindexed kind —
   measured live 2026-09-08, since fixed)
5. Zero results AND any leg failed / a degraded caveat exists →
   `unavailable/partial_failure_zero_results`
6. **Default: every leg succeeded, found nothing → `no_match`** — the ONLY
   path that's genuinely "nothing matches." Everything else that looks like
   "no results" is deliberately routed to `unavailable` instead, because the
   whole point (per the package's own doc) is never collapsing "answered,
   found nothing" and "could not be answered" into one bucket — this exists
   because `ai_interviewing`'s own search component once rendered "No
   results for …" on a backend error, and this design is the fix.

**Redaction — enforced at multiple independent layers, not just one filter**:
- Lexical: `WHERE passages_fts MATCH ? AND p.redacted = 0` — filtered at
  query time, every request, no cache.
- Semantic: own `redactedPIDs` exclusion, applied separately.
- Catalog/suggest: `dropRedactedTargets` RE-CHECKS the live DB's `redacted`
  column before a (possibly-stale in-memory) catalog row can become a
  suggestion.
- Crossrefs: drops redacted/dangling targets during traversal, AND
  separately re-resolves every edge through the registry to strip the
  preview snippet if the publication gate says so (belt-and-braces).
- **A dedicated gate already proves this is synchronous, not eventually
  consistent**: `platform/gates/verify-g-kg-25-search-redaction-sync.sh` +
  `pkg/search/g_kg_25_test.go` — builds a real derived DB, confirms a
  synthetic passage is found, redacts it through the REAL
  `internal/redaction.Plan.Apply`, re-issues the identical search against
  the SAME already-open DB with no reopen/reload/restart, asserts nothing
  survives. A separate paired-mutation test proves this gate isn't vacuous.
  **Only the lexical leg has this dedicated redaction-sync proof — semantic/
  catalog/crossrefs redaction paths exist in code but have no equivalent
  named paired-mutation gate.** Real gap for the future brainstorm.

**Special characters / injection**: neutralized by construction (FTS5-literal
quoting), not a blocklist — no SQL injection surface (bound parameters
throughout, explicit comment confirms no string concatenation). A
pure-punctuation query tokenizes to zero tokens and short-circuits to zero
results (falls into the ladder above), never an error.

## 4. Existing coverage — do not duplicate

All Go-test-based (not `helixqa http` banks), in `platform/gates/`:
- `verify-g-kg-25-search-redaction-sync.sh` — lexical-leg redaction-sync only (see above).
- `verify-g-http-5-search-survives-answering-down.sh` — search must keep serving lexical results with the answer provider stopped; ask must 503, never the reverse.
- `verify-search-determinism.sh` — same query/generation must return identical results (found flaky against `mode=semantic` 2026-09-04, since fixed).
- `verify-search-concurrency.sh` — latency budgets hold under ≥5 concurrent clients.
- `verify-search-latency.sh` — SC-006 budget measured live (`docs/limits.md` §2: `/api/search` p95 2094.8ms, `/api/suggest` p95 14.2ms).

None of these are functional/contract-style HelixQA banks — a bank covering
empty-query/filters/deep-links/redaction-in-results would be complementary,
except the redaction-in-search-results case should target the HTTP-observable
behavior directly (does `GET /api/search?q=<redacted terms>` omit the
passage) rather than re-deriving G-KG-25's internal proof.

## 5. Crossrefs — separate feature, shares infrastructure

`GET /api/passages/{pid}/crossrefs` is point-to-point graph navigation
between passages (`relation`/`origin`/`depth`/`limit` filters), NOT invoked
from the search pane at all — its only caller is
`features/transcript/crossrefs.component.ts` (embedded in the transcript
reader) and `core/status.component.ts`'s diagnostics probe. It shares the
same `Envelope` three-state contract and the SAME `PublicationGate` instance
as search/passages (deliberately — so a redacted passage's content can't
leak via crossref preview even after direct access 410s), but runs its own
two legs (`index`, `registry`), never touching the retrieval engine.

**Today's diagnostics fix is directly relevant**: `/status`'s probe used to
collapse EVERY `unavailable` outcome from the three Envelope-based routes
(suggest/search/crossrefs, probed together) into "route is not registered",
masking a genuinely-erroring crossrefs route. Fixed to check
`reason.code === 'endpoint_not_implemented'` specifically — confirms these
three routes are grouped on the diagnostics surface, though functionally
crossrefs remains distinct from full-text search.

## 6. Authentication

Same as every other API route — no special-casing. `wrapWithAuth` exempts
only `/api/health` and `/api/auth/*`; everything else (search, suggest,
passages, terms) requires a bearer token via `authhttp.Middleware`, inside
the outer `api.LoopbackOnly` wrap.

**Caveat, time-bound to when this was measured**: at investigation time, an
UNCOMMITTED, temporary golden-bad mutation was present in `main.go` (part of
a concurrent HelixQA sub-project's own controlled test-and-revert cycle for
`WK-CHLIST-002`), bypassing auth on all `/api/*` routes. This is transient
and unrelated to search's own real (committed) auth requirement — verify
`git diff -- platform/backend/cmd/workshop-server/main.go` is clean before
trusting any live auth-behavior observation for this or any other sub-project.

## Files most relevant for the future brainstorm

- `app.routes.ts`, `features/inquiry/inquiry.component.ts` (read its header in full)
- `core/api.ts` (~316-377): `suggest`/`search`/`crossrefs` client methods
- `internal/api/router.go`, `internal/api/search.go`, `internal/api/crossrefs.go`
- `pkg/search/envelope.go` — the decision ladder is the highest-value thing to test exhaustively
- `pkg/search/lexical.go` — redaction filter + FTS5 query building
- `pkg/search/service.go` — `corpusBlock`, cross-leg publication/redaction wiring
- `platform/gates/verify-g-kg-25-search-redaction-sync.sh` + `pkg/search/g_kg_25_test.go`
- `docs/limits.md` §2

## Suggested focus for the brainstorming session

1. The `NewEnvelope` 6-branch decision ladder is the highest-value target —
   each branch needs its own real, live-triggered bank case.
2. Redaction-in-search-results at the HTTP level (complementary to, not
   duplicating, G-KG-25's internal lexical-leg proof).
3. The semantic/catalog/crossrefs redaction paths have no dedicated
   paired-mutation gate the way the lexical leg does — a real, currently-
   unguarded gap.
4. No pagination exists — decide whether this is in-scope to test as a
   documented limitation or out of scope as a non-feature.
5. `kinds=<unknown>` (400) vs `kinds=<known-but-empty>`
   (`unavailable/kind_not_indexed`) — easy to conflate, worth a dedicated
   pair of cases.
