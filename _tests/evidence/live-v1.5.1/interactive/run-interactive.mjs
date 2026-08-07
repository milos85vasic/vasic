import { chromium } from 'playwright';
import fs from 'fs';

const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.5.1/interactive';
const SHOT = '/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.5.1/screenshots';
const sites = [
  { key: 'vasic', url: 'https://vasic.digital/', navSel: 'a.od-nav__link[href="portfolio/"]', navExpect: '/portfolio/' },
  { key: 'milos', url: 'https://milosvasic.ru/', navSel: 'a[href="/#work"]', navExpect: '#work' },
];
const viewports = [375, 768, 1280];
const results = [];
const browser = await chromium.launch();

for (const site of sites) {
  for (const w of viewports) {
    const r = { site: site.key, viewport: w };
    const ctx = await browser.newContext({ viewport: { width: w, height: 900 }, deviceScaleFactor: 1 });
    const page = await ctx.newPage();
    try {
      await page.goto(site.url, { waitUntil: 'networkidle', timeout: 45000 });

      // horizontal overflow
      const overflow = await page.evaluate(() => ({
        scrollW: document.documentElement.scrollWidth,
        innerW: window.innerWidth,
      }));
      r.horizontalOverflow = overflow.scrollW > overflow.innerW + 2 ? `OVERFLOW(${overflow.scrollW}>${overflow.innerW})` : 'none';

      // scroll to bottom to trigger lazy content + back-to-top
      await page.evaluate(async () => {
        await new Promise(res => { let y = 0; const t = setInterval(() => { window.scrollBy(0, 600); y += 600; if (y >= document.body.scrollHeight) { clearInterval(t); res(); } }, 40); });
      });
      await page.waitForTimeout(800);

      // broken images (after full scroll)
      const brokenImgs = await page.evaluate(() => Array.from(document.images)
        .filter(im => im.currentSrc && im.complete && im.naturalWidth === 0)
        .map(im => im.currentSrc));
      r.brokenImages = brokenImgs.length ? brokenImgs : 'none';
      r.imgCount = await page.evaluate(() => document.images.length);

      // back-to-top visible after scroll
      const btt = await page.evaluate(() => {
        const el = document.querySelector('.od-to-top');
        if (!el) return { present: false };
        const cs = getComputedStyle(el);
        const rect = el.getBoundingClientRect();
        const visible = cs.display !== 'none' && cs.visibility !== 'hidden' && parseFloat(cs.opacity) > 0.05 && rect.width > 0;
        return { present: true, visible, opacity: cs.opacity };
      });
      r.backToTop = btt.present ? (btt.visible ? `visible(op=${btt.opacity})` : `PRESENT_BUT_HIDDEN(op=${btt.opacity})`) : 'MISSING';

      // click back-to-top -> scroll to top
      if (btt.present && btt.visible) {
        await page.click('.od-to-top');
        await page.waitForTimeout(700);
        const y = await page.evaluate(() => window.scrollY);
        r.backToTopClick = y < 50 ? `OK(y=${y})` : `FAIL(y=${y})`;
      }

      // screenshot
      await page.screenshot({ path: `${SHOT}/${site.key}-${w}.png`, fullPage: false });

      // mobile hamburger (milos @375)
      if (site.key === 'milos' && w === 375) {
        await page.evaluate(() => window.scrollTo(0, 0));
        await page.waitForTimeout(300);
        const before = await page.getAttribute('#nav-toggle', 'aria-expanded');
        await page.click('#nav-toggle');
        await page.waitForTimeout(400);
        const after = await page.getAttribute('#nav-toggle', 'aria-expanded');
        const menuVisible = await page.evaluate(() => {
          const m = document.querySelector('#nav-links');
          if (!m) return false;
          const cs = getComputedStyle(m); const rect = m.getBoundingClientRect();
          return cs.display !== 'none' && cs.visibility !== 'hidden' && rect.height > 0;
        });
        r.hamburger = `expanded ${before}->${after}, menuVisible=${menuVisible}` + ((after === 'true' && menuVisible) ? ' OK' : ' CHECK');
      }

      // nav click navigates (desktop 1280)
      if (w === 1280) {
        await page.evaluate(() => window.scrollTo(0, 0));
        const has = await page.$(site.navSel);
        if (has) {
          await page.click(site.navSel);
          await page.waitForTimeout(700);
          const u = page.url();
          r.navClick = u.includes(site.navExpect) ? `OK(${u})` : `CHECK(${u})`;
        } else {
          r.navClick = `SELECTOR_NOT_FOUND(${site.navSel})`;
        }
      }
    } catch (e) {
      r.error = String(e);
    }
    results.push(r);
    console.log(JSON.stringify(r));
    await page.close(); await ctx.close();
  }
}
await browser.close();
fs.writeFileSync(`${OUT}/interactive-results.json`, JSON.stringify(results, null, 2));
console.log('DONE');
