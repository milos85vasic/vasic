# VSC-404 Investigation — GitHub default branch `master` → `main`

**Umbrella repo:** `vasic` at `/home/milosvasic/Projects/vasic`
**Branch:** `pr/root-fixes-2026-11-27`, HEAD `a9f71a5`
**Investigation type:** read-only investigation (no edits, no commits, no pushes, no GitHub changes)
**Status:** INVESTIGATION COMPLETE — ready for operator action

---

## 1. Current default branch (from gh API)

| Repo | URL | `gh api ... --jq '.default_branch'` |
|---|---|---|
| LLMOrchestrator | `git@github.com:vasic-digital/LLMOrchestrator.git` | **master** |
| VisionEngine | `git@github.com:vasic-digital/VisionEngine.git` | **master** |

Both repos currently have `master` as their GitHub default branch.

---

## 2. Remote refs (`git ls-remote origin`)

### LLMOrchestrator (`submodules/llm_orchestrator`)

```
8ee57956359c1d1b609bb9a0aa53887c06969941	HEAD
8ee57956359c1d1b609bb9a0aa53887c06969941	refs/heads/main
8ee57956359c1d1b609bb9a0aa53887c06969941	refs/heads/master
a40ec635680f0ad2f176ad1ac00c2cb7d92e2598	refs/tags/1.0.2-dev-0.0.2
ff86bd5a07ecd8a89c4604ed7e5e1cd00510ea6c	refs/tags/1.0.2-dev-0.0.2^{}
3cd0b46e6f8a4bec08774cb50f0ec3fad7b81b26	refs/tags/1.1.0-dev
3cd0b46e6f8a4bec08774cb50f0ec3fad7b81b26	refs/tags/1.1.1-dev-0.0.1
3cd0b46e6f8a4bec08774cb50f0ec3fad7b81b26	refs/tags/1.1.1-dev-0.0.2
```

- Remote branches: `main` and `master` both exist.
- `main` == `master` == `8ee57956...` (identical commit — no divergence).
- Advertised remote `HEAD` → `8ee57956...` (which is both `main` and `master`).
- Note: remote `HEAD` already resolves to the `main` commit even though GitHub's `default_branch` field still says `master` — a pre-existing inconsistency that is harmless because the two commits are identical.

### VisionEngine (`submodules/vision_engine`)

```
9deea37bcb996567835b49688e41084093f03e0d	HEAD
1b2b991c31d46fd43447f2456f163032dfdcaf94	refs/heads/main
9deea37bcb996567835b49688e41084093f03e0d	refs/heads/master
2b63362f576d5b09c565d8fa6f19dd9e57760598	refs/heads/pr/upstream-recipes-2026-11-25
2b63362f576d5b09c565d8fa6f19dd9e57760598	refs/pull/1/head
8bc1f8c71acf93cb6b3d226aae8140c681268629	refs/tags/1.0.2-dev-0.0.2
c82ed6fa4da1f6ab3ef330252f221327f7c3bf4f	refs/tags/1.0.2-dev-0.0.2^{}
46f1c814f69253658b4a2d0ed1deae8891b750b6	refs/tags/1.1.0-dev
46f1c814f69253658b4a2d0ed1deae8891b750b6	refs/tags/1.1.1-dev-0.0.1
46f1c814f69253658b4a2d0ed1deae8891b750b6	refs/tags/1.1.1-dev-0.0.2
```

- Remote branches: `main` and `master` both exist (plus `pr/upstream-recipes-2026-11-25`).
- `main` = `1b2b991c...`, `master` = `9deea37b...` (**different commits** — there IS divergence).
- Advertised remote `HEAD` → `9deea37b...` (`master`), consistent with GitHub `default_branch=master`.

---

## 3. Local branches (`git branch -a`)

### LLMOrchestrator
```
* master
  remote-only (1):
    main
```
- Local `master` checked out. `main` exists only as a remote-tracking ref (no local `refs/heads/main`).

### VisionEngine
```
* master
  + pr/upstream-recipes-2026-11-25
  remote-only (2):
    main
    pr/upstream-recipes-2026-11-25
```
- Local `master` checked out. `main` exists only as a remote-tracking ref (no local `refs/heads/main`).

---

## 4. Current HEAD (`git rev-parse HEAD` / `symbolic-ref HEAD`)

| Repo | `symbolic-ref HEAD` | `rev-parse HEAD` | Matches gitlink? |
|---|---|---|---|
| LLMOrchestrator | `refs/heads/master` | `c84c410daa05fa6532f8baca826e6d0427e72c11` | YES |
| VisionEngine | `refs/heads/master` | `d52fa447d168b2023613cdd6e0bcf7e9c2148bbb` | YES |

Both submodules' local HEAD matches the umbrella gitlink exactly (clean, no drift).

---

## 5. Does `main` exist locally?

**No — for neither repo.**

```
git -C submodules/llm_orchestrator   show-ref --verify refs/heads/main   → fatal: not a valid ref (exit 128)
git -C submodules/vision_engine      show-ref --verify refs/heads/main   → fatal: not a valid ref (exit 128)
```

