/* Accessibility + WCAG 2.2 audit runner (READ-ONLY evidence gatherer).
   Serves the already-generated static HTML (started externally) and drives it
   with Playwright(chromium) + @axe-core/playwright. Produces:
     - axe-json/<target>.json         raw axe violations per target
     - data/contrast.json             measured WCAG contrast ratios (from axe + custom sampler)
     - data/checks.json               keyboard/focus/reduced-motion/landmark/alt findings
     - data/summary.json              aggregate counts

   No source, CSS, generator, or live-site files are modified. */
const path = require('path');
const fs = require('fs');
const { chromium } = require(path.join('/Volumes/T7/Projects/vasic/_tests/node_modules/playwright'));
const { AxeBuilder } = require(path.join('/Volumes/T7/Projects/vasic/_tests/node_modules/@axe-core/playwright'));

const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/a11y-audit';
const MV = 'http://localhost:8502';   // milosvasic.ru (Jekyll _site)
const VD = 'http://localhost:8501';   // vasic.digital

// theme storage keys differ per site
const THEME_KEY = { mv: 'mv-theme', vd: 'od-theme' };
const LANG_KEY  = { mv: 'mv-lang',  vd: 'vasic-digital-lang' };

// Representative target matrix. lang applies where the page is localized.
const TARGETS = [
  // --- milosvasic.ru ---
  { id: 'mv-home-en-light',  site: 'mv', url: `${MV}/`, theme: 'light', lang: 'en', kind: 'landing' },
  { id: 'mv-home-en-dark',   site: 'mv', url: `${MV}/`, theme: 'dark',  lang: 'en', kind: 'landing' },
  { id: 'mv-home-ru-dark',   site: 'mv', url: `${MV}/`, theme: 'dark',  lang: 'ru', kind: 'landing' },
  { id: 'mv-home-ar-light',  site: 'mv', url: `${MV}/`, theme: 'light', lang: 'ar', kind: 'landing', rtl: true },
  { id: 'mv-home-ar-dark',   site: 'mv', url: `${MV}/`, theme: 'dark',  lang: 'ar', kind: 'landing', rtl: true },
  { id: 'mv-home-ja-light',  site: 'mv', url: `${MV}/`, theme: 'light', lang: 'ja', kind: 'landing' },
  { id: 'mv-product-en-light', site: 'mv', url: `${MV}/products/helixtrack.html`, theme: 'light', lang: 'en', kind: 'product' },
  { id: 'mv-product-en-dark',  site: 'mv', url: `${MV}/products/helixtrack.html`, theme: 'dark',  lang: 'en', kind: 'product' },
  { id: 'mv-portfolio-en-light', site: 'mv', url: `${MV}/portfolio/`, theme: 'light', lang: 'en', kind: 'portfolio' },
  { id: 'mv-portfolio-en-dark',  site: 'mv', url: `${MV}/portfolio/`, theme: 'dark',  lang: 'en', kind: 'portfolio' },
  { id: 'mv-doc-en-light',   site: 'mv', url: `${MV}/`, theme: 'light', lang: 'en', kind: 'doc', article: 'helix-code' },
  { id: 'mv-doc-ar-light',   site: 'mv', url: `${MV}/`, theme: 'light', lang: 'ar', kind: 'doc', article: 'helix-code', rtl: true },

  // --- vasic.digital (only homepage is localized; product/portfolio English-only) ---
  { id: 'vd-home-en-light',  site: 'vd', url: `${VD}/`, theme: 'light', lang: 'en', kind: 'landing' },
  { id: 'vd-home-en-dark',   site: 'vd', url: `${VD}/`, theme: 'dark',  lang: 'en', kind: 'landing' },
  { id: 'vd-home-ru-dark',   site: 'vd', url: `${VD}/`, theme: 'dark',  lang: 'ru', kind: 'landing' },
  { id: 'vd-home-ar-light',  site: 'vd', url: `${VD}/`, theme: 'light', lang: 'ar', kind: 'landing', rtl: true },
  { id: 'vd-home-ja-light',  site: 'vd', url: `${VD}/`, theme: 'light', lang: 'ja', kind: 'landing' },
  { id: 'vd-product-en-light', site: 'vd', url: `${VD}/products/catalogizer.html`, theme: 'light', lang: 'en', kind: 'product', englishOnly: true },
  { id: 'vd-product-en-dark',  site: 'vd', url: `${VD}/products/catalogizer.html`, theme: 'dark',  lang: 'en', kind: 'product', englishOnly: true },
  { id: 'vd-portfolio-en-light', site: 'vd', url: `${VD}/portfolio/`, theme: 'light', lang: 'en', kind: 'portfolio', englishOnly: true },
  { id: 'vd-portfolio-en-dark',  site: 'vd', url: `${VD}/portfolio/`, theme: 'dark',  lang: 'en', kind: 'portfolio', englishOnly: true },
  { id: 'vd-doc-en-light',   site: 'vd', url: `${VD}/`, theme: 'light', lang: 'en', kind: 'doc', article: 'helixcode' },
  { id: 'vd-doc-ar-light',   site: 'vd', url: `${VD}/`, theme: 'light', lang: 'ar', kind: 'doc', article: 'helixcode', rtl: true },
];

