# HelixQA Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the real `HelixDevelopment/qa` (HelixQA) framework and its `vasic-digital/challenges` dependency as submodules of the `vasic` umbrella, make it actually run web QA against `workshop` and `ai_interviewing`, wire it into each project's mandatory pre-push validation, and create a new `independent-content-review` Claude Code skill for dispatching independent reviewer subagents against model-generated content.

**Architecture:** HelixQA is consumed as a sibling-submodule Go module (`submodules/qa`, module `digital.vasic.helixqa`) alongside `submodules/challenges` (`digital.vasic.challenges`) and the already-present `submodules/containers` (`digital.vasic.containers`) — its own `go.mod` `replace` directives resolve all three as `../challenges` / `../containers` from `submodules/qa`, so all three must be siblings directly under `submodules/`. HelixQA's own Android/mobile `tools/opensource/*` nested submodules are never initialized — only `web`/`api`-platform test banks are written. A new gate script per project (`workshop/platform/gates/verify-helixqa-web.sh`, `ai_interviewing/platform/backend/gates/verify-helixqa-web.sh`) invokes the built `helixqa` CLI against each project's live, loopback-bound server and is wired into that project's existing verification aggregator.

**Tech Stack:** Go 1.26 (matches `submodules/qa`'s `go.mod`; this host already has it — used for `submodules/containers`), YAML test banks (HelixQA's native format), bash gate scripts (matching each project's existing convention), a new Markdown-frontmatter Claude Code skill.

**Spec:** [`docs/superpowers/specs/2026-09-18-helixqa-integration-design.md`](../specs/2026-09-18-helixqa-integration-design.md)

**Note on paths:** every command below uses `$VASIC_ROOT` for the umbrella
repo's own root — set it once per shell before starting, e.g.
`VASIC_ROOT="$(git rev-parse --show-toplevel)"` run from anywhere inside this
checkout. No path in this plan is a specific developer's home directory —
that would not survive a different clone location (this is a public repo;
`scripts/audit-hardcoded-paths.sh` enforces exactly this).

## Global Constraints

- No `tools/opensource/*` nested submodule of `submodules/qa` is ever initialized (`git submodule update --init` targets only `submodules/qa` and `submodules/challenges` themselves).
- `submodules/containers` is NOT re-added or duplicated — it already exists at the umbrella root and already satisfies HelixQA's `digital.vasic.containers` dependency (confirmed: `submodules/containers/go.mod` declares `module digital.vasic.containers`).
- Every new gate script follows its OWN project's existing exit-code contract exactly: `workshop`'s gates are three-valued (0 clean · 1 real defect · 2 could not determine, per every existing `platform/gates/verify-*.sh`); `ai_interviewing`'s existing gates (`platform/backend/gates/verify-g-live-*.sh`, `verify-g-rbac-*.sh`) do not currently declare a paired `prove-*.sh` mutation script, so the new gate there follows that lighter, already-established local convention rather than importing workshop's heavier one uninvited.
- Every YAML test bank uses HelixQA's real, measured schema: `version: "1.0"`, `name`, `description`, `metadata: {author, app, version}`, `test_cases: [{id, name, category, priority, platforms, steps: [{name, action, expected}], tags, estimated_duration, expected_result}]` — copied from `submodules/qa/banks/security-validation.yaml`'s real structure, not invented.
- Neither `workshop` nor `ai_interviewing` is bound to the LAN during this work — `workshop` stays loopback-only per the operator's 2026-09-18 decision (open `verify-suppressed-residue.sh` G5 finding); all HelixQA runs target `http://127.0.0.1:<port>`.
- No commit in this plan touches `vasic.digital`/`milosvasic.ru`'s existing `_tests/helixqa/` Challenge-bank setup — out of scope per the spec.

---

### Task 1: Add `submodules/qa` and `submodules/challenges` as gitlinks

**Files:**
- Create (via `git submodule add`): `.gitmodules` entries for `submodules/qa` and `submodules/challenges`
- Modify: `$VASIC_ROOT/helix-deps.yaml`

**Interfaces:**
- Produces: `submodules/qa` (checked out at `HelixDevelopment/qa`'s current `main` HEAD) and `submodules/challenges` (checked out at `vasic-digital/challenges`'s current `main` HEAD), both siblings of the existing `submodules/containers`, all three directly under `submodules/`.

- [ ] **Step 1: Add the two submodules**

```bash
cd $VASIC_ROOT
git submodule add git@github.com:HelixDevelopment/qa.git submodules/qa
git submodule add git@github.com:vasic-digital/challenges.git submodules/challenges
```

- [ ] **Step 2: Confirm neither pulled in nested submodules**

```bash
git -C submodules/qa submodule status 2>&1 | head -5
```

Expected: every listed nested submodule (the `tools/opensource/*` list) shows a leading `-` (not initialized). `git submodule add` alone never recurses into nested submodules — this step only confirms that, it does not need to change anything.

- [ ] **Step 3: Record real refs in `helix-deps.yaml`**

Read the current `ref` of each newly added submodule first:

```bash
git -C submodules/qa rev-parse HEAD
git -C submodules/challenges rev-parse HEAD
```

Find the existing `submodules/containers` entry in `helix-deps.yaml` (`grep -n 'name: containers' helix-deps.yaml`) to match its exact YAML shape, then add two new entries immediately after it, using the SSH URLs and the real `HEAD` values just read:

```yaml
  - name: qa
    ssh_url: git@github.com:HelixDevelopment/qa.git
    ref: "<real HEAD from Step 3>"
    why: "HelixQA — the anti-bluff QA orchestration framework Helix Constitution §11.4.160/§11.4.27 mandates every governed project run generated/served content through. Provides YAML test banks, cross-platform (incl. web, via Playwright) execution, LLM-powered issue detection, evidence collection, and an autonomous vision-verification QA session mode. Added 2026-09-18 per docs/superpowers/specs/2026-09-18-helixqa-integration-design.md — no helixqa submodule existed in this umbrella before this, despite the constitutional mandate. Its own go.mod declares `replace digital.vasic.challenges => ../challenges` and `replace digital.vasic.containers => ../containers`, so it MUST be checked out as a sibling of both submodules/challenges and submodules/containers, never nested. Its own tools/opensource/* nested submodules (scrcpy, appium, docker-android, leakcanary, etc. — Android/mobile device tooling) are deliberately NOT initialized: neither workshop nor ai_interviewing is a mobile app, and pulling that tree in would be a large, irrelevant dependency footprint for pure web QA."
    layout: grouped

  - name: challenges
    ssh_url: git@github.com:vasic-digital/challenges.git
    ref: "<real HEAD from Step 3>"
    why: "digital.vasic.challenges — the test-execution/reporting foundation HelixQA (submodules/qa) is built on, per its own go.mod replace directive. Added alongside submodules/qa 2026-09-18 for the same reason; not independently consumed by anything else in this umbrella yet."
    layout: grouped
```

- [ ] **Step 4: Verify manifest pins and governance cascade**

```bash
bash scripts/verify-manifest-pins.sh
bash scripts/verify-governance-cascade.sh
```

Expected: `verify-manifest-pins.sh` reports `N MATCH, 0 DRIFT, 0 UNDETERMINED` where N is now 15 (13 previous + qa + challenges). `verify-governance-cascade.sh` C1 now classifies 13 owned submodules (was 11); if C2/C3 fail because `qa`/`challenges` lack the 4-carrier (CLAUDE.md/AGENTS.md/QWEN.md/GEMINI.md) pointer-inheritance setup this umbrella's OTHER owned submodules have, that is a REAL, separate gap to fix in Step 5 below — do not skip it or explain it away.

- [ ] **Step 5: If C2/C3 fail for the new submodules, this is a real defect — fix it**

Read one existing owned submodule's carrier files for the pattern (e.g. `cat submodules/containers/CLAUDE.md | head -40`), and check whether `submodules/qa` and `submodules/challenges` already carry their own `CLAUDE.md`/`AGENTS.md`/`QWEN.md`/`GEMINI.md` (likely yes, since they are themselves real, governed projects — check `ls submodules/qa/*.md` first). If they already have compliant pointer-inheritance carriers, C2/C3 should pass without any edit; do not add carriers to a submodule this project does not own. If the cascade genuinely fails, capture the exact failing check's output and stop — this is new information the plan did not anticipate, and needs a decision before continuing (do not silently work around it).

- [ ] **Step 6: Run the hardcoded-paths audit**

```bash
bash scripts/audit-hardcoded-paths.sh
```

Expected: exit 0, no new findings beyond the existing baselined ones.

- [ ] **Step 7: Commit**

```bash
git add .gitmodules submodules/qa submodules/challenges helix-deps.yaml
git commit -m "$(cat <<'EOF'
add HelixDevelopment/qa and vasic-digital/challenges submodules

Per docs/superpowers/specs/2026-09-18-helixqa-integration-design.md.
Neither Android/mobile tools/opensource/* nested submodule is
initialized — pure web QA for workshop/ai_interviewing does not need
them. submodules/containers already satisfies HelixQA's
digital.vasic.containers dependency; not duplicated.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

Do NOT push yet — Task 2 needs the binary built before the pre-push Playwright gate is worth running again.

---

### Task 2: Build the `helixqa` binary and confirm it runs

**Files:**
- Read: `submodules/qa/Makefile`, `submodules/qa/go.work`
- No new files.

**Interfaces:**
- Produces: `submodules/qa/bin/helixqa`, an executable CLI usable by every later task (`helixqa run`, `helixqa list`, `helixqa report`, `helixqa version`).

- [ ] **Step 1: Confirm the Go toolchain resolves the workspace**

```bash
cd $VASIC_ROOT/submodules/qa
go version
cat go.work
```

Expected: Go reports 1.26.x or later (matches `go 1.26` in `submodules/qa/go.mod`, confirmed already present on this host from earlier `submodules/containers` work). `go.work` should read `go 1.26` / `use .` — if it lists additional `use` directives for `../challenges`/`../containers` that do not exist relative to `submodules/qa`, that is a real build-blocking finding to report, not silently patch.

- [ ] **Step 2: Build**

```bash
cd $VASIC_ROOT/submodules/qa
make build
```

Expected: exits 0, produces `bin/helixqa`. If `make build` fails on a missing `../challenges` or `../containers` resolution (the `go.mod replace` paths), verify Task 1 actually placed both as direct siblings under `submodules/` (`ls -d $VASIC_ROOT/submodules/{qa,challenges,containers}`) before trying anything else — this is the most likely failure mode and Task 1's own layout is the fix, not a code change here.

- [ ] **Step 3: Confirm the binary runs**

```bash
./bin/helixqa version
```

Expected: prints a real version string, exit 0. Capture the exact output in the task's completion note — this is the deterministic evidence this task is done, not an assumption.

- [ ] **Step 4: Commit (only if Step 1's `go.work` needed a fix; otherwise nothing to commit)**

If `go.work` required no change, there is nothing new to commit for this task — say so explicitly rather than committing a no-op. If it did need a fix:

```bash
git add submodules/qa
git commit -m "fix(qa): go.work workspace resolution for sibling submodule layout

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Write and prove a real web test bank for `workshop`

**Files:**
- Create: `submodules/qa/banks/workshop/spa-routing.yaml`

**Interfaces:**
- Consumes: `helixqa` binary from Task 2 (`submodules/qa/bin/helixqa`); the live workshop server at `http://127.0.0.1:8087` (already running per this session — confirm with `curl -sS http://127.0.0.1:8087/api/health`, and if it is not running, `cd $VASIC_ROOT/workshop && bash scripts/restart.sh` first, loopback-only, no `WORKSHOP_HTTP_BIND` override).
- Produces: a bank file later tasks (Task 5) point the gate script at.

- [ ] **Step 1: Write the bank, encoding the already-fixed dotted-slug regression as a golden-good check**

```yaml
# SPDX-FileCopyrightText: 2026 Milos Vasic
# SPDX-License-Identifier: Apache-2.0
#
# HelixQA Test Bank: Workshop Curriculum — SPA routing
# Pins the 2026-09-17 fix for webHandler's dotted-client-route 404 bug
# (path.Ext("/chapters/02.02") was misread as a file extension) against
# silent regression.

version: "1.0"
name: "Workshop Curriculum SPA Routing"
description: "Direct-navigation routing checks for the Angular SPA fallback, including dotted chapter slugs"
metadata:
  author: "vasic-digital"
  app: "workshop"
  version: "1.0.0"

test_cases:
  - id: WK-ROUTE-001
    name: "Direct navigation to a dotted chapter slug reaches the SPA, not a 404"
    category: functional
    priority: critical
    platforms: [web]
    steps:
      - name: "GET /chapters/02.02 directly (no prior client-side navigation)"
        action: "HTTP GET http://127.0.0.1:8087/chapters/02.02"
        expected: "200 OK, HTML body, not the raw '404 page not found' text"
      - name: "GET /chapters/02.01 directly"
        action: "HTTP GET http://127.0.0.1:8087/chapters/02.01"
        expected: "200 OK, HTML body"
    tags: [routing, spa, regression, dotted-slug]
    estimated_duration: "5s"
    expected_result: "Both dotted chapter slugs resolve to the Angular app on a fresh page load"

  - id: WK-ROUTE-002
    name: "A genuinely missing static asset still 404s"
    category: functional
    priority: high
    platforms: [web]
    steps:
      - name: "GET a nonexistent hashed asset"
        action: "HTTP GET http://127.0.0.1:8087/main-ZZZZZZZZ.js"
        expected: "404 Not Found"
    tags: [routing, spa, regression, negative-control]
    estimated_duration: "5s"
    expected_result: "The SPA fallback does not swallow every 404 — a real missing asset still 404s"
```

- [ ] **Step 2: List the bank to confirm HelixQA parses it**

```bash
cd $VASIC_ROOT/submodules/qa
./bin/helixqa list --banks banks/workshop/
```

Expected: exits 0, lists `WK-ROUTE-001` and `WK-ROUTE-002`.

- [ ] **Step 3: Run it against the live server and confirm PASS**

```bash
./bin/helixqa run --banks banks/workshop/ --platform web
```

Expected: both cases PASS. Capture the actual output.

- [ ] **Step 4: Prove the bank actually bites — golden-bad control**

```bash
cd $VASIC_ROOT/workshop
FIX_COMMIT="$(git log --format=%H --all -- platform/backend/cmd/workshop-server/main.go \
    | xargs -I{} sh -c 'git show {}:platform/backend/cmd/workshop-server/main.go 2>/dev/null | grep -q looksLikeAssetExtension && echo {}' \
    | tail -1)"
echo "FIX_COMMIT=$FIX_COMMIT"
git show "${FIX_COMMIT}^..${FIX_COMMIT}" -- platform/backend/cmd/workshop-server/main.go | head -30
```

`FIX_COMMIT` now holds the real commit that introduced `looksLikeAssetExtension`. Temporarily check out the PRE-fix version of `main.go`, rebuild, restart workshop against it, re-run the bank, and confirm `WK-ROUTE-001` now FAILS (`WK-ROUTE-002` should still pass, since that fix did not change genuine-404 behavior). Then restore the real, fixed `main.go`, rebuild, and restart:

```bash
cd $VASIC_ROOT/workshop
git status --short  # confirm clean before mutating — should be nothing pending
git checkout "${FIX_COMMIT}^" -- platform/backend/cmd/workshop-server/main.go
bash scripts/build.sh
bash scripts/restart.sh
cd $VASIC_ROOT/submodules/qa
./bin/helixqa run --banks banks/workshop/ --platform web
# Expected: WK-ROUTE-001 FAILS, WK-ROUTE-002 still PASSES
cd $VASIC_ROOT/workshop
git checkout HEAD -- platform/backend/cmd/workshop-server/main.go
bash scripts/build.sh
bash scripts/restart.sh
cd $VASIC_ROOT/submodules/qa
./bin/helixqa run --banks banks/workshop/ --platform web
# Expected: both PASS again
```

- [ ] **Step 5: Commit**

```bash
cd $VASIC_ROOT
git add submodules/qa
git commit -m "$(cat <<'EOF'
qa: real HelixQA web test bank for workshop's SPA routing

Encodes the 2026-09-17 dotted-chapter-slug 404 fix as a regression
check, proven live against both the fixed and the pre-fix binary
(golden-good/golden-bad, per HelixQA's own anti-bluff convention).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

Note: this commits INSIDE `submodules/qa` (a gitlink bump for the umbrella is a separate, later step once all banks/gates in this plan are done — see Task 7).

---

### Task 4: Write and prove a real web test bank for `ai_interviewing`

**Files:**
- Create: `submodules/qa/banks/ai_interviewing/rbac.yaml`

**Interfaces:**
- Consumes: `helixqa` binary from Task 2; the live `ai_interviewing` server at `http://127.0.0.1:8099` (confirm with `curl -sS http://127.0.0.1:8099/api/health`; if not running, `cd $VASIC_ROOT/ai_interviewing && bash platform/scripts/restart.sh`). Requires the seeded `rami`/user-role credential from `specs/007-decouple-modules-auth/spec.md` and a valid session cookie obtained via `POST /api/auth/login` — HelixQA's `action`/`expected` steps describe the HTTP exchange; if HelixQA's own executor cannot itself perform a stateful login-then-request sequence from a YAML step list (check `ARCHITECTURE.md`'s `pkg/navigator` docs for what its web executor actually supports before assuming), fall back to a two-step bank (login step asserts 200 + Set-Cookie, second step is a manual curl-style HTTP assertion) and record precisely which form HelixQA's real executor required — do not guess ahead of reading its own navigator code.

- [ ] **Step 1: Read `submodules/qa/pkg/navigator`'s web executor before writing steps that assume a capability it may not have**

```bash
cd $VASIC_ROOT/submodules/qa
grep -rn "func.*Execute\|type.*Executor" pkg/navigator/*.go | head -20
```

Note exactly what an `action` string can describe for the `web` platform (a bare HTTP request? a Playwright page action? both?) before writing Step 2.

- [ ] **Step 2: Write the bank**

Using whatever step shape Step 1 established as real (adjust the `action`/`expected` wording to match, but keep the `id`/structure below):

```yaml
# SPDX-FileCopyrightText: 2026 Milos Vasic
# SPDX-License-Identifier: Apache-2.0
#
# HelixQA Test Bank: AI Interviewing — RBAC
# Pins the 2026-09-17 fix for a 403 (permission denied) being shown as a
# generic backend outage, with a Retry button that could only ever 403
# again.

version: "1.0"
name: "AI Interviewing RBAC"
description: "Role-based access checks — a permission denial must never be reported as a connectivity failure"
metadata:
  author: "vasic-digital"
  app: "ai_interviewing"
  version: "1.0.0"

test_cases:
  - id: AI-RBAC-001
    name: "A user-role visitor sees a permission-denied message for an admin-only module, not an outage message"
    category: security
    priority: critical
    platforms: [web]
    steps:
      - name: "Log in as the seeded user-role account"
        action: "POST /api/auth/login as rami (see specs/007-decouple-modules-auth/spec.md)"
        expected: "200 OK, session cookie set"
      - name: "Request an admin-only module page while logged in as rami"
        action: "GET /module/41 with the rami session"
        expected: "Page renders \"You don't have permission to view this module\", contains no \"could not be reached\" text, and shows no Retry button"
    tags: [security, rbac, regression, permission-denied]
    estimated_duration: "10s"
    expected_result: "A 403 is reported as a permission denial, never as a connectivity fault"
```

- [ ] **Step 3: List and run**

```bash
cd $VASIC_ROOT/submodules/qa
./bin/helixqa list --banks banks/ai_interviewing/
./bin/helixqa run --banks banks/ai_interviewing/ --platform web
```

Expected: `AI-RBAC-001` PASSes against the current, fixed code.

- [ ] **Step 4: Golden-bad control**

Same pattern as Task 3 Step 4: find this session's commit fixing the 403-as-outage bug in `ai_interviewing` (`git -C $VASIC_ROOT/ai_interviewing log --oneline | grep -i "forbidden\|403"`), temporarily check out `module.component.ts` and `load-status.ts` from the parent of that commit, rebuild (`cd $VASIC_ROOT/ai_interviewing && bash platform/scripts/build.sh`), restart, re-run the bank (expect FAIL), then restore and confirm PASS again.

- [ ] **Step 5: Commit**

```bash
cd $VASIC_ROOT
git add submodules/qa
git commit -m "$(cat <<'EOF'
qa: real HelixQA web test bank for ai_interviewing's RBAC

Encodes the 2026-09-17 403-as-outage fix as a regression check, proven
live against both the fixed and the pre-fix code.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Wire HelixQA into `workshop`'s mandatory validation path

**Files:**
- Create: `workshop/platform/gates/verify-helixqa-web.sh`
- Create: `workshop/platform/gates/prove-helixqa-web.sh`
- Modify: `workshop/scripts/verify.sh` (workshop's own gate aggregator — confirm the exact registration mechanism by reading how an existing gate like `verify-server-unity.sh` is invoked from it before writing this)

**Interfaces:**
- Consumes: `submodules/qa/bin/helixqa` (built in Task 2) and `submodules/qa/banks/workshop/` (written in Task 3) — both live OUTSIDE the `workshop` git repository, at `$VASIC_ROOT/submodules/qa`. The gate script must locate them via a path relative to the umbrella root, not assume a fixed absolute path (mirror how `workshop`'s existing scripts resolve `WORKSHOP_HOME`/`PLATFORM_HOME` via `BASH_SOURCE`-relative `cd`, per this module's own established convention — read `workshop/scripts/_common.sh`'s header for the exact pattern before writing this).

- [ ] **Step 1: Read `workshop/scripts/verify.sh` to learn the registration pattern**

```bash
grep -n "verify-server-unity\|run_gate\|GATES" $VASIC_ROOT/workshop/scripts/verify.sh | head -20
```

- [ ] **Step 2: Write the gate script**

```bash
#!/usr/bin/env bash
# verify-helixqa-web.sh — runs the real HelixQA web test bank against the
# live workshop server. Three-valued exit (0 clean · 1 real defect ·
# 2 could not determine), matching every other gate in this directory.
#
# HelixQA itself lives OUTSIDE this repository, as a sibling submodule of
# the umbrella this module is checked out inside
# (submodules/qa relative to the umbrella root, NOT to workshop/). Found via
# a parent-walk from this script's own path, the same technique
# find_constitution.sh uses, so this gate degrades to UNDETERMINED rather
# than guessing when workshop is checked out somewhere this relationship
# does not hold (e.g. a standalone clone with no umbrella parent).
set -uo pipefail

GATES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_HOME="$(cd -- "$GATES_DIR/../.." && pwd)"
UMBRELLA_HOME="$(cd -- "$WORKSHOP_HOME/.." && pwd)"
HELIXQA_BIN="$UMBRELLA_HOME/submodules/qa/bin/helixqa"
BANKS_DIR="$UMBRELLA_HOME/submodules/qa/banks/workshop"

echo "== verify-helixqa-web =="

if [ ! -x "$HELIXQA_BIN" ]; then
    echo "UNDETERMINED: helixqa binary not found or not executable at $HELIXQA_BIN"
    echo "  (this workshop checkout has no umbrella sibling submodules/qa, or it is not built — run 'make build' inside it)"
    exit 2
fi

if [ ! -d "$BANKS_DIR" ]; then
    echo "UNDETERMINED: no test banks found at $BANKS_DIR"
    exit 2
fi

if ! curl -fsS -o /dev/null --max-time 5 "http://127.0.0.1:8087/api/health"; then
    echo "UNDETERMINED: workshop is not answering on http://127.0.0.1:8087 — start it first (scripts/restart.sh)"
    exit 2
fi

set +e
OUT="$("$HELIXQA_BIN" run --banks "$BANKS_DIR" --platform web 2>&1)"
RC=$?
set -e

echo "$OUT"

if [ "$RC" -eq 0 ]; then
    echo "PASS: all HelixQA web checks passed against the live workshop server"
    exit 0
fi

echo "FAIL: HelixQA reported a real finding against the live workshop server"
exit 1
```

- [ ] **Step 3: Write the paired mutation proof, per workshop's own §1.1 convention**

Model this on an existing pair — read `workshop/platform/gates/prove-status-exit-contract.sh`'s structure (already read this session) for the exact shape (seed a mutation, confirm the gate catches it, restore, confirm clean). The mutation here: temporarily revert the `looksLikeAssetExtension` fix (same commit identified in Task 3 Step 4) and confirm `verify-helixqa-web.sh` exits 1, not 0 or 2.

```bash
#!/usr/bin/env bash
# prove-helixqa-web.sh — paired mutation proof for verify-helixqa-web.sh.
# Seeds the pre-2026-09-17 dotted-slug routing defect, confirms the gate
# catches it (exit 1, not silently 0 or a masking 2), then restores.
set -uo pipefail

GATES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_HOME="$(cd -- "$GATES_DIR/../.." && pwd)"
MAIN_GO="$WORKSHOP_HOME/platform/backend/cmd/workshop-server/main.go"

# Resolves itself, rather than hardcoding a hash that would silently go
# stale the next time main.go's history is rewritten (it never is in this
# tree, but a self-resolving value is strictly safer than a copy-pasted
# one) — the exact commit that introduced looksLikeAssetExtension.
FIX_COMMIT="$(git -C "$WORKSHOP_HOME" log --format=%H --all -- "$MAIN_GO" \
    | xargs -I{} sh -c 'git -C "$0" show {}:platform/backend/cmd/workshop-server/main.go 2>/dev/null | grep -q looksLikeAssetExtension && echo {}' "$WORKSHOP_HOME" \
    | tail -1)"
if [ -z "$FIX_COMMIT" ]; then
    echo "UNDETERMINED: could not resolve the commit that introduced looksLikeAssetExtension"
    exit 2
fi

echo "== prove-helixqa-web =="

cd "$WORKSHOP_HOME"
if ! git diff --quiet -- "$MAIN_GO"; then
    echo "PROBLEM: $MAIN_GO has uncommitted changes; refusing to seed a mutation over them"
    exit 1
fi

git checkout "${FIX_COMMIT}^" -- "$MAIN_GO"
bash scripts/build.sh >/dev/null 2>&1
bash scripts/restart.sh >/dev/null 2>&1

set +e
bash "$GATES_DIR/verify-helixqa-web.sh" >/tmp/prove-helixqa-web.out 2>&1
MUTATED_RC=$?
set -e

git checkout HEAD -- "$MAIN_GO"
bash scripts/build.sh >/dev/null 2>&1
bash scripts/restart.sh >/dev/null 2>&1

if [ "$MUTATED_RC" -eq 1 ]; then
    echo "CAUGHT: the mutation was correctly reported as a real defect (rc=1)"
    exit 0
fi

echo "MISSED: the mutation was NOT caught — gate returned rc=$MUTATED_RC instead of 1"
cat /tmp/prove-helixqa-web.out
exit 1
```

Fill in `FIX_COMMIT` with the real hash before running.

- [ ] **Step 4: Run the proof**

```bash
chmod +x $VASIC_ROOT/workshop/platform/gates/verify-helixqa-web.sh
chmod +x $VASIC_ROOT/workshop/platform/gates/prove-helixqa-web.sh
bash $VASIC_ROOT/workshop/platform/gates/prove-helixqa-web.sh
```

Expected: `CAUGHT`, exit 0. If `MISSED`, do not proceed to Step 5 — the gate itself needs fixing first (this is the systematic-debugging discipline: a mutation proof that doesn't catch its own mutation means the gate under test is not actually testing what it claims to).

- [ ] **Step 5: Register in `verify.sh` per the pattern read in Step 1, and run the full aggregator**

```bash
cd $VASIC_ROOT/workshop
bash scripts/verify.sh
```

Expected: the new gate appears in the aggregator's own output and its result is folded into the overall verdict correctly (a real finding here should make `verify.sh`'s own exit non-zero, not be silently absorbed).

- [ ] **Step 6: Commit**

```bash
cd $VASIC_ROOT/workshop
git add platform/gates/verify-helixqa-web.sh platform/gates/prove-helixqa-web.sh scripts/verify.sh
git commit -m "$(cat <<'EOF'
gates: wire HelixQA web checks into mandatory validation

New verify-helixqa-web.sh runs the real HelixQA banks
(../../submodules/qa relative to the umbrella root) against the live,
loopback-bound server. Paired mutation proof confirms it actually
catches a real regression (the 2026-09-17 dotted-slug routing defect),
not just that it runs.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

Then independently verify: `LOCAL=$(git rev-parse main); REMOTE=$(git ls-remote origin refs/heads/main | cut -f1); [ "$LOCAL" = "$REMOTE" ] && echo MATCH || echo MISMATCH`.

---

### Task 6: Wire HelixQA into `ai_interviewing`'s mandatory validation path

**Files:**
- Create: `ai_interviewing/platform/backend/gates/verify-helixqa-web.sh`

**Interfaces:**
- Consumes: same `submodules/qa/bin/helixqa` and `submodules/qa/banks/ai_interviewing/` from Tasks 2 and 4.
- Follows `ai_interviewing`'s own lighter gate convention (no paired `prove-*.sh` — confirmed absent from its existing `platform/backend/gates/` in Task investigation; do not invent one unprompted, per this plan's Global Constraints).

