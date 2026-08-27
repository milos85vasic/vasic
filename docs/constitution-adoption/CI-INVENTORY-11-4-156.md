# CI inventory under Constitution §11.4.156

> **⚠ SUPERSEDED IN PART — read before acting on any "Action required" cell.**
> This is a **forensic snapshot** of the audit window 21:15–21:34 on 2026-08-27,
> and every *measurement* in it stands exactly as recorded. What does **not**
> stand is its forward plan for `milosvasic.ru` (row 4, the standing-action
> paragraph, and §1 of "Operator actions this audit cannot perform").
>
> Later the same day the *"disable both"* decision was **partially reversed**:
>
> - **Umbrella (`.`)** — `.github/workflows/ci.yml` → `ci.yml.disabled` **stands**;
>   the rename has since been staged as recorded and the gates run from a local
>   pre-push hook (`scripts/pre-push-gates.sh` + an installed `.git/hooks/pre-push`).
> - **`milosvasic.ru` (row 4)** — the staged `pages.yml` → `pages.yml.disabled`
>   rename observed at T1 was **never committed or pushed, and has been undone.**
>   `.github/workflows/pages.yml` is **ACTIVE** and will stay active.
>   `gh api repos/milos85vasic/milosvasic.ru/pages` returns
>   `build_type: "workflow"`: that workflow is the **sole** publish path for the
>   live production site. There is no `gh-pages` branch, no `docs/` folder, and
>   the repository root is Jekyll SOURCE, so it cannot be served raw from a
>   branch; `_tools/deploy-langs.sh` pushes source and then `sleep`s waiting for
>   that workflow, so it is not a fallback. Operator's overriding directive,
>   verbatim: ***"Make sure all pages websites work flawlessly! No website can be
>   broken! All websites we have here are running deployed in production!"***
>   `milosvasic.ru` is a **known, documented deviation** from §11.4.156 — **not**
>   an `Override §11.4.156`, which the rule forbids, and never to be recorded as
>   one.
> - **`vasic.digital`** — classified **(c) CLEAN** below on the correct basis
>   that it has no root CI *file*. That remains true and is not an error, but it
>   is **not the same as compliant**: verified 2026-08-27,
>   `gh api repos/vasic-digital/vasic-digital.github.io/pages` returns
>   `build_type: "legacy"`, and `pages build and deployment`
>   (`dynamic/pages/pages-build-deployment`) runs on every push. The probe this
>   inventory uses is file-based and cannot see that. **No file-level remedy
>   exists** — there is no file to disable.
>
> Full record: [`DECISION-11-4-156-COMPLY.md`](DECISION-11-4-156-COMPLY.md) §0.
> Appendix A's raw output is a **T1 snapshot** and is preserved unedited as
> evidence of that moment, not as current state.

**Scope:** every git repository reachable from the `vasic` umbrella, fully recursively.
**Audit type:** read-only. No CI file was created, edited, renamed or deleted by this audit.
**Audit window:** 2026-08-27, approximately 21:15 → 21:29 +02:00 (Europe/Belgrade).
**Umbrella HEAD at close of audit:** `f1e0c838bbabf14a47a13cd0ff209c3fa2db98df`
**`milosvasic.ru` HEAD at close of audit:** `66c8d607b20f0d9e984cb0e06f10a2020ebd9a10`

## The rule being applied

§11.4.156 (`submodules/constitution/Constitution.md`, line 9552) mandates, in the
parts that decide this inventory:

- **(A) Zero active CI at the repository ROOT.** "the only location a provider executes".
- **(B) Disabled means a push triggers ZERO runs.** Delete, or rename to a
  non-active name (the §11.4.75 `.disabled` / `.disabled-local-only` convention).
  `if: false` jobs under live `on:` triggers are NOT compliant.
- **(C) Scope = repositories we author + push.** Vendored / third-party source
  whose `.github/workflows` or `.gitlab-ci.yml` sit BELOW the repo root are
  **INERT** — "a provider never executes a non-root config" — so they are
  **OUT of scope and MUST NOT be mass-edited** (§11.4.29 vendor-name exemption +
  tree integrity). The decisive test is: *"does a push to one of OUR upstreams
  trigger a run?"* — yes ⇒ disable; structurally inert ⇒ document and leave
  (§11.4.6 — verify inertness as FACT, never assume).
- **(E) Pre-push verification:**
  `git ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$'`
  must return empty for authored repos.

The probe used throughout this document is the §11.4.156(E) probe widened to
also catch GitLab pipeline includes:

```bash
git ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
```

It is anchored to `^`, so it matches **only** root-level configuration — the only
location a provider executes.

## Repository enumeration — how the 16 repositories were found

`git submodule status --recursive` **cannot** enumerate this tree. It aborts:

```
fatal: no submodule mapping found in .gitmodules for path 'Upstreamable'
fatal: failed to recurse into submodule 'Upstreamable'
fatal: failed to recurse into submodule 'milosvasic.ru'
```

Enumeration was therefore done with `find . -name .git`, which is
gitlink-safe: a submodule's `.git` is a **FILE**, not a directory. Every
existence test in this audit used `-e`, never `-d`. `find` completed with
`rc=0` (no permission-denied truncation) and `git worktree list` reports a
single worktree, so no repository is hidden behind a linked worktree.

`find` returned **17** `.git` entries. **16** of them are functioning git
repositories. The 17th is analysed in the "Non-repository `.git` file" section
below.

## Ownership determination

"Ours" is decided from `git remote -v` only. Owned upstream namespaces:
`github.com/HelixDevelopment`, `github.com/vasic-digital`,
`gitlab.com/helixdevelopment1`, `gitlab.com/vasic-digital`,
`gitflic.ru/helixdevelopment`, `gitverse.ru/helixdevelopment`, and the
milosvasic-owned namespaces `github.com/milos85vasic`, `gitflic.ru/milosvasic`,
`gitlab.com/milos85vasic`, `gitverse.ru/milosvasic`. Full remote URLs for every
repository are in Appendix A.

