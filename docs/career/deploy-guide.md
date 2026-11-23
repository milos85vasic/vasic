# Deploy guide: `_tools/deploy-langs.sh`

| | |
|---|---|
| Purpose | Operator manual, guide and FAQ for publishing the two static sites (`vasic.digital`, `milosvasic.ru`) with `_tools/deploy-langs.sh`, as the script behaves on 2026-11-23 |
| Constitution | 11.4.257 (manual + guide + FAQ), 11.4.61 (metadata table + contents), 11.4.44 (revision header), 11.4.113 (never force-push), 11.4.151 (release-tag naming), 11.4.6 (no guessing) |
| Revision | 1 (2026-11-23). First version |
| Status | Draft for independent review (11.4.142) |
| Source of truth | `_tools/deploy-langs.sh` (header comments, `deploy_pathspecs`, `deploy_unrelated_dirty`, `build_gate`, live validation block). Read from the working tree, which may carry uncommitted changes to that file (diff-stat not quoted as current) |
| Not covered | Building the career PDFs (`site-build-guide.md`), the vault (`vault-guide.md`), workshop platform releases |

## Contents

1. [What a deploy does](#1-what-a-deploy-does)
2. [Before you run it: the safety rules](#2-before-you-run-it-the-safety-rules)
3. [Deploy-owned paths and the admin switch](#3-deploy-owned-paths-and-the-admin-switch)
4. [Environment switches](#4-environment-switches)
5. [Exit codes](#5-exit-codes)
6. [Self-tests that touch nothing](#6-self-tests-that-touch-nothing)
7. [Dry run: what it really does](#7-dry-run-what-it-really-does)
8. [Live validation after the push](#8-live-validation-after-the-push)
9. [Rollback](#9-rollback)
10. [Tags](#10-tags)
11. [What NOT to do](#11-what-not-to-do)
12. [FAQ and troubleshooting](#12-faq-and-troubleshooting)
13. [Verification record](#13-verification-record)

## 1. What a deploy does

`bash _tools/deploy-langs.sh` is one incremental cycle. In order:

1. Answers `--prove-*` self-tests, if asked, and exits (section 6).
2. **Pre-flight.** In each site submodule it lists every dirty path (staged, unstaged, untracked) that this deploy does not produce. If there is any, it aborts with exit 3 before building anything.
3. Counts source documents and decides which languages are COMPLETE (every source doc has a PASS review verdict in `_tests/evidence/translate-new/<lang>/`).
4. Builds the generator (`_tools/gen`, `go build`) with the footer year pinned (from `SOURCE_DATE_EPOCH`, else the year of the last commit, else the current year).
5. Syncs assets and regenerates English (`_tools/gen/build.sh --lang en --no-jekyll`), then regenerates every COMPLETE language into both sites.
6. Builds PDFs when `weasyprint` and `pandoc` are both present; otherwise prints a skip line (`_tools/pdf/build-pdfs.sh`).
7. Rebuilds the Jekyll `_site` for `milosvasic.ru`: host `jekyll`, else `bundle exec jekyll`, else the container build `_tools/containers/bin/site-build` (about 9 minutes, needs rootless podman, see `site-build-guide.md`).
8. **Build gate** (section 5). A required step that ran and failed aborts with 5; one that could not run aborts with 2.
9. Without `--dry-run`, per site: refuses unless HEAD is the symbolic ref `refs/heads/main` (a detached HEAD or another branch is refused) and local `main` has no commit that `origin/main` lacks (anything unpushed was not made by this deploy); stages only the deploy-owned paths; runs `git diff --cached --name-only -z` and aborts the site (exit 4, nothing committed) if any staged path is outside the whitelist or is a gitlink; commits; and pushes the exact new commit as `<sha>:refs/heads/main` to `origin` only. Other remotes need an explicit allow-list, `DEPLOY_PUSH_REMOTES='origin gitlab'`. The remote-tracking ref `refs/remotes/<remote>/main` is read as is, with no fetch, so run `git fetch` in a site first if it is stale.
10. Waits for GitHub Pages (120 s by default), checks both origins answer, and runs the live Playwright suite against production.

`bash _tools/deploy-langs.sh --help` prints usage and exits 0 with no side effects. Every argument is validated **before** `--help` is honoured, so `--help --typo` exits 2. Unknown arguments exit 2 (usage on stderr), at most one `--prove-*` is accepted, and a `--prove-*` cannot be combined with `--dry-run` or `-n` (exit 2). With no argument the script is a real deploy.

## 2. Before you run it: the safety rules

* Both sites are live production. Commit your unrelated work first; the pre-flight refuses a dirty tree on purpose.
* Never force-push (11.4.113), never `--no-verify`, never rewrite published history.
* Never rename, disable or "fix" `milosvasic.ru/.github/workflows/pages.yml`. It is the sole publish path of that site (provider setting `build_type: workflow`).
* The commit message the script writes is `i18n: localized pages + PDFs - languages [...]`. No co-author trailer is added unless `DEPLOY_COAUTHOR='<full trailer line>'` is set.
* The script cannot run in the background safely: the live-validation step sleeps 120 s and then runs a browser suite.

## 3. Deploy-owned paths and the admin switch

Staging is scoped to the paths this script produces (function `deploy_pathspecs`). Anything else dirty makes the pre-flight abort.

Deploy-owned, for each site: `index.html`, `sitemap.xml`, `robots.txt`, `products/`, `portfolio/`, `assets/od/`, `downloads/` and every language directory (`ru sr de es fr be zh kk hi ja ko ar tr fa`). A path is listed only if it exists on disk or is known to the index.

Added on 2026-11-23 for `milosvasic.ru` (the expertise section):

| Path | Why |
|---|---|
| `expertise/` | The expertise hub and area pages; all in `sitemap.xml` and crawled by the live link-integrity spec |
| `expertise_localized.json` | Generator source data read by `_tools/career/expertise_pages.py`; ships with the pages it renders. Jekyll also copies it to the site as a static file (no `exclude:` entry), a decision for the site owner |
| `assets/og/` | OG images those pages name in front matter |
| `_data/ui.json` | Carries `nav.expertise`, used by the shared nav |
| `_layouts/default.html` | Renders `data-area` and the Expertise nav link |

Without those, a real run aborted at pre-flight over its own output (exit 3), and `DEPLOY_ALLOW_UNRELATED=1` would have published a partial, inconsistent subset.

**Never owned**, and so reported as unrelated if dirty: `_site/**` (build artifact, untracked since operator decision #13), `articles/`, `_article_src/`, `pages/`, the rest of `_data/` and `_layouts/`, `docs/`, `Gemfile*`, `CNAME`, governance carriers, nested submodules (a nested gitlink is reported even under an owned prefix).

### 3.1 `DEPLOY_INCLUDE_ADMIN` (default OFF)

Held back by default (all five): `admin/`, `assets/js/vault.js`, `assets/js/vault-console.js`, `_layouts/admin_console.html` and `downloads/vault/`. `downloads` stays owned, but `downloads/vault` is carved out with a git `:(exclude)` pathspec.

The `:(exclude)downloads/vault` pathspec is emitted whenever the flag is not `1`, without testing that the directory exists (git accepts an exclude that matches nothing while another positive pathspec is present), so a tracked vault deleted from disk never has its deletion staged (`--prove-deploy-scope` P6, mutant M11).

`DEPLOY_INCLUDE_ADMIN=1` adds `admin/`, `assets/js/vault.js`, `assets/js/vault-console.js` and `_layouts/admin_console.html` to the owned list and drops the `downloads/vault` carve-out so that `downloads/vault/` is published too (all five paths). Only the literal `1` enables it; `0`, empty, `yes`, `true` and `01` do not (proved by `--prove-deploy-scope`, assertion P3b).

Consequences, stated plainly:

* With the flag unset, a dirty or untracked copy of those files is not silently skipped. The pre-flight reports it as `held back - admin/vault surface; set DEPLOY_INCLUDE_ADMIN=1 to publish it` and aborts with exit 3 (it is still "dirty and not published"). Commit or stash it, or deploy with the flag.
* `assets/js/vault-console.js` and `_layouts/admin_console.html` are part of the admin set and are held back the same way.
* `DEPLOY_ALLOW_UNRELATED=1` does **not** lift this. The admin/vault surface and nested gitlinks are hard blocks (exit 3 even with the override, `--prove-deploy-scope` P8).
* Whether an admin console and sealed vault files belong on a public Pages site is the operator's decision. The script does not make it.

## 4. Environment switches

All are literal-`1` unless noted.

| Variable | Effect |
|---|---|
| `DEPLOY_INCLUDE_ADMIN=1` | Publish `admin/`, `assets/js/vault.js`, `assets/js/vault-console.js`, `_layouts/admin_console.html`, `downloads/vault/` (section 3.1) |
| `DEPLOY_ALLOW_UNRELATED=1` | Proceed despite unrelated unstaged or untracked paths. Never lifts the hard blocks (admin/vault surface, nested gitlinks). Staging stays scoped, and a path already staged outside the whitelist aborts that site before the commit (exit 4, P7). Read every listed path first |
| `DEPLOY_PUSH_REMOTES='<names>'` | Push allow-list, space separated. Default `origin` only |
| `DEPLOY_TOLERATE_BUILD_FAILURE=1` | Pardon fatal build steps (prints a loud banner naming each one) |
| `DRY_RUN=1`, `--dry-run`, `-n` | No stage, no commit, no push. It still rewrites the working trees (section 7) |
| `SKIP_LIVE_VALIDATE=1` | Skip the live suite. The run says "This is not a PASS" |
| `LIVE_VALIDATE_GRACE` (seconds, default 120) | Wait for Pages before validating |
| `LIVE_PROBE_TIMEOUT` (seconds, default 20) | Per-attempt origin probe timeout |
| `SOURCE_DATE_EPOCH` | Pins the footer year |

## 5. Exit codes

From the script header and the end of the script.

| Code | Meaning |
|---|---|
| 0 | Cycle completed; live validation passed or was explicitly skipped. A dry run also ends 0 |
| 1 | Deployed, and the live suite ran, reached production and asserted a real defect (broken link or shipped-state regression). Act on the sites. (Also: `gen build failed`) |
| 2 | Could not determine, never a pass. Either a required build step could not run (`BUILD-GATE undetermined`; nothing staged or pushed), or deployed but live validation reached no verdict (missing `node_modules`, browser, spec, `npx`, or the network was down) |
| 3 | **Pre-flight abort.** Unrelated changes in a site submodule. Nothing built, staged, committed, pushed or un-staged. In `--dry-run` the same condition prints "a real deploy WOULD ABORT here (exit 3)" and the preview continues |
| 4 | The publish failed (staging error, commit rejected, no push remote, push rejected). Live validation is skipped on purpose |
| 5 | A required build step ran and failed (`en gen`, `pdf en`, jekyll rebuild). Nothing staged or pushed. 5 outranks 2 |

Tolerated steps (`gen <lang>`, `pdf <lang>`) only produce a NOTE; the previous generation of that language is republished.

## 6. Self-tests that touch nothing

They return before any build, staging, commit or push.

```text
$ bash _tools/deploy-langs.sh --prove-deploy-scope
DEPLOY-SCOPE §1.1 PAIRED MUTATION PROOF - deploy_pathspecs / deploy_unrelated_dirty
P1 expertise-owned     expertise/, assets/og/, _data/ui.json, _layouts/default.html not reported
P2 admin-held-back     admin/, vault.js, vault-console.js, admin_console.html, downloads/vault/ reported and labelled DEPLOY_INCLUDE_ADMIN
P3 flag-honoured       DEPLOY_INCLUDE_ADMIN=1 owns admin/, vault.js, vault-console.js, admin_console.html, downloads/vault/
P3b flag-strictness    only the literal '1' enables it (0, empty, yes, true, 01 do not)
P4 still-refuses       docs/BUILD.md and notes.txt stay unrelated even with the flag
P5 staging-scope       expertise staged; vault, admin, docs, notes not staged
M7 mutant-is-caught    the historical whitelist reports expertise/ UNRELATED (the real-run abort): P1 discriminates
deploy-scope §1.1 MUTATION PROOF: PASS - 30 assertions incl. mutants M7, M8, M11-M16.   # rc 0
(P6-P11 cover: deleted tracked vault, pre-staged admin/ under the override, hard blocks, rename sides, branch and unpushed guard, expertise_localized.json.)

$ bash _tools/deploy-langs.sh --prove-build-fatality
M1 ran-and-failed  M2 could-not-run  M3 tolerated-only  M4 precedence  M5 override-honoured
M5b override-strictness  M6 mutant-is-caught
build_gate §1.1 MUTATION PROOF: PASS - 7 assertions, including the precedence claim (M4) ...   # rc 0

$ bash _tools/deploy-langs.sh --prove-buildyear
B2 epoch-1700000000  B1 adversarial-cwd  B3 garbage-input  B4 bsd-contract (SIM)
portable_epoch_year §1.1 MUTATION PROOF: PASS - 6 assertions ...                # rc 0
```

(Lines are abridged to the check names; each assertion printed a check mark and its message when run. B4 is a simulation of BSD `date`, not a measurement on a BSD host, as the script itself says.) Run them after editing the script.

## 7. Dry run: what it really does

`--dry-run` skips only staging, the commit and the push. Everything before that still executes, so **a dry run is not read-only**. It:

* runs `go build` for the generator (writes `_tools/gen/gen`);
* runs `_tools/gen/build.sh --lang en --no-jekyll`, which syncs `assets/od/**` and **rewrites `sitemap.xml`** and generated pages in both sites;
* regenerates every COMPLETE language into both sites;
* rebuilds PDFs into `downloads/` when `weasyprint` and `pandoc` are present;
* writes a temporary `milosvasic.ru/_config.deploy.yml` (removed afterwards) and rebuilds `milosvasic.ru/_site` through the container build when there is no host jekyll (about 9 minutes);
* then prints, per site, `WOULD commit+push` with a `git status` preview limited to the deploy-owned paths, or `no change (would not push)`.

So after a dry run the working tree is dirty with generated output. This is why `git status` in `milosvasic.ru` already showed modified `sitemap.xml` and `assets/od/milosvasic.css` on 2026-11-23. A dry run still enforces the build gate (exit 5 or 2 on a failed or impossible build) and does not run live validation.

Not executed here: a dry run on this checkout would rewrite the live trees and start a 9-minute container build while other work on PDFs and generators is in flight.

## 8. Live validation after the push

After a successful push the script waits `LIVE_VALIDATE_GRACE` seconds, probes `https://<domain>/` of both sites (3 attempts each), then runs

```bash
(cd _tests && npx playwright test --config=playwright.live.config.js)
```

with `VD_BASE`, `MV_BASE`, `VASIC_BASE`, `MILOS_BASE` pointed at production. Specs run: `all-languages-link-integrity`, `restyle-seo-regression`, `v170-fixes`, `v171-hardcoding` (read-only, chromium). Domains come from `vasic.digital/CNAME` and `milosvasic.ru/_site/CNAME` (else `milosvasic.ru/CNAME`).

The result is classified: PASS (exit 0), FAIL (exit 1: real assertion failures), or UNVERIFIED (exit 2: toolchain missing, or every failure is a transport fault). Re-run validation alone, with no deploy:

```bash
(cd _tests && npx playwright test --config=playwright.live.config.js)
```

Not executed here: it targets production and depends on the network. Needs `_tests/node_modules` (`npm ci`) and a Playwright chromium.

The new expertise pages are in the sitemap and so are crawled by the link-integrity spec. A 404 there means the page was not published (check section 3).

## 9. Rollback

There is no rollback command in the script. A deploy is a normal commit in each site submodule, pushed to its remotes. Roll back by adding a commit that undoes it, never by rewriting history.

```bash
git -C milosvasic.ru log --oneline -5            # find the deploy commit
git -C milosvasic.ru revert <deploy-commit>      # new commit; history untouched
git -C milosvasic.ru push <remote> main          # fast-forward, to each remote the script used
# same for vasic.digital if it also published
```

Then update the umbrella gitlink pointers (a normal umbrella commit) and re-run the live suite (section 8). For `milosvasic.ru`, GitHub Pages rebuilds from the pushed commit through `pages.yml`, so the revert goes live only after that workflow finishes. Not executed here: the command forms are standard git; no deploy was made.

If the sealed vault was published by mistake, reverting removes it from the served site but not from git history or from anyone who fetched it. See `vault-guide.md`.

## 10. Tags

Tag naming is governed by 11.4.151 and the procedure in `docs/releases/ADDING-A-RELEASE.md`. Do not invent a name. The options that exist in this repository (`git tag`, 2026-11-23):

| Option | Form | When |
|---|---|---|
| Development release of the platform | `<prefix>-1.0.0-dev-0.0.N`, annotated. Prefix from `bash submodules/constitution/scripts/release_prefix.sh` (prints `vasic`). N is the next number taken from the **remote** tag list, not the local one. Existing: `vasic-1.0.0-dev-0.0.1` to `vasic-1.0.0-dev-0.0.7` | A numbered release cut with `ADDING-A-RELEASE.md` (workshop-centred: build once, verdict, back up, promote, tag at the umbrella and each owned submodule) |
| Site release tags (historical) | `v1.7.1`, `v1.7.2`, `v1.8.0`, plus `pre-restyle` | Used for earlier site releases. Whether to continue the `vN.N.N` line is an operator decision; the procedure document does not cover it |
| No tag | none | A routine content deploy |

`ADDING-A-RELEASE.md` is the authority; do not tag a site deploy by hand until you have read it.

## 11. What NOT to do

* Never force-push, never `--force-with-lease`, never rewrite history (11.4.113).
* Never `git commit` or `git push` with `--no-verify`.
* Never touch `milosvasic.ru/.github/workflows/pages.yml`.
* Never "fix" an exit 3 with `git add -A` or `git stash` of someone else's work. Read each reported path first.
* Never set `DEPLOY_ALLOW_UNRELATED=1` or `DEPLOY_TOLERATE_BUILD_FAILURE=1` to get past a red result you have not understood.
* Never run the script with NO argument unless you mean to deploy: no argument is a real deploy. `--help` is safe (exit 0, no side effects).
* Never publish `downloads/vault/` or `admin/` by accident: they ship only with `DEPLOY_INCLUDE_ADMIN=1`.
* Never put secrets in a commit; `_secure/` stays ignored.

## 12. FAQ and troubleshooting

**It aborted with exit 3 and listed paths.** Those paths are dirty and not produced by this deploy. Commit, stash or revert them inside the named submodule, or, for the admin files, decide whether to use `DEPLOY_INCLUDE_ADMIN=1`.

**Exit 3 names `assets/js/vault-console.js` or `_layouts/admin_console.html`.** They are held back by default and published only with `DEPLOY_INCLUDE_ADMIN=1` (section 3.1). Either commit or stash them, or deploy with the flag.

**Exit 2 with `BUILD-GATE undetermined`.** A required toolchain could not run (for example no jekyll and no usable container runtime). Nothing was published. Fix the toolchain; do not read it as a site defect.

**Exit 5.** A required step ran and failed. Read the log lines above the abort.

**Exit 4.** Publish failed. Live validation was skipped on purpose. Read the `ERROR` lines for the site and remote.

**Exit 1 after a successful push.** The live suite found a real problem on production. Fix content or generator and redeploy.

**Exit 2 after a successful push.** Nothing was verified (network or toolchain). Re-run validation alone (section 8).

**Is `_site` committed?** No. Production rebuilds it from source through `pages.yml`; the local rebuild exists for local tests.

**Why does the dry run take so long?** It performs the full build (section 7).

## 13. Verification record

Executed on 2026-11-23:

| Command | Result |
|---|---|
| `bash _tools/deploy-langs.sh --prove-deploy-scope` | rc 0, 30 assertions PASS incl. mutants M7, M8, M11-M16 |
| `bash _tools/deploy-langs.sh --prove-args` | rc 0, 23 assertions PASS incl. mutants M9, M9b, M9c, M10, M10b |
| `bash _tools/deploy-langs.sh --prove-build-fatality` | rc 0, 7 assertions PASS |
| `bash _tools/deploy-langs.sh --prove-buildyear` | rc 0, 6 assertions PASS |
| `git tag`, `ls docs/releases` | tag list as in section 10 |

Read from the script, not executed: pre-flight abort text, exit 4 paths, live validation classification, commit message and trailer, the staging and push loop.

Not executed, with reasons:

| Item | Reason |
|---|---|
| `bash _tools/deploy-langs.sh` (real) and `--dry-run` | Rewrites the live trees, 9-minute container build, and a real run publishes to production |
| `_tests` live suite | Targets production over the network |
| `git revert` rollback | No deploy to roll back |
| `release_prefix.sh` | The prefix `vasic` is quoted from `ADDING-A-RELEASE.md` section 2, which records it as checked on 2026-10-20 |
