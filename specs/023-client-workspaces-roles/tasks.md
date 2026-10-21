# Tasks: Client Workspaces as Roles (spec 023)

Evidence (S18 worktree `s18-023-roles`, 2026-10-21/22): Go `ok` for passwordpolicy, workshop-accounts, workshop-passwd, workshop-server, authhttp,
authstore (`evidence/s18/final/go.txt`, `go-server.txt`); Angular unit `Executed 977 of 977 SUCCESS` (`fe-unit.txt`); `scripts/verify-roles.sh` rc 0
(`verify-roles.txt`); passwordpolicy RED (`evidence/s18/red/passwordpolicy-red.txt`) and mutants PM1-PM5 CAUGHT. NOT re-run in the final
pass: Playwright `e2e/roles.spec.ts` (T012) and the Go mutation set M01-M29 (T003 ticked from the earlier recorded run `evidence/s18/mutants/go-mutants.log`,
23 CAUGHT / 0 SURVIVED / 6 INVALID mutants, taken before the rami and policy changes).

Test-first (RED run pasted, then GREEN). A box is ticked ONLY for what was run and seen to pass in the S18 build
(`s18-023-roles` worktree, evidence under its `evidence/s18/` and the final report). Unticked = not done or not re-run.

## US1 Server-enforced split
- [x] T001 [TDD] role matrix test (anonymous/student/administrator x admin/learner paths, dot-segment/case bypass) - `pkg/authhttp/roles_test.go`
- [x] T002 enforce in `authhttp.Middleware` + `RegisterAdminOnly`, admin permission resource in `authstore`
- [x] T003 mutation set for the guards (`evidence/s18/mutants`), all CAUGHT

## US2 Provisioning
- [x] T004 [TDD] `EnsureAccount` idempotent, role convergence revokes sessions, never resets a changed password - `pkg/authstore/roles_test.go`
- [x] T005 [TDD] `workshop-accounts` + `scripts/provision-accounts.sh`: env or 0600 file only, rc 2 on missing/loose, no secret output
- [x] T006 [TDD] roster is `milosvasic`,`rami` (admins) + `student1..5`; `rami` converges to admin
- [x] T007 [TDD] `passwordpolicy.MinLen()` / `WORKSHOP_PASSWORD_MIN_LEN` (6..72, default 8), invalid fails closed, non-length checks retained
- [x] T008 [TDD] provisioning validates the initial password against the policy minimum; refusal names the required minimum, never the password

## US3 First-sign-in change
- [x] T009 [TDD] `must_change_password` gate (403 `password_change_required`), `POST /api/account/password`, throttle
- [x] T010 `GET /api/account`, `GET /api/admin/users` (no hashes)

## US4 UI
- [x] T011 role service, admin guard, role badge, `/account`, `/admin/users`, admin nav link (Angular unit specs)
- [ ] T012 Playwright `e2e/roles.spec.ts` against an isolated server

## US5 / verification
- [x] T013 `scripts/verify-roles.sh` on a throwaway server (rc 0)
- [x] T014 guide `docs/guides/roles-and-accounts.md` + FAQ entry, including the password trade-off
- [ ] T015 operator-driven live walk-through on an isolated copy (OPERATOR step; not performed by the agent)
- [ ] T016 independent review verdict (NOT self-declared)
