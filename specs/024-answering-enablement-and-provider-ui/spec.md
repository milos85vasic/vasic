# Feature Specification: Answering Enablement + Provider Status UI (measured, two-sided gate)

**Feature Branch**: `024-answering-enablement-and-provider-ui`

**Created**: 2026-10-20

**Status**: Draft

**Input**: Operator brief (2026-10-20): "Answering is OFF by default (`compose.yml` answer-provider
`none`; `/api/ask` returns 503 `no_provider`; SC-010 'decline 100% of unanswerable' is UNMET with
measured 19.4% answerable / 4.6% fabrication). Spec how to safely ENABLE answering: an
operator-visible provider settings/status UI (selectable providers from the spec 011 catalogue,
current provider, health, remote-vs-local/LAN badge, audit-log summary), gating by a measured
regression/calibration check (two-sided: answers what is answerable AND declines what is not), the
fix path for the known fabrication cases, and keeping browse/search unaffected. Never enable by
default without the measured gate."

**Builds on**: `specs/011-multi-provider-llm-providers` (provider catalogue; US2 audit log and US3
`lan` locality are SOFT dependencies, see Dependencies), `specs/001-workshop-curriculum-platform`
(the L1-L5 answering pipeline, FR-051, SC-009, SC-010/SC-094), `specs/017-exhaustive-rag-expansion`
(retrieval changes that move the measured numbers). Closes the Jordan-client requirements-document
items REQ-5 (trust discipline visible to the operator) and the operator-facing half of REQ-6
(provider choice and data-locality visibility); it does NOT build the learning-medium or
generation features (those are separate, unspecced).

**Content boundary**: `workshop/` is a PRIVATE submodule. This public spec carries counts, paths and
mechanism names only. The fabricated benchmark questions, their cited passages and the answer text
are NOT reproduced here; they are referenced as `F1`/`F2`/`F3` in
`workshop/platform/backend/evidence/answering/fabrications-generation-15-2026-09-24.md`.

## Measured baseline (informational, every figure re-derivable; UNCONFIRMED where stated)

| Fact | Evidence |
|---|---|
| Answering is OFF by default: compose passes `-answer-provider ${WORKSHOP_ANSWER_PROVIDER:-none}`; the live container runs `-answer-provider none`; `GET /api/ask` returns HTTP 503 with `reason.code no_provider` | `workshop/platform/compose.yml:553-554`; `pkg/answer/outcome.go:186` (`CodeNoProvider`); `internal/answering/wire.go:27-28`; architecture baseline (cmdline of the live process) |
| The decision to turn it OFF (2026-09-25) rests on a measurement: deployed funnel answers **14 of 72 = 19%** (Wilson 95%: 12-30%) of the 24 original answerable questions (3 repeats) and fabricates **4 of 87 = 4.6%** (2-11%) of 29 unanswerable trials; the 4 are concentrated in **2 of 29 questions** (3 trials of one deterministic question, 1 of another) | `workshop/platform/backend/evidence/answering/MEASUREMENT-generation-15-2026-09-24.md` §1 |
| `calibrated: true` on `/api/ask/status` means only `min_score > 0`, not that anyone measured anything | same file "Read this first"; `pkg/answer/pipeline.go:31` (`Thresholds.Calibrated`) |
| Retrieval-gate score/margin carry almost no signal once benchmark labels are corrected (top-score AUC 0.497, margin AUC 0.491 in the sensitivity reading) | MEASUREMENT file §2.1 |
| Only the entailment-based L4 reached 0 fabrication (0 of 87) and it did so at 8% recall; the Ollama LLM judge gave 0 fabrication at 0% recall | MEASUREMENT file §1 table |
| The benchmark itself is small and was contaminated: 24 A / 33 U as written, 29 U after dropping 4 contaminated rows, 9 U rows later found answerable | MEASUREMENT file header and §6; `workshop/platform/backend/testdata/benchmark/questions.tsv` (166 lines incl. comments) |
| A measurement harness exists and refuses to produce a table of 503s: it exits 2 unless the scratch server reports answering enabled | `workshop/platform/backend/gates/answer-eval/README.md` ("It measures answering only when answering is enabled"); `eval.sh`, `runbench.py`, `cmp.py` |
| An offline, no-model provider `extractive` exists, "cannot fabricate by construction" (every claim is a verbatim copy of request text) but does not synthesise | `pkg/answer/extractive.go:10-27`; `pkg/answer/registry.go:196` |
| The backend already exposes the facts a status UI needs: `GET /api/ask/status` returns `enabled`, `suspended`, `provider`, `model`, `endpoint`, `locality`, `locality_verified`, `calibrated`, `min_score`, `min_margin`, `generation`, `verifier_kind`, `question_verifier_kind` | `pkg/answer/http.go:651-720` |
| The provider catalogue is a single data table with `Registrations()`, `RegisteredProviders()`, `LookupProvider()`; kinds `builtin`/`local`/`hosted`; `openai_compatible` is an always-refusing stub | `pkg/answer/registry.go:86-94,102-127,342-365`; `pkg/answer/ollama.go:476-493` (per spec 011 FR-009/FR-010) |
| Frontend: no settings or providers route exists; the answering capability is read once on `/ask`; `/status` is the platform honesty page | `platform/frontend/src/app/app.routes.ts` route list; `features/inquiry/inquiry.component.ts:1284` (`askCapability()`); `core/status.component.ts` |
| Roles `admin` / `user` exist in the auth store | `pkg/authstore/authstore.go:47,54` (whether the frontend session exposes the role: UNCONFIRMED) |
| Spec 011 is 5/27 tasks done: only US1 (openai/anthropic catalogue rows) landed; US2 audit log, US3 LAN, US4 hot switch are not built | `specs/011-multi-provider-llm-providers/tasks.md`; commit `bb69fe5` |

