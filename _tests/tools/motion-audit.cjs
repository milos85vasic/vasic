/* =============================================================================
 * READ-ONLY functional motion / interactive-widget audit driver.
 * Drives the ALREADY-GENERATED static output of both sites with real browsers
 * (chromium + firefox + webkit via Playwright) and records rock-solid evidence:
 *   - before/after screenshots proving state change for each interaction
 *   - a JSON metrics dump (metrics.json) consumed by the report generator
 *   - long-task / jank capture during a scripted scroll
 *   - prefers-reduced-motion re-render verification
 * It edits NO site source and runs NO generator. It only serves the two static
 * roots over http.server and observes behaviour.
 * ========================================================================== */
const { chromium, firefox, webkit } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('node:path');
const http = require('http');

// Derive the repo root from this file's own location (repo/_tests/tools/ -> ../..)
// so the audit runs from ANY checkout without a hardcoded absolute path.
// VASIC_ROOT overrides the default when the repo root is elsewhere.
const REPO = process.env.VASIC_ROOT || path.resolve(__dirname, '..', '..');
// Ports and bases are DERIVED from ../env.js (MOTION_* pair), never frozen here:
// the port a server BINDS and the base a browser REQUESTS are now one value, and
// a second checkout can drive this with MOTION_VD_PORT / MOTION_MV_PORT set.
const { MOTION_VD_PORT, MOTION_MV_PORT, MOTION_VD_BASE, MOTION_MV_BASE } = require('../env.js');
const OUT = path.join(REPO, '_tests/evidence/motion-audit');
const SHOTS = path.join(OUT, 'screenshots');
const DATA = path.join(OUT, 'data');
fs.mkdirSync(SHOTS, { recursive: true });
fs.mkdirSync(DATA, { recursive: true });

const SERVERS = [
  { root: path.join(REPO, 'milosvasic.ru/_site'), port: MOTION_MV_PORT, base: MOTION_MV_BASE },
  { root: path.join(REPO, 'vasic.digital'), port: MOTION_VD_PORT, base: MOTION_VD_BASE },
];

const SITES = {
  milos: {
    base: MOTION_MV_BASE,
    label: 'milosvasic.ru',
    pages: {
      landing: '/',
      product: '/products/helixtrack.html',
      portfolio: '/portfolio/',
    },
    themeBtn: '#theme-btn',
    langBtn: '#lang-btn',
    langMenu: '#lang-menu',
    stickyHeader: '.nav',
    themeKey: 'mv-theme',
  },
  vasic: {
    base: MOTION_VD_BASE,
    label: 'vasic.digital',
    pages: {
      landing: '/',
      product: '/products/catalogizer.html',
      portfolio: '/portfolio/',
    },
    themeBtn: '.od-theme-toggle', // class matches both #od-theme-toggle (landing/product) and #pf-theme-toggle (portfolio)
    langBtn: null, // brief: OD pages have no switcher — verify
    langMenu: null,
    stickyHeader: '.od-header',
    themeKey: 'od-theme',
  },
};

const results = { generatedAt: new Date().toISOString(), sites: {} };

/* ----------------------------- infra helpers ---------------------------- */
function startServer(root, port) {
  // ThreadingHTTPServer: single-threaded http.server stalls under 3 concurrent
  // browser engines + reloads, which caused a transient webkit nav timeout.
  const code = `import functools,http.server;H=functools.partial(http.server.SimpleHTTPRequestHandler,directory=${JSON.stringify(root)});http.server.ThreadingHTTPServer(("127.0.0.1",${port}),H).serve_forever()`;
  const p = spawn('python3', ['-c', code], { stdio: 'ignore' });
  return p;
}
async function gotoRetry(page, url, tries = 3) {
  let last;
  for (let i = 0; i < tries; i++) {
    try { return await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 }); }
    catch (e) { last = e; await page.waitForTimeout(500); }
  }
  throw last;
}
function waitFor(url, tries = 40) {
  return new Promise((resolve, reject) => {
    const attempt = (n) => {
      http.get(url, (res) => { res.resume(); resolve(true); })
        .on('error', () => {
          if (n <= 0) return reject(new Error('server not up: ' + url));
          setTimeout(() => attempt(n - 1), 250);
        });
    };
    attempt(tries);
  });
}
const shotName = (parts) => parts.filter(Boolean).join('__').replace(/[^\w.-]+/g, '-') + '.png';
async function shot(page, parts) {
  const file = shotName(parts);
  try { await page.screenshot({ path: path.join(SHOTS, file) }); } catch (e) { return null; }
  return file;
}

