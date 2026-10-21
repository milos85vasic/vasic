# Implementation Plan: Client Workspaces as Roles (spec 023)

Backend root `workshop/platform/backend/`, frontend `workshop/platform/frontend/src/app/`.

## Design
- Enforcement in `pkg/authhttp` middleware (already guards `/api/*`, `/docs/*`, `/media/*`): admin-only prefix table,
  decided before routing, on the cleaned path; `RegisterAdminOnly` for extension.
- `pkg/authstore`: `must_change_password`, permission resource `admin`, `EnsureAccount` (idempotent, role convergence
  revokes sessions, never resets a changed password), `ChangePassword`, `ListUsers` (no hashes).
- `internal/passwordpolicy`: `MinLen()` reads `WORKSHOP_PASSWORD_MIN_LEN` (6..72, default 8); invalid override fails closed.
- `cmd/workshop-accounts` + `scripts/provision-accounts.sh`: secrets from env or a 0600 file only.
- Server wiring in NEW files `cmd/workshop-server/wire_roles.go` (one hook line in the existing `wire_hooks.go`).
- UI: `core/role.ts`, `admin-guard.ts`, `role-badge.component.ts`, `features/account`, `features/admin`; shared
  header/nav/route lines are in the already-modified `app.component.ts`, `app.routes.ts`.

## Verification
Go unit/handler tests (RED first), mutation set (`evidence/s18/mutants`), `scripts/verify-roles.sh` on a throwaway
server, Angular unit specs, Playwright `e2e/roles.spec.ts` against an isolated server. The operator drives the live
walk-through (ratified: isolated copy + operator).
