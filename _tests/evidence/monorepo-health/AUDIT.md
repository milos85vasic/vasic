# Vasic Monorepo — Health & Consistency Audit (READ-ONLY)

- **Date:** 2026-08-07
- **Mode:** Read-only. No source edits, commits, pushes, generator or deploy runs. Only `git` read ops, `curl`, and this evidence file were produced.
- **Caveat (concurrent deploy):** A `deploy-langs.sh` (v1.6.0 re-style) was **actively running during this audit**. It mutated the `vasic.digital/` and `milosvasic.ru/` submodule working trees and **pushed `v1.6.0` tags + advanced `main` mid-audit** (v1.6.0 tags were absent on the first `ls-remote` pass and present ~minutes later). Findings below rely on **stable** data (remote refs, tags, recorded gitlinks); dynamic/in-flight items are timestamped and labelled.
- **Scope:** umbrella `/Volumes/T7/Projects/vasic`, `vasic.digital`, `milosvasic.ru`, `submodules/constitution`, `design-toolkit`. (`design-system/` is a **tracked subdirectory of the umbrella**, not a submodule — see Loose Ends.)

---

## PASS / FLAG / UNVERIFIED summary

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | Umbrella remote sync | **PASS** | branch `feat/content-generator` HEAD `a48554e` == `origin/refs/heads/feat/content-generator` `a48554e` |
| 1 | vasic.digital remote sync | **PASS** (caught up mid-audit) | local `main` now `d87a1d6` == origin/github/gitlab `main` `d87a1d6`. Was `e2f85bc` (behind) early in audit before deploy advanced it |
| 1 | milosvasic.ru remote sync | **PASS** (caught up mid-audit) | local `main` now `8324f27` == origin/github/gitlab/gitflic `main` `8324f27`. Was `1f2b605` (behind) early in audit |
| 1 | milosvasic.ru `origin` remote config | **FLAG** | `origin` has **split fetch/push URLs**: fetch=`github.com/milos85vasic/milosvasic.ru`, push=`gitflic.ru/...` **and** `github.com/...net.v2` (two push URLs). Non-standard; verify intentional |
| 1 | constitution remote sync | **PASS** | `main` `38c9825` == `origin/main` `38c9825` |
| 1 | design-toolkit remote sync | **PASS** | `main` `74a037f` == origin+gitlab `main` `74a037f` |
| 2 | Release/pre-restyle tags present | **PASS** (w/ flag) | Full matrix below. `v1.6.0` pushed to both sites during audit |
| 2 | milosvasic.ru `gitflic` mirror tag parity | **FLAG** | gitflic is **missing `v0.9.0-baseline` and `v1.0.0`** tags that github+gitlab carry |
| 3 | design-toolkit gitlink reachable | **PASS** | umbrella records `74a037f` = remote `main` tip & `v0.2.1^{}` → reachable, not dangling |
| 3 | constitution gitlink reachable | **PASS** | umbrella records `38c9825` = remote `main` tip → reachable, not dangling |
| 3 | Site submodule pointers current | **FLAG** (deploy-in-progress) | umbrella still records `milosvasic.ru=00794fb` (v1.5.1) & `vasic.digital=e2f85bc` (v1.5.0/pre-restyle); both reachable but **stale** — sites advanced to v1.6.0, umbrella bump not yet committed |
| 4 | Constitution §11.4.236 + §11.4.237 | **PASS** | On `origin/main:Constitution.md`: §11.4.236 ×2, §11.4.237 ×4 |
| 4 | design-toolkit nested in constitution `.gitmodules` | **PASS** | `origin/main:.gitmodules` has `[submodule "design-toolkit"]` → `github.com:vasic-digital/design-toolkit.git` |
| 5 | vasic.digital live | **PASS** | `HTTP 200`, 47384 B, `server: GitHub.com` |
| 5 | milosvasic.ru live | **PASS** | `HTTP 200`, 38193 B, `server: GitHub.com`, `generator content="Jekyll v4.4.1"` |
| 5 | Re-style (v1.6.0) live? | **UNVERIFIED** (expected — deploy in flight) | Both roots `last-modified: Fri, 07 Aug 2026 14:50:15 GMT`, **unchanged** before & after the v1.6.0 push → Pages not yet rebuilt with re-style. Not asserted live |
| 6 | umbrella secrets .gitignore | **PASS** | ignores `.mcp.json`, `.env`, `*.env`, `.env.*`, `api_keys.sh`, `**/api_keys.sh`, `secrets.sh` |
| 6 | constitution secrets .gitignore | **PASS** (minor) | ignores `.env`/`.env.*`/`*.env` (whitelists `.env.example`). `.mcp.json` **not** listed; a tracked `plugins/scheduled-work/.mcp.json` exists (0 real secrets inside) |
| 6 | vasic.digital secrets .gitignore | **FLAG** | **No `.gitignore` tracked at all** — no repo-level secret coverage |
| 6 | design-toolkit secrets .gitignore | **FLAG** | **No `.gitignore` tracked at all** — no repo-level secret coverage |
| 6 | milosvasic.ru secrets .gitignore | **FLAG** | `.gitignore` present but `.env` line is **commented out** (`# .env`); no `.mcp.json`/`api_keys` coverage |
| 6 | Leaked real secrets (all repos) | **PASS** | 0 real key matches. Only hit = `submodules/constitution/scripts/hooks/test_credential_scan_lib.sh` (a credential-scanner **test fixture**, by-design sample patterns). No secret values printed |
| 7 | Stale/forgotten uncommitted work | **PASS** | Only the umbrella tree is dirty, and every change is re-style-related (see Loose Ends). Sites/constitution/design-toolkit trees clean |
| 7 | Untracked large files (>5MB) | **PASS** | None found in umbrella working tree |
| 7 | Detached-HEAD submodules | **PASS** | All submodules on `main`; umbrella on `feat/content-generator` (intentional restyle branch) |

