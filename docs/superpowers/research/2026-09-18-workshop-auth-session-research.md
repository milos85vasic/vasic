# Research: Workshop Auth & Session Surface (for future HelixQA brainstorming)

Read-only investigation, 2026-09-18. Input for the "Auth & Session" sub-project
of the exhaustive-HelixQA-coverage effort (sub-project 2 of 8 — see
`docs/superpowers/specs/2026-09-18-workshop-chapter-browsing-qa-design.md` for
the shape/depth this matches). No credential values are recorded here — only
where they live and how to reference them.

## 1. Registered auth routes

Registered in `wrapWithAuth`, `platform/backend/cmd/workshop-server/main.go:3339-3346`:

| Route | Handler | File:line |
|---|---|---|
| `POST /api/auth/login` | `authLoginHandler` | `main.go:3340`, impl `main.go:3387-3451` |
| `POST /api/auth/logout` | `authLogoutHandler` | `main.go:3341`, impl `main.go:3454-3472` |
| `POST /api/auth/switch` | `authSwitchHandler` | `main.go:3342`, impl `main.go:3477-3524` |
| `GET /api/auth/me` | `authMeHandler` | `main.go:3343`, impl `main.go:3527-3549` |
| `POST /api/auth/migrate-progress` | `authMigrateProgressHandler` | `main.go:3344` (T574-576 progress-migration flow, adjacent to core login) |
| `GET /api/health` | served un-gated | `main.go:3345` |

No token-refresh endpoint. Sessions are 24h fixed-expiry
(`authhttp.TokenExpiry`, `pkg/authhttp/authhttp.go:56`); no silent renewal —
handled reactively (next 401 → frontend redirect).

Wiring order (`main.go:3339-3346`): `authMux` carves out `/api/auth/*` +
`/api/health` as unauthenticated-reachable; everything else routes through
`apiPathsOnly(authhttp.Middleware(authDB), content)` — `authhttp.Middleware`
only gates `/api/*`, never the SPA shell.

## 2. Session/token mechanism

Dual carrier, cookie-first. `authhttp.ExtractToken`,
`pkg/authhttp/authhttp.go:129-139`: checks the `session` cookie first, falls
back to `Authorization: Bearer <token>`. This order is itself a fix for a real
bug found and fixed 2026-09-17: `internal/api.LoopbackOnly` (G-HTTP-9) also
reads `Authorization: Bearer <token>` for an unrelated network-level shared
secret, so header-first order meant a LAN caller satisfying G-HTTP-9 had that
header occupied by the network credential and could never present a session
via header — cookie-first fixes it. Test:
`TestSessionCookieWinsOverAnUnrelatedAuthorizationHeader`,
`pkg/authhttp/authhttp_test.go:100`.

Cookie: `Name: "session"`, `HttpOnly: true`, `SameSite: Strict`, `Path: "/"`,
no `Secure` flag noted (`main.go:3557-3568`) — worth checking under an
HTTPS-fronted deployment scenario.

Token: 32 random bytes, base64 URL-safe; stored server-side only as a
SHA-256 hash — raw token never persisted (`authhttp.go:41-53`).

Middleware failure modes: no token → 401 `authentication required`;
invalid/expired/revoked → 401 `invalid or expired token` (no distinction
leaked to the client).

## 3. Seeded credentials

Two mandated users (`pkg/authstore/authstore.go:153-166`): `milosvasic`
(admin) and `rami` (user) — both get identical full access on workshop
specifically (`TestWorkshopBothRolesFullAccess`,
`pkg/authstore/authstore_test.go:39`), unlike `ai_interviewing`'s RBAC
differentiation.

**Plaintext values are NOT recorded here** — see
`specs/007-decouple-modules-auth/spec.md` at the umbrella root (`FR-009`,
line 184, reiterated at 57-60/150/230-232/343). That spec itself documents
these values as compromised-by-definition (public repo, in git history).
`submodules/qa/banks/ai_interviewing/rbac.yaml`'s header points to the same
location for its own credential-slot usage — the established convention.

Password hashes are exported constants (`SeedHashMilosvasic`/`SeedHashRami`,
`authstore.go:76-79`) specifically so a boot guard can refuse to start if a
live account's hash still equals these known values in a would-be-production
posture.

## 4. Frontend login component

`platform/frontend/src/app/features/auth/login.component.ts`. State machine
is `LoadStatus<AuthSession>`: `idle` → `loading` → `unavailable` (renders
`s.reason` in a `[role=alert]`) → `ready` (navigates away).

- Invalid credentials (401), network failure (`status === 0`), and a
  sanitized `returnUrl` redirect (refuses protocol-relative/absolute URLs —
  explicit open-redirect defense, `sanitiseReturnUrl`, lines 149-160) are all
  handled and tested (`login.component.spec.ts`).
