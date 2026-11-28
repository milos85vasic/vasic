# Uncommitted Changes Report — `vasic` umbrella monorepo

**Generated:** investigation session (2026-11-28)
**Repository:** /home/milosvasic/Projects/vasic
**Current branch:** `main`
**HEAD commit:** d5fc795 Merge branch 'pr/root-fixes-2026-11-27' into main
**Nothing was committed.** The operator decides what to commit and when.

---

## 1. `git status --short` — ALL changes

### Modified tracked files (3)
```
 M _tests/evidence/homepages/milos-desktop-dark.png
 M _tests/evidence/homepages/milos-desktop-light.png
 M _tests/evidence/homepages/milos-mobile.png
```
All three are binary PNG evidence files (screenshot comparisons).

### Modified submodules — gitlink pointer moved, clean internal worktree (9)
```
 M submodules/LLMProvider
 M submodules/RAG
 M submodules/challenges
 M submodules/llm_orchestrator
 M submodules/llm_provider
 M submodules/qa
 M submodules/security
 M submodules/vision_engine
 M workshop
```
For each of these, `git -C <submodule> status --short` returned **empty** (clean working tree inside the submodule). The change in the parent is purely a **gitlink pointer move**: the submodule's HEAD advanced to a new commit that the parent's recorded gitlink does not yet point at. This is submodule pointer drift.

### Submodule with internal modifications (1)
```
 m job_seeker
```
Lowercase `m` = submodule HEAD changed **plus** untracked/modified content inside. Inside `job_seeker`:
```
 M evidence/JSK-T032/live-h3.txt
 M tools/containers/cmd/jsstack/main.go
?? submodules/
```
- `evidence/JSK-T032/live-h3.txt`: 46 lines changed (23 insertions, 25 deletions)
- `tools/containers/cmd/jsstack/main.go`: 1 line changed
- `?? submodules/`: an untracked `submodules/` directory inside job_seeker containing a `containers` subdirectory (nested repo material, not registered with the umbrella)

### Submodule flagged by git status, no pointer drift (1)
```
 ? submodules/constitution
```
`submodules/constitution` is a **registered, initialized submodule** (`.gitmodules` entry present, gitlink `160000 2c0b3ad16a12...` in the index). Its HEAD is `2c0b3ad1` — **identical to the recorded gitlink**, so there is **no pointer drift** for constitution. The `?` marker indicates untracked content **within** the constitution submodule (it contains a nested `submodules/claude_toolkit` entry). This is not a modified submodule in the pointer-drift sense.

---

## 2. Per-submodule investigation (`log --oneline -3` + `status --short`)

### job_seeker (m — HEAD changed + internal mods)
```
HEAD: 8c7986f Merge pull request #248 from vasic-digital/pr/hook-ssh-keepalive
      91c65de fix(hooks): install-hooks sets core.sshCommand with ServerAliveInterval...
      2db7fe3 Merge pull request #247 from vasic-digital/pr/wrapup-2026-11-25
Internal status:
 M evidence/JSK-T032/live-h3.txt
 M tools/containers/cmd/jsstack/main.go
?? submodules/
```

### submodules/LLMProvider (M — pointer move only, clean inside)
```
HEAD: 53e4b2e docs(governance): pointer to vasic umbrella override, hosted Jev decision model only (shadow)
      261cfde fix(challenges): CONST-050(B) pass-rate floors and down replicas are findings (VSC-369 operator decision)
      131842d fix(challenges): VSC-369 review follow-ups ...
Internal status: (clean)
```

### submodules/RAG (M — pointer move only, clean inside)
```
HEAD: f53c503 docs(governance): pointer to vasic umbrella override, hosted Jev decision model only (shadow)
      90b7058 fix(challenges): CONST-050(B) pass-rate floors and down replicas are findings (VSC-369 operator decision)
      7e18911 fix(challenges): VSC-369 review follow-ups ...
Internal status: (clean)
```

### submodules/challenges (M — pointer move only, clean inside)
```
HEAD: d94e554 cascade: chore(docs): Markdown-only docs - formats export OFF by default, remove generated PDF/HTML/DOCX exports
      1aefc3a chore(gitignore): ignore tests/stress/qa-results/ run artifacts
      5567794 fix(host-power): CONST-033 scanner gains a paired --prove-failure proof ...
Internal status: (clean)
```

### submodules/constitution (? — registered, HEAD == gitlink, no drift)
```
HEAD: 2c0b3ad1 merge(pi-constitution): merge task/pi-constitution-test-suite — comprehensive test suite (11 types, 186 tests)
      54884006 test(pi-constitution): add comprehensive test suite (11 types, 186 tests)
      6993044e Merge branch 'docs/pi-constitution-exhaustive-docs' ...
Internal status: ? submodules/claude_toolkit  (untracked nested entry inside constitution)
```

