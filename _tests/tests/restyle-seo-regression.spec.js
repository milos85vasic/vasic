// =============================================================================
// PERMANENT v1.6.1 SHIPPED-STATE REGRESSION SUITE
// -----------------------------------------------------------------------------
// Guards the v1.6.1 production state of BOTH sites against silent regression.
// Runs READ-ONLY against LIVE production URLs by default:
//     vasic.digital  → MACHINA re-style (Bricolage display font)
//     milosvasic.ru  → TERMINAL BRUTALIST re-style (Anton display font)
//
// Override targets for staging with env vars:
//     VASIC_BASE=https://staging.vasic.digital  MILOS_BASE=...
//
// Run:  npx playwright test --config=playwright.live.config.js
//
// Every assertion below encodes a fix/feature verified live at v1.6.1. If any
// fails, that is a REAL regression (or an upstream change), not a test to relax.
//
// Covers (per task):
//   1. Re-style present (served CSS carries the display font + woff2 200)
//   2. Self-referential canonical on localized pages (+ no double-slash)
//   3. Sitemap <lastmod> on every <url>, loc count, no // in loc
//   4. D1/D2 localized od CSS/JS assets all resolve 200
//   5. Localization: <html lang>/dir + no raw English hero leak
//   6. a11y: axe-core WCAG 2.2 AA → 0 serious/critical
//   7. Interactive behavior: hamburger, back-to-top, console, no h-overflow
//   8. milos #43 SEO: no empty twitter:site @, JSON-LD name diacritics
// =============================================================================

const { test, expect } = require('@playwright/test');
const { AxeBuilder } = require('@axe-core/playwright');

const VASIC = (process.env.VASIC_BASE || 'https://vasic.digital').replace(/\/$/, '');
const MILOS = (process.env.MILOS_BASE || 'https://milosvasic.ru').replace(/\/$/, '');

/** origin (scheme+host) of a base URL, used to build expected canonicals. */
function origin(base) { return new URL(base + '/').origin; }

