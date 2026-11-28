# C7 PRIVATE HOIST PLAN — `milosvasic.ru/_private`

**Goal:** Break the forbidden own-org nesting chain flagged by cascade check C7 by hoisting the nested gitlink `milosvasic.ru/_private` to the umbrella root as `submodules/_private`, declaring it in root `.gitmodules` and root `helix-deps.yaml`, and cleaning up the now-dangling references inside `milosvasic.ru`.

**Repository:** `/home/milosvasic/Projects/vasic` (branch `pr/root-fixes-2026-11-27`, HEAD `a9f71a5`)
**Mode:** PLAN ONLY. This file documents exact commands. Per the constraint, no repo file is edited, committed, or pushed here. Steps marked **AGENT** can be executed by an agent; steps marked **OPERATOR** require an operator decision (commit authoring, gitlink bumps, private-repo changes).

---

## 0. Current state (before any step)

Cascade gate `scripts/verify-governance-cascade.sh` result (measured):

```
⚪ NOTE  C7 · milosvasic.ru/Upstreamable — nested gitlink in namespace github.com/red-elf;
           not an owned namespace, documented as third-party in helix-deps.yaml,
           excluded from the cascade
❌ FAIL  C7 RECURSION — nested gitlink(s) in a namespace this tree OWNS —
           a forbidden own-org chain: milosvasic.ru/_private(github.com/vasic-digital)
CM-GOVERNANCE-CASCADE: 11 PASS, 1 FAIL, 0 ENV, 8 NOTE
❌ CM-GOVERNANCE-CASCADE: FAIL — 1 real cascade violation(s)
```

Relevant measured facts:

| Item | Value |
|---|---|
| Umbrella gitlink for `milosvasic.ru` | `805111bad2595eb9d80a52cfb5a6d057660ba292` |
| Nested `_private` gitlink (in `milosvasic.ru` index + tree) | `8abff3de6cc11608cd201e686f32c16ca0436f3d` |
| `_private` URL | `git@github.com:vasic-digital/milosvasic_ru_private.git` |
| `_private` namespace (per `url_namespace`) | `github.com/vasic-digital` → **OWNED** (many vasic-digital submodules) |
| `milosvasic.ru/_private` directory locally | exists but **empty / not initialized** (no `.git`; `git cat-file -t 8abff3de…` → object NOT present locally; fetch required) |
| `_private` references inside tracked `milosvasic.ru` files | `.gitmodules` (declares it), `_config.yml:60` (`- _private` in Jekyll `exclude`), `.github/workflows/pages.yml:30-39` (comment + `git submodule update --init -- _private` using `PRIVATE_VAULT_DEPLOY_KEY`) |

Why C7 fails: C7 (`c7_recursion`) recurses into each OWNED root submodule's `.gitmodules`. For a nested entry, if the URL's namespace is in `OWNED_NAMESPACES` it is flagged as a forbidden own-org chain **before** the exclusion branch is reached — documenting it as third-party would not make it legal. `vasic-digital` is an owned namespace, so `milosvasic.ru/_private` is an own-org chain → C7 FAIL. `milosvasic.ru/Upstreamable` (namespace `red-elf`, not owned) is correctly documented as third-party and passes.

Gate rules that shape the plan:
- **C7:** nested own-org gitlink under an owned submodule is forbidden → must hoist `_private` to the project root and remove it from `milosvasic.ru/.gitmodules`.
- **C4:** `_private` CANNOT be recorded as a third-party exclusion in `helix-deps.yaml` — its namespace (`github.com/vasic-digital`) is owned, and C4's self-exclusion rule rejects excluding an owned namespace. It must be an **owned `deps[]` entry**, mirroring `job_seeker`.
- **C1:** `submodules/_private` (URL `…:vasic-digital/…`) → owned root (22nd owned submodule).
- **C6 / C9:** root `.gitmodules` and `helix-deps.yaml` must agree in both directions; `helix-deps.yaml` path convention: `layout: grouped` → `<root>/submodules/<name>`, `layout: flat` → `<root>/<name>`. Since `_private` lives at `submodules/_private`, use `name: _private` + `layout: grouped`. `deps[].ref` must equal the gitlink (`8abff3de…`) per C9.
- **C2 / C3:** every owned root submodule must carry all four agent carriers (`AGENTS.md`, `CLAUDE.md`, `QWEN.md`, `GEMINI.md`) as pointer carriers. Hoisting `_private` as an owned root therefore makes C2 require those four carriers in `submodules/_private` (see Risks/edge cases, step 6).

