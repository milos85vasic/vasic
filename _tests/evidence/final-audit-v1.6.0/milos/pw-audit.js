const { chromium } = require('playwright');
const fs = require('fs');
const DIR = __dirname;
const BASE = 'https://milosvasic.ru';

async function collect(page) {
  const errors = [];
  const bad = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('PAGEERROR: ' + e.message));
  page.on('response', r => { if (r.status() >= 400) bad.push(r.status() + ' ' + r.url()); });
  return { errors, bad };
}

async function main() {
  const browser = await chromium.launch();
  const result = {};

  // ---- Screenshots + design render (desktop 1280 light/dark, mobile 390) ----
  for (const [name, w, h, theme] of [
    ['home-desktop-light', 1280, 900, 'light'],
    ['home-desktop-dark', 1280, 900, 'dark'],
    ['home-mobile-390', 390, 844, 'light'],
  ]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, colorScheme: theme, deviceScaleFactor: 1 });
    const page = await ctx.newPage();
    const { errors, bad } = await collect(page);
    await page.goto(BASE + '/', { waitUntil: 'networkidle' });
    if (theme === 'dark') {
      // force dark via toggle attribute if site uses data-theme
      await page.evaluate(() => document.documentElement.setAttribute('data-theme', 'dark'));
      await page.waitForTimeout(300);
    }
    await page.screenshot({ path: `${DIR}/shot-${name}.png`, fullPage: false });
    await page.screenshot({ path: `${DIR}/shot-${name}-full.png`, fullPage: true });
    // font render check on hero title
    const design = await page.evaluate(() => {
      const el = document.querySelector('.od-hero__title, h1');
      const cs = el ? getComputedStyle(el) : null;
      // Anton loaded?
      const antonLoaded = document.fonts ? [...document.fonts].some(f => /anton/i.test(f.family) && f.status === 'loaded') : null;
      // red-line profile decorations: look for elements with red-ish borders/lines
      const redEls = [...document.querySelectorAll('*')].filter(e => {
        const s = getComputedStyle(e);
        const c = (s.borderTopColor + s.borderLeftColor + s.backgroundColor + s.color + s.outlineColor);
        return /rgb\(2[0-4][0-9],\s*[0-6][0-9],|rgb\(2[0-9][0-9],\s*[0-5][0-9],\s*[0-5]/.test(c);
      }).length;
      return {
        heroFont: cs ? cs.fontFamily : null,
        heroFontSize: cs ? cs.fontSize : null,
        heroTransform: cs ? cs.textTransform : null,
        antonLoaded,
        redAccentElements: redEls,
        htmlTheme: document.documentElement.getAttribute('data-theme'),
      };
    });
    result[name] = { viewport: `${w}x${h}`, theme, design, consoleErrors: errors, badResponses: bad };
    await ctx.close();
  }

  // ---- Interactive behavior at 375 / 768 / 1280 ----
  result.interactive = {};
  for (const w of [375, 768, 1280]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: 900 } });
    const page = await ctx.newPage();
    const { errors, bad } = await collect(page);
    await page.goto(BASE + '/', { waitUntil: 'networkidle' });
    const r = { consoleErrors: errors, badResponses: bad };

    // horizontal overflow
    r.horizontalOverflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1 ? (document.documentElement.scrollWidth + '>' + window.innerWidth) : false);

    // broken images
    r.brokenImages = await page.evaluate(() => [...document.images].filter(i => i.complete && i.naturalWidth === 0).map(i => i.currentSrc || i.src));

    // hamburger (expect present <=760)
    const ham = await page.$('[aria-controls][aria-expanded], button.od-nav__toggle, .hamburger, [data-nav-toggle], button[aria-label*="menu" i]');
    if (ham) {
      const before = await ham.getAttribute('aria-expanded');
      await ham.click().catch(()=>{});
      await page.waitForTimeout(300);
      const after = await ham.getAttribute('aria-expanded');
      r.hamburger = { present: true, ariaBefore: before, ariaAfter: after, toggled: before !== after };
      // close again
      await ham.click().catch(()=>{});
      await page.waitForTimeout(200);
    } else {
      r.hamburger = { present: false };
    }

    // theme toggle
    const themeBtn = await page.$('[data-theme-toggle], button[aria-label*="theme" i], button[aria-label*="dark" i], .theme-toggle, #theme-toggle');
    if (themeBtn) {
      const b = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
      await themeBtn.click().catch(()=>{});
      await page.waitForTimeout(300);
      const a = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
      r.themeToggle = { present: true, before: b, after: a, changed: b !== a };
    } else {
      r.themeToggle = { present: false };
    }

    // language switcher: open + count options
    const langBtn = await page.$('[data-lang-toggle], .lang-menu button, button[aria-label*="lang" i], .lang-switch, [aria-controls*="lang" i]');
    if (langBtn) {
      await langBtn.click().catch(()=>{});
      await page.waitForTimeout(400);
      const opts = await page.evaluate(() => {
        const links = [...document.querySelectorAll('a[href^="/"], a[hreflang], [role="menuitem"], .lang-menu a, [class*="lang"] a')];
        const langs = new Set();
        links.forEach(a => { const m = (a.getAttribute('hreflang') || (a.getAttribute('href')||'').match(/^\/([a-z]{2})\/?$/)?.[1]); if (m) langs.add(m); });
        return [...langs];
      });
      r.langSwitcher = { present: true, langsFound: opts, count: opts.length };
    } else {
      r.langSwitcher = { present: false };
    }

    // download modal
    const dlTrig = await page.$('[data-dl="cv"], [data-dl]');
    if (dlTrig) {
      await dlTrig.click().catch(()=>{});
      await page.waitForTimeout(400);
      const dl = await page.evaluate(() => {
        const m = document.getElementById('dl-modal');
        const rows = m ? m.querySelectorAll('.dl-lang').length : 0;
        const open = m ? (!m.hidden && m.classList.contains('open')) : false;
        return { open, rows };
      });
      r.downloadModal = { present: true, ...dl };
      // close
      await page.keyboard.press('Escape').catch(()=>{});
      await page.waitForTimeout(200);
    } else {
      r.downloadModal = { present: false };
    }

    // back-to-top
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(400);
    const btt = await page.$('[data-back-to-top], .back-to-top, a[href="#top"], button[aria-label*="top" i], #back-to-top');
    r.backToTop = { present: !!btt };
    if (btt) {
      const vis = await btt.isVisible().catch(()=>false);
      r.backToTop.visibleAfterScroll = vis;
    }

    // article viewer trigger
    const artTrig = await page.$('[data-article]');
    r.articleViewer = { triggerPresent: !!artTrig };
    if (artTrig) {
      await artTrig.click().catch(()=>{});
      await page.waitForTimeout(500);
      r.articleViewer.opened = await page.evaluate(() => !!document.querySelector('.mv-article-modal, [class*="article-modal"]'));
      await page.keyboard.press('Escape').catch(()=>{});
    }

    result.interactive['w' + w] = r;
    await ctx.close();
  }

  // ---- Network 404 scan: home + product page ----
  result.network = {};
  for (const [label, url] of [['home', '/'], ['product', '/products/helixtrack.html']]) {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await ctx.newPage();
    const { errors, bad } = await collect(page);
    await page.goto(BASE + url, { waitUntil: 'networkidle' });
    await page.waitForTimeout(500);
    result.network[label] = { url, badResponses: bad, consoleErrors: errors };
    await ctx.close();
  }

  fs.writeFileSync(`${DIR}/pw-audit-results.json`, JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
  await browser.close();
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
