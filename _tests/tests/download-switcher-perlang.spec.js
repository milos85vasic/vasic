const { test, expect } = require('@playwright/test');

// Per-language download switcher (auto-publish tooling verification).
//
// Proves that, on BOTH sites, the download popup offers the FULL set of shipped
// languages and that the CURRENT UI language is pre-selected with its OWN
// matching-language PDF. All 15 languages now ship genuine CV / Cover-Letter /
// Portfolio PDFs (verified on disk + genuine translated content), so the switcher
// offers all 15 and never falls back for a supported language. EN remains the
// first/default row and the fallback for any UNSUPPORTED language.

const MV = 'http://localhost:8082';   // milosvasic.ru/_site
const VD = 'http://localhost:8401';   // vasic.digital

// Every language that ships a PDF (order per the deploy language order).
const ALL15 = ['EN', 'SR', 'RU', 'DE', 'ES', 'FR', 'BE', 'ZH', 'KK', 'HI', 'JA', 'KO', 'AR', 'TR', 'FA'];

test.describe('milosvasic.ru — download popup honours the current UI language', () => {

  // Each supported UI language pre-selects its OWN matching-language PDF (not EN).
  for (const { ui, PDF } of [
    { ui: 'de', PDF: 'DE' },
    { ui: 'fr', PDF: 'FR' },
    { ui: 'sr', PDF: 'SR' },
  ]) {
    test(`UI lang = ${ui} → CV popup pre-selects ${PDF} and it resolves 200`, async ({ page }) => {
      // Set the UI language BEFORE first paint (same mechanism the site uses:
      // localStorage "mv-lang" applied to <html lang> by the head bootstrap).
      await page.addInitScript((l) => { try { localStorage.setItem('mv-lang', l); } catch (e) {} }, ui);
      await page.goto(MV);
      await expect(page.locator('html')).toHaveAttribute('lang', ui);

      await page.locator('button[data-dl="cv"]').first().click();
      const modal = page.locator('#dl-modal');
      await expect(modal).toBeVisible();

      // The full language set is offered — no silent 404 rows, no missing langs.
      await expect(modal.locator('.dl-lang')).toHaveCount(ALL15.length);

      // The current-language row is this UI language's own PDF.
      const current = modal.locator('.dl-lang[data-current="1"]');
      await expect(current).toHaveCount(1);
      await expect(current).toHaveAttribute('data-lang', PDF);
      await expect(current).toHaveAttribute('href', new RegExp(`Milos_Vasic_CV_${PDF}\\.pdf$`));

      const href = await current.getAttribute('href');
      const resp = await page.request.get(new URL(href, MV).toString());
      expect(resp.status(), href).toBe(200);
    });
  }

  test('every language CV / Cover Letter / Portfolio PDF resolves 200 (all 15)', async ({ page }) => {
    const docs = ['Milos_Vasic_CV', 'Milos_Vasic_Cover_Letter', 'Portfolio'];
    for (const doc of docs) {
      for (const L of ALL15) {
        const resp = await page.request.get(`${MV}/downloads/${doc}_${L}.pdf`);
        expect(resp.status(), `${doc}_${L}.pdf`).toBe(200);
      }
    }
  });
});

test.describe('vasic.digital — localized portfolio serves the matching-language PDF', () => {

  test('EN portfolio page links to Portfolio_EN.pdf and it resolves 200', async ({ page }) => {
    await page.goto(`${VD}/portfolio/`);
    const dl = page.locator('a.od-btn--primary[href$="Portfolio_EN.pdf"]');
    await expect(dl).toHaveCount(1);
    const href = await dl.getAttribute('href');
    const resp = await page.request.get(new URL(href, `${VD}/portfolio/`).toString());
    expect(resp.status(), href).toBe(200);
  });

  test('every language company Portfolio PDF resolves 200 (all 15)', async ({ page }) => {
    for (const L of ALL15) {
      const resp = await page.request.get(`${VD}/downloads/Portfolio_${L}.pdf`);
      expect(resp.status(), `Portfolio_${L}.pdf`).toBe(200);
    }
  });
});
