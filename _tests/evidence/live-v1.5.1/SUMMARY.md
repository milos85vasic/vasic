# Live Verification Evidence Matrix — v1.5.x (READ-ONLY, live production)

- Date: 2026-08-07
- Method: raw `curl -sSL` + Playwright (chromium) + @axe-core/playwright against LIVE URLs only. No generator run, no source edits, no commit/push.
- Sites / deployed versions:
  - vasic.digital — v1.5.0 (commit e2f85bc)
  - milosvasic.ru — v1.5.1 (commit 00794fb)
- Languages (15): EN + 14 non-EN: ar be de es fa fr hi ja kk ko ru sr tr zh
- Every claim is backed by a saved artifact under this directory.

## PASS / FAIL / UNVERIFIED table

| # | Check | vasic.digital | milosvasic.ru | Evidence |
|---|-------|---------------|---------------|----------|
| 1 | Root 200 | PASS (200) | PASS (200) | curl (this run) |
| 1 | sitemap.xml reachable | PASS 525 URLs, own domain only | PASS 525 URLs, own domain only | reachability/sitemap-*.xml |
| 1 | ~30 sampled URLs (incl. localized) 200 | PASS 34/34, 0 non-200 | PASS 34/34, 0 non-200 | reachability/samplecheck-*.txt |
| 2 | 14 localized homes: 200 + html lang + dir(rtl ar/fa) + in-language hero + no EN-leak | PASS 14/14 | PASS 14/14 | homes/grid-*.txt, homes/page-*.html |
| 3 | Home switcher exposes per-lang home URLs | PASS OD_PAGE.paths = 14 langs +en | PASS MV_PAGE.paths = 14 langs +en | langswitch/*.txt |
| 4 | D1/D2: localized product/portfolio use ../../assets/od/…, assets 200 | PASS (7 assets 200) | n/a (vasic-specific) | d1d2/d1d2-assets.txt, d1d2/*-assets.txt |
| 4 | D1/D2: portfolio->product ../../products/<l>/… 200; Home /<l>/ 200 (ru,de,ar,ja) | PASS all 200 | n/a | d1d2/d1d2-resolve.txt |
| 5 | v1.5.0 VFX in served home (vd-hero, aurora/grid, data-od-count, od-magnetic, od-glow) | PASS (see Note A) | PASS = ABSENT (all 0) | vfx/vfx-vasic.txt, vfx/vfx-milos*.txt, vfx/vfx-aurora-context.txt |
| 5 | prefers-reduced-motion in served brand CSS | PASS (vasic-digital.css 1, animations.css 4, motion.js 1) | present too (milosvasic.css 1) | vfx/vfx-vasic.txt |
| 6 | Per-language PDFs 200 + application/pdf + non-trivial | PASS 15/15 Portfolio (0.97–1.11 MB) | PASS 45/45 CV+CL+Portfolio (0.20–0.75 MB) | pdf/vasic-pdf-grid.txt, pdf/milos-pdf-grid.txt |
| 6 | downloads.js offers 15 langs | n/a (no downloads.js; static links) | PASS ALL15 for cv/cl/portfolio | pdf/downloads.js |
| 7 | axe-core serious/critical = 0 (EN home, ru home, ar RTL) | PASS 0/0 all 3 | PASS 0/0 all 3 | a11y/axe-*.json, a11y/axe-summary.json |
| 8 | No horizontal overflow @375/768/1280 | PASS all | PASS all | interactive/interactive-results.json |
| 8 | No broken images | PASS | PASS | same |
| 8 | Back-to-top appears on scroll + returns to top | PASS all viewports | PASS all viewports | same + screenshots/*.png |
| 8 | Nav click navigates | PASS -> /portfolio/ | PASS -> /#work | same |
| 8 | Mobile hamburger works | n/a | PASS (#nav-toggle aria-expanded false->true, menu visible) | interactive-results.json, screenshots/milos-375.png |

No UNVERIFIED rows. No FAIL rows.

## Defect list

EMPTY — no defects found. All checks pass on both production sites.

## Notes (non-defects)

- Note A — VFX class naming: the v1.5.0 aurora/grid hero effects are served on vasic.digital under class names `vd-hero__fx` (wrapper), `vd-hero__aurora`, `vd-hero__grid` (CSS keyframe `vd-aurora-drift`), NOT the literal tokens `od-aurora`/`od-grid` in the brief. Feature confirmed in served HTML (vfx/vfx-aurora-context.txt). Other tokens matched literally: vd-hero (x11), data-od-count (x3), od-magnetic (x3), od-glow (x34). milos home has none of these.
- milosvasic.ru also serves the full product/portfolio catalog (495 /products/ + 15 /portfolio/ localized URLs, own domain, all sampled 200) — by design, not a cross-site leak.
- One transient TLS reset on overlays.css during batch checks; immediate retry returned 200 (text/css, 4092 bytes). Recorded in d1d2/d1d2-assets.txt.

## Artifact index
- reachability/ — sitemaps, sample-check logs
- homes/ — 28 localized pages + grids
- langswitch/ — OD_PAGE / MV_PAGE evidence
- d1d2/ — asset + link resolution
- vfx/ — visual-effects token checks + served CSS
- pdf/ — 60 verified PDFs + downloads.js
- a11y/ — 7 axe JSON incl. summary
- interactive/ — interactive-results.json
- screenshots/ — 2 sites x 3 viewports
