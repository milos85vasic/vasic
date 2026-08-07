import { chromium } from 'playwright';
import { AxeBuilder } from '@axe-core/playwright';
import fs from 'fs';

const B = 'https://vasic.digital';
const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/final-audit-v1.6.0/vasic';
const SS = `${OUT}/screenshots`;
const AX = `${OUT}/axe`;
const IT = `${OUT}/interactive`;
const AS = `${OUT}/assets`;

const results = { screenshots: [], axe: [], interactive: [], assets: [] };

function log(...a){ console.log(...a); }

const browser = await chromium.launch({ headless: true });

// ---------- helper: collect network + console for a page load ----------
async function loadWithLogging(ctx, url, label){
  const page = await ctx.newPage();
  const failed = [];
  const console_errors = [];
  page.on('response', r => {
    const s = r.status();
    if (s >= 400) failed.push({ url: r.url(), status: s, type: r.request().resourceType() });
  });
  page.on('requestfailed', r => {
    failed.push({ url: r.url(), status: 'FAILED:'+(r.failure()?.errorText||'?'), type: r.resourceType() });
  });
  page.on('console', m => { if (m.type() === 'error') console_errors.push(m.text()); });
  page.on('pageerror', e => console_errors.push('PAGEERROR: '+e.message));
  const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
  return { page, failed, console_errors, status: resp?.status() };
}

// ========== 1. SCREENSHOTS (home light+dark 1280, mobile 390) ==========
{
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 1 });
  const { page } = await loadWithLogging(ctx, B + '/', 'home-desktop');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: `${SS}/home-desktop-light-1280.png`, fullPage: false });
  results.screenshots.push('home-desktop-light-1280.png');
  // check computed font-family of h1 to confirm Bricolage rendering (not fallback)
  const h1font = await page.evaluate(() => {
    const h1 = document.querySelector('h1');
    return h1 ? getComputedStyle(h1).fontFamily : 'NO-H1';
  });
  // check that Bricolage font actually loaded
  const fontLoaded = await page.evaluate(async () => {
    await document.fonts.ready;
    const loaded = [];
    document.fonts.forEach(f => { if (f.status === 'loaded') loaded.push(f.family + ' ' + f.weight); });
    return {
      bricolageAvailable: document.fonts.check('700 24px "Bricolage Grotesque"'),
      loadedList: [...new Set(loaded)]
    };
  });
  results.h1font = h1font;
  results.fontLoaded = fontLoaded;
  // dark mode: toggle theme
  const beforeTheme = await page.evaluate(() => document.documentElement.getAttribute('data-theme') || document.documentElement.className);
  // try theme toggle button
  const toggled = await page.evaluate(() => {
    const sel = ['[data-theme-toggle]','.theme-toggle','button[aria-label*="theme" i]','button[aria-label*="dark" i]','#theme-toggle'];
    for (const s of sel){ const el = document.querySelector(s); if (el){ el.click(); return s; } }
    return null;
  });
  await page.waitForTimeout(700);
  const afterTheme = await page.evaluate(() => document.documentElement.getAttribute('data-theme') || document.documentElement.className);
  results.theme = { selector: toggled, before: beforeTheme, after: afterTheme, changed: beforeTheme !== afterTheme };
  await page.screenshot({ path: `${SS}/home-desktop-dark-1280.png`, fullPage: false });
  results.screenshots.push('home-desktop-dark-1280.png');
  await ctx.close();
}
{
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, deviceScaleFactor: 2 });
  const { page } = await loadWithLogging(ctx, B + '/', 'home-mobile');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: `${SS}/home-mobile-390.png`, fullPage: false });
  results.screenshots.push('home-mobile-390.png');
  await ctx.close();
}

// ========== 2. AXE a11y ==========
const axeTargets = [
  { url: B + '/', name: 'en-home' },
  { url: B + '/ru/', name: 'ru-home' },
  { url: B + '/ar/', name: 'ar-home-rtl' },
  { url: B + '/products/ru/catalogizer.html', name: 'ru-product' },
];
for (const t of axeTargets){
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await ctx.newPage();
  await page.goto(t.url, { waitUntil: 'networkidle', timeout: 45000 });
  await page.waitForTimeout(800);
  const res = await new AxeBuilder({ page })
    .withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa'])
    .analyze();
  fs.writeFileSync(`${AX}/axe-${t.name}.json`, JSON.stringify(res, null, 2));
  const sev = { critical:0, serious:0, moderate:0, minor:0 };
  for (const v of res.violations){ sev[v.impact] = (sev[v.impact]||0) + v.nodes.length; }
  results.axe.push({ name: t.name, url: t.url, violations: res.violations.length, severities: sev,
    ids: res.violations.map(v => `${v.id}(${v.impact}:${v.nodes.length})`) });
  log('AXE', t.name, JSON.stringify(sev), 'violations=', res.violations.length);
  await ctx.close();
}