---

## Step 1 — Hoist `_private` to umbrella root (AGENT, requires network fetch)

Create the root-level gitlink `submodules/_private` at commit `8abff3de…` and register it in root `.gitmodules`. `git submodule add` clones the remote at HEAD (which is `8abff3de…`) into `submodules/_private`, stages the gitlink, and writes the `[submodule "submodules/_private"]` block into root `.gitmodules` (covering step 2 as well).

```bash
cd /home/milosvasic/Projects/vasic
git submodule add git@github.com:vasic-digital/milosvasic_ru_private.git submodules/_private
```

Notes:
- The object `8abff3de…` is not in the local object store, so this **must fetch** from the remote (remote is reachable per context). If a fetch is not desired, the equivalent manual form is `git update-index --add --cacheinfo 160000,8abff3de6cc11608cd201e686f32c16ca0436f3d,submodules/_private` plus a hand-written `.gitmodules` block — but the commit object must still be obtainable to complete a later commit.
- `submodules/_private` must not already exist at root (it does not).
- Do NOT touch `workshop` or `ai_interviewing`.

**Expected state after step 1:** root `.gitmodules` declares `submodules/_private` at `8abff3de…`; `submodules/_private` is checked out with the remote's content. C7: **still FAIL** — `milosvasic.ru` still nests `_private` in its own `.gitmodules`, so C7 still reports the own-org chain. (Hoisting alone does not close C7; step 4/5 does.)

---

## Step 2 — Confirm root `.gitmodules` entry (AGENT, verification)

Verify the block was added by `git submodule add`:

```bash
git -C /home/milosvasic/Projects/vasic config -f .gitmodules --get-regexp 'submodule\("submodules/_private"\)'
git -C /home/milosvasic/Projects/vasic ls-files -s | grep 'submodules/_private'
```

Expected:
```
submodule.submodules/_private.path	submodules/_private
submodule.submodules/_private.url	git@github.com:vasic-digital/milosvasic_ru_private.git
160000 8abff3de6cc11608cd201e686f32c16ca0436f3d 0	submodules/_private
```

**Expected state after step 2:** no change beyond step 1; confirmed. C7: **still FAIL**.

---

## Step 3 — Add `_private` as an owned `deps[]` entry in root `helix-deps.yaml` (AGENT)

Add a `deps[]` entry mirroring the `job_seeker` format (owned, `layout: grouped` so the path resolves to `submodules/_private`). Do **NOT** put it in the third-party comment block (C4 self-exclusion would reject it — see §0).

Insert near the `job_seeker` entry (placement is cosmetic; C6 uses set comparison):

```yaml
  - name: _private
    ssh_url: git@github.com:vasic-digital/milosvasic_ru_private.git
    ref: "8abff3de6cc11608cd201e686f32c16ca0436f3d"
    why: "Private single-operator job-search vault / tooling, hoisted from the milosvasic.ru nested gitlink to break the own-org nesting chain (cascade check C7, §11.4.28(C)). Personal data only in the git-ignored overlay."
    layout: grouped
```

`layout: grouped` → path `submodules/_private`, matching root `.gitmodules` (C6 both directions). `ref` = `8abff3de…` matches the gitlink (C9).

**Expected state after step 3:** `helix-deps.yaml` records `submodules/_private`; C6 passes for this entry; C7 **still FAIL** (milosvasic.ru still nests `_private`).

---

## Step 4 — Clean up `milosvasic.ru` (AGENT)

Inside the `milosvasic.ru` submodule:

