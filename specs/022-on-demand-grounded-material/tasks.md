# Tasks: On-Demand Grounded Material Generation

**Input**: Design documents from `specs/022-on-demand-grounded-material/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/` (6 files), `quickstart.md` (all present)

**Tests**: INCLUDED and test-first. Every implementation task follows a RED task whose oracle is named in
`contracts/`. Execution markers map 1:1 onto `/speckit.superspec.execute`'s vocabulary.

**Organization**: by user story. US1–US3 are P1 and deliver the safe core with the **local provider** and the
scripted fake; US4 (remote/LAN + audit) depends on spec 011 and is partly blocked; US5 cache; US6 operator review.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]** parallel-safe · **[TDD]** strict RED→GREEN→REFACTOR · **[REVIEW]** independent review (Opus, effort
  xhigh, verdict file with `finding_layer`) before dependents start · **[SUBAGENT]** safe to delegate ·
  **[HOOK]** touches an orchestrator-owned file (exact lines stated, host file not edited by the stream) ·
  **[BLOCKED:xxx]** cannot start, reason named · **[OD-n]** waits for an operator decision.
- Story labels: `SETUP`, `FOUND`, `US1`–`US6`, `POLISH`.

## Path conventions

Backend `workshop/platform/backend/` (`pkg/materialgen/`, `internal/api/materials.go`,
`cmd/workshop-server/wire_materialgen.go`); frontend `workshop/platform/frontend/src/app/features/materials/`;
oracle `workshop/pipeline/`; gates `workshop/platform/gates/`; docs `workshop/docs/features/grounded-material/`.
**Content boundary**: no text from `workshop/chapters/**` or transcripts in any file; counts, ids and paths only.
**Host safety**: before any fan-out record `ulimit -u`, live thread count and `free -m` (§12.6, §12.12); wrap
heavy runs in the repository's bounded execution; stage explicit paths only (§11.4.84).

---

## Phase 1: Setup

- [ ] T001 [SETUP] Baseline: checked-task counts of specs 011 (expected 5/27) and 013/015, workshop `HEAD`,
      `GET /api/health` build stamp, the running container's flags (`/proc/<pid>/cmdline` of the server: confirm
      `-answer-provider none`, `-min-score`), host headroom. Write `specs/022-on-demand-grounded-material/evidence/setup-baseline.json`
      with sha256.
- [ ] T002 [P] [SETUP] Confirm every reuse point cited in `research.md` §0 by CodeGraph/semantic search and record
      path:line corrections: `answer.Provider`, `GenRequest/GenResult/GenStats`, `BuildPrompt`, `Prompt.Resolve`,
      `VerifyClaims`, `SupportVerifier`, `QuestionVerifier`, `LiveRegistry`, `grounding.RetrievalGate`,
      `ValidateCitations`, `ValidateVerbatim`, the provider registry constructor, and `core/markdown.ts`
      sanitisation. Any symbol that does not exist as cited is a spec correction before T010.
- [ ] T003 [P] [SETUP] **Research R-1 (§11.4.150).** Deep multi-angle web research with primary-source citations
      written into `research.md`: faithful/citation-grounded generation and its evaluation; hallucination and
      unsupported-claim detection in RAG output; structured-output reliability of small instruct models; prompt
      injection through retrieved text; LLM-service budgeting, caching and idempotency practice; privacy of sending
      private corpora to hosted models. Amend FR-005/FR-007/FR-020 if evidence contradicts them.
- [ ] T004 [P] [SETUP] **Research R-2.** Read `specs/011-…/contracts/remote-generation-audit-log.md` and (once
      written) `pkg/answer/audit.go` / `hosted.go`; establish whether 011's call sites audit per **attempt** (spec
      FR-004) or per **construction** (011 T011 wording: "`newHostedProvider`"). Record the finding; if per
      construction, the per-attempt requirement is raised to 011's owner (blocker for US4, not for the rest).