// ========== 3. INTERACTIVE + ASSET INTEGRITY (375/768/1280) ==========
const vpts = [ {w:375,h:812,name:'375'}, {w:768,h:1024,name:'768'}, {w:1280,h:900,name:'1280'} ];
for (const vp of vpts){
  const ctx = await browser.newContext({ viewport: { width: vp.w, height: vp.h }, isMobile: vp.w < 768 });
  const { page, failed, console_errors } = await loadWithLogging(ctx, B + '/', 'home-'+vp.name);
  await page.waitForTimeout(1000);
  // horizontal overflow
  const overflow = await page.evaluate(() => ({
    scrollW: document.documentElement.scrollWidth,
    clientW: document.documentElement.clientWidth,
    overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1
  }));
  // broken images
  const brokenImgs = await page.evaluate(() => {
    return [...document.images].filter(i => i.complete && i.naturalWidth === 0).map(i => i.currentSrc || i.src);
  });
  // back-to-top: scroll down, check appearance
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(900);
  const backToTop = await page.evaluate(() => {
    const sel = ['#back-to-top','.back-to-top','[data-back-to-top]','a[href="#top"]','button[aria-label*="top" i]'];
    for (const s of sel){ const el = document.querySelector(s); if (el){ const st = getComputedStyle(el); const vis = st.display!=='none' && st.visibility!=='hidden' && parseFloat(st.opacity)>0.05; return { found:true, selector:s, visible:vis }; } }
    return { found:false };
  });
  await page.evaluate(() => window.scrollTo(0,0));
  results.interactive.push({ vp: vp.name, overflow, brokenImgs, backToTop, console_errors, http_failed: failed });
  results.assets.push({ page: 'home', vp: vp.name, failed });
  log('INT', vp.name, 'overflow=', overflow.overflow, 'broken=', brokenImgs.length, 'b2t=', JSON.stringify(backToTop), 'consoleErr=', console_errors.length, 'netFail=', failed.length);
  await ctx.close();
}

// ========== 4. Nav click + language switcher (desktop) ==========
{
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await ctx.newPage();
  await page.goto(B + '/', { waitUntil: 'networkidle', timeout: 45000 });
  await page.waitForTimeout(600);
  // nav click: find an in-page nav link and click
  const navInfo = await page.evaluate(() => {
    const links = [...document.querySelectorAll('header a[href], nav a[href]')].filter(a => a.getAttribute('href') && a.getAttribute('href') !== '#');
    return { count: links.length, sample: links.slice(0,6).map(a => ({ text:a.textContent.trim().slice(0,20), href:a.getAttribute('href') })) };
  });
  // click first anchor nav (#) link to test smooth-scroll nav
  let navClick = null;
  try {
    const anchor = await page.$('header a[href^="#"], nav a[href^="#"]');
    if (anchor){ const href = await anchor.getAttribute('href'); await anchor.click(); await page.waitForTimeout(700); navClick = { clicked: href, ok:true }; }
  } catch(e){ navClick = { ok:false, err:String(e) }; }
  // language switcher: navigate to a localized home
  let langSwitch = null;
  try {
    const before = page.url();
    // find language switcher link to /ru/ or similar
    const langLink = await page.$('a[href$="/ru/"], a[href*="/ru/"], [data-lang="ru"], .lang-switcher a[href*="ru"]');
    if (langLink){
      await langLink.click();
      await page.waitForLoadState('networkidle', { timeout: 20000 }).catch(()=>{});
      await page.waitForTimeout(500);
      langSwitch = { ok:true, before, after: page.url(), navigated: page.url() !== before };
    } else {
      langSwitch = { ok:false, reason:'no ru lang link found on home' };
    }
  } catch(e){ langSwitch = { ok:false, err:String(e) }; }
  results.nav = { navInfo, navClick, langSwitch };
  log('NAV', JSON.stringify(results.nav).slice(0,300));
  await ctx.close();
}

// ========== 5. Asset integrity on a product page ==========
{
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const { page, failed, console_errors } = await loadWithLogging(ctx, B + '/products/ru/catalogizer.html', 'product');
  await page.waitForTimeout(800);
  const brokenImgs = await page.evaluate(() => [...document.images].filter(i => i.complete && i.naturalWidth === 0).map(i => i.currentSrc || i.src));
  results.assets.push({ page: 'products/ru/catalogizer.html', vp:'1280', failed, brokenImgs, console_errors });
  log('PRODUCT-ASSETS failed=', failed.length, 'broken=', brokenImgs.length, 'consoleErr=', console_errors.length);
  await ctx.close();
}

await browser.close();
fs.writeFileSync(`${OUT}/browser-results.json`, JSON.stringify(results, null, 2));
log('\n=== DONE ===');
log('h1 font:', results.h1font);
log('font loaded:', JSON.stringify(results.fontLoaded));
log('theme:', JSON.stringify(results.theme));