### submodules/llm_orchestrator (M — pointer move only, clean inside)
```
HEAD: c84c410 fix(challenges): CONST-050(B) pass-rate floors and down replicas are findings (VSC-369 operator decision)
      17f59d7 fix(challenges): VSC-369 review follow-ups ...
      45983aa fix(challenges): CONST-050(B) family gains one --prove-failure convention ...
Internal status: (clean)
```

### submodules/llm_provider (M — pointer move only, clean inside)
```
HEAD: 53e4b2e docs(governance): pointer to vasic umbrella override, hosted Jev decision model only (shadow)
      261cfde fix(challenges): CONST-050(B) pass-rate floors and down replicas are findings (VSC-369 operator decision)
      131842d fix(challenges): VSC-369 review follow-ups ...
Internal status: (clean)
```

### submodules/qa (M — pointer move only, clean inside)
```
HEAD: b16a089 Merge remote-tracking branch 'github/main'
      41a0680 cascade: chore(docs): Markdown-only docs - formats export OFF by default...
      8851c1a test(opensource): share one legacy-path fixture constant set; clarify AuditTools doc-key comment
Internal status: (clean)
```

### submodules/security (M — pointer move only, clean inside)
```
HEAD: 0513361 fix(challenges): CONST-050(B) pass-rate floors and down replicas are findings (VSC-369 operator decision)
      23a7d5d fix(challenges): VSC-369 review follow-ups — stub loopback binding measured...
      33b0434 fix(challenges): trio review follow-ups — early exit caught by an EXIT-trap floor...
Internal status: (clean)
```

### submodules/vision_engine (M — pointer move only, clean inside)
```
HEAD: d52fa44 fix(challenges): CONST-050(B) pass-rate floors and down replicas are findings (VSC-369 operator decision)
      7cdd8ec fix(challenges): VSC-369 review follow-ups ...
      562aec6 fix(challenges): CONST-050(B) family gains one --prove-failure convention ...
Internal status: (clean)
```

### workshop (M — pointer move only, clean inside)
```
HEAD: 5a7acdd1 Merge pull request #1 from milos85vasic/pr/runner-flag
      7797b732 feat(runner): --runner=NAME / CONTAINERS_RUNNER forces the container runner...
      e5c51070 fix: auto-start podman machine on macOS after reboot
Internal status: (clean)
```

---

## 3. Untracked files (`?`) — categorization

### A. LUMEN_*.md reports (from this session's Lumen investigation) — 7 files
| File | Lines | Modified |
|---|---|---|
| `LUMEN_CLEANUP_REPORT.md` | 201 | 2026-11-28 00:59 |
| `LUMEN_CONFIG_REPORT.md` | 329 | 2026-11-28 00:44 |
| `LUMEN_DOCTOR_FIX.md` | 82 | 2026-11-28 00:26 |
| `LUMEN_DOCTOR_REPORT.md` | 384 | 2026-11-27 23:47 |
| `LUMEN_GPU_REPORT.md` | 152 | 2026-11-28 00:46 |
| `LUMEN_REINDEX_REPORT.md` | 92 | 2026-11-27 23:53 |
| `LUMEN_SEARCH_TEST_REPORT.md` | 173 | 2026-11-28 00:52 |

All dated 2026-11-27/28 — **NEW from this session**.

### B. Agent report files — 10 files
| File | Lines | Modified | Category |
|---|---|---|---|
| `PR_READINESS.md` | 174 | 2026-11-27 22:46 | PR readiness summary for `pr/root-fixes-2026-11-27` |
| `SUBMODULE_DRIFT_ANALYSIS.md` | 205 | 2026-11-27 22:47 | Submodule drift analysis |
| `AUDIT-ENDPOINT-FINDINGS.md` | 104 | 2026-11-27 22:23 | Audit of frozen ENDPOINT assumptions in workshop/platform/gates/ |
| `C7_PRIVATE_HOIST_PLAN.md` | 201 | 2026-11-27 22:49 | C7 PRIVATE HOIST PLAN — milosvasic.ru/_private |
| `CONSOLIDATED_STATUS_REPORT.md` | 145 | 2026-11-27 22:27 | Consolidated status report — vasic umbrella monorepo |
| `CONSTITUTION_BINDING_AUDIT.md` | 153 | 2026-11-27 22:47 | Constitution binding audit — vasic umbrella repository |
| `GATE_VERIFICATION_REPORT.md` | 118 | 2026-11-27 22:51 | Gate verification report — vasic umbrella repository |
| `T038_BRIEFING.md` | 128 | 2026-11-27 22:47 | T038 Briefing — Passage-contract review checkpoint |
| `TASKS-008-UNBLOCKED.md` | 140 | 2026-11-27 22:22 | Implementation-ready task descriptions — specs/008-unified-workshop-platform |
| `VSC404_DEFAULT_BRANCH.md` | 185 | 2026-11-27 22:47 | VSC-404 Investigation — GitHub default branch master → main |

All dated 2026-11-27 — **NEW from this session**.

