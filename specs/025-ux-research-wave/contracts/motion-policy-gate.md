# Contract: Motion Policy + Gate

**Implements**: FR-009, FR-010, FR-012 | **New files**: `workshop/docs/design-system/motion-policy.md`,
`workshop/platform/frontend/scripts/check-motion-policy.mjs` (gate), its prover
`workshop/platform/gates/prove-motion-policy-mutation.sh`.

## Policy (normative text lives in `motion-policy.md`; this table is what the gate enforces)

| Rule | Value |
|---|---|
| Duration band | 150-200 ms for UI state changes; <= 500 ms for data-dense views; tokens `--od-dur-fast 150ms` / `--od-dur-base 250ms` (`kit-tokens.css:57,135-136`) are the only allowed sources (a literal duration outside tokens is a finding) |
| Animated properties | only `opacity` and `transform` (compositor); forbidden: `top`, `left`, `right`, `bottom`, `width`, `height`, `margin*`, `padding*`, `box-shadow`, `filter` blur radius, `backdrop-filter` |
| `will-change` | never on `*`; allowed only on a named element class for the duration of an animation |
| Reduced motion | **substitute**: transform/slide/scale removed, short `opacity` transition (<= 150 ms) retained, `scroll-behavior:auto`; final visual states identical |
| Contrast / transparency | `prefers-contrast: more` selects the high-contrast token set; `prefers-reduced-transparency: reduce` removes translucency (opaque surfaces) |
| View transitions | duration <= 200 ms; skipped under reduced motion; never wrapping transcript load or an in-flight `/api/ask` |

## Gate behaviour

`check-motion-policy.mjs` scans `src/**/*.{scss,css,ts}` for `transition`/`animation` declarations and
inline style bindings and exits 0/1/2 (three-valued; 2 = could not parse, never a pass). The prover
seeds: animated `width`, `will-change:*`, literal `400ms` outside tokens, a removed reduced-motion
substitution block, a `backdrop-filter` transition - each must be caught (rc 1) with a clean control (rc 0).

## What the existing rule does today

`src/styles.scss:232-238` sets every animation/transition duration to `.01ms !important`: final states
survive (proved by `e2e/reduced-motion.spec.ts`) but nothing is substituted. The replacement keeps that
guarantee and adds the opacity fade.
