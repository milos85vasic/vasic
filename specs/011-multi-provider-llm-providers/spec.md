# Feature Specification: Multi-Provider LLM Abstraction — Remote, LAN, and Audited Generation

**Feature Branch**: `011-multi-provider-llm-providers`

**Created**: 2026-09-30

**Status**: Draft

**Input**: Formalization of `workshop/docs/research/education-platform/multi-provider-llm-and-content-model.md`, Part A only (Part B — the universal content model and user profile page — is formalized separately as spec 015-universal-content-model-profile and is referenced here by name, not re-specified).

## Summary

The workshop curriculum platform's answering backend (`platform/backend/pkg/answer`) already
ships a real, table-driven, 33-row provider registry
(`platform/backend/pkg/answer/registry.go:169-259`) built on the already-adopted
`submodules/LLMProvider` library, rather than an Ollama-only path. It already supports a
built-in `none` (no-model) provider, a loopback-enforced local OpenAI-compatible server
(`llamacpp`), a local `ollama` row, and 28 hosted third-party vendor rows, all behind one shared
`HostedProvider` implementation (`platform/backend/pkg/answer/hosted.go`) that enforces
remote opt-in, locality agreement, credential scrubbing, and health-check-before-use
uniformly. This feature formalizes the three concrete, phased extensions the research
identified as real gaps rather than architecture that needs inventing: (1) wiring OpenAI and
Anthropic — whose adapters already exist in `submodules/LLMProvider` — as two more catalogue
rows, plus closing the process-wide-vs-per-generation opt-in gap with a per-generation audit
log; (2) extending the locality model to a genuine LAN (operator-controlled, non-loopback)
case, which today has no working path; (3) removing the current full-server-restart
requirement for changing the active answering provider. Every requirement below is grounded
in the research document's own file:line citations against the real codebase, re-verified in
this session where noted.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Operator turns on OpenAI or Anthropic as the answering provider (Priority: P1)

An operator who has decided the privacy tradeoff of a hosted provider is acceptable for their
deployment (per the existing 2026-09-25 decision to keep answering off by default,
`WORKSHOP_ANSWER_PROVIDER=none`) wants to point `workshop-server` at OpenAI or Anthropic
instead of a local model, using their own API key, and get real generated answers through the
platform's existing `/api/ask` flow — with every existing safeguard (opt-in gate, locality
check, credential scrubbing, health-check) applying automatically, because those safeguards
live in the shared `HostedProvider`, not per-row.

**Why this priority**: The research's own headline finding is that this is "the single most
concrete, lowest-risk action item this document identifies"
(`multi-provider-llm-and-content-model.md:179-180`) — LLMProvider's `openai` and `anthropic`
adapter packages already exist and compile
(`submodules/LLMProvider/pkg/providers/openai/openai.go`,
`.../pkg/providers/anthropic/anthropic.go`), and adding them is "two more `hosted(...)` table
rows... no new architecture, no new refusal logic, no new privacy gate"
(`multi-provider-llm-and-content-model.md:176-178`). It delivers real, independently-usable
value (two additional real providers, still gated by the existing opt-in) with the smallest
possible change.

**Independent Test**: Start `workshop-server` with `-answer-provider openai
-answer-allow-remote -answer-model gpt-4o` and a valid `ApiKey_OpenAI` environment variable set;
submit a real question through `/api/ask`; confirm a real, non-`none`/non-`extractive` answer
is returned, the response descriptor names `openai` as the provider, and repeat for
`-answer-provider anthropic` with `ApiKey_Anthropic` and an Anthropic model id. Both can be
tested independently of Stories 2 and 3 and of spec 015.

**Acceptance Scenarios**:

