# Tasks: Answering Enablement + Provider Status UI (measured, two-sided gate)

**Input**: Design documents from `specs/024-answering-enablement-and-provider-ui/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md` (all present)

**Tests**: INCLUDED and test-first (§11.4.224). Every implementation task has a preceding task that
writes the failing test, names its ORACLE (§11.4.245) and records the RED run. The implementer of a
task is never the author of its acceptance test or its reviewer (§11.4.240/§11.4.249): test-authoring
and implementation are separate `[SUBAGENT]` dispatches.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]** parallel-safe (different files, no same-phase dependency) - **[TDD]** RED then GREEN then
  refactor, RED run pasted - **[REVIEW]** independent review (Opus, effort xhigh, §11.4.142/§11.4.209)
  with a verdict file carrying `finding_layer` (§11.4.235(D)) before the next dependent task
- **[SUBAGENT]** safe to delegate - **[Story]** `US1`..`US5`, `FOUND`, `SETUP`, `POLISH`

## Path conventions (all inside the private `workshop` submodule unless stated)

- Backend root: `workshop/platform/backend/` (`pkg/answer`, `internal/answering`, `cmd/workshop-server`, `gates/answer-eval`, `testdata/benchmark`, `evidence/answering`)
- Frontend root: `workshop/platform/frontend/src/app/` (`core`, `features/settings` NEW, `features/inquiry`), e2e in `workshop/platform/frontend/e2e/`
- Scripts: `workshop/scripts/`; docs: `workshop/docs/`; machine evidence: `workshop/evidence/024-answering-enablement/`
- **Architecture rules**: new code in NEW files; do NOT edit `cmd/workshop-server/main.go`, `app/app.routes.ts`, `core/vocabulary.ts` directly - each stream ships a `wire_answering_*.go` / `settings.routes.ts` / `settings-vocabulary.ts` plus ONE hook line that the orchestrator lands (plan "Shared-file protocol"). Worktree streams NEVER run `restart.sh`/`start.sh`/`stop.sh`/`ingest.sh` against the live stack.
- **Content boundary**: nothing from `workshop/` (benchmark questions, passages, answers) is copied into this public repo; evidence files stay under `workshop/`.

---

## Phase 1: Setup (preconditions, no feature code)

- [ ] T001 [SETUP] Record the pre-feature baseline: `cd workshop/platform/backend && go build ./... && go vet ./... && go test ./pkg/answer/... ./internal/answering/... ./cmd/workshop-server/... -count=1` (wrap with `scripts/agent-admit.sh`/`bounded-run`, `GOMAXPROCS=4 go test -p 2`). Paste the real pass/fail counts into `workshop/evidence/024-answering-enablement/baseline/go-baseline.txt`. Any pre-existing failure is listed by name, not fixed here.
- [ ] T002 [P] [SETUP] Read-only live confirmation (no restart, no write): unauthenticated `GET /api/health` (build id, `source_dirty`), and authenticated `GET /api/ask/status` + `GET /api/index/status` via `scripts/_live_auth.sh`; confirm `enabled:false`, `provider:"none"`, and record the index generation + root hash. Write `workshop/evidence/024-answering-enablement/baseline/live-readonly.json` with sha256. If the live state differs from spec.md's baseline table, STOP and correct spec.md first.
- [ ] T003 [P] [SETUP] Host headroom and scratch-server feasibility (§12.6/§12.12): `ulimit -u`, live thread count, `free -m`; start ONE scratch server per `gates/answer-eval/README.md` with `--answer-provider extractive` on a free port against an index COPY; confirm `/api/ask/status` `enabled:true`; stop it. Record the command (flags only) and result in `baseline/scratch-smoke.txt`. This proves the isolated-launch mechanism that every later task relies on (architecture §6 lists it UNCONFIRMED).
- [ ] T004 [P] [SETUP] Confirm the harness classifies outcomes the way FR-008 needs: read `gates/answer-eval/runbench.py` + `cmp.py` and write `baseline/outcome-classification.md` stating, with line citations, how `answered`/`declined`/`unavailable` map to recall and fabrication, and how HTTP-503 bodies are recorded. Any gap against FR-008 becomes task T044.
- [ ] T005 [P] [SETUP] Role plumbing (settles an UNCONFIRMED): find how a handler obtains the caller's role (`pkg/authhttp/authhttp.go`, `pkg/authstore/authstore.go:47`) and whether the frontend `AuthService` (`core/auth.ts`) exposes it. Write `baseline/role-plumbing.md` with file:line citations; if the frontend lacks it, record the fallback (API-only enforcement, UI renders what the API returned) as the plan.
- [ ] T006 [SETUP] Confirm the shared-file hook mechanism: check whether `cmd/workshop-server/wire_*.go` hook split (architecture Wave 0) has landed (`ls cmd/workshop-server | grep wire_`; at HEAD `33e9760` only characterization evidence is committed). If not landed, this feature's backend wiring is delivered as `wire_answering_overview.go` + `answering_gate.go` and the orchestrator adds the two call sites; record the exact two lines to add in `baseline/hook-lines.md`.

**Checkpoint**: environment and mechanisms confirmed; no feature code written.

---

## Phase 2: Foundational (blocks every story)

**Purpose**: the pieces US1 (displays verdicts), US2 (produces/consumes them) and US3 (needs a
trustworthy before/after) all depend on.

