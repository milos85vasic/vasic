# Data Model: Multi-Provider LLM Abstraction

**Feature**: 011-multi-provider-llm-providers | **Date**: 2026-09-30

This document covers the entities this feature touches or adds. Each entity
is marked EXISTING (unchanged shape), EXTENDED (existing type, new value/
field), or NEW.

## 1. Provider Registration — EXTENDED (two new rows, no shape change)

**Existing type**: `answer.Registration` (`pkg/answer/registry.go`). No field
is added or changed. This feature adds two rows to the `catalogue` slice:

```go
hosted("openai", "OpenAI", "pkg/providers/openai",
    func(k, u, m string) llmprovider.LLMProvider { return openai.NewProvider(k, u, m) }),
hosted("anthropic", "Anthropic", "pkg/providers/anthropic",
    func(k, u, m string) llmprovider.LLMProvider { return anthropic.NewProvider(k, u, m) }),
```

- **Name**: `openai` / `anthropic` — the values `-answer-provider` and
  `$WORKSHOP_ANSWER_PROVIDER` accept.
- **Kind**: `KindHosted` — identical to the 28 existing rows; derives
  `RequiresRemoteOptIn() == true` automatically (`registry.go`'s
  `RequiresRemoteOptIn` is computed from `Kind`, never stored — a new hosted
  row cannot be added without the opt-in requirement coming with it).
- **Credential**: `"OpenAI"` / `"Anthropic"` — resolves to environment
  variables `ApiKey_OpenAI` / `ApiKey_Anthropic` via the existing
  `credentialPrefix + Credential` convention (`apikeys.Prefix = "ApiKey_"`).
  **Confirmed by reading the constructor signatures directly**
  (`submodules/LLMProvider/pkg/providers/openai/openai.go:136` and
  `.../anthropic/anthropic.go:151`): both are
  `func NewProvider(apiKey, baseURL, model string) *Provider`, matching the
  `func(apiKey, baseURL, model string) llmprovider.LLMProvider` shape every
  `hosted(...)` row requires. No adapter-specific wrapper is needed.
- **build**: `newHostedProvider` — shared, unmodified.

No new `Kind` value is needed for Story 1 (both rows are ordinary hosted
rows). Story 3 (below) is what extends `Kind`'s vocabulary.

## 2. Provider Locality — EXTENDED (third declared value: `lan`)

**Existing type**: `answer.Locality` (`pkg/answer/locality.go:27`) and
`VerifyLocality(declared, endpoint string) Locality`. Today `VerifyLocality`
recognizes exactly two declared values in its control flow: `"remote"`
(no loopback requirement) and everything else, treated as `"local"` (loopback
required, verified against DNS-resolved addresses, three enforcement layers
in `llamacpp.go`).

**Change**: a third declared value, `"lan"`, is added to `VerifyLocality`'s
branching:

```text
declared == "remote"  → Verified=true unconditionally (unchanged)
declared == "lan"     → Verified=true if resolvable, REGARDLESS of loopback
                         (an operator-controlled, non-loopback endpoint is
                         exactly what this value exists to allow) — but an
                         UNRESOLVABLE endpoint is still a fault, exactly as
                         today for "local", because an unverifiable locality
                         must never be treated as an assumption
everything else (incl. "local", "") → unchanged: loopback required
```

