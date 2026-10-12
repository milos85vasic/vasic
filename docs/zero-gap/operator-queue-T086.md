# Operator queue item T086 (register id VSC-397)

Rotate the passwords of the two predefined accounts exposed in the public `specs/007-decouple-modules-auth/` tree.
Credential VALUES are never written in this file; accounts are named by reference only.

| Field | Value |
|---|---|
| Register id | VSC-397 (Operator-blocked, operator-action) |
| Related | VSC-387 (the decision item: rotate or keep), T085 (the scan that found it), T043 (security wave), T050 (queue) |
| Accounts | `milosvasic` (role admin), `rami` (role user; restricted on ai_interviewing) |
| Where they are accepted | workshop auth DB (`auth.db` in the dir given by `-index` / `$WORKSHOP_INDEX_DIR`), ai_interviewing `auth_user` table in its sqlite DB (default `ai_interviewing/platform/data/curriculum.db`) |
| Exposure | plaintext in `specs/007-decouple-modules-auth/spec.md` (FR-009 line), first public in ed9a34a; present in git history on a public remote, so rotation is the only remedy (section 11.4.10) |
| Owner | operator |
| Recheck date | 2026-10-15 (plan due the same day) |
| Unblock cost | about 20 minutes of operator time; one password typed at a prompt per account per module (4 prompts); all open sessions of both accounts end; private QA fixtures and `WORKSHOP_TEST_SEED_PASSWORD` users must be updated if they hold the old values |

## Procedure A: workshop (exact, uses the module's own tool)

Source: `workshop/platform/backend/cmd/workshop-passwd/main.go` (`workshop-passwd -help` carries the runbook). The new password is
never taken from argv; exit 0 changed, 1 refused, 2 could not determine. The server may keep running.

```bash
cd workshop/platform/backend && go build -o /tmp/workshop-passwd ./cmd/workshop-passwd   # or use the shipped binary
# Prompt mode (echo off, asked twice). Repeat for each account:
/tmp/workshop-passwd -index "$WORKSHOP_INDEX_DIR" -user milosvasic
/tmp/workshop-passwd -index "$WORKSHOP_INDEX_DIR" -user rami
```

Policy: 12 to 72 bytes, at least 8 distinct characters, must not contain the user name, must not equal the current or the known example
password. Proof of rotation: start the server with `-env production` (or `WORKSHOP_ENV=production`); it refuses to boot while either
account still carries its example hash (`cmd/workshop-server/boot_guard.go`).

## Procedure B: ai_interviewing (no rotate CLI exists; two steps with existing parts)

Sources: `platform/backend/cmd/hashpw/main.go` (makes the hash the login accepts, reads stdin, never argv),
`internal/store/auth.go` (`SetPasswordHash`, `RevokeSessionsForUser`), `internal/bootguard`.

```bash
cd ai_interviewing/platform/backend
# Per account: type the new password at the silent prompt; capture the hash (a hash, not the password)
read -rs PW && H="$(printf '%s' "$PW" | go run ./cmd/hashpw)"; unset PW
# Stop the server or accept SQLite write locking, then (DB path = the server's -db flag):
sqlite3 ../data/curriculum.db "UPDATE auth_user SET password_hash='$H' WHERE username='<ACCOUNT>';
  UPDATE auth_session SET revoked_at=strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE revoked_at IS NULL
  AND user_id=(SELECT id FROM auth_user WHERE username='<ACCOUNT>');"
```

Run with `<ACCOUNT>` = `milosvasic`, then `rami`. Proof: boot with `AI_INTERVIEWING_ENV=production`; the boot guard refuses while a seed hash remains.
Note: the sqlite3 UPDATE duplicates `SetPasswordHash` plus `RevokeSessionsForUser`; a small `ai_interviewing-passwd` command mirroring
workshop-passwd would be the durable fix (follow-up, not part of T086).

## Closure evidence required (T086 is not closed by this note)

1. `workshop-passwd` exit 0 for both accounts (the tool prints only user name and revoked-session count).
2. Both servers boot in production mode.
3. Operator confirms the old values are rejected at both login endpoints.
4. Private QA fixtures that held the old values are updated (check, do not print).

## Concerns

- Rotating the live DBs does not remove the example hashes from source (`authstore.SeedHash*`, `store.SeedAccountHashes`); fresh DBs are re-seeded with them by design and guarded only in production mode.
- The same two values also occur in tracked `ai_interviewing` files (per VSC-387); those are separate scrub work.
- VSC-387's recheck (2026-10-01) has already elapsed (V-G2 finding); it needs the operator's rotate-or-keep decision.
