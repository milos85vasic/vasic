const { test, expect } = require('@playwright/test');

// UI/chrome localization proof (Part 3).
//   * vasic.digital: localized pages carry TRANSLATED chrome SERVER-SIDE — the
//     nav/footer/labels are in the page HTML itself (no JS needed), because the
//     Go generator now resolves T(lang,key) from the full 15-lang ui-i18n dict.
//   * milosvasic.ru: static localized pages (<html lang="xx>) auto-apply their
//     own language's chrome ON LOAD via the main.js html-lang fix — no manual
//     switch — while a stored user choice still wins.

const { VD_BASE: VD, MV_BASE: MV } = require('../env.js');  // vasic.digital (static), milosvasic.ru/_site (jekyll)

test.describe('vasic.digital — server-side localized chrome', () => {
  test('ru product page: Russian nav + footer in the served HTML', async ({ page }) => {
    const r = await page.goto(`${VD}/products/ru/catalogizer.html`);
    expect(r.status()).toBe(200);
    await expect(page.locator('html')).toHaveAttribute('lang', 'ru');
    const nav = page.locator('.od-nav__link');
    await expect(nav.filter({ hasText: 'Главная' })).toHaveCount(1);
    await expect(nav.filter({ hasText: 'Продукты' })).toHaveCount(1);
    // No English chrome leaking through:
    await expect(nav.filter({ hasText: 'Products' })).toHaveCount(0);
    await expect(page.locator('footer')).toContainText('OpenDesign');
    await expect(page.locator('body')).not.toContainText('built on the OpenDesign system');
  });

  test('ru portfolio page: Russian eyebrow/title + stat labels', async ({ page }) => {
    const r = await page.goto(`${VD}/portfolio/ru/index.html`);
    expect(r.status()).toBe(200);
    await expect(page.locator('html')).toHaveAttribute('lang', 'ru');
    await expect(page.locator('body')).toContainText('Продукт'); // pf.stat.products / nav
  });

  test('zh product page: Chinese nav in served HTML', async ({ page }) => {
    const r = await page.goto(`${VD}/products/zh/catalogizer.html`);
    expect(r.status()).toBe(200);
    await expect(page.locator('html')).toHaveAttribute('lang', 'zh');
    const nav = page.locator('.od-nav__link');
    await expect(nav.filter({ hasText: '产品' })).toHaveCount(1);      // Products
    await expect(nav.filter({ hasText: 'Products' })).toHaveCount(0);
  });

  test('ar product page: RTL + Arabic chrome in served HTML', async ({ page }) => {
    const r = await page.goto(`${VD}/products/ar/catalogizer.html`);
    expect(r.status()).toBe(200);
    await expect(page.locator('html')).toHaveAttribute('lang', 'ar');
    await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
    const nav = page.locator('.od-nav__link');
    await expect(nav.filter({ hasText: 'المنتجات' })).toHaveCount(1);  // Products
    await expect(nav.filter({ hasText: 'Products' })).toHaveCount(0);
  });
});

test.describe('milosvasic.ru — client-side apply on load (html-lang fix)', () => {
  test('ru product page renders Russian chrome on load, no manual switch', async ({ page, context }) => {
    await context.clearCookies();
    // fresh visitor: no stored mv-lang
    await page.addInitScript(() => { try { localStorage.removeItem('mv-lang'); } catch (e) {} });
    const r = await page.goto(`${MV}/products/ru/catalogizer.html`);
    expect(r.status()).toBe(200);
    await expect(page.locator('html')).toHaveAttribute('lang', 'ru');
    const nav = page.locator('#nav-links a');
    await expect(nav.filter({ hasText: 'Проекты' })).toHaveCount(1);   // nav.work
    await expect(nav.filter({ hasText: 'Work' })).toHaveCount(0);
  });

  test('stored user choice (de) still wins over the page lang (ru)', async ({ page }) => {
    await page.addInitScript(() => { try { localStorage.setItem('mv-lang', 'de'); } catch (e) {} });
    await page.goto(`${MV}/products/ru/catalogizer.html`);
    await expect(page.locator('html')).toHaveAttribute('lang', 'de');
    const nav = page.locator('#nav-links a');
    await expect(nav.filter({ hasText: 'Projekte' })).toHaveCount(1);  // nav.work (de)
  });
});
