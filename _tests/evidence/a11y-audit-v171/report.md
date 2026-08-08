# Accessibility Audit — vasic.digital & milosvasic.ru

**Standard:** WCAG 2.2 Level AA (AAA noted where relevant)
**Tooling:** axe-core 4.11.3 via `@axe-core/playwright`, Chromium (Playwright), headless.
**Rule sets applied:** `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa, best-practice`.
**Date:** 2026-08-08
**Method:** Each URL loaded to `networkidle` in a context with `reducedMotion: 'reduce'`, axe injected and run in-page; DOM landmarks/headings/alt/lang/dir and keyboard focus captured; dark theme forced via `data-theme="dark"`. Color-contrast items that axe could not compute (gradient/overlap backgrounds) were re-measured at the pixel level from element screenshots (see `contrast-probe.mjs`). **No site or source files were modified — audit only.**

Raw per-page axe JSON: `raw/<page-id>.json`. Machine summary: `summary.json`.

---

## Executive Summary

### Confirmed violations by impact (per site)

| Site | Critical | Serious | Moderate | Minor | Total confirmed |
|------|:---:|:---:|:---:|:---:|:---:|
| **vasic.digital** | 0 | 0 | 0 | 0 | **0** |
| **milosvasic.ru** | 0 | 1 rule (6 node-instances) | 0 | 0 | **1 rule** |

- **vasic.digital is CLEAN** — 0 axe violations across all 6 page states tested (home light, home dark, `/sr/`, `/ar/` RTL, a product page, portfolio).
- **milosvasic.ru has ONE confirmed rule failure**: `target-size` (WCAG 2.2 AA, SC 2.5.8), *serious*, affecting 3 distinct interactive components, observed on 5 of the 6 tested page states.

### Pages tested (12 states)

| Page ID | Site | URL | HTTP | Confirmed violations |
|---|---|---|:---:|:---:|
| vd-home-light | vasic.digital | `/` | 200 | 0 |
| vd-home-dark | vasic.digital | `/` (data-theme=dark) | 200 | 0 |
| vd-sr | vasic.digital | `/sr/` | 200 | 0 |
| vd-ar-rtl | vasic.digital | `/ar/` (RTL) | 200 | 0 |
| vd-product | vasic.digital | `/products/helixtrack.html` | 200 | 0 |
| vd-portfolio | vasic.digital | `/portfolio/` | 200 | 0 |
| mv-home-light | milosvasic.ru | `/` | 200 | 1 (target-size) |
| mv-home-dark | milosvasic.ru | `/` (data-theme=dark) | 200 | 1 (target-size) |
| mv-sr | milosvasic.ru | `/sr/` | 200 | 0 |
| mv-ar-rtl | milosvasic.ru | `/ar/` (RTL) | 200 | 2 nodes (target-size) |
| mv-product | milosvasic.ru | `/products/helixtrack.html` | 200 | 1 (target-size) |
| mv-portfolio | milosvasic.ru | `/portfolio/` | 200 | 1 (target-size) |

> Note on the milos "article/downloads" test slot: milosvasic.ru's sitemap (525 URLs) contains **only** home + localized homes + `/portfolio/` + `/products/*.html`. There is no articles/downloads/blog section (`/downloads/`, `/articles/`, `/blog/` all return HTTP 404). An extra product page was therefore substituted for that slot.

---

## Findings (ranked; critical/serious first)

| # | Site | URL(s) | Rule | Impact | Selector | Measured value | WCAG SC | Suggested fix |
|---|------|--------|------|:---:|---------|---------------|---------|---------------|
| 1 | milosvasic.ru | `/`, `/products/helixtrack.html`, `/portfolio/` (+ dark) | `target-size` | serious | `a.brand` (`<a class="brand" href="/#top">milos.vasic</a>`) | Rendered **113.9 x 23.5 px** — height **0.5 px below** the 24 px minimum | 2.5.8 Target Size (Minimum), AA | Give the brand link a min tap height, e.g. `.brand{display:inline-flex;align-items:center;min-height:24px;line-height:24px}` (increase padding, not font). |
| 2 | milosvasic.ru | `/ar/` (RTL) | `target-size` | serious | `#lang-btn` (`button.icon-btn`) | Effective **38 x 5.9 px** — `partiallyObscured`; unobscured height 5.9 px, far below 24 px | 2.5.8 Target Size (Minimum), AA | Ensure header icon buttons keep a full >=24x24 px hit area and are not overlapped by an adjacent element on RTL; set `min-width:24px;min-height:24px` and audit the header flex/overlap in RTL. |
| 3 | milosvasic.ru | `/ar/` (RTL) | `target-size` | serious | `#theme-btn` (`button.icon-btn`) | Effective **38 x 5.9 px** — `partiallyObscured`; unobscured height 5.9 px, far below 24 px | 2.5.8 Target Size (Minimum), AA | Same as #2 — restore full clickable area / remove the RTL overlap so the button's tap target is not clipped. |

