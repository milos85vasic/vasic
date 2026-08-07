/* Renders real pages, measures COMPUTED bg/fg + WCAG contrast of every
   green status badge, and runs axe color-contrast. Evidence gatherer only. */
const path = require('path');
const fs = require('fs');
const { chromium } = require(path.join('/Volumes/T7/Projects/vasic/_tests/node_modules/playwright'));
const { AxeBuilder } = require(path.join('/Volumes/T7/Projects/vasic/_tests/node_modules/@axe-core/playwright'));

const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/a11y-fix2';
const MV = 'http://localhost:8502';
const VD = 'http://localhost:8501';
const THEME_KEY = { mv: 'mv-theme', vd: 'od-theme' };

const TARGETS = [
  { id: 'vd-home',      site: 'vd', url: `${VD}/` },
  { id: 'vd-portfolio', site: 'vd', url: `${VD}/portfolio/` },
  { id: 'vd-catalogizer(production)', site: 'vd', url: `${VD}/products/catalogizer.html` },
  { id: 'vd-docprocessor(active)',    site: 'vd', url: `${VD}/products/docprocessor.html` },
  { id: 'vd-helixconstitution(shipped)', site: 'vd', url: `${VD}/products/helixconstitution.html` },
  { id: 'vd-sfcf(stable)', site: 'vd', url: `${VD}/products/server-factory-core-framework.html` },
  { id: 'vd-helixtrack(beta)', site: 'vd', url: `${VD}/products/helixtrack.html` },
  { id: 'mv-home',      site: 'mv', url: `${MV}/` },
  { id: 'mv-portfolio', site: 'mv', url: `${MV}/portfolio/` },
  { id: 'mv-catalogizer(production)', site: 'mv', url: `${MV}/products/catalogizer.html` },
  { id: 'mv-docprocessor(active)',    site: 'mv', url: `${MV}/products/docprocessor.html` },
  { id: 'mv-helixconstitution(shipped)', site: 'mv', url: `${MV}/products/helixconstitution.html` },
  { id: 'mv-sfcf(stable)', site: 'mv', url: `${MV}/products/server-factory-core-framework.html` },
  { id: 'mv-helixtrack(beta)', site: 'mv', url: `${MV}/products/helixtrack.html` },
];

const sampler = () => {
  function parse(s){const m=s&&s.match(/rgba?\(([^)]+)\)/);if(!m)return null;const p=m[1].split(',').map(x=>parseFloat(x.trim()));return{r:p[0],g:p[1],b:p[2],a:p.length>3?p[3]:1};}
  function lin(c){c/=255;return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4);}
  function L(c){return 0.2126*lin(c.r)+0.7152*lin(c.g)+0.0722*lin(c.b);}
  function ratio(fg,bg){const a=L(fg)+0.05,b=L(bg)+0.05;return +( (Math.max(a,b)/Math.min(a,b)).toFixed(2) );}
  function hex(c){return '#'+[c.r,c.g,c.b].map(v=>Math.round(v).toString(16).padStart(2,'0')).join('');}
  const out=[];
  document.querySelectorAll('[class*="od-badge--status--"]').forEach(el=>{
    const cs=getComputedStyle(el);
    const fg=parse(cs.color), bg=parse(cs.backgroundColor);
    const cls=[...el.classList].find(c=>c.startsWith('od-badge--status--'))||'';
    if(fg&&bg&&bg.a>0){out.push({status:cls.replace('od-badge--status--',''),fg:hex(fg),bg:hex(bg),ratio:ratio(fg,bg),text:el.textContent.trim().slice(0,20)});}
  });
  return out;
};

(async () => {
  const browser = await chromium.launch();
  const results = [];
  let axeBadgeNodes = 0;
  const perTarget = [];
  for (const t of TARGETS) {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    for (const theme of ['light','dark']) {
      await page.addInitScript(([k,v])=>{try{localStorage.setItem(k,v);}catch(e){}}, [THEME_KEY[t.site], theme]);
      await page.goto(t.url, { waitUntil: 'networkidle' });
      await page.evaluate((th)=>{document.documentElement.setAttribute('data-theme',th);}, theme);
      await page.waitForTimeout(150);
      const badges = await page.evaluate(sampler);
      // axe color-contrast only
      const axe = await new AxeBuilder({ page }).withTags(['wcag2aa']).options({ runOnly:['color-contrast'] }).analyze();
      const badgeViol = [];
      for (const v of axe.violations) {
        for (const n of v.nodes) {
          if (/od-badge--status--/.test(n.html)) { badgeViol.push(n.html.slice(0,120)); axeBadgeNodes++; }
        }
      }
      const uniq = {};
      badges.forEach(b=>{ const k=b.status+'|'+theme; if(!uniq[k])uniq[k]=b; });
      perTarget.push({ target:t.id, theme, badges:Object.values(uniq), axeBadgeContrastNodes: badgeViol.length, axeBadgeSamples: badgeViol.slice(0,3) });
    }
    await ctx.close();
  }
  await browser.close();
  const minRatio = Math.min(...perTarget.flatMap(p=>p.badges.map(b=>b.ratio)));
  const summary = { totalAxeBadgeColorContrastNodes: axeBadgeNodes, minBadgeRatioMeasured: minRatio, perTarget };
  fs.writeFileSync(path.join(OUT,'badge-render-results.json'), JSON.stringify(summary,null,2));
  console.log('TOTAL axe badge color-contrast nodes:', axeBadgeNodes);
  console.log('MIN badge ratio measured:', minRatio);
  for (const p of perTarget) {
    const b = p.badges.map(x=>`${x.status}:${x.fg}/${x.bg}=${x.ratio}`).join('  ');
    console.log(`${p.target} [${p.theme}] axeNodes=${p.axeBadgeContrastNodes}  ${b}`);
  }
})();
