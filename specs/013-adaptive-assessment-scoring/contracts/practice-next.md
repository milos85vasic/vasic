# Contract: `GET /api/areas/{area}/questions/next`

**New endpoint.** Session-scoped (requires `X-Session`, via the existing `sessionOf` helper —
`internal/api/lessons.go` line 311 — the same header `ProgressHandler` and `AssessmentSubmitHandler`
already require). Unlike the existing `GET /api/areas/{area}/questions` (deliberately sessionless,
`internal/api/questions.go` line 329, unchanged by this feature), this route serves exactly
**one** recommended question plus the serving token the following submit call must present —
User Story 1's "the next question served is chosen near the learner's current estimate" and FR-009's
cold-start fallback, made into a real HTTP contract.

## Request

```
GET /api/areas/{area}/questions/next
X-Session: <opaque session string, 1-200 bytes, required>
```

No body. `{area}` is a `passage.PID` (26-character ULID), matching every other `{area}` path
parameter already in this router.

## Selection logic (data-model.md §4)

1. **Cold start** (zero `response_log` rows for this session in this area): the lowest
   `difficulty_estimate` item across the union of the practice bank and the graded catalog for this
   area (FR-009's fallback — the practice bank alone has 0 `easy`-seeded items today).
2. **Downgrade override**: if the session's last `Config.DowngradeStreak` (default 3) responses in
   this area are all incorrect, the nearest item to `(currentAbility - Config.DowngradeMagnitude)`
   (default 1.5) rather than to `currentAbility` directly.
3. **Normal adaptive pick**: the item whose `difficulty_estimate` is nearest to the session's
   current `AbilityScore.Ability` for this area.

Every branch mints one `served_question` row (data-model.md §1.4, §5) and returns its token.

## Response — 200

```json
{
  "status": "ok",
  "question": {
    "id": "01J9Z3K7QW8X2N4P6R1T5V7Y9B",
    "area": "01J9Z3K7QW8X2N4P6R1T5V7Y9A",
    "kind": "mcq",
    "prompt": "…",
    "choices": [{"text": "…"}, {"text": "…"}],
    "category": "…"
  },
  "serving": {
    "token": "01J9Z3K7QW9Y3P5Q7S2U6W8Z0C",
    "served_difficulty": 2.5,
    "expires_at": "2026-10-01T09:00:00Z"
  },
  "selection": {
    "rule": "cold_start",
    "downgrade_triggered": false
  }
}
```

- `question` reuses the **existing** `questionWire` rendering (`internal/api/questions.go` line
  290) for field-name consistency with `GET /api/areas/{area}/questions` — **never** the answer key
  (`answer`, `correct_index`, `explanation`), matching the existing answer-withholding discipline
  for every question this route could ever recommend, whether or not it happens to also be a graded
  question under D9's cross-reference.
- `selection.rule` is one of `cold_start` / `downgrade` / `adaptive` — the honest label for which
  branch fired, so a client (or an operator reading logs) never has to infer it from the difficulty
  number alone.
- `serving.expires_at` is `served_at + Config.ServingTokenTTL` (default 24h) — after this, the
  token is refused by submit (400, not scored) and a fresh `GET …/next` call is required.

## Response — 404

The area exists but has no eligible item to serve at all (an emptied or misconfigured bank) —
a determined negative, matching this platform's existing `not_found`/`unavailable` distinction
(`internal/api/progress.go` lines 148-158's documented split, applied here).

```json
{"status": "not_found", "message": "no eligible practice question exists for this area"}
```

## Response — 503

The question bank or passage registry could not be read (mirrors `writeUnavailable`'s existing
shape, `internal/api/chapters.go` line 1135) — never collapsed into the 404 above, per this
project's Honest Instruments principle.
