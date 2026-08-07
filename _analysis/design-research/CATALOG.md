# Design Capabilities Catalog — Skills, MCP Servers, Knowledge & Uniqueness Approaches

**Date:** 2026-08-06 · **Purpose:** curated, actionable intelligence on FREE / OSS / no-subscription DESIGN capabilities to incorporate (as git submodules / MCP installs / encoded skills) into a design toolkit **combined with OpenDesign** — to produce unique, enterprise-grade, non-repeatable UI/UX across all platforms, OSes, and app types.

**Scope constraint enforced:** only genuinely free / open-source / no-subscription items are recommended. Anything paywalled, unlicensed ("all rights reserved" by default), or abandoned (>~12 months no commits) is INCLUDED for the record but **flagged and EXCLUDED from the "incorporate" list**. Every metric (stars, last-push, license) was verified against the live GitHub REST API / repo / npm / docs page during research (2026-08-06). Where a fact could not be confirmed it is marked **unverified**.

**How this relates to what already exists here:** `_analysis/design-research.md` (2026-08-05) covers *techniques* (scroll-driven animation, view transitions, DTCG tokens, print CSS, responsive images, SEO). This catalog is the complementary *tooling/capability* layer — what to plug in around OpenDesign. `_analysis/OPENDESIGN-ADOPTION-PLAN.md` and the `design-system/` build are the current baseline this augments. Governance context: §11.4.162 mandates OpenDesign as the token source of truth (see companion `INCORPORATION-PLAN.md` for how each item respects that).

**Fit rating** = 1–5, how strongly the item advances *unique, enterprise-grade, cross-platform* design.

---

## RECOMMENDED TO INCORPORATE — ranked shortlist (value × freeness × ease)

Only truly-free, license-clean, actively-maintained items. Ranked by combined leverage.

| # | Item | Type | License | How to add | Why it ranks | Fit |
|---|------|------|---------|-----------|--------------|-----|
| 1 | **anthropics/skills** (frontend-design, theme-factory, web-artifacts-builder, brand-guidelines, canvas-design, algorithmic-art) | Claude skills | Apache-2.0 (per-skill) | plugin marketplace / copy skill dir / submodule | Official, permissive, on-mission; `frontend-design` + `theme-factory` are the aesthetic + theming core | 5 |
| 2 | **material-color-utilities** | Color engine (lib) | Apache-2.0 | npm dep / submodule in token script | Seed→full accessible HCT palette + named "variant" personalities = the deterministic uniqueness primitive | 5 |
| 3 | **Chrome DevTools MCP** | MCP (QA) | Apache-2.0 | `claude mcp add` (already a plugin here) | Best design-QA: Lighthouse a11y/perf + screenshots, fully local; feeds §11.4.170 proof | 5 |
| 4 | **Playwright MCP** | MCP (QA) | Apache-2.0 | `claude mcp add` | Screenshotting/visual-regression backbone, local, vendor-backed | 5 |
| 5 | **Owl-Listener/designer-skills** | Claude skills (239) | MIT | plugin marketplace (vendor subset) | Full design lifecycle (research→systems→handoff); modular so we vendor only complements | 5 |
| 6 | **Style Dictionary** | Token emitter (lib) | Apache-2.0 | npm dep / submodule | DTCG→CSS/iOS/Android/Windows; the cross-platform fan-out layer under OpenDesign | 5 |
| 7 | **color.js (colorjs.io)** | Color engine (lib) | MIT | npm dep / submodule | OKLCH-first, gamut-safe P3, APCA/WCAG contrast; the modern ramp/ harmony math | 5 |
| 8 | **shadcn MCP** (official) + **Jpisnice/shadcn-ui-mcp-server** | MCP (components) | MIT | `npx shadcn@latest mcp` / `claude mcp add` | Registry-driven component reuse, multi-framework (React/Vue/Svelte/RN) | 5 |
| 9 | **GLips/Figma-Context-MCP (Framelink)** | MCP (Figma) | MIT | `claude mcp add` (free Figma PAT) | Only mature *truly-free* Figma-to-code bridge (15.6k★); design ingestion | 5 |
| 10 | **utopia-core** | Fluid scale (lib) | *verify LICENSE* (sibling MIT) | npm dep in token script | Fluid type/space `clamp()` from params; type-ratio = a strong personality axis | 5 |
| 11 | **jezweb/claude-skills** (frontend + design-assets) | Claude skills | MIT | plugin marketplace | Tailwind v4 + shadcn + icon/palette/favicon generation, marketplace-clean | 4 |
| 12 | **nextlevelbuilder/ui-ux-pro-max-skill** | Claude skill | MIT | skill dir / CLI | Widest cross-platform coverage (22 stacks incl. Compose/Flutter/SwiftUI/desktop) | 4 |
| 13 | **chroma.js** | Color engine (lib) | BSD-3-Clause | npm dep / submodule | Tiny perceptual-ramp workhorse (alt/base to color.js) | 5 |
| 14 | **svg.js** | Generative SVG (lib) | MIT | npm dep / submodule | Build-time seeded generative marks/backgrounds = per-project visual signature | 5 |
| 15 | **draw.io MCP (lgazo)** + **Mermaid MCP (peng-shawn)** | MCP (diagrams) | MIT | `npx` / `claude mcp add` | Agent-authored architecture/diagram assets, local | 4 |
| 16 | **x51xxx/coolors-mcp** | MCP (color) | MIT | `claude mcp add` | MD3 + OKLCH + WCAG color ops as a live agent tool (low stars, pilot first) | 4 |
| 17 | **uxKero/anydesign** | Claude skill | MIT | skill dir | Design-to-code token extraction from image/URL/Figma — the ingestion counterpart to OpenDesign | 4 |
| 18 | **google-fonts-mcp** | MCP (fonts) | MIT | `claude mcp add -- uvx` | Offline font pairing → CSS/Tailwind type systems, zero auth | 4 |
| 19 | **sharp-mcp** | MCP (image opt) | MIT | `npx` | Local AVIF/WebP/resize (backs the responsive-image work in design-research.md) | 3 |
| 20 | **kenneives/design-token-bridge-mcp** | MCP (tokens) | MIT | `npm i -g` | DTCG→Material3(Kotlin)/SwiftUI/CSS as a live tool (young; pilot) | 4 |

