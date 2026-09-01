const { test, expect } = require('@playwright/test');
const BASE = 'http://localhost:8401';

// vasic.digital — AI-development company homepage, rebuilt on the OpenDesign system.
// Asserts the NEW .od-* structure: header/nav, hero, product cards linking products/,
// portfolio link resolves, theme toggle + persistence, mobile has no overflow,
// and keeps the banned-private-repo deep-link guard.
test.describe('vasic.digital — AI company site (OpenDesign)', () => {

  test('loads with correct title', async ({ page }) => {
    await page.goto(BASE);
    await expect(page).toHaveTitle(/Vasic Digital/i);
  });

  test('primary nav is present with Work/Products/Portfolio/Contact', async ({ page }) => {
    await page.goto(BASE);
    const nav = page.locator('header.od-header nav.od-nav');
    await expect(nav).toBeVisible();
    const links = nav.locator('a.od-nav__link');
    await expect(links).toHaveCount(4);
    await expect(links.nth(0)).toHaveText('Work');
    await expect(links.nth(1)).toHaveText('Products');
    await expect(links.nth(2)).toHaveText('Portfolio');
    await expect(links.nth(3)).toHaveText('Contact');
  });

  test('hero renders with OpenDesign hero + CTA to products and portfolio', async ({ page }) => {
    await page.goto(BASE);
    await expect(page.locator('.od-hero__title')).toBeVisible();
    await expect(page.locator('.od-hero .od-btn--primary')).toHaveAttribute('href', '#products');
    await expect(page.locator('.od-hero .od-btn--secondary')).toHaveAttribute('href', 'portfolio/');
  });

  test('no-FOUC bootstrap applies a stored theme before paint', async ({ page }) => {
    await page.addInitScript(() => { try { localStorage.setItem('od-theme', 'dark'); } catch (e) {} });
    await page.goto(BASE);
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  });

  test('theme toggle switches and persists across reload', async ({ page }) => {
    await page.goto(BASE);
    const html = page.locator('html');
    await page.locator('#od-theme-toggle').click();
    const after = await html.getAttribute('data-theme');
    expect(['light', 'dark']).toContain(after);
    const stored = await page.evaluate(() => localStorage.getItem('od-theme'));
    expect(stored).toBe(after);
    await page.reload();
    expect(await page.locator('html').getAttribute('data-theme')).toBe(after);
  });

  test('at least 8 product cards link to real products/*.html pages', async ({ page }) => {
    await page.goto(BASE);
    const productLinks = page.locator('.od-product-card a[href^="products/"][href$=".html"]');
    const count = await productLinks.count();
    expect(count).toBeGreaterThanOrEqual(8);
    const hrefs = await productLinks.evaluateAll((els) => els.map((e) => e.getAttribute('href')));
    for (const h of hrefs) expect(h).toMatch(/^products\/[a-z0-9-]+\.html$/);
    // A representative product page must actually resolve (200).
    const resp = await page.request.get(`${BASE}/products/helixtrack.html`);
    expect(resp.status()).toBe(200);
  });

  test('Portfolio PDF download link is present and resolves (200) on home + /portfolio/', async ({ page }) => {
    await page.goto(BASE);
    const dl = page.locator('a[href$="downloads/Portfolio_EN.pdf"]').first();
    await expect(dl).toBeVisible();
    const resp = await page.request.get(`${BASE}/downloads/Portfolio_EN.pdf`);
    expect(resp.status()).toBe(200);
    const body = await resp.body();
    expect(body.length).toBeGreaterThan(10000); // a real PDF, not an empty/placeholder file
    expect(body.slice(0, 5).toString('latin1')).toBe('%PDF-');

    await page.goto(`${BASE}/portfolio/`);
    const dl2 = page.locator('a[href$="downloads/Portfolio_EN.pdf"]').first();
    await expect(dl2).toBeVisible();
  });

  test('portfolio link resolves (200)', async ({ page }) => {
    await page.goto(BASE);
    const pf = page.locator('a[href="portfolio/"]').first();
    await expect(pf).toBeVisible();
    const resp = await page.request.get(`${BASE}/portfolio/`);
    expect(resp.status()).toBe(200);
  });

  test('governance block cites HelixConstitution and HelixQA', async ({ page }) => {
    await page.goto(BASE);
    const gov = page.locator('#governance');
    await expect(gov).toContainText('HelixConstitution');
    await expect(gov).toContainText('HelixQA');
  });

  test('no links deep-link known-private repos (no 404 deep links)', async ({ page }) => {
    await page.goto(BASE);
    const hrefs = await page.locator('a[href]').evaluateAll((els) => els.map((e) => e.getAttribute('href')));
    const banned = ['/Web-Client', '/Desktop-Client', '/Android-Client', '/iOS-Client', '/Bear-Suite/Mail', '/Bear-Suite/Messenger'];
    for (const h of hrefs) {
      for (const b of banned) expect(h, `link ${h} must not deep-link private repo ${b}`).not.toContain(b);
    }
    expect(hrefs.length).toBeGreaterThan(10);
  });

  test('responsive: no horizontal overflow on mobile (375px)', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 800 });
    await page.goto(BASE);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow).toBeLessThanOrEqual(2);
  });

  test('evidence screenshots (chromium)', async ({ page }, testInfo) => {
    if (testInfo.project.name !== 'chromium') test.skip();
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto(BASE);
    // Settle the hero stat count-up BEFORE the first capture. The three
    // `[data-od-count]` stats are animated by a JS requestAnimationFrame loop
    // (assets/od/motion.js `initCountUp`): an IntersectionObserver starts them
    // and for 1200 ms they rewrite textContent from 0 up to the authored value.
    // `animations: 'disabled'` governs CSS animations/transitions and WAAPI — it
    // does NOT reach a rAF loop — so without this wait the FIRST screenshot
    // catches mid-count digits, and because the digit widths differ the whole
    // hero reflows, which is why this shot drifted across runs while the others
    // did not. Wait past the animation's own declared duration, then ASSERT the
    // settled state so a future change fails loudly instead of silently
    // producing nondeterministic evidence.
    if (await page.locator('[data-od-count]').count() > 0) {
      await page.waitForTimeout(1500); // > the 1200 ms count-up duration
      const settled = await page.evaluate(() =>
        [...document.querySelectorAll('[data-od-count]')].every((el) =>
          !el.hasAttribute('data-od-count-final') ||
          el.textContent === el.getAttribute('data-od-count-final')));
      expect(settled, 'hero count-up still mid-flight — screenshot would be nondeterministic').toBe(true);
    }

    // `animations: 'disabled'` is what makes this evidence reproducible AND
    // correct. Playwright fast-forwards finite CSS transitions to completion and
    // cancels infinite animations to their initial state, which settles all
    // three sources of pixel drift at once: the theme-swap
    // `transition: background-color` fade (vasic-digital.css:246), the `.reveal`
    // IntersectionObserver opacity transitions, and the two infinite decorative
    // loops (`vd-aurora-drift` 22s at vasic-digital.css:554, `vd-scan` 6.5s at
    // :582). Without it these shots sampled a random frame of a running loop.
    await page.evaluate(() => { localStorage.setItem('od-theme', 'light'); document.documentElement.setAttribute('data-theme', 'light'); });
    await page.screenshot({ path: 'evidence/homepages/vasic-desktop-light.png', fullPage: true, animations: 'disabled' });
    await page.evaluate(() => { localStorage.setItem('od-theme', 'dark'); document.documentElement.setAttribute('data-theme', 'dark'); });
    await page.screenshot({ path: 'evidence/homepages/vasic-desktop-dark.png', fullPage: true, animations: 'disabled' });
    await page.setViewportSize({ width: 375, height: 812 });
    await page.reload();
    await page.screenshot({ path: 'evidence/homepages/vasic-mobile.png', fullPage: true, animations: 'disabled' });
  });

});
