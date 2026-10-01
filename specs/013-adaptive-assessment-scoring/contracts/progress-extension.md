# Contract: `GET /api/progress` extension — `ability_score`

**Modifies an existing endpoint**, additively only (FR-013: "rather than introducing a separate,
independently-polled progress endpoint"). Mirrors the **existing** `lesson_completion` addition
(`internal/api/progress.go` lines 266-299) field-for-field in mechanism:

- A new `AbilityScoreSource func(session string) (map[string]AbilityScoreSummary, error)` closure
  parameter on `ProgressHandler`, exactly parallel to the existing `LessonCompletionSource`.
- `nil` is legitimate (no `scoring.Store` configured on this deployment) and simply omits the field
  — never a fabricated zero, matching `LessonCompletionSource`'s own documented rule
  (`progress.go` lines 289-292).
- A source failure does **not** fault the whole request — the reading-position half of this route
  has already been served its own honest answer by the time this runs, matching
  `LessonCompletionSource`'s own documented rule (`progress.go` lines 294-298) exactly.

## Response — 200 (existing shape, one field added)

```json
{
  "positions": { "…": "…" },
  "lesson_completion": { "…": "…" },
  "ability_score": {
    "01J9Z3K7QW8X2N4P6R1T5V7Y9A": {
      "area_title": null,
      "ability": 5.386,
      "attempt_count": 2,
      "updated_at": "2026-09-30T14:02:11Z",
      "last_downgrade_reason": null
    },
    "01J9Z3K7QW8X2N4P6R1T5V7Y9F": {
      "area_title": null,
      "ability": 2.671,
      "attempt_count": 30,
      "updated_at": "2026-09-30T13:58:44Z",
      "last_downgrade_reason": "downgrade: last 3 attempts were all wrong -> serving 1.5 points easier than the normal nearest-to-ability pick, to rebuild a run of correct answers before difficulty climbs again"
    }
  }
}
```

- Keyed by area `passage.PID`, one entry per area this session has at least one `response_log` row
  in — an area never attempted is simply absent, the same "absence is a determined fact, not an
  error" discipline `positions`/`lesson_completion` already use.
- `area_title` is reserved as `null` in Phase 1 (this route does not currently resolve area titles
  for any other field either) rather than invented here — a future consumer (`014-gamification-
  design-system`) resolving titles client-side from `GET /api/areas/{area}` is unaffected either
  way; this field exists so the shape does not need to change when that resolution is added.
- `attempt_count` is FR-016's confidence signal — present unconditionally, the same requirement
  `practice-submit.md`'s `ability` object carries.
- `last_downgrade_reason` is `null` when the session's most recent entry in this area was not a
  downgrade — **User Story 2's Acceptance Scenario 4** (not FR-008, which is unrelated — FR-008
  governs item-difficulty label seeding; the sentence below is quoted verbatim from spec.md's User
  Story 2, Acceptance Scenario 4, the data-contract-only half of that story, with FR-013 as the
  functional requirement that puts this field on `GET /api/progress` in the first place — already
  cited at the top of this document): "the
  change and its cause are available to the client as data … this story defines that data contract
  only; rendering it is out of scope." This field is exactly that contract, and nothing about
  rendering it is implied or required by this document.

## `GET /api/progress`'s existing 404/503 contract is unchanged

This addition changes nothing about the existing three-answer contract documented at
`internal/api/progress.go` lines 146-158 (200 / determined 404 / undetermined 503) for the
reading-position half of the route. A session with **zero** positions, **zero** lesson completions
and **zero** ability-score rows still reaches the existing 404 branch
(`internal/api/progress.go` line 357's `len(positions) == 0 && len(lessonCompletion) == 0` check)
— this plan extends that condition to `&& len(abilityScore) == 0`, so a session that has only ever
submitted a practice answer (no stored reading position, no marked lesson) still gets a 200 with
just `ability_score` populated, not a false 404.
