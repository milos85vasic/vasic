// Render milosvasic.ru/_site/index.html in a chosen theme, report computed
// colors for the hero CTA buttons, and run axe-core color-contrast.
// Usage: node render-axe.js <dark|light>
const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const THEME = process.argv[2] || 'dark';
const ROOT = '/Volumes/T7/Projects/vasic/milosvasic.ru/_site';
const PORT = 8399;

const MIME = { '.html':'text/html', '.css':'text/css', '.js':'text/javascript',
  '.svg':'image/svg+xml', '.json':'application/json', '.woff2':'font/woff2',
  '.woff':'font/woff', '.png':'image/png', '.jpg':'image/jpeg', '.webp':'image/webp',
  '.ico':'image/x-icon' };

function serve() {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split('?')[0]);
      if (p.endsWith('/')) p += 'index.html';
      let fp = path.join(ROOT, p);
      if (!fs.existsSync(fp)) { res.statusCode = 404; return res.end('nf'); }
      if (fs.statSync(fp).isDirectory()) fp = path.join(fp, 'index.html');
      res.setHeader('Content-Type', MIME[path.extname(fp)] || 'application/octet-stream');
      fs.createReadStream(fp).pipe(res);
    });
    srv.listen(PORT, () => resolve(srv));
  });
}

// WCAG relative-luminance contrast ratio from two "rgb(r, g, b)" strings.
function parseRGB(s){ const m = s.match(/(\d+(?:\.\d+)?)/g).map(Number); return m; }
function lum([r,g,b]){ const f=c=>{c/=255;return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4);};
  return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b); }
function ratio(fg,bg){ const L1=lum(parseRGB(fg)),L2=lum(parseRGB(bg));
  const a=Math.max(L1,L2),b=Math.min(L1,L2); return (a+0.05)/(b+0.05); }
function toHex(s){ const [r,g,b]=parseRGB(s); return '#'+[r,g,b].map(x=>Math.round(x).toString(16).padStart(2,'0')).join(''); }

(async () => {
  const srv = await serve();
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ colorScheme: THEME });
  const page = await ctx.newPage();
  await page.addInitScript((t) => {
    try { localStorage.setItem('mv-theme', t); } catch(e){}
  }, THEME);
  await page.goto(`http://localhost:${PORT}/index.html`, { waitUntil: 'networkidle' });
  // Force theme attribute deterministically too.
  await page.evaluate((t)=>document.documentElement.setAttribute('data-theme', t), THEME);
  await page.waitForTimeout(300);

  const appliedTheme = await page.evaluate(()=>document.documentElement.getAttribute('data-theme'));

  // Inspect every button/link inside the hero.
  const btns = await page.evaluate(() => {
    const hero = document.querySelector('.mvx-hero, .hero, [class*="hero"]');
    const scope = hero || document;
    const els = Array.from(scope.querySelectorAll('a.od-btn, button.od-btn, .od-btn'));
    return els.map((el) => {
      const cs = getComputedStyle(el);
      // Resolve the effective background by walking up until non-transparent.
      let bgEl = el, bg = cs.backgroundColor;
      while (bgEl && (bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent')) {
        bgEl = bgEl.parentElement;
        if (!bgEl) { bg = 'rgb(18, 18, 18)'; break; }
        bg = getComputedStyle(bgEl).backgroundColor;
      }
      return {
        text: (el.textContent||'').trim().slice(0,30),
        i18n: el.getAttribute('data-i18n') || '',
        cls: el.className,
        color: cs.color,
        bgSelf: cs.backgroundColor,
        bgEffective: bg,
        opacity: cs.opacity,
      };
    });
  });

  console.log(`\n=== THEME applied: ${appliedTheme} (requested ${THEME}) ===`);
  for (const b of btns) {
    const r = ratio(b.color, b.bgEffective);
    console.log(`\n[${b.i18n || b.text}]  cls="${b.cls}"`);
    console.log(`  text "${b.text}"`);
    console.log(`  fg ${toHex(b.color)} (${b.color})  on bg ${toHex(b.bgEffective)} (${b.bgEffective}, self=${b.bgSelf})  opacity=${b.opacity}`);
    console.log(`  ratio = ${r.toFixed(2)}  ${r>=4.5?'PASS':'*** FAIL (need 4.5) ***'}`);
  }

  // axe-core: color-contrast only.
  const results = await new AxeBuilder({ page }).withRules(['color-contrast']).analyze();
  const cc = results.violations.filter(v => v.id === 'color-contrast');
  const nodes = cc.flatMap(v => v.nodes);
  console.log(`\n=== axe-core color-contrast violations: ${nodes.length} node(s) ===`);
  for (const n of nodes) {
    console.log(`  target: ${JSON.stringify(n.target)}`);
    console.log(`    ${n.failureSummary.replace(/\n/g,' ')}`);
  }
  // Hero-CTA specific count
  const heroNodes = nodes.filter(n => JSON.stringify(n.target).match(/hero|od-btn/i));
  console.log(`\n=== hero/od-btn color-contrast nodes: ${heroNodes.length} ===`);

  fs.writeFileSync(path.join(__dirname, `axe-${THEME}.json`), JSON.stringify({
    theme: appliedTheme, buttons: btns.map(b=>({...b, ratio: ratio(b.color,b.bgEffective)})),
    axeColorContrastNodes: nodes.map(n=>({target:n.target, summary:n.failureSummary})),
  }, null, 2));

  await browser.close();
  srv.close();
})();
