# Implementation Plan: Multi-Provider LLM Abstraction — Remote, LAN, and Audited Generation

**Branch**: `011-multi-provider-llm-providers` | **Date**: 2026-09-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/011-multi-provider-llm-providers/spec.md`

## Summary

The workshop curriculum platform's answering backend (`platform/backend/pkg/answer`)
already ships a real, table-driven, 33-row provider registry built on the
already-adopted `submodules/LLMProvider` library. This feature adds three
concrete, independently-shippable extensions to that existing mechanism,
following the research's own phased breakdown:

1. **P1 — wire `openai` and `anthropic` as two more `hosted(...)` catalogue
   rows** in `registry.go`, consuming `submodules/LLMProvider/pkg/providers/openai`
   and `.../anthropic`, which already compile and already expose the same
   `NewProvider(apiKey, baseURL, model string)` shape every existing row uses.
   No new refusal logic, no new privacy gate — `HostedProvider` already applies
   its four safeguards uniformly to any row built through `hosted(...)`.
2. **P1 — a per-generation, append-only remote-generation audit log**, closing
   the gap between "remote opt-in is process-wide" and the requirement for a
   per-generation, auditable gate. Modelled directly on this codebase's own
   existing append-only audit-log convention (`curriculum/redactions.jsonl` /
   `passage.RedactionLog`, materialised into a served table by
   `cmd/workshop-server/redaction_log.go`), not invented fresh.
3. **P2 — a third locality value (`lan`)** extending `ProviderConfig.Locality`
   and `VerifyLocality`, plus a real construction path for a non-loopback
   OpenAI-compatible endpoint (completing or replacing the permanently-stubbed
   `openai_compatible` row), so `RegisteredProviders()` never lists a row that
   always refuses.

Story 4 (hot provider-switching, P3) is **out of this plan's Phase 1 scope**.
The spec itself marks FR-011/FR-012 `NEEDS CLARIFICATION` and states the story
"is not blocking Stories 1-3, which are independently shippable ahead of it."
Planning it now would mean designing around two undecided operator choices;
this plan proceeds with Stories 1-3 and records Story 4 as deferred, pending
those decisions (see Complexity Tracking).

## Technical Context

**Language/Version**: Go **1.26.2** (verified: `workshop/platform/backend/go.mod:3`
— exact patch version, not assumed from the umbrella's general "Go 1.26"
reference).

**Primary Dependencies** (verified from `go.mod`, all consumed via `replace`
directives into sibling submodule checkouts three-to-four levels up from
`platform/backend/`, per the existing §11.4.74 catalogue-check pattern this
module already documents in its own `go.mod` comments):

- `digital.vasic.llmprovider` → `submodules/LLMProvider` — supplies every
  vendor adapter (`pkg/providers/<name>`), the shared `provider.LLMProvider`
  interface, and the sole credential reader `pkg/apikeys`. This feature adds
  **zero new go.mod entries** — `openai` and `anthropic` are two more
  sub-packages of an already-required module, exactly like the 28 existing
  hosted rows.
- `digital.vasic.rag` → `submodules/RAG` — grounding/claim types consumed by
  `hosted.go`'s `Generate`.
- `github.com/vasic-digital/passage` → `submodules/passage` — the identity/
  `RedactionLog` append-only-log mechanism this plan's audit log reuses the
  shape of (see Data Model).
- `github.com/vasic-digital/verdict` → `submodules/verdict`.
- `digital.vasic.containers` → `submodules/containers` (§11.4.76 — not
  touched by this feature; `workshop-server` remains a single Go binary
  running inside the existing container, no new containerised component is
  introduced).
- `modernc.org/sqlite` — the served database driver; used if the audit log's
  read-side chooses to materialise into a queryable table, mirroring
  `redaction_log.go`'s precedent (decision recorded in data-model.md).

**Storage**: Flat, append-only JSON Lines file for the remote-generation audit
log (new: `curriculum/remote-generations.jsonl`, sibling to the existing
`curriculum/redactions.jsonl`), following the exact convention
`passage.RedactionLog` already establishes for this codebase's other
append-only audit trail. No new database engine, no new service.

**Testing**: Go's standard `testing` package via `go test ./...`, matching
every existing `pkg/answer/*_test.go` file's convention (table-driven tests,
an in-process fake satisfying `provider.LLMProvider` standing in for real
vendor HTTP — see `hosted.go`'s own documented honest boundary: "NO HOSTED ROW
HAS EVER BEEN EXECUTED AGAINST ITS REAL VENDOR ENDPOINT FROM THIS TREE". This
feature's own Constructible/Refusal/Decode-proven boundary is identical in
kind for the two new rows, not a new limitation.

**Target Platform**: Linux server process (`workshop-server`, already running
containerised on this host per `workshop/CLAUDE.md`'s measured
`workshop-curriculum_platform_1` container). No new target platform.

**Project Type**: Single Go module extension (`platform/backend/pkg/answer/`
plus `cmd/workshop-server/`), inside the private `workshop` submodule. No new
service, no new deployable, no frontend change (the Angular workspace at
`platform/frontend` is out of scope — nothing in spec.md's requirements
touches the served UI).

**Performance Goals**: Not applicable in a throughput sense. Hosted-provider
latency is explicitly "a property of their service and is not measured here"
(`hosted.go`'s own `Generate` comment, unchanged by this feature). The audit
log write is a single append per generation attempt and must not become the
request's bottleneck; no numeric target is set because none exists for the
comparable `redactions.jsonl` append today.

**Constraints**:
- Every safeguard `HostedProvider` already enforces (remote opt-in before
  credential read, locality-must-agree, credential scrubbing, health-check-
  before-use) MUST continue to apply to `openai`/`anthropic` with **zero**
  row-specific reimplementation (FR-003) — this is a hard constraint on *how*
  the two rows are added, not just *that* they are added.
- The audit record MUST NEVER contain prompt text, retrieved-passage content,
  or generated-answer text (FR-005) — a structural constraint on the record
  shape, not a policy to be remembered at each call site.
- `local` locality's existing three-layer loopback enforcement
  (`llamacpp.go:16-33`) MUST NOT be weakened by introducing `lan` (FR-008).
- No new absolute host path may be hardcoded anywhere in this module (module-
  local rule 6, `workshop/CLAUDE.md`), and no private chapter/curriculum
  content may be quoted into this public umbrella repository's `specs/` tree
  (content-boundary rule) — relevant here because this plan and its data-model
  reference `workshop/`-internal file paths only, never file *contents*.

**Scale/Scope**: Two new catalogue rows (of what becomes 35 total: 33 today,
minus 1 for the removed `openai_compatible` stub, plus 3 for `openai`,
`anthropic`, and `openai_compatible_lan`), one new
locality value (of what becomes 3), one new append-only log file, no new
service boundary. Small, additive change to an already-converged mechanism —
the spec's own framing ("two more `hosted(...)` table rows... no new
architecture") is accurate to the code as read.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This is a targeted check against the anchors most relevant to a
multi-provider LLM credential/privacy-boundary feature, not an exhaustive
271-anchor audit. Each anchor's text was grepped directly from
`submodules/constitution/Constitution.md` (reachable from this umbrella root)
before writing this row.

| Anchor | Relevance | Verdict |
|---|---|---|
| **§11.4.10** — Credentials-handling mandate | New hosted rows read API keys (`ApiKey_OpenAI`, `ApiKey_Anthropic`) via `apikeys.Scan()`. | **COMPLIES.** FR-001-FR-003 require the new rows to use the existing `hosted(...)` constructor unchanged, which means credential reads go through `apikeys.Scan()` (`hosted.go:143-158`) — never `os.Getenv` directly, never written to a file, never echoed (the existing `scrub`/`scrubCredential` mechanism, `hosted.go:224-233`, already strips the secret from any upstream error text before it reaches a `Reason`). This plan adds **zero** new credential-handling code; it adds two more rows that reuse the one mechanism §11.4.10 already governs. No tension. |
| **§11.4.74** — Submodule-catalogue-first discovery + extend-don't-reimplement | The whole feature is "is there already a submodule for this?" territory. | **COMPLIES, and is the load-bearing anchor for Story 1.** `Catalogue-Check: reuse vasic-digital/LLMProvider@<pinned commit>` — `submodules/LLMProvider/pkg/providers/openai` and `.../anthropic` already exist, already compile, and already expose the uniform `(apiKey, baseURL, model string)` constructor shape every other hosted row depends on (confirmed by reading `openai.go:136` and `anthropic.go:151` directly: both are `func NewProvider(apiKey, baseURL, model string) *Provider`). Nothing is reimplemented; two rows are added to the one table that already exists for this purpose (`registry.go`'s own documented rationale: "a coverage set that is asserted rather than derived... is the defect this fleet has been bitten by three times"). |
| **§11.4.252** — Fail-closed-on-dangerous-combination for mutating/credential surfaces | A hosted-provider generation call combines ≥2 of the taxonomy's dangerous classes: (2) untrusted input (the operator's prompt/retrieved text), (3) credential access (the API key), (4) external side effect (the outbound HTTP call to a third party). | **COMPLIES, pre-existing design already satisfies the invariant, and this plan does not touch it.** `HostedProvider`'s four refusals (`hosted.go:9-44`) already fail closed on every precondition — opt-in unset, model unset, credential absent, unhealthy provider — each with a named `Reason` rather than a silent default or a relaxed retry. FR-002/FR-003 require the new rows to go through this exact path with no row-specific carve-out, so the two new rows inherit a mechanism that already satisfies §11.4.252 rather than this plan needing to design one. The one place this anchor is newly load-bearing is the **audit log** (FR-004): a write failure must not silently degrade into "the attempt is unaudited but proceeds as if it were" — see the Edge Case `NEEDS CLARIFICATION` on fail-open vs fail-closed audit writes, which this plan does NOT resolve (see below). |
| **§11.4.6** — No-guessing mandate | The spec carries three genuine `NEEDS CLARIFICATION` markers (FR-005 audit schema exact shape, FR-011 switch mechanism, FR-012 in-flight-job resolution policy). | **COMPLIES by NOT fabricating an answer.** This plan resolves FR-005's schema question concretely in data-model.md (below) because "plan" is where such a decision belongs and the spec correctly left only the *requirements-level* question open — but it explicitly does NOT resolve the fail-open/fail-closed audit-write question (an Edge Case, not an FR) or FR-011/FR-012 (Story 4, out of this plan's scope), because those are genuine operator-facing tradeoffs this plan is not authorized to decide unilaterally. Where a decision is made, it is marked as a decision with reasoning; where one is not made, it is marked `NEEDS CLARIFICATION` rather than asserted. |
| **§11.4.201** — Every guard/gate MUST assert the REAL condition | FR-010 forbids `RegisteredProviders()` listing a row (`openai_compatible`) that always returns `CodeProviderDisabled`. | **Identifies a PRE-EXISTING violation this feature is scoped to fix, not one it introduces.** `ollama.go`'s `NewOpenAICompatibleProvider` is a documented permanent stub today — selectable by name, always refuses. FR-009/FR-010 require this plan's `lan`-locality work to close that gap (either complete the row for real, or replace it with a working LAN row and stop listing the stub as selectable). This is why User Story 3 exists rather than being deferred with Story 4: the standing violation is already in production and §11.4.201 does not permit leaving a fake-green surface in place once a plan is written that touches the same file. |

**No unjustified violations.** The Complexity Tracking table below records the
one deliberate scope decision (deferring Story 4) with its justification, per
the spec's own stated rationale — it is not a Constitution Check violation,
because nothing in this plan's Phase 1 scope requires FR-011/FR-012 to be
implemented.

## Project Structure

### Documentation (this feature)

```text
specs/011-multi-provider-llm-providers/
├── plan.md              # This file
├── data-model.md         # Phase 1 output: Registration/Kind extension, RemoteGenerationAuditRecord, Locality extension
├── contracts/
│   └── remote-generation-audit-log.md  # The audit log's on-disk shape and read/write contract
├── quickstart.md         # Operator-facing validation guide
└── tasks.md              # Phase 2 output (not produced by this plan)
```

### Source Code (repository root)

```text
workshop/platform/backend/
├── pkg/answer/
│   ├── registry.go            # MODIFY (US1): add hosted("openai", "OpenAI", ...) and
│   │                           #   hosted("anthropic", "Anthropic", ...) rows, importing
│   │                           #   digital.vasic.llmprovider/pkg/providers/{openai,anthropic}
│   ├── hosted.go               # MODIFY (US2): add one audit-log write call inside
│   │                           #   newHostedProvider (construction-time attempt) and/or
│   │                           #   Generate (per-call attempt) — exact call site decided
│   │                           #   against FR-004's "attempt, not only success" wording
│   │                           #   during implementation; refusals 1-4 unchanged
│   ├── audit.go                # NEW (US2): RemoteGenerationAuditRecord type + writer,
│   │                           #   modelled on passage.RedactionLog's append-only-JSONL
│   │                           #   shape (see data-model.md)
│   ├── audit_test.go            # NEW (US2): unit tests — schema shape, field exclusion
│   │                           #   (never prompt/passage/answer text), append-only behaviour
│   ├── locality.go              # MODIFY (US3): VerifyLocality grows a third declared
│   │                           #   value "lan" — non-loopback allowed, opt-in NOT required
│   ├── ollama.go                # MODIFY (US3): NewOpenAICompatibleProvider's permanent
│   │                           #   stub either becomes real for `lan` endpoints, or is
│   │                           #   replaced per FR-009's stated alternative (a distinct
│   │                           #   row reusing llamacpp.go's transport minus its
│   │                           #   loopback-only dial check)
│   ├── registry_test.go         # MODIFY (US1, US3): catalogue coverage assertions grow
│   │                           #   to 30/31 hosted rows; openai_compatible-is-a-live-stub
│   │                           #   assertion removed once FR-010 is satisfied
│   └── llamacpp_test.go         # REFERENCE ONLY (US3): the loopback-enforcement test
│                               #   FR-008 requires be UNCHANGED in outcome
├── cmd/workshop-server/
│   └── main.go                  # MODIFY (US2): wire -answer-audit-log flag /
│                               #   $WORKSHOP_ANSWER_AUDIT_LOG, mirroring the existing
│                               #   -redaction-log flag pattern in the same file
└── platform/gates/
    └── prove-answer-provider-selection.sh  # REFERENCE (US1, US3): the existing paired-
                                   #   mutation proof that RegisteredProviders() coverage
                                   #   tracks the catalogue — grows automatically when the
                                   #   two new rows land, per its own documented design;
                                   #   no edit needed unless FR-010's stub-marking needs a
                                   #   new assertion added to it (implementation-time call)
```

**Structure Decision**: Every file touched already exists in
`workshop/platform/backend/pkg/answer/`; this feature adds one new file
(`audit.go` + its test) and extends four existing ones. No new package, no new
directory, no new service — consistent with the spec's own framing that this
is closing concrete gaps in an already-converged mechanism, not building new
architecture. The audit log's storage format (JSONL) deliberately mirrors
`curriculum/redactions.jsonl`'s existing sibling file rather than introducing
a second on-disk convention for the same kind of artifact (append-only,
line-delimited, operator-auditable).

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

| Decision | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Story 4 (provider hot-switching, FR-011/FR-012) excluded from this plan's Phase 1 scope | FR-011 and FR-012 are both marked `NEEDS CLARIFICATION` in spec.md, and each blocks a real design choice (the reload trigger mechanism; whether an in-flight job finishes on the old provider or is explicitly failed) that this plan is not authorized to decide unilaterally per §11.4.6 — deciding either unilaterally would be exactly the kind of fabricated-compliance this anchor forbids. | Planning Story 4 "provisionally" (picking one design to unblock tasks.md) was rejected because the spec itself states the codebase's philosophy "argues against a design that transparently migrates an in-flight generation to a different model mid-stream" without choosing the alternative — any provisional pick this plan made would be presented as more settled than it is, and Stories 1-3 are explicitly, independently shippable without it (spec.md Assumptions: "this story is not blocking Stories 1-3"). |
