# Deep Live-Interaction Sweep — Pre-Deploy Gate

Driver: Playwright 1.61 (Chromium ≈ Yandex). Read-only. Built output served locally
(`milosvasic.ru/_site` @ :8082, `vasic.digital` @ :8401).
Viewports: tablet 1024×768, mobile 390×844, desktop 1440×900.
Raw data: `results.json` (385 assertions). Evidence PNGs in this folder.

## Verdict: PASS with ONE real defect

- **314 PASS / 385** on first machine pass.
- After manual verification of every non-PASS row, **only ONE is a genuine user-facing
  defect** (milos mobile nav). The rest are harness selector mismatches or by-design.

---

## Genuine defect (should be addressed)

| # | Sev | Site | Pages | Viewport | Element | Selector | What's wrong |
|---|-----|------|-------|----------|---------|----------|--------------|
| 1 | MEDIUM | milosvasic.ru | ALL (home, portfolio, all products) | **mobile 390** only | Primary nav links (Work/Experience/Skills/Contact) | `nav.nav .nav-links a` | Hidden at ≤760px via `@media(max-width:760px){.nav-links{display:none}}` in `assets/css/style.css`, and there is **NO hamburger / mobile menu** replacement. On a phone the 4 in-page section links are unreachable. Brand (→home), language, and theme controls DO remain in the header, and sections are still reachable by scrolling, so it's degraded — not total breakage. Tablet 1024 and desktop are unaffected (breakpoint is 760px). Evidence: `DEFECT-milos-mobile-390-nav-missing.png`, `DEFECT-milos-mobile-390-fullheader.png` vs `OK-milos-tablet-1024-nav-present.png`. vasic.digital's `.od-nav` stays visible at 390 and passed. |

---

## Non-PASS rows that were verified NOT defects (false positives / by-design)

| Reported | Rows | Reality (verified) |
|----------|------|--------------------|
| vasic Lang switcher "BROKEN — lang unchanged=en" | 15 | FALSE POSITIVE. Harness clicked the first menu item, which is **English (current)** → no change. Manual probe: selecting Беларуская flips `<html lang>` en→be in place (`od-i18n.js applyDict`). Switcher works on every vasic page/viewport. |
| vasic Footer links "MISSING" | 18 | BY DESIGN. `<footer class="od-footer">` is intentionally text-only ("© 2026 Vasic Digital — built on the OpenDesign system.") with no `<a>`. milos footer has links (15 PASS). |
| vasic portfolio Theme toggle + Brand "MISSING" | 6 | HARNESS SELECTOR MISS. Portfolio uses `#pf-theme-toggle` (not `#od-theme-toggle`) and brand as `a.od-nav__link` (not `a.od-brand`). Probe: theme flips null→dark; brand href=`../index.html` → home. Both functional. |
| milos article page Theme/Lang/Back-to-top/Footer/Brand "MISSING" | 15 | NOT A NAV TARGET. `/articles/en/*.html` are bare HTML fragments (no site chrome, no `<title>`) injected into the on-page article modal. milos home has **0** direct `<a href*="/articles/">` links — they are never loaded as standalone pages. The real "doc" surface is the CV/Cover-Letter/Portfolio download modal, which PASSED. |

---

## Everything that PASSED (verified working, both sites unless noted)

| Check | Result |
|-------|--------|
| Header nav links (desktop + tablet, both sites) | 76 PASS — hash links scroll to existing target section; subpage `/#work` etc. navigate to home and land on the section; vasic cross-page links navigate. |
| Brand / logo → home | 27 PASS (+6 selector-miss that are functional). |
| Theme toggle (`data-theme` flip + persists across reload) | 27 PASS (+6 selector-miss functional; milos article n/a). |
| Language switcher | milos 15 PASS (flips `<html lang>`); vasic verified functional (see above). |
| Download (milos CV/CL/Portfolio modal opens; PDFs resolve) | 12 PASS — modal opens, referenced PDFs return HTTP 200; vasic Portfolio_EN.pdf 200. |
| Read-more / product-card links | 6 PASS — navigate to the product page. |
| Accordion / disclosure (product pages) | 18 PASS — `aria-expanded` toggles + panel visibility changes. |
| Back-to-top floating button | 30 PASS (hidden at top, appears after scroll, click → scrollY 0, name "Back to top"); 3 n/a (short article fragment). |
| Footer links | milos 15 PASS all valid href; vasic text-only by design. |
| Images (logo, portrait, diagrams) naturalWidth>0 | 33/33 PASS — no broken images. vasic brand renders the real `Assets/Logo.jpeg`/`logo.webp`, not a monogram. |
| Horizontal overflow (tablet + mobile) | 22/22 PASS — `scrollWidth ≤ innerWidth+1` everywhere. |
| Console errors / pageerrors | 33/33 PASS — clean on every page/viewport. |

## Pages covered
- milosvasic.ru: `/`, `/portfolio/`, `/products/helixcode.html`, `/products/catalogizer.html`, `/products/mail-server-factory.html`, `/articles/en/catalogizer.html`
- vasic.digital: `/index.html`, `/portfolio/`, `/products/helixcode.html`, `/products/catalogizer.html`, `/products/mail-server-factory.html`
- × 3 viewports each.
