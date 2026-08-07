import { chromium } from 'playwright';
import { AxeBuilder } from '@axe-core/playwright';
import fs from 'fs';

const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.5.1/a11y';
const targets = [
  ['vasic-en', 'https://vasic.digital/'],
  ['vasic-ru', 'https://vasic.digital/ru/'],
  ['vasic-ar', 'https://vasic.digital/ar/'],
  ['milos-en', 'https://milosvasic.ru/'],
  ['milos-ru', 'https://milosvasic.ru/ru/'],
  ['milos-ar', 'https://milosvasic.ru/ar/'],
];

const summary = [];
const browser = await chromium.launch();
for (const [name, url] of targets) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await context.newPage();
  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();
    fs.writeFileSync(`${OUT}/axe-${name}.json`, JSON.stringify(results, null, 2));
    const counts = { serious: 0, critical: 0, moderate: 0, minor: 0 };
    const seriousCritical = [];
    for (const v of results.violations) {
      counts[v.impact] = (counts[v.impact] || 0) + 1;
      if (v.impact === 'serious' || v.impact === 'critical') seriousCritical.push(`${v.impact}:${v.id}(${v.nodes.length})`);
    }
    summary.push({ name, url, counts, totalViolations: results.violations.length, seriousCritical });
    console.log(`${name}: serious=${counts.serious} critical=${counts.critical} moderate=${counts.moderate} minor=${counts.minor} | ${seriousCritical.join(', ') || 'none serious/critical'}`);
  } catch (e) {
    summary.push({ name, url, error: String(e) });
    console.log(`${name}: ERROR ${e}`);
  }
  await page.close();
  await context.close();
}
await browser.close();
fs.writeFileSync(`${OUT}/axe-summary.json`, JSON.stringify(summary, null, 2));
console.log('DONE');
