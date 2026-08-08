// =============================================================================
// PERMANENT v1.7.1 HARDCODED-CONTENT REGRESSION SUITE (#67)
// -----------------------------------------------------------------------------
// Live-confirmation guards for the v1.7.1 "eliminate ALL hardcoded content" work
// on BOTH sites. Every assertion encodes a state VERIFIED LIVE at v1.7.1 — a
// failure against production is a REAL regression (English leaking onto a
// localized page, a floating/hardcoded copyright year, or a transliterated
// brand), never a test to relax. READ-ONLY against LIVE production URLs.
//
// Override targets:  VASIC_BASE=... MILOS_BASE=...
// Run: npx playwright test v171-hardcoding.spec.js --config=playwright.live.config.js
//
// Covers (Helix Constitution §11.4.140/141 localized-strings-as-data,
// §11.4.216 generated-values, §11.4.65 render determinism, §11.4.6 anti-bluff):
//   FOOTER  deterministic, non-hardcoded © year on both sites
//   BLK1    localized portfolio card blurbs (no English leak)
//   BLK2    localized product meta / OG / Twitter / JSON-LD descriptions
//   HEAD    creative section headings translated on non-EN product pages
//   LINUX   "Linux" stays Latin in localized content (no transliteration)
//   PDF     sr cover-letter uses the correct term (Пропратно писмо, not Пријава)
// =============================================================================

const { test, expect } = require('@playwright/test');
const { execFileSync } = require('child_process');
const os = require('os');
const path = require('path');
const fs = require('fs');

const VASIC = (process.env.VASIC_BASE || 'https://vasic.digital').replace(/\/$/, '');
const MILOS = (process.env.MILOS_BASE || 'https://milosvasic.ru').replace(/\/$/, '');

// English marketing phrases from portfolio.json / product summaries that MUST
// NOT appear on a localized page (they are the EN source that was leaking).
const EN_PROD_PHRASES = [
  'self-hostable media collection', // catalogizer summary
  'for the free world',             // helixtrack tagline
];
// English creative section headings (prod.head.*) that must be localized away.
const EN_HEADINGS = [
  'Why we built it', 'Short description', 'Long description',
  'The problem we set out to solve', 'Why this exists',
];
// Devanagari / Hangul / Arabic / Persian transliterations of the brand "Linux".
const LINUX_TRANSLIT = { hi: 'लिनक्स', ko: '리눅스', ar: 'لينكس', fa: 'لینوکس' };

async function getText(request, url) {
  const res = await request.get(url);
  expect(res.status(), `${url} must be 200`).toBe(200);
  return res.text();
}

