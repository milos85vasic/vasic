const { test, expect } = require('@playwright/test');
const BASE = 'http://localhost:8401';

const SLUGS = ['catalogizer','grabtube','shareconnect','panoptic','android-toolkit','asinka','helixtrack-core','helixcode','helixtranslate','helix-flow-platform','llmsverifier','server-factory-core-framework','mail-server-factory','helixtrack-web-client','helixtrack-desktop-client','helixtrack-android-client','helixtrack-ios-client','yole'];

test.describe('vasic.digital — read-more article modal', () => {

  test('all 18 portfolio cards have a read-more trigger', async ({ page }) => {
    await page.goto(BASE);
    expect(await page.locator('[data-article]').count()).toBe(18);
  });

  test('clicking read-more opens a dialog with article content', async ({ page }) => {
    await page.goto(BASE);
    await page.locator('[data-article="catalogizer"]').first().click();
    const dialog = page.locator('[role="dialog"]');
    await expect(dialog).toContainText('Catalogizer');
    await page.keyboard.press('Escape');
  });

  test('all 18 article fragments return 200', async ({ page }) => {
    for (const s of SLUGS) {
      const resp = await page.request.get(`${BASE}/articles/en/${s}.html`);
      expect(resp.status(), s).toBe(200);
    }
  });

  test('articles.css and articles.js are linked and load', async ({ page }) => {
    await page.goto(BASE);
    expect(await page.request.get(`${BASE}/css/articles.css`).then(r => r.status())).toBe(200);
    expect(await page.request.get(`${BASE}/js/articles.js`).then(r => r.status())).toBe(200);
  });
});