## Inventory

| # | Repository path (relative to umbrella root) | Remotes — ours? | Root-level CI files found (probe output) | Classification | Action required |
|---|---|---|---|---|---|
| 1 | `.` (umbrella) | **YES** — `github.com/milos85vasic/vasic` (github, origin, upstream) | **T0:** `.github/workflows/ci.yml` — **T1:** none (staged rename to `ci.yml.disabled`) — **T2:** `.github/workflows/zz-probe.yml` (mutation probe, staged) — **T3:** none | **(a) VIOLATION at T0 — remediated in flight, staged only** | Commit + push the staged `ci.yml` → `ci.yml.disabled` rename. Concurrent-agent work; NOT touched by this audit. |
| 2 | `ai_interviewing` | **YES** — `github.com/milos85vasic/ai_interviewing` | *(none)* | **(c) CLEAN** | None |
| 3 | `design-toolkit` | **YES** — `github.com/vasic-digital/design-toolkit` | *(none)* | **(c) CLEAN** | None |
| 4 | `milosvasic.ru` | **YES** — `github.com/milos85vasic/milosvasic.ru` + `gitflic.ru/milosvasic/milosvasic-net-v-2` | **T0:** `.github/workflows/pages.yml` — **T1:** none (staged rename to `pages.yml.disabled`) | **(a) VIOLATION at T0 — remediation observed in flight at T1, ~~then~~ **REVERSED**; now a documented deviation** | ~~Commit + push the staged `pages.yml` → `pages.yml.disabled` rename, then bump the umbrella gitlink.~~ **DO NOT.** The rename was never committed and has been undone; `pages.yml` is ACTIVE and stays active — it is the sole publish path for the live production site (`build_type: "workflow"`). See the banner at the head of this document. **No action required; none permitted.** |
| 5 | `milosvasic.ru/Upstreamable` | **UNDETERMINED** — `github.com/red-elf/Upstreamable` + `gitflic.ru/red-elf/upstreamable`; the `red-elf` namespace is not in the owned-upstream list and is not named as owned in `README.md` or `CLAUDE.md` | *(none)* | **(c) CLEAN** — ownership is moot because there is nothing to disable | None. Ownership left UNDETERMINED rather than guessed (§11.4.6). |
| 6 | `monetization` | **YES** — `github.com/milos85vasic`, `gitflic.ru/milosvasic`, `gitlab.com/milos85vasic`, `gitverse.ru/milosvasic` (4 owned upstreams) | *(none)* | **(c) CLEAN** | None |
| 7 | `submodules/constitution` | **YES** — `github.com/HelixDevelopment`, `gitflic.ru/helixdevelopment`, `gitlab.com/helixdevelopment1`, `gitverse.ru/helixdevelopment`, `github.com/vasic-digital`, `gitlab.com/vasic-digital` (6 owned upstreams) | *(none)* | **(c) CLEAN** | None |
| 8 | `submodules/constitution/submodules/anti_bluff` | **YES** — `github.com/vasic-digital/anti_bluff` | *(none)* | **(c) CLEAN** | None |
| 9 | `submodules/constitution/submodules/continuum` | **YES** — `github.com/vasic-digital/continuum` | *(none)* | **(c) CLEAN** | None |
| 10 | `submodules/constitution/submodules/design-toolkit` | **YES** — `github.com/vasic-digital/design-toolkit` | *(none)* | **(c) CLEAN** | None |
| 11 | `submodules/constitution/submodules/docs_chain` | **YES** — `github.com/vasic-digital/docs_chain` + `gitlab.com/vasic-digital/docs_chain` | *(none)* | **(c) CLEAN** | None |
| 12 | `submodules/constitution/submodules/helix_perf_cache` | **YES** — `github.com/HelixDevelopment/helix_perf_cache` | *(none)* | **(c) CLEAN** | None |
| 13 | `submodules/constitution/submodules/session_orchestrator` | **YES** — `github.com/vasic-digital/session_orchestrator` | *(none)* | **(c) CLEAN** | None |
| 14 | `submodules/constitution/submodules/token_optimizer` | **YES** — `github.com/vasic-digital/token_optimizer` | *(none)* | **(c) CLEAN** | None |
| 15 | `submodules/superspec` | **NO** — sole remote `github.com/WangX0111/superspec` | `.github/workflows/ci.yml` | **(b) THIRD-PARTY / VENDORED** | **NONE — DO NOT EDIT.** See analysis below. |
| 16 | `vasic.digital` | **YES** — `github.com/vasic-digital/vasic-digital.github.io` | *(none)* | **(c) CLEAN** | None |

### Counts

| Classification | Count |
|---|---|
| Repositories scanned | **16** |
| (a) Ours, active root CI — **VIOLATION** (state at T0, start of audit) | **2** |
| (a) still uncommitted at T1 (staged `.disabled` renames, not yet pushed) | **2** |
| (b) Third-party / vendored, out of scope | **1** |
| (c) Clean — no root-level CI | **13** |
| Ownership UNDETERMINED | **1** (`milosvasic.ru/Upstreamable`; also CLEAN, so no action either way) |

Note on the arithmetic: 2 + 1 + 13 = 16. `milosvasic.ru/Upstreamable` is counted
once, inside the 13 CLEAN repositories; its UNDETERMINED ownership is an
orthogonal attribute, not a fourth bucket.

## Repository 15 — `submodules/superspec`: why it is out of scope

This is the only case where an **active, root-level** workflow is being left in
place. The reasoning, stated as fact rather than assumption:

1. Its root-level CI is real and active. `submodules/superspec/.github/workflows/ci.yml`
   declares `on: push: branches: [main]` and `on: pull_request`. A push to
   *its* upstream would trigger a run.
