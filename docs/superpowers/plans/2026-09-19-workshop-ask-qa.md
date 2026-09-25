# Workshop Ask / Q&A — Exhaustive HelixQA Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exhaustive, live-verified HelixQA test-bank coverage for workshop's ask/Q&A surface, scoped to what is honestly reachable with the live `Provider: none` deployment setting (`GET/POST /api/ask`, `GET /api/ask/status`), with any real bug found root-caused and TDD-fixed before this plan is done.

**Architecture:** One `helixqa http` bank file, proven with golden-good/golden-bad pairs against the live, rebuilt workshop server, then wired into the existing `verify-helixqa-web.sh` gate's bank scope.

**Tech Stack:** HelixQA (`submodules/qa/bin/helixqa`, `http` subcommand only — never `run`), YAML test banks.

**Spec:** [docs/superpowers/specs/2026-09-19-workshop-ask-qa-design.md](../specs/2026-09-19-workshop-ask-qa-design.md)

## Global Constraints

- **Do NOT change the live answer-provider deployment setting (`none`) under any circumstance.** This is an explicit, documented operator directive (`compose.yml:459-461`). If any step of this plan seems to require a provider to be reachable, that is a signal to scope the case out as a documented gap (per the spec's own "What this bank does NOT cover, and why" section), never a signal to flip the setting yourself.
- Every bank uses the structured `http:` action type exclusively — never a prose `action:` string, and every run uses `helixqa http`, never `helixqa run`.
- Every case needs a real golden-bad control where one is safely possible; where the deployment-scoping constraint above makes a golden-bad control inapplicable (e.g., you cannot make "no_provider" genuinely NOT fire without changing the provider setting), say so precisely rather than forcing one.
- The workshop server must be rebuilt and its `source_commit` confirmed equal to `workshop`'s current `HEAD` before any live verification step in any task.
- **After any real application-level fix in this sub-project, re-run the FULL `verify-helixqa-web.sh` gate**, not just this bank in isolation (per the auth-session sub-project's own cross-project lesson).
- Any real bug HelixQA finds triggers a full `systematic-debugging` root-cause pass (Phase 1-4) and a TDD fix.
- Credentials are supplied only at CLI-invocation time, never written into any bank file.
- workshop is a private repo with its own remote; implementers commit locally, the controller pushes after task review.
- Known HelixQA framework limitations (single-slot `auth: admin` credential cache, no cross-step response capture, no CookieJar) are already investigated — `_skip` with a precise reason if a case needs one of these, matching `auth-session.yaml`'s established convention.

---

### Task 1: Write and prove `ask.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/ask.yaml`

**Interfaces:**
- Consumes: `submodules/qa/bin/helixqa` (already built), the live workshop server at `http://127.0.0.1:8087`.
- Produces: a proven bank later wired into the gate.

- [ ] **Step 1: Confirm the server is rebuilt and current, and confirm the answer provider is STILL `none`**

```bash
cd $VASIC_ROOT/workshop
curl -sS http://127.0.0.1:8087/api/health | grep source_commit
git rev-parse HEAD
curl -sS -H "Authorization: Bearer <token>" http://127.0.0.1:8087/api/ask/status
```
Confirm the last command's response reflects `Provider: none` (or equivalent field showing no generative provider configured) before writing any case that assumes this. If the provider has somehow changed since the design was written, STOP and report this precisely rather than writing cases against an assumption that may no longer hold — this is a deployment fact to verify, not infer.

- [ ] **Step 2: Read the real `/api/ask` and `/api/ask/status` handlers**

```bash
sed -n '1,50p' pkg/answer/http.go
```
Read `pkg/answer/http.go`'s `Mount` function and both handlers in full. Note: the exact JSON field names `/api/ask/status` returns (`enabled`, `suspended`, `calibrated`, `verifier_kind`, `question_verifier_kind`, `estimated_seconds`, `latency_note` — confirm these are the REAL field names, don't assume from this list); the exact `reason.code` value for the no-provider case (research says `no_provider` — confirm live); `MaxQuestionBytes` (research says 2000) and `MaxWait` (research says 200s) — read the real constants, don't assume the research doc's numbers are still current.

- [x] **Step 3: Write the bank**

Cases:
- `WK-ASK-001`: `GET /api/ask/status` (authenticated) returns 200 with the real capability fields reflecting the live `none` provider state.
- `WK-ASK-002`: `GET /api/ask/status` unauthenticated returns 401 (confirmed live in prior research — a direct regression pin).
- `WK-ASK-003`: a well-formed question with no provider configured returns 503 with the real `reason.code` from Step 2 (the one honestly-reachable "asked a real question" path today).
- `WK-ASK-004`: an empty question returns 400 `empty_query` — distinct from the 503 path.
- `WK-ASK-005`: a question exceeding `MaxQuestionBytes` returns 413.
- `WK-ASK-006`: `GET /api/search` remains reachable while `/api/ask` returns 503 (one case here, or read `verify-g-http-5-search-survives-answering-down.sh`'s own approach first and mirror its HTTP-observable assertion without re-deriving its internal proof).
- `WK-ASK-007`: unauthenticated `POST /api/ask` returns 401.

Follow the existing sibling banks' exact `http:`/`auth:` YAML structure. In the bank's own header comment, explicitly document (matching the design doc's own list) that `answered`/`declined` states, the six-member decline vocabulary, and the async/job/SSE surface are NOT covered here because the live provider is `none` and this bank does not change deployment settings — name this as a documented, intentional scope boundary, not a silent gap.

- [ ] **Step 4: Run it against the live server, capture real output.**

```bash
cd $VASIC_ROOT/submodules/qa
./bin/helixqa http --banks banks/workshop/ask.yaml --base-url http://127.0.0.1:8087 --login-path /api/auth/login --admin-user <real user> --admin-pass <real password> --verbose
```
Expected: every case PASSes.

- [ ] **Step 5: Golden-bad controls where safely possible**

For WK-ASK-002 (auth required) and WK-ASK-007 (auth required) — invert the real auth check, confirm genuine FAIL, restore, confirm PASS again, matching the established pattern. For WK-ASK-003/004/005 (input validation / no-provider response), find a real, revertible way to invert the specific check being asserted WITHOUT touching the provider setting (e.g., temporarily changing `MaxQuestionBytes`'s comparison operator, or the `empty_query` check's condition) — read the real code first to find a genuinely revertible mutation, don't force one that isn't clean. If no safe golden-bad exists for a given case without touching deployment config, say so precisely.

- [x] **Step 6: Commit**

```bash
cd $VASIC_ROOT/submodules/qa
git add banks/workshop/ask.yaml
git status   # confirm ONLY your file is staged
git commit -m "qa: HelixQA bank for workshop's ask/Q&A surface (scoped to the live no_provider state)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
Do NOT push.

---

### Task 2: Wire `ask.yaml` into workshop's HelixQA gate

- [ ] **Step 1: Confirm the server is rebuilt and current.**

- [ ] **Step 2: Read the current gate script.** Confirm it already globs the whole `banks/workshop/` directory.

- [ ] **Step 3: Run the FULL gate for real:**

```bash
bash $VASIC_ROOT/workshop/platform/gates/verify-helixqa-web.sh
```
Expected: PASS, reporting the full, now-larger case count.

- [ ] **Step 4: Commit** any script changes, or the no-op statement if none were needed.

---

### Task 3: Triage and root-cause any real findings

- [ ] **Step 1: Collect every case that did not PASS as expected.**

- [ ] **Step 2: For each real finding, invoke `systematic-debugging`'s full Phase 1-4 process.**

- [ ] **Step 3: Fix each real finding with TDD** — remembering the Global Constraint that the provider setting itself is never touched. If a "finding" turns out to only be reachable by changing that setting, it is NOT a finding for this plan to fix — document it as an operator-decidable gap instead, exactly as the design doc already anticipates.

- [ ] **Step 4: Re-run the affected bank(s) AND the full gate live** after each fix.

- [ ] **Step 5: If zero real findings surfaced**, state that explicitly and precisely.

- [ ] **Step 6: Commit each fix separately**, never pushed by the implementer.

---

## Completion evidence — 2026-09-24 (bookkeeping audit)

Only two step types are ticked, and only where the artifact is provable from the repositories: **Write/Create the bank** (the bank file exists and is tracked in `submodules/qa`) and **Commit** (a `submodules/qa` commit touches that bank). Every OBSERVATION step (confirm the server, read handlers, run live, capture output, golden-bad controls, wire and run the gate, triage) is deliberately left unticked: it happened in a past session and cannot be re-proven from the tree. Unticked therefore means "not provable here", not "not done".

| Task | Step | Kind | Bank | `submodules/qa` commit |
|---|---|---|---|---|
| Task 1 | Step 3 | write | `ask.yaml` | 6488b63 qa: HelixQA bank for workshop's ask/Q&A surface (scoped to the live no_provider state) |
| Task 1 | Step 6 | commit | `ask.yaml` | 6488b63 qa: HelixQA bank for workshop's ask/Q&A surface (scoped to the live no_provider state) |