## Clarifications

### Session 2026-10-20 (author-resolved from evidence; operator confirmation items are in "Open operator decisions")

- Q: Should the UI be able to switch the provider or turn answering on? → A: **No.** Spec 011 US4
  (hot switch) is explicitly blocked on unresolved design (011 FR-011/FR-012 `NEEDS CLARIFICATION`);
  and a UI "enable" button would be exactly the unmeasured default-enable the brief forbids.
  This feature ships a READ-ONLY status page plus a guarded, operator-run enable procedure.
- Q: Where does the gate live so it cannot be bypassed by prose? → A: At two mechanical seams: a
  boot-time check in the server (provider other than `none` is forced off unless a fingerprint-
  matching PASS verdict exists, FR-009) and the operator enable script (FR-017). Both read the
  same machine-written verdict (§11.4.236/§11.4.262).
- Q: Does enabling change browse/search? → A: It MUST NOT. Search, browse, transcripts and
  practice are independent of the answering provider (`internal/answering/wire.go:27-29` states a
  non-`none`/`none` choice "leaves every other route tree untouched"); FR-016 turns that claim
  into a test.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Operator can SEE the answering state and the provider (Priority: P1)

An operator opens a new "Answering & providers" page and immediately sees: is answering ON or OFF,
and if OFF exactly why (not configured / gate not cleared / suspended for ingest / provider
unhealthy); which provider and model are configured; whether the provider is local, on the LAN, or
remote (a badge that is verified, not guessed); the provider catalogue with each row's kind and
whether it is a working row or a stub; whether a credential is present (a yes/no, never the value);
the latest measured verdict for the current configuration; and, for administrators, a summary of the
remote-generation audit log. The `/ask` page, when answering is off, shows the same reason and a
link here instead of a generic failure.

**Why this priority**: Today the operator can see none of this. The only signal is a 503 on `/ask`
and a command line in a container. The brief's first requirement is operator-visible provider
state; it is also the surface every later story reports through, and it is read-only, so it is the
safest first increment.

**Independent Test**: With the live stack as it is today (answering OFF), log in and open
`/settings/providers`: the page shows state `off_by_config`, provider `none`, the catalogue rows,
the "no verdict" gate card, and `/ask` shows the same reason with a link to the page. Delivers value
with no other story.

**Acceptance Scenarios**:

1. **Given** the server runs with `-answer-provider none`, **When** an authenticated user opens
   `/settings/providers`, **Then** the state shows "OFF - not configured" with the closed-vocabulary
   code `off_by_config`, the page states that search and browse are unaffected, and no control on
   the page can change the provider.
2. **Given** any configured provider, **When** the page renders, **Then** it shows provider name,
   model, endpoint host (never a credential), declared locality and whether the locality was
   verified, as a badge reading local / LAN / remote / unverified, with text, not colour alone.
