# Feature Specification: Exhaustive RAG Expansion + Textbook Ingestion + Jordan Correction

**Feature Branch**: `017-exhaustive-rag-expansion`

**Created**: 2026-10-05

**Status**: Draft

**Input**: User description: "We have research materials in docs/research/clients/germany and first textbook materils for full processing in: workshop/textbooks/ with first directory containing themL ai_001. For working with textbooks and similar materials we MUST incorporate everything we can from: https://github.com/prime-radiant-inc/books-for-bots. It is MANDATORY to perform multiple additional rounds of deep web research to obtain as much as possible new game changing ideas and innovative apporaches we could apply! Another big improvement we MUST DO is to introduce significant exhaustive use uf RAG technology with all existing materials we have - all video and textual chapter (with all existing meeting notes andtranscriptions) and all text books we have. We MUST keep in mind that in the future we will be adding more video chapters, textual chapters or text books! It is important to note that client is from Jordan, not Germany, therefore all references (directory name and others) pointing to Germany as country MUST BE updated to Jordan!"

**Builds on**: `specs/012-document-ingestion-textbooks` (Draft, 0/55 tasks — EPUB/PDF/FB2/DOCX/HTML ingestion
into the existing passage pipeline; this feature does not duplicate it) and `specs/015-universal-content-model-profile`
(Draft — the page/location-anchored citation type non-video content, including textbooks, needs). Both are
prerequisites this feature extends, not reimplements.

## Research Summary *(informational — not a requirement; context for the sections below)*

Deep, multi-round investigation (internal repository investigation + external research on
`prime-radiant-inc/books-for-bots` + multiple rounds of web research on 2025-2026 RAG best practices)
found that most of the retrieval infrastructure this request asks for **already exists and is already
wired** into `workshop`, via the owned `submodules/RAG` module: hybrid lexical (BM25/FTS5) + semantic
(embeddings) + code-symbol (Lumen) retrieval, fused with Reciprocal Rank Fusion, plus an optional,
off-by-default lexical window-reorder (`reorderWindow`) — **corrected 2026-10-05**, during
implementation research into the real query path (`research.md` §0): the original claim that this
is "reranked with Maximal-Marginal-Relevance" was wrong. MMR was measured non-deterministic and
score-corrupting and was removed from this pipeline entirely; it is not used anywhere in it. The
passage layer also carries a knowledge-graph layer, **nine kinds** (`kg_area`, `kg_term`,
`kg_lesson_section`, `kg_question`, `kg_mention`, `kg_next_point`, `kg_open_question`,
`kg_meeting_note`, `kg_todo`) — corrected from the original "five-kind" claim, measured directly
from `knowledge.Kinds()`) — and a proven, already-used embedding-regeneration
primitive (`cmd/index-embed`) that has already migrated the live corpus between embedding models once
before. The genuine, evidence-backed gaps this feature closes are narrower and more concrete than
"introduce RAG": no LEARNED cross-encoder reranking stage exists; content-type is not yet a first-class
retrieval/chunking dimension (today it is one ad hoc population-scoping bug fix, not a general
mechanism); the three new textbook PDFs are not yet ingested because spec 012's Phase 2 (PDF
ingestion) is fully designed but 0% built; and the `germany` research directory's Germany attribution
was itself an unverified inference layered on top of two client-feedback fragments that name no
country at all — correcting it to Jordan requires striking the now-groundless Germany-specific
inferences, not a find-and-replace of one word.

## Clarifications

### Session 2026-10-05

- Q: When a passage is stored under an existing kind that could represent more than one of FR-009's content-type categories — for example, `doc_section` could currently be meeting notes, an authored lesson, or (new) textbook prose — what should actually determine which content-type label it gets? → A: Determined by the ingesting pipeline/script at ingestion time — each ingestion script explicitly stamps the content-type as it writes the passage; never inferred after the fact from path, content, or configuration.
- Q: If the new cross-encoder reranking service is down or times out when a search query comes in, what should the query do? → A: Serve a cached last-known-good reranked result for that exact query if one exists; otherwise fall back to the pre-reranking (RRF-fused — corrected 2026-10-05, no MMR step exists in this pipeline) result. The query MUST NEVER fail outright because the reranking service is unavailable.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Textbooks become searchable, citable curriculum content (Priority: P1)

