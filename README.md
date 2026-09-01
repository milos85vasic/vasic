# vasic

> **No server-side CI at this umbrella root. Gates run locally.** As of
> 2026-08-27 **this repository** has **no active GitHub Actions workflow**, per
> constitution §11.4.156 ("all CI/CD automation MUST be disabled"). The CI status
> badge that stood here was removed because it advertised a workflow that no
> longer runs. The same gates are enforced by a **local pre-push hook** — and
> `.git/hooks/` is not tracked by git, so **a fresh clone has no gate enforcement
> until `bash scripts/pre-push-gates.sh --install` is run**, and
> `git push --no-verify` bypasses the hook with no record. Run the gates by hand
> as described below, and see
> [`docs/constitution-adoption/DECISION-11-4-156-COMPLY.md`](docs/constitution-adoption/DECISION-11-4-156-COMPLY.md)
> for the decision, its honest boundary, and what it costs.
>
> **This applies to the umbrella root only — not to the site submodules.**
> `milosvasic.ru` deliberately keeps an **active** `pages.yml`: it is the sole
> publish path for a live production website (see **Deploys** below). Do not
> "finish the job" by disabling it.

Umbrella repository for two personal/portfolio sites and the shared tooling that
builds, translates, and validates them. Nothing here is a framework — it is the
working monorepo: the sites live as git submodules, and everything that
generates or checks them lives at the top level.

## What's in here

| Path | What it is |
| --- | --- |
| `vasic.digital/` | Site submodule — committed **static HTML**, served as-is (no build step). |
| `milosvasic.ru/` | Site submodule — **Jekyll** source; the rendered `_site/` is produced by `jekyll build` and is git-ignored. |
| `_tools/gen/` | **Go generator** (`go 1.26`) that renders the localized pages for both sites. |
| `_tools/` | Translation, PDF, and portfolio tooling (`translate/`, `pdf/`, `portfolio/`), plus `deploy-langs.sh`. |
| `design-system/` | **Design system** — per-brand tokens, fonts, icons, motion, and component CSS shared by both sites. |
| `_tests/` | **Playwright + self-validating test harness** (visual oracle, PDF/OCR export checks, link/sitemap integrity). |
| `_content*/` | English source content (`_content/`) and its per-language translations (`_content_<lang>/`). |
| `.github/workflows/ci.yml.disabled` | ~~The CI workflow that runs the gates described below on every push / PR to `main`.~~ **Disabled 2026-08-27** per §11.4.156(B) — a provider ignores any name that is not its exact trigger filename, so this file triggers nothing. It is preserved as the reference definition of the gate set; enforcement moved to a local pre-push hook. Its header block records the disabling and points at the replacement. |
| `scripts/pre-push-gates.sh` | **The local replacement for that workflow.** Tracked and reviewable; runs every gate the workflow ran, plus the §11.4.156(E) self-check. `--install` writes the (untracked) `.git/hooks/pre-push` shim that execs it. |
| `scripts/verify-provider-ci.sh` | **Measures what a file-level check cannot see.** Enumerates the owned repositories from this checkout's own remotes and queries the provider: Pages `build_type`, provider-generated `pages build and deployment` runs, branch protection / required checks, Actions enablement. Exit `0` none found, `1` confirmed, `2` could not determine — **`2` is not a pass.** Run it instead of quoting a `build_type` out of any document here. `scripts/setup-agents-wizard.sh` runs it as Step 9 and turns a confirmed finding into a manual step. |
| `scripts/ollama-tune.sh` | Detects how ollama is managed on **this** host and computes its concurrency from measured CPU/RAM/model facts. Report-only by default; `--print-commands`, `--apply`, `--revert`. The setup wizard runs it as Step 7 and will not apply it behind your back — applying restarts ollama and aborts in-flight embedding jobs. |

## Fresh clone & run the gates

The commands below mirror the gate definitions preserved in
`.github/workflows/ci.yml.disabled` exactly. That workflow no longer runs
anywhere — **these commands, and the local pre-push hook that wraps them, are
the only enforcement there is.** Run them from the repository root after cloning.

### 1. Clone and init the two site submodules (non-recursive)

