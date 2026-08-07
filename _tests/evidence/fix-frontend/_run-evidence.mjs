import { chromium } from '@playwright/test';

const EV = '/Volumes/T7/Projects/vasic/_tests/evidence/fix-frontend';
const MILOS = 'http://localhost:8811';
const VASIC = 'http://localhost:8812';
const results = {};

async function shot(page, path) { await page.screenshot({ path }); }

async function edgeSpacing(browser, tag, base, homePath, productPath) {
  for (const w of [375, 1280]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: w === 375 ? 812 : 900 }, deviceScaleFactor: 2 });
    const page = await ctx.newPage();
    for (const [name, p] of [['home', homePath], ['product', productPath]]) {
      await page.goto(base + p, { waitUntil: 'networkidle' });
      await page.waitForTimeout(300);
      await page.screenshot({ path: `${EV}/edge-spacing/${tag}-${name}-${w}.png`, fullPage: w === 375 ? false : false });
      // measure gutters + overflow
      const m = await page.evaluate(() => {
        const de = document.documentElement;
        const g = (sel) => { const el = document.querySelector(sel); if (!el) return null; const cs = getComputedStyle(el); return { l: cs.paddingLeft, r: cs.paddingRight, t: cs.paddingTop, b: cs.paddingBottom }; };
        return { innerW: window.innerWidth, overflow: de.scrollWidth > de.clientWidth, scrollW: de.scrollWidth, clientW: de.clientWidth,
          section: g('.od-section'), hero: g('.od-hero,.vd-hero'), wrap: g('.wrap'), header: g('.od-header,.nav') };
      });
      results[`${tag}-${name}-${w}`] = m;
    }
    await ctx.close();
  }
}

