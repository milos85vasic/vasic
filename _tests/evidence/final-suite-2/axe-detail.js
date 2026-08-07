const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');
const MV = 'http://localhost:8082';
const VASIC = 'http://localhost:8401';

(async () => {
  const browser = await chromium.launch();

  // 1. mv home dark color-contrast detail
  {
    const ctx = await browser.newContext(); const page = await ctx.newPage();
    await page.goto(`${MV}/`, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.documentElement.setAttribute('data-theme', 'dark'));
    await page.waitForTimeout(300);
    const r = await new AxeBuilder({ page }).disableRules(['heading-order','link-in-text-block']).analyze();
    const cc = r.violations.find(v => v.id === 'color-contrast');
    console.log('=== MV HOME DARK color-contrast nodes ===');
    if (cc) cc.nodes.forEach(n => console.log(JSON.stringify({ target: n.target, summary: n.failureSummary })));
    await ctx.close();
  }

  // 2. vasic legacy modal aria-dialog-name + button-name detail
  {
    const ctx = await browser.newContext(); const page = await ctx.newPage();
    await page.goto(`${VASIC}/index.legacy.html`, { waitUntil: 'networkidle' });
    const trig = page.locator('[data-article]').first();
    await trig.click();
    await page.waitForTimeout(900);
    const r = await new AxeBuilder({ page }).disableRules(['heading-order','link-in-text-block']).analyze();
    console.log('\n=== VASIC LEGACY MODAL violations ===');
    r.violations.filter(v => ['aria-dialog-name','button-name'].includes(v.id)).forEach(v =>
      console.log(v.id, '->', JSON.stringify(v.nodes.map(n => ({ target: n.target, html: n.html.slice(0,120) })))));
    // Does vasic articles.js set aria-labelledby? inspect the live dialog
    const attrs = await page.evaluate(() => {
      const d = document.querySelector('[role="dialog"], [aria-modal="true"], .article-overlay, [data-open]');
      return d ? { tag: d.tagName, cls: d.className, labelledby: d.getAttribute('aria-labelledby'), label: d.getAttribute('aria-label'), role: d.getAttribute('role') } : 'no-dialog-found';
    });
    console.log('vasic dialog attrs:', JSON.stringify(attrs));
    await ctx.close();
  }

  await browser.close();
})();