3. **Given** the catalogue, **When** the provider table renders, **Then** every row from
   `Registrations()` appears once with kind and upstream; a row that always refuses (stub) is marked
   as such and is not presented as selectable (spec 011 FR-010).
4. **Given** a provider whose credential environment variable is unset, **When** the table renders,
   **Then** the row says "credential: not present" and shows the variable NAME only; no value, no
   length, no prefix is ever returned or rendered.
5. **Given** an administrator and an existing audit log (spec 011 US2), **When** the page renders,
   **Then** it shows per-provider attempt counts and the most recent attempts' metadata (never
   prompt, passage or answer text); a non-administrator does not receive these rows from the API.
6. **Given** spec 011 US2 is not built, **When** the page renders, **Then** the audit card says
   "audit log not available on this build" (an absent state, not an empty list).
7. **Given** answering is off, **When** a user opens `/ask`, **Then** the existing unavailable state
   gains a visible reason and a link to the status page; the search tab on the same page keeps
   working.

---

### User Story 2 - Answering can only be enabled by a measured, two-sided gate (Priority: P1)

An operator who wants answering on runs one measurement command that exercises the exact
configuration they intend to run (provider, model, endpoint, thresholds, verifier layers, corpus
generation) against a labelled benchmark containing BOTH questions the corpus can answer and
questions it cannot. The command writes a machine-readable verdict. The server, at boot, refuses to
leave a non-`none` provider enabled unless a verdict exists whose fingerprint equals the running
configuration and whose result is PASS on BOTH sides: it answers enough of what is answerable AND
fabricates (statistically) none of what is not.

**Why this priority**: This is the operator's hard requirement ("Never enable by default without the
measured gate") and the measured history shows why a one-sided check fails: the entailment
configuration reaches 0% fabrication at 8% recall (useless) and the deployed one reaches 19% recall
at 4.6% fabrication (unsafe). A gate that checks only one side certifies one of these.

**Independent Test**: Feed the verdict validator four synthetic verdicts (high recall + high
fabrication; low recall + zero fabrication; both good; both good but stale fingerprint) and confirm
exactly the third passes; boot a scratch server with each and confirm answering is on only for the
third.

**Acceptance Scenarios**:

1. **Given** a measured run with fabrication Wilson upper bound above the fabrication limit,
   **When** the verdict is computed, **Then** it is FAIL with `failed_side: fabrication`, regardless
   of recall.
2. **Given** a measured run with recall Wilson lower bound below the recall floor, **When** the
   verdict is computed, **Then** it is FAIL with `failed_side: recall`, regardless of fabrication.
3. **Given** a PASS verdict, **When** any fingerprint input changes (provider, model, endpoint,
   `min_score`, `min_margin`, `min_support`, verifier kind, question-verifier kind, corpus root hash
   or benchmark hash), **Then** the verdict is STALE and the boot check treats it as no verdict.
4. **Given** `-answer-provider ollama` and no matching PASS verdict, **When** the server boots,
   **Then** it starts, search/browse work, answering is forced off, `/api/ask` returns 503
   `no_provider`, the reason detail says the gate is not cleared, and the overview reports
   `off_gate_not_cleared`.
5. **Given** a verdict file that is unparseable, truncated, or schema-invalid, **When** the server
   boots, **Then** it is treated as absent (fail closed), never as PASS.
6. **Given** benchmark and thresholds are data files, **When** a threshold is changed to make a
   failing run pass, **Then** the change alters the benchmark/thresholds hash, so previously issued
   verdicts become STALE and the change is visible in review (no silent loosening).
7. **Given** the measurement harness, **When** the target server reports answering disabled,
   **Then** it exits 2 (existing behaviour, preserved) and never produces a verdict.

---

### User Story 3 - The known fabrication cases are root-caused and closed (Priority: P2)

The three known fabrications (F1 deterministic at the deployed gate; F3 one of three repeats; F2
stopped only by the margin test) are reproduced on the broken configuration, root-caused layer by
layer, fixed, and kept forever as regression fixtures, without raising floors until recall falls to
zero.

**Why this priority**: The gate in Story 2 will keep failing until the pipeline stops fabricating on
the questions it currently fabricates on; this story is the fix path the brief asks for. It depends
on Story 2's harness for a trustworthy before/after, hence P2.

