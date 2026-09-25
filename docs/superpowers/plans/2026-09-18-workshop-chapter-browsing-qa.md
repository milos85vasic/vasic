# Workshop Chapter Browsing & Content — Exhaustive HelixQA Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exhaustive, live-verified HelixQA test-bank coverage for workshop's chapter-browsing surface (`/chapters`, `/chapters/:slug`, `/chapters/:slug/transcript`), across all 4 real chapters, with any real bug found root-caused and TDD-fixed before this plan is done.

**Architecture:** Four `helixqa http` bank files, one per concern, each proven with a golden-good/golden-bad pair against the live, rebuilt workshop server, then wired into the existing `verify-helixqa-web.sh` gate's bank scope.

**Tech Stack:** HelixQA (`submodules/qa/bin/helixqa`, `http` subcommand only — never `run`), YAML test banks, `pipeline/extract`'s existing Go/TypeScript/Angular stack for any fix work.

**Spec:** [docs/superpowers/specs/2026-09-18-workshop-chapter-browsing-qa-design.md](../specs/2026-09-18-workshop-chapter-browsing-qa-design.md)

## Global Constraints

- Every bank uses the structured `http:` action type exclusively — never a prose `action:` string, and every run uses `helixqa http`, never `helixqa run` (the vacuous-bank-bluff class this session already found and fixed twice today in `submodules/qa`'s own gate scripts).
- Every case needs a real golden-bad control (invert the real code path, confirm genuine FAIL, restore, confirm PASS again) — no case ships without one.
- The workshop server must be rebuilt and its `source_commit` confirmed equal to `workshop`'s current `HEAD` before any live verification step in any task — re-check this at the start of each task, since earlier tasks' commits move HEAD.
- Any real bug HelixQA finds triggers a full `systematic-debugging` root-cause pass (Phase 1-4) and a TDD fix — never a symptom patch, never silently working around it.
- Credentials are supplied only at CLI-invocation time (`--admin-user`/`--admin-pass` flags), never written into any bank file.
- workshop is a private repo with its own remote; implementers commit locally, the controller pushes after task review (same standing rule as this session's other workshop work).
- This pipeline's existing test commands need `PYTHONPATH=".:pipeline/extract"` with `pipeline/venv/bin/python` — irrelevant to this plan's own Go/Angular/YAML work but relevant if a fix touches `pipeline/extract/`.

---

### Task 1: Write and prove `chapter-list.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/chapter-list.yaml`

**Interfaces:**
- Consumes: `submodules/qa/bin/helixqa` (already built), the live workshop server at `http://127.0.0.1:8087`.
- Produces: a proven bank file later tasks and Task 5's gate wiring depend on.

- [ ] **Step 1: Confirm the server is rebuilt and current**

```bash
cd $VASIC_ROOT/workshop
curl -sS http://127.0.0.1:8087/api/health | grep source_commit
git rev-parse HEAD
```
Expected: the two commit hashes match. If not, `bash scripts/build.sh && bash scripts/restart.sh` first, and re-check.

- [ ] **Step 2: Read the real `GET /chapters` list-endpoint handler to learn its exact response shape**

```bash
grep -n "func listChapters\|api/chapters\"" platform/backend/cmd/workshop-server/main.go | head -10
```
Read the full handler function this finds — its exact JSON field names, and what it returns for the count (`4` chapters, confirmed live via `/api/health`'s own `"chapters": 4` field). Do not guess field names; quote the real ones you find.

- [ ] **Step 3: Obtain the real seeded login credential**

Read `specs/007-decouple-modules-auth/spec.md` at the **umbrella root** (`$VASIC_ROOT/specs/007-decouple-modules-auth/spec.md` — this path does not resolve from inside `workshop/` or `submodules/qa/`, exactly as this session already found and fixed for the `ai_interviewing` RBAC bank) for the seeded credential to use against workshop's own login endpoint. If workshop's seeded credential differs from `ai_interviewing`'s, find workshop's own real one — check `platform/backend/gates/` for an existing `--admin-user`/`--admin-pass` invocation of a workshop gate that already authenticates, and mirror it exactly.

- [x] **Step 4: Write the bank**

Using the exact field names from Step 2 and the real credential mechanism from Step 3, write a bank with these cases (fill in real `expect_body_contains`/`expect_json_path` values from what Step 2 actually found — do not invent field names):

```yaml
# SPDX-FileCopyrightText: 2026 Milos Vasic
# SPDX-License-Identifier: Apache-2.0
#
# HelixQA Test Bank: Workshop Chapter List
# Part of exhaustive chapter-browsing coverage (docs/superpowers/specs/
# 2026-09-18-workshop-chapter-browsing-qa-design.md). Uses `helixqa http`
# exclusively -- `helixqa run` never dispatches a real request for an
# http-asserting case on the web platform (see banks/workshop/spa-routing.yaml's
# own header for the full investigation this session already did).

version: "1.0"
name: "Workshop Chapter List"
description: "The chapter list endpoint returns exactly the 4 real chapters with correct shape"
metadata:
  author: "vasic-digital"
  app: "workshop"
  version: "1.0.0"

test_cases:
  - id: WK-CHLIST-001
    name: "Authenticated GET /api/chapters returns all 4 real chapters"
    category: functional
    priority: critical
    platforms: [web]
    steps:
      - name: "Authenticate"
        action: "http: POST /api/auth/login"
        auth: "admin"
        expect_status: 200
        expected: "200 OK, session token issued"
      - name: "List chapters"
        action: "http: GET /api/chapters"
        auth: "admin"
        expect_status: 200
        expected: "200 OK, response reports exactly 4 chapters (fill in the real field/count assertion from Step 2's findings)"
    tags: [chapters, list, regression]
    estimated_duration: "5s"
    expected_result: "The chapter list reflects the real, current 4-chapter corpus"

  - id: WK-CHLIST-002
    name: "Unauthenticated GET /api/chapters is genuinely denied"
    category: security
    priority: high
    platforms: [web]
    steps:
      - name: "List chapters with no credential"
        action: "http: GET /api/chapters"
        expect_status: 401
        expected: "401, never a silent empty-content 200"
    tags: [chapters, list, security, regression]
    estimated_duration: "5s"
    expected_result: "No session means no chapter data, not an empty-but-200 response"
```

- [ ] **Step 5: Run it against the live server**

```bash
cd $VASIC_ROOT/submodules/qa
./bin/helixqa http --banks banks/workshop/chapter-list.yaml --base-url http://127.0.0.1:8087 --login-path /api/auth/login --admin-user <real user from Step 3> --admin-pass <real password from Step 3> --verbose
```
Expected: both cases PASS. Capture the real output.

- [ ] **Step 6: Golden-bad control for WK-CHLIST-002**

Find a real, revertible way to make the auth check fail open (e.g., temporarily commenting out the auth middleware wrapper for this one route in `main.go`, or the equivalent this codebase actually uses — read how the route is wired first). Rebuild, restart, re-run the bank, confirm WK-CHLIST-002 now FAILs (a 200 where 401 was expected). Restore, rebuild, restart, confirm PASS again. If no clean, safely-revertible mutation exists for this specific case, say so precisely rather than forcing one — this is itself a valid finding.

- [x] **Step 7: Commit**

```bash
cd $VASIC_ROOT/submodules/qa
git add banks/workshop/chapter-list.yaml
git status   # confirm ONLY your file is staged
git commit -m "qa: HelixQA bank for workshop's chapter list endpoint

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
Do NOT push — the controller decides on pushing after task review.

---

### Task 2: Write and prove `chapter-detail-recording.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/chapter-detail-recording.yaml`

**Interfaces:**
- Consumes: same as Task 1.
- Produces: a proven bank covering the recording/watch section of chapter detail.

- [ ] **Step 1: Confirm the server is rebuilt and current** (same check as Task 1 Step 1 — HEAD may have moved since Task 1's own commit).

- [ ] **Step 2: Read `chapter-detail.component.ts`'s recording section and its backing API** to learn the exact contract for `recording.present`/absent, and find the real API route the frontend calls for a chapter's recording data/probe (`/api/chapters/:slug/recording`, `/api/chapters/:slug/recording/probe` — confirmed to exist as real registered routes earlier this session; read their handlers for exact response shape).

- [x] **Step 3: Write the bank** with cases for: a chapter WITH a real recording (pick one of 01/02/02.01/02.02 — confirm via the live API which ones have `recording.present: true` right now, do not assume), the recording-probe endpoint's real response shape, and a nonexistent chapter slug against this same endpoint (expect a genuine 404). Mirror Task 1's exact `http:`/`auth:` structure.

- [ ] **Step 4: Run against the live server, capture real output.**

- [ ] **Step 5: Golden-bad control** for at least the nonexistent-slug 404 case (a real, revertible way to make chapter-slug validation fail open — read the routing code first, do not guess).

- [x] **Step 6: Commit** (same pattern as Task 1 Step 7, own file only).

---

### Task 3: Write and prove `chapter-detail-content.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/chapter-detail-content.yaml`

**Interfaces:**
- Consumes: same as Task 1. Also consumes the real per-chapter state table from the design spec (2 PDF-sourced, 1 transcript-only, 1 freshly-ASR'd) — re-verify this table live before writing cases, since it was measured before this plan's own Task 1/2 work, which could not have changed it, but re-confirm rather than trust a stale table.

**Interfaces:**
- Produces: a proven bank covering the four knowledge sub-sections (`next-meeting`, `open-questions`, `meeting-notes`, `todo`) and the transcript-presence/uncertain-count display.

- [ ] **Step 1: Confirm the server is rebuilt and current.**

- [ ] **Step 2: Read the four knowledge sub-endpoints' handlers** (`/api/chapters/01/meeting-notes`, `/api/chapters/01/open-questions`, `/api/chapters/01/todo`, and the next-meeting equivalent — confirm its exact route name, it was not in the earlier grep's result set, find it) for their real response shape, specifically the `state` field's real possible values (`unwritten`/`authored`/whatever the real enum is — do not assume the exact string, read it).

- [x] **Step 3: Write cases for each of the 4 real chapters against each of the 4 knowledge endpoints** (16 combinations), asserting the real, currently-live `state` value for each — pull the real values via a live authenticated `curl` first, do not guess, and record what you found in your report.

- [ ] **Step 4: Add the one synthetic case: an "unwritten" state.**

No real chapter currently has this state (all 4 were populated earlier this session). Create a temporary, minimal fixture chapter directory (e.g., `chapters/99-qa-fixture/` with only the minimal structure `discover_chapters`/the chapter roster needs to register it — read what that minimum actually is first, do not guess) with genuinely no meeting-notes content, run the bank case against it, then **delete the fixture directory completely** before finishing this task — confirm via `git status` that no fixture trace remains. Document this exact setup/teardown procedure in the bank file's own header comment so a future re-run knows it needs to recreate the fixture, not find it already there.

- [ ] **Step 5: Run against the live server, capture real output for all 17 cases.**

- [ ] **Step 6: Golden-bad control** for at least one `state` assertion (temporarily rename or move a real chapter's knowledge file to simulate the state changing, confirm the bank catches it, restore immediately, confirm PASS, verify via `git status`/`diff` that the real chapter content is byte-identical to before the mutation).

- [x] **Step 7: Commit** (own file only; the fixture chapter must NOT be part of this commit — confirm it was already deleted in Step 4).

---

### Task 4: Write and prove `chapter-transcript-route.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/chapter-transcript-route.yaml`

**Interfaces:**
- Consumes: same as Task 1.
- Produces: a proven bank covering the dedicated `/chapters/:slug/transcript` route and its backing API.

- [ ] **Step 1: Confirm the server is rebuilt and current.**

- [ ] **Step 2: Read the transcript route's real backing API** (likely `/api/chapters/:slug/transcript` or similar — confirm the exact path from `main.go`'s route table, do not assume it matches the frontend path) for its response shape, specifically how `uncertain_count` and `passage_count` are represented (confirmed present in the frontend component's template).

- [x] **Step 3: Write cases**: a chapter with a real transcript (all 4 currently qualify — pick 02.02 since it's the freshest, least-previously-tested one), the passage/uncertain counts matching real live values (pull them live, don't guess), and a nonexistent chapter slug against this endpoint (expect genuine 404, matching Task 2's discipline).

- [ ] **Step 4: Run against the live server, capture real output.**

- [ ] **Step 5: Golden-bad control** for the nonexistent-slug case, mirroring Task 2's approach.

- [x] **Step 6: Commit** (own file only).

---

### Task 5: Wire the 4 new banks into workshop's HelixQA gate

**Files:**
- Modify: `workshop/platform/gates/verify-helixqa-web.sh`

**Interfaces:**
- Consumes: `BANKS_DIR` variable already defined in this gate (points at `submodules/qa/banks/workshop`) — the 4 new bank files land inside that same directory, so **no path change is needed**; confirm this by reading the current gate script before assuming a change is required.
- Produces: the expanded bank set now runs as part of workshop's mandatory `scripts/verify.sh`.

- [ ] **Step 1: Read the current `verify-helixqa-web.sh` in full**, especially its invocation of `helixqa http --banks "$BANKS_DIR"` — confirm it already points at the whole `banks/workshop/` directory (not a single named file), meaning the 4 new files are automatically included with zero script changes needed. If it DOES need a change (e.g., it currently names `spa-routing.yaml` explicitly rather than the whole directory), make the minimal fix to point at the directory.

- [ ] **Step 2: Also apply this session's own vacuous-bank-bluff fix, if it is not already present** — read the gate's current JSON-parsing/case-count-accounting logic (added earlier today per the final-review fix round) and confirm it correctly requires `total_cases` to match what the (now-larger) bank set declares. If the fix was written assuming a fixed, small case count, verify it still works generically as the bank set grows — this is exactly the kind of regression this session's own earlier finding warned about.

- [ ] **Step 3: Run the gate for real** against the live, rebuilt server:

```bash
bash $VASIC_ROOT/workshop/platform/gates/verify-helixqa-web.sh
```
Expected: PASS, reporting the full, now-larger case count (4 bank files' worth) — paste the real output.

- [ ] **Step 4: Run the full `scripts/verify.sh` aggregator** (this may take several minutes — this session's own experience shows it can exceed 5 minutes; do not treat a long runtime as a hang) and confirm the HelixQA gate's result is correctly folded into the aggregate verdict.

- [ ] **Step 5: Commit** any script changes from Step 1/2 (if none were needed, say so explicitly in your report rather than committing a no-op).

---

### Task 6: Triage and root-cause any real findings

**Files:** Determined by whatever Tasks 1-5 actually found — this task's scope is the PROCESS, not a predetermined file list.

**Interfaces:**
- Consumes: the real, captured output from every bank run in Tasks 1-5.

- [ ] **Step 1: Collect every case that did not PASS as expected** across all four banks' real runs (not the golden-bad controls — those are supposed to fail — but any case that failed unexpectedly during golden-good verification, or any discrepancy between what a case asserted and what Step 2 of its own task found when reading the real handler).

- [ ] **Step 2: For each real finding, invoke `systematic-debugging`'s full Phase 1-4 process**: reproduce consistently, read the actual error/response, trace to the actual source (not a guess), form a single hypothesis, test it minimally, and only then implement a fix.

- [ ] **Step 3: Fix each real finding with TDD** — a failing test first (in whichever language/layer the bug actually lives: Go backend, Angular frontend, or the HelixQA bank itself if the bank's own assertion was wrong), then the minimal fix, then confirm GREEN, per this session's established discipline throughout today's other real findings (the vacuous-bank-bluff fix, the `answer_text` redaction-gate bypass fix, etc.).

- [ ] **Step 4: Re-run the affected bank(s) live** after each fix to confirm the case now genuinely PASSes against the rebuilt, restarted server — never trust an in-memory or unit-test-only confirmation for something this plan committed to verifying live.

- [ ] **Step 5: If zero real findings surfaced** (every bank passed exactly as each task's own Step 2 predicted from reading the real handlers), state that explicitly and precisely in this task's report — an empty findings list from genuinely thorough testing is a legitimate, valuable result, not something to pad with manufactured findings.

- [ ] **Step 6: Commit each fix separately**, scoped to its own repository (workshop, or the umbrella if the fix somehow touches umbrella-level code — unlikely for this sub-project's scope), following the same never-push-without-controller-review discipline as every other task.

---

## Completion evidence — 2026-09-24 (bookkeeping audit)

Only two step types are ticked, and only where the artifact is provable from the repositories: **Write/Create the bank** (the bank file exists and is tracked in `submodules/qa`) and **Commit** (a `submodules/qa` commit touches that bank). Every OBSERVATION step (confirm the server, read handlers, run live, capture output, golden-bad controls, wire and run the gate, triage) is deliberately left unticked: it happened in a past session and cannot be re-proven from the tree. Unticked therefore means "not provable here", not "not done".

| Task | Step | Kind | Bank | `submodules/qa` commit |
|---|---|---|---|---|
| Task 1 | Step 4 | write | `chapter-list.yaml` | 6a7c1f9 qa: HelixQA bank for workshop's chapter list endpoint |
| Task 1 | Step 7 | commit | `chapter-list.yaml` | 6a7c1f9 qa: HelixQA bank for workshop's chapter list endpoint |
| Task 2 | Step 3 | write | `chapter-detail-recording.yaml` | 1d57faa qa: HelixQA bank for workshop's chapter-detail recording surface |
| Task 2 | Step 6 | commit | `chapter-detail-recording.yaml` | 1d57faa qa: HelixQA bank for workshop's chapter-detail recording surface |
| Task 3 | Step 3 | write | `chapter-detail-content.yaml` | efb5a3a fix(chapter-detail-content): correct WK-CHDETCONT-001 for chapter 01's real, fixed meeting-n |
| Task 3 | Step 7 | commit | `chapter-detail-content.yaml` | efb5a3a fix(chapter-detail-content): correct WK-CHDETCONT-001 for chapter 01's real, fixed meeting-n |
| Task 4 | Step 3 | write | `chapter-transcript-route.yaml` | 041ed03 test(workshop): add chapter-transcript-route HelixQA bank |
| Task 4 | Step 6 | commit | `chapter-transcript-route.yaml` | 041ed03 test(workshop): add chapter-transcript-route HelixQA bank |