async function milosModal(browser) {
  const ctx = await browser.newContext({ viewport: { width: 380, height: 640 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  await page.goto(MILOS + '/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(300);
  // open download CV modal
  await page.click('[data-dl="cv"]');
  await page.waitForSelector('#dl-modal:not([hidden])', { timeout: 3000 });
  await page.waitForTimeout(300);
  const before = await page.evaluate(() => {
    const list = document.querySelector('#dl-modal .dl-langs');
    const card = document.querySelector('#dl-modal .dl-card');
    const rows = list.querySelectorAll('.dl-lang');
    const last = rows[rows.length - 1];
    const lr = list.getBoundingClientRect();
    const last_r = last.getBoundingClientRect();
    return { rowCount: rows.length, listScrollH: list.scrollHeight, listClientH: list.clientHeight,
      scrollable: list.scrollHeight > list.clientHeight + 2,
      cardH: Math.round(card.getBoundingClientRect().height), vh: window.innerHeight,
      lastText: last.textContent.trim(),
      lastVisibleAtTop: last_r.top < lr.bottom && last_r.bottom > lr.top };
  });
  await page.screenshot({ path: `${EV}/modal-scroll/milos-dl-modal-380x640-top.png` });
  // scroll list to bottom
  await page.evaluate(() => { const l = document.querySelector('#dl-modal .dl-langs'); l.scrollTop = l.scrollHeight; });
  await page.waitForTimeout(250);
  const after = await page.evaluate(() => {
    const list = document.querySelector('#dl-modal .dl-langs');
    const rows = list.querySelectorAll('.dl-lang');
    const last = rows[rows.length - 1];
    const lr = list.getBoundingClientRect();
    const last_r = last.getBoundingClientRect();
    return { scrollTop: Math.round(list.scrollTop),
      lastFullyVisible: last_r.bottom <= lr.bottom + 1 && last_r.top >= lr.top - 1,
      lastText: last.textContent.trim() };
  });
  await page.screenshot({ path: `${EV}/modal-scroll/milos-dl-modal-380x640-scrolled-bottom.png` });
  results['milos-modal'] = { before, after };
  await ctx.close();
}

async function vasicMenu(browser) {
  const ctx = await browser.newContext({ viewport: { width: 380, height: 640 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  await page.goto(VASIC + '/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(400);
  await page.click('#od-lang-btn');
  await page.waitForSelector('#od-lang-menu:not([hidden])', { timeout: 3000 });
  await page.waitForTimeout(250);
  const before = await page.evaluate(() => {
    const menu = document.querySelector('#od-lang-menu');
    const rows = menu.querySelectorAll('button[role="menuitem"]');
    return { rowCount: rows.length, scrollH: menu.scrollHeight, clientH: menu.clientHeight,
      scrollable: menu.scrollHeight > menu.clientHeight + 2, maxH: getComputedStyle(menu).maxHeight };
  });
  await page.screenshot({ path: `${EV}/modal-scroll/vasic-langmenu-380x640-top.png` });
  await page.evaluate(() => { const m = document.querySelector('#od-lang-menu'); m.scrollTop = m.scrollHeight; });
  await page.waitForTimeout(200);
  const after = await page.evaluate(() => {
    const menu = document.querySelector('#od-lang-menu');
    const rows = menu.querySelectorAll('button[role="menuitem"]');
    const last = rows[rows.length - 1];
    const mr = menu.getBoundingClientRect(); const lr = last.getBoundingClientRect();
    return { scrollTop: Math.round(menu.scrollTop), lastText: last.textContent.trim(),
      lastVisible: lr.bottom <= mr.bottom + 1 };
  });
  await page.screenshot({ path: `${EV}/modal-scroll/vasic-langmenu-380x640-scrolled-bottom.png` });
  results['vasic-menu'] = { before, after };
  await ctx.close();
}

async function langSwitch(browser) {
  // MILOS product: navigate-to-localized (DE) + graceful-home (delete MV_PAGE -> FR)
  {
    const ctx = await browser.newContext({ viewport: { width: 1000, height: 800 } });
    const page = await ctx.newPage();
    await page.goto(MILOS + '/products/catalogizer.html', { waitUntil: 'networkidle' });
    await page.waitForTimeout(300);
    const cfg = await page.evaluate(() => window.MV_PAGE);
    await page.click('#lang-btn');
    await page.waitForTimeout(150);
    await Promise.all([ page.waitForNavigation({ timeout: 5000 }).catch(()=>{}), page.click('#lang-menu button[data-code="de"]') ]);
    const deURL = page.url();
    // graceful: reload EN, delete MV_PAGE, choose FR -> should go to /fr/
    await page.goto(MILOS + '/products/catalogizer.html', { waitUntil: 'networkidle' });
    await page.waitForTimeout(300);
    await page.evaluate(() => { delete window.MV_PAGE; });
    await page.click('#lang-btn');
    await page.waitForTimeout(150);
    await Promise.all([ page.waitForNavigation({ timeout: 5000 }).catch(()=>{}), page.click('#lang-menu button[data-code="fr"]') ]);
    const gracefulURL = page.url();
    results['milos-langswitch'] = { hasMVPAGE: !!cfg, type: cfg && cfg.type, deURL, deOK: deURL.endsWith('/products/de/catalogizer.html'), gracefulURL, gracefulOK: gracefulURL.endsWith('/fr/') };
    await ctx.close();
  }
  // VASIC product: navigate-to-localized (DE)
  {
    const ctx = await browser.newContext({ viewport: { width: 1000, height: 800 } });
    const page = await ctx.newPage();
    await page.goto(VASIC + '/products/catalogizer.html', { waitUntil: 'networkidle' });
    await page.waitForTimeout(400);
    const cfg = await page.evaluate(() => window.OD_PAGE);
    await page.click('#od-lang-btn');
    await page.waitForTimeout(200);
    await Promise.all([ page.waitForNavigation({ timeout: 5000 }).catch(()=>{}), page.click('#od-lang-menu button[data-lang="de"]') ]);
    const deURL = page.url();
    results['vasic-langswitch'] = { hasODPAGE: !!cfg, type: cfg && cfg.type, deURL, deOK: deURL.endsWith('/products/de/catalogizer.html') };
    await ctx.close();
  }
}

const browser = await chromium.launch();
await edgeSpacing(browser, 'milos', MILOS, '/', '/products/catalogizer.html');
await edgeSpacing(browser, 'vasic', VASIC, '/', '/products/catalogizer.html');
await milosModal(browser);
await vasicMenu(browser);
await langSwitch(browser);
await browser.close();
console.log(JSON.stringify(results, null, 2));
