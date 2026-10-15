# QA readiness, 2026-10-15

| Field | Value |
|---|---|
| Revision | 1 |
| Date | 2026-10-15 |
| Purpose | Which local URLs are up for the full manual QA session, and what is known about them |
| Method | `bash scripts/qa-up.sh` (ports discovered via `_tools/containers/cmd/port-discover`), then `curl` per URL |
| Visibility | Public-safe: URLs, ports, status codes, no credential, no private content |

## Contents

1. URLs and status checks
2. Started versus reused
3. How to stop
4. Credentials
5. Known caveats

## 1. URLs and status checks

All listeners are loopback only. Format: HTTP status, bytes, seconds.

| Service | URL | Check | Result |
|---|---|---|---|
| vasic.digital | http://127.0.0.1:8402/ | home | 200, 48630, 0.002 |
| vasic.digital | http://127.0.0.1:8402/products/ar/helixota.html | deep page | 200, 41306, 0.004 |
| milosvasic.ru | http://127.0.0.1:8089/ | home | 200, 39711, 0.001 |
| milosvasic.ru | http://127.0.0.1:8089/products/be/catalogizer.html | deep page | 200, 45277, 0.003 |
| ai_interviewing | http://127.0.0.1:8099/ | home | 200, 20753, 0.004 |
| ai_interviewing | http://127.0.0.1:8099/tracks | deep page | 200, 20753, 0.001 |
| ai_interviewing | http://127.0.0.1:8099/api/health | health | 200, 134 (curriculum 1, module 77, lesson 435, question 2488) |
| ai_interviewing | https://localhost:8445/ | self-signed TLS | 200 with `-k`; certificate verification fails by design |
| workshop (live) | http://127.0.0.1:8087/ | home | 200, 12719 |
| workshop (live) | http://127.0.0.1:8087/api/health | health | 200, 436 |
| workshop (live) | http://127.0.0.1:8087/login | login page | 200, 12719 |
| workshop (live) | http://127.0.0.1:8087/media/ | unauthenticated | 401 (expected) |
| workshop (live) | http://127.0.0.1:8087/docs/ | unauthenticated | 401 (expected) |

Not listed for QA: the agent QA instance on 127.0.0.1:8187 was NOT listening when checked (connection refused); it is for agents and was left untouched.

## 2. Started versus reused

Nothing was started in this session. `qa-up.sh` reused four services already running:
vasic.digital (python http.server, port 8402), milosvasic.ru (python http.server over `milosvasic.ru/_site`, port 8089), ai_interviewing (`aicur`, HTTP 8099, HTTPS 8445) and the live workshop container `workshop-curriculum_platform_1` on 8087 (not restarted, not reconfigured). No Jekyll rebuild ran: `_site/index.html` (2026-10-01) is newer than the tracked source judged by `qa-up.sh`, so the containerised build was not needed.

## 3. How to stop

State files live in `.service-registry/qa/`. Stop the two static sites by killing their recorded pids (`vd.pid`, `mv.pid`), after confirming the cmdline names the port.
Caution: `.service-registry/qa/` still holds `workshop.started` and `ai.started` markers from a 2026-10-14 run. `bash scripts/qa-up.sh --stop` honours those markers, so it may attempt to stop the live workshop and the ai stack. Do not run `--stop` without checking that first.

## 4. Credentials

The live workshop uses the operator's own account. Nothing here uses or records a credential. The agent QA instance has its own separate arrangement (see `workshop-qa-access.md`).

## 5. Known caveats

- The live workshop runs build 72c565e and does not include the later W1/W2/redaction commits; they are not yet redeployed.
- LAN access stays closed (loopback bind, operator decision).
- The answering feature is OFF by design (semantic search stays on).
- The host suspend guard is not installed (root step pending).
- UNHEALTHY `helixagent-mcp-*` containers are pre-existing and unrelated to this project.
- `llmctl-decide` on 127.0.0.1:8095 resets plain HTTP connections to `/`; it is not a QA website and was not checked further.
