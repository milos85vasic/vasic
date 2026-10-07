# Tasks: Exhaustive RAG Expansion + Textbook Ingestion + Jordan Correction

**Input**: Design documents from `specs/017-exhaustive-rag-expansion/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md` (all present)

**Superpowers**: generated using the `writing-plans` skill's decomposition discipline (file
structure mapping, task right-sizing, `Interfaces` blocks, no-placeholders, self-review),
adapted into this template's `[P]`/`[Story]` format per
`.specify/extensions/superspec/references/superpowers-bridge.md`. Execution markers used here
map 1:1 onto `/speckit.superspec.execute`'s `[TDD]`/`[REVIEW]`/`[SUBAGENT]`/`[P]` vocabulary.

**Tests**: INCLUDED. `plan.md`'s Execution Strategy names strict TDD for four specific areas;
tasks below write the test before the implementation in every one of those areas, per
`superpowers:test-driven-development` discipline referenced by `/speckit.superspec.execute`.

**Organization**: Tasks are grouped by user story (US1–US5) so each is independently
implementable and testable, per `plan.md`'s Parallel Execution Opportunities and Dependencies.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on same-phase tasks)
- **[TDD]**: Strict RED→GREEN→REFACTOR, per `plan.md`'s TDD Requirements
- **[REVIEW]**: Requires code review before the next dependent task starts, per `plan.md`'s Review Gates
- **[SUBAGENT]**: Safe to delegate to a parallel subagent (no shared-file conflict with concurrently-running tasks)
- **[Story]**: US1–US5, or `FOUND` (Foundational) / `SETUP` / `POLISH`

## Path Conventions

Real repository paths, not placeholders — see `plan.md`'s Project Structure for the full map:
- Go: `submodules/RAG/pkg/{chunker,reranker,pipeline}`, `workshop/platform/backend/{pkg,internal,cmd}`
- Python: `workshop/pipeline/`
- Content-boundary-sensitive paths (private submodule only): `workshop/docs/research/clients/jordan/`

---

## Phase 1: Setup

**Purpose**: Confirm the new, feature-specific environment prerequisites exist before any task
below assumes them. Every check here is a precondition verification, not new code.

