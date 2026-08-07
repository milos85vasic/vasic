const { chromium } = require('playwright');
const fs = require('fs');
const OUT = '/Volumes/T7/Projects/vasic/_tests/evidence/live-v1.3.1';
const results = [];
function rec(site, check, pass, detail){ results.push({site,check,pass,detail}); console.log(`${pass?'PASS':'FAIL'} [${site}] ${check} ${detail||''}`); }

const pages = [
  ['vasic-home','https://vasic.digital/'],
  ['vasic-portfolio-ru','https://vasic.digital/portfolio/ru/'],
  ['milos-home','https://milosvasic.ru/'],
  ['milos-portfolio-ru','https://milosvasic.ru/portfolio/ru/'],
];
const widths = [375,768,1280];

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext();

  for (const [label,url] of pages) {
    const page = await ctx.newPage();
    await page.goto(url,{waitUntil:'networkidle',timeout:45000});

    // horizontal overflow at each width
    for (const w of widths) {
      await page.setViewportSize({width:w,height:900});
      await page.waitForTimeout(300);
      const over = await page.evaluate(()=>({sw:document.documentElement.scrollWidth, cw:document.documentElement.clientWidth}));
      const ok = over.sw <= over.cw + 2;
      rec(label, `no-hoverflow@${w}`, ok, `scrollW=${over.sw} clientW=${over.cw}`);
    }
    await page.setViewportSize({width:1280,height:900});

    // broken images
    const imgs = await page.evaluate(()=>{
      const out=[];
      document.querySelectorAll('img').forEach(i=>{ if(i.complete && i.naturalWidth===0) out.push(i.currentSrc||i.src); });
      return {total:document.querySelectorAll('img').length, broken:out};
    });
    rec(label,'no-broken-imgs', imgs.broken.length===0, `imgs=${imgs.total} broken=${JSON.stringify(imgs.broken)}`);

    // back-to-top reveal on scroll
    const btt = await page.$('.od-to-top');
    if(btt){
      const before = await btt.evaluate(el=>({vis:getComputedStyle(el).visibility,op:getComputedStyle(el).opacity,cls:el.className,ah:el.getAttribute('aria-hidden')}));
      await page.evaluate(()=>window.scrollTo(0,2000));
      await page.waitForTimeout(700);
      const after = await btt.evaluate(el=>({vis:getComputedStyle(el).visibility,op:getComputedStyle(el).opacity,cls:el.className,ah:el.getAttribute('aria-hidden')}));
      const revealed = (parseFloat(after.op)>parseFloat(before.op)) || (before.vis==='hidden'&&after.vis==='visible') || (before.cls!==after.cls) || (before.ah!==after.ah);
      rec(label,'backtotop-reveal-on-scroll', revealed, `before=${JSON.stringify(before)} after=${JSON.stringify(after)}`);
      await page.evaluate(()=>window.scrollTo(0,0));
    } else {
      rec(label,'backtotop-present', false, '.od-to-top not found');
    }
    await page.close();
  }

  // nav navigation checks
  // vasic home: click Portfolio nav -> /portfolio/
  {
    const page = await ctx.newPage();
    await page.goto('https://vasic.digital/',{waitUntil:'networkidle'});
    await page.click('a.od-nav__link[data-i18n="nav.portfolio"]');
    await page.waitForLoadState('networkidle');
    const u = page.url();
    rec('vasic-home','nav-click-portfolio-navigates', /\/portfolio\/?$/.test(u), `landed=${u}`);
    await page.close();
  }
  // milos portfolio subpage: click nav /#work -> lands on home with #work
  {
    const page = await ctx.newPage();
    await page.goto('https://milosvasic.ru/portfolio/ru/',{waitUntil:'networkidle'});
    await page.click('a[href="/#work"]');
    await page.waitForTimeout(1500);
    const u = page.url();
    rec('milos-portfolio-ru','nav-click-work-navigates-to-home', /milosvasic\.ru\/#work$/.test(u)||/milosvasic\.ru\/?$/.test(u.split('#')[0]+''), `landed=${u}`);
    await page.close();
  }

  fs.writeFileSync(`${OUT}/interactive-live.json`, JSON.stringify(results,null,2));
  const fails = results.filter(r=>!r.pass);
  fs.writeFileSync(`${OUT}/interactive-live-summary.txt`,
    `total=${results.length} pass=${results.length-fails.length} fail=${fails.length}\n`+
    results.map(r=>`${r.pass?'PASS':'FAIL'} [${r.site}] ${r.check} ${r.detail||''}`).join('\n')+'\n');
  console.log(`\nTOTAL=${results.length} PASS=${results.length-fails.length} FAIL=${fails.length}`);
  await browser.close();
})();
