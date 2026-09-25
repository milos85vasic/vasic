# Workshop Areas & Practice — Exhaustive HelixQA Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exhaustive, live-verified HelixQA test-bank coverage for workshop's areas/learning-path/practice-deck surfaces, with any real bug found root-caused and TDD-fixed before this plan is done.

**Architecture:** One `helixqa http` bank file with three clearly-separated case groups (taxonomy, learning-path, practice-deck), proven with golden-good/golden-bad pairs against the live, rebuilt workshop server, then wired into `verify-helixqa-web.sh`.

**Tech Stack:** HelixQA (`submodules/qa/bin/helixqa`, `http` subcommand only), YAML test banks.

**Spec:** [docs/superpowers/specs/2026-09-19-workshop-areas-practice-qa-design.md](../specs/2026-09-19-workshop-areas-practice-qa-design.md)

## Global Constraints

- Every bank uses the structured `http:` action type exclusively; every run uses `helixqa http`, never `helixqa run`.
- Every case needs a real golden-bad control where safely possible.
- The workshop server must be rebuilt and its `source_commit` confirmed equal to `workshop`'s current `HEAD` before any live verification step in any task.
- **This sub-project's cases may write server-side state** (lesson-state POSTs, assessment submissions) — confirm and document idempotency/cleanup implications, same discipline as the progress-plan sub-project.
- **After any real application-level fix, re-run the FULL gate**, not just this bank.
- Any real bug HelixQA finds triggers a full `systematic-debugging` root-cause pass and a TDD fix.
- Treat taxonomy, learning-path, and practice-deck as three distinct contract surfaces — do not flatten the three practice-deck withholding mechanisms (citation-resolvability, answer-key disclosure, D11/D12 leak suppression) into one case.
- Credentials supplied only at CLI-invocation time. workshop is a private repo; implementers commit locally, never push.
- Known HelixQA framework limitations are already investigated — `_skip` with a precise reason if needed, matching `auth-session.yaml`'s convention for a genuine cross-session case that can't be expressed in one bank case.

---

### Task 1: Write and prove `areas-practice.yaml` — taxonomy + learning-path cases

**Files:**
- Create: `submodules/qa/banks/workshop/areas-practice.yaml`

- [ ] **Step 1: Confirm the server is rebuilt and current.**

- [ ] **Step 2: Read the real handlers** for `AreasHandler`/`AreaHandler` (`areas.go`), `LessonsHandler`/`AssessmentHandler`/`AssessmentSubmitHandler` (`lessons.go`) — exact field names, status codes, the `unknown_choice`/`malformed_pid`/`area_not_found` error codes.

- [ ] **Step 3: Confirm live, current corpus state before writing cases** — which real areas are published vs held-back (query `GET /api/areas` live, cross-reference detail routes), which have completed-vs-locked assessment gates. Do not assume the 819/817 figures from the research still hold; that was a historical measurement, re-derive current state.

- [x] **Step 4: Write the TAXONOMY and LEARNING-PATH case groups** (design doc cases 1-13): published/held-back/malformed/unknown area ids, `?include=held_back` validation, unauthenticated access, locked/unlocked assessment gates, the 403-no-result-key locked-submission case, and the cross-session `unknown_choice` isolation case (investigate the framework's session-addressing limitations first per the Global Constraints — if genuinely inexpressible in one bank case, `_skip` with a precise reason and independently verify the underlying server property via direct curl in your own verification session, matching the auth-session sub-project's WK-AUTH-005 resolution).

- [ ] **Step 5: Run it against the live server, capture real output.**

- [ ] **Step 6: Golden-bad controls** for the cross-session isolation case (highest value) and the publication-asymmetry case.

- [x] **Step 7: Commit** (own file only, never pushed).

---

### Task 2: Extend `areas-practice.yaml` — practice-deck cases

**Files:**
- Modify: `submodules/qa/banks/workshop/areas-practice.yaml`

- [ ] **Step 1: Confirm the server is rebuilt and current** (Task 1's commit may have moved HEAD; check for other concurrent sub-projects' commits too).

- [ ] **Step 2: Read the real `QuestionsHandler`** (`questions.go`) and `questions_graded.go` in full — the three withholding mechanisms' exact field names (`WithholdReason` vocabulary, `answer_key_disclosure` values, `citations_withheld`).

- [ ] **Step 3: Confirm live which real areas/questions currently exhibit each of the three withholding mechanisms** — don't assume; query the practice-deck route for a real area and inspect the actual response shape.

- [x] **Step 4: Write the PRACTICE-DECK case group** (design doc cases 14-17): sessionless access confirmed live, a citation-resolvability-withheld question, an answer-key-disclosure-withheld question with `citations_withheld: true`, and a disclosed question with real citations as the contrast case. Keep these three mechanisms in three separate assertions, never conflated.

- [ ] **Step 5: Run the full bank against the live server, capture real output.**

- [ ] **Step 6: Golden-bad controls** for at least one of the three withholding mechanisms.

- [x] **Step 7: Commit.**

---

### Task 3: Wire the bank into the gate

- [ ] **Step 1: Confirm server current.**
- [ ] **Step 2: Confirm the gate's directory glob picks up the file with no script change.**
- [ ] **Step 3: Run the FULL gate live**, expect PASS with the larger case count.
- [ ] **Step 4: Commit** any script change, or state none was needed.

---

### Task 4: Triage and root-cause any real findings

- [ ] **Step 1: Collect every case that did not PASS as expected.**
- [ ] **Step 2: For each real finding, invoke `systematic-debugging`'s full Phase 1-4 process.**
- [ ] **Step 3: Fix each real finding with TDD.**
- [ ] **Step 4: Re-run the affected bank(s) AND the full gate live** after each fix.
- [ ] **Step 5: If zero real findings surfaced**, state that explicitly and precisely.
- [ ] **Step 6: Commit each fix separately**, never pushed.

---

## Completion evidence — 2026-09-24 (bookkeeping audit)

Only two step types are ticked, and only where the artifact is provable from the repositories: **Write/Create the bank** (the bank file exists and is tracked in `submodules/qa`) and **Commit** (a `submodules/qa` commit touches that bank). Every OBSERVATION step (confirm the server, read handlers, run live, capture output, golden-bad controls, wire and run the gate, triage) is deliberately left unticked: it happened in a past session and cannot be re-proven from the tree. Unticked therefore means "not provable here", not "not done".

| Task | Step | Kind | Bank | `submodules/qa` commit |
|---|---|---|---|---|
| Task 1 | Step 4 | write | `areas-practice.yaml` | 4074093 qa: HelixQA bank for workshop's areas taxonomy + learning-path surface |
| Task 1 | Step 7 | commit | `areas-practice.yaml` | 4074093 qa: HelixQA bank for workshop's areas taxonomy + learning-path surface |
| Task 2 | Step 4 | write | `areas-practice.yaml` | ca77e56 qa: extend workshop areas-practice bank with practice-deck cases (WK-PRACTICE-*) |
| Task 2 | Step 7 | commit | `areas-practice.yaml` | ca77e56 qa: extend workshop areas-practice bank with practice-deck cases (WK-PRACTICE-*) |