- [ ] T005 [P] [SETUP] **Research R-3.** Determine how `internal/answering/wire.go` builds the retriever and applies
      suppression (`installSuppression`, `api.FilterSuppressedBody`), whether a passage-level "exclude suppressed
      pids from the admitted set" function exists, and which content-type scopes are available (spec 017). Record the
      reuse points and the gap, if any.
- [ ] T006 [P] [SETUP] **Research R-4.** Identify the source of "corpus generation" at request time
      (`Pipeline.Generation`, `pkg/answer/pipeline.go:92-95`), confirm it changes whenever an index swap can change
      retrieval results, and test whether retrieval is deterministic for a fixed generation (`pkg/search/determinism.go`
      exists). If not deterministic, FR-017's decline-caching changes to a short TTL — record that decision.
- [ ] T007 [SETUP] Wave-0 hook confirmation: `// hook:materialgen` in `cmd/workshop-server/main.go` and the one-line
      hooks in `app.routes.ts` and `core/vocabulary.ts`. **If absent: STOP and request the orchestrator; never edit
      those files.** Record.
- [ ] T008 [SETUP] **Calibration and baseline.** Establish which `-min-score` / `-min-margin` the live server runs
      with and whether calibrated values exist (`platform/backend/evidence/answering/CALIBRATION*.tsv`,
      `calibratedFloor` in `main.go`); re-derive the quoted answering figures (answer rate, fabrication count) from
      `MEASUREMENT-generation-15-2026-09-24.md` (figures only, no passage text) and record whether they reproduce.
      Output `evidence/baseline-answering.json`. If no calibrated thresholds exist: record it — generation must
      refuse (`thresholds_uncalibrated`) and T062 will record `skipped_operator_gated`.
- [ ] T009 [REVIEW] [SETUP] Independent review of `contracts/failure-scenarios-and-fabrication-matrix.md`: each of
      I1/I2/I3 has scenarios with named tests, oracles and paired mutations; F-1…F-15 are complete; reviewer ≠ author
      (§11.4.239: the map exists before code).

**Checkpoint**: facts re-verified, hooks confirmed, scenario map accepted, calibration state known. No code yet.

---

## Phase 2: Foundational (blocks every story)

- [ ] T010 [TDD] [FOUND] `pkg/materialgen/outcome.go`: `Status`, `DeclineReason`, `UnavailableCode`,
      `DisjointVocabularies()`. Tests in `outcome_test.go`: **disjointness** (FR-003) and **parity** — every reused
      name equals the corresponding constant in `pkg/answer` (`outcome.go:113-300`). Oracle: the literal lists in
      `data-model.md` §2 and the `answer` constants. RED first.
- [ ] T011 [TDD] [FOUND] `pkg/materialgen/request.go`: `Form`, `Request`, `Normalise`, validation (topic 1–300 runes,
      NFC, no control characters, bounded count, `Idempotency-Key` shape, `RemoteAck`). Table test of valid/invalid
      requests incl. MCQ rejected (`invalid_form`), prompt-injection-looking topics accepted-but-bounded. Oracle:
      table in test header derived from `data-model.md` §1. RED first.
- [ ] T012 [TDD] [FOUND] `pkg/materialgen/cachekey.go` + `TestCacheKeyGoldenVectors`: oracle = vectors produced by
      T013 (independent). Include NFC/whitespace/case variants (C-9) and a generation/template-version sensitivity
      check (C-2).
- [ ] T013 [P] [SUBAGENT] [FOUND] **Independent oracle.** A DIFFERENT agent than the Go implementer writes
      `pipeline/materialgen_oracle.py` (stdlib only, `python3 -I`): cache-key vectors, the budget boundary table (B-1)
      and the fabrication-matrix JSON shape from `contracts/` text alone, with `pipeline/tests/test_materialgen_oracle.py`
      and committed outputs under `platform/backend/pkg/materialgen/testdata/materialgen/`
      (`cache_key_vectors.json`, `budget_table.json`, `fabrication_matrix.json`). `--check` mode regenerates and
      diffs. Record the author agent id (Producer ≠ Oracle, §11.4.249).