**Independent Test**: A fixture test replays F1 and F3 against the configuration that fabricated;
RED before the fix (observed `answered`), GREEN after (`declined`), with the same test file, and the
two-sided re-measure shows recall did not collapse.

**Acceptance Scenarios**:

1. **Given** the deployed configuration at the 2026-09-24 measurement, **When** F1 is replayed 3
   times, **Then** the harness reproduces `answered` (RED baseline recorded, §11.4.115) before any
   code changes.
2. **Given** the root-cause investigation (§11.4.102), **When** it concludes, **Then** a per-layer
   trace (retrieval gate, L3 citation, L4 support, L5 question-focus) shows which layer admitted each
   fabrication and why, citing code lines, with hypotheses explicitly marked UNCONFIRMED until the
   trace proves them.
3. **Given** a fix, **When** F1, F2, F3 are replayed (>= 3 repeats each), **Then** all are
   `declined` or `unavailable`, and the same fixture test that was RED is now GREEN.
4. **Given** a fix, **When** the benchmark v2 is re-measured, **Then** the recall lower bound does
   not fall below its value before the fix by more than the recorded tolerance (a fix that "works"
   by refusing everything is detected by the recall side).
5. **Given** a fabricated case that the fix does not close after the allowed attempts, **Then** the
   attempts are recorded (§11.4.267) and the matter is escalated to the operator; the gate stays
   closed.

---

### User Story 4 - Providers can be compared under the same gate, and locality/residency is visible (Priority: P2)

The operator can see, per tried configuration, the history of verdicts (provider, model, date,
recall and fabrication with intervals, PASS/FAIL), so choosing between the offline `extractive`
provider, the local `ollama` model, a LAN model server, or a hosted vendor is an evidence-based
decision. For remote and LAN rows the page shows the operator-authored data-residency note.

**Why this priority**: REQ-6 (provider choice and data locality) and the compose warning that "another
model is not a free swap". It is useful only once the gate (US2) produces verdicts.

**Independent Test**: Seed three verdict files for three configurations; the page lists three
history rows with the correct badges and marks only the one matching the running configuration as
"current".

**Acceptance Scenarios**:

1. **Given** several verdict files, **When** the page renders, **Then** the history lists them
   newest first, each with fingerprint short-hash, provider, model, locality, rates with intervals,
   result and date; the row matching the running fingerprint is marked current.
2. **Given** a remote or LAN provider is configured, **When** the page renders, **Then** the
   operator-authored residency note (a static file the operator controls) is displayed with a
   plain statement that the platform makes no legal claim; if no note file exists, the page says so.
3. **Given** a hosted row, **When** the page renders, **Then** it states that remote opt-in
   (`-answer-allow-remote`) is required and whether it is currently set, and that every generation
   attempt is audited only if spec 011 US2 is present on this build.

---

### User Story 5 - Enabling and disabling is one guarded operator procedure, and search never notices (Priority: P3)

An operator runs `scripts/answering-enable.sh` (and `answering-disable.sh`). Enable refuses unless a
matching PASS verdict exists, prints the exact restart command and the pre/post checks, and never
touches the live stack itself from a worktree. After the orchestrator restarts, a post-check script
proves answering state, proves search results are byte-identical for a fixed query set before and
after, and writes machine evidence.

**Why this priority**: Without a guarded procedure the gate is advice. It is last because it
presupposes a verdict (US2) and is exercised on the live stack only by the orchestrator.

**Independent Test**: Run enable with no verdict: exit non-zero naming the missing verdict; with a
stale verdict: exit non-zero; with a matching PASS: exit 0 and prints the command. Run the
post-check against a scratch server in both states and compare the search digest.

**Acceptance Scenarios**:

1. **Given** no or stale verdict, **When** `answering-enable.sh` runs, **Then** it exits non-zero
   with the reason and changes nothing.
2. **Given** a matching PASS verdict, **When** it runs, **Then** it prints the single command to
   apply and exits 0; it does not itself restart the stack (the restart is the orchestrator's,
   per the live-stack lock rule).
3. **Given** the enable has been applied and the stack restarted, **When** the post-check runs,
   **Then** it writes `result.json` and a sha256 manifest showing: overview state `on_cleared`, an
   answered known-answerable question, a declined known-unanswerable question, and an identical
   search digest to the pre-enable capture.
