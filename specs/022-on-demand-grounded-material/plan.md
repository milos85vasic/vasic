# Implementation Plan: On-Demand Grounded Material Generation

**Branch**: `022-on-demand-grounded-material` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/022-on-demand-grounded-material/spec.md`

## Summary

A learner-initiated, corpus-only generation service: request → admit (validate, cache, budget) → retrieve and gate
→ one provider call through spec 011's `answer.Provider` seam → strict parse → four-layer verification → atomic
persist → cited, quoted, provenance-labelled draft **or** an honest decline **or** a determined "unavailable".
Everything except the model call is deterministic and unit-tested against a scripted fake provider. Cost and egress
are bounded by pre-flight budgets, an explicit per-request acknowledgement for non-local providers, a
fail-closed audit record per remote attempt, and a hard rule that nothing ever runs unasked. The feature ships
**default OFF** behind a measured-fabrication enablement bar.

## Technical Context

**Language/Version**: Go 1.26 (`platform/backend`); TypeScript/Angular standalone (`platform/frontend`); Python
(independent oracle only).
**Primary Dependencies**: existing only — `pkg/answer` (Provider, BuildPrompt, VerifyClaims), `pkg/entail`,
`submodules/RAG/pkg/grounding`, `pkg/search`/retriever as wired by `internal/answering`, `pkg/authstore` roles,
`modernc`/SQLite driver already used by `authstore`. **No new third-party dependency.**
**Storage**: `materials.db` (new, separate; survives re-ingest) + the external append-only audit file defined by
spec 011.
**Testing**: `go test` with a scripted fake provider and an `httptest` stub that counts requests and captures
bodies; Karma; Playwright; `pytest` for the oracle; gates with paired mutations; a live script writing machine
evidence.
**Target Platform**: container `workshop-curriculum_platform_1`; streams verify on an isolated throwaway server,
the orchestrator deploys.
**Project Type**: web service + SPA in the private `workshop` submodule.
**Performance Goals**: not a throughput feature. Generation latency is dominated by the model (answering measured
11.7–67.1 s on this host per the `-answer-timeout` comment, `main.go:543`); cache hits and declines before the
provider must be fast (target < 100 ms server time, measured in T062, not promised).
**Constraints**: corpus-only grounding; fail closed; no background generation; no new provider-specific code; new
code in new files with hook lines owned by the orchestrator; content boundary (no private chapter text in any spec).
**Scale/Scope**: ~14 Go files (+tests), ~10 Angular files, 1 Python oracle, 2–3 gates, docs.

## Constitution Check

| Principle / anchor | Status | Notes |
|---|---|---|
| Evidence-based claims; no guessing (§11.4.6) | PASS | Facts carry path:line; unknowns are UNCONFIRMED with owning task (T003–T008). |
| Test-first with named oracle (§11.4.224/245) | PASS | Fabrication matrix, budget table, cache vectors come from an independent oracle (T013). |
| Producer ≠ oracle ≠ gate ≠ verifier (§11.4.249/240) | PASS | T013 authored by a different agent; reviewers distinct. |
| Independent review, Opus xhigh (§11.4.142/209) | PASS | Review task per story and for the whole feature (T072). |
| Critical-invariant DoD (§11.4.239) | PASS | `contracts/failure-scenarios-and-fabrication-matrix.md` precedes code; T009 reviews it. |
| Fail-closed on dangerous combination (§11.4.252) | PASS | mutation + untrusted input + egress/credentials: every ambiguity refuses; audit-before-return. |
| Idempotency under retry (§11.4.253) | PASS | UNIQUE(cache_key), UNIQUE(session, idem_key), reservation rows; concurrency tests. |
| Boot invariants + capability matrix (§11.4.254) | PASS | Boot validation tests (S-14); matrix in the failure contract. |
| Machine-created evidence (§11.4.262) | PASS | Matrix JSON, live `result.json` + sha256 manifest, fabrication measurement file. |
| Claim-vs-reality ledger (§11.4.266) | PASS (task T061) | "never fabricates", "never runs unasked", "audited" each need a passing challenge. |
| Docs + four diagram classes (§11.4.257/258/168) | PASS (tasks) | T063–T071. |
| Honest instruments | PASS | Three-state outcome; uncalibrated gate ⇒ unavailable, never "declined"; entailment-judge limits stated. |
| A Screen's Precision Is Not Its Recall | PASS | FR-022 requires a recall-style bound (fabrication upper bound) rather than a pass/fail claim. |
| Source Is Not Served / A Restart Runs What Was Built | PASS | Live verification records the build stamp; flags are visible in `/api/materials/provider`. |
| Content boundary | PASS | No private chapter/transcript text; the Jordan document is cited by path and requirement id only. |
| No CI/CD; no force push (§11.4.156/113) | PASS | Local gates; streams never push. |

## Project Structure

### Documentation (this feature)

```text
specs/022-on-demand-grounded-material/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md  tasks.md
├── contracts/
│   ├── generation-pipeline.md
│   ├── budget-and-cost-guards.md
│   ├── audit-and-egress.md
│   ├── cache-and-idempotency.md
│   ├── materials-endpoints.md
│   └── failure-scenarios-and-fabrication-matrix.md
├── checklists/requirements.md
└── evidence/   # baseline, fabrication-measurement/, ui/, live/ (result.json + MANIFEST.sha256)
```

### Source code (real paths; all new)

```text
workshop/platform/backend/
├── pkg/materialgen/                 outcome.go request.go config.go cachekey.go budget.go store.go prompt.go
│                                    draft.go generator.go verify.go audit.go suppress.go
│                                    mgtest/ (scripted fake provider, counting HTTP stub — reused by gates)
│                                    testdata/materialgen/{fabrication_matrix.json,cache_key_vectors.json,budget_table.json}
├── internal/api/materials.go        handlers (+ materials_test.go)
├── cmd/workshop-server/wire_materialgen.go   registerMaterials, addMaterialFlags, worker start, boot reconcile
├── gates/verify-materialgen-single-callsite.sh  prove-…  verify-materialgen-egress.sh  prove-…
workshop/platform/frontend/src/app/features/materials/
│   materials.routes.ts materials-new.component.ts materials-list.component.ts material-view.component.ts
│   materials-admin.component.ts materials.service.ts materials.vocabulary.ts (+ *.spec.ts)
workshop/platform/frontend/e2e/materials.spec.ts
workshop/pipeline/materialgen_oracle.py + pipeline/tests/test_materialgen_oracle.py
workshop/scripts/seed-materials-demo.sh  scripts/verify-materials-live.sh  scripts/measure-material-fabrication.sh
workshop/docs/features/grounded-material/{manual.md,guide-*.md,faq.md,diagrams.md} (+ exports)
```

**Hook points (single-writer rule):** `main.go` `// hook:materialgen` (flags + `registerMaterials` + worker
start/stop); `app.routes.ts` one append line (lazy `features/materials/materials.routes.ts`); `core/vocabulary.ts` one
registration line; gate-registry TSV rows. Nothing else in shared files is edited. `compose.yml` flag additions
(default OFF) are orchestrator-owned.

