# Contract: Achievement events (the stream spec 014 consumes)

**Added by spec 026 on 2026-10-20 (decision D3).** Spec 014 (`014-gamification-design-system`) consumes an
`AchievementEvent` stream that spec 013 was assumed to produce but never defined. This document is that
definition. It is additive: it changes no existing 013 contract except by adding one array to the submit
response and one query parameter and one field to `GET /api/progress` (both nil-tolerant, like the existing
`lesson_completion` and `ability_score` additions).

Consumer shape (spec 014 `data-model.md`, TypeScript): `AchievementEvent { id, kind, title, message,
scoreDelta?, occurredAt, coalesceKey, modalWorthy? }`, `AchievementKind = 'level-up' | 'chapter-complete' | 'adjusted'`.

## 1. Wire shape (server, snake_case)

```json
{
  "seq": 41,
  "id": "01J9Z3K7QW9Y3P5Q7S2U6W8Z0C",
  "kind": "level-up",
  "title": "Ability level up",
  "message": "Your answers moved you up to level 6 in this area.",
  "score_delta": 0.84,
  "occurred_at": "2026-10-20T09:15:02Z",
  "coalesce_key": "ability:01J9Z3K7QW8X2N4P6R1T5V7Y9A",
  "modal_worthy": true,
  "area": "01J9Z3K7QW8X2N4P6R1T5V7Y9A",
  "remedial_href": null
}
```