2. The §11.4.156(C) test is **"does a push to one of OUR upstreams trigger a
   run?"** For this repository the answer is **no**, because it has no owned
   upstream: `git remote -v` reports exactly one remote, `origin`, fetch and
   push both `git@github.com:WangX0111/superspec.git`. There is no
   HelixDevelopment / vasic-digital / milosvasic remote configured on it.
3. The umbrella's own governance carrier corroborates this. `CLAUDE.md`
   ("Owned submodules") states: *"`submodules/superspec` is third-party
   (upstream `WangX0111/superspec`) and is outside the owned-submodule set for
   tagging and propagation purposes."*
4. The umbrella records this submodule as a **gitlink** (mode `160000`,
   `c20ac6c1ba069cc9a72dacb8044b7b193d3dde81`), i.e. a bare commit SHA. Pushing
   the umbrella to `github.com/milos85vasic/vasic` transmits the SHA, not the
   submodule's file tree, and GitHub Actions does not execute a submodule's
   workflows.

Therefore: **document and leave alone.** Editing it would be a §11.4.29 /
tree-integrity violation and would create a permanent diff against an upstream
we do not control.

**Honest boundary (§11.4.6):** items 1–4 are verified locally from the git
index, the remote configuration and the governance carrier. What was NOT
verified — because it requires network access this audit did not perform — is
whether the operator holds push credentials to `WangX0111/superspec`. If such a
push right exists and is ever exercised, this repository moves into scope. That
is recorded here rather than papered over.

## Non-root `.github/workflows` — verified inert, out of scope

Two distinct classes of non-root workflow exist in the tree. Both were checked
for the trap the rule warns about: a config that *looks* nested but is actually
sitting at some other repository's root. Neither is.

### (i) `.specify/extensions/superspec/.github/workflows/ci.yml` — TRACKED in the umbrella

This is the case that most deserves scrutiny, because it **is** tracked in a
repository we push (`git ls-files` in the umbrella returns it). It is
nevertheless inert. Verified facts:

- The umbrella's root is `/run/media/milosvasic/DATA4TB/Projects/vasic`
  (`git rev-parse --show-toplevel`). The file sits three directories below that
  root, at `.specify/extensions/superspec/.github/workflows/ci.yml`. GitHub
  Actions reads only `.github/workflows/` **relative to the repository root**.
- `.specify/extensions/superspec` is **not** a repository root. `git -C
  .specify/extensions/superspec rev-parse --show-toplevel` fails with
  `fatal: not a git repository`. It contains a stray `.git` **FILE** whose
  content is `gitdir: ../../.git/modules/submodules/superspec`, which resolves
  to `.specify/extensions/.git/modules/submodules/superspec` — a path that does
  not exist. It is a **broken gitlink**, left behind by the spec-kit extension
  installer that copied the superspec tree into place (see
  `.specify/extensions/.registry`, `"source": "local"`, installed
  `2026-08-26T18:34:15Z`).
- It is **not** a submodule of the umbrella: it does not appear in `.gitmodules`,
  and the umbrella index holds its 59 files as ordinary blobs (`git ls-files -s`
  shows modes `100644` / `100755` only — no `160000` gitlink for this path).
- The stray `.git` file is itself untracked (`git ls-files
  .specify/extensions/superspec/.git` returns nothing).
- No symlink aliases it up to the root: every `.github` and `workflows` path in
  the tree was tested with `-L` and all are real directories. The umbrella's
  root `.github/workflows` is a real directory containing exactly one entry.
- Content check: this file is **byte-identical** to
  `submodules/superspec/.github/workflows/ci.yml` (`cmp -s` reports identical).
  It is a vendored copy of the same third-party workflow.

**Conclusion: structurally inert, out of scope, MUST NOT be edited.** A push to
`github.com/milos85vasic/vasic` triggers zero runs from this file.

### (ii) `ai_interviewing/platform/frontend/node_modules/**` — untracked npm packages

**6** `.github/workflows` directories containing **9** workflow files, all under
`ai_interviewing/platform/frontend/node_modules/`:

| Package | Workflow files |
|---|---|
| `fast-uri` | `ci.yml`, `lock-threads.yml`, `package-manager-ci.yml` |
| `json-schema-traverse` | `build.yml`, `publish.yml` |
| `needle` | `nodejs.yml` |
| `reusify` | `ci.yml` |
| `rfdc` | `ci.yml` |
| `wildcard` | `build.yml` |

Doubly out of scope, both facts verified:

1. **Non-root.** They sit far below the `ai_interviewing` repository root
   (`git rev-parse --show-toplevel` = `.../vasic/ai_interviewing`), and none of
   the intervening directories is a repository — `find . -name .git` reports no
   `.git` anywhere under `node_modules`.
2. **Untracked.** `git -C ai_interviewing ls-files` matches **zero** CI paths at
   any depth. `git check-ignore -v` confirms the exclusion rule:
   `platform/frontend/.gitignore:10:/node_modules`. They are never transmitted
   by a push at all.

## Other CI providers — checked and absent

Each of the 16 repository roots was additionally checked, on disk, for
`Jenkinsfile`, `.circleci/`, `.travis.yml`, `.drone.yml`, `.woodpecker.yml`,
`.woodpecker/`, `bitbucket-pipelines.yml`, `azure-pipelines.yml`,
`.azure-pipelines/`, `.gitlab-ci.yml`, `.gitlab/`, `appveyor.yml` and
`.cirrus.yml`. Result: **NONE** at any of the 16 roots. GitHub Actions is the
only provider present anywhere in this tree.

`.specify/workflows/` exists at the umbrella but is a spec-kit workflow registry
(`workflow-registry.json` + a `speckit/` directory), not a CI provider path.

## Concurrent remediation observed in flight

Two other agents were editing CI files while this audit ran. Both transitions
were observed directly and are recorded rather than smoothed over, because the
inventory rows above would otherwise be unreproducible.