- [ ] T014 [TDD] [FOUND] `pkg/materialgen/budget.go`: pure arithmetic (`Estimate`, `Admit(ledgerView, limits, est)`),
      limits struct + `Validate()` (boot, S-14). Tests: boundary table from T013 (`TestBudgetBoundaries`), invalid
      config table. RED first.
- [ ] T015 [TDD] [FOUND] `pkg/materialgen/store.go`: `Open(dir)` → `materials.db` with the DDL of `data-model.md` §4
      (CHECKs, UNIQUEs), migrations idempotent, open-failure error codes. Tests: each constraint rejects a bad row
      (`TestSchemaConstraints`: `generated` without content, `declined` with content, duplicate `(session,idem_key)`,
      duplicate `cache_key`), idempotent re-open. Oracle: the DDL's own CHECK list (assert by attempting violating
      inserts). RED first.
- [ ] T016 [P] [FOUND] `pkg/materialgen/mgtest/`: (a) scripted fake `answer.Provider` driven by a script file
      (claims, errors, delays) with a call counter and prompt capture; (b) an `httptest` stub speaking the provider's
      HTTP protocol with request counter, canary capture, configurable locality via bind address, upstream error and
      timeout modes. Used by unit tests, gates and the isolated server. Own tests prove the counter and capture work
      (a counter that cannot fail is a bluff).
- [ ] T017 [P] [FOUND] `platform/gates/verify-materialgen-single-callsite.sh` (three-valued: 0 clean / 1 finding /
      2 could-not-determine) enforcing: exactly one non-test `.Generate(` call in `pkg/materialgen`, `Generator.Run`
      referenced only from the job worker, and no `materialgen` reference in boot/ticker/ingest/index-swap/`/api/ask`
      paths. Paired `prove-…` injects a second call and a `main.go` warm-up call into a throwaway copy and requires
      exit 1 for each. Registry TSV row handed to the orchestrator.
- [ ] T018 [TDD] [FOUND] `pkg/materialgen/config.go` + `wire_materialgen.go` flag declarations (`addMaterialFlags`):
      all flags of `contracts/budget-and-cost-guards.md` §1 with env mirrors; `-materials-enabled` default `false`.
      `TestBootRefusesInvalidConfig` (S-14): zero limits, session > global, enabled without store, remote provider
      without audit path. Capability-matrix row declared.
- [ ] T019 [REVIEW] [FOUND] Independent review of T010–T018; verify the fake provider and stub really can fail their
      own counters; verify T017's prove script fails for each injected call.

**Checkpoint**: vocabularies, normalisation, key, budget arithmetic, store, fakes, static gate, config exist.

---

## Phase 3: User Story 1 — Grounded material or an honest decline (P1) 🎯 MVP

### Tests first ⚠️

- [ ] T020 [TDD] [P] [US1] `generator_test.go` `TestGeneratedForEachForm`: fixture corpus (`internal/testcorpus`) +
      scripted provider returning valid items for `explainer`/`flashcards`/`short_prompts`; assert status
      `generated`, item count == requested, every citation ∈ admitted set, quote present, provenance fields complete,
      one provider call. Oracle: scripted claims + fixture pid set.
- [ ] T021 [TDD] [P] [US1] `TestDeclinesBeforeTheProvider`: topic uncovered, below threshold, margin too small,
      insufficient coverage (< `MinDistinctPassages`) ⇒ `declined` with the right reason and **provider counter 0**;
      response body contains no generated text. Oracle: expected reasons computed from fixture scores.
- [ ] T022 [TDD] [P] [US1] `TestUnavailablePaths`: provider `none`, provider `Health` failing, uncalibrated
      thresholds (S-2: `min-score=0` ⇒ `thresholds_uncalibrated`, counter 0), retrieval error, disabled flag. Each ⇒
      the specified code, HTTP 503, **not** a decline. Oracle: `data-model.md` §2.