**Knowledge to ENCODE into skills (not installs) — top open-licensed sources:** WCAG 2.2 + WAI-ARIA APG (W3C, truly open, legally load-bearing) · Material Design 3 (Apache-2.0/CC-BY-4.0, richest vendorable system) · DTCG token spec (open) · Apple HIG (rules-only, paraphrase — copyrighted) · OKLCH + Radix Colors (MIT) + Open Color (MIT) · Every Layout primitives (concepts) + MDN container queries · Utopia fluid type. Details in Category 3.

---

## CATEGORY 1: Claude Skills / Skill Collections for Design

> Star/license/`pushed_at` verified via GitHub REST API on 2026-08-06.

### RECOMMENDED (free + license-clean)

**1. anthropics/skills — official design skills** — Fit 5/5
- URL: https://github.com/anthropics/skills/tree/main/skills
- What: Official skills. Design-relevant: `frontend-design` (distinctive non-templated UI aesthetic), `theme-factory` (fonts + color themes / design-system theming), `web-artifacts-builder` (React+Tailwind+shadcn multi-component artifacts), `brand-guidelines`, `canvas-design` (visual art→PNG/PDF), `algorithmic-art` (generative), `webapp-testing` (Playwright UI verification).
- License: **Apache-2.0** per-skill (`LICENSE.txt` inside `frontend-design/` and `theme-factory/` confirmed; no root LICENSE so API license field is null). Note: the `docx/pdf/pptx/xlsx` document skills are "source-available," NOT OSS — but those are not design skills.
- Install: plugin marketplace (`.claude-plugin/marketplace.json`), or copy a skill folder into `~/.claude/skills/`, or git submodule.
- Maturity: ~166,638★; last push 2026-07-24; official.

**2. Owl-Listener/designer-skills — broadest design-only pack** — Fit 5/5
- URL: https://github.com/Owl-Listener/designer-skills
- What: Largest design-dedicated pack — 239 skills / 88 commands / 33 plugins across design-research, design-systems, ux-strategy, ui-design, interaction-design, prototyping-testing, design-ops, visual-critique.
- License: **MIT**. Install: `/plugin marketplace add Owl-Listener/designer-skills` (also Gemini CLI extensions).
- Maturity: 1,980★; last push 2026-06-14; 55 commits.

**3. nextlevelbuilder/ui-ux-pro-max-skill — cross-platform design intelligence** — Fit 4/5
- URL: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- What: 84 UI styles, 192 palettes, 161 reasoning rules, BM25 style ranking, targeting **22 stacks** (React/Next/Vue/Svelte/SwiftUI/React Native/Flutter/Tailwind/shadcn/**Jetpack Compose**/Angular/JavaFX/WPF/WinUI3/Avalonia/Uno…).
- License: **MIT** (optional PayPal donations; free `ui-ux-pro-max-cli` on npm; no subscription gate).
- Maturity: ~114,056★ (API-reported; single-maintainer); last push 2026-08-06.
- Caveat: single-maintainer, donation-driven; a large "styles catalog" can drift generic unless paired with OpenDesign tokens.

**4. jezweb/claude-skills — Tailwind v4 / shadcn / design-assets** — Fit 4/5
- URL: https://github.com/jezweb/claude-skills
- What: 52 skills / 11 plugins. Design-relevant: `frontend` (Tailwind v4 theming, shadcn, landing pages, React 19, visual design-quality review, RN+Expo) and `design-assets` (color-palette gen, favicon, SVG icon sets, image processing/gen).
- License: **MIT**. Install: `/plugin marketplace add jezweb/claude-skills` → `/plugin install frontend@jezweb-skills`.
- Maturity: 957★; last push 2026-07-02; 717 commits. Sibling: `secondsky/claude-skills` (MIT, 204★, pushed 2026-08-06).

**5. uxKero/anydesign — design-to-code / token extraction** — Fit 4/5
- URL: https://github.com/uxKero/anydesign
- What: Analyzes any image, website URL, or Figma file → structured `design.md` with design system + tokens + component inventory.
- License: **MIT**. Install: copy skill folder into `~/.claude/skills/`.
- Maturity: 151★; last push 2026-06-11.

**6. mattbx/shadcn-skills — shadcn discovery & review** — Fit 3/5
- URL: https://github.com/mattbx/shadcn-skills · **MIT** · 15★ · last push 2026-04-27. Discover 1,500+ shadcn components before building custom; review against shadcn patterns/themes. Narrow but useful for reuse/consistency.

**7. wholiver/swiftui-design-skill — SwiftUI anti-slop** — Fit 3/5
- URL: https://github.com/wholiver/swiftui-design-skill · **MIT** · 164★ · last push 2026-05-01. Apple-platform front-end design with "six rules against AI sloppiness." Single-platform scope.

**8. rohitg00/awesome-claude-design — aesthetic DESIGN.md packs** — Fit 3/5
- URL: https://github.com/rohitg00/awesome-claude-design · **MIT** · 963★ · last push 2026-04-23. 28 `DESIGN.md` exemplars by aesthetic family + "anti-slop" fingerprint toolkit. Prompt scaffolding, not installable skills — good for aesthetic direction / avoiding generic output.

### FLAGGED / EXCLUDED (license or content issues)

