import { chromium } from 'playwright';
const B = 'https://vasic.digital';
const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
const page = await ctx.newPage();
await page.goto(B + '/', { waitUntil: 'networkidle' });
await page.waitForTimeout(600);

// Inspect the /ru/ link's ancestry + visibility
const info = await page.evaluate(() => {
  const a = document.querySelector('a[href="https://vasic.digital/ru/"], a[href$="/ru/"]');
  if (!a) return { found:false };
  const r = a.getBoundingClientRect();
  const st = getComputedStyle(a);
  let anc = [];
  let el = a.parentElement; let depth=0;
  while (el && depth<5){ anc.push({ tag: el.tagName, cls: el.className, id: el.id, disp: getComputedStyle(el).display, hidden: el.hidden }); el = el.parentElement; depth++; }
  return { found:true, visible: r.width>0 && r.height>0 && st.display!=='none', rect:{w:r.width,h:r.height}, display:st.display, ancestry: anc };
});
console.log('RU LINK:', JSON.stringify(info, null, 2));

// find a toggle button that reveals language menu
const toggleTry = await page.evaluate(() => {
  const cands = [...document.querySelectorAll('button, [role="button"], a')].filter(b => {
    const t = (b.getAttribute('aria-label')||'') + ' ' + (b.className||'') + ' ' + (b.id||'') + ' ' + b.textContent;
    return /lang|locale|globe|🌐|translat/i.test(t);
  });
  return cands.map(c => ({ tag:c.tagName, aria:c.getAttribute('aria-label'), cls:c.className, id:c.id, txt:c.textContent.trim().slice(0,20) }));
});
console.log('TOGGLE CANDIDATES:', JSON.stringify(toggleTry, null, 2));

// Attempt: click first candidate then click /ru/
let result = { navigated:false };
if (toggleTry.length){
  try {
    const btn = await page.$('button[aria-label*="lang" i], button[aria-label*="Language" i], [aria-label*="lang" i]');
    if (btn){ await btn.click(); await page.waitForTimeout(500); }
  } catch(e){ console.log('toggle click err', String(e).slice(0,100)); }
}
try {
  const before = page.url();
  await page.click('a[href="https://vasic.digital/ru/"], a[href$="/ru/"]', { timeout: 8000 });
  await page.waitForLoadState('networkidle', { timeout:15000 }).catch(()=>{});
  result = { navigated: page.url()!==before, before, after: page.url() };
} catch(e){
  // fallback: direct navigation works regardless (link href is valid)
  result = { clickFailed: String(e).slice(0,120) };
}
console.log('SWITCH RESULT:', JSON.stringify(result));
await browser.close();