```bash
git clone git@github.com:milos85vasic/vasic.git
cd vasic

# Init ONLY the two submodules the gates need, and NON-recursively.
# Why non-recursive: milosvasic.ru embeds a nested submodule
# (red-elf/Upstreamable) whose own .gitmodules is a broken 0-byte gitlink, so a
# recursive checkout of the umbrella fails. It is excluded from the Jekyll build
# anyway, and the other submodules (constitution/, design-toolkit/) are not read
# by any gate — so only these two are fetched.
git submodule update --init vasic.digital milosvasic.ru
```

### 2. Prerequisites

The gates expect these toolchains on `PATH` (versions match the preserved
workflow definition):

- **Go 1.26** — Go unit tests + generator build.
- **Node 20** — the Playwright harness (`_tests`).
- **Ruby 3.3 + Bundler** — the `milosvasic.ru` Jekyll build.
- **poppler-utils** and **tesseract-ocr** — the export self-validation (gate 5)
  uses `pdftotext`/`pdfimages`/`pdftoppm` + OCR. If they are missing that gate
  degrades to a reasoned SKIP rather than failing; install them to run it for real.

### 3. Run each gate

```bash
# Gate E — §11.4.156(E) pre-push self-check: no active root CI config is tracked.
# Prints nothing and exits 1 (no match) when the repository is compliant.
git ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$'

# Gate 0 — hardcoded path audit (fails if a machine-specific absolute path returns)
./scripts/audit-hardcoded-paths.sh

# Gate 1 — Go unit tests (the generator)
cd _tools/gen && go test ./... && cd -

# Gate 2 — hardcoding audit (builds the Go generator)
bash _tools/audit-hardcoding.sh

# Gate 3 — HelixTranslate reproducibility self-test
bash _tools/translate/reproducibility-selftest.sh

# Gate 4 — portfolio §1.1 data-integrity self-validation
bash _tools/portfolio/self-validate.sh

# Gate 5 — harness self-validation (visual §11.4.170 + export §11.4.168)
bash _tests/run-harness-selfvalidation.sh
```

### 4. Playwright (chromium)

Gate 6 serves both sites and runs the chromium suite. `vasic.digital` is served
as committed static HTML; `milosvasic.ru` must be built first because its
`_site/` is git-ignored.

Gate 6 is **hermetic**: it reaches nothing but the two local `http.server`
instances. Four specs assert against LIVE production instead, and each is kept
out of this gate by a different mechanism:

- `restyle-seo-regression`, `v170-fixes`, `v171-hardcoding` — excluded by
  `testIgnore` in `_tests/playwright.config.js`. They have no local mode at all
  (`VASIC_BASE`/`MILOS_BASE` default to the production origins).
- `all-languages-link-integrity` — excluded by the `--grep-invert` below. It
  *does* have a local mode (`VD_BASE`/`MV_BASE` default to localhost), but the
  full crawl is too slow to gate every push.

All four run under `playwright.live.config.js`. Only the `all-language` crawl is
run automatically, by `_tools/deploy-langs.sh` after a deploy; the other three
are **manual-only** — see "Deploys" below.

```bash
cd _tests
npm ci
npx playwright install chromium

# Build the milosvasic.ru _site that Playwright will serve:
(cd ../milosvasic.ru && bundle install && JEKYLL_ENV=production bundle exec jekyll build --destination _site)

# Run the chromium suite, excluding the live all-language crawl:
npx playwright test --project=chromium --grep-invert "all-language"
```

### 5. Install the pre-push hook (do this once per clone)

`.git/hooks/` is **not tracked by git**, so a fresh clone has *no* gate
enforcement until you install the hook. The logic itself is tracked, in
`scripts/pre-push-gates.sh`; the hook is a three-line shim that execs it, so
editing the script takes effect immediately with no reinstall.

```bash
bash scripts/pre-push-gates.sh --install    # write .git/hooks/pre-push
bash scripts/pre-push-gates.sh --list       # print the gate table, run nothing
bash scripts/pre-push-gates.sh              # run the gates now (exit 0 = push OK)
bash scripts/pre-push-gates.sh --uninstall  # remove the shim it installed
```