- [ ] T023 [TDD] [P] [US1] `TestJobLifecycleAndRecovery`: phases `queued→retrieving→generating→verifying→done`
      observable by polling; durable across a simulated restart; a job left `pending` at boot is settled
      `unavailable interrupted` with its reservation released (S-12, kill-9 variant in the gate task T043).

### Implementation

- [ ] T024 [US1] `pkg/materialgen/prompt.go`: versioned templates (`mg-explainer-v1`, `mg-flashcards-v1`,
      `mg-short-prompts-v1`) using `answer.BuildPrompt` budget semantics; untrusted-delimiter structure; strict JSON
      schema block; `TemplateVersion()` feeds the cache key. Golden-prompt test (oracle: committed golden file) so a
      template change is a deliberate, versioned act.
- [ ] T025 [US1] `pkg/materialgen/draft.go`: strict item parsing (`DisallowUnknownFields`), per-form shape limits,
      exact-count rule (F-8…F-11). GREEN the parse/shape rows of T020/T021 and the matrix rows F-8…F-11.
- [ ] T026 [US1] `pkg/materialgen/generator.go`: stages 0–3, 5–10 and 12 of `contracts/generation-pipeline.md`
      (stage 4 cache and stage 11 verification are stubs returning `NotImplemented`, flagged by a test so they cannot
      ship unimplemented). Single `Provider.Generate` call site. GREEN T020–T023.
- [ ] T027 [US1] `internal/api/materials.go` handlers: `GET /api/materials/provider`, `POST /api/materials/preflight`,
      `POST /api/materials`, `GET /api/materials/jobs/{job_id}`, `GET /api/materials`, `GET /api/materials/{id}`,
      `DELETE /api/materials/{id}`; owner-only (S-8, 404 not 403); unknown params/fields ⇒ 400; `Cache-Control: no-store`.
      Contract goldens in `materials_test.go` written first.
- [ ] T028 [US1] [HOOK] `cmd/workshop-server/wire_materialgen.go`: `registerMaterials(mux, deps)`, job worker start/stop,
      boot reconcile; hand the orchestrator the single `// hook:materialgen` line and the compose flag lines
      (default OFF).
- [ ] T029 [P] [TDD] [US1] Frontend `features/materials/`: request page (`/materials/new`: topic, form, count,
      preflight disclosure panel showing provider/locality/token bound, inline confirm — no `window.confirm`),
      job progress with phases, result view with citation chips (`/passage/:pid`), "Show source" quotes, withheld
      reasons, provenance line and "Generated" chip, decline view with reason in plain words and the ingestion
      suggestion, unavailable view with code and reset time. Sanitised markdown only. Karma specs first.
- [ ] T030 [REVIEW] [US1] Independent review of the US1 slice; run quickstart Scenarios 1–3 on the isolated scripted
      server and attach logs.

**Checkpoint (US1 MVP)** — Scenarios 1, 2, 3 pass in scripted mode; verification and cache still stubs (flagged).

---

## Phase 4: User Story 2 — Decline instead of fabricate (P1)

- [ ] T031 [TDD] [US2] `TestFabricationMatrix` (S-1): load `fabrication_matrix.json` (T013), run F-1…F-15 through the
      scripted provider; assert outcome, reason, 0 persisted `material`/`material_cache` rows, 0 generated text in
      declines. RED (verification stubbed).
- [ ] T032 [TDD] [P] [US2] Layer-isolation tests in `verify_test.go`: membership alone, verbatim alone, entailment
      alone (scripted `SupportVerifier`), relevance alone (scripted `QuestionVerifier`); precedence order test
      (first failing layer decides the reason); verifier error ⇒ `unavailable verification_unavailable` (F-14).
- [ ] T033 [US2] `pkg/materialgen/verify.go`: adapters over `grounding.ValidateCitations`, `ValidateVerbatim`,
      `answer.VerifyClaims`/`SupportVerifier`, `answer.QuestionVerifier`; all-or-nothing aggregation; wire into
      generator stage 11. GREEN T031/T032.
