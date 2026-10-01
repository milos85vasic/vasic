# Contract: Profile HTTP Endpoints (FR-009–FR-012)

Four new read-only `GET` routes under `workshop/platform/backend/internal/api`,
following this codebase's real, existing conventions rather than a new
shape — grounded by reading `lessons.go`, `progress.go`, and `api.go`
(`writeJSON`, `writeError`, `writeUnavailable`, the closed `ErrorCode`
vocabulary, the `X-Session` identity, the three-valued 200/4xx/503
discipline). No route here introduces a new `search.ReasonCode` or a new
`search.Leg` — every failure mode maps onto `ReasonProgressStoreUnreadable`
/ `LegProgress` (the `learning-progress.json` / `progress.json` stores) or
`ReasonCurriculumUnreadable` / `LegCurriculum` (the learning catalog), which
already exist for exactly these two stores.

**Identity**: every route uses `sessionOf(w, r)` (`lessons.go`) exactly as
the existing learning routes do — an authenticated caller resolves to
`authhttp.UserProgressKey(u.ID)`; an unauthenticated caller falls back to the
`X-Session` header. This is FR-009–FR-012's "read from existing data" applied
to identity itself: no new identity mechanism, per spec.md's own Assumptions
("follows whatever identity mechanism the platform uses generally").

**Error envelope** (unchanged from every other route on this surface):

```json
// 4xx — writeError
{ "error": { "code": "unknown_parameter", "message": "...", "field": "cursor" } }
```

```json
// 503 — writeUnavailable
{
  "status": "unavailable",
  "generation": null,
  "reason": {
    "code": "progress_store_unreadable",
    "leg": "progress",
    "message": "...",
    "retry_after_s": null
  }
}
```

---

## 1. `GET /api/profile` (FR-009)

Profile summary: identity, account age, overall completion percentage.

**Request**: no path or query parameters. `X-Session` header or
authenticated session (per Identity, above).

**Response `200`**:

```json
{
  "status": "ok",
  "identity": {
    "kind": "session",
    "key": "opaque, never the raw account id or X-Session value verbatim if authenticated — the same UserProgressKey/X-Session the rest of this surface already uses"
  },
  "account_age": null,
  "completion": {
    "areas_touched": 3,
    "areas_total": 39,
    "overall_percent": 41
  }
}
```