---

## 1. Repos & remotes

| Repo | Branch | HEAD (stable) | Remotes (excl. `upstream`) | Local==remote? |
|------|--------|---------------|----------------------------|----------------|
| umbrella | `feat/content-generator` | `a48554e` | `origin`,`github` = `github.com:milos85vasic/vasic.git` | **YES** (`feat` tip matches). `origin/main`=`a98ad77`; feat is 8 ahead / 0 behind main |
| vasic.digital | `main` | `d87a1d6` (post-deploy) | `origin`,`github`=`github.com:vasic-digital/vasic-digital.github.io.git`; `gitlab`=`gitlab.com:milos85vasic/vasic.digital.git` | **YES** (all 3 remotes `main`=`d87a1d6`) |
| milosvasic.ru | `main` | `8324f27` (post-deploy) | `origin` fetch=`github.com:milos85vasic/milosvasic.ru.git` / push=`gitflic.ru:...`+`github.com:...net.v2`; `github`=`...net.v2`; `gitlab`=`gitlab.com:milos85vasic/milosvasic.ru.git`; `gitflic`=`gitflic.ru:milosvasic/milosvasic-net-v-2.git` | **YES** (all 4 remotes `main`=`8324f27`) — but see split-URL flag |
| submodules/constitution | `main` | `38c9825` | `origin`=`github.com:HelixDevelopment/HelixConstitution.git` | **YES** |
| design-toolkit | `main` | `74a037f` | `origin`=`github.com:vasic-digital/design-toolkit.git`; `gitlab`=`gitlab.com:vasic-digital/design-toolkit.git` | **YES** |

No remote out of sync at final measurement. Note: vasic.digital & milosvasic.ru read as *behind remote main* early in the audit; the concurrent deploy advanced the local checkouts to match. `.gitmodules` (umbrella) declares all four submodules.

## 2. Tags (per repo → commit)