`--install` is idempotent, and it hardlink-backs-up any pre-existing foreign
`pre-push` hook before writing (§9) rather than clobbering it.

Useful switches:

| Variable | Effect |
| --- | --- |
| `PREPUSH_VERBOSE=1` | Stream each gate's output live instead of only on failure. |
| `PREPUSH_SKIP_SLOW=1` | Skip gate 6 (the full Playwright suite) with a printed reason. |
| `PREPUSH_STRICT=1` | Treat every SKIP as a **failure** — use before a release or a §11.4.40 pre-tag sweep. |
| `PREPUSH_ONLY="E 0 1"` | Run only the listed gate ids (`E 0 1 2 3 4 5 6`). |

Gates 5 and 6 SKIP with a stated reason when `_tests/node_modules` or the built
`milosvasic.ru/_site` is absent — a SKIP is reported loudly and is **not** a
pass. There is deliberately no switch that skips gate E: §11.4.156 states "No
escape hatch — no `--allow-ci`, `--enable-workflow`, `--keep-pipeline`,
`--remote-ci-OK`, `--ci-exempt` flag."

## Deploys

Deploys are driven by `bash _tools/deploy-langs.sh` — it regenerates EN plus
every complete language into both site submodules, commits and pushes each site
only when something changed, then runs the exhaustive all-language link/sitemap
validator against the LIVE sites (pass `--dry-run` to preview without committing).

> **⚠ `milosvasic.ru` self-publishes on push — and `pages.yml` must stay
> active.** ~~`milosvasic.ru` no longer self-publishes on push. Its
> `.github/workflows/pages.yml` … is disabled under the same §11.4.156
> decision.~~ **That was briefly true in a working tree on 2026-08-27 and was
> reversed the same day, before anything was committed or pushed. The live site
> was never interrupted.**
>
> `.github/workflows/pages.yml` is the custom GitHub Pages build+deploy action
> and is **ACTIVE**. `gh api repos/milos85vasic/milosvasic.ru/pages` returns
> `build_type: "workflow"` — GitHub publishes `https://milosvasic.ru/`
> **exclusively** by running that workflow. There is no `gh-pages` branch, no
> `docs/` folder, and the repository root is Jekyll **source** (Liquid + front
> matter), so it cannot be served raw from a branch.
>
> **`_tools/deploy-langs.sh` is not a substitute.** It generates, commits and
> pushes *source*, then `sleep`s waiting for the server to rebuild — the rebuild
> it waits for **is** that workflow. Disabling `pages.yml` would not downgrade
> the deploy to manual; it would stop the site updating at all. Operator
> directive: *"Make sure all pages websites work flawlessly! No website can be
> broken! All websites we have here are running deployed in production!"*
> `milosvasic.ru` is therefore a **known, documented deviation** from §11.4.156
> — **not** an `Override §11.4.156`, which the rule forbids
> ([record](docs/constitution-adoption/DECISION-11-4-156-COMPLY.md) §0).
>
> `vasic.digital` needs no build step (committed static HTML), but its Pages
> source was `build_type: "legacy"` when last measured, so every push still
> triggers a provider-side `pages build and deployment` Actions run — with
> **zero** workflow files in its tree. Nothing in that repository can change
> this; it is non-compliant at the provider level with no file-level remedy.
>
> **Every `build_type` above is a dated observation, not a standing fact.**
> Provider settings live outside this tree and change without leaving a trace in
> it. Re-measure instead of quoting:
>
> ```bash
> bash scripts/verify-provider-ci.sh
> #   exit 0 = no provider-generated triggering found
> #   exit 1 = provider-side triggering CONFIRMED (operator-only to change, in the provider UI)
> #   exit 2 = COULD NOT DETERMINE — this is NOT a pass
> ```
>
> It enumerates the owned repositories from this checkout's own remotes and
> queries the provider for what no file-level check can see: Pages `build_type`,
> provider-generated `pages build and deployment` runs, branch protection and
> required checks, and Actions enablement. `scripts/setup-agents-wizard.sh` runs
> it as Step 9 and turns a confirmed finding into a manual step.
