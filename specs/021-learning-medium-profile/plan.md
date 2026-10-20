# Implementation Plan: Learning-Medium Profile and Best-Method Recommendation

**Branch**: `021-learning-medium-profile` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/021-learning-medium-profile/spec.md`

## Summary

A deterministic, model-free, learner-scoped inference layer that reads spec 013's append-only response log,
computes per-question-format performance **relative to what ability and item difficulty predicted**
(observed − expected, using the values 013 stored at answer time), classifies each format into a closed set of
honest states (`insufficient_evidence` … `preferred`), and exposes it as a read-only profile page, an
explainable per-area recommendation, a learner override (auto / pinned / off), and a reset. An optional,
consent-gated engagement capture (US4) covers content formats. Server-side question routing (US5) is recorded
and blocked. The work splits cleanly into a **pure algorithm that is buildable and fully testable today**
(against fixtures and an independent Python oracle) and an **integration slice that is blocked on spec 013**.

## Technical Context

**Language/Version**: Go 1.26 (`platform/backend`), TypeScript/Angular standalone components
(`platform/frontend`), Python 3.14 (reference oracle only; `pipeline/`).
**Primary Dependencies**: standard library + existing workshop packages (`pkg/assessment` for `Kind`,
`pkg/scoring` from spec 013 for `D` and the log, `internal/api` conventions). **No new third-party dependency**
(charts are hand-rolled SVG, as spec 015 FR-017 requires).
**Storage**: derived data is never stored. A small separate SQLite file `medium.db` (authstore idiom) holds
preference, consent, engagement events. Survives re-ingest.
**Testing**: `go test`; Karma/Jasmine; Playwright (`platform/frontend/e2e/medium.spec.ts`); `pytest` for the
oracle; gates `platform/gates/verify-medium-*.sh` with `prove-medium-*.sh` paired mutations.
**Target Platform**: existing container `workshop-curriculum_platform_1`; verified on an isolated throwaway
server per stream, and on the live stack only by the orchestrator after merge.
**Project Type**: web service + SPA inside the private `workshop` submodule (gitlink bump in the umbrella).
**Performance Goals**: O(n) in one learner's newest ≤ 5000 rows; target p95 < 50 ms on the live host for the
default cap (to be measured in T052, not assumed).
**Constraints**: determinism (FR-008); no model/network in `pkg/medium` (SC-006); session isolation (P-1/P-2);
new code only in new files (hooks, below); no edits to `main.go`, `app.routes.ts`, `core/vocabulary.ts`.
**Scale/Scope**: ~12 Go files (+tests), ~8 Angular files (+specs), 1 Python oracle, 4 gate scripts, docs.

## Constitution Check

| Principle / anchor | Status | Notes |
|---|---|---|
| Evidence-Based Claims (§11.4, §11.4.6) | PASS | Every claim in spec/research carries a path:line or is marked UNCONFIRMED/HYPOTHESIS with a closing task. |
| Test-first, named oracle (§11.4.224, §11.4.245) | PASS (by task structure) | Each algorithmic/privacy task has a RED task with the oracle named in `contracts/`. Coverage floor ≥ 85% measured with `go test -cover`; never cited as proof of correctness. |
| Producer ≠ oracle ≠ gate ≠ verifier (§11.4.249, §11.4.240) | PASS | Python oracle (T012) authored by a different agent than the Go implementer; reviewers are separate agents; recorded in the task log. |
| Independent review, Opus/xhigh (§11.4.142, §11.4.209) | PASS | `[REVIEW]` tasks at each checkpoint plus whole-feature review T062. |
| Critical-invariant DoD (§11.4.239) | PASS | `contracts/privacy-and-failure-scenarios.md` precedes code; T008 gates it. |
| Fail-closed on dangerous combination (§11.4.252) | PASS | Event capture = untrusted input + persistence: consent-gated, closed shape, size/rate bounded. |
| Idempotency under retry (§11.4.253) | PASS | `UNIQUE(session, idem_key)` with concurrent-replay test P-7. |
| Boot-time invariants, capability matrix (§11.4.254) | PASS | Threshold validation refuses to start (P-12); matrix row in the privacy contract. |
| Reproduce before repairing | N/A | New capability, not a fix. |
| Source Is Not Served / A Restart Runs What Was Built | PASS | R-4/T006 checks the served bundle, not source; live verification records the build stamp. |
| A Screen's Precision Is Not Its Recall / two-sided check | PASS | SC-009 measures both false-preference rate and power. |
| Machine-created evidence (§11.4.262) | PASS | T052 writes `result.json` + sha256 manifest; simulation writes JSON. |
| Claim-vs-reality ledger (§11.4.266) | PASS (task) | T051 adds a row per advertised capability with a passing challenge. |
| Docs: manual/guide/FAQ + four diagram classes (§11.4.257, §11.4.258) | PASS (tasks) | T053–T059; exports validated independently (§11.4.168) in T060–T061. |
| Content boundary | PASS | No private chapter/transcript text anywhere in this spec; research paths cited, not quoted. |
| No CI/CD (§11.4.156); no force push (§11.4.113) | PASS | Local gates only; streams never push. |

## Project Structure

### Documentation (this feature)

```text
specs/021-learning-medium-profile/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md  tasks.md
├── contracts/
│   ├── medium-signal-algorithm.md
│   ├── medium-endpoints.md
│   ├── response-source-interface.md
│   └── privacy-and-failure-scenarios.md
├── checklists/requirements.md
└── evidence/            # created by tasks: setup-baseline.json, simulation/, live/ (result.json + MANIFEST.sha256)
```

### Source code (real paths; everything new unless stated)

```text
workshop/platform/backend/
├── pkg/medium/                      medium.go config.go vocab.go source.go evidence.go signal.go
│                                    explain.go recommend.go store.go (+ *_test.go, sim_test.go, testdata/medium/)
├── pkg/scoring/read_responses.go    NEW FILE in spec 013's package, requested from 013's owner (T028)
├── internal/api/medium.go           handlers (+ medium_test.go)
├── cmd/workshop-server/wire_medium.go   registerMedium(mux, deps), addMediumFlags(fs, *config), scoringSource adapter
├── gates/verify-medium-no-model.sh  prove-medium-no-model.sh  verify-medium-isolation.sh  prove-medium-isolation.sh
workshop/platform/frontend/src/app/features/medium/
│   medium.routes.ts  medium-profile.component.ts  medium-recommendation.component.ts
│   medium-hint.component.ts  medium.service.ts  medium.vocabulary.ts  (+ *.spec.ts)
workshop/platform/frontend/e2e/medium.spec.ts
workshop/pipeline/medium_reference.py  + pipeline/tests/test_medium_reference.py     (oracle)
workshop/scripts/seed-medium-demo.sh   scripts/verify-medium-live.sh
workshop/docs/features/learning-medium/{manual.md,guide-*.md,faq.md,diagrams.md}     (+ exports)
```

**Hook points (single-writer rule, architecture plan §2.2).** The orchestrator owns exactly these one-line hooks;
streams never edit the host file: `main.go` → `// hook:medium` (flags + `registerMedium`);
`app.routes.ts` → one append line loading `features/medium/medium.routes.ts`; `core/vocabulary.ts` → one
registration line for `medium.vocabulary.ts`; `platform/gates` registry TSV rows. Two minimal edits in existing
feature components (area page hint slot; practice selector) are declared `[HOOK]` tasks (≤ 10 lines each).

