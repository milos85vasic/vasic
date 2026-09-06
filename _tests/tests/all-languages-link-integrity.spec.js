const { test, expect } = require('@playwright/test');
const { VD_BASE, MV_BASE } = require('../env.js');

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
 * Default: runs against the locally-served build. Live mode: set VD_BASE /
 * MV_BASE to the production origins.
 *
 * WHERE THE BASE URLS COME FROM — and why this spec no longer names a port.
 * Until this edit, this was the ONE spec of 22 that did not read ../env.js; it
 * carried its own `process.env.VD_BASE || 'http://localhost:8401'` pair. That
 * is exactly the split the F13/F14 work removed everywhere else, and leaving it
 * here was not cosmetic: playwright.config.js BINDS its two static servers on
 * VD_PORT / MV_PORT, so `VD_PORT=9401 MV_PORT=9082 npx playwright test` served
 * 9401 while this spec still requested 8401. Nothing listens there, `get()`
 * below turns a connection refusal into `last = 0`, and `expect(sm.status)
 * .toBe(200)` then reports `Received: 0` — a HARNESS misconfiguration rendered
 * as a broken production website. Deriving both bases from env.js makes the
 * port that is bound and the base that is requested one value, so they cannot
 * disagree; setting VD_BASE / MV_BASE directly still wins outright, which is
 * what playwright.live.config.js and _tools/deploy-langs.sh rely on.
 */

const SITES = [
  {
    key: 'vasic.digital',
    canonical: 'https://vasic.digital',
    base: VD_BASE,
    pdfs: ['Portfolio'],
  },
  {
    key: 'milosvasic.ru',
    canonical: 'https://milosvasic.ru',
    base: MV_BASE,
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
    // Local build resolves in seconds; a LIVE GitHub-Pages crawl is thousands of
    // network round-trips, so give live headroom + tolerate transient drops.
    const isLive = !/localhost|127\.0\.0\.1/.test(site.base);
    test.setTimeout(isLive ? 1_800_000 : 600_000);
    const POOL = isLive ? 8 : 16; // bounded concurrency: fast, but gentle on the host

    // Bounded-concurrency map — run fn over items POOL-at-a-time.
    async function mapPool(items, fn) {
      const it = items[Symbol.iterator]();
      await Promise.all(
        Array.from({ length: Math.min(POOL, items.length || 1) }, async () => {
          for (let n = it.next(); !n.done; n = it.next()) await fn(n.value);
        }),
      );
    }
    // GET with transient-retry: a live host dropping ONE connection (thrown error /
    // status 0 / 429 / 5xx) must not abort the whole crawl — retry with backoff;
    // only a PERSISTENT failure after 4 tries, or a definitive 4xx, is returned.
    async function get(url, wantBody) {
      let last = 0;
      for (let attempt = 1; attempt <= 4; attempt++) {
        try {
          const r = await request.get(url, { timeout: 30_000, maxRedirects: 5 });
          last = r.status();
          if (last < 400) return wantBody ? { status: last, body: await r.text() } : { status: last };
          if (last < 500 && last !== 429) return { status: last, body: '' }; // definitive client error
        } catch (e) { last = 0; } // network throw → transient
        await new Promise((res) => setTimeout(res, 400 * attempt));
      }
      return { status: last, body: '' }; // 0 / 429 / 5xx after retries → persistent failure
    }

    // 1) Discover every page from the sitemap (auto-scales as content grows).
    const sm = await get(`${site.base}/sitemap.xml`, true);
    expect(sm.status, 'sitemap.xml must resolve').toBe(200);
    const pages = [...sm.body.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
    expect(pages.length, 'sitemap must list pages').toBeGreaterThan(100);

    // 2) Walk every page (parallel); collect resolved internal targets → sample referrer.
    const targets = new Map(); // localURL -> referrer(canonical)
    const addTarget = (localURL, ref) => { if (!targets.has(localURL)) targets.set(localURL, ref); };
    const brokenPages = [];
    const host = new URL(site.canonical).host;

    await mapPool(pages, async (canonicalPage) => {
      const { status, body } = await get(canonicalToBase(canonicalPage, site), true);
      if (status >= 400 || status === 0) { brokenPages.push(`${status}  ${canonicalPage}  (sitemap page)`); return; }

      // 2a) every <a href>, resolved relative-aware against the CANONICAL page URL.
      for (const m of body.matchAll(HREF_RE)) {
        const raw = m[1].trim();
        if (!raw || raw.startsWith('#') || /^(mailto:|tel:|javascript:|data:)/i.test(raw)) continue;
        let abs;
        try { abs = new URL(raw, canonicalPage); } catch { continue; }
        if (abs.protocol !== 'http:' && abs.protocol !== 'https:') continue;
        if (abs.host !== host) continue; // internal only
        abs.hash = '';
        addTarget(canonicalToBase(abs.toString(), site), canonicalPage);
      }

      // 2b) JS language-switcher targets (OD_PAGE / MV_PAGE .paths) — invisible to href crawling.
      const scope = body.includes('OD_PAGE') || body.includes('MV_PAGE') ? body : '';
      for (const m of scope.matchAll(PATHMAP_RE)) {
        addTarget(canonicalToBase(site.canonical + m[2], site), canonicalPage);
      }
    });

    // 3) Every downloadable PDF for every language (linked via JS popup on MV).
    for (const doc of site.pdfs) {
      for (const L of PDF_LANGS) {
        addTarget(`${site.base}/downloads/${doc}_${L}.pdf`, `${site.canonical}/ (downloads)`);
      }
    }

    // 4) Check every unique internal target (parallel); collect the broken ones.
    const broken = [];
    await mapPool([...targets.keys()], async (url) => {
      const { status } = await get(url, false);
      if (status >= 400 || status === 0) broken.push(`${status}  ${url}   (referrer: ${targets.get(url)})`);
    });

    const allBroken = [...brokenPages, ...broken];
    expect(
      allBroken,
      `Broken internal links on ${site.key} (${allBroken.length}):\n` + allBroken.join('\n'),
    ).toEqual([]);
  });
}