- **tommyjepsen/awesome-ux-skills** — 30 UX/product frameworks (personas, journey maps, double diamond, heuristic eval, Dieter Rams, AI-product patterns). 131★, pushed 2026-07-28. **NO LICENSE file → all-rights-reserved; unsafe to vendor.** Excellent content — clarify license before use. Fit 3/5 but blocked.
- **Awesome-list indexes** (discovery only, licenses unconfirmed): `ComposioHQ/awesome-claude-skills` (71,942★, README says Apache-2.0 but API reports none), `travisvn/awesome-claude-skills` (14,536★, no license), `wilwaldon/Claude-Code-Frontend-Design-Toolkit` (604★, no license).
- **obra/superpowers** (267,850★, MIT, very active) — **NOT a design pack**: skills are dev methodology (TDD, debugging, worktrees). Adopt only for workflow discipline. The old `obra/superpowers-skills` is **ARCHIVED** (2025-10-14) — do not depend on it.
- **Figma official Claude plugin** (`figma:figma-generate-design`, etc.) — vendor-distributed, requires Figma account/auth; no verifiable OSS license/public repo. Treat as proprietary integration (present in this environment as a plugin).
- Vendor-scoped skills (not general): Qt (`qt-figma-*`, `qt-ui-design`), Atlassian `forge:atlassian-design-tokens`, Wix `wix-design-system`, Shopify Polaris — useful only within their own SDKs.

---

## CATEGORY 2: Free Design MCP Servers

> "Truly free" = works with no paid subscription. Paid/hosted-gated servers are flagged and excluded.

### 2A — Figma / Icons / Color / Tokens / Image-gen

**Figma access**

- **GLips/Figma-Context-MCP (Framelink)** — Fit 5/5 — https://github.com/GLips/Figma-Context-MCP — **MIT** — reads Figma layout/design data via REST → simplified JSON for agents (`get_figma_data`, `download_figma_images`). **TRULY FREE: free Figma Personal Access Token, any plan** (no Dev Mode seat). Install: `claude mcp add framelink-figma -- npx -y figma-developer-mcp --figma-api-key=YOUR-KEY --stdio`. 15,597★; last push 2026-07-03. The de-facto free design-to-code bridge.
- **open-figma-mcp (Shivam990q)** — Fit 2/5 — https://github.com/Shivam990q/open-figma-mcp — MIT — free PAT; smaller-token alt + token extraction. Only **3★**, single author — unproven vs Framelink.
- ⚠️ **EXCLUDED — Official Figma Dev Mode MCP** — https://developers.figma.com/docs/figma-mcp-server/ — proprietary. Free-tier ~6 calls/month (unusable); real use needs a **paid Dev/Full seat**, and Figma states it "will eventually be usage-based paid." Fails the no-subscription bar.

**Icons**

- **imjac0b/iconify-mcp-server** — Fit 3/5 — https://github.com/imjac0b/iconify-mcp-server — **GPL-3.0** — searches Iconify's 200k+ icons; free, no key. 13★; last push 2025-11-22. Cleanest single-source with a real license (GPL = fine as external tool, note if vendoring code).
- ⚠️ **awssat/mcp-universal-icons** — https://github.com/awssat/mcp-universal-icons — **NO LICENSE** (all-rights-reserved) — best breadth (~10 sets: Material Symbols, Lucide, Tabler, Heroicons, Phosphor, FontAwesome, Feather, Bootstrap, Remix, Iconoir) + Tailwind injection; free via Iconify API. 5★; last push 2026-01-25. Blocked by missing license.
- ⚠️ **Osmansiddiquer/iconify-mcp** (README says MIT but no LICENSE file; 0★) and **agentic-ph/icon-mcp** (MIT but last push 2025-08-01 → stale/abandoned) — both weak.

**Color / palette**

- **x51xxx/coolors-mcp** — Fit 4/5 — https://github.com/x51xxx/coolors-mcp — **MIT** — MD3 support, HCT/OKLCH perceptual color, Delta-E, CSS theme matching, image color extraction, WCAG. **Fully local, no key.** Install: `claude mcp add coolors -- npx -y @trishchuk/coolors-mcp`. 2★; last push 2026-05-20. Most design-system-relevant color server; low stars → pilot first.
- **rog0x/mcp-color-tools** — Fit 3/5 — https://github.com/rog0x/mcp-color-tools — **MIT** — HEX/RGB/HSL/CMYK convert, palette gen (complementary/analogous/triadic/split), WCAG contrast, gradients. Local, no key. 0★; last push 2026-03-21.
- ⚠️ **ColorMcp (keyurgolani)** — MIT, 0★, README "TBD" — verify it works. ⚠️ **color-scheme-mcp (deepakkumardewani)** — NO LICENSE + last push 2025-05-31 (abandoned).

**Design tokens**

- **kenneives/design-token-bridge-mcp** — Fit 4/5 — https://github.com/kenneives/design-token-bridge-mcp — **MIT** — ingests Tailwind/CSS/Figma/**W3C DTCG** → emits Material 3 (Kotlin), SwiftUI, Tailwind, CSS Variables. Local, no key. Install: `npm install -g design-token-bridge-mcp`. 5★; last push 2026-03-25. Only real *MCP server* for DTCG cross-platform output; young → pilot.
- Note: **Style Dictionary** and **tokens-studio/sd-transforms** are libraries/CLI, **not MCP servers** (see Category 4 / knowledge).

**Image / asset generation (free / local)**

- **joenorton/comfyui-mcp-server** — Fit 4/5 — https://github.com/joenorton/comfyui-mcp-server — **Apache-2.0** — drives a **local ComfyUI** (Stable Diffusion) for text-to-image. **Fully local, no paid API** (needs your own ComfyUI + models/GPU). 396★; last push 2026-02-17.
- **artokun/comfyui-mcp** — Fit 4/5 — https://github.com/artokun/comfyui-mcp — **MIT** — local-first ComfyUI control plane (image/video/audio, authors+runs workflows, 178 tools). 508★; last push 2026-08-06 (very active). Heavier than joenorton's.

