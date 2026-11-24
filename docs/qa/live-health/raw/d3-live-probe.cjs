const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({headless:true});const c=await b.newContext();const p=await c.newPage();const out={};
for(const u of ['/','/ar/','/ru/','/ja/']){await p.goto('https://milosvasic.ru'+u,{waitUntil:'load'});out[u]=await p.evaluate(()=>({lang:document.documentElement.lang,dir:document.documentElement.dir,btn:(document.getElementById('lang-btn')||{}).textContent,stored:localStorage.getItem('mv-lang')}));}
out.adminStatus={};for(const u of ['/admin/','/downloads/vault/','/matrix.tsv','/assets/js/vault.js','/assets/css/admin-console.css']){const r=await p.request.get('https://milosvasic.ru'+u);out.adminStatus[u]=r.status();}
console.log(JSON.stringify(out,null,1));await b.close();})();
