const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const { VD_BASE: BASE } = require('../env.js');

// Footer "Website version" for vasic.digital — vasic.digital/VERSION is the single
// source; every page's footer shows v<VERSION> linked to the GitHub release page of
// that tag, with the label localized from _tools/gen/ui-i18n.json (footer.version).
// scripts/check-site-version-footer.py covers every page of the built tree.
const REPO_ROOT = path.join(__dirname, '..', '..');
const VERSION = fs.readFileSync(path.join(REPO_ROOT, 'vasic.digital', 'VERSION'), 'utf8').trim();
const UI = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, '_tools', 'gen', 'ui-i18n.json'), 'utf8'));
const RELEASE = `https://github.com/vasic-digital/vasic-digital.github.io/releases/tag/v${VERSION}`;
const LANGS = ['en', 'ru', 'sr', 'de', 'es', 'fr', 'be', 'zh', 'kk', 'hi', 'ja', 'ko', 'ar', 'tr', 'fa'];
const home = (l) => (l === 'en' ? '/' : `/${l}/`);

test.describe('vasic.digital — footer website version', () => {
  test('VERSION is semver', () => {
    expect(VERSION).toMatch(/^\d+\.\d+\.\d+$/);
  });

  for (const lang of LANGS) {
    test(`${lang} home footer: localized label + v${VERSION} linked to its release`, async ({ page }) => {
      await page.goto(BASE + home(lang));
      const ver = page.locator('footer .site-version');
      await expect(ver).toHaveCount(1);
      await expect(ver).toBeVisible();
      const link = ver.locator('a');
      await expect(link).toHaveAttribute('href', RELEASE);
      await expect(link).toHaveText(`v${VERSION}`);
      await expect(ver.locator('[data-i18n="footer.version"]')).toHaveText(UI[lang]['footer.version']);
      if (lang === 'ar' || lang === 'fa') {
        await expect(link).toHaveCSS('direction', 'ltr');
      }
    });
  }

  test('product and portfolio pages carry the same footer link', async ({ page }) => {
    for (const p of ['/products/catalogizer.html', '/portfolio/', '/products/ru/catalogizer.html', '/portfolio/ja/']) {
      await page.goto(BASE + p);
      await expect(page.locator('footer a[href*="/releases/tag/"]'), p).toHaveAttribute('href', RELEASE);
    }
  });

  test('footer wraps inside a 320px viewport: badge stays within the footer box', async ({ page }) => {
    // (document-level scrollWidth is NOT asserted: the hero aurora decoration already
    // overflows on main, independent of the footer.)
    await page.setViewportSize({ width: 320, height: 700 });
    await page.goto(BASE + '/de/');
    const a = page.locator('footer .site-version a');
    await a.scrollIntoViewIfNeeded();
    await expect(a).toBeVisible();
    const f = await page.locator('footer').boundingBox();
    const b = await a.boundingBox();
    expect(f.x + f.width).toBeLessThanOrEqual(320.5);
    expect(b.x).toBeGreaterThanOrEqual(f.x);
    expect(b.x + b.width).toBeLessThanOrEqual(f.x + f.width + 0.5);
  });

  test('home: client-side language switch keeps the badge and re-localizes the label', async ({ page }) => {
    await page.goto(BASE + '/');
    await page.evaluate((dict) => {
      // apply the home dictionary through the page's own data-i18n path (od-i18n.js)
      const d = window.OD_I18N.ru;
      document.querySelectorAll('[data-i18n]').forEach((n) => { const k = n.getAttribute('data-i18n'); if (d[k] != null) n.innerHTML = d[k]; });
    }, null);
    await expect(page.locator('footer [data-i18n="footer.version"]')).toHaveText(UI.ru['footer.version']);
    await expect(page.locator('footer a[href*="/releases/tag/"]')).toHaveAttribute('href', RELEASE);
    await expect(page.locator('footer [data-i18n="footer.text"]')).toContainText('Vasic Digital');
  });
});