1. **Given** `workshop-server` started with `-answer-provider openai -answer-allow-remote
   -answer-locality remote -answer-model <a valid OpenAI chat model id>` and `ApiKey_OpenAI`
   set to a valid key, **When** an authenticated `POST /api/ask` request is submitted,
   **Then** the system returns a generated answer (not a `no_provider`/`503` response), and the
   answer's descriptor names provider `openai`, the configured model, and locality `remote`
   (mirroring `hosted.go:240-249`'s existing descriptor behavior).
2. **Given** the same setup but with `-answer-provider anthropic` and `ApiKey_Anthropic` set,
   **When** a request is submitted, **Then** the system returns a generated answer with a
   descriptor naming provider `anthropic`.
3. **Given** `-answer-provider openai` configured but `-answer-allow-remote` NOT set, **When**
   a request is submitted, **Then** the system refuses before any credential read, DNS lookup,
   or health probe (matching the existing "REFUSAL 1" behavior at `hosted.go:96-107`), exactly
   as it already does for every other hosted row.
4. **Given** `-answer-provider openai` configured with no `ApiKey_OpenAI` environment variable
   set, **When** a request is submitted, **Then** the system refuses with a `Reason` naming the
   missing credential, never sending a request to OpenAI with an empty or absent key.
5. **Given** an OpenAI or Anthropic upstream call returns an error containing the caller's API
   key in its error text, **When** that error is surfaced to the system's logs or `Reason`,
   **Then** the key is scrubbed (per the existing `HostedProvider.scrub`, `hosted.go:224-233`),
   never appearing in a log line or response.
6. **Given** `answer-providers --names` (or equivalent operator-facing provider listing) is run
   after this change, **When** its output is inspected, **Then** `openai` and `anthropic`
   appear in the selectable-provider list alongside the existing 28 hosted vendors, `ollama`,
   `llamacpp`, `none`, and `extractive`.

---

### User Story 2 - Every remote generation is individually audit-logged (Priority: P1)

An operator running a hosted provider (OpenAI, Anthropic, or any of the other 28 vendor rows)
wants a per-request, append-only audit trail of exactly when private content was sent to a
remote provider — not just the coarse fact that remote answering was enabled for the life of
the server process. Today, `-answer-allow-remote` is "process-wide and per-server-start... once
set, every `/api/ask` request for the life of that server process may reach the configured
hosted provider, with no further confirmation and no per-request audit log beyond whatever the
platform's general HTTP access logging captures"
(`multi-provider-llm-and-content-model.md:437-444`).

**Why this priority**: This is the research's named concrete gap against the task's explicit
requirement for "a configuration-level gate requiring explicit operator opt-in per-generation
before any private content is sent to a remote provider, logged/auditable"
(`multi-provider-llm-and-content-model.md:439-441`). It is independently valuable and
independently testable without Story 1 being complete (it applies to every existing hosted row
today, not only the new OpenAI/Anthropic rows), though it is recommended to land "ahead of, or
alongside, actually turning either row on for real private content"
(`multi-provider-llm-and-content-model.md:865-866`).

**Independent Test**: Configure any existing hosted row (e.g. `groq`, already wired) with
remote opt-in enabled; submit several `/api/ask` requests; confirm one structured audit record
per remote generation attempt exists in a distinct, append-only log, each carrying session,
provider, model, endpoint, timestamp, and content byte-count — and confirm the record never
contains the request or response content itself.

**Acceptance Scenarios**:

1. **Given** a hosted provider configured with remote opt-in enabled, **When** a `/api/ask`
   request reaches `HostedProvider.Generate`, **Then** exactly one structured audit record is
   appended to a log distinct from general HTTP access logs, before or as part of the
   generation attempt.
2. **Given** an audit record for a remote generation attempt, **When** its fields are
   inspected, **Then** it contains session identifier, provider name, model name, endpoint,
   timestamp, and content byte-count, and it does NOT contain the prompt text, the retrieved
   passage content, or the generated answer text.
3. **Given** a generation attempt that fails (health check failure, credential missing, or
   upstream error), **When** the audit log is inspected, **Then** the attempt is still recorded
   (an audit record marks an *attempt*, not only a success).
4. **Given** `-answer-provider none` or a local provider (`ollama`, `llamacpp`), **When**
   requests are submitted, **Then** no remote-generation audit record is written (the log is
   scoped to hosted/remote rows only, matching `RequiresRemoteOptIn()`'s existing Kind-derived
   scoping at `registry.go:150-153`).

---

### User Story 3 - Operator points the platform at a model server on their own LAN (Priority: P2)

An operator runs a model server (llama.cpp's server mode, LM Studio's local server, or a second
machine's Ollama instance) on another machine on their own network — infrastructure they
administer, not a third party's service — and wants the platform to use it without either (a)
being refused the way `llamacpp` refuses any non-loopback address today, or (b) being forced
through the third-party hosted-provider opt-in path meant for services the operator does not
control.

**Why this priority**: This is Phase 2 of the research's own phased breakdown
(`multi-provider-llm-and-content-model.md:868-871`) — real, but explicitly lower priority than
Phase 1, and explicitly deferrable: "`llamacpp` already covers same-host and the 28+2 hosted
rows already cover third-party-with-consent" so this phase is only needed "if local-network
model support is wanted before a full LAN-OpenAI-compatible path is needed"
(`multi-provider-llm-and-content-model.md:869-871`). It is independently testable and
independently valuable without Stories 1 or 2.

**Independent Test**: Run an OpenAI-compatible model server (llama.cpp server mode or
equivalent) on a second machine on the same LAN; configure `workshop-server` with the new LAN
locality pointed at that machine's address; submit a request; confirm generation succeeds with
no remote-provider opt-in flag required, and confirm the descriptor records locality as `lan`,
distinct from both `local` and `remote`.

**Acceptance Scenarios**:

1. **Given** an OpenAI-compatible model server reachable at a non-loopback address the operator
   has explicitly declared as a LAN endpoint, **When** `workshop-server` is configured with the
   new LAN locality value pointed at that address, **Then** generation succeeds without
   `-answer-allow-remote` being required.
2. **Given** the same LAN configuration, **When** a request completes, **Then** the response
   descriptor records the declared locality as `lan` (not silently reported as `local` or
   `remote`), per the existing design principle that "a name that nobody chose makes that field
   a guess" (`hosted.go:125-131`, cited at
   `multi-provider-llm-and-content-model.md:329-330`).
3. **Given** an operator declares a non-loopback address with locality `local` (not `lan`),
   **When** the system validates the configuration, **Then** it is refused exactly as
   `llamacpp`'s existing loopback enforcement already refuses a non-loopback address declared
   `local` today (`llamacpp.go:16-33`) — LAN reachability is never silently inferred from a
   `local` declaration.
4. **Given** the existing `openai_compatible` catalogue row, **When** this feature's LAN support
   ships, **Then** the row either becomes real (constructs a working provider against a
   declared non-loopback OpenAI-compatible endpoint) or the LAN locality is served by a
   distinct row reusing `llamacpp.go`'s transport minus its loopback-only dial check — but in
   either case `openai_compatible` MUST NOT continue silently listed as selectable while still
   returning `CodeProviderDisabled` for every real LAN address (closing the "standing
   honest-boundary risk" the research names at
   `multi-provider-llm-and-content-model.md:847-853`).

---

### User Story 4 - Operator changes the active answering provider without a full outage (Priority: P3)

An operator wants to switch which provider is answering questions (e.g. from `ollama` to
`openai`, or between two hosted vendors) without taking `/api/ask` fully offline for the
duration of a server restart, and without silently migrating an in-flight generation job to a
different model mid-stream.

**Why this priority**: This is Phase 3 in the research's own breakdown — explicitly the last
phase, and explicitly gated on real design work the research does not complete: "the codebase's
own stated preference (no silent substitution) argues against a design that transparently
migrates an in-flight generation to a different model mid-stream"
(`multi-provider-llm-and-content-model.md:830-834`). It is the smallest-value, most
architecturally open story of the four and is included so the phased roadmap is complete, not
because it is ready to implement without further design clarification (see NEEDS
CLARIFICATION below).

**Why this priority, continued**: Today, "changing the configured provider... requires a full
server restart, and any in-flight `/api/ask` job is lost (subsequent polls 404
`job_not_found`)... this is real, already-documented behavior, not a hypothetical risk"
(`multi-provider-llm-and-content-model.md:822-826`), because `pkg/answer/jobs.go` states jobs
are "in-memory and single-machine" and "a job id does not survive a restart"
(`jobs.go:16-19`, cited at `multi-provider-llm-and-content-model.md:820-822`).

**Independent Test**: With the platform running and an in-flight `/api/ask` job outstanding,
issue a provider-switch action (operator command, API call, or config-reload signal — exact
mechanism is a `NEEDS CLARIFICATION` item below); confirm the previously in-flight job either
completes on its original provider or fails with an explicit, distinguishable status (never
silently answered by the newly-configured provider), and confirm a subsequent new request is
served by the newly-configured provider without a process restart.

**Acceptance Scenarios**:

1. **Given** `workshop-server` running with provider A configured and an `/api/ask` job
   in-flight, **When** an operator issues a provider switch to provider B, **Then** the
   in-flight job either completes on provider A or is explicitly failed/cancelled with a status
   distinguishable from a normal completion — it is never silently completed using provider B's
   output.
2. **Given** a provider switch has completed, **When** a new `/api/ask` request is submitted,
   **Then** it is served by the newly-configured provider, with no `workshop-server` process
   restart having occurred.
3. **Given** a provider switch is requested to a provider that fails its health check (bad
   credential, unreachable endpoint), **When** the switch is attempted, **Then** the switch is
   refused and the previously-active provider remains configured and serving — a failed switch
   attempt MUST NOT leave the system in a state with no working provider configured.

---

### Edge Cases

- What happens when an operator sets `-answer-provider openai` with a model id that does not
  exist on OpenAI's side (e.g. a typo)? → The existing health-check-before-use and
  upstream-error-surfacing behavior applies unchanged (`hosted.go`'s existing refusal path);
  this feature introduces no new model-validation logic beyond what every other hosted row
  already has.
- What happens when both `ApiKey_OpenAI` and `ApiKey_Anthropic` are set but only one provider
  is configured via `-answer-provider`? → Only the configured provider's credential is read;
  the other is ignored, matching the existing per-row credential-lookup pattern
  (`apikeys.go:31-58`) that scans for the specific `ApiKey_<Provider>` name the active row
  declares.
- What happens to the per-generation audit log (Story 2) when the disk backing it is full or
  unwritable? → `NEEDS CLARIFICATION: should an audit-log write failure block the generation
  attempt (fail closed) or allow the generation to proceed with the failure itself logged
  through the general error path (fail open)? The research does not resolve this; the
  codebase's general philosophy is "an outage is visible, a silent substitution is worse"
  (hosted.go:43-44), which argues for fail-closed, but this is a genuine operator-facing
  tradeoff between availability and audit completeness that this spec does not decide
  unilaterally.`
- What happens when an operator declares an address as `lan` locality that turns out to resolve
  to a public, non-operator-controlled IP? → `NEEDS CLARIFICATION: should LAN locality
  validation include any reachability/ownership check beyond "not loopback", or is the
  operator's explicit declaration the sole basis for trust (mirroring how declared `remote`
  opt-in already trusts the operator's own decision with no further verification)? The research
  proposes the locality value as a trust signal the operator states, not a property the system
  independently verifies (multi-provider-llm-and-content-model.md:314-322), but does not
  explicitly rule out an ownership check.`
- What happens when a provider-switch (Story 4) is requested while the platform has zero
  in-flight jobs? → The switch proceeds with no special in-flight-job handling needed; this is
  the common case and should not be gated behind any job-draining logic that only matters when
  jobs are actually outstanding.
- What happens to cost exposure once OpenAI/Anthropic rows are wired and turned on for real
  traffic? → Out of scope for this feature's functional requirements (see Assumptions): the
  research confirms "the codebase currently has no cost-tracking, budget-cap, or per-request
  cost estimate anywhere in `pkg/answer`"
  (`multi-provider-llm-and-content-model.md:395-398`) and recommends a request-count cap as a
  reasonable low-effort addition, but that addition is not part of this spec's requirements.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide `openai` and `anthropic` as selectable values for
  `-answer-provider` (and its `WORKSHOP_ANSWER_PROVIDER` environment-variable equivalent),
  constructed as additional rows in the existing provider catalogue
  (`platform/backend/pkg/answer/registry.go`), following the exact `hosted(...)` construction
  pattern every one of the 28 existing hosted rows uses, consuming
  `submodules/LLMProvider/pkg/providers/openai` and `.../pkg/providers/anthropic` respectively.
- **FR-002**: When `-answer-provider openai` (or `anthropic`) is configured together with
  `-answer-allow-remote`, a declared `remote` locality, and a valid provider-specific API key
  (read via the existing `ApiKey_<Provider>` environment-variable convention,
  `apikeys.go:31-58`), the system MUST allow an operator to receive real generated answers
  through the existing three-state answer-outcome model (answered / declined / withheld, per
  the existing `/api/ask` contract) with no new refusal, scrubbing, or opt-in logic beyond what
  `HostedProvider` already applies to every hosted row.
- **FR-003**: The system MUST apply every one of the four existing hosted-row safeguards
  (explicit per-process remote opt-in before any credential read, DNS lookup, or health probe;
  locality-must-agree-with-intent; credential scrubbing from every error path; provider/model/
  locality named on every answer's descriptor — `hosted.go:9-44, 96-233, 240-249`) to the new
  `openai` and `anthropic` rows automatically, with zero row-specific reimplementation of any
  of the four.
- **FR-004**: The system MUST record one structured, append-only audit entry per individual
  remote-generation attempt (not per server-process-lifetime), distinct from general HTTP
  access logs, for every hosted-provider row (existing 28 rows plus the two new ones), whenever
  remote opt-in is enabled and a generation attempt is made — whether that attempt succeeds,
  fails a health check, or fails with an upstream error.
- **FR-005**: Each audit entry produced under FR-004 MUST contain, at minimum: session
  identifier, provider name, model name, target endpoint, timestamp, and the content
  byte-count of the request — and MUST NOT contain the request prompt text, retrieved passage
  content, or generated answer text. **[NEEDS CLARIFICATION: the research names this minimum
  field set (multi-provider-llm-and-content-model.md:448-451) but does not define the exact
  on-disk schema (file format — JSON Lines vs. a dedicated store; field names; whether it
  reuses or parallels the existing `internal/answering/redaction` audit pattern the research
  gestures at). This must be decided before implementation, following whichever existing
  audit-logging convention this codebase already has for answered-job auditing.]**
- **FR-006**: The system MUST introduce a third locality value, distinct from `local` and
  `remote`, denoting an operator-controlled, non-loopback network endpoint (referred to here as
  `lan`), as an extension of `ProviderConfig.Locality` and `VerifyLocality`
  (`multi-provider-llm-and-content-model.md:489-508`).
- **FR-007**: A provider declared with `lan` locality MUST NOT require `-answer-allow-remote`
  opt-in (matching the research's reasoning that operator-administered infrastructure is not
  the same privacy risk class as a third party's service), but the locality value `lan` MUST be
  explicitly declared by the operator — it MUST NEVER be silently inferred from an address that
  happens not to be loopback.
- **FR-008**: A provider declaring locality `local` MUST continue to be refused if its resolved
  endpoint address is not loopback, exactly as `llamacpp`'s existing three-layer loopback
  enforcement already does (`llamacpp.go:16-33`) — introducing `lan` MUST NOT weaken the
  existing `local` guarantee.
- **FR-009**: The system MUST provide a real, working construction path for an
  OpenAI-compatible model server reachable at a declared `lan`-locality, non-loopback address —
  either by completing the existing `openai_compatible` stub
  (`pkg/answer/ollama.go:476-493`, currently hardcoded to always return
  `CodeProviderDisabled`) or by introducing a distinct catalogue row that reuses
  `llamacpp.go`'s OpenAI-compatible transport with its loopback-only dial check removed.
- **FR-010**: The system MUST NOT list any provider row as selectable (via
  `RegisteredProviders()` / `answer-providers --names` or equivalent) while that row is, in
  fact, a permanent stub that always refuses — either the `openai_compatible` row becomes real
  under FR-009, or its stub status MUST be visibly distinguished from a working row in whatever
  surfaces the selectable-provider list to an operator.
- **FR-011**: The system MUST provide an operator-initiated mechanism to change the active
  answering provider's configuration while `workshop-server` continues running, without
  requiring a full process restart. **[NEEDS CLARIFICATION: the research explicitly defers the
  exact mechanism (`multi-provider-llm-and-content-model.md:827-834`) — options named are (a)
  a hot-reloadable `ProviderConfig` via an admin API/signal, or (b) some other reload trigger;
  neither is designed. The interaction surface (CLI signal, HTTP admin endpoint, config-file
  watch) must be decided before implementation.]**
- **FR-012**: When a provider switch (FR-011) occurs while an `/api/ask` job is in-flight on the
  previously-active provider, the system MUST NOT silently complete that job using the newly-
  configured provider's output — the in-flight job MUST either run to completion on its
  original provider or be explicitly failed/cancelled with a status distinguishable from a
  normal completion. **[NEEDS CLARIFICATION: the research states the codebase's existing
  philosophy argues against transparent mid-stream migration but explicitly does not choose
  between "finish on the old provider" and "fail them explicitly"
  (`multi-provider-llm-and-content-model.md:828-830`) — this decision is a prerequisite for
  implementing FR-012, not merely an implementation detail.]**
- **FR-013**: A provider-switch attempt (FR-011) to a provider configuration that fails its
  construction or initial health check MUST be refused, and the system MUST continue serving
  requests using the previously-active, still-valid provider configuration — a failed switch
  attempt MUST NOT leave the system with no working provider configured.
- **FR-014**: The system's provider catalogue and its selectable-name listing (`registry.go`'s
  `catalogue` slice and `RegisteredProviders()`) MUST remain derived from the same single data
  table for every provider added under this feature, preserving the existing guarantee that "a
  gate that enumerates providers and the constructor that builds them cannot drift apart"
  (`registry.go:9-27, 290-298`, cited at `multi-provider-llm-and-content-model.md:51-55`) — this
  feature MUST NOT reintroduce a hand-written switch or a second, separately-maintained list of
  provider names anywhere.

### Key Entities *(include if feature involves data)*

- **Provider Registration**: An existing entity (`Registration` in `registry.go`) — one row per
  constructible answering provider, carrying its name, display name, construction function, and
  `Kind` (which drives whether remote opt-in is required). This feature adds two new rows
  (`openai`, `anthropic`) and extends `Kind`'s vocabulary to distinguish a LAN-locality row from
  a loopback-local or third-party-hosted one.
- **Remote-Generation Audit Record**: A new entity, one per individual remote-generation
  attempt — session, provider, model, endpoint, timestamp, content byte-count. Explicitly
  excludes prompt, retrieved-passage, and answer content. Distinct from, and additional to, the
  platform's existing general HTTP access logs.
- **Provider Locality**: An existing but currently two-valued concept
  (`ProviderConfig.Locality`, checked by `VerifyLocality`), extended by this feature to a
  third value (`lan`) denoting an operator-controlled, non-loopback network endpoint, alongside
  the existing `local` (loopback-enforced) and `remote` (third-party, opt-in-required) values.
- **Provider Switch Request**: A new entity representing an operator-initiated request to
  change the active `ProviderConfig` without a process restart, and its outcome (applied /
  refused-with-reason), including how any job in-flight at the moment of the switch is
  resolved.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can configure `workshop-server` with `-answer-provider openai` (or
  `anthropic`), a valid API key, and remote opt-in, and receive a real generated answer through
  `/api/ask` — verified by at least one end-to-end request against each of the two new
  providers returning a non-`none`/non-`extractive`, non-error answer.
- **SC-002**: 100% of requests made to the two new hosted rows while remote opt-in is NOT
  enabled are refused before any network call is made to the provider (verified by absence of
  any outbound HTTP request to the provider's API host in that scenario).
- **SC-003**: 100% of remote-generation attempts, across all 30 hosted rows (28 existing + 2
  new), while remote opt-in is enabled, produce exactly one audit record each, verifiable by
  comparing the count of generation attempts made in a test run against the count of audit
  records produced.
- **SC-004**: 0% of audit records produced under SC-003 contain the request prompt text, the
  retrieved passage content, or the generated answer text, verified by inspecting a sample of
  audit records against the corresponding request/response pairs.
- **SC-005**: An operator can reach a real, working OpenAI-compatible model server on another
  machine on their own network and receive generated answers from it, with zero
  `-answer-allow-remote` flag set, verified by one end-to-end request against a LAN-declared
  endpoint.
- **SC-006**: An operator can change the active answering provider while `workshop-server`
  continues serving `/api/ask` for other, unrelated requests throughout the change, verified by
  measuring zero request-serving downtime (excluding the switched job itself) across a
  provider-switch event in a test run.
- **SC-007**: 0% of in-flight jobs present at the moment of a provider switch are silently
  completed using the newly-configured provider's output, verified by inspecting the recorded
  provider descriptor on every job that was in-flight at switch time.
- **SC-008**: The operator-facing selectable-provider listing never includes a row that always
  refuses every real request (i.e., the `openai_compatible` permanent-stub state is fully
  resolved, either by completion or by visible stub-marking), verified by attempting a
  construction/health-check against every listed row and confirming no row that reports
  "selectable" also reports "always refuses."

## Assumptions

- The privacy-safeguard mechanism this feature extends (opt-in gate, locality check, credential
  scrubbing, health-check-before-use) is already correct and sufficient as a *process-wide*
  control; this feature's scope is narrowing its granularity (per-generation audit) and
  broadening its locality vocabulary (LAN), not redesigning the mechanism itself.
- The 2026-09-25 operator decision to keep answering OFF by default
  (`WORKSHOP_ANSWER_PROVIDER=none`, following the SC-010/SC-094 fabrication-avoidance
  measurement recorded in `workshop/CLAUDE.md`) is unaffected by this feature and is not
  reopened here — this feature makes OpenAI/Anthropic *available* as configuration options, it
  does not change the platform's default or re-litigate whether answering should be on.
- Cost-tracking, budget caps, and per-request spend estimation for hosted-provider usage are
  explicitly out of scope for this feature (see Edge Cases); the research names this as a real
  gap worth closing "before an `openai`/`anthropic` row goes from 'constructible' to 'operator
  actually turns it on'" for production use, but it is a separate, not-yet-scoped follow-up.
- Embeddings remain out of scope: `pkg/embed`'s Ollama-only implementation is unaffected by
  this feature, which concerns the `pkg/answer` generation path only (the research documents
  this as a "genuinely new upstream contribution" candidate for `submodules/LLMProvider`
  itself, separate from this feature — `multi-provider-llm-and-content-model.md:516-524`).
- This feature does not specify or depend on the universal content model or user profile page
  (spec 015-universal-content-model-profile); any future free-text-grading or
  content-generation feature that would introduce a new model dependency is expected to route
  through this same `answer.Provider` abstraction, including its `none` default, per the
  research's own recommendation (`multi-provider-llm-and-content-model.md:260-266`), but that
  is not this feature's concern.
- `submodules/LLMProvider`'s `openai` and `anthropic` adapter packages' exact exported
  constructor names will be confirmed at implementation time (the research notes they are not
  uniform across all 28 existing rows, e.g. `cerebras.NewCerebrasProvider` vs.
  `chutes.NewProvider` — `multi-provider-llm-and-content-model.md:479-481`); this is an
  implementation detail, not a design decision this spec needs to resolve.
- Story 4 (provider switching) is included for phase-roadmap completeness per the research's
  own three-phase breakdown, but its two `NEEDS CLARIFICATION` items (FR-011, FR-012) are
  expected to require operator/design input before implementation begins — this story is not
  blocking Stories 1-3, which are independently shippable ahead of it.