- [ ] **Step 1: Read one existing `ai_interviewing` gate for its exact conventions**

```bash
cat $VASIC_ROOT/ai_interviewing/platform/backend/gates/verify-g-rbac-1-ai-interviewing.sh | head -40
```

Note its exit-code contract and how it locates the live server, and match both exactly.

- [ ] **Step 2: Write the gate**, following the same UNDETERMINED-first structure as Task 5 Step 2 but adapted to `ai_interviewing`'s own conventions read in Step 1, targeting `http://127.0.0.1:8099` and `submodules/qa/banks/ai_interviewing/`.

- [ ] **Step 3: Run it directly and confirm it passes against the current, fixed code**

```bash
bash $VASIC_ROOT/ai_interviewing/platform/backend/gates/verify-helixqa-web.sh
```

- [ ] **Step 4: Find and run whatever aggregates `ai_interviewing`'s own gates (if one exists — check for a `Makefile` target or a `scripts/verify.sh` equivalent; if none exists, this gate is registered by being present in `platform/backend/gates/` alone, matching the existing siblings' own discoverability — do not invent a new aggregator this project has never had)**

```bash
find $VASIC_ROOT/ai_interviewing -maxdepth 2 -iname 'verify*.sh' -not -path '*/gates/*'
grep -rn "gates/verify" $VASIC_ROOT/ai_interviewing/Makefile 2>/dev/null
```

