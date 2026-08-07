#!/usr/bin/env node
/*
 * Render the unified /portfolio/ web section for BOTH sites from
 * _content/portfolio/portfolio.json (single source of truth → identical set).
 *
 * Output:
 *   vasic.digital/portfolio/index.html   (company brand)
 *   milosvasic.ru/portfolio/index.html   (personal brand)
 *
 * OpenDesign tokens/components only (§11.4.162). Skip link, no-FOUC data-theme
 * bootstrap + toggle. Additive: touches no existing index.html/CSS.
 */
'use strict';

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const data = JSON.parse(fs.readFileSync(path.join(ROOT, '_content', 'portfolio', 'portfolio.json'), 'utf8'));

const esc = (s) => String(s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

const TIER_META = {
  'helix-primary': { eyebrow: '// tier 1 — flagship', title: 'Helix family & LLM infrastructure' },
  'vasic-util-secondary': { eyebrow: '// tier 2 — utilities', title: 'Vasic Digital utilities' },
  'serverfactory-tertiary': { eyebrow: '// tier 3 — heritage', title: 'Server Factory' },
};

const LEDE = 'A unified, evidence-based portfolio of the Helix family, vasic-digital utilities, and the Server Factory toolchain.';
const SUMMARY = 'One fleet: large product applications on top of dozens of small, decoupled, independently-tested modules — governed by a shared engineering Constitution and verified by anti-bluff QA. The dominant language is Go, with Kotlin/KMP, TypeScript/React, Python, Swift, and Shell where they fit best. The unifying thesis: a feature is done only when a real user can use it and there is captured evidence to prove it.';

const BRANDS = [
  {
    key: 'vasic-digital',
    css: '../../design-system/brand-vasic-digital/vasic-digital.css',
    out: path.join(ROOT, 'vasic.digital', 'portfolio', 'index.html'),
    name: 'Vasic Digital',
    lang: 'en',
    footer: '© 2026 Vasic Digital — built on the OpenDesign system',
  },
  {
    key: 'milosvasic',
    css: '../../design-system/brand-milosvasic/milosvasic.css',
    out: path.join(ROOT, 'milosvasic.ru', 'portfolio', 'index.html'),
    name: 'Miloš Vasić',
    lang: 'en',
    footer: '© 2026 Miloš Vasić — built on the OpenDesign system',
  },
];

function card(e) {
  const chips = e.tech.slice(0, 6).map((t) => `<span class="od-chip">${esc(t)}</span>`).join('');
  const more = e.tech.length > 6 ? `<span class="od-chip">+${e.tech.length - 6}</span>` : '';
  const lic = (e.license && !/^(unverified|tbd)/i.test(e.license))
    ? `<span class="od-tag--license">${esc(e.license)}</span>` : '';
  const href = `../products/${esc(e.slug)}.html`;
  return `        <article class="od-card od-product-card" style="padding:var(--od-space-6)">
          <h3 class="od-product-card__title">${esc(e.name)} <span class="od-badge--status od-badge--status--${esc(e.status)}">${esc(e.status)}</span></h3>
          <div class="od-product-card__tech">${chips}${more}</div>
          <p class="pf-card__blurb">${esc(e.tagline || e.summary)}</p>
          <div class="pf-card__meta">${lic}</div>
          <div class="pf-card__actions"><a class="od-btn od-btn--secondary" href="${href}">Read more</a></div>
        </article>`;
}

function tierSection(tier) {
  const meta = TIER_META[tier];
  const list = data.entries.filter((e) => e.tier === tier);
  const cards = list.map(card).join('\n');
  return `    <section class="od-section">
      <p class="od-section__eyebrow">${esc(meta.eyebrow)}</p>
      <h2 class="od-section__title">${esc(meta.title)} <span class="od-chip">${list.length}</span></h2>
      <div class="pf-grid">
${cards}
      </div>
    </section>`;
}

const PAGE_STYLE = `  <style>
    .pf-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:var(--od-space-6);align-items:stretch;}
    .od-product-card__tech{display:flex;flex-wrap:wrap;gap:var(--od-space-2);}
    .pf-card__blurb{font-size:var(--od-fs-base);line-height:var(--od-lh-normal);color:var(--od-text);margin:0 0 var(--od-space-4);}
    .pf-card__meta{display:flex;flex-wrap:wrap;gap:var(--od-space-2);}
    .pf-card__meta:empty{display:none;}
    .pf-card__actions{margin-top:auto;padding-top:var(--od-space-3);}
    .pf-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:var(--od-space-6);max-width:48rem;margin:var(--od-space-8) auto 0;}
    /* status badge extensions — OpenDesign tokens only (§11.4.162) */
    .od-badge--status--production,.od-badge--status--shipped,.od-badge--status--active,.od-badge--status--stable{background-color:var(--od-success);color:var(--od-on-accent);}
    .od-badge--status--scaffold,.od-badge--status--mixed{background-color:var(--od-surface-2);color:var(--od-text);}
    /* skip link stays keyboard-focusable but is excluded from the visible layout until focused */
    .od-skip-link{opacity:0;}
    .od-skip-link:focus{opacity:1;}
  </style>`;

const NOFOUC = `  <script>(function(){try{var t=localStorage.getItem('od-theme');if(t==='dark'||t==='light'){document.documentElement.setAttribute('data-theme',t);}}catch(e){}})();</script>`;

const TOGGLE = `  <script>
    (function(){
      var btn=document.getElementById('pf-theme-toggle');
      if(!btn)return;
      function cur(){var a=document.documentElement.getAttribute('data-theme');if(a)return a;return (window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches)?'dark':'light';}
      btn.addEventListener('click',function(){var n=cur()==='dark'?'light':'dark';document.documentElement.setAttribute('data-theme',n);try{localStorage.setItem('od-theme',n);}catch(e){}});
    })();
  </script>`;

for (const b of BRANDS) {
  const sections = data.tiers.map(tierSection).join('\n\n');
  const html = `<!doctype html>
<html lang="${b.lang}">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Portfolio — ${esc(b.name)}</title>
  <meta name="description" content="${esc(LEDE)}"/>
  <link rel="stylesheet" href="${b.css}"/>
${NOFOUC}
${PAGE_STYLE}
</head>
<body>
  <a class="od-skip-link" href="#main">Skip to content</a>
  <header class="od-header">
    <a class="od-nav__link" href="../index.html" style="font-family:var(--od-font-display);font-weight:700">${esc(b.name)}</a>
    <nav class="od-nav">
      <a class="od-nav__link" href="../index.html">Home</a>
      <a class="od-nav__link" href="#main">Portfolio</a>
      <button class="od-btn od-btn--ghost" id="pf-theme-toggle" type="button" aria-label="Toggle color theme">Theme</button>
    </nav>
  </header>

  <main id="main">
    <section class="od-hero">
      <p class="od-section__eyebrow">// unified portfolio</p>
      <h1 class="od-hero__title">Portfolio</h1>
      <p class="od-hero__lede">${esc(LEDE)}</p>
      <div class="pf-stats">
        <div class="od-stat"><div class="od-stat__value">${data.count}</div><div class="od-stat__label">Products</div></div>
        <div class="od-stat"><div class="od-stat__value">3</div><div class="od-stat__label">Tiers</div></div>
        <div class="od-stat"><div class="od-stat__value">${data.entries.filter(e=>e.tier==='helix-primary').length}</div><div class="od-stat__label">Helix products</div></div>
      </div>
    </section>

    <section class="od-section">
      <p class="od-section__eyebrow">// overview</p>
      <h2 class="od-section__title">One fleet, one discipline</h2>
      <p class="pf-card__blurb" style="max-width:70ch">${esc(SUMMARY)}</p>
    </section>

${sections}
  </main>

  <footer class="od-footer">${esc(b.footer)}</footer>
${TOGGLE}
</body>
</html>
`;
  fs.mkdirSync(path.dirname(b.out), { recursive: true });
  fs.writeFileSync(b.out, html);
  console.log(`[render] wrote ${path.relative(ROOT, b.out)} (${data.count} products)`);
}
