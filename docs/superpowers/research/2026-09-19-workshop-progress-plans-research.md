# Research: Workshop Progress & Plan Surface (for future HelixQA brainstorming)

Read-only investigation, 2026-09-19, live-state facts captured against
`workshop-curriculum_platform_1` (`source_commit=fae0a71a32d3765e55f48ed866ad3fed4175c9a0`,
`source_dirty=true`, `chapters=4`). Input for the "Progress/Plan" sub-project
named in
`docs/superpowers/specs/2026-09-18-workshop-chapter-browsing-qa-design.md`
("First of 8 planned sub-projects... Out of scope for this sub-project: ...
progress/plan, areas/practice, diagnostics/status"). All paths relative to
`workshop/`.

**Scope boundary, stated up front**: `/api/areas` and the practice/quiz
mechanics belong to the separate "areas/practice" sub-project. This document
touches `/api/areas` only insofar as the Progress and Plan surfaces consume
it — it does not re-derive `AreaHandler`'s publication-state machine
(`internal/api/areas.go`), which is that sub-project's own subject.

## 1. Two real, distinct routes/components — not one merged surface

Unlike `/search`+`/ask` (one `InquiryComponent`), `/progress` and `/plan` are
**two separate components with no shared parent**, both real and
auth-guarded:

`app.routes.ts:106-117`:

| Route | Component | File |
|---|---|---|
| `GET /progress` | `ProgressComponent` | `features/progress/progress.component.ts` (422 lines) |
| `GET /plan` | `StudyPlanComponent` | `features/plans/study-plan.component.ts` (225 lines) |

They cross-link each other (`progress.component.ts:55-57`'s "See a study
plan built from this →"; `study-plan.component.ts:126-130`'s fallback links
back to `/` and `/progress`), and both consume the same two backend
signals — `/api/progress` and `/api/areas` — but render independently.

**`/plan` has NO backend endpoint of its own.** `study-plan.component.ts:14-24`
states this explicitly: no `/api/plan` exists in any contract, no
spaced-repetition scheduler is built, and the "study plan" is a **client-computed
recommendation**: `core/study-plan.ts`'s `rankAreasForStudy()` takes the
`Area[]` array from `GET /api/areas` and the `furthest_s` map from
`GET /api/progress`, and produces an ordering — unreached areas first (in
recording order via `area.from_s`, since no authored curriculum-order field
exists), reached areas after. This is the single most important framing fact
for a bank: **there is nothing to POST to on `/plan`, and no ranking to
assert against a server oracle** — the oracle is the pure function
`rankAreasForStudy` itself (`core/study-plan.ts:46-70`), already covered by
unit tests (§4).

## 2. `/api/progress` — the one real backend endpoint in scope

`internal/api/progress.go`, registered `GET`/`POST /api/progress`
(`main.go:814-815`) on the **authenticated content mux** (`wrapWithAuth`,
`main.go:3339`+) — confirmed live: `curl -i http://127.0.0.1:8087/api/progress`
→ `401 {"error":"unauthorized","message":"authentication required"}`.

**Storage is a flat JSON file, not the index DB, and that is deliberate**
(`progress.go:42-49`): the index database is rebuilt wholesale on every
re-index, and a reading position is not derived from the corpus, so it lives
in `<indexDir>/progress.json`, written atomically (temp-file-plus-rename,
`progress.go:117-124`) so a torn write cannot corrupt the whole store.

**Session identity has TWO layers, and one is now effectively dead code on
this build.** `ProgressHandler` (`progress.go:191-194`):
```
session := r.Header.Get("X-Session")
if u, _, ok := authhttp.FromContext(r.Context()); ok {
    session = authhttp.UserProgressKey(u.ID)
}
```
`authhttp.Middleware` (`pkg/authhttp/authhttp.go:144-161`) **unconditionally
401s any request with no valid token** before it ever reaches this handler —
there is no code path that lets an unauthenticated request through with
`FromContext` returning `ok=false`. So on this build, **every request that
reaches `ProgressHandler` already has an authenticated user, and the
`X-Session`-keyed branch can never execute in production.** The frontend
still sends `X-Session` on every progress/lesson call
(`core/api.ts:781-807`'s `sessionHeader()`, `crypto.randomUUID`-minted,
`localStorage`-cached) — it is simply overridden every time. This is worth a
deliberate bank decision: test the auth-derived key path (the only reachable
one today), and treat the anonymous `X-Session`-only path as
untestable-live-but-real-in-code (it is exercised directly at the Go level —
see `internal/api/progress_test.go`, which calls `ProgressHandler` without
the auth middleware at all).

**Request/response shapes, measured from `progress.go` and
`progress_test.go`:**

- `GET /api/progress` →
  - `200 {"positions": {"<chapter_slug>": {"chapter_slug","pid","t_seconds","at"}, ...}}`
  - `404 {"status":"not_found","message":"no reading position is stored for this session"}` — a DETERMINED negative (store read, nothing there)
  - `503` — §4 envelope: `{"status":"unavailable","reason":{"code":"progress_store_unreadable","leg":"progress","message":...,"retry_after_s":null}}` plus `X-Workshop-Search-Status: unavailable` header — the store exists on disk and could not be parsed (torn/corrupt file). **The 404/503 split is this route's entire reason for existing** (`progress.go:148-183`): a corrupt store answering 404 would tell a reader "you have never read anything here" on the strength of a file nobody could open.
- `POST /api/progress` body `{"chapter_slug","pid","t_seconds"}` →
  - `200 {"stored": {...}}`
  - `400 unknown_parameter` for: missing/unsafe `chapter_slug` (path-traversal guarded — `../etc` is rejected), missing/malformed `pid` (must parse as a 26-char ULID — `sha256:...` and short strings are rejected with `malformed_pid`), missing or negative `t_seconds`. **`t_seconds` is never defaulted to `0`** — "the reader is at the start" and "the client did not say" are deliberately different facts (`progress.go:250-257`).
  - A later POST for the SAME `chapter_slug` **overwrites**, never accumulates — one position per chapter, not a history.

**Frontend read side**: `core/api.ts:701-708`'s `progress()` normalises the
body via `normaliseProgress` (`core/knowledge.ts:618-636`) into
`ProgressState{ entries[], furthest_s: {chapter_slug: max t_start_s} }`. Note
the field-name mismatch across the boundary that the client already
compensates for: the server's POST field is `t_seconds` but the GET response
and `ProgressEntry` use `t_start_s` — `core/api.ts:710-732`'s own long
comment documents this was a **real, previously-shipped bug** (the client
used to POST `t_start_s`, got 400 `unknown_parameter` on every write, and
every progress write was silently dropped until fixed).

## 3. `/api/progress` writes come from the QUIZ surface, not from watching/reading — a real, non-obvious split

**This is the highest-value finding in this document.** The Progress page's
own copy says "Measured as position in the recording" and shows a rail
labelled "Your furthest point in the recording" — but grep for every caller
of `WorkshopApi.recordProgress()` finds exactly one, and it is not a video or
transcript component:

- `features/practice/practice.component.ts:604-616` — `record(q: Question)`
  fires on every answered practice/quiz question, and stores the **cited
  passage's own citation** (`q.citations[0]`: `chapter_slug`, `pid`,
  `t_start_s`) as a reading position, with its own doc comment stating why:
  *"There is no per-question progress endpoint on this build, so what is
  stored is what genuinely exists: the passage the question cites... rather
  than an invented score row."* Failed writes are queued (`unsaved` signal)
  and retried via `retrySaves()`.