- **T0** (≈21:15–21:25 +02:00). Umbrella HEAD `f1e0c83`; probe returns
  `.github/workflows/ci.yml`; `git status --porcelain -- .github/workflows/`
  is empty (worktree matched HEAD). `milosvasic.ru` HEAD `66c8d60`; probe
  returns `.github/workflows/pages.yml`; status empty. **Both are §11.4.156(A)
  violations at this point.**
- **T1** (≈21:28 +02:00). Both probes return empty. On disk:
  `.github/workflows/ci.yml.disabled` (15164 bytes) and
  `milosvasic.ru/.github/workflows/pages.yml.disabled` (1333 bytes).
  `git status --porcelain` reports `RM .github/workflows/ci.yml ->
  .github/workflows/ci.yml.disabled` in the umbrella and
  `R  .github/workflows/pages.yml -> .github/workflows/pages.yml.disabled` in
  `milosvasic.ru`. Both HEADs unchanged — **the renames are STAGED, not
  committed, and not pushed.**

- **T2** (21:32:57 +02:00). A **new** file appeared in the umbrella index:
  `git status --porcelain -- .github` now reports
  `A  .github/workflows/zz-probe.yml` alongside the `ci.yml` rename, and the
  §11.4.156(E) probe consequently returns `.github/workflows/zz-probe.yml`
  again. Its full staged content is 121 bytes:

  ```yaml
  name: probe
  on:
    push:
      branches: [main]
  jobs:
    noop:
      runs-on: ubuntu-latest
      steps:
        - run: echo probe
  ```

  Read plainly, this is a §1.1 mutation-pair probe: a deliberately introduced
  active workflow whose purpose is to prove that a §11.4.156 gate FAILS when a
  root workflow reappears. This audit did not create it and did not remove it.

  Had it survived into a commit it would have been a live violation on two
  counts: `on: push: branches: [main]` is a real trigger, so a pushed
  `zz-probe.yml` breaches §11.4.156(A) (active CI at the root) and §11.4.156(D)
  (no new CI may be added), and it would have silently undone the `ci.yml`
  remediation staged beside it. It did not survive — see T3.

- **T3** (21:34:04 +02:00). `zz-probe.yml` is gone — removed from both the index
  and the working tree by whoever staged it, exactly as a mutation pair should
  end. `git status --porcelain -- .github` reports only
  `RM .github/workflows/ci.yml -> .github/workflows/ci.yml.disabled`; the
  §11.4.156(E) probe returns empty; `ls .github/workflows/` shows one entry,
  `ci.yml.disabled`. The T2 hazard is therefore **closed, not outstanding** —
  it is recorded above because a reader re-running the sweep between 21:32 and
  21:34 would otherwise get a result this table could not explain, and because
  §11.4.6 forbids omitting an observed state.

  A concurrent agent also staged `scripts/pre-push-gates.sh` (new file) during
  this window. This audit did not read or evaluate it; whether it implements
  the §11.4.156(E) pre-push check is outside what was verified here.

**Standing action at close of audit (21:34):** the umbrella and `milosvasic.ru`
each hold a STAGED, UNCOMMITTED `.disabled` rename. Neither is pushed. Until
push, both upstreams still serve an active workflow.

> **T4 (post-audit, same day) — the two diverged.** The umbrella's rename stands
> and awaits commit + push. **`milosvasic.ru`'s rename was reverted**:
> `.github/workflows/pages.yml` is back and ACTIVE (verified — submodule
> `git status` clean, `git diff HEAD` empty, YAML parses, `build` and `deploy`
> jobs intact), because it is the only thing that publishes the production site.
> Because that rename never reached a commit, **the live site was never
> interrupted**. See the banner at the head of this document.

The `.disabled` suffix is the §11.4.75 convention §11.4.156(B) explicitly
sanctions: GitHub Actions matches only `*.yml` / `*.yaml` under
`.github/workflows/`, so `ci.yml.disabled` ~~and `pages.yml.disabled`~~ is not a
workflow file. **Until the umbrella's rename is committed and pushed, its pushed
state still contains an active workflow and it remains non-compliant.**
Compliance is claimed for the umbrella only after push, verified by re-running
the §11.4.156(E) probe post-commit — and is **never** claimed for
`milosvasic.ru`, which is knowingly and permanently outside the clause.

This audit did not touch either file.

## Operator actions this audit cannot perform (§11.4.156 honest boundary)

File-level disabling stops FILE-triggered runs. It does not reach provider-side
server settings. For `milosvasic.ru` specifically, the file being disabled is
`pages.yml`, a **GitHub Pages deployment** workflow. Two consequences the
operator must decide on, neither of which an agent can action from the
filesystem:

1. ~~Disabling `pages.yml` removes the mechanism that publishes
   `milosvasic.ru`. GitHub may fall back to its built-in
   "pages build and deployment" action, which the file's own header comment
   says was replaced precisely because it fails on the broken
   `Upstreamable` nested gitlink. Whether Pages should be switched to a
   deploy-from-branch source, or turned off entirely, is an operator decision.~~
   **RESOLVED and REVERSED, same day.** The "may fall back" was the open question
   and it has been answered: `gh api repos/milos85vasic/milosvasic.ru/pages`
   returns **`build_type: "workflow"`** — there is **no** fallback. Pages
   delegates publishing entirely to `pages.yml`, and switching to a
   deploy-from-branch source is not available either, because the repository root
   is Jekyll SOURCE (Liquid + front matter) with no `gh-pages` branch and no
   `docs/` folder to serve. Disabling `pages.yml` would leave the production site
   with no publisher at all. **The operator decided: keep it.** *"Make sure all
   pages websites work flawlessly! No website can be broken! All websites we have
   here are running deployed in production!"* `pages.yml` is ACTIVE and stays
   active; `milosvasic.ru` is a documented deviation from §11.4.156, not an
   override.
2. Repository / organisation settings that no local file controls —
   org-default required workflows, branch-protection required checks, and
   provider-side scheduled exports — must be turned off in the provider UI.
   This audit did not and cannot verify their state.

