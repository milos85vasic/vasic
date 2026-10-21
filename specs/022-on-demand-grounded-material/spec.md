# Feature Specification: On-Demand Grounded Material Generation

**Feature Branch**: `022-on-demand-grounded-material`

**Created**: 2026-10-20

**Status**: Draft

**Input**: Jordan client requirements document (`workshop/docs/research/clients/jordan/client-requirements-and-context.md`),
requirement **REQ-3** (custom, on-demand material generation, citation-mandatory). Gap analysis of 2026-10-20: **no
spec covers it** — spec 015 FR-006 only lets authoring/ingestion emit `document` Materials, authoring is an offline
pipeline (`workshop/pipeline/extract/author.py`), and there is no learner-facing generation flow.

**Builds on** (extends, never duplicates):
- `specs/011-multi-provider-llm-providers` — the provider catalogue and locality model (`local` / `lan` / `remote`),
  and, **when built**, the append-only remote-generation audit log (011 FR-004/FR-005). This feature calls the
  existing `answer.Provider` seam and adds **no provider-specific code**.
- The shipped answering safeguards in `workshop/platform/backend/pkg/answer` (retrieval gate, citation validation,
  entailment verification, three-state outcome) — reused as building blocks, not re-implemented.
- `specs/017-exhaustive-rag-expansion` / `012` — richer source material (textbooks) improves coverage but is not
  required.
- Related, separate: `specs/024-answering-enablement-and-provider-ui` (turning Q&A answering back on and the provider
  settings screen). This feature does not build provider-selection UI or the audit-log viewer; it consumes them.

## Research Summary *(informational)*

Measured on 2026-10-20 (paths relative to `workshop/`):

- The **provider seam already exists**: `answer.Provider` with `Descriptor` / `Health` / `Generate`
  (`platform/backend/pkg/answer/provider.go:34-50`); `Generate` returns claims keyed by passage id plus measured
  `GenStats` (`provider.go:52-95`), and returns a typed `*Reason` rather than an opaque error.
- **Three-state honesty already exists** as code: `answered` / `declined` / `unavailable`, with a closed decline
  vocabulary and a disjoint closed unavailable vocabulary
  (`platform/backend/pkg/answer/outcome.go:54-300`). A decline is a correct result served with HTTP 200;
  `unavailable` is HTTP 503 (`outcome.go:84-91`).
- The grounding layers exist and are reusable: L1 retrieval gate `grounding.RetrievalGate`
  (`submodules/RAG/pkg/grounding/grounding.go:193`), citation membership `ValidateCitations` (`:282`), verbatim
  quote check `ValidateVerbatim` (`:322`), entailment judge package `platform/backend/pkg/entail`, claim
  verification `VerifyClaims` (called at `pkg/answer/pipeline.go:447`), question-relevance layer L5
  (`pkg/answer/question.go:80`).
- **Answering is OFF by default and the fabrication target is unmet**: compose passes `-answer-provider none`
  (`platform/compose.yml:553`) and the umbrella governance carrier records a measured 14/72 answer rate and 4/87
  (4.6%) fabrication on the unanswerable set (`platform/backend/evidence/answering/MEASUREMENT-generation-15-2026-09-24.md`
  exists; the figures here are quoted from the governance record and are re-measured by T008). **Generation of
  multi-sentence material is a larger fabrication surface than one-answer Q&A.** That is why this feature ships
  **default OFF** and why FR-022 sets an enablement bar.
- **Thresholds**: `-min-score` defaults to 0, which is *uncalibrated* and makes the gate refuse everything as
  `unavailable` (`platform/backend/cmd/workshop-server/main.go:545`, `pkg/answer/pipeline.go:24-31`). A material
  pipeline built on an uncalibrated gate must refuse, not generate.
- **Assessment content already demands citations**: `Question.Citations` is mandatory and validated non-empty
  (`platform/backend/pkg/assessment/question.go:141-145,231`). Generated items follow the same rule.
