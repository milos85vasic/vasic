/* Generates REPORT.md from data/metrics.json produced by motion-audit.cjs. */
const fs = require('fs');
const path = require('node:path');

// Derive the repo root from this file's own location (repo/_tests/tools/ -> ../..)
// so the report generator runs from ANY checkout without a hardcoded absolute
// path. VASIC_ROOT overrides the default when the repo root is elsewhere.
const REPO = process.env.VASIC_ROOT || path.resolve(__dirname, '..', '..');
const OUT = path.join(REPO, '_tests', 'evidence', 'motion-audit');
const m = JSON.parse(fs.readFileSync(path.join(OUT, 'data/metrics.json'), 'utf8'));

const ICON = { works: 'WORKS', broken: 'BROKEN', absent: 'absent', present: 'present', 'absent-classes': 'absent', error: 'ERROR' };
function st(s) { return s ? (ICON[s] || s) : 'n/a'; }

const lines = [];
const P = (s = '') => lines.push(s);

P('# Motion & Interactive-Widget Functional Audit');
P('');
P(`Generated: ${m.generatedAt}`);
P('');
P('Read-only. Both already-generated static sites were served locally and driven with real');
P('browser automation (Playwright: chromium + firefox + webkit). No site source was edited and');
P('the Go generator was not run. Every verdict below is backed by a live DOM measurement and, for');
P('state-changing interactions, a before/after screenshot pair under `screenshots/`.');
P('');
P('- milosvasic.ru served from `milosvasic.ru/_site/` (port 8482)');
P('- vasic.digital served from `vasic.digital/` (port 8481)');
P('- Pages per site: landing (`/`), a product page, the portfolio page.');
P('');

/* ---- Functional matrix (chromium = deep run, all pages) ---- */
P('## Functional matrix (widget x site x page — chromium deep run)');
P('');
P('| Interaction | Site | landing | product | portfolio |');
P('|---|---|---|---|---|');
const checkRows = [
  ['scrollReveal', 'Scroll-reveal'],
  ['stickyHeader', 'Sticky header'],
  ['accordion', 'Accordion/disclosure'],
  ['themeToggle', 'Theme toggle'],
  ['langSwitcher', 'Language switcher'],
  ['modal', 'Dialog/modal'],
  ['lottie', 'Lottie'],
  ['microInteractions', 'Bounce/blink/highlight'],
];
for (const [key, label] of checkRows) {
  for (const siteKey of Object.keys(m.sites)) {
    const pgs = m.sites[siteKey].browsers.chromium.pages;
    const cell = (pk) => pgs[pk] ? st(pgs[pk].checks[key] && pgs[pk].checks[key].status) : 'n/a';
    P(`| ${label} | ${m.sites[siteKey].label} | ${cell('landing')} | ${cell('product')} | ${cell('portfolio')} |`);
  }
}
P('');

/* ---- Theme persistence detail ---- */
P('## Theme toggle — switch + persistence (chromium)');
P('');
P('| Site | page | button id | before | after | bg changed | persists on reload |');
P('|---|---|---|---|---|---|---|');
for (const siteKey of Object.keys(m.sites)) {
  const pgs = m.sites[siteKey].browsers.chromium.pages;
  for (const pk of Object.keys(pgs)) {
    const t = pgs[pk].checks.themeToggle;
    if (!t || t.status === 'absent') { P(`| ${m.sites[siteKey].label} | ${pk} | — | — | — | — | ${t ? t.status : 'n/a'} |`); continue; }
    const bgChanged = t.before && t.after && t.before.bg !== t.after.bg ? 'yes' : 'no';
    P(`| ${m.sites[siteKey].label} | ${pk} | \`#${t.toggleId || '—'}\` | ${t.before?.theme} | ${t.after?.theme} | ${bgChanged} | ${t.persists ? 'yes' : 'NO'} |`);
  }
}
P('');
P('> Note: vasic.digital uses button id `#od-theme-toggle` on landing/product but `#pf-theme-toggle`');
P('> on portfolio (each with its own inline handler). Both function; the id is merely inconsistent.');
P('');