- [ ] T034 [TDD] [P] [US2] `TestSuppressedNeverReachesPromptOrMaterial` (S-1/SC-007): canary passage marked
      suppressed — absent from the stub-captured prompt, from the material, from the cache value; a suppression
      landing between generation and delivery ⇒ `declined redacted_evidence` (F-13).
- [ ] T035 [US2] `pkg/materialgen/suppress.go`: drop suppressed pids from the admitted set before the prompt; serve-time
      recheck hook used by the cache. Reuse the platform's suppression index (T005 finding); no second suppression
      mechanism. GREEN T034.
- [ ] T036 [US2] `platform/gates/verify-materialgen-fabrication.sh` (replays F-1…F-15 against an isolated scripted
      server) + `prove-materialgen-verification.sh`: removes each layer in a throwaway copy (skip membership, skip
      verbatim, skip entailment, skip relevance, strip-bad-item, trim-extras, lenient-parse, treat-verifier-error-as-
      pass) and requires the gate/tests to FAIL for each. §1.1 paired proof.
- [ ] T037 [REVIEW] [US2] Independent review; reviewer constructs **two additional fabrication cases not in the
      matrix** and runs them; any that pass through is a finding that extends the matrix (§11.4.118 discovery
      pressure).

**Checkpoint (US2)** — Scenario 4 passes; mutation proofs red-for-the-right-reason.

---

## Phase 5: User Story 3 — Never unasked, bounded cost, fail closed (P1)

- [ ] T038 [TDD] [US3] [OD-5] `TestBudgetBoundaries` / `TestBudgetConcurrency` (S-5): boundary table from T013;
      50 concurrent requests against a budget admitting k ⇒ exactly k admitted and stub count ≤ k; rate limit;
      concurrency cap; refused ⇒ stub count unchanged (B-3); day rollover uses the reservation's UTC day (B-5);
      cache hits not charged (B-6); `unavailable` releases reservation (B-8). Defaults are set only after OD-5.
- [ ] T039 [US3] Store-backed ledger in `store.go`/`budget.go`: `BEGIN IMMEDIATE` reservation, settle, release,
      boot-time release of stale reservations; derived sums (no mutable counter). GREEN T038.
- [ ] T040 [TDD] [US3] `TestNeverUnasked` (S-4, SC-003): start the server wiring with the counting stub, run the
      boot sequence, exercise every other endpoint (ask, search, areas, progress, ingest hooks via the test seam),
      idle with an injected clock for 10 simulated minutes ⇒ stub count 0; plus the static gate (T017) green.
- [ ] T041 [TDD] [US3] `TestFailClosedMatrix` (S-11, SC-010): retriever, verifier, budget store, cache store, audit
      file, provider each individually failing ⇒ the specified `unavailable` code, stub count 0 where the call would
      have been after the failure point, **no partial rows**.
- [ ] T042 [US3] Implement fail-closed mapping for every dependency error in the generator (single error-to-outcome
      table; no `default: allow`). GREEN T040/T041.
- [ ] T043 [TDD] [US3] `TestCrashRecovery` (S-12): run a worker in a child process, `kill -9` mid-generation, reopen;
      job ⇒ `unavailable interrupted`, reservation released, `generation_attempt` visible as crashed, no partial
      material. Child pid handling follows §11.4.263 (validate pgid > 1 before any signal; own process group).
      Also `scripts/verify-materials-budget.sh` (boundary + 50-way concurrency against the counting stub) used by
      Quickstart Scenario 5.
- [ ] T044 [REVIEW] [US3] Independent review of budget/never-unasked/fail-closed; reviewer reruns the mutations of
      `budget-and-cost-guards.md` §3 and the single-call-site `prove-` script.

**Checkpoint (US3)** — Scenarios 4–5 pass.

---

## Phase 6: User Story 4 — Local/LAN/remote providers, egress control and audit (P2)

*Local-provider operation is complete after US3. Tasks marked [BLOCKED] wait for spec 011.*