- [ ] **Step 5: Commit**

```bash
cd $VASIC_ROOT/ai_interviewing
git add platform/backend/gates/verify-helixqa-web.sh
git commit -m "$(cat <<'EOF'
gates: wire HelixQA web checks into validation

New verify-helixqa-web.sh runs the real HelixQA RBAC bank
(../../../submodules/qa relative to the umbrella root) against the
live server, following this project's existing gate conventions.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

Independently verify the push the same way as Task 5 Step 6.

---

### Task 7: Create the `independent-content-review` skill

**Files:**
- Create: `$VASIC_ROOT/.claude/skills/independent-content-review/SKILL.md`

**Interfaces:**
- Produces: a user-invocable and model-invocable Claude Code skill. Its output contract: a JSON verdict file HelixQA's evidence conventions can read (mirrors HelixQA's own `pkg/evidence`/`pkg/ticket` shape — reviewer identity, content reference, verdict, reason).

- [ ] **Step 1: Write the skill file**

```markdown
---
name: "independent-content-review"
description: "Dispatch an independent, specialized reviewer subagent against a piece of model-generated content (a curriculum section, an area write-up, an autonomously-generated QA ticket, etc.) and record a verdict evidence file HelixQA's conventions can verify."
argument-hint: "<path to the generated content> [dimension: accuracy|tone|redaction-safety|accessibility|general]"
metadata:
  author: "vasic-digital"
