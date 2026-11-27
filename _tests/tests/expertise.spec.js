// /expertise/ — hub + 10 area pages across EN and ar, fa, de, ja, zh.
// Hermetic: served from milosvasic.ru/_site by playwright.config.js (MV_BASE).
// Canonical/hreflang URLs are production URLs; they are resolved against the
// local server by swapping the origin, so a 404 here is a missing built page.
const { test, expect } = require('@playwright/test');
const { AxeBuilder } = require('@axe-core/playwright');
const { MV_BASE } = require('../env.js');

const CANON = 'https://milosvasic.ru';
const AREAS = ['ai-engineering', 'android', 'android-aosp', 'android-tv', 'desktop',
  'flutter', 'go', 'mobile', 'react-native', 'web-frontend'];
const LANGS = ['en', 'ar', 'fa', 'de', 'ja', 'zh'];
const RTL = new Set(['ar', 'fa']);
const EXPECTED_HREFLANGS = 16; // 15 languages + x-default

const path = (area, lang) =>
  '/expertise/' + (area ? area + '/' : '') + (lang === 'en' ? '' : lang + '/');
const TARGETS = [];
for (const area of [null, ...AREAS]) for (const lang of LANGS) TARGETS.push({ area, lang, p: path(area, lang) });

const local = (u) => (u.startsWith(CANON) ? MV_BASE + u.slice(CANON.length) : u);

function jsonLd(html) {
  return [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)]
    .map((m) => JSON.parse(m[1]));
}

test.describe('expertise — structure, SEO, resilience', () => {
  for (const t of TARGETS) {
    test(`${t.p} lang/dir, canonical, hreflang, JSON-LD`, async ({ page, request }) => {
      const errors = [];
      page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
      page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
      const resp = await page.goto(MV_BASE + t.p);
      expect(resp.status()).toBe(200);

      const html = await page.content();
      expect(await page.getAttribute('html', 'lang')).toBe(t.lang);
      expect(await page.getAttribute('html', 'dir')).toBe(RTL.has(t.lang) ? 'rtl' : 'ltr');

      const canon = await page.getAttribute('link[rel="canonical"]', 'href');
      expect(canon).toBe(CANON + t.p);

      const hl = await page.$$eval('link[rel="alternate"][hreflang]',
        (els) => els.map((e) => [e.getAttribute('hreflang'), e.getAttribute('href')]));
      expect(hl.length, 'hreflang count').toBe(EXPECTED_HREFLANGS);
      expect(new Set(hl.map((h) => h[0])).size, 'hreflang codes unique').toBe(EXPECTED_HREFLANGS);
      expect(hl.some((h) => h[0] === 'x-default')).toBe(true);
      expect(hl.some((h) => h[0] === t.lang && h[1] === CANON + t.p), 'self hreflang').toBe(true);
      const bad = [];
      for (const [, href] of hl) {
        const r = await request.get(local(href));
        if (r.status() !== 200) bad.push(r.status() + ' ' + href);
      }
      expect(bad, 'hreflang targets must resolve 200').toEqual([]);

      const ld = jsonLd(html);
      expect(ld.length, 'JSON-LD blocks parse').toBeGreaterThan(0);
      const web = ld.find((o) => o['@type'] === 'WebPage');
      expect(web, 'WebPage JSON-LD present').toBeTruthy();
      expect(web.url, 'WebPage url').toBe(CANON + t.p);
      // Area pages carry ProfilePage; the hub is allowed WebPage only, but every
      // typed page object must declare the page language.
      const typed = ld.filter((o) => o['@type'] === 'ProfilePage' || o['@type'] === 'WebPage');
      if (t.area) expect(ld.some((o) => o['@type'] === 'ProfilePage'), 'area page needs ProfilePage').toBe(true);
      for (const o of typed) expect(o.inLanguage, `${o['@type']}.inLanguage`).toBe(t.lang);

      expect(errors, 'no console/page errors').toEqual([]);
    });

    test(`${t.p} no horizontal overflow at 400px`, async ({ page }) => {
      await page.setViewportSize({ width: 400, height: 800 });
      await page.goto(MV_BASE + t.p);
      const o = await page.evaluate(() => ({
        sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
      expect(o.sw, `scrollWidth ${o.sw} vs ${o.cw}`).toBeLessThanOrEqual(o.cw + 1);
    });
  }
});

test.describe('expertise — colour contrast, light and dark', () => {
  // Representative subset (every area in en, plus hub in every language) keeps runtime sane.
  const subset = TARGETS.filter((t) => t.lang === 'en' || t.area === null);
  for (const scheme of ['light', 'dark']) {
    for (const t of subset) {
      test(`${t.p} contrast [${scheme}]`, async ({ page }) => {
        test.slow();
        // reducedMotion: the area timeline fades in via a scroll-driven animation
        // (opacity .25 at scroll 0); axe would measure that transient, not the resting style.
        await page.emulateMedia({ colorScheme: scheme, reducedMotion: 'reduce' });
        await page.goto(MV_BASE + t.p);
        const res = await new AxeBuilder({ page }).withRules(['color-contrast']).analyze();
        const v = res.violations.flatMap((x) => x.nodes.map((n) => n.target.join(' ') + ' :: ' + (n.any[0] && n.any[0].message)));
        expect(v, 'contrast violations').toEqual([]);
      });
    }
  }
});

test.describe('expertise — admin console is private', () => {
  // Since milosvasic.ru commit 14b2d8b the operator-private console is listed in
  // _config.yml `exclude:` and is never published. The earlier premise of this
  // test (served, 200, noindex) is obsolete; the invariant that matters is that
  // it is NOT served and NOT advertised.
  test('admin console is not published and not in the sitemap', async ({ request }) => {
    const resp = await request.get(MV_BASE + '/admin/console.html');
    expect(resp.status(), 'the operator-private console must not be served').toBe(404);
    const sm = await (await request.get(MV_BASE + '/sitemap.xml')).text();
    expect(sm).not.toContain('/admin/');
  });
  test('sitemap lists the hub and every area (derived, floored)', async ({ request }) => {
    const sm = await (await request.get(MV_BASE + '/sitemap.xml')).text();
    const locs = [...sm.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
    for (const area of [null, ...AREAS]) for (const lang of LANGS)
      expect(locs, path(area, lang)).toContain(CANON + path(area, lang));
  });
});
