# Workshop Search — Exhaustive HelixQA Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exhaustive, live-verified HelixQA test-bank coverage for workshop's search/retrieval surface (`GET /api/search`, `GET /api/suggest`, `GET /api/passages/{pid}/crossrefs`), centered on the `NewEnvelope` 6-branch decision ladder, with any real bug found root-caused and TDD-fixed before this plan is done.

**Architecture:** One `helixqa http` bank file, proven with golden-good/golden-bad pairs against the live, rebuilt workshop server, then wired into the existing `verify-helixqa-web.sh` gate's bank scope (same directory glob every prior sub-project's bank already uses).

**Tech Stack:** HelixQA (`submodules/qa/bin/helixqa`, `http` subcommand only — never `run`), YAML test banks.

**Spec:** [docs/superpowers/specs/2026-09-19-workshop-search-qa-design.md](../specs/2026-09-19-workshop-search-qa-design.md)

## Global Constraints

- Every bank uses the structured `http:` action type exclusively — never a prose `action:` string, and every run uses `helixqa http`, never `helixqa run`.
- Every case needs a real golden-bad control (invert the real code path, confirm genuine FAIL, restore, confirm PASS again) — no case ships without one, UNLESS the sandbox guardrail refuses a live restart onto the specific mutation, in which case a code-level-only verification is acceptable (matching prior sub-projects' precedent) — state this explicitly if it recurs.
- The workshop server must be rebuilt and its `source_commit` confirmed equal to `workshop`'s current `HEAD` before any live verification step in any task — re-check this at the start of each task, since earlier tasks' commits (and OTHER sub-projects' concurrent commits — see the auth-session sub-project's own cross-project lesson in its ledger) move HEAD.
- **After any real application-level fix in this sub-project, re-run the FULL `verify-helixqa-web.sh` gate, not just this bank in isolation** — a fix here could change real served content an earlier sub-project's bank pinned as a regression check, exactly as happened between the meeting-notes fix and the chapter-browsing sub-project's bank.
- Any real bug HelixQA finds triggers a full `systematic-debugging` root-cause pass (Phase 1-4) and a TDD fix — never a symptom patch.
- Credentials are supplied only at CLI-invocation time (`--admin-user`/`--admin-pass` flags), never written into any bank file.
- workshop is a private repo with its own remote; implementers commit locally, the controller pushes after task review.
- `helixqa http`'s single-slot `auth: admin` credential caching, lack of cross-step response-capture/templating, and its HTTP client's lack of a CookieJar are KNOWN, already-investigated limitations (see the auth-session sub-project's own findings) — do not re-investigate these from scratch; if a case needs a mechanism this framework structurally lacks, `_skip` it with a precise, specific reason citing the exact limitation, exactly as the auth-session bank already does for its own analogous cases.
- The `kinds=` allow-list, exact route paths, and the 6-branch `Envelope` decision ladder must be read from the REAL code (`pkg/search/envelope.go`, `internal/api/router.go`, `internal/api/search.go`) before writing any case — do not assume field/branch names from the design doc's paraphrase.

---

### Task 1: Write and prove `search.yaml`

**Files:**
- Create: `submodules/qa/banks/workshop/search.yaml`

**Interfaces:**
- Consumes: `submodules/qa/bin/helixqa` (already built), the live workshop server at `http://127.0.0.1:8087`.
- Produces: a proven bank later wired into the gate.

- [ ] **Step 1: Confirm the server is rebuilt and current**

```bash
cd $VASIC_ROOT/workshop
curl -sS http://127.0.0.1:8087/api/health | grep source_commit
git rev-parse HEAD
```
Expected: the two commit hashes match. If not, `bash scripts/build.sh && bash scripts/restart.sh` first, and re-check. Also confirm `git diff -- platform/backend/cmd/workshop-server/main.go` is clean — a prior session's research noted a temporary, unrelated golden-bad mutation was once present here from a concurrent sub-project's own test-and-revert cycle; if a similar mutation from ANOTHER concurrently-running sub-project's task is present when you start, wait or coordinate rather than testing against a known-mutated tree.

- [ ] **Step 2: Read the real search/suggest/crossrefs handlers and the Envelope decision ladder**

```bash
sed -n '1,80p' platform/backend/internal/api/router.go | grep -n "search\|suggest\|passages\|crossrefs"
```
Read `pkg/search/envelope.go`'s `NewEnvelope` function in full (the 6-branch decision ladder) and `internal/api/search.go`/`internal/api/crossrefs.go` for the real request/response shapes. Note the EXACT field names in the `Envelope` type (`status`, `q`, `legs`, `reason`, `degraded`, `corpus`, `filters`, `generation`, `took_ms`) and the array field name per endpoint (`results` for search, `suggestions` for suggest, `crossrefs` for the crossrefs route). Read the real `kinds=` allow-list (the closed vocabulary that returns 400 for an unknown name).

- [ ] **Step 3: Confirm live, real inputs for each Envelope branch — do not guess a query that "should" hit a branch**

Using an authenticated `curl` against the live server (real credentials from `specs/007-decouple-modules-auth/spec.md` FR-009 at the umbrella root), confirm BEFORE writing any case:
- A real query term/phrase that returns at least one result (branch 2, `ok`).
- A real, well-formed query guaranteed to match nothing in the current corpus (branch 6, `no_match`) — try a deliberately obscure token and confirm live it returns `no_match`, not something else.
- A real `kinds=` value that is currently valid but has zero indexed rows right now (branch 4, `kind_not_indexed`) — the research notes `kg_*` kinds may not even be valid `kinds=` values since they're excluded from `indexed_kinds` entirely; read the real allow-list from Step 2 and confirm live which kind (if any) is currently empty-but-valid. If NO such kind currently exists, say so precisely in your report and write this case as best-effort against whatever real gap you can find, or mark it `_skip` with a precise reason — do not invent a kind name that doesn't exist in the allow-list.
- A pure-punctuation query — confirm live which branch it actually lands in (the design doc flags this as unconfirmed; find out for real).

- [x] **Step 4: Write the bank**

Using the exact field names and confirmed branch-triggering inputs from Steps 2-3, write a bank with cases for:
- `WK-SEARCH-001`: a real query returns real results (branch `ok`), asserting `"status": "ok"` and at least one hit with the documented fields.
- `WK-SEARCH-002`: a real query matching nothing returns `no_match`, not `unavailable`.
- `WK-SEARCH-003`: `kinds=` filtered to a real, currently-empty-but-valid kind returns `unavailable`/`kind_not_indexed` (or is `_skip`'d with a precise reason if Step 3 found no such kind exists right now).
- `WK-SEARCH-004`: `kinds=<genuinely unknown name>` returns 400 — distinct from case 3.
- `WK-SEARCH-005`: empty `q` returns 400 `empty_query`.
- `WK-SEARCH-006`: `q` exceeding 8192 bytes returns 413.
- `WK-SEARCH-007`: an unknown query parameter returns 400.
- `WK-SEARCH-008`: `limit` out of range (below 1 or above 100) — read the real handler first to know whether this is a 400 or a silent clamp, then assert the REAL behavior, not an assumption.
- `WK-SEARCH-009`: a pure-punctuation query lands in the branch Step 3 confirmed live.
- `WK-SEARCH-010`: redaction-in-search-results at the HTTP level — a query known to match ONLY redacted content must not return that passage. This is the single most security-relevant case in this bank; find a real redacted passage's distinguishing term first (read `curriculum/redactions.jsonl` and cross-reference `curriculum/passages.jsonl` for a term that appears ONLY in a redacted row's text, confirmed live via an admin-authenticated search that the term returns zero hits despite the passage existing).
- `WK-SEARCH-011`: `GET /api/suggest` returns real suggestions for a real prefix/term.
- `WK-SEARCH-012`: `GET /api/passages/{pid}/crossrefs` for a real pid with real crossref data.
- `WK-SEARCH-013`: crossrefs to a redacted/dangling target are dropped (find a real pid with a crossref to redacted content, or state precisely if none currently exists in this corpus).
- `WK-SEARCH-014`: unauthenticated `GET /api/search` returns 401.

Follow the existing sibling banks' exact `http:`/`auth:` YAML structure (see `submodules/qa/banks/workshop/chapter-list.yaml` or `auth-session.yaml` for the established pattern).

- [ ] **Step 5: Run it against the live server, capture real output.**

```bash
cd $VASIC_ROOT/submodules/qa
./bin/helixqa http --banks banks/workshop/search.yaml --base-url http://127.0.0.1:8087 --login-path /api/auth/login --admin-user <real user> --admin-pass <real password> --verbose
```
Expected: every non-skipped case PASSes.

- [ ] **Step 6: Golden-bad controls**

For each case, especially WK-SEARCH-010 (redaction) — the highest-value target in this bank — find a real, revertible way to invert the actual code path (e.g., temporarily disable the `redacted = 0` filter or the wrapping redaction check the research names), rebuild, restart, confirm genuine FAIL (the redacted content now leaks), restore, rebuild, restart, confirm PASS again. If the sandbox guardrail refuses any specific mutation's live restart, accept a code-level-only verification for that case and say so precisely.

- [x] **Step 7: Commit**

```bash
cd $VASIC_ROOT/submodules/qa
git add banks/workshop/search.yaml
git status   # confirm ONLY your file is staged
git commit -m "qa: HelixQA bank for workshop's search/suggest/crossrefs surface

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
Do NOT push.

---

### Task 2: Wire `search.yaml` into workshop's HelixQA gate

**Files:**
- Modify: `workshop/platform/gates/verify-helixqa-web.sh` (only if needed)

- [ ] **Step 1: Confirm the server is rebuilt and current** (HEAD may have moved since Task 1's commit — check for concurrent sub-project commits too).

- [ ] **Step 2: Read the current gate script.** Confirm it already globs the whole `banks/workshop/` directory — if so, the new bank file is automatically included with zero script changes.

- [ ] **Step 3: Run the FULL gate for real** (not just this bank in isolation — per the Global Constraints' cross-sub-project lesson):

```bash
bash $VASIC_ROOT/workshop/platform/gates/verify-helixqa-web.sh
```
Expected: PASS, reporting the full, now-larger case count. If any case from an EARLIER sub-project's bank now fails because this sub-project's own work legitimately changed real served content, investigate whether the older bank's expectation is now stale (matching the auth-session sub-project's own precedent for `chapter-detail-content.yaml`'s WK-CHDETCONT-001) rather than assuming your new work is broken — but verify the ROOT CAUSE either way, don't assume.

- [ ] **Step 4: Commit** any script changes from Step 2, or the no-op statement if none were needed.

---

### Task 3: Triage and root-cause any real findings

**Files:** Determined by whatever Tasks 1-2 actually found.

- [ ] **Step 1: Collect every case that did not PASS as expected** during golden-good verification.

- [ ] **Step 2: For each real finding, invoke `systematic-debugging`'s full Phase 1-4 process.**

- [ ] **Step 3: Fix each real finding with TDD.**

- [ ] **Step 4: Re-run the affected bank(s) AND the full gate live** after each fix.

- [ ] **Step 5: If zero real findings surfaced**, state that explicitly and precisely.

- [ ] **Step 6: Commit each fix separately**, scoped to its own repository, never pushed by the implementer.

---

## Completion evidence — 2026-09-24 (bookkeeping audit)

Only two step types are ticked, and only where the artifact is provable from the repositories: **Write/Create the bank** (the bank file exists and is tracked in `submodules/qa`) and **Commit** (a `submodules/qa` commit touches that bank). Every OBSERVATION step (confirm the server, read handlers, run live, capture output, golden-bad controls, wire and run the gate, triage) is deliberately left unticked: it happened in a past session and cannot be re-proven from the tree. Unticked therefore means "not provable here", not "not done".

| Task | Step | Kind | Bank | `submodules/qa` commit |
|---|---|---|---|---|
| Task 1 | Step 4 | write | `search.yaml` | 1e2264d qa: HelixQA bank for workshop's search/suggest/crossrefs surface |
| Task 1 | Step 7 | commit | `search.yaml` | 1e2264d qa: HelixQA bank for workshop's search/suggest/crossrefs surface |