user-invocable: true
disable-model-invocation: false
---

## What this skill does

Content a model generated is not "done" until an INDEPENDENT reviewer —
a fresh agent with no memory of producing it — has read it and issued a
verdict. This skill is that dispatch step. It does not itself judge
content; it hands the judging to a fresh subagent scoped to one
specific quality dimension, and it writes that subagent's verdict to a
file shaped so HelixQA (or any later automated check) can verify a
review actually happened and actually reached a decision — not merely
that some text got appended near the content.

## When to use this

Invoke after generating or substantially rewriting any content meant
to be served to a real reader: a curriculum area write-up, a
transcript-derived summary, an autonomously-generated QA ticket
(HelixQA's own `pkg/ticket` output), or similar. Do NOT invoke for a
one-line copy-edit or for content a human wrote directly — this exists
for MODEL-GENERATED content specifically.

## Process

1. **Identify the review dimension.** If the caller did not specify
   one via `$ARGUMENTS`, infer it from the content: a curriculum
   section needs `accuracy` (does it correctly represent its source
   material) and `tone` (is it written the way this project's other
   published content is); anything touching `chapters/`/`curriculum/`
   private source material needs `redaction-safety` (does it leak
   anything a redaction rule should have withheld — this is NOT
   optional given this session's own open `verify-suppressed-residue.sh`
   G5 finding); a generated QA ticket or report needs `accuracy`
   (are its claims actually backed by the evidence it cites).

2. **Dispatch ONE fresh subagent per dimension**, never the
   conversation that produced the content. Use the `Agent` tool with a
   subagent type that has NOT seen the content-generation conversation
   (a fresh `general-purpose` agent, not a `fork`, since a fork
   inherits the generating conversation's context and is therefore NOT
   independent for this purpose). Give the reviewer:
   - The exact file path(s) to review.
   - The ONE dimension it is scoped to (do not ask for a vague "look
     this over" pass — a reviewer told to check everything checks
     nothing in particular).
   - The specific standard for that dimension (for `redaction-safety`:
     the project's own content-boundary rules; for `accuracy`: the
     specific source material to cross-check against; for `tone`:
     2-3 examples of already-published content in the same voice).
   - An explicit instruction to return ONE of exactly three verdicts —
     `pass`, `fail`, or `needs-revision` — each with a one-paragraph
     reason. A reviewer that hedges without picking one of the three
     has not finished its job; ask it to commit to one.

3. **Write the verdict file.** For content at `<path>`, write
   `<path>.review.json` (sibling file, same directory) with this exact
   shape:

   ```json
   {
     "content_path": "<path, relative to the repo root>",
     "content_sha256": "<sha256 of the reviewed file's bytes at review time>",
     "dimension": "accuracy|tone|redaction-safety|accessibility|general",
     "reviewer": "independent-subagent",
     "reviewed_at": "<ISO 8601 UTC timestamp>",
     "verdict": "pass|fail|needs-revision",
     "reason": "<the reviewer's own one-paragraph reason, verbatim>"
   }
   ```

   Compute `content_sha256` yourself (`sha256sum <path>`) at write time
   — this is what lets a later check detect that the content changed
   AFTER being reviewed and the verdict file is now stale.

4. **On `fail` or `needs-revision`:** do not silently accept the
   content as done. Surface the reviewer's reason to whoever is
   driving this skill (the calling conversation), and do not treat a
   `needs-revision` verdict as equivalent to `pass` — content is not
   ready until a review file records `pass` for every dimension it
   needed.

5. **Multiple dimensions:** if content needs more than one dimension
   reviewed, dispatch one subagent PER dimension (in parallel is fine
   — they are independent of each other, not just of the generator),
   and write one verdict file per dimension:
   `<path>.review.<dimension>.json`.

## What this skill deliberately does NOT do

- It does not itself write or edit the content under review.
- It does not decide what "independent" means on your behalf beyond
  "not the generating conversation, not a fork of it" — if the calling
  context is unsure whether a given agent counts as independent for a
  specific case, that is a judgment call for the calling agent to make
  explicitly, not something this skill silently assumes.
- It is not HelixQA — it does not run test banks, does not orchestrate
  cross-platform QA, and does not replace `submodules/qa`. It produces
  evidence files a HelixQA-driven or other automated check can consume;
  it is not itself that check.
```

- [ ] **Step 2: Confirm the skill is discoverable**

```bash
ls $VASIC_ROOT/.claude/skills/independent-content-review/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
cd $VASIC_ROOT
git add .claude/skills/independent-content-review/SKILL.md
git commit -m "$(cat <<'EOF'
skills: add independent-content-review

Dispatches a fresh, independent reviewer subagent (never the
generating conversation) per content-quality dimension, and writes a
verdict evidence file (pass|fail|needs-revision + sha256 + reason)
that HelixQA or any later automated check can verify actually
happened. Per docs/superpowers/specs/2026-09-18-helixqa-integration-design.md.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

Independently verify the push.

---

### Task 8: Bump the umbrella's submodule pins and final verification

**Files:**
- Modify: `$VASIC_ROOT/helix-deps.yaml`

**Interfaces:**
- Consumes: the final commit SHAs of `submodules/qa` (after Tasks 3 and 5's commits inside it) and `workshop`/`ai_interviewing` (after Tasks 5 and 6's commits inside them).

- [ ] **Step 1: Stage every moved gitlink together with the manifest**

```bash
cd $VASIC_ROOT
git add submodules/qa submodules/challenges workshop ai_interviewing
```

- [ ] **Step 2: Update `helix-deps.yaml`'s `ref` for `qa`, `workshop`, and `ai_interviewing`** to their new real HEADs (`git -C submodules/qa rev-parse HEAD`, etc.), following the same "prior entry, preserved" style already used elsewhere in that file for each entry — read the current `workshop`/`ai_interviewing` entries first and prepend, do not overwrite their history.

- [ ] **Step 3: Full verification**

```bash
bash scripts/verify-manifest-pins.sh
bash scripts/verify-governance-cascade.sh
bash scripts/verify-submodule-remote-sync.sh
bash scripts/audit-hardcoded-paths.sh
```

Expected: manifest pins MATCH for all 15 declared deps, 0 DRIFT; governance cascade PASS; remote-sync CURRENT for every owned gitlink (this will show `qa` and `challenges` as CURRENT only once they are pushed — they are not owned by this umbrella so nothing needs pushing to them, they just need to match their own remote HEAD, which they will since nothing local was force-changed); hardcoded-paths exit 0.

- [ ] **Step 4: Commit and push, checking for the port-8082 conflict pattern seen earlier this session**

```bash
ss -tlnp 2>&1 | grep ':8082' || true
```

If occupied by an unrelated process (as it was earlier this session — a `llama-server`), use `MV_PORT=9082` when pushing, exactly as done for every umbrella push earlier in this session:

```bash
git commit -m "$(cat <<'EOF'
bump submodules/qa, workshop, ai_interviewing: HelixQA integration complete

Real web test banks, mandatory-validation gate wiring in both
projects, and the independent-content-review skill. See
docs/superpowers/specs/2026-09-18-helixqa-integration-design.md and
this plan's own commit history in each submodule for the full account.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
MV_PORT=9082 git push origin main
```

- [ ] **Step 5: Independently verify**

```bash
LOCAL=$(git rev-parse main); REMOTE=$(git ls-remote origin refs/heads/main | cut -f1)
[ "$LOCAL" = "$REMOTE" ] && echo "MATCH — verified: $LOCAL" || echo "MISMATCH"
```