`main` exists **remotely** on `origin` for both repos, but there is no local `refs/heads/main` branch in either submodule. A fresh `git submodule update --init` or `git clone` would check out whatever the remote default branch is (currently `master`).

---

## 6. helix-deps.yaml entries

File: `helix-deps.yaml` (root). Both entries use **sha pins** (not branch names), so a default-branch flip does **not** invalidate the pins.

| Line | Field | Value |
|---|---|---|
| 527 | `name` | `llm_orchestrator` |
| 528 | `ssh_url` | `git@github.com:vasic-digital/LLMOrchestrator.git` |
| 529 | `ref` | `c84c410daa05fa6532f8baca826e6d0427e72c11` |
| 551 | `name` | `vision_engine` |
| 552 | `ssh_url` | `git@github.com:vasic-digital/VisionEngine.git` |
| 553 | `ref` | `d52fa447d168b2023613cdd6e0bcf7e9c2148bbb` |

Both entries carry the comment `# gitlink tracks heads/master`. That comment is cosmetic only; no `ref:` value references `master` as a branch name, so **no helix-deps.yaml edit is functionally required** by the default-branch change. If desired, the two comments could be updated to `heads/main`, but that is optional documentation.

No other `helix-deps.yaml` line mentions `master` in a way that ties to these repos (the two `master` substring hits at lines 250 and 491 are unrelated comments on other submodules).

---

## 7. `.gitmodules` / CI references to `master`

- `git config -f .gitmodules --get-regexp 'submodule\.(llm_orchestrator|vision_engine)\.'` → **no matches** (exit 1). Neither submodule has a `branch =` setting in `.gitmodules`, so `git submodule update` is not branch-tracking for these; pins are sha-based. The default-branch change will not alter `git submodule update` behavior for them.
- `grep -rln 'master'` over `.github/` (root) and over `submodules/llm_orchestrator/.github/` + `submodules/vision_engine/.github/` → **no workflow/CI files reference `master`**. Zero CI impact.

---

## 8. Exact `gh api` commands for the operator

These are the **only** mutations required. Run each once (read-only until you execute them):

```bash
# LLMOrchestrator: switch default branch master -> main
gh api -X PATCH repos/vasic-digital/LLMOrchestrator -f default_branch=main

# VisionEngine: switch default branch master -> main
gh api -X PATCH repos/vasic-digital/VisionEngine -f default_branch=main
```

Verify after:
```bash
gh api repos/vasic-digital/LLMOrchestrator --jq '.default_branch'
gh api repos/vasic-digital/VisionEngine --jq '.default_branch'
```

Both repos already have a `main` branch on `origin`, so no branch needs to be created or pushed first.

---

## 9. Impact assessment

| Area | LLMOrchestrator | VisionEngine | Verdict |
|---|---|---|---|
| Remote `main` exists? | Yes (8ee57956) | Yes (1b2b991) | ✅ |
| `main` vs `master` commit | Identical (no divergence) | **Different** (1b2b991 ≠ 9deea37b) | ⚠️ VisionEngine HEAD moves to a different commit |
| Remote `HEAD` advertises | main's commit (same sha) | master's commit | After flip, HEAD → main in both |
| Local `refs/heads/main` | No | No | Not needed; pins are sha-based |
| Umbrella gitlink matches local HEAD | Yes | Yes | Unchanged by this operation |
| helix-deps.yaml `ref:` uses branch name? | No (sha pin) | No (sha pin) | No edit required |
| helix-deps.yaml comment "tracks heads/master" | Cosmetic only | Cosmetic only | Optional comment update |
| `.gitmodules branch =` set? | No | No | No impact on `git submodule update` |
| CI/workflow references to `master` | None | None | No CI impact |
| Other submodules touched? | — | — | workshop / ai_interviewing NOT touched (out of scope) |

### Safety conclusion: SAFE to proceed, with one caveat

- **LLMOrchestrator:** Fully safe. `main` and `master` are the same commit, so flipping the default branch changes nothing about resolved content. Fresh clones and `git ls-remote` will see `HEAD` → `main` = same sha as before.
- **VisionEngine:** Safe **provided the operator intends `main` (1b2b991c...) to become the default**. `main` differs from the current `master` (9deea37b), so after the flip the advertised remote `HEAD` and any fresh clone will check out `1b2b991c` instead of `9deea37b`. The umbrella's pinned gitlink (`d52fa447...`, local master) is **not** the same as either remote `main` or `master` — it is a local-only commit. That is already the case today and is unaffected by the default-branch flip; future `git submodule update` will still use the pinned sha, not the default branch.

No commits, pushes, or gitlink bumps are required as part of this change. `helix-deps.yaml` needs no functional edit. No CI files reference `master`. `workshop` and `ai_interviewing` are out of scope and untouched.

---

## 10. Recommended next steps (operator decision)

1. Run the two `gh api -X PATCH ... -f default_branch=main` commands above.
2. Verify `default_branch` returns `main` for both repos.
3. Optionally verify `git -C submodules/<repo> ls-remote origin` shows `HEAD` → `main`'s commit.
4. No repository edits, commits, or pushes are needed in the `vasic` umbrella for this change.