- **Audit-log gap**: spec 011's audit writer (`pkg/answer/audit.go`) is not built (011 US2 tasks T007–T014 unchecked);
  011's contract leaves "fail open vs fail closed on audit-write failure" as NEEDS CLARIFICATION
  (`specs/011-multi-provider-llm-providers/contracts/remote-generation-audit-log.md` §2). This feature decides it
  **for its own path** (fail closed, FR-015) and requires consistency with whatever 011 decides.
- **Interpretation to confirm (OD-2).** REQ-3 as written asks for material about needs "not already covered by the
  ingested corpus". The instruction governing this feature is stricter and is adopted: material is grounded
  **only** in retrieved corpus passages. Where the corpus does not cover a topic the platform **declines** and
  points the operator to ingestion (REQ-2: specs 012/017/020). The feature re-composes what the corpus *knows* into
  new forms (explainer, flashcards, short prompts) for a topic or a learner's need; it never supplies knowledge
  from the model's own memory.

## Clarifications

### Session 2026-10-20 (design defaults, to be ratified by the operator)

- Q: May a generated material enter the shared curriculum? → A: No. Generated material is a **private draft** for the
  requesting learner, labelled "Generated". Promotion into authored content (spec 015 `document` Material /
  `author.py` pipeline) requires independent review and is deferred and blocked (User Story 6, T058).
- Q: Which model does the learner use? → A: The operator-configured material provider (`-material-provider`,
  default: the answering provider). Learners do not choose a model; they see which one will be used.
- Q: Are declined requests cached? → A: Yes, keyed identically, because with the same corpus generation the decision
  is deterministic and re-asking should not spend resources. `unavailable` results are never cached.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A learner asks for grounded study material on a topic and gets cited material or an honest decline (Priority: P1)

A signed-in learner opens "Create study material", types a topic ("explain X"), picks a form (explainer,
flashcards, short-answer prompts), sees which provider will run and its locality, confirms, and receives a draft in
which every sentence carries a citation they can open (`/passage/:pid`) and a verbatim supporting quote. If the
corpus does not support the topic well enough, the platform declines and says why.

**Why this priority**: this *is* REQ-3, and it must be trustworthy before it is convenient.

**Independent Test**: With the scripted fake provider (no real model), request a topic the fixture corpus covers and
one it does not; assert one `generated` material in which 100% of items cite live passages, and one `declined`
material with a closed reason code and zero provider calls beyond the gate.

**Acceptance Scenarios**:

1. **Given** a covered topic and a working provider, **When** the learner confirms the request, **Then** a job is
   created, progresses (`retrieving` → `generating` → `verifying`), and ends `generated` with items, each with ≥ 1
   citation and a quote; provenance (provider, model, locality, corpus generation, passage count) is shown.
2. **Given** a topic the corpus does not cover, **When** requested, **Then** the result is `declined` (HTTP 200) with
   a reason from the closed vocabulary and **no** generated text, and the UI offers "ask an operator to add a
   source" (no invented answer).
3. **Given** the provider is down, **When** requested, **Then** the result is `unavailable` (HTTP 503) with a code
   and no decline is reported (an outage is not a verdict on the corpus).
4. **Given** generation is disabled (default), **When** the learner opens the page, **Then** it says generation is
   off and why, and no request can be submitted; the rest of the platform is unaffected.

---

### User Story 2 - The platform declines instead of fabricating (Priority: P1)

Every generated item is verified after generation: its citations must be members of the retrieval set that was
actually shown to the model, its quote must appear verbatim in the cited passage, its claim must be entailed by the
cited passage, and it must address the requested topic. One failing item declines the **whole** material — items are
never silently stripped to make a draft look better.

**Why this priority**: SC-010-style behaviour ("decline rather than fabricate") is the product's differentiator
(REQ-5) and the feature is unsafe without it.

**Independent Test**: A scripted provider emits each fabrication class (invented citation id, citation outside the
set, missing citation, quote not in passage, claim contradicting passage, off-topic claim, ungrounded flashcard
answer); every one yields `declined` with the matching reason and persists nothing.