// ---- WCAG contrast helpers (executed in-page) ----
const inPageContrastSampler = () => {
  function parseRGB(s) {
    const m = s && s.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    const p = m[1].split(',').map(x => parseFloat(x.trim()));
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  }
  function lum({ r, g, b }) {
    const f = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
  }
  function ratio(fg, bg) {
    const L1 = lum(fg), L2 = lum(bg);
    const a = Math.max(L1, L2), b = Math.min(L1, L2);
    return (a + 0.05) / (b + 0.05);
  }
  function effectiveBg(el) {
    let node = el;
    while (node && node !== document.documentElement) {
      const c = parseRGB(getComputedStyle(node).backgroundColor);
      if (c && c.a !== 0) return c;
      node = node.parentElement;
    }
    const bodyc = parseRGB(getComputedStyle(document.body).backgroundColor);
    return bodyc && bodyc.a !== 0 ? bodyc : { r: 255, g: 255, b: 255, a: 1 };
  }
  const selectors = [
    '.od-muted', '.vd-muted', '.mvx-muted', '.od-section__eyebrow', '.od-stat__label',
    '.od-hero__lede', '.od-section__lede', '.mvx-card__blurb', '.od-btn--primary',
    '.od-btn--secondary', '.od-btn--ghost', '.od-badge', '.badge', '.tag', '.chip',
    'a', 'nav a', 'footer a', '.role', 'p', 'small', 'code', '.od-nav__link',
    '.mono', '.od-pill', '.od-tag'
  ];
  const seen = new Set();
  const rows = [];
  selectors.forEach(sel => {
    let els;
    try { els = document.querySelectorAll(sel); } catch (e) { return; }
    let count = 0;
    els.forEach(el => {
      if (count >= 3) return;               // sample up to 3 per selector
      const txt = (el.textContent || '').trim();
      if (!txt) return;
      const cs = getComputedStyle(el);
      if (cs.visibility === 'hidden' || cs.display === 'none' || parseFloat(cs.opacity) === 0) return;
      const fg = parseRGB(cs.color);
      if (!fg) return;
      const bg = effectiveBg(el);
      // blend fg over bg if fg has alpha
      const af = fg.a == null ? 1 : fg.a;
      const blended = { r: fg.r * af + bg.r * (1 - af), g: fg.g * af + bg.g * (1 - af), b: fg.b * af + bg.b * (1 - af) };
      const cr = ratio(blended, bg);
      const fontPx = parseFloat(cs.fontSize);
      const weight = parseInt(cs.fontWeight) || 400;
      const isLarge = fontPx >= 24 || (fontPx >= 18.66 && weight >= 700);
      const threshold = isLarge ? 3.0 : 4.5;
      const key = sel + '|' + Math.round(cr * 100) + '|' + txt.slice(0, 20);
      if (seen.has(key)) return;
      seen.add(key);
      count++;
      rows.push({
        selector: sel,
        sample: txt.slice(0, 40),
        fg: `rgb(${Math.round(fg.r)},${Math.round(fg.g)},${Math.round(fg.b)})`,
        bg: `rgb(${Math.round(bg.r)},${Math.round(bg.g)},${Math.round(bg.b)})`,
        fontPx: Math.round(fontPx * 10) / 10,
        weight,
        large: isLarge,
        ratio: Math.round(cr * 100) / 100,
        threshold,
        pass: cr >= threshold - 0.005
      });
    });
  });
  return rows;
};