3. **`vasic.digital` — a surface this inventory's probe structurally cannot
   see.** It is classified **(c) CLEAN** in the table because it has no root CI
   *file*, which is true. It is nevertheless **not compliant**: verified
   2026-08-27, `gh api repos/vasic-digital/vasic-digital.github.io/pages` returns
   `build_type: "legacy"`, and the Actions run list shows `pages build and
   deployment` (`dynamic/pages/pages-build-deployment`, event `dynamic`) on
   2026-08-27 and 2026-08-10. Every push starts a run **with zero workflow files
   in the tree**. Nothing in that repository can change this, and turning it off
   in the Pages UI would unpublish a production site. This is the general lesson
   of the §11.4.156 honest boundary made concrete: a file probe measures files,
   and "no file" is not "no runs".

Related open gap: `CLAUDE.md` records **G4** — "`.github/workflows/ci.yml` is
active at the repository root, which conflicts with anchor 11.4.156(A)". This
inventory is the evidence base for **the umbrella half** of G4; G4 is not closed
by this document, only by the committed-and-pushed umbrella rename plus a re-run
probe — and **G4 as a whole will not close at all**, because `milosvasic.ru` and
`vasic.digital` remain knowingly non-compliant by decision and by provider
mechanics respectively.

---

# Appendix A — raw per-repository command output

Every row in the table above is reproducible from the commands below. Run them
from `/run/media/milosvasic/DATA4TB/Projects/vasic`.

## A.0 — Enumeration

```console
$ git submodule status --recursive
 ed73d8558e289ca0254b4ccc45e0df810767d3ae ai_interviewing (heads/main)
 efd2c3fb2f880aaf2baf7f4819ce28a1ce3609cb design-toolkit (v0.2.2-6-gefd2c3f)
 66c8d607b20f0d9e984cb0e06f10a2020ebd9a10 milosvasic.ru (v1.8.0-6-g66c8d60)
 94f9831b8aa0a1d4df23671d2e4600886aad0dcf milosvasic.ru/Upstreamable (heads/main)
fatal: no submodule mapping found in .gitmodules for path 'Upstreamable'
fatal: failed to recurse into submodule 'Upstreamable'
fatal: failed to recurse into submodule 'milosvasic.ru'
```

Because the recursive walk aborts, enumeration used `find`:

```console
$ find . -name .git | sort
./ai_interviewing/.git
./design-toolkit/.git
./.git
./milosvasic.ru/.git
./milosvasic.ru/Upstreamable/.git
./monetization/.git
./.specify/extensions/superspec/.git      <-- NOT a repository; broken gitlink, see body
./submodules/constitution/.git
./submodules/constitution/submodules/anti_bluff/.git
./submodules/constitution/submodules/continuum/.git
./submodules/constitution/submodules/design-toolkit/.git
./submodules/constitution/submodules/docs_chain/.git
./submodules/constitution/submodules/helix_perf_cache/.git
./submodules/constitution/submodules/session_orchestrator/.git
./submodules/constitution/submodules/token_optimizer/.git
./submodules/superspec/.git
./vasic.digital/.git

$ find . -name .git > /dev/null; echo "rc=$?"
rc=0                                       # no permission-denied truncation

$ git worktree list
/run/media/milosvasic/DATA4TB/Projects/vasic  f1e0c83 [main]
```

`.git` kind per repository (`-e`, never `-d`):

```
.                                                     DIRECTORY
ai_interviewing                                       FILE -> gitdir: ../.git/modules/ai_interviewing
design-toolkit                                        FILE -> gitdir: ../.git/modules/design-toolkit
milosvasic.ru                                         FILE -> gitdir: ../.git/modules/milosvasic.ru
milosvasic.ru/Upstreamable                            FILE -> gitdir: ../../.git/modules/milosvasic.ru/modules/Upstreamable
monetization                                          FILE -> gitdir: ../.git/modules/monetization
.specify/extensions/superspec                         FILE -> gitdir: ../../.git/modules/submodules/superspec   (BROKEN — target does not exist)
submodules/constitution                               FILE -> gitdir: ../../.git/modules/submodules/constitution
submodules/constitution/submodules/anti_bluff         FILE -> gitdir: ../../../../.git/modules/submodules/constitution/modules/submodules/anti_bluff
submodules/constitution/submodules/continuum          FILE -> gitdir: ../../../../.git/modules/submodules/constitution/modules/submodules/continuum
submodules/constitution/submodules/design-toolkit     FILE -> gitdir: ../../../../.git/modules/submodules/constitution/modules/design-toolkit
submodules/constitution/submodules/docs_chain         FILE -> gitdir: ../../../../.git/modules/submodules/constitution/modules/submodules/docs_chain
submodules/constitution/submodules/helix_perf_cache   FILE -> gitdir: ../../../../.git/modules/submodules/constitution/modules/submodules/helix_perf_cache
submodules/constitution/submodules/session_orchestrator FILE -> gitdir: ../../../../.git/modules/submodules/constitution/modules/submodules/session_orchestrator
submodules/constitution/submodules/token_optimizer    FILE -> gitdir: ../../../../.git/modules/submodules/constitution/modules/submodules/token_optimizer
submodules/superspec                                  FILE -> gitdir: ../../.git/modules/submodules/superspec
vasic.digital                                         FILE -> gitdir: ../.git/modules/vasic.digital
```

## A.1 — `.` (umbrella)

```console
$ git -C . rev-parse --show-toplevel
/run/media/milosvasic/DATA4TB/Projects/vasic

$ git -C . remote -v
github  git@github.com:milos85vasic/vasic.git (fetch)
github  git@github.com:milos85vasic/vasic.git (push)
origin  git@github.com:milos85vasic/vasic.git (fetch)
origin  git@github.com:milos85vasic/vasic.git (push)
upstream        git@github.com:milos85vasic/vasic.git (fetch)
upstream        git@github.com:milos85vasic/vasic.git (push)

# T0 (~21:15)
$ git -C . ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
.github/workflows/ci.yml

$ sed -n '71,78p' .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

# T1 (~21:28) — concurrent agent staged the rename
$ git -C . ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
(no output)

$ git -C . status --porcelain -- .github
RM .github/workflows/ci.yml -> .github/workflows/ci.yml.disabled

$ ls -la .github/workflows
-rw-r--r-- 1 milosvasic milosvasic 15164 Aug 27 21:28 ci.yml.disabled
```