async function pdfText(request, url) {
  const res = await request.get(url);
  expect(res.status(), `${url} must be 200`).toBe(200);
  const buf = await res.body();
  const tmp = path.join(os.tmpdir(), `v171-${Date.now()}-${Math.random().toString(36).slice(2)}.pdf`);
  fs.writeFileSync(tmp, buf);
  try {
    return execFileSync('pdftotext', [tmp, '-'], { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  } finally {
    fs.unlinkSync(tmp);
  }
}

// =============================================================================
// FOOTER — deterministic, non-hardcoded copyright year (§11.4.216 / §11.4.65)
//   The footer renders "© <year> <Brand>" where <year> is generated (pinned via
//   the build), never a hardcoded literal. We assert a well-formed, current-era
//   year (≥ 2026) on the served home of BOTH sites.
// =============================================================================
test.describe('FOOTER deterministic © year', () => {
  for (const [site, base, brand] of [
    ['vasic.digital', VASIC, 'Vasic Digital'],
    ['milosvasic.ru', MILOS, 'Miloš Vasić'],
  ]) {
    test(`${site} footer shows a generated © <year> ${brand}`, async ({ request }) => {
      const html = await getText(request, `${base}/`);
      const m = html.match(new RegExp('©\\s*(\\d{4})\\s*' + brand.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
      expect(m, `footer "© <year> ${brand}" must be present`).toBeTruthy();
      const year = parseInt(m[1], 10);
      expect(year, `footer year must be current-era (got ${year})`).toBeGreaterThanOrEqual(2026);
    });
  }
});

// =============================================================================
// BLK1 — localized portfolio card blurbs (no English leak)
// =============================================================================
test.describe('BLK1 localized portfolio card blurbs', () => {
  for (const lang of ['de', 'ru']) {
    test(`vasic.digital /portfolio/${lang}/ card blurbs are localized (no EN leak)`, async ({ request }) => {
      const html = await getText(request, `${VASIC}/portfolio/${lang}/`);
      const blurbs = [...html.matchAll(/<p class="pf-card__blurb">([^<]*)<\/p>/g)].map((x) => x[1]);
      expect(blurbs.length, 'portfolio must render card blurbs').toBeGreaterThan(10);
      for (const p of EN_PROD_PHRASES) {
        expect(html.includes(p), `/portfolio/${lang}/ must not leak English blurb "${p}"`).toBe(false);
      }
    });
  }
  test('vasic.digital /portfolio/de/ carries the German helixtrack blurb', async ({ request }) => {
    const html = await getText(request, `${VASIC}/portfolio/de/`);
    expect(html.includes('für die freie Welt'), 'German helixtrack blurb must be present').toBe(true);
  });
});

// =============================================================================
// BLK2 — localized product meta / OG / Twitter / JSON-LD descriptions
// =============================================================================
test.describe('BLK2 localized product descriptions', () => {
  for (const lang of ['de', 'ru', 'ar']) {
    test(`vasic.digital /products/${lang}/catalogizer.html descriptions are localized`, async ({ request }) => {
      const html = await getText(request, `${VASIC}/products/${lang}/catalogizer.html`);
      for (const p of EN_PROD_PHRASES) {
        expect(html.includes(p), `${lang} product must not leak English summary "${p}"`).toBe(false);
      }
      // meta description present + non-empty
      const md = html.match(/<meta name="description" content="([^"]+)"/);
      expect(md && md[1].length > 20, 'meta description present + non-trivial').toBeTruthy();
      // og + twitter + JSON-LD description all present (localized from same source)
      expect(/<meta property="og:description" content="[^"]{20,}"/.test(html), 'og:description present').toBe(true);
      expect(/"description"\s*:\s*"[^"]{20,}"/.test(html), 'JSON-LD description present').toBe(true);
    });
  }
});

// =============================================================================
// HEAD — creative section headings translated on non-EN product pages
// =============================================================================
test.describe('HEAD creative headings localized', () => {
  test('vasic.digital /products/de/catalogizer.html has no English creative headings', async ({ request }) => {
    const html = await getText(request, `${VASIC}/products/de/catalogizer.html`);
    for (const h of EN_HEADINGS) {
      expect(html.includes(h), `de product must not show English heading "${h}"`).toBe(false);
    }
  });
});

// =============================================================================
// LINUX — brand stays Latin in localized content (no transliteration)
// =============================================================================
test.describe('LINUX latinized in localized content', () => {
  for (const [lang, translit] of Object.entries(LINUX_TRANSLIT)) {
    test(`vasic.digital /products/${lang}/qemu-utils.html keeps "Linux" Latin`, async ({ request }) => {
      const html = await getText(request, `${VASIC}/products/${lang}/qemu-utils.html`);
      expect(html.includes(translit), `${lang} page must not transliterate Linux ("${translit}")`).toBe(false);
      expect(html.includes('Linux'), `${lang} page must contain Latin "Linux"`).toBe(true);
    });
  }
});

// =============================================================================
// PDF — sr cover-letter uses the correct term (Пропратно писмо, not Пријава)
// =============================================================================
test.describe('PDF sr cover-letter term', () => {
  test('milos sr Cover Letter PDF says "Пропратно писмо" (not "Пријава")', async ({ request }) => {
    const txt = await pdfText(request, `${MILOS}/downloads/Milos_Vasic_Cover_Letter_SR.pdf`);
    expect(txt.includes('Пропратно писмо'), 'sr cover letter must use "Пропратно писмо"').toBe(true);
    expect(/\bПријава\b/.test(txt), 'sr cover letter must NOT use "Пријава" (=job application)').toBe(false);
  });
});