const inPageChecks = () => {
  const out = {};
  // skip link
  const skip = document.querySelector('.skip-link, a[href="#main"], a[href="#top"], a[href^="#"][class*="skip"]');
  out.skipLink = skip ? { text: (skip.textContent || '').trim(), href: skip.getAttribute('href') } : null;
  // focus-visible rule present?
  let focusVisible = false, reducedMotion = false;
  for (const sheet of document.styleSheets) {
    let rules; try { rules = sheet.cssRules; } catch (e) { continue; }
    if (!rules) continue;
    for (const rule of rules) {
      const css = rule.cssText || '';
      if (css.includes(':focus-visible') && /(outline|box-shadow|border)/.test(css)) focusVisible = true;
      if (rule.media && rule.media.mediaText && rule.media.mediaText.includes('prefers-reduced-motion')) reducedMotion = true;
    }
  }
  out.focusVisibleRule = focusVisible;
  out.reducedMotionRule = reducedMotion;
  // landmarks
  out.landmarks = {
    header: !!document.querySelector('header, [role=banner]'),
    nav: !!document.querySelector('nav, [role=navigation]'),
    main: !!document.querySelector('main, [role=main]'),
    footer: !!document.querySelector('footer, [role=contentinfo]'),
  };
  // headings order
  out.headings = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6'))
    .map(h => ({ level: +h.tagName[1], text: (h.textContent || '').trim().slice(0, 40) }));
  out.h1Count = document.querySelectorAll('h1').length;
  // images missing alt
  out.imagesNoAlt = Array.from(document.querySelectorAll('img'))
    .filter(i => !i.hasAttribute('alt'))
    .map(i => i.getAttribute('src') || i.outerHTML.slice(0, 80));
  out.imgTotal = document.querySelectorAll('img').length;
  // icon-only buttons/links without accessible name
  function accName(el) {
    const al = el.getAttribute('aria-label');
    if (al && al.trim()) return al.trim();
    const lb = el.getAttribute('aria-labelledby');
    if (lb) { const t = document.getElementById(lb); if (t) return (t.textContent || '').trim(); }
    const title = el.getAttribute('title');
    if (title && title.trim()) return title.trim();
    const txt = (el.textContent || '').replace(/\s+/g, ' ').trim();
    return txt;
  }
  out.iconOnlyNoName = Array.from(document.querySelectorAll('button, a[role=button], [role=button]'))
    .filter(b => {
      const name = accName(b);
      const hasImg = b.querySelector('svg,img,use,i');
      return hasImg && (!name || name.length === 0);
    })
    .map(b => b.outerHTML.replace(/\s+/g, ' ').slice(0, 120));
  // interactive controls present
  out.controls = {
    themeToggle: !!document.querySelector('#theme-btn, .od-theme-toggle, [class*="theme-toggle"]'),
    langSwitcher: !!document.querySelector('#lang-btn, .od-lang, [class*="lang"], [class*="language-switcher"]'),
  };
  return out;
};

async function keyboardChecks(page, target) {
  const res = { tabReachesInteractive: false, themeToggleFocusable: false, langFocusable: false, tabbedTags: [] };
  await page.evaluate(() => { document.body.focus(); });
  const tags = [];
  for (let i = 0; i < 25; i++) {
    await page.keyboard.press('Tab');
    const info = await page.evaluate(() => {
      const el = document.activeElement;
      if (!el || el === document.body) return null;
      return { tag: el.tagName, id: el.id || '', cls: (el.className && el.className.toString ? el.className.toString() : '').slice(0, 40) };
    });
    if (info) { tags.push(info); }
  }
  res.tabbedTags = tags.slice(0, 15);
  res.tabReachesInteractive = tags.length > 0;
  res.themeToggleFocusable = tags.some(t => /theme/.test(t.id) || /theme/.test(t.cls));
  res.langFocusable = tags.some(t => /lang/.test(t.id) || /lang/.test(t.cls));
  return res;
}

