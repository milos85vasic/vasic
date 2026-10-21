# Feature Specification: Client Workspaces as Roles — Professor (administrator) and Student accounts

**Feature Branch**: `023-client-workspaces-roles` (build stream S18, branch `s18-023-roles`)
**Created**: 2026-10-21 **Status**: Draft (build in progress; see `tasks.md` for what has actually been run)

**Input**: Gap-analysis stub "023-client-workspaces-consulting-mode" (per-client corpus scope, client-owned
uploads, deliverable export, workspace switcher), BLOCKED on one sentence. Operator, 2026-10-21 (ratified,
not to be re-asked): a **"client" is a STUDENT user**; the main user / **administrator is the PROFESSOR**.
There MUST be a clear, enforced, visible difference between the two, in the backend and in the UI.

## Ratified decisions

| # | Decision |
|---|---|
| D1 | client = student (stored role `user`, exposed as `student`); admin = professor (`administrator`). |
| D2 | Accounts: administrators `milosvasic` and `rami`; students `student1`..`student5`. `rami` already exists in the live store as role `user`; provisioning CONVERGES it to `admin` (sessions revoked on a role change). |
| D3 | The students start with ONE weak, operator-supplied default password. It is NEVER written to any file, test, log or evidence. It is supplied through an environment variable or a 0600 runtime file only. |
| D4 | The global password minimum length is lowered and made operator-configurable (`WORKSHOP_PASSWORD_MIN_LEN`, bounded 6..72, default 8). Strength checks that do not depend on length (distinct characters, no control characters, UTF-8, must not contain the user name, maximum 72 bytes) stay. |
| D5 | Authorisation is server-side and deny-by-default for administrator surfaces. UI gating is a convenience, never the control. |

## User Stories

- **US1 (P1) Server-enforced split.** Every path under `/api/admin/` is administrator-only: anonymous 401, student 403,
  administrator 200, decided BEFORE routing so a nonexistent admin path is not an existence oracle. Other streams add
  rules with `authhttp.RegisterAdminOnly`. Dot-segment and case tricks do not bypass it.
- **US2 (P1) Provisioning.** `workshop-accounts` / `scripts/provision-accounts.sh` create or converge the roster
  idempotently; it never resets a password a student already changed; it never prints a secret; with a missing secret
  or a secrets file that is not mode 0600 it refuses (rc 2). At provisioning time the password is validated against the
  policy and on failure the tool fails CLOSED with a message naming the REQUIRED MINIMUM, never the password.
- **US3 (P1) First-sign-in change.** A student on the operator-supplied initial password is flagged
  `must_change_password`; the server refuses everything except the change endpoint until it is changed (403
  `password_change_required`). After the change the student reaches the learner surface and is still not an administrator.
- **US4 (P2) Visible difference in the UI.** Role badge, `/account` (role, what you can do, change password),
  `/admin/users` (administrator only, route guard, admin nav link only for administrators).
- **US5 (P2) Documentation.** A guide for operators and a FAQ entry, including the password trade-off.

## Out of scope for this slice (NOT built, not claimed)

Per-student corpus scope, student uploads, deliverable export and a workspace switcher (`/workspaces`) from the original
stub: the operator sentence defines clients as students, which does not by itself require a per-client corpus. They
remain OPEN questions (see "Open questions") and no code exists for them.

## Requirements

- **FR-001** Roles stay `admin | user` in storage; the API exposes `role_label` `administrator | student`.
- **FR-002** Additive schema only (`must_change_password`, permission resource `admin` granted to role `admin` only).
- **FR-003** `GET /api/account`, `POST /api/account/password`, `GET /api/admin/users` (never returns hashes).
- **FR-004** Password policy minimum comes from `passwordpolicy.MinLen()`: `WORKSHOP_PASSWORD_MIN_LEN` if set and valid,
  else 8. An invalid value (non-numeric, below 6 or above 72) FAILS CLOSED to the strictest safe behaviour: the default 8
  is NOT silently substituted for a malformed override; the process/tool refuses with a message naming the allowed range.
- **FR-005** Seeding (`workshop-accounts`, dev seed) validates against the same policy; failure names the required
  minimum and never echoes the password.
- **FR-006** No secret appears in any output of any tool, script, test or evidence file.

## Success criteria

- **SC-001** The role matrix (anonymous / student / administrator x admin path / learner path) passes, including bypass attempts.
- **SC-002** Provisioning twice changes nothing; a changed student password is never reset.
- **SC-003** `scripts/verify-roles.sh` passes on a throwaway server with throwaway passwords.
- **SC-004** Each guard has a paired mutation that is CAUGHT by a test.

## Risks and the security trade-off (read this)

Lowering the global minimum length (D4) weakens EVERY password on the instance, not only the students'. A short, known,
shared initial password is guessable by anyone who learns it; the mitigations are: forced change at first sign-in
(US3), the sign-in rate limit (5 per minute per source address), the retained non-length checks, and the operator's
ability to raise `WORKSHOP_PASSWORD_MIN_LEN` at any time. Administrators SHOULD set a long password regardless of the
configured minimum. The initial password is a bearer secret until changed: treat the window between provisioning and
first sign-in as exposure.

## Open questions (not guessed)

Q2 per-student corpus scope? Q3 student uploads / deliverable export? Q5 which existing diagnostics pages
(`/status`, `GET /api/index/status`) must students not see (left open to students pending the answer)?
