# Contract: `GET /api/system/provenance`

**Implements**: FR-004, FR-005, FR-006 | **Handler**: `internal/api/provenance.go` (NEW) | **Mount**: `cmd/workshop-server/wire_provenance.go` →
`registerProvenance(mux, cfg, loadedRegistry)`; one orchestrator hook line in `main.go`. **Auth**: session required (the `/api/` gate); `/api/health`
stays exempt and unchanged.

## Request / response

`GET /api/system/provenance` — no parameters (the handler reads none; a test asserts query/path inputs are ignored). Body: `data-model.md` §3.

| Status | Meaning |
|---|---|
| 200 | determined (individual blocks may be `unavailable`) |
| 401 | no session (from the shared middleware) |
| 405 | any verb other than GET/HEAD |

The endpoint is mounted unconditionally; blocks that cannot be computed (no web dir, no registry, no DB) report themselves `unavailable` with a reason code
rather than turning the whole response into a 404/500.

## Invariants *(each has a test)*

1. **Allow-list, not deny-list.** Fields are constructed explicitly; there is no reflection over `config`. A regex test over the marshalled JSON asserts no key
   matches `(?i)(url|endpoint|key|token|secret|password|host)` and no string value starts with `http` or contains `://`.
2. **Hashes are cached by stat signature** (path, size, mtime-ns). Unchanged signature → zero re-hash (counter in the test). Changed → recomputed once.
3. **`loaded_sha256` is measured at the boot hook** immediately after the registry load; `disk_sha256` at request time (cached); `disk_matches_loaded`
   is their equality. A write between load and hook is possible; it can only produce a *false mismatch* (visible and conservative), never a false match.
4. **No state mutation**, no outbound call, no model call.
5. **Counts reconcile**: `sum(by_content_type) == total == loaded_rows`; a registry row with a value outside the closed vocabulary is counted under
   `unclassified`, never dropped.
6. **Deterministic**: two calls on unchanged state return identical bodies except `generated_at`.
7. **Passes the boundary guards unchanged**: the body is not altered by `sourceref.RedactJSON` and does not match `search.HasSourceFilenameShape` (otherwise `writeJSON` would answer 410 `withheld`); no key is named `path` or `source_ref`; the registry is reported as a `basename`, never a path.
8. **Boot invariant** (§11.4.254): the server logs one line `provenance: registry_sha=<12 hex> rows=<N> web_files=<M>` at start; absence of the registry or web dir is
   logged and the corresponding block reports `unavailable` — the server does not refuse to start (it must be able to say *why* it is degraded).

## Consumers

`scripts/deploy-gate.sh` (G2/G3/G4/G5/G6), `features/status-live` (panel), Playwright `status-live.spec.ts`.