### 2B — Diagramming / Screenshot / Fonts / Illustration / Motion / Components / Layout / Image-opt

**Diagramming / whiteboard**

- **draw.io MCP (lgazo)** — Fit 4/5 — https://github.com/lgazo/drawio-mcp-server — **MIT** — CRUD draw.io/diagrams.net elements; built-in editor or browser-extension bridge. Fully local, no key. Install: `npx -y drawio-mcp-server --editor`. ~1.4k★, ~266 commits (most-adopted community draw.io MCP).
- **Mermaid MCP (peng-shawn)** — Fit 4/5 — https://github.com/peng-shawn/mermaid-mcp-server — **MIT** — Mermaid code → PNG/SVG via headless Puppeteer, fully local. Install: `claude mcp add mermaid -- npx -y @peng-shawn/mermaid-mcp-server`. ~232★.
- **Excalidraw MCP (official)** — Fit 4/5 — https://github.com/excalidraw/excalidraw-mcp — **MIT** — streams editable hand-drawn diagrams with live canvas control. Fully local (optional hosted endpoint not required). ~5.1k★; build step (pnpm) required.

**Screenshot / visual-diff / browser QA**

- **Chrome DevTools MCP** — Fit 5/5 — https://github.com/ChromeDevTools/chrome-devtools-mcp — **Apache-2.0** — live Chrome automation, DOM/console/network, **Lighthouse audits**, perf traces, screenshots. Fully local (perf-trace URLs go to Google CrUX API + anon usage stats — both opt-out). Install: `claude mcp add chrome-devtools --scope user npx chrome-devtools-mcp@latest`. ~48.6k★. Already a plugin in this environment.
- **Playwright MCP** — Fit 5/5 — https://github.com/microsoft/playwright-mcp — **Apache-2.0** — accessibility-tree-driven browser automation + screenshots. Fully local. Install: `claude mcp add playwright npx @playwright/mcp@latest`. ~35.9k★.
- **MCP Image Compare (leky90)** — Fit 3/5 — https://github.com/leky90/mcp-image-compare-server — **MIT** — Pixelmatch pixel-diff of two images or URL-screenshot-vs-baseline. Local (needs `playwright install chromium`). ~3★ (immature — Playwright's own `toHaveScreenshot` is more battle-tested).

**Fonts**

- **google-fonts-mcp (sliday)** — Fit 4/5 — https://github.com/sliday/google-fonts-skill (PyPI `google-fonts-mcp`) — **MIT** — searches ~1,923 Google Fonts, suggests pairs, emits CSS/Tailwind type systems. Fully local/offline, no key. Install: `claude mcp add google-fonts -- uvx google-fonts-mcp`. ~9★ (niche but self-contained).

**Illustration / SVG**

- **svgo-mcp (undirectlookable)** — Fit 2/5 — https://github.com/undirectlookable/svgo-mcp — MIT — SVGO optimize/minify. 0★. Trivially replaceable by a `svgo` Bash step — low value as a server.
- **svgr-mcp (pchalupa)** — Fit 2/5 — https://github.com/pchalupa/svgr-mcp — license **unverified** — SVG→React via SVGR. Niche.

**Motion / Lottie**

- ⚠️ **mcp-server-lottiefiles (junmer)** — Fit 2/5 — https://github.com/junmer/mcp-server-lottiefiles — MIT — searches LottieFiles. **Almost certainly remote-dependent; whether a token is required is unverified.** ~19★. The vendor "Lottie Creator MCP" is a hosted product tied to a LottieFiles account — **excluded** (not free/local). Prefer CSS/SVG motion (per design-research.md).

**UI component libraries**

- **shadcn MCP (official)** — Fit 5/5 — https://ui.shadcn.com/docs/mcp — shadcn/ui **MIT** — browse/search/install components by NL. Fully local & free for public registries (keys only for private). Install: `npx shadcn@latest mcp init --client claude`.
- **Jpisnice/shadcn-ui-mcp-server** — Fit 5/5 — https://github.com/Jpisnice/shadcn-ui-mcp-server — **MIT** — component source/blocks/demos/metadata across **React, Svelte, Vue, React Native**. Local; optional GitHub token only to raise rate limits. Install: `claude mcp add shadcn -- npx -y @jpisnice/shadcn-ui-mcp-server`. ~2.9k★.
- **Magic UI MCP (official)** — Fit 4/5 — https://github.com/magicuidesign/mcp — **MIT** — search/install Magic UI animated/marketing components. Local, no key. `npx @magicuidesign/mcp@latest`. ~200★.
- **MUI MCP (official)** — Fit 3/5 — https://mui.com/material-ui/getting-started/mcp/ — MUI core MIT (MCP pkg license unstated — verify) — serves MUI docs/examples (docs-grounding, not codegen). Local. `npx -y @mui/mcp@latest`.
- ⚠️ **EXCLUDED — 21st.dev Magic MCP** — https://github.com/21st-dev/magic-mcp — **license unspecified** — 10,000+ React/Tailwind components + AI UI gen, but **requires a 21st.dev API key** and README references "paid code retrieval"; free-tier limits undocumented. Fails the no-subscription bar.

**Layout / grid** — no mature free MCP exists.
- **CarbonoDev/tailwindcss-mcp-server** — Fit 3/5 — https://github.com/CarbonoDev/tailwindcss-mcp-server — MIT, ~38★, local — Tailwind utility/grid/flex guidance + class optimization. Most credible of a thin field. Others pull in paid Gemini keys or are abandoned. Treat layout as a capability of the component/Tailwind servers.

**Image optimization**