/* ---- Reveal detail ---- */
P('## Scroll-reveal — before/after state change (chromium)');
P('');
P('| Site | page | below-fold reveal targets | before transform/opacity | after transform/opacity | verdict |');
P('|---|---|---|---|---|---|');
for (const siteKey of Object.keys(m.sites)) {
  const pgs = m.sites[siteKey].browsers.chromium.pages;
  for (const pk of Object.keys(pgs)) {
    const r = pgs[pk].checks.scrollReveal;
    if (!r) continue;
    const bt = r.before ? `${short(r.before.transform)} / ${r.before.opacity}` : '—';
    const at = r.after ? `${short(r.after.transform)} / ${r.after.opacity}` : '—';
    P(`| ${m.sites[siteKey].label} | ${pk} | ${r.belowFoldCount ?? '—'} | ${bt} | ${at} | ${st(r.status)} |`);
  }
}
P('');
for (const siteKey of Object.keys(m.sites)) {
  const pgs = m.sites[siteKey].browsers.chromium.pages;
  for (const pk of Object.keys(pgs)) {
    const r = pgs[pk].checks.scrollReveal;
    if (r && r.note) P(`- Note (${m.sites[siteKey].label} / ${pk}): ${r.note}.`);
  }
}
P('');

/* ---- Language switcher detail ---- */
P('## Language switcher (chromium, landing)');
P('');
for (const siteKey of Object.keys(m.sites)) {
  const l = m.sites[siteKey].browsers.chromium.pages.landing.checks.langSwitcher;
  if (l.status === 'absent') {
    P(`- **${m.sites[siteKey].label}**: ${st(l.status)} — ${l.note || 'no switcher'} (lang-like elements found: ${l.langLikeElements ?? 0}).`);
  } else {
    P(`- **${m.sites[siteKey].label}**: ${st(l.status)} — ${l.items} languages listed; aria-expanded ${l.ariaBefore} -> ${l.ariaAfterOpen}; Escape closes: ${l.escapeCloses}; opens via keyboard (Enter): ${l.keyboardOpens}.`);
  }
}
P('');

/* ---- Modal detail ---- */
P('## Dialog / modal + backdrop (chromium, landing)');
P('');
for (const siteKey of Object.keys(m.sites)) {
  const d = m.sites[siteKey].browsers.chromium.pages.landing.checks.modal;
  if (d.status === 'absent') { P(`- **${m.sites[siteKey].label}**: absent — no reachable modal trigger on landing.`); continue; }
  P(`- **${m.sites[siteKey].label}**: ${st(d.status)} — opens on trigger click (opacity ${d.openState?.opacity}), backdrop backdrop-filter: \`${d.openState?.backdropBlur}\`; Escape closes: ${d.escapeCloses}.`);
}
P('');

/* ---- Long tasks / jank ---- */
P('## Long-task / jank summary (chromium, scripted full-page scroll)');
P('');
P('PerformanceObserver `longtask` entries recorded while scripting a full scroll through each page.');
P('A task > 50ms blocks the main thread noticeably; > 200ms is a jank concern.');
P('');
P('| Site | page | longtask API | count | max ms | total ms | tasks>50ms |');
P('|---|---|---|---|---|---|---|');
for (const siteKey of Object.keys(m.sites)) {
  const pgs = m.sites[siteKey].browsers.chromium.pages;
  for (const pk of Object.keys(pgs)) {
    const lt = pgs[pk].checks.longTasks;
    if (!lt) continue;
    P(`| ${m.sites[siteKey].label} | ${pk} | ${lt.supported ? 'yes' : 'no'} | ${lt.count} | ${lt.maxMs} | ${lt.totalMs} | ${lt.over50ms} |`);
  }
}
P('');

