# OpenDesign Design System

The single source of visual truth for **both** sites, all documents, and all PDFs, per Helix Constitution **§11.4.162** (OpenDesign is the mandatory design/token system — no ad-hoc CSS, no other token system). Generated with OpenDesign (`github.com/nexu-io/open-design`) via a verified, LLMsVerifier-approved model.

## Structure

```
design-system/
  brand-milosvasic/    milosvasic.css   DESIGN.md   # personal brand — crimson #a31e39
  brand-vasic-digital/ vasic-digital.css DESIGN.md  # company brand — red #dc3545
  icons/               icons.svg                     # self-hosted SVG sprite (currentColor)
  fonts/               fonts.css + <family>/*.woff2  # self-hosted brand typefaces (OFL 1.1, no CDN)
  preview/             *.html + *.png                # component gallery + rendered proof (light+dark)
  _prompts/            *.md                          # the OpenDesign generation prompts (reproducible)
```

## Architecture — shared foundation + two brand themes

Both stylesheets share an identical **foundation**: typography scale (fluid `clamp()`), spacing (4px base, `--od-space-1..12`), radius, shadow, motion, z-index, container width, and the SAME component set (`.od-*`). They differ **only** in the accent color ramp (crimson vs red) and the dark-accent value. This satisfies "one system governs everything" while keeping the personal and company brands distinct.

- **Tokens**: CSS custom properties on `:root` (light) with a complete dark override in BOTH `:root[data-theme="dark"]` AND `@media (prefers-color-scheme: dark)`. Every component is styled *only* from tokens.
- **Components**: `od-skip-link, od-btn (--primary/--secondary/--ghost + states), od-card, od-chip, od-field/od-label/od-input/od-textarea, od-header/od-nav, od-footer, od-hero, od-stat, od-section (+__eyebrow mono), od-product-card, od-product-detail (article typography), od-table, od-dialog (accessible modal), od-badge--status (--roadmap/--in-development/--beta), od-tag--license`.
- **Accessibility**: WCAG 2.2 AA contrast (status-badge contrast verified/fixed per §11.4.107), `:focus-visible` rings, `prefers-reduced-motion`, logical properties for RTL.

## Extended component library — `components-extended.css`