- [x] T007 [TDD] [SUBAGENT] [FOUND] RED: write `pkg/answer/verdict/wilson_test.go`. **Oracle**: published/recorded reference values, independent of the code under test - 0 of 87 at 95% -> upper 0.0423 (closed form `z^2/(n+z^2)` for k=0), and the MEASUREMENT file's own `14/72 -> 12%-30%` and `4/87 -> 2%-11%` (rounded). Also property cases: bounds in [0,1], low<=p<=high, monotone in k, n=0 -> error not NaN. Run, confirm FAIL (package missing), paste the RED log. *(S14 evidence: Wilson tests (closed form 0/87, recorded 14/72 & 4/87))*
- [x] T008 [FOUND] GREEN: implement `pkg/answer/verdict/wilson.go` (`Wilson(k, n int, z float64) (lo, hi float64, err error)`). Minimal code to pass T007; run, paste GREEN. *(S14 evidence: wilson.go)*
- [x] T009 [TDD] [SUBAGENT] [FOUND] RED: `pkg/answer/verdict/fingerprint_test.go`. **Oracle**: a committed golden file `testdata/fingerprint-golden.json` containing three inputs and their SHA-256 digests computed by an independent implementation (Python `hashlib` over `json.dumps(sort_keys=True, separators=(',',':'))`, produced by the test author, not by the Go implementer); plus property tests (key order/whitespace never changes the digest; every single-input change always does - table over all 16 inputs). *(S14 evidence: golden fingerprint (python-computed) + property tests)*
- [x] T010 [FOUND] GREEN: `pkg/answer/verdict/fingerprint.go` (`ConfigFingerprint`, `Canonical()`, `Digest()`), per `contracts/answering-verdict.md` "Fingerprint canonicalisation". *(S14 evidence: fingerprint.go)*
- [x] T011 [TDD] [SUBAGENT] [FOUND] RED: `pkg/answer/verdict/verdict_test.go` covering the loader's fail-closed rules from `contracts/answering-verdict.md` "Validation": **Oracle**: spec contract text + hand-written fixtures under `pkg/answer/verdict/testdata/` (valid pass, valid fail, 10 invalid variants: truncated, wrong schema, tampered count, tampered bound, tampered result, fingerprint mismatch, raw-runs hash mismatch, manifest mismatch, extra unknown field, non-UTF-8). Assert `Load` returns status `pass`/`fail` only for the two valid fixtures and `invalid` for all others, never panics, never returns `pass` on error (§11.4.252). *(S14 evidence: 12 python-generated invalid fixtures, each rejected for its own reason)*
- [x] T012 [FOUND] GREEN: `pkg/answer/verdict/verdict.go` (types, `Load(dir, running ConfigFingerprint) (Status, *Verdict, error)`, `Status` = none|pass|fail|stale|invalid). *(S14 evidence: verdict.go Load/Inspect/Validate)*
- [ ] T013 [P] [FOUND] [SUBAGENT] Decision rule as code-independent data: write `gates/answer-eval/gate_verdict.py` skeleton + `test_gate_verdict.py` RED. **Oracle**: the "Decision rule" section of `contracts/answering-verdict.md` encoded as 8 table cases (the four SC-004 shapes x trial-minimum met/unmet). The Python producer and the Go loader recompute the same rule independently; a cross-check test (T051) feeds Python-produced verdicts to the Go loader.
- [x] T014 [P] [FOUND] Thresholds file schema + loader: `testdata/benchmark/gate-thresholds.json` is created ONLY after operator decision D1; until then this task creates `testdata/benchmark/gate-thresholds.schema.json` and a loader test asserting that a missing/null numeric field is rejected (rc 2 in the tool, error in Go) - no numeric default that passes exists in code (FR-008). *(S14 evidence: thresholds schema + ParseThresholds rejects missing/null (incl. tolerance); CLI rc 2)*
- [ ] T015 [FOUND] Benchmark v2 construction plan task (data work, no code): a labeller agent that is NOT the pipeline builder (distinct agent id recorded) reads `testdata/benchmark/questions.tsv` + `evidence/answering/benchmark-audit-generation-15-2026-09-24.tsv` and writes `testdata/benchmark/questions-v2.audit.tsv` (every drop/relabel with reason) and `questions-v2.tsv` (id, class, question, expected_pids, tier, labeller, label_basis) with at least the trial counts D1 requires (>= `min_*_trials` after repeats). Unanswerable labels are proven by search evidence stored next to the file (the term/phrase search shows absence), answerable labels by the deciding passage id. Never edit the v1 files. Content stays private.
- [ ] T016 [FOUND] [REVIEW] Independent review (Opus xhigh) of T007-T015: decision rule parity Python vs Go, fail-closed loader, benchmark v2 independence and contamination check (no question text indexed verbatim - run the same contamination probe the v1 audit used). Verdict file `evidence/024-answering-enablement/reviews/foundation-review.json`. GO required.

**Checkpoint**: verdict maths, fingerprint, loader and benchmark v2 exist and are reviewed. No UI, no boot change yet.

---

## Phase 3: User Story 1 - Operator can SEE the answering state and the provider (Priority: P1) MVP

**Goal**: read-only `/settings/providers` + `/ask` off banner + `GET /api/answering/overview`.
**Independent Test**: spec.md US1 independent test, on the live stack's current OFF state.

### Tests first

