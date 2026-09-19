# Workshop Diagnostics / Status — Exhaustive HelixQA Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exhaustive, live-verified HelixQA test-bank coverage for `GET /api/health` and `GET /api/index/status`, centered on the two currently-untested gaps (index `degraded` state, `probeOllama`'s states), with any real bug found root-caused and TDD-fixed before this plan is done.

**Architecture:** One `helixqa http` bank file, proven with golden-good/golden-bad pairs against the live, rebuilt workshop server, then wired into `verify-helixqa-web.sh`.

**Tech Stack:** HelixQA (`submodules/qa/bin/helixqa`, `http` subcommand only), YAML test banks.

**Spec:** [docs/superpowers/specs/2026-09-19-workshop-diagnostics-status-qa-design.md](../specs/2026-09-19-workshop-diagnostics-status-qa-design.md)

## Global Constraints

- Every bank uses the structured `http:` action type exclusively; every run uses `helixqa http`, never `helixqa run`.
- Every case needs a real golden-bad control where safely possible; where the shared live corpus makes a mutation unsafe (e.g. removing all chapters to test the empty-corpus case), `_skip` with a precise reason rather than forcing it.
- The workshop server must be rebuilt and its `source_commit` confirmed equal to `workshop`'s current `HEAD` before any live verification step in any task.
- **After any real application-level fix, re-run the FULL gate**, not just this bank.
- This bank does NOT re-test `/api/chapters`, `/api/suggest`, `/api/search`, or `/api/passages/{pid}/crossrefs` themselves — only what is unique to `/api/health`/`/api/index/status`.
- Do not confuse `verify-status-*.sh` (the unrelated CLI-lifecycle gates) with this sub-project's surface.
- Credentials supplied only at CLI-invocation time. workshop is a private repo; implementers commit locally, never push.

---

### Task 1: Write and prove `diagnostics-status.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/diagnostics-status.yaml`

- [ ] **Step 1: Confirm the server is rebuilt and current.**

- [ ] **Step 2: Read `healthHandler`/`probeOllama`/`buildIdentity`** (`main.go`) and `IndexStatusHandler` (`router.go`) in full for exact field names and the closed vocabularies (`INDEX_STATE`'s 5 members, the two `unavailable` reason codes).

- [ ] **Step 3: Confirm live, current values before writing cases** — `curl` both routes (health unauthenticated, index-status authenticated) and record the REAL current `ollama.configured` value, the REAL current index `state`/`unavailable` reason, and the REAL current `chapters` count vs. a live `GET /api/chapters` count. Do not assume any specific value from the design doc; confirm what THIS run of the live server actually reports.

- [ ] **Step 4: Write the bank** with cases for: `/api/health`'s full field set (unauthenticated), the `chapters`-count cross-check against `GET /api/chapters`, the `web:true`/`GET /` agreement check, `ollama.configured` reflecting the real live state, `/api/index/status`'s real current response (whichever of `ok`/`unavailable` it currently is), the `state` enum membership check if `ok`, unauthenticated `/api/index/status` → 401.

- [ ] **Step 5: Investigate the `degraded`-state live trigger** (design doc case 8, the highest-value case in this bank) — read `pkg/index/degraded_test.go`'s real mechanism (`index.MarkDegraded`, recording a redaction against the currently-live generation) and determine whether an HTTP-level equivalent can be safely, revertibly constructed against the live shared corpus. If yes, build it. If no safe mechanism exists without risking real corruption to shared state other sub-projects depend on, say so precisely with the specific blocker, and `_skip` the case with that reason — do not force a risky mutation against the shared live index.

- [ ] **Step 6: Run the bank against the live server, capture real output.**

- [ ] **Step 7: Golden-bad controls** where safely possible — the cross-check cases (2, chapters count; the web-flag agreement) are naturally strong even without an explicit mutation, since they compare two independently-computed live values.

- [ ] **Step 8: Commit** (own file only, never pushed).

---

### Task 2: Wire the bank into the gate

- [ ] **Step 1: Confirm server current.**
- [ ] **Step 2: Confirm the gate's directory glob picks up the file with no script change.**
- [ ] **Step 3: Run the FULL gate live**, expect PASS with the larger case count.
- [ ] **Step 4: Commit** any script change, or state none was needed.

---

### Task 3: Triage and root-cause any real findings

**Files:** Determined by findings.

- [ ] **Step 1: Collect every case that did not PASS as expected.**
- [ ] **Step 2: Assess the session-expires-mid-`/status`-page ambiguity** (design doc's named gap): is generic "server refused the request" wording for an expired session acceptable, or does it need to be distinguishable? This is a judgment call about UX/security tradeoffs, not purely a code defect — investigate, form a recommendation, and either fix it (if a small, safe, TDD-able change) or document the decision explicitly rather than silently leaving it open.
- [ ] **Step 3: For each other real finding, invoke `systematic-debugging`'s full Phase 1-4 process and fix with TDD.**
- [ ] **Step 4: Re-run the affected bank(s) AND the full gate live** after each fix.
- [ ] **Step 5: If zero real findings surfaced beyond the two named, documented gaps** (session-expiry wording, empty-corpus probing), state that explicitly.
- [ ] **Step 6: Commit each fix separately**, never pushed.