/** true if a URL, after its scheme, contains a `//` (a path double-slash defect). */
function hasPathDoubleSlash(u) {
  const afterScheme = u.replace(/^https?:\/\//, '');
  return afterScheme.includes('//');
}

// -----------------------------------------------------------------------------
// 1. RE-STYLE PRESENT — the shipped display font must be in the served CSS and
//    its woff2 must resolve. Guards the MACHINA / BRUTALIST re-style from revert.
// -----------------------------------------------------------------------------
const RESTYLE = [
  {
    site: 'vasic.digital', base: VASIC, font: 'Bricolage',
    cssUrl: `${VASIC}/assets/od/vasic-digital.css`,
    woff2: `${VASIC}/assets/od/display/bricolage-800-latin.woff2`,
  },
  {
    site: 'milosvasic.ru', base: MILOS, font: 'Anton',
    cssUrl: `${MILOS}/assets/css/style.css`,
    woff2: `${MILOS}/assets/od/anton/anton-latin-400.woff2`,
  },
];

test.describe('1. Re-style present (display font not silently reverted)', () => {
  for (const r of RESTYLE) {
    test(`${r.site}: served CSS declares "${r.font}"`, async ({ request }) => {
      const res = await request.get(r.cssUrl);
      expect(res.status(), `${r.cssUrl} must be 200`).toBe(200);
      const css = await res.text();
      expect(css, `${r.font} must appear in served CSS`).toContain(r.font);
    });

    test(`${r.site}: display woff2 returns 200`, async ({ request }) => {
      const res = await request.get(r.woff2);
      expect(res.status(), `${r.woff2} must be 200`).toBe(200);
      const ct = (res.headers()['content-type'] || '').toLowerCase();
      // font/woff2 or application/octet-stream are both acceptable in the wild.
      expect(ct.includes('woff2') || ct.includes('font') || ct.includes('octet-stream'),
        `unexpected content-type for font: ${ct}`).toBeTruthy();
    });
  }
});

// -----------------------------------------------------------------------------
// 2. SELF-REFERENTIAL CANONICAL — localized pages must point at THEMSELVES,
//    not the EN original; EN home canonical = origin root; no double-slash.
// -----------------------------------------------------------------------------
const CANONICAL = [
  { base: VASIC, path: '/',                          selfRef: true },  // EN home = root
  { base: VASIC, path: '/ru/',                       selfRef: true },
  { base: VASIC, path: '/de/',                       selfRef: true },
  { base: VASIC, path: '/products/ru/helixtrack.html', selfRef: true },
  { base: VASIC, path: '/portfolio/ru/',             selfRef: true },
  { base: MILOS, path: '/',                          selfRef: true },
  { base: MILOS, path: '/ru/',                       selfRef: true },
];

test.describe('2. Self-referential canonical (localized ≠ EN)', () => {
  for (const c of CANONICAL) {
    test(`${c.base}${c.path} canonical is self-referential`, async ({ page }) => {
      const resp = await page.goto(c.base + c.path, { waitUntil: 'domcontentloaded' });
      expect(resp.status(), `${c.path} must load`).toBeLessThan(400);

      const canon = await page.locator('head link[rel="canonical"]').first().getAttribute('href');
      expect(canon, 'canonical must be present').toBeTruthy();

      const expected = origin(c.base) + c.path;
      expect(canon, `canonical must equal the page's own URL (${expected}), not the EN one`)
        .toBe(expected);
      expect(hasPathDoubleSlash(canon), `canonical must not contain a path double-slash: ${canon}`)
        .toBe(false);
    });
  }
});

// -----------------------------------------------------------------------------
// 3. SITEMAP <lastmod> — both sitemaps parse; every <url> carries <lastmod>;
//    loc count > 400; no path double-slash in any <loc>.
// -----------------------------------------------------------------------------
test.describe('3. Sitemap integrity (lastmod on every url)', () => {
  for (const base of [VASIC, MILOS]) {
    test(`${base}/sitemap.xml is complete`, async ({ request }) => {
      const res = await request.get(`${base}/sitemap.xml`);
      expect(res.status(), 'sitemap.xml must be 200').toBe(200);
      const xml = await res.text();

      const urlBlocks = xml.match(/<url>[\s\S]*?<\/url>/g) || [];
      const locs = [...xml.matchAll(/<loc>([\s\S]*?)<\/loc>/g)].map((m) => m[1].trim());

      expect(locs.length, 'sitemap must have > 400 <loc> entries').toBeGreaterThan(400);
      expect(urlBlocks.length, '<url> blocks must match <loc> count').toBe(locs.length);

      // Every <url> block must carry a <lastmod>.
      const missingLastmod = urlBlocks.filter((b) => !/<lastmod>[^<]+<\/lastmod>/.test(b));
      expect(missingLastmod.length, `every <url> must have a <lastmod> (missing: ${missingLastmod.length})`).toBe(0);

      // No path double-slash in any loc.
      const badLocs = locs.filter(hasPathDoubleSlash);
      expect(badLocs.length, `no <loc> may contain a path double-slash; offenders: ${badLocs.slice(0, 5).join(', ')}`).toBe(0);
    });
  }
});

// -----------------------------------------------------------------------------
// 4. D1/D2 LOCALIZED ASSETS — on a localized product + portfolio page, every
//    referenced OpenDesign CSS/JS (the ../../assets/od/* relative paths) must
//    resolve 200. Verified both by DOM-referenced fetch AND live network watch.
// -----------------------------------------------------------------------------
const OD_ASSET_PAGES = [
  { base: VASIC, path: '/products/ru/helixtrack.html', label: 'localized product' },
  { base: VASIC, path: '/portfolio/ru/',               label: 'localized portfolio' },
];

test.describe('4. D1/D2 localized od assets resolve 200', () => {
  for (const p of OD_ASSET_PAGES) {
    test(`${p.label} (${p.path}) — no 404 on od CSS/JS`, async ({ page }) => {
      // Watch live responses for any od asset that errors during the load.
      const failed = [];
      page.on('response', (resp) => {
        const u = resp.url();
        if (/\/assets\/od\/.*\.(css|js|woff2)(\?|$)/.test(u) && resp.status() >= 400) {
          failed.push(`${resp.status()} ${u}`);
        }
      });

      const resp = await page.goto(p.base + p.path, { waitUntil: 'networkidle' });
      expect(resp.status(), 'page must load').toBeLessThan(400);

      // Collect every DOM-referenced od CSS/JS, resolved to absolute URLs.
      const assetUrls = await page.evaluate(() => {
        const out = new Set();
        document.querySelectorAll('link[rel="stylesheet"][href]').forEach((l) => out.add(l.href));
        document.querySelectorAll('script[src]').forEach((s) => out.add(s.src));
        return [...out].filter((u) => u.includes('/assets/od/'));
      });
      expect(assetUrls.length, 'localized page must reference od assets').toBeGreaterThan(0);

      // Every referenced od asset must independently return 200.
      for (const u of assetUrls) {
        const r = await page.request.get(u);
        expect(r.status(), `od asset must resolve 200: ${u}`).toBe(200);
      }

      expect(failed, `no od asset may 404 during load:\n${failed.join('\n')}`).toEqual([]);
    });
  }
});

// -----------------------------------------------------------------------------
// 5. LOCALIZATION — sample 3 non-EN homes per site: <html lang>, dir (rtl for
//    ar/fa), and the hero must be in-language (no raw English hero leak).
// -----------------------------------------------------------------------------
const CYRILLIC = /[Ѐ-ӿ]/;
const ARABIC = /[؀-ۿ]/;

const L10N = [
  {
    site: 'vasic.digital', base: VASIC,
    heroSel: '[data-i18n="hero.title"]',
    enLeak: 'built to be trusted',
    langs: [
      { code: 'ru', dir: 'ltr', positive: (t) => CYRILLIC.test(t) },
      { code: 'de', dir: 'ltr', positive: (t) => /vertrauensw[üu]rdig/i.test(t) },
      { code: 'ar', dir: 'rtl', positive: (t) => ARABIC.test(t) },
    ],
  },
  {
    site: 'milosvasic.ru', base: MILOS,
    heroSel: '[data-i18n="mv2.hero.lede"]',
    enLeak: 'verifiable AI-development systems',
    langs: [
      { code: 'ru', dir: 'ltr', positive: (t) => CYRILLIC.test(t) },
      { code: 'de', dir: 'ltr', positive: (t) => /nachpr[üu]fbare|KI-Ingenieur/i.test(t) },
      { code: 'ar', dir: 'rtl', positive: (t) => ARABIC.test(t) },
    ],
  },
];

test.describe('5. Localization (lang/dir + no English hero leak)', () => {
  for (const s of L10N) {
    for (const l of s.langs) {
      test(`${s.site} /${l.code}/ is localized (${l.dir})`, async ({ page }) => {
        const resp = await page.goto(`${s.base}/${l.code}/`, { waitUntil: 'domcontentloaded' });
        expect(resp.status(), 'localized home must load').toBeLessThan(400);

        const html = page.locator('html');
        expect(await html.getAttribute('lang'), 'html lang').toBe(l.code);
        if (l.dir === 'rtl') {
          expect(await html.getAttribute('dir'), `${l.code} must be RTL`).toBe('rtl');
        }

        const hero = (await page.locator(s.heroSel).first().textContent() || '').trim();
        expect(hero.length, 'hero text must be present').toBeGreaterThan(0);
        expect(l.positive(hero), `hero must be in-language (${l.code}); got: ${hero.slice(0, 80)}`).toBeTruthy();
        expect(hero.toLowerCase().includes(s.enLeak.toLowerCase()),
          `raw English hero must not leak into ${l.code}`).toBe(false);
      });
    }
  }
});

// -----------------------------------------------------------------------------
// 6. ACCESSIBILITY — axe-core WCAG 2.2 AA on each site's EN home + one localized
//    home → 0 serious/critical violations. (heading-order + link-in-text-block
//    disabled to match the shipped, documented a11y baseline of the suite.)
// -----------------------------------------------------------------------------
const A11Y = [
  { name: 'vasic EN home',       url: `${VASIC}/` },
  { name: 'vasic RU home',       url: `${VASIC}/ru/` },
  { name: 'milos EN home',       url: `${MILOS}/` },
  { name: 'milos RU home',       url: `${MILOS}/ru/` },
];

test.describe('6. a11y (axe WCAG 2.2 AA, 0 serious/critical)', () => {
  for (const p of A11Y) {
    test(`${p.name} — 0 serious/critical`, async ({ page }) => {
      await page.goto(p.url, { waitUntil: 'networkidle' });
      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
        .disableRules(['heading-order', 'link-in-text-block'])
        .analyze();
      const serious = results.violations.filter((v) => v.impact === 'serious' || v.impact === 'critical');
      if (serious.length) {
        console.log(`AXE ${p.name}:`, JSON.stringify(serious.map((v) => ({
          id: v.id, impact: v.impact, help: v.help,
          nodes: v.nodes.slice(0, 5).map((n) => n.target),
        })), null, 2));
      }
      expect(serious, `${p.name} must have no serious/critical a11y violations`).toEqual([]);
    });
  }
});

// -----------------------------------------------------------------------------
// 7. INTERACTIVE BEHAVIOR — milos hamburger toggles aria-expanded ≤760px; both
//    sites reveal a back-to-top control on scroll; no console errors on load;
//    no horizontal overflow at 375 / 768 / 1280.
// -----------------------------------------------------------------------------
test.describe('7. Interactive behavior', () => {
  test('milos hamburger toggles aria-expanded (≤760px)', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 800 });
    await page.goto(`${MILOS}/`, { waitUntil: 'domcontentloaded' });
    const toggle = page.locator('#nav-toggle');
    await expect(toggle, 'hamburger must be visible at 375px').toBeVisible();
    expect(await toggle.getAttribute('aria-expanded'), 'starts collapsed').toBe('false');
    await toggle.click();
    await expect(toggle).toHaveAttribute('aria-expanded', 'true');
    await toggle.click();
    await expect(toggle).toHaveAttribute('aria-expanded', 'false');
  });

  for (const base of [VASIC, MILOS]) {
    test(`${base} back-to-top appears on scroll`, async ({ page }) => {
      await page.goto(`${base}/`, { waitUntil: 'networkidle' });
      const btn = page.locator('.od-to-top, [data-back-to-top], #back-to-top, .back-to-top').first();
      await expect(btn, 'a back-to-top control must exist').toHaveCount(1);
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      await page.waitForTimeout(600);
      const state = await btn.evaluate((el) => {
        const s = getComputedStyle(el);
        return { disp: s.display, vis: s.visibility, opacity: parseFloat(s.opacity), pos: s.position };
      });
      expect(state.disp, 'must not be display:none after scroll').not.toBe('none');
      expect(state.vis, 'must not be visibility:hidden after scroll').not.toBe('hidden');
      expect(state.opacity, 'must be revealed (opaque) after scroll').toBeGreaterThan(0.5);
      expect(['fixed', 'sticky'], 'must be a floating control').toContain(state.pos);
    });

    test(`${base} EN home has no console errors`, async ({ page }) => {
      const errors = [];
      page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('pageerror', (e) => errors.push(String(e)));
      await page.goto(`${base}/`, { waitUntil: 'networkidle' });
      await page.waitForTimeout(500);
      expect(errors, `console/page errors:\n${errors.join('\n')}`).toEqual([]);
    });

    for (const width of [375, 768, 1280]) {
      test(`${base} no horizontal overflow @${width}`, async ({ page }) => {
        await page.setViewportSize({ width, height: 900 });
        await page.goto(`${base}/`, { waitUntil: 'networkidle' });
        const overflow = await page.evaluate(() => {
          const doc = document.documentElement;
          return { scrollW: doc.scrollWidth, clientW: doc.clientWidth };
        });
        // 1px tolerance for sub-pixel rounding.
        expect(overflow.scrollW, `no horizontal overflow @${width} (scrollW=${overflow.scrollW}, clientW=${overflow.clientW})`)
          .toBeLessThanOrEqual(overflow.clientW + 1);
      });
    }
  }
});

