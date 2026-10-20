# Contract: Budget and Cost Guards (FR-011 – FR-013, §11.4.252, §11.4.253)

Principle: **the feature spends nothing unless a learner asked, and never more than the configured bounds.**
Every check below runs before the provider is called; every ambiguity fails closed.

## 1. Configuration (flags in `wire_materialgen.go`, env mirrors, validated at boot)

| Flag / env | Meaning | Proposed default (OD-5 to ratify) |
|---|---|---|
| `-materials-enabled` / `WORKSHOP_MATERIALS_ENABLED` | master switch | `false` |
| `-material-provider` | catalogue row; empty ⇒ same as `-answer-provider` | empty |
| `-material-max-passages` | per-request admitted passages | 8 |
| `-material-max-prompt-tokens` | per-request estimated prompt tokens | 4000 |
| `-material-max-output-tokens` | per-request output cap passed to the provider | 1500 |
| `-material-timeout` | wall clock per generation | 240 s (matches `-answer-timeout`, `main.go:543`) |
| `-material-session-daily-tokens` | in+out per session per UTC day | 40 000 |
| `-material-global-daily-tokens` | in+out for the whole deployment per UTC day | 400 000 |
| `-material-max-concurrent` | in-flight generations | 2 |
| `-material-rate-per-min` | requests per session per minute | 3 |
| `-material-price-table` | optional operator file `{provider,model,usd_per_mtok_in,usd_per_mtok_out}` | none |

The defaults are **proposals**, not measured facts. Boot validation refuses: any limit ≤ 0, session budget >
global budget, `max_output_tokens` > the provider's recorded limit when known, enabled without a store path.

## 2. Reservation algorithm (one SQLite transaction, `BEGIN IMMEDIATE`)

```
est   = estimated_prompt_tokens(admitted prompt) + max_output_tokens          // upper bound
check per-request caps (passages, prompt tokens)           else refuse budget_exceeded{which:"request_*"}
check concurrency (count of reservations in state reserved) else refuse budget_exceeded{which:"concurrent"}
check rate (reservations by this session in the last 60 s)  else refuse rate_limited
used_s = Σ tokens(state=reserved) + Σ settled(state=settled)  for (today, session)
used_g = same for today, all sessions
if used_s + est > session_limit  -> budget_exceeded{which:"session_daily", resets_at:"next 00:00 UTC"}
if used_g + est > global_limit   -> budget_exceeded{which:"global_daily",  resets_at:"next 00:00 UTC"}
INSERT budget_reservation(job_id, day, session, tokens=est, state='reserved')
```

Settlement (after the provider returns): `UPDATE … state='settled', settled=actual_tokens` (actual from
`GenStats`; if the provider reports none, the estimate stands, flagged `estimated`). Release on any failure before
the provider call: `state='released'`. A reservation older than `timeout + 60 s` still `reserved` at boot is
released and its job marked `unavailable interrupted` (crash recovery; no tokens are charged without evidence).

## 3. Properties (each has a test)

| ID | Property | Oracle | Paired mutation |
|---|---|---|---|
| B-1 | boundary: `limit−1`, `limit`, `limit+1` admitted/admitted/refused exactly | table of expected admits computed by hand and by the Python oracle | `>` ↔ `>=` flipped ⇒ FAIL |
| B-2 | 50 concurrent requests against a budget admitting k ⇒ exactly k admitted and provider stub count ≤ k | stub counter | reserve without a transaction ⇒ FAIL |
| B-3 | refused request ⇒ provider stub count unchanged | stub counter | move the check after the call ⇒ FAIL |
| B-4 | budget store unreadable ⇒ `unavailable budget_store_unreadable`, stub count 0 | injected failing store | map error to "allow" ⇒ FAIL |
| B-5 | day rollover: reservation keeps its own UTC day | injected clock | use "now" at settle ⇒ FAIL |
| B-6 | cache hit consumes 0 tokens and does not enter the ledger | ledger row count | charge hits ⇒ FAIL |
| B-7 | never-unasked: boot + 10 min idle + all other endpoints ⇒ stub count 0 | stub counter | add a warm-up call ⇒ gate FAIL |
| B-8 | `unavailable` releases the reservation (no leak) | Σ reserved after N failures == 0 | skip release ⇒ FAIL |

## 4. Cost transparency (FR-013)

`POST /api/materials/preflight` (or the `preflight` field of the confirm step) returns, without calling any
provider or reserving anything beyond a rate-limit tick: provider, model, locality, `estimated_tokens_in_max`,
`max_output_tokens`, remaining session and global budget, and `monetary_estimate: null` unless a price table is
configured. No number in this response is invented: estimates are labelled as upper bounds.

## 5. Never-unasked invariants (FR-011, SC-003)

1. The only caller of `Generator.Run` is the job worker started by `POST /api/materials`.
2. No ticker, `init`, boot sequence, ingest hook, index-swap hook or `/api/ask` path references `materialgen`.
3. A corpus generation change does **not** regenerate anything; stale cache entries are simply missed.
4. `verify-materialgen-single-callsite.sh` fails if (1) or (2) is violated; its `prove-` pair injects a call into
   a throwaway copy of `main.go` hooks and requires exit 1.