4. **Given** the disable script, **When** applied and restarted, **Then** state returns to
   `off_by_config`, `/api/ask` returns 503 `no_provider`, and the search digest is unchanged.

---

### Edge Cases

- Verdict exists and PASS, but the corpus was re-ingested afterwards (new root hash): STALE, answering
  forced off at next boot; the overview shows "measured on an older corpus" with both hashes' short
  forms. (Decision D3 covers whether this strictness is kept.)
- The measurement used a scratch server with a COPY of the index; the running server uses the live
  index: the fingerprint binds the index root hash read from `/api/index/status`, so a copy that
  differs in content is a different fingerprint.
- Verdict directory unreadable (permissions) or missing: treated as no verdict, reported as such,
  never a crash.
- Two verdicts for the same fingerprint (re-measurement): the newest wins; both are retained.
- Provider unhealthy at boot after a PASS: state `degraded_provider_unhealthy`, `/api/ask` returns
  the existing `unavailable` reason from `Provider.Health`, the verdict is not invalidated.
- Ingest window (`POST /api/ask/suspend`): state `suspended_ingest`; the overview and page must show
  it, and `enabled` keeps its existing meaning (provider health only), per the comment at
  `pkg/answer/http.go:658-672`.
- The overview endpoint itself failing (bug, DB down): `/ask`, search and browse must be unaffected
  and the page shows an explicit "status unavailable" state, not a blank.
- A user without the admin role requests admin-only fields: the API omits them (not hides in UI).
- Hosted provider key present but remote opt-in unset: row shows "remote opt-in: not set"; the gate
  does not matter because the provider cannot be constructed.
- A benchmark question whose label is disputed: it is listed in an audit file with tier, dropped from
  rates or kept per the recorded rule, never silently relabelled.
- Fingerprint canonicalisation differences (key order, float formatting): one canonical form,
  property-tested.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide `GET /api/answering/overview` (authenticated like every other
  `/api/*` route except health/auth) returning the document in
  `contracts/answering-overview-api.md`. It composes existing facts (`/api/ask/status` fields, the
  catalogue, the latest verdict, the audit summary) and adds no answering behaviour.
- **FR-002**: The overview `state` MUST be a member of a closed vocabulary: `off_by_config`,
  `off_gate_not_cleared`, `suspended_ingest`, `degraded_provider_unhealthy`, `on_cleared`. Each state
  has exactly one human sentence and one machine code; the vocabulary is shared by backend and
  frontend and guarded by a vocabulary-parity test.
- **FR-003**: The overview MUST list every catalogue row from `answer.Registrations()` exactly once
  with `name`, `kind`, `upstream`, `selectable` (false for a permanent stub), `credential_env` (the
  variable NAME), `credential_present` (boolean) and `locality_class`.
- **FR-004**: No overview, audit-summary, verdict-history, log or UI output MAY contain a credential
  value or prefix, a prompt, a retrieved passage, or generated answer text. This MUST be enforced
  structurally (response structs have no such fields) and by a scan test over fixtures.
- **FR-005**: The locality badge MUST derive from the DECLARED locality plus `locality_verified`;
  an unverified locality is shown as "unverified", never as local. `lan` is shown only when
  spec 011 US3 provides it; until then rows are local/remote/unverified.
- **FR-006**: The audit summary MUST be admin-only at the API layer, MUST report
  `available:false` with a reason when spec 011 US2 is absent, and MUST contain counts and metadata
  only.
- **FR-007**: A **verdict** MUST be a machine-written JSON document conforming to
  `contracts/answering-verdict.md`, containing the configuration fingerprint, benchmark hash,
  thresholds hash, counts, Wilson intervals, per-side results, and an overall result. It MUST be
  written only by the measurement tooling, never by hand and never by the server.
- **FR-008**: The gate MUST be two-sided. PASS requires BOTH: (a) recall criterion on the answerable
  set (Wilson lower bound >= recall floor) AND (b) fabrication criterion on the unanswerable set
  (Wilson upper bound <= fabrication limit), each with a minimum number of trials. Floors, limits and
  minimum trials are data in `testdata/benchmark/gate-thresholds.json` whose values are an operator
  decision (D1); the code has no numeric default that passes.