// -----------------------------------------------------------------------------
// 8. milos #43 SEO FIXES — no twitter:site with an empty "@"; JSON-LD name
//    carries the correct diacritics ("Miloš Vasić").
// -----------------------------------------------------------------------------
test.describe('8. milos #43 SEO fixes', () => {
  test('milos home has no empty twitter:site @', async ({ page }) => {
    await page.goto(`${MILOS}/`, { waitUntil: 'domcontentloaded' });
    const loc = page.locator('head meta[name="twitter:site"]');
    const n = await loc.count();
    // Fix: the empty-@ tag was removed entirely, so the tag is expected to be
    // absent. If it is ever re-added it must carry a real non-empty handle —
    // never "" or a bare "@". (count() first: getAttribute on a zero-match
    // locator would block until timeout.)
    if (n > 0) {
      const twSite = (await loc.first().getAttribute('content') || '').trim();
      expect(twSite, 'twitter:site must not be empty or a bare @').not.toBe('');
      expect(twSite, 'twitter:site must not be a bare @').not.toBe('@');
    }
  });

  test('milos JSON-LD name === "Miloš Vasić" (diacritics intact)', async ({ page }) => {
    await page.goto(`${MILOS}/`, { waitUntil: 'domcontentloaded' });
    const blocks = await page.locator('script[type="application/ld+json"]').allTextContents();
    expect(blocks.length, 'must have JSON-LD').toBeGreaterThan(0);

    const names = [];
    const walk = (n) => {
      if (n == null) return;
      if (Array.isArray(n)) return n.forEach(walk);
      if (typeof n === 'object') {
        if (typeof n.name === 'string') names.push(n.name);
        Object.values(n).forEach(walk);
      }
    };
    for (const b of blocks) {
      let parsed;
      expect(() => { parsed = JSON.parse(b); }, 'JSON-LD must parse').not.toThrow();
      walk(parsed);
    }
    expect(names, 'a JSON-LD name must be the diacritic-correct "Miloš Vasić"').toContain('Miloš Vasić');
  });
});
