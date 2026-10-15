# QA readiness, 2026-10-15

| Field | Value |
|---|---|
| Revision | 2 |
| Date | 2026-10-15 (revision 2 measured 17:10 to 17:17 CEST) |
| Purpose | Which local URLs are up for the full manual QA session, built from which commit, and how each was checked |
| Method | `bash scripts/qa-up.sh` (ports discovered via `_tools/containers/cmd/port-discover`), the documented QA-instance start (`workshop-qa-access.md` section 6), then `curl` per URL |
| Visibility | Public-safe: URLs, ports, status codes, commit ids, no credential, no private content |
| Supersedes | Revision 1 (same date): ai_interviewing was then a 2026-09-25 binary, and the QA instance on 8187 was down |

## Contents

1. Service table
2. Verification evidence
3. Started versus reused
4. How to stop
5. Credentials
6. Not covered, and why
7. Known caveats

## 1. Service table

All listeners are loopback only. Ports were read from `ss -ltnp` after discovery, not from memory.

| Service | URL | Port | Process / owner | Built or served from | Started at | Verdict |
|---|---|---|---|---|---|---|
| vasic.digital (static) | http://127.0.0.1:8402/ | 8402 | `python3 -m http.server`, pid 164036 | `vasic.digital/` working tree, HEAD `d4e741c438c2`, clean | 2026-10-14 14:54 | BOOTED-AND-VERIFIED |
| milosvasic.ru (Jekyll output) | http://127.0.0.1:8089/ | 8089 | `python3 -m http.server`, pid 164075 | `milosvasic.ru/_site` (built 2026-10-01), source HEAD `04cf16559bbd`, clean; qa-up found no tracked source newer than `_site`, so no rebuild | 2026-10-14 14:54 | BOOTED-AND-VERIFIED |
| ai_interviewing (HTTP) | http://127.0.0.1:8099/ | 8099 | `aicur`, pid 4044814, scope `bounded-run-ai-interviewing-qa` | HEAD `5c0ed32ccc07`; `/api/health` reports `source_commit 5c0ed32…`, `source_dirty false` | 2026-10-15 17:12 | BOOTED-AND-VERIFIED |
| ai_interviewing (HTTPS) | https://localhost:8445/ | 8445 | same `aicur` process | same | same | BOOTED-AND-VERIFIED (self-signed; `curl -k`) |
| workshop QA instance | http://127.0.0.1:8187/ | 8187 | `workshop-server`, pid 4163866, scope `bounded-run-workshop-qa-instance` | committed workshop HEAD `da916c1a6a2c` (clean `git archive` export: backend + Angular bundle); `/api/health` build `da916c1-20261015T151242Z`, `source_dirty false` | 2026-10-15 17:14 | BOOTED-AND-VERIFIED |
| workshop live (reported only) | http://127.0.0.1:8087/ | 8087 | container `workshop-curriculum_platform_1`, pid 191466 | build `72c565e-20261014T160710Z-dirty` (not HEAD) | 2026-10-14 18:07 | RUNNING, not touched (read-only GETs only) |
| llmctl decide (reported only) | 127.0.0.1:8095 | 8095 | `llmctl-decide-gateway.service` pid 2618; `llmctl-onnx@decide-nli.service` pid 3445 | n/a | 2026-10-14 14:37 | RUNNING, not touched; pids identical before and after this session |

Repository state at measurement: umbrella HEAD `85b631eab268` (the `qa-up.sh` that ran). The workshop working tree carried uncommitted edits by another agent (ingest, gates, scripts); none of them is in the QA build, because the build came from a `git archive` of HEAD. The content directories the QA instance reads (`chapters`, `curriculum`, `docs`, `platform/prebuilt`) showed zero differences from HEAD. The Go `replace` modules it compiles against (`containers`, `passage`, `verdict`, `RAG`, `LLMProvider`, `curriculum-kit`) were clean at their gitlinks; `authkit` is a tracked directory with no uncommitted change.

Out of scope, with reason: `monetization` declares no HTTP listener (CLI tools and markdown reports only). No documented local HelixQA or catalogizer service exists in this repository; those names appear only as product pages on the two sites.

## 2. Verification evidence

Probe: a script that prints the status code and time for each URL (no bodies). Result: 29 of 29 PASS.

| Check | Expected | Got |
|---|---|---|
| vasic.digital root, 5 sitemap URLs (entries 1, 131, 262, 393, 525 of 525), asset `assets/od/fonts.css` | 200 each | 200 each, all under 0.005 s |
| milosvasic.ru root, 5 sitemap URLs (same positions of 525), asset `assets/od/milosvasic.css` | 200 each | 200 each, all under 0.006 s |
| ai_interviewing `/`, `/tracks`, `/api/health`, HTTPS `/` with `-k` | 200 | 200 (health stats: curriculum 1, module 77, lesson 435, question 2488) |
| workshop live `/api/health`, `/login` | 200 | 200 |
| workshop live `/media/`, `/docs/` unauthenticated | 401 | 401 |
| workshop QA `/`, `/api/health`, `/login` | 200 | 200 |
| workshop QA `/api/search?q=pipeline`, `/api/chapters` unauthenticated | 401 | 401 |
| workshop QA `/media/`, `/docs/` unauthenticated | 401 | 401 |