/* --------------------------- measurement probes ------------------------- */
// Scroll-reveal: find a reveal element below the fold, measure before/after.
async function probeReveal(page, selectorList) {
  return await page.evaluate((sels) => {
    const els = [];
    sels.forEach((s) => document.querySelectorAll(s).forEach((e) => els.push(e)));
    if (!els.length) return { present: false };
    // Prefer an element that is BELOW the fold at load (so scrolling produces a
    // real state delta). Fall back to the last element if none are below fold.
    const below = els.filter((e) => e.getBoundingClientRect().top > window.innerHeight);
    const target = below.length ? below[0] : els[els.length - 1];
    window.__odRevealTarget = target; // reused by scrollRevealAndMeasure
    const cs = getComputedStyle(target);
    const r = target.getBoundingClientRect();
    return {
      present: true,
      count: els.length,
      belowFoldCount: below.length,
      belowFoldAtLoad: r.top > window.innerHeight,
      before: {
        transform: cs.transform,
        opacity: cs.opacity,
        isVisibleClass: target.classList.contains('is-visible') || target.classList.contains('in'),
      },
    };
  }, selectorList);
}
async function scrollRevealAndMeasure(page, selectorList) {
  return await page.evaluate(async (sels) => {
    const els = [];
    sels.forEach((s) => document.querySelectorAll(s).forEach((e) => els.push(e)));
    const target = window.__odRevealTarget || els[els.length - 1];
    target.scrollIntoView({ block: 'center' });
    await new Promise((r) => setTimeout(r, 900));
    const cs = getComputedStyle(target);
    return {
      transform: cs.transform,
      opacity: cs.opacity,
      isVisibleClass: target.classList.contains('is-visible') || target.classList.contains('in'),
    };
  }, selectorList);
}

/* --------------------------- long-task capture -------------------------- */
async function installLongTaskObserver(page) {
  await page.evaluate(() => {
    window.__longtasks = [];
    try {
      const po = new PerformanceObserver((list) => {
        for (const e of list.getEntries()) window.__longtasks.push({ dur: Math.round(e.duration), start: Math.round(e.startTime) });
      });
      po.observe({ type: 'longtask', buffered: true });
      window.__longtaskSupported = true;
    } catch (e) { window.__longtaskSupported = false; }
  });
}
async function scriptedScroll(page) {
  await page.evaluate(async () => {
    const h = document.body.scrollHeight;
    const step = Math.max(200, Math.floor(window.innerHeight * 0.6));
    for (let y = 0; y <= h; y += step) {
      window.scrollTo(0, y);
      await new Promise((r) => setTimeout(r, 60));
    }
    window.scrollTo(0, 0);
    await new Promise((r) => setTimeout(r, 120));
  });
}
async function collectLongTasks(page) {
  return await page.evaluate(() => ({
    supported: !!window.__longtaskSupported,
    tasks: window.__longtasks || [],
  }));
}