Non-root CI tracked in this repository:

```console
$ git -C . ls-files | grep -E '(^|/)\.github/workflows/.*\.ya?ml$|(^|/)\.gitlab-ci\.yml$|(^|/)\.gitlab/'
.specify/extensions/superspec/.github/workflows/ci.yml      # (T1; at T0 the root ci.yml also appeared)

$ git -C . ls-files -s | awk '$1=="160000"'
160000 ed73d8558e289ca0254b4ccc45e0df810767d3ae 0 ai_interviewing
160000 efd2c3fb2f880aaf2baf7f4819ce28a1ce3609cb 0 design-toolkit
160000 66c8d607b20f0d9e984cb0e06f10a2020ebd9a10 0 milosvasic.ru
160000 54ed7b0f5add52821d18866facb5ee8c75adef69 0 monetization
160000 902979027a907051dc036668a9c353bd27aedf47 0 submodules/constitution
160000 c20ac6c1ba069cc9a72dacb8044b7b193d3dde81 0 submodules/superspec
160000 6e5411c21b3cd9c6df5addb543b1a07930c3bfa9 0 vasic.digital
```

Note `.specify/extensions/superspec` is absent from the `160000` list — it is
tracked as ordinary blobs, not a gitlink.

## A.2 — `ai_interviewing`

```console
$ git -C ai_interviewing remote -v
github  git@github.com:milos85vasic/ai_interviewing.git (fetch)
github  git@github.com:milos85vasic/ai_interviewing.git (push)
origin  git@github.com:milos85vasic/ai_interviewing.git (fetch)
origin  git@github.com:milos85vasic/ai_interviewing.git (push)
upstream        git@github.com:milos85vasic/ai_interviewing.git (fetch)
upstream        git@github.com:milos85vasic/ai_interviewing.git (push)

$ git -C ai_interviewing ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
(no output)

# any depth, to prove node_modules workflows are untracked:
$ git -C ai_interviewing ls-files | grep -E '(^|/)\.github/workflows/'
(no output)

$ git -C ai_interviewing check-ignore -v platform/frontend/node_modules/needle/.github/workflows
platform/frontend/.gitignore:10:/node_modules    platform/frontend/node_modules/needle/.github/workflows
```

## A.3 — `design-toolkit`

```console
$ git -C design-toolkit remote -v
origin  git@github.com:vasic-digital/design-toolkit.git (fetch)
origin  git@github.com:vasic-digital/design-toolkit.git (push)

$ git -C design-toolkit ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
(no output)
```

## A.4 — `milosvasic.ru`

```console
$ git -C milosvasic.ru remote -v
gitflic git@gitflic.ru:milosvasic/milosvasic-net-v-2.git (fetch)
gitflic git@gitflic.ru:milosvasic/milosvasic-net-v-2.git (push)
github  git@github.com:milos85vasic/milosvasic.ru.git (fetch)
github  git@github.com:milos85vasic/milosvasic.ru.git (push)
origin  git@github.com:milos85vasic/milosvasic.ru.git (fetch)
origin  git@gitflic.ru:milosvasic/milosvasic-net-v-2.git (push)
origin  git@github.com:milos85vasic/milosvasic.ru.git (push)
upstream        git@gitflic.ru:milosvasic/milosvasic-net-v-2.git (fetch)
upstream        git@gitflic.ru:milosvasic/milosvasic-net-v-2.git (push)

# T0 (~21:15)
$ git -C milosvasic.ru ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
.github/workflows/pages.yml

$ git -C milosvasic.ru log -1 --format='%H %ad %s' --date=iso -- .github/workflows/pages.yml
fae3b2457900a6771949e1b2cb6bf930428031c9 2026-06-26 15:05:31 +0300 Add custom Pages workflow: submodules:false to fix broken Upstreamable gitlink
```

Trigger block of the T0 file (evidence it was ACTIVE, not `if: false`-neutered):

```yaml
name: Deploy Jekyll to GitHub Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
```

```console
# T1 (~21:28)
$ git -C milosvasic.ru ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
(no output)

$ git -C milosvasic.ru status --porcelain -- .github
R  .github/workflows/pages.yml -> .github/workflows/pages.yml.disabled

$ ls -la milosvasic.ru/.github/workflows
-rw-r--r-- 1 milosvasic milosvasic 1333 Aug 17 11:56 pages.yml.disabled
```

## A.5 — `milosvasic.ru/Upstreamable`

```console
$ git -C milosvasic.ru/Upstreamable remote -v
gitflic git@gitflic.ru:red-elf/upstreamable.git (fetch)
gitflic git@gitflic.ru:red-elf/upstreamable.git (push)
github  git@github.com:red-elf/Upstreamable.git (fetch)
github  git@github.com:red-elf/Upstreamable.git (push)
origin  git@github.com:red-elf/Upstreamable.git (fetch)
origin  git@gitflic.ru:red-elf/upstreamable.git (push)
origin  git@github.com:red-elf/Upstreamable.git (push)
upstream        git@gitflic.ru:red-elf/upstreamable.git (fetch)
upstream        git@gitflic.ru:red-elf/upstreamable.git (push)

$ git -C milosvasic.ru/Upstreamable ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
(no output)
```

Ownership evidence searched and NOT found — hence UNDETERMINED, not guessed:

```console
$ grep -rn 'red-elf\|Upstreamable' README.md CLAUDE.md
README.md:36:# (red-elf/Upstreamable) whose own .gitmodules is a broken 0-byte gitlink, so a
CLAUDE.md:175:  `commit` resolves on PATH to `$SUBMODULES_HOME/Upstreamable/commit`, which
```