Authenticated smoke, QA instance only (`~/.cache/agent-scratch/workshop-qa-instance/smoke.sh`, secret read from its 0600 file, never printed):

| Check | Result |
|---|---|
| Login | HTTP 200, token length 43 |
| `/api/chapters` without and with the token | 401, then 200 with 6 chapters |
| `/api/areas`, `/api/chapters/01/transcript` | 200, 200 |
| `/api/search` for three terms, `/api/suggest` | 200 each |
| `/api/ask` (POST and GET) | 503, reason code `no_provider` (answering is off by design) |
| Logout, then reuse the token | 200, then 401 |
| Wrong password versus unknown user | both 401, identical bodies |

QA-instance startup log facts: question bank 292 questions (311 on 2026-10-14; the SC-009 data commits removed questions), index generation 1 reused (corpus byte-identical), vectors and cross-references already complete, so search and cross-references are fully served from the first request.

## 3. Started versus reused

- Reused by `qa-up.sh`, not restarted: vasic.digital, milosvasic.ru, the live workshop.
- Restarted by `qa-up.sh --only ai`: ai_interviewing. The running process was a 2026-09-25 binary started before HEAD `275928e`/`5c0ed32` and carried no build stamp; its own `start.sh` rebuilds from the (clean) tree, so the restart put HEAD on the port.
- Started: the workshop QA instance, from a binary and web bundle built from a clean export of workshop HEAD `da916c1a6a2c`, with the live container's flag set except the QA port, `-port-fallback 0`, the QA state directory and the HEAD bundle. Its existing auth database (with the rotated QA password) was reused.
- Both started servers run inside bounded `systemd --user` scopes with an 8 hour cap; they stop by themselves around 01:12 and 01:14 on 2026-10-16. A server started by `qa-up.sh` inside a plain `bounded-run` call would die when that call returns, because the scope kills what it leaves behind; the ai start therefore holds its scope open after `qa-up.sh` returns.

## 4. How to stop

Run from the repository root. Do NOT run `bash scripts/qa-up.sh --stop` without `--only`: `.service-registry/qa/workshop.started` is a stale marker from 2026-10-14, and `--stop` honours it, which would run `workshop/scripts/stop.sh` against the LIVE container.

| Service | Stop command |
|---|---|
| vasic.digital | `bash scripts/qa-up.sh --stop --only vd` |
| milosvasic.ru | `bash scripts/qa-up.sh --stop --only mv` |
| ai_interviewing | `bash scripts/qa-up.sh --stop --only ai`, then `systemctl --user stop bounded-run-ai-interviewing-qa.scope` |
| workshop QA instance | `systemctl --user stop bounded-run-workshop-qa-instance.scope` |
| workshop live | not part of QA teardown; leave running (operator decision) |

## 5. Credentials

The live workshop uses the operator's own account; nothing here uses or records a credential for it. The QA instance (8187) uses the rotated QA-only password from `workshop-qa-access.md`; operator login instructions, without the secret, are in a 0600 file outside the repository on the QA host (`~/.cache/agent-scratch/qa-boot/workshop-qa-login.md`). ai_interviewing and the two static sites need no login for the pages listed.

## 6. Not covered, and why

- No browser was driven in this revision; pages were checked by status code only. Visual and interactive checks are the manual QA itself.
- The live workshop was checked only with unauthenticated GETs (no credential for it is available to agents, by decision).
- ai_interviewing was not exercised with a login.
- The two deliberate wrong-password logins in the smoke can trip the QA login rate limiter (HTTP 429) for about a minute.

## 7. Known caveats

- The live workshop runs build `72c565e` (dirty) and does not include the later redaction, SC-009 and quick-start commits; the QA instance on 8187 does (HEAD `da916c1`). Test HEAD behaviour on 8187.
- The QA instance serves the Angular bundle built from HEAD; the in-tree `workshop/platform/web` (2026-10-07) predates UI commit `1d4cdfa` and was not used or changed.
- LAN access stays closed (loopback bind, operator decision).
- The answering feature is OFF by design (semantic search stays on).
- The host suspend guard is not installed (root step pending).
- UNHEALTHY `helixagent-mcp-*` containers are pre-existing and unrelated to this project.
- `llmctl-decide` on 127.0.0.1:8095 resets plain HTTP connections to `/`; it is not a QA website and was not checked further.
