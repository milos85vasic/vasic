const { test, expect } = require('@playwright/test');
const { MV_BASE: BASE } = require('../env.js');

test.describe('milosvasic.ru — download popup (EN/SR/RU chooser)', () => {

  test('popup offers all shipped languages and builds correct CV hrefs', async ({ page }) => {
    await page.goto(BASE);
    await page.locator('button[data-dl="cv"]').first().click();
    const modal = page.locator('#dl-modal');
    await expect(modal).toBeVisible();
    // All 15 languages ship genuine PDFs → the switcher offers the full set.
    await expect(modal.locator('.dl-lang')).toHaveCount(15);
    for (const L of ['EN', 'SR', 'RU', 'DE']) {
      await expect(modal.locator(`.dl-lang[data-lang="${L}"]`))
        .toHaveAttribute('href', new RegExp(`Milos_Vasic_CV_${L}\\.pdf$`));
    }
  });

  test('popup switches to Cover Letter hrefs', async ({ page }) => {
    await page.goto(BASE);
    await page.locator('button[data-dl="cl"]').first().click();
    const modal = page.locator('#dl-modal');
    await expect(modal).toBeVisible();
    await expect(modal.locator('.dl-lang[data-lang="EN"]')).toHaveAttribute('href', /Milos_Vasic_Cover_Letter_EN\.pdf$/);
    await expect(modal.locator('.dl-lang[data-lang="SR"]')).toHaveAttribute('href', /Milos_Vasic_Cover_Letter_SR\.pdf$/);
  });

  test('popup closes on Escape', async ({ page }) => {
    await page.goto(BASE);
    await page.locator('button[data-dl="cv"]').first().click();
    const modal = page.locator('#dl-modal');
    await expect(modal).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(modal).toBeHidden();
  });

  test('EN CV and EN/SR Cover Letter PDFs return 200', async ({ page }) => {
    await page.goto(BASE);
    for (const f of ['Milos_Vasic_CV_EN.pdf', 'Milos_Vasic_Cover_Letter_EN.pdf', 'Milos_Vasic_Cover_Letter_SR.pdf']) {
      const resp = await page.request.get(`${BASE}/downloads/${f}`);
      expect(resp.status(), f).toBe(200);
    }
  });
});

// The old "read-more article modal" homepage system is gone. On the reframed
// OpenDesign homepage, each product card exposes a "Read more" link that
// NAVIGATES to a real /products/<slug>.html page. These tests assert that
// current, user-visible behavior (product-page navigation replaces the modal).
test.describe('milosvasic.ru — product-card "Read more" navigation (replaces article modal)', () => {

  test('every product card exposes a "Read more" link to a real /products/*.html page', async ({ page }) => {
    await page.goto(BASE);
    const readMore = page.locator('.od-product-card a[data-i18n="mv2.readmore"]');
    const count = await readMore.count();
    // Homepage previously exposed 12 article triggers; the reframed grid shows
    // at least that many product cards, each with a Read more link.
    expect(count).toBeGreaterThanOrEqual(12);
    const hrefs = await readMore.evaluateAll((els) => els.map((e) => e.getAttribute('href')));
    for (const h of hrefs) expect(h).toMatch(/^\/products\/[a-z0-9-]+\.html$/);
  });

  test('clicking a product card "Read more" navigates to the product page with its content', async ({ page }) => {
    await page.goto(BASE);
    const link = page.locator('.od-product-card a[href="/products/helixtrack.html"][data-i18n="mv2.readmore"]').first();
    await expect(link).toBeVisible();
    await link.click();
    await page.waitForURL('**/products/helixtrack.html');
    await expect(page).toHaveTitle(/HelixTrack/i);
    await expect(page.locator('h1')).toContainText(/HelixTrack/i);
  });

  test('localized article fragments are still generated and served (EN, 200)', async ({ page }) => {
    const slugs = ['helix-track-core','helix-code','helix-translate','helix-agent','helix-flow-platform','catalogizer','llms-verifier','panoptic','mail-server-factory','share-connect','grab-tube','android-toolkit'];
    for (const s of slugs) {
      const resp = await page.request.get(`${BASE}/articles/en/${s}.html`);
      expect(resp.status(), s).toBe(200);
    }
  });
});
