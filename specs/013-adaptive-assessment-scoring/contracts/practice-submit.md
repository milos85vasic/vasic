# Contract: `POST /api/areas/{area}/questions/{question}/submit`

**New endpoint** — FR-001: "no such endpoint exists today (only a one-shot, lesson-gated
end-of-area assessment submit route exists)." Session-scoped, same `X-Session` discipline as
`practice-next.md`. Consumes the serving token `GET .../questions/next` minted (FR-014, §11.4.253 —
see plan.md's "Idempotency and the served-question problem" and data-model.md §5 for the full
mechanism this contract is the wire shape of).

## Request

```
POST /api/areas/{area}/questions/{question}/submit
X-Session: <opaque session string, required>
Content-Type: application/json

{
  "serving_token": "01J9Z3K7QW9Y3P5Q7S2U6W8Z0C",
  "chosen": [0],
  "text": null
}
```

- `serving_token` is **required**. Its absence, or a token this session/area/question combination
  was never actually issued, is refused per FR-014 — fail-closed, never scored, matching this
  platform's existing pattern for an unresolvable choice token (`internal/api/lessons.go` lines
  756-762) and for an empty/malformed graded submission
  (`internal/api/assessment_disclosure.go`'s own documented prior-defect fix).
- `chosen` (array of choice indices, for `mcq`) and `text` (for `short`/`flashcard`) follow the
  existing `assessment.Question` kind vocabulary (`pkg/assessment/question.go` lines 45-56) —
  exactly one of the two is populated per `KindOf`, matching the existing `decodeSubmitBody`
  discipline the graded path already applies (`internal/api/lessons.go` line 717).
- Grading an `mcq`/`short` response against the question's own answer key happens **server-side**,
  using the same `ckit`-adjacent correctness check the graded path uses where the question is also
  graded content, or a direct `Question.CorrectIndex`/`Question.Answer` comparison otherwise — this
  contract does not change how correctness is decided, only how the decision is logged and scored.

## Response — 200, first (real) submission

```json
{
  "status": "ok",
  "result": {
    "correct": true,
    "explanation": "…"
  },
  "scoring": {
    "entry_id": "01J9Z3K8AB1C2D3E4F5G6H7J8K",
    "ability_before": 5.009,
    "ability_after": 5.386,
    "delta": 0.377,
    "k_factor": 0.759,
    "served_difficulty": 5.0,
    "downgrade_triggered": false,
    "reason": "normal adaptive pick: nearest-difficulty item to current ability estimate"
  },
  "ability": {
    "area": "01J9Z3K7QW8X2N4P6R1T5V7Y9A",
    "current": 5.386,
    "attempt_count": 2
  },
  "next": {
    "id": "01J9Z3K7QW8X2N4P6R1T5V7Y9D",
    "serving": {
      "token": "01J9Z3K7QW9Y3P5Q7S2U6W8Z0E",
      "served_difficulty": 5.5,
      "expires_at": "2026-10-01T09:05:00Z"
    },
    "selection": {"rule": "adaptive", "downgrade_triggered": false}
  }
}
```

- `scoring` is `ResponseLogEntry` rendered on the wire — every field FR-002 requires is present
  (session is implicit in the auth context, not re-echoed), and `reason` is **never empty**, for a
  downgrade or not (FR-002, FR-011).
- `ability` is exactly what SC-002 requires: the caller's own next `GET /api/progress` read (or this
  same response) reflects this submission with no staleness, and `attempt_count` is FR-016's
  confidence signal, present on every response, not only on request.
- `next` is the **same shape** `practice-next.md` returns, included here so a client driving a
  continuous practice session never has to make a second GET call per question — but `GET
  .../questions/next` remains independently callable (e.g. on a fresh page load) and mints its own
  fresh token when called that way.

## Response — 200, retried (idempotent replay)

An identical POST retried with the **same** `serving_token` (a network-level retry, not a new
attempt) returns the **exact stored result** of the first successful call — same `entry_id`, same
`ability_after` — computed **once**, not recomputed:

```json
{
  "status": "ok",
  "replay": true,
  "result": { "…": "…" },
  "scoring": { "…": "…", "entry_id": "01J9Z3K8AB1C2D3E4F5G6H7J8K" },
  "ability": { "…": "…" }
}
```

`"replay": true` is the one field this shape adds over the first-submission response — an honest
signal, not a silent difference, that this call scored nothing new (§11.4.253's "second attempt
refused, caught by caller as duplicate-already-succeeded = SUCCESS," rendered on the wire rather
than left implicit). `next` is omitted on replay — the original response already carried it, and
re-minting a second `served_question` row on a retry would itself violate the single-token-per-serve
invariant this whole mechanism exists to protect.