/* ------------------------------- per-page ------------------------------- */
async function auditPage(browserName, site, siteCfg, pageKey, pagePath, ctxOpts, full) {
  const url = siteCfg.base + pagePath;
  const context = await site.browser.newContext(ctxOpts || {});
  const page = await context.newPage();
  const rec = { url, checks: {} };
  const revealSel = ['.od-reveal', '.od-stagger', '.reveal'];

  await gotoRetry(page, url);
  await page.waitForTimeout(500); // allow deferred motion.js/main.js boot

  /* --- static inventory (presence of widgets the brief expects) --- */
  const inventory = await page.evaluate((s) => {
    const c = (sel) => document.querySelectorAll(sel).length;
    return {
      odReveal: c('.od-reveal'),
      odStagger: c('.od-stagger'),
      legacyReveal: c('.reveal'),
      accordion: c('.od-accordion'),
      lottie: c('.od-lottie'),
      bounce: c('.od-bounce'),
      blink: c('.od-blink'),
      highlight: c('.od-highlight'),
      stickyNav: c('[data-od-sticky-nav]'),
      themeBtn: s.themeBtn ? c(s.themeBtn) : 0,
      langBtn: s.langBtn ? c(s.langBtn) : 0,
      dlTriggers: c('[data-dl]'),
      dialogs: c('[role="dialog"]'),
      backToTop: c('.back-to-top, [data-back-to-top], .to-top, #to-top'),
      toasts: c('.toast, [role="status"], .od-toast'),
    };
  }, siteCfg);
  rec.inventory = inventory;

  /* ------------------------- 1. Scroll reveal ------------------------- */
  try {
    const before = await probeReveal(page, revealSel);
    let beforeShot = null, afterShot = null, after = null;
    if (before.present) {
      beforeShot = await shot(page, [site.key, pageKey, 'reveal', 'before', browserName]);
      after = await scrollRevealAndMeasure(page, revealSel);
      afterShot = await shot(page, [site.key, pageKey, 'reveal', 'after', browserName]);
    }
    // Caught a real transition: the below-fold element changed to rest state.
    const changed = before.present && (
      (before.before.transform !== after?.transform) ||
      (before.before.opacity !== after?.opacity) ||
      (!before.before.isVisibleClass && after?.isVisibleClass)
    );
    // Reveal controller demonstrably ran and put the element in final state
    // (identity transform, opaque, is-visible/in class present).
    const revealedFinal = before.present && after &&
      after.isVisibleClass &&
      (after.transform === 'none' || after.transform === 'matrix(1, 0, 0, 1, 0, 0)') &&
      parseFloat(after.opacity) > 0.99;
    let status, note;
    if (!before.present) { status = 'absent'; }
    else if (changed) { status = 'works'; }
    else if (revealedFinal && before.belowFoldCount === 0) {
      status = 'works';
      note = 'only reveal target sits above the fold; revealed at load (is-visible set) — no scroll delta to capture';
    } else { status = 'broken'; }
    rec.checks.scrollReveal = {
      status, note, before: before.before, after,
      belowFoldAtLoad: before.belowFoldAtLoad, belowFoldCount: before.belowFoldCount,
      count: before.count, screenshots: { before: beforeShot, after: afterShot },
    };
  } catch (e) { rec.checks.scrollReveal = { status: 'error', error: String(e) }; }

  /* ------------------------- 2. Sticky header ------------------------- */
  try {
    const sel = siteCfg.stickyHeader;
    const beforeTop = await page.evaluate((s) => {
      const el = document.querySelector(s); if (!el) return null;
      return { top: Math.round(el.getBoundingClientRect().top), pos: getComputedStyle(el).position };
    }, sel);
    await page.evaluate(() => window.scrollTo(0, 1600));
    await page.waitForTimeout(300);
    const afterState = await page.evaluate((s) => {
      const el = document.querySelector(s); if (!el) return null;
      const r = el.getBoundingClientRect();
      return { top: Math.round(r.top), bottom: Math.round(r.bottom), visible: r.bottom > 0 && r.top < innerHeight, scrollY: Math.round(window.scrollY) };
    }, sel);
    const stickyShot = await shot(page, [site.key, pageKey, 'sticky-after-scroll', browserName]);
    await page.evaluate(() => window.scrollTo(0, 0));
    const works = beforeState_ok(beforeTop) && afterState && afterState.visible && Math.abs(afterState.top) <= 4;
    rec.checks.stickyHeader = {
      status: !beforeTop ? 'absent' : (works ? 'works' : 'broken'),
      position: beforeTop?.pos, beforeTop: beforeTop?.top, afterScroll: afterState,
      screenshot: stickyShot,
    };
  } catch (e) { rec.checks.stickyHeader = { status: 'error', error: String(e) }; }

  /* --------------------- 3. Accordion / disclosure -------------------- */
  try {
    if (inventory.accordion === 0) {
      rec.checks.accordion = { status: 'absent', note: 'no .od-accordion elements on page' };
    } else {
      const trig = page.locator('.od-accordion__trigger').first();
      const beforeExp = await trig.getAttribute('aria-expanded');
      const beforeShot = await shot(page, [site.key, pageKey, 'accordion', 'before', browserName]);
      await trig.click();
      await page.waitForTimeout(400);
      const afterExp = await trig.getAttribute('aria-expanded');
      const afterShot = await shot(page, [site.key, pageKey, 'accordion', 'after', browserName]);
      rec.checks.accordion = {
        status: beforeExp !== afterExp ? 'works' : 'broken',
        beforeExpanded: beforeExp, afterExpanded: afterExp,
        screenshots: { before: beforeShot, after: afterShot },
      };
    }
  } catch (e) { rec.checks.accordion = { status: 'error', error: String(e) }; }

  /* ------------------------- 4. Theme toggle -------------------------- */
  try {
    const sel = siteCfg.themeBtn;
    const exists = await page.locator(sel).count();
    if (!exists) {
      rec.checks.themeToggle = { status: 'absent', note: 'no theme toggle button' };
    } else {
      const toggleId = await page.locator(sel).first().getAttribute('id');
      const beforeState = await page.evaluate(() => ({
        theme: document.documentElement.getAttribute('data-theme'),
        bg: getComputedStyle(document.body).backgroundColor,
      }));
      const beforeShot = await shot(page, [site.key, pageKey, 'theme', 'before', browserName]);
      await page.locator(sel).first().click();
      await page.waitForTimeout(500);
      const afterState = await page.evaluate(() => ({
        theme: document.documentElement.getAttribute('data-theme'),
        bg: getComputedStyle(document.body).backgroundColor,
        stored: (() => { try { return localStorage.getItem('mv-theme') || localStorage.getItem('od-theme'); } catch (e) { return null; } })(),
      }));
      const afterShot = await shot(page, [site.key, pageKey, 'theme', 'after', browserName]);
      // persistence: reload and read applied theme
      await page.reload({ waitUntil: 'domcontentloaded', timeout: 20000 });
      await page.waitForTimeout(300);
      const afterReload = await page.evaluate(() => ({
        theme: document.documentElement.getAttribute('data-theme'),
        bg: getComputedStyle(document.body).backgroundColor,
      }));
      const toggled = beforeState.theme !== afterState.theme && beforeState.bg !== afterState.bg;
      const persisted = afterReload.theme === afterState.theme;
      rec.checks.themeToggle = {
        status: toggled ? 'works' : 'broken',
        persists: persisted, toggleId, before: beforeState, after: afterState, afterReload,
        screenshots: { before: beforeShot, after: afterShot },
      };
    }
  } catch (e) { rec.checks.themeToggle = { status: 'error', error: String(e) }; }

  /* ----------------------- 5. Language switcher ----------------------- */
  try {
    if (!siteCfg.langBtn) {
      const anyLang = await page.locator('[id*="lang"], [class*="lang-"], [aria-label*="language" i]').count();
      rec.checks.langSwitcher = { status: 'absent', note: 'site has no language switcher control', langLikeElements: anyLang };
    } else {
      const btn = page.locator(siteCfg.langBtn);
      const exists = await btn.count();
      if (!exists) {
        rec.checks.langSwitcher = { status: 'absent' };
      } else {
        const beforeExpanded = await btn.getAttribute('aria-expanded');
        await btn.click();
        await page.waitForTimeout(300);
        const menu = page.locator(siteCfg.langMenu);
        const openState = await page.evaluate((ms) => {
          const m = document.querySelector(ms);
          return { open: m ? m.classList.contains('open') : false, items: m ? m.querySelectorAll('button,[role="menuitem"]').length : 0 };
        }, siteCfg.langMenu);
        const openShot = await shot(page, [site.key, pageKey, 'lang', 'open', browserName]);
        const afterExpanded = await btn.getAttribute('aria-expanded');
        // keyboard operability: Escape closes
        await page.keyboard.press('Escape');
        await page.waitForTimeout(200);
        const closed = await page.evaluate((ms) => { const m = document.querySelector(ms); return m ? !m.classList.contains('open') : true; }, siteCfg.langMenu);
        // keyboard: focus button and open via Enter
        await btn.focus();
        await page.keyboard.press('Enter');
        await page.waitForTimeout(200);
        const openedViaKb = await page.evaluate((ms) => { const m = document.querySelector(ms); return m ? m.classList.contains('open') : false; }, siteCfg.langMenu);
        rec.checks.langSwitcher = {
          status: openState.open && openState.items > 0 ? 'works' : 'broken',
          items: openState.items, ariaBefore: beforeExpanded, ariaAfterOpen: afterExpanded,
          escapeCloses: closed, keyboardOpens: openedViaKb, screenshot: openShot,
        };
      }
    }
  } catch (e) { rec.checks.langSwitcher = { status: 'error', error: String(e) }; }

  /* ------- 6. Dialogs/modals/dropdowns/back-to-top/toasts ------------- */
  try {
    const modal = { status: 'absent' };
    if (inventory.dlTriggers > 0) {
      const trig = page.locator('[data-dl]').first();
      await trig.click();
      await page.waitForTimeout(400);
      const open = await page.evaluate(() => {
        const m = document.querySelector('#dl-modal');
        if (!m) return null;
        const cs = getComputedStyle(m);
        const backdrop = m.querySelector('.dl-backdrop');
        return {
          visible: cs.visibility !== 'hidden' && cs.display !== 'none' && m.classList.contains('open'),
          opacity: cs.opacity,
          backdropBlur: backdrop ? getComputedStyle(backdrop).backdropFilter : null,
        };
      });
      const openShot = await shot(page, [site.key, pageKey, 'modal', 'open', browserName]);
      await page.keyboard.press('Escape');
      await page.waitForTimeout(300);
      const closedNow = await page.evaluate(() => { const m = document.querySelector('#dl-modal'); return m ? (m.hidden || !m.classList.contains('open')) : true; });
      Object.assign(modal, {
        status: open && open.visible ? 'works' : 'broken',
        openState: open, escapeCloses: closedNow, screenshot: openShot,
      });
    }
    rec.checks.modal = modal;
    rec.checks.backToTop = { status: inventory.backToTop > 0 ? 'present' : 'absent' };
    rec.checks.toasts = { status: inventory.toasts > 0 ? 'present' : 'absent' };
  } catch (e) { rec.checks.modal = { status: 'error', error: String(e) }; }

  /* ----------------------------- 7. Lottie ---------------------------- */
  rec.checks.lottie = {
    status: inventory.lottie > 0 ? 'present' : 'absent',
    count: inventory.lottie,
    note: inventory.lottie === 0 ? 'no .od-lottie hosts — motion.js Lottie path never engages on this page' : undefined,
  };

  /* ------------- 8. Bounce / blink / highlight micro-interactions ----- */
  try {
    const micro = { bounce: inventory.bounce, blink: inventory.blink, highlight: inventory.highlight };
    // Sample a real hover micro-interaction (card lift) if a card exists.
    let hover = null;
    const card = page.locator('.od-product-card, .card').first();
    if (await card.count()) {
      const beforeT = await card.evaluate((el) => getComputedStyle(el).transform);
      await card.hover();
      await page.waitForTimeout(250);
      const afterT = await card.evaluate((el) => getComputedStyle(el).transform);
      hover = { before: beforeT, after: afterT, changed: beforeT !== afterT };
    }
    rec.checks.microInteractions = {
      status: (micro.bounce + micro.blink + micro.highlight) > 0 ? 'present' : 'absent-classes',
      counts: micro, hoverSample: hover,
    };
  } catch (e) { rec.checks.microInteractions = { status: 'error', error: String(e) }; }

  /* ---------------------- PERF: long-task capture --------------------- */
  if (full) {
    try {
      await installLongTaskObserver(page);
      await scriptedScroll(page);
      const lt = await collectLongTasks(page);
      const durs = lt.tasks.map((t) => t.dur);
      rec.checks.longTasks = {
        supported: lt.supported,
        count: lt.tasks.length,
        maxMs: durs.length ? Math.max(...durs) : 0,
        totalMs: durs.reduce((a, b) => a + b, 0),
        over50ms: durs.filter((d) => d > 50).length,
        note: lt.supported ? undefined : 'longtask API not supported in this engine',
      };
    } catch (e) { rec.checks.longTasks = { status: 'error', error: String(e) }; }
  }

  await context.close();
  return rec;
}

