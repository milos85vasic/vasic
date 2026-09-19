# HawkScan (local DAST scanning)

HawkScan is StackHawk's dynamic application security testing (DAST) scanner.
It is a **SaaS-backed commercial tool**, not a self-contained open-source
project — the scanner engine (`stackhawk/hawkscan` container image) always
calls out to StackHawk's own backend to authenticate and report results.
There is no fully-local, no-account mode. This is why it's set up here as a
**local runner against a pulled image**, not a git submodule: nothing about
HawkScan's own distribution is a clonable source repository.

## Current state

- Image pulled locally: `docker.io/stackhawk/hawkscan:latest` (via `podman`).
- Config scaffolded: `stackhawk.yml` (targets workshop's live server by
  default, `http://127.0.0.1:8087`).
- Runner: `run.sh` — **never blocks other work**. With no `HAWK_API_KEY` set,
  or with the config's placeholder `applicationId` still in place, it prints
  a clear warning and exits 0.
- **Not yet usable for a real scan** — two things need a StackHawk account,
  which only the operator can create (interactive signup with email
  verification; this cannot be automated from a CLI/API call):

## Setup steps (operator-only, one time)

1. Sign up for StackHawk's free tier at <https://app.stackhawk.com> (email +
   password, a couple of minutes).
2. In the StackHawk dashboard, create an **Application** for this project.
   This issues an `applicationId` (a UUID) — paste it into
   `stackhawk.yml`'s `app.applicationId` field, replacing the
   `REPLACE_WITH_REAL_STACKHAWK_APPLICATION_ID` placeholder.
3. Generate an **API key** from the StackHawk dashboard (Settings → API
   Keys). Export it as an environment variable — never commit it:
   ```bash
   export HAWK_API_KEY="<your key>"
   ```

## Running a scan

```bash
# Against the default target (workshop, loopback):
_tools/hawkscan/run.sh

# Against a different live target (e.g. ai_interviewing):
_tools/hawkscan/run.sh --target http://127.0.0.1:8099
```

## Why this isn't a git submodule

`helix-deps.yaml`'s schema (§11.4.31) is for git-clonable own-org and
third-party source dependencies. HawkScan has no such repository to clone —
`stackhawk/hawkscan-action` (a public GitHub Actions wrapper) exists but
wraps the same closed-source, SaaS-authenticated scanner image used here
directly. Tracking this tool's presence and configuration lives in this
directory instead, following the same spirit (a declared, documented,
locally-runnable dependency) without forcing it into a schema built for a
different kind of dependency.