- [ ] T045 [US4] **Decision record.** Reconcile with 011's open question (011 T009 / audit contract §2): this
      feature requires **fail closed** and a per-attempt record (FR-015). Write the decision into
      `contracts/audit-and-egress.md` and notify 011's owner so one policy governs both paths; if 011 chooses
      differently, the divergence is an explicit, reviewed exception, not drift.
- [ ] T046 [TDD] [US4] [BLOCKED:011-US2] `TestAuditEquality` / `TestAuditHasNoContent` / `TestAuditUnwritableBlocksProvider`
      (A-1…A-3, A-7): non-local stub; lines == provider requests for success/upstream-error/timeout; canary strings in
      topic, passages and output never in the audit file; chmod'd/failing sink ⇒ `audit_unwritable`, stub count 0;
      kill-9 between call and audit ⇒ crashed attempt visible after reboot.
- [ ] T047 [US4] [BLOCKED:011-US2] `pkg/materialgen/audit.go`: `generation_attempt` insert → call → settle → call 011's
      writer (signature per its contract; takes a byte count, never text) → return; open-append precondition check
      before the call. GREEN T046.
- [ ] T048 [TDD] [US4] `TestEgressPreconditions` (A-4…A-6, S-6): remote without allow flag ⇒ `provider_disabled`;
      allow but no/mismatched `remote_ack` ⇒ 400; local provider ⇒ no audit line and the stub peer is loopback;
      non-loopback endpoint declared `local` is refused as `ollama.go:123` does today. LAN variants
      [BLOCKED:011-US3].
- [ ] T049 [US4] Implement preflight disclosure, `remote_ack` comparison against the server's current disclosure, and
      the egress gate (stage 8); `verify-materialgen-egress.sh` + `prove-` pair (remove each precondition in a
      throwaway copy ⇒ FAIL). GREEN T048.
- [ ] T050 [P] [TDD] [US4] Frontend: disclosure panel states in plain language where passages will go, the
      acknowledgement control names the provider and locality shown, a stale page cannot acknowledge a changed
      provider (server mismatch ⇒ message and refetch). Karma + Playwright (scripted remote stub) first.
- [ ] T051 [REVIEW] [US4] Independent review; **hand-off to spec 024** (provider settings screen, audit-log viewer,
      data-residency copy): list the read-only endpoint and fields this feature exposes
      (`/api/materials/provider`) so 024 does not duplicate them.

**Checkpoint (US4)** — Scenario 7 passes where 011 allows; otherwise recorded as BLOCKED with the exact blocker.

---

## Phase 7: User Story 5 — Cache, single-flight, idempotency (P2)

- [ ] T052 [TDD] [US5] `TestCacheAndIdempotency` (C-1…C-9, SC-006): second identical request ⇒ 0 provider calls and
      byte-identical material; generation bump ⇒ miss; 20 concurrent identical ⇒ 1 call/1 row/1 audit line; 20
      retries with one key ⇒ 1 job; same key different body ⇒ 409; declines cached; `unavailable` never cached; cached
      item later suppressed ⇒ withheld; golden key vectors. RED (stage 4 stub).
- [ ] T053 [US5] Implement stage 4 and stage 12 persistence: `INSERT … ON CONFLICT(cache_key) DO NOTHING`, in-process
      single-flight, serve-time re-validation (live pids + suppression), `served_from` labelling; transactional
      `material_cache` + `material` + settlement. If T006 found retrieval non-deterministic, implement decline-TTL
      instead of permanent decline caching.
- [ ] T054 [P] [US5] Frontend: "served from cache" label, regenerate affordance (an explicit new request with the
      same key bypassed only by a learner action and counted in the budget), list page with delete.
- [ ] T055 [REVIEW] [US5] Independent review; reviewer verifies the cache row has no session/topic linkage (S-10).

**Checkpoint (US5)** — Scenario 6 passes.

---

## Phase 8: User Story 6 — Operator review (P3)

