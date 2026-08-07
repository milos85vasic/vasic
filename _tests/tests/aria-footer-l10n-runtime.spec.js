const { test, expect } = require('@playwright/test');

// Runtime proof for the aria/footer localization work: a client-side language
// switch must re-localize aria-labels (data-i18n-aria) too, not only text —
// on BOTH sites. Server-side rendering is proven separately by grep; this
// exercises the JS apply path (milosvasic main.js translate() / vasic od-i18n.js).

const MV = 'http://localhost:8082';   // milosvasic.ru/_site
const VD = 'http://localhost:8401';   // vasic.digital

test.describe('runtime language switch re-localizes aria-labels', () => {

  test('milosvasic.ru home — switching to RU updates theme-btn aria-label + footer suffix', async ({ page }) => {
    await page.goto(MV);
    const theme = page.locator('#theme-btn');
    // starts English (server-rendered en)
    await expect(theme).toHaveAttribute('aria-label', 'Toggle dark / light theme');

    // trigger the real runtime switch through the language menu
    await page.locator('#lang-btn').click();
    await page.locator('#lang-menu button[data-code="ru"]').click();

    await expect(page.locator('html')).toHaveAttribute('lang', 'ru');
    // aria-label re-localized at runtime via data-i18n-aria
    await expect(theme).toHaveAttribute('aria-label', 'Переключить темную / светлую тему');
    // title re-localized via data-i18n-title
    await expect(theme).toHaveAttribute('title', 'Тема');
    // footer suffix re-localized via data-i18n (proper nouns preserved)
    await expect(page.locator('span[data-i18n="footer.text"]')).toHaveText(
      'Belgrade · Dubna. Создан как статический сайт, развернут на GitHub Pages.');
  });

  test('vasic.digital home — switching to RU updates back-to-top aria-label', async ({ page }) => {
    await page.goto(VD);
    const top = page.locator('.od-to-top');
    await expect(top).toHaveAttribute('aria-label', 'Back to top');

    await page.locator('#od-lang-btn').click();
    await page.locator('#od-lang-menu button[data-lang="ru"]').click();

    await expect(page.locator('html')).toHaveAttribute('lang', 'ru');
    await expect(top).toHaveAttribute('aria-label', 'Вернуться наверх');
  });
});