An operator has placed licensed textbook PDFs under `workshop/textbooks/ai_001/` (currently three AI/LLM
engineering books) and wants their content to become searchable and citable through the exact same
search and `/passage/{pid}` mechanisms that already serve recorded chapters and authored lessons —
without a parallel pipeline, and without re-deriving extraction logic spec 012 has already designed.

**Why this priority**: This is the literal, immediately-blocking value: three real textbooks sit on
disk today, fully unprocessed. Every other story in this feature (reranking, content-type-aware
retrieval, incremental growth) has nothing to operate on until textbook content actually enters the
corpus. Spec 012 Phase 2 already designs the requirements this story fulfills; however, deep technical
research performed during this feature's own planning (`research.md` §5) found spec 012's own
assumption — that textbook PDF extraction can reuse "the same `pdftotext -layout` convention already
proven elsewhere in this pipeline" — to be **incorrect**: that convention exists only in
`workshop/pipeline/transcribe/pdf_notes.py`, for structurally different meeting-notes PDFs, and
`workshop/pipeline/md_sections.py` (the file that would extend to textbook content) contains no PDF
handling at all. This story therefore builds a new, purpose-built extraction script
(`pdf_textbook_sections.py`), informed by both existing precedents but copying neither, rather than
reusing a mechanism that does not actually apply.

**Independent Test**: Ingest the three PDFs currently in `workshop/textbooks/ai_001/` (each with a
recorded license basis) and confirm each becomes a set of searchable `textbook_section` passages (a
new passage kind this feature introduces, distinct from `doc_section`, so content-type classification
can later distinguish textbook content from meeting notes and authored lessons — see FR-009), reachable
by both lexical and semantic search, citable at `/passage/{pid}`, and excluded from `/api/chapters`.

**Acceptance Scenarios**:

1. **Given** a text-layer PDF textbook with a recorded license basis, **When** ingestion runs, **Then**
   its text is extracted via a purpose-built textbook extraction script and sectioned into
   `textbook_section` passages, each carrying a precise location anchor (page or path+line range) a
   reader or agent can navigate to directly.
2. **Given** a textbook with ambiguous or missing heading structure, **When** section/title boundaries
   are resolved, **Then** the system falls back through a defined priority order — declared table of
   contents, then in-body heading, then document title metadata, then filename — rather than failing or
   guessing silently.
3. **Given** the same textbook ingested once, **When** ingestion is re-run against the unchanged file,
   **Then** zero duplicate passages are created.
4. **Given** a corrected, re-published edition of an already-ingested textbook changes some section text
   but not its position, **When** it is re-ingested, **Then** only the changed sections are treated as
   new content; unchanged sections keep their existing identity.
5. **Given** a textbook with no recorded license/permission basis, **When** ingestion is attempted,
   **Then** it is refused outright before any passage is written, inheriting spec 012's license gate
   rather than defining a second one.
6. **Given** any textbook ingestion run, **When** it completes, **Then** it reports both the count of
   successfully-ingested sections and an explicit list of any pages/sections it could not extract —
   never a bare success count with failures silently omitted.
7. **Given** the same source file processed twice, **When** the two extraction outputs are compared,
   **Then** they are byte-for-byte identical — extraction performs no summarization, paraphrasing, or
   other judgment-based alteration of source text.

---

### User Story 2 - Retrieval quality improves with a reranking stage, measurably (Priority: P2)

An operator or learner issuing a search query wants the most relevant results first, especially for
queries that depend on dense, technical textbook prose — not merely whatever the existing
hybrid-retrieval-plus-diversity-reranking pipeline returns today.

**Why this priority**: This is the single most concrete, evidence-backed gap the research identified
against current practice. **Corrected 2026-10-05**, during implementation research into the real
query path (`research.md` §0): the existing pipeline fuses lexical, semantic and code retrieval with
Reciprocal Rank Fusion, and separately offers an OPTIONAL, off-by-default window-local lexical
reorder (`reorderWindow`) — it does **not** rerank for diversity via MMR; that mechanism was
measured to be non-deterministic and score-corrupting and was removed from this pipeline entirely,
and is not used anywhere else in it either. There is no LEARNED relevance-modeling reranking
stage — lexical reordering and RRF-position fusion are the only mechanisms today. It directly
serves textbook content (User Story 1), which is exactly the dense, multi-hop-prone material this
upgrade benefits most.