A single, 100% token-driven stylesheet layered **on top of** either brand CSS (it declares no `:root` — every value is `var(--od-*)`, so it inherits each brand's tokens and is correct for **both brands** and **both themes** automatically). Generated THROUGH OpenDesign in 4 themed batches (prompts in `_prompts/components/`, concatenated; §11.4.162 — no ad-hoc CSS). Every interactive control ships a `:focus-visible` ring (`--od-focus`), hover/active/selected/disabled states, ARIA-friendly class hooks, WCAG 2.2 AA text contrast, and a `prefers-reduced-motion` guard per batch plus a global one.

Load order: `<link>` brand CSS → `components-extended.css` → `motion/animations.css`.

Catalog (all `od-` prefixed):

- **Overlays**: `od-toast` + `od-toast-region` (`--success/--warning/--danger/--info`, `__icon/__body/__title/__msg/__close`); `od-menu`/`od-dropdown` (`__item[aria-disabled]/__separator/__label`); `od-select` (`__control[aria-expanded]/__chevron`); `od-tooltip` (`__bubble[data-placement]`); `od-popover` (`__arrow/__title/__body`); `od-fab` (+`--sm`).
- **Forms**: `od-switch` (`__input/__track/__thumb`); `od-checkbox` (`__box`, checked + `:indeterminate`); `od-radio` (`__dot`); `od-range` (cross-browser `input[type=range]` thumb/track); `od-segmented` (`__option[aria-selected]`); `od-search` (`__input/__icon/__clear`); `od-stepper` (`__btn/__input`, no native spinners).
- **Nav + feedback**: `od-tabs` (`__list/__tab[aria-selected]/__panel`); `od-breadcrumb` (`__list/__item[aria-current]/__link`); `od-pagination` (`__link[aria-current]/[aria-disabled]`); `od-progress` (+`--indeterminate`, `__bar`); `od-spinner` (+`--sm/--lg`, `od-visually-hidden` label helper); `od-skeleton` (+`--text/--circle`); `od-alert`/`od-banner` (`--success/--warning/--danger/--info`, `__icon/__title/__body`); `od-avatar` (+`--sm/--lg/--ring`, `od-avatar-group`); `od-empty-state` (`__icon/__title/__msg/__action`).
- **Chrome**: tasteful custom scrollbar — global `html` + opt-in `.od-scroll` (Firefox `scrollbar-color`/`scrollbar-width` + WebKit `::-webkit-scrollbar*`), all token-colored.

Proof: `preview/components.html` instantiates every component; `_tests/visual/visual-oracle.js` at full-page height (`1280x8000`) returns **PASS** in light **and** dark (0 overlap/clip/giant). WCAG spot-checks (toast/alert title & body, dropdown item) all clear ≥4.5:1 in both themes. Evidence: `_tests/evidence/components/{components.{light,dark}.png,components.verdict.json,wcag-contrast.txt}`.

## How each surface consumes it

- **milosvasic.ru** (Jekyll): `@import`/`@use` `brand-milosvasic/milosvasic.css` into `assets/css/style.scss`; components use `.od-*` and `var(--od-*)` only.
- **vasic.digital** (static): `<link>` `brand-vasic-digital/vasic-digital.css`; markup uses `.od-*`.
- **Docs & PDFs**: the same tokens feed the pandoc→weasyprint pipeline (composed with the constitution `styles/default-pdf.css`), so CV / Cover Letter / Portfolio share the web design language.

## Fonts — self-hosted (`fonts/`)

The three brand typefaces are **self-hosted** under `fonts/` — **zero CDN, zero external `@import`** (privacy / GDPR + §11.4.162 "no external font @import"). All three are **SIL Open Font License 1.1** (freely self-hostable); the full `OFL.txt` for each sits beside its woff2 files.

- **Inter** (body, `--od-font-body`) — weights 400 / 500 / 600 / 700 — `fonts/inter/`
- **Space Grotesk** (display, `--od-font-display`) — weights 500 / 600 / 700 — `fonts/space-grotesk/`
- **JetBrains Mono** (mono, `--od-font-mono`) — weights 400 / 500 — `fonts/jetbrains-mono/`

The woff2 are subset by script — **latin, latin-ext, cyrillic, cyrillic-ext** (the sites include Cyrillic languages) — and `fonts.css` sets `unicode-range` per subset so a page fetches only the scripts it uses. Each family is a **variable** woff2 (one file per subset covers the whole weight axis); `fonts.css` emits a per-weight `@font-face` that pins `font-weight` to each instance, all with `font-display: swap` and `src: url('<family>/<file>.woff2') format('woff2')`, and `font-family` names matching the tokens exactly (`Inter`, `Space Grotesk`, `JetBrains Mono`).

**Script coverage (honest):** **Space Grotesk is Latin-only** — it has no Cyrillic, so Cyrillic *display* headings fall back to the body font (Inter, which does cover Cyrillic). **Arabic and CJK glyphs are NOT present** in any of these Latin/Cyrillic families — Arabic (`ar`) and CJK (`zh`/`ja`/`ko`) text falls back to the system stack in each brand's `--od-font-*` token. That is expected and acceptable for these brand faces.

**How pages include it** — add once, **before** the brand stylesheet, so the `@font-face` families are defined before the tokens reference them:

```html
<link rel="stylesheet" href="/design-system/fonts/fonts.css">
<link rel="stylesheet" href="/design-system/brand-<brand>/<brand>.css">
```

For Jekyll (milosvasic.ru) the SCSS `@import`s the brand CSS; add the `fonts.css` `<link>` in the site `<head>` (or `@import "../fonts/fonts.css";` from the brand SCSS entry). No `@import` reaches any external host — every `src` is a repo-relative `.woff2`.

**Rendered proof + validation.** `fonts/preview.html` links only `fonts.css` and renders pangrams and display/body/mono samples (Latin + Cyrillic) at every weight. Verified with headless Chromium (`_tests/node_modules`): the CSS Font Loading API reports all three families `loaded`, the browser fetched each self-hosted woff2 over `file://`, and **zero external requests** were made. Evidence: `_tests/evidence/fonts/{fonts-preview.png, font-load-report.json, network-requests.txt}`. Each woff2 is a valid Web Open Font Format (Version 2) file (`file(1)` / `wOF2` magic).

## Reproducibility (§11.4.77)

Regenerate a brand stylesheet:
```sh
_tools/od/start-daemon.sh                      # headless OpenDesign daemon (Electron runtime)
bash _tools/od/generate.sh design-system/_prompts/<brand>.md design-system/brand-<brand>/<brand>.css other 24000
```
Rebuild + re-render the proof gallery:
```sh
node _tools/od/build-preview.mjs
NODE_PATH="$PWD/_tests/node_modules" node _tools/od/shoot.cjs '<jobs-json>'
```
BYOK: `source ~/api_keys.sh`; provider = openai-compatible, base `https://api.mistral.ai/v1`, model `codestral-latest` (LLMsVerifier-verified, `code:true`, score 0.919). Keys are sourced at runtime, never stored.

## Evidence

`preview/{milosvasic,vasic-digital}-{light,dark}.png` — full-page renders of the component gallery in both themes for both brands (§11.4.170 spirit). Regenerate anytime with the commands above.
