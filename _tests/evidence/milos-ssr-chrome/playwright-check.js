const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('/Volumes/T7/Projects/vasic/_tests/node_modules/playwright');

const ROOT = '/Volumes/T7/Projects/vasic/milosvasic.ru/_site';
const MIME = { '.html':'text/html', '.js':'application/javascript', '.css':'text/css', '.json':'application/json', '.svg':'image/svg+xml', '.jpg':'image/jpeg', '.png':'image/png', '.woff2':'font/woff2', '.woff':'font/woff', '.pdf':'application/pdf' };

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  let fp = path.join(ROOT, p);
  try { if (fs.statSync(fp).isDirectory()) fp = path.join(fp, 'index.html'); } catch(e){}
  fs.readFile(fp, (err, data) => {
    if (err) { res.writeHead(404); res.end('404'); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(fp)] || 'application/octet-stream' });
    res.end(data);
  });
});

(async () => {
  await new Promise(r => server.listen(0, r));
  const port = server.address().port;
  const base = `http://127.0.0.1:${port}`;
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const out = {};

  // 1. Load Russian page — check SSR + runtime-consistent Russian chrome
  await page.goto(`${base}/products/ru/helixcode.html`, { waitUntil: 'networkidle' });
  out.ru_htmlLang = await page.getAttribute('html', 'lang');
  out.ru_dir = await page.getAttribute('html', 'dir');
  out.ru_navWork = (await page.textContent('[data-i18n="nav.work"]')).trim();
  out.ru_navContact = (await page.textContent('[data-i18n="nav.contact"]')).trim();
  out.ru_skip = (await page.textContent('[data-i18n="a11y.skip"]')).trim();

  // 2. Switch language at runtime via the lang switcher to German, verify JS still works
  await page.click('#lang-btn');
  await page.waitForSelector('#lang-menu [data-lang="de"], #lang-menu button', { timeout: 3000 }).catch(()=>{});
  // click the German entry (menu items rendered by i18n.js)
  const clicked = await page.evaluate(() => {
    const items = Array.from(document.querySelectorAll('#lang-menu [data-lang], #lang-menu button, #lang-menu a'));
    const de = items.find(el => (el.getAttribute('data-lang')||'').toLowerCase()==='de' || /deutsch/i.test(el.textContent));
    if (de) { de.click(); return true; }
    return false;
  });
  out.de_switchClicked = clicked;
  await page.waitForTimeout(400);
  out.after_navWork = (await page.textContent('[data-i18n="nav.work"]')).trim();
  out.after_htmlLang = await page.getAttribute('html', 'lang');

  console.log(JSON.stringify(out, null, 2));
  await browser.close();
  server.close();
})().catch(e => { console.error('ERR', e); process.exit(1); });
