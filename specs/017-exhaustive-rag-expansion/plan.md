# Implementation Plan: Exhaustive RAG Expansion + Textbook Ingestion + Jordan Correction

**Branch**: `017-exhaustive-rag-expansion` | **Date**: 2026-10-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/017-exhaustive-rag-expansion/spec.md`

## Summary

The workshop platform (`workshop/platform/backend`) already runs a hybrid RAG stack — lexical
(FTS5/BM25) + semantic (Ollama embeddings) + code-symbol (Lumen CLI) retrieval, fused via RRF, over
a passage schema of 5 base kinds + 9 `kg_*` knowledge-graph kinds (14 total, not the "10"/"5
knowledge-graph kinds" this document originally stated — corrected 2026-10-05 during
`/speckit.superspec.execute`, measured directly from `knowledge.Kinds()`). Research (three parallel
forks, Phase-0-equivalent, reported below and consolidated into `research.md`) confirmed this is
substantially built and wired, not greenfield. The real, evidence-backed gaps this feature closes
are narrower than "introduce RAG":

1. **No cross-encoder (learned relevance-model) reranking stage.** **CORRECTED 2026-10-05**: the
   original text here said a new cross-encoder stage must compose "ahead of MMR" and preserve MMR
   "for passage cross-referencing." That premise is **false** — see `research.md` §0. `MMRReranker`
   is not called anywhere in the production workshop backend: it was measured live to be both
   non-deterministic (served set/order varied across identical calls) and score-corrupting
   (overwrites relevance score with Jaccard word-overlap) and was **removed** from
   `(*Service).fuse`; `pkg/crossref` independently declined to use it for the identical reason,
   documented in its own package doc. The real existing reranking mechanism this feature's
   cross-encoder stage must account for is `pkg/search/rerank_window.go`'s `reorderWindow` — a
   pure window-permutation (BM25-OR over the served window, fused via RRF with the incoming
   order), gated by `Service.WindowRerank`, **off by default** because it measurably helps some
   query classes and costs others. FR-008 adds a true cross-encoder stage as a second candidate
   answer to the question `reorderWindow` already answers one way — see Technical Context and
   Constraints below for the composition decision.
2. **Content-type is not yet a first-class retrieval dimension**, only an ad-hoc fix
   (`Semantic.WithPopulation`, `workshop/platform/backend/pkg/search/semantic.go:122`). FR-009/010
   generalize it.
3. **Textbook PDF ingestion has no code to build on.** Spec 012's own claim that the
   `pdftotext -layout` convention is "already proven elsewhere" is **incorrect for textbooks**:
   that convention exists only in `workshop/pipeline/transcribe/pdf_notes.py`, for meeting-notes
   PDFs — a different source type with a different structure. `workshop/pipeline/md_sections.py`
   (the file that WOULD apply) contains no PDF handling at all. FR-001–007 build a dedicated
   textbook-PDF ingestion stage, informed by but not copied from the meeting-notes precedent.
4. **No embedding-model bake-off has ever been run** against the current default
   (`jina-embeddings-code-cpu`), and the default was chosen for code/transcript content, not prose
   textbook content. FR-016 runs one, offline, using the existing generation-scoped re-embedding
   mechanism (`cmd/index-embed`) so it carries zero live-service risk.
5. **The Jordan/Germany correction is content-boundary-sensitive.** The client is based in Jordan,
   not Germany, and the existing research lives in a **private** submodule
   (`workshop/docs/research/clients/germany/`). FR-014/015/017 correct it, and Wave-2 research has
   already been performed (summarized by mechanism only in `research.md` — see the Content
   Boundary note in that file; no client-identifying content is duplicated into this **public**
   `vasic` repository's `specs/` tree, per this project's standing content-boundary invariant).

## Technical Context

**Language/Version**: Go 1.26 (workshop platform backend — `cmd/workshop-server`, `pkg/search`,
`pkg/crossref`, `internal/passagestore`); Python 3.14 (ingestion/pipeline scripts under
`workshop/pipeline/`, run inside the project venv at `workshop/pipeline/venv` for anything needing
`faster_whisper`/`ctranslate2` — textbook ingestion itself needs no ASR, so plain `python3` is
sufficient for the new script); Bash (orchestration, matching `_tools/deploy-langs.sh` and
`workshop/pipeline/*.sh` conventions).

**Primary Dependencies**:
- `submodules/RAG` (`pkg/chunker`, `pkg/retriever`, `pkg/reranker`, `pkg/hybrid`, `pkg/pipeline`,
  `pkg/grounding`) — consumed **by reference**, per §11.4.28/§11.4.74 (extend, don't reimplement).
  No new RAG-stack package is written from scratch where this module already has an interface;
  the hierarchical parent-child chunker (new, see below) implements that module's own `Chunker`
  interface so it composes with the existing pipeline rather than forking it.
- **NEW: `llama-server` (llama.cpp) running `bge-reranker-v2-m3-GGUF`** (MIT license, ~0.6B
  params) as the cross-encoder reranking backend, reached over its `--reranking` HTTP endpoint.
  Chosen over a Python sentence-transformers sidecar (rejected: introduces a second runtime
  dependency into an otherwise Go-and-process-exec serving path) and over an in-process Go ONNX
  runtime (rejected: no mature, already-used Go ONNX binding exists in this codebase; adds
  dependency surface disproportionate to the gain). Measured CPU latency ~241 ms/batch on the
  reference hardware profiled during feasibility research — see `research.md`.
- Ollama (existing) — embeddings for the semantic leg; the bake-off (FR-016) evaluates models
  served through the same existing Ollama path, not a new serving mechanism.
- Lumen CLI (existing, unchanged) — code-symbol retrieval leg; out of scope for this feature.
- SQLite (existing) — `embeddings` (generation-scoped), `passages`, `passages_fts` tables; this
  feature extends the passage schema (content-type classification) and never bypasses
  `search.IndexVectors`/`DocumentObservation` to write to it directly.

**Storage**: SQLite, as above. No new storage engine. Content-type classification is a new
indexed column/kind-group, not a new store. **UPDATED 2026-10-05 per `/speckit-clarify`**:
reranking is query-time but no longer purely stateless — FR-008's clarified three-tier fallback
(fresh rerank → cached last-known-good → pre-rerank order) requires one new table, `rerank_cache`
(data-model.md §4, contracts/reranker-service-contract.md), in the SAME SQLite database, keyed by
exact query text. No reranked score is ever written to the `embeddings`/`passages` tables
themselves; the cache is a dedicated, bounded, separately-evicted table.

**Testing**: Go `testing` (table-driven, matching the existing `pkg/search`/`pkg/crossref` test
style) for the Go-side reranker client, content-type classifier, and chunker; Python
`unittest`/`pytest`-compatible tests for the new textbook-PDF ingestion script, following
`workshop/pipeline/md_sections.py`'s own tiered-idempotency test pattern; a characterization-test
pass over `md_sections.py`'s idempotency algorithm BEFORE writing the new PDF script, so the new
script's idempotency logic is proven equivalent in spirit (anchor-first, then exact-text, then
elided-text bridge, then unique line-range) rather than reinvented ad hoc.

**Target Platform**: CPU-only Linux (confirmed: no GPU assumed anywhere in this stack; `podman`
present, `docker` absent; `llama-server` reranking is explicitly a CPU-serving choice).

**Project Type**: Backend service extension (workshop platform, a web service) + offline
pipeline/ingestion scripts. Not a new service — this feature extends
`workshop/platform/backend` and `workshop/pipeline`, both of which already exist and are wired
into the running `workshop-curriculum_platform_1` container.

**Performance Goals**:
- Reranking adds bounded latency to the query path: target p95 reranking overhead within the
  existing `/api/suggest`/`/api/ask` latency budget (existing `search-latency` gate reports text
  legs at p95 41 ms; the reranking stage must not regress that by more than the single CPU batch
  cost measured in feasibility research, ~241 ms for a typical top-K candidate set).
- Incremental re-indexing (FR-011/012) must not require a full-corpus re-embed when new content
  (a new chapter, a new textbook) is added — only the new content's passages get a new
  generation's vectors, reusing `cmd/index-embed`'s existing `-generation` auto-increment.
- Textbook ingestion (FR-001–007) must be idempotent on re-run, matching `md_sections.py`'s
  existing tiered-match guarantee, so a partial-failure re-run never double-inserts passages.

**Constraints**:
- `calibratedFloor` (`cmd/workshop-server/main.go`) is **only** calibrated for
  `nomic-embed-text` with the exact corpus size `2478` PIDs; every other model, including today's
  default, is `calibrated=false` always. The bake-off (FR-016) must not be read as "recalibrating"
  this function — a model switch is a separate, explicit follow-on decision with its own
  calibration pass, not a side effect of the bake-off's measurement.
- `nomic-embed-text` has a measured ~7000-character HTTP ceiling (6000 accepted in practice per
  the existing comment in `cmd/workshop-server/main.go`) — any chunking strategy feeding it must
  respect `-embed-max-chars`/`-embed-max-batch-chars`, which matters directly for textbook content
  (long prose paragraphs, unlike terse transcript segments).
- **CORRECTED 2026-10-05** (was: "the cross-encoder stage MUST run before MMR in the pipeline...
  or the cross-encoder's work is silently discarded"). That constraint described a composition
  point that does not exist: `MMRReranker` is not called anywhere in the real query path
  (`research.md` §0). `MMRReranker.Rerank` **does** overwrite `doc.Score` with Jaccard similarity
  (`submodules/RAG/pkg/reranker/reranker.go:205`) — that fact survives, and it is exactly WHY both
  `(*Service).fuse` (`workshop/platform/backend/pkg/search/service.go:1041-1101`) and `pkg/crossref`
  (`workshop/platform/backend/pkg/crossref/crossref.go:26-37`) measured it and removed/declined it.
  The real composition constraint: the new cross-encoder stage is a second candidate for the role
  `reorderWindow` (`pkg/search/rerank_window.go`) already plays — a pure permutation of the
  already-fused, already-filtered served window, applied inside `(*Service).split` only when its
  own feature flag is on. **Design decision (this correction, not a re-litigation deferred to task
  breakdown):** the cross-encoder stage ships as its own flag,
  `Service.CrossEncoderRerank`/`-search-cross-encoder-rerank` (mirroring `WindowRerank`'s own
  flag shape), mutually exclusive with `WindowRerank` at request time — composing two independent
  window permutations has no established meaning and is explicitly out of this feature's scope,
  not silently assumed safe. Both remain available; which one a deployment enables is an operator
  choice informed by the two-sided evaluation FR-008's acceptance criteria already require.
- `Semantic.WithPopulation` (`pkg/search/semantic.go:122`) is the existing single-purpose fix this
  feature generalizes; its own doc comment records the exact defect it closed (nonsense-query
  probe returning `kg_term` rows above the relevance floor) — the generalized content-type
  dimension must preserve that specific fix as one instance of the general mechanism, not regress
  it while generalizing.
- **Content boundary**: `workshop` is a **private** submodule; this `vasic` umbrella repository is
  **public**. Nothing produced by this feature's Jordan-correction or bake-off work may duplicate
  client-identifying names, feedback text, or candidate-company names from
  `workshop/docs/research/clients/` into any file under `specs/017-.../` or any other
  public-repository path. All client-specific content changes happen **inside** the `workshop`
  submodule's own commits; this repository's artifacts describe mechanism and process only. See
  the project's own `verify-content-boundary.sh` gate and its documented 2026-09-01 incident.

## Constitution Check

*GATE: Must pass before proceeding. Re-check after design phase.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **Evidence-Based Claims** | PASS | Every gap this plan addresses is backed by an exact file:line citation from the three research forks (consolidated in `research.md`), not an assumption. The "RAG needs to be introduced" framing from the raw user request was itself corrected by evidence before scoping began. |
| **Honest Instruments** | PASS (as of 2026-10-05) | The reranker stage and the content-type classifier are new "instruments" in this codebase's sense. FR-008 was clarified (`/speckit-clarify`, 2026-10-05) to a three-valued outcome — `reranked_fresh` / `served_from_cache` / `fallback_no_cache` — and `contracts/reranker-service-contract.md` + `data-model.md` §4 now specify exactly that; a query never fails and the three outcomes are never conflated. Was NEEDS ATTENTION until the clarification resolved the previously-unspecified failure behavior. |
| **A Gate's Population Is Part of Its Claim** | PASS | FR-009/010's content-type dimension is exactly this principle applied to retrieval: a relevance claim scoped to the wrong population (e.g. `kg_term` rows polluting a prose-content query) is what `WithPopulation` already fixed once; generalizing it keeps the population explicit rather than implicit. |
| **A Screen's Precision Is Not Its Recall** | NEEDS ATTENTION | The Jordan Wave-2 web research is a screen with unknown recall (a null identity-match result does not prove no identity exists, only that this search did not find one) — `research.md` must state this explicitly rather than imply completeness, and SC-008 already requires every new claim to cite its source for exactly this reason. |
| **A Gate Cannot See a Displacement Larger Than Its Window** | NEEDS ATTENTION | The embedding bake-off (FR-016) evaluates on textbook/prose content specifically, per spec — the plan must not generalize a bake-off win on that narrow window into a claim about code/transcript retrieval quality, which the current default was actually chosen for. Flagged for `data-model.md`'s bake-off result schema to carry an explicit "evaluated-on" population field. |
| **A Rule Enforced by Nothing Is Not a Rule** | NEEDS ATTENTION | FR-008 (reranking), FR-010 (content-type chunking) and FR-011 (incremental re-index, never mix generations) each need a paired mutation test, not just a passing happy-path test, matching this project's existing `--prove-failure` convention (e.g. `verify-pretooluse-guard.sh --prove-failure`). Tracked into Execution Strategy's TDD Requirements below. |
| **Reproduce Before Repairing** | PASS | The Jordan correction does not "repair" REQ-6 by assumption — Wave-2 research reproduced the original Germany-identity-search methodology against Jordan before concluding the same null result, rather than assuming it would transfer. |
| **A Statistic a Fix Can Overshoot Requires a Two-Sided Check** | NEEDS ATTENTION | The reranking stage's own evaluation (SC-002/SC-003) needs a two-sided check: measuring only "more relevant results float up" risks missing "previously-correct top-1 results get bumped down" — `quickstart.md` must include a regression scenario using today's known-good top-1 answers, not only the known-bad ones the reranker is meant to fix. **This is not hypothetical caution**: `reorderWindow`, this codebase's existing window-reorder mechanism, was measured to do exactly this (helps some query classes, costs others — net not a clear win, which is why it ships off by default) — the cross-encoder stage must be held to the same two-sided measurement before any decision to enable it by default, not a lesser bar because it is "smarter." |
| **The Content Boundary Is a Standing Invariant** | PASS (by construction) | This plan's own Summary and Technical Context sections already apply the rule: no client-identifying content from `workshop/docs/research/clients/` appears anywhere in this document or any planned artifact. Enforced procedurally in Execution Strategy's Review Gates below (a dedicated boundary self-check before any commit touching Jordan-correction content). |
| **Stage the Pointer and Its Manifest Together** | N/A | No submodule-pin change is part of this feature. |
| **Isolation by Default (mutation-paired gates)** | NEEDS ATTENTION | Same substance as "A Rule Enforced by Nothing" above — restated here because this project's constitution names both; satisfied by the same paired-mutation tasks. |
| **Comprehensive Documentation** | NEEDS ATTENTION | `CONTINUATION.md` at the umbrella root must record this feature's branch and active-work state once implementation begins (not yet done — this plan has not yet reached implementation). Tracked as a Phase-1 polish task. |

No PASS-blocking VIOLATION was found. Every NEEDS ATTENTION item above is addressed by a concrete
Phase 1 artifact or Execution Strategy task named next to it, not deferred without a plan.

## Project Structure

### Documentation (this feature)

```text
specs/017-exhaustive-rag-expansion/
├── spec.md                          # Feature specification
├── plan.md                          # This file
├── research.md                      # Phase 0 output (below)
├── data-model.md                    # Phase 1 output
├── contracts/                       # Phase 1 output
│   ├── textbook-ingestion-stage.md
│   ├── reranker-service-contract.md
│   ├── content-type-classification-contract.md
│   └── embedding-bakeoff-contract.md
├── quickstart.md                    # Phase 1 output
├── checklists/requirements.md       # Already generated by /speckit-specify
└── tasks.md                         # /speckit.superspec.tasks output (not yet generated)
```

### Source Code (repository structure — real paths, not placeholders)

```text
submodules/RAG/pkg/                              # consumed by reference, extended not forked
├── chunker/chunker.go                           # Chunker interface; NEW hierarchical chunker implements it
├── retriever/retriever.go                       # Retriever interface, Document, Options — unchanged
├── reranker/reranker.go                         # Reranker interface — UNCHANGED; the concrete
│   │                                               #   cross-encoder implementation lives in
│   │                                               #   workshop/platform/backend/pkg/rerank (below),
│   │                                               #   not here — this module stays interface-only
├── hybrid/hybrid.go                              # RRFStrategy, LinearStrategy — unchanged
└── grounding/{grounding.go,extractive.go}        # RetrievalGate, citation validation — unchanged
    (pipeline/pipeline.go's Stage/Builder is NOT used — CORRECTED 2026-10-05: `grep -rn
    "digital.vasic.rag/pkg/pipeline"` across the whole workshop backend returns zero hits. The
    real query path is workshop's own hand-written `(*Service).fuse`/`split` in service.go; this
    feature's reranker composes directly into THOSE functions, not into a generic Stage/Builder.)

workshop/platform/backend/                        # PRIVATE submodule — all code changes land here
├── pkg/search/
│   ├── lexical.go                                # unchanged
│   ├── semantic.go                                # WithPopulation generalized (FR-009)
│   ├── lumen.go                                   # unchanged
│   ├── rerank_window.go                          # EXISTING — reorderWindow, the real window-local
│   │                                               #   reranker (research.md §0). UNCHANGED code;
│   │                                               #   the new cross-encoder stage is a SIBLING
│   │                                               #   mode in split(), not a replacement of this.
│   └── service.go                                 # split() gains a second flag-gated branch calling
│   │                                               #   the new pkg/rerank.Client, mutually exclusive
│   │                                               #   with WindowRerank at request time (Constraints)
├── pkg/rerank/                                    # NEW package: llama-server HTTP client, implements
│   │                                               #   submodules/RAG/pkg/reranker.Reranker's method
│   │                                               #   shape (so its TYPE SIGNATURE matches that
│   │                                               #   interface) but is called directly from
│   │                                               #   split(), not through pipeline.Builder
│   └── client.go
├── pkg/crossref/{crossref.go,traverse.go}         # unchanged (its own "why MMR is not used here,
│   │                                               #   though it is available" note is the proof
│   │                                               #   MMR was never load-bearing in this codebase)
├── internal/passagestore/domain.go                # content-type classification extends KnownKinds/ValidateRecord
├── cmd/index-embed/main.go                        # unchanged mechanism, reused as-is for incremental re-index
│   │                                               #   and for the offline bake-off (FR-011, FR-016)
├── cmd/workshop-server/main.go                    # NEW flag `-search-cross-encoder-rerank` /
│   │                                               #   `WORKSHOP_SEARCH_CROSS_ENCODER_RERANK`,
│   │                                               #   mirroring `-search-window-rerank`'s own
│   │                                               #   shape (main.go:408); wires svc.CrossEncoderRerank,
│   │                                               #   mutually exclusive with svc.WindowRerank;
│   │                                               #   calibratedFloor untouched (see Constraints)
└── cmd/reranker-probe/main.go                      # NEW: health-check CLI mirroring cmd/runtime-probe's pattern

workshop/pipeline/
├── md_sections.py                                  # UNCHANGED — precedent read, not copied (see Summary point 3)
├── transcribe/pdf_notes.py                         # UNCHANGED — meeting-notes PDF precedent, read for its
│   │                                                 #   pdftotext -layout convention, not textbook-applicable as-is
└── pdf_textbook_sections.py                        # NEW: textbook PDF ingestion script (FR-001–007), informed
                                                       #   by both precedents above but purpose-built for textbook
                                                       #   structure (chapters/sections vs. meeting-note headers)

workshop/textbooks/ai_001/                          # PRIVATE — real textbook PDFs, ingestion target (FR-001)
workshop/docs/research/clients/jordan/              # PRIVATE — corrected-and-researched client content
                                                       #   (renamed from germany/; FR-014/015/017). Content never
                                                       #   duplicated into this public repo's specs/ tree.

specs/012-document-ingestion-textbooks/             # PREREQUISITE, not duplicated — this feature extends its
specs/015-universal-content-model-profile/          # PREREQUISITE — LocationAnchor/Material types reused as-is
```

**Structure Decision**: Every code change lands inside the existing `workshop/platform/backend`
Go module and `workshop/pipeline` Python scripts — both already-running components of a single
backend service plus its offline ingestion pipeline. This is **not** a new service, new module, or
new repository: no `src/`, `tests/unit`, `tests/integration` scaffold is created at this
umbrella-root level, because the umbrella root is a monorepo of independent projects and this
feature's code belongs entirely inside one existing project (`workshop`). The `submodules/RAG`
change (the new hierarchical chunker only — **corrected 2026-10-05**: the concrete cross-encoder
reranker implementation is NOT a `submodules/RAG` change; `pkg/rerank` lives entirely inside
`workshop`, since the `llama-server` HTTP integration is a backend-specific choice, not a
generically reusable RAG-library concern, and `workshop`'s query path never routes through that
module's `pipeline.Builder` abstraction in the first place) is an additive implementation of that
module's own already-exported `Chunker` interface — composed into the pipeline, not merged into or
forked from the module's own git history (which this umbrella repository does not own or commit to
directly; see §11.4.28/§11.4.74 and the project's own "Submodules-As-Equal-Codebase" governance).
Where a change genuinely belongs in `submodules/RAG` itself (the new chunker type), it is proposed
as a change to that submodule's own repository, pinned and manifest-staged together per
"Stage the Pointer and Its Manifest Together," not vendored as a local fork.

## Execution Strategy

### TDD Requirements

- [x] **`pkg/rerank` (new llama-server client)**: strict RED-GREEN-REFACTOR. The HTTP contract
      (request/response shape, timeout, unavailable-backend fallback) has many edge cases
      (empty candidate set, backend down, malformed response, batch-size limits) and a silent
      wrong behavior here (e.g. swallowing an error as an empty-but-successful rerank) is exactly
      the "Honest Instruments" violation flagged in the Constitution Check above.
- [x] **`rerank_cache` write-through/read-on-failure (NEW, added 2026-10-05 per `/speckit-clarify`)**:
      strict TDD covering all three outcomes — write on `reranked_fresh`, read on cache-hit
      (`served_from_cache`), and correct fallback to the pre-rerank order on cache-miss
      (`fallback_no_cache`) — plus the eviction policy the task breakdown must define
      (contracts/reranker-service-contract.md's "Cache storage contract"). A test proving a STALE
      cache entry (written before a corpus change) is still served as `served_from_cache` rather
      than silently invalidated is required, so the documented staleness limitation is an observed
      behavior, not an assumed one.
- [x] **Content-type classification (`internal/passagestore/domain.go` extension)**: strict TDD.
      `ValidateRecord`'s existing invariants (kind membership, human-only speaker attribution,
      media-backed-kind field requirements) must keep passing for every existing kind while the
      new classification is added — a classic "extend without regressing" case best proven by
      tests written before the extension.
- [x] **`pdf_textbook_sections.py` idempotency**: strict TDD, explicitly modeled on
      `md_sections.py`'s own tiered-match test suite (anchor match → exact-text match →
      elided-text bridge → unique-line-range match) — write the characterization tests against
      the EXISTING `md_sections.py` behavior first (proving the pattern is understood), then write
      the new script's tests in the same shape before implementing.
- [x] **`CrossEncoderRerank`/`WindowRerank` mutual exclusivity** (**corrected 2026-10-05**, was
      "Reranker-before-MMR pipeline ordering" — that framing assumed an MMR composition point
      that does not exist in this codebase; see research.md §0 and the corrected Constraints
      above): a dedicated test asserting that `split()` runs at most ONE window-reorder per
      request — `reorderWindow` when `WindowRerank` is set, the new cross-encoder client when
      `CrossEncoderRerank` is set, never both — and that enabling both on the same `Service` is
      refused at construction/startup rather than silently running one and ignoring the other or
      composing them in an unreviewed way (satisfies "A Rule Enforced by Nothing Is Not a Rule").

### Parallel Execution Opportunities

- [x] **User Story 1 (textbook ingestion)** and **User Story 2 (cross-encoder reranking)** share
      no files — `pdf_textbook_sections.py` touches only the Python pipeline;
      `pkg/rerank`/`pkg/reranker` touches only Go. Fully parallelizable.
- [x] **User Story 5 (Jordan correction)** is independent of every other story and is additionally
      **isolated by content boundary** — it touches only paths inside the private `workshop`
      submodule's research directory and never the shared Go/Python code paths. Dispatch to a
      subagent that is explicitly briefed on the content-boundary constraint before it starts.
- [x] **User Story 3 (content-type dimension)** has a real dependency on User Story 1: the new
      textbook content type is one of the concrete population classes User Story 3 must handle,
      so User Story 3's chunking/classification work should start only after User Story 1's
      ingestion script defines what a "textbook section" passage looks like (or run them with a
      shared design checkpoint between the two implementers rather than fully independently).
- [x] **User Story 4 (incremental re-indexing)** depends on User Story 3's content-type dimension
      existing (an incremental re-index must know what content type a new passage is to classify
      it correctly) — sequence after US3, not parallel with it.

### Human Checkpoints

1. After foundational setup — verify the embedding-model bake-off decision (FR-016) is locked in
   (a model switch, or an explicit decision to keep the current default) before any chunking or
   reranking work depends on a specific embedding dimension/context-length assumption.
2. After each user story — verify behavior matches acceptance scenarios; for User Story 5
   specifically, verify via `scripts/verify-content-boundary.sh`-style review that no
   client-identifying content crossed into the public repository before that story's commits are
   pushed anywhere.
3. After all stories — run the full existing regression suite (`pkg/search`, `pkg/crossref`,
   `internal/passagestore` Go tests; `workshop/pipeline` Python tests) before polish phase, plus
   the two-sided reranking check named in the Constitution Check table above.
4. Before merge — final review against spec, with the content-boundary self-check as a named,
   non-skippable item on that review (not merely implied by "review the diff").

### Review Gates

- [x] **`pkg/rerank` client contract / `contracts/reranker-service-contract.md`**: review before
      implementing `cmd/workshop-server`'s consumer of it — an external-process HTTP contract is
      exactly the kind of interface this project's "Review Gates" convention exists for.
- [x] **Content-type classification data model (`internal/passagestore/domain.go` changes)**:
      review before migration — it extends `KnownKinds`/`ValidateRecord`, both load-bearing
      invariants for every existing passage kind.
- [x] **Any commit touching `workshop/docs/research/clients/jordan/`**: mandatory content-boundary
      self-review before commit, separate from ordinary code review — confirm no
      client-identifying text appears in any file outside the private `workshop` submodule, and
      that the commit itself stays inside that submodule's own history.

## Complexity Tracking

> Two items are flagged for explicit justification, not because they violate a constitution
> principle outright, but because each adds real implementation weight.

| Addition | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Hierarchical parent-child ("auto-merging") chunker, built from scratch in `submodules/RAG/pkg/chunker` | Textbook chapters are long, structured prose where a retrieved child chunk often needs its parent section's context to be useful; flat fixed-size chunking (the existing `FixedSizeChunker`/`RecursiveChunker`) loses that structure. Feasibility research confirmed no existing Go library implements this pattern. | Reusing `RecursiveChunker` as-is was rejected: feasibility research found its `mergeAndOverlap` does not actually implement the overlap its own config field promises (`submodules/RAG/pkg/chunker/chunker.go:215`) — building on a chunker with a known-silent defect would inherit that defect into textbook content specifically, the one content type this feature is adding. |
| A new external process dependency (`llama-server --reranking`) rather than an in-process Go reranker | A genuine cross-encoder relevance model requires a transformer forward pass per query-document pair; no pure-Go implementation exists in this codebase or was found during feasibility research. `MMRReranker` is proven NOT to be one (it overwrites scores with Jaccard overlap) — which is WHY this codebase measured it and removed it from production use entirely (research.md §0), not a reason to route the new stage through it. Nor does `reorderWindow`'s existing BM25-OR window reorder substitute for a true learned relevance model — it is lexical, not learned, and FR-008 specifically asks for the latter. | An in-process Go ONNX runtime was rejected: it would be the first ONNX dependency in this codebase, adding build/deploy surface for a single feature, versus `llama-server`, which this stack can run the same way it already runs other `llama.cpp`-family tooling referenced elsewhere in this project's own containers tooling. |
