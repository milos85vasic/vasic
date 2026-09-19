# Design: Exhaustive HelixQA Coverage — Workshop Auth & Session

**Status**: Approved in chat 2026-09-19 (operator: "all, one by one, subagents
driven" — continuing the standing exhaustive-HelixQA-coverage effort). Second
of 8 planned sub-projects, matching the depth and process of the first
(`2026-09-18-workshop-chapter-browsing-qa-design.md`).

## Scope of this sub-project

Core session mechanics only, via `POST /api/auth/login`, `POST
/api/auth/logout`, `POST /api/auth/switch`, `GET /api/auth/me`:

- Login with valid/invalid credentials, both seeded users (`milosvasic`,
  `rami` — identical full access on workshop).
- Logout invalidates the session (a subsequent authenticated call with the
  same token/cookie genuinely fails).
- `GET /api/auth/me` reflects the authenticated caller.
- Concurrent multi-session behavior (research finding (d) — real, currently
  untested at every layer): two independent logins for the same user both
  stay valid; `/switch` mass-revokes the caller's own prior sessions.
- Unauthenticated access to any gated `/api/*` route is a genuine 401, never
  a silent empty-content 200 (mirrors the RBAC bank's own discipline).
- The loopback/LAN + per-user-session interaction named in research finding
  (h): a loopback caller with a valid session cookie and NO `Authorization`
  header must still work end-to-end (this is the exact bug class behind the
  2026-09-17 LAN-deadlock and cookie/header-precedence fixes — a live
  regression pin for both belongs here, not only in the Go test suite).

Out of scope (each is one of the other 6 remaining sub-projects, or already
done): chapter browsing (done), search, ask/Q&A, progress/plan,
areas/practice, diagnostics/status. Also out of scope: the
`pending_migration_choice` progress-migration flow itself (already covered by
`platform/gates/verify-g-auth-1/2/3-workshop.sh`) — this sub-project only
needs to not choke on that field appearing in login/switch responses, per
research finding (5) in the suggested-focus list.

## Why this matters as its own sub-project, not a footnote

No core-login/session HelixQA bank exists yet at all — every other sub-project
so far (chapter browsing) authenticates via `auth: admin` but has never had
its OWN mechanics independently tested. And research finding (d) — concurrent
multi-session behavior — is a real, currently-UNTESTED gap at every layer (Go
unit tests, frontend Karma tests, and now HelixQA), not merely an
under-covered corner.

## Architecture

One `helixqa http` bank file, at `submodules/qa/banks/workshop/`:

- `auth-session.yaml`

Every case uses the structured `http:` action type exclusively (never a prose
`action:` string). Where a case needs an authenticated call, it uses the
credential-slot mechanism already proven in `rbac.yaml`/the chapter-browsing
banks (`--login-path /api/auth/login --admin-user --admin-pass`, real
credentials supplied only at CLI-invocation time, never written into the bank
file). Some cases in THIS bank are special: they test the login/logout/switch
flow ITSELF, so they issue their own explicit `POST /api/auth/login` /
`POST /api/auth/logout` steps rather than relying solely on the harness's
`auth: admin` shortcut, in order to assert on the raw response shape
(session cookie presence, `pending_migration_choice` field, token behavior
post-logout).

## Data flow / cases to encode

From the research doc, confirmed against the real code before any case is
written (not assumed):

1. **Valid login, each seeded user** — `milosvasic` and `rami` both succeed,
   response includes whatever session-establishing fields the real handler
   returns (read `authLoginHandler`, `main.go:3387-3451`, to get exact field
   names — do not guess).
2. **Invalid credentials** — wrong password and unknown username BOTH return
   an identical message (research finding (g), spec-required) — assert the
   two are indistinguishable, not just that both fail.
3. **`GET /api/auth/me` reflects the authenticated caller** — for both seeded
   users.
4. **Logout invalidates the session** — a subsequent call with the
   now-logged-out token/cookie against a gated route genuinely 401s.
5. **Concurrent sessions** — two independent logins for the SAME user; both
   tokens/cookies stay independently valid against a gated route; then
   `/switch` to the other seeded user and confirm the caller's own prior
   session(s) are revoked (mass-revoke-on-switch, research finding (d)).
6. **Unauthenticated access** to a representative gated `/api/*` route (e.g.
   `/api/chapters`, already proven in the chapter-list bank) returns 401, not
   a silent empty-content 200.
7. **Loopback + cookie-only, no `Authorization` header** — the exact
   regression class behind the 2026-09-17 fixes: confirm this combination
   still works end-to-end against a live server (a live pin alongside the Go
   test suite's `TestFullServer_SPAIsReachableFromANonLoopbackCallerWithNoCredential`
   / cookie-precedence tests, not a duplicate of them — HelixQA exercises the
   real HTTP surface, not the Go internals).

## Error handling / edge cases to encode

- Malformed login body (missing field, wrong content-type) — expect a clean
  4xx, not a 500 or a hang.
- Already-authenticated visit behavior is a FRONTEND (Angular) concern per
  the research (`auth-guard.ts` deliberately does not wrap `/login`) — read
  whether `POST /api/auth/login` itself has any server-side "already logged
  in" special-casing before deciding whether this belongs in this bank at
  all; if it's purely a frontend routing behavior with no distinct backend
  response, note that explicitly rather than inventing a backend case for it.

## Testing discipline

Every case gets a golden-bad control, matching the established pattern:
invert the real code path, confirm genuine FAIL, restore, confirm PASS again.
The concurrent-session case's golden-bad control is a strong candidate for
sandbox-guardrail refusal (mutating auth-adjacent code and restarting the
live server), matching Task 1's WK-CHLIST-002 finding in the chapter-browsing
sub-project — if that refusal recurs here, the same "accept code-level-only
verification" ruling applies rather than forcing a workaround.

Any real defect HelixQA surfaces gets a full `systematic-debugging` pass and
a TDD fix, live re-verified — no exceptions.

## Assumptions

- The live workshop server stays rebuilt and current (`source_commit` ==
  `HEAD`) for the duration of this sub-project; re-confirmed at design time
  (`fae0a71a32d3765e55f48ed866ad3fed4175c9a0` on both sides).
- `helixqa http` (never `run`) is the only execution path used.
- This bank is wired into `verify-helixqa-web.sh` alongside the existing
  five banks (spa-routing + the four chapter-browsing banks), reusing the
  same admin-login flag wiring Task 5 already added — no new gate-script
  mechanism should be needed, only the directory-glob picking up the new
  file automatically (confirm this rather than assume it, per that gate's
  own `BANKS_DIR` design).
- No new fixture chapters or other filesystem state is needed for this
  sub-project — every case operates against the existing seeded accounts and
  existing routes.
