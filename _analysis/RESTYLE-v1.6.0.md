# RESTYLE v1.6.0 — Bold Re-Style (both sites)

> Umbrella analysis note. Documents the shipped v1.6.0 bold re-style for both
> sites, its accessibility/safety evidence, the rejected alternates, the new
> self-hosted fonts, and how it was generated. **Faithful to the re-style
> evidence under `_tests/evidence/restyle/` — every axe/behavior/overflow number
> below is quoted from those files.** This file is umbrella documentation only;
> it changes no site code.

---

## 1. Overview

v1.6.0 is a **bold re-style** of both properties. Each site was generated as two
distinct candidates (A and B); **Candidate A shipped** on both, Candidate B is
retained as a re-appliable alternate (§4). The **brand accent hue is locked** on
each site and was carried through unchanged.

### vasic.digital → Candidate A **"MACHINA"**
Industrial-precision grotesque. Oversized machined display headings in
**Bricolage Grotesque** (self-hosted, OFL 1.1), **sharp corners (0–4px radii)**, a
whole-page faint **blueprint technical grid**, hard-edged layered depth (hairline
ring + 10px hard-offset accent shadow), tight uppercase mono accents, and a slow
accent **scanline** sweep over a drifting deep-red gradient-mesh in the hero.
Brand hue **kept**: deep dark-red ramp, accent `#8f1d2d` (`--od-accent-700`).
Evidence: `_tests/evidence/restyle/vasic/candidateA.css` (header + tokens).

### milosvasic.ru → Candidate A **"TERMINAL BRUTALIST"**
Bold crimson dossier. Monumental **uppercase Anton** display (self-hosted, OFL),
**2px ink frames** (`--od-border:#2a241d`), **hard offset print-shadows**
(`3px/5px/8px 8px 0`), square geometry (1–3px radii), mono index ticks/eyebrows,
and a subtle **engineering-grid** paper texture behind everything. Snap-lift hover
(`translate(-3px,-3px)`). Brand hue **kept**: crimson `#a31e39`.
Evidence: `_tests/evidence/restyle/milos/candidateA/_append-od.css` +
`_append-chrome.scss` (headers + tokens).

### Restore points (rollback)
| Scope | Restore point |
|-------|---------------|
| vasic.digital | **v1.5.0** |
| milosvasic.ru | **v1.5.2** |
| umbrella (vasic monorepo) | **pre-restyle** commit |

Pristine pre-restyle sources are also preserved in the evidence tree:
- vasic OD baseline: `_tests/evidence/restyle/vasic/_ORIGINAL-vasic-digital.css`
- milos baselines: `_tests/evidence/restyle/milos/_base/milosvasic.css.orig`,
  `design-system-milosvasic.css.orig`, `style.scss.orig`

---

## 2. Design-DNA per site (shipped Candidate A)

Axes sourced from the candidate CSS headers/token blocks. Body face (Inter) and
mono face (JetBrains Mono) are unchanged on both sites; only the **display**
axis and shape/depth/motion/voice change.

### vasic.digital — "MACHINA"
| Axis | Change |
|------|--------|
| **Type** | Display → **Bricolage Grotesque 700/800** (was Space Grotesk); oversized machined headings, punchier top-end type scale; tight uppercase JetBrains-mono accents. Body Inter / mono JetBrains unchanged. |
| **Shape** | **Sharp machined corners** — `--od-radius-sm/md: 0`, `lg: 2px`, `xl: 4px`, pill `9999px`. |
| **Spacing** | Standard OD spacing scale; type scale top end widened for oversized headings (`--od-fs-2xl` up to ~2.9rem). |
| **Depth** | **Hard-edged layered depth**: `--od-shadow-sm: 0 0 0 1px hairline`; `--od-shadow-lg: 0 0 0 1px border, 10px 10px 0 -1px` hard accent. |
| **Motion** | **GPU-only (transform/opacity)**: drifting deep-red gradient-mesh (`vd-aurora-drift`), edge-masked technical grid, slow accent **scanline** (`vd-scan`). Reduced-motion → all off. |
| **Voice** | Blueprint/technical — whole-page faint grid texture, uppercase mono index labels, industrial-precision grotesque. |
| **Color (locked)** | Deep dark-red hue kept; accent `#8f1d2d`. Cool "machined" light neutrals (bg `#fff`, text `#141519`). |

### milosvasic.ru — "TERMINAL BRUTALIST"
| Axis | Change |
|------|--------|
| **Type** | Display → **Anton 400, uppercase** (was Space Grotesk); monumental hero slab `clamp(3rem,9vw,6rem)`, giant Anton stat figures; uppercase mono eyebrows with crimson index block. Body Inter / mono JetBrains unchanged. |
| **Shape** | **Square** — `--od-radius-sm:1px`, `md/lg:2px`, `xl:3px`, pill `2px`; **2px ink frames** on cards/stats/buttons/accordion. |
| **Spacing** | OD spacing scale retained; container max `1120px`. |
| **Depth** | **Hard offset print-shadows** — `--od-shadow-sm:3px3px0`, `md:5px5px0`, `lg:8px8px0` crimson; card hover `translate(-3px,-3px)` snap-lift to `7px7px0` accent. |
| **Motion** | Minimal snap transitions (`--od-dur-fast`); subtle static **engineering-grid** paper texture (`body::before`, very low alpha). Reduced-motion neutralized by the global guard. |
| **Voice** | Bold crimson "dossier" brutalism — mono index ticks, uppercase buttons (`letter-spacing:.05em`), crimson underline slabs under section titles. |
| **Color (locked)** | Crimson hue kept; accent `#a31e39`. Warm paper light (bg `#f4f1ea`, ink `#16130f`); dark theme bg `#14110d`, accent `#f05a6f`. |