**4a. Remove `_private` from `milosvasic.ru/.gitmodules`** — delete the whole block:
```
[submodule "_private"]
	path = _private
	url = git@github.com:vasic-digital/milosvasic_ru_private.git
```

**4b. Repoint/remove the `pages.yml` reference** — `.github/workflows/pages.yml:30-39` runs `git submodule update --init -- _private` with a `PRIVATE_VAULT_DEPLOY_KEY`. Since `_private` will no longer be nested in `milosvasic.ru` (and is excluded from the Jekyll build anyway, so not published), the cleanest action is to **remove the entire "Check out private submodule" step** (comment + env block + `run:`). Alternative (operator decision): keep a repointed clone step — but `_private` now lives at the umbrella root and is not reachable from within the milosvasic.ru Pages checkout (`submodules: false`), so removal is the working default.

**4c. Update `_config.yml` exclude** — line 60 lists `- _private` under Jekyll `exclude`. After hoisting there is no `milosvasic.ru/_private` to exclude, so the line is a harmless no-op; remove it for cleanliness (optional).

**4d. Drop the gitlink from the `milosvasic.ru` index** — `_private` is uninitialized (empty dir), so:
```bash
cd /home/milosvasic/Projects/vasic/milosvasic.ru
git rm --cached _private          # removes the mode-160000 gitlink from the index
rmdir _private                    # now-empty directory
git add .gitmodules               # re-stage the edited .gitmodules
```

**Expected state after step 4:** `milosvasic.ru` worktree no longer declares or nests `_private`. C7 read against the worktree: **PASS** for `_private` (own-org chain gone). **However** the `milosvasic.ru` submodule is now dirty: its committed gitlink (`805111ba…`) still contains `_private`, while the worktree no longer does. Not a clean committed state until step 5.

---

## Step 5 — Commit inside `milosvasic.ru` and bump its umbrella gitlink (OPERATOR DECISION)

Commit the `milosvasic.ru` changes (`.gitmodules`, `.github/workflows/pages.yml`, optionally `_config.yml`, plus the de-registered `_private` gitlink) to a new commit `M2`, then bump the umbrella's `milosvasic.ru` gitlink from `805111ba…` to `M2`.

```bash
cd /home/milosvasic/Projects/vasic/milosvasic.ru
git commit -m "chore(milosvasic.ru): de-register nested _private gitlink (hoisted to umbrella root as submodules/_private)"   # operator: message/authoring
cd /home/milosvasic/Projects/vasic
git add milosvasic.ru                 # stage the new gitlink M2
# operator: include this gitlink bump in the root commit; do NOT force-push (§11.4.113 absolute)
```

This is an **operator decision** because it commits inside a consumed submodule and bumps the umbrella gitlink (the bump itself is an operator decision per project policy; submodule bumps are never agent-auto-pushed).

**Expected state after step 5:** `milosvasic.ru`'s committed `.gitmodules` no longer nests `_private`; the umbrella gitlink points at `M2`. C7: **CLEAN PASS** — no owned submodule nests an own-org gitlink; `submodules/_private` is an owned root with no nested `.gitmodules` (C7 skips it). `Upstreamable` under `milosvasic.ru` remains documented third-party (still passes).

---

## Step 6 — Keep C2/C3 green: carriers for `submodules/_private` (OPERATOR DECISION, required follow-up)

Because `_private` is now an **owned** root submodule (namespace `vasic-digital`), C2 requires all four agent carriers in `submodules/_private`:
`AGENTS.md`, `CLAUDE.md`, `QWEN.md`, `GEMINI.md`, each a pointer carrier opening with the `## INHERITED FROM ` block (§11.4.35 inv. 6). `job_seeker` (the analogous private job-search submodule) carries all four; `_private` almost certainly does not (it is a vault).

Check after step 1's clone:
```bash
ls /home/milosvasic/Projects/vasic/submodules/_private/AGENTS.md \
   /home/milosvasic/Projects/vasic/submodules/_private/CLAUDE.md \
   /home/milosvasic/Projects/vasic/submodules/_private/QWEN.md \
   /home/milosvasic/Projects/vasic/submodules/_private/GEMINI.md
```