- **sharp-mcp (greatSumini)** — Fit 3/5 — https://github.com/greatSumini/sharp-mcp — **MIT** — libvips/Sharp resize/convert/metadata/color-extract + optional local ML bg-removal. Fully local, no key. `npx -y sharp-mcp`. ~11★ (lib is industry-standard).
- **mcp-image-optimizer (piephai)** — https://github.com/piephai/mcp-image-optimizer — license **unverified** — Sharp optimize/resize/convert + LQIP placeholders. Comparable; verify license. (Squoosh forks exist but Squoosh upstream is effectively unmaintained → archival risk.)

---

## CATEGORY 3: Design Knowledge / Method Resources (to ENCODE into skills)

> Distinguishes **truly open** (CC/MIT/Apache — vendorable/quotable) from **free-to-read but copyrighted** (readable; distill rules in your own words) from **PAID**. Facts/heuristics aren't copyrightable — encode the *rules*, not the prose. Vendor sites are usually copyrighted while their sibling code repos are MIT/Apache.

### 3.1 All-platform UI/UX guidelines
- **Apple HIG** — https://developer.apple.com/design/human-interface-guidelines — iOS/iPadOS/macOS/watchOS/tvOS/visionOS. **Free-to-read, COPYRIGHTED** (paraphrase rules only). Fit 5.
- **Material Design 3** — https://m3.material.io/ — color roles, type scale, motion/easing, components, tokens, adaptive layout. **TRULY OPEN — Apache-2.0 / CC-BY-4.0 (vendorable w/ attribution).** Fit 5.
- **Microsoft Fluent 2** — https://fluent2.microsoft.design/ (site copyrighted) + **microsoft/fluentui** code **MIT** (https://github.com/microsoft/fluentui). Fit 4.
- **Windows app design** — https://learn.microsoft.com/en-us/windows/apps/design/ — MS Learn docs generally CC-BY-4.0 (confirm per page). Fit 3.
- **GNOME HIG** — https://developer.gnome.org/hig/ — Linux/GTK conventions; GNOME docs typically CC-BY-SA. Fit 3.
- **WCAG 2.2** — https://www.w3.org/TR/WCAG22/ — accessibility standard (W3C Rec, 2024-12-12). **Free + W3C Document License** (freely readable/redistributable; normative text unmodifiable). Legal baseline. Fit 5.
- **WAI-ARIA APG** — https://www.w3.org/WAI/ARIA/apg/ — accessible design *patterns* (keyboard models + ARIA for menus/dialogs/combobox/tabs…). **TRULY OPEN**, code examples vendorable. Fit 5.
- **WHATWG HTML** — https://html.spec.whatwg.org/multipage/ — **CC-BY-4.0.** Fit 3. · **MDN** — https://developer.mozilla.org/ — content CC-BY-SA, code CC0. Fit 4.

### 3.2 Design-system methodologies
- **Atomic Design (Brad Frost)** — https://atomicdesign.bradfrost.com/ — atoms→pages taxonomy. **Free-to-read, COPYRIGHTED** (distill taxonomy). Fit 5.
- **DTCG token spec** — https://www.designtokens.org/ (drafts https://www.designtokens.org/TR/) — standard token JSON; first stable **2025.10**. **Open** (W3C Community Group). Fit 5.
- **Style Dictionary** — https://styledictionary.com/ — DTCG→CSS/iOS/Android/JS. **TRULY OPEN — Apache-2.0.** Fit 5.
- **IBM Carbon** — https://carbondesignsystem.com/ — enterprise system (tokens, components, a11y, data-viz). **Apache-2.0.** Fit 5.
- **Shopify Polaris** — https://shopify.dev/docs/api/polaris — code **MIT**; docs free. Fit 4. · **GitHub Primer** — https://primer.style/ — code **MIT**. Fit 4.
- ⚠️ **Every Layout** — https://every-layout.dev/ — **PAID ($69)**; intro chapters free (concepts encodable). Fit 5. · ⚠️ **Refactoring UI** — https://www.refactoringui.com/ — **PAID ($99–149)**; buy as team reference, never copy. Fit 4.

