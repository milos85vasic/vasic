const { test, expect } = require('@playwright/test');
const { VD_BASE, MV_BASE } = require('../env.js');

// SEO / structured-data assertions (§11.4.169). Per key page:
//   * exactly one non-empty <title>
//   * a non-empty meta description
//   * a canonical link
//   * valid Open Graph (og:title/og:type/og:description) + Twitter card
//   * >= 1 parseable JSON-LD block carrying a schema.org @type
//   * reciprocal hreflang (x-default + en anchored to canonical) on the pages
//     that carry the Go-rendered hreflang matrix.
//
// Architecture note (honest, not a defect): the milosvasic.ru HOMEPAGE <head>
// is owned by Jekyll's jekyll-seo-tag, which does not emit hreflang. Its
// product/portfolio pages ARE Go-rendered and carry the full hreflang matrix,
// as does the entire vasic.digital site. So `hreflang: true` is asserted
// everywhere EXCEPT the milosvasic.ru homepage, which is documented in
// _tests/TEST-TYPES.md.

const PAGES = [
  { site: 'vasic.digital', base: VD_BASE, path: '/', hreflang: true },
  { site: 'vasic.digital', base: VD_BASE, path: '/portfolio/', hreflang: true },
  { site: 'vasic.digital', base: VD_BASE, path: '/products/helixtrack.html', hreflang: true },
  { site: 'milosvasic.ru', base: MV_BASE, path: '/', hreflang: false },
  { site: 'milosvasic.ru', base: MV_BASE, path: '/portfolio/', hreflang: true },
  { site: 'milosvasic.ru', base: MV_BASE, path: '/products/helixtrack.html', hreflang: true },
];

function findType(node, out) {
  if (node == null) return;
  if (Array.isArray(node)) { for (const n of node) findType(n, out); return; }
  if (typeof node === 'object') {
    if (node['@type']) out.push(node['@type']);
    for (const k of Object.keys(node)) findType(node[k], out);
  }
}

for (const p of PAGES) {
  test.describe(`SEO — ${p.site}${p.path}`, () => {
    test.beforeEach(async ({ page }) => {
      const r = await page.goto(p.base + p.path, { waitUntil: 'domcontentloaded' });
      expect(r.status()).toBeLessThan(400);
    });

    test('exactly one non-empty <title>', async ({ page }) => {
      const titles = await page.locator('head > title').count();
      expect(titles).toBe(1);
      expect((await page.title()).trim().length).toBeGreaterThan(0);
    });

    test('non-empty meta description', async ({ page }) => {
      const desc = await page.locator('head meta[name="description"]').first().getAttribute('content');
      expect(desc && desc.trim().length, 'meta description must be non-empty').toBeGreaterThan(10);
    });

    test('canonical link present and absolute', async ({ page }) => {
      const canon = await page.locator('head link[rel="canonical"]').first().getAttribute('href');
      expect(canon).toMatch(new RegExp(`^https://${p.site.replace('.', '\\.')}/`));
    });

    test('Open Graph + Twitter card', async ({ page }) => {
      for (const prop of ['og:title', 'og:type', 'og:description']) {
        const v = await page.locator(`head meta[property="${prop}"]`).first().getAttribute('content');
        expect(v && v.trim().length, `${prop} must be present`).toBeGreaterThan(0);
      }
      const twCard = await page.locator('head meta[name="twitter:card"]').first().getAttribute('content');
      expect(twCard, 'twitter:card must be present').toBeTruthy();
    });

    test('>=1 JSON-LD block with a schema.org @type', async ({ page }) => {
      const blocks = await page.locator('script[type="application/ld+json"]').allTextContents();
      expect(blocks.length, 'must have a JSON-LD block').toBeGreaterThan(0);
      const types = [];
      for (const b of blocks) {
        let parsed;
        expect(() => { parsed = JSON.parse(b); }, 'JSON-LD must be parseable').not.toThrow();
        findType(parsed, types);
      }
      expect(types.length, `no @type found in JSON-LD; blocks=${blocks.length}`).toBeGreaterThan(0);
    });

    if (p.hreflang) {
      test('reciprocal hreflang (x-default + en anchored to canonical)', async ({ page }) => {
        const links = page.locator('head link[rel="alternate"][hreflang]');
        const n = await links.count();
        expect(n, 'must emit an hreflang matrix').toBeGreaterThanOrEqual(2);
        const map = {};
        for (let i = 0; i < n; i++) {
          const lang = await links.nth(i).getAttribute('hreflang');
          map[lang] = await links.nth(i).getAttribute('href');
        }
        expect(map['x-default'], 'x-default alternate required').toBeTruthy();
        expect(map['en'], 'en alternate required').toBeTruthy();
        // Reciprocity anchor: the en/x-default alternate equals the page canonical.
        const canon = await page.locator('head link[rel="canonical"]').first().getAttribute('href');
        expect(map['x-default']).toBe(canon);
        expect(map['en']).toBe(canon);
      });
    }
  });
}
