# Quickstart: Validating On-Demand Grounded Material Generation

Run from `workshop/` unless stated. Authenticated calls use the repository helper
(`source scripts/_live_auth.sh; AUTH="$(ws_live_auth_header "$BASE")"`; the seed password comes only from
`WORKSHOP_TEST_SEED_PASSWORD`; never write a credential into this file or into evidence). `BASE` defaults to
`http://127.0.0.1:8087`. Streams verify on an **isolated throwaway server** (architecture plan §2.2 item 6); only the
orchestrator restarts the live stack.

Two provider modes are used below and the difference matters for what a run proves:
- **scripted**: the isolated server is started against `pkg/materialgen/mgtest`'s counting stub that speaks the
  provider's HTTP protocol — proves the mechanism deterministically; says nothing about a real model.
- **real**: the live stack with `-materials-enabled` and a real provider — the only mode that says anything about
  model behaviour (Scenario 8). If it is not enabled, Scenario 8 records `skipped_operator_gated`, exit 2.

## Prerequisites
- `go build ./...` clean; Playwright installed; `python3` for the oracle.
- Calibrated gate thresholds available for the scripted corpus (the scripted server sets known values); for the
  real stack, T008's finding. Record `GET /api/health` `build_id` / `source_dirty` in every evidence file.

## Scenario 0 — deterministic units and the independent oracle (runs without any server)
```bash
cd platform/backend && go test ./pkg/materialgen/... -count=1 -v
python3 -I ../../pipeline/materialgen_oracle.py --check testdata/materialgen   # regenerates vectors, diffs against committed ones
```
Expect PASS and an empty oracle diff: cache-key vectors (C-8), budget table (B-1), fabrication matrix shape.

## Scenario 1 — disabled by default
Start the stack/isolated server **without** `-materials-enabled`. `GET /api/materials/provider` ⇒
`{"enabled":false}`; `POST /api/materials` ⇒ `503 generation_disabled`; the page `/materials/new` says
generation is off and why. Q&A, search and chapters unaffected.

## Scenario 2 — a covered topic (scripted)
`POST /api/materials/preflight` with `{"form":"flashcards","topic":"<topic the fixture corpus covers>","count":4}` ⇒
provider/locality/token bound. Confirm in the UI. **Operator sees**: phases moving, then 4 cards, each with a
citation chip opening `/passage/<pid>`, a "Show source" quote, and a provenance line
("Generated · provider · locality · corpus generation · 6 passages"). Network panel shows exactly one provider call.

## Scenario 3 — decline, not fabricate
Request a topic the corpus does not cover. **Operator sees** "Not enough in the library to answer this", the reason
(`insufficient_coverage` in plain words), retrieval numbers, and the suggestion to ask an operator to add a source.
Provider stub count for this request: 0.

## Scenario 4 — fabrication matrix on the running mechanism
```bash
platform/gates/verify-materialgen-fabrication.sh --base "$BASE"   # replays F-1…F-15 through the scripted provider
```
Expect every row refused with the specified outcome and `0` persisted materials; its `prove-` pair removes each layer
in a throwaway copy and must fail.

## Scenario 5 — budgets and "never unasked"
```bash
platform/gates/verify-materialgen-single-callsite.sh                # static: exactly one Generate call site
scripts/verify-materials-budget.sh --base "$BASE"                    # boundary + 50-way concurrency against the counting stub
```
Idle the server 10 minutes after boot with the stub attached; stub count stays 0. In the UI, exhaust the small
session budget: **operator sees** "Daily limit reached — resets at 00:00 UTC (session_daily)" and no spinner.

## Scenario 6 — cache and idempotency
Repeat Scenario 2 exactly: **operator sees** "served from cache", identical cards, no phases; stub count unchanged.
Bump the corpus generation (isolated server: touch + reindex helper) and repeat: fresh generation again. Fire 20
identical concurrent requests: one generation, one audit line (non-local stub).

## Scenario 7 — remote/LAN disclosure and audit (BLOCKED until spec 011 US2/US3)
Configure the stub as a `lan`/`remote` provider. Without the allow flag ⇒ `provider_disabled`; with it but without
the acknowledgement ⇒ `400 remote_ack_required`; with both ⇒ generation proceeds and
`jq -c . curriculum/remote-generations.jsonl` shows exactly one line per provider request and none of the canary
strings placed in the topic and corpus.

## Scenario 8 — LIVE verification with a real provider (machine evidence)
```bash
scripts/verify-materials-live.sh --base "$BASE" --out ../specs/022-on-demand-grounded-material/evidence/live
sha256sum -c ../specs/022-on-demand-grounded-material/evidence/live/MANIFEST.sha256
```
Expect `result.json` with `verdict` ∈ {`pass`,`fail`,`skipped_operator_gated`} (the last exits 2), `build_id`,
`source_dirty`, provider/model/locality, per-check results, token totals, and the audit/stub reconciliation.

## Scenario 9 — enablement measurement (FR-022, operator-gated)
```bash
scripts/measure-material-fabrication.sh --set <unanswerable-set> --out ../specs/022-on-demand-grounded-material/evidence/fabrication-measurement
```
Writes counts, the fabrication rate with its upper 95% bound (rule-of-three when zero), the harness version and the
set's hash. Enabling anywhere requires the operator's recorded decision on that bound (OD-1).

## Full-feature regression
`go test ./...`, `npm run test:unit`, Playwright `e2e/materials.spec.ts`, `pytest` oracle, all gates and their
`prove-` pairs. One failing mutation-proof means a blind gate; the feature is not done.
