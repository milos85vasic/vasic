# Live health sweep, 2026-11-24

| Field | Value |
|---|---|
| Date (UTC) | 2026-11-24, 16:10-16:20 |
| Scope | https://milosvasic.ru (GitHub Pages, build_type workflow) and https://digital.vasic.dev (vasic.digital submodule) |
| Mode | READ-ONLY: GET/HEAD only, headless local Chromium with fresh contexts (no user profile), no push, no deploy, no provider setting change |
| Prior evidence compared | `docs/qa/live-site/baseline-live-2026-11-23.json`, `docs/qa/live-site/baseline-live-digital-vasic-dev-2026-11-23.json`, `_tests/evidence/test-types/perf-budget.json` |
| Roadmap-Item | UNCONFIRMED (no VSC id was issued for this sweep) |
| Raw evidence | `docs/qa/live-health/raw/` |

## Contents
1. Summary table
2. Defects and observations
3. Perf-budget growth (+26 KB) investigation
4. Admin / vault / private material
5. Method and honest boundaries

## 1. Summary table

| Check | milosvasic.ru | digital.vasic.dev |
|---|---|---|
| Sitemap URLs (all 15 languages incl. en) | 690 (was 525 on 2026-11-23; +165 expertise pages and 11 og cards from the v2.0.0 deploy) | 525 `<loc>` in sitemap.xml; verifier reports 527 (the 2-URL difference is UNCONFIRMED); unchanged vs baseline |
| HTTP 200 on every sitemap URL | 690/690 | 525/525 (527/527 in the verifier crawl) |
| Title present, non-empty | 690/690 | 525/525 |
| `<html lang>` equals URL language | 690/690 | 525/525 |
| Canonical present; hreflang 16 entries | all | all |
| Mixed content (http:// src/href) | 0 | 0 |
| Sample assets (css/js/fonts/images) | 58 checked, 0 non-200 | 52 checked, 0 non-200 |
| `verify-live-site.py` vs 2026-11-23 baseline | PASS rc 0, 0 regressions, 176 new paths (expected) | PASS rc 0, 0 regressions, 0 new |
| TLS | Let's Encrypt YR2, valid to 2027-01-19 (56 days), SAN apex + www | Let's Encrypt YR1, valid to 2027-01-25 (62 days), SAN apex only |
| http -> https | 301 | 301 |
| www -> apex | 301 to apex (https and http) | n/a, www does not resolve |
| Response time, total, 690 / 525 sequential-ish GETs (4 parallel) | p50 0.096 s, p95 0.244 s, max 1.75 s | p50 0.099 s, p95 0.326 s, max 0.88 s |
| Console errors/warnings, desktop 1366 and mobile 390, 9 / 7 sample pages | 0 | 0 |
| Failed requests in browser | 0 | 0 |
| Horizontal overflow at 390 px and 360 px, all 15 home pages | none | `/de/` at 390 px and 360 px, `/ru/` at 360 px (D2) |
| Admin/vault console served | false | false |
| Secret / host-path patterns in all page bodies | none | none |

## 2. Defects and observations

No production-down or content-correctness defect was found. Items, by severity:

**D1 (low, digital.vasic.dev, edge behaviour).** Requests for non-existent URLs intermittently get GitHub/Fastly `503 Unicorn` instead of `404`. Repro (see `raw/tls-redirect-admin-probe.txt`): 40 sequential GETs of distinct non-existent paths on digital.vasic.dev gave 25x 404 and 15x 503; the same on milosvasic.ru gave 40x 404; 40 GETs of existing pages gave 40x 200. Existing pages are not affected (525 sitemap URLs plus 80 further GETs, zero 5xx). Cause: UNCONFIRMED. Both sites have no custom `404.html`, so that does not explain the difference. Impact is limited to broken inbound links and scanners. Proposed fix: none in-repo is known; add a minimal `404.html` to vasic.digital as an experiment and re-measure with the same burst, or leave it. No fix PR is proposed because the cause is not established.

**D2 (low, digital.vasic.dev, mobile layout).** On `/de/` at 390 px the page scrolls horizontally (`scrollWidth` 463 vs viewport 390); at 360 px `/de/` is 454 and `/ru/` is 368. The overflowing elements are `.vd-hero__aurora` (right edge 476 px, present on every language but clipped elsewhere) and `.od-to-top` (right edge 439 px). The earlier note "back-to-top flake in live run" in the Git history may be the same element (relationship UNCONFIRMED, not investigated). Proposed fix: `overflow-x: clip` on the hero container or `body`, and keep `.od-to-top` inside the viewport; to be done in the vasic.digital submodule with a Playwright overflow check across the 15 languages at 360/390 px.

**D3 (low-medium, milosvasic.ru, behaviour by design, UX).** `assets/js/main.js` stores `mv-lang` on every page view, including English `/`. A visitor who has opened `/` once and then follows a direct link to `/ar/` gets `<html lang="en" dir="ltr">` with an English chrome over an Arabic page (the stored choice wins). Repro: one browser context, load `/` then `/ar/`; `raw/browser-probe-shared-context-lang-override.json` records `lang=en dir=ltr` for `/ru/`, `/ar/`, `/ja/`. With a fresh context each page reports the correct `lang` and `dir` (`raw/browser-probe-fresh-context.json`). Server-rendered HTML is correct, so crawlers are not affected. Proposed fix: store `mv-lang` only on an explicit switcher choice, not in `translate()` on load. This is a source change in the milosvasic.ru submodule, and a main push deploys production, so it is NOT included here and needs a reviewer GO first.

**Observation O1 (preventive, milosvasic.ru).** `admin/`, `downloads/vault/`, `assets/js/vault*.js`, `assets/css/admin-console.css` and `matrix.tsv` are untracked locally and are NOT in the Jekyll `exclude:` list of `_config.yml`. They are not served today (all 404). The commit wrapper runs `git add .`, so an accidental commit would publish them on the next push. Proposed fix: add `admin`, `downloads/vault`, `matrix.tsv` to `exclude:` and to `.gitignore` until the console is deliberately shipped.

**Observation O2.** `https://vasic.digital` (legacy apex) resolves to 31.177.76.32 / 31.177.80.32, not GitHub Pages, and HTTPS connect fails. It is not the production host (digital.vasic.dev is), but any old link to it is dead. Whether that is intended is UNKNOWN.

**Observation O3.** `/CLAUDE.md` and `/AGENTS.md` (both sites) and `/README.md` (digital.vasic.dev) are served with 200. They are committed carriers of public repositories and contain no credential pattern. Adding them to the Jekyll `exclude` list would stop publishing them, an operator decision.

## 3. Perf-budget growth (+26 KB) investigation

`_tests/evidence/test-types/perf-budget.json` (uncommitted diff) moves milosvasic.ru `/` from 470,718 to 496,628 bytes (+25,910) and `/products/helixtrack.html` from 406,893 to 432,821 (+25,928). vasic.digital rows are unchanged. These are LOCAL, uncompressed measurements.

Cause: `assets/od/milosvasic.css` grew from 24,384 to 51,289 bytes (+26,905 raw) between the pins 04cf165 (2026-09-25) and HEAD (commits b589664 v2.0.0 rework, a514112 footer version). The added rules are the Aurora Atlas v2 hub and area pages (expertise tiles, timelines, project grids, dark-theme variants, view transitions). The same file served live is 51,289 bytes raw and 11,249 bytes gzip (was 6,244 gzip), so the real transfer cost on live is about +5 KB, not +26 KB.

Live transfer, fresh Chromium context, `/`: 265,966 bytes over 18 requests (budget in the spec: 1,500,000 bytes, 45 requests); `/products/helixtrack.html` 204,519 bytes over 16 requests; vasic.digital `/` 204,034 bytes over 13. Verdict: a real but small page-weight increase (about 5 KB gzip) caused by one stylesheet carrying hub/area styles on every page; no regression against the budget. Optional improvement: split hub/area rules into a stylesheet loaded only on `/expertise/`.

Largest live assets on milosvasic.ru `/`: `inter-latin.woff2` 48 KB, `i18n.js` 37 KB gzip (111 KB raw), `profile-400.webp` 32 KB, two fonts 31 KB each.

## 4. Admin / vault / private material

Probed 40 likely paths on each site (list in `raw/tls-redirect-admin-probe.txt`). All admin, vault, console, config, `.git`, `.env`, backup and tooling paths return 404; nothing admin or vault related appears in either sitemap. `admin_console_served=false`, `vault_console_served=false`, `vault_downloads_served=false`. All 1,215 sitemap page bodies were scanned for private-key blocks, GitHub/OpenAI/AWS/Google key shapes and host-absolute paths: zero hits. See O1 for the preventive gap. The `docs/qa/i18n-review` set was not re-read in this sweep (UNCONFIRMED comparison); the live lang/dir/title/hreflang checks above stand on their own.

## 5. Method and honest boundaries

- Tools: `scripts/verify-live-site.py` (sitemap sweep, assets, hreflang, baseline compare), curl timing, openssl, Playwright Chromium 1228 headless (desktop 1366x900, mobile 390x844 touch), `raw/body-scan.py`.
- Response time is measured from one client on a single network path, 4 parallel requests; it is not a global figure. Most responses were CDN cache hits.
- Browser probe covered 9 (milosvasic.ru) and 7 (digital.vasic.dev) sample pages, not all 1,215; the HTTP/title/lang/hreflang/mixed-content checks covered all.
- Firefox and WebKit were not run (WebKit libraries are missing on this host).
- Link integrity inside pages (internal anchors) was not crawled beyond the verifier's checks.
- Console warnings were included in the count; zero were seen.
- The 503 cause (D1) is UNCONFIRMED.
