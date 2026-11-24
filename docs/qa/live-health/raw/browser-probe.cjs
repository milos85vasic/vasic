const { chromium } = require('playwright');
const fs=require('fs');
const pages = {
 'https://milosvasic.ru': ['/','/ru/','/ar/','/ja/','/products/helixtrack.html','/expertise/','/expertise/ai-engineering/','/expertise/ai-engineering/ru/','/portfolio/'],
 'https://digital.vasic.dev': ['/','/ru/','/ar/','/zh/','/products/helixtrack.html','/fa/','/de/'],
};
(async()=>{
 const b = await chromium.launch({headless:true});
 const out=[];
 for (const [base,paths] of Object.entries(pages)) {
  const portal = await (async()=>{ // discover real links from sitemap not needed
  })();
  for (const vp of [{n:'desktop',w:1366,h:900,m:false},{n:'mobile',w:390,h:844,m:true}]) {
   let ctx;
   const mk=async()=>await b.newContext({viewport:{width:vp.w,height:vp.h}, isMobile:vp.m, hasTouch:vp.m, userAgent: vp.m?'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36':undefined});
   for (const p of paths) {
    ctx = await mk(); const page = await ctx.newPage();
    const errs=[], failed=[], mixed=[], reqs=[]; 
    page.on('console',m=>{ if(['error','warning'].includes(m.type())) errs.push(m.type()+': '+m.text().slice(0,200));});
    page.on('pageerror',e=>errs.push('pageerror: '+String(e).slice(0,200)));
    page.on('requestfailed',r=>failed.push(r.url()+' '+r.failure()?.errorText));
    page.on('request',r=>{ if(r.url().startsWith('http://')) mixed.push(r.url()); });
    page.on('requestfinished',r=>{reqs.push(r)});
    let st=0;
    try{ const r=await page.goto(base+p,{waitUntil:'networkidle',timeout:45000}); st=r.status(); }catch(e){errs.push('nav: '+e.message.slice(0,150));}
    let bytes=0; const rows=[];
    for(const r of reqs){ try{const s=await r.sizes(); const t=s.responseBodySize+s.responseHeadersSize; bytes+=t; rows.push([r.resourceType(),t,r.url().replace(base,'')]);}catch{} }
    const info = await page.evaluate(()=>({title:document.title, lang:document.documentElement.lang, dir:document.documentElement.dir, hreflang:[...document.querySelectorAll('link[rel=alternate][hreflang]')].map(l=>l.hreflang).length, canonical:document.querySelector('link[rel=canonical]')?.href, mixedEls:[...document.querySelectorAll('[src],[href]')].map(e=>e.getAttribute('src')||e.getAttribute('href')).filter(u=>/^http:\/\//.test(u||'')).length, hscroll: document.documentElement.scrollWidth>document.documentElement.clientWidth+1})).catch(()=>({}));
    out.push({base,path:p,vp:vp.n,status:st,bytes,requests:reqs.length,errs,failed,mixed,info,rows});
    await page.close(); await ctx.close();
   }
  }
 }
 await b.close();
 fs.writeFileSync('browser2.json',JSON.stringify(out,null,1));
 for(const o of out) console.log(o.base.replace('https://',''),o.path,o.vp,o.status,o.bytes,o.requests,'errs='+o.errs.length,'failed='+o.failed.length,'mixed='+o.mixed.length,'|',o.info.lang,o.info.dir,'hl='+o.info.hreflang,'hscroll='+o.info.hscroll,'|',(o.info.title||'').slice(0,40));
})();
