import { chromium } from 'playwright';
const B = 'https://vasic.digital';
const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
const page = await ctx.newPage();
await page.goto(B + '/', { waitUntil: 'networkidle' });
await page.waitForTimeout(500);
const before = page.url();
await page.click('#od-lang-btn');
await page.waitForTimeout(600);
// what's in the opened menu?
const menu = await page.evaluate(() => {
  const links = [...document.querySelectorAll('a[href], [role="menuitem"], [data-lang], button[data-lang]')]
    .filter(a => /ru|Русск|русск/i.test((a.getAttribute('href')||'')+(a.textContent||'')+(a.getAttribute('data-lang')||'')));
  return links.slice(0,8).map(a => ({ tag:a.tagName, href:a.getAttribute('href'), dl:a.getAttribute('data-lang'), txt:a.textContent.trim().slice(0,24), vis: a.getBoundingClientRect().height>0 }));
});
console.log('MENU RU-ish:', JSON.stringify(menu, null, 2));
let result = {};
try {
  // click any visible ru option
  const clicked = await page.evaluate(() => {
    const cand = [...document.querySelectorAll('a[href], [data-lang], [role="menuitem"]')]
      .find(a => a.getBoundingClientRect().height>0 && /(\/ru\/|data-lang="ru"|>ru<|Русск)/i.test(a.outerHTML));
    if (cand){ cand.click(); return cand.outerHTML.slice(0,120); }
    return null;
  });
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(()=>{});
  await page.waitForTimeout(500);
  result = { clicked, before, after: page.url(), navigated: page.url() !== before, isRu: /\/ru\//.test(page.url()) };
} catch(e){ result = { err: String(e).slice(0,150) }; }
console.log('RESULT:', JSON.stringify(result, null, 2));
await browser.close();