function beforeState_ok(b) { return b && (b.pos === 'sticky' || b.pos === 'fixed'); }

/* --------------------- reduced-motion verification ------------------- */
async function auditReducedMotion(browserName, site, siteCfg, pageKey, pagePath) {
  const url = siteCfg.base + pagePath;
  const context = await site.browser.newContext({ reducedMotion: 'reduce' });
  const page = await context.newPage();
  await gotoRetry(page, url);
  await page.waitForTimeout(600);
  const revealSel = ['.od-reveal', '.od-stagger', '.reveal'];
  // Without scrolling, reveal elements should already be in final state
  // (motion.js short-circuits to add is-visible; main.js adds .in; CSS neutralises transitions).
  const state = await page.evaluate((sels) => {
    const els = [];
    sels.forEach((s) => document.querySelectorAll(s).forEach((e) => els.push(e)));
    if (!els.length) return { present: false };
    const belowFold = els.filter((e) => e.getBoundingClientRect().top > window.innerHeight);
    const sample = belowFold.length ? belowFold : els;
    const summary = sample.slice(0, 8).map((e) => {
      const cs = getComputedStyle(e);
      return {
        transform: cs.transform,
        opacity: cs.opacity,
        transitionDuration: cs.transitionDuration,
        shown: cs.transform === 'none' && parseFloat(cs.opacity) > 0.99,
        hasVisibleClass: e.classList.contains('is-visible') || e.classList.contains('in'),
      };
    });
    return {
      present: true,
      total: els.length,
      belowFoldCount: belowFold.length,
      allShownImmediately: summary.every((s) => s.shown || s.hasVisibleClass),
      transitionsNeutralised: summary.every((s) => /0\.001ms|0s|^0ms/.test(s.transitionDuration) || parseFloat(s.transitionDuration) <= 0.01),
      samples: summary,
    };
  }, revealSel);
  const s = await shot(page, [site.key, pageKey, 'reduced-motion', browserName]);
  await context.close();
  return { url, state, screenshot: s };
}

