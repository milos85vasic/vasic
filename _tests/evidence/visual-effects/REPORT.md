# vasic.digital — Visual Effects & Motion Signature

Local, uncommitted work that elevates the generated **vasic.digital** home with a
distinctive animated hero and reusable motion effects — built on the existing
OpenDesign token/motion layer (no ad-hoc CSS; §11.4.162), GPU-only, accessible,
and reduced-motion safe.

## Why vasic's motion is DISTINCT from milosvasic.ru
- **milosvasic.ru** (personal portfolio): warm, editorial, human — hero portrait
  with crimson corner accents, gentle reveals.
- **vasic.digital** (AI-engineering company): "engineered / precision" — animated
  deep-red gradient-mesh **aurora** + faint **technical grid** behind the hero,
  **metric count-ups**, **magnetic CTAs**, **accent card-glow**, **precision divider**.
The vasic visuals live in the per-site brand tokens and are wired only to the `vd`
prefix in the generator, so milosvasic.ru never renders them. The shared motion
layer only gained generic, opt-in primitives.

## Effects (all wired into generated markup)
1. Aurora mesh + technical grid hero backdrop — `.vd-hero__fx > .vd-hero__aurora/.vd-hero__grid` (aria-hidden)
2. Scroll-reveal stagger (retained) — `.od-reveal` / `.od-stagger`
3. Metric count-up (0 -> authored value on scroll-in) — `.od-stat__value[data-od-count]`
4. Magnetic CTA buttons (fine pointer only) — `.od-btn.od-magnetic`
5. Card hover/focus accent glow — `.od-product-card.od-glow` (34x)
6. Precision divider (scaleX reveal) — `hr.vd-hero__rule.od-divider`

## Performance safeguards
- Compositor-only: every animation/transition touches only transform/opacity. Aurora
  drifts via transform on a soft radial-gradient layer (no filter:blur, no repaint);
  grid is static.
- No LCP block / no CLS: decorative backdrop sits behind text (z-index 0 vs 1) so copy
  paints independently; count-up renders the FINAL value in HTML and only enhances it;
  tabular-nums keeps digit width fixed so the animating number never reflows siblings.
- Scroll effects gated by IntersectionObserver (reveal + count-up; count-up runs once
  then unobserves). Magnetic bound only on (pointer:fine). No new libraries.
- Mobile 390px: horizontal overflow <= 2px (aurora clipped by overflow:hidden).

## Accessibility safeguards
- axe-core (WCAG 2.0/2.1 A+AA): 0 violations on the regenerated home (axe-home.json = []).
  Aurora opacity capped (0.14 light / 0.22 dark) + faint --od-border grid behind an
  edge-fade mask keep hero text well above AA in both themes.
- Backdrop is aria-hidden + pointer-events:none (decorative, never focusable). Magnetic
  transform resets on pointerleave/blur; keyboard nav/activation untouched. Count-up is
  not a live region (SR announces only the final value).

## Reduced-motion path (verified — hero-reduced-motion.png)
Reveals show instantly at rest; aurora pinned to a still frame (animation:none); divider
shown at full scaleX(1); magnetic never bound; count-ups keep final value (40+/140+/33).
Neutralized in three layers: animations.css reduced block, vasic-digital.css global reduced
block, and motion.js early-return guards.

## Files changed (uncommitted)
- _tools/gen/home.go — instantiates effects in vd hero/card markup; renderHomeCTA gained
  an `extra` class param (callers updated).
- design-system/motion/motion.js — initCountUp() + initMagnetic() (guarded); .od-divider
  added to the reveal observer.
- design-system/motion/animations.css — reusable .od-glow, .od-divider, .od-magnetic
  primitives + reduced-motion neutralization.
- design-system/brand-vasic-digital/vasic-digital.css — vasic motion signature (.vd-hero
  aurora + grid + @keyframes vd-aurora-drift, divider sizing, tabular-nums) + reduced pin.
- Regenerated: vasic.digital/index.html (EN), vasic.digital/ru/index.html (localized), and
  synced vasic.digital/assets/od/* (also re-synced to milosvasic.ru/assets/od/*, visually
  unchanged — uses none of the new classes).

## Verification
- go test ./... — green.
- vasic-digital.spec.js + vasic-digital-features.spec.js (chromium) — 16/16 passed.
- visual-effects.spec.js (chromium) — 7/7 passed, including the axe gate.
- Effects present in EN + ru HTML; milosvasic.ru home has 0 vd effect hooks.

## Evidence files
- hero-desktop-light.png, hero-desktop-dark.png — animated hero, both themes.
- home-desktop-light-full.png — full page.
- card-hover-glow.png — .od-glow accent sheen.
- hero-mobile.png — 390px hero (no overflow).
- hero-reduced-motion.png — motion disabled, hero static + usable.
- axe-home.json — axe violations (empty []).
