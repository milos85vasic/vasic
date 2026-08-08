import { chromium } from 'playwright';
const b = await chromium.launch();
const p = await b.newPage();
await p.goto('file:///tmp/v180vd/vasic.digital/index.html', {waitUntil:'networkidle'});
const r = await p.evaluate(() => {
  const el = document.querySelector('h1');
  const cs = getComputedStyle(el);
  return { h1FontFamily: cs.fontFamily, tokenDisplay: getComputedStyle(document.documentElement).getPropertyValue('--od-font-display').trim() };
});
console.log(JSON.stringify(r,null,2));
await b.close();