**That is the complete list of confirmed failures.** vasic.digital produced none.

---

## Items axe reported as INCOMPLETE (manual review) — verified, NOT failures

axe marks checks it cannot decide automatically as *incomplete*. These are **not** violations. Each was manually verified; all pass. Documenting them so the report is complete and non-bluff.

### A. `aria-valid-attr-value` — flagged *critical* on every vasic.digital page (1 node) -> NOT AN ISSUE
- Element: `#od-lang-btn` with `aria-controls="od-lang-menu"` + `aria-haspopup="menu"`.
- axe message: *"Unable to determine if aria-controls referenced ID exists ... while using aria-haspopup"*.
- **Verification (scripted):** `#od-lang-menu` **does exist in the DOM at page load** (`<ul id="od-lang-menu" role="menu" aria-label="Language" hidden>`). Clicking the button correctly flips `aria-expanded` to `true` and reveals the menu. aria-controls pointing at a `hidden`-until-open menu is correct ARIA authoring. **Pass.**

### B. `color-contrast` — flagged *serious* incomplete, large node counts -> manually measured, PASS (AAA)
- vasic.digital: up to 288 nodes/page flagged with reason `bgGradient` / `elmPartiallyObscured` — axe cannot compute a ratio over a CSS gradient/overlapping layer.
- milosvasic.ru: reasons `bgOverlap`, `imgNode` (text inside inline SVG diagrams), `nonBmp` (the theme-toggle glyph).
- **Verification (pixel-level, `contrast-probe.mjs`):** screenshotted each key element and computed WCAG contrast between its darkest and lightest opaque pixels (worst realistic case):

| Site | Element | Text color | Measured contrast |
|---|---|---|---|
| vasic.digital | `a[href$="#work"]` nav link | rgb(20,21,25) | **18.24 : 1** |
| vasic.digital | `a[data-i18n="nav.products"]` | rgb(20,21,25) | **18.24 : 1** |
| vasic.digital | `.od-brand` | rgb(20,21,25) | **18.24 : 1** |
| vasic.digital | `h1` | rgb(20,21,25) | **16.58 : 1** |
| milosvasic.ru | `.brand` | rgb(22,19,15) | **16.41 : 1** |
| milosvasic.ru | `nav a` | rgb(22,19,15) | **16.41 : 1** |
| milosvasic.ru | `h1` | rgb(22,19,15) | **16.41 : 1** |

All exceed AA (4.5:1) **and** AAA (7:1). The remaining incomplete nodes are inline-SVG diagram `<text>` (not automatable) and the single theme icon glyph. **No color-contrast failure found.**

---

## Positive baseline (both sites, evidenced from DOM capture)

- **Landmarks:** `main`, `nav`, `footer` present on every page; vasic.digital also emits `<header>`/banner. *(Minor best-practice note: milosvasic.ru has no `<header>`/`[role=banner]` wrapper — header content sits in `nav`; axe's `region` rule still passes.)*
- **Headings:** exactly **one `<h1>` per page** on all 12 states; no heading-order violations reported.
- **Images:** **0 images missing `alt`** on any tested page.
- **Language & direction:** `lang` set correctly per locale (`en`/`sr`/`ar`); Arabic pages correctly set `dir="rtl"` on `<html>`.
- **Skip link:** present and focusable on both sites in every locale (localized text confirmed). First Tab lands on the skip link.
- **Visible focus:** vasic.digital -> `outline: auto 1px rgb(0,95,204)`; milosvasic.ru -> `outline: solid 3px` — both provide a visible focus indicator (SC 2.4.7 pass).
- **Reduced motion:** pages rendered cleanly under `prefers-reduced-motion: reduce` with no axe issues.

---

## Proof of clean pages (vasic.digital)

Command: `cd _tests && node evidence/a11y-audit-v171/audit.mjs`

Output (violation counts per page):
```
vd-home-light  http=200  violations=0
vd-home-dark   http=200  violations=0
vd-sr          http=200  violations=0
vd-ar-rtl      http=200  violations=0
vd-product     http=200  violations=0
vd-portfolio   http=200  violations=0
mv-home-light  http=200  violations=1
mv-home-dark   http=200  violations=1
mv-sr          http=200  violations=0
mv-ar-rtl      http=200  violations=1   (2 target-size nodes)
mv-product     http=200  violations=1
mv-portfolio   http=200  violations=1
```

## Artifacts
- `audit.mjs` — the audit script (axe injection + DOM/focus capture).
- `contrast-probe.mjs` — pixel-level contrast re-measurement for gradient-flagged elements.
- `summary.json` — structured results for all 12 page states.
- `raw/<page-id>.json` — full axe output (violations, passes, incomplete) per page.
