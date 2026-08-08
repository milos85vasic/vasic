# Performance Audit — vasic.digital & milosvasic.ru (v1.7.1)

Tool: **Lighthouse 12.8.2** (system Chrome, headless), mobile + desktop; supplementary `curl`.
Raw artifacts (`*.report.json` / `*.report.html` / `*.log`) alongside this file. Audit only.

## Scores

| Site | Page | Form | Perf | SEO | BP |
|------|------|------|:--:|:--:|:--:|
| vasic.digital | Home | Mobile | 96 | 92 | 96 |
| vasic.digital | Home | Desktop | 100 | 92 | 96 |
| vasic.digital | Product | Mobile | 98 | 100 | 96 |
| vasic.digital | Product | Desktop | 100 | 100 | 96 |
| milosvasic.ru | Home | Mobile | 99 | 92 | 96 |
| milosvasic.ru | Home | Desktop | 100 | 92 | 96 |
| milosvasic.ru | Product | Mobile | 99 | 100 | 96 |
| milosvasic.ru | Product | Desktop | **90** | 100 | 96 |

Both sites already excellent. CWV all "good" except **mv-product desktop CLS 0.208**.

## Prioritized fixes
**Quick wins**
1. `/favicon.ico` 404 on every page — the sole console error → BP 96→100 both sites.
2. mv-product desktop **CLS 0.208** — `article.od-product-detail.od-reveal` scroll-reveal animates layout; drive via transform/opacity only → Perf 90→~100.
3. 23× non-descriptive "READ MORE" links on both homepages → SEO 92 (product pages 100). Add descriptive `aria-label` → SEO 92→100 + a11y.
4. Delete orphaned `Assets/Logo.jpeg` (531 KiB) — referenced in source but browser loads the 3 KiB `logo.webp` (network trace confirms it's NOT a live cost; latent repo bloat only).

**Medium**
5. Render-blocking CSS (5–6 serial `<head>` sheets): ~870–900 ms mobile on vasic home/product; drop mv's redundant 6th sheet if any; inline critical CSS.
6. Preload the two critical fonts (Inter-latin + display) → shorter swap / faster mobile LCP.

**Low/optional:** minify CSS/JS (~5 KiB); brotli/cache-TTL are GH Pages platform limits (need a CDN — not worth it at current weights).

Fonts: all `font-display: swap` (no FOIT). Images: responsive srcset + width/height + fetchpriority on mv hero (well done). Every number traces to a captured Lighthouse artifact; single run per config (mobile SI ±~10% noise).