## Execution Strategy

### TDD Requirements (strict RED → GREEN → REFACTOR)

1. Outcome vocabularies and disjointness; request normalisation; cache-key vectors; budget arithmetic.
2. Fabrication matrix F-1…F-15 and every layer's removal mutation.
3. Never-unasked, budget concurrency, fail-closed matrix, crash recovery.
4. Audit equality / no-content / egress preconditions (non-local stub).
5. Cache hit/miss/single-flight/idempotency; owner-only access; admin logging.
6. Frontend: component specs before components; Playwright before wiring.

### Parallel Execution Opportunities

- Setup research T003–T006 parallel; T013 (oracle) ‖ T010–T012 ‖ T016 (fake provider) ‖ T017 (static gate).
- US1 test tasks T020–T023 independent files; verification (US2) and budgets (US3) are independent of each other
  after US1's generator skeleton (T025) exists.
- Frontend T029/T050 start against endpoint goldens; docs T063–T069 parallel once behaviour is stable.

### Human / Operator Checkpoints

1. OD-2 (REQ-3 reading) — before US1 UI wording is frozen.
2. OD-5 (budget numbers) — before T038 fixes defaults.
3. OD-1/OD-6 — after T060's measurement, before enabling anywhere.
4. T059 — operator signs the UI acceptance checklist.

### Review Gates (independent, Opus at xhigh, verdict with `finding_layer`)

Foundational (T019), US1 (T030), US2 (T037), US3 (T044), US4 (T051), US5 (T055), US6 (T058 design), whole feature
(T072).

## Dependencies and sequencing against other specs

- **Spec 011 US2 (audit writer)** — required by US4 remote/LAN path; until built, US4 tasks are `[BLOCKED:011-US2]`;
  everything else proceeds with the local provider.
- **Spec 011 US3 (`lan` locality)** — required only for LAN rows.
- **Spec 011 US1** — done (catalogue rows).
- **Calibration** — T008 determines whether calibrated thresholds exist; without them the pipeline is
  correct-by-refusal (`thresholds_uncalibrated`) and live generation cannot be demonstrated (T062 records
  `skipped_operator_gated`, exit 2).
- **Spec 024** — provider settings screen / audit viewer; coordinate through T051; no code dependency.
- **Specs 012/017/019/020** — more sources raise coverage; none required.
- **Specs 013/015/021** — none; 021's recommended medium could later pick a default form (not specified).
- **Wave placement** (architecture DAG): independent of 012–016; touches `main.go` only through its hook; schedule
  after the Wave-0 hook split; can run in parallel with 013/014/016 streams.

## Complexity Tracking

| Choice | Why not simpler |
|---|---|
| Separate package `pkg/materialgen` instead of extending `answer.Pipeline` | `answer.Pipeline.Ask` is a one-answer, in-memory, synchronous design; editing it would risk the shipped answering path; reuse is by calling its building blocks. |
| Durable job + attempt + reservation rows | Crash safety and auditability (S-12, A-7) cannot be had from memory. |
| All-or-nothing verification | Silent stripping would turn verification into presentation polish (the pattern `ReasonNoCitations` already forbids for answers). |
| Independent Python oracle | Budget math, key canonicalisation and the matrix are exactly where a self-agreeing test would hide a bug. |
| Default OFF + measured bar | The measured answering fabrication rate is nonzero; generation is a wider surface. |