- [x] T017 [TDD] [SUBAGENT] [US1] RED: `internal/answering/overview_test.go`. **Oracle**: `answer.Registrations()` as the independent source for the provider list (compare names), the closed state vocabulary from `data-model.md` (table of 8 derivation cases incl. the order "none beats everything"), and `/api/ask/status` field values from an `httptest` handler built with the REAL `answer.Handler` (not a mock of it) so overview and status cannot drift. Cases: none, extractive on, ollama on healthy, ollama unhealthy, suspended, forced-off, hosted without remote opt-in, stub row `openai_compatible` -> `selectable=false`. *(S14 evidence: overview_test.go (9 state cases + drift vs real handler))*
- [x] T018 [P] [TDD] [SUBAGENT] [US1] RED: `internal/answering/overview_redaction_test.go` (SC-008). **Oracle**: a regex set written by the test author (not from the implementation): `(?i)bearer\s`, `sk-[A-Za-z0-9]{8,}`, any value of an env var set by the test to a canary string `CANARY-NEVER-LEAK-<uuid>`, any key named prompt/passage/answer/text. Serialise overview for every state with canary credentials in the environment; assert zero matches. Also assert the response struct type has no string field named like content (reflect walk). *(S14 evidence: overview_redaction_test.go)*
- [x] T019 [P] [TDD] [SUBAGENT] [US1] RED: `internal/answering/overview_http_test.go`: 200 with answering off; 401 without token; `audit` null for role `user`, present (or `available:false`) for `admin`; `Cache-Control: no-store`; handler fault -> 500 with the documented body and **search handler still 200** in the same mux (FR-016). *(S14 evidence: overview_http_test.go)*
- [x] T020 [P] [TDD] [SUBAGENT] [US1] RED: vocabulary parity test `internal/answering/overview_vocab_test.go` comparing the Go state constants with the TypeScript union in `core/answering-models.ts` by parsing the TS file (pattern: the existing `prove-ui-vocabulary-mutation.sh`/`question_verify_vocabulary_test.go` approach). *(S14 evidence: overview_vocab_test.go)*
- [x] T021 [P] [TDD] [SUBAGENT] [US1] RED: frontend unit specs (Karma) `features/settings/providers-page.component.spec.ts`, `provider-table.component.spec.ts`, `locality-badge.component.spec.ts`, `gate-verdict-card.component.spec.ts`, `audit-summary.component.spec.ts`. **Oracle**: the overview JSON fixtures (shared with Go, copied from the Go golden files so both sides read the same bytes) and the WCAG rules in `spec.md` FR-015 (text + icon not colour only; `role="status"` polite region only on state change; table has caption and `scope` headers; no `title`-only information). Each component renders every state; absent states (`audit.available=false`, `gate.verdict_status=none`) render an explicit message, never an empty element. *(S14 evidence: Karma 59/59 (fixtures pinned to Go output))*
- [x] T022 [P] [TDD] [SUBAGENT] [US1] RED: Playwright spec `e2e/settings-providers.spec.ts` (desktop-chromium + mobile-chromium, axe via `@axe-core/playwright`): login, open `/settings/providers`, assert state card text, table rows, no console errors, no axe violations of impact serious/critical, tab order, and that the page contains NO button or form control that changes provider/enable (FR-011 negative check). Second case: `/ask` with answering off shows the banner with a link to the page and the search tab still returns results. Runs against a RUNNING stack only (`WORKSHOP_BASE_URL`); for worktree streams that is the scratch server (T003). *(S14 evidence: playwright 22 passed (fixture + real scratch backend))*

### Implementation

- [x] T023 [US1] GREEN: `internal/answering/overview.go` - pure builder `BuildOverview(in OverviewInputs) AnsweringOverview` (no I/O inside; inputs are descriptor, health reason, thresholds, suspension, verdict status, registrations, credential-presence snapshot, optional audit reader). State derivation per `data-model.md`. Credential presence via the same `apikeys` snapshot the registry uses, booleans only. *(S14 evidence: overview.go)*
- [x] T024 [US1] GREEN: `internal/answering/overview_http.go` - handler + role split, `no-store`, error body; `cmd/workshop-server/wire_answering_overview.go` - `registerAnsweringOverview(mux, deps)`; add the single call-site line via the orchestrator hook (record in `evidence/024-answering-enablement/hook-lines.md`). *(S14 evidence: overview_http.go + wire_answering.go (hook lines in evidence/s14/hook-lines.md))*
- [x] T025 [P] [US1] `core/answering-models.ts` (typed `AnsweringOverview`, `AnsweringState` union, normaliser that returns `unavailable('malformed_response')` for a bad body, same pattern as `normaliseAskCapability`) and `core/answering-api.ts` (a small injectable service `AnsweringApi.overview()` using `HttpClient`, `LoadStatus` mapping as in `core/api.ts`; does NOT edit `core/api.ts`). *(S14 evidence: answering-models.ts/answering-api.ts)*
- [x] T026 [P] [US1] `features/settings/settings-vocabulary.ts`: user-facing sentences for the five states, the five verdict statuses and the locality classes, keyed by code. The orchestrator merges these into `core/vocabulary.ts` at integration (hook), same-name keys guarded by the vocabulary gate `prove-ui-vocabulary-mutation.sh`. *(S14 evidence: settings-vocabulary.ts)*
- [x] T027 [US1] `features/settings/providers-page.component.ts` (standalone, OnPush, signals) + `provider-table.component.ts` + `locality-badge.component.ts` + `gate-verdict-card.component.ts` + `audit-summary.component.ts`. Honest states via the existing `app-state`/`UnavailableComponent`. No mutation controls. Phone-width layout: table in its own `overflow-x:auto` container, 16px gutters. *(S14 evidence: settings components)*
- [x] T028 [US1] `features/settings/settings.routes.ts` exporting `SETTINGS_ROUTES = [{ path: 'settings/providers', loadComponent: ..., title: 'Answering & providers · Workshop Curriculum' }]` and the one append line for `app.routes.ts` (orchestrator hook) plus the nav entry hook; record both lines in `hook-lines.md`. *(S14 evidence: settings.routes.ts (app.routes.ts hook REQUESTED))*
- [ ] T029 [US1] `features/inquiry/answering-off-banner.component.ts` + its single-tag hook in `features/inquiry/inquiry.component.ts` (orchestrator-serialised with spec 025 US1, plan "Shared-file protocol"): consumes the existing `unavailableCode()`/`unavailableDetail()` already in that component (`inquiry.component.ts:476-477`) and adds the link to `/settings/providers`; does not change the search path.
- [ ] T030 [US1] Run the RED tests from T017-T022 against the implementation; paste GREEN logs. Run `npx ng build`, `npm run check-design-system`, `npm run check-platform-tokens`, `go vet ./...`.
- [ ] T031 [US1] [REVIEW] Independent review of T023-T029 (Opus xhigh): credential/prompt leak surface, role split enforced server-side, vocabulary parity, a11y of the table and live region, no edits to forbidden shared files (diff check), search-unaffected on fault. Verdict `reviews/us1-review.json`.
- [ ] T032 [US1] LIVE-in-scratch verification: with the scratch server from T003 (one run with `extractive`, one with `none`), execute `e2e/settings-providers.spec.ts` and capture the JSON of `GET /api/answering/overview` for both. Write `workshop/evidence/024-answering-enablement/us1/result.json` (`check`, `expected`, `observed`, `rc` per row) and `manifest.sha256`. Paired mutation: run the leak scan (T018 regexes) against a deliberately broken copy that adds an env value to the body - must fail (rc != 0).
- [ ] T033 [US1] UI-VISIBLE ACCEPTANCE (operator can SEE it): after the orchestrator's quiescent-tree restart of the live stack (artifact fingerprint recorded, §11.4.236), take Playwright screenshots of `/settings/providers` (desktop + 390px) and `/ask` (off banner) into `workshop/evidence/024-answering-enablement/us1/screens/` and give the operator the two URLs plus the checklist in `quickstart.md` section "Operator acceptance". Operator signs off in `progress` notes; no sign-off, no closure of US1.
- [x] T034 [US1] Scenario map for the critical invariant "the page never claims answering is on when it is not" (§11.4.239): Given-When-Then for forced-off, stale verdict, provider unhealthy, ingest suspended, overview fault - recorded in `evidence/024-answering-enablement/us1/scenario-map.md` BEFORE closure of T023. *(S14 evidence: evidence/s14/scenario-map-us1.md)*

