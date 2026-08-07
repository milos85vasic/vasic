// =============================================================================
// PERMANENT v1.7.0 SIX-FIX REGRESSION SUITE
// -----------------------------------------------------------------------------
// Live-confirmation guards for the SIX fixes shipped in v1.7.0 of BOTH sites.
// Every assertion below encodes a state VERIFIED LIVE at v1.7.0 — if one fails
// against production that is a REAL regression (or an upstream change), never a
// test to relax. Runs READ-ONLY against LIVE production URLs by default:
//     vasic.digital   → MACHINA re-style (Bricolage display font)
//     milosvasic.ru   → TERMINAL BRUTALIST re-style (Anton display font)
//
// Override targets (e.g. staging) with env vars:
//     VASIC_BASE=https://staging.vasic.digital  MILOS_BASE=...
//
// Run:  npx playwright test v170-fixes.spec.js --config=playwright.live.config.js
//
// The SIX fixes (Helix Constitution §11.4.237 localization mandate applies to
// #62 / #63 / #65):
//   #62  Serbian Cyrillic everywhere        — /sr/ prose + sr PDFs are Cyrillic
//   #63  Language switcher actually switches — 15-path map, click navigates+relangs
//   #64  Tall modal/dialog scrolls          — download language list is reachable
//   #65  PDFs fully localized               — no EN chrome leak, correct script
//   #66  Content never flush to edge        — safe-area-aware gutters, padding>0
//   re-style intact                         — Bricolage (vasic) / Anton (milos)
// =============================================================================

const { test, expect } = require('@playwright/test');
const { execFileSync } = require('child_process');
const os = require('os');
const path = require('path');
const fs = require('fs');

const VASIC = (process.env.VASIC_BASE || 'https://vasic.digital').replace(/\/$/, '');
const MILOS = (process.env.MILOS_BASE || 'https://milosvasic.ru').replace(/\/$/, '');

// --- script detectors ---------------------------------------------------------
const CYRILLIC = /\p{Script=Cyrillic}/gu;
const ARABIC = /\p{Script=Arabic}/gu;
const CJK = /\p{Script=Han}/gu;
const LATIN = /\p{Script=Latin}/gu;
const ANY_LETTER = /\p{L}/gu;

// English chrome strings that MUST NOT leak into a non-EN PDF (BUG #65).
const EN_CHROME = [
  'Selected architecture', 'Curriculum Vitae', 'Cover Letter',
  'Engineering since', 'Repository fleet',
];
// English stop/sentence words used to detect EN-sentence leakage in localized
// HTML prose. Serbian Cyrillic prose has ~0 of these; a raw-EN leak has dozens.
// Short glossary/brand Latin tokens (Anthropic, OpenAI, GitHub, "JSON-lines
// over stdio") are allowed — hence a small non-zero tolerance, not a hard 0.
const EN_STOPWORDS = [
  'the', 'and', 'with', 'from', 'your', 'our', 'are', 'that', 'this', 'for',
  'you', 'which', 'was', 'were', 'have', 'has', 'been', 'their', 'they', 'when',
  'while', 'into', 'than', 'then', 'after', 'before', 'because', 'through',
  'built', 'trusted', 'engineering', 'since', 'repository', 'fleet', 'selected',
  'architecture',
];
const EN_STOPWORD_RE = new RegExp('\\b(' + EN_STOPWORDS.join('|') + ')\\b', 'gi');

/** ratio of `pat` matches to all letters (any script) in `text`. */
function scriptRatio(text, pat) {
  const letters = (text.match(ANY_LETTER) || []).length;
  if (!letters) return 0;
  return (text.match(pat) || []).length / letters;
}

/** visible body prose with script/style/code stripped and URLs/domains removed. */
async function bodyProse(page) {
  const raw = await page.evaluate(() => {
    const c = document.body.cloneNode(true);
    c.querySelectorAll('script,style,noscript,code,pre').forEach((e) => e.remove());
    return c.innerText;
  });
  return raw
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/[\w.-]+\.[a-z]{2,}(\/\S*)?/gi, ' '); // bare domains / paths
}

