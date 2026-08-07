const { test, expect } = require('@playwright/test');

// Per-language download switcher (auto-publish tooling verification).
//
// Proves that, on BOTH sites, the CURRENT UI language serves the matching
// -language PDF, falling back to EN when no PDF exists for that language yet.
// The shipped PDF languages are EN/SR/RU. `de` (German) has NO PDF — it was
// English content mislabeled as German and was removed — so a `de` UI must
// fall back to the EN PDF, and the switcher never offers a silent-404 DE row.

const MV = 'http://localhost:8082';   // milosvasic.ru/_site
const VD = 'http://localhost:8401';   // vasic.digital

test.describe('milosvasic.ru — download popup honours the current UI language', () => {

  test('UI lang = de (no DE PDF) → CV popup falls back to EN as the current choice and it resolves 200', async ({ page }) => {
    // Set the UI language to German BEFORE first paint (same mechanism the site
    // uses: localStorage "mv-lang" applied to <html lang> by the head bootstrap).
    await page.addInitScript(() => { try { localStorage.setItem('mv-lang', 'de'); } catch (e) {} });
    await page.goto(MV);
    await expect(page.locator('html')).toHaveAttribute('lang', 'de');

    await page.locator('button[data-dl="cv"]').first().click();
    const modal = page.locator('#dl-modal');
    await expect(modal).toBeVisible();

    // German has no PDF (it was removed — English mislabeled as German), so the
    // current-language row falls back to EN and no DE row is offered at all.
    const current = modal.locator('.dl-lang[data-current="1"]');
    await expect(current).toHaveCount(1);
    await expect(current).toHaveAttribute('data-lang', 'EN');
    await expect(current).toHaveAttribute('href', /Milos_Vasic_CV_EN\.pdf$/);
    await expect(modal.locator('.dl-lang[data-lang="DE"]')).toHaveCount(0);

    const href = await current.getAttribute('href');
    const resp = await page.request.get(new URL(href, MV).toString());
    expect(resp.status(), href).toBe(200);
  });

  test('UI lang = fr (no PDF yet) → CV popup falls back to EN as the current choice', async ({ page }) => {
    await page.addInitScript(() => { try { localStorage.setItem('mv-lang', 'fr'); } catch (e) {} });
    await page.goto(MV);
    await expect(page.locator('html')).toHaveAttribute('lang', 'fr');

    await page.locator('button[data-dl="cv"]').first().click();
    const modal = page.locator('#dl-modal');
    await expect(modal).toBeVisible();

    const current = modal.locator('.dl-lang[data-current="1"]');
    await expect(current).toHaveCount(1);
    await expect(current).toHaveAttribute('data-lang', 'EN'); // fallback
    await expect(current).toHaveAttribute('href', /Milos_Vasic_CV_EN\.pdf$/);
  });

  test('EN/SR/RU PDFs (CV, Cover Letter, Portfolio) return 200; DE was removed', async ({ page }) => {
    for (const f of [
      'Milos_Vasic_CV_EN.pdf', 'Milos_Vasic_CV_SR.pdf', 'Milos_Vasic_CV_RU.pdf',
      'Milos_Vasic_Cover_Letter_EN.pdf', 'Milos_Vasic_Cover_Letter_SR.pdf', 'Milos_Vasic_Cover_Letter_RU.pdf',
      'Portfolio_EN.pdf', 'Portfolio_SR.pdf', 'Portfolio_RU.pdf',
    ]) {
      const resp = await page.request.get(`${MV}/downloads/${f}`);
      expect(resp.status(), f).toBe(200);
    }
    // DE PDFs intentionally don't exist (were English content mislabeled as German).
    const de = await page.request.get(`${MV}/downloads/Milos_Vasic_CV_DE.pdf`);
    expect(de.status(), 'Milos_Vasic_CV_DE.pdf should be absent').toBe(404);
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

  test('company Portfolio EN/SR/RU resolve 200; DE was removed', async ({ page }) => {
    for (const f of ['Portfolio_EN.pdf', 'Portfolio_SR.pdf', 'Portfolio_RU.pdf']) {
      const resp = await page.request.get(`${VD}/downloads/${f}`);
      expect(resp.status(), f).toBe(200);
    }
    // The DE portfolio was removed (English mislabeled as German).
    const de = await page.request.get(`${VD}/downloads/Portfolio_DE.pdf`);
    expect(de.status(), 'Portfolio_DE.pdf should be absent').toBe(404);
  });
});
