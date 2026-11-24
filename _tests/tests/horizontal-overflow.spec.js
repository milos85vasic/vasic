// No horizontal page scroll on any language home, at any phone/tablet width.
//
// Defect D2 (docs/qa/live-health/live-health-2026-11-24.md): on the live site
// /de/ at 320-414 px and /ru/ at 320-360 px scrolled sideways. Measured
// 2026-11-24: document.scrollWidth 454-464 vs clientWidth 320-414. The report
// blamed `.vd-hero__aurora` and `.od-to-top`; bisecting by hiding nodes showed
// neither is the cause (the aurora is clipped by `.vd-hero { overflow: hidden }`
// and `.od-to-top` is position:fixed). The cause was `h2.od-section__title`
// in #server-factory: the translated title contains U+2011 NON-BREAKING hyphens
// ("Infrastruktur‑Automatisierung"), so the word offers no break opportunity and
// overflowed its box at 800-weight display size. Fix: `overflow-wrap: break-word`
// on the title, in design-system/brand-vasic-digital/vasic-digital.css.
//
// The language list is DERIVED from the home page's own hreflang alternates, so
// a newly added language is covered without editing this file. A language that
// cannot be discovered is a failure, not a silent skip.
const { test, expect } = require('@playwright/test');
const { VD_BASE } = require('../env.js');

const WIDTHS = [320, 360, 390, 414, 768];

async function discoverLangs(request) {
  const res = await request.get(`${VD_BASE}/`);
  expect(res.status()).toBe(200);
  const html = await res.text();
  const langs = new Set();
  for (const m of html.matchAll(/<link[^>]+rel="alternate"[^>]*>/g)) {
    const h = /hreflang="([a-zA-Z-]+)"/.exec(m[0]);
    const href = /href="([^"]+)"/.exec(m[0]);
    if (!h || !href || h[1] === 'x-default') continue;
    const p = new URL(href[1], VD_BASE).pathname;
    const seg = p.split('/').filter(Boolean)[0];
    langs.add(seg && /^[a-z]{2,3}$/.test(seg) ? seg : '');
  }
  return [...langs].sort();
}

// Offenders worth naming in a failure message: elements whose box leaves the
// viewport and that no overflow-clipping ancestor already contains, plus text
// boxes whose content is wider than the box (the D2 shape: rect fits, text does not).
function offenders() {
  const vw = document.documentElement.clientWidth;
  const clipped = (e) => {
    for (let a = e.parentElement; a && a !== document.documentElement; a = a.parentElement) {
      if (getComputedStyle(a).overflowX !== 'visible' && a.getBoundingClientRect().right <= vw + 1) return true;
    }
    return false;
  };
  const out = [];
  document.querySelectorAll('body *').forEach((e) => {
    if (clipped(e)) return;
    const r = e.getBoundingClientRect();
    const boxOut = r.width > 0 && r.right > vw + 1;
    const textOut = e.scrollWidth > e.clientWidth + 1 && getComputedStyle(e).overflowX === 'visible' && e.clientWidth > 0;
    if (boxOut || textOut) out.push(`${e.tagName.toLowerCase()}.${String(e.className).slice(0, 40)} right=${Math.round(r.right)} scrollW=${e.scrollWidth} clientW=${e.clientWidth}`);
  });
  return out.slice(0, 8);
}

test.describe('vasic.digital: no horizontal overflow', () => {
  let langs;
  test.beforeAll(async ({ playwright }) => {
    const ctx = await playwright.request.newContext();
    try { langs = await discoverLangs(ctx); } finally { await ctx.dispose(); }
  });

  test('language discovery found the full set', () => {
    expect(langs.length).toBeGreaterThanOrEqual(15);
    expect(langs).toContain('');
    expect(langs).toContain('de');
    expect(langs).toContain('ru');
  });

  for (const w of WIDTHS) {
    test(`all language homes fit a ${w}px viewport`, async ({ browser }) => {
      const ctx = await browser.newContext({ viewport: { width: w, height: 800 } });
      const bad = [];
      try {
        for (const l of langs) {
          const page = await ctx.newPage();
          await page.goto(`${VD_BASE}/${l ? l + '/' : ''}`, { waitUntil: 'load' });
          const m = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
          if (m.sw > m.cw) bad.push(`/${l ? l + '/' : ''} scrollWidth ${m.sw} > clientWidth ${m.cw}: ${(await page.evaluate(offenders)).join(' | ')}`);
          await page.close();
        }
      } finally { await ctx.close(); }
      expect(bad, `horizontal overflow at ${w}px`).toEqual([]);
    });
  }
});