## Response — 400, refused (fail-closed, FR-014)

```json
{
  "status": "error",
  "error": {
    "code": "serving_token_invalid",
    "message": "this serving token was not issued to this session for this question, is expired, or was never issued — re-read GET /api/areas/{area}/questions/next and submit the token it returns"
  }
}
```

Covers: missing token; token issued to a different session; token naming a different
area/question than the path; expired token (past `Config.ServingTokenTTL`); structurally malformed
body. **None of these default toward an outcome that benefits the learner's score** (FR-014's own
words) — no `response_log` row is written, no `AbilityScore` is touched, and the previously-served
(now-refused) token remains unconsumed rather than silently marked used, so a legitimate retry with
the SAME token after correcting a transient client bug can still succeed.

## Response — 403, forbidden

Reserved for parity with `AssessmentSubmitHandler`'s own `ErrAssessmentLocked` shape
(`internal/api/lessons.go` lines 811-829) **only if** a future area-level gate is added to the
practice bank; the practice bank carries no such gate today (it is explicitly ungated, unlike the
graded assessment), so this status is not expected to occur in Phase 1 and is documented here only
so a client's error-handling switch statement is not surprised by it later.


## Reconciled by S2 on 2026-10-20 (independent review of the first S2 commits)

- **`next` shape.** The embedded `next` object is exactly what `GET .../next` returns:
  `{"question": {...}, "serving": {...}, "selection": {...}}` (the example above showed a bare `id`; that was a
  sketch). It is omitted on a replay.
- **Error codes.** A missing, unknown, foreign, expired or stale token AND a structurally malformed body (including
  an unknown JSON key) are `400 serving_token_invalid`, as the section above states. A well-formed body whose
  `chosen` is not exactly one served option is `400 unknown_parameter` (field `chosen`). A question that is not in
  the session's pool is `404 question_not_found`.
- **Disclosure.** `result.correct`, the score movement and the events exist only for pooled rows, i.e. rows whose key
  is disclosed to this session (see `practice-next.md`). The explanation is therefore always disclosable.
- **Graded submit idempotency.** `POST /api/areas/{area}/assessment/submit` honours an optional `Idempotency-Key`
  header (<= 200 bytes): a retry with the same key replays the stored scoring entries instead of scoring again.
  Without a key a retry is scored again (documented limitation).

### Second reconciliation (S2, 2026-10-20, re-review)

- `POST /api/areas/{area}/assessment/submit` and `Idempotency-Key`: a key longer than 200 bytes is refused
  `400 idempotency_key_invalid` (it is never silently dropped, which would turn a retry into a second score); a key
  already used in this (session, area) for a DIFFERENT paper is `409 idempotency_key_reuse`. Both are decided before
  anything is recorded.

## Reconciled by n1-013-adaptive on 2026-10-21 (kind-easing, integrity reading)

- **Request, flashcards.** A flashcard served by a kind-eased downgrade (`serving.grading == "self_rated"`) is
  answered with `{"serving_token": "...", "recalled": true|false}` and NO `chosen`; a multiple-choice question takes
  `chosen` and NO `recalled`. Anything else is 400 `unknown_parameter` (field `recalled` / `chosen`). A flashcard can
  be answered only by a session it was served to (else 404 `question_not_found`), and only with the token minted for
  it. (The `text` field shown in the request above is not accepted by this route: the body is strict.)
- **Response, flashcards.** `result.self_rated: true`, `result.answer` (the flipped card's answer) and
  `result.correct == recalled`. The entry is scored through the same pipeline, `scoring.downgrade_triggered` is true
  and `scoring.reason` carries the downgrade reason with the "kind eased" note.
- **`scoring.integrity`** (research-derived A9, additive, omitted when it could not be read): the repeat-attempt /
  rapid-guess reading for this area: `{flags[], attempts, repeat_attempts, repeat_after_wrong, rapid_guesses,
  rapid_wrong}`. `repeat_after_wrong` counts answers to a question the session had already answered with at least one
  wrong; `rapid_guesses` counts practice answers STRICTLY faster than `Config.RapidGuessMin` (2s, UNVALIDATED) after
  the serve (a graded outcome has no serve time and is never counted). A flag is raised at `GamingRepeatFlag` (3) /
  `GamingRapidFlag` (5). It is evidence, never a verdict: it changes no score.
- **`achievement_events`** now includes `adjusted` (coalesce_key `adjusted:<area>`, `modal_worthy` false,
  `remedial_href` = the question's study link, else null) on the entry answering a downgrade-served question.
