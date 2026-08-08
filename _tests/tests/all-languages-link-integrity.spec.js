const { test, expect } = require('@playwright/test');

/*
 * EXHAUSTIVE all-language link & sitemap integrity — the permanent guard that
 * MUST catch broken links before a human ever does (Helix Constitution:
 * automated full-site QA is the safety net; manual QA must find nothing).
 *
 * For BOTH sites, for EVERY page in sitemap.xml (all 15 languages), this:
 *   1. asserts the page itself resolves (2xx),
 *   2. extracts EVERY <a href> and resolves it RELATIVE-AWARE against the page's
 *      canonical URL (this is what catches page-relative 404s like a localized
 *      home linking "portfolio/" → /<lang>/portfolio/ — the exact class of bug
 *      manual QA caught on Serbian),
 *   3. extracts the JS language-switcher targets (OD_PAGE/MV_PAGE `paths`,
 *      which static href crawling cannot see) and checks them,
 *   4. checks every downloadable PDF for every language,
 * then asserts ZERO internal targets are broken (<400), reporting each broken
 * URL with a sample referring page.
 *
 * Default: runs against the locally-served build (playwright webServer on
 * :8401 / :8082). Live mode: set VD_BASE / MV_BASE to the production origins.
 */

const SITES = [
  {
    key: 'vasic.digital',
    canonical: 'https://vasic.digital',
    base: process.env.VD_BASE || 'http://localhost:8401',
    pdfs: ['Portfolio'],
  },
  {
    key: 'milosvasic.ru',
    canonical: 'https://milosvasic.ru',
    base: process.env.MV_BASE || 'http://localhost:8082',
    pdfs: ['Milos_Vasic_CV', 'Milos_Vasic_Cover_Letter', 'Portfolio'],
  },
];

// Every language that ships a PDF / localized route.
const PDF_LANGS = ['EN', 'SR', 'RU', 'DE', 'ES', 'FR', 'BE', 'ZH', 'KK', 'HI', 'JA', 'KO', 'AR', 'TR', 'FA'];

const HREF_RE = /href=["']([^"']+)["']/g;
// Language-switcher path map entries: 2-letter code → root-absolute URL. The
// chrome dictionary (OD_I18N) never uses "/"-leading values, so this is specific
// to OD_PAGE/MV_PAGE .paths.
const PATHMAP_RE = /"([a-z]{2})":"(\/[^"]*)"/g;

function canonicalToBase(url, site) {
  return url.startsWith(site.canonical)
    ? site.base + url.slice(site.canonical.length)
    : url;
}

for (const site of SITES) {
  test(`${site.key} — exhaustive all-language link & sitemap integrity`, async ({ request }) => {
    test.setTimeout(600000); // exhaustive crawl of ~525 pages + their links

    // 1) Discover every page from the live sitemap (auto-scales as content grows).
    const smResp = await request.get(`${site.base}/sitemap.xml`);
    expect(smResp.status(), 'sitemap.xml must resolve').toBe(200);
    const sm = await smResp.text();
    const pages = [...sm.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
    expect(pages.length, 'sitemap must list pages').toBeGreaterThan(100);

    // 2) Walk every page; collect resolved internal targets → sample referrer.
    const targets = new Map(); // localURL -> referrer(canonical)
    const addTarget = (localURL, ref) => { if (!targets.has(localURL)) targets.set(localURL, ref); };

    for (const canonicalPage of pages) {
      const localPage = canonicalToBase(canonicalPage, site);
      const resp = await request.get(localPage);
      expect(resp.status(), `sitemap page must resolve: ${canonicalPage}`).toBeLessThan(400);
      const html = await resp.text();

      // 2a) every <a href>, resolved relative-aware against the CANONICAL page URL.
      for (const m of html.matchAll(HREF_RE)) {
        const raw = m[1].trim();
        if (!raw || raw.startsWith('#') || /^(mailto:|tel:|javascript:|data:)/i.test(raw)) continue;
        let abs;
        try { abs = new URL(raw, canonicalPage); } catch { continue; }
        if (abs.protocol !== 'http:' && abs.protocol !== 'https:') continue;
        if (abs.host !== new URL(site.canonical).host) continue; // internal only
        abs.hash = '';
        addTarget(canonicalToBase(abs.toString(), site), canonicalPage);
      }

      // 2b) JS language-switcher targets (OD_PAGE / MV_PAGE .paths) — invisible to href crawling.
      const scope = html.includes('OD_PAGE') || html.includes('MV_PAGE') ? html : '';
      for (const m of scope.matchAll(PATHMAP_RE)) {
        const path = m[2];
        addTarget(canonicalToBase(site.canonical + path, site), canonicalPage);
      }
    }

    // 3) Every downloadable PDF for every language (linked via JS popup on MV).
    for (const doc of site.pdfs) {
      for (const L of PDF_LANGS) {
        addTarget(`${site.base}/downloads/${doc}_${L}.pdf`, `${site.canonical}/ (downloads)`);
      }
    }

    // 4) Check every unique internal target; collect the broken ones.
    const broken = [];
    for (const [url, ref] of targets) {
      const r = await request.get(url);
      if (r.status() >= 400) broken.push(`${r.status()}  ${url}   (referrer: ${ref})`);
    }

    expect(
      broken,
      `Broken internal links on ${site.key} (${broken.length}):\n` + broken.join('\n'),
    ).toEqual([]);
  });
}