**Acceptance Scenarios**:

1. **Given** an item citing a pid that was not in the prompt, **When** verified, **Then** the whole material is
   declined `no_citations`.
2. **Given** a quote that is not a substring (after whitespace normalisation) of the cited passage, **Then**
   declined `unsupported`.
3. **Given** the entailment judge cannot run, **When** verification is required, **Then** the result is
   `unavailable` (`verification_unavailable`), never "verified".
4. **Given** a passage suppressed after retrieval but before delivery, **Then** declined `redacted_evidence`.

---

### User Story 3 - It never runs unless the learner asks, and cost is bounded (Priority: P1)

Nothing generates in the background: no startup warm-up, no prefetch, no scheduled job, no regeneration after a
corpus change. A request is an explicit authenticated action. Every request is checked against per-request caps,
per-session and global daily token budgets, a concurrency limit and a rate limit **before** any provider call; a
refused request says which budget and when it resets. Budget accounting survives restarts and cannot be exceeded by
concurrent requests.

**Why this priority**: REQ-3 raises the cost and egress exposure of the whole platform; the learner (and the
operator paying for a remote provider) must be able to rely on "it only spends when I ask".

**Independent Test**: Boot the server with a counting provider stub; exercise every other endpoint and idle 10
minutes; stub count = 0. Then drive requests across each budget boundary (limit−1, limit, limit+1) and 50
concurrent requests against a small budget; the stub count never exceeds the budget-implied number.

**Acceptance Scenarios**:

1. **Given** no request, **When** the server runs, **Then** provider call count is 0 (SC-003).
2. **Given** a request whose estimated prompt exceeds the per-request cap, **Then** it is refused
   `budget_exceeded` (which=`request_prompt`) before any provider call.
3. **Given** the session daily budget would be exceeded, **Then** `budget_exceeded` (which=`session_daily`) with a
   reset time.
4. **Given** the budget store is unreadable, **Then** `unavailable budget_store_unreadable` — fail closed.

---

### User Story 4 - The operator can use a local or LAN model, and every remote generation is audit-logged (Priority: P2)

The operator points material generation at any catalogue provider, including a local model and a model server on
the LAN (spec 011 US3). Retrieved corpus passages leave the host **only** for a non-local provider, only when the
operator has allowed remote use, and only for a request that carries the learner's explicit acknowledgement naming
the provider and its locality. Each remote or LAN generation attempt writes one audit record (no prompt, passage or
answer text) **before** the response is returned; if the audit record cannot be written the request fails closed.

**Why this priority**: the corpus is private and the client context raises data-locality questions (REQ-6);
the feature must not widen egress silently.

**Independent Test**: Against a stub provider with a request counter, for success, upstream error and timeout,
`audit lines == provider requests`, zero lines contain canary strings placed in the topic, the passages and the
output.

**Acceptance Scenarios**:

