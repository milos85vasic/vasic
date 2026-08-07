// Standalone axe-core audit: both sites, key pages, light + dark.
// Confirms badge color-contrast = 0 and aria-dialog-name = 0.
const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');
const fs = require('fs');

const VASIC = 'http://localhost:8401';
const MV = 'http://localhost:8082';

const PAGES = [
  { site: 'vasic', page: 'home',      url: `${VASIC}/` },
  { site: 'vasic', page: 'product',   url: `${VASIC}/products/helixtrack.html` },
  { site: 'vasic', page: 'portfolio', url: `${VASIC}/portfolio/` },
  { site: 'mv',    page: 'home',      url: `${MV}/` },
  { site: 'mv',    page: 'product',   url: `${MV}/products/helixtrack.html` },
  { site: 'mv',    page: 'portfolio', url: `${MV}/portfolio/` },
];

// Same disabled rules as the repo a11y spec (documented intentional patterns).
const DISABLED = ['heading-order', 'link-in-text-block'];

function summarize(results) {
  const serious = results.violations.filter(v => v.impact === 'serious' || v.impact === 'critical');
  return {
    total: results.violations.length,
    serious: serious.length,
    seriousIds: serious.map(v => ({ id: v.id, impact: v.impact, nodes: v.nodes.length })),
    allIds: results.violations.map(v => ({ id: v.id, impact: v.impact, nodes: v.nodes.length })),
    // badge color-contrast: color-contrast violations whose target references a badge
    badgeContrast: results.violations
      .filter(v => v.id === 'color-contrast')
      .flatMap(v => v.nodes)
      .filter(n => JSON.stringify(n.target).toLowerCase().includes('badge')).length,
    dialogName: (results.violations.find(v => v.id === 'aria-dialog-name')?.nodes.length) || 0,
  };
}

(async () => {
  const browser = await chromium.launch();
  const out = [];
  let totalSerious = 0, totalBadgeContrast = 0, totalDialogName = 0;

  for (const p of PAGES) {
    for (const theme of ['light', 'dark']) {
      const ctx = await browser.newContext();
      const page = await ctx.newPage();
      await page.goto(p.url, { waitUntil: 'networkidle' });
      await page.evaluate(t => {
        document.documentElement.setAttribute('data-theme', t);
        try { localStorage.setItem('theme', t); localStorage.setItem('mv-theme', t); } catch (e) {}
      }, theme);
      await page.waitForTimeout(250);
      const results = await new AxeBuilder({ page }).disableRules(DISABLED).analyze();
      const s = summarize(results);
      totalSerious += s.serious;
      totalBadgeContrast += s.badgeContrast;
      totalDialogName += s.dialogName;
      out.push({ site: p.site, page: p.page, theme, ...s });
      console.log(`${p.site.padEnd(6)} ${p.page.padEnd(10)} ${theme.padEnd(6)} serious=${s.serious} total=${s.total} badgeContrast=${s.badgeContrast} dialogName=${s.dialogName}` +
        (s.serious ? '  -> ' + JSON.stringify(s.seriousIds) : ''));
      await ctx.close();
    }
  }

  // Exercise the article modal (legacy homepage is where the dialog lives) to
  // confirm aria-dialog-name on the LIVE opened dialog.
  for (const [site, base] of [['mv', MV], ['vasic', VASIC]]) {
    for (const theme of ['light', 'dark']) {
      const ctx = await browser.newContext();
      const page = await ctx.newPage();
      try {
        await page.goto(`${base}/index.legacy.html`, { waitUntil: 'networkidle' });
        await page.evaluate(t => document.documentElement.setAttribute('data-theme', t), theme);
        const trigger = page.locator('[data-article]').first();
        if (await trigger.count() === 0) { await ctx.close(); continue; }
        await trigger.click();
        await page.waitForSelector('[role="dialog"][data-open="true"], [aria-modal="true"][data-open="true"]', { timeout: 5000 }).catch(()=>{});
        await page.waitForTimeout(700); // allow fragment fetch -> aria-labelledby
        const results = await new AxeBuilder({ page }).disableRules(DISABLED).analyze();
        const s = summarize(results);
        // read the dialog's accessible name attributes for evidence
        const nameAttrs = await page.evaluate(() => {
          const d = document.querySelector('[role="dialog"], [aria-modal="true"]');
          if (!d) return null;
          return { labelledby: d.getAttribute('aria-labelledby'), label: d.getAttribute('aria-label'), open: d.getAttribute('data-open') };
        });
        totalSerious += s.serious;
        totalDialogName += s.dialogName;
        out.push({ site, page: 'article-modal(legacy)', theme, ...s, dialogNameAttrs: nameAttrs });
        console.log(`${site.padEnd(6)} ${'modal'.padEnd(10)} ${theme.padEnd(6)} serious=${s.serious} dialogName=${s.dialogName} nameAttrs=${JSON.stringify(nameAttrs)}` +
          (s.serious ? '  -> ' + JSON.stringify(s.seriousIds) : ''));
      } catch (e) {
        console.log(`${site} modal ${theme} ERROR ${e.message}`);
      }
      await ctx.close();
    }
  }

  await browser.close();
  const report = { totalSerious, totalBadgeContrast, totalDialogName, pages: out };
  fs.writeFileSync(__dirname + '/03-axe.json', JSON.stringify(report, null, 2));
  console.log('\n=== TOTALS ===');
  console.log(`serious/critical violations across all page+theme runs: ${totalSerious}`);
  console.log(`badge color-contrast violations: ${totalBadgeContrast}`);
  console.log(`aria-dialog-name violations: ${totalDialogName}`);
})();