**This is where spec.md's Edge Cases `NEEDS CLARIFICATION` on LAN-locality
ownership/reachability checking is resolved.** spec.md asks: "should LAN
locality validation include any reachability/ownership check beyond 'not
loopback', or is the operator's explicit declaration the sole basis for
trust... the research does not explicitly rule out an ownership check." The
decision made here is **resolvability-only, no ownership check**: `declared ==
"lan"` is verified by DNS/address resolution succeeding, with no further check
of who owns or administers the resolved address. Reasoning: this matches how
`declared == "remote"` already works today (`Verified=true` unconditionally,
trusting the operator's own opt-in decision with no independent verification),
so `lan` is held to the same trust model as its nearest sibling rather than a
stricter one invented just for it — and it matches the research's own framing
of locality as "a trust signal the operator states, not a property the system
independently verifies." **Honest boundary**: this is the minimal-viable
interpretation, not a resolved operator decision. The research explicitly does
not rule out an ownership check, so — exactly like FR-005's schema decision
above — this choice still needs the same kind of operator sign-off before it
is treated as settled; it is marked here as a decision with its reasoning
stated, not as a foregone conclusion.

This is an *additive* branch. `declared == "local"` falls through the
existing `else` path unchanged — FR-008's requirement that introducing `lan`
"MUST NOT weaken the existing `local` guarantee" is satisfied structurally: no
existing branch is touched, a new one is inserted beside it.

**`Kind` vocabulary extension** (`registry.go`): a `KindLAN` value is added,
alongside `KindBuiltin` / `KindLocal` / `KindHosted`. `RequiresRemoteOptIn()`
continues to be derived from `Kind`:

```go
func (r Registration) RequiresRemoteOptIn() bool { return r.Kind == KindHosted }
```

`KindLAN` falls outside `KindHosted`, so a `lan`-locality row derives
`RequiresRemoteOptIn() == false` automatically — satisfying FR-007 ("MUST NOT
require `-answer-allow-remote` opt-in") the same *derived, not stored* way
every other opt-in requirement in this table already works, rather than as a
special case bolted onto the switch.

## 3. LAN-locality Provider Row — NEW registration, reusing existing transport

Per FR-009's explicitly offered alternative, the concrete decision is: **do
not attempt to complete the `openai_compatible` stub as a third, independent
implementation.** Instead:

- A new `Name: "openai_compatible_lan"` (exact final name is an
  implementation-time naming decision, not a design one) row is registered
  with `Kind: KindLAN`, reusing `llamacpp.go`'s existing transport
  (`newLlamaCppClient`, the OpenAI-compatible `/v1/chat/completions` /
  `/v1/models` request shapes, `DecodeAnswerPayload` schema enforcement) with
  its loopback-only dial-time `Control` hook parameterized to allow any
  address `VerifyLocality("lan", endpoint)` already verified as resolvable —
  rather than hardcoding loopback.
- The existing `openai_compatible` row (`Kind: KindHosted`, permanently
  stubbed) is **removed from the catalogue** rather than left dual-listed,
  closing FR-010 ("MUST NOT list any provider row as selectable... while that
  row is, in fact, a permanent stub"). This is the smaller change of the two
  alternatives FR-009 names, because it reuses an already-hardened transport
  (three-layer dial-time enforcement, already tested via
  `llamacpp_dial_test.go`) rather than writing a second one against
  `NewOpenAICompatibleProvider`'s never-executed generic-adapter path.

**Why not keep both rows**: `RegisteredProviders()` is a single derived list
(`registry.go`'s own documented design principle — "a gate that enumerates
providers and the constructor that builds them cannot drift apart"). Keeping
a renamed-but-still-present `openai_compatible` stub beside a new working
`openai_compatible_lan` row would satisfy FR-009 (a working LAN path exists)
while still violating FR-010 (a permanently-refusing row remains selectable)
— removal, not addition, is what closes both requirements from one change.

## 4. Remote-Generation Audit Record — NEW entity

**Resolves FR-005's `NEEDS CLARIFICATION`** on exact on-disk schema, file
format, and field names, per this plan's own mandate (the requirements-level
question is correctly left open in spec.md; this is where it is decided).

### Format decision: JSON Lines, modelled directly on `passage.RedactionLog`

This codebase already has exactly one precedent for "a structured, append-
only, per-event audit trail sitting beside the served artifact":
`curriculum/redactions.jsonl`, read by `passage.LoadRedactionLog` and
materialised into a served-database table by
`cmd/workshop-server/redaction_log.go`. That file documents its own design
reasoning in terms directly reusable here: *"the FILE is the append-only
artifact"*, *"it changes no disclosure decision — it writes a table nothing in
the read path consults"*, *"it never fails the boot... reported loudly and
serving continues."* The remote-generation audit log adopts the same three
properties for the same reasons: an audit trail must never gate the thing it
is auditing, and a missing/unwritable log must be loud, not fatal.

**New file**: `curriculum/remote-generations.jsonl`, one JSON object per line,
append-only, sibling to `curriculum/redactions.jsonl`.

### Schema

```jsonc
{
  "id": "rg_2026-09-30T14:03:11.842Z_a1b2c3d4",  // time-prefixed + random suffix,
                                                   // same shape convention as
                                                   // passage IDs (sortable, unique
                                                   // without a sequence table)
  "ts": "2026-09-30T14:03:11.842Z",               // RFC 3339, UTC, server clock
  "session_id": "sess_9f8e...",                   // the existing /api/ask session
                                                   // identifier already carried by
                                                   // Jobs — no new session concept
  "provider": "openai",                           // Registration.Name — exactly the
                                                   // catalogue row name
  "model": "gpt-4o",                              // ProviderConfig.Model as configured
  "endpoint": "https://api.openai.com/v1",        // resolved endpoint — vendor default
                                                   // when -answer-endpoint was unset,
                                                   // exactly as the descriptor already
                                                   // reports it (hosted.go Descriptor())
  "content_bytes": 4821,                          // len(req.Prompt.Text) in bytes —
                                                   // NOT a token estimate: a byte count
                                                   // needs no tokenizer assumption and
                                                   // cannot itself leak content shape
                                                   // the way a token count from a
                                                   // specific tokenizer might hint at
  "outcome": "success",                           // "success" | "health_check_failed" |
                                                   // "credential_missing" |
                                                   // "upstream_error" | "cancelled" |
                                                   // "schema_violation" — mirrors the
                                                   // Reason.Code vocabulary hosted.go
                                                   // already uses, so this is a closed
                                                   // set derived from an existing
                                                   // enumeration, not a new one
  "duration_ms": 1284                             // wall-clock for the attempt; 0 for
                                                   // attempts refused before any network
                                                   // call (health_check_failed at
                                                   // construction, credential_missing)
}
```

**Fields explicitly and permanently excluded** (FR-005's negative
requirement, enforced by the writer's function signature never accepting
these as parameters — not merely by convention):

- the request prompt text
- the retrieved passage / grounding content
- the generated answer text
- the credential value (the writer never receives `secret`, only `reg.Name`
  and `reg.CredentialEnv()`'s *name*, mirroring `HostedProvider`'s own
  never-render-the-value discipline)

### Write call sites (two, both "attempt" moments)

FR-004 requires one record "per individual remote-generation attempt...
whether that attempt succeeds, fails a health check, or fails with an
upstream error" — i.e., an attempt is recorded even when it never reaches the
network. Concretely, this means **two** call sites inside the existing hosted
path, not one:

1. **`newHostedProvider`** (`hosted.go`), after refusals 1-2 (opt-in,
   locality, model — these are configuration-shape refusals that happen
   before any credential is even read, and per FR-004's own framing an
   "attempt" is a generation attempt, not a configuration error; these two
   refusals are NOT audited) and specifically at refusals 3-4 (credential
   missing; health-check failure) — both are real attempts to reach a remote
   provider with private-content-bearing configuration already resolved.
2. **`Generate`** (`hosted.go`), wrapping the `upstream.Complete` call —
   records `success`, `upstream_error`, `cancelled`, or `schema_violation`
   depending on how the call concludes.

This two-site design is why `audit.go` is a new file rather than one line
added inline: both call sites share one `writeAuditRecord` helper, keeping
the "exactly one record per attempt" invariant enforced in one place rather
than re-derived at each site.

### Read side

No new read API is introduced by this feature. The contract
(`contracts/remote-generation-audit-log.md`) documents the file as directly
operator-readable (`jq` over JSON Lines, exactly how `redactions.jsonl` is
read today) and via the same `SyncDB`-into-served-table pattern
`redaction_log.go` already established, should a future feature want it
queryable from the API — that materialisation is NOT part of this feature's
scope (spec.md's FR-004/FR-005 require the record to exist and be structured;
nothing requires it to be served over HTTP).

## 5. Provider Switch Request — NEW entity, design DEFERRED

Per spec.md's own Assumptions and this plan's Complexity Tracking, Story 4's
entity (`Provider Switch Request`) is named here for completeness but is
**not designed** by this plan: FR-011 (the interaction surface — CLI signal,
HTTP admin endpoint, config-file watch) and FR-012 (in-flight-job resolution
policy — finish-on-old-provider vs. explicit-fail) are both open operator
decisions this plan does not make. A future plan revision resolves these once
that operator input exists.
