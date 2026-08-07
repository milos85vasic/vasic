// Render preview HTML files to PNG in light and dark via Chromium.
// Run from repo root with NODE_PATH=_tests/node_modules
// Usage: node shoot.cjs '[{"file":"/abs.html","out":"/abs-THEME.png"}]'
const { chromium } = require('@playwright/test');
(async () => {
  const jobs = JSON.parse(process.argv[2]);
  const browser = await chromium.launch();
  for (const j of jobs) {
    for (const theme of ['light', 'dark']) {
      const page = await browser.newPage({ viewport: { width: 1280, height: 2400 }, colorScheme: theme });
      await page.goto('file://' + j.file, { waitUntil: 'load' });
      await page.evaluate((t) => document.documentElement.setAttribute('data-theme', t), theme);
      await page.waitForTimeout(250);
      const out = j.out.replace('THEME', theme);
      await page.screenshot({ path: out, fullPage: true });
      console.log('shot', out);
      await page.close();
    }
  }
  await browser.close();
})();