## Execution Strategy

### TDD Requirements (strict RED → GREEN → REFACTOR)

1. Signal algorithm and aggregation (T016–T024) — oracle: data-model §3 + independent Python reference.
2. Every privacy scenario P-1 … P-13 — oracle named per row in the privacy contract; each with a paired mutation.
3. Store constraints and idempotency (T035, T046) — oracle: SQL row counts.
4. Handler contracts (T029, T039) — oracle: contract JSON golden files.
5. Frontend: component specs written before components; Playwright spec RED before wiring.

### Parallel Execution Opportunities

- Phase 1 research tasks T003–T006 are independent. T012 (oracle) and T013 (static gate) run in parallel with
  T009–T011 (different files).
- US1a tests T016–T021 are mutually independent (different test files); implementation T022–T024 sequential.
- The simulator T026 runs in parallel with T022–T025 once the classify function signature is frozen.
- Frontend T032/T041 can start against `contracts/medium-endpoints.md` goldens before the backend handlers land.
- US4 (T046–T048) is independent of US3 after US2's store exists.

### Human / Operator Checkpoints

1. After T027 (measured simulation): OD-1 — accept or retune thresholds.
2. Before T046: OD-3 — ship engagement capture at all?
3. Before any client-facing use: OD-4 (retention/legal) and OD-5 (instructor view; needs client identity).
4. T049: the operator opens the UI and signs the acceptance checklist.

### Review Gates (independent reviewer, Opus at xhigh effort, verdict file with `finding_layer`)

Phase 2 (T015), pure algorithm (T025), integration slice (T034), US2 (T042), US3 (T045), whole feature (T062).

## Dependencies and sequencing against other specs

- **Spec 013** (blocking for integration): needs US1's response log, a session-scoped read seam
  (`ResponsesForSession`), and grading provenance (`GradedBy`). Tasks T028–T034 and the live scenarios are
  BLOCKED until 013's US1 checkpoint (T025 in 013's tasks). If 013 changes shape, only `scoringSource` (one
  file) changes — that is why the interface is owned here (`contracts/response-source-interface.md`).
- **Spec 015**: convention-only dependency; the `/profile` page remains 015's. This feature links to
  `/profile/medium` from 015's page via the orchestrator-owned link hook once 015's page exists; the route works
  without it.
- **Spec 011**: none.
- **Wave order** (architecture plan §3 DAG): after the Wave-0 hook split and 013 US1; parallel with 014 and 016
  streams (disjoint files) — the shared practice path is the one semantic-conflict risk (T044).
- **Stub 023 / client identity**: no dependency; any instructor/consultant view waits for it.

## Complexity Tracking

| Choice | Why not simpler |
|---|---|
| Separate `medium.db` instead of reusing `scoring.db` | Different lifecycle and a privacy-driven reset boundary (DELETE must be complete and scoped) while 013's log is append-only; sharing a file would couple erasure to an immutable store. |
| Python oracle in addition to Go tests | Constitution §11.4.245/§11.4.249: a test whose expected values come from the code under test is a bluff; the reference is an independent implementation. |
| Simulation task (T026–T027) | Thresholds are the product; shipping them untested would be the "default-allow" failure in statistical form. |
| Consent-gated US4 inside this spec | The content-format half of REQ-1 is meaningless without engagement data; isolating it as P3 with default OFF keeps the P1 path free of new personal data. |
