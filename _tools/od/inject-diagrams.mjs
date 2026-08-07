#!/usr/bin/env node
// Inject generated OpenDesign SVG diagrams into product pages at their
// <figure ... data-slug="SLUG"> placeholder. If no diagram exists for a slug,
// strip the empty placeholder so no blank figure ships.
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const DIAG = 'design-system/diagrams';
const sites = ['vasic.digital/products', 'milosvasic.ru/products'];
let injected = 0, stripped = 0, missing = 0;

for (const site of sites) {
  for (const f of readdirSync(site).filter((x) => x.endsWith('.html'))) {
    const slug = f.replace(/\.html$/, '');
    const p = join(site, f);
    let html = readFileSync(p, 'utf8');
    const re = new RegExp(`<figure\\b[^>]*\\bdata-slug="${slug}"[^>]*>[\\s\\S]*?<\\/figure>`, 'i');
    if (!re.test(html)) { missing++; continue; }
    const svgPath = join(DIAG, `${slug}.svg`);
    if (existsSync(svgPath)) {
      const svg = readFileSync(svgPath, 'utf8').replace(/<\?xml[^>]*\?>\s*/i, '');
      const fig = `<figure class="od-diagram" data-slug="${slug}">\n${svg}\n<figcaption class="od-section__eyebrow" style="margin-top:var(--od-space-2)">// architecture</figcaption>\n</figure>`;
      html = html.replace(re, fig);
      injected++;
    } else {
      html = html.replace(re, '');
      stripped++;
    }
    writeFileSync(p, html);
  }
}
console.log(`injected=${injected} stripped=${stripped} noPlaceholder=${missing}`);
