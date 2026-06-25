# Dual-Site Rebuild — Design & Architecture Spec

**Date:** 2026-06-17
**Author:** Milos Vasic (milos85vasic) + Claude Code
**Scope:** Rebuild `milosvasic.ru` (personal CV/portfolio) and `vasic.digital` (company site) into cutting-edge, enterprise-grade, fully responsive, multilingual, dark/light, deeply-tested websites driven by REAL repository data.

> Status legend: ✅ done · 🔄 in progress · ⏳ blocked on data · ⬜ todo

---

## 1. Current State (verified on disk)

### milosvasic.ru — personal CV
- **Stack:** Jekyll, `jekyll-theme-cayman` (`_config.yml` = single line). Content lives in `README.md`, rendered as index.
- **Broken:** `_layouts/default.html` contains leftover **"Limo Serbia"** limousine-site metadata (description/keywords). Must be replaced.
- **Assets:** `assets/images/milosvasic.png`, CV PDFs (`Milos_Vasic_CV_EN.pdf`, `Milos_Vasic_CV_FULL.pdf`), `Fundamental_Kotlin_3rd_Edition.pdf`. Scattered.
- **Cover letter / CVs:** in `pages/` (`Cover_Letter.md`, `Cover_Letter.pdf`, `Milos_Vasic_CL.pdf`, `Milos_Vasic_CV*.pdf`) AND `assets/pdf/`. Duplicated/scattered.
- **No i18n. No theme toggle. No responsive design beyond Cayman defaults.**
- **Brand color:** `#a31e39` (crimson).
- **Remotes:** `github` (milos85vasic/milosvasic.net.v2), `gitflic` (milosvasic-net-v-2), plus `origin`/`upstream` mixing both. **Submodule:** `Upstreamable` → red-elf/Upstreamable.