/* ---- Reduced motion ---- */
P('## Reduced-motion re-render (prefers-reduced-motion: reduce)');
P('');
P('Each page re-loaded under emulated reduced-motion. PASS = reveal content is in its final state');
P('immediately (no scroll needed) and CSS transitions are neutralised.');
P('');
P('| Site | page | browser | reveal shown immediately | transitions neutralised |');
P('|---|---|---|---|---|');
for (const siteKey of Object.keys(m.sites)) {
  const brs = m.sites[siteKey].browsers;
  for (const bn of Object.keys(brs)) {
    for (const pk of Object.keys(brs[bn].reducedMotion)) {
      const rm = brs[bn].reducedMotion[pk].state;
      if (!rm || !rm.present) { P(`| ${m.sites[siteKey].label} | ${pk} | ${bn} | n/a | n/a |`); continue; }
      P(`| ${m.sites[siteKey].label} | ${pk} | ${bn} | ${rm.allShownImmediately ? 'PASS' : 'FAIL'} | ${rm.transitionsNeutralised ? 'PASS' : 'FAIL'} |`);
    }
  }
}
P('');

/* ---- Cross-browser ---- */
P('## Cross-browser sanity (landing — key interactions)');
P('');
P('| Site | interaction | chromium | firefox | webkit |');
P('|---|---|---|---|---|');
for (const siteKey of Object.keys(m.sites)) {
  const brs = m.sites[siteKey].browsers;
  const cell = (bn, key) => { const p = brs[bn]?.pages?.landing; return p ? st(p.checks[key]?.status) : 'n/a'; };
  for (const [key, label] of [['themeToggle', 'Theme toggle'], ['scrollReveal', 'Scroll-reveal'], ['langSwitcher', 'Language switcher']]) {
    P(`| ${m.sites[siteKey].label} | ${label} | ${cell('chromium', key)} | ${cell('firefox', key)} | ${cell('webkit', key)} |`);
  }
}
P('');

/* ---- Broken / absent inventory ---- */
P('## Broken or absent interactions (page + selector)');
P('');
const SELECTORS = {
  scrollReveal: '.od-reveal / .od-stagger / .reveal',
  stickyHeader: 'sticky header element',
  accordion: '.od-accordion__trigger',
  themeToggle: 'theme toggle button',
  langSwitcher: '#lang-btn / #lang-menu',
  modal: '[data-dl] -> #dl-modal',
  lottie: '.od-lottie[data-src]',
  microInteractions: '.od-bounce / .od-blink / .od-highlight',
};
let anyBad = false;
for (const siteKey of Object.keys(m.sites)) {
  const pgs = m.sites[siteKey].browsers.chromium.pages;
  for (const pk of Object.keys(pgs)) {
    for (const [key, label] of checkRows) {
      const c = pgs[pk].checks[key];
      if (!c) continue;
      if (['broken', 'error', 'absent', 'absent-classes'].includes(c.status)) {
        anyBad = true;
        const kind = c.status === 'broken' || c.status === 'error' ? 'BROKEN' : 'ABSENT';
        P(`- [${kind}] ${m.sites[siteKey].label} — ${pk} — ${label} — selector \`${SELECTORS[key]}\`${c.note ? ' — ' + c.note : ''}`);
      }
    }
  }
}
if (!anyBad) P('- None: every expected-and-present interaction functioned.');
P('');
P('> "Absent" means the effect the brief asked about does not exist on that page (nothing to break),');
P('> not that it failed. See the matrix for the works/broken/absent split.');

function short(t) {
  if (!t) return '—';
  if (t === 'none') return 'none';
  return t.length > 34 ? t.slice(0, 31) + '...' : t;
}

fs.writeFileSync(path.join(OUT, 'REPORT.md'), lines.join('\n'));
console.log('WROTE REPORT.md');
