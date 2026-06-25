const { test, expect } = require('@playwright/test');
const BASE = 'http://localhost:8082';
const SLUGS = ['helix-track-core','helix-code','helix-translate','helix-agent','helix-flow-platform','catalogizer','llms-verifier','panoptic','mail-server-factory','share-connect','grab-tube','android-toolkit'];

test.describe('milosvasic.ru — localized article fragments (RU/SR)', () => {

  test('all 12 RU and 12 SR fragments return 200', async ({ page }) => {
    for (const lang of ['ru', 'sr']) {
      for (const s of SLUGS) {
        const r = await page.request.get(`${BASE}/articles/${lang}/${s}.html`);
        expect(r.status(), `${lang}/${s}`).toBe(200);
      }
    }
  });

  test('RU fragment is Cyrillic, SR fragment is Latin', async ({ page }) => {
    const ru = await (await page.request.get(`${BASE}/articles/ru/helix-track-core.html`)).text();
    const sr = await (await page.request.get(`${BASE}/articles/sr/helix-track-core.html`)).text();
    expect(/[Ѐ-ӿ]/.test(ru), 'RU has Cyrillic').toBeTruthy();
    // SR (Latin) body should not be predominantly Cyrillic
    const srCyr = (sr.match(/[Ѐ-ӿ]/g) || []).length;
    expect(srCyr, 'SR body is Latin (≈0 Cyrillic)').toBeLessThan(10);
  });

  test('switching to RU then opening an article shows Cyrillic content', async ({ page }) => {
    await page.goto(BASE);
    await page.locator('#lang-btn').click();
    await page.waitForSelector('.lang-menu.open');
    await page.locator('#lang-menu button[data-code="ru"]').click();
    expect(await page.locator('html').getAttribute('lang')).toBe('ru');
    await page.locator('.card-more[data-article="helix-track-core"]').click();
    const dialog = page.locator('.mv-article-modal');
    await expect(dialog).toHaveAttribute('data-open', 'true');
    await expect(dialog).toContainText(/[Ѐ-ӿ]/);
  });
});
