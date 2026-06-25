const { test, expect } = require('@playwright/test');
const BASE = 'http://localhost:8082';

test.describe('milosvasic.ru — download popup (EN/SR/RU chooser)', () => {

  test('popup offers EN/SR/RU and builds correct CV hrefs', async ({ page }) => {
    await page.goto(BASE);
    await page.locator('button[data-dl="cv"]').first().click();
    const modal = page.locator('#dl-modal');
    await expect(modal).toBeVisible();
    await expect(modal.locator('.dl-lang')).toHaveCount(3);
    await expect(modal.locator('.dl-lang[data-lang="EN"]')).toHaveAttribute('href', /Milos_Vasic_CV_EN\.pdf$/);
    await expect(modal.locator('.dl-lang[data-lang="SR"]')).toHaveAttribute('href', /Milos_Vasic_CV_SR\.pdf$/);
    await expect(modal.locator('.dl-lang[data-lang="RU"]')).toHaveAttribute('href', /Milos_Vasic_CV_RU\.pdf$/);
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

test.describe('milosvasic.ru — read-more article modal', () => {

  test('every project card has a read-more trigger', async ({ page }) => {
    await page.goto(BASE);
    const triggers = page.locator('.card-more[data-article]');
    expect(await triggers.count()).toBe(12);
  });

  test('clicking read-more opens dialog with the article content', async ({ page }) => {
    await page.goto(BASE);
    await page.locator('.card-more[data-article="helix-track-core"]').click();
    const dialog = page.locator('.mv-article-modal');
    await expect(dialog).toHaveAttribute('data-open', 'true');
    await expect(dialog).toContainText('HelixTrack Core');
    // scroll lock applied
    const locked = await page.evaluate(() => document.body.classList.contains('mv-article-lock'));
    expect(locked).toBeTruthy();
    // closes on Escape and restores scroll
    await page.keyboard.press('Escape');
    await expect(dialog).toHaveAttribute('data-open', 'false');
    const unlocked = await page.evaluate(() => document.body.classList.contains('mv-article-lock'));
    expect(unlocked).toBeFalsy();
  });

  test('all 12 article fragments return 200', async ({ page }) => {
    const slugs = ['helix-track-core','helix-code','helix-translate','helix-agent','helix-flow-platform','catalogizer','llms-verifier','panoptic','mail-server-factory','share-connect','grab-tube','android-toolkit'];
    for (const s of slugs) {
      const resp = await page.request.get(`${BASE}/articles/en/${s}.html`);
      expect(resp.status(), s).toBe(200);
    }
  });
});