- **FR-009**: At boot, if the configured provider is not `none`, the server MUST look for a verdict
  whose fingerprint equals the running configuration and whose result is PASS. If none exists, or the
  file is invalid, the server MUST start with answering forced off, MUST keep every other route
  working, MUST log one line stating the reason (counts and short hashes only), and MUST report
  `off_gate_not_cleared`. The check MUST be fail-closed (§11.4.252) and registered as a boot
  invariant in the capability matrix (§11.4.254).
- **FR-010**: The compose default MUST remain `none`. A gate MUST assert, on every run of the
  existing compose-consistency verifier, that the default is `none` and that no compose line enables
  a provider without the verdict mechanism.
- **FR-011**: There MUST be no bypass flag in this feature. If the operator decides (D2) that a
  logged, expiring waiver is wanted, it is a separate, explicit addition recorded in the plan; the
  default specified here is no waiver.
- **FR-012**: A benchmark v2 MUST exist as new files (the old `questions.tsv` and its audit stay as
  historical record): contaminated rows dropped, now-answerable rows relabelled, enlarged so the
  minimum-trial rule in FR-008 is satisfiable, labelled by an actor other than the one that built or
  tuned the pipeline (§11.4.240/§11.4.249), with every drop and relabel recorded in an audit file.
  The benchmark remains a private asset (existing answer-key-disclosure gates apply).
- **FR-013**: Each of F1, F2, F3 MUST become a permanent regression fixture. Fix acceptance MUST be
  RED-before / GREEN-after with the same test (§11.4.115, §11.4.146), and MUST NOT be achieved by
  raising `min_score`, `min_margin` or `min_support` as the only change (a recall-collapse guard
  covers this, FR-008(a)).
- **FR-014**: Every measured configuration MUST produce an append-only verdict file; verdicts are
  never edited or deleted by tooling, and a re-measurement adds a file. The directory carries a
  sha256 manifest.
