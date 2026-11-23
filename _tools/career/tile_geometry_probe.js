// Usage: node tile_geometry_probe.js <baseUrl> <path> ; prints JSON of tile boxes.
// playwright is resolved from _tests/node_modules.
const path = require('path');
const { chromium } = require(path.resolve(__dirname, '../../_tests/node_modules/playwright'));
(async () => {
  const [base, p] = process.argv.slice(2);
  const browser = await chromium.launch();
  const out = [];
  try {
    for (const width of [1280, 400]) for (const theme of ['light', 'dark']) {
      const ctx = await browser.newContext({ viewport: { width, height: 900 }, colorScheme: theme });
      const page = await ctx.newPage();
      await page.goto(base + p, { waitUntil: 'load' });
      await page.evaluate((t) => document.documentElement.setAttribute('data-theme', t), theme);
      const tiles = await page.evaluate(() => [...document.querySelectorAll('.mv-expertise-tile')].map(t => {
        const r = (sel) => { const e = t.querySelector(sel); if (!e) return null; const b = e.getBoundingClientRect(); return [b.left, b.top, b.right, b.bottom]; };
        const tb = t.getBoundingClientRect();
        return { area: t.dataset.area, tile: [tb.left, tb.top, tb.right, tb.bottom],
          title: r('.mv-expertise-tile__title'), tagline: r('.mv-expertise-tile__tagline'),
          metric: r('.mv-expertise-tile__metric'), projects: r('.mv-expertise-tile__projects') };
      }));
      out.push({ width, theme, tiles });
      await ctx.close();
    }
  } finally { await browser.close(); }
  console.log(JSON.stringify(out));
})().catch(e => { console.error(e); process.exit(2); });
