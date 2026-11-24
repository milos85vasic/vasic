const { chromium } = require(process.env.PW_MODULE||'@playwright/test');
const base = process.argv[2];
const langs = ['', 'ar','be','de','es','fa','fr','hi','ja','kk','ko','ru','sr','tr','zh'];
const widths = [320,360,390,414,768];
(async()=>{
  const b = await chromium.launch();
  const out=[];
  for (const w of widths) { const ctx = await b.newContext({viewport:{width:w,height:800}}); 
    for (const l of langs) { const p = await ctx.newPage();
      try { await p.goto(base+'/'+(l?l+'/':''),{waitUntil:'load'}); await p.waitForTimeout(400);
      const r = await p.evaluate(()=>{const d=document.documentElement;const vw=d.clientWidth;const off=[];
        document.querySelectorAll('body *').forEach(e=>{const r=e.getBoundingClientRect();if(r.right>vw+1&&r.width>0){off.push((e.tagName+'.'+(e.className&&e.className.baseVal===undefined?e.className:'')).slice(0,60)+' R='+Math.round(r.right));}});
        return {sw:d.scrollWidth,cw:vw,bsw:document.body.scrollWidth,off:off.slice(0,6)}});
      out.push({l:l||'en',w,...r,over:r.sw>r.cw}); } catch(e){out.push({l:l||'en',w,err:String(e)})}
      await p.close(); }
    await ctx.close(); }
  await b.close();
  const bad=out.filter(o=>o.over||o.err); console.log('total',out.length,'overflow',bad.length);
  bad.forEach(o=>console.log(JSON.stringify(o)));
})();