/* --------------------------------- main -------------------------------- */
(async () => {
  const procs = SERVERS.map((s) => startServer(s.root, s.port));
  try {
    await Promise.all(SERVERS.map((s) => waitFor(`${s.base}/`)));
    console.log('servers up');

    const engines = { chromium, firefox, webkit };
    const keyBrowsers = ['chromium', 'firefox', 'webkit'];

    for (const [siteKey, siteCfg] of Object.entries(SITES)) {
      results.sites[siteKey] = { label: siteCfg.label, base: siteCfg.base, browsers: {} };

      for (const browserName of keyBrowsers) {
        const browser = await engines[browserName].launch();
        const site = { key: siteKey, browser };
        const isFull = browserName === 'chromium'; // full deep audit + screenshots on chromium
        const b = { pages: {}, reducedMotion: {} };

        for (const [pageKey, pagePath] of Object.entries(siteCfg.pages)) {
          // Cross-browser sanity: on firefox/webkit only re-run the KEY 3
          // interactions (theme, reveal, switcher) + on landing; chromium runs all.
          if (!isFull && pageKey !== 'landing') continue;
          console.log(`[${browserName}] ${siteKey}/${pageKey}`);
          b.pages[pageKey] = await auditPage(browserName, site, siteCfg, pageKey, pagePath, null, isFull);
        }

        // reduced-motion re-render — landing for every browser; all pages on chromium
        for (const [pageKey, pagePath] of Object.entries(siteCfg.pages)) {
          if (!isFull && pageKey !== 'landing') continue;
          b.reducedMotion[pageKey] = await auditReducedMotion(browserName, site, siteCfg, pageKey, pagePath);
        }

        results.sites[siteKey].browsers[browserName] = b;
        await browser.close();
      }
    }

    fs.writeFileSync(path.join(DATA, 'metrics.json'), JSON.stringify(results, null, 2));
    console.log('WROTE metrics.json');
  } finally {
    procs.forEach((p) => { try { p.kill('SIGKILL'); } catch (e) {} });
  }
})().catch((e) => { console.error('FATAL', e); process.exit(1); });