async function reducedMotionCheck(context, target) {
  const page = await context.newPage();
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await applyPrefs(page, target);
  await page.goto(target.url, { waitUntil: 'networkidle' }).catch(() => {});
  await page.waitForTimeout(500);
  const r = await page.evaluate(() => {
    const reveals = document.querySelectorAll('.reveal');
    const shown = document.querySelectorAll('.reveal.in');
    // sample a few animated elements' effective animation/transition duration
    let anyAnimating = false;
    document.querySelectorAll('.reveal, [class*="anim"], .od-hero, .od-card').forEach(el => {
      const cs = getComputedStyle(el);
      const ad = parseFloat(cs.animationDuration) || 0;
      if (ad > 0.01 && cs.animationName !== 'none') anyAnimating = true;
    });
    return { reveals: reveals.length, shown: shown.length, anyAnimating };
  });
  await page.close();
  return r;
}

async function applyPrefs(page, target) {
  const tkey = THEME_KEY[target.site], lkey = LANG_KEY[target.site];
  await page.addInitScript(([tk, tv, lk, lv]) => {
    try { localStorage.setItem(tk, tv); localStorage.setItem(lk, lv); } catch (e) {}
  }, [tkey, target.theme, lkey, target.lang]);
}

async function run() {
  const browser = await chromium.launch();
  const contrastAll = [];
  const checksAll = {};
  const summary = { targets: [], totals: { violations: 0, byImpact: {}, contrastRowsFail: 0, contrastRowsTotal: 0 } };

  for (const target of TARGETS) {
    const context = await browser.newContext();
    const page = await context.newPage();
    await applyPrefs(page, target);
    try {
      await page.goto(target.url, { waitUntil: 'networkidle', timeout: 30000 });
    } catch (e) {
      console.log(`WARN goto ${target.id}: ${e.message}`);
    }
    await page.waitForTimeout(400);

    // For doc targets, open the article modal
    if (target.kind === 'doc') {
      await page.evaluate((slug) => {
        if (window.openArticle) return window.openArticle(slug);
        if (window.MVArticles) return window.MVArticles.open(slug);
        if (window.VDArticles) return window.VDArticles.open(slug);
      }, target.article).catch(() => {});
      await page.waitForTimeout(1200);
    }

    // confirm applied theme/lang
    const applied = await page.evaluate(() => ({
      lang: document.documentElement.getAttribute('lang'),
      dir: document.documentElement.getAttribute('dir'),
      theme: document.documentElement.getAttribute('data-theme'),
    }));

    // axe run — all rules; record tags to separate WCAG from best-practice
    let axe;
    try {
      axe = await new AxeBuilder({ page }).analyze();
    } catch (e) {
      console.log(`AXE ERROR ${target.id}: ${e.message}`);
      axe = { violations: [], incomplete: [], error: e.message };
    }
    // slim raw file
    fs.writeFileSync(path.join(OUT, 'axe-json', `${target.id}.json`), JSON.stringify({
      target, applied,
      violations: axe.violations,
      incomplete: (axe.incomplete || []).map(v => ({ id: v.id, impact: v.impact, nodes: v.nodes.length })),
      passesCount: (axe.passes || []).length,
    }, null, 2));

    // aggregate axe
    const vlist = axe.violations.map(v => ({
      id: v.id, impact: v.impact, help: v.help, tags: v.tags,
      nodeCount: v.nodes.length,
      nodes: v.nodes.slice(0, 8).map(n => ({ target: n.target, summary: (n.failureSummary || '').slice(0, 200) })),
    }));
    let nodeTotal = 0;
    vlist.forEach(v => { nodeTotal += v.nodeCount; summary.totals.byImpact[v.impact] = (summary.totals.byImpact[v.impact] || 0) + v.nodeCount; });
    summary.totals.violations += nodeTotal;

    // contrast from axe color-contrast (measured ratios)
    const ccViol = axe.violations.filter(v => v.id === 'color-contrast' || v.id === 'color-contrast-enhanced');
    ccViol.forEach(v => v.nodes.forEach(n => {
      const d = (n.any && n.any[0] && n.any[0].data) || {};
      contrastAll.push({
        target: target.id, site: target.site, theme: target.theme, lang: target.lang,
        source: 'axe', selector: (n.target || []).join(' '),
        fg: d.fgColor, bg: d.bgColor,
        ratio: d.contrastRatio, required: d.expectedContrastRatio,
        fontSize: d.fontSize, fontWeight: d.fontWeight, pass: false,
      });
    }));

    // custom contrast sampler
    const sampled = await page.evaluate(inPageContrastSampler);
    sampled.forEach(r => {
      contrastAll.push({
        target: target.id, site: target.site, theme: target.theme, lang: target.lang,
        source: 'sampler', selector: r.selector, sample: r.sample,
        fg: r.fg, bg: r.bg, ratio: r.ratio, required: r.threshold,
        fontSize: r.fontPx, fontWeight: r.weight, large: r.large, pass: r.pass,
      });
      summary.totals.contrastRowsTotal++;
      if (!r.pass) summary.totals.contrastRowsFail++;
    });

    // page checks
    const checks = await page.evaluate(inPageChecks);
    // keyboard (skip for doc where modal already changed focus; still run)
    let kb = null;
    try { kb = await keyboardChecks(page, target); } catch (e) { kb = { error: e.message }; }

    // focus trap for doc modals: after opening, press Tab many times, ensure focus stays within modal
    let focusTrap = null;
    if (target.kind === 'doc') {
      focusTrap = await page.evaluate(async () => {
        const modal = document.querySelector('[class*="article-modal"], [role=dialog], .modal, dialog[open]');
        if (!modal) return { modalFound: false };
        return { modalFound: true, role: modal.getAttribute('role'), ariaModal: modal.getAttribute('aria-modal'),
                 ariaLabel: modal.getAttribute('aria-label') || modal.getAttribute('aria-labelledby') };
      });
      // tab within and check containment
      const contained = await (async () => {
        let inside = 0, outside = 0;
        for (let i = 0; i < 15; i++) {
          await page.keyboard.press('Tab');
          const r = await page.evaluate(() => {
            const modal = document.querySelector('[class*="article-modal"], [role=dialog], .modal, dialog[open]');
            const el = document.activeElement;
            return modal && el ? modal.contains(el) : null;
          });
          if (r === true) inside++; else if (r === false) outside++;
        }
        return { inside, outside };
      })();
      focusTrap.containment = contained;
    }

    checksAll[target.id] = { applied, checks, keyboard: kb, focusTrap };

    // reduced motion (fresh page)
    const rm = await reducedMotionCheck(context, target);
    checksAll[target.id].reducedMotion = rm;

    summary.targets.push({
      id: target.id, kind: target.kind, applied,
      violationNodes: nodeTotal,
      violationRules: vlist.map(v => `${v.id}(${v.impact}:${v.nodeCount})`),
    });

    console.log(`DONE ${target.id}  lang=${applied.lang} dir=${applied.dir||'ltr'} theme=${applied.theme}  axeNodes=${nodeTotal}  contrastFail(sampler)=${sampled.filter(s=>!s.pass).length}`);
    await context.close();
  }

  fs.writeFileSync(path.join(OUT, 'data', 'contrast.json'), JSON.stringify(contrastAll, null, 2));
  fs.writeFileSync(path.join(OUT, 'data', 'checks.json'), JSON.stringify(checksAll, null, 2));
  fs.writeFileSync(path.join(OUT, 'data', 'summary.json'), JSON.stringify(summary, null, 2));
  await browser.close();
  console.log('\n=== AUDIT COMPLETE ===');
  console.log('Total axe violation nodes:', summary.totals.violations, 'byImpact:', JSON.stringify(summary.totals.byImpact));
  console.log('Contrast sampler rows:', summary.totals.contrastRowsTotal, 'fails:', summary.totals.contrastRowsFail);
}

run().catch(e => { console.error(e); process.exit(1); });
