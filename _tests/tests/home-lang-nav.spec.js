// Home language-switch NAVIGATION: choosing a language on the EN home must load
// the fully-translated localized home (/<lang>/) — body + chrome — not a chrome-
// only client swap. Closes the "home body doesn't translate on switch" issue.
const { test, expect } = require('@playwright/test');
const { VD_BASE, MV_BASE } = require('../env.js');

// vasic.digital (self-contained) — switcher mounted by od-i18n.js.
test('vasic.digital: EN home → pick Russian → lands on /ru/ with Russian body', async ({ page }) => {
  await page.goto(`${VD_BASE}/`);
  await expect(page.locator('html')).toHaveAttribute('lang', 'en');
  await page.locator('#od-lang-btn').click();
  await expect(page.locator('#od-lang-menu')).toBeVisible();
  await page.locator('#od-lang-menu button[data-lang="ru"]').click();
  await page.waitForURL('**/ru/');
  await expect(page.locator('html')).toHaveAttribute('lang', 'ru');
  // BODY is translated (hero title in Cyrillic, not the English source).
  const hero = await page.locator('h1.od-hero__title').innerText();
  expect(hero).toMatch(/[А-Яа-я]/);
  expect(hero).not.toMatch(/AI-native software engineering/);
});

test('vasic.digital: EN home → pick Arabic → /ar/ is RTL with Arabic body', async ({ page }) => {
  await page.goto(`${VD_BASE}/`);
  await page.locator('#od-lang-btn').click();
  await page.locator('#od-lang-menu button[data-lang="ar"]').click();
  await page.waitForURL('**/ar/');
  await expect(page.locator('html')).toHaveAttribute('lang', 'ar');
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  const hero = await page.locator('h1.od-hero__title').innerText();
  expect(hero).toMatch(/[؀-ۿ]/); // Arabic script
});

// milosvasic.ru (Jekyll) — switcher in shared layout, driven by main.js + MV_PAGE.
test('milosvasic.ru: EN home → pick Russian → lands on /ru/ with Russian body', async ({ page }) => {
  await page.goto(`${MV_BASE}/`);
  await page.locator('#lang-btn').click();
  await expect(page.locator('.lang-menu.open')).toBeVisible();
  await page.locator('#lang-menu button[data-code="ru"]').click();
  await page.waitForURL('**/ru/');
  await expect(page.locator('html')).toHaveAttribute('lang', 'ru');
  // A translated product-card blurb proves the BODY (not just chrome) is localized.
  const bodyText = await page.locator('main').innerText();
  expect(bodyText).toMatch(/[А-Яа-я]/);
});
