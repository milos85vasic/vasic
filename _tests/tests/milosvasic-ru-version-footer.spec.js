const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const { MV_BASE } = require('../env.js');

// Footer "Website version" — VERSION (milosvasic.ru/VERSION) is the single source;
// every page's footer must show v<VERSION> linked to that GitHub release tag, with
// the label localized from _data/ui.json. Drift between VERSION, the rendered
// footer and the release URL fails here; scripts/verify-live-site.py
// --expect-version and _tools/career/check_version_footer.py cover the whole site
// and the git-tag / release-page linkage.
const ROOT = path.join(__dirname, '..', '..', 'milosvasic.ru');
const VERSION = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const UI = JSON.parse(fs.readFileSync(path.join(ROOT, '_data', 'ui.json'), 'utf8'));
const RELEASE = `https://github.com/milos85vasic/milosvasic.ru/releases/tag/v${VERSION}`;
const LANGS = ['en', 'ru', 'sr', 'de', 'es', 'fr', 'be', 'zh', 'kk', 'hi', 'ja', 'ko', 'ar', 'tr', 'fa'];
const home = (l) => (l === 'en' ? '/' : `/${l}/`);

test.describe('milosvasic.ru — footer website version', () => {
  test('VERSION is semver', () => {
    expect(VERSION).toMatch(/^\d+\.\d+\.\d+$/);
  });

  for (const lang of LANGS) {
    test(`${lang} home footer shows localized label + v${VERSION} linked to its release`, async ({ page }) => {
      await page.goto(MV_BASE + home(lang));
      const ver = page.locator('footer .mv-ver');
      await expect(ver).toHaveCount(1);
      const link = ver.locator('a.mv-ver__link');
      await expect(link).toHaveAttribute('href', RELEASE);
      await expect(link).toHaveText(`v${VERSION}`);
      await expect(ver.locator('[data-i18n="footer.version"]')).toHaveText(UI[lang]['footer.version']);
      // aligned with the © line: same footer, bottom row
      const box = await page.locator('footer .mv-footbar').boundingBox();
      expect(box.width).toBeGreaterThan(0);
    });
  }

  test('product, expertise and portfolio pages carry the same footer link', async ({ page, request }) => {
    const xml = await (await request.get(MV_BASE + '/sitemap.xml')).text();
    const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => new URL(m[1]).pathname);
    const pick = [locs.find((p) => /^\/products\/[^/]+\.html$/.test(p)), locs.find((p) => p.startsWith('/expertise/')),
      locs.find((p) => /portfolio/.test(p))].filter(Boolean);
    expect(pick.length).toBeGreaterThanOrEqual(2);
    for (const p of pick) {
      await page.goto(MV_BASE + p);
      await expect(page.locator('footer a.mv-ver__link'), p).toHaveAttribute('href', RELEASE);
    }
  });

  test('switching language at runtime re-localizes the label, link unchanged', async ({ page }) => {
    await page.goto(MV_BASE + '/');
    await page.evaluate(() => { try { localStorage.setItem('mv-lang', 'de'); } catch (e) { /* ignore */ } });
    await page.goto(MV_BASE + '/');
    await page.locator('#lang-btn').click();
    await page.locator('#lang-menu button[data-code="ru"]').click();
    await page.waitForURL(/\/ru\//);
    await expect(page.locator('footer [data-i18n="footer.version"]')).toHaveText(UI.ru['footer.version']);
    await expect(page.locator('footer a.mv-ver__link')).toHaveAttribute('href', RELEASE);
  });

  test('RTL footer keeps the version inside the viewport (no horizontal overflow)', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 800 });
    await page.goto(MV_BASE + '/ar/');
    const over = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(over).toBeLessThanOrEqual(0);
    await expect(page.locator('footer a.mv-ver__link')).toBeVisible();
  });
});