**Independent Test**: On a fixed evaluation query set spanning transcript, authored-lesson, and textbook
content, compare top-5 result relevance before and after the reranking stage is added, with the
comparison method and acceptable regression bound decided during planning.

**Acceptance Scenarios**:

1. **Given** a hybrid-retrieved candidate set for a query, **When** the new reranking stage runs,
   **Then** it re-scores the candidates using a genuine learned relevance model, distinct from the
   existing RRF-position fusion and from the existing optional lexical window-reorder
   (`reorderWindow`) — and the two reorder mechanisms are mutually exclusive per request, never both
   applied to the same served window (corrected 2026-10-05: there is no MMR mechanism in this
   pipeline for the new stage to coexist with or preserve).
2. **Given** the same fixed evaluation query set run before and after this change, **When** results are
   compared, **Then** top-5 relevance is measurably improved or unchanged for every query class, and
   provably not regressed for any query class the evaluation set covers.
3. **Given** the reranking stage is added, **When** end-to-end query latency is measured, **Then** it
   stays within the latency budget decided during planning (the research found cross-encoder reranking
   can add materially to response time on larger candidate sets).
4. **Given** a query that was previously reranked successfully, **When** the reranking stage becomes
   unavailable or times out and the same query is issued again, **Then** the cached last-known-good
   reranked result for that exact query is served, and the response (or its logs) indicates the
   result came from the cache rather than from a fresh rerank.
5. **Given** a query with no cached last-known-good reranked result, **When** the reranking stage is
   unavailable or times out, **Then** the pre-reranking (RRF-fused — corrected 2026-10-05, no MMR step exists in this pipeline) result is served and the
   query does not fail.

---

### User Story 3 - Different content types stop interfering with each other's search results (Priority: P3)

A learner searching the platform wants transcript segments, meeting notes, authored lessons, and
textbook prose to each surface appropriately for the kind of query they answer best — not have one
content type's embedding characteristics dominate or suppress another's, the way a code-specialized
embedding model currently risks doing for prose-heavy content.

**Why this priority**: The project has already hit and fixed one instance of this class of problem (an
out-of-population semantic-score containment bug, fixed by scoping rather than by moving the relevance
floor). This story generalizes that one-off fix into a first-class mechanism before textbook content
(a new, prose-heavy content type) makes the problem worse, and before chunking policy can reasonably
differ by content type (User Story 1's textbook prose has different natural structure than a short
transcript segment or meeting-note line).

**Independent Test**: Issue queries whose best answer is known to live in one specific content type
(transcript, meeting notes, authored lesson, textbook) and confirm each query's results are not
measurably degraded by the presence of the other content types in the shared index, compared to a
content-type-scoped baseline.

**Acceptance Scenarios**:

1. **Given** every passage in the corpus, **When** it is indexed, **Then** it carries an explicit
   content-type/source-type classification (at minimum: transcript segment, meeting notes, authored
   lesson, textbook, code) usable as a first-class filtering and reranking input, generalizing the
   existing population-scoping mechanism.
2. **Given** two content types with materially different natural structure (e.g. textbook prose and a
   short transcript segment), **When** each is chunked for retrieval, **Then** each uses a chunking
   policy appropriate to its own structure rather than one fixed policy applied uniformly to all content.
3. **Given** a query whose best answer lives in textbook content, **When** it is issued, **Then** the
   answer is retrievable in the top results with reliability comparable to an equivalent query already
   answered from transcript or authored content today.

---

### User Story 4 - Adding a new chapter or textbook later costs an incremental update, not a rebuild (Priority: P4)

An operator who adds a new recorded chapter, a new textual chapter, or a new textbook in the future
wants that content to become searchable through an incremental update scoped to the new material —
never a mandatory full-corpus re-embed, which would make every future addition progressively more
expensive.

