# v1.8.0 Design-Token Visual Regression

Before/after visual-regression harness for the **v1.8.0 design-token change**.
Read-only against production; writes only under `_tests/evidence/v180-visual/`.

The v1.8.0 change SHOULD be a **palette / type / space refinement** — a crimson
tonal ramp plus fluid type & spacing — **not** a layout or structural change.
So geometry should stay near-identical between `before/` and `after/`; only
colors (and possibly type sizing) should shift subtly. Any large geometric diff
is a regression, not the intended change.

## Page set (per site, 4 pages)

| slug        | vasic.digital                      | milosvasic.ru                        |
|-------------|------------------------------------|--------------------------------------|
| `home`      | `/`                                | `/`                                  |
| `product`   | `/products/helixtrack.html`        | `/products/catalogizer.html`         |
| `portfolio` | `/portfolio/`                      | `/portfolio/`                        |
| `sr-home`   | `/sr/`                             | `/sr/`                               |

## Variants (3 per page)

- `desktop-light` — 1280px, `data-theme=light`
- `desktop-dark`  — 1280px, `data-theme=dark`
- `mobile-light`  — 390px,  `data-theme=light`

**2 sites x 4 pages x 3 variants = 24 shots per label.** All captures are
`fullPage`.

Determinism: navigation waits for `networkidle`; `prefers-reduced-motion` is
emulated and a `*{animation:none;transition:none}` style is injected so diffs
are palette-only, not motion-noise. Theme is seeded via `localStorage` (both
sites' keys: `od-theme`, `mv-theme`) plus a forced `documentElement[data-theme]`
after load.

## Output layout

```
_tests/evidence/v180-visual/
  shoot.mjs
  README.md
  before/   <site>-<page>-<variant>.png   (current live baseline — DONE)
  after/    <site>-<page>-<variant>.png    (capture after v1.8.0 deploys)
```

## Workflow

1. **BEFORE (done)** — current live, pre-token-change (crimson MACHINA /
   terminal-brutalist):
   ```
   node _tests/evidence/v180-visual/shoot.mjs --label before
   ```
   → 24/24 shots, all HTTP 200.

2. **AFTER** — once v1.8.0 is deployed to production, re-run with the same page
   set and variants:
   ```
   node _tests/evidence/v180-visual/shoot.mjs --label after
   ```

   To capture a staging/preview deploy instead of live, override the bases:
   ```
   VASIC_BASE=https://staging.vasic.digital \
   MILOS_BASE=https://staging.milosvasic.ru \
   node _tests/evidence/v180-visual/shoot.mjs --label after
   ```

3. **DIFF** `before/` vs `after/` — filenames are identical between labels, so
   pairs line up 1:1.

   - **pixelmatch is NOT installed** in `_tests/node_modules` (only `pngjs` is).
     Either add it (`cd _tests && npm i -D pixelmatch`) for an automated per-pair
     diff, or do a **manual side-by-side** review of each of the 24 pairs.

   - Minimal automated diff once pixelmatch is present (writes `diff-*.png` and
     prints changed-pixel %):
     ```js
     // _tests/evidence/v180-visual/diff.mjs  (create if desired)
     import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
     import { PNG } from 'pngjs';
     import pixelmatch from 'pixelmatch';
     const dir = new URL('.', import.meta.url).pathname;
     for (const f of readdirSync(dir + 'before')) {
       const a = PNG.sync.read(readFileSync(dir + 'before/' + f));
       const b = PNG.sync.read(readFileSync(dir + 'after/' + f));
       const { width, height } = a;
       const out = new PNG({ width, height });
       const n = pixelmatch(a.data, b.data, out.data, width, height, { threshold: 0.1 });
       writeFileSync(dir + 'diff-' + f, PNG.sync.write(out));
       console.log(`${(100 * n / (width * height)).toFixed(2)}%  ${f}`);
     }
     ```
     (Requires equal dimensions; if `before`/`after` heights differ, that alone
     signals a layout change worth investigating.)

## Expectation for a clean v1.8.0

- Every pair has (near) identical dimensions.
- Diffs concentrate in colored surfaces / accents / text color — the crimson
  ramp — not in the position of elements.
- No new/missing sections, no reflow.