- **FR-015**: The UI MUST provide the route `/settings/providers` and the `/ask` off banner, both
  keyboard-operable, WCAG 2.1 AA (the platform's standing level, spec 001 FR-041/FR-042), responsive
  to phone width, state conveyed by text and icon, not colour alone, polite live region for state
  changes only.
- **FR-016**: Browse, search, transcripts, practice and progress MUST be unaffected by this feature
  in every state. Failure injection MUST cover: overview handler error, verdict directory missing,
  verdict invalid, provider unhealthy. For each, search answers HTTP 200 with identical results for a
  fixed query set (extends the existing `prove-g-http-5-search-survives-answering-down.sh`).
- **FR-017**: `scripts/answering-enable.sh` and `scripts/answering-disable.sh` MUST exist, refuse
  without a matching PASS verdict (enable), print the apply command rather than restarting the live
  stack, support `--dry-run`, and be three-valued (0 ok, 1 refused, 2 could not determine; 2 is never
  a pass).
- **FR-018**: The residency note MUST be an operator-authored file read-only by the server; the
  platform makes no legal assertion; absence is displayed honestly.
- **FR-019**: The overview MUST be computed from live objects (descriptor, health, thresholds,
  verdict directory), never cached across requests longer than a stated TTL, and MUST NOT call the
  remote provider to produce health beyond what `Provider.Health` already does.
- **FR-020**: Gate decisions MUST emit structured log lines (decision, short fingerprint, side
  results; no content) and expose counts in the existing metrics surface if one exists (UNCONFIRMED
  which; otherwise logs only, recorded in the capability matrix).
- **FR-021**: Documentation: a user manual section, an operator guide and FAQ entries for the page
  and the enable procedure, plus the four diagram classes (architecture, data-flow, state machine,
  sequence) embedded at point of use (§11.4.257/§11.4.258), exported per §11.4.65 and independently
  validated per §11.4.168.

### Key Entities

See `data-model.md`: `AnsweringOverview`, `ProviderRow`, `GateVerdict`, `GateThresholds`,
`ConfigFingerprint`, `BenchmarkItemV2`, `AuditSummary`, `ResidencyNote`.

## Success Criteria *(mandatory)*

- **SC-001**: An operator who has never seen the page determines, within three interactions (open
  page, read state card, read provider table), the answering state, the reason if off, the provider,
  and its locality class - verified by an automated UI test and an operator-visible acceptance step.
- **SC-002**: In 100% of boot attempts with a non-`none` provider and no matching PASS verdict (at
  least 8 distinct negative fixtures: absent, stale per fingerprint field x7, invalid JSON, wrong
  schema, FAIL result), answering is off, `/api/ask` returns 503, and search returns 200.
- **SC-003**: With a matching PASS verdict (synthetic fixture on a scratch server), answering is on
  and the overview reports `on_cleared` (1 positive fixture); a one-field mutation of the verdict
  or of the running config flips it off (>= 9 mutations, each caught).
- **SC-004**: The two-sided property holds on synthetic verdicts: high-recall/high-fabrication ->
  FAIL(fabrication); zero-fabrication/low-recall -> FAIL(recall); both good -> PASS (4 of 4 correct).
- **SC-005**: Wilson interval implementation matches published reference values: 0 of 87 -> upper
  bound 4.2%; 14 of 72 -> 12-30% (the MEASUREMENT file's own figures).
- **SC-006**: F1, F2, F3 each produce zero `answered` outcomes over >= 3 repeats on the fixed
  configuration (F1 deterministic), and the recall lower bound on benchmark v2 does not regress
  beyond the recorded tolerance.
- **SC-007**: **Enable clearance (outcome of measurement, not a promise)**: the configuration the
  operator chooses achieves a PASS verdict under the D1 thresholds on benchmark v2. If no
  configuration passes, the feature's accepted end state is "answering remains OFF, with the
  measured per-side reasons displayed" - that is a successful, evidenced outcome, not a failure.
- **SC-008**: 0 occurrences of a credential value/prefix, prompt text, passage text or answer text in
  any overview, verdict-history, audit-summary, log line or UI DOM sample across the fixture corpus
  (scan test).
- **SC-009**: For a fixed set of >= 25 search queries, the byte-identical search digest is produced
  with answering off, gated-off, and on (on a scratch server).
- **SC-010**: Documentation coverage map shows every new user-visible capability has manual + guide
  + FAQ and the four diagram classes; exported documents pass the independent validator.

## Assumptions

- The harness in `gates/answer-eval/` remains the measurement instrument; this feature wraps and
  extends it rather than replacing it (§11.4.74).
- A local generative model (`qwen2.5:3b-instruct-q4_K_M`) and the offline `extractive` provider are
  available on the development host for measurement; hosted vendors need operator-supplied keys and
  have never run against a real endpoint from this tree (spec 011 "honest boundary").
- Scratch measurement servers use a COPY of the index and their own port; they never touch the live
  stack (architecture live-stack-lock rule).
- The role value is obtainable on the frontend (UNCONFIRMED; task T006 settles it; fallback: the
  API alone enforces admin-only fields and the UI renders whatever the API returned).
- Retrieval changes from spec 017 (textbooks, reranker) change the measured numbers; every such
  change makes existing verdicts STALE by design.

## Dependencies

- **Soft on 011 US2** (audit log): the audit card degrades to "not available". **Soft on 011 US3**
  (LAN locality): badges degrade to local/remote/unverified. **None on 011 US4** (hot switch).
- **Soft on 017/019** (corpus promotion): verdicts bind to the corpus root hash, so the final live
  verdict is taken after the corpus is stable; the spec can be built and tested on scratch indexes
  before that.
- **Shared-file serialisation with 025**: both specs add one template hook in
  `features/inquiry/inquiry.component.ts`; the orchestrator lands 025-US1 first (see plan).

## Open operator decisions (carried to the final report)

- **D1** Numeric gate thresholds: recall floor, fabrication limit, minimum trials. Author proposal
  (a proposal, not a measurement): fabrication Wilson upper bound <= 2% (needs >= ~180 unanswerable
  trials with 0 fabrications), recall Wilson lower bound >= 40% on answerable-and-indexed questions.
- **D2** Waiver: none (spec default) vs logged expiring waiver.
- **D3** Verdict validity vs corpus: strict root-hash binding (spec default) vs tolerance window.
- **D4** Forced-off signalling: reuse `no_provider` with detail (spec default) vs add a new
  unavailable code (touches closed, proven-disjoint vocabularies in backend and frontend).
- **D5** Who may see the page: any authenticated user (spec default, admin-only fields omitted for
  others) vs admin only.
- **D6** Which configuration to measure first: `extractive` (cannot fabricate by construction; does
  not synthesise), local `ollama`, or a LAN/hosted provider (needs keys and 011 US2).
- **D7** Residency note text (operator-authored; the platform does not draft legal text).
