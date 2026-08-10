const { test, expect } = require('@playwright/test');
const BASE = 'http://localhost:8401';

const SLUGS = ['catalogizer','grabtube','shareconnect','panoptic','android-toolkit','asinka','helixtrack-core','helixcode','helixtranslate','helix-flow-platform','llmsverifier','server-factory-core-framework','mail-server-factory','helixtrack-web-client','helixtrack-desktop-client','helixtrack-android-client','helixtrack-ios-client','yole'];

// The old "read-more article modal" is gone. Portfolio and homepage product
// cards now NAVIGATE to real /products/<slug>.html pages. These tests assert
// that current, user-visible behavior (product-page navigation replaces modal).
test.describe('vasic.digital — portfolio/product navigation (replaces article modal)', () => {

  test('portfolio lists product cards linking to real products pages (>=8)', async ({ page }) => {
    await page.goto(`${BASE}/portfolio/`);
    const links = page.locator('.od-product-card a[href*="products/"][href$=".html"]');
    const count = await links.count();
    expect(count).toBeGreaterThanOrEqual(8);
    const hrefs = await links.evaluateAll((els) => els.map((e) => e.getAttribute('href')));
    for (const h of hrefs) expect(h).toMatch(/products\/[a-z0-9-]+\.html$/);
    // A representative target resolves (200).
    const resp = await page.request.get(`${BASE}/products/catalogizer.html`);
    expect(resp.status()).toBe(200);
  });

  test('clicking a portfolio product link navigates to the product page with its content', async ({ page }) => {
    await page.goto(`${BASE}/portfolio/`);
    const link = page.locator('.od-product-card a[href$="/products/catalogizer.html"], .od-product-card a[href$="products/catalogizer.html"]').first();
    await expect(link).toBeVisible();
    await link.click();
    await page.waitForURL('**/products/catalogizer.html');
    await expect(page).toHaveTitle(/Catalogizer/i);
    await expect(page.locator('h1')).toContainText(/Catalogizer/i);
  });

  test('all 18 article fragments return 200', async ({ page }) => {
    for (const s of SLUGS) {
      const resp = await page.request.get(`${BASE}/articles/en/${s}.html`);
      expect(resp.status(), s).toBe(200);
    }
  });

  // NOTE: the legacy article-modal assets (css/articles.css, js/articles.js) were
  // removed as dead code — vasic.digital replaced the article modal with the
  // portfolio/product navigation (0 pages link them). The obsolete "articles.* load"
  // assertion was deleted with them.
});
