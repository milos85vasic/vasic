// READ-ONLY perf metrics collector. Uses real headless Chromium (Playwright).
// No Lighthouse available (CLI not installed; Chrome DevTools MCP exposes no
// lighthouse_audit tool) -> we capture real browser metrics instead and label honestly.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, 'metrics');
fs.mkdirSync(OUT, { recursive: true });

const TARGETS = [
  { site: 'milosvasic.ru', page: 'landing',   url: 'http://localhost:8082/' },
  { site: 'milosvasic.ru', page: 'product',   url: 'http://localhost:8082/products/helixtrack.html' },
  { site: 'milosvasic.ru', page: 'portfolio', url: 'http://localhost:8082/portfolio/' },
  { site: 'vasic.digital', page: 'landing',   url: 'http://localhost:8401/' },
  { site: 'vasic.digital', page: 'product',   url: 'http://localhost:8401/products/helixtrack.html' },
  { site: 'vasic.digital', page: 'portfolio', url: 'http://localhost:8401/portfolio/' },
];

async function collect(browser, t) {
  const ctx = await browser.newContext({ viewport: { width: 1366, height: 900 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  // capture network via CDP for accurate transfer sizes
  const responses = [];
  page.on('response', async (resp) => {
    try {
      const req = resp.request();
      let size = 0;
      try { const hdr = await resp.headerValue('content-length'); if (hdr) size = parseInt(hdr, 10); } catch (e) {}
      responses.push({ url: resp.url(), status: resp.status(), type: req.resourceType(), contentLength: size });
    } catch (e) {}
  });

  const start = Date.now();
  await page.goto(t.url, { waitUntil: 'load', timeout: 45000 });
  // settle for LCP/CLS/longtasks
  await page.waitForTimeout(3500);

  const metrics = await page.evaluate(() => {
    const nav = performance.getEntriesByType('navigation')[0] || {};
    const res = performance.getEntriesByType('resource').map(r => ({
      name: r.name, initiatorType: r.initiatorType,
      transferSize: r.transferSize, encodedBodySize: r.encodedBodySize,
      decodedBodySize: r.decodedBodySize, duration: Math.round(r.duration),
      renderBlocking: r.renderBlockingStatus || null,
    }));
    // LCP
    let lcp = null;
    const lcpEntries = performance.getEntriesByType('largest-contentful-paint');
    if (lcpEntries.length) lcp = lcpEntries[lcpEntries.length - 1].startTime;
    // paint
    const fcp = (performance.getEntriesByName('first-contentful-paint')[0] || {}).startTime || null;
    // CLS + longtasks captured by observers set on window
    const cls = window.__cls || 0;
    const longtasks = window.__longtasks || [];
    const tbt = longtasks.reduce((s, d) => s + Math.max(0, d - 50), 0);
    return {
      navigationTiming: {
        responseEnd: Math.round(nav.responseEnd || 0),
        domContentLoaded: Math.round(nav.domContentLoadedEventEnd || 0),
        loadEvent: Math.round(nav.loadEventEnd || 0),
        transferSizeDocument: nav.transferSize || 0,
        encodedDocument: nav.encodedBodySize || 0,
      },
      fcp: fcp ? Math.round(fcp) : null,
      lcp: lcp ? Math.round(lcp) : null,
      cls: Math.round(cls * 1000) / 1000,
      approxTBT_fromLongtasks: Math.round(tbt),
      longtaskCount: longtasks.length,
      resources: res,
    };
  });

  // render-blocking analysis from DOM
  const blocking = await page.evaluate(() => {
    const headSyncScripts = [...document.head.querySelectorAll('script[src]')].filter(s => !s.defer && !s.async).map(s => s.src);
    const headStylesheets = [...document.head.querySelectorAll('link[rel="stylesheet"]')].map(l => ({ href: l.href, media: l.media || 'all' }));
    const remoteHosts = [...document.querySelectorAll('link[href],script[src],img[src]')]
      .map(e => e.href || e.src).filter(Boolean)
      .filter(u => { try { return new URL(u).host !== location.host; } catch (e) { return false; } });
    const imgs = [...document.images].map(i => ({ src: i.currentSrc || i.src, natW: i.naturalWidth, natH: i.naturalHeight, dispW: i.clientWidth, dispH: i.clientHeight, loading: i.loading || 'auto', hasWH: !!(i.getAttribute('width') && i.getAttribute('height')) }));
    return { headSyncScripts, headStylesheets, remoteHosts: [...new Set(remoteHosts)], imgs };
  });

  // aggregate response transfer by type (use resource timing transferSize which reflects real over-the-wire bytes)
  const byType = {};
  let totalTransfer = 0;
  for (const r of metrics.resources) {
    const key = r.initiatorType || 'other';
    byType[key] = byType[key] || { count: 0, transfer: 0 };
    byType[key].count++;
    byType[key].transfer += r.transferSize || 0;
    totalTransfer += r.transferSize || 0;
  }
  totalTransfer += metrics.navigationTiming.transferSizeDocument || 0;

  await ctx.close();
  return {
    ...t,
    method: 'Playwright headless Chromium, viewport 1366x900, no network throttling, cold context',
    capturedAt: new Date().toISOString(),
    wallClockMs: Date.now() - start,
    coreWebVitals: { LCP_ms: metrics.lcp, FCP_ms: metrics.fcp, CLS: metrics.cls, approxTBT_ms: metrics.approxTBT_fromLongtasks, longtaskCount: metrics.longtaskCount },
    navigationTiming: metrics.navigationTiming,
    totals: { requestCount: metrics.resources.length + 1, totalTransferBytes: totalTransfer, byInitiatorType: byType },
    renderBlocking: { headSyncScripts: blocking.headSyncScripts, headStylesheets: blocking.headStylesheets },
    remoteHosts: blocking.remoteHosts,
    images: blocking.imgs,
    resources: metrics.resources.sort((a, b) => (b.transferSize || 0) - (a.transferSize || 0)).slice(0, 25),
  };
}

(async () => {
  const browser = await chromium.launch();
  // inject CLS + longtask observers before any script via addInitScript per context is per-page; do inline instead
  const all = [];
  for (const t of TARGETS) {
    const ctx = await browser.newContext();
    await ctx.close();
    // wrap: need observers installed pre-navigation
    const c2 = await browser.newContext({ viewport: { width: 1366, height: 900 } });
    await c2.addInitScript(() => {
      window.__cls = 0; window.__longtasks = [];
      try { new PerformanceObserver((l) => { for (const e of l.getEntries()) { if (!e.hadRecentInput) window.__cls += e.value; } }).observe({ type: 'layout-shift', buffered: true }); } catch (e) {}
      try { new PerformanceObserver((l) => { for (const e of l.getEntries()) window.__longtasks.push(e.duration); }).observe({ type: 'longtask', buffered: true }); } catch (e) {}
      try { new PerformanceObserver((l) => { const es = l.getEntries(); window.__lcp = es[es.length - 1].renderTime || es[es.length - 1].startTime; }).observe({ type: 'largest-contentful-paint', buffered: true }); } catch (e) {}
    });
    const page = await c2.newPage();
    const responses = [];
    const start = Date.now();
    await page.goto(t.url, { waitUntil: 'load', timeout: 45000 });
    await page.waitForTimeout(3500);
    const data = await page.evaluate(() => {
      const nav = performance.getEntriesByType('navigation')[0] || {};
      const res = performance.getEntriesByType('resource').map(r => ({ name: r.name, initiatorType: r.initiatorType, transferSize: r.transferSize, encodedBodySize: r.encodedBodySize, decodedBodySize: r.decodedBodySize, duration: Math.round(r.duration) }));
      const lcp = window.__lcp || null;
      const fcp = (performance.getEntriesByName('first-contentful-paint')[0] || {}).startTime || null;
      const cls = window.__cls || 0; const lt = window.__longtasks || [];
      const tbt = lt.reduce((s, d) => s + Math.max(0, d - 50), 0);
      const headSyncScripts = [...document.head.querySelectorAll('script[src]')].filter(s => !s.defer && !s.async).map(s => s.src);
      const headStylesheets = [...document.head.querySelectorAll('link[rel="stylesheet"]')].map(l => ({ href: l.href, media: l.media || 'all' }));
      const remoteHosts = [...new Set([...document.querySelectorAll('link[href],script[src],img[src]')].map(e => e.href || e.src).filter(Boolean).filter(u => { try { return new URL(u).host !== location.host; } catch (e) { return false; } }))];
      const imgs = [...document.images].map(i => ({ src: i.currentSrc || i.src, natW: i.naturalWidth, natH: i.naturalHeight, dispW: i.clientWidth, dispH: i.clientHeight, loading: i.loading || 'auto', hasWH: !!(i.getAttribute('width') && i.getAttribute('height')) }));
      return { nav: { responseEnd: Math.round(nav.responseEnd || 0), domContentLoaded: Math.round(nav.domContentLoadedEventEnd || 0), loadEvent: Math.round(nav.loadEventEnd || 0), transferSizeDocument: nav.transferSize || 0 }, lcp: lcp ? Math.round(lcp) : null, fcp: fcp ? Math.round(fcp) : null, cls: Math.round(cls * 1000) / 1000, tbt: Math.round(tbt), ltCount: lt.length, res, headSyncScripts, headStylesheets, remoteHosts, imgs };
    });
    const byType = {}; let totalTransfer = data.nav.transferSizeDocument || 0;
    for (const r of data.res) { const k = r.initiatorType || 'other'; byType[k] = byType[k] || { count: 0, transfer: 0 }; byType[k].count++; byType[k].transfer += r.transferSize || 0; totalTransfer += r.transferSize || 0; }
    all.push({
      site: t.site, page: t.page, url: t.url,
      method: 'Playwright headless Chromium 1366x900, no throttling, cold cache',
      capturedAt: new Date().toISOString(), wallClockMs: Date.now() - start,
      coreWebVitals: { LCP_ms: data.lcp, FCP_ms: data.fcp, CLS: data.cls, approxTBT_ms: data.tbt, longtaskCount: data.ltCount },
      navigationTiming: data.nav,
      totals: { requestCount: data.res.length + 1, totalTransferBytes: totalTransfer, byInitiatorType: byType },
      renderBlocking: { headSyncScripts: data.headSyncScripts, headStylesheets: data.headStylesheets },
      remoteHosts: data.remoteHosts,
      images: data.imgs,
      topResources: data.res.sort((a, b) => (b.transferSize || 0) - (a.transferSize || 0)).slice(0, 20),
    });
    await c2.close();
    console.log(`OK ${t.site} ${t.page}: LCP=${data.lcp}ms CLS=${data.cls} req=${data.res.length + 1} transfer=${(totalTransfer/1024).toFixed(0)}KB remoteHosts=${data.remoteHosts.length}`);
  }
  await browser.close();
  fs.writeFileSync(path.join(OUT, 'metrics.json'), JSON.stringify(all, null, 2));
  console.log('WROTE metrics.json');
})();
