// Visual-regression guard for EXISTING pages against the NEW milosvasic.css.
// Baseline = the submodule's HEAD stylesheet (`git -C milosvasic.ru show
// HEAD:assets/od/milosvasic.css`), injected by route interception, so no stash
// and no second server. Same built HTML, same fonts, animations disabled; only
// the stylesheet differs. A page outside /expertise/ changing by more than
// THRESHOLD of its pixels is a regression candidate.
const { test, expect } = require('@playwright/test');
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');
const pm = require('pixelmatch');
const pixelmatch = pm.default || pm;
const { MV_BASE } = require('../env.js');

const THRESHOLD = 0.005; // 0.5%
const MV_REPO = path.resolve(__dirname, '..', '..', 'milosvasic.ru');
const OUT = process.env.CSS_VR_OUT || path.resolve(__dirname, '..', 'test-results', 'css-vr');
const CSS_URL = /\/assets\/od\/milosvasic\.css(\?.*)?$/;

let baseCss = null;
try {
  // CSS_VR_BASE_FILE: mutation proof — baseline from an arbitrary file to show the guard can fail.
  if (process.env.CSS_VR_BASE_FILE) { baseCss = fs.readFileSync(process.env.CSS_VR_BASE_FILE, 'utf8'); } else
  baseCss = execFileSync('git', ['-C', MV_REPO, 'show', 'HEAD:assets/od/milosvasic.css'], { encoding: 'utf8', maxBuffer: 1 << 26 });
} catch (e) { baseCss = null; }

const PAGES = [
  ['home-en', '/'], ['home-de', '/de/'], ['home-ar-rtl', '/ar/'], ['home-ja', '/ja/'],
  ['product-en', '/products/catalogizer.html'], ['product-de', '/products/de/catalogizer.html'],
  ['product-hx', '/products/helixtrack.html'], ['portfolio', '/portfolio/'],
];

test.describe('milosvasic.css HEAD vs working tree — existing pages', () => {
  test.skip(!baseCss, 'cannot read HEAD stylesheet from milosvasic.ru submodule — UNDETERMINED, not a pass'); // SKIP-OK: VSC-433 conditional on the milosvasic.ru submodule HEAD stylesheet being readable; the skip text says UNDETERMINED, not a pass
  fs.mkdirSync(OUT, { recursive: true });
  for (const scheme of ['light', 'dark']) for (const vw of [1280, 400]) for (const [name, url] of PAGES) {
    test(`${name} ${scheme} ${vw}px`, async ({ browser }, info) => {
      const shot = async (useBase) => {
        const ctx = await browser.newContext({ viewport: { width: vw, height: 900 }, colorScheme: scheme, reducedMotion: 'reduce' });
        const page = await ctx.newPage();
        if (useBase) await page.route(CSS_URL, (r) => r.fulfill({ status: 200, contentType: 'text/css', body: baseCss }));
        await page.goto(MV_BASE + url, { waitUntil: 'networkidle' });
        await page.addStyleTag({ content: '*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}' });
        await page.evaluate(() => document.fonts && document.fonts.ready);
        const buf = await page.screenshot({ fullPage: true });
        await ctx.close();
        return PNG.sync.read(buf);
      };
      const a = await shot(true), b = await shot(false);
      const w = Math.max(a.width, b.width), h = Math.max(a.height, b.height);
      const pad = (p) => { const o = new PNG({ width: w, height: h }); o.data.fill(255); PNG.bitblt(p, o, 0, 0, p.width, p.height, 0, 0); return o; };
      const A = pad(a), B = pad(b), D = new PNG({ width: w, height: h });
      const n = pixelmatch(A.data, B.data, D.data, w, h, { threshold: 0.1 });
      const ratio = n / (w * h);
      const tag = `${name}-${scheme}-${vw}`;
      fs.writeFileSync(path.join(OUT, tag + '.diff.png'), PNG.sync.write(D));
      const line = `CSSVR ${tag} diff=${(ratio * 100).toFixed(3)}% px=${n} headH=${a.height} newH=${b.height}`;
      console.log(line); fs.appendFileSync(path.join(OUT, 'report.txt'), line + '\n');
      info.annotations.push({ type: 'diff', description: line });
      expect(ratio, line).toBeLessThanOrEqual(THRESHOLD);
    });
  }
});
