# Live Audit — milosvasic.ru @ v1.6.0 ("TERMINAL BRUTALIST")

- Scope: Read-only adversarial audit of LIVE https://milosvasic.ru. No edits/commits/deploys.
- Method: raw `curl -sSL`, Playwright 1.61.0 (chromium), @axe-core/playwright — all against live URLs.
- Date: 2026-08-07
- Verdict: PASS. 0 defects. 2 informational notes (Fraunces fonts absent-by-design; article-viewer has no reachable trigger).
- Every claim below is backed by a saved artifact in this directory.

## PASS / FAIL / UNVERIFIED matrix

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | Reachability — root 200 | PASS | root.html (HTTP 200, 38193 B) |
| 1 | Sitemap URL count | PASS (525 URLs) | sitemap.xml (200, application/xml) |
| 1 | ~25 sample routes (EN+14 localized homes, portfolio, product, robots) all 200 | PASS (25/25 = 200) | reachability.txt |
| 2 | Served style.css contains Anton | PASS (7 Anton refs) | style.css |
| 2 | Served od/milosvasic.css contains Anton | PASS (10 Anton refs) | od-milosvasic.css |
| 2 | Anton woff2 fonts 200 + font/woff2 + non-trivial | PASS | anton.woff2 (18612 B); latin-ext 31356 B — both font/woff2 |
| 2 | assets/od/fraunces/* return 200 woff2 | N/A — Fraunces absent by design (Note A) | 404s; not referenced in served CSS |
| 2 | Bold Anton/engineering-dossier design renders (not fallback) — desktop light+dark, mobile | PASS | shot-home-desktop-light.png, shot-home-desktop-dark.png, shot-home-mobile-390.png; pw-audit-results.json (heroFont Anton, antonLoaded:true, uppercase) |
| 2 | Evolved red-line profile decorations present | PASS (red bracket frame around portrait, both themes) | screenshots (top-right + bottom-left red rules) |
| 3 | 14 non-EN /<lang>/ → 200 | PASS (14/14) | reachability.txt |
| 3 | <html lang=xx> correct; ar/fa dir=rtl | PASS (14/14; ar+fa rtl) | localization.txt |
| 3 | In-language hero + nav (no English leaks) | PASS (14/14 translated) | l10n-content.txt |
| 3 | Language switcher opens (15) + navigates | PASS (15 items; DE click → /de/, htmlLang=de) | switcher-axe-results.json |
| 4 | 45 PDFs (CV+CoverLetter+Portfolio × 15) → 200 + application/pdf + non-trivial | PASS (45/45; 202KB–754KB) | pdfs.txt |
| 4 | downloads.js offers 15 langs | PASS (ALL15 array; modal renders 15 rows) | downloads.js; pw-audit-results.json |
| 5 | axe-core EN home — serious/critical = 0 | PASS (0 total violations) | axe-en-home.json |
| 5 | axe-core ru home — serious/critical = 0 | PASS (0 total) | axe-ru-home.json |
| 5 | axe-core ar home (RTL) — serious/critical = 0 | PASS (0 total) | axe-ar-home-rtl.json |
| 5 | axe-core product detail — serious/critical = 0 | PASS (0 total) | axe-product-helixtrack.json |
| 6 | Hamburger ≤760px opens nav (aria-expanded toggles) | PASS (375px: false→true) | pw-audit-results.json |
| 6 | Theme toggle | PASS (light→dark at 375/768/1280) | pw-audit-results.json |
| 6 | Back-to-top | PASS (present + visible after scroll) | pw-audit-results.json |
| 6 | Download modal opens (15 langs) | PASS (15 rows, all widths) | pw-audit-results.json |
| 6 | Article viewer opens/closes | UNVERIFIED — no reachable trigger (Note B) | pw-audit-results.json (triggerPresent:false) |
| 6 | No broken images | PASS (0 at 375/768/1280) | pw-audit-results.json |
| 6 | No horizontal overflow | PASS (0 at 375/768/1280) | pw-audit-results.json |
| 6 | No console errors | PASS (0 everywhere) | pw-audit-results.json |
| 7 | Sitemap valid + hreflang | PASS (16 hreflang = 15 langs + x-default) | root.html, sitemap.xml |
| 7 | JSON-LD valid; name = Miloš Vasić (diacritics) | PASS (1 block, valid, @type WebSite) | root.html |
| 7 | No twitter:site content="@" (#43 fix holds) | PASS (no twitter:site tag at all) | root.html |
| 7 | og/meta sane | PASS (og:title/desc/url/image/type, canonical, twitter:card) | root.html |
| 8 | Network 404 scan — home | PASS (0 responses ≥400) | pw-audit-results.json (network.home) |
| 8 | Network 404 scan — product page | PASS (0 responses ≥400) | pw-audit-results.json (network.product) |

## Defects found

None. No FAIL results. Two informational notes below (neither is a live-site defect — no broken requests, no user-visible breakage).

### Note A — Fraunces fonts absent (by design, not a defect)
The brief expected assets/od/fraunces/* to serve 200. On live v1.6.0, Fraunces is NOT used: served od/milosvasic.css defines only @font-face for Anton, and the stack is `Anton,"Space Grotesk",sans-serif` / `"Inter",sans-serif` / `"JetBrains Mono",monospace`. Probed Fraunces paths 404, but nothing references them, so zero broken font requests (network scan: 0 responses ≥400). The restyle evolved away from Fraunces. N/A vs. stale brief expectation, not a defect.

### Note B — Article-viewer modal has no reachable trigger
articles.js (200, loads cleanly) implements a "Read more" article modal fetching articles/<lang>/<slug>.html from [data-article] triggers. Homepage article-card "Read more" buttons instead link to /products/*.html detail pages (real 200 pages); there are no [data-article] triggers anywhere reachable and no article/blog/news URLs in the sitemap. Modal open/close is UNVERIFIABLE from live pages (no content to open). Not a defect — no article content is wired up.

## Key confirmations (adversarial highlights)
- Design renders live, not fallback: hero computed font-family `Anton,"Space Grotesk",sans-serif`, text-transform uppercase, document.fonts reports Anton status "loaded". Verified light/dark/390px mobile.
- Red-line profile decoration = crimson bracket frame around portrait (top-right + bottom-left rules), both themes; accent `--od-accent:#a31e39` (light) / `#f05a6f` (dark).
- a11y: 0 axe violations (serious/critical/moderate/minor all 0) on all four sampled pages incl. RTL Arabic.
- All 45 PDFs served (200, application/pdf, 202KB–754KB); download modal renders all 15 languages.
- Zero console errors and zero HTTP≥400 across every page/viewport exercised.

## Artifacts (this directory)
- HTML: root.html, sitemap.xml, langhtml/<lang>.html ×14
- CSS/JS/fonts: style.css, od-milosvasic.css, downloads.js, articles.js, anton.woff2
- Sweeps: reachability.txt, pdfs.txt, localization.txt, l10n-content.txt
- Playwright: pw-audit.js + pw-audit-results.json; pw-switcher-axe.js + switcher-axe-results.json
- Screenshots: shot-home-desktop-light.png (+-full), shot-home-desktop-dark.png (+-full), shot-home-mobile-390.png (+-full)
- axe JSON: axe-en-home.json, axe-ru-home.json, axe-ar-home-rtl.json, axe-product-helixtrack.json
