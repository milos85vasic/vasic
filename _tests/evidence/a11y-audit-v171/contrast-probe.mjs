// Manual pixel-level contrast measurement for elements axe flagged as INCOMPLETE
// (gradient/overlap backgrounds). Renders the live page, screenshots each element,
// finds the darkest & lightest pixels (text vs background) inside its box, and
// computes WCAG contrast between the extreme luminances = worst realistic case.
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const TARGETS = [
  { url: 'https://vasic.digital/', sels: ['a[href$="#work"]', 'a[data-i18n="nav.products"]', '.od-brand', 'h1'] },
  { url: 'https://milosvasic.ru/', sels: ['.brand', 'nav a', 'h1'] },
];

function relLum([r, g, b]) {
  const c = [r, g, b].map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
function ratio(a, b) { const L1 = relLum(a), L2 = relLum(b); const hi = Math.max(L1, L2), lo = Math.min(L1, L2); return (hi + 0.05) / (lo + 0.05); }
const hex = ([r, g, b]) => '#' + [r, g, b].map(v => v.toString(16).padStart(2, '0')).join('');

const browser = await chromium.launch();
for (const t of TARGETS) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  await page.goto(t.url, { waitUntil: 'networkidle' });
  console.log('\n==== ' + t.url + ' ====');
  for (const sel of t.sels) {
    const el = page.locator(sel).first();
    const n = await el.count();
    if (!n) { console.log(sel + ': (not found)'); continue; }
    const color = await el.evaluate(e => getComputedStyle(e).color).catch(() => '?');
    let buf;
    try { buf = await el.screenshot(); } catch (e) { console.log(sel + ': screenshot failed ' + e); continue; }
    const png = PNG.sync.read(buf);
    // collect luminance extremes
    let dark = null, light = null, dL = 2, lL = -1;
    for (let i = 0; i < png.data.length; i += 4) {
      const a = png.data[i + 3]; if (a < 200) continue;
      const px = [png.data[i], png.data[i + 1], png.data[i + 2]];
      const L = relLum(px);
      if (L < dL) { dL = L; dark = px; }
      if (L > lL) { lL = L; light = px; }
    }
    if (!dark || !light) { console.log(sel + ': no opaque pixels'); continue; }
    const r = ratio(dark, light);
    console.log(`${sel}: computed color=${color} | darkest=${hex(dark)} lightest=${hex(light)} => extreme contrast=${r.toFixed(2)}:1`);
  }
  await page.close();
}
await browser.close();
