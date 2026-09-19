# Workshop Auth & Session — Exhaustive HelixQA Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exhaustive, live-verified HelixQA test-bank coverage for workshop's core auth/session mechanics (login, logout, switch, me, concurrent sessions, loopback+cookie interaction), with any real bug found root-caused and TDD-fixed before this plan is done.

**Architecture:** One `helixqa http` bank file, proven with golden-good/golden-bad pairs against the live, rebuilt workshop server, then wired into the existing `verify-helixqa-web.sh` gate's bank scope (same directory glob the chapter-browsing banks already use — confirm no script change is needed before assuming one is).

**Tech Stack:** HelixQA (`submodules/qa/bin/helixqa`, `http` subcommand only — never `run`), YAML test banks.

**Spec:** [docs/superpowers/specs/2026-09-19-workshop-auth-session-qa-design.md](../specs/2026-09-19-workshop-auth-session-qa-design.md)

## Global Constraints

- Every bank uses the structured `http:` action type exclusively — never a prose `action:` string, and every run uses `helixqa http`, never `helixqa run`.
- Every case needs a real golden-bad control (invert the real code path, confirm genuine FAIL, restore, confirm PASS again) — no case ships without one, UNLESS the sandbox guardrail refuses a live restart onto auth-weakened code, in which case a code-level-only verification is acceptable (matching the chapter-browsing sub-project's WK-CHLIST-002 precedent) — state this explicitly if it recurs, don't force a workaround.
- The workshop server must be rebuilt and its `source_commit` confirmed equal to `workshop`'s current `HEAD` before any live verification step in any task.
- Any real bug HelixQA finds triggers a full `systematic-debugging` root-cause pass (Phase 1-4) and a TDD fix — never a symptom patch.
- Credentials are supplied only at CLI-invocation time (`--admin-user`/`--admin-pass` flags), never written into any bank file.
- workshop is a private repo with its own remote; implementers commit locally, the controller pushes after task review.
- The two seeded users are `milosvasic` (admin) and `rami` (user) — read the real credential values from `specs/007-decouple-modules-auth/spec.md` at the umbrella root (`$VASIC_ROOT/specs/007-decouple-modules-auth/spec.md`, FR-009) — this path does NOT resolve from inside `workshop/` or `submodules/qa/`.

---

### Task 1: Write and prove `auth-session.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/auth-session.yaml`

**Interfaces:**
- Consumes: `submodules/qa/bin/helixqa` (already built), the live workshop server at `http://127.0.0.1:8087`.
- Produces: a proven bank later wired into the gate.

- [ ] **Step 1: Confirm the server is rebuilt and current**

```bash
cd $VASIC_ROOT/workshop
curl -sS http://127.0.0.1:8087/api/health | grep source_commit
git rev-parse HEAD
```
Expected: the two commit hashes match. If not, `bash scripts/build.sh && bash scripts/restart.sh` first, and re-check.

- [ ] **Step 2: Read the real auth handlers to learn exact request/response shapes**

```bash
sed -n '3376,3560p' platform/backend/cmd/workshop-server/main.go
```
Read `authLoginHandler`, `authLogoutHandler`, `authSwitchHandler`, `authMeHandler` in full. Note the exact field names in the login/switch response (including `pending_migration_choice` if present), the exact cookie name (`session`) and its attributes, and the exact 401 error message bodies for invalid credentials vs. missing/expired token. Do not guess any field name — quote what you find in your report.

- [ ] **Step 3: Obtain the real seeded credentials**

Read `specs/007-decouple-modules-auth/spec.md` at the umbrella root (`$VASIC_ROOT/specs/007-decouple-modules-auth/spec.md`, FR-009) for both seeded users' real values.

- [ ] **Step 4: Write the bank**

Using the exact field/message values from Step 2 and the real credentials from Step 3, write a bank with these cases (fill in real values from what Step 2 actually found — do not invent field names):

```yaml
# SPDX-FileCopyrightText: 2026 Milos Vasic
# SPDX-License-Identifier: Apache-2.0
#
# HelixQA Test Bank: Workshop Auth & Session
# Part of exhaustive HelixQA coverage (docs/superpowers/specs/
# 2026-09-19-workshop-auth-session-qa-design.md). Uses `helixqa http`
# exclusively -- `helixqa run` never dispatches a real request for an
# http-asserting case on the web platform.

version: "1.0"
name: "Workshop Auth & Session"
description: "Core login/logout/switch/me mechanics, concurrent sessions, and the loopback+cookie interaction behind the 2026-09-17 fixes"
metadata:
  author: "vasic-digital"
  app: "workshop"
  version: "1.0.0"

test_cases:
  - id: WK-AUTH-001
    name: "Valid login for each seeded user succeeds"
    category: functional
    priority: critical
    platforms: [web]
    steps:
      - name: "Login as milosvasic"
        action: "http: POST /api/auth/login"
        expect_status: 200
        expected: "200 OK, session established (fill in real response-field assertion from Step 2)"
      - name: "Login as rami"
        action: "http: POST /api/auth/login"
        expect_status: 200
        expected: "200 OK, session established"
    tags: [auth, login, regression]
    estimated_duration: "5s"
    expected_result: "Both seeded users can authenticate"

  - id: WK-AUTH-002
    name: "Invalid credentials are indistinguishably rejected"
    category: security
    priority: high
    platforms: [web]
    steps:
      - name: "Login with wrong password for a real user"
        action: "http: POST /api/auth/login"
        expect_status: 401
        expected: "401, message identical to unknown-username case (fill in exact message from Step 2)"
      - name: "Login with an unknown username"
        action: "http: POST /api/auth/login"
        expect_status: 401
        expected: "401, message identical to wrong-password case"
    tags: [auth, login, security, regression]
    estimated_duration: "5s"
    expected_result: "No account-enumeration signal between wrong-password and unknown-user"

  - id: WK-AUTH-003
    name: "GET /api/auth/me reflects the authenticated caller"
    category: functional
    priority: high
    platforms: [web]
    steps:
      - name: "Login"
        action: "http: POST /api/auth/login"
        auth: "admin"
        expect_status: 200
      - name: "Fetch own identity"
        action: "http: GET /api/auth/me"
        auth: "admin"
        expect_status: 200
        expected: "Reflects the logged-in user (fill in real field assertion)"
    tags: [auth, me, regression]
    estimated_duration: "5s"
    expected_result: "/me correctly identifies the caller"

  - id: WK-AUTH-004
    name: "Logout invalidates the session"
    category: security
    priority: critical
    platforms: [web]
    steps:
      - name: "Login"
        action: "http: POST /api/auth/login"
        expect_status: 200
      - name: "Logout"
        action: "http: POST /api/auth/logout"
        expect_status: 200
      - name: "Use the now-logged-out session against a gated route"
        action: "http: GET /api/chapters"
        expect_status: 401
        expected: "The logged-out token/cookie no longer authenticates"
    tags: [auth, logout, security, regression]
    estimated_duration: "5s"
    expected_result: "Logout genuinely revokes the session"

  - id: WK-AUTH-005
    name: "Concurrent sessions for the same user both stay valid; switch mass-revokes"
    category: functional
    priority: high
    platforms: [web]
    steps:
      - name: "First login as milosvasic"
        action: "http: POST /api/auth/login"
        expect_status: 200
      - name: "Second, independent login as milosvasic"
        action: "http: POST /api/auth/login"
        expect_status: 200
      - name: "First session still valid against a gated route"
        action: "http: GET /api/chapters"
        expect_status: 200
      - name: "Second session still valid against a gated route"
        action: "http: GET /api/chapters"
        expect_status: 200
      - name: "Switch to rami using the second session"
        action: "http: POST /api/auth/switch"
        expect_status: 200
      - name: "First (pre-switch) session is now revoked"
        action: "http: GET /api/chapters"
        expect_status: 401
        expected: "Switch mass-revokes the caller's own prior sessions"
    tags: [auth, session, concurrency, regression]
    estimated_duration: "10s"
    expected_result: "Two independent logins coexist; switch revokes prior sessions for that account"

  - id: WK-AUTH-006
    name: "Unauthenticated access to a gated route is a genuine 401"
    category: security
    priority: high
    platforms: [web]
    steps:
      - name: "List chapters with no credential"
        action: "http: GET /api/chapters"
        expect_status: 401
        expected: "401, never a silent empty-content 200"
    tags: [auth, security, regression]
    estimated_duration: "5s"
    expected_result: "No session means no data, not an empty-but-200 response"

  - id: WK-AUTH-007
    name: "Loopback caller with a valid session cookie and no Authorization header works end-to-end"
    category: security
    priority: critical
    platforms: [web]
    steps:
      - name: "Login (session cookie issued)"
        action: "http: POST /api/auth/login"
        expect_status: 200
      - name: "Access a gated route via cookie only, from loopback, no Authorization header"
        action: "http: GET /api/chapters"
        expect_status: 200
        expected: "Cookie-only session from loopback succeeds — regression pin for the 2026-09-17 LAN-deadlock and cookie/header-precedence fixes"
    tags: [auth, security, regression, loopback]
    estimated_duration: "5s"
    expected_result: "The exact combination behind two real 2026-09-17 fixes still works"

  - id: WK-AUTH-008
    name: "Malformed login request is a clean 4xx, never a 500 or hang"
    category: functional
    priority: medium
    platforms: [web]
    steps:
      - name: "POST /api/auth/login with a missing required field"
        action: "http: POST /api/auth/login"
        expect_status: 400
        expected: "Clean 4xx, not a 500 or timeout"
    tags: [auth, login, regression]
    estimated_duration: "5s"
    expected_result: "Malformed input is rejected cleanly"
```

- [ ] **Step 5: Run it against the live server, capture real output.**

```bash
cd $VASIC_ROOT/submodules/qa
./bin/helixqa http --banks banks/workshop/auth-session.yaml --base-url http://127.0.0.1:8087 --login-path /api/auth/login --admin-user <real user> --admin-pass <real password> --verbose
```
Expected: all cases PASS. Some cases (WK-AUTH-002, 004, 005, 007, 008) issue their own explicit login/logout steps rather than relying on the harness's `auth: admin` shortcut — read `helixqa http`'s own step-action syntax (`banks/workshop/spa-routing.yaml` or the chapter-browsing banks) to confirm the exact way to express an explicit login step with a specific credential pair per-step if the harness's `auth: admin` shortcut can't express "two independent logins in one case" — investigate this before writing Step 4's YAML if `auth: admin` turns out to only support one implicit session per bank run; report precisely what you find rather than guessing at the mechanism.

- [ ] **Step 6: Golden-bad controls**

For each of: WK-AUTH-002 (account enumeration), WK-AUTH-004 (logout revocation), WK-AUTH-005 (mass-revoke-on-switch), WK-AUTH-006 (auth gating), WK-AUTH-007 (loopback+cookie) — find a real, revertible way to invert the actual code path, rebuild, restart, confirm genuine FAIL, restore, rebuild, restart, confirm PASS again. If the sandbox guardrail refuses a live restart onto any of these mutations (same class as chapter-browsing's WK-CHLIST-002), accept a code-level-only verification for that specific case and say so precisely — do not force a workaround.

- [ ] **Step 7: Commit**

```bash
cd $VASIC_ROOT/submodules/qa
git add banks/workshop/auth-session.yaml
git status   # confirm ONLY your file is staged
git commit -m "qa: HelixQA bank for workshop's core auth/session mechanics

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
Do NOT push — the controller decides on pushing after task review.

---

### Task 2: Wire `auth-session.yaml` into workshop's HelixQA gate

**Files:**
- Modify: `workshop/platform/gates/verify-helixqa-web.sh` (only if needed)

**Interfaces:**
- Consumes: `BANKS_DIR` variable already defined in this gate (points at `submodules/qa/banks/workshop`) — the new bank file lands inside that same directory.
- Produces: the expanded bank set now runs as part of workshop's mandatory `scripts/verify.sh`.

- [ ] **Step 1: Confirm the server is rebuilt and current** (HEAD may have moved since Task 1's commit).

- [ ] **Step 2: Read the current gate script.** Confirm it already globs the whole `banks/workshop/` directory (Task 5 of the chapter-browsing plan already made it do this generically) — if so, the new bank file is automatically included with zero script changes.

- [ ] **Step 3: Run the gate for real**

```bash
bash $VASIC_ROOT/workshop/platform/gates/verify-helixqa-web.sh
```
Expected: PASS, reporting the full, now-larger case count. Paste the real output.

- [ ] **Step 4: Commit** any script changes from Step 2 (if none were needed, say so explicitly in your report rather than committing a no-op).

---

### Task 3: Triage and root-cause any real findings

**Files:** Determined by whatever Tasks 1-2 actually found.

**Interfaces:**
- Consumes: the real, captured output from every bank run in Tasks 1-2.

- [ ] **Step 1: Collect every case that did not PASS as expected** during golden-good verification (not the golden-bad controls, which are supposed to fail).

- [ ] **Step 2: For each real finding, invoke `systematic-debugging`'s full Phase 1-4 process.**

- [ ] **Step 3: Fix each real finding with TDD.**

- [ ] **Step 4: Re-run the affected bank(s) live** after each fix to confirm the case now genuinely PASSes against the rebuilt, restarted server.

- [ ] **Step 5: If zero real findings surfaced**, state that explicitly and precisely in this task's report.

- [ ] **Step 6: Commit each fix separately**, scoped to its own repository, never pushed by the implementer.
