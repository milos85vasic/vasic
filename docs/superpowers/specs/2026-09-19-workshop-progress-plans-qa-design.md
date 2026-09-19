# Design: Exhaustive HelixQA Coverage — Workshop Progress & Plan

**Status**: Approved in chat 2026-09-19 (operator: "all, one by one, subagents
driven"). Fifth of 8 planned sub-projects.

## Scope of this sub-project

`GET/POST /api/progress` — the one real backend endpoint behind both the
`/progress` (`ProgressComponent`) and `/plan` (`StudyPlanComponent`) frontend
routes. `/plan` itself has **no backend endpoint** — it is a pure
client-computed ranking (`core/study-plan.ts`'s `rankAreasForStudy`) over
`GET /api/areas` + `GET /api/progress`, already covered by existing frontend
unit tests (`core/study-plan.spec.ts`). This sub-project does not re-test
that pure function; it tests the real HTTP surface both pages consume.

`POST /api/auth/migrate-progress` (T574-576) is the one other route that can
mutate the `progress.json` store this sub-project is about — in scope only
for one case confirming it doesn't corrupt or leak state this sub-project's
other cases depend on, not a full re-test of that flow (already covered by
the auth & session research and its own Go tests).

Out of scope: `/api/areas`'s own publication-state machine (the
areas/practice sub-project's subject) — this sub-project only confirms
`/api/areas` is reachable and authenticated where `/plan`'s ranking needs it.

## The highest-value finding this design centers on

**The quiz-vs-reading split.** Every real write to `/api/progress` comes from
`features/practice/practice.component.ts`'s quiz-answer handler — never from
the actual video/transcript readers, which write to a completely separate,
`localStorage`-only, server-never-touched store. So a reader who watches an
entire chapter's recording top to bottom but never answers a practice
question will see `/progress` report "nothing reached," while a reader who
never watches anything but answers one quiz question moves the rail. The
page copy ("your position in the recording") reads as if it tracked
playback; it does not. This is real, documented-in-code behavior, not a bug
this sub-project fixes — but it is exactly the kind of load-bearing fact a
bank must assert directly, because it would be trivially easy to write a
bank that (wrongly) assumes reading activity moves the rail.

## A real, currently-unguarded gap this design flags for priority triage

**No redaction check exists on stored progress entries.** `ProgressHandler`'s
`Get`/`Put` never touch the publication/redaction gate that `pkg/search`,
`pkg/answer`, and `internal/api/areas.go` all enforce elsewhere (confirmed:
zero hits for `redact` in `internal/api/progress*.go` or
`pkg/authhttp/progress*.go`). A stored position echoes back `chapter_slug` +
`t_start_s` verbatim regardless of whether that passage has since been
redacted — exactly the kind of "where in the recording" fact the redaction
gate exists to withhold elsewhere. **This is a real, live-testable gap, not
an assumption** — Task 3 of this sub-project's implementation plan MUST
investigate whether this is genuinely exploitable (can a reader's own stored
progress position reveal the existence/location of since-redacted content
they should no longer see?) and, if so, treat it with the same
systematic-debugging + TDD rigor the T508 finding in the auth-session
sub-project received — not merely note it and move on.

## Architecture

One `helixqa http` bank file, at `submodules/qa/banks/workshop/`:

- `progress-plan.yaml`

Every case uses the structured `http:` action type exclusively, `auth: admin`
for authenticated cases (both seeded accounts are needed for the isolation
case — read the auth-session sub-project's own findings on how to express
two accounts' worth of coverage within this framework's single-slot
`auth: admin` cache before assuming a mechanism).

## Data flow / cases to encode

1. **404 on a fresh account/session** — `GET /api/progress` for an account
   with no stored position returns `404 not_found` (a determined negative,
   always-reproducible for a fresh test run against either seeded account
   if their positions happen to be clear, or confirm live which account
   currently has none).
2. **POST then GET round-trip** — a real `POST /api/progress` with a real
   `chapter_slug`/`pid`/`t_seconds`, then `GET` reflects it (`t_start_s` in
   the response, not `t_seconds` — the real, documented field-name
   asymmetry across the boundary).
3. **Overwrite, not accumulate** — a second POST for the SAME chapter_slug
   replaces the stored position rather than creating a second entry.
4. **Malformed POST bodies → 400** — at minimum: unsafe `chapter_slug`
   (path-traversal attempt), malformed `pid` (not a 26-char ULID), missing/
   negative `t_seconds`. Read the real handler for the exact `unknown_parameter`
   vs `malformed_pid` error codes — don't assume from this list.
5. **`t_seconds: 0` is a real, stored value, not treated as absent** — POST
   with `t_seconds: 0`, confirm GET reflects `t_start_s: 0`, not a missing
   field or a 400.
6. **The quiz-vs-reading split, asserted directly** — this is the
   centerpiece case. Confirm live (read `curriculum/`/live API state first,
   don't assume): does `/api/progress` currently reflect ONLY positions
   written by the practice/quiz path? At minimum, assert the CONTRACT this
   split implies: a position written via `POST /api/progress` (simulating
   what the quiz component does) is visible; nothing in this sub-project can
   assert the NEGATIVE ("reading never writes here") over HTTP alone since
   reading writes only to `localStorage` in the browser — so this case's
   real, HTTP-testable form is confirming the POST/GET contract itself
   works exactly as the quiz component depends on it working, with the
   split documented in the bank's own header as a frontend-only behavioral
   fact this bank cannot directly observe end-to-end (no browser
   automation in this framework) but which the POST contract underpins.
7. **`/api/areas` requires auth, contrary to a stale 2026-09-01 frontend
   comment** — confirmed live in research as 401, not 404. One case
   confirming this current, correct behavior — regression pin against the
   stale comment ever becoming true again in a way that would break
   `/plan`'s ranking silently.
8. **Cross-account isolation, live over HTTP** — `milosvasic`'s
   `/api/progress` never reflects `rami`'s stored position and vice versa.
   Both are full-access seeded accounts (no authorization difference), so
   this is purely an identity-isolation check.
9. **Unauthenticated `GET`/`POST /api/progress`** → 401, matching the
   established discipline.
10. **The redaction gap (see above)** — at minimum, one case establishing
    the CURRENT observable behavior (does a stored position for a since-
    redacted pid still get served back verbatim?), feeding directly into
    Task 3's mandatory investigation.

## Testing discipline

Every case gets a golden-bad control per the established pattern. Case 4
(malformed-body validation) and case 8 (cross-account isolation) are the
strongest golden-bad candidates — invert the validation check or the
session-keying respectively, confirm genuine FAIL, restore, confirm PASS.

## Assumptions

- The live workshop server stays rebuilt and current for the duration of
  this sub-project.
- `helixqa http` (never `run`) only.
- Wired into `verify-helixqa-web.sh` via the same directory glob.
- No new fixture chapters or filesystem state needed — this sub-project
  writes and reads real `progress.json` entries via the real API, which is
  itself the point (unlike the read-only surfaces tested so far, this is
  the first sub-project whose bank cases genuinely WRITE server-side
  state). Implementers should confirm cleanup/idempotency: does re-running
  this bank leave stray progress entries that could affect a LATER
  sub-project's assumptions about a "fresh" account state? Document this
  explicitly rather than leaving it implicit.