---

## 3. Accessibility + safety evidence

All numbers below are quoted verbatim from the evidence JSON. **Zero
serious/critical, zero total violations, zero horizontal overflow** on every
tested page/theme, on both shipped and alternate candidates.

### vasic.digital — Candidate A (shipped)
- **axe (home):** `total: 0`, `serious: 0`, `violations: []`
  — `_tests/evidence/restyle/vasic/candidateA/axe-home.json`
- **axe (product/helixcode):** `total: 0`, `serious: 0`, `violations: []`
  — `_tests/evidence/restyle/vasic/candidateA/axe-product-helixcode.json`
- **overflow / summary:** home `overflowDesktop: 0, overflowMobile: 0`;
  product-helixcode `overflowDesktop: 0, overflowMobile: 0` (both also
  `axeSerious: 0, axeTotal: 0`)
  — `_tests/evidence/restyle/vasic/candidateA/summary.json`
- **reduced-motion:** `@media (prefers-reduced-motion: reduce)` neutralizes all
  animation and forces the scanline `animation: none; transform: translateY(-120%); opacity: 0`
  — `_tests/evidence/restyle/vasic/candidateA.css` (~L570–583)

### milosvasic.ru — Candidate A (shipped)
- **axe (all 4 states):** `home-light`, `home-dark`, `product-light`,
  `product-dark` each `violations: 0`, `serious_critical: 0`, `impacts: {}`
  — `_tests/evidence/restyle/milos/candidateA/axe.json`
- **overflow:** `home_mobile_overflow: false`, `product_mobile_overflow: false`
  — same file.
- **behavior intact (all pass):** `hamburger_visible: true`,
  `navlinks_open_after_click: true`, `nav_toggle_aria: "true"`,
  `lang_menu_open: true`, `lang_menu_items: 15`, `download_modal_open: true`,
  `download_modal_langs: 15`, `back_to_top_present: true`,
  `back_to_top_visible_after_scroll: true`
  — `_tests/evidence/restyle/milos/candidateA/behavior-check.json`
- **reduced-motion:** global guard in the chrome layer
  (`prefers-reduced-motion: reduce` → `animation/transition-duration:.001ms`,
  `scroll-behavior:auto`) plus per-component guards (nav, article modal,
  download modal); the Terminal Brutalist append relies on this global guard.
  — `_tests/evidence/restyle/milos/candidateA/style.scss` (~L45, L203, L521, L561)

### Both sites — Candidate B (alternate) also passed
- vasic B: axe home/product `total:0, serious:0`; summary overflow all `0`
  — `_tests/evidence/restyle/vasic/candidateB/{axe-home,axe-product-helixcode,summary}.json`
- milos B: axe all 4 states `violations:0, serious_critical:0`; no mobile overflow
  — `_tests/evidence/restyle/milos/candidateB/axe.json`
- vasic B additionally ships **reduced-transparency + no-backdrop-filter
  fallbacks** (glass → opaque `--vd-glass-solid`) via
  `@supports not (backdrop-filter…)` and `@media (prefers-reduced-transparency: reduce)`
  — `_tests/evidence/restyle/vasic/candidateB.css` (~L268, L275).

---

## 4. The rejected alternates (Candidate B) — re-appliable

Both B candidates cleared the same accessibility/overflow gates (§3) and are kept
as drop-in alternates. Their fonts are already deployed to the sites (§5), so
re-applying is a stylesheet swap/append.

### vasic.digital — Candidate B **"VOLTAGE"**
Expressive editorial: high-contrast **Fraunces** serif with true-italic accents,
soft/large radii, **frosted-glass panels** floating over a warm deep-red
gradient-mesh, airy perfect-fourth rhythm, warm editorial cream light theme
(bg `#fbf6f3`). Glass has opaque + reduced-transparency fallbacks. Brand hue
locked (`#8f1d2d`). Source: `_tests/evidence/restyle/vasic/candidateB.css`.

**Re-apply (swap the OD stylesheet; Fraunces already in `assets/od/display/`):**
```sh
cp _tests/evidence/restyle/vasic/candidateB.css \
   vasic.digital/assets/od/vasic-digital.css
# (to restore MACHINA / shipped: cp _tests/evidence/restyle/vasic/candidateA.css → same target)
```

