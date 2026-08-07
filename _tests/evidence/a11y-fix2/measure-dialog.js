/* Opens the mv article modal on real rendered pages, waits for the fragment
   (and its <h1>) to load, then runs axe aria-dialog-name. Evidence only. */
const path = require('path');
const fs = require('fs');
const { chromium } = require(path.join('/Volumes/T7/Projects/vasic/_tests/node_modules/playwright'));
const { AxeBuilder } = require(path.join('/Volumes/T7/Projects/vasic/_tests/node_modules/@axe-core/playwright'));

const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/a11y-fix2';
const MV = 'http://localhost:8502';
const TARGETS = [
  { id: 'mv-home-en-light', url: `${MV}/`, theme: 'light', slug: 'helix-code' },
  { id: 'mv-home-en-dark',  url: `${MV}/`, theme: 'dark',  slug: 'catalogizer' },
  { id: 'mv-home-loaded-en-light', url: `${MV}/`, theme: 'light', slug: 'helix-track-core' },
  // Subdir page: articles.js fetches a root-relative fragment that 404s here,
  // so the modal shows its error state — exercises the aria-label FALLBACK path.
  { id: 'mv-portfolio-errorstate-light', url: `${MV}/portfolio/`, theme: 'light', slug: 'helix-track-core' },
];

(async () => {
  const browser = await chromium.launch();
  const perTarget = [];
  let totalDialogNameNodes = 0;
  for (const t of TARGETS) {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    await page.addInitScript((th) => { try { localStorage.setItem('mv-theme', th); } catch (e) {} }, t.theme);
    await page.goto(t.url, { waitUntil: 'networkidle' });
    await page.evaluate((th)=>document.documentElement.setAttribute('data-theme',th), t.theme);
    // open the modal via public API
    await page.evaluate((slug) => window.MVArticles.open(slug), t.slug);
    // Wait until the dialog has a settled accessible name: either the injected
    // <h1> (loaded path) or the aria-label fallback (loading/error path).
    let named = false;
    for (let i = 0; i < 60 && !named; i++) {
      await page.waitForTimeout(100);
      named = await page.evaluate(() => {
        const d = document.querySelector('.mv-article-modal');
        if (!d) return false;
        const lb = d.getAttribute('aria-labelledby');
        const byH = !!(lb && document.getElementById(lb));
        const byLabel = !!(d.getAttribute('aria-label') || '').trim();
        // settled = either labelled by loaded h1, OR error state reached
        const settled = byH || d.querySelector('.mv-article-modal__state button[data-article-retry]');
        return (byH || byLabel) && !!settled;
      });
    }
    if (!named) throw new Error('modal never named for ' + t.id);
    const info = await page.evaluate(() => {
      const d = document.querySelector('.mv-article-modal');
      const lb = d.getAttribute('aria-labelledby');
      const h = lb ? document.getElementById(lb) : null;
      return {
        role: d.getAttribute('role'),
        ariaModal: d.getAttribute('aria-modal'),
        ariaHidden: d.getAttribute('aria-hidden'),
        ariaLabel: d.getAttribute('aria-label'),
        ariaLabelledby: lb,
        labelTargetTag: h ? h.tagName : null,
        accessibleName: h ? h.textContent.trim().slice(0, 60) : null
      };
    });
    const axe = await new AxeBuilder({ page }).options({ runOnly: ['aria-dialog-name'] }).analyze();
    const nodes = axe.violations.reduce((n, v) => n + v.nodes.length, 0);
    totalDialogNameNodes += nodes;
    perTarget.push({ target: t.id, theme: t.theme, slug: t.slug, aria: info, axeDialogNameNodes: nodes });
    await ctx.close();
  }
  await browser.close();
  fs.writeFileSync(path.join(OUT, 'dialog-name-results.json'), JSON.stringify({ totalDialogNameNodes, perTarget }, null, 2));
  console.log('TOTAL axe aria-dialog-name nodes:', totalDialogNameNodes);
  for (const p of perTarget) {
    console.log(`${p.target} [${p.theme}] axeNodes=${p.axeDialogNameNodes}  labelledby=${p.aria.ariaLabelledby} (${p.aria.labelTargetTag}) name="${p.aria.accessibleName}"`);
  }
})();
