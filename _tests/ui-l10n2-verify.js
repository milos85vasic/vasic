const { chromium } = require('playwright');
// The server this attaches to is started elsewhere; its address is DERIVED
// (UI_L10N2_PORT / UI_L10N2_BASE via ./env.js), not frozen to one box.
const { UI_L10N2_BASE: BASE } = require('./env.js');
(async () => {
  const b = await chromium.launch();
  const out={};
  async function grab(page){
    return await page.evaluate(()=>{
      const nav=document.querySelector('nav');
      return {
        lang:document.documentElement.getAttribute('lang'),
        dir:document.documentElement.getAttribute('dir'),
        nav: nav?nav.innerText.replace(/\s+/g,' ').trim():'(none)',
        skip: (document.querySelector('[data-i18n="a11y.skip"]')||{}).textContent
      };
    });
  }
  // 1. ru product on load
  let p=await b.newPage(); await p.goto(BASE+'/products/ru/helixcode.html',{waitUntil:'networkidle'}); await p.waitForTimeout(350);
  out['ru-onload']=await grab(p); await p.close();
  // 2. ar product on load (rtl)
  p=await b.newPage(); await p.goto(BASE+'/products/ar/helixcode.html',{waitUntil:'networkidle'}); await p.waitForTimeout(350);
  out['ar-onload']=await grab(p); await p.close();
  // 3. en product stays English
  p=await b.newPage(); await p.goto(BASE+'/products/helixcode.html',{waitUntil:'networkidle'}); await p.waitForTimeout(350);
  out['en-onload']=await grab(p); await p.close();
  // 4. stored choice (de) must NOT be overridden on a ru page
  p=await b.newPage();
  await p.goto(BASE+'/products/ru/helixcode.html',{waitUntil:'domcontentloaded'});
  await p.evaluate(()=>{try{localStorage.setItem('mv-lang','de')}catch(e){}});
  await p.goto(BASE+'/products/ru/helixcode.html',{waitUntil:'networkidle'}); await p.waitForTimeout(350);
  out['ru-with-stored-de']=await grab(p); await p.close();
  console.log(JSON.stringify(out,null,2));
  await b.close();
})();
