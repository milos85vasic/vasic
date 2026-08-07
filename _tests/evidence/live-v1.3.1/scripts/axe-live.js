const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');
const fs = require('fs');

const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.3.1';
const targets = [
  ['vasic-home-en',      'https://vasic.digital/'],
  ['vasic-portfolio-ar', 'https://vasic.digital/portfolio/ar/'],
  ['vasic-portfolio-ru', 'https://vasic.digital/portfolio/ru/'],
  ['milos-home-en',      'https://milosvasic.ru/'],
  ['milos-portfolio-ar', 'https://milosvasic.ru/portfolio/ar/'],
  ['milos-portfolio-ru', 'https://milosvasic.ru/portfolio/ru/'],
];

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const summary = [];
  for (const [label, url] of targets) {
    const page = await context.newPage();
    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa'])
        .analyze();
      fs.writeFileSync(`${OUT}/axe-${label}.json`, JSON.stringify(results, null, 2));
      const byImpact = { critical:0, serious:0, moderate:0, minor:0, null:0 };
      const ids = [];
      for (const v of results.violations) {
        byImpact[v.impact ?? 'null'] = (byImpact[v.impact ?? 'null']||0)+1;
        ids.push(`${v.impact}:${v.id}(${v.nodes.length})`);
      }
      const line = `${label} | crit=${byImpact.critical} serious=${byImpact.serious} mod=${byImpact.moderate} minor=${byImpact.minor} | ${ids.join(', ')||'none'}`;
      summary.push(line);
      console.log('OK  ' + line);
    } catch (e) {
      const line = `${label} | ERROR: ${e.message}`;
      summary.push(line); console.log('ERR ' + line);
    } finally { await page.close(); }
  }
  fs.writeFileSync(`${OUT}/axe-summary.txt`, summary.join('\n')+'\n');
  await browser.close();
})();
