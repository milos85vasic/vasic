# Contract: Medium HTTP Endpoints (FR-009 – FR-016)

All routes live in `platform/backend/internal/api/medium.go` (new file) and are registered from
`cmd/workshop-server/wire_medium.go` (`registerMedium(mux, deps)`); `main.go` receives one hook line.
Conventions are 015's `contracts/profile-endpoints.md`: `sessionOf(w, r)` identity (authenticated user key, else
`X-Session`), `writeJSON`, `writeError` (closed `ErrorCode` vocabulary), `writeUnavailable` (503 envelope).
No new `search.ReasonCode`. Every route is session-scoped; none accepts a `session` parameter (FR-013).

## 1. `GET /api/profile/medium`

Overall and per-area evidence and signals.

`200`:
```json
{
  "status": "ok",
  "empty": false,
  "preference": {"mode":"auto","medium":null,"set_at":"2026-10-20T10:00:00Z"},
  "overall": {"mediums":[ /* MediumEvidence + state, see algorithm §4 */ ], "comparison": {…}},
  "areas": [{"area":"<slug>","mediums":[…],"comparison":{…}}],
  "retired_areas": [],
  "window": {"from":"…","to":"…","truncated":false,"unmapped":0},
  "generated_by": "deterministic-v1"
}
```
- Zero responses ⇒ `200`, `"empty": true`, zero counts (FR-015).
- Mode `off` ⇒ `200`, `"state":"off_by_learner"`, **no** `overall`/`areas` bodies (nothing computed for display).
- `503` `{"status":"unavailable","reason":{"code":"scoring_store_unreadable|scoring_store_absent",…}}`.

## 2. `GET /api/profile/medium/recommendation?area=<slug>`

`area` optional (absent ⇒ overall). Unknown parameter ⇒ `400 unknown_parameter`. Unknown area ⇒ `404 unknown_area`.

`200`: `Recommendation` (data-model §1.4) with `explanation` (algorithm §4):
```json
{"status":"ok","area":"<slug>","medium":"flashcard","state":"preferred","reason":"preferred_by_evidence",
 "scope":"area","overridden":false,"explanation":{…}}
```
`medium: null` + `reason: "no_signal_yet"` when there is nothing to recommend (still `200`).

## 3. `PUT /api/profile/medium/preference`

Body: `{"mode":"auto"|"pinned"|"off","medium":"mcq|short|flashcard"?}`.
`400 invalid_preference` for: unknown mode; `pinned` without medium; medium with `auto`/`off`; a format medium
(`unsupported_pin_medium`). Idempotent. `200` returns the stored preference with `set_at`.

## 4. `DELETE /api/profile/medium`

Deletes this session's `medium_preference`, `medium_consent` and `medium_event` rows. `200`
`{"deleted":{"preference":1,"consent":0,"events":12},"response_log":"untouched (append-only, spec 013)"}`.
Idempotent (second call deletes 0, still `200`).

## 5. US4 — engagement (all gated; default OFF)

- `PUT /api/profile/medium/consent` body `{"engagement":true|false}`. Turning it off does not delete events;
  deletion is `DELETE /api/profile/medium` (explicit).
- `POST /api/profile/medium/events` body `{"medium","area","duration_bucket","idem_key"}` (+ server stamps `at`).
  - consent off/absent ⇒ `403 consent_required`, nothing stored (fail closed, §11.4.252).
  - any extra JSON field ⇒ `400 unknown_field` (decoder uses `DisallowUnknownFields`).
  - duplicate `(session, idem_key)` ⇒ `200` replay, no second row (UNIQUE constraint, §11.4.253).
  - per-session rate limit ⇒ `429`; body > 1 KiB ⇒ `413`.
- `GET /api/profile/medium/activity` ⇒ per format medium and bucket counts (ACTIVITY only, never fed to the signal).

## 6. Headers and caching

`Cache-Control: no-store` on every route (personal data). No ETag. No CORS additions.

## 7. Disjoint vocabularies (FR-018)

States: `insufficient_evidence|no_clear_preference|leaning|preferred|not_measurable|off_by_learner`.
Reasons: `preferred_by_evidence|leaning_by_evidence|learner_pinned|no_signal_yet|learner_off|scope_fallback_overall`.
Unavailable codes: `scoring_store_unreadable|scoring_store_absent|medium_store_unreadable`.
A single test asserts pairwise-empty intersection and that no member is a prefix-collision of another.