### vasic.digital — company site
- **Stack:** static HTML/CSS/JS. `index.html` (749 lines), `css/style.css` (1000 lines, has light/dark vars), `css/logo.css`, `js/translations.js` (29 langs, many sparse), `js/language-switcher.js`, `js/script.js`.
- **Sections:** header/nav (+theme toggle, hamburger), hero, about (+stats), services (8 cards), portfolio (19 hand-crafted SVG project cards), contact, footer.
- **Logo:** `Assets/Logo.jpeg` (543 KB, white background). **MUST KEEP** (per user). `LOGO_CONVERSION.md` requests a transparent PNG version.
- **Brand color:** red `#dc3545` family.
- **Inconsistencies to fix:** "since 2024" (README) vs "since 2023" (footer) vs "© 2025"; unverified claims (e.g., HelixTrack "50,000+ req/s", "102% parity", "387 API actions") — MUST verify against real READMEs or soften.
- **References org `Bear-Suite`** (not in user's listed orgs) — flag/confirm.
- **Remote:** single GitHub `vasic-digital/vasic-digital.github.io`.

---

## 2. Data Foundation (running now — 4 background agents)

| Artifact | Source | Status |
|---|---|---|
| `_analysis/github-vasic-digital.{json,md}` | GH org vasic-digital (185) | 🔄 |
| `_analysis/github-helix-others.{json,md}` | GH HelixDevelopment(30)+Helix-Track(13)+Helix-Flow(1)+Server-Factory(12) | 🔄 |
| `_analysis/gitlab-all.{json,md}` | GL groups (vasic-digital 100 + others) | 🔄 |
| `_analysis/research-best-practices.md` | Web research (CV/HR/company/i18n/theming) | 🔄 |

**Next:** synthesize `_analysis/MASTER-inventory.md` — deduped (GH↔GL mirrors, forks removed), ranked by size, tagged by org & product family, with a curated "FEATURED" set (biggest/most advanced) and a "MORE" long-tail.

---

## 3. Target Architecture

### Shared design system (both sites)
- **Tokens:** CSS custom properties for color/space/type/radius/shadow; `[data-theme="dark|light"]` on `<html>`.
- **Theme toggle:** respects `prefers-color-scheme`, persists to `localStorage`, **inline no-flash script** in `<head>`.
- **i18n:** vanilla-JS dictionary + `data-i18n` attributes + language switcher (reuse vasic.digital pattern). `hreflang`/`lang` set correctly; RTL handling for `ar`, `fa`, `he`.
- **Responsive:** mobile-first, fluid type (`clamp()`), CSS grid/flex, tested at 320/375/768/1024/1440.
- **A11y:** WCAG 2.2 AA — semantic landmarks, focus states, contrast, reduced-motion, alt text.
- **Perf:** self-host fonts where feasible, lazy-load images, minimal JS, Lighthouse ≥ 90.

### milosvasic.ru (personal CV) — **DECISION: stay on Jekyll**, custom theme
- Rationale: GitHub Pages builds Jekyll natively; CNAME + Pages already wired. Avoids new build pipeline.
- Replace Cayman with custom `_layouts/default.html` + `_includes/` + custom SCSS (no theme gem). Keep `assets/css/style.scss` entrypoint.
- Sections (HR/ATS-optimized, order per research): Hero (name, title, photo, CTAs) → Summary → Highlighted projects (from FEATURED data) → Experience → Skills → Author/Books → Education → Contact.
- **Profile photo:** `~/Pictures/Profile.jpg` → processed/optimized into `assets/images/profile.jpg` (responsive sizes), themed framing.
- **Downloads (new requirement):** `downloads/` dir with stable direct links:
  - `downloads/Milos_Vasic_CV.pdf` (ATS-friendly), `downloads/Milos_Vasic_CV_EN.pdf`, language variants as feasible.
  - `downloads/Milos_Vasic_Cover_Letter.pdf`.
  - Generated from canonical Markdown via a documented pipeline; linked from the site header/hero.
- i18n + theme toggle added (mirror company pattern). Core langs EN/RU/SR fully; framework for more.

### vasic.digital (company) — refresh + polish, keep foundation
- Keep `Logo.jpeg` (also produce optional transparent PNG per `LOGO_CONVERSION.md`, but default stays the JPEG logo).
- Rebuild portfolio from REAL deduped data: client-facing framing (value/outcomes, not internal jargon). Featured grid + filterable "all projects".
- Fix date/claim inconsistencies; verify or soften superlatives.
- Complete/clean i18n for core langs; keep switcher.
- Enhance design to "cutting-edge enterprise" (motion tasteful, dark/light parity, trust signals, clear CTAs).

---

## 4. Testing Strategy (in-depth — "rock-solid evidence")
- **HTML validation:** `html-validate` / W3C nu validator.
- **Unit:** Node tests for i18n dictionary completeness (every key present per core lang), theme persistence logic.
- **E2E / cross-browser / responsive / visual:** **Playwright** (Chromium, Firefox, WebKit) — nav, theme toggle persists + no FOUC, language switch updates DOM + `lang`/`dir`, all links resolve, downloads return 200, responsive layouts at breakpoints, screenshots committed as evidence.
- **A11y:** axe-core via Playwright.
- **Perf:** Lighthouse (chrome-devtools MCP) — budget ≥ 90 perf/a11y/best-practices/SEO.
- **Link/asset integrity:** crawl for 404s; verify PDFs open.
- All test runs produce committed artifacts (reports, screenshots) under each repo's `tests/` + `_analysis/test-evidence/`.

---

## 5. Delivery
- Commit per logical unit. Update submodule `Upstreamable` if touched.
- Push to ALL upstreams: milosvasic.ru → `github` + `gitflic`; vasic.digital → `github`.
- Deploy: both are GitHub Pages (push to default branch = deploy). Verify live after push.

---

## 6. Key Decisions (assumed defaults — autonomous mode; correct if wrong)
1. milosvasic.ru stays **Jekyll** (custom theme), not a rewrite to a JS framework.
2. Full professional translations for **EN, RU, SR** core; remaining ~26 langs use the existing framework + best-effort (NOT claimed as native-perfect — no bluff).
3. Company **Logo.jpeg preserved** as primary; transparent PNG optional.
4. "Major projects to highlight" chosen by **size + advancement signals** from real data (stars, recency, README depth), curated to ~8–12 featured.
5. Photo source corrected to `Profile.jpg` (user wrote `.jpeg`; `.jpeg` does not exist).
6. `Bear-Suite` projects retained in company portfolio (already present) pending confirmation; not in scope for personal CV unless data warrants.

---

## 7. Open Questions (non-blocking; proceeding with defaults)
- Exact set of "major languages" to FULLY translate vs. framework-only.
- Whether to mirror milosvasic.ru i18n into the Russian-market focus (RU primary?) given `.ru` domain.
- Confirm `Bear-Suite` inclusion and any private repos that should/shouldn't be surfaced publicly.
