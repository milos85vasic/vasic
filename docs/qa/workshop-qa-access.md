# Workshop QA access (separate QA instance)

| Field | Value |
|---|---|
| Revision | 1 |
| Date | 2026-10-14 |
| Decision | Operator, 2026-10-14: "create the workshop QA password yourself and document everything" |
| Scope | Authenticated verification of the private `workshop` platform without touching the live instance |
| Visibility | Public-safe: contains no secret and no private content |

## Contents

1. Why a separate instance
2. What exists
3. How it was created
4. Where the secret lives
5. Loading the secret safely
6. Start, stop, status
7. Rotate or revoke
8. Smoke test
9. Risks and limits

## 1. Why a separate instance

The live workshop (container `workshop-curriculum_platform_1`, port 8087, LAN-exposed, serves
private content) has no documented QA user. Its seed accounts `milosvasic` and `<participant-handle>` carry
bcrypt hashes tracked in source (`pkg/authstore.SeedHash*`), and the plaintext is not stored
anywhere in the repository. Adding a QA credential to the live instance would be a security
decision on a LAN-exposed service and was not made. Instead, the same server binary runs as a
second, loopback-only process with its own auth database.

Nothing in the live container, its volume, its state file or its configuration was read,
written, restarted or probed with credentials.

## 2. What exists

| Item | Location |
|---|---|
| QA server process (systemd user scope `workshop-qa-instance`) | `http://127.0.0.1:8187` (loopback only) |
| QA state and auth database | `~/.cache/agent-scratch/workshop-qa-instance/state/` (disk, not tmpfs) |
| QA server log | `~/.cache/agent-scratch/workshop-qa-instance/logs/server.log` |
| Rotation tool binary | `~/.cache/agent-scratch/workshop-qa-instance/bin/workshop-passwd` |
| Secret file | `~/.config/workshop-qa/seed.env` (mode 0600, dir mode 0700) |
| Base-URL file | `~/.config/workshop-qa/base.env` (mode 0600) |
| Smoke script | `~/.cache/agent-scratch/workshop-qa-instance/smoke.sh` |

The port was chosen with `_tools/containers/bin/port-discover workshop-qa 8187`.
Content (chapters, curriculum, docs, web, prebuilt) is read from the repository checkout
read-only; the server writes only to the QA state directory and its own `-state` file.

## 3. How it was created

The repository's own mechanism is `workshop-passwd` (`platform/backend/cmd/workshop-passwd`):
it replaces one account's bcrypt hash in an existing `auth.db` and ends that account's sessions.
The tracked seed hashes cannot be given a new password any other way; the
`WORKSHOP_TEST_SEED_PASSWORD` variable that the test harness reads is the OLD plaintext matching
the tracked hash, not a way to set a new one.

1. Start `platform/bin/workshop-server` with the live container's flag set, except:
   `-http 127.0.0.1:8187`, `-port-fallback 0`, `-state` and `-index` pointing at the QA state
   directory. This creates and seeds the QA `auth.db`.
2. Build `workshop-passwd` from `platform/backend/cmd/workshop-passwd` into the scratch `bin/`.
3. Generate a random password with `python3 -c 'import secrets; print(secrets.token_urlsafe(24))'`.
4. Pipe it over stdin: `printf '%s\n' "$PW" | workshop-passwd -index <qa-state> -user milosvasic -password-fd 0`.
   The password never appears in argv. A second random password was set for `<participant-handle>` and
   discarded (not stored anywhere), so no compromised example hash stays valid on the QA instance.
5. Write `WORKSHOP_TEST_SEED_PASSWORD=<value>` as one line into the 0600 secret file.

The tracked seed hash was valid on the QA instance for a few seconds on loopback between
steps 1 and 4.

## 4. Where the secret lives

Only in `~/.config/workshop-qa/seed.env`, one line `WORKSHOP_TEST_SEED_PASSWORD=...`, mode 0600,
in a 0700 directory. It is never committed, logged, echoed or written to reports. The password
works only against the QA instance (its own auth database); it is meaningless on the live one.

## 5. Loading the secret safely

Source it inside the command that needs it, with auto-export, and never print it:

```bash
set -a; . ~/.config/workshop-qa/seed.env; . ~/.config/workshop-qa/base.env; set +a
# workshop/scripts/_live_auth.sh reads WORKSHOP_TEST_SEED_PASSWORD; point BASE at the QA instance:
BASE="$WORKSHOP_QA_BASE" ws_live_auth_header "$BASE"
```

Do not use `set -x`, do not pass the value on a command line, and do not paste response bodies
into reports (they contain private content); report counts, status codes and sizes only.

## 6. Start, stop, status

Status: `curl -s http://127.0.0.1:8187/api/health` (public route, returns metrics only).

Stop (ends only this scope): `systemctl --user stop workshop-qa-instance.scope`.

Start again: run `platform/bin/workshop-server` from the `workshop/` directory under
`~/.local/bin/bounded-run -m 3G -T <seconds> -n workshop-qa-instance --` with the flag set
described in section 3; the existing state directory and its rotated credentials are reused.

The process runs under a wall-clock cap (8 hours) and dies by itself after that.

## 7. Rotate or revoke

Rotate: repeat section 3 steps 3 to 5 against the existing state directory (the server may keep
running; the change takes effect on the next sign-in and ends the account's sessions).

Revoke completely: stop the instance (section 6), then delete only the QA state directory
`~/.cache/agent-scratch/workshop-qa-instance/state/` and the file `~/.config/workshop-qa/seed.env`.
A later start re-seeds an empty auth database with the tracked example hashes, so rotate again
before use.

## 8. Smoke test

Run `bash ~/.cache/agent-scratch/workshop-qa-instance/smoke.sh`. Results on 2026-10-14
(metrics only):

| Check | Result |
|---|---|
| Login with the QA password | HTTP 200, token length 43 |
| `/api/chapters` without a token | HTTP 401 |
| `/api/chapters` with the token | HTTP 200, 6 chapters |
| `/api/areas` | HTTP 200 |
| `/api/chapters/01/transcript` | HTTP 200 |
| `/api/search` for three terms | HTTP 200 each |
| `/api/suggest` | HTTP 200 |
| `/api/ask` | HTTP 503, reason code `no_provider` (answering is off, as on the live instance) |
| Logout, then reuse the token | logout HTTP 200, reuse HTTP 401 |
| Wrong password versus unknown user | both HTTP 401, identical bodies |

Note: `/api/curriculum` does not exist as a route (HTTP 404 is correct); the learning and
curriculum content is served through `/api/areas` and `/api/chapters/{chapter}/transcript`.

Observed: repeated failed logins trip the login rate limiter (HTTP 429) for roughly a minute;
space smoke runs accordingly.

## 9. Risks and limits

- The QA instance answers 401 until a login and serves the same private content as the live one
  once logged in. It is bound to loopback only; do not rebind it to a LAN address.
- Anyone with read access to `~/.config/workshop-qa/seed.env` (the host user) can log in to the
  QA instance. The file mode and directory mode are the only protection.
- The QA instance does not exercise the live container, its volume, its network binding, or
  LAN-login behaviour (spec 008 phase 16 access token), so a pass here is not evidence about them.
- The state directory lives under `~/.cache`, which cleanup tools may remove; deleting it
  resets the instance to the tracked example hashes (see section 7).
- Giving agents a credential for the live instance remains an open operator decision. If wanted,
  the change would be a source change in the private `workshop` repository (a new account hash)
  or running `workshop-passwd` against the live volume, either of which alters a LAN-exposed
  service that serves private content.
