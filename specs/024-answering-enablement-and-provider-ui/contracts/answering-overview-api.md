# Contract: Answering Overview API

**Implements**: FR-001..FR-006, FR-015, FR-019 | **New file**: `workshop/platform/backend/internal/answering/overview_http.go`

## Route

`GET /api/answering/overview` - authenticated (bearer, same middleware as the other `/api/*` routes
except `/api/health` and `/api/auth/*`; `workshop/platform/backend/cmd/workshop-server/main.go:3497,3654`
describe that exemption list). Registered through the per-feature wiring file (hook line owned by
the orchestrator, see plan "Shared-file protocol"), never by editing the 3.9k-line mux block.

Responses:

| Status | Body | When |
|---|---|---|
| 200 | `AnsweringOverview` (data-model.md §1) | always when the server is up, **including when answering is off** (same philosophy as `/api/ask/status`, `pkg/answer/http.go:643-650`: this route reports a state, successfully) |
| 401 | standard auth error | no/invalid token |
| 500 | `{"status":"error","reason":{"code":"overview_failed","detail":"<no content>"}}` | internal fault; the UI renders an explicit "status unavailable" state; `/api/ask` and search are unaffected (FR-016) |

Headers: `Cache-Control: no-store`.

## Role handling

`audit` is `null` for role `user`; populated (or `{available:false,...}`) for role `admin`. The
omission is server-side. The role is read from the same session object other handlers use (UNCONFIRMED
accessor name; T006 records it).

## Example (answering OFF as deployed today; illustrative shape, no real values beyond the catalogue)

```json
{
  "state": "off_by_config",
  "state_reason": "Answering is not configured on this deployment. Search and browsing are unaffected.",
  "search_unaffected": true,
  "active": {"provider":"none","model":"","endpoint_host":"","locality_declared":"","locality_verified":false,
             "locality_class":"unverified","remote_opt_in":false},
  "thresholds": {"calibrated": true, "calibrated_means": "min_score>0, not measured",
                 "min_score": 0.45, "min_margin": 0.05, "verifier_kind": null, "question_verifier_kind": null},
  "providers": [{"name":"extractive","kind":"builtin","selectable":true,"locality_class":"local"}],
  "gate": {"verdict_status":"none","current_fingerprint":"","history_count":0},
  "audit": null,
  "residency_note": {"present": false},
  "generated_at": "2026-10-20T00:00:00Z"
}
```

## Invariants (each has a test)

1. `providers` equals `answer.Registrations()` by name, exactly once each (single source, FR-003).
2. Serialised body contains none of: any env var VALUE, `Authorization`, `sk-`/`Bearer ` patterns,
   any prompt/passage/answer field names (struct has none) - scan test over all fixtures (SC-008).
3. `state` is a member of the closed vocabulary; the TS union generated/parity-checked against the Go
   constants (FR-002).
4. `search_unaffected` is `true` in every state; a live-search probe asserts reality (FR-016).
5. Idempotent and side-effect free: GET performs no writes, no provider network call beyond the
   existing `Provider.Health` (FR-019).
