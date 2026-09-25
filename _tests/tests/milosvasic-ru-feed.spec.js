const { test, expect } = require('@playwright/test');
const { MV_BASE } = require('../env.js');

// milosvasic.ru Atom feeds (RFC 4287). Until 2026-09-24 /feed.xml was a valid but
// EMPTY jekyll-feed output (no _posts) that no page advertised. The operator chose
// to build a real feed: the site's product pages, one feed per language.
// English = /feed.xml, every other language = /<lang>/feed.xml.
const LANGS = ['en', 'ar', 'be', 'de', 'es', 'fa', 'fr', 'hi', 'ja', 'kk', 'ko', 'ru', 'sr', 'tr', 'zh'];
const feedPath = (l) => (l === 'en' ? '/feed.xml' : `/${l}/feed.xml`);
const RFC3339 = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$/;

// The expected entry count is DERIVED from the sitemap (the site's own list of
// indexable pages), so adding a product page changes the expectation with it.
async function expectedProducts(request) {
  const xml = await (await request.get(MV_BASE + '/sitemap.xml')).text();
  const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => new URL(m[1]).pathname);
  const per = {};
  for (const l of LANGS) {
    per[l] = locs.filter((p) => (l === 'en' ? /^\/products\/[^/]+\.html$/.test(p) : p.startsWith(`/products/${l}/`)));
  }
  return per;
}

test.describe('milosvasic.ru — Atom feeds', () => {
  for (const lang of LANGS) {
    test(`feed for ${lang} is well-formed Atom listing that language's product pages`, async ({ page, request }) => {
      const expected = (await expectedProducts(request))[lang];
      expect(expected.length, `sitemap must list product pages for ${lang}`).toBeGreaterThan(0);
      const res = await request.get(MV_BASE + feedPath(lang));
      expect(res.status(), `${feedPath(lang)} must exist`).toBe(200);
      expect(res.headers()['content-type'] || '', 'served as XML').toMatch(/xml/);
      const text = await res.text();
      // Parse in a real browser: DOMParser reports ANY well-formedness error.
      await page.goto(MV_BASE + '/');
      const parsed = await page.evaluate((src) => {
        const doc = new DOMParser().parseFromString(src, 'application/xml');
        if (doc.querySelector('parsererror')) return { error: doc.querySelector('parsererror').textContent.slice(0, 200) };
        const NS = 'http://www.w3.org/2005/Atom';
        const one = (el, n) => Array.from(el.children).filter((c) => c.namespaceURI === NS && c.localName === n);
        const root = doc.documentElement;
        const txt = (el, n) => (one(el, n)[0] || {}).textContent;
        return {
          rootOk: root.namespaceURI === NS && root.localName === 'feed',
          lang: root.getAttribute('xml:lang'),
          id: txt(root, 'id'), title: txt(root, 'title'), updated: txt(root, 'updated'),
          author: one(root, 'author').length > 0 && !!(one(one(root, 'author')[0], 'name')[0] || {}).textContent,
          self: one(root, 'link').filter((l) => l.getAttribute('rel') === 'self').map((l) => l.getAttribute('href') + '|' + l.getAttribute('type')),
          entries: one(root, 'entry').map((e) => ({
            id: txt(e, 'id'), title: txt(e, 'title'), updated: txt(e, 'updated'),
            link: (one(e, 'link')[0] || { getAttribute: () => null }).getAttribute('href'),
          })),
        };
      }, text);
      expect(parsed.error, 'feed must be well-formed XML').toBeUndefined();
      expect(parsed.rootOk, 'root must be atom:feed').toBe(true);
      expect(parsed.lang).toBe(lang);
      expect(parsed.id).toBe('https://milosvasic.ru' + feedPath(lang));
      expect(parsed.title, 'feed title').toBeTruthy();
      expect(parsed.updated).toMatch(RFC3339);
      expect(parsed.author, 'RFC 4287: feed author').toBe(true);
      expect(parsed.self, 'rel=self at the canonical URL').toContain('https://milosvasic.ru' + feedPath(lang) + '|application/atom+xml');
      expect(parsed.entries.length, 'entry count equals the sitemap product pages for this language').toBe(expected.length);
      const ids = new Set();
      for (const e of parsed.entries) {
        expect(e.title, `entry title (${e.id})`).toBeTruthy();
        expect(e.updated).toMatch(RFC3339);
        expect(e.link).toBe(e.id);
        expect(e.id, 'absolute canonical URL, never localhost').toMatch(/^https:\/\/milosvasic\.ru\/products\//);
        expect(ids.has(e.id), `duplicate id ${e.id}`).toBe(false);
        ids.add(e.id);
      }
      expect([...ids].sort()).toEqual(expected.map((p) => 'https://milosvasic.ru' + p).sort());
      // Every entry link resolves on the served site (production host mapped to the QA base).
      const bad = [];
      for (const e of parsed.entries) {
        const r = await request.get(MV_BASE + new URL(e.link).pathname);
        if (r.status() !== 200) bad.push(`${r.status()} ${e.link}`);
      }
      expect(bad, 'entry links that do not return 200').toEqual([]);
    });
  }

  test('there is exactly one feed per language and no stray jekyll-feed duplicate', async ({ request }) => {
    const res = await request.get(MV_BASE + '/feed.xml');
    const t = await res.text();
    expect(t.match(/<feed[\s>]/g) || [], 'one <feed> root').toHaveLength(1);
    expect(t, 'must not be the empty jekyll-feed output').toContain('<entry>');
    expect(t, 'jekyll-feed generator tag must be gone').not.toMatch(/generator[^>]*jekyll/i);
  });

  for (const lang of LANGS) {
    test(`the ${lang} home page advertises its own feed and the link resolves`, async ({ page, request }) => {
      await page.goto(MV_BASE + (lang === 'en' ? '/' : `/${lang}/`));
      const hrefs = await page.locator('head link[rel="alternate"][type="application/atom+xml"]').evaluateAll((els) => els.map((e) => e.getAttribute('href')));
      expect(hrefs, 'exactly one atom alternate').toHaveLength(1);
      expect(new URL(hrefs[0], MV_BASE).pathname).toBe(feedPath(lang));
      expect((await request.get(new URL(hrefs[0], MV_BASE).toString())).status()).toBe(200);
    });
  }
});