**Checkpoint (US1)**: a read-only, honest status page exists and is verified on a scratch server; live exposure waits for the orchestrator restart.

---

## Phase 4: User Story 2 - Answering can only be enabled by a measured, two-sided gate (Priority: P1)

**Goal**: verdict production (tooling), boot-time fail-closed gate, compose-default assertion.
**Independent Test**: spec.md US2 independent test and SC-002/003/004.

### Tests first

- [x] T035 [TDD] [SUBAGENT] [US2] RED: `cmd/workshop-server/answering_gate_test.go`. **Oracle**: the negative-fixture matrix required by SC-002 (absent dir, empty dir, FAIL verdict, invalid JSON, wrong schema, stale for each of the fingerprint inputs that can differ at boot: provider, model, endpoint_host, min_score, min_margin, min_support, verifier kind, question-verifier kind, corpus root hash, benchmark hash) = at least 12 cases, all expecting "forced off"; one positive case expecting "pass through unchanged"; plus 9 one-field mutations of the positive fixture (SC-003). Uses the real `verdict.Load` and a real `answer.NewProvider` result, not a stub of either. *(S14 evidence: answering_gate_test.go: 22 negative + 10 one-field mutations + positive)*
- [x] T036 [P] [TDD] [SUBAGENT] [US2] RED: `cmd/workshop-server/answering_gate_boot_http_test.go`: boot the answering route tree with the gate result "forced off": `/api/ask` -> 503 `no_provider` with a detail mentioning the gate; `/api/ask/status` `enabled:false`; the search route (`/api/suggest` or the search handler used by existing `serve-probe`) -> 200 with the same body as with provider `none` (SC-002, FR-016). *(S14 evidence: wire_answering_test.go end-to-end boot gate)*
- [ ] T037 [P] [TDD] [SUBAGENT] [US2] RED: `gates/answer-eval/test_gate_verdict.py` full rule table (T013 cases) + file-layout tests (writes `verdict-<fp12>-<utc>.json`, `.runs.tsv`, manifest line; refuses to overwrite; exit 2 when thresholds missing or server reports answering disabled).
- [x] T038 [P] [TDD] [SUBAGENT] [US2] RED: `gates/verify-answering-verdict.sh` + `gates/prove-answering-verdict-mutation.sh` (paired mutation, §1.1): the verifier asserts every verdict file in the directory validates under the Go loader (via a tiny `cmd/answering-verdict-check` binary) and that the manifest matches; the prover seeds 8 faults in a throwaway copy (tampered count, tampered result, edited threshold hash, deleted runs file, reordered manifest, truncated verdict, duplicate fingerprint overwrite, file modified after manifest) and requires rc != 0 for each and rc 0 for the control. *(S14 evidence: verify-answering-gate.sh + prove-answering-gate-mutations.sh (11/11 killed); named differently from the task)*
- [ ] T039 [P] [TDD] [SUBAGENT] [US2] RED: extend `gates/verify-compose-answering-consistency.sh` test (and its prover) so it fails if the compose default for `-answer-provider` is anything but `none`, or if a compose line sets a provider without the `-answer-verdict-dir` flag being passed. Mutation: change the default to `ollama` in a copy -> rc 1.

### Implementation

