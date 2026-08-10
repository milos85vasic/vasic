const { test, expect } = require('@playwright/test');

// Link-integrity crawl (§11.4.169 integration test type).
// For each generated site: start from the homepage, portfolio, and a product
// page; collect every INTERNAL link (nav, product cards, portfolio, downloads);
// assert each resolves < 400. Then parse sitemap.xml and assert every listed
// URL resolves. Then re-assert the anti-bluff private-repo guard: no link may
// deep-link a known-private repo.

const SITES = [
  { key: 'vasic.digital', base: 'http://localhost:8401', domain: 'vasic.digital' },
  { key: 'milosvasic.ru', base: 'http://localhost:8082', domain: 'milosvasic.ru' },
];

// Known-private repos/paths that must never be linked (extends the homepage guard).
const BANNED = [
  '/Web-Client', '/Desktop-Client', '/Android-Client', '/iOS-Client',
  '/Bear-Suite/Mail', '/Bear-Suite/Messenger',
];

const SEEDS = ['/', '/portfolio/', '/products/helixtrack.html'];

function isInternal(href) {
  if (!href) return false;
  if (href.startsWith('#')) return false;
  if (/^(mailto:|tel:|javascript:)/i.test(href)) return false;
  if (/^https?:\/\//i.test(href)) return false; // external absolute
  return true;
}

for (const site of SITES) {
  test.describe(`link-integrity — ${site.key}`, () => {

    test('all internal links resolve (< 400) and none deep-link a private repo', async ({ page }) => {
      const seen = new Set();
      const bannedHits = [];

      for (const seed of SEEDS) {
        const resp = await page.goto(site.base + seed, { waitUntil: 'domcontentloaded' });
        expect(resp, `seed ${seed} must load`).toBeTruthy();
        expect(resp.status(), `seed ${seed} status`).toBeLessThan(400);

        const hrefs = await page.locator('a[href]').evaluateAll((els) => els.map((e) => e.getAttribute('href')));
        for (const h of hrefs) {
          for (const b of BANNED) if (h && h.includes(b)) bannedHits.push(`${seed} -> ${h}`);
          if (!isInternal(h)) continue;
          // Resolve relative to the page it was found on.
          const abs = new URL(h, site.base + seed).toString();
          if (abs.startsWith(site.base)) seen.add(abs);
        }
      }

      expect(bannedHits, `private-repo deep links found: ${bannedHits.join(', ')}`).toHaveLength(0);
      expect(seen.size, 'should have discovered internal links to check').toBeGreaterThan(10);

      const broken = [];
      for (const url of seen) {
        const r = await page.request.get(url);
        if (r.status() >= 400) broken.push(`${url} -> ${r.status()}`);
      }
      expect(broken, `broken internal links: ${broken.join(', ')}`).toHaveLength(0);
    });

    test('every sitemap.xml URL resolves (200)', async ({ page }) => {
      // This legitimately crawls every sitemap URL (500+ for vasic.digital)
      // sequentially; the default 60s cap is too tight on a slow CI runner even
      // though every URL still resolves. Give it room — the check is unchanged.
      test.setTimeout(300000);
      const r = await page.request.get(site.base + '/sitemap.xml');
      expect(r.status()).toBe(200);
      const xml = await r.text();
      const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
      expect(locs.length, 'sitemap must list URLs').toBeGreaterThan(5);

      const prodPrefix = `https://${site.domain}/`;
      const broken = [];
      for (const loc of locs) {
        expect(loc.startsWith(prodPrefix), `sitemap loc ${loc} must be a production URL`).toBeTruthy();
        const local = site.base + '/' + loc.slice(prodPrefix.length);
        const rr = await page.request.get(local);
        if (rr.status() >= 400) broken.push(`${loc} (${local}) -> ${rr.status()}`);
      }
      expect(broken, `sitemap URLs that 404 locally: ${broken.join(', ')}`).toHaveLength(0);
    });

  });
}
