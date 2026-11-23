# Site build guide: expertise pages, checks, container build, local QA

| | |
|---|---|
| Purpose | Operator manual, guide and FAQ for regenerating the career expertise pages of `milosvasic.ru`, validating them, building the Jekyll site in a container, serving it locally and running the tests |
| Constitution | 11.4.257 (manual + guide + FAQ), 11.4.61 (metadata table + contents), 11.4.44 (revision header), 11.4.76 (containers submodule), 11.4.6 (no guessing) |
| Revision | 1 (2026-11-23). First version |
| Status | Draft for independent review (11.4.142) |
| Source of truth | `_tools/career/` (`expertise_pages.py`, `career.py`, `check_a2_contrast.py`, tests), `_tools/containers/` (`site-build`), `scripts/qa-up.sh`, `_tests/` |
| Not covered | Publishing (`deploy-guide.md`), the vault (`vault-guide.md`). The career PDF build is being reworked, see section 7 |

## Contents

1. [Map of the pieces](#1-map-of-the-pieces)
2. [Regenerating the expertise pages](#2-regenerating-the-expertise-pages)
3. [Validation commands that are safe to run](#3-validation-commands-that-are-safe-to-run)
4. [The containerized site build](#4-the-containerized-site-build)
5. [Local QA serve](#5-local-qa-serve)
6. [Browser test suite](#6-browser-test-suite)
7. [PDF content: status, being reworked](#7-pdf-content-status-being-reworked)
8. [FAQ and troubleshooting](#8-faq-and-troubleshooting)
9. [Verification record](#9-verification-record)

## 1. Map of the pieces

| Piece | Where | Output |
|---|---|---|
| Career data | `_content/career/` (`profile.yaml`, `areas/*.yaml`, `locales/*.yaml`) | input |
| Document model and renderers | `_tools/career/` (`resolve.py`, `model.py`, `render/`, `latex/`) | in-memory model, PDFs |
| Expertise pages (hub plus 10 areas, English) | `_tools/career/expertise_pages.py` | `milosvasic.ru/expertise/**`, `milosvasic.ru/assets/og/*.svg` |
| Localized expertise pages | `_tools/gen` (Go generator) with `expertise_localized.json` | per-language `expertise/` pages |
| Site render | Jekyll, run in a container by `_tools/containers/bin/site-build` | `milosvasic.ru/_site/` (git-ignored, untracked) |
| Local servers | `scripts/qa-up.sh` | ports discovered at run time |

The ten areas are: `ai-engineering`, `android`, `android-aosp`, `android-tv`, `desktop`, `flutter`, `go`, `mobile`, `react-native`, `web-frontend`. There are 15 languages including English (14 translated locales).

## 2. Regenerating the expertise pages

```bash
python3 _tools/career/expertise_pages.py
```

Run from the repository root. **It takes no arguments and ignores them**: `--help` is not handled, and passing it regenerates everything. It writes into the live source tree of `milosvasic.ru` (`expertise/`, `assets/og/`), so run it deliberately and expect `git -C milosvasic.ru status` to show those paths afterwards.

Output seen on 2026-11-23 (first lines of a run that was started by passing `--help`; it generated 22 files):

```text
generated 22 files:
  <repo>/milosvasic.ru/expertise/index.html
  <repo>/milosvasic.ru/expertise/ai-engineering/index.html
  <repo>/milosvasic.ru/expertise/android/index.html
  ...
  <repo>/milosvasic.ru/assets/og/expertise.svg
  <repo>/milosvasic.ru/assets/og/ai-engineering.svg
  ...
```

22 = 1 hub + 10 area pages + 1 hub OG card + 10 area OG cards. The script's docstring states the output is idempotent (two runs give byte-identical files); this was **not re-verified here** (a second run was not performed, and the files were untracked so no diff base exists). The localized pages come from the Go generator, not from this script.

## 3. Validation commands that are safe to run

All run from the repository root, all read-only (they build harness pages in temp directories where needed), all executed on 2026-11-23.

### 3.1 Locale files

```text
$ python3 _tools/career/career.py locales
sr: OK
ru: OK
de: OK
es: OK
fr: OK
be: OK
zh: OK
kk: OK
hi: OK
ja: OK
ko: OK
ar: OK
tr: OK
fa: OK
                                        # rc 0
```

`career.py locales --fix` is documented in its help as "re-run translators via subagents (not yet wired)"; do not use it.

### 3.2 DocumentModel contract

```text
$ python3 _tools/career/career.py model
{
 "ok": true,
 "errors": []
}                                       # rc 0
```

### 3.3 Contrast (WCAG) for the `--a2-*` tokens

Checks text 4.5:1, filled 4.5:1, non-text 3:1, hex/oklch parity and the dark-theme cascade for the default accent and every `[data-area]` accent, in both themes. Default file: `design-system/brand-milosvasic/milosvasic.css`.

```text
$ python3 _tools/career/check_a2_contrast.py
PASS: 682 checks, 0 finding(s), 10 areas x 2 themes      # rc 0
```

Exit codes: 0 clear, 1 findings, 2 could not determine. An optional second argument is a second CSS path that must be byte-identical to the first. The script does not accept `--help`: it treats `--help` as a file name and prints `CANNOT DETERMINE: [Errno 2] No such file or directory: '--help'` (rc 2).

### 3.4 Python unit tests

| Command | Result (2026-11-23) |
|---|---|
| `python3 _tools/career/test_expertise_localized.py` | `Ran 19 tests ... OK` |
| `python3 _tools/career/test_expertise_tile_geometry.py` | `Ran 2 tests in 4.161s ... OK` |
| `python3 _tools/career/test_profile_facts.py` | `Ran 8 tests ... OK` |
| `python3 _tools/career/test_locale_comp_items.py` | `Ran 5 tests ... OK` |
| `python3 _tools/career/test_gates_render.py` | `Ran 15 tests in 15.560s ... OK` |
| `python3 _tools/career/test_vault.py` | `Ran 15 tests ... OK`, plus 19 `node PASS` lines |

### 3.5 Tile geometry test

`_tools/career/test_expertise_tile_geometry.py` builds a harness page from the generator's own hub functions plus the real design-system CSS, serves it from a temp directory on a free 127.0.0.1 port, and asserts the title, tagline, metric and projects boxes never intersect and stay inside their tile, at 1280 px and 400 px, light and dark. It uses `_tests/node_modules/playwright` and the probe `_tools/career/tile_geometry_probe.js`. It skips (never passes) when node, playwright or chromium is unavailable.

```text
$ python3 _tools/career/test_expertise_tile_geometry.py
..
Ran 2 tests in 4.161s

OK
```

A "skipped" count in that output means the test did not check anything.

### 3.6 Generator tests (Go)

```text
$ cd _tools/gen && go test -count=1 ./...
ok  	vasic.digital/tools/gen	0.221s
```

This includes the untracked `mv_nav_i18n_test.go` present in the tree on 2026-11-23.

## 4. The containerized site build

There is no Jekyll on the host (`bundle`, `bundler` and `jekyll` are not on PATH). The site is built inside a `ruby:3.3` container through the Containers Submodule (11.4.76).

```bash
_tools/containers/bin/site-build -workload jekyll -build-year 2026
```

Flags (from `site-build` with `-h`): `-workload jekyll|gen-test` (default `jekyll`), `-build-year` pins the rendered footer year, `-probe` reports runtime and compose availability and starts nothing, `-timeout` (default 20m), `-compose`, `-project-name` (default `vasic-sites`), `-root`.

Requirements: rootless podman with compose. Check them without starting anything:

```text
$ _tools/containers/bin/site-build -probe
site-build: runtime: podman 5.7.0
runtime=podman version=5.7.0 compose=available root=<repo> workload=jekyll      # rc 0
```

Behaviour, from the repository records and the deploy script (not re-observed today): it takes about 9 minutes, keeps gems in the named volume `vasic-sites_jekyll-bundle`, writes `milosvasic.ru/_site/`, and asserts a fresh `_site/index.html`. A reading recorded on 2026-09-22 was "wrote 807 file(s)". Exit codes: 0 success, 1 a real build failure, 2 could not run (never a pass). `deploy-langs.sh` calls it automatically when there is no host Jekyll. If the binary is stale or missing it is rebuilt with `cd _tools/containers && go build -o bin/site-build ./cmd/site-build`.

`_site/` is git-ignored and untracked. Production does not read it: `pages.yml` rebuilds on the provider.

**Not executed here:** the build itself (about 9 minutes, rewrites `_site/` which the local test harness serves, and other work on generators was in flight). Only `-probe` was run.

## 5. Local QA serve

```bash
bash scripts/qa-up.sh                 # boot everything, print URLs
bash scripts/qa-up.sh --only mv       # just milosvasic.ru (vd | mv | workshop | ai)
bash scripts/qa-up.sh --no-rebuild    # never rebuild milosvasic.ru/_site
bash scripts/qa-up.sh --stop          # stop what the script started
```

It serves `milosvasic.ru/_site/` (rebuilt first, in a container, when a tracked source is newer, unless `--no-rebuild`). Ports are discovered at run time with `_tools/containers/cmd/port-discover` and recorded in `.service-registry/`; preferred defaults are 8401 (`vd`) and 8084 (`mv`), overridable with `QA_VD_DEFAULT_PORT` and `QA_MV_DEFAULT_PORT`. It binds `127.0.0.1` unless `QA_BIND` is set; **`QA_BIND=0.0.0.0` exposes every service, including the workshop, to the LAN.** Read the printed URLs; do not assume a port. Exit codes: 0 all requested services answer, 1 a service failed, 2 could not determine.

**Not executed here:** it starts long-running servers and may trigger the 9-minute rebuild. The usage text above is read from the script header (`bash scripts/qa-up.sh --help` prints it).

## 6. Browser test suite

Playwright specs in `_tests/` serve `milosvasic.ru/_site/` themselves (see `_tests/playwright.config.js`), so a built `_site` is required. Setup once: `cd _tests && npm ci && npx playwright install chromium`.

Run the expertise spec on chromium (it covers the hub and 10 areas across `en ar fa de ja zh`: structure, canonical and hreflang (16 entries), JSON-LD, 400 px overflow, axe accessibility):

```bash
cd _tests && npx playwright test tests/expertise.spec.js --project=chromium
```

Result on 2026-11-23, against the `_site` already on disk (not rebuilt by me), took 3.8 minutes:

```text
  1 flaky
    [chromium] › tests/expertise.spec.js:71:5 › expertise — structure, SEO, resilience › /expertise/android/zh/ no horizontal overflow at 400px
  99 passed (3.8m)                                       # rc 0
```

The output was cut to its last 15 lines when captured. A block of about a dozen further test names precedes the `1 flaky` line, under a header that was cut off; its meaning (most likely tests that did not run) is UNCONFIRMED, and the exit code was 0. Re-run without a tail to read it. One flaky test passed on retry; treat repeated flakiness as a defect to investigate, not noise.

Other specs exist in `_tests/tests/` (for example `css-visual-regression.spec.js`, untracked at the time of writing); they were not run here. The webkit project cannot launch on this host (missing system libraries), so `--project=chromium` is the working choice; running everything without `--project` will report webkit as an environment fault, not as a site defect. Preflight: `node _tests/preflight.js` (exit 0 ready, 2 cannot determine, never 1); not run here.

## 7. PDF content: status, being reworked

**Status: being reworked by another agent.** The PDF build and the document generator are changing. This guide therefore does not document a PDF procedure, does not claim any PDF output is current, and ran none of these. Commands that exist (confirmed only by `--help`, nothing executed):

```text
$ python3 _tools/career/career.py --help
  {catalog,locales,screen,build,verify,model}
    catalog   dump translatable strings     (--lang LANG, --langs)
    locales   validate locale files         (--fix not yet wired)
    screen    run the HR screening gate     (--area --lang --kind {cv,cover} --text --epoch)
    build     resolve + render + gate artifacts   (--area --lang --kind {cv,cover} --epoch --jobs)
    verify    assert the full 10x2x15 matrix is built, gated and manifested   (--jobs)
    model     validate the DocumentModel contract
```

The `10x2x15` text in the `verify` help means 10 areas, 2 kinds (cv, cover), 15 languages. `career.py build` writes PDFs into `.cache-career/` (the vault CLI reads from there), and `_tools/pdf/build-pdfs.sh` is the older per-language site PDF builder used by `deploy-langs.sh`. Their behaviour in the reworked state is UNCONFIRMED. Check with the owner of that work before relying on them. Sealing PDFs into the vault is in `vault-guide.md`.

## 8. FAQ and troubleshooting

**I ran `expertise_pages.py --help` and files changed.** It ignores arguments and regenerates. Check `git -C milosvasic.ru status`.

**The expertise page is 404 locally.** `_site` is stale or missing. Rebuild (section 4) or run `qa-up.sh` without `--no-rebuild`.

**Playwright reports webkit failures.** Missing host libraries (`libmanette-0.2-0`, `libwoff1` per the repository notes). Installing packages is an operator action. Use `--project=chromium`.

**`site-build` exits 2.** The container runtime or compose could not run. Run `-probe`. Not a content defect.

**Contrast check finds something.** Fix the token in `design-system/brand-milosvasic/milosvasic.css`; exit 1 names the failing pair.

**`career.py locales` says a language is not OK.** Fix that locale file under `_content/career/locales/`. Do not use `--fix`.

## 9. Verification record

Executed on 2026-11-23, outputs quoted above:

| Command | Result |
|---|---|
| `python3 _tools/career/expertise_pages.py` (started by `--help`) | generated 22 files |
| `python3 _tools/career/career.py --help`, `locales --help`, `model --help`, `build --help`, `verify --help`, `catalog --help`, `screen --help` | usage printed |
| `python3 _tools/career/career.py locales` | 14 locales OK, rc 0 |
| `python3 _tools/career/career.py model` | `"ok": true`, rc 0 |
| `python3 _tools/career/check_a2_contrast.py` | 682 checks, 0 findings, rc 0 |
| The six Python test files in section 3.4 and the tile geometry test | OK |
| `cd _tools/gen && go test -count=1 ./...` | ok |
| `_tools/containers/bin/site-build -probe` | podman 5.7.0, compose available, rc 0 |
| `_tools/containers/bin/site-build -h` | flags as in section 4 |
| `npx playwright test tests/expertise.spec.js --project=chromium` | 99 passed, 1 flaky, rc 0 |

Not executed:

| Item | Reason |
|---|---|
| `site-build -workload jekyll ...` | About 9 minutes and rewrites `_site/` |
| `scripts/qa-up.sh` (all modes) | Starts long-running servers, may rebuild |
| A second `expertise_pages.py` run to prove idempotency | Rewrites the live source tree; the run that happened was an accident of passing `--help` |
| `career.py build`, `verify`, `screen`, `catalog`, `locales --fix` | PDF pipeline being reworked, or writes outputs |
| `node _tests/preflight.js`, other Playwright specs, firefox and webkit projects | Not run for this document |
