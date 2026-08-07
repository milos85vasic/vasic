#!/usr/bin/env node
/* Generate a real raster PNG (so pdfimages can confirm an embedded image in
 * the golden-good PDF). Uses the already-installed Chromium. */
'use strict';
const { chromium } = require('@playwright/test');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'fixtures', 'figure.png');
const html = `<!doctype html><meta charset=utf-8><body style="margin:0">
<div style="width:520px;height:220px;font-family:sans-serif;background:#fff;padding:16px;box-sizing:border-box">
  <div style="font-weight:700;font-size:18px;margin-bottom:12px">Quarterly throughput (units)</div>
  <div style="display:flex;align-items:flex-end;gap:24px;height:150px">
    <div style="width:70px;height:60px;background:#2f6feb"></div>
    <div style="width:70px;height:95px;background:#2f6feb"></div>
    <div style="width:70px;height:130px;background:#2f6feb"></div>
    <div style="width:70px;height:150px;background:#1f9d57"></div>
  </div>
</div></body>`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 552, height: 252 } });
  await p.setContent(html, { waitUntil: 'networkidle' });
  await p.locator('div').first().screenshot({ path: out });
  await b.close();
  console.log('wrote', out);
})().catch(e => { console.error(e); process.exit(1); });