| Field | Type | Rule |
|---|---|---|
| `seq` | integer | Monotonic per database (`AUTOINCREMENT`); replay cursor. NOT part of 014's type (the adapter drops it). |
| `id` | string (ULID) | Stable id of this occurrence (014 uses it for idempotent re-delivery). |
| `kind` | `level-up` / `chapter-complete` / `adjusted` | Wire value for a downgrade is `adjusted` (013's internal `DowngradeTriggered` is unchanged). |
| `title`, `message` | string | Fixed server-side copy templates (section 4). Required. |
| `score_delta` | number or omitted | `level-up`: `ability_after - ability_before` rounded to 2 places; `adjusted`: omitted (a downgrade routes difficulty, it does not remove points); `chapter-complete`: omitted. |
| `occurred_at` | RFC 3339 UTC | Server wall clock at the write that caused the event. |
| `coalesce_key` | string | `ability:<area>` (level-up), `chapter:<area>` (chapter-complete), `adjusted:<area>` (adjusted). |
| `modal_worthy` | boolean | Producer default: `true` for `level-up`, `false` otherwise. Spec 014 T020 (operator routing map, O-3) may override it client-side; this is the default only. |
| `area` | string (area PID) | The area the event is about. |
| `remedial_href` | string or null | `adjusted` only: the served question's `lesson_sections_study_href`, else `citations_study_href` (`internal/api/questions.go:516,532`), else null. Consumed by 014 FR-022. |

The 014 adapter (task T016) maps: `score_delta` -> `scoreDelta`, `occurred_at` -> `occurredAt`, `coalesce_key` -> `coalesceKey`, `modal_worthy` -> `modalWorthy`; `seq`, `area`, `remedial_href` are carried on the adapter's extended event.

## 2. Triggers (when an event is emitted)

| Kind | Trigger | Emitted by |
|---|---|---|
| `level-up` | In `Store.recordResponse`, `floor(ability_after) > floor(ability_before)` AND `attempt_count >= Config.LevelUpMinAttempts` (default 5, `[CONFIGURABLE-DEFAULT]`, NOT POC-verified; the confidence guard follows FR-016). "Level" = `floor(ability)` on the 0-10 scale, 0..10. Only upward crossings emit; a downward crossing emits nothing (a downgrade is the `adjusted` event). | `pkg/scoring` (practice and graded paths alike, because both go through `recordResponse`) |
| `adjusted` | The logged entry has `DowngradeTriggered = true` (FR-011). | `pkg/scoring` |
| `chapter-complete` | An area's lesson tally transitions to `complete_lessons == total_lessons` (`LessonCompletionSummary`, `internal/api/progress.go:266-272`) as a result of `POST /api/areas/{area}/lessons/{lesson}/state`. Emitted once per (session, area): a later un-mark and re-mark does not re-emit. | the lesson-state handler (`internal/api/lessons.go`) calling `scoring.Store.RecordAchievement` |

**Granularity of `chapter-complete` is an open operator decision (O-5).** The default above treats the curriculum
AREA as the "chapter" because that is the only completion tally the server holds per area. If the operator decides that
"chapter" means a recorded chapter's reading completion, only this row and the `chapter:<area>` key change.

A routine per-answer score delta that crosses no level and triggers no downgrade emits NO event (014 spec edge case:
it must not produce a toast or badge).

## 3. Storage and idempotency (append-only, §11.4.253)

New table in `scoring.db`, created by the Phase 1 schema task (T008a):

```sql
CREATE TABLE achievement_event (
  seq             INTEGER PRIMARY KEY AUTOINCREMENT,
  id              TEXT NOT NULL UNIQUE,
  session         TEXT NOT NULL,
  area            TEXT NOT NULL,
  kind            TEXT NOT NULL CHECK (kind IN ('level-up','chapter-complete','adjusted')),
  title           TEXT NOT NULL,
  message         TEXT NOT NULL,
  score_delta     REAL,
  coalesce_key    TEXT NOT NULL,
  modal_worthy    INTEGER NOT NULL CHECK (modal_worthy IN (0,1)),
  remedial_href   TEXT,
  source_entry_id TEXT,              -- response_log entry id; NULL for chapter-complete
  occurred_at     TEXT NOT NULL,
  UNIQUE (session, kind, area, source_entry_id)
);
```

An immutability trigger (same pattern as `response_log`, T008) forbids UPDATE and DELETE. A retried submit that resolves
to the same `response_log` entry (the existing idempotent token path) hits the `UNIQUE` key and emits nothing new.
For `chapter-complete`, `source_entry_id` is NULL and SQLite treats NULLs as distinct, so once-per-(session, area) is
enforced in `RecordAchievement` by a lookup inside the same transaction, not by the constraint (stated so nobody
assumes the constraint covers it).

## 4. Copy templates (fixed, no learner-negative vocabulary)

014 FR-003/FR-016 forbid danger/warning framing for `adjusted`. Templates live in one Go file as named constants so the
014 vocabulary gate can be pointed at them:

| Kind | `title` | `message` |
|---|---|---|
| `level-up` | `Ability level up` | `Your answers moved you up to level {level} in this area.` |
| `chapter-complete` | `Chapter complete` | `You completed every lesson in this area.` |
| `adjusted` | `Path adjusted` | `We moved your next question to an easier one so you can rebuild momentum; the harder questions come back as your answers improve.` |

## 5. Delivery

1. **Inline on submit**: `POST /api/areas/{area}/questions/{question}/submit` and the graded submit return, additively,
   `"achievement_events": [ ...wire events caused by this submission... ]` (empty array when none). A replayed
   (idempotent) submission returns the SAME events for that entry.
2. **Replay / reload-safe**: `GET /api/progress?events_after=<seq>&events_limit=<n>` returns, additively,
   `"achievement_events": { "events": [...], "next_after": <seq> }` (default limit 50, max 200). Events are scoped to
   the requesting session. The field is omitted when no scoring store is configured (never a fabricated empty list),
   matching `ability_score`'s nil rule. It does not change the existing 200/404/503 contract; a session whose only data
   is events still gets a 200.
3. **`chapter-complete` delivery**: the lesson-state response contract is outside 013; the client calls (2) after a
   lesson-state write. Inline delivery on the lesson-state response is optional and UNCONFIRMED (not required here).
4. No server push (SSE/WebSocket) in this feature: poll + inline covers the "no reload" requirement (014 SC-001) because
   every event is caused by a request the client itself just made.

## 6. Not covered

Badge persistence on the chapter list (014 FR-010/011 state) is client state derived from `chapter-complete` events and
the existing `lesson_completion` tallies; no new server field. Kind-easing and any change to which questions are served
is spec 013 T036b (deferred, O-4), not this contract.
