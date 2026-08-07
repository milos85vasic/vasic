const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext();
  const urls = ['/portfolio/','/portfolio/de/','/portfolio/ru/','/portfolio/ar/','/portfolio/ja/'];
  for (const path of urls) {
    const p = await ctx.newPage();
    await p.goto('https://vasic.digital'+path,{waitUntil:'networkidle'});
    await p.waitForTimeout(400);
    const info = await p.evaluate(()=>{
      const el=document.querySelector('.od-to-top');
      // find matched opacity from stylesheets
      let ruleOpacities=[];
      for (const ss of document.styleSheets){ try{ for(const r of ss.cssRules){ if(r.selectorText && /od-to-top/.test(r.selectorText) && r.style && r.style.opacity!==''){ ruleOpacities.push(r.selectorText+' => '+r.style.opacity);}}}catch(e){} }
      return {scrollH:document.documentElement.scrollHeight, inlineStyle:el.getAttribute('style'), cls:el.className, computedOp:getComputedStyle(el).opacity, ruleOpacities};
    });
    console.log(path, JSON.stringify(info));
    await p.close();
  }
  await b.close();
})();
