// Render an SVG file to light+dark PNGs. Usage: node render-diagram.cjs <svgPath> <outDir> <slug>
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const [svgPath, outDir, slug] = process.argv.slice(2);
  const svg = fs.readFileSync(svgPath, 'utf8');
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  for (const theme of ['light', 'dark']) {
    const bg = theme === 'light' ? '#ffffff' : '#0f172a';
    const page = await browser.newPage({ viewport: { width: 1000, height: 660 }, deviceScaleFactor: 2 });
    await page.emulateMedia({ colorScheme: theme });
    const html = `<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:${bg};color:${theme==='light'?'#1e293b':'#e2e8f0'}}#wrap{padding:20px;box-sizing:border-box}svg{width:960px;height:auto;display:block}</style><div id="wrap">${svg}</div>`;
    await page.setContent(html, { waitUntil: 'networkidle' });
    const el = await page.$('#wrap');
    const out = path.join(outDir, `${slug}-${theme}.png`);
    await el.screenshot({ path: out });
    console.log('wrote', out);
    await page.close();
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