### C. `.pi/` and `.pi-lens.json` (agent artifacts) — 2 items
| Item | Description | Modified |
|---|---|---|
| `.pi-lens.json` | 4-line pi-lens config (`maxProjectFiles: 20000`) | 2026-11-27 20:53 |
| `.pi/` | Agent artifact directory containing `todos/` | 2026-11-27 18:58 |

All dated 2026-11-27 — **NEW from this session**.

### D. Anything else — untracked directories + scripts — 4 items
| Item | Description | Modified | Assessment |
|---|---|---|---|
| `findings/` | Dir with 1 file: `008_T006_lint_contradiction.md` (lint contradiction audit for specs/008 Phase 1 T006) | 2026-11-27 21:29 | NEW from this session |
| `challenges/` | Untracked directory with nested `.git` (35 entries: AGENTS.md, CLAUDE.md, go.mod, cmd/, docs/, banks/, etc.). **NOT a registered submodule** — no gitlink in index, `.gitmodules` has no active `challenges` submodule entry. | 2026-11-24 19:31 | Pre-existing drift (Nov 24) |
| `HelixQA/` | Untracked directory with nested `.git` (43 entries: AGENTS.md, API_REFERENCE.md, cmd/, banks/, challenges/, Dockerfile, etc.). **NOT a registered submodule** — no gitlink in index despite 1 `.gitmodules` match. | 2026-11-24 19:31 | Pre-existing drift (Nov 24) |
| `land.sh` | 32-line bash script (with embedded Python) for landing a branch/PR against `job_seeker-wt-w2r` worktree | 2026-11-24 15:26 | Pre-existing drift (Nov 24) |

---

## 4. Recent commits (`git log --oneline -5`)

```
d5fc795 Merge branch 'pr/root-fixes-2026-11-27' into main     (HEAD)
ea3429c fix(lumen): repair index-doctor schema mismatch for multi-project store
dd123e8 Merge origin/main into pr/root-fixes-2026-11-27
dab0e31 fix(lumen-index-doctor): match projects by path in multi-project index
4932e9c fix(lumen): refuse GPU-backed embedding paths (CUDA, ROCm), not just Vulkan
```

HEAD is `d5fc795` on `main`. All uncommitted changes sit on top of this commit.

---

## 5. NEW from this session vs pre-existing drifts

### NEW from this session (timestamps 2026-11-27 / 2026-11-28)
These correlate with the current investigation/Lumen work and are dated after the branch's last commit:

1. **All 7 `LUMEN_*.md` reports** (2026-11-27 23:47 → 2026-11-28 00:59)
2. **All 10 agent report `.md` files** (2026-11-27 22:22 → 22:51)
3. **`.pi/` and `.pi-lens.json`** (2026-11-27 18:58 → 20:53)
4. **`findings/`** directory (2026-11-27 21:29)
5. **PNG modifications** in `_tests/evidence/homepages/` (2026-11-28 00:08 — just now, 3 binary files)

### Pre-existing drifts (timestamps 2026-11-24, present before this session)
These are NOT products of the current session:

1. **`land.sh`** (2026-11-24 15:26) — untracked landing script
2. **`challenges/`** (2026-11-24 19:31) — untracked nested repo, not a registered submodule
3. **`HelixQA/`** (2026-11-24 19:31) — untracked nested repo, not a registered submodule
4. **Submodule pointer drift** across 9 submodules (`LLMProvider`, `RAG`, `challenges`, `llm_orchestrator`, `llm_provider`, `qa`, `security`, `vision_engine`, `workshop`) — each has a clean internal worktree but its HEAD is ahead of the parent's recorded gitlink. These appear to be pre-existing drift (submodule HEADs advanced without the parent gitlink being committed). Operator should verify against `git diff HEAD --submodule=log`.
5. **`job_seeker` internal changes** (`evidence/JSK-T032/live-h3.txt`, `tools/containers/cmd/jsstack/main.go`, untracked `submodules/`) — modification date not separately determined; treat as pre-existing pending operator confirmation.

---

## Summary

| Category | Count | Items |
|---|---|---|
| Modified tracked files | 3 | 3 PNG evidence files |
| Modified submodules (pointer drift only) | 9 | LLMProvider, RAG, challenges, llm_orchestrator, llm_provider, qa, security, vision_engine, workshop |
| Submodule w/ internal mods | 1 | job_seeker |
| Submodule clean but flagged | 1 | submodules/constitution (no drift) |
| Untracked — LUMEN reports | 7 | NEW this session |
| Untracked — agent reports | 10 | NEW this session |
| Untracked — agent artifacts | 2 | .pi/, .pi-lens.json — NEW this session |
| Untracked — other | 4 | findings/ (NEW), challenges/ (pre-existing), HelixQA/ (pre-existing), land.sh (pre-existing) |

**Recommendation:** Review the NEW session artifacts (LUMEN reports, agent reports, `.pi/`) and the PNG changes for intentional inclusion; treat `challenges/`, `HelixQA/`, and `land.sh` (all Nov 24) as pre-existing untracked material; and resolve the 9 submodule pointer drifts plus `job_seeker` internal changes per operator decision. **Nothing has been committed.**
