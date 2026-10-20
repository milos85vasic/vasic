# Contract: Materials HTTP Endpoints (FR-001, FR-003, FR-006, FR-009, FR-019, FR-025, FR-026)

New file `platform/backend/internal/api/materials.go`, registered by `registerMaterials(mux, deps)` in
`cmd/workshop-server/wire_materialgen.go`. Identity, error envelope, 200/4xx/503 discipline follow spec 015's
profile contract. Outcome statuses follow `pkg/answer/outcome.go:84-91`: **declined = 200, unavailable = 503**.
`Cache-Control: no-store` everywhere. Unknown query parameters or JSON fields ⇒ `400`.

| Method / path | Purpose |
|---|---|
| `GET /api/materials/provider` | read-only disclosure: `{enabled, provider, model, locality, remote_allowed, budgets_remaining}` |
| `POST /api/materials/preflight` | validates a request, returns the disclosure + token upper bound; no provider call |
| `POST /api/materials` | create a job (headers `Idempotency-Key`; body request) ⇒ `202 {job_id, status:"pending"}` |
| `GET /api/materials/jobs/{job_id}` | job status/phase; terminal states embed the material or outcome |
| `GET /api/materials` | the caller's materials, newest first (paginated by cursor, max 50) |
| `GET /api/materials/{id}` | one material (owner only) with items, citations, quotes, provenance |
| `DELETE /api/materials/{id}` | learner deletes own material (ownership row); idempotent |
| `GET /api/admin/materials` | admin review list (FR-025); admin role only; each read logged |

### `POST /api/materials` request / responses

```json
{"form":"flashcards","topic":"…","count":6,"remote_ack":{"provider":"ollama","locality":"local"}}
```
- `202` job created; `200` idempotent replay of an existing job; `400` invalid (`invalid_topic`, `invalid_form`,
  `invalid_count`, `remote_ack_required`, `remote_ack_mismatch`, `unknown_field`); `401` unauthenticated;
  `409 idempotency_conflict`; `503` envelope for `generation_disabled`, `no_provider`, `budget_exceeded`,
  `rate_limited`, `thresholds_uncalibrated`, … (the same codes as `data-model.md` §2), evaluated **before** the job
  is created where they are knowable at admission, otherwise reported on the job.

### Terminal job body

```json
{"status":"generated","material":{"id":"…","form":"flashcards","items":[{"front":"…","back":"…",
  "citations":[{"pid":"…","href":"/passage/…","withheld_reason":null}],"quote":"…"}],
  "provenance":{ /* data-model §6 */ }}}
{"status":"declined","reason":{"code":"insufficient_coverage","message":"…","retrieval":{"top_score":0.41,"margin":0.02,"admitted":2}},
 "suggestion":"ask an operator to add a source on this topic"}
{"status":"unavailable","reason":{"code":"budget_exceeded","which":"session_daily","resets_at":"2026-10-21T00:00:00Z"}}
```

A declined body never contains generated text. Citation objects reuse the answering `Citation` shape and its
withheld-reason convention (`pkg/answer/outcome.go:357-380`).

### Authorisation
Owner-only reads (FR-009). The admin list requires `role=admin`, returns provenance and verification summaries,
omits `topic`/bodies unless OD-3 approved, and writes an access record per call (who, when, count).

### Closed error codes
`invalid_topic, invalid_form, invalid_count, remote_ack_required, remote_ack_mismatch, unknown_field,
idempotency_conflict, not_found, forbidden` — added to this route family's own list (the platform's global
`ErrorCode` vocabulary is not edited; a parity test asserts none collides with an existing code).