- **Possible gap**: no explicit "already authenticated, redirect away from
  `/login`" guard was found — `auth-guard.ts` deliberately does NOT wrap
  `/login` itself (so an unauthenticated visit never loops), but this also
  means an already-authenticated visit to `/login` isn't redirected away
  either. Worth confirming intended behavior in the brainstorm.

Supporting files: `core/auth.ts` (`AuthService`), `core/auth-guard.ts`,
`core/auth-interceptor.ts` (attaches bearer to `/api/*` except
`/api/auth/login`/`/api/health`; on any other 401, clears session and
redirects to `/login?returnUrl=...`, with loop-avoidance for `/login` itself).

## 5. Existing coverage — do not duplicate

- Go: `internal/api/access_test.go` (G-HTTP-9 network-level gate, 7 cases),
  `pkg/authhttp/authhttp_test.go` (8 cases), `pkg/authstore/authstore_test.go`
  (3+ cases), `cmd/workshop-server/auth_wire_test.go` (8+ full-server
  integration cases — the direct regression pin for the LAN deadlock fix),
  `auth_db_outage_test.go`, `auth_secret_leak_test.go`, `authkit_wire_test.go`
  (audience-scoped tokens, per-account/per-source rate limiting, mass
  cutover invalidation).
- Frontend Karma: `login.component.spec.ts` (7), `core/auth.spec.ts` (17),
  `core/auth-guard.spec.ts` (3), `core/auth-interceptor.spec.ts` (8).
- Shell gates `platform/gates/verify-g-auth-1/2/3-workshop.sh` cover the
  progress-migration flow (T574-576), NOT core login/session mechanics —
  genuinely adjacent, not duplicative, but a login bank case touching the
  login/switch response should account for the `pending_migration_choice`
  field these gates already exercise.
- No `rbac.yaml`-equivalent bank exists yet for workshop (only
  `ai_interviewing` needed one, since both workshop's seeded users get
  identical access). No core-login HelixQA bank exists yet at all.

## 6. Real edge cases

- **(a) LAN-vs-loopback deadlock — fixed 2026-09-17.** `api.LoopbackOnly`
  used to wrap the entire server output including the SPA shell, and
  `authhttp.Middleware` wrapped the entire content mux — a LAN caller with no
  network credential could never reach even the login page. Fixed via
  `apiPathsOnly` applied at both layers, gating only `/api/`, `/media/`,
  `/docs/` while leaving `GET /` (SPA shell) universally reachable.
  Regression-pinned by `TestFullServer_SPAIsReachableFromANonLoopbackCallerWithNoCredential`
  / `TestFullServer_APIStillRequiresLoopbackOrCredential`.
- **(b) Cookie/header precedence bug — fixed 2026-09-17.** See §2.
- **(c) Expired/invalid session**: uniform 401 with no distinction leaked;
  frontend `isExpired` fails-closed on unparseable `expiresAt` (treats as
  expired, not as an unbounded session).
- **(d) Concurrent-session behavior — UNTESTED at every layer.** `LoginSession`
  never revokes a prior session on a new login, so one account can hold
  multiple simultaneously valid tokens (e.g. two browsers). Only
  `authSwitchHandler` mass-revokes (on ACCOUNT SWITCH, revokes the caller's
  own prior sessions before logging into the new account) — it does not limit
  one account to one concurrent session. **Real, currently-untested bank
  case candidate**: two logins for the same user, confirm both tokens stay
  independently valid, confirm `/switch` revokes appropriately.
- **(e) No token-refresh** — a gap to name, not necessarily a bug.
- **(f) Rate limiting (T508)** — per-account AND per-source, both checked
  unconditionally (deliberate, so partial-attack traffic still consumes both
  budgets); checked BEFORE the bcrypt credential check so timing/response
  can't be used to fingerprint account existence via rate-limit state.
- **(g) No account enumeration** — unknown-user and wrong-password return an
  identical message (spec-required, `spec.md:164,327`).
- **(h) `Authorization` header is overloaded by two independent mechanisms**
  (per-user bearer session here; the G-HTTP-9 network-level shared secret in
  `internal/api/access.go:43-53`). A future bank exercising BOTH loopback
  behavior and per-user auth together must be deliberate about which
  credential occupies the header vs. cookie — exactly the bug class behind
  (a)/(b). Natural regression case: loopback caller + valid session cookie +
  NO `Authorization` header at all should still work end-to-end.

## Suggested focus for the brainstorming session

1. No bank yet exists for core login/logout/switch/me itself.
2. Concurrent multi-session behavior (d) is untested everywhere — a real gap.
3. `SameSite=Strict` with no `Secure` flag — worth a scenario check.
4. Already-authenticated visit to `/login` — confirm intended behavior.
5. `pending_migration_choice` in login/switch responses — don't let a naive
   bank case choke on this extra field.
