const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext();
  const urls = [
    'https://vasic.digital/products/ru/catalogizer.html',
    'https://vasic.digital/products/catalogizer.html',
    'https://milosvasic.ru/portfolio/ru/',
  ];
  for (const url of urls) {
    const p = await ctx.newPage();
    const failed = [];
    p.on('requestfailed', r => failed.push(r.url()));
    const bad = [];
    p.on('response', r => { if (r.status()>=400) bad.push(r.status()+' '+r.url()); });
    await p.goto(url,{waitUntil:'networkidle',timeout:45000});
    const info = await p.evaluate(()=>({
      loadedSheets:[...document.styleSheets].map(s=>s.href).filter(Boolean).length,
      loadedSheetHrefs:[...document.styleSheets].map(s=>s.href).filter(Boolean),
      bodyBg:getComputedStyle(document.body).backgroundColor,
      cssLinks:[...document.querySelectorAll('link[rel=stylesheet]')].length,
    }));
    console.log('URL', url);
    console.log('  cssLinksInDom='+info.cssLinks+' loadedStylesheets='+info.loadedSheets+' bodyBg='+info.bodyBg);
    console.log('  4xx responses: '+ (bad.length?bad.join('; '):'none'));
    await p.close();
  }
  await b.close();
})();
