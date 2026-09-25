# Workshop Progress & Plan — Exhaustive HelixQA Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exhaustive, live-verified HelixQA test-bank coverage for workshop's `GET/POST /api/progress` endpoint (backing both `/progress` and `/plan` frontend pages), with any real bug found root-caused and TDD-fixed before this plan is done — including a mandatory investigation of a real, currently-unguarded redaction gap this sub-project's design flags.

**Architecture:** One `helixqa http` bank file, proven with golden-good/golden-bad pairs against the live, rebuilt workshop server, then wired into `verify-helixqa-web.sh`.

**Tech Stack:** HelixQA (`submodules/qa/bin/helixqa`, `http` subcommand only), YAML test banks.

**Spec:** [docs/superpowers/specs/2026-09-19-workshop-progress-plans-qa-design.md](../specs/2026-09-19-workshop-progress-plans-qa-design.md)

## Global Constraints

- Every bank uses the structured `http:` action type exclusively; every run uses `helixqa http`, never `helixqa run`.
- Every case needs a real golden-bad control where safely possible.
- The workshop server must be rebuilt and its `source_commit` confirmed equal to `workshop`'s current `HEAD` before any live verification step in any task.
- **This is the FIRST sub-project whose bank cases genuinely WRITE server-side state** (`POST /api/progress`). Confirm and document cleanup/idempotency: does re-running this bank leave stray progress entries that could affect a later sub-project's assumptions about a "fresh" account state? State this explicitly in Task 1's report.
- **After any real application-level fix, re-run the FULL `verify-helixqa-web.sh` gate**, not just this bank in isolation.
- Any real bug HelixQA finds triggers a full `systematic-debugging` root-cause pass (Phase 1-4) and a TDD fix.
- **Priority mandatory investigation**: the design flags a real, currently-unguarded gap — `ProgressHandler` never applies the redaction/publication gate `pkg/search`/`pkg/answer`/`areas.go` all enforce. Task 3 MUST investigate whether a stored progress position can reveal since-redacted content's location, with the same rigor the T508 auth-session finding received (root cause, TDD fix if confirmed exploitable) — not merely re-stated as a note.
- Credentials supplied only at CLI-invocation time. workshop is a private repo; implementers commit locally, never push.
- Known HelixQA framework limitations (single-slot `auth: admin`, no cross-step capture, no CookieJar) are already investigated — `_skip` with a precise reason if needed.

---

### Task 1: Write and prove `progress-plan.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/progress-plan.yaml`

- [ ] **Step 1: Confirm the server is rebuilt and current.**

- [ ] **Step 2: Read the real `/api/progress` handler** (`internal/api/progress.go`) in full for exact field names (`positions`, `chapter_slug`, `pid`, `t_seconds` on POST vs `t_start_s` on GET — confirm this asymmetry is real, don't assume from the design doc), status codes (200/400/404/503), and the exact `unknown_parameter`/`malformed_pid` error codes for each validation failure.

- [ ] **Step 3: Confirm live, current account state before writing cases** — check whether `milosvasic` and `rami` currently have stored progress positions (a case asserting 404-on-fresh-account needs a genuinely empty account; if both accounts already have positions from earlier testing this session, note this and adapt the case, e.g. by using a definitely-fresh `chapter_slug` that has never been posted for either account, rather than assuming a blank slate).

- [x] **Step 4: Write the bank** with cases for: POST/GET round-trip (real field-name asymmetry asserted), overwrite-not-accumulate, malformed bodies → 400 (path-traversal chapter_slug, malformed pid, missing/negative t_seconds), `t_seconds: 0` stored as a real value, `/api/areas` requiring auth (contrast with the stale 2026-09-01 frontend comment claiming 404), cross-account isolation (milosvasic's progress never reflects rami's), unauthenticated access → 401, and one case establishing current observable behavior for a stored position referencing a since-redacted pid (feeding Task 3's investigation — read `curriculum/redactions.jsonl` for a real redacted pid to use, don't invent one).

- [ ] **Step 5: Run it against the live server, capture real output.**

- [ ] **Step 6: Golden-bad controls** — at minimum for the malformed-body validation and cross-account isolation cases.

- [x] **Step 7: Commit** (own file only, in `submodules/qa`, never pushed).

---

### Task 2: Wire `progress-plan.yaml` into the gate

- [ ] **Step 1: Confirm server current.**
- [ ] **Step 2: Confirm the gate's directory glob picks up the new file with no script change.**
- [ ] **Step 3: Run the FULL gate live**, expect PASS with the larger case count.
- [ ] **Step 4: Commit** any script change, or state none was needed.

---

### Task 3: Triage, and the mandatory redaction-gap investigation

- [ ] **Step 1: Collect every case that did not PASS as expected.**
- [ ] **Step 2: Investigate the redaction gap named in the Global Constraints, with full systematic-debugging rigor** — is a since-redacted passage's location (`chapter_slug` + `t_start_s`) genuinely retrievable via a reader's own stored `/api/progress` entry after that passage was redacted? Read `internal/redaction/plan.go`'s `Plan.Apply()` (already read once this session for the G5 fix — reuse that context) to see whether `progress.json` is among its 8 target surfaces; if not, that IS the root cause of the gap. Confirm live: store a position for a pid, redact that pid via the real redaction path, GET the position again, observe what's actually returned.
- [ ] **Step 3: If confirmed exploitable, fix with TDD** — likely either (a) redacting a pid should scrub/null any stored progress position referencing it, added to `Plan.Apply()`'s surface list, or (b) `ProgressHandler`'s GET should check the pid's live redaction status before serving. Decide which based on what `Plan.Apply()`'s existing 8-surface pattern suggests is the established convention for this codebase, don't invent a novel mechanism.
- [ ] **Step 4: For every other real finding, invoke `systematic-debugging`'s full Phase 1-4 process and fix with TDD.**
- [ ] **Step 5: Re-run the affected bank(s) AND the full gate live** after each fix.
- [ ] **Step 6: If the redaction gap investigation concludes it is NOT exploitable** (e.g., `t_start_s` alone is deemed insufficiently precise to constitute a real disclosure, or some other mitigating factor), state this conclusion explicitly with the evidence behind it — this is an acceptable outcome if genuinely investigated, not merely asserted.
- [ ] **Step 7: Commit each fix separately**, never pushed.

---

## Completion evidence — 2026-09-24 (bookkeeping audit)

Only two step types are ticked, and only where the artifact is provable from the repositories: **Write/Create the bank** (the bank file exists and is tracked in `submodules/qa`) and **Commit** (a `submodules/qa` commit touches that bank). Every OBSERVATION step (confirm the server, read handlers, run live, capture output, golden-bad controls, wire and run the gate, triage) is deliberately left unticked: it happened in a past session and cannot be re-proven from the tree. Unticked therefore means "not provable here", not "not done".

| Task | Step | Kind | Bank | `submodules/qa` commit |
|---|---|---|---|---|
| Task 1 | Step 4 | write | `progress-plan.yaml` | eb3c5b1 fix(progress-plan): update WK-PROG-010 to confirm the redaction-leak fix, not the bug |
| Task 1 | Step 7 | commit | `progress-plan.yaml` | eb3c5b1 fix(progress-plan): update WK-PROG-010 to confirm the redaction-leak fix, not the bug |