### milosvasic.ru — Candidate B **"LUMINOUS CRIMSON GLASS"**
Editorial glass: **Fraunces** display serif (600/900), soft large radii
(8–28px), frosted nav/cards/modals (`backdrop-filter` blur), layered
crimson-tinted shadows, glowing accents, a radial crimson aurora behind the hero.
Brand hue locked (`#a31e39`). Source:
`_tests/evidence/restyle/milos/candidateB/_append-od.css` + `_append-chrome.scss`.

**Re-apply (append the two layers, then recompile SCSS; Fraunces already in
`assets/od/fraunces/`):**
```sh
cat _tests/evidence/restyle/milos/candidateB/_append-od.css \
    >> milosvasic.ru/assets/od/milosvasic.css
cat _tests/evidence/restyle/milos/candidateB/_append-chrome.scss \
    >> milosvasic.ru/assets/css/style.scss
# recompile style.scss → style.css per the site's build
```

> **Shipped Candidate A** was applied the same way from the A directory:
> vasic → `candidateA.css` copied over `assets/od/vasic-digital.css`; milos →
> `candidateA/_append-od.css` appended to `assets/od/milosvasic.css` and
> `candidateA/_append-chrome.scss` appended to `assets/css/style.scss`.

---

## 5. New self-hosted fonts

All new faces are **OFL, self-hosted (no CDN, no external `@import`)**,
`font-display: swap`, split **latin + latin-ext** (Cyrillic display falls back to
the body font, as the prior shared Space Grotesk face did). Body **Inter** and
mono **JetBrains Mono** are unchanged on both sites.

| Site | Candidate | Face | Weights / styles | Deployed to | Files |
|------|-----------|------|------------------|-------------|-------|
| vasic.digital | **A (shipped)** | **Bricolage Grotesque** (OFL 1.1) | 700, 800 | `vasic.digital/assets/od/display/` | `bricolage-700-latin{,-ext}.woff2`, `bricolage-800-latin{,-ext}.woff2` |
| vasic.digital | B (alternate) | **Fraunces** (OFL 1.1) | 600, 700, italic 600 | `vasic.digital/assets/od/display/` | `fraunces-600-latin{,-ext}.woff2`, `fraunces-700-latin{,-ext}.woff2`, `fraunces-italic-600-latin{,-ext}.woff2` |
| milosvasic.ru | **A (shipped)** | **Anton** (OFL) | 400 | `milosvasic.ru/assets/od/anton/` | `anton-latin-400.woff2`, `anton-latin-ext-400.woff2` |
| milosvasic.ru | B (alternate) | **Fraunces** (OFL) | 600, 900 | `milosvasic.ru/assets/od/fraunces/` | `fraunces-latin-600.woff2`, `fraunces-latin-ext-600.woff2`, `fraunces-latin-900.woff2`, `fraunces-latin-ext-900.woff2` |

Because both A and B faces are already deployed on each site, switching
candidates (§4) requires no font work.

---

## 6. Reproducibility

The DNA behind each candidate follows the **design-toolkit parametric uniqueness
engine** (`design-toolkit/knowledge/uniqueness-engine.md`, submodule
`design-toolkit @ v0.2.1`). Relevant to this re-style:

- **Deterministic pipeline** — `seed → PRNG → design-DNA vector → blue-noise gate
  → guardrail projection → emitters → DTCG tokens → QA`. Same seed reproduces the
  same system; record seed + generator version in provenance.
- **DNA axes exercised here** — Type pairing [H] (display face swap: Bricolage /
  Anton for A, Fraunces for B; Inter body kept), Shape/radius [H] (sharp 0–4px /
  square 1–3px vs. soft 8–28px), Motion [E/H] (M3 base + reduced-motion static
  fallback), Texture/depth [H] (blueprint/engineering grid + hard shadows for A;
  glass/blur for B, with mandatory opaque fallback).
- **Blue-noise separation (§4)** — the two candidates per site, and the two sites
  vs. each other, are intentionally far apart in DNA space: A = grotesque/sharp/
  hard-shadow/grid; B = serif/soft/glass/glow — distinct type + shape + texture
  axes (color/type dominate the weighted distance).
- **Brand-lock guardrail (§5)** — each site's accent hue is a locked token
  (vasic `#8f1d2d`, milos `#a31e39`); the engine varied everything *around* it and
  never overwrote it. Confirmed by the unchanged accent ramps in every candidate.
- **Dual accessibility gate (§5)** — WCAG 2.2 AA held as the normative gate;
  results verified post-projection by axe (§3, all `0`).
- **Depth/motion fallbacks (§5)** — every glass/blur (vasic B, milos B) ships an
  opaque fallback; every animation (vasic A scanline/aurora) has a reduced-motion
  static state. Verified in the candidate CSS (§3).

**To regenerate:** run the uniqueness engine with each site's recorded seed and
brand-lock token, emit DTCG tokens, map them onto the site's `--od-*` layer
(vasic: `assets/od/vasic-digital.css`; milos: `assets/od/milosvasic.css` +
`assets/css/style.scss`), then re-run the QA gate (axe + overflow + behavior)
exactly as captured under `_tests/evidence/restyle/`.
