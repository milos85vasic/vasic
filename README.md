# vasic

[![CI](https://github.com/milos85vasic/vasic/actions/workflows/ci.yml/badge.svg)](https://github.com/milos85vasic/vasic/actions/workflows/ci.yml)

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
| `.github/workflows/ci.yml` | The CI workflow that runs the gates described below on every push / PR to `main`. |

## Fresh clone & run the gates

The commands below mirror `.github/workflows/ci.yml` exactly. Run them from the
repository root after cloning.

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

The gates expect these toolchains on `PATH` (versions match CI):

- **Go 1.26** — Go unit tests + generator build.
- **Node 20** — the Playwright harness (`_tests`).
- **Ruby 3.3 + Bundler** — the `milosvasic.ru` Jekyll build.
- **poppler-utils** and **tesseract-ocr** — the export self-validation (gate 5)
  uses `pdftotext`/`pdfimages`/`pdftoppm` + OCR. If they are missing that gate
  degrades to a reasoned SKIP rather than failing; install them to run it for real.

### 3. Run each gate

```bash
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
`_site/` is git-ignored. The `all-language` crawl is excluded here — it is the
spec designed to run LIVE against production (see deploys below), not per-run.

```bash
cd _tests
npm ci
npx playwright install chromium

# Build the milosvasic.ru _site that Playwright will serve:
(cd ../milosvasic.ru && bundle install && JEKYLL_ENV=production bundle exec jekyll build --destination _site)

# Run the chromium suite, excluding the live all-language crawl:
npx playwright test --project=chromium --grep-invert "all-language"
```

## Deploys

Deploys are driven by `bash _tools/deploy-langs.sh` — it regenerates EN plus
every complete language into both site submodules, commits and pushes each site
only when something changed, then runs the exhaustive all-language link/sitemap
validator against the LIVE sites (pass `--dry-run` to preview without committing).
