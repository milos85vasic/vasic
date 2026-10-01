---
description: "Task list for feature 011: Multi-Provider LLM Abstraction — Remote, LAN, and Audited Generation"
---

# Tasks: Multi-Provider LLM Abstraction — Remote, LAN, and Audited Generation

**Input**: Design documents from `specs/011-multi-provider-llm-providers/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [data-model.md](data-model.md), [contracts/remote-generation-audit-log.md](contracts/remote-generation-audit-log.md), [quickstart.md](quickstart.md)

**Global Constraints** (from plan.md's Technical Context and Constitution Check — every task's requirements implicitly include these):

- All source edits happen inside the private `workshop` submodule, specifically `workshop/platform/backend/pkg/answer/` and `workshop/platform/backend/cmd/workshop-server/`. Nothing is copied into this public umbrella repository's `specs/` tree beyond file *paths* and *line numbers*, per this repository's content-boundary rule.
- Every safeguard `HostedProvider` already enforces (remote opt-in before credential read, locality-must-agree, credential scrubbing, health-check-before-use) MUST continue to apply to the two new rows with **zero** row-specific reimplementation (FR-003) — several tasks below are explicitly "confirm existing coverage extends" rather than "write new coverage," and must be treated that way, not padded with redundant tests.
- The audit record MUST NEVER contain prompt text, retrieved-passage content, generated-answer text, or the credential value (FR-005) — enforced structurally (the writer's parameters), not by convention.
- `local` locality's existing three-layer loopback enforcement (`llamacpp.go:16-33`) MUST NOT be weakened by introducing `lan` (FR-008) — every task touching `locality.go` or the new LAN row carries an explicit regression check for this.
- No new `go.mod` entry is needed (`openai`/`anthropic` are existing sub-packages of the already-required `digital.vasic.llmprovider` module) and no new third-party dependency, database engine, or service is introduced anywhere in this feature.
- Per `hosted.go`'s own documented honest boundary, **no hosted row has ever been executed against its real vendor endpoint from this tree**, and this feature does not change that. Tasks that would require a real `ApiKey_OpenAI` / `ApiKey_Anthropic` / real LAN server are marked **OPERATOR-GATED** below: they are not required to close their user story, and their completion note must say plainly whether they were actually run against a real endpoint or deferred — never implied as done on a guess (§11.4.6).
- **Corrected discrepancy, recorded rather than silently dropped**: `contracts/remote-generation-audit-log.md` §2 previously stated the audit record carries "the seven fields listed in `data-model.md` §4," while that section's own JSON example has always listed **nine** keys (`id`, `ts`, `session_id`, `provider`, `model`, `endpoint`, `content_bytes`, `outcome`, `duration_ms`). The contract has been corrected to say "nine" so the two source documents now agree. T007 below implements against the nine-key schema.
- Story 4 (provider hot-switching) is **out of scope for implementation** per plan.md's Complexity Tracking — see Phase 6 below, which records the blocker rather than inventing tasks against an undesigned mechanism.

## Format: `[ID] [P?] [TDD?] [REVIEW?] [SUBAGENT?] [Story] Description`

- **[P]**: parallel-safe — different files, no dependency on a same-phase sibling task
- **[TDD]**: must follow RED (failing test, run and confirm it fails) → GREEN (minimal implementation) → the task's own re-run confirming PASS
- **[REVIEW]**: requires independent code review (§11.4.142) before the story's checkpoint is considered closed
- **[SUBAGENT]**: self-contained enough to hand off to a subagent with no further context
- **[Story]**: US1/US2/US3/US4, or none for Setup/Polish

---

## Phase 1: Setup

**Purpose**: Establish the pre-change baseline every later task's "still green" claim is measured against — this codebase's own `registry_test.go` convention (`prodConfig()`, the production-argv comment) is to pin behavior against a measured baseline, not an assumed one.

- [ ] **T001 [P]** Record the pre-feature baseline: `cd workshop/platform/backend && go build ./... && go test ./pkg/answer/... -v -count=1 2>&1 | tail -40`. Paste the real pass count (expect all `pkg/answer` tests green, `TestCatalogueIsCoherent`'s `len(names)` currently 33) into this task's completion note. This is the number every later "still passes" claim in this feature is compared against — do not guess it.

**Checkpoint**: Baseline captured. Phases 2 onward may begin.

---

## Phase 2: Foundational — none

No shared scaffolding blocks every story here. User Story 1 (catalogue rows) needs nothing beyond the catalogue's existing `hosted(...)` helper, User Story 2 (audit log) is a new, independent file wired into two existing call sites, and User Story 3 (LAN locality) extends `locality.go` and `Kind` independently of the other two. Per spec.md's own framing ("Both can be tested independently of Stories 2 and 3"), this phase is intentionally empty — do not invent foundational work to fill it.

---

## Phase 3: User Story 1 - Operator turns on OpenAI or Anthropic as the answering provider (Priority: P1) 🎯 MVP

**Goal**: `openai` and `anthropic` become two more `hosted(...)` catalogue rows in `workshop/platform/backend/pkg/answer/registry.go`, inheriting every one of `HostedProvider`'s four safeguards with zero new code in `hosted.go`.

**Independent Test**: `go test ./pkg/answer/... -run 'TestOpenAI|TestCatalogueIsCoherent|TestEveryHostedRow|TestNoHostedRow|TestACredentialNeverReachesAReason' -v` plus `quickstart.md` Part 1 (operator-gated, real keys).

### Tests for User Story 1

- [ ] **T002 [TDD] [P] [US1]** RED: add `TestOpenAIAndAnthropicRowsAreCatalogued` to `workshop/platform/backend/pkg/answer/registry_test.go` asserting, for both new rows: `LookupProvider("openai")` returns `ok: true` with `Kind: KindHosted`, `Upstream: "pkg/providers/openai"`, `Credential: "OpenAI"`, and `CredentialEnv() == "ApiKey_OpenAI"`; and `LookupProvider("anthropic")` returns `ok: true` with `Kind: KindHosted`, `Upstream: "pkg/providers/anthropic"`, `Credential: "Anthropic"`, `CredentialEnv() == "ApiKey_Anthropic"` (FR-001). Run `go test ./pkg/answer/... -run TestOpenAIAndAnthropicRowsAreCatalogued -v` from `workshop/platform/backend` and confirm it FAILS (`ok: false` — the rows do not exist yet). Paste the real failing output into the completion note.

### Implementation for User Story 1

- [ ] **T003 [SUBAGENT] [US1]** GREEN: in `workshop/platform/backend/pkg/answer/registry.go`, add two import lines for `digital.vasic.llmprovider/pkg/providers/openai` and `.../anthropic` (alphabetically among the existing 27 lines at `registry.go:50-77`), and append two rows to `catalogue` (after the `zen` row, `registry.go:307-308`):
  ```go
  hosted("openai", "OpenAI", "pkg/providers/openai",
      func(k, u, m string) llmprovider.LLMProvider { return openai.NewProvider(k, u, m) }),
  hosted("anthropic", "Anthropic", "pkg/providers/anthropic",
      func(k, u, m string) llmprovider.LLMProvider { return anthropic.NewProvider(k, u, m) }),
  ```
  Both constructors are confirmed real at `submodules/LLMProvider/pkg/providers/openai/openai.go:136` and `.../anthropic/anthropic.go:151` (`func NewProvider(apiKey, baseURL, model string) *Provider`) — do not re-verify the signature, it was read directly for this plan. Run T002's test again from `workshop/platform/backend`; confirm PASS. **No edit to `hosted.go`, `provider.go`, or any refusal path** — this task is catalogue-only, which is the whole point of FR-001/FR-014 (one table, no second list).

- [ ] **T004 [REVIEW] [US1]** Confirm FR-003 (zero row-specific reimplementation) by demonstration, not by writing new tests: the existing refusal-coverage tests in `registry_test.go` derive their subject from `hostedRows(t)` / `Registrations()` (`registry_test.go:204-220`), so they extend to the two new rows automatically once T003 lands. Run, from `workshop/platform/backend`:
  ```bash
  go test ./pkg/answer/... -v -run \
    'TestCatalogueIsCoherent|TestEveryHostedRowRefusesWithoutTheRemoteOptIn|TestNoHostedRowSubstitutesAModel|TestEveryHostedRowRefusesWithoutItsCredential|TestACredentialNeverReachesAReason|TestTheScrubIsNotVacuous|TestAnUnreachableHostedProviderIsUnavailableAndNeverFallsBack'
  ```
  Confirm the output's per-subtest lines include `.../openai` and `.../anthropic` (Go's `t.Run(reg.Name, ...)` subtest naming) and that every one PASSes — this is the real evidence for Acceptance Scenarios 3-5, satisfied by existing, now-extended coverage rather than new code (mirrors this repository's spec-009 `T011a` pattern of confirming existing behavior rather than assuming it). Paste the real output into the completion note. If any expected subtest is MISSING (not just failing), that is a finding to report, not to paper over.

- [ ] **T005 [US1]** Confirm Acceptance Scenario 6 (the selectable-provider listing). Read `workshop/platform/backend/cmd/answer-providers/main.go` first to confirm its real flag name (do not assume `--names` matches `quickstart.md`'s illustrative example without checking), then run the real binary or the equivalent `RegisteredProviders()`-backed listing and confirm both `openai` and `anthropic` are present alongside the existing 33 rows. Paste the real command and its real output into the completion note.

- [ ] **T006 [P] [US1] OPERATOR-GATED** — not required to close this story. If a real `ApiKey_OpenAI` and/or `ApiKey_Anthropic` is available, run `quickstart.md` Part 1 for real (SC-001, Acceptance Scenarios 1-2) and Part 2's two negative cases (SC-002, missing opt-in and missing credential), and paste the real descriptor/refusal output into the completion note. Per `hosted.go`'s own documented honest boundary ("NO HOSTED ROW HAS EVER BEEN EXECUTED AGAINST ITS REAL VENDOR ENDPOINT FROM THIS TREE"), this MAY be deferred without blocking US1's completion — but if deferred, the completion note MUST say so explicitly, not imply it was run.

**Checkpoint**: User Story 1 is independently complete — T002-T005 are required; T006 is operator-gated and does not block this checkpoint.

---

## Phase 4: User Story 2 - Every remote generation is individually audit-logged (Priority: P1)

**Goal**: A new append-only `curriculum/remote-generations.jsonl`, written from two call sites inside the existing `HostedProvider` path, records one structured record per remote-generation *attempt* — success or failure — for all 30 hosted rows (28 existing + the two from US1), with prompt/passage/answer content structurally excluded.

**Independent Test**: `go test ./pkg/answer/... -run 'TestWriteAuditRecord|TestAudit|TestField' -v` plus `quickstart.md` Part 3 against any already-wired hosted row (does not require US1 to be complete — applies to the existing 28 rows today).

### Tests for User Story 2

- [ ] **T007 [TDD] [P] [US2]** RED: create `workshop/platform/backend/pkg/answer/audit_test.go` with failing tests for the new writer (data-model.md §4, contract §2), against the **nine-field** schema (see this file's header note on the seven-vs-nine discrepancy):
  - `TestWriteAuditRecordAppendsOneJSONLine` — write two `RemoteGenerationAuditRecord`s to a temp path; confirm the file has exactly 2 lines, each valid JSON carrying exactly `id`, `ts`, `session_id`, `provider`, `model`, `endpoint`, `content_bytes`, `outcome`, `duration_ms`.
  - `TestAuditRecordStructurallyExcludesContent` — reflect on `RemoteGenerationAuditRecord`'s field set and on `writeAuditRecord`'s parameter list; confirm there is no field or parameter through which prompt text, passage text, answer text, or the credential *value* (as opposed to the credential *name*) could reach the writer (FR-005's negative requirement, enforced structurally).
  - `TestWriteAuditRecordIsAllOrNothing` — point the writer at an unwritable path (e.g. a directory, or a path under a nonexistent parent); confirm it returns a non-nil error and that zero bytes are appended to any file (contract §2 postcondition — "no partial-line writes").
  Run `go test ./pkg/answer/... -run 'TestWriteAuditRecord|TestAuditRecordStructurallyExcludesContent' -v` from `workshop/platform/backend`; confirm FAIL (`ModuleNotFoundError`-equivalent: undefined `RemoteGenerationAuditRecord` / `writeAuditRecord`). Paste the real compiler/test failure into the completion note.

### Implementation for User Story 2

- [ ] **T008 [SUBAGENT] [US2]** GREEN: create `workshop/platform/backend/pkg/answer/audit.go` implementing `RemoteGenerationAuditRecord` (the nine fields above, with an `Outcome` type whose closed vocabulary is exactly `success`, `health_check_failed`, `credential_missing`, `upstream_error`, `cancelled`, `schema_violation` — mirroring the existing `Reason.Code` vocabulary this package already uses rather than inventing a new one) and `writeAuditRecord(path string, rec RemoteGenerationAuditRecord) error`, buffering the complete JSON line in memory before any `Write` call (contract §2's "no partial-line writes" postcondition — do not stream field-by-field). Model the file-handling shape (append-only, create-on-first-write, never truncate) directly on `submodules/passage/pkg/passage/redaction.go`'s existing `RedactionLog` precedent, per data-model.md §4's explicit instruction to reuse that convention rather than invent a second one. Run T007's tests; confirm PASS.

- [ ] **T009 [REVIEW] [US2]** Resolve the fail-open-vs-fail-closed audit-write-failure question that `contracts/remote-generation-audit-log.md` §2 ("Failure handling") and `plan.md`'s Constitution Check (§11.4.252 row) both explicitly leave open, rather than silently defaulting either way. The contract requires: "Implementation MUST pick one, mark the choice in a code comment naming this section, and MUST NOT silently default to fail-open without that comment being present." Absent an explicit operator decision by the time this task runs, apply §11.4.252's general fail-closed posture (an audit-write failure fails the generation attempt closed) **with the required code comment**, and state plainly in this task's completion note that this is an unreviewed default pending operator confirmation — not a settled design decision. [REVIEW] because this is exactly the class of choice independent review exists to catch before it ships silently.

- [ ] **T010 [TDD] [US2]** RED: add failing tests (in `workshop/platform/backend/pkg/answer/registry_test.go`, alongside the existing hosted-row behavior tests, reusing the same in-process fake `LLMProvider` pattern `TestAnUnreachableHostedProviderIsUnavailableAndNeverFallsBack` already uses at `registry_test.go:407` rather than inventing a new fixture style) asserting the two write call sites data-model.md §4 specifies:
  - a construction that fails at REFUSAL 3 (credential missing, `hosted.go:149-162`) produces exactly one audit record with `outcome: credential_missing`;
  - a construction that fails at REFUSAL 4 (health-check failure, `hosted.go:206-214`) produces exactly one record with `outcome: health_check_failed`;
  - a construction that fails at REFUSAL 1 or REFUSAL 2 (`hosted.go:96-144`) produces **zero** audit records — data-model.md §4 explicitly designs these two as "configuration-shape refusals," not generation attempts;
  - a successful `Generate` call (`hosted.go:284-385`) produces one record with `outcome: success`;
  - an upstream error from `Generate` produces one record with `outcome: upstream_error`.
  Run from `workshop/platform/backend`; confirm RED (no audit file is written yet). Paste the real failing output into the completion note.

- [ ] **T011 [SUBAGENT] [US2]** GREEN: wire the two `writeAuditRecord` call sites into `hosted.go`'s `newHostedProvider` (`hosted.go:96-216`, after refusals 3-4 resolve, whichever way) and `Generate` (`hosted.go:284-385`, wrapping the `upstream.Complete` call at line 317), applying T009's fail-open/fail-closed decision. `HostedProvider` needs a new unexported field carrying the resolved audit-log path (plumbed from `ProviderConfig`, wired in T012) and a session identifier — read `pkg/answer/jobs.go:44` (`Job.ID`) first: there is no separate `SessionID` field on `Job` today, so reuse `Job.ID` as the `session_id` value rather than inventing a second identifier, threading it down to `Generate`/`newHostedProvider` as a new field if it is not already reachable there. Run T010's tests; confirm PASS.

- [ ] **T012 [SUBAGENT] [US2]** Wire the new `-answer-audit-log` flag / `$WORKSHOP_ANSWER_AUDIT_LOG` into `workshop/platform/backend/cmd/workshop-server/main.go`, in the same flag-declaration block as `-answer-provider` (`main.go:501-509`), mirroring `-redaction-log`'s declaration (`main.go:538-544`) — including a path-resolution helper analogous to `redactionLogPath` (`cmd/workshop-server/redaction_log.go:131`) that defaults to the registry file's sibling `remote-generations.jsonl` when the flag is unset (contract §1). Add a test confirming the log path is absent-tolerant at boot — starting the server with no prior log file and no remote opt-in enabled must not error, mirroring `syncRedactionLog`'s documented "ABSENT IS NOT AN ERROR" design in the same file. Run the new test; confirm PASS.

- [ ] **T013 [TDD] [US2]** RED then GREEN: add a failing test for Acceptance Scenario 4 / FR-004's scoping — constructing `none`, `ollama`, or `llamacpp` (the `KindBuiltin`/`KindLocal` rows) and generating never calls `writeAuditRecord`, matching `RequiresRemoteOptIn()`'s existing `Kind`-derived scoping (`registry.go:149`). Confirm RED if T011's wiring is not already correctly scoped; implement by gating the two T011 call sites on `reg.Kind == KindHosted`. Run; confirm PASS.

- [ ] **T014 [REVIEW] [US2] OPERATOR-GATED (partially)** — the negative/refusal half is required; the real-success half is operator-gated like T006. Run `quickstart.md` Part 3 for real: the no-credential negative case (no real key required — `-answer-provider openai -answer-allow-remote -answer-locality remote -answer-model gpt-4o` with `ApiKey_OpenAI` deliberately unset) MUST be run for real and its `outcome: credential_missing` record pasted into the completion note (this closes SC-003/SC-004's negative path with no real cost). If a real key is available, additionally run a real successful generation and paste its `outcome: success` record and the `jq` negative-content checks from `quickstart.md` Part 3. If no real key is available, say so explicitly rather than implying it was run.

**Checkpoint**: User Story 2 is independently complete — testable and demonstrable without User Story 1 being finished, exactly as spec.md states ("it applies to every existing hosted row today, not only the new OpenAI/Anthropic rows").

---

## Phase 5: User Story 3 - Operator points the platform at a model server on their own LAN (Priority: P2)

**Goal**: A third `lan` locality value is added to `VerifyLocality`, a new `KindLAN` catalogue row reuses `llamacpp.go`'s hardened transport (loopback check removed) to reach a real non-loopback OpenAI-compatible server, and the permanently-stubbed `openai_compatible` row is removed from the catalogue rather than left dual-listed (FR-006 through FR-010).

**Independent Test**: `go test ./pkg/answer/... -run 'TestVerifyLocality|TestLAN|TestOpenAICompatible|TestNoRegisteredRowIsAPermanentStub' -v` plus `quickstart.md` Part 4 (operator-gated for the positive case; the FR-008 negative case needs only one real non-loopback address, not a real model server).

### Tests for User Story 3

- [ ] **T015 [TDD] [P] [US3]** RED: extend the existing `VerifyLocality` test in `workshop/platform/backend/pkg/answer/provider_test.go` (around lines 74-123) with new assertions: `VerifyLocality("lan", "<a resolvable non-loopback test address>")` → `Verified: true`; `VerifyLocality("lan", "http://nx.invalid.test.example:8080")` (unresolvable) → `Verified: false`, mirroring the existing unresolvable-`local` case at line 93; and, as the FR-008 regression pin, re-assert the existing `routable := VerifyLocality("local", "http://example.com:11434")` case at line 85 is **unchanged** (still `Verified: false`) — declaring `lan` must not have altered the `local` branch at all. Run from `workshop/platform/backend`; confirm RED (the `lan` branch does not exist yet — it currently falls into the loopback-required `else` path and would incorrectly report `Verified: false` for a resolvable non-loopback address). Paste the real failing output.

### Implementation for User Story 3

- [ ] **T016 [SUBAGENT] [US3]** GREEN: add the `lan` branch to `VerifyLocality` in `workshop/platform/backend/pkg/answer/locality.go` per data-model.md §2 (`declared == "lan"` → `Verified=true` iff the endpoint resolves at all, regardless of loopback; unresolvable is still a fault, never an assumption). Add `KindLAN` to `registry.go`'s `Kind` closed vocabulary (`registry.go:86-93`, alongside `KindBuiltin`/`KindLocal`/`KindHosted`) and to the `switch r.Kind` exhaustiveness check in `TestCatalogueIsCoherent` (`registry_test.go:190-194`, currently only three cases — add the fourth or the test itself will start failing on the new row added in T018). Confirm `RequiresRemoteOptIn()` (`registry.go:149`, `return r.Kind == KindHosted`) needs **no edit** — `KindLAN != KindHosted` already derives FR-007's "no remote opt-in required" property; read the function to confirm this rather than adding a special case. Run T015; confirm PASS.

- [ ] **T017 [TDD] [US3]** RED: add a failing test for the new LAN-locality row (data-model.md §3), using an `httptest.NewServer`-backed OpenAI-compatible fixture in the same style `llamacpp_test.go`'s `TestLlamaCppGenerateEndToEnd` (line 366) already uses, asserting: (a) construction succeeds with `-answer-locality lan` and `AllowRemote` unset (FR-007); (b) the identical construction with `-answer-locality local` against a non-loopback endpoint is refused with `CodeLocalityUnverified` — written as a NEW test against the NEW row (not merely trusting `llamacpp`'s own unchanged `TestLlamaCppRefusesAnythingThatIsNotLoopback`, line 185) so FR-008 is pinned on the code path this feature actually adds; (c) `Descriptor().Locality` reads exactly `"lan"` (Acceptance Scenario 2), never `"local"` or `"remote"`. Confirm RED.

- [ ] **T018 [SUBAGENT] [US3]** GREEN: implement the new `KindLAN` catalogue row per data-model.md §3's chosen design (`Name: "openai_compatible_lan"` — confirm this exact name has not been superseded by an operator naming decision before implementing; it is explicitly marked implementation-time-decidable in plan.md). Reuse `llamacpp.go`'s `newLlamaCppClient()` (`llamacpp.go:121-133`) and `loopbackDialer()` (`llamacpp.go:97-115`) transport, parameterizing the dialer's `Control` hook to accept any address `VerifyLocality("lan", endpoint)` (T016) already verified as resolvable, rather than hardcoding `ip.IsLoopback()` — reuse the existing `/v1/chat/completions` / `/v1/models` request shapes and `DecodeAnswerPayload` schema enforcement unchanged; do not write a second transport. Run T017; confirm PASS.

- [ ] **T019 [US3]** Remove the permanently-stubbed `openai_compatible` row from `catalogue` (`registry.go:227-251`) per data-model.md §3's "remove, not add" decision (closes FR-010). Update `llamacpp_test.go`'s `TestOpenAICompatibleStillRequiresTheRemoteOptIn` (line 335), which asserts against the row being removed: replace it with an assertion that `LookupProvider("openai_compatible")` now returns `ok: false` (the stub is gone, not merely hidden behind a flag) and `LookupProvider("openai_compatible_lan")` returns `ok: true, Kind: KindLAN`. Run `grep -rn openai_compatible workshop/platform/backend/pkg/answer/*_test.go` before and after this edit and paste both outputs into the completion note, confirming no other test still references the removed row. Run the full `pkg/answer` suite; confirm green.

- [ ] **T020 [TDD] [US3]** RED then GREEN: add `TestNoRegisteredRowIsAPermanentStub` to `registry_test.go`, iterating `Registrations()` and asserting no row's `build` function is a constant-refusal closure — the exact defect class `openai_compatible` was (FR-010's *general* form, a standing regression guard, not merely the one instance T019 fixes). This is genuinely new coverage, not a confirmation of existing coverage (unlike T004): run it against the pre-T019 tree first if feasible (it should catch `openai_compatible` as a violation), confirm it goes green once T019 lands.

- [ ] **T021 [REVIEW] [US3] OPERATOR-GATED (partially)** — the FR-008 negative case is required and needs no real model server, only one real non-loopback address reachable from this host; the positive LAN-generation case is operator-gated. Run, for real: `./workshop-server -answer-provider llamacpp -answer-locality local -answer-endpoint http://<a real non-loopback address>:8080 -answer-model x ...` and paste the real `CodeLocalityUnverified` refusal, confirming it is byte-for-byte unchanged in kind from pre-feature behavior. If a second LAN-reachable machine running an OpenAI-compatible server is available, additionally run `quickstart.md` Part 4's positive scenario and paste the real descriptor showing `locality: lan`; otherwise, say so explicitly.

**Checkpoint**: All three P1/P2 stories (US1, US2, US3) are independently complete and verified. User Story 4 below is explicitly out of scope for implementation.

---

## Phase 6: User Story 4 - Operator changes the active answering provider without a full outage (Priority: P3) — BLOCKED, no implementation tasks

Per `plan.md`'s Complexity Tracking and `spec.md`'s own Assumptions, **FR-011** (the provider-switch interaction surface: CLI signal vs. HTTP admin endpoint vs. config-file watch) and **FR-012** (in-flight-job resolution policy: finish-on-old-provider vs. explicit-fail) are both marked `NEEDS CLARIFICATION` in spec.md, and neither is designed in plan.md or data-model.md (data-model.md §5 names the `Provider Switch Request` entity "for completeness" only and explicitly states it is "not designed"). Writing implementation tasks against an undesigned interaction surface and an undecided in-flight-job policy would assert a settledness neither document claims — a §11.4.6 violation. None are written here.

- [ ] **T022 [BLOCKED] [US4]** FR-011 (provider-switch interaction surface) requires an explicit operator decision before any implementation task can be written. Not actionable.
- [ ] **T023 [BLOCKED] [US4]** FR-012 (in-flight-job resolution policy on a provider switch) requires an explicit operator decision before any implementation task can be written. Not actionable.

Once both are decided, re-plan this story via a `plan.md` revision — per plan.md's own stated resolution path ("A future plan revision resolves these once that operator input exists") — rather than retrofitting guessed tasks into this file.

---

## Phase 7: Polish

- [ ] **T024 [P]** Run the full post-feature regression suite: `cd workshop/platform/backend && go build ./... && go test ./pkg/answer/... -v -count=1 2>&1 | tail -60`. Paste the real pass/fail summary and compare the total test count against T001's baseline (expect it to have grown by exactly the tests added in T002, T007, T010, T013, T015, T017, T020, minus `TestOpenAICompatibleStillRequiresTheRemoteOptIn`'s removal in T019).
- [ ] **T025 [P]** Run `platform/gates/prove-answer-provider-selection.sh` and `platform/gates/verify-answer-provider-selection.sh` (both pre-existing; plan.md's Project Structure records them as growing automatically once the two new rows land, needing no edit). Paste real output confirming both gates cover `openai`, `anthropic`, and `openai_compatible_lan` with zero gate-file edits having been required.
- [ ] **T026** Update this module's operator-facing findings log (`docs/work-register.md`, per this module's existing convention) recording: the catalogue now totals 35 rows (was 33; `openai_compatible` removed, `openai`/`anthropic`/`openai_compatible_lan` added, net +2); T009's fail-open/fail-closed audit decision and whether it is operator-confirmed or still a pending default; and which of T006/T014/T021's operator-gated real-endpoint runs were actually exercised versus deferred for lack of a real key or a real LAN server.
- [ ] **T027** Re-check this feature's flagged Constitution anchors (§11.4.10, §11.4.74, §11.4.252, §11.4.6, §11.4.201 — see plan.md's Constitution Check table) against the diff as actually landed, not as planned, and record any divergence found.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependency — T001 first.
- **Foundational (Phase 2)**: empty — does not block anything.
- **User Story 1 (Phase 3)**: depends only on Phase 1 (T001's baseline). No dependency on US2 or US3.
- **User Story 2 (Phase 4)**: depends only on Phase 1. Genuinely independent of US1 — it wires into `hosted.go`'s existing shared path, which already covers the 28 pre-existing hosted rows; it does not need the two new rows to exist to be tested.
- **User Story 3 (Phase 5)**: depends only on Phase 1. Independent of US1 and US2. T019 (removing `openai_compatible`) and T016 (adding `KindLAN` to the `Kind` switch) both touch `registry.go`, the same file T003 (US1) edits — see Parallel Execution Notes below for the sequencing this implies.
- **User Story 4 (Phase 6)**: blocked; no tasks execute.
- **Polish (Phase 7)**: depends on whichever of US1/US2/US3 were completed (T024's baseline comparison is only meaningful once all three have landed; run it last).

### Within Each User Story

- RED tests before GREEN implementation (T002→T003, T007→T008, T010→T011, T013's RED/GREEN pair, T015→T016, T017→T018, T020's RED/GREEN pair).
- A story's [REVIEW]-marked task (T004 for US1, T009 and T014 for US2, T021 for US3) gates that story's checkpoint — do not mark a story's checkpoint reached until its [REVIEW] task's completion note is real, not asserted.

### Parallel Opportunities

- T002 (US1), T007 (US2), and T015 (US3) touch three different files (`registry_test.go`'s new function, the new `audit_test.go`, and `provider_test.go`'s extension respectively) and may be written in parallel.
- T006, T014, and T021's OPERATOR-GATED real-endpoint runs may all be dispatched in parallel once their respective story's non-gated tasks are green — they depend on external credentials/hardware, not on each other.
- T024-T027 (Polish) marked `[P]` may run in parallel with each other once all prior phases are done; T026 and T027 are not `[P]` because they depend on reading the real, landed outcome of the gated tasks and the review tasks respectively.

### File-Overlap Sequencing (read before dispatching parallel subagents)

`registry.go` is touched by **T003** (US1: add two `hosted(...)` rows), **T016** (US3: add `KindLAN` to the `Kind` const block and the `TestCatalogueIsCoherent` switch), and **T019** (US3: remove the `openai_compatible` row). Per this repository's own subagent-driven-development convention (see spec 009's tasks.md Parallel Execution Notes), **do not dispatch T003 and T016/T019 to two concurrent subagents** — sequence them (T003 first is arbitrary but simplest, since US1 and US3 are otherwise independent), or hand the whole small sequence to one subagent. `registry_test.go` has the same overlap between T002 (US1) and T016's `TestCatalogueIsCoherent` edit (US3) — same rule applies. `hosted.go` is touched only within US2 (T011), so US1 and US3 do not conflict with it.

---

## Parallel Example: User Story 2 (fully independent of US1/US3)

```bash
# Launch US2's RED test-writing task on its own, since it touches only new files:
Task: "T007 — create audit_test.go with failing tests for RemoteGenerationAuditRecord / writeAuditRecord"

# Once T007 is RED and confirmed, T008 (GREEN) proceeds; T009's REVIEW task can be
# drafted in parallel with T008 since it is a design-decision write-up, not code.
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. T001 (baseline).
2. Phase 3 (T002-T005; T006 optional).
3. **STOP and VALIDATE**: `go test ./pkg/answer/... -v` green, T004's pasted output shows real `openai`/`anthropic` subtests passing.
4. This is a legitimate, independently shippable MVP — two more selectable providers, every existing safeguard inherited, per-generation audit not yet added.

### Incremental Delivery

1. T001 → Phase 3 (US1) → validate → ship.
2. Phase 4 (US2) → validate independently (does not require US1) → ship — closes the process-wide-vs-per-generation audit gap for all 30 hosted rows at once.
3. Phase 5 (US3) → validate independently → ship — closes the `openai_compatible` permanent-stub violation (FR-010) as a side effect, which is why this story is not deferred alongside US4 even though it is lower priority.
4. Phase 6 (US4) stays blocked until FR-011/FR-012 are decided by the operator; it is not on this delivery path.
5. Phase 7 (Polish) runs once whichever of US1-US3 are in scope for a given release have landed.

### Parallel Team Strategy

With more than one agent/developer available:

1. One stream takes US1 (Phase 3) — touches `registry.go`, `registry_test.go`.
2. A second stream takes US2 (Phase 4) — touches `audit.go` (new), `audit_test.go` (new), `hosted.go`, `main.go`, `redaction_log.go`-adjacent code — no file overlap with US1.
3. A third stream takes US3 (Phase 5) — touches `locality.go`, `provider_test.go`, `llamacpp.go`-adjacent new code, and `registry.go`/`registry_test.go` (overlapping US1's stream — see "File-Overlap Sequencing" above; coordinate the `registry.go` edits between streams 1 and 3 rather than letting them race).
4. All three converge at Phase 7.