**umbrella:** `pre-restyle` → `8ae909d` (annotated; `^{}`=`e3228373`). No v1.x / no v1.6.0 (umbrella is not release-tagged).

**vasic.digital:** `v0.9.0-baseline`=`683a717`, `v1.0.0`=`ad0563c`, `v1.1.0`=`56d7e8e`, `v1.1.1`=`41da3ae`, `v1.2.0`=`2bb9a8b`, `v1.3.0`=`9b4b64b`, `v1.3.1`=`8403754`, `v1.4.0`=`d6575ba`, `v1.5.0`(→`e2f85bc`), `pre-restyle`(→`e2f85bc`), **`v1.6.0`=`d87a1d6` (pushed during audit)**.

**milosvasic.ru:** `v0.9.0-baseline`=`fae3b24`, `v1.0.0`=`c8e06ff`, `v1.1.0`=`85e74ac`, `v1.1.1`=`97df136`, `v1.2.0`=`2e574cf`, `v1.3.0`=`e48bc61`, `v1.3.1`=`679e66d`, `v1.4.0`=`058d3bf`, `v1.5.0`(→`653362`), `v1.5.1`(→`00794fb`), `v1.5.2`(→`1f2b605`), `pre-restyle`(→`1f2b605`), **`v1.6.0`(→`8324f27`) (pushed during audit)**. → **FLAG:** `gitflic` mirror is **missing `v0.9.0-baseline` and `v1.0.0`**.

**submodules/constitution:** `v1.0.0`=`afead29` (`^{}`=`19af087`); `git describe`=`v1.0.0-28-g38c9825`.

**design-toolkit:** `v0.2.0`=`22b6b2d` (`^{}`=`13a76eb`), `v0.2.1`=`ba55f5f` (`^{}`=`74a037f`).

## 3. Submodule pointer consistency

Umbrella committed gitlinks (`git ls-tree HEAD`): `design-toolkit`=`74a037f`, `milosvasic.ru`=`00794fb`, `vasic.digital`=`e2f85bc`, `submodules/constitution`=`38c9825`.

- `design-toolkit 74a037f` → equals remote `main` tip & `v0.2.1^{}` → **reachable, not dangling.**
- `submodules/constitution 38c9825` → equals remote `main` tip → **reachable, not dangling.**
- `milosvasic.ru 00794fb` → equals remote `v1.5.1^{}` → reachable but **STALE** (site now at v1.6.0/`8324f27`).
- `vasic.digital e2f85bc` → equals remote `v1.5.0^{}`/`pre-restyle^{}` → reachable but **STALE** (site now at v1.6.0/`d87a1d6`).

No dangling pointers. The two site pointers lag because the deploy's umbrella-side gitlink bump is not yet committed (working tree shows ` M milosvasic.ru`, ` M vasic.digital`).

## 4. Constitution governance
`origin/main:Constitution.md` contains **§11.4.236 (×2)** and **§11.4.237 (×4)** (also §11.4.162 ×21). Constitution's `origin/main:.gitmodules` nests `design-toolkit` (→ `vasic-digital/design-toolkit.git`) alongside token_optimizer, session_orchestrator, continuum, anti_bluff, helix_perf_cache. **PASS.**

## 5. Live sites
- `https://vasic.digital/` → **HTTP 200**, 47384 B, `server: GitHub.com`, **no `generator` meta** (custom Pages workflow), `last-modified: Fri, 07 Aug 2026 14:50:15 GMT`.
- `https://milosvasic.ru/` → **HTTP 200**, 38193 B, `server: GitHub.com`, `generator content="Jekyll v4.4.1"`, `last-modified: Fri, 07 Aug 2026 14:50:15 GMT`.
- **v1.6.0 re-style deploy IN PROGRESS.** `last-modified` was identical before and after the v1.6.0 push → the currently served content is the pre-v1.6.0 build. Re-style **not asserted live** (UNVERIFIED, as instructed).

