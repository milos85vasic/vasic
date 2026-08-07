const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');
const fs = require('fs');
const DIR = __dirname;
const BASE = 'https://milosvasic.ru';

async function main() {
  const browser = await chromium.launch();
  const out = { switcher: {}, axe: {} };

  // ---- Language switcher: open #lang-btn, count items, test navigation ----
  {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await ctx.newPage();
    await page.goto(BASE + '/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(500);
    const btn = await page.$('#lang-btn');
    await btn.click();
    await page.waitForTimeout(600);
    const info = await page.evaluate(() => {
      const menu = document.getElementById('lang-menu');
      const btn = document.getElementById('lang-btn');
      const items = menu ? [...menu.querySelectorAll('a,[role="menuitem"],button')] : [];
      return {
        ariaExpanded: btn.getAttribute('aria-expanded'),
        itemCount: items.length,
        langs: items.map(a => a.getAttribute('hreflang') || (a.getAttribute('href')||'').replace(/^https?:\/\/[^/]+/,'') || a.textContent.trim()).slice(0, 40),
      };
    });
    out.switcher.desktop = info;
    // navigate: click the German item
    const deLink = await page.$('#lang-menu a[href*="/de/"], #lang-menu a[hreflang="de"]');
    if (deLink) {
      await deLink.click();
      await page.waitForLoadState('networkidle').catch(()=>{});
      await page.waitForTimeout(500);
      out.switcher.navigatedTo = page.url();
      out.switcher.htmlLangAfterNav = await page.evaluate(() => document.documentElement.getAttribute('lang'));
    }
    await ctx.close();
  }

  // ---- axe-core on 4 pages ----
  const pages = [
    ['en-home', '/'],
    ['ru-home', '/ru/'],
    ['ar-home-rtl', '/ar/'],
    ['product-helixtrack', '/products/helixtrack.html'],
  ];
  for (const [name, url] of pages) {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await ctx.newPage();
    await page.goto(BASE + url, { waitUntil: 'networkidle' });
    await page.waitForTimeout(600);
    const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze();
    const summary = {
      url,
      violationsTotal: results.violations.length,
      serious: results.violations.filter(v => v.impact === 'serious').length,
      critical: results.violations.filter(v => v.impact === 'critical').length,
      moderate: results.violations.filter(v => v.impact === 'moderate').length,
      minor: results.violations.filter(v => v.impact === 'minor').length,
      violations: results.violations.map(v => ({ id: v.id, impact: v.impact, nodes: v.nodes.length, help: v.help })),
    };
    fs.writeFileSync(`${DIR}/axe-${name}.json`, JSON.stringify(results, null, 2));
    out.axe[name] = summary;
    await ctx.close();
  }

  fs.writeFileSync(`${DIR}/switcher-axe-results.json`, JSON.stringify(out, null, 2));
  console.log(JSON.stringify(out, null, 2));
  await browser.close();
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
