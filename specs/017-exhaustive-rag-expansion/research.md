# Phase 0 Research: Exhaustive RAG Expansion + Textbook Ingestion + Jordan Correction

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)
**Method**: Three parallel research forks dispatched before planning began — (1) deep technical
facts on the RAG/workshop codebase, (2) feasibility research on reranking/chunking/embedding
candidates, (3) Jordan Wave-2 client research. Findings are consolidated below by topic, each
resolving one area of the plan's Technical Context. No `NEEDS CLARIFICATION` marker remains.

## 0. CORRECTION (2026-10-05, during `/speckit.superspec.execute`): the real reranking architecture

**Everything in §1 below was written without knowledge of code that already exists and is
already deployed.** During implementation (Phase 2/4 investigation), reading
`workshop/platform/backend/pkg/search/service.go`'s `fuse`/`split` functions and
`pkg/search/rerank_window.go` end to end revealed a materially different picture from what §1
assumed. This section is the correction; §1 is kept below, superseded, because the sequence is the
lesson (research that skips reading the actual pipeline code reaches a wrong premise even when its
literal claim — "no cross-encoder exists" — is technically true).

**MMR is not used anywhere in the production workshop backend, and never "remains available" for
anything.** `digital.vasic.rag/pkg/reranker.MMRReranker` still exists as library code, but:
- It was **removed** from `(*Service).fuse` after being measured, live, to be both
  non-deterministic (its greedy argmax ranges over a Go map; measured over the 26-query benchmark:
  the served *set* varied on 14/26 identical calls at limit=10, the served *order* on 19/26) and
  score-corrupting (`Rerank` overwrites `doc.Score` with a Jaccard word-overlap ratio against the
  raw query string — measured live: three semantic hits scored exactly `0` because the matched
  passages didn't literally contain the query word despite being genuine embedding matches).
- `pkg/crossref` **explicitly declines to use it**, for the identical documented reason
  (`crossref.go`'s own package doc, section "WHY MMR IS NOT USED HERE, THOUGH IT IS AVAILABLE").
- So there is no "existing MMR mechanism" anywhere in this codebase for a new reranking stage to
  be "composable with" or to "preserve for passage cross-referencing" — that entire framing,
  carried into FR-008 and `plan.md`'s Constraints, is **built on a premise that does not hold**.

**The real existing reranking mechanism is `reorderWindow` (`pkg/search/rerank_window.go`), gated
by the `Service.WindowRerank` flag (CLI `-search-window-rerank`, env
`WORKSHOP_SEARCH_WINDOW_RERANK`) — OFF by default in production.** It is a pure permutation of the
already-floor-filtered, already-served hit window: BM25-OR indexed over just that window (a
mini-corpus of at most `limit` documents), fused via RRF with the incoming order, applied only to
the window `split` already decided to serve. It cannot add, remove, or rescore a hit — abstention
and the relevance floor are structurally outside its reach, by the same "permutation, not a new
retrieval" argument FR-008 independently arrives at for the cross-encoder stage. It is OFF by
default because it was measured, live, to help some query classes and cost others (widening the
window from 1 to 2+ did not improve the 22-query kinds benchmark; turning the base mechanism on
costs 4 of 12 term queries per its own flag's help text) — not a clear net win, not yet a defect
either.

**What this means for FR-008 and the cross-encoder stage's design:**
1. The cross-encoder must compose with `(*Service).fuse`'s real pipeline — RRF-fuses lexical/
   semantic/code passage populations, rescales and rank-interleaves catalogue (knowledge-graph)
   rows onto the same curve via `mergeLexical`, dedupes, filters, then optionally (if
   `WindowRerank`) permutes the served window via `reorderWindow` — not with a fictional
   MMR step that was never actually in this path.
2. The cross-encoder stage and `reorderWindow` are two candidate answers to the SAME question
   (how should the served window be reordered for relevance beyond RRF's rank-position fusion).
   Whether the new stage REPLACES `reorderWindow`'s role, runs ALONGSIDE it as an alternative
   selectable mode, or SUPERSEDES it outright is a genuine design decision this correction does
   not make unilaterally — `plan.md`'s corrected design states the chosen answer explicitly.
3. The two-sided regression discipline `reorderWindow`'s own measurement already demonstrates
   (helps some queries, costs others — never assume a reorder is a pure win) applies with full
   force to the cross-encoder stage too, reinforcing rather than introducing the "A Statistic a
   Fix Can Overshoot Requires a Two-Sided Check" Constitution principle already cited in `plan.md`.

**`spec.md`'s FR-008 and User Story 2's Acceptance Scenario 1 carry the same false MMR-preservation
premise and were NOT corrected in this pass** — the operator's instruction for this correction
named `research.md`/`plan.md`/`data-model.md`/`contracts/` specifically; `spec.md` needs its own
follow-up correction (structurally the same kind of fix `/speckit-analyze` already applied twice
to this spec for similar "premise disproven by this feature's own research" defects) before this
feature's documentation set is fully consistent again.

## 1. Reranking: Decision (SUPERSEDED BY §0 ABOVE — kept for the history, not as current fact)

**Decision**: Add a cross-encoder reranking stage served by `llama-server --reranking` running
`bge-reranker-v2-m3-GGUF`, composed into the existing `submodules/RAG/pkg/pipeline` **ahead of**
`MMRReranker`.

**Rationale**:
- `bge-reranker-v2-m3-GGUF` is MIT-licensed, ~0.6B parameters, and measured at ~241 ms average CPU
  latency per batch on the reference hardware profiled during feasibility research — well inside
  this stack's CPU-only constraint and the existing query latency budget.
- The existing `MMRReranker` (`submodules/RAG/pkg/reranker/reranker.go`) is **not** a relevance
  model: its `Rerank` method computes Jaccard word-overlap similarity and, at line 205,
  unconditionally does `doc.Score = querySims[idx]` — overwriting whatever cosine/BM25 score the
  retriever produced. Running it alone (as today) means there has never been a true relevance
  reranking stage in this stack, only a diversity reorder. This is exactly the defect
  `workshop/platform/backend/pkg/crossref/crossref.go:26-37` already documents and defends
  against by NOT running candidates through MMR when it would discard a semantic ranking.
- A cross-encoder stage must therefore run **before** MMR: its score becomes the relevance input
  MMR diversifies against, rather than being silently discarded by MMR's own overwrite.

**Alternatives considered**:
- *Python sentence-transformers sidecar process.* Rejected — introduces a second runtime
  (Python, with its own model-loading and process-lifecycle concerns) into what is otherwise a
  Go-service-plus-CLI-shellouts architecture, for no serving-latency benefit over `llama-server`.
- *In-process Go ONNX runtime.* Rejected — no mature Go ONNX binding is already used anywhere in
  this codebase; adopting one is a larger dependency-surface decision than this feature's scope
  warrants, and it would need its own feasibility pass independent of the reranking decision.
- *Keep using `MMRReranker` as the only reranking step.* Rejected — per the finding above, it
  provides no relevance-model signal at all; this would leave FR-008 unmet.

## 2. Chunking: Decision

**Decision**: Build a new hierarchical parent-child ("auto-merging") chunker in
`submodules/RAG/pkg/chunker`, implementing that package's existing `Chunker` interface
(`Chunk(text string) []Chunk`), rather than extending or forking the existing
`FixedSizeChunker`/`RecursiveChunker`/`SentenceChunker`.

**Rationale**:
- Feasibility research found **no existing Go library** implementing hierarchical parent-child
  chunking; this is a from-scratch build, acknowledged and justified in `plan.md`'s Complexity
  Tracking.
- The existing `RecursiveChunker`'s `mergeAndOverlap` (`submodules/RAG/pkg/chunker/chunker.go:215`)
  does **not** actually implement the overlap its own `Config.Overlap` field promises — a silent
  defect discovered during technical-facts research. Building the new chunker on top of this
  known-silent defect would inherit it into the one content type (long-form textbook prose) where
  overlap matters most for preserving cross-chunk context.
- `SentenceChunker`'s `getOverlapText` (line 370) DOES implement real overlap and is the pattern
  the new hierarchical chunker's own overlap logic should follow, not `RecursiveChunker`'s.

**Alternatives considered**:
- *Flat fixed-size chunking* (`FixedSizeChunker`, already used for transcript/code content).
  Rejected for textbook content specifically — long structured prose chapters lose section-level
  context when chunked flatly; a retrieved child chunk often needs its parent section to be
  useful to a reader or to a downstream citation check.
- *Reuse `RecursiveChunker` as-is, accepting its overlap defect.* Rejected per the rationale above.

## 3. Embedding model bake-off: Decision

**Decision**: Run an **offline** bake-off, using the existing generation-scoped re-embedding
mechanism (`cmd/index-embed`, which already supports `-generation -1` auto-increment with zero
live-service risk — see §4 below), evaluating four candidates specifically on textbook/prose
content (the content type the current default was never evaluated against):

| Candidate | License | Dim / Context | Notes |
|---|---|---|---|
| `jina-embeddings-code-cpu` (current default) | **Apache-2.0**, confirmed | — | The CC-BY-NC worry raised before this research was unfounded: that non-commercial license applies to a different, newer Jina model family, not this one. |
| `nomic-embed-text` | Apache-2.0 | 8192 tokens stated; **~7000-char practical ceiling observed** | Discrepancy between the stated token limit and the observed character ceiling is flagged `UNCONFIRMED` — not reconciled by this research; `calibratedFloor` is only calibrated for this model at an exact historical corpus size (2478 PIDs), which the bake-off must not be read as updating. |
| `Qwen3-Embedding-0.6B` | Apache-2.0 | — | MTEB retrieval nDCG@10 = 61.41 in published benchmarks. |
| `BGE-M3` | MIT | 1024-dim, 8192-token context | Supports dense+sparse hybrid retrieval, which this stack does not currently use but which is a candidate future enhancement outside this feature's scope. |

**Rationale**: The current default was never evaluated against textbook/prose content; it was
chosen for code/transcript retrieval. A bake-off scoped to the actual new content type (textbooks)
is the narrowest evidence-backed way to answer "is the current default still right," without
generalizing a result on one content population to a claim about the whole corpus (see `plan.md`'s
Constitution Check row "A Gate Cannot See a Displacement Larger Than Its Window").

**Alternatives considered**:
- *Skip the bake-off, keep the default.* Rejected by the operator's own resolution of FR-016 (Q1):
  the bake-off is explicitly in scope.
- *Switch embedding models immediately without a bake-off.* Rejected — no evidence yet exists to
  justify a switch; §11.4.6 (no-guessing) forbids asserting a better model without measurement.

## 4. Incremental re-indexing mechanism: Decision

**CORRECTION (2026-10-05, tasks.md T037).** The Decision and Rationale below are WRONG on the one
claim that matters for FR-011/SC-004 ("never a mandatory full-corpus re-embed" / "a measured,
bounded incremental update"), and the error is not a measurement gap — it is a PRE-EXISTING,
already-documented, already-named finding this research simply failed to cross-reference: **G-IDX-2**
(`workshop/platform/backend/pkg/index/incremental_test.go`,
`TestGateIDX2_ChapterAdditionInvalidatesCarryForwardForTheWholeCorpus`, from an earlier spec round).
Re-run fresh today (2026-10-05) rather than assumed stale: `go test ./pkg/index/... -run
TestGateIDX2 -v` → **PASS** — and this test's own PASS is the finding, not a clean bill of health:
its assertions are written to pass WHILE the gap exists and to FAIL the day it is fixed (its own
comment: *"EXPECTED FINDING DID NOT REPRODUCE... if this now succeeds, the root_hash-equality
restriction has been relaxed"*).

**The mechanism, read precisely, is NOT "no content-type-specific logic, therefore sound for any
addition."** `search.CarryForwardVectors` (`pkg/search/carryforward.go`) copies a prior
generation's vectors into a new one ONLY when the two generations share an IDENTICAL `root_hash`
— a hash over the WHOLE member set's `(pid, content_hash)` pairs. Adding ANY content (a textbook,
same as "a chapter") changes the member set, which ALWAYS changes `root_hash`, so carry-forward
finds no candidate and copies **nothing** — not even the unchanged members. `search.IndexVectors`
then treats every member, old and new, as pending, because it selects "passages with no row in
`embeddings` FOR THAT GENERATION" and the new generation starts with zero rows for everyone. So
adding one textbook to an N-textbook corpus re-embeds all N+1, not just the new one — the literal
shape FR-011 forbids ("never a mandatory full-corpus re-embed") and SC-004 requires be absent
("costs a measured, bounded incremental update").

**Why this is a correction and not merely a restatement of G-IDX-2.** G-IDX-2 was written against
a generic "chapter addition" and reserved its own fix to "someone else" in a different round; this
research cited the SAME underlying mechanism (`search.IndexVectors`/`CarryForwardVectors`) and
concluded the opposite ("requires no new mechanism") without checking whether that someone had
ever acted. They had not. Per §11.4.214 (recurrence-links-not-mints), T037 does **not** mint a
second, textbook-flavoured copy of this finding — it links to G-IDX-2, confirms it still
reproduces today, and corrects this document instead.

**What a real fix would require, assessed rather than guessed, and NOT implemented in this
pass.** `CarryForwardVectors`'s root_hash check is whole-generation because `embeddings` records
no PER-PID content identity — only `(pid, generation, model, dim, vec)`. `passages.content_hash`
(the per-pid value `root_hash` is itself computed FROM — `submodules/passage/pkg/passage/
registry.go:1036`, `content_hash TEXT NOT NULL`) is REBUILT WHOLESALE every boot with no
generation history, so there is no way to ask "was pid X's content, AS OF the generation that
embedded it, the same as it is now" without recording that fact AT EMBED TIME. A sound per-pid fix
therefore needs: (1) a schema migration adding a `content_hash` column to `embeddings`, written by
`IndexVectors` from `passages.content_hash` at insert time; (2) `CarryForwardVectors`'s match
changed from `g.root_hash = ?` to a per-pid join on `embeddings.content_hash = passages.content_hash`,
dropping the whole-generation requirement entirely; (3) the IDENTICAL shape mirrored in
`pkg/crossref/carryforward.go` (G-IDX-2's own file names it as sharing the defect) to close FR-011
for derived cross-references, not only vectors; (4) re-validating every one of the ~8 existing test
files that construct a raw `embeddings`/`passages` fixture without a `content_hash` column
(`pkg/search/carryforward_test.go`, `coverage_test.go`, `floor_scope_test.go`,
`semantic_deadline_test.go`, `veccache_test.go`, `content_type_scope_test.go`, plus
`pkg/crossref/floor_population_test.go`). This is a real, cross-package, production-hot-path
schema change — `embeddings` is read and written on every `cmd/workshop-server` boot — and
G-IDX-2's own file pre-authorizes exactly this response to a change of this shape: *"if it turns
out to be a much larger change than expected, stop and report back honestly... rather than rushing
a risky change."* This document does that rather than attempting the migration inside this task.

**FOLLOW-UP CORRECTION (2026-10-05, tasks.md T039): the assessment above was acted on, not left as
future work — the sentence "NOT implemented in this pass" is WITHDRAWN.** All three steps named
above for the VECTOR leg were implemented in `pkg/search/carryforward.go`/`semantic.go`:
`ensureEmbeddingsSchema` migrates `content_hash` into `embeddings` via an additive `ALTER TABLE`
(never a drop-and-rebuild — vectors are too expensive to lose), `IndexVectors` writes it at embed
time, and the new `carryForwardPerPID` function runs as a fallback inside `CarryForwardVectors`
whenever the whole-generation `root_hash` match finds nothing — matching per pid on
`embeddings.content_hash = passages.content_hash` instead. Every one of the pre-existing fixture
files the assessment listed (and several more: 11 in total) was individually verified to still
pass unmodified, because the new path degrades to a documented no-op against a `passages` table
with no `content_hash` column — a defensive compatibility guard, not a rewrite of those fixtures.
Real end-to-end confirmation (tasks.md T040, no mocks): adding a real second textbook
(LLM Engineers's Handbook, 513 passages) to an already-embedded real first textbook (OpenAI API
Cookbook, 179 passages) via a real running Ollama embedder carried all 179 unchanged vectors
per-pid with **zero** embedder calls and embedded **exactly** the 513 genuinely new ones — no
full-corpus re-embed.

**Honest boundary this correction does NOT close.** Step (3) of the assessment above —
`pkg/crossref/carryforward.go`'s identical whole-generation-root_hash limitation for DERIVED
CROSS-REFERENCES — was explicitly named as sharing the defect and was **NOT** fixed in this pass.
Crossref derivation is in-process and measured elsewhere in this codebase as cheap relative to an
embedding provider round trip, so FR-011's costliest violation (re-contacting an embedding
provider for unchanged content) is closed; a corpus addition still re-derives cross-references for
the whole corpus, which remains a real, smaller, UNFIXED instance of the same gap.

**Original (now-superseded) Decision and Rationale, kept for the record:**

**Decision**: Reuse `cmd/index-embed`'s existing generation-scoped mechanism unchanged — new
content (a new textbook, a future chapter) gets embedded into a **new generation**, never mixed
into an existing one, and the semantic retrieval path already reads the latest generation by
default. This is the proven "offline-then-transplant" pattern already used for embedding-model
migration; it requires no new mechanism, only consistent use of the existing one as new content
types are added.

**Rationale**: `search.IndexVectors(ctx, db, e, generation, batch)`
(`workshop/platform/backend/pkg/search/semantic.go:529`) is the exact function `cmd/index-embed`
already calls — there is no second implementation to maintain, and the bake-off in §3 can run
entirely offline against new generations without touching the generation the live service reads.

**Alternatives considered (superseded)**: None — this is confirmed-existing infrastructure, not a design
choice; the only decision was confirming it generalizes to "any future content addition," which it
does by construction (the mechanism has no content-type-specific logic).

## 5. Textbook PDF ingestion: Corrected precedent and decision

**Decision**: Build a new, purpose-built ingestion script, `workshop/pipeline/pdf_textbook_sections.py`,
rather than extending `workshop/pipeline/md_sections.py` (which has no PDF handling) or copying
`workshop/pipeline/transcribe/pdf_notes.py` (which handles a structurally different source type).

**Critical correction**: Specification 012 (`specs/012-document-ingestion-textbooks/`) claims the
`pdftotext -layout` convention needed for textbook PDF extraction is "already proven elsewhere" in
this codebase. **This is incorrect.** Technical-facts research found `pdftotext -layout` used only
in `workshop/pipeline/transcribe/pdf_notes.py` (lines 182, 195), and that file processes **meeting
notes**, not textbooks — a different document structure (notes/action-items vs. chapters/sections)
with different section-boundary heuristics. `md_sections.py`, the file that would actually be
extended for textbook markdown-derived content, contains **no** `pdftotext` call at all. Spec 012
Phase 2 (PDF textbook ingestion) therefore has **no existing code to build on** beyond this
unrelated precedent, contrary to its own plan's assumption. This correction must be carried into
spec 012's own tracking when that spec is next touched (out of this feature's direct scope, but
recorded here so the gap is not silently rediscovered).

**books-for-bots adoption decision**: `prime-radiant-inc/books-for-bots` (Rust, EPUB-only CLI, MIT
license) is **not adopted as a dependency** — it targets EPUB, and this feature's textbooks are
PDF (`workshop/textbooks/ai_001/`). Its two **design patterns** are adopted instead:
1. **Offset-based direct-read location anchors** — byte/line offsets into flattened text, so a
   citation can point at an exact location rather than a fuzzy section name. This generalizes the
   `LocationAnchor{SectionID, Locator, PassageAnchor}` struct already defined in spec 015's
   `data-model.md`, reused as-is by this feature (see `data-model.md` below).
2. **TOC→heading→title→filename chapter-resolution fallback chain** — a graceful-degradation
   lookup order for resolving "what chapter is this passage in" when the strongest signal (a
   table-of-contents entry) is unavailable. Adopted for `pdf_textbook_sections.py`'s own
   chapter-resolution logic.

**Idempotency**: must match `md_sections.py`'s proven tiered-priority algorithm — (0) inline
anchor comment, (1) exact text match, (1b) elided-text match (a historical bug-repair bridge),
(2) line-range match, only when exactly one candidate exists — adapted to PDF-extracted text
(which lacks the inline-comment mechanism markdown has, so tier 0 is not directly portable; the
new script's design must substitute a PDF-appropriate anchor, e.g. a content-hash sidecar entry,
for that tier — see `data-model.md` and `contracts/textbook-ingestion-stage.md`).

## 6. Jordan correction and Wave-2 research: Decision and Content-Boundary note

**Decision**: Both halves of the resolved FR-017 are completed at the research level: (a) a
correction pass identifying every Germany-grounded reference needing update to Jordan, and (b) a
Wave-2 web-research pass independently re-deriving Jordan-specific candidates for REQ-6 using the
same methodology as the original (Germany-targeted) research.

**Findings, reported by mechanism only — see Content Boundary note below**:
- The Wave-2 search mirrored the original company-identity-search methodology, now targeted at
  Jordan instead of Germany, and found **no definitive Jordan-based identity match** for the
  client entities named in the existing (private) research document — the same null result as the
  original Germany-targeted search. This is a **screen result, not a proof of absence** (see
  `plan.md`'s Constitution Check row "A Screen's Precision Is Not Its Recall") — a future search
  with different terms or sources could still find a match.
- The Wave-2 research did find concrete, independently-verifiable facts about Jordan's data-
  protection regulatory environment relevant to re-grounding REQ-6: Jordan's Personal Data
  Protection Law (Law No. 24 of 2023) requires breach notification to data subjects within
  **24 hours** (shorter than GDPR's 72-hour standard), gates cross-border data transfer on
  consent-or-adequacy, and — unlike some regional frameworks — imposes **no explicit
  data-residency/localization mandate**. These facts are general regulatory facts, not
  client-identifying, and are safe to record in this public repository.

**Content Boundary note (binding on all downstream artifacts of this feature)**: The original
research document, `workshop/docs/research/clients/germany/client-requirements-and-context.md`,
and its Wave-2-corrected Jordan successor, live inside the **private** `workshop` submodule. Both
contain verbatim client feedback, specific company names, and candidate-company names. **None of
that content is reproduced in this document, `data-model.md`, `contracts/`, or any other artifact
in this public `vasic` repository.** This spec's own `spec.md` (User Story 5, FR-014/015)
similarly describes the correction in terms of categories of claims ("a candidate company's
country-of-origin reference," "a market-specific compliance framing") rather than quoting the
actual names — verified before this research.md was written by grepping `spec.md` and
`checklists/requirements.md` for the specific client/candidate identifiers; zero matches found.
The actual correction work (renaming `germany/` to `jordan/`, rewriting REQ-6's grounding, folding
in the Wave-2 findings) happens entirely as commits **inside** the `workshop` submodule, per
this project's own standing content-boundary invariant and its documented 2026-09-01 incident
(`docs/content-boundary-incident-2026-09-01.md` at the umbrella root).

## 7. Summary of resolved NEEDS CLARIFICATION markers

Both markers raised during `/speckit-specify` were resolved by the operator before planning began
(recorded in `spec.md` and `checklists/requirements.md`); no further research was needed to close
them, only the bake-off (§3) and Wave-2 research (§6) their resolutions required, both completed
above.
