const { test, expect } = require('@playwright/test');
const BASE = 'http://localhost:8082';

// milosvasic.ru — AI-engineer personal site, reframed on the OpenDesign system while
// keeping the Jekyll `default` layout chrome (nav, footer, theme + MV_I18N, download popup).
// Asserts the NEW .od-* content structure and that the existing mechanisms still work.
test.describe('milosvasic.ru — AI engineer site (OpenDesign + Jekyll)', () => {

  test('loads with correct title', async ({ page }) => {
    await page.goto(BASE);
    // Name now renders with diacritics: "Miloš Vasić" (accept ASCII or diacritic form).
    await expect(page).toHaveTitle(/Milo[sš] Vasi[cć]/i);
  });

  test('hero renders name, lede and a CV download trigger', async ({ page }) => {
    await page.goto(BASE);
    await expect(page.locator('.od-hero__title')).toContainText('Vasi');
    await expect(page.locator('.od-hero__lede')).toBeVisible();
    const cvBtn = page.locator('button[data-dl="cv"]').first();
    await expect(cvBtn).toBeVisible();
    await expect(cvBtn).toContainText('Download CV');
  });

  test('no-FOUC theme: data-theme set on html before paint', async ({ page }) => {
    await page.goto(BASE);
    const theme = await page.locator('html').getAttribute('data-theme');
    expect(['light', 'dark']).toContain(theme);
  });

  test('theme toggle switches dark/light and persists across reload', async ({ page }) => {
    await page.goto(BASE);
    const html = page.locator('html');
    const before = await html.getAttribute('data-theme');
    await page.locator('#theme-btn').click();
    await page.waitForTimeout(150);
    const after = await html.getAttribute('data-theme');
    expect(after).not.toBe(before);
    const stored = await page.evaluate(() => localStorage.getItem('mv-theme'));
    expect(stored).toBe(after);
    await page.reload();
    expect(await page.locator('html').getAttribute('data-theme')).toBe(after);
  });

  test('primary nav present; language switch (RU) still updates it + persists', async ({ page }) => {
    await page.goto(BASE);
    const navWork = page.locator('.nav-links a').first();
    await expect(navWork).toHaveText('Work');
    await expect(page.locator('.nav-links a')).toHaveCount(4);

    await page.locator('#lang-btn').click();
    await page.waitForSelector('.lang-menu.open');
    await page.locator('#lang-menu button[data-code="ru"]').click();
    await expect(navWork).toHaveText('Проекты');
    const stored = await page.evaluate(() => localStorage.getItem('mv-lang'));
    expect(stored).toBe('ru');
    expect(await page.locator('html').getAttribute('lang')).toBe('ru');
  });

  test('at least 8 product cards link to real products/*.html pages', async ({ page }) => {
    await page.goto(BASE);
    const productLinks = page.locator('.od-product-card a[href*="/products/"][href$=".html"]');
    const count = await productLinks.count();
    expect(count).toBeGreaterThanOrEqual(8);
    const hrefs = await productLinks.evaluateAll((els) => els.map((e) => e.getAttribute('href')));
    for (const h of hrefs) expect(h).toMatch(/\/products\/[a-z0-9-]+\.html$/);
    const resp = await page.request.get(new URL(hrefs[0], BASE).toString());
    expect(resp.status()).toBe(200);
  });

  test('portfolio link resolves (200)', async ({ page }) => {
    await page.goto(BASE);
    const pf = page.locator('a[href$="/portfolio/"]').first();
    await expect(pf).toBeVisible();
    const href = await pf.getAttribute('href');
    const resp = await page.request.get(new URL(href, BASE).toString());
    expect(resp.status()).toBe(200);
  });

  test('download popup: EN CV and EN Portfolio PDFs resolve 200', async ({ page }) => {
    await page.goto(BASE);
    // CV
    await page.locator('button[data-dl="cv"]').first().click();
    const modal = page.locator('#dl-modal');
    await expect(modal).toBeVisible();
    const cvEn = modal.locator('.dl-lang[data-lang="EN"]');
    const cvHref = await cvEn.getAttribute('href');
    expect(cvHref).toMatch(/Milos_Vasic_CV_EN\.pdf$/);
    let resp = await page.request.get(new URL(cvHref, BASE).toString());
    expect(resp.status()).toBe(200);
    await page.locator('#dl-modal .dl-x').click();
    await expect(modal).toBeHidden();

    // Portfolio (EN-only extension of the popup)
    await page.locator('button[data-dl="portfolio"]').first().click();
    await expect(modal).toBeVisible();
    const pfEn = modal.locator('.dl-lang[data-lang="EN"]');
    const pfHref = await pfEn.getAttribute('href');
    expect(pfHref).toMatch(/Portfolio_EN\.pdf$/);
    resp = await page.request.get(new URL(pfHref, BASE).toString());
    expect(resp.status()).toBe(200);
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

  test('footer has correct year (2026) and social links', async ({ page }) => {
    await page.goto(BASE);
    await expect(page.locator('footer')).toContainText('2026');
    const hrefs = await page.locator('footer a').evaluateAll((els) => els.map((e) => e.getAttribute('href')));
    const all = hrefs.join(' ');
    expect(all).toMatch(/github/);
    expect(all).toMatch(/t\.me|telegram/);
    expect(all).toMatch(/mvasic\.ru/);
  });

  test('evidence screenshots (chromium)', async ({ page }, testInfo) => {
    if (testInfo.project.name !== 'chromium') test.skip();
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto(BASE);
    // Settle any JS count-up before capturing. milosvasic.ru carries no
    // `[data-od-count]` today, so this is a no-op here; it is present because
    // this page DOES load assets/od/motion.js, whose `initCountUp` drives a
    // 1200 ms requestAnimationFrame text animation that `animations: 'disabled'`
    // cannot reach. Without it, adding one stat to this page would silently make
    // the evidence nondeterministic again (that is exactly what happened on
    // vasic.digital). Costs nothing while there are no counters.
    if (await page.locator('[data-od-count]').count() > 0) {
      await page.waitForTimeout(1500); // > the 1200 ms count-up duration
      const settled = await page.evaluate(() =>
        [...document.querySelectorAll('[data-od-count]')].every((el) =>
          !el.hasAttribute('data-od-count-final') ||
          el.textContent === el.getAttribute('data-od-count-final')));
      expect(settled, 'count-up still mid-flight — screenshot would be nondeterministic').toBe(true);
    }

    // `animations: 'disabled'` is what makes this evidence reproducible AND
    // correct. Playwright fast-forwards finite CSS transitions to completion and
    // cancels infinite animations to their initial state, which settles all
    // three sources of pixel drift at once: the theme-swap
    // `transition: background-color` fade, the `.reveal` IntersectionObserver
    // opacity transitions, and any looping decorative animation. Without it the
    // committed "dark theme" shot was a mid-fade frame that never reached the
    // dark background token at all — a wrong screenshot, not just a noisy one.
    await page.evaluate(() => { localStorage.setItem('mv-theme', 'light'); document.documentElement.setAttribute('data-theme', 'light'); });
    await page.screenshot({ path: 'evidence/homepages/milos-desktop-light.png', fullPage: true, animations: 'disabled' });
    await page.evaluate(() => { localStorage.setItem('mv-theme', 'dark'); document.documentElement.setAttribute('data-theme', 'dark'); });
    await page.screenshot({ path: 'evidence/homepages/milos-desktop-dark.png', fullPage: true, animations: 'disabled' });
    await page.setViewportSize({ width: 375, height: 812 });
    await page.reload();
    await page.screenshot({ path: 'evidence/homepages/milos-mobile.png', fullPage: true, animations: 'disabled' });
  });

});
