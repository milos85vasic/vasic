# Quickstart: Validating Multi-Provider LLM Abstraction

**Feature**: 011-multi-provider-llm-providers

This is an operator-facing validation guide, not implementation code. It
assumes User Stories 1-2 (OpenAI/Anthropic rows + audit log) have been
implemented per `plan.md`; User Story 3 (LAN locality) has its own section
below. Every command is real and runnable against the actual
`workshop-server` binary — none of this is illustrative pseudocode.

## Prerequisites

- A built `workshop-server` binary (`cd workshop/platform/backend && go build
  ./cmd/workshop-server`) at a commit that includes this feature's changes.
- A real OpenAI API key exported as `ApiKey_OpenAI`, and/or a real Anthropic
  API key exported as `ApiKey_Anthropic` — the exact convention
  `apikeys.Scan()` already reads from `~/api_keys.sh` or the process
  environment. **Do not commit either key anywhere; export them in your
  shell only** (per this umbrella's credential-handling rules and §11.4.10).
- The platform's existing curriculum registry already built and reachable
  (whatever `-curriculum` / `-registry` flags this deployment already uses —
  this feature adds no new prerequisite here).

## Part 1 — Turn on OpenAI as the answering provider (Story 1)

```bash
export ApiKey_OpenAI="sk-...your real key..."

./workshop-server \
  -answer-provider openai \
  -answer-allow-remote \
  -answer-locality remote \
  -answer-model gpt-4o \
  -curriculum /path/to/curriculum \
  # ... whatever other flags this deployment already requires (port, registry, etc.)
```

**Confirm the row is selectable and no longer a stub-in-waiting**:

```bash
./answer-providers --names | grep -E '^(openai|anthropic)$'
# expect both lines printed
```

**Submit a real question** (replace `<host:port>` and the auth this
deployment's `/api/ask` already requires):

```bash
curl -s -X POST http://<host:port>/api/ask \
  -H 'Content-Type: application/json' \
  -d '{"question": "What does chapter 1 cover?"}'
# poll the returned job id until it completes, per the existing async job
# contract (pkg/answer/jobs.go) — this feature changes nothing about that
# polling shape
```

**Verify the descriptor**: the completed job's response MUST name provider
`openai`, the configured model, and locality `remote` — exactly the shape
`hosted.go`'s `Descriptor()` already produces for every other hosted row
(SC-001 / Acceptance Scenario 1).

**Repeat for Anthropic**:

```bash
export ApiKey_Anthropic="sk-ant-...your real key..."
./workshop-server -answer-provider anthropic -answer-allow-remote \
  -answer-locality remote -answer-model claude-3-5-sonnet-20241022 ...
```

## Part 2 — Confirm the refusal paths still work (Story 1, negative cases)

**Without `-answer-allow-remote`** (SC-002):

```bash
./workshop-server -answer-provider openai -answer-model gpt-4o ...
# submit a request; expect an immediate refusal, CodeProviderDisabled,
# BEFORE any credential read or network call — confirm by watching for
# zero outbound connections to api.openai.com (e.g. via a packet capture
# or by temporarily unsetting DNS resolution for that host)
```

**Without the credential set**:

```bash
unset ApiKey_OpenAI
./workshop-server -answer-provider openai -answer-allow-remote \
  -answer-locality remote -answer-model gpt-4o ...
# submit a request; expect a Reason naming the missing ApiKey_OpenAI
# variable, never a request reaching OpenAI with an empty key
```

## Part 3 — Verify the audit log (Story 2)

```bash
./workshop-server \
  -answer-provider groq -answer-allow-remote -answer-locality remote \
  -answer-model <a valid groq model> \
  -answer-audit-log /path/to/curriculum/remote-generations.jsonl \
  ...

# submit 3 real requests through /api/ask, then:
wc -l /path/to/curriculum/remote-generations.jsonl
# expect exactly 3 lines (SC-003: one record per attempt)

jq -c . /path/to/curriculum/remote-generations.jsonl
# inspect each record: confirm session_id, provider, model, endpoint,
# timestamp, content_bytes, outcome are all present (FR-005)

jq -c 'select(.content_bytes == null or has("prompt") or has("answer") or has("passage"))' \
  /path/to/curriculum/remote-generations.jsonl
# expect ZERO matches — this is the direct negative check for SC-004: no
# audit record contains prompt, passage, or answer content
```

**Confirm attempts are logged even on failure**: repeat Part 2's
no-credential scenario with `-answer-audit-log` set, and confirm a record
with `"outcome": "credential_missing"` is appended (FR-004 Acceptance
Scenario 3 — an attempt is recorded even when it never reaches the network).

**Confirm local/`none` providers are NOT audited** (Acceptance Scenario 4):

```bash
./workshop-server -answer-provider none -answer-audit-log /path/to/remote-generations.jsonl ...
# submit requests; confirm the file is untouched / unchanged in line count
```

## Part 4 — LAN locality (Story 3, once implemented)

Requires a second machine on the same network running an OpenAI-compatible
model server (e.g. `llama-server` from llama.cpp, bound to that machine's LAN
address rather than loopback).

```bash
# On the LAN host (example, adjust to the real server binary in use):
llama-server --host 0.0.0.0 --port 8080 -m <model.gguf>

# On the workshop-server host:
./workshop-server \
  -answer-provider openai_compatible_lan \
  -answer-locality lan \
  -answer-endpoint http://<lan-host-ip>:8080 \
  -answer-model <model-name> \
  ... # no -answer-allow-remote required (FR-007)
```

**Confirm**:

1. Generation succeeds with `-answer-allow-remote` absent (SC-005).
2. The response descriptor's locality reads `lan`, not `local` or `remote`
   (Acceptance Scenario 2).
3. The old stub name is gone from the selectable list:
   `./answer-providers --names | grep openai_compatible` returns no exact
   `openai_compatible` match (only `openai_compatible_lan`, if that is the
   final chosen name) — SC-008.

**Confirm `local` is unweakened** (FR-008 regression check): the existing
`llamacpp` row, pointed at a genuinely non-loopback address with
`-answer-locality local` (not `lan`), MUST still be refused exactly as it is
today. This is a NEGATIVE test — nothing about this feature should make it
pass.

```bash
./workshop-server -answer-provider llamacpp -answer-locality local \
  -answer-endpoint http://<some-non-loopback-ip>:8080 -answer-model x ...
# expect CodeLocalityUnverified refusal, unchanged from pre-feature behaviour
```

## What this quickstart does NOT cover

- **Story 4** (hot provider switching) has no validation steps here because
  its design is deferred (see `plan.md` Complexity Tracking) — FR-011/FR-012
  are unresolved `NEEDS CLARIFICATION` items, not yet implementable.
- **Cost exposure** from real OpenAI/Anthropic usage is explicitly out of
  scope for this feature (spec.md Assumptions) — running Part 1 against real
  keys incurs real provider cost; use minimal test questions and small models
  where practical.
- **Vendor-HTTP-level correctness** of the `openai`/`anthropic` adapters
  themselves is NOT re-verified by this quickstart — that is
  `submodules/LLMProvider`'s own test responsibility. This quickstart verifies
  the workshop platform's integration of those adapters (refusals, audit,
  descriptor correctness), consistent with `hosted.go`'s own documented
  honest boundary ("CONSTRUCTIBLE, REFUSAL-PROVEN and DECODE-PROVEN; NOT
  vendor-proven").
