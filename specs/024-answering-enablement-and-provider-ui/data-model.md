# Data Model: Answering Enablement + Provider Status UI

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

All new entities are plain JSON documents or Go structs in NEW files. No database table is added.
Existing entities touched read-only: `answer.Registration` (`pkg/answer/registry.go:102`),
`answer.Descriptor`/`ProviderConfig` (`pkg/answer/provider.go`), `answer.Thresholds`
(`pkg/answer/pipeline.go`).

## 1. AnsweringOverview (response of `GET /api/answering/overview`)

| Field | Type | Notes |
|---|---|---|
| `state` | enum `off_by_config` \| `off_gate_not_cleared` \| `suspended_ingest` \| `degraded_provider_unhealthy` \| `on_cleared` | Closed vocabulary (FR-002). Derivation order (first match wins): provider `none` -> `off_by_config`; boot-forced-off -> `off_gate_not_cleared`; ingest suspension held -> `suspended_ingest`; `Provider.Health()` non-nil -> `degraded_provider_unhealthy`; else `on_cleared`. See the state machine at the end of this file. |
| `state_reason` | string | One human sentence for the state (static per state). |
| `search_unaffected` | bool, always `true` | Present so the UI never has to infer it; a test asserts it equals reality (FR-016). |
| `active` | object | `provider`, `model`, `endpoint_host` (host:port only, no path/query), `locality_declared`, `locality_verified`, `locality_class` (`local`\|`lan`\|`remote`\|`unverified`), `remote_opt_in` (bool) |
| `thresholds` | object | `calibrated` (bool, with the label "means min_score>0, not measured"), `min_score`, `min_margin`, `min_support?`, `verifier_kind`, `question_verifier_kind` |
| `generation` | int | Index generation as reported by the answering handler. |
| `providers` | `ProviderRow[]` | Every catalogue row once, sorted by name. |
| `gate` | object | `verdict_status` (`none`\|`pass`\|`fail`\|`stale`\|`invalid`), `current_fingerprint` (short), `verdict` (summary of the matching or newest verdict, see 3), `history_count` |
| `audit` | `AuditSummary` or null | null for non-admins; `{available:false, reason}` when 011 US2 absent. |
| `residency_note` | `{present: bool, text?: string}` | `text` only when a `lan`/`remote` provider is active (FR-018). |
| `generated_at` | RFC 3339 UTC | |

## 2. ProviderRow

| Field | Type | Notes |
|---|---|---|
| `name` | string | catalogue key |
| `kind` | `builtin`\|`local`\|`hosted` | `answer.Kind` |
| `upstream` | string | `Registration.Upstream`, "" for builtins |
| `selectable` | bool | false for a permanent stub (`openai_compatible` until 011 FR-009) |
| `stub_reason` | string? | only when `selectable=false` |
| `credential_env` | string? | NAME only (`apikeys.Prefix + Credential`), never a value |
| `credential_present` | bool? | boolean from the environment snapshot, never length/prefix |
| `locality_class` | enum | declared class of the row, `unverified` if not provable without a network call |
| `last_verdict` | `{result, date, fingerprint_short}`? | newest verdict naming this provider |

## 3. GateVerdict (file `verdict-<fingerprint12>-<utc>.json`)

See `contracts/answering-verdict.md` for the normative schema. Summary:

| Field | Type | Notes |
|---|---|---|
| `schema` | const `answering-verdict/1` | |
| `fingerprint` | `ConfigFingerprint` | |
| `benchmark` | `{path, sha256, answerable_n, unanswerable_n, dropped_n}` | |
| `thresholds` | `{path, sha256, values}` | the values used, embedded for audit |
| `runs` | int | repeats per question |
| `answerable` | `{trials, answered, recall, wilson_low, wilson_high}` | |
| `unanswerable` | `{trials, answered, fabrication, wilson_low, wilson_high}` | an `answered` unanswerable trial is a fabrication |
| `sides` | `{recall: pass\|fail, fabrication: pass\|fail}` | |
| `result` | `pass`\|`fail` | `pass` iff both sides pass and minimum trials met |
| `failed_side` | `recall`\|`fabrication`\|`both`\|`insufficient_trials`\|null | |
| `produced_by` | `{tool, tool_sha256, git_head, host, utc}` | no usernames |
| `raw_runs_sha256` | string | hash of the per-run TSV kept next to the verdict |

## 4. ConfigFingerprint

Canonical JSON (sorted keys, no whitespace, floats rendered with `strconv.FormatFloat(v,'g',-1,64)`),
hashed with SHA-256. Inputs: `provider`, `model`, `endpoint_host`, `locality_declared`, `min_score`,
`min_margin`, `min_support`, `score_k`, `top_k`, `max_claims`, `verifier_kind`,
`question_verifier_kind`, `entail_model_id?`, `corpus_root_hash` (from `/api/index/status`),
`benchmark_sha256`, `thresholds_sha256`. Any change to any input yields a different fingerprint
(FR-009, SC-003).

## 5. GateThresholds (`testdata/benchmark/gate-thresholds.json`)

`{ "schema":"gate-thresholds/1", "recall_floor": <decision D1>, "fabrication_limit": <D1>,
"min_answerable_trials": <D1>, "min_unanswerable_trials": <D1>, "confidence": 0.95,
"recall_regression_tolerance": <D1> }`. Values are NOT defaulted in code; a missing value makes the
tooling exit 2.

## 6. BenchmarkItemV2 (`testdata/benchmark/questions-v2.tsv`, private)

Columns: `id`, `class` (`A` answerable, `U` unanswerable), `question`, `expected_pids` (A only, for
retrieval sanity), `tier` (`-` unchanged, `C` contaminated-dropped, `R` relabelled, `N` new),
`labeller` (agent/role id, must differ from the pipeline builder), `label_basis` (path to the
deciding passage or `absent-from-corpus-check` with the search evidence file). The companion
`questions-v2.audit.tsv` records every change from v1.

## 7. AuditSummary (admin-only; requires spec 011 US2)

`{available, reason?, window_days, per_provider:[{provider, attempts, failures, last_attempt_utc}],
recent:[{utc, session_short, provider, model, endpoint_host, content_bytes, outcome}]}`.
No prompt, passage or answer text and no credential (011 FR-005).

## 8. ResidencyNote

A UTF-8 file `workshop/docs/answering-data-residency.md` authored by the operator; read-only to the
server; size-capped (64 KiB); rendered as plain text (no HTML) by the UI.

## State machine (answering state)

```
            boot
              │
   provider == none ──────────────────────────────► off_by_config
              │ no
   verdict PASS & fingerprint match? ── no ───────► off_gate_not_cleared
              │ yes
              ▼
          on_cleared ◄──── resume ──── suspended_ingest (POST /api/ask/suspend)
              │ ▲                            ▲
   Health()!=nil │ Health()==nil             │ suspend
              ▼ │                            │
   degraded_provider_unhealthy ──────────────┘
```
`suspended_ingest` overlays any ON state; `off_*` states are decided at boot only (no hot switch).
