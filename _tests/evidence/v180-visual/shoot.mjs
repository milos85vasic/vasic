// v1.8.0 design-token visual-regression harness.
//
// Screenshots a FIXED page set for both sites at a given label, so a "before"
// (current live) baseline can be diffed against an "after" (post-v1.8.0)
// capture. READ-ONLY against production; writes only under this directory.
//
// Usage:
//   node _tests/evidence/v180-visual/shoot.mjs --label before
//   node _tests/evidence/v180-visual/shoot.mjs --label after
//
// Base URLs default to the live sites; override with env vars:
//   VASIC_BASE=https://vasic.digital MILOS_BASE=https://milosvasic.ru
//
// The change under test SHOULD be a palette/type/space refinement, NOT a
// layout change, so geometry stays near-identical and only colors shift.

import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// --- args ---
function argVal(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
const label = argVal('label', null);
if (!label) {
  console.error('ERROR: --label <name> is required (e.g. --label before)');
  process.exit(2);
}

const VASIC_BASE = (process.env.VASIC_BASE || 'https://vasic.digital').replace(/\/$/, '');
const MILOS_BASE = (process.env.MILOS_BASE || 'https://milosvasic.ru').replace(/\/$/, '');

// --- fixed page set ---
// slug is used in the output filename; path is appended to the site base.
const SITES = [
  {
    site: 'vasic',
    base: VASIC_BASE,
    pages: [
      { slug: 'home', path: '/' },
      { slug: 'product', path: '/products/helixtrack.html' },
      { slug: 'portfolio', path: '/portfolio/' },
      { slug: 'sr-home', path: '/sr/' },
    ],
  },
  {
    site: 'milos',
    base: MILOS_BASE,
    pages: [
      { slug: 'home', path: '/' },
      { slug: 'product', path: '/products/catalogizer.html' },
      { slug: 'portfolio', path: '/portfolio/' },
      { slug: 'sr-home', path: '/sr/' },
    ],
  },
];

// --- variants ---
// desktop 1280 light + dark, mobile 390 light.
const VARIANTS = [
  { name: 'desktop-light', width: 1280, height: 900, theme: 'light' },
  { name: 'desktop-dark', width: 1280, height: 900, theme: 'dark' },
  { name: 'mobile-light', width: 390, height: 844, theme: 'light' },
];

// Kills animation/transition motion so before/after diffs are palette-only,
// not motion-noise. Injected as a persistent init style + a post-load style tag.
const FREEZE_CSS = '*,*::before,*::after{animation:none!important;transition:none!important;animation-duration:0s!important;scroll-behavior:auto!important;caret-color:transparent!important}';

// Seeds theme so the site's own boot script picks the right mode. Both sites
// toggle documentElement[data-theme]; they persist under different localStorage
// keys (vasic: od-theme, milos: mv-theme), so we seed every known key.
function initScript(theme) {
  return `
    try {
      var keys = ['od-theme','mv-theme','theme','data-theme'];
      for (var i=0;i<keys.length;i++) localStorage.setItem(keys[i], '${theme}');
    } catch (e) {}
    try { document.documentElement.setAttribute('data-theme','${theme}'); } catch (e) {}
  `;
}

const OUT_ROOT = resolve(__dirname, label);

async function shoot() {
  const browser = await chromium.launch();
  const results = [];

  for (const variant of VARIANTS) {
    const context = await browser.newContext({
      viewport: { width: variant.width, height: variant.height },
      deviceScaleFactor: 1,
      reducedMotion: 'reduce',
      colorScheme: variant.theme,
      ignoreHTTPSErrors: false,
    });
    await context.addInitScript(initScript(variant.theme));

    for (const { site, base, pages } of SITES) {
      for (const p of pages) {
        const url = base + p.path;
        const file = resolve(OUT_ROOT, `${site}-${p.slug}-${variant.name}.png`);
        const page = await context.newPage();
        let status = null;
        let ok = false;
        try {
          const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
          status = resp ? resp.status() : null;
          // Force theme again post-load in case boot script re-read a differing
          // stored value, then re-freeze motion.
          await page.evaluate((t) => {
            document.documentElement.setAttribute('data-theme', t);
          }, variant.theme);
          await page.addStyleTag({ content: FREEZE_CSS });
          // let layout settle after theme swap; fixed short wait (no animation).
          await page.waitForTimeout(400);
          await page.screenshot({ path: file, fullPage: true });
          ok = status !== null && status >= 200 && status < 400;
        } catch (err) {
          status = status || `ERR:${err.message.split('\n')[0]}`;
        }
        results.push({ url, file, variant: variant.name, status, ok });
        const mark = ok ? 'OK ' : 'XX ';
        console.log(`${mark}[${String(status).padEnd(6)}] ${site}-${p.slug}-${variant.name}  ${url}`);
        await page.close();
      }
    }
    await context.close();
  }

  await browser.close();
  return results;
}

await mkdir(OUT_ROOT, { recursive: true });
console.log(`\nv1.8.0 visual harness  label=${label}`);
console.log(`  VASIC_BASE=${VASIC_BASE}`);
console.log(`  MILOS_BASE=${MILOS_BASE}`);
console.log(`  out=${OUT_ROOT}\n`);

const results = await shoot();

const total = results.length;
const okCount = results.filter((r) => r.ok).length;
const bad = results.filter((r) => !r.ok);
console.log(`\n---- summary (${label}) ----`);
console.log(`shots: ${okCount}/${total} captured with 2xx/3xx status`);
if (bad.length) {
  console.log('NON-OK pages:');
  for (const b of bad) console.log(`  [${b.status}] ${b.variant}  ${b.url}`);
} else {
  console.log('all pages returned OK status');
}
process.exit(bad.length ? 1 : 0);
