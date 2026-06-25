const { test, expect } = require('@playwright/test');
const BASE = 'http://localhost:8401';
const SLUGS = ['catalogizer','grabtube','shareconnect','panoptic','android-toolkit','asinka','helixtrack-core','helixcode','helixtranslate','helix-flow-platform','llmsverifier','server-factory-core-framework','mail-server-factory','helixtrack-web-client','helixtrack-desktop-client','helixtrack-android-client','helixtrack-ios-client','yole'];

test.describe('vasic.digital — localized article fragments (RU/SR)', () => {
  test('all 18 RU and 18 SR fragments return 200', async ({ page }) => {
    for (const lang of ['ru', 'sr']) {
      for (const s of SLUGS) {
        const r = await page.request.get(`${BASE}/articles/${lang}/${s}.html`);
        expect(r.status(), `${lang}/${s}`).toBe(200);
      }
    }
  });

  test('RU fragment is Cyrillic', async ({ page }) => {
    const ru = await (await page.request.get(`${BASE}/articles/ru/catalogizer.html`)).text();
    expect(/[Ѐ-ӿ]/.test(ru)).toBeTruthy();
  });
});