- [ ] T056 [TDD] [US6] `TestAdminList` (S-9): admin-only (`403` otherwise), provenance + verification + decline
      reasons + tokens, topic/body omitted unless OD-3 approved, every call writes an access record; learner routes
      never widen for admin.
- [ ] T057 [US6] Handler + frontend `materials-admin.component.ts` (route behind admin guard); filters by outcome and
      reason; token totals vs budget. GREEN T056.
- [ ] T058 [REVIEW] [US6] [BLOCKED] [OD-7] **Promotion into authored curriculum is design-only here.** Write a short
      options note in `research.md` (what `pipeline/extract/author.py` and spec 015 `document` Materials would require;
      independent content review; provenance carry-over) and stop. No implementation until the operator decides OD-7.

---

## Phase 9: Polish and cross-cutting

- [ ] T059 [US1] [POLISH] **Operator-visible acceptance (SC-008).** `workshop/scripts/seed-materials-demo.sh`
      (starts the isolated scripted server or uses the real one when enabled; drives requests through the public API
      with a throwaway learner; password only from `WORKSHOP_TEST_SEED_PASSWORD`) and a one-page walkthrough with
      screenshots of Quickstart Scenarios 1–6 and a pass/fail checklist the operator signs; saved under `evidence/ui/`
      with sha256.
- [ ] T060 [POLISH] [OD-1] **Enablement measurement (FR-022).** `scripts/measure-material-fabrication.sh`: runs the
      real pipeline against the operator-approved unanswerable-topic set and a covered-topic set; writes counts, the
      fabrication rate with its upper 95% bound (rule of three at zero), `malformed_output` rate, usefulness
      (generated rate on covered topics), set hash and harness version to `evidence/fabrication-measurement/`.
      Measurement is the only statement about residual risk; present it to the operator with OD-1/OD-6. If no real
      provider is enabled, record `skipped_operator_gated` (exit 2).
- [ ] T061 [P] [POLISH] Claim-vs-reality ledger rows (§11.4.266): "declines instead of fabricating", "never runs
      unless asked", "remote generation is audited", "private to the learner", "bounded cost" — each with a passing
      challenge command; run the ledger verifier and paste output. Update the capability matrix doc.
- [ ] T062 [POLISH] **LIVE verification (machine evidence, §11.4.262).** `workshop/scripts/verify-materials-live.sh`
      (three-valued) against the running stack (orchestrator-run; build stamp recorded): checks `/api/materials/provider`
      truthfulness against the container's real flags; disabled-by-default behaviour; if enabled with a real provider
      and calibrated thresholds: one covered topic ⇒ `generated` with all citations resolving through
      `/api/passages/{pid}` and quotes verbatim, one uncovered topic ⇒ `declined`, one repeat ⇒ cache, budget
      refusal, and audit/stub reconciliation for non-local; if not enabled or uncalibrated: records the determined
      `unavailable` code and `verdict:"skipped_operator_gated"` with exit 2 — **never PASS**. Writes
      `evidence/live/result.json` (verdict, build_id, source_dirty, provider/model/locality, per-check results,
      tokens, timings) and `MANIFEST.sha256`; `sha256sum -c` must pass.
- [ ] T063 [P] [POLISH] User manual `workshop/docs/features/grounded-material/manual.md` (§11.4.257): what it is and
      is not (corpus-only), forms, outcomes in plain words, provider/locality disclosure, budgets, privacy, limits.
- [ ] T064 [P] [POLISH] Task guides: `guide-create-material.md`, `guide-read-a-decline.md`, `guide-budgets.md`,
      `guide-operator-enable-and-measure.md` (flags, calibration, T060), `guide-operator-audit-and-egress.md`,
      `guide-operator-review.md`.
- [ ] T065 [P] [POLISH] FAQ `faq.md`: "Why did it decline?", "Can it use knowledge outside the library?",
      "Where do my topics go?", "Why is it off?", "What does a remote provider see?", "Why no multiple-choice?",
      each answer cites the FR it rests on.
