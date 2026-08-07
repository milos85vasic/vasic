const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext();
  for (const url of ['https://vasic.digital/portfolio/ru/','https://vasic.digital/portfolio/','https://vasic.digital/']) {
    const p = await ctx.newPage();
    await p.goto(url,{waitUntil:'networkidle'});
    const info = await p.evaluate(()=>{
      const el=document.querySelector('.od-to-top');
      const scripts=[...document.querySelectorAll('script[src]')].map(s=>s.getAttribute('src'));
      return {
        scrollH:document.documentElement.scrollHeight,
        innerH:window.innerHeight,
        atTop:{op:getComputedStyle(el).opacity,vis:getComputedStyle(el).visibility,cls:el.className},
        hasMotion:scripts.some(s=>/motion\.js/.test(s)),
        scripts
      };
    });
    console.log(url,'\n ',JSON.stringify(info));
  }
  await b.close();
})();