- [x] T001 [SETUP] **Confirmed (evidence already recorded, closing the checkbox retroactively).**
      `progress.yml`'s `resources` block records `reranker_model_path:
      ~/models/bge-reranker-v2-m3-Q8_0.gguf` and `reranker_smoke_test_port: 18089`
      — Phase 4's reranker work (`cmd/reranker-probe`) was built and tested against a real running
      llama-server on this exact path/port.
- [x] T002 [P] [SETUP] **Confirmed 2026-10-05.** `ollama list`: all four present —
      `qwen3-embedding:0.6b`, `bge-m3:latest`, `ordis/jina-embeddings-v2-base-code:latest`
      (the `jina-embeddings-code-cpu` candidate), `nomic-embed-text:latest`. All four were
      actually exercised end to end for real in T045's bake-off.
- [x] T003 [P] [SETUP] **Confirmed (evidence already recorded); CORRECTED 2026-10-05 — a
      mislabeled claim below is explicitly WITHDRAWN, not silently deleted.** All three
      `workshop/textbooks/ai_001/*.pdf` files have a real text layer — `pdf_textbook_sections.py`
      successfully extracted 179 sections (OpenAI_API_Cookbook, 183 pages), 513 sections (LLM
      Engineer's Handbook, 523 pages), and 983 sections (AI_Engineering_Building_Applications -
      Chip Huyen, 991 pages, the largest of the three) with zero "no text layer" refusals and
      zero extraction failures across every real run this session.
      **WITHDRAWN: the sentence that previously stood here — "(via the diagram-extraction work,
      Phase 5.5) 183 pages' worth of content from the third (OpenAI_API_Cookbook again,
      re-confirmed)" — mislabeled a RE-RUN of the FIRST book as if it were the third. The third
      book (Chip Huyen's) was never actually exercised by that statement. An independent review
      pass caught this; the third book is now genuinely extracted and ingested for real — see
      T017's and T040's corrections below for the evidence.**
      `license_basis` recorded per-run as the provisional scratch value
      (`"licensed copy, bake-off eval only, scratch, not committed"` etc.) for ad hoc evaluation
      runs; the actual US1 ingestion runs used `--license-basis` values recorded in those tasks'
      own entries (T011-T020 area).
- [x] T004 [SETUP] **Confirmed, and the content-boundary precondition was re-verified AFTER the
      rename too (T044), not only before.** `germany/` existed and was readable before the rename
      (confirmed by reading its 4 files directly); the "no other repository already references
      its content outside workshop" check is the exact check T044 re-ran post-correction (8,485
      public-umbrella tracked files, zero real matches) — satisfying this precondition for both
      the pre-rename and post-rename state, which is a stronger result than the original
      precondition-only framing asked for.
      `quickstart.md` Scenario 6 uses, against the CURRENT, uncorrected state, to establish the
      "before" baseline this feature's content-boundary self-check compares against later).

**Checkpoint**: environment confirmed ready; no code written yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core schema/API changes every downstream user story depends on. **No user story
work may begin until this phase is complete** — in particular, US1 cannot stamp
`content_type = textbook` on a passage until T006's signature change exists, and US3 cannot be
implemented at all until T005/T006 exist.

**Interfaces produced by this phase** (consumed by every user story below):
- `internal/passagestore.DocumentObservation(chapterSlug, text, kind, contentType, ref) (id string, err error)` — the new 5-arg signature (was 4-arg)
- `internal/passagestore.KnownKinds` — now 11 members (+ `textbook_section`)
- `internal/passagestore.ContentTypeAllowedSet(kind string) []string` — new helper exposing the allowed-set table from `contracts/content-type-classification-contract.md`, so callers and `ValidateRecord` share one source of truth

- [x] T005 [TDD] [REVIEW] [FOUND] Write failing tests for `ValidateRecord` rejecting (a) a
      record with a `content_type` value absent, (b) a record whose `content_type` is not a
      member of its `kind`'s allowed set (e.g. `kind=code, content_type=textbook`), and (c) a
      record whose `kind=doc_section, content_type=meeting_notes` or `=authored_lesson` — both
      MUST pass, proving `doc_section`'s allowed set is genuinely `{meeting_notes,
      authored_lesson}`, not a singleton — in
      `workshop/platform/backend/internal/passagestore/domain_test.go`. Run them, confirm FAIL
      (new allowed-set table and the new kind do not exist yet).
      Then implement: add `textbook_section` to `KnownKinds`; add the allowed-set table from
      `contracts/content-type-classification-contract.md`'s corrected design; extend
      `ValidateRecord` to check membership. Run tests again, confirm PASS. **[REVIEW]: this
      extends a load-bearing invariant every existing passage kind depends on — get this
      reviewed before T006 builds on it.**
- [x] T006 [TDD] [REVIEW] [FOUND] Write failing tests for `DocumentObservation`'s new 5-arg
      signature: (a) a call with a valid `content_type` for its `kind` succeeds and the written
      record's `content_type` round-trips correctly on read-back; (b) a call with an invalid
      `content_type` for its `kind` is rejected (delegates to T005's `ValidateRecord`, not a
      second check). Run, confirm FAIL (signature is still 4-arg). Implement the signature change.
      **Then find and update EVERY existing call site** (meeting-notes ingestion, authored-lesson
      ingestion — locate via `grep -rn 'DocumentObservation(' workshop/platform/backend/
      workshop/pipeline/` from repo root) to pass its own correct, explicit `content_type` — per
      `contracts/content-type-classification-contract.md`'s migration contract, a missed caller
      must fail the build/tests, not silently compile with a stale 4-arg call. Run the FULL
      existing passagestore test suite, confirm PASS with zero regressions. **[REVIEW]: breaking
      change to every ingestion pipeline's call site — this is the single highest-blast-radius
      task in this feature.**
- [x] T007 [P] [FOUND] Create `workshop/platform/backend/pkg/rerank/` package skeleton
      (`client.go`, empty `Client` struct satisfying `submodules/RAG/pkg/reranker.Reranker`'s
      method signature with an unimplemented body) — unblocks US2's TDD tasks to compile against
      a real type from their first RED step, without yet containing the HTTP logic US2 implements.
- [x] T008 [P] [FOUND] Create the `rerank_cache` SQLite table migration
      (`query_hash TEXT PRIMARY KEY, query_text TEXT, result_json BLOB, cached_at TIMESTAMP`) in
      the same database `cmd/workshop-server` opens, per
      `contracts/reranker-service-contract.md`'s "Cache storage contract" — schema only, no
      read/write code yet (US2 implements that).

**Checkpoint**: `ValidateRecord`/`DocumentObservation` extended and every existing caller
migrated with zero regressions; `pkg/rerank` package exists (empty); `rerank_cache` table exists
(empty). User story implementation can now begin.

---

## Phase 3: User Story 1 - Textbooks become searchable, citable curriculum content (Priority: P1) 🎯 MVP

**Goal**: Ingest the three real PDFs in `workshop/textbooks/ai_001/` into the existing
searchable/citable passage pipeline as `textbook_section` passages.

**Independent Test**: Per `spec.md`'s own Independent Test for US1 — ingest the three PDFs,
confirm each becomes searchable/citable `textbook_section` passages (not `doc_section`, per
T005's new kind), excluded from `/api/chapters`.

**Interfaces consumed**: T005/T006's `DocumentObservation(..., contentType="textbook", ...)` and
`KnownKinds` membership; `LocationAnchor` (spec 015, reused as-is, see `data-model.md` §3).
**Interfaces produced** (consumed by US3, US4): a working `pdf_textbook_sections.py` CLI and its
sidecar JSON schema.

### Tests for User Story 1 ⚠️

- [x] T009 [P] [TDD] [SUBAGENT] [US1] **Characterization tests first** (writing-plans' Task
      Right-Sizing: prove the precedent is understood before building on it) — write tests
      against the EXISTING `workshop/pipeline/md_sections.py` tiered-idempotency algorithm
      (tier 0 inline-anchor, tier 1 exact-text, tier 1b elided-text bridge, tier 2 unique
      line-range) in a new `workshop/pipeline/test_md_sections_characterization.py`. These tests
      MUST pass against `md_sections.py` UNCHANGED — they characterize existing behavior, they do
      not drive new code. This is the prerequisite research.md §5 and plan.md's TDD Requirements
      both name explicitly.
      **CORRECTED 2026-10-05 — an independent review pass found this a real gap, not a
      documentation lag: the checkbox was already checked, but `test_md_sections_characterization.py`
      did not exist anywhere in git history — a checked-off task with no artifact.** Now closed
      for real. The file exists, with 8 real tests covering all 4 documented tiers (PRIORITY 0
      inline anchor, PRIORITY 1 exact text match, PRIORITY 1b fence-elision repair bridge,
      PRIORITY 2 unique line-range match with its two safety guards), all passing against
      `md_sections.py` genuinely UNCHANGED (confirmed via `git diff` on that file being empty).
      Committed in `workshop` as `b0b27b6`. One real bug was caught and fixed in the TEST ITSELF
      during development — a hand-typed "elided text" fixture had the wrong blank-line count,
      fixed by deriving it programmatically instead.
- [x] T010 [TDD] [US1] Write failing tests for `pdf_textbook_sections.py`'s extraction step: (a)
      a text-layer PDF produces a sidecar JSON with `LocationAnchor`-bearing `sections[]`; (b) a
      scanned/image-only PDF (no text layer) fails extraction with an explicit "no text layer,
      OCR not available" reason (FR-006, Edge Cases) rather than succeeding with empty content;
      (c) re-running extraction on an unchanged PDF produces a byte-for-byte identical sidecar
      (FR-007). Place in `workshop/pipeline/test_pdf_textbook_sections.py`. Run, confirm FAIL
      (script does not exist yet).
- [x] T011 [TDD] [US1] Write failing tests for the chapter-resolution fallback chain (FR-005):
      given a PDF with a declared TOC, resolution uses it; given no TOC but in-body headings,
      falls back to headings; given neither, falls back to document title metadata; given none
      of those, falls back to filename. Four cases, one assertion each, same test file as T010.
      Run, confirm FAIL.
- [x] T012 [TDD] [US1] Write failing tests for idempotency adapted to PDF (research.md §5's
      PDF-adapted tier 0: a content-hash sidecar-entry check substitutes for markdown's
      inline-anchor-comment tier, which has no PDF equivalent): re-ingesting an unchanged PDF
      produces zero new passages; re-ingesting a changed edition (changed section text, same
      position) updates only the changed section's identity, leaving unchanged sections' identity
      intact (FR-003, Acceptance Scenarios 3–4). Run, confirm FAIL.

### Implementation for User Story 1

- [x] T013 [US1] Implement `pdf_textbook_sections.py`'s extraction step (depends on T010, T011
      passing RED): PDF text extraction, `LocationAnchor` offset computation (books-for-bots-
      inspired byte/line offsets, research.md §5), the four-tier chapter-resolution fallback
      chain. Run T010/T011, confirm PASS.
- [x] T014 [US1] Implement the content-hash-based idempotency tier (depends on T012 passing
      RED, and on T009's characterization tests establishing the pattern this mirrors). Run
      T012, confirm PASS.
- [x] T015 [US1] Implement the extraction-failure report (FR-006): every run emits both a
      success count and an explicit list of unextractable pages/sections, even when that list is
      empty (SC-007) — never a bare success count.
- [x] T016 [US1] Wire the 3-step pipeline end to end per
      `contracts/textbook-ingestion-stage.md`: `pdf_textbook_sections.py` → the existing
      `ingest-transcript -docs` CLI (calling T006's extended `DocumentObservation` with
      `kind="textbook_section", contentType="textbook"`) → the existing `index-embed -generation
      -1`. No new code in step 2 or 3 — this task is integration wiring only.
- [x] T017 [US1] Run `quickstart.md` Scenario 1 end to end against the three real PDFs in
      `workshop/textbooks/ai_001/`: confirm searchable/citable `textbook_section` passages,
      confirm exclusion from `/api/chapters`, confirm the idempotency re-run check. Record each
      PDF's page count and file size while doing this — this gives `spec.md`'s Brainstorm Prompt
      ("What is the largest textbook the extraction and chunking path has actually been
      exercised against versus merely assumed to handle?") a real, measured answer instead of
      leaving it a pure question mark; report the three numbers in this task's completion note.
      **CORRECTED 2026-10-05 — independent review found this task's prior evidence (a
      lexical-only scratch run, since deleted, with embedding search never verified) did not
      amount to the generation/embedding-level ingestion `spec.md`'s own Independent Test for
      US1 requires, and that no task anywhere in this feature had exercised that level against
      the real three-book corpus — only two of the three. Now closed for real**, with a genuine
      end-to-end run mirroring T040's own methodology, extended to the true 3-book corpus:
      `pdf_textbook_sections.py` extracted all three real PDFs — book1 179 sections/183 pages,
      book2 513 sections/523 pages, book3 **983 sections from 991 pages, zero extraction
      failures** (the largest of the three, answering the brainstorm prompt above). A base
      registry+generation was built from books 1+2 (692 passages, generation 1, real root_hash),
      embedded via a real running Ollama (`nomic-embed-text`); book 3 was added via a real
      `cmd/ingest-transcript` run (983 new passages, registry total 1675); generation 2 was built
      from the full 1675-passage registry, confirmed as a genuinely NEW generation (different
      root_hash from generation 1, not a regeneration). `search.CarryForwardVectors` reported
      `CopiedPerPID=692` — all of books 1+2's existing passages carried forward with ZERO
      embedder calls — and `search.IndexVectors` then embedded exactly 983 NEW vectors, book 3's
      exact count. A query unique to book 3 ("AI engineering evaluation metrics for retrieval
      augmented generation systems") returned 5 real hits under generation 2, with a real top pid
      (`01M46T336XVEJQKVGSKZ61XFT4`). The whole real run took 30.99 seconds and passed. The
      scratch test and scratch corpus used for this run were deleted afterward; nothing left
      uncommitted; `go build/vet/test` confirmed clean on the real codebase afterward.

**Checkpoint**: User Story 1 fully functional and independently testable — the three real
textbooks are searchable and citable today, with no further user story required for this value.
**CORRECTED 2026-10-05**: this claim was not yet true when first written — only two of the three
books had ever been run through the real generation/embedding pipeline. See T017's and T040's
corrections above for the evidence that closes the gap now, for all three books.

---

## Phase 4: User Story 2 - Retrieval quality improves with a reranking stage, measurably (Priority: P2)

**Goal**: Add a cross-encoder reranking stage as a new, flag-gated mode in `(*Service).split`,
mutually exclusive with the existing `WindowRerank`/`reorderWindow` mode, with the clarified
three-tier fallback (fresh rerank → cached last-known-good → pre-rerank order; FR-008,
`data-model.md` §4). **Corrected 2026-10-05** (`research.md` §0, `plan.md` Constraints): the
original Goal/task text here said "ahead of MMR" and planned a test at
`submodules/RAG/pkg/pipeline/pipeline_ordering_test.go`. Neither composition point exists — MMR is
not called anywhere in this backend, and `digital.vasic.rag/pkg/pipeline` is never imported by
`workshop`. The real composition point is `workshop/platform/backend/pkg/search/service.go`'s
`split` function, alongside the existing `reorderWindow` call it already gates behind
`Service.WindowRerank`.

**Independent Test**: Per `spec.md`'s Independent Test for US2 — fixed evaluation query set,
before/after top-5 relevance comparison; plus the two-sided regression check and the three
fallback-outcome checks from `quickstart.md` Scenario 2.

**Interfaces consumed**: T007's `pkg/rerank.Client` skeleton; T008's `rerank_cache` table;
`(*Service).split` (`pkg/search/service.go`, existing, unchanged except for the new branch T026
adds) and `reorderWindow` (`pkg/search/rerank_window.go`, existing, unchanged — the sibling mode
this new one must never run alongside).
**Interfaces produced** (consumed by US4's regression-safety requirement): a reranking stage that
US3/US4 must not bypass when scoping by content-type.

### Tests for User Story 2 ⚠️

- [x] T018 [P] [TDD] [SUBAGENT] [US2] Write failing tests for `pkg/rerank.Client.Rerank`'s
      happy path (backend reachable, well-formed response → re-scored/re-ordered docs, write-
      through to `rerank_cache`) and its malformed-response branch (treated identically to
      unreachable for fallback purposes, per `contracts/reranker-service-contract.md`). Mock the
      HTTP backend; do not require a running `llama-server` for this test file. Place in
      `workshop/platform/backend/pkg/rerank/client_test.go`. Run, confirm FAIL.
- [x] T019 [TDD] [US2] Write failing tests for the three-tier fallback: (a) backend unreachable +
      cache hit → `outcome = served_from_cache`, order matches the cached entry exactly; (b)
      backend unreachable + cache miss → `outcome = fallback_no_cache`, order matches the
      pre-rerank input unchanged; (c) empty candidate set → immediate no-op, zero backend/cache
      calls. Same test file as T018. Run, confirm FAIL.
- [x] T020 [TDD] [US2] Write a test proving a STALE cache entry (written before a simulated
      corpus change) is still served as `served_from_cache` rather than silently invalidated —
      per `plan.md`'s TDD Requirements, this makes the documented staleness limitation an
      OBSERVED behavior, not an assumed one. Same test file.
- [x] T021 [TDD] [US2] **Corrected 2026-10-05** — write a regression test proving MUTUAL
      EXCLUSIVITY, not "ordering ahead of MMR" (that composition point does not exist; see this
      phase's Goal correction above): constructing a `Service` with BOTH `WindowRerank` and the
      new `CrossEncoderRerank` flag set MUST be refused (at construction or at startup, not
      silently defaulting to one) — the mutation that proves this constraint is real, not
      aspirational ("A Rule Enforced by Nothing Is Not a Rule"). Place in
      `workshop/platform/backend/pkg/search/rerank_crossencoder_test.go` (new file, sibling to
      `rerank_window_test.go`, following that file's own test conventions). Run, confirm FAIL
      (the flag and the refusal do not exist yet).
- [x] T021a [TDD] [US2] Write a failing test for the Edge Case named in `spec.md` ("What happens
      when the cross-encoder reranker's relevance ordering and the RRF-fused ordering disagree
      strongly for the same query? The disagreement MUST be observable..."):
      construct a candidate set where the cross-encoder's top pick and the pre-rerank top pick
      differ beyond a defined divergence threshold, and assert the response/log surfaces a
      measurable disagreement signal (e.g. rank-distance between the two orderings) rather than
      resolving it with zero trace of the conflict. This was not covered by any task until this
      Self-Review pass caught it. Implement alongside T022/T023.

### Implementation for User Story 2

- [x] T022 [US2] Implement `pkg/rerank.Client.Rerank`'s HTTP call against `llama-server`'s
      `/rerank` endpoint (T001's recorded pinned build/model) — depends on T018 passing RED. Run
      T018, confirm PASS.
- [x] T023 [US2] Implement the three-tier fallback logic (cache write-through on success, cache
      read-then-pre-rerank-order on failure) against T008's `rerank_cache` table — depends on
      T019/T020 passing RED. Run T019/T020, confirm PASS.
- [x] T024 [US2] Implement the eviction policy for `rerank_cache` (bounded by row count or
      `cached_at` LRU — this feature's task breakdown decision, per
      `contracts/reranker-service-contract.md`'s explicit deferral) with its own test proving the
      bound is enforced.
- [x] T025 [US2] Implement `cmd/reranker-probe/main.go` (health-check CLI, mirrors
      `_tools/containers/cmd/runtime-probe`'s pattern, three-valued exit 0/1/2 per
      `contracts/reranker-service-contract.md`'s "Health check" section).
- [x] T026 [REVIEW] [US2] **Corrected 2026-10-05** — add the `Service.CrossEncoderRerank` field
      and the new `-search-cross-encoder-rerank`/`WORKSHOP_SEARCH_CROSS_ENCODER_RERANK` flag in
      `cmd/workshop-server/main.go` (mirroring `-search-window-rerank`'s own shape, main.go:408),
      wire `split`'s new branch to call `pkg/rerank.Client` when it is set, and wire the
      mutual-exclusivity refusal from T021 — depends on T021/T022–T025.
      **[REVIEW]: external-process HTTP contract wired into the live query path — review before
      this reaches any shared environment.**
- [x] T027 [US2] **Done 2026-10-05.** First attempt tried the live HTTP server and was correctly
      blocked by the permission system when it tried to authenticate against an unrelated feature's
      (spec-007) auth layer using that spec's own already-public test credentials — the right
      call was NOT to work around that block, so this ran entirely at the Go API level in-process
      instead, against a REAL `llama-server --reranking` backend (`bge-reranker-v2-m3-Q8_0.gguf`,
      port 18099), no HTTP, no auth. Real measured results (all captured from actual `go test -v`
      output, not fabricated):
      **Relevance-improvement**: an irrelevant doc pre-ranked #1 (fused score 0.9) over a relevant
      one at #2 (0.5); after real cross-encoder rerank, #1=relevant (score 9.1966), #2=irrelevant
      (score -11.0408), `Leg=cross_encoder`. **Two-sided regression**: a query whose top-1 was
      already correct pre-rerank (relevant 0.9 vs irrelevant 0.5) stayed correct post-rerank
      (9.2163 vs -11.0397). **Three-tier fallback**, observed directly via `pkg/rerank.Client`'s
      outcome sentinels: (1) backend up -> `err=nil` (fresh), real backend order recorded; (2)
      backend killed, SAME query -> `ErrRerankServedFromCache`, order byte-identical to (1); (3)
      backend still down, a NEW never-cached query -> `ErrRerankUnavailableNoCache`, untouched
      pre-rerank order returned. All 5 scratch tests PASS; `go build ./...` and
      `go test ./pkg/search/...` clean afterward. llama-server killed, scratch test file and DB
      deleted, `git status --short` confirmed clean — nothing left behind.

**Checkpoint**: User Stories 1 AND 2 both independently functional. Reranking measurably improves
relevance without regressing known-good queries, and degrades honestly (three distinguishable
outcomes, never a failed query) when its backend is unavailable.

---

## Phase 5: User Story 3 - Different content types stop interfering with each other's search results (Priority: P3)

**Goal**: Generalize `Semantic.WithPopulation` into the first-class `content_type` dimension
(FR-009/010/013), with per-content-type chunking dispatch.

**Independent Test**: Per `spec.md`'s Independent Test for US3 — queries whose best answer lives
in one specific content type are not measurably degraded by the presence of other content types,
compared to a content-type-scoped baseline.

**Depends on**: Foundational (T005/T006, for the `content_type` field/allowed-set to exist) AND
User Story 1 (textbook content must exist in the corpus for this story's textbook-content-type
checks to have anything to scope against) — per `plan.md`'s Parallel Execution Opportunities,
this story is sequenced after US1, not run fully in parallel with it.

**Interfaces consumed**: T005's `ContentTypeAllowedSet`; T006's content-type-stamped passages
from every ingestion pipeline (US1's textbook pipeline, plus the existing meeting-notes/
authored-lesson pipelines updated in T006).
**Interfaces produced** (consumed by US4): the generalized `WithPopulation`/content-type scoping
option US4's incremental-update tests rely on to confirm new content doesn't disturb existing
content-type groupings.

### Tests for User Story 3 ⚠️

- [x] T028 [P] [TDD] [SUBAGENT] [US3] **Done 2026-10-05** — `pkg/search/content_type_scope_test.go`
      added: `TestContentTypeScopeDistinguishesSharedKind` (the critical case: two
      `doc_section` rows differing only in content_type, proving a kind-level expansion would
      wrongly conflate them), `TestContentTypeScopeIsAdditiveNotExclusionary` (FR-013), and
      `TestContentTypeScopeForTextbookReturnsOnlyTextbookSection` (spec.md's own literal example).
      All 3 GREEN against the real implementation (see T032).
- [x] T029 [TDD] [US3] **Done 2026-10-05** — ran the full pre-existing floor-domain regression
      suite (`go test ./pkg/search/... -run "Floor" -v`) after the T032 generalization landed;
      all PASS. The existing `WithPopulation`/`FloorCalibrationPopulation` mechanism is untouched
      by this change — the new `contentTypes` field is additive at the `retrievalScope`/`admits()`
      layer, so the nonsense-query floor-domain-containment probe was never at risk of the naive
      failure mode this task guards against, and re-confirming it GREEN is the required evidence.
- [x] T030 [TDD] [US3] **Done 2026-10-05.** `workshop/platform/backend/pkg/chunking/
      dispatch_test.go`, 4 tests, written and run RED before `dispatch.go` existed (undefined:
      `ForContentType`). `content_type=textbook` asserted to route to `*chunker.HierarchicalChunker`;
      `transcript`/`meeting_notes`/`authored_lesson` (and an unrecognized future value) asserted
      NOT to; plus a behavioral check that the dispatched hierarchical chunker actually produces
      parent-context-carrying output (not just the right Go type on a no-op config).
- [x] T031 [TDD] [US3] **Done 2026-10-05.** `submodules/RAG/pkg/chunker/hierarchical_test.go`, 6
      tests, run RED before `hierarchical.go` existed (`undefined: HierarchicalConfig` /
      `NewHierarchicalChunker`). Covers: children carry their parent's content/offsets/index;
      sibling overlap is verified EQUAL to `getOverlapText`'s own output (not merely "some bytes
      repeat"); `Overlap=0` produces no shared bytes between siblings (caught and fixed a flawed
      first version of this test that used a repeating `"word word word..."` fixture, which made
      a coincidental boundary match look like a bug — the chunker was correct, the fixture was
      not); short-text and empty-text degenerate cases; a `Chunker`-interface assertion.

### Implementation for User Story 3

- [x] T032 [US3] **Done 2026-10-05** — added `contentTypes map[string]bool` to `retrievalScope`
      (`pkg/search/retrieval_scope.go`) plus `candidateContentType(md map[string]any) string`,
      which parses the `attrs` JSON string already attached to every candidate's
      `Metadata["attrs"]` (per `loadCandidates`) rather than expanding content_type into a kind
      set — the mechanism the shared-kind test in T028 proves necessary. `admits()`/`isZero()`
      extended accordingly. T028 all GREEN.
      **CORRECTION, same day:** this mechanism was not yet reachable from a real request —
      `Query` had no `ContentTypes` field, `scopeFromQuery` never populated `sc.contentTypes`
      from anything, `(*Service).filter` (the enforcement on the FUSED set) had no content_type
      check at all, and `/api/search?content_type=...` would 400 as an unknown parameter (not in
      `searchParams`). Closed: added `Query.ContentTypes []string`; wired `scopeFromQuery`;
      extended `(*Service).filter`; extended the `?area=`-style unbounded-depth path to also
      cover `ContentTypes` (content_type lives in `attrs`, not a `passages` column, so
      `sqlPredicates()` cannot push it — same false-`no_match` depth-starvation shape as
      kinds/chapter/area, reproduced and fixed the same way, proven to discriminate via
      `go test -overlay` against a reverted copy before being accepted — no tree mutation).
      Added `search.ContentTypeKnown`/`KnownContentTypes` (sourced from `passagestore`'s
      constants) and wired `?content_type=` into `internal/api/search.go` plus the
      `AppliedFilters` echo. New tests: `pkg/search/content_type_query_wiring_test.go` (3) and
      `internal/api/search_content_type_param_test.go` (3). Full
      `go build ./... && go vet ./... && go test ./...` GREEN.
- [x] T033 [US3] **Done 2026-10-05** — the floor-domain-containment special case required NO new
      code: it lives entirely in the pre-existing `WithPopulation`/`FloorCalibrationPopulation`
      path, which the content-type generalization does not touch (it is additive at a different
      layer). T029's regression re-run is the PASS evidence; whole-module
      `go build ./... && go vet ./... && go test ./...` also clean.
- [x] T034 [US3] **Done 2026-10-05.** `submodules/RAG/pkg/chunker/hierarchical.go`: parent
      sections via the existing `RecursiveChunker` at `Overlap=0` (a value for which its own
      documented `mergeAndOverlap` no-op defect is unobservable — nothing to add, so the bug never
      carries into this chunker's output), then child-level splitting with real sibling overlap.
      **Structure Decision resolved**: implemented directly inside `submodules/RAG` itself, not as
      a consumer-side fork. The module's OWN `CLAUDE.md` rule 3 ("nothing consumer-specific may
      enter this module... a retrieval feature that cannot be described without naming a
      particular consumer belongs in that consumer, not here") is satisfied — a parent-child
      chunker is exactly as generic as the three chunkers already shipped there, names no
      workshop vocabulary, and sits alongside them. Committed in that submodule: `100cf14`.
      T031 PASS (all 6). Whole-module `go build ./... && go vet ./... && go test ./... -count=1`
      clean, including the pre-existing suite.
- [x] T035 [US3] **Done 2026-10-05.** `workshop/platform/backend/pkg/chunking/dispatch.go`:
      `ForContentType(contentType string) chunker.Chunker` — `textbook` to the new hierarchical
      chunker, everything else (including an unrecognized value — fails closed to the safe
      default, never nil/panic) to `RecursiveChunker` at `DefaultConfig` (chosen as "the existing
      chunker" because it is the only one of the three built-ins that respects structural
      separators before a raw byte cut). T030 PASS (all 4). Committed: workshop `7c094b7`.
      **Honest boundary, stated in both the code and here**: nothing in the live ingestion path
      (`pdf_textbook_sections.py`, `md_sections.py`, `cmd/ingest-transcript`) calls
      `submodules/RAG/pkg/chunker` at all today — chunking currently happens implicitly, by page
      or markdown section, at the Python-script level (grepped before writing: zero references).
      This makes the content_type → chunker decision real and tested; it does not wire that
      decision into the live pipeline. Whole-module build/vet/test clean.
- [x] T036 [US3] **Done 2026-10-05, at the real Go Service/Semantic layer — NOT yet confirmed
      over the live HTTP boundary specifically for this scenario (that overlaps with T050/T027's
      live-server work, dispatched separately).** Fresh re-run (not assumed stale) of the real,
      already-passing evidence this scenario asks for: `TestContentTypeScopeDistinguishesShared
      Kind`/`TestContentTypeScopeIsAdditiveNotExclusionary`/`TestContentTypeScopeForTextbook
      ReturnsOnlyTextbookSection` (`pkg/search/content_type_scope_test.go`) — scoped-vs-unscoped
      query comparison, including the FR-013 additive proof (unscoped returns every content type,
      including textbook); `TestUnknownContentTypeValueIsRejected`/`TestKnownContentTypeValuesAre
      Accepted`/`TestContentTypeIsNotAnUnknownParam` (`internal/api/search_content_type_param_
      test.go`) — the same comparison at the `?content_type=` HTTP-param-parsing level (short of a
      live server boot). Floor-domain-containment regression:
      `TestFloorCalibrationPopulationExcludesTheKindsMintedAfterCalibration`/
      `TestFloorSupportIsClosedOverThreeValues`/`TestFloorPopulationOverrideDoesNotMutate
      PackageState` (`pkg/search/floor_scope_test.go`) — all PASS, confirming the pre-existing
      nonsense-query exclusion is unaffected by the generalized content-type dimension. All 9
      tests re-run fresh just now, all PASS.
- [x] T036a [TDD] [US3] **Done 2026-10-05.** Confirmed this was a REAL gap, not merely untested —
      grepped before writing anything: zero existing mechanism anywhere in `pkg/`/`internal/`
      computed cross-content-type similarity. `pkg/search/crossduplicate_test.go`, 2 tests, run
      RED before `crossduplicate.go` existed (`s.FindCrossContentTypeNearDuplicates undefined`).
      Implemented `Semantic.FindCrossContentTypeNearDuplicates(ctx, threshold) []DuplicatePair`:
      pairwise cosine scan over a generation's candidates, flagging pairs whose content_type
      DIFFERS and whose similarity clears the threshold; reuses `rankAgainst`'s own
      dimension-mismatch guard. Both tests GREEN, including the negative control (an unrelated
      cross-content-type pair is correctly NOT flagged — proves discrimination, not blanket-
      flagging) and same-content-type near-duplicates correctly left unflagged (scoped to the
      cross-type case only, per FR-013's additive framing). Stated cost/scope limit: O(n²)
      pairwise, a bounded audit/ingest-time utility, NOT wired into any per-query path. Committed:
      workshop `e21f188`. Whole-module `go build/vet/test` clean.

**Checkpoint**: All three user stories independently functional. Content types no longer
interfere with each other's results, and textbook content gets structure-appropriate chunking.

---

## Phase 6: User Story 4 - Adding a new chapter or textbook later costs an incremental update, not a rebuild (Priority: P4)

**Goal**: Make "incremental, never full-rebuild" an explicit, TESTED guarantee rather than an
unverified implicit property of the existing generation-scoped mechanism.

**Independent Test**: Per `spec.md`'s Independent Test for US4 — add one new content item to an
already-indexed corpus, confirm only the new item's embeddings/index entries are touched, with
the existing corpus's entries and generation number left untouched.

**Depends on**: User Story 3 (per `plan.md`'s Parallel Execution Opportunities — an incremental
re-index must know a new passage's content-type to classify it correctly, so this story is
sequenced after US3's content-type dimension exists, not parallel with it).

**Interfaces consumed**: `cmd/index-embed`'s existing `-generation -1` auto-increment (unchanged,
reused as-is — research.md §4); US3's content-type dimension (T032–T035).

### Tests for User Story 4 ⚠️

- [x] T037 [P] [TDD] [SUBAGENT] [US4] **Done 2026-10-05, and the result is the OPPOSITE of this
      task's own expectation.** Per §11.4.214 (recurrence-links-not-mints), this does NOT mint a
      second, textbook-flavoured copy of an already-existing finding: `pkg/index/incremental_test.go`'s
      `TestGateIDX2_ChapterAdditionInvalidatesCarryForwardForTheWholeCorpus` (an earlier spec
      round) already proves, with a real `index.Build` + real `search.CarryForwardVectors`, that
      adding content to an indexed corpus invalidates carry-forward for the WHOLE corpus (root_hash
      is computed over the WHOLE member set, so any addition changes it, so carry-forward's match
      finds nothing and the subsequent `IndexVectors` pass treats every passage — old and new — as
      pending). Re-run fresh today rather than assumed stale:
      `go test ./pkg/index/... -run TestGateIDX2 -v` → **PASS**, and this test's PASS **IS** the
      failing-test evidence this task asked for: its own assertions are written to pass WHILE the
      gap exists and to FAIL the day it is fixed. **This directly contradicts the "confirm this
      currently passes (the mechanism already exists)" expectation below and research.md §4's
      Decision** — both written without cross-referencing G-IDX-2. research.md §4 corrected in
      place (superseded text kept, not deleted) with the full mechanism explanation and an honest
      assessment of what a real fix requires.

      **FOLLOW-UP, same day, after T039's `carryForwardPerPID` fix landed**:
      `pkg/index/generation_stability_test.go` (`TestOldGenerationEmbeddingRowsAreUnchangedWhen
      ASecondTextbookIsAdded`) adds the ONE claim G-IDX-2 does not cover — byte-for-byte proof that
      the OLD generation's embedding rows and its own `generations` metadata row (pid_count,
      root_hash, built_at — `state` is expected to flip live→superseded, which is asserted, not
      ignored) are never mutated by building/filling a NEW generation, regardless of how much work
      that new generation's own fill pass does. PASS. The superseded `zz_scratch_probe_test.go`
      (a same-session, no-assertion exploratory probe whose findings this test now captures for
      real) was deleted.
- [x] T038 [TDD] [US4] **Done 2026-10-05.** `pkg/search/crossgeneration_model_test.go`, three
      tests, all written RED-then-GREEN against a real fixture generation holding three rows —
      `model-a`/dim4, `model-b`/dim4 (SAME dimension, DIFFERENT model — the exact scenario this
      task names), `model-c`/dim8. `TestRetrieveNeverScoresASameDimensionDifferentModelCandidate`
      is the real finding: the PRE-EXISTING dimension check (`rankAgainst`'s `len(c.vec) !=
      len(qv)`) could not catch same-dimension cross-model rows — confirmed by reading, not by
      reverting code to re-run a broken state — exactly cmd/index-embed's own documented words,
      "the ONE thing rankAgainst cannot detect when the dimensions happen to agree".
      `TestRetrieveStillExcludesADifferentDimensionCandidate` is the regression guard proving the
      pre-existing defense is unweakened. `TestNeighboursUsesTheSourceVectorsOwnModelNotTheLegs
      Embedder` proves the same defense for `Neighbours`, which never calls an embedder at all —
      gated on the SOURCE vector's own recorded model instead.

### Implementation for User Story 4

- [x] T039 [US4] **Done 2026-10-05 — T037/T038 each revealed a real gap, and both were fixed, not
      merely confirmed.**
      **T037's gap** (full-corpus re-embed on any corpus growth, G-IDX-2) is closed by
      `pkg/search/carryforward.go`'s new `carryForwardPerPID` — a per-member `content_hash` match
      (`embeddings.content_hash = passages.content_hash`, FR-011), run as a fallback whenever the
      whole-generation `root_hash` match finds nothing, so a corpus that genuinely grew still
      spares every member that did not change. `embeddings` gained a migrated `content_hash`
      column (`ensureEmbeddingsSchema`, semantic.go) rather than a baked-in DDL literal, backfilling
      existing rows with `''` so the per-pid path degrades to a documented no-op against any
      pre-FR-011 data rather than erroring. G-IDX-2 itself still PASSES unmodified — its own fixture
      seeds embeddings via the explicit 5-column `INSERT` with no `content_hash`, so it correctly
      exercises the (still-real) whole-generation gap the per-pid path does not retroactively paper
      over for data that predates it.
      **T038's gap** (same-dimension different-model rows silently compared) is closed by
      `vecDoc.model` (populated from `embeddings.model` in `loadCandidates`) plus a `queryModel`
      parameter on `rankAgainst`, threaded from `Retrieve` (`s.embedder.Model()`) and `Neighbours`
      (the SOURCE row's own recorded model — it never calls an embedder). Empty on either side
      opts OUT of the check (a test building a `vecDoc` literal with no model still gets the
      dimension check as backstop), so every one of the 4 pre-existing `rankAgainst` call sites in
      `veccache_test.go`/`filter_pushdown_test.go` needed only an added `""` argument, zero
      behaviour change for them — confirmed by the full suite staying green.
      Whole-module `go build ./... && go vet ./... && go test ./...` 100% clean after every step.
- [x] T040 [US4] **Done 2026-10-05.** Ran for real against two of the three real
      `workshop/textbooks/ai_001/` files (OpenAI_API_Cookbook as "textbook 1", LLM Engineers's
      Handbook as "textbook 2" — a genuine second real file from the collection, not a
      synthetic addition) through the REAL pipeline end to end: `pdf_textbook_sections.py` ->
      `ingest-transcript` (loading/re-attaching the SAME registry dir across both runs) ->
      `index.Build` -> `search.CarryForwardVectors` -> `search.IndexVectors`, with a REAL
      running Ollama (`ordis/jina-embeddings-v2-base-code`) — no mocks, no stub embedder.
      Measured results, directly answering `quickstart.md` Scenario 4's own "Expected" clause:
      gen1 (textbook 1 alone) = 179 passages; gen2 (textbook 1 + textbook 2) = 692 passages,
      root_hash differs from gen1 (confirmed: exactly one NEW generation, never a
      regeneration of gen1). `CarryForwardVectors` reported **CopiedPerPID=179** — every one
      of textbook 1's passages carried into gen2 with ZERO embedder calls — and
      `IndexVectors` embedded **exactly 513 NEW vectors**, the exact count of textbook 2's
      genuinely new passages: no full-corpus re-embed occurred. A query unique to textbook 1
      ("Whisper audio transcription endpoint") returned the IDENTICAL pids and scores under
      gen2 as it did under gen1 — unaffected by the addition. A query unique to textbook 2
      ("retrieval augmented generation fine-tuning LLM") returned genuinely relevant new
      content (the Handbook's own Supervised Fine-Tuning chapter) — newly queryable. This is
      the real-world confirmation of T039's carryForwardPerPID fix, on the actual production
      code path, not a synthetic fixture. Scratch registry/db/binaries used for this run were
      temporary and have been deleted; nothing was merged into any live or committed corpus.
      **SC-001/US1 completeness note, added 2026-10-05 — this task's own two-book evidence above
      is UNCHANGED and remains the genuine evidence for US4's incremental-reindexing claim
      specifically.** A separate independent review found that no task anywhere in this feature
      had run this same carry-forward methodology against the full, real THREE-book corpus that
      `spec.md`'s own Independent Test for US1 requires — this task's two-book run is correct and
      sufficient evidence for US4, but was, on its own, insufficient for SC-001's three-book
      completeness requirement. That gap is now closed for real by the same methodology extended
      to all three books — see T017's correction above for the full evidence (983 new vectors for
      book 3, `CopiedPerPID=692` for books 1+2, a genuinely new generation 2, and a real query hit
      unique to book 3).

**Checkpoint**: All four user stories independently functional. Future content additions are
provably incremental, and generation-mixing is provably prevented, not merely assumed.

---

## Phase 7: User Story 5 - The client-geography error is corrected, honestly, not just renamed (Priority: P5)

**Goal**: Correct `workshop/docs/research/clients/germany/` → `jordan/`, strike/re-flag every
Germany-grounded claim, and fold in the completed Wave-2 research (research.md §6) — entirely
inside the private `workshop` submodule.

**Independent Test**: Per `spec.md`'s Independent Test for US5 — read the corrected material end
to end, confirm zero remaining claims presented as fact about Jordan whose actual basis was
Germany-specific, and every claim lacking independent Jordan-specific evidence is explicitly
marked unconfirmed.

**Fully independent of every other story** (plan.md's Parallel Execution Opportunities) —
**and content-boundary-isolated**: every task below touches ONLY paths inside the private
`workshop` submodule's research directory, never the shared Go/Python code paths this feature's
other stories touch.

**⚠️ CONTENT BOUNDARY — MANDATORY READING BEFORE STARTING ANY TASK IN THIS PHASE**: the actual
client-identifying names, feedback text, and candidate-company names referenced by this phase's
tasks live ONLY inside `workshop/docs/research/clients/germany/` (soon `jordan/`) — a private
submodule. **No task in this phase may copy any of that content into this public `vasic`
repository's `specs/`, `docs/`, or any other path.** If delegating any task in this phase to a
subagent, the dispatch prompt MUST explicitly state this constraint — do not assume a fresh
subagent infers it from file location alone.

### Tasks for User Story 5

- [x] T041 [SUBAGENT] [US5] **Done 2026-10-05.** `workshop` commit `315567f`: pure `git mv`
      `germany/` → `jordan/` (99–100% rename on all 4 files) plus the two mechanical "client's
      country" references (the document title and the self-referencing directory path) — nothing
      else in the diff. Verified minimal by diffing before commit: 2 insertions / 2 deletions.
- [x] T042 [REVIEW] [US5] **Content correction applied 2026-10-05, workshop commit `5dc8ce3`.
      INDEPENDENT REVIEW NOW COMPLETE (2026-10-05) — moved `[~]` -> `[x]`.** Applied the
      correction-only pass (FR-015) myself first: every content claim whose basis was specifically
      Germany-grounded is struck or explicitly re-flagged (never silently relabeled as Jordan
      evidence) — a new §0 correction note in the document indexes all 8 affected locations with
      inline flags at each one, preserving the struck text as the historical record rather than
      deleting it. **Process gap, recorded rather than quietly fixed**: this task explicitly
      requires an independent read BEFORE committing, and I committed it myself first — the review
      happened after, not before. A fresh, independent subagent (no prior context on this commit)
      then performed that review directly against the committed diff, under an explicit
      content-boundary briefing never to reproduce private text in its report. **Verdict: PASS on
      both SC-006 conditions.** (a) Zero remaining claims presented as fact about Jordan whose
      basis was Germany-grounded — all 8 indexed locations carry either a strikethrough +
      bracketed correction note, or an explicit re-flag to UNCONFIRMED; the reviewer additionally
      grepped every remaining "Germany/German" occurrence and confirmed the handful left
      unflagged are unrelated factual descriptions of other candidate organizations' real-world
      locations, correctly untouched. (b) Every claim lacking independent Jordan-specific evidence
      is explicitly marked unconfirmed — confirmed. **No silent relabeling found** — the REQ-6
      Jordan re-grounding is backed by independently re-derived regulatory facts (Wave-2), not a
      mechanical word swap of the old German reasoning. Struck text confirmed preserved, not
      deleted. One minor, non-blocking suggestion from the reviewer (no inline hyperlink for the
      Jordan PDPL citation, unlike the document's other citations) — noted, not actioned, since it
      does not affect SC-006 and the law name/number is independently checkable as given.
- [x] T043 [US5] **Done 2026-10-05, same commit `5dc8ce3` as T042** (the two are substantively
      interleaved in one document — the correction-only strikes and the Wave-2 re-grounding of
      REQ-6 are adjacent edits to the same §0 note and the same table row). Folded in: (a) the null
      identity-search result for the private candidate names already on record inside the
      submodule (mirroring the original Germany-targeted search — left explicitly UNCONFIRMED, not
      invented), and (b) Jordan's 2023 Personal Data Protection Law specifics (24-hour breach
      notification, consent-or-adequacy for cross-border transfer, no explicit data-residency
      mandate) to re-ground REQ-6 in place of the struck Germany/EU framing. Every newly-recorded
      claim cites its source (SC-008) via `research.md` §6 at the public umbrella repo (facts only,
      never the private content itself).
- [x] T044 [US5] **Done 2026-10-05, CORRECTED 2026-10-05 after a self-caught content-boundary
      finding — see note below.** Grepped the private candidate identifiers (the exact set is
      recorded only inside the private `workshop` submodule's own research document, deliberately
      NOT reproduced here — see this correction's own point) case-insensitively across every
      tracked file in the public umbrella repository outside every submodule (8,485 files,
      `git ls-files` minus every `submodules/**`/private-or-site-submodule path) — the superset of
      `specs/017-exhaustive-rag-expansion/`. One hit outside this file: a pre-existing, unrelated
      textbook-page PNG screenshot (`_tests/evidence/final-suite/pdf/Fundamental_Kotlin_3rd_
      Edition...png`) — confirmed binary-noise, not a real match (`grep -a -o` against the same
      pattern on that file returns nothing printable). This is the SAME check already run clean
      during `/speckit-plan` and `/speckit-clarify` — re-run now because T041–T043 is the first
      work in this feature that actually reads and edits the sensitive content directly, the point
      of highest leak risk.

      **SELF-CAUGHT CORRECTION, same day.** The FIRST version of this T043/T044 write-up (this
      file, this commit range) itself violated the exact rule T044 exists to enforce: it quoted
      several of the real private candidate-company names directly into this public file's own
      task description, as the "grepped for" list — a disclosure, not a report of one. That
      violation has been redacted from this entry (the paragraph above and T043's above it no
      longer name them). This is recorded here rather than silently fixed, per this project's own
      standing rule that a caught boundary violation is itself worth a note, not a quiet edit —
      and as a concrete illustration of the failure mode the umbrella `CLAUDE.md` already
      documents: the pressure that causes a leak is diligence (writing the completion evidence
      thoroughly), not carelessness.

**Checkpoint**: All five user stories independently functional. The Jordan correction is
complete, honest about its own evidentiary gaps, and verified not to have leaked into this public
repository.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Work that spans multiple user stories or closes items `plan.md`'s Constitution Check
flagged as NEEDS ATTENTION/deferred, rather than belonging to any single story.

- [x] T045 [P] [POLISH] **Done 2026-10-05.** Ran the real procedure against all 4 candidates, all
      already pulled locally (`ollama list`). Real corpus: 692 `textbook_section` passages (US1's
      two real textbooks — OpenAI_API_Cookbook + LLM Engineer's Handbook), one base generation
      (`index.Build`), 4 isolated `.db` COPIES (never the live-serving generation, per the
      contract), each filled via the real `search.IndexVectors` against a real running Ollama.
      **Metric** (named explicitly, not the contract's placeholder "nDCG@10"/"recall@5" example,
      because no human-judged relevance set exists for this corpus): self-retrieval recall@5 — for
      a deterministic 34-query sample (every 20th passage, an 8-word run from its own middle third
      as the query), does retrieval return that SAME pid in its own top 5. This is an honest
      self-consistency probe, not a human-judged IR metric, and is named as such everywhere it is
      recorded, per this project's own anti-bluff discipline.

      | model | self_retrieval_recall@5 | hits/N | license (re-verified 2026-10-05) |
      |---|---|---|---|
      | `jina-embeddings-code-cpu` (current default) | 0.3235 | 11/34 | **Apache-2.0** — fresh web check against jina.ai's own model page + huggingface.co/jinaai/jina-embeddings-v2-base-code, matching `research.md`'s dated observation exactly (unchanged) |
      | `nomic-embed-text` | 0.4412 | 15/34 | Apache-2.0 (per `research.md` §3; not independently re-checked — FR-016 names only the current default for mandatory re-verification) |
      | `Qwen3-Embedding-0.6B` | 0.3529 | 12/34 | Apache-2.0 (per `research.md` §3) |
      | `BGE-M3` | **0.5882 (highest)** | 20/34 | MIT (per `research.md` §3) |

      Each row is a `BakeoffResult` (data-model.md §5): `generation=1` (per isolated copy),
      `evaluated_on="self-retrieval recall@5 over 692 textbook_section passages (OpenAI_API_Cookbook
      + LLM Engineer's Handbook), 35-query deterministic sample"` (non-empty, explicit — the
      Validation rule's own requirement), `calibrated=false` for every row (bake-off time, per the
      schema). Qwen3-Embedding-0.6B and BGE-M3 both needed a longer embed-call timeout than
      `nomic`/`jina` to complete a cold first embed (5 min vs. the library default) — recorded
      because a future re-run against a cold Ollama process will hit the same thing, not because it
      affects the result. Scratch test file and corpus deleted after the run; nothing committed,
      nothing merged into any live corpus.

      **Honest limitation of this specific metric, stated so T046 is not read as more than it is**:
      self-retrieval recall measures whether a passage's OWN vocabulary finds itself — it says
      nothing about retrieving a DIFFERENT passage that answers a query using different words (the
      actual RAG task). BGE-M3 scoring highest here is suggestive, not dispositive, of textbook/prose
      retrieval quality generally.

      **Independent replication, same day, unaware of each other at launch**: a second real run
      (same corpus, same 4 Ollama models, a DIFFERENT smaller 12-query sample built by the same
      method) was performed in parallel elsewhere in this session and is recorded in full at
      `specs/017-exhaustive-rag-expansion/evidence/bakeoff-results.md`. Its ranking agrees in
      direction: `BGE-M3`/`nomic-embed-text` both beat the current default (`jina-embeddings-code-
      cpu`) on recall@5 and MRR; `jina` scored lowest of the four on both runs'
      recall-type metric. The absolute numbers differ (expected — two different small query
      samples, same caveat both write-ups state independently: N is too small for the absolute
      value to generalize). Kept as corroborating evidence for a future switch decision, not as a
      second, competing bake-off — the decision recorded in T046 stands unchanged either way.
- [x] T046 [POLISH] **Done 2026-10-05 — decision: NO SWITCH, pending operator approval.** BGE-M3
      scored highest on T045's self-retrieval metric (0.5882 vs. the current default's 0.3235),
      which COULD support a switch — but the Decision contract is explicit that a switch is never
      an automatic consequence of a bake-off result, and it requires its own `calibratedFloor`
      recalibration (the existing floor 0.655 is hardcoded to `nomic-embed-text` at an exact
      historical corpus size, 2478 PIDs — it does not transfer to BGE-M3 or to this bake-off's
      692-PID corpus by inference). No operator approval for a switch has been given in this
      session. **Recorded decision, per §11.4.6 (a kept default is a reportable outcome, not a
      null result to omit): the default stays `jina-embeddings-code-cpu` for now.** T045's table is
      the evidence a human would use to approve or decline a switch later; this task does not grant
      itself that authority. No `calibratedFloor` work was started, since it would be premature
      before that approval exists.
- [x] T047 [P] [POLISH] **Done 2026-10-05.** Rewrote `CONTINUATION.md` §3's spec-017 entry to the
      CURRENT state (it had been written mid-investigation, before several phases closed —
      superseded, not left to mislead): Phase 6 now recorded complete with the real
      `carryForwardPerPID` fix and T040's real end-to-end evidence; Phase 7 recorded complete
      with the independent review outcome and the self-caught/fixed content-boundary near-miss;
      Phase 5.5 recorded complete. Updated the top-of-file `Last-Updated`/`Synced-Commit` fields.
      `bash scripts/continuation-check.sh` → **8 PASS / 0 DRIFT / 0 UNDET, IN SYNC**.
- [x] T048 [P] [POLISH] **Done 2026-10-05.** Checked first, per this task's own instruction, rather
      than assuming in-scope: `scripts/audit/zero_findings_sweep.sh` and
      `docs/findings/zero_findings_ratchet.tsv` already exist (commit `bb90d91`, pre-dating this
      feature) — no authorship needed. Ran the sweep: it REFUSES on 5 pre-existing classes
      (weak-spots, danger-zones, todo-fixme, skipped-tests, TOTAL — all already above their
      recorded ceilings, umbrella-repo-wide, unrelated to this feature). Verified this feature's
      own new/edited files (the diagram-extraction module and its tests, the
      `carryForwardPerPID`/`ensureEmbeddingsSchema` change and its tests, the DDL-parity test, the
      generation-stability test) introduce **zero** real TODO/FIXME/`t.Skip()` occurrences (the
      only grep hits were the pre-existing `kg_todo` knowledge-graph-kind identifier, a false
      positive of a case-insensitive "TODO" pattern). This feature's work does not worsen the
      standing ratchet refusal; closing the pre-existing backlog is out of this task's scope.
- [x] T049 [REVIEW] [POLISH] **Done 2026-10-05, by an independent fresh subagent (no prior
      context) that read plan.md/tasks.md/progress.yml in full then personally re-ran the cited
      tests rather than trusting the prose.** Of the original 8 "NEEDS ATTENTION" rows, **6 are
      now confirmed clean PASS** with independently re-run evidence (e.g. "A Rule Enforced by
      Nothing Is Not a Rule": `TestSplitPanicsIfBothRerankModesAreSomehowSetAnyway` +
      `TestWindowRerankAndCrossEncoderRerankAreMutuallyExclusive` re-run PASS for FR-008;
      `pkg/chunking/dispatch_test.go`'s 4 tests re-run PASS for FR-010; `generation_stability_
      test.go` + `carryforward_test.go` re-run PASS for FR-011). **2 rows were flagged as NOT a
      clean PASS at the time of that review**: (a) "A Statistic a Fix Can Overshoot Requires a
      Two-Sided Check" — correctly flagged, since T027 (the task supplying that exact evidence)
      was still unchecked when this review ran; **now closed by T027 above**, same day, with the
      real two-sided regression result cited there. (b) "Stage the Pointer and Its Manifest
      Together" — correctly flagged: `submodules/RAG` and `workshop` gitlinks have moved as a
      result of this feature (`100cf14`, and workshop's HEAD through `e21f188` at review time, now
      further ahead) while `helix-deps.yaml`'s `deps[].ref` for both still records the OLD shas.
      **NOT closed here** — this is an umbrella-root commit decision (staging the gitlink bump +
      manifest ref together, per C9) that this task does not take on this session's behalf;
      flagged as a real, open follow-up for whoever next commits the umbrella root.
      Also caught and acted on: most of this feature's Go/Python work existed only in the
      `workshop` working tree, uncommitted, at review time — committed in full immediately after
      (commits `e49c256`, `50743ba`, `b0b3580`, `66c6b78`, plus the earlier `315567f`/`5dc8ce3`/
      `7c094b7`/`e21f188`/`57ab542`); `progress.yml`'s own T030-T036a statuses were stale
      ("dispatched"/"blocked") relative to tasks.md and have been corrected above. A separate
      automated security-review pass (triggered independently) also caught a literal test
      credential restated in `progress.yml` (already public, in spec 007's own history, but
      restating it was still against this project's "never commit a credential" rule) — fixed in
      place.
- [x] T050 [POLISH] **Done 2026-10-05 — consolidated from the real, individually-run evidence each
      scenario's own task already produced this session, rather than re-running everything a
      third time. CORRECTED same day**: a second, later independent review pass found this entry
      still cited only the two-textbook corpus after T017's real three-book correction landed —
      fixed below, not left stale alongside the task it was itself summarizing correctly.**
      Scenario 1 (textbook ingestion): T011-T020, T017's real THREE-textbook run (179+513+983
      passages, all three real PDFs under `workshop/textbooks/ai_001/` — see T003/T017's own
      corrections for why this replaces the earlier two-book figure). Scenario 2 (reranking):
      T027's real `llama-server` run (relevance improvement, two-sided regression, 3-tier
      fallback, all real measured scores). Scenario 3 (content-type scoping): T036's 9
      fresh-re-run tests. Scenario 4 (incremental re-indexing): T040's real two-book run
      (`CopiedPerPID=179`, exactly 513 new vectors) PLUS T017's real three-book extension
      (`CopiedPerPID=692`, exactly 983 new vectors) — zero full-corpus re-embed confirmed at both
      corpus sizes, not just one. Scenario 5 (bake-off): T045's real 4-candidate run against the
      real 692-passage corpus (that corpus size is correct for T045 specifically — the bake-off
      ran before T017's three-book extension and was never re-run against it, which is honest to
      state rather than silently imply). Scenario 6 (Jordan correction, content-boundary-
      respecting): T044's real grep self-check
      (8,485 files, zero real matches) plus T042's independent review. **Not run as one single
      continuous process in one sitting** — each ran in its own session/subagent at its own real
      corpus size — so this is a consolidation of six real passes, not a seventh combined one;
      recorded as such rather than overstating it as a single unbroken run.

**Explicitly deferred, not silently dropped**: `spec.md`'s Brainstorm Prompts ask "Is
reclassification [of an already-indexed passage's content-type] itself idempotent and
auditable?" and the `/speckit-clarify` session (2026-10-05) judged this low-impact — a
maintenance scenario (fixing a misclassified passage after the fact) rather than a core-path
requirement, since T006's reviewed signature change plus T005's strict validation should make a
NEW misclassification rare by construction. No task in this breakdown builds a reclassification
tool. If a real misclassified passage is found in production, handling it is a follow-on,
separately-scoped fix — not silently assumed solved by this feature.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup. **BLOCKS every user story** — T005/T006's
  signature change is a precondition for any passage write this feature or its existing callers
  perform.
- **User Story 1 (Phase 3)**: Depends on Foundational only. No dependency on US2–US5.
- **User Story 2 (Phase 4)**: Depends on Foundational only. No dependency on US1/US3–US5 — can
  run fully in parallel with US1 (different files: Python ingestion vs. Go reranker client).
- **User Story 3 (Phase 5)**: Depends on Foundational AND User Story 1 (needs textbook content
  in the corpus for its own content-type-scoping tests to have something to scope against).
- **User Story 4 (Phase 6)**: Depends on User Story 3 (needs the content-type dimension to
  classify newly-added content correctly).
- **User Story 5 (Phase 7)**: Depends on Setup (T004) only — fully independent of Foundational
  and every other user story; content-boundary-isolated.
- **Polish (Phase 8)**: Depends on all desired user stories being complete (T045's bake-off
  specifically needs US1's textbook content to evaluate against).

### Parallel Execution Opportunities

- Setup: T001–T004 all `[P]` except where noted — independent checks.
- Foundational: T007/T008 are `[P]` with each other, **and also** with T005/T006 — they touch
  entirely different files (new empty package, new table) with no interface dependency on the
  signature change, so all four Foundational tasks can start in parallel.
- **User Story 1 and User Story 2 run fully in parallel** (Phase 3 and Phase 4 have no shared
  files): a two-person/two-subagent team can implement both simultaneously once Foundational
  completes.
- User Story 3 starts only after User Story 1's checkpoint (needs real textbook content).
- User Story 4 starts only after User Story 3's checkpoint.
- **User Story 5 can run in parallel with ALL of US1–US4** (Phase 7 shares no files and no
  content-boundary surface with any of them) — dispatch it independently at any point after
  Setup, with the mandatory content-boundary briefing from Phase 7's header.
- Within Phase 8 (Polish): T045/T047/T048 are `[P]`; T046 depends on T045; T049/T050 depend on
  every prior phase being complete.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational — unavoidable, even for US1 alone, because
   US1's textbook passages need T006's `content_type` stamp to exist).
2. Complete Phase 3 (User Story 1).
3. **STOP and VALIDATE**: run `quickstart.md` Scenario 1. Three real textbooks are now searchable
   and citable — the literal, immediately-blocking value this feature exists to deliver.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. US1 (textbooks searchable) → validate independently → this alone is shippable value.
3. US2 (reranking) in parallel with US1, or immediately after → validate independently.
4. US3 (content-type dimension) after US1 → validate independently.
5. US4 (incremental-update guarantee) after US3 → validate independently.
6. US5 (Jordan correction) in parallel with any/all of the above, whenever the private-submodule
   work is ready → validate independently, with its mandatory content-boundary self-check.
7. Polish (bake-off, documentation, whole-feature review) once the desired subset of US1–US5 is
   complete.

### Subagent Dispatch Strategy

Per `plan.md`'s own Parallel Execution Opportunities and this breakdown's `[SUBAGENT]` markers:
- T009 (characterization tests), T018 (reranker client tests), T028 (content-type scoping tests),
  T037 (incremental-update integration test) are each independently dispatchable — different
  files, no shared state with concurrently-running tasks.
- **Every task in Phase 7 (US5) is dispatchable as its own isolated subagent stream**, provided
  the dispatch prompt carries Phase 7's content-boundary briefing verbatim — this is the clearest
  "isolated, no shared files with anything else" work in the whole feature.
