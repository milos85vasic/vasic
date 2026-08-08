// v180-apply verification: in-browser token proof, screenshots (1280x900 to
// match STAGE-vd-*.png), and WCAG contrast ratios (light + dark).
import { chromium } from 'playwright';
import { createServer } from 'http';
import { readFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { extname, join, normalize } from 'path';

const ROOT = '/tmp/v180vd/vasic.digital';
const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/v180-apply';
const PORT = 8791;

const MIME = {
  '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
  '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp',
  '.json': 'application/json', '.ico': 'image/x-icon', '.avif': 'image/avif',
  '.txt': 'text/plain', '.xml': 'application/xml',
};

const server = createServer(async (req, res) => {
  try {
    let p = decodeURIComponent(req.url.split('?')[0]);
    if (p.endsWith('/')) p += 'index.html';
    const fp = normalize(join(ROOT, p));
    if (!fp.startsWith(ROOT) || !existsSync(fp)) { res.writeHead(404); res.end('nf'); return; }
    const body = await readFile(fp);
    res.writeHead(200, { 'Content-Type': MIME[extname(fp)] || 'application/octet-stream' });
    res.end(body);
  } catch (e) { res.writeHead(500); res.end(String(e)); }
});
await new Promise(r => server.listen(PORT, r));
const base = `http://127.0.0.1:${PORT}`;

// --- WCAG helpers ---------------------------------------------------------
function parseColor(s) {
  s = s.trim();
  let m = s.match(/^#([0-9a-f]{6})$/i);
  if (m) { const n = parseInt(m[1], 16); return [(n>>16)&255,(n>>8)&255,n&255]; }
  m = s.match(/^#([0-9a-f]{3})$/i);
  if (m) return m[1].split('').map(c => parseInt(c+c,16));
  m = s.match(/rgba?\(([^)]+)\)/i);
  if (m) { const p = m[1].split(',').map(x=>parseFloat(x)); return [p[0],p[1],p[2]]; }
  throw new Error('cannot parse color: ' + s);
}
function relLum([r,g,b]) {
  const f = v => { v/=255; return v<=0.03928 ? v/12.92 : Math.pow((v+0.055)/1.055,2.4); };
  return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b);
}
function contrast(a,b) {
  const L1=relLum(parseColor(a)), L2=relLum(parseColor(b));
  const hi=Math.max(L1,L2), lo=Math.min(L1,L2);
  return (hi+0.05)/(lo+0.05);
}

async function readTokens(page) {
  return await page.evaluate(() => {
    const cs = getComputedStyle(document.documentElement);
    const g = n => cs.getPropertyValue(n).trim();
    // resolved USED color: element that actually paints with var(--od-accent)
    const probe = document.createElement('div');
    probe.style.color = 'var(--od-accent)';
    probe.style.backgroundColor = 'var(--od-accent-700)';
    document.body.appendChild(probe);
    const pc = getComputedStyle(probe);
    const used_accent = pc.color;
    const used_accent700 = pc.backgroundColor;
    probe.remove();
    return {
      accent700: g('--od-accent-700'), accent: g('--od-accent'),
      bg: g('--od-bg'), text: g('--od-text'),
      onAccent: g('--od-on-accent'),
      used_accent, used_accent700,
    };
  });
}

const browser = await chromium.launch();
const results = { proof: {}, contrast: {}, shots: [] };

const pages = [
  ['home', '/index.html'],
  ['product', '/products/helixagent.html'],
  ['portfolio', '/portfolio/index.html'],
];

for (const scheme of ['light', 'dark']) {
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 900 },
    colorScheme: scheme,
    deviceScaleFactor: 1,
  });
  for (const [name, path] of pages) {
    const page = await ctx.newPage();
    await page.goto(base + path, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(400);

    const tok = await readTokens(page);
    if (name === 'home') {
      results.proof[scheme] = tok;
      results.contrast[scheme] = {
        'text/bg': +contrast(tok.text, tok.bg).toFixed(2),
        'on-accent/accent': +contrast(tok.onAccent, tok.used_accent).toFixed(2),
      };
    }
    const file = join(OUT, `vd-${name}-${scheme}.png`);
    // viewport shot (matches STAGE 1280x900) for direct comparison
    await page.screenshot({ path: file, fullPage: false });
    results.shots.push(file);
    // full-page shot too (task asks for full-page)
    const ffile = join(OUT, `vd-${name}-${scheme}-full.png`);
    await page.screenshot({ path: ffile, fullPage: true });
    results.shots.push(ffile);
    await page.close();
  }
  await ctx.close();
}

await browser.close();
server.close();

console.log(JSON.stringify(results, null, 2));