**Meanwhile, `chapter-detail.component.ts` and `transcript.component.ts` —
the actual video/transcript readers — write to a COMPLETELY DIFFERENT,
browser-local-only store**: `core/progress.ts`'s `ProgressStore`
(`localStorage`, key prefix `workshop-progress:`), injected at
`transcript.component.ts:550` and written at `transcript.component.ts:1197`
(`this.progress.write(this.slug(), p.pid, p.t_start_s)` on every seek). This
store **never calls the server** — it is `localStorage`-only, and the UI is
honest about that inline: the save toast reads *"Position saved at ... (this
browser only)"* (`transcript.component.ts:1198-1200`).

**Consequence, stated plainly**: a reader who watches/reads an entire
chapter's transcript top to bottom, but never answers a single practice
question, will see `/progress` report "Nothing reached yet" — the rail, the
percentage, and the study-plan ranking are **all driven exclusively by quiz
activity**, never by reading/watching activity, even though every piece of
UI copy on `/progress` and `/plan` talks about "the recording" and "how far
you have got" in a way that reads as if it tracked playback. This is not
flagged as a defect anywhere in the code (the practice component's own
comment defends the choice as "a real fact... rather than an invented score
row"), but it is exactly the kind of load-bearing behavioral fact a bank
must assert directly rather than assume from the page copy.

## 4. Existing coverage — do not duplicate

**Go, `/api/progress` (`internal/api/progress_test.go`, all in-process
against the real handler)**: `TestProgressRoundTrip`,
`TestProgressEmptyIs404AndBrokenIs503` (the 404-vs-503 split, with a torn
store), `TestProgressSessionIsolation` (missing header → 400; two sessions
never see each other's positions), `TestProgressRejectsUnkeyedOrUnpositionedWrites`
(8 malformed-body cases including path-traversal `../etc` and a content-hash
posing as a pid), `TestProgressOverwritesWithinAChapter`,
`TestProgress503CarriesTheDocumentedEnvelope` (full §4 envelope shape +
`X-Workshop-Search-Status` header agreement).

**Go, account-derived keying and migration** (mentioned in the auth/session
research doc — not re-derived here): `pkg/authhttp/progress_bridge_test.go`
(`TestUserProgressKeyDerivesFromUserID`, `TestProgressIsolatedPerAccount` —
two accounts get disjoint keys, same account gets a stable key across
re-logins); `internal/api/progress_census_test.go`
(`TestAnonymousCensus_ExcludesAccountDerivedKeys`,
`TestAnonymousCensus_EmptyStoreIsValid`,
`TestAnonymousCensus_CorruptStoreIsUnreadable`,
`TestMigrateSession_MovesPositionsAndRemovesSource`,
`TestMigrateSession_KeepsNewerExistingPosition`,
`TestDeleteSession_RemovesRecord`) — this is the T574-576
anonymous-to-authenticated progress cutover
(`POST /api/auth/migrate-progress`, `cmd/workshop-server/migration_wiring.go`):
body `{"record_id","choice":"migrate"|"discard"}`, requiring its own bearer
token check (sits on `authMux`, not the content mux), answering `503
migration_not_configured` when no census is wired (the ordinary case on this
build — no `-migration-census` flag was found configured), `404
record_not_found`, `409 already_recorded` (with the prior `outcome` echoed
back), or `200 {"status":"ok","outcome":{...}}`. **This flow is already
documented in the auth & session research doc** (§1, §5, §6h there) — it is
recapped here only because it directly mutates the `progress.json` store this
document is otherwise about; a bank exercising `/api/progress` state
transitions should be aware `POST /api/auth/migrate-progress` is the one
other route that can move or delete entries in it.

**Frontend, ranking heuristic only** (`core/study-plan.spec.ts`, pure unit
tests against `rankAreasForStudy`/`estimateAreaReached`, no HTTP): unreached
areas rank first; an area is "reached" once furthest position passes its
`from_s`; an area with no timed position can never be "reached"; sort order
is unreached-then-reached, chronological within each group; every unreached
reason string names a distinct checkable fact; one paired-mutation case
(reading from the wrong chapter is caught).

**Frontend, `POST /api/progress` wire contract only**
(`core/api-progress.spec.ts`): asserts the field name is `t_seconds` (not
`t_start_s`), the `X-Session` header is sent, and `t_seconds: 0` is sent as a
real value rather than omitted.

**Frontend, `StudyPlanComponent`** (`features/plans/study-plan.component.spec.ts`):
**only 2 tests, both about ONE method** — `progressCaveat()` distinguishing
the "haven't started yet" (empty) sentence from the "could not be read"
(unavailable) sentence. **Nothing in the existing spec suite renders or
asserts the ranked list itself, the `empty`/`absent`/`unavailable` area-state
branches, or the loading skeleton** — the component template's four
`@switch` branches (`ready`/`loading`/`empty`/`unavailable`, with an
`absent`-vs-`unavailable` split inside the last one) are effectively
untested at the component level.

**Frontend, `ProgressComponent`: ZERO test coverage exists.** There is no
`progress.component.spec.ts` anywhere in the tree
(`find src -iname "*progress.component.spec*"` returns nothing) — the
component with the rail, the figures grid, the moments-reached list, and the
per-area breakdown section (T088) has never been unit-tested. This is the
single largest concrete gap for a future bank to close.

**Shell gates**: **none exist for either `/progress` or `/plan`.** No
`verify-*progress*.sh` or `verify-*plan*.sh` gate touches this surface —
`verify-plan-coverage-proposal.sh` is unrelated (it is about
specs/006's session-record "coverage proposal" verdicts for chapter session
plans, a completely different sense of "plan"). All existing coverage for
this surface is Go unit tests and two narrow Karma spec files; **no
HelixQA-style bank and no shell gate with a live HTTP assertion covers either
route today.**

## 5. Real edge cases

- **(a) 404-vs-503 (§2)** — the load-bearing case, already Go-tested
  in-process; a bank should still assert it over real HTTP against the live
  server for the reachable (404, empty-store) half, since that is a
  determined, always-reproducible state for a fresh session/account.
- **(b) The quiz-vs-reading split (§3)** — a genuinely untested-as-a-scenario
  fact: does answering a practice question actually move the `/progress`
  rail and change the `/plan` ranking? Does reading a full transcript with
  zero quiz activity leave both surfaces reporting "nothing reached"? Both
  are real, live-observable predictions from the code, and neither has any
  existing assertion at the HTTP/DOM level.
- **(c) No redaction check on stored progress entries — untested anywhere.**
  `ProgressHandler`'s `Get`/`Put` never touch the publication/redaction gate
  that `pkg/search`, `pkg/answer` and `areas.go` all enforce elsewhere (`grep
  -rn redact internal/api/progress*.go pkg/authhttp/progress*.go` — zero
  hits). A stored position echoes back its `pid`, `chapter_slug` and
  `t_start_s` verbatim regardless of whether that passage has since been
  redacted. The `pid` itself is an opaque ULID, but `chapter_slug` +
  `t_start_s` together are exactly the kind of "where in the recording" fact
  the redaction gate exists to withhold elsewhere in this codebase. This is a
  real, currently-unguarded gap worth a dedicated bank case (or an explicit
  accepted-gap note) rather than an assumption either way.
- **(d) `X-Session` fallback is dead code on this build (§2)** — worth an
  explicit bank decision on whether to test it (it is real, Go-level-tested
  code) or note it as unreachable on the live deployment given auth is now
  mandatory on every content route.
- **(e) `/api/areas` requires auth, contrary to a stale frontend comment.**
  `study-plan.component.ts:41` and `progress.component.ts` both carry
  comments dated 2026-09-01 asserting `/api/areas` "answers 404" on this
  build (endpoint not implemented). **Confirmed live, 2026-09-19**:
  `curl -i http://127.0.0.1:8087/api/areas` → `401 unauthorized`, not a bare
  404 — the route is fully implemented (`internal/api/areas.go`, extensive
  publication-state logic dated 2026-09-02 onward) and simply requires
  authentication like every other content route. The `absent`-state UI
  branch these two components carry for `reason.code ===
  'endpoint_not_implemented'` is therefore very unlikely to be reachable on
  a properly-authenticated live request today; a bank should confirm what
  `areaRouteAbsent()` actually renders for an authenticated caller now that
  the route is real, rather than trust the 2026-09-01-era comment.
- **(f) Empty-vs-unavailable framing bug, already fixed once, worth a
  regression case.** Both `progress.component.ts:155-180` and
  `study-plan.component.ts:189-213` carry detailed comments about a shipped
  defect (fixed 2026-09-08): a first-time visitor's `404 not_found` on
  `/api/progress` used to be misclassified as a server fault ("could not be
  read") by `httpToLoadStatus`'s pre-fix logic, because the 404 body was
  contract-shaped but carried no explicit `error`/`reason` code. The fix
  (`core/api.ts:831-877`) is a three-way branch: an explicit code wins
  verbatim; a contract-shaped body with no code is `empty()`; a body with no
  contract shape at all (Go's bare "404 page not found") is
  `endpoint_not_implemented`. A bank exercising a brand-new account/session
  against `/progress` and `/plan` is exercising exactly the branch this fix
  targets, and should assert the "haven't started yet" copy, not a fault
  message.
- **(g) The "reached" heuristic is intentionally shared, not duplicated.**
  `progress.component.ts`'s per-area breakdown (T088) and
  `study-plan.component.ts`'s ranking both call the SAME
  `estimateAreaReached()` (`core/study-plan.ts:32-40`) so the two surfaces
  cannot disagree about what "reached" means. A bank should treat this as one
  fact to verify (do the two pages ever show inconsistent reached/unreached
  verdicts for the same area?), not as two independent behaviors.
- **(h) Session/account isolation** — already Go-tested (§4), but worth a
  live two-account HTTP case: does `milosvasic`'s `/progress` ever leak
  `rami`'s reading position, and vice versa? (Both are full-access seeded
  accounts per the auth research doc, so this is a same-permission,
  different-identity isolation check, not an authorization check.)

## Files most relevant for the future brainstorm

- `app.routes.ts:106-117`
- `features/progress/progress.component.ts` (whole file — zero existing spec)
- `features/plans/study-plan.component.ts`, `core/study-plan.ts`
- `core/api.ts:701-755` (progress/recordProgress), `core/api.ts:756-810`
  (`sessionHeader`/`sessionId`)
- `core/progress.ts` (the OTHER, browser-local-only progress store — see §3)
- `core/knowledge.ts:594-636` (`ProgressEntry`/`ProgressState`/`normaliseProgress`)
- `internal/api/progress.go` (handler + store)
- `cmd/workshop-server/migration_wiring.go` (T574-576 migrate/discard flow)
- `pkg/authhttp/authhttp.go:144-161` (`Middleware` — why `X-Session` fallback is dead code)
- `features/practice/practice.component.ts:604-632` (the ONLY writer of `/api/progress`)
- `features/transcript/transcript.component.ts:1197-1200`,
  `features/chapters/chapter-detail.component.ts` (the browser-local reader
  that never reaches the server)

## Suggested focus for the brainstorming session

1. **The quiz-vs-reading split (§3)** is the highest-value, least-obvious
   target: assert directly that `/progress` and `/plan` respond to practice
   activity and are silent on pure reading/watching activity — the page
   copy alone would mislead a bank author into assuming the opposite.
2. `ProgressComponent` has zero existing test coverage of any kind (Karma or
   otherwise) — the rail, the figures grid, the moments list, and the
   per-area breakdown's three-valued switch are all open ground.
3. `StudyPlanComponent`'s template — the ranked list rendering, the
   `empty`/`absent`/`unavailable` branches — is untested beyond one caveat
   method; the ranking *algorithm* is well-covered, the *page* is not.
4. No shell gate or HelixQA bank exists for either route today — this
   sub-project would be the first live-HTTP coverage of `/api/progress`
   beyond Go-internal tests.
5. The redaction gap on stored progress entries (§5c) — decide whether to
   test it as a real gap or record it as an accepted, out-of-scope
   limitation.
6. `/api/areas`'s stale "answers 404" comments (§5e) — confirm current
   `absent`-vs-real-data behavior for an authenticated caller before writing
   any bank case that assumes the 2026-09-01 measurement still holds.
7. Cross-account isolation for `/progress`, live over HTTP with the two
   seeded accounts (§5h) — the Go-level test already proves the mechanism;
   a bank case would prove it end-to-end.