### 3.3 Motion / animation
- **Material 3 Motion** — https://m3.material.io/styles/motion/overview — easing tokens, durations, choreography. **Open (Apache-2.0/CC-BY-4.0).** Fit 5.
- **easings.net** — https://easings.net/ — 31 easings + cubic-bezier/CSS. **MIT** (https://github.com/ai/easings.net) — vendorable table. Fit 4.
- **prefers-reduced-motion (MDN)** — https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion — reduced-motion + WCAG 2.3.3 gate. **CC-BY-SA.** Fit 5.
- **Disney 12 principles** — Wikipedia (CC-BY-SA) summary; original book is PAID. Fit 4. (Val Head's book/articles are paid/copyrighted — use Material Motion + easings.net + WCAG instead.)

### 3.4 Color
- **OKLCH picker (Evil Martians)** — https://oklch.com/ — OKLCH/LCH perceptual space + P3 fallbacks. Free/OSS. Encode OKLCH as the palette model. Fit 5.
- **WCAG 2.2 contrast (1.4.3/1.4.11)** — the **legally authoritative** ratios (4.5:1 text, 3:1 large/UI). Enforce this. Fit 5.
- ⚠️ **APCA** — https://github.com/Myndex/SAPC-APCA — perceptual Lc contrast; **bespoke beta-license, pulled from WCAG 3 draft (2023), undetermined as of 2026.** Advisory only, not authoritative. Fit 4.
- **Material 3 color roles** — https://m3.material.io/styles/color/system/overview — semantic roles + tonal palettes. **Open.** Fit 5.
- **Radix Colors** — https://www.radix-ui.com/colors — 12-step accessible scales, APCA-tuned, auto dark, P3. Code **MIT.** Fit 5. · **Open Color** — https://yeun.github.io/open-color/ — 13 hues × 10 shades. **MIT** (v1.9.1). Fit 4.

### 3.5 Typography
- **Utopia** — https://utopia.fyi/ — fluid `clamp()` type/space scales; free calculators (concepts encodable). Fit 5.
- **web.dev Variable Fonts** — https://web.dev/articles/variable-fonts — **content CC-BY-4.0, code Apache-2.0.** Fit 4.
- **Material 3 Typography** — https://m3.material.io/styles/typography/overview — type-scale roles. **Open.** Fit 4. · **MDN CSS text/font** — CC-BY-SA. Fit 3.

### 3.6 Layout
- **Every Layout primitives** (Stack/Cluster/Sidebar/Switcher/Cover/Grid) — https://every-layout.dev/ — PAID but *concepts* encodable. Fit 5.
- **MDN Container Queries** — https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_containment/Container_queries — `container-type`/`@container`/`cqi`. **CC-BY-SA.** Component-level responsiveness. Fit 5.
- **Material 3 Layout & spacing** — https://m3.material.io/foundations/layout/understanding-layout/overview — authoritative free source of the **4/8dp grid**. **Open.** Fit 5. · **MDN Grid/Flexbox** — CC-BY-SA. Fit 4.

**Highest-leverage to encode (open × cross-platform value):** (1) WCAG 2.2 + WAI-ARIA APG — hard a11y gate + widget specs; (2) Material Design 3 whole system — richest vendorable defaults (color roles, type scale, motion, 8pt grid); (3) DTCG + Style Dictionary — token interoperability backbone; (4) Apple HIG rules-only — platform-adaptation checklist for cross-platform nativeness; (5) OKLCH + Radix + Open Color + WCAG contrast — color stack; (6) Every Layout primitives + container queries + 8pt grid — layout engine; (7) Utopia + variable-fonts — fluid type.

---

## CATEGORY 4: Approaches for Unique, Non-Repeatable Per-Project Design

The organizing idea: reduce a project's aesthetic to a small **parameter vector / "design DNA" seed**, deterministically expand it into a full token set, and add build-time seeded generative accents — so every project is distinct-but-on-brand and reproducible (same seed ⇒ same design).

### (A) Parametric token / color tools (seed → full token set)
- **material-color-utilities** — Fit 5 — https://github.com/material-foundation/material-color-utilities — **Apache-2.0** — Google's M3 dynamic color: one seed → HCT space → tonal palettes + role-mapped light/dark scheme. Ships named **scheme variants** (Vibrant/Expressive/Fidelity/Neutral/Monochrome/Fruit-Salad) — each a per-project "personality" dial. TS/Java/Dart/C++/Swift/Kotlin. **The strongest deterministic uniqueness primitive.**
- **color.js (colorjs.io)** — Fit 5 — https://github.com/color-js/color.js — **MIT** — OKLCH-first conversion/interpolation, gamut-safe P3, APCA/WCAG contrast (by CSS Color spec editors). The future-proof ramp/harmony engine.
- **chroma.js** — Fit 5 — https://github.com/gka/chroma.js — **BSD-3-Clause** — tiny perceptual `chroma.scale()` (Lab/Lch), Bezier interpolation, correctLightness. Workhorse for custom harmony ramps (alt/base to color.js).
- **Adobe Leonardo** (`@adobe/leonardo-contrast-colors`) — Fit 4 — https://github.com/adobe/leonardo — **Apache-2.0 (open source, NOT the paid Adobe CC product)** — generates ramps from *target contrast ratios*; adaptive. Personality = contrast curve + background luminance. Optional add for contrast-driven theme modes.
- **Radix Colors custom generator** — Fit 4 — https://github.com/radix-ui/colors (tool https://www.radix-ui.com/colors/custom) — **MIT** — role-semantic 12-step scales from 1–2 seeds; the "safe/restrained" personality.
- **utopia-core** — Fit 5 (technique) — https://github.com/trys/utopia-core — license **to confirm on repo** (npm 403; sibling `tailwind-utopia` is MIT) — `calculateTypeScale/SpaceScale/Clamp` → fluid `clamp()` from params. Type-scale ratio (1.2 vs 1.333 vs 1.5) + spacing multiplier = a strong personality axis. **Verify LICENSE before submoduling.**
- **Style Dictionary** — Fit 5 — https://styledictionary.com / https://github.com/amzn/style-dictionary — **Apache-2.0** — the emitter (not a generator): one generated token set → every platform + per-project overrides. Sits on top of OpenDesign output.
- **Tailwind palette generators** — Fit 3 — tints.dev (**MIT**, https://github.com/SimeonGriggs/tints.dev, has JSON API), uicolors.app, tailwindcss-palette-generator, tailwind.ink — one hex → 11-step scale. Only for Tailwind-native projects; less rigorous than MCU/OKLCH.

### (B) Theme-variation strategies (parameters → many distinct themes)
- **Seed + harmony rules** (Fit 5): hue rotation — complementary +180°, analogous ±30°, triadic ±120°, split-comp. MCU does this internally; or roll your own with color.js/chroma.js. The *harmony rule chosen* is a per-project lever.
- **Scheme "variant" presets** (Fit 5): MCU's Vibrant/Expressive/Neutral/Monochrome/Fidelity — cheapest reliable "make it feel different" switch.
- **Type-scale ratio + font pairing** (Fit 5): ratio sets hierarchy drama; the pairing (geometric-sans display + humanist body vs serif display + grotesque body vs mono accents) sets voice. Curate an OSS font-pair matrix (Google Fonts) keyed to brand adjectives — **highest visual differentiation per unit effort.** Refs: https://madegooddesigns.com/font-pairing/ , https://www.axiswebart.com/blog/fonts-can-express-personality-traits/
- **Shape/roundness + spacing density** (Fit 5): radius base (0 sharp/technical → 8–12px friendly → pill playful) + spacing multiplier (compact vs airy) — big feel change, near-zero risk. Frames these as *ranges*: https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11853653 (style-grammars patent).
- **Contrast/mode variants** (Fit 4): Leonardo contrast curve → "premium dark high-contrast" vs "airy light."
- **Design-personality parameter model** (Fit 4, framework): adjectives (modern/trustworthy/playful/editorial/technical) → {hue temp, chroma, radius, scale ratio, font class, density}. Methodology, not a tool — design your own schema.

### (C) Generative aesthetics libs (build-time marks / backgrounds / textures)
- **svg.js** — Fit 5 — https://github.com/svgdotjs/svg.js — **MIT** — clean resolution-independent SVG creation; seed a deterministic RNG → per-project SVG texture/mark/divider, colors from tokens. Best for *production*.
- **p5.js** — Fit 3 — https://github.com/processing/p5.js — **LGPL-2.1** — creative coding; use at *build time* for offline SVG/PNG assets (note copyleft if ever bundled into shipped JS).
- **seeded-noise** — Fit 3 — https://github.com/andyinabox/seeded-noise — seeded simplex noise for reproducible organic textures (confirm license). · **ribbit** — Fit 3 — https://ribbit.sn4pe.com — **MIT** — hash string→seed→identical SVG mark (deterministic avatars/marks).
- Reference: georgedoescode "Generative SVG Starter Kit" — https://dev.to/georgedoescode/a-generative-svg-starter-kit-5cm1 (technique).
- **Caveat:** keep generative art at *build time* producing static SVG assets — protects performance and accessibility (consistent with design-research.md GPU-only / no-jank rules).

### (D) Seed / "design-DNA" concepts
- **Material 3 dynamic color IS the canonical shipping example** of "one seed → whole accessible system," OSS Apache-2.0 — proof the approach is enterprise-grade, not a blog fantasy.
- **Deterministic-seed principle** (verified via ribbit / seeded-noise): same seed + options + version ⇒ identical output. Derive a project seed = `hash(project-name + domain)` → color seed, hue offsets, scale ratio, radius, pattern params. Reruns stable; projects diverge.
- **No single OSS "brand-in-a-box"** does color+type+space+shape+marks end-to-end — the pieces exist (MCU + Utopia + Style Dictionary + svg.js); assembly is our work. "Design tokens from a seed for AI agents" write-ups (https://www.mindstudio.ai/blog/design-token-system-ai-agents-brand-visuals , https://www.contentful.com/blog/design-token-system/) are methodology, not code.
- **LLM/agent-driven variation** (credible research, not a product): **CPT — "Controllable & Editable Design Variations with Language Models"** https://arxiv.org/html/2604.04380 — choose which attributes vary (color/font/layout) under brand constraints. Practitioner guidance: https://www.uxpin.com/studio/blog/connect-design-system-llms-on-brand-ui/ . **Takeaway:** don't free-form "invent a design"; give the agent a **bounded parameter space** and have it select + justify values → deterministic, on-brand, unique.

### Proposed recipe — "make every Vasic project look distinct on top of OpenDesign"
See `INCORPORATION-PLAN.md` §"Parametric uniqueness layer" for the full pipeline. In brief: a container-only Node token-generator takes a per-project **design-DNA vector** `{seedHue, mcuVariant, typeRatio, spaceMultiplier, radiusBase, fontPairId, contrastMode}` (deterministically derived from a seed) → **material-color-utilities** for HCT palettes + variant personality → **color.js/chroma.js** for custom OKLCH harmony ramps + P3 → **utopia-core** for fluid type/space → radius+density tokens → **Style Dictionary** emits the CSS custom properties the sites consume, with **OpenDesign remaining the structural/semantic source of truth** (this layer only supplies values, honoring §11.4.162 via upstream emission — see plan). Plus **svg.js** build-time seeded marks/backgrounds for a visual signature. The parameter space + adjective→range mapping is encoded as a **theming-designer skill** (constrained selection, not free-form).

---

## Consolidated honesty flags (do NOT incorporate as-is)

- **Paywalled / hosted-gated (excluded):** Official Figma Dev Mode MCP (needs paid seat), 21st.dev Magic MCP (API key + paid retrieval), LottieFiles Creator MCP (hosted account), Refactoring UI ($99–149), Every Layout ($69 — concepts only), Disney *Illusion of Life* / Val Head books.
- **No license = all-rights-reserved (unsafe to vendor until clarified):** awssat/mcp-universal-icons, Osmansiddiquer/iconify-mcp, deepakkumardewani/color-scheme-mcp, tommyjepsen/awesome-ux-skills, most awesome-list indexes (Composio/travisvn/wilwaldon).
- **Copyrighted-but-free-to-read (encode rules, don't copy text):** Apple HIG, Fluent 2 site, Atomic Design online book.
- **Advisory/unsettled:** APCA (bespoke beta license, pulled from WCAG 3 draft) — use as supplementary; enforce WCAG 2.2 ratios.
- **Stale / abandoned (>~12mo):** agentic-ph/icon-mcp (2025-08), color-scheme-mcp (2025-05), obra/superpowers-skills (ARCHIVED 2025-10), Squoosh upstream.
- **Immature (≤5★, single author — pilot before standardizing):** coolors-mcp, mcp-color-tools, design-token-bridge-mcp, open-figma-mcp, google-fonts-mcp, sharp-mcp, MCP Image Compare, svgo-mcp.
- **Unverified licenses to confirm before vendoring:** utopia-core, @mui/mcp package, svgr-mcp, piephai/mcp-image-optimizer, seeded-noise, tailwindcss-palette-generator.
- **Not what the name implies:** obra/superpowers (no design skills); Style Dictionary / sd-transforms / DTCG (libraries/specs, not MCP servers); layout/grid MCPs (no mature free option — use component/Tailwind servers).

---

## 2026-08-07 EXPANSION — additional shortlist (license-tagged)

A second research pass broadened capability coverage (icons, motion, print, TUI, XR, data-viz, full
design systems) and surfaced more FREE/no-key MCPs. Everything below is **truly free / OSS / no
subscription** unless a caveat is stated. This section is **additive** to the shortlist above.

### New generator / library deps (added to `generators/package.json`)

| Item | License | Role |
|------|---------|------|
| **Open Props** | **MIT** | Ready-made design-token breadth (color/space/type/easing/shadow/gradient) complementing the seeded generator. |
| **culori** | **MIT** | Fast, tree-shakeable color-space math (OKLCH/OKLAB/P3/Delta-E) alongside colorjs.io/chroma.js. |
| **Motion** (motion.dev, formerly Framer Motion) | **MIT** | The **OSS motion engine** we standardize on — replaces **non-OSI GSAP**. |
| **@iconify/json** + 9-set icon breadth | **MIT** wrapper (each set keeps its own permissive license) | Offline icon-data engine. Concrete permissive sets pinned: **lucide (ISC)**, **@tabler/icons (MIT)**, **@phosphor-icons/core (MIT)** (+ Material Symbols, Heroicons, Feather, Bootstrap, Remix, Iconoir via Iconify data). |
| **Paged.js** (`pagedjs`) | **MIT** | Print / paged-media (CSS Paged Media polyfill) for PDF/print output. |

**EXCLUDED from deps:** **GSAP** (non-OSI "no-charge" license with redistribution/competitor
restrictions — not OSS; Motion replaces it), **tints.dev** (fine hosted tool, but prefer local
culori/chroma ramps), **Animate.css** (MIT but a prebuilt grab-bag that undercuts the seeded/Motion
approach), **Vivliostyle** (**AGPL-3.0** copyleft — Paged.js is the MIT print path).

### New FREE MCPs (added to `mcp/INSTALL.md` §3b)

| MCP | License | Role |
|-----|---------|------|
| **better-icons** | **MIT** | 200k+ icon search/insertion (Iconify-backed) — iconographer. |
| **mcp-excalidraw-server** | **MIT** | Local editable wireframes/diagrams — ux-flow-designer. |
| **mcp-image-optimizer** | **MIT** | Local image optimize/resize/convert (Sharp superset) — iconographer. |
| **hig-mcp** | **MIT** | Apple HIG search + audit (the FREE replacement for the paid Apple-UI MCP) — design-qa-auditor. |
| **wcag-guidelines-mcp** | **MIT on npm, NO LICENSE file** (CAVEAT — external use only) | WCAG 2.2 success-criteria lookup — design-qa-auditor. |
| **design-systems** (southleft, hosted HTTP) | **MIT** | Design-systems patterns/components/tokens knowledge — layout-architect/theming-designer. |
| **tailwindcss-mcp-server** | **MIT** | Tailwind utility/grid/flex guidance — layout-architect. |
| **@just-every/mcp-screenshot-website-fast** | **MIT** | Fast full-page screenshots — design-qa-auditor. |
| **@antv/mcp-server-chart** | **MIT (hosted-render default; set `VIS_REQUEST_SERVER` for offline)** | 25+ chart types — ux-flow-designer/design-qa-auditor. |
| **daisyui-mcp**, **registry-directory-mcp**, **joenorton/comfyui-mcp-server** | **MIT / MIT / Apache-2.0** | Submodule/build-from-source candidates; ComfyUI is local-only (needs your own GPU). |

### New reference / full design-system repos (submodule candidates, `submodules/PLAN.md` §C-bis)

- **Full systems:** Carbon (**Apache-2.0**), Fluent UI (**MIT**), PatternFly (**MIT**), USWDS
  (**public domain**), GOV.UK Frontend (**MIT**).
- **Headless quartet:** Radix Primitives (**MIT**), Ark UI (**MIT**), Base UI (**MIT**), Headless UI
  (**MIT**).
- **TUI:** Charm lipgloss (**MIT**), bubbletea (**MIT**), Textual (**MIT**).
- **Print:** Paged.js (**MIT**).
- **Data-viz:** D3 (**ISC**), Observable Plot (**ISC**), Vega/Vega-Lite (**BSD-3-Clause**), ECharts
  (**Apache-2.0**), visx (**MIT**).
- **XR:** A-Frame (**MIT**), react-three-fiber (**MIT**), MRTK (**MIT**).
- **npm-dep-preferred default:** pin as npm deps where a package exists; submodule only for
  source-level reference/patching.

### EXCLUDED (2026-08-07 pass) — paid / no-license / copyleft / abandoned

- **Paid / subscription:** Apple UI "design" MCP (paid → use hig-mcp), Figma Dev Mode MCP (paid seat),
  21st.dev Magic MCP (API key + paid retrieval), paid cloud image APIs (TinyPNG / hosted bg-removal /
  cloud image-gen).
- **Copyleft (kept out of vendored tree):** **storybook-mcp-server (AGPL-3.0)**, GPL iconify servers
  (imjac0b et al.), **Vivliostyle (AGPL-3.0)**, GSAP (non-OSI).
- **No LICENSE file (all-rights-reserved / caveat):** awssat/mcp-universal-icons, Osmansiddiquer/
  iconify-mcp, deepakkumardewani/color-scheme-mcp; **wcag-guidelines-mcp** and **material3-style
  servers** declare MIT on npm but ship no LICENSE file → external process only, do not vendor source.
- **Abandoned / archived:** agentic-ph/icon-mcp, archived puppeteer MCP, Squoosh-based optimizers.
- **Hosted-render caveat:** @antv/mcp-server-chart renders remotely unless `VIS_REQUEST_SERVER` is set;
  local image-generation (ComfyUI) needs your own GPU.
