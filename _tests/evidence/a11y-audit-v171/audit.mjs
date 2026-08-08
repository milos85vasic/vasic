// Accessibility audit v1.7.1 — axe-core via Playwright against LIVE sites.
// Audit only; does not modify any site source. Dumps per-page axe JSON + a summary.
import { chromium } from 'playwright';
import { AxeBuilder } from '@axe-core/playwright';
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RAW = join(__dirname, 'raw');
mkdirSync(RAW, { recursive: true });

const AXE_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];

// Test matrix. dark=true toggles data-theme="dark" before scanning.
const TARGETS = [
  // vasic.digital
  { site: 'vasic.digital', id: 'vd-home-light',    url: 'https://vasic.digital/' },
  { site: 'vasic.digital', id: 'vd-home-dark',     url: 'https://vasic.digital/', dark: true },
  { site: 'vasic.digital', id: 'vd-sr',            url: 'https://vasic.digital/sr/' },
  { site: 'vasic.digital', id: 'vd-ar-rtl',        url: 'https://vasic.digital/ar/' },
  { site: 'vasic.digital', id: 'vd-product',       url: 'https://vasic.digital/products/helixtrack.html' },
  { site: 'vasic.digital', id: 'vd-portfolio',     url: 'https://vasic.digital/portfolio/' },
  // milosvasic.ru
  { site: 'milosvasic.ru', id: 'mv-home-light',    url: 'https://milosvasic.ru/' },
  { site: 'milosvasic.ru', id: 'mv-home-dark',     url: 'https://milosvasic.ru/', dark: true },
  { site: 'milosvasic.ru', id: 'mv-sr',            url: 'https://milosvasic.ru/sr/' },
  { site: 'milosvasic.ru', id: 'mv-ar-rtl',        url: 'https://milosvasic.ru/ar/' },
  { site: 'milosvasic.ru', id: 'mv-product',       url: 'https://milosvasic.ru/products/helixtrack.html' },
  { site: 'milosvasic.ru', id: 'mv-portfolio',     url: 'https://milosvasic.ru/portfolio/' },
];

async function collectDom(page) {
  return await page.evaluate(() => {
    const q = (s) => Array.from(document.querySelectorAll(s));
    const htmlEl = document.documentElement;
    // skip link = first anchor with href starting with # that targets an id, usually visually hidden until focus
    const anchors = q('a[href^="#"]');
    const skip = anchors.find(a => /skip|content|main/i.test((a.textContent||'') + (a.getAttribute('href')||'')));
    return {
      lang: htmlEl.getAttribute('lang'),
      dir: htmlEl.getAttribute('dir') || getComputedStyle(htmlEl).direction,
      theme: htmlEl.getAttribute('data-theme'),
      title: document.title,
      landmarks: {
        header: q('header, [role=banner]').length,
        nav: q('nav, [role=navigation]').length,
        main: q('main, [role=main]').length,
        footer: q('footer, [role=contentinfo]').length,
      },
      headings: q('h1,h2,h3,h4,h5,h6').map(h => ({ tag: h.tagName, text: (h.textContent||'').trim().slice(0,60) })),
      h1Count: q('h1').length,
      imgTotal: q('img').length,
      imgNoAlt: q('img:not([alt])').length,
      skipLink: skip ? { text: (skip.textContent||'').trim(), href: skip.getAttribute('href') } : null,
      langSwitcher: q('[class*=lang], [class*=locale], select').length,
    };
  });
}

// Focus-visibility probe: Tab to first focusable and read its computed outline/box-shadow.
async function focusProbe(page) {
  try {
    await page.keyboard.press('Tab');
    return await page.evaluate(() => {
      const el = document.activeElement;
      if (!el || el === document.body) return { focused: null };
      const cs = getComputedStyle(el);
      return {
        focused: el.tagName + (el.className ? '.' + String(el.className).split(' ').filter(Boolean).slice(0,2).join('.') : ''),
        text: (el.textContent||'').trim().slice(0,40),
        outlineStyle: cs.outlineStyle,
        outlineWidth: cs.outlineWidth,
        outlineColor: cs.outlineColor,
        boxShadow: cs.boxShadow,
      };
    });
  } catch (e) { return { error: String(e) }; }
}

const results = [];
const browser = await chromium.launch();

for (const t of TARGETS) {
  const ctx = await browser.newContext({ reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  const rec = { ...t };
  try {
    const resp = await page.goto(t.url, { waitUntil: 'networkidle', timeout: 45000 });
    rec.httpStatus = resp ? resp.status() : null;
    if (t.dark) {
      await page.evaluate(() => document.documentElement.setAttribute('data-theme', 'dark'));
      await page.waitForTimeout(400);
    }
    rec.dom = await collectDom(page);
    rec.focus = await focusProbe(page);

    const axe = await new AxeBuilder({ page }).withTags(AXE_TAGS).analyze();
    // strip large fields for summary, keep full in raw
    writeFileSync(join(RAW, t.id + '.json'), JSON.stringify(axe, null, 2));

    const byImpact = { critical: 0, serious: 0, moderate: 0, minor: 0, null: 0 };
    const rules = {};
    for (const v of axe.violations) {
      const imp = v.impact || 'null';
      byImpact[imp] = (byImpact[imp] || 0) + v.nodes.length;
      rules[v.id] = rules[v.id] || { id: v.id, impact: v.impact, help: v.help, wcag: (v.tags||[]).filter(x=>/wcag/.test(x)), nodes: [] };
      for (const n of v.nodes) {
        const cc = (n.any||[]).concat(n.all||[]).find(c => c.id === 'color-contrast');
        rules[v.id].nodes.push({
          target: n.target,
          html: (n.html||'').slice(0, 220),
          failureSummary: (n.failureSummary||'').slice(0, 300),
          contrast: cc ? cc.data : undefined,
        });
      }
    }
    rec.violationCount = axe.violations.length;
    rec.nodeByImpact = byImpact;
    rec.rules = Object.values(rules);
    rec.passesCount = axe.passes.length;
    rec.incomplete = axe.incomplete.map(i => ({ id: i.id, impact: i.impact, nodes: i.nodes.length }));
  } catch (e) {
    rec.error = String(e);
  }
  results.push(rec);
  console.log(`${t.id}  http=${rec.httpStatus}  violations=${rec.violationCount ?? 'ERR'}  ${rec.error||''}`);
  await ctx.close();
}

await browser.close();
writeFileSync(join(__dirname, 'summary.json'), JSON.stringify(results, null, 2));
console.log('DONE -> summary.json');