- [x] T040 [US2] GREEN: `cmd/workshop-server/answering_gate.go` - `applyAnsweringGate(cfg answeringGateInput) (effective providerName string, decision GateDecision)`; reads verdicts via `verdict.Load`; replaces the provider with `none` on anything but a matching PASS; logs ONE line (decision, 12-char fingerprints, side results; no content); returns `forced_off_reason` for the overview. Boot-invariant registration in the capability matrix doc (T093). The two call sites are hook lines for the orchestrator (`hook-lines.md`). *(S14 evidence: answering_gate.go)*
- [x] T041 [US2] GREEN: flags `-answer-verdict-dir` (+ env `WORKSHOP_ANSWER_VERDICT_DIR`) declared in `cmd/workshop-server/wire_answering_gate.go` (an `addAnsweringGateFlags(fs, cfg)` function; the single hook line for the flag block is the orchestrator's). Default `evidence/answering-verdicts`; unreadable => `none` and logged. *(S14 evidence: flags in wire_answering.go)*
- [ ] T042 [US2] GREEN: `gates/answer-eval/gate_verdict.py` + `scripts/answering-measure.sh` (wrapper: parse the intended configuration -> `eval.sh` on a scratch server with an index copy -> `perrun.py` rows -> `gate_verdict.py` computing counts, Wilson bounds, sides, result, fingerprint, hashes -> writes verdict + runs TSV + manifest line). Never mutates v1 benchmark files; refuses without `gate-thresholds.json`.
- [x] T043 [US2] GREEN: `cmd/answering-verdict-check/main.go` (new binary; three-valued exit; prints per-file status) used by T038 and by `answering-enable.sh`. *(S14 evidence: cmd/answering-verdict)*
- [ ] T044 [US2] If T004 found a classification gap in `runbench.py`/`cmp.py` (e.g. `unavailable` mid-run counted as decline), fix it in NEW wrapper code (`gates/answer-eval/classify.py`) with its own RED test - do not change the historical `cmp.py` output format that the MEASUREMENT file was derived with.
- [ ] T045 [US2] GREEN: compose consistency gate extension (T039) in `gates/verify-compose-answering-consistency.sh`; add the compose mount `../evidence/answering-verdicts:/opt/workshop/evidence/answering-verdicts:ro` and the flag line in `platform/compose.yml` (orchestrator-serialised file; a stream proposes the diff, the orchestrator lands it).
- [x] T046 [US2] Test-only provider construction path for scratch servers: tests construct the answering tree via a helper in a `_test.go` file / `testdata` harness that bypasses the gate by NOT linking `applyAnsweringGate`; there is NO production flag that bypasses it (FR-011, research R8). A test asserts `grep -R "bypass\|skip-gate\|allow-ungated" cmd/ internal/ pkg/` finds no such flag name. *(S14 evidence: no bypass flag; TestNoBypassFlagExists + prover M10)*
- [x] T047 [US2] Run all RED tests (T035-T039) to GREEN; paste logs; `go vet`, `go test -race ./cmd/workshop-server/... ./pkg/answer/verdict/...` (`-m 6G` per architecture §4). *(S14 evidence: tests green (full-suite: only seed-password logins fail, baseline not run))*
- [ ] T048 [US2] [REVIEW] Independent review (Opus xhigh): fail-closed on every error path, no new flag that disables the gate, fingerprint inputs complete (every input that can change answering behaviour is in it - the reviewer lists what is NOT in it and each omission is justified or added), Python/Go rule parity, forbidden shared-file edits. Verdict `reviews/us2-review.json`.
- [ ] T049 [US2] Measure the first candidate configuration `extractive` with `answering-measure.sh` on benchmark v2 (D6 permitting) and store the verdict. Report PASS/FAIL by side. **Whatever the result, record it**: a FAIL is a valid outcome (SC-007). No threshold edit follows a FAIL in the same task (a threshold change is a D1 decision, §11.4.267 attempt record).
- [ ] T050 [US2] Measure the second candidate `ollama` + `qwen2.5:3b-instruct-q4_K_M` with the deployed L4/L5 settings (`-question-verify llm` per the compose comment) and store the verdict; repeat count and wall time recorded (settles the R10 UNCONFIRMED duration).
- [ ] T051 [P] [US2] Cross-implementation check: take the verdicts from T049/T050 and run `cmd/answering-verdict-check` over them (Python-produced, Go-validated) - rc 0 required; mutate one byte in a copy - rc 1.
- [ ] T052 [US2] Registry rows: add the new gates to the gate registries (`gates/check-registry-0NN.tsv` append-only rows, deterministic order) and `gates/POPULATION-CHANGES.md` entry - orchestrator resolves TSV conflicts by keeping both.
- [ ] T053 [US2] LIVE-in-scratch verification of the boot gate: for each of {no verdict, FAIL verdict, matching PASS (synthetic fixture), PASS with one mutated input} start a scratch server with `-answer-provider ollama -answer-verdict-dir <fixture>` and record `GET /api/answering/overview.state`, `/api/ask/status.enabled`, `/api/ask` HTTP status, and a 25-query search digest. Write `workshop/evidence/024-answering-enablement/us2/result.json` + `manifest.sha256`. Expected: only the matching-PASS case is `on_cleared`; all four search digests identical (SC-009).
- [x] T054 [US2] Paired mutation of the boot gate itself (§1.1): build a throwaway copy of `answering_gate.go` that returns pass-through on any error; the T035 matrix MUST fail on it (the gate's tests are proven able to fail). Evidence `us2/mutation-boot-gate.txt`. *(S14 evidence: prove-answering-go-mutations.sh 25/25 killed (G8 equivalent mutant documented))*
- [x] T055 [US2] Scenario map for the critical class "answering enabled without a clearing verdict" (§11.4.239) in `us2/scenario-map.md`: Given/When/Then for stale, forged, truncated, missing dir, clock skew (verdict dated in the future is invalid), concurrent re-measurement while the server boots. *(S14 evidence: evidence/s14/scenario-map-us2.md)*
- [ ] T056 [US2] UI-VISIBLE ACCEPTANCE: the gate card on `/settings/providers` shows the two verdicts from T049/T050 (history rows) and the live state; operator confirms the card matches the files by comparing the short fingerprint with `ls evidence/answering-verdicts` (checklist in `quickstart.md`).

**Checkpoint (US2)**: there is a mechanical, fail-closed, two-sided gate and at least two measured verdicts, PASS or FAIL.

---

## Phase 5: User Story 3 - The known fabrication cases are root-caused and closed (Priority: P2)

**Goal**: F1, F2, F3 closed with RED/GREEN regression fixtures and no recall collapse.
**Independent Test**: spec.md US3 independent test.

- [ ] T057 [US3] Reproduce on the broken artifact (§11.4.115): scratch server with the exact deployed configuration (`-min-score 0.45 -min-margin 0.05`, lexical L4 floor 0.50, L5 `focus`+`llm`, `qwen2.5:3b-instruct-q4_K_M`), replay F1, F2, F3 (3 repeats each) through `runbench.py` restricted to those ids. Record outcome per run in `workshop/evidence/024-answering-enablement/us3/red-baseline.tsv`. Expected from the 2026-09-24 record: F1 `answered` 3/3, F3 `answered` 1/3, F2 `declined` at the deployed margin. If F1 does not reproduce, STOP: the fix path premise changed (record and escalate).
- [ ] T058 [US3] Root-cause trace (§11.4.102 Iron Law, no fix before this finishes): for F1 and F3 produce a per-layer trace (retrieval gate values, which passage was cited, L3 citation check, L4 lexical support score vs floor, L5 focus decision and judge decision) by running the pipeline with the existing verbose/debug outputs in a scratch process or a Go test harness that calls `answer.Pipeline` directly. Write `us3/root-cause.md` naming the layer(s) that admitted each fabrication, citing `pkg/answer/verify.go`, `pkg/answer/question.go`, `internal/answering/wire.go` lines. Every hypothesis in research R5 is either CONFIRMED with the trace or WITHDRAWN here.
- [ ] T059 [P] [TDD] [SUBAGENT] [US3] RED: regression fixtures `pkg/answer/fabrication_regression_test.go` + private data `testdata/benchmark/fabrication-fixtures.tsv` (question ids F1/F2/F3 and, for each, the retrieved-passage ids captured by T057 so the test is deterministic offline - no model call: the L3/L4/L5 deterministic layers are exercised against the recorded retrieval + a recorded model answer). **Oracle**: the 2026-09-24 record (`fabrications-generation-15-2026-09-24.md`) says these three are class U (corpus does not contain the fact) and that the pipeline answered; the test asserts the pipeline outcome is NOT `answered`. Author != implementer of the fix. RED log pasted (must fail on current code).
- [ ] T060 [P] [TDD] [SUBAGENT] [US3] RED: negative-control fixtures - at least 15 answerable questions from benchmark v2 with their recorded good answers, asserting the same deterministic layers still return `answered` (the recall guard at unit level; a fix that rejects everything fails here).
- [ ] T061 [US3] GREEN: implement the smallest fix at the layer T058 named, in a NEW file (provisional name `pkg/answer/demand_check.go` for a deterministic "asked-for quantity/unit must be present in the cited span" rule IF and only if the trace points at the question-focus layer; if the trace points elsewhere the file name and approach differ and `plan.md` is amended first). The change is wired through the existing verifier chain with one hook line. No threshold (`min_score`, `min_margin`, `min_support`) is changed as part of this task (FR-013).
- [ ] T062 [US3] Run T059/T060 to GREEN with the same test files (same-test-confirms-fix, §11.4.146); paste logs; `go vet`; `go test -race ./pkg/answer/...`.
- [ ] T063 [US3] Replay on a scratch server (3 repeats x F1,F2,F3): all `declined`/`unavailable`; write `us3/green-replay.tsv`. Re-measure benchmark v2 two-sided with the same configuration; compare `answerable.wilson_low` with the pre-fix verdict (T050) using the recall regression guard; write `us3/recall-guard.json`. A drop beyond `recall_regression_tolerance` fails the task.
- [ ] T064 [US3] Attempt record (§11.4.267): `us3/attempts.md` lists every approach tried (including failed ones), outcome, and the escalation rule: after 3 failed fixes of the same fabrication stop and bring the trace to the operator; do not silently loop.
- [ ] T065 [US3] [REVIEW] Independent review (Opus xhigh) of T057-T063 including whether the fix generalises (the reviewer proposes 5 new adversarial unanswerable questions of the same shape as F1/F3, labels them from corpus evidence, and the fix is run against them - results recorded, new fixtures added for any that fabricate).
- [ ] T066 [US3] Paired mutation: revert the fix in a throwaway copy - T059 must fail again (proves the fixture detects the original defect).
- [ ] T067 [US3] Idempotency/determinism check: run T059 fixtures 20 times; identical outcomes (the MEASUREMENT file reports F1 as deterministic; a flaky pass is not a pass).
- [ ] T068 [US3] LIVE-in-scratch verification: write `us3/result.json` + `manifest.sha256` covering T057 (RED), T063 (GREEN), T067 (stability); paired mutation row T066.
- [ ] T069 [US3] UI-VISIBLE ACCEPTANCE: in the `/ask` page of the scratch server, the operator submits the three fixture questions and sees a decline/refusal outcome with its reason (not an answer); screenshots saved to `us3/screens/`.
- [ ] T070 [US3] If the fix does not clear the gate, record the remaining fabrication rate and its source classes in `us3/remaining-gaps.md` as TRACKED findings (§11.4.261) with provenance, not as prose.

**Checkpoint (US3)**: F1-F3 closed with evidence or the gap is escalated with a trace.

---

## Phase 6: User Story 4 - Providers comparable under the same gate; locality/residency visible (Priority: P2)

- [ ] T071 [TDD] [SUBAGENT] [US4] RED: `internal/answering/verdict_history_test.go`: lists verdict files newest first, marks the running-fingerprint row current, tolerates invalid files (listed as `invalid`, never crashing the page). **Oracle**: fixture directory built by the test author with 5 verdicts (2 providers, 1 stale, 1 invalid, 1 duplicate fingerprint with later time).
- [ ] T072 [P] [TDD] [SUBAGENT] [US4] RED: `internal/answering/residency_note_test.go`: file absent -> `present:false`; present -> text returned only when active locality class is `lan`/`remote`; >64 KiB -> truncated with a flag; HTML in the file is returned as plain text (the UI test asserts it is escaped); symlink escaping the docs directory is refused (path traversal).
- [ ] T073 [US4] GREEN: `internal/answering/verdict_history.go`, `residency_note.go`; extend `BuildOverview` inputs (T023) with these; flag `-answer-residency-note` (default `docs/answering-data-residency.md`) in `wire_answering_gate.go`.
- [ ] T074 [P] [US4] Frontend: `features/settings/verdict-history.component.ts` (+spec), `residency-note.component.ts` (+spec): history table with intervals and result text, current-row marker with text "current configuration", remote-opt-in statement for hosted rows, "no residency note provided" absent state.
- [ ] T075 [US4] Hosted-row facts: surface `remote_opt_in` and, when spec 011 US2 is built, `audit.available`; when not built, the explanatory sentence. No network call is made to any vendor (FR-019).
- [ ] T076 [US4] LAN badge: when spec 011 US3 adds `lan`, the badge shows it; a contract test (`overview_locality_test.go`) asserts that a non-loopback endpoint declared `local` is shown `unverified`/refused, never `local`; if US3 is not built the `lan` branch is covered by a unit test over a fake registration and marked `# until 011 US3` in the test name.
- [ ] T077 [US4] [REVIEW] Independent review (Opus xhigh): path traversal, plain-text rendering, no content in history rows, locality never over-claimed.
- [ ] T078 [US4] Operator-authored residency note: create the file ONLY from operator-supplied text (D7); until supplied the page displays the absent state. A task note records that no agent drafts it.
- [ ] T079 [US4] LIVE-in-scratch verification + `us4/result.json` + manifest: three verdict fixtures render three rows with exactly one current; residency note present/absent states; hosted row without remote opt-in rendered as such.
- [ ] T080 [US4] UI-VISIBLE ACCEPTANCE: operator opens the page on the scratch server seeded with the T049/T050 verdicts and sees both candidates side by side with PASS/FAIL per side.

---

## Phase 7: User Story 5 - Guarded enable/disable procedure; search never notices (Priority: P3)

- [x] T081 [TDD] [SUBAGENT] [US5] RED: `scripts/answering-enable.test.sh` (pattern of `restart-quiescence.test.sh`). **Oracle**: the contract `contracts/enable-procedure.md` exit-code table; cases: no verdict rc 1, stale rc 1 naming the differing input, invalid rc 1, matching PASS rc 0 printing the apply command, unreadable dir rc 2, `--dry-run` never reads the network, disable always rc 0. Uses a fake `curl` shim for `/api/index/status`; no live call. *(S14 evidence: answering-enable.test.sh 34 passed)*
- [x] T082 [US5] GREEN: `scripts/answering-enable.sh`, `scripts/answering-disable.sh` (shellcheck-clean, `set -u`, portable per the umbrella's `_portable.sh` helpers; no GNU-only `sed -i`/`stat -c`). *(S14 evidence: answering-enable.sh/disable.sh)*
- [x] T083 [TDD] [SUBAGENT] [US5] RED: `scripts/answering-postcheck.test.sh` against `gates/answer-eval/fake_server.py` extended with an overview route: asserts `result.json` rows and rc semantics (any mismatch rc 1, unreachable rc 2). *(S14 evidence: answering-postcheck.test.sh 22 passed)*
- [x] T084 [US5] GREEN: `scripts/answering-postcheck.sh` (search digest = sha256 of canonical result JSON of a committed 25-query list `testdata/benchmark/search-digest-queries.txt`; known-answerable/unanswerable probes read from benchmark v2 ids so no question text is hard-coded in the script). *(S14 evidence: answering-postcheck.sh + 25-query list)*
- [ ] T085 [US5] Extend `gates/prove-g-http-5-search-survives-answering-down.sh` (or add a sibling `prove-g-http-6-search-survives-gate.sh`) to cover the forced-off and overview-fault paths (FR-016); paired mutation: a copy of the wiring in which an overview panic propagates -> search 5xx -> the prover must fail.
- [ ] T086 [US5] [REVIEW] Independent review of the scripts: no live restart performed, no secret in output, three-valued exits honest, digest list not leaking content.
- [ ] T087 [US5] ORCHESTRATOR-ONLY, operator-gated: with a clearing verdict (only if one exists), capture pre-digest (`answering-postcheck.sh --expect off`), apply the printed enable command from the primary checkout on a quiescent tree, run `--expect on`. Evidence `workshop/evidence/024-answering-enablement/live/` (`result.json`, `manifest.sha256`, build id, image digest per §11.4.264). If no verdict clears the gate, this task's recorded outcome is the NEGATIVE ARM: run `answering-enable.sh` and record its rc 1 refusal plus an actual boot with a non-`none` provider and no verdict showing forced-off and search 200 (still evidence, still a valid close).
- [ ] T088 [US5] ORCHESTRATOR-ONLY: disable arm - apply `answering-disable.sh` output, run `--expect off`, digest equals the pre-capture (SC-009). Restore the deployed state the operator wants afterwards.
- [ ] T089 [US5] Failure-injection run (§11.4.260): kill the provider endpoint mid-session on a scratch server; overview -> `degraded_provider_unhealthy`, `/api/ask` explicit unavailable, search 200. Evidence `us5/failure-injection.json`.
- [ ] T090 [US5] UI-VISIBLE ACCEPTANCE: operator watches the state card change across enable/disable on the live page and confirms `/ask` shows the banner OFF / the input ON (screenshots `live/screens/`).

---

## Phase 8: Polish & cross-cutting

- [ ] T091 [P] [POLISH] Operator guide `workshop/docs/guides/answering-enablement-guide.md` (how to measure, read a verdict, enable, disable, what to do on FAIL, how stale works) - linked from `workshop/docs/README.md`.
- [ ] T092 [P] [POLISH] User manual section in `workshop/docs/manual.md` ("Answering is off: what you see and why") and `workshop/docs/answering.md` updated (status page, gate, states); FAQ entries in `workshop/docs/faq.md` (why is Ask off, what does "calibrated" mean, why did my verdict go stale, can the UI turn it on, where are my credentials). Coverage map `workshop/docs/coverage/024-docs-coverage.md` (capability -> manual/guide/FAQ) with no orphan capability (§11.4.257).
- [ ] T093 [P] [POLISH] Capability matrix + boot invariants doc (§11.4.254): row for answering gate, verdict dir, residency note, overview.
- [ ] T094 [P] [POLISH] Diagram 1 of 4 - ARCHITECTURE (Mermaid, embedded in the guide at point of use): components `workshop-server` (answer.Handler, answering gate, overview handler), verdict dir, measurement tooling, scratch server, frontend page. Truthful to the files in this spec.
- [ ] T095 [P] [POLISH] Diagram 2 of 4 - DATA FLOW: question -> retrieval gate -> generation -> L3/L4/L5 -> outcome; measurement flow benchmark v2 -> harness -> verdict -> boot check -> overview.
- [ ] T096 [P] [POLISH] Diagram 3 of 4 - STATE MACHINE: the five answering states and transitions (from `data-model.md`).
- [ ] T097 [P] [POLISH] Diagram 4 of 4 - SEQUENCE: operator measure -> verdict -> enable script -> orchestrator restart -> boot gate -> postcheck; and the negative path (no verdict).
- [ ] T098 [POLISH] Exports (§11.4.65): `bash scripts/build-exports.sh` for the guide/manual/FAQ (html, pdf, docx triplets as the existing docs have); ensure Mermaid is rendered, no raw diagram source leaks.
- [ ] T099 [POLISH] [REVIEW] Independent export validation by a separate agent (§11.4.168): open the PDF/DOCX, check content, text and full visual layers (tesseract is installed per the umbrella carrier), verdict `reviews/exports-review.json`.
- [ ] T100 [POLISH] Claim-vs-reality ledger rows (§11.4.266): "Answering is gated by a measured two-sided verdict", "The page never exposes credentials", "Search is unaffected by answering state" - each with a passing challenge (T053, T032, T053/T085).
- [ ] T101 [POLISH] Full-suite retest on a clean baseline (§11.4.40): `go build ./... && go vet ./... && go test ./... -p 2`, `npm run test:unit`, `npx ng build`, Playwright desktop + mobile, all gates affected; paste counts. Done once, after all stories.
- [ ] T102 [POLISH] Whole-feature independent review (Opus xhigh, §11.4.194): all scenarios, all angles; includes a bluff audit of every PASS claim in `evidence/024-answering-enablement/` (each PASS has the captured runtime artefact).
- [ ] T103 [POLISH] Discovery-pressure (§11.4.238): an agent that did not build the feature explores the page and the gate for 30 minutes of scripted adversarial inputs (weird verdict dirs, huge notes, role confusion) and records anything found as an escape with a root-cause + missing-check audit.
- [ ] T104 [POLISH] Zero-gaps sweep (§11.4.261): list every TODO/stub/"for now" introduced by this spec; each CLOSED with evidence or TRACKED with an item id; ratchet not raised.
- [ ] T105 [POLISH] Sync trackers: `specs/024.../progress.yml` (orchestrator-owned), `CONTINUATION.md` in the umbrella (§12.10), workshop evidence indexes; gitlink bump + `helix-deps.yaml` ref in ONE umbrella change (cascade C9).
- [ ] T106 [POLISH] Operator decision record: D1-D7 answers captured in `specs/024.../decisions.md` (created when answered) and reflected in thresholds file, flags and docs; no task is marked closed on an assumed answer.
- [ ] T107 [POLISH] Version bump after the QA deploy (§11.4.235(B)) and tag only after T101 with the project prefix (§11.4.151).
- [ ] T108 [POLISH] Final live verification bundle: assemble `workshop/evidence/024-answering-enablement/live/result.json` + `manifest.sha256` indexing every sub-result (us1..us5), with image digest and build id; the operator's UI sign-off notes from T033/T056/T080/T090.

---

## Dependencies & Execution Order

- Phase 1 -> Phase 2 -> all stories. T013/T014 in Phase 2 are `[P]` with T007-T012.
- **US1 and US2 are independent after Phase 2** and may run as two parallel streams (different files); both end with an orchestrator hook landing. US1 consumes verdict status from `verdict.Load` (T012) so it can show real statuses as soon as Phase 2 is done.
- US3 needs US2's harness (T042) and the benchmark (T015) for a trustworthy comparison; T057/T058 (reproduce and trace) can start right after T042 + T003.
- US4 needs T012, T023 and at least one verdict (T049).
- US5 needs T040/T043 and T082/T084; T087/T088 additionally need the orchestrator and the operator's decisions.
- Polish after the desired stories; T101 once.

### Parallel opportunities

T002-T005; T007/T009/T011/T013/T014 test-authoring; T017-T022 test-authoring; T035-T039; T091-T097.

### Subagent dispatch notes

Test-author agents and implementer agents are distinct. The labeller for T015 and the adversarial reviewer for T065 are distinct from the pipeline builder. Measurement tasks (T049, T050, T063) are long-running: register the long-op before running (§11.4.232), detach, heartbeat, background; they do NOT run in parallel with each other on the host (CPU/GPU contention changes latency, not outcomes, but memory headroom is checked first).

## Implementation Strategy

MVP = Phases 1, 2 and 3 (read-only visibility). Then US2 (the gate) - the pair is the shippable value. US3 is the fix path whose outcome decides whether the gate ever clears. US4 and US5 complete the operator experience. If the gate never clears, answering stays OFF, honestly displayed (SC-007).