Neither line asserts ownership of the `red-elf` namespace, and `red-elf` is
absent from `CLAUDE.md`'s "Owned submodules" list.

## A.6 — `monetization`

```console
$ git -C monetization remote -v
gitflic git@gitflic.ru:milosvasic/monetization.git (fetch/push)
github  git@github.com:milos85vasic/monetization.git (fetch/push)
gitlab  git@gitlab.com:milos85vasic/monetization.git (fetch/push)
gitverse ssh://git@gitverse.ru:2222/milosvasic/monetization.git (fetch/push)
origin  git@github.com:milos85vasic/monetization.git (fetch)
origin  git@gitflic.ru:milosvasic/monetization.git (push)
origin  git@github.com:milos85vasic/monetization.git (push)
origin  git@gitlab.com:milos85vasic/monetization.git (push)
origin  ssh://git@gitverse.ru:2222/milosvasic/monetization.git (push)
upstream        git@gitflic.ru:milosvasic/monetization.git (fetch/push)

$ git -C monetization ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
(no output)
```

## A.7 — `submodules/constitution`

```console
$ git -C submodules/constitution remote -v
gitflic git@gitflic.ru:helixdevelopment/helixconstitution.git (fetch/push)
github  git@github.com:HelixDevelopment/HelixConstitution.git (fetch/push)
gitlab  git@gitlab.com:helixdevelopment1/helixconstitution.git (fetch/push)
gitverse        git@gitverse.ru:helixdevelopment/HelixConstitution.git (fetch/push)
origin  git@github.com:HelixDevelopment/HelixConstitution.git (fetch)
origin  git@gitflic.ru:helixdevelopment/helixconstitution.git (push)
origin  git@github.com:HelixDevelopment/HelixConstitution.git (push)
origin  git@gitlab.com:helixdevelopment1/helixconstitution.git (push)
origin  git@gitverse.ru:helixdevelopment/HelixConstitution.git (push)
origin  git@github.com:vasic-digital/HelixConstitution.git (push)
origin  git@gitlab.com:vasic-digital/HelixConstitution.git (push)
upstream        git@gitflic.ru:helixdevelopment/helixconstitution.git (fetch/push)
vasic_digital_github    git@github.com:vasic-digital/HelixConstitution.git (fetch/push)
vasic_digital_gitlab    git@gitlab.com:vasic-digital/HelixConstitution.git (fetch/push)

$ git -C submodules/constitution ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
(no output)
```

This is the §11.4.75 posture already in effect: the constitution repo's own
compliance workflow is preserved under a non-active name and therefore does not
appear in the probe.

## A.8–A.14 — constitution's nested submodules

```console
$ git -C submodules/constitution/submodules/anti_bluff remote -v
origin  git@github.com:vasic-digital/anti_bluff.git (fetch/push)

$ git -C submodules/constitution/submodules/continuum remote -v
origin  git@github.com:vasic-digital/continuum.git (fetch/push)

$ git -C submodules/constitution/submodules/design-toolkit remote -v
origin  git@github.com:vasic-digital/design-toolkit.git (fetch/push)

$ git -C submodules/constitution/submodules/docs_chain remote -v
github  git@github.com:vasic-digital/docs_chain.git (fetch/push)
gitlab  git@gitlab.com:vasic-digital/docs_chain.git (fetch/push)
origin  git@github.com:vasic-digital/docs_chain.git (fetch)
origin  git@github.com:vasic-digital/docs_chain.git (push)
origin  git@gitlab.com:vasic-digital/docs_chain.git (push)
upstream        git@github.com:vasic-digital/docs_chain.git (fetch/push)

$ git -C submodules/constitution/submodules/helix_perf_cache remote -v
origin  git@github.com:HelixDevelopment/helix_perf_cache.git (fetch/push)

$ git -C submodules/constitution/submodules/session_orchestrator remote -v
origin  git@github.com:vasic-digital/session_orchestrator.git (fetch/push)

$ git -C submodules/constitution/submodules/token_optimizer remote -v
origin  git@github.com:vasic-digital/token_optimizer.git (fetch/push)
```

Probe result for all seven:

```console
$ for p in anti_bluff continuum design-toolkit docs_chain helix_perf_cache \
           session_orchestrator token_optimizer; do
    echo "--- $p"
    git -C submodules/constitution/submodules/$p ls-files \
      | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
  done
--- anti_bluff
--- continuum
--- design-toolkit
--- docs_chain
--- helix_perf_cache
--- session_orchestrator
--- token_optimizer
```

All empty.

## A.15 — `submodules/superspec` (THIRD-PARTY — DO NOT EDIT)

```console
$ git -C submodules/superspec rev-parse --show-toplevel
/run/media/milosvasic/DATA4TB/Projects/vasic/submodules/superspec

$ git -C submodules/superspec remote -v
origin  git@github.com:WangX0111/superspec.git (fetch)
origin  git@github.com:WangX0111/superspec.git (push)

$ git -C submodules/superspec ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
.github/workflows/ci.yml
```

Its trigger block (active — recorded for completeness, NOT to be edited):

```yaml
name: CI

on:
  push:
    branches:
      - main
  pull_request:
```

Identity with the vendored copy in `.specify`:

```console
$ cmp -s submodules/superspec/.github/workflows/ci.yml \
         .specify/extensions/superspec/.github/workflows/ci.yml && echo IDENTICAL
IDENTICAL
```

## A.16 — `vasic.digital`

```console
$ git -C vasic.digital remote -v
github  git@github.com:vasic-digital/vasic-digital.github.io.git (fetch/push)
origin  git@github.com:vasic-digital/vasic-digital.github.io.git (fetch/push)
upstream        git@github.com:vasic-digital/vasic-digital.github.io.git (fetch/push)

$ git -C vasic.digital ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/'
(no output)
```

---

# Appendix B — non-root inertness verification