/** download a URL to a temp file and return its pdftotext output (empty on any failure). */
async function pdfText(request, url) {
  const res = await request.get(url);
  expect(res.status(), `${url} must be 200`).toBe(200);
  const buf = await res.body();
  const tmp = path.join(os.tmpdir(), `v170-${Date.now()}-${Math.random().toString(36).slice(2)}.pdf`);
  fs.writeFileSync(tmp, buf);
  try {
    return execFileSync('pdftotext', [tmp, '-'], { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  } finally {
    fs.unlinkSync(tmp);
  }
}

// =============================================================================
// #62  SERBIAN CYRILLIC EVERYWHERE (§11.4.237)
//   milos + vasic /sr/ home BODY prose Cyrillic ratio ≥ 0.7; <html lang="sr">;
//   no English-sentence leakage; sr CV PDF pdftotext Cyrillic ratio ≥ 0.6.
// =============================================================================
test.describe('#62 Serbian Cyrillic everywhere', () => {
  for (const [site, base] of [['vasic.digital', VASIC], ['milosvasic.ru', MILOS]]) {
    test(`${site} /sr/ home is Serbian Cyrillic (lang + prose ratio + no EN leak)`, async ({ page }) => {
      const resp = await page.goto(`${base}/sr/`, { waitUntil: 'networkidle' });
      expect(resp.status(), '/sr/ must load').toBeLessThan(400);

      expect(await page.locator('html').getAttribute('lang'), 'html lang must be sr').toBe('sr');

      const prose = await bodyProse(page);
      const letters = (prose.match(ANY_LETTER) || []).length;
      expect(letters, 'must have meaningful body prose').toBeGreaterThan(500);

      const cyr = scriptRatio(prose, CYRILLIC);
      expect(cyr, `body prose Cyrillic ratio must be ≥ 0.7 (got ${cyr.toFixed(3)})`).toBeGreaterThanOrEqual(0.7);

      // English-sentence leakage: glossary/brand Latin tokens are allowed, but a
      // raw-EN leak lights up dozens of stopwords. ≤ 5 keeps glossary, kills leak.
      const enHits = (prose.match(EN_STOPWORD_RE) || []).length;
      expect(enHits, `English-sentence leakage into /sr/ (stopword hits=${enHits}; glossary tolerance=5)`)
        .toBeLessThanOrEqual(5);
    });
  }

  test('milos sr CV PDF text is Cyrillic (ratio ≥ 0.6)', async ({ request }) => {
    const txt = await pdfText(request, `${MILOS}/downloads/Milos_Vasic_CV_SR.pdf`);
    const cyr = scriptRatio(txt, CYRILLIC);
    expect(cyr, `CV_SR.pdf Cyrillic ratio must be ≥ 0.6 (got ${cyr.toFixed(3)})`).toBeGreaterThanOrEqual(0.6);
    for (const s of EN_CHROME) {
      expect(txt.includes(s), `CV_SR.pdf must not contain EN chrome string "${s}"`).toBe(false);
    }
  });
});

// =============================================================================
// #63  LANGUAGE SWITCHER ACTUALLY SWITCHES (§11.4.237)
//   Served HTML exposes the page-path map (milos MV_PAGE / vasic OD_PAGE) with
//   15 localized paths; every localized product target resolves 200; and the
//   on-page switcher, when clicked, NAVIGATES and re-langs the document — on
//   BOTH a product page AND the portfolio page, on BOTH sites.
// =============================================================================
const SWITCHER = [
  {
    site: 'vasic.digital', base: VASIC, glob: 'OD_PAGE',
    btn: '#od-lang-btn', item: (c) => `#od-lang-menu button[data-lang="${c}"]`,
    product: '/products/helixtrack.html', portfolio: '/portfolio/',
  },
  {
    site: 'milosvasic.ru', base: MILOS, glob: 'MV_PAGE',
    btn: '#lang-btn', item: (c) => `#lang-menu button[data-code="${c}"]`,
    product: '/products/catalogizer.html', portfolio: '/portfolio/',
  },
];

test.describe('#63 Language switcher actually switches', () => {
  for (const s of SWITCHER) {
    test(`${s.site} product served HTML carries ${s.glob} with 15 paths + all targets 200`, async ({ request }) => {
      const res = await request.get(s.base + s.product);
      expect(res.status(), 'product page must be 200').toBe(200);
      const html = await res.text();

      const m = html.match(new RegExp(`${s.glob}\\s*=\\s*(\\{[\\s\\S]*?\\})\\s*;`));
      expect(m, `${s.glob} global must be embedded in served HTML`).toBeTruthy();
      const data = JSON.parse(m[1]);
      const paths = data.paths || {};
      const codes = Object.keys(paths);
      expect(codes.length, `${s.glob}.paths must list 15 languages (got ${codes.length})`).toBe(15);
      expect(codes, 'must include en + sr').toEqual(expect.arrayContaining(['en', 'sr', 'de', 'ru', 'ar', 'zh']));

      // Every localized target must resolve 200 (no dead switcher entries).
      for (const code of codes) {
        const target = new URL(paths[code], s.base + '/').toString();
        const r = await request.get(target);
        expect(r.status(), `switcher target must resolve 200: ${code} → ${target}`).toBe(200);
      }
    });

    test(`${s.site} portfolio served HTML carries ${s.glob} with 15 paths`, async ({ request }) => {
      const res = await request.get(s.base + s.portfolio);
      expect(res.status(), 'portfolio page must be 200').toBe(200);
      const html = await res.text();
      const m = html.match(new RegExp(`${s.glob}\\s*=\\s*(\\{[\\s\\S]*?\\})\\s*;`));
      expect(m, `${s.glob} global must be embedded in served portfolio HTML`).toBeTruthy();
      const codes = Object.keys(JSON.parse(m[1]).paths || {});
      expect(codes.length, `portfolio ${s.glob}.paths must list 15 languages (got ${codes.length})`).toBe(15);
    });

    for (const [label, pathKey, code] of [['product', 'product', 'de'], ['portfolio', 'portfolio', 'ru']]) {
      test(`${s.site} ${label}: clicking switcher → ${code} navigates and re-langs`, async ({ page }) => {
        await page.goto(s.base + s[pathKey], { waitUntil: 'networkidle' });
        const before = await page.locator('html').getAttribute('lang');
        expect(before, 'source page starts in EN').toBe('en');

        await page.locator(s.btn).click();
        const opt = page.locator(s.item(code));
        await expect(opt, `switcher must offer a ${code} option`).toHaveCount(1);
        await opt.click();

        // The switcher must actually take us to the localized doc. It performs a
        // full navigation, so wait on the URL landing at the /<code>/ path (robust
        // across the document swap), THEN assert the new document is re-langed.
        await page.waitForURL(new RegExp(`/${code}/`), { timeout: 15000 });
        await expect(page.locator('html'), `document must re-lang to ${code}`).toHaveAttribute('lang', code);
      });
    }
  }
});

// =============================================================================
// #64  TALL MODAL / DIALOG SCROLLS
//   CSS assertion: milos style.css gives .dl-langs overflow-y:auto AND .dl-card
//   a bounded max-height; vasic overlays.css gives the dialog panel/menu
//   max-height + overflow-y. PLUS a live check: at 380×640 the milos download-CV
//   language list overflows AND its last row is reachable by scroll.
// =============================================================================
/** collapse whitespace so multi-line CSS rules match a single-line probe. */
function flat(css) { return css.replace(/\s+/g, ' '); }

test.describe('#64 Tall modal/dialog scrolls', () => {
  test('milos style.css: .dl-langs scrolls + .dl-card is height-bounded', async ({ request }) => {
    const res = await request.get(`${MILOS}/assets/css/style.css`);
    expect(res.status()).toBe(200);
    const css = flat(await res.text());
    expect(/\.dl-langs\s*\{[^}]*overflow-y:\s*auto/.test(css), '.dl-langs must be overflow-y:auto').toBe(true);
    expect(/\.dl-card\s*\{[^}]*max-height:\s*min\(/.test(css), '.dl-card must have a bounded max-height').toBe(true);
  });

  test('vasic overlays.css: dialog panel + menus are height-bounded and scroll', async ({ request }) => {
    const res = await request.get(`${VASIC}/assets/od/overlays.css`);
    expect(res.status()).toBe(200);
    const css = flat(await res.text());
    expect(/\.od-dialog__panel\s*\{[^}]*max-height:\s*min\([^}]*overflow-y:\s*auto/.test(css),
      '.od-dialog__panel must have max-height + overflow-y:auto').toBe(true);
    expect(/overflow-y:\s*auto/.test(css) && /max-height:\s*min\(70/.test(css),
      'floating menus (.od-menu/.od-lang__menu) must be bounded + scroll').toBe(true);
  });

  test('milos download-CV language list is reachable by scroll @380×640', async ({ page }) => {
    await page.setViewportSize({ width: 380, height: 640 });
    await page.goto(`${MILOS}/`, { waitUntil: 'networkidle' });
    await page.locator('button[data-dl="cv"]').first().click();

    const modal = page.locator('#dl-modal');
    await expect(modal).toBeVisible();
    const list = modal.locator('.dl-langs');
    const rows = modal.locator('.dl-lang');
    await expect(rows, 'the CV modal offers the full 15-language list').toHaveCount(15);

    const metrics = await list.evaluate((el) => ({
      overflowY: getComputedStyle(el).overflowY,
      scrollable: el.scrollHeight > el.clientHeight + 1,
    }));
    expect(metrics.overflowY, '.dl-langs must be overflow-y:auto/scroll').toMatch(/auto|scroll/);
    expect(metrics.scrollable, 'list must actually overflow its bounded height at 640px').toBe(true);

    // The last language row must be brought fully into view by scrolling.
    const last = rows.last();
    await last.scrollIntoViewIfNeeded();
    const reachable = await last.evaluate((el) => {
      const r = el.getBoundingClientRect();
      return r.top >= 0 && r.bottom <= window.innerHeight + 1;
    });
    expect(reachable, 'last language row must be reachable by scroll (BUG #64)').toBe(true);
  });
});

// =============================================================================
// #65  PDFs FULLY LOCALIZED (§11.4.237)
//   For 4 sample langs (sr/de/ar/zh): served CV (milos) + Portfolio (both sites)
//   have ZERO English chrome-string leakage AND carry the correct target script.
//   DE is Latin-script, so its check is "Latin-dominant + no Cyrillic/Arabic/CJK".
// =============================================================================
const PDF_LANGS = [
  { code: 'sr', label: 'Serbian', assert: (t) => scriptRatio(t, CYRILLIC) >= 0.6, why: 'Cyrillic ≥ 0.6' },
  { code: 'ar', label: 'Arabic', assert: (t) => scriptRatio(t, ARABIC) >= 0.6, why: 'Arabic ≥ 0.6' },
  { code: 'zh', label: 'Chinese', assert: (t) => scriptRatio(t, CJK) >= 0.3, why: 'Han ≥ 0.3 (CJK is compact)' },
  {
    code: 'de', label: 'German',
    assert: (t) => scriptRatio(t, LATIN) >= 0.8 && scriptRatio(t, CYRILLIC) < 0.02
      && scriptRatio(t, ARABIC) < 0.02 && scriptRatio(t, CJK) < 0.02,
    why: 'Latin-dominant, no foreign script',
  },
];

const PDF_DOCS = [
  { site: 'milosvasic.ru', base: MILOS, name: (c) => `Milos_Vasic_CV_${c.toUpperCase()}.pdf`, doc: 'CV' },
  { site: 'milosvasic.ru', base: MILOS, name: (c) => `Portfolio_${c.toUpperCase()}.pdf`, doc: 'Portfolio' },
  { site: 'vasic.digital', base: VASIC, name: (c) => `Portfolio_${c.toUpperCase()}.pdf`, doc: 'Portfolio' },
];

test.describe('#65 PDFs fully localized', () => {
  for (const d of PDF_DOCS) {
    for (const l of PDF_LANGS) {
      test(`${d.site} ${d.doc} ${l.code}: no EN chrome + ${l.why}`, async ({ request }) => {
        const txt = await pdfText(request, `${d.base}/downloads/${d.name(l.code)}`);
        expect(txt.length, 'PDF must extract to non-trivial text').toBeGreaterThan(200);

        for (const s of EN_CHROME) {
          expect(txt.includes(s), `${d.name(l.code)} must not leak EN chrome "${s}"`).toBe(false);
        }
        expect(l.assert(txt), `${d.name(l.code)} must be in the ${l.label} target script (${l.why})`).toBe(true);
      });
    }
  }
});

// =============================================================================
// #66  CONTENT NEVER FLUSH TO THE EDGE
//   Served brand CSS carries env(safe-area-inset-*) gutters; and on both home
//   pages, at 375 and 1280, the main content bands keep a real horizontal gutter
//   (computed padding-inline ≥ 16px — never flush to the viewport edge).
// =============================================================================
const EDGE = [
  { site: 'vasic.digital', base: VASIC, cssUrl: `${VASIC}/assets/od/vasic-digital.css`, sel: '.od-hero, .od-section, .od-header' },
  { site: 'milosvasic.ru', base: MILOS, cssUrl: `${MILOS}/assets/css/style.css`, sel: '.wrap' },
];

test.describe('#66 Content never flush to edge (safe-area gutters)', () => {
  for (const e of EDGE) {
    test(`${e.site} brand CSS declares env(safe-area-inset-*) gutters`, async ({ request }) => {
      const res = await request.get(e.cssUrl);
      expect(res.status()).toBe(200);
      const css = await res.text();
      expect(/env\(\s*safe-area-inset-left/.test(css), 'must use safe-area-inset-left').toBe(true);
      expect(/env\(\s*safe-area-inset-right/.test(css), 'must use safe-area-inset-right').toBe(true);
    });

    for (const width of [375, 1280]) {
      test(`${e.site} content keeps a gutter @${width} (padding-inline ≥ 16px)`, async ({ page }) => {
        await page.setViewportSize({ width, height: 900 });
        await page.goto(`${e.base}/`, { waitUntil: 'domcontentloaded' });
        const pads = await page.evaluate((sel) => {
          return [...document.querySelectorAll(sel)].slice(0, 4).map((el) => {
            const cs = getComputedStyle(el);
            return { pl: parseFloat(cs.paddingLeft) || 0, pr: parseFloat(cs.paddingRight) || 0 };
          });
        }, e.sel);
        expect(pads.length, `must find content bands (${e.sel})`).toBeGreaterThan(0);
        for (const p of pads) {
          expect(p.pl, `left gutter must be ≥ 16px @${width} (got ${p.pl})`).toBeGreaterThanOrEqual(16);
          expect(p.pr, `right gutter must be ≥ 16px @${width} (got ${p.pr})`).toBeGreaterThanOrEqual(16);
        }
      });
    }
  }
});

// =============================================================================
// RE-STYLE INTACT — the v1.6.1 display re-style must survive the v1.7.0 work:
//   vasic served CSS declares "Bricolage"; milos served CSS declares "Anton".
// =============================================================================
test.describe('Re-style intact (display font not reverted)', () => {
  for (const [site, cssUrl, font] of [
    ['vasic.digital', `${VASIC}/assets/od/vasic-digital.css`, 'Bricolage'],
    ['milosvasic.ru', `${MILOS}/assets/css/style.css`, 'Anton'],
  ]) {
    test(`${site} served CSS still declares "${font}"`, async ({ request }) => {
      const res = await request.get(cssUrl);
      expect(res.status(), `${cssUrl} must be 200`).toBe(200);
      expect((await res.text()).includes(font), `${font} must remain in served CSS`).toBe(true);
    });
  }
});