If missing, the operator must:
1. Add the four pointer carrier files to `submodules/_private` (inherit from the root carriers).
2. Commit inside `submodules/_private` → new commit (changes `_private`'s commit away from `8abff3de…`).
3. Bump the umbrella gitlink for `submodules/_private` to the new commit **and** update `helix-deps.yaml` `deps[].ref` for `_private` to match (C9), in the same change.

Marked **operator decision** because it modifies the private `_private` repo and changes its pinned commit (requires gitlink + manifest resync per C9/C6). Until done, C2 will FAIL on `submodules/_private/*` carriers (missing), so a fully green cascade requires this step.

---

## Expected end state (all steps complete)

| Gate | Expected verdict |
|---|---|
| C7 RECURSION | **PASS** — no nested own-org chain; `milosvasic.ru/_private` removed; `submodules/_private` has no nested `.gitmodules` |
| C6 MANIFEST-FLEET-SYNC | **PASS** — `.gitmodules` and `helix-deps.yaml` agree (both include `submodules/_private`) |
| C9 MANIFEST-PIN-SYNC | **PASS** — `helix-deps.yaml deps[].ref` == gitlink `8abff3de…` (unless step 6 changes `_private`'s commit, then resync) |
| C1 FLEET-CLASSIFIED | **PASS** — 22 owned, 1 governance source (`submodules/constitution`), 1 third-party (`submodules/superspec`) |
| Full cascade | **PASS** (modulo the C2 carrier follow-up in step 6) |

The own-org chain `milosvasic.ru/_private(github.com/vasic-digital)` is broken; `_private` is reached by C2/C3 via the root declaration.

---

## Risks / edge cases

1. **C2/C3 carrier requirement (load-bearing).** Hoisting `_private` as an owned root makes C2 demand 4 pointer carriers in `submodules/_private`. If absent, C2 FAILs. Remediation is step 6 (operator decision). This is the single largest residual risk to a fully green gate.

2. **Do NOT record `_private` as a third-party exclusion.** C4's self-exclusion rule rejects excluding any gitlink whose namespace is owned (`github.com/vasic-digital` is owned). It must be an owned `deps[]` entry (step 3). The third-party comment block must keep only `milosvasic.ru/Upstreamable` (red-elf, not owned) and `submodules/superspec` (WangX0111, not owned).

3. **C6 path convention.** Use `name: _private` + `layout: grouped` → path `submodules/_private`. A flat entry named `_private` would resolve to path `_private` and mismatch root `.gitmodules` (`submodules/_private`), causing a C6 unrecorded/phantom FAIL.

4. **Network fetch required.** `8abff3de…` is not present locally (`git cat-file -t` → not found). `git submodule add` (step 1) must fetch from `git@github.com:vasic-digital/milosvasic_ru_private.git` (remote reachable per context). Offline execution would fail.

5. **`pages.yml` deploy-key step.** After hoisting, `git submodule update --init -- _private` inside `milosvasic.ru` references a submodule that no longer exists there; the step must be removed (or repointed, but it cannot reach `submodules/_private` from within the milosvasic.ru Pages checkout). The `PRIVATE_VAULT_DEPLOY_KEY` env block becomes unused. `_private` is excluded from the Jekyll build (`_config.yml`), so it is not published either way — removal does not affect published output.

6. **Ordering of the `milosvasic.ru` bump.** Step 5 (commit `M2` inside `milosvasic.ru` + umbrella gitlink bump) should be committed together with or after the root hoist changes so C6/C9 stay consistent at every commit boundary. Do not force-push (§11.4.113 absolute).

7. **`_private` empty locally vs. remote content.** Locally `milosvasic.ru/_private` is an empty, uninitialized directory; the remote at `8abff3de…` holds the actual vault content. `git submodule add` brings that content down. Verify post-clone that `_private` is non-empty before committing.

8. **Scope guard.** Do NOT touch `workshop` or `ai_interviewing` submodules. Do not edit, commit, or push anything while producing this plan — this document is read-only.