```console
$ git -C . rev-parse --show-toplevel
/run/media/milosvasic/DATA4TB/Projects/vasic

$ git -C .specify/extensions/superspec rev-parse --show-toplevel
fatal: not a git repository: /run/media/milosvasic/DATA4TB/Projects/vasic/.specify/extensions/superspec/../../.git/modules/submodules/superspec

$ cat .specify/extensions/superspec/.git
gitdir: ../../.git/modules/submodules/superspec        # resolves to a path that does not exist

$ git ls-files .specify/extensions/superspec/.git
(no output — the stray .git file is untracked)

$ git ls-files .specify/extensions/superspec | wc -l
59

$ git ls-files -s .specify/extensions/superspec | awk '{print $1}' | sort -u
100644
100755            # ordinary blobs only — no 160000 gitlink

$ grep -n 'superspec' .gitmodules      # .specify path is NOT registered as a submodule
19:[submodule "submodules/superspec"]
20:	path = submodules/superspec
21:	url = git@github.com:WangX0111/superspec.git
```

Three matching LINES describing exactly ONE registered submodule
(`submodules/superspec`). No `.gitmodules` stanza mentions
`.specify/extensions/superspec`. `grep -n` is used here rather than `grep -c`
precisely because `grep -c` would report `3` and invite the line-count-as-
thing-count error the closing note in Appendix C warns about.

Symlink check — every `.github` / `workflows` path in the tree, tested with `-L`:

```console
$ find . -path ./.git -prune -o -name '.github' -print -o -name 'workflows' -print \
  | while read -r f; do
      printf '%s : ' "$f"
      if [ -L "$f" ]; then echo "SYMLINK -> $(readlink "$f")"; else echo "real $(stat -c %F "$f")"; fi
    done
./.github : real directory
./.github/workflows : real directory
./milosvasic.ru/.github : real directory
./.specify/workflows : real directory
./milosvasic.ru/.github/workflows : real directory
./submodules/superspec/.github : real directory
./submodules/superspec/.github/workflows : real directory
./.specify/extensions/superspec/.github : real directory
./.specify/extensions/superspec/.github/workflows : real directory
... (remaining entries are all under ai_interviewing/platform/frontend/node_modules/, all "real directory")
```

Zero symlinks. No non-root workflow is aliased up to any repository root.

Complete on-disk census of workflow files (state at T1):

```console
$ find . -path ./.git -prune -o -type f -path '*/.github/workflows/*' -print | sed 's#^\./##' | sort
ai_interviewing/platform/frontend/node_modules/fast-uri/.github/workflows/ci.yml
ai_interviewing/platform/frontend/node_modules/fast-uri/.github/workflows/lock-threads.yml
ai_interviewing/platform/frontend/node_modules/fast-uri/.github/workflows/package-manager-ci.yml
ai_interviewing/platform/frontend/node_modules/json-schema-traverse/.github/workflows/build.yml
ai_interviewing/platform/frontend/node_modules/json-schema-traverse/.github/workflows/publish.yml
ai_interviewing/platform/frontend/node_modules/needle/.github/workflows/nodejs.yml
ai_interviewing/platform/frontend/node_modules/reusify/.github/workflows/ci.yml
ai_interviewing/platform/frontend/node_modules/rfdc/.github/workflows/ci.yml
ai_interviewing/platform/frontend/node_modules/wildcard/.github/workflows/build.yml
.github/workflows/ci.yml.disabled
milosvasic.ru/.github/workflows/pages.yml.disabled
.specify/extensions/superspec/.github/workflows/ci.yml
submodules/superspec/.github/workflows/ci.yml

$ find . -path ./.git -prune -o -type f -path '*/.github/workflows/*' -print | wc -l
13
$ find . -path ./.git -prune -o -type f -path '*/node_modules/*/.github/workflows/*' -print | wc -l
9
$ find . -path ./.git -prune -o -type d -path '*/node_modules/*' -name workflows -print | wc -l
6
```

13 files on disk = 9 untracked npm vendored + 2 already renamed `.disabled`
+ 1 vendored non-root tracked copy + 1 third-party repo root. At T1, zero
active, root-level, tracked workflow files remained in any repository we push —
**in the working tree**. Two of those (rows 1 and 4) were staged but not yet
committed or pushed.

**Transiently superseded at T2 (21:32:57), restored at T3 (21:34:04):** for
roughly 90 seconds a concurrent agent's mutation probe
`.github/workflows/zz-probe.yml` (121 bytes, live `on: push: branches: [main]`)
raised the on-disk total to 14 and returned the umbrella's §11.4.156(E) probe to
non-empty. It was removed from both index and working tree at T3, and the census
of 13 above is the state at close of audit. See "Concurrent remediation observed
in flight" for the full T2/T3 record.

---

# Appendix C — the exact re-runnable sweep

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
for p in . ai_interviewing design-toolkit milosvasic.ru milosvasic.ru/Upstreamable \
         monetization submodules/constitution \
         submodules/constitution/submodules/anti_bluff \
         submodules/constitution/submodules/continuum \
         submodules/constitution/submodules/design-toolkit \
         submodules/constitution/submodules/docs_chain \
         submodules/constitution/submodules/helix_perf_cache \
         submodules/constitution/submodules/session_orchestrator \
         submodules/constitution/submodules/token_optimizer \
         submodules/superspec vasic.digital; do
  out=$(git -C "$p" ls-files 2>/dev/null \
        | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^\.gitlab/')
  echo "--- $p : ${out:-NONE}"
done
```

Expected compliant output: `NONE` for all 16 rows except
`submodules/superspec`, which is permitted to report `.github/workflows/ci.yml`
under §11.4.156(C) because it is third-party and has no owned upstream.

**Counting caution:** these outputs are file paths, one per line, and the counts
in this document are counts of FILES, verified by listing them. `grep -c` counts
matching LINES and must not be used as a file count where a single file could
produce multiple matching lines.