`account_age` is `null` **before** the small `authstore.CreatedAt` read-side
addition lands (see `data-model.md`'s "Honest gap" note — `pkg/authstore.User`
currently carries no `CreatedAt` field, though the underlying `auth_user`
table's `created_at` column already exists and is already populated). This
is a small, in-scope, read-side task (add the struct field, extend the two
existing `SELECT`s), **not** a schema migration and **not** excluded by
FR-013, which forbids new persisted write-side state, not a read of
already-persisted state. Once it lands, `account_age` is populated for
every AUTHENTICATED caller and stays `null` only for an anonymous,
`X-Session`-only caller with no account row at all. The field is present on
the wire in both cases (never omitted) so a client can render "not
available" rather than inferring absence-means-error. `completion.overall_percent` is derived
from `ckit.Completion(area, progress)` summed across every area in
`d.Catalog.Areas` the session has touched at least one lesson of — the same
tally `LessonCompletionFromDeps` already computes per-area in
`internal/api/lessons.go`, aggregated here rather than reported per-area.

**Response `404`**: never. A session with zero recorded activity still gets
a `200` with `completion.areas_touched: 0` and `completion.overall_percent:
0` — this is FR-018's empty-state requirement applied at the API layer: an
empty profile is a determined, valid state, not an absence.

**Response `503`**: `ReasonProgressStoreUnreadable`/`LegProgress` if
`pkg/learning.SessionStore.Get` fails, or
`ReasonCurriculumUnreadable`/`LegCurriculum` if the catalog itself could not
be read — mirroring `LearningDeps.progressOf` and `LessonsHandler`'s own
existing failure mapping exactly.

---

## 2. `GET /api/profile/activity` (FR-010)

Reverse-chronological, paginated activity timeline merging reading-position
updates and assessment attempts (see `data-model.md`'s Activity Timeline
Entry section for which two sources, and why not a third).

**Request query parameters**:

- `limit` — optional, integer, default and max TBD at implementation time
  following this surface's existing `intParam` clamping convention (e.g.
  `/api/search`'s own `limit` clamp), NOT rejected out of range, clamped.
- `cursor` — optional, opaque pagination token (SC-007 requires pagination;
  the exact cursor encoding — e.g. `<at>_<kind>_<id>` matching the sort key
  in `data-model.md` — is an implementation detail for the task that builds
  this handler, not fixed here).

An unrecognised query parameter is rejected via `rejectUnknownParams`,
exactly as `/api/search` and `/api/suggest` already do (`api.go`'s own
documented rule: "an unrecognised key answers a question the caller did not
ask").

**Response `200`**:

```json
{
  "status": "ok",
  "entries": [
    {
      "kind": "assessment_attempt",
      "at": "2026-09-30T12:05:00Z",
      "area_id": "01JABCDEF...",
      "assessment_id": "01JABCDEF...",
      "percent": 84,
      "marked_percent": 84,
      "passed": true,
      "determinate": true,
      "href": "/api/areas/01JABCDEF.../assessment"
    },
    {
      "kind": "reading_position",
      "at": "2026-09-30T11:58:00Z",
      "chapter_slug": "02",
      "pid": "01JABCDEF...",
      "t_seconds": 512.0,
      "href": "/chapters/02/transcript?t=512"
    }
  ],
  "next_cursor": null,
  "has_more": false
}
```

`entries` is `[]`, not `null`, when the session has recorded nothing — this
is the wire-level form of FR-018's empty state (never an error, never an
omitted field). Sort order: `at` descending, tie-broken deterministically by
`(kind, id)` ascending (see `data-model.md`), so two same-timestamp events
render in the same order on every request (spec.md's own Edge Case).

**Response `503`**: `ReasonProgressStoreUnreadable`/`LegProgress` — both
underlying stores (`ProgressStore`, `SessionStore`) map to this one reason;
if only one of the two failed, the response still reports `unavailable`
rather than silently serving a half-merged, mislabelled-as-complete feed —
a partial activity history that does not SAY it is partial is exactly the
kind of confident-but-wrong answer this codebase's other routes refuse to
produce (see `progress.go`'s own extensive commentary on the 404-vs-503
distinction).

---

## 3. `GET /api/profile/reports` (FR-011)

Per-area score/result history, structured for chart rendering and per-area
reporting.

**Request**: no parameters beyond the standard identity header.

**Response `200`**:

```json
{
  "status": "ok",
  "areas": [
    {
      "area_id": "01JABCDEF...",
      "area_title": "Passage Identity and Redaction",
      "completion": { "total_lessons": 6, "complete_lessons": 6, "in_progress_lessons": 0, "percent": 100 },
      "best_attempt": { "assessment_id": "01J...", "at": "2026-09-30T12:05:00Z", "marked_percent": 84, "passed": true, "determinate": true },
      "attempt_count": 2,
      "retake_href": "/api/areas/01JABCDEF.../assessment"
    }
  ],
  "ability_scores": null,
  "ability_scores_status": "not_enough_data"
}
```

`areas` is built from exactly the same per-area primitives
`AssessmentHandler` already uses: `ckit.Completion`, `p.BestAttempt(as.ID)`,
`len(p.AttemptsFor(as.ID))` — restricted to areas the session has touched at
least one lesson or attempt of (an untouched area contributes no row, same
discretion `LessonCompletionFromDeps` already applies, for the same stated
reason: a zero-and-zero row for every area in the whole catalogue would make
a small answer the size of the catalogue).

`ability_scores` / `ability_scores_status` is FR-019's degrade-gracefully
contract: `"not_enough_data"` (with `ability_scores: null`) whenever spec
013's data source has nothing for this session or is not yet wired at all —
this is the determined, not-an-error state the spec requires, and it is the
DEFAULT until spec 013 ships, not a state this feature has to wait to
implement. Once spec 013's read-only interface exists, `ability_scores_status`
becomes `"ok"` and `ability_scores` carries the real per-area/ability rows;
the wire shape for that state is **not defined here**, per spec.md's own
Assumption that this specification does not define or duplicate spec 013's
data model — it is deferred to whichever task wires the actual read.

**Response `503`**: same as endpoint 1.

---

## 4. `GET /api/profile/areas/{area}` (FR-012)

One area's full attempt/score history — the detail view a "retake
self-assessment" link's surrounding context comes from.

**Request**: `{area}` is a 26-character ULID, validated identically to
every other `{area}` path parameter on this surface (`passage.ParsePID`,
`ErrMalformedPID` on failure — see `learningArea`'s own first check in
`lessons.go`).

**Response `200`**:

```json
{
  "status": "ok",
  "area_id": "01JABCDEF...",
  "area_title": "Passage Identity and Redaction",
  "completion": { "total_lessons": 6, "complete_lessons": 6, "in_progress_lessons": 0, "percent": 100 },
  "availability": { "available": true, "required_lessons": ["..."], "missing_lessons": [], "complete_of_required": 6, "required_count": 6 },
  "attempts": [
    { "assessment_id": "01J...", "at": "2026-09-30T12:05:00Z", "points": 21, "max_points": 25, "percent": 84, "marked_points": 21, "marked_percent": 84, "passed": true, "determinate": true }
  ],
  "best_attempt": { "...": "same shape as one entry of attempts, or null" },
  "retake_href": "/api/areas/01JABCDEF.../assessment"
}
```

Every field is read verbatim from the SAME functions `AssessmentHandler`
already calls (`availabilityObject`, `ckitCompletion`, `attemptObjects`,
`p.BestAttempt`) — this endpoint is a read-only reprojection of data the
learning surface already serves, assembled for the profile page's own
layout rather than the area-detail page's. **No new grading, scoring, or
gating logic** (FR-016): `retake_href` points at the EXISTING
`POST /api/areas/{area}/assessment/submit` flow (via its `GET` companion
`/api/areas/{area}/assessment`, exactly as `AssessmentHandler`'s own
`submit_href` field already does) — this endpoint does not itself accept a
submission.

**Response `404`** — `ErrAreaNotFound`, when the area does not exist or is
not currently published (FR-020's "target area is no longer available"
case) — reusing the SAME `learningArea` resolution path (and its existing
`AreaHeldBack`/`AreaUndetermined`/`AreaBuildInconsistent` handling) every
other `{area}`-scoped route already goes through, rather than a second
existence check invented for this endpoint.

**Response `503`**: same reasons as endpoint 1, plus
`ReasonCurriculumUnreadable`/`LegCurriculum` on a catalog read failure —
identical to `AssessmentHandler`'s own existing failure surface.
