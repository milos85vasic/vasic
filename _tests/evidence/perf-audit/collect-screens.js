// READ-ONLY responsive + cross-browser screenshots via Playwright.
const { chromium, firefox, webkit } = require('playwright');
const fs = require('fs');
const path = require('path');

const RESP = path.join(__dirname, 'responsive');
const XB = path.join(__dirname, 'cross-browser');
fs.mkdirSync(RESP, { recursive: true });
fs.mkdirSync(XB, { recursive: true });

const PAGES = [
  { site: 'mv', label: 'landing',   url: 'http://localhost:8082/' },
  { site: 'mv', label: 'product',   url: 'http://localhost:8082/products/helixtrack.html' },
  { site: 'mv', label: 'portfolio', url: 'http://localhost:8082/portfolio/' },
  { site: 'vd', label: 'landing',   url: 'http://localhost:8401/' },
  { site: 'vd', label: 'product',   url: 'http://localhost:8401/products/helixtrack.html' },
  { site: 'vd', label: 'portfolio', url: 'http://localhost:8401/portfolio/' },
];
const BREAKPOINTS = [ { name: 'mobile', w: 390, h: 844 }, { name: 'tablet', w: 768, h: 1024 }, { name: 'desktop', w: 1440, h: 900 } ];

async function overflow(page) {
  return await page.evaluate(() => ({
    docW: document.documentElement.scrollWidth,
    innerW: window.innerWidth,
    horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth + 1,
    overflowBy: document.documentElement.scrollWidth - window.innerWidth,
  }));
}

(async () => {
  const findings = [];
  // Responsive (chromium)
  const cb = await chromium.launch();
  for (const p of PAGES) {
    for (const bp of BREAKPOINTS) {
      const ctx = await cb.newContext({ viewport: { width: bp.w, height: bp.h } });
      const page = await ctx.newPage();
      await page.goto(p.url, { waitUntil: 'load', timeout: 45000 });
      await page.waitForTimeout(1200);
      const of = await overflow(page);
      const file = path.join(RESP, `${p.site}-${p.label}-${bp.name}-${bp.w}.png`);
      await page.screenshot({ path: file, fullPage: true });
      findings.push({ kind: 'responsive', site: p.site, page: p.label, breakpoint: bp.name, width: bp.w, ...of, file: path.basename(file) });
      console.log(`resp ${p.site}/${p.label}/${bp.name}: overflow=${of.horizontalOverflow} by=${of.overflowBy}px docW=${of.docW}`);
      await ctx.close();
    }
  }
  await cb.close();

  // Cross-browser landing pages
  const engines = { chromium, firefox, webkit };
  for (const [name, engine] of Object.entries(engines)) {
    const b = await engine.launch();
    for (const p of PAGES.filter(x => x.label === 'landing')) {
      const ctx = await b.newContext({ viewport: { width: 1440, height: 900 } });
      const page = await ctx.newPage();
      await page.goto(p.url, { waitUntil: 'load', timeout: 45000 });
      await page.waitForTimeout(1500);
      const of = await overflow(page);
      const file = path.join(XB, `${p.site}-landing-${name}.png`);
      await page.screenshot({ path: file, fullPage: false });
      findings.push({ kind: 'cross-browser', site: p.site, page: 'landing', engine: name, ...of, file: path.basename(file) });
      console.log(`xb ${p.site}/landing/${name}: overflow=${of.horizontalOverflow} by=${of.overflowBy}px`);
      await ctx.close();
    }
    await b.close();
  }
  fs.writeFileSync(path.join(__dirname, 'metrics', 'layout-findings.json'), JSON.stringify(findings, null, 2));
  console.log('DONE screenshots');
})();
