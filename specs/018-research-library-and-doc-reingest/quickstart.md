# Quickstart: Research Library and Research-Document Re-ingestion

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Validation scenarios, not the test suite. All commands run from `workshop/` of the **primary** checkout unless noted.
Authenticated calls use `scripts/_live_auth.sh` (`ws_live_auth_header`); the credential is never printed.

## Prerequisites

- Stack up: `bash scripts/status.sh` → `RUNNING`.
- Frontend rebuilt and promoted (spec 019 procedure) — otherwise the UI scenarios see the stale October-7 bundle.
- `pipeline/venv/bin/python` present; `platform/bin/ingest-transcript` built.

## Scenario 1 — the Library lists everything (US1)

```bash
source scripts/_live_auth.sh; H="$(ws_live_auth_header http://127.0.0.1:8087)"
curl -fsS -H "$H" http://127.0.0.1:8087/api/library | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["counts"])'
find docs/research -type f ! -name '*.sections.json' ! -name '*.html' ! -name '*.pdf' | wc -l   # oracle input
```
**Expected**: `documents` = number of `.md` under the tree (9), `supporting_files` = 5; equals the disk oracle.
**UI**: sign in → header **Library** → the same counts on screen.

## Scenario 2 — open every format (US2)

In the browser: open one document in-app; click **HTML**, **PDF** (new tabs, no 401); open the sample `.epub`
(download link, "binary file, not previewed"). Machine check: the live gate HEADs every href → all 200.

## Scenario 3 — re-ingest the missing research (US3)

```bash
bash scripts/ingest-research.sh --dry-run          # splits, filters, proves on a COPY; prints counts only
# expect: rows_after-rows_before == 120 minus excluded literal-[REDACTED] sections (0 expected for these 5 documents), changed_existing_rows 0, second run 0/0
```
The live merge is the orchestrator's step (`--apply`, after backup) and needs the operator's go-ahead.

## Scenario 4 — a hit links back to its document (US3/US4)

Search for a term unique to a previously unindexed research document (term chosen at run time by the verifier from
the sidecar, not written here). **Expected**: ≥ 1 hit; its card shows the document title and a link that opens
`/library/read?doc=…` (attribution by `GET /api/library/sources`; the hit itself carries only a line-span label, by design).

## Scenario 5 — redaction (FR-009)

```bash
python3 -I pipeline/research_redaction_filter.py --self-check   # fixture with literal [REDACTED] sections → 0 rows kept for them
```
Live: no search for any term finds text of a literal-`[REDACTED]` section; `withheld_sections` > 0 is shown on that
document's Library row.

## Scenario 6 — no model, no ASR (FR-008)

`bash scripts/ingest-research.test.sh` → the network-sandbox test reports `model_calls=0`.
