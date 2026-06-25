const { test, expect } = require('@playwright/test');
const BASE = 'http://localhost:8081';

test.describe('vasic.digital — company site', () => {

  test('loads with correct title and logo', async ({ page }) => {
    await page.goto(BASE);
    await expect(page).toHaveTitle(/Vasic Digital/i);
    const logo = page.locator('#logo');
    await expect(logo).toBeVisible();
    const ok = await logo.evaluate((img) => img.complete && img.naturalWidth > 0);
    expect(ok).toBeTruthy();
  });

  test('no-flash theme: data-theme set before paint', async ({ page }) => {
    await page.goto(BASE);
    const theme = await page.locator('html').getAttribute('data-theme');
    expect(['light', 'dark']).toContain(theme);
  });

  test('theme toggle switches and persists across reload', async ({ page }) => {
    await page.goto(BASE);
    const html = page.locator('html');
    const before = await html.getAttribute('data-theme');
    await page.locator('#theme-toggle').click();
    const after = await html.getAttribute('data-theme');
    expect(after).not.toBe(before);
    await page.reload();
    expect(await page.locator('html').getAttribute('data-theme')).toBe(after);
  });

  test('language switch to Russian updates content + persists', async ({ page }) => {
    await page.goto(BASE);
    await page.locator('#language-toggle').click();
    await page.locator('.language-option[data-lang="ru"]').click();
    await expect(page.locator('.nav-link').first()).not.toHaveText('Home');
    const stored = await page.evaluate(() => localStorage.getItem('vasic-digital-lang'));
    expect(stored).toBe('ru');
  });

  test('corrected stats and footer year render', async ({ page }) => {
    await page.goto(BASE);
    await expect(page.locator('.about-stats')).toContainText('240+');
    await expect(page.locator('.about-stats')).toContainText('GitHub Organizations');
    await expect(page.locator('.footer-bottom')).toContainText('2026');
  });

  test('no portfolio links point to known-private repos (no 404 deep links)', async ({ page }) => {
    await page.goto(BASE);
    const hrefs = await page.locator('.project-link').evaluateAll((els) => els.map((e) => e.getAttribute('href')));
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
    await expect(page.locator('.hamburger')).toBeVisible();
  });

  test('all service cards exist and have content', async ({ page }) => {
    await page.goto(BASE);
    const serviceCards = page.locator('.service-card');
    const count = await serviceCards.count();
    expect(count).toBe(9);
    // Each card should have an icon, heading, and description
    for (let i = 0; i < count; i++) {
      const card = serviceCards.nth(i);
      await expect(card.locator('.service-icon')).toBeVisible();
      await expect(card.locator('h3')).toBeVisible();
      await expect(card.locator('p')).toBeVisible();
      const heading = await card.locator('h3').textContent();
      expect(heading.length).toBeGreaterThan(0);
    }
  });

  test('portfolio section renders project cards', async ({ page }) => {
    await page.goto(BASE);
    await expect(page.locator('#portfolio .section-title')).toContainText('Portfolio');
    const portfolioItems = page.locator('.portfolio-item');
    const count = await portfolioItems.count();
    expect(count).toBeGreaterThanOrEqual(10);
    // Each portfolio item should have a title, project links, and description
    for (let i = 0; i < Math.min(count, 3); i++) {
      const item = portfolioItems.nth(i);
      await expect(item.locator('h3')).toBeVisible();
      await expect(item.locator('.project-link')).toBeVisible();
      await expect(item.locator('.project-tech')).toBeVisible();
    }
  });

  test('contact section exists and has contact methods', async ({ page }) => {
    await page.goto(BASE);
    await expect(page.locator('#contact')).toBeVisible();
    await expect(page.locator('#contact')).toContainText('Get in Touch');
    const contactItems = page.locator('.contact-item');
    const count = await contactItems.count();
    expect(count).toBeGreaterThanOrEqual(3);
    // Verify email, phone, and location are present
    const contactHtml = await page.locator('#contact').innerHTML();
    expect(contactHtml).toMatch(/i@mvasic\.ru/);
    expect(contactHtml).toMatch(/Belgrade|Serbia/);
  });

  test('hero buttons are clickable', async ({ page }) => {
    await page.goto(BASE);
    const primaryBtn = page.locator('.hero-buttons .btn-primary');
    const secondaryBtn = page.locator('.hero-buttons .btn-secondary');
    await expect(primaryBtn).toBeVisible();
    await expect(secondaryBtn).toBeVisible();
    // Primary button links to portfolio
    await expect(primaryBtn).toHaveAttribute('href', '#portfolio');
    // Secondary button links to GitHub
    await expect(secondaryBtn).toHaveAttribute('href', 'https://github.com/vasic-digital');
  });

  test('mobile hamburger menu toggles', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 800 });
    await page.goto(BASE);
    const hamburger = page.locator('.hamburger');
    const navMenu = page.locator('.nav-menu');
    await expect(hamburger).toBeVisible();
    // Initial state — menu is not active
    await expect(navMenu).not.toHaveClass(/active/);
    // Click to open
    await hamburger.click();
    await expect(navMenu).toHaveClass(/active/);
    await expect(hamburger).toHaveClass(/active/);
    // Click to close
    await hamburger.click();
    await expect(navMenu).not.toHaveClass(/active/);
  });

  test('evidence screenshots for each browser', async ({ page }, testInfo) => {
    if (testInfo.project.name !== 'chromium') test.skip();
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto(BASE);
    await page.evaluate(() => {
      localStorage.setItem('theme', 'light');
      document.documentElement.setAttribute('data-theme', 'light');
    });
    await page.screenshot({ path: 'evidence/vasic-desktop-light.png', fullPage: true });
    await page.evaluate(() => {
      localStorage.setItem('theme', 'dark');
      document.documentElement.setAttribute('data-theme', 'dark');
    });
    await page.screenshot({ path: 'evidence/vasic-desktop-dark.png', fullPage: true });
    await page.setViewportSize({ width: 375, height: 812 });
    await page.reload();
    await page.screenshot({ path: 'evidence/vasic-mobile.png', fullPage: true });
  });

});