- [ ] T066 [P] [POLISH] Diagram class 1 — **architecture** (Mermaid, `diagrams.md`): learner → API → worker →
      retriever/gate → provider seam (local/LAN/remote) → verifiers → `materials.db`; audit file; budget ledger.
- [ ] T067 [P] [POLISH] Diagram class 2 — **data flow**: what text travels where (topic, passages, prompt, claims),
      what is persisted, what is never logged, where egress occurs.
- [ ] T068 [P] [POLISH] Diagram class 3 — **state machine**: job/outcome states with the decline/unavailable reason
      groups and the cache short-circuit.
- [ ] T069 [P] [POLISH] Diagram class 4 — **sequence**: a successful remote-provider request including preflight,
      acknowledgement, reservation, attempt row, audit write, verification, persist; plus the audit-unwritable branch.
- [ ] T070 [POLISH] Exports for all new docs via the repository export build (`scripts/build-exports.sh`; verify its
      usage first — UNCONFIRMED arguments): `.html/.pdf/.docx/.sections.json`, mermaid rendered, no raw source.
- [ ] T071 [REVIEW] [POLISH] Independent export validation (§11.4.168): a validator that did not generate them checks
      CONTENT, TEXT and full VISUAL layers (open PDFs; OCR available), verdict saved.
- [ ] T072 [REVIEW] [POLISH] Whole-feature independent review (Opus, xhigh): every FR/SC → evidence; every S-/A-/B-/C-
      scenario run; all mutation proofs re-run; reviewer adds fabrication cases; content-boundary scan of the spec
      directory (no private text); verdict with `finding_layer` per finding.
- [ ] T073 [POLISH] Full-suite retest on a clean baseline (§11.4.40, orchestrator), `verify-claim-ledger`, zero-findings
      sweep if present (UNCONFIRMED existence), TRACKED list of residual findings.
- [ ] T074 [POLISH] Hand-off: `specs/022-on-demand-grounded-material/progress.yml`, pending orchestrator hook lines,
      compose flag lines (default OFF), gitlink bump note (workshop + `helix-deps.yaml` ref in one change), and the
      open operator decisions OD-1…OD-7 with the evidence attached to each.

---

## Dependencies & Execution Order

- Setup → Foundational → US1 → {US2 ‖ US3} → US4 (partly 011-blocked) ‖ US5 → US6 → Polish.
- US2 and US3 depend only on US1's generator skeleton (T026); they touch different files (`verify.go`/`suppress.go`
  vs `budget.go`/`store.go`) and may run in parallel, converging in T041/T042.
- T013 (oracle) before T012/T014/T031; its author ≠ the implementer of T012/T014.
- US4's audit tasks wait on 011 US2 (T007–T014 there); T045 can proceed now. LAN rows wait on 011 US3.
- T062 needs the orchestrator, calibrated thresholds (T008) and an enabled provider for a PASS; otherwise it
  records the honest skip.
- T060 gates any enabling decision; nothing in this spec enables the feature in any deployment.

### Parallel opportunities

T003–T006; T010 ‖ T011 ‖ T013 ‖ T016 ‖ T017; T020–T023; T029 ‖ backend; T032 ‖ T034; T063–T069.

### MVP strategy

1. Setup + Foundational. 2. US1 with the local/scripted provider. 3. US2 and US3 (the feature is not safe to show
without them — treat US1 alone as a demo, never as shippable). 4. Validate Scenarios 1–6. 5. US4/US5/US6 by
priority and by 011's progress.

### Subagent dispatch notes

Independent streams: T013 (oracle), T016 (fakes), T017 (static gate), T020–T023 (four test files), T029 / T050 / T054
(frontend), T063–T069 (docs). Reviewers are always different agents from the producers they review and run on Opus
at xhigh effort, stamped in each verdict. Every producer prompt carries the content-boundary and host-safety
briefing above. Before any commit: mutation-marker grep (§11.4.84), explicit-path staging, and the independent review
verdict (§11.4.142).