## 6. Secrets hygiene
- **umbrella:** robust coverage (`.mcp.json`, `.env`, `*.env`, `.env.*`, `api_keys.sh`, `**/api_keys.sh`, `secrets.sh`, `**/secrets.sh`) — **PASS**.
- **constitution:** covers `.env` variants, whitelists `.env.example`/`.sample`/`.template`. `.mcp.json` not ignored; `plugins/scheduled-work/.mcp.json` is tracked but contains **0** real-secret values — **PASS (minor)**.
- **vasic.digital:** **no tracked `.gitignore`** — **FLAG**.
- **design-toolkit:** **no tracked `.gitignore`** — **FLAG**.
- **milosvasic.ru:** `.gitignore` present but `.env` is **commented out** (`# .env`); no `.mcp.json`/`api_keys` rule — **FLAG**.
- **Leaked real keys:** **0** across all repos. Sole pattern hit = `submodules/constitution/scripts/hooks/test_credential_scan_lib.sh` (scanner test fixture — benign). No secret values were printed at any point.

## 7. Loose ends
- **Uncommitted work — umbrella only, all re-style-related (NOT stale):** modified `_tests/evidence/visual-effects/*.png` (6 files), `_tools/gen/build.sh`, `design-system/brand-milosvasic/milosvasic.css`, `design-system/brand-vasic-digital/vasic-digital.css`, plus submodule-pointer moves ` M milosvasic.ru`, ` M vasic.digital`. Untracked: `_tests/evidence/{closure-final,content-quality-43,restyle}/`, `design-system/brand-vasic-digital/fonts/`. All consistent with the active v1.6.0 re-style.
- **Other repos clean:** vasic.digital, milosvasic.ru, constitution, design-toolkit working trees = 0 changes at measurement.
- **No untracked files >5MB.**
- **No detached-HEAD submodules** (all on `main`).
- **`design-system/`** is a **tracked subdirectory of the umbrella** (no nested `.git`, not in `.gitmodules`) — not an orphan repo. Not a defect; noted for clarity.

---

## Issues found
1. **[FLAG] milosvasic.ru `origin` remote has split/asymmetric URLs** — fetch=`github.com/milos85vasic/milosvasic.ru`, push=`gitflic.ru/...` + a second push=`github.com/...net.v2`. Non-standard multi-push config; confirm intentional (risk: pushes fan out to mirrors, fetch from a different host).
2. **[FLAG] milosvasic.ru `gitflic` mirror missing tags** — `v0.9.0-baseline` and `v1.0.0` present on github+gitlab but absent on gitflic (tag drift between mirrors).
3. **[FLAG] vasic.digital has no tracked `.gitignore`** — no repo-level secret coverage (relies solely on umbrella-level ignore).
4. **[FLAG] design-toolkit has no tracked `.gitignore`** — same secret-coverage gap.
5. **[FLAG] milosvasic.ru `.gitignore` does not ignore `.env`** — the `.env` rule is commented out; no `.mcp.json`/`api_keys` rules either.
6. **[FLAG/INFO] Umbrella submodule pointers for both sites are stale** — records v1.5.1/v1.5.0 while sites advanced to v1.6.0; the umbrella gitlink bump + commit is still pending (expected mid-deploy, but must be committed to finish the release).
7. **[UNVERIFIED/INFO] v1.6.0 re-style not confirmed live** — `v1.6.0` pushed to both site remotes during the audit, but served `last-modified` is unchanged (pre-v1.6.0 build still served); Pages rebuild pending. Not a defect at time of audit, just incomplete.
8. **[INFO] constitution tracks `plugins/scheduled-work/.mcp.json`** — contains no real secrets, but tracking `.mcp.json` at all is inconsistent with the umbrella policy of ignoring it; review whether it should be tracked.

_No dangling submodule pointers, no leaked real secrets, no detached submodules, no stale non-restyle uncommitted work, no oversized untracked blobs._