1. **Given** a `local` provider, **When** generating, **Then** no remote audit line is written and no data leaves
   the host (asserted by the stub's bind address).
2. **Given** a `remote` provider without allow-remote, **Then** `unavailable provider_disabled`, 0 provider calls.
3. **Given** allow-remote but no per-request acknowledgement, **Then** `400 remote_ack_required`, 0 provider calls.
4. **Given** the audit file is not writable, **Then** `unavailable audit_unwritable`, 0 provider calls.

---

### User Story 5 - Repeating a request is cheap, correct and idempotent (Priority: P2)

A verified material is cached under a key derived from the form, the normalised topic, the parameters, the corpus
generation and the prompt-template version. Asking again costs nothing and returns the same material, re-checked at
serve time (cited passages still exist and are not suppressed). A new corpus generation invalidates the cache.
Concurrent identical requests produce one generation.

**Independent Test**: second identical request = 0 provider calls and byte-identical material; generation bump =
miss; 20 concurrent identical requests = 1 provider call and 1 audit line; replayed `Idempotency-Key` = 1 job.

---

### User Story 6 - The operator can review what was generated (Priority: P3)

An admin can list generated materials with provenance, verification results, decline reasons and token usage to
judge quality and cost. Promotion into authored curriculum is **blocked** (needs an operator decision and an
independent content review path; see T058).

### Edge Cases

- Topic is empty, too long (> 300 characters), contains control characters, or is itself an instruction to
  the model ("ignore the passages…"): validated and bounded; passages and topic are untrusted text, output is
  structurally validated, never executed (FR-020).
- The corpus generation changes while a job is running: the job finishes against the generation it started with
  and is labelled with it; a later read re-validates and may withhold stale citations.
- The same topic in a different language than the corpus: behaviour is UNCONFIRMED; the retrieval gate decides
  (likely `below_threshold`), and the feature never translates.
- Provider returns well-formed JSON with zero items: `declined no_items`.
- Provider returns more items than requested: extra items discarded **before** verification is not allowed
  (silent stripping); the whole result is declined `malformed_output`.
- Very large cached object: bounded by `max_items` and `max_item_chars`; oversize ⇒ `malformed_output`.
- Two learners request the same topic: separate private materials may share one cache entry's *verified
  content*; each learner's ownership is a separate row, and neither learner's identity is stored in the cache row.
- Clock skew or day rollover during a request: budget day is the server's UTC date at reservation time and is
  stored with the reservation.
- Admin deletes a material or a learner deletes their own: cache entry remains (content is corpus-derived and
  contains no personal data); ownership row is removed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Material generation MUST be reachable only via an authenticated, explicit request
  (`POST /api/materials`). The request carries `form` ∈ {`explainer`, `flashcards`, `short_prompts`}, `topic`
  (≤ 300 characters), `count` (bounded), and, for non-local providers, `remote_ack`.
- **FR-002**: Every generated item MUST be grounded **only** in passages that were retrieved, gated and placed in
  the prompt. Every item MUST carry ≥ 1 citation (pid) that is a member of that admitted set, plus a verbatim quote
  from the cited passage. Anything that cannot be so grounded MUST cause the whole material to be declined.
- **FR-003**: Outcomes are the closed three-state set `generated` / `declined` / `unavailable`. Their reason-code
  vocabularies (decline reasons, unavailable codes) MUST be mutually disjoint, enforced by a test. `declined` is
  HTTP 200, `unavailable` is HTTP 503. A budget refusal, outage or missing capability is `unavailable`, never a
  decline.
- **FR-004**: The retrieval gate MUST use calibrated thresholds. With `min-score == 0` (uncalibrated) the result is
  `unavailable thresholds_uncalibrated`; the pipeline MUST NOT generate. In addition a coverage rule requires at
  least `MinDistinctPassages` (default 3) distinct admitted passages; otherwise `declined insufficient_coverage`.
- **FR-005**: (S17 review H2: a verifier that is only the lexical word-overlap floor, or a relevance check that is only the deterministic focus check, is NOT an acceptable judge: generation is `unavailable verification_unavailable` with an operator-facing reason until a real entailment judge and the model-backed relevance check are configured, and a pass is never recorded from a floor.) Verification layers, in order: citation membership; verbatim quote; entailment of the item's claim by
  its cited passage; relevance of the item to the requested topic. A verifier that cannot run yields `unavailable
  verification_unavailable`; an unverifiable item is never treated as verified.
- **FR-006**: The learner MUST be able to see, per item, the citation link and the supporting quote ("show
  source"). Withheld (suppressed) passage text MUST show the withheld reason, not an empty string, as the answering
  `Citation` does (`pkg/answer/outcome.go:357-380`).
- **FR-007**: Forms supported in this feature: `explainer` (≤ N short sections), `flashcards` (front / back),
  `short_prompts` (prompt + model answer). **EVERY learner-visible generated field is a verified claim** (S17 review
  H1, 2026-10-21): the lead (front / prompt / heading) and the assertion (back / model answer / body) are
  verified TOGETHER as one claim by the entailment and relevance layers, and each is also checked by the
  suppression layer; a lead that passes only a text filter is a defect (a fabricated heading over a faithful body
  would otherwise be served as verified). A quote must be at least 20 characters and share a content word with the
  claim it supports. **Multiple-choice quizzes are deferred**: distractors are by design not corpus claims, and how
  to ground or bound them is an unresolved design question (OD-4). The feature MUST NOT emit MCQ.
- **FR-008**: Each material MUST record provenance: provider, model, locality, corpus generation, prompt-template
  version, the admitted passage ids, per-layer verification results, token statistics, and a `served_from` ∈
  {`fresh`, `cache`}. The UI labels it "Generated" and never presents it as authored or published content.
- **FR-009**: A material is private to the requesting session. No endpoint returns a material of another session
  except the admin review list (FR-025), which is audited.
- **FR-010**: Suppressed or redacted passages MUST be excluded from the admitted set **before** the prompt is
  built, MUST never appear in the prompt, material or cache value, and a cache hit MUST re-check suppression at
  serve time.
- **FR-011**: There MUST be exactly one code path that calls `Provider.Generate` for materials, and it is reachable
  only from the request handler. No scheduler, warm-up, prefetch, startup or post-ingest hook may call it. A static
  gate enumerates the call sites (SC-003).
- **FR-012**: Budgets, all enforced **before** any provider call and fail-closed: per-request (max admitted
  passages, max estimated prompt tokens, max output tokens, wall-clock timeout), per-session daily tokens, global
  daily tokens, concurrent generations, requests per minute per session. Reservation is atomic (a request reserves
  its estimate; concurrent requests cannot jointly exceed a budget); settlement records actual `GenStats`.
- **FR-013**: Before confirmation the UI MUST show provider, locality, and an upper-bound token estimate; after
  completion it MUST show actual tokens. No monetary figure is shown unless the operator supplied a price table;
  none is invented.
- **FR-014**: The provider is any `answer.Provider` row from the catalogue, including `local`, `lan` and `remote`
  localities, constructed by the existing registry. No provider-specific branch is added. With provider `none`:
  `unavailable no_provider`.
- **FR-015**: For every non-`local` provider, one audit record per generation attempt MUST be written in the
  schema of spec 011 FR-005 (session id, provider, model, endpoint, timestamp, request byte-count, outcome) —
  **no prompt, passage or generated text** — synchronously before the response is returned. If it cannot be
  written the request MUST fail closed (`unavailable audit_unwritable`) and the provider MUST NOT be called. A
  durable `generation_attempt` row is inserted before the call and settled after it, so an attempt that crashed
  mid-flight is visible rather than silently unaudited.
- **FR-016**: Passages leave the host only for a non-local provider **and** only if the operator enabled remote use
  **and** the request carries `remote_ack` naming the provider and locality shown to the learner.
- **FR-017**: Caching: key = SHA-256 of the canonical tuple (form, normalised topic, parameters, corpus generation,
  template version). `UNIQUE(cache_key)`; value = verified material or a decline; `unavailable` is never stored.
  A hit re-validates that every cited pid is live and unsuppressed, with no model call, and is labelled
  `served_from=cache`. A new corpus generation yields a miss. Identical concurrent requests are single-flighted.
- **FR-018**: Topic normalisation is deterministic (NFC, trim, collapse whitespace; case-folded for the key only).
- **FR-019**: `POST` accepts an `Idempotency-Key`; `UNIQUE(session, idem_key)` makes retries return the same job.
- **FR-020**: Retrieved passage text and the learner's topic are untrusted. The provider's output MUST be parsed
  against a strict schema (unknown fields rejected), rendered through the platform's markdown sanitiser, and never
  executed or used to alter budgets, provider, flags or storage paths.
- **FR-021**: Everything except the model call is deterministic and unit-testable: retrieval admission, thresholds,
  budget arithmetic, cache keying, verification order. Tests use a scripted fake provider.
- **FR-022**: The feature ships **default OFF** (`-materials-enabled=false`). Enabling it in a deployment requires a
  recorded measurement of fabrication on an unanswerable-topic set (harness and set recorded in `evidence/`), with
  the upper confidence bound stated, and an operator sign-off (OD-1). The spec does not assert any rate.
- **FR-023**: Observability: counters for requests, outcomes by reason/code, cache hits, tokens in/out, budget
  refusals; structured logs carrying ids and codes, never topic text, passage text or output text.
- **FR-024**: Boot invariants (§11.4.254): invalid budget configuration, missing store, enabled-without-provider, or
  remote-provider-without-audit-path refuse to start (or, for provider/audit absence, register routes that answer
  determined `unavailable`); a capability-matrix row is declared.
- **FR-025**: Admin review (US6): list with provenance, verification results, decline reason, token usage; topic
  text shown only if the operator enabled it (OD-3); every admin read of another session's material is itself
  logged.
- **FR-026**: Deletion: a learner can delete their own materials; deleting removes the ownership row and any
  personal linkage but not the corpus-derived cache content.

### Key Entities

- **MaterialRequest** (normalised topic, form, params, idempotency key, remote_ack).
- **Material** (id, session, form, status, items[], provenance, served_from, created_at).
- **Item** (kind, text fields, citations[pid], quote, verification results).
- **Job** (id, status, phase, elapsed) — durable.
- **CacheEntry** (key, status ∈ generated|declined, content, corpus_generation, template_version).
- **BudgetLedger** (day, scope, tokens_reserved, tokens_settled, requests).
- **GenerationAttempt** (id, material id, provider, locality, started_at, settled_at, outcome).
- **AuditRecord** (spec 011 schema; external file).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In ≥ 200 scripted generations (fake provider, fixture corpus), 100% of items carry ≥ 1 citation to a
  live, non-suppressed member of the admitted set and a quote found verbatim in it; 0 uncited items exist in any
  persisted `generated` material.
- **SC-002**: A fabrication matrix of ≥ 10 classes (invented pid, out-of-set pid, no citation, non-verbatim quote,
  contradicting claim, off-topic claim, extra items, malformed JSON, empty items, oversize) yields 100% refusal
  (`declined` or `unavailable`), 0 persisted materials, with a paired mutation per layer proving the test would
  catch its removal.
- **SC-003**: With a counting provider stub, boot + 10 minutes idle + exercising all other endpoints ⇒ 0 provider
  requests; a static gate shows exactly one `Generate` call site for materials, reachable only from the handler.
- **SC-004**: 100% of over-budget requests are refused before any provider call; boundary cases (limit−1, limit,
  limit+1) behave as specified; 50 concurrent requests against a budget that admits k never produce more than k
  provider calls.
- **SC-005**: For each of success, upstream error and timeout against a non-local stub, audit lines == provider
  requests; 0 audit lines contain canary strings placed in the topic, passages or output; audit-unwritable ⇒ 0
  provider calls.
- **SC-006**: Repeat request ⇒ 0 provider calls, byte-identical material; corpus generation bump ⇒ miss; 20
  concurrent identical requests ⇒ exactly 1 provider call and 1 audit line; 20 retries with one `Idempotency-Key`
  ⇒ 1 job.
- **SC-007**: A canary passage marked suppressed never appears in any prompt (captured at the stub), material or
  cache value; a cache hit after suppression withholds it.
- **SC-008**: UI-visible: an operator can walk quickstart Scenarios 1–6 on the running UI: request form with provider
  and locality disclosure → confirmation → draft with citations and quotes → a decline → a budget refusal → a cache
  hit, and sign the checklist (T059).
- **SC-009**: Live verification writes `evidence/live/result.json` + `MANIFEST.sha256` (T062). If no real provider is
  enabled by the operator, the live run records `skipped_operator_gated` and exits 2 — never PASS.
- **SC-010**: Fail-closed matrix: with each dependency individually down (retriever, verifier, budget store, cache
  store, audit file, provider) the outcome is the specified `unavailable` code, with 0 partial materials persisted.
- **SC-011**: Documentation set (manual, guides, FAQ, four diagrams) exists and its exports pass independent
  validation (T063–T071).

## Assumptions

- A calibrated retrieval threshold set exists or is produced before enablement; its provenance is recorded
  (T008). Today it is UNCONFIRMED (`min-score` defaults to 0; the `floor-domain` calibration corpus is recorded as
  no longer existing in the governance record).
- The operator controls providers and flags; learners cannot select a model.
- The retriever interface used by answering is reusable for materials; content-type scoping default is "all
  non-suppressed prose kinds" (OD to confirm the exclusion of `kg_term`-style rows, as the existing floor does).
- A local generative model is available on the host (a 3B instruct model is recorded in the governance carrier);
  whether it is fit for multi-item generation is **UNCONFIRMED** and is what T008 and the enablement measurement
  determine.

## Risks and operator decisions (S17 review, 2026-10-21)

| Risk | Decision |
|---|---|
| `served_from = cache`: a learner who asked for a topic someone else already generated would receive that cached material, revealing that the topic was requested before. | **RATIFIED 2026-10-21 (operator decision OD-8): the cache is PER LEARNER only.** Generated material (and, stricter than required, declines) is never shared across learners: the cache key folds in a salted, one-way learner tag, so `served_from: cache` can only ever mean the learner's OWN earlier request. **Spend implication:** the same topic asked by N learners costs N separate generations; the per-session and global daily token budgets, rate and concurrency caps still apply to each. Cache entries written by the earlier (shared-key) build become unreachable to new requests; their owners still read them through their own rows. |
| A non-local provider may bill a request whose result we discard (timeout, audit write failing after a successful upstream call). | **Accepted and priced in:** such attempts are charged the full reservation (an upper bound), never refunded. |

## Dependencies and Blockers

| Dependency | Needed for | Status 2026-10-20 |
|---|---|---|
| Spec 011 US1 (catalogue rows) | provider abstraction | done (workshop `bb69fe5` per gap analysis) |
| Spec 011 US2 (audit log writer) | remote/LAN generation (US4) | **not built** (T007–T014 open); US4 remote path BLOCKED, local path unaffected |
| Spec 011 US3 (`lan` locality) | LAN provider | not built; LAN path BLOCKED |
| Spec 011 US4 (provider switch) | none | blocked upstream; not needed |
| Calibrated gate thresholds | FR-004 | UNCONFIRMED (T008) — generation refuses until present |
| Fabrication measurement + sign-off | enabling | open (OD-1) |
| Wave-0 hook split | flags/routes/vocabulary | not performed |
| Spec 024 | provider settings + audit viewer UI | separate; coordinate T051 |
| Spec 013 / 021 | none (optional later: default form from 021's recommendation) | n/a |

**Blocked on unresolved client identity.** REQ-3's wording ("a topic, client, or participant need") presumes a
notion of *client* and *client-owned material*. Which organisation originated the feedback (ACS consulting /
Valaeon / the "Drall platform" failure it complains about) is UNCONFIRMED in the research document, and the platform
has no tenant/workspace concept. This feature is therefore **single-corpus, per-learner**. Per-client corpora,
client-owned uploads and deliverable export wait for the workspace stub (gap analysis item 023) and for the
client's identity and requirements; nothing about them is invented here.

## Open operator decisions

- **OD-1** Enablement bar: acceptable upper bound on measured fabrication, the unanswerable-topic set, and sign-off.
- **OD-2** Confirm the interpretation of REQ-3 (corpus-only; decline + ingestion pointer when uncovered) with the client.
- **OD-3** May admin review show topic text and material bodies, and is the learner told? (privacy disclosure).
- **OD-4** MCQ with distractors: how to ground or bound them (allow model-written distractors flagged as
  "not from the corpus"? disallow?). Default: disallowed.
- **OD-5** Budget numbers (per-request, per-session daily, global daily, rate) and whether a price table is supplied.
- **OD-6** Is remote generation permitted for this private corpus at all, and under which acknowledgement text?
- **OD-7** Promotion of generated material into authored curriculum (who reviews, which pipeline).