**Why this priority**: The user explicitly named this as a standing requirement ("we will be adding
more... in future"), and the project already has the proven primitives this needs — generation-scoped
embeddings and an offline-then-transplant re-embedding tool that has already migrated the corpus
between embedding models once. This story makes "incremental, never full-rebuild" an explicit,
testable guarantee rather than an implicit property nobody has verified.

**Independent Test**: Add one new content item (a new textbook, or a new chapter) to an already-indexed
corpus and confirm that making it searchable touches only the new item's embeddings/index entries,
with the existing corpus's entries and generation number left untouched unless an explicit full
re-embed is separately requested (e.g. for an embedding-model change).

**Acceptance Scenarios**:

1. **Given** an already-indexed corpus, **When** one new textbook or chapter is added, **Then** making
   it searchable requires only an incremental embedding/index update scoped to the new content.
2. **Given** an incremental update has just run, **When** the existing (pre-addition) corpus's
   passages are inspected, **Then** their embeddings, generation number, and search behavior are
   unchanged.
3. **Given** an embedding-model change (a different scenario from adding content), **When** it occurs,
   **Then** it is handled through the existing generation-versioned full-reembed-then-transplant
   mechanism, and vectors from two different embedding-model generations are never mixed within one
   retrieval comparison.

---

### User Story 5 - The client-geography error is corrected, honestly, not just renamed (Priority: P5)

An operator who knows the client researched at `workshop/docs/research/clients/germany/` is actually
from Jordan wants the research material to reflect that correctly — including any content whose
accuracy depended specifically on the (wrong) Germany attribution, not merely the directory's name.

**Why this priority**: This is independent of the RAG/textbook work and carries its own, separable
risk: the existing material's Germany attribution was itself an inference the document's own text
flags as speculative ("given the 'germany' scope of this research directory... an inference from
plausibility, not a confirmed identity match"), built on no country-naming evidence in either quoted
client-feedback fragment. A bare rename would leave Germany-grounded claims (a named candidate
company's German location, a German trade-fair reference, EU/German-specific compliance framing)
standing under a new, equally unverified Jordan label — replacing one wrong confident claim with
another.

**Independent Test**: Read the corrected research material end to end and confirm zero remaining claims
are presented as fact about Jordan when their actual basis was Germany-specific, and every claim
lacking independent Jordan-specific evidence is explicitly marked unconfirmed rather than silently
relabeled.

**Acceptance Scenarios**:

1. **Given** the `workshop/docs/research/clients/germany/` directory and its content, **When** the
   correction is applied, **Then** the directory and every internal reference to the client's country
   read Jordan, not Germany.
2. **Given** a content claim whose basis was specifically Germany-grounded (a candidate company's German
   location, a German-market trade-fair reference, EU/German-specific regulatory framing), **When** the
   correction is applied, **Then** that claim is struck or explicitly re-flagged as unconfirmed — never
   silently relabeled as if it were now evidence about Jordan.
3. **Given** the corrected material, **When** it is read by someone unfamiliar with the error history,
   **Then** nothing in it implies Jordan-specific research was performed unless it genuinely was.
4. **Given** the correction-only pass has struck or re-flagged the Germany-grounded claims, **When**
   the Wave-2 research pass runs, **Then** it independently re-derives Jordan-specific client-identity
   and market-context candidates (the same research class the original Wave-1 pass attempted for
   Germany) and records genuinely-found evidence where it exists.
5. **Given** the Wave-2 pass cannot find independently-verified evidence for a given gap, **When** it
   reports its findings, **Then** that gap remains explicitly marked unconfirmed rather than being
   filled with an invented Jordan-specific claim to mirror the original document's shape.

---

### Edge Cases

- What happens when a textbook's extracted content is near-identical to an existing authored lesson's
  content (a genuine near-duplicate across two different content types)? System MUST surface this
  rather than silently double-indexing near-identical content under two different content-type
  classifications.
- What happens when the cross-encoder reranker's relevance ordering and the RRF-fused ordering
  disagree strongly for the same query (corrected 2026-10-05: "existing RRF/MMR-fused ordering" —
  no MMR step exists in this pipeline to disagree with)? The disagreement MUST be observable (not
  silently resolved by one mechanism unconditionally overriding the other) so it can be
  investigated.
- What happens when the reranking stage itself is unavailable or times out for an incoming query?
  The system MUST serve a cached last-known-good reranked result for that exact query if one
  exists, and otherwise MUST fall back to the pre-reranking (RRF-fused — corrected 2026-10-05, no MMR step exists in this pipeline) result — the query
  MUST NEVER fail outright solely because the reranking stage is unavailable (see Clarifications,
  Session 2026-10-05, and FR-008).
- What happens when a future content type doesn't fit the existing content-type classification set
  (minimum: transcript segment, meeting notes, authored lesson, textbook, code)? The system MUST
  refuse to silently misclassify it — an honest "unclassified" state is required, never a guessed
  best-fit label.
- What happens when an embedding-model change is in flight (full re-embed under way) at the same time
  a new textbook is incrementally added? The two operations MUST NOT be allowed to mix vectors from
  two different embedding-model generations in one retrieval comparison.
- What happens when zero independently-verified Jordan-specific market research exists for a claim the
  old Germany material used to make confidently? The corrected material MUST say so explicitly
  (unconfirmed / gap) rather than inventing Jordan-specific content to preserve the old document's
  shape.
- What happens when a textbook PDF turns out to be scanned/image-only (no text layer) rather than
  text-layer, as the three current PDFs are assumed to be? Ingestion MUST be refused with an explicit
  "no text layer, OCR not available" reason — OCR handling is spec 012 Phase 3 scope, inherited here,
  not reimplemented.

#### Brainstorm Prompts

- **Boundary conditions**: What is the largest textbook (page count, file size) the extraction and
  chunking path has actually been exercised against versus merely assumed to handle?
- **Scale**: At what corpus size would the research's "GraphRAG and agentic RAG are not yet worth it at
  this scale" conclusion need re-checking?
- **User confusion**: Could a learner be misled by a textbook passage appearing alongside recorded
  chapter content with no visible indication of which content type it came from?
- **Data integrity**: What happens if the content-type classification of an already-indexed passage
  needs to change later (a passage was misclassified at ingestion)? Is reclassification itself
  idempotent and auditable?
- **Backwards compatibility**: Does adding content-type-aware chunking change the chunk boundaries (and
  therefore the stable passage identity) of already-ingested, already-cited content?

## Open Questions

| # | Question | Status | Resolution |
|---|----------|--------|------------|
| Q1 | Should this feature include evaluating/switching the embedding model, given the current default is code-specialized and license-unverified for this use? | Resolved | Yes — in scope. Evaluate candidates (e.g. Qwen3-Embedding-0.6B, BGE-M3) against the current pair on textbook/prose content; present a switch-or-keep recommendation, with any actual switch requiring explicit operator approval and its own recalibration pass, via the existing generation-scoped re-embed mechanism (see FR-016's correction below). |
| Q2 | What depth of Jordan-specific correction is in this feature's scope — a factual strike/re-flag pass, or a full Wave-2 market-research re-derivation? | Resolved | Both. A correction-only pass (strike/re-flag Germany-grounded claims) AND a Wave-2 research pass re-deriving Jordan-specific client-identity/market-context candidates to fill the gaps the correction-only pass leaves open. |

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST ingest PDF textbook material placed under `workshop/textbooks/<collection>/`
  (e.g. `ai_001`) into the same searchable, citable passage pipeline that already serves transcript and
  authored-document content, as already designed in spec 012 Phase 2. **Correction (found during this
  feature's own planning research, `research.md` §5, and recorded here per this project's
  Evidence-Based-Claims withdrawal discipline rather than silently fixed):** this requirement originally
  said the extraction "using the text extraction convention already proven elsewhere in this pipeline...
  zero new ingestion entrypoint or pipeline stage beyond what spec 012 defines." That is **false** —
  spec 012's own assumed convention (`pdftotext -layout`) exists only for structurally different
  meeting-notes PDFs. This feature therefore DOES add one new ingestion entrypoint, a purpose-built
  textbook-PDF extraction script that spec 012 itself did not define — informed by, but not copying,
  the meeting-notes precedent.
- **FR-002**: Every ingested textbook MUST carry a recorded license/permission basis before any of its
  content becomes searchable, inheriting spec 012's existing license gate rather than defining a second
  one.
- **FR-003**: A changed or newly-added textbook MUST re-ingest idempotently — zero duplicate passages on
  an unchanged re-run, and a corrected edition's changed sections identified and updated without
  re-minting the identity of its unchanged sections — reusing the tiered idempotency strategy already
  used for Markdown content and already designed for EPUB/PDF in spec 012.
- **FR-004**: Every extracted textbook passage MUST carry a precise location anchor (page, or path and
  line range) so a reader or agent can navigate directly to its exact source location, consuming spec
  015's page/location-anchored citation type rather than defining a second citation mechanism; the
  direct-offset-navigation approach researched from `prime-radiant-inc/books-for-bots` informs this
  requirement's design, not its own tooling (that project is Rust/EPUB-only and is not adopted as a
  dependency).
- **FR-005**: When a textbook's chapter/section-title structure is ambiguous or missing, the system
  MUST resolve it through a defined fallback priority order — declared table of contents, then in-body
  heading, then document title metadata, then filename — rather than failing or guessing silently; this
  fallback order is adopted from the `books-for-bots` project's own proven chapter-resolution chain.
- **FR-006**: Every textbook ingestion run MUST report, alongside its successfully-ingested section
  count, an explicit list of any pages or sections it could not extract — never a bare success count
  with failures silently omitted, matching spec 012 Phase 3's existing extraction-failure-reporting
  requirement.
- **FR-007**: Textbook extraction MUST be deterministic: the same source file, extracted twice, MUST
  produce byte-for-byte identical extracted section text — no summarization, paraphrasing, or other
  judgment-based alteration of source content.
- **FR-008**: System MUST add a cross-encoder (or equivalent learned relevance-model) reranking stage
  to the existing hybrid (lexical + semantic + code) retrieval pipeline, applied after candidate
  retrieval and before results are returned. **Corrected 2026-10-05** (`research.md` §0): there is
  no existing lexical-diversity MMR mechanism in this pipeline for the new stage to be "composable
  with" or to "preserve for passage cross-referencing" — that mechanism was measured
  non-deterministic and score-corrupting and was removed from production entirely, and is declined
  for the identical reason everywhere else in this codebase (including passage cross-referencing).
  The new stage MUST instead be mutually exclusive, per request, with the existing optional
  lexical window-reorder (`reorderWindow`) — the two are alternative answers to the same question
  (how to reorder the served window beyond RRF fusion), and composing both on one window is out of
  scope. When the reranking stage is
  unavailable or times out for a given query, the system MUST serve a cached last-known-good
  reranked result for that exact query if one exists, and otherwise MUST fall back to the
  pre-reranking (RRF-fused — corrected 2026-10-05, no MMR step exists in this pipeline) result; a query MUST NEVER fail outright solely because the
  reranking stage is unavailable, and the response (or its logs) MUST distinguish which of the
  three outcomes — freshly reranked, served-from-cache, or pre-reranking-fallback — actually
  occurred for that query.
- **FR-009**: Every passage MUST carry an explicit content-type/source-type classification (minimum
  closed set: transcript segment, meeting notes, authored lesson, textbook, code) usable as a
  first-class filtering and reranking input, generalizing the existing ad hoc population-scoping
  mechanism into a general-purpose one rather than leaving it a single-purpose bug fix.
  Content-type MUST be determined by the ingesting pipeline/script at the moment it writes each
  passage — an explicit stamp the ingestion code already has the context to supply — and MUST
  NEVER be inferred after the fact from the passage's existing `kind`, its source file path, or
  its content, since several categories in this minimum set (e.g. meeting notes and authored
  lesson) can share the same existing `kind` value and are not otherwise distinguishable.
- **FR-010**: Chunking strategy MUST be selectable per content-type classification (FR-009) rather than
  one fixed chunking policy applied uniformly to every content type, so textbook prose, transcript
  segments, meeting notes, and authored-lesson text can each use a granularity appropriate to their own
  natural structure.
- **FR-011**: Adding a new textbook, chapter, or other content item to an already-indexed corpus MUST
  require only an incremental embedding/index update scoped to the new content — never a mandatory
  full-corpus re-embed — reusing the existing generation-scoped embedding and offline-then-transplant
  re-embedding mechanism already proven in this pipeline.
- **FR-012**: An embedding-model change MUST continue to use the existing generation-versioned
  full-reembed-then-transplant mechanism, and the system MUST NEVER mix vectors produced by two
  different embedding-model generations within one retrieval comparison.
- **FR-013**: The retrieval architecture MUST operate uniformly across every currently-supported content
  type (video-chapter transcripts, meeting notes, authored lesson text, code, and textbooks) and MUST
  require no feature-specific rework when a new instance of an already-supported content type — an
  additional video chapter, textual chapter, or textbook — is added later.
- **FR-014**: The `workshop/docs/research/clients/germany/` directory and every internal reference to
  the client's country within it MUST be corrected to Jordan.
- **FR-015**: Any content claim in the corrected client-research material whose basis was specifically
  grounded in Germany — not merely inherited from the directory's former name — MUST be struck or
  explicitly re-flagged as unconfirmed rather than silently relabeled as evidence about Jordan.
- **FR-016**: System MUST evaluate candidate embedding models (at minimum: `Qwen3-Embedding-0.6B`,
  `BGE-M3`) against the current default (`jina-embeddings-code-cpu`, with `nomic-embed-text` as the
  historically-used fallback) specifically on textbook and other prose-heavy content, and MUST present
  the measured results as an explicit switch-or-keep recommendation. **Correction (originally this
  requirement said the system "MUST switch... if the evaluation's measured results support it" —
  automatic language that no task actually implements, and that this feature's own
  `contracts/embedding-bakeoff-contract.md` Decision contract deliberately built against, for safety: a
  model switch requires its own `calibratedFloor` recalibration, so it MUST be a separate,
  explicitly operator-approved decision, never an automatic consequence of a bake-off result.)** If a
  switch is approved, it MUST use the existing generation-scoped embedding and offline-then-transplant
  re-embedding mechanism (never a live-service degradation window). The exact commercial-use license of
  the current `jina-embeddings-code-cpu` deployment MUST be independently re-verified as part of this
  evaluation, rather than assumed safe because "jina" models in general are usable.
- **FR-017**: The Jordan correction (FR-014/FR-015) MUST include BOTH: (a) a correction-only pass that
  strikes or explicitly re-flags as unconfirmed every content claim whose basis was specifically
  Germany-grounded, and (b) a Wave-2 web-research pass that re-derives Jordan-specific client-identity
  and market-context candidates (the same kind of research the original, incorrectly-Germany-scoped
  Wave-1 pass performed) to fill the gaps the correction-only pass leaves explicitly open. Any gap the
  Wave-2 pass cannot close with independently-verified evidence MUST remain explicitly marked
  unconfirmed — the Wave-2 pass closes gaps where real evidence exists, it does not manufacture
  Jordan-specific claims to preserve the original document's shape.

### Key Entities *(include if feature involves data)*

- **Textbook**: A standalone, non-chapter-shaped licensed document (PDF today; EPUB/FB2/DOCX/HTML per
  spec 012) ingested as source material, scoped as `textbook-<slug>`, explicitly excluded from the
  chapter listing.
- **Passage**: An existing addressable unit of searchable/citable content. This feature adds a NEW
  passage kind, `textbook_section` (alongside the existing `transcript_segment`,
  `doc_section`, `code`, `diagram`, `screen_text`, and the knowledge-graph kinds — corrected
  2026-10-05, measured directly from `knowledge.Kinds()`: there are **nine** knowledge-graph kinds
  today, not five, making 15 total kinds with this addition, not 11 — textbook content
  is deliberately NOT stored as `doc_section`), plus a new content-type/source-type classification
  layered on top of kind. The two dimensions are independent: `kind` determines structural handling,
  `content_type` (FR-009) determines retrieval/chunking treatment, and a single kind such as
  `doc_section` can carry more than one `content_type` value (`meeting_notes` or `authored_lesson`) —
  which is exactly why content-type cannot be derived from kind alone.
- **Content-Type / Source-Type Classification**: A first-class retrieval dimension distinguishing
  transcript, meeting-notes, authored-lesson, textbook, and code origin, used for chunking-policy
  selection and reranking/filtering (FR-009, FR-010). Stamped explicitly by the ingesting
  pipeline/script at write time, never inferred post-hoc (see Clarifications, Session 2026-10-05).
- **Reranking Stage**: The retrieval-pipeline step that re-scores a hybrid-retrieved candidate set
  before results are returned. This feature adds a cross-encoder relevance-model stage, mutually
  exclusive per request with the existing optional lexical window-reorder mechanism (corrected
  2026-10-05: there is no MMR mechanism in this pipeline — see FR-008's own correction), plus a
  last-known-good result cache consulted only when the reranking stage is unavailable or times out
  (see Clarifications, Session 2026-10-05, and FR-008) — the cache is never consulted on a
  successful rerank, and is itself not a source of truth for ranking, only a fallback.
- **Embedding Generation**: The existing versioned snapshot of the vector index tied to a specific
  embedding model and a specific set of indexed content. This feature's incremental-update and
  never-mix-generations requirements build directly on it.
- **Client Research Profile**: The per-client research document tree under
  `workshop/docs/research/clients/<country>/`. This feature corrects the existing one's country
  attribution and strikes or re-flags the content whose basis depended on that attribution.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every textbook currently placed under `workshop/textbooks/` (and any textbook placed
  there in the future) becomes fully searchable and citable without requiring a parallel,
  textbook-specific search path.
- **SC-002**: A query whose best answer lives in textbook content is retrievable in the top results at
  least as reliably as an equivalent query already answered from transcript or authored content today,
  measured on a fixed evaluation query set.
- **SC-003**: Top-5 result relevance on a fixed evaluation query set is measurably improved, or
  unregressed, after the reranking upgrade ships, compared to the pre-upgrade hybrid-only baseline.
- **SC-004**: Adding one new textbook or chapter after this feature ships costs a measured, bounded
  incremental update — never a full-corpus re-embed — demonstrated by directly comparing the scope of
  work before and after one real addition.
- **SC-005**: On a fixed evaluation query set spanning all content types, no content type's results are
  measurably degraded by the presence of the others in the shared index, compared to a
  content-type-scoped baseline for the same queries.
- **SC-006**: A reviewer reading the corrected client-research material end to end finds zero remaining
  claims presented as fact about Jordan whose actual basis was Germany-specific, and finds every claim
  lacking independent Jordan-specific evidence explicitly marked unconfirmed, after both the
  correction-only pass and the Wave-2 research pass have run.
- **SC-007**: Every textbook ingestion run, for every textbook processed during this feature's
  validation, reports its extraction-failure list (even when empty) alongside its success count — no
  run reports a bare success count.
- **SC-008**: The Wave-2 research pass's findings are independently re-checkable — every newly-recorded
  Jordan-specific claim cites the source that supports it, exactly as the original Wave-1 Germany
  research did for its own (ultimately wrong) claims.

## Assumptions

- Specs 012 (document ingestion for textbooks) and 015 (universal content model / location-anchored
  citation) are prerequisites this feature builds on; this feature does not redesign or duplicate
  EPUB/PDF/FB2/DOCX/HTML extraction mechanics or the citation-anchor type — it extends what those specs
  already define, and completing spec 012's own already-designed tasks (particularly Phase 2, PDF) is
  implied, in-scope work for this feature's User Story 1.
- The three files currently in `workshop/textbooks/ai_001/` are text-layer PDFs, not scanned/image-only;
  OCR handling for image-only PDFs remains spec 012 Phase 3 scope, inherited here, not reimplemented by
  this feature.
- GraphRAG-style community-summarization retrieval and agentic/multi-hop query decomposition are
  explicitly OUT OF SCOPE for this feature at the project's current corpus size, per the research
  finding that both approaches frequently underperform plain hybrid retrieval below a certain corpus
  size and complexity threshold; they are named here as a deferred future-phase idea, not a requirement.
- `prime-radiant-inc/books-for-bots` itself (a Rust, EPUB-only CLI) is not adopted as a dependency or
  shelled-out tool; only its offset-based-navigation technique (FR-004) and its chapter-title-resolution
  fallback order (FR-005) are adopted as design patterns within this project's own existing Go/Python
  pipeline.
- "Jordan" refers to the client's country as corrected by the operator. No independently-verified
  Jordan-specific market research exists yet; this feature's scope explicitly includes a Wave-2
  research pass (FR-017) to begin closing that gap, alongside the correction-only pass (FR-014/FR-015)
  that strikes or re-flags the now-groundless Germany-specific claims.
- The existing hybrid retrieval (lexical + semantic + code, RRF-fused) and the existing knowledge-graph
  passage layer are retained as-is; this feature adds to them (a reranking stage, a content-type
  dimension), it does not replace the retrieval architecture.

## Brainstorm Log

<!-- Maintained by /speckit.superspec.brainstorm; no entries yet. -->
