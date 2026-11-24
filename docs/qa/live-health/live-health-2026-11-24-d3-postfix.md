# Live health follow-up: D3 post-fix verification (2026-11-24)

| Field | Value |
|---|---|
| Site fix | milos85vasic/milosvasic.ru PR #5, merge `cc7853480d55` |
| Spec | milos85vasic/vasic PR #44, merge `a29727173063` (`_tests/tests/mv-lang-explicit-only.spec.js`) |
| Deploy run | 45437231806 (Deploy Jekyll to GitHub Pages) success |

- RED before fix: spec failed with `Received: "en"` (mv-lang stored on a view of `/`). GREEN after the fix (chromium + firefox).
- Live, one real headless Chromium context, `/` then `/ar/`, `/ru/`, `/ja/`: lang/dir correct (`ar` rtl, `ru` ltr, `ja` ltr), chrome button AR/RU/JA, `mv-lang` null. Raw: `raw/d3-live-probe-output.json`.
- Admin paths on live: `/admin/`, `/downloads/vault/`, `/matrix.tsv`, `/assets/js/vault.js`, `/assets/css/admin-console.css` all 404.
- `scripts/verify-live-site.py --base https://milosvasic.ru`: PASS rc 0, 0 failed, 0 undetermined (`raw/verify-live-site-mv-post-d3.txt`, JSON beside it).
- Local pre-merge build: 870 html pages, 690/690 sitemap URLs 200, admin/vault files absent from `_site` even with the files present on disk.
- Limitation: users whose browser already holds a stale `mv-lang=en` from earlier visits keep it until they pick a language (cannot be told apart from an explicit choice).
