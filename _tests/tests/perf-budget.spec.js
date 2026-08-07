const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Performance budget (§11.4.169). Lighthouse/LHCI is NOT a declared dependency
// of this repo and is not assumed installable in CI, so — per the task's
// explicit allowance — this uses a DOCUMENTED lighter proxy instead of faking a
// Lighthouse score: a real transferred-bytes + request-count budget measured
// from Playwright's network layer, plus an LCP-candidate presence check and a
// render-blocking-script check. Real numbers are written to
// evidence/test-types/perf-budget.json.

const BUDGET = {
  maxBytes: 1_500_000, // measured homepage weight ~0.4–0.6 MB; generous, meaningful ceiling
  maxRequests: 45,
};

const PAGES = [
  { site: 'vasic.digital', base: 'http://localhost:8401', path: '/', lcp: '.od-hero__title' },
  { site: 'vasic.digital', base: 'http://localhost:8401', path: '/products/helixtrack.html', lcp: 'h1' },
  { site: 'milosvasic.ru', base: 'http://localhost:8082', path: '/', lcp: 'h1' },
  { site: 'milosvasic.ru', base: 'http://localhost:8082', path: '/products/helixtrack.html', lcp: 'h1' },
];

const results = [];

test.afterAll(async () => {
  if (results.length === 0) return;
  const dir = path.join(__dirname, '..', 'evidence', 'test-types');
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, 'perf-budget.json');
  let prev = [];
  try { prev = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { /* first run */ }
  // Keep one row per site+path+browser (last write wins).
  const key = (r) => `${r.site}${r.path}|${r.browser}`;
  const merged = new Map(prev.map((r) => [key(r), r]));
  for (const r of results) merged.set(key(r), r);
  fs.writeFileSync(file, JSON.stringify([...merged.values()], null, 2) + '\n');
});

for (const p of PAGES) {
  test(`perf budget — ${p.site}${p.path}`, async ({ page }, testInfo) => {
    let bytes = 0;
    let requests = 0;
    page.on('requestfinished', async (req) => {
      requests++;
      try {
        const s = await req.sizes();
        bytes += (s.responseBodySize || 0) + (s.responseHeadersSize || 0);
      } catch (e) { /* request may be gone */ }
    });

    await page.goto(p.base + p.path, { waitUntil: 'load' });
    await page.waitForLoadState('networkidle');

    // LCP candidate must exist and be visible (cross-browser).
    await expect(page.locator(p.lcp).first()).toBeVisible();

    // No render-blocking scripts in <head> (CSS is allowed to block; JS is not).
    const blockingHeadScripts = await page.locator('head script[src]').evaluateAll(
      (els) => els.filter((e) => !e.defer && !e.async).map((e) => e.getAttribute('src'))
    );
    expect(blockingHeadScripts, `render-blocking head scripts: ${blockingHeadScripts.join(', ')}`).toHaveLength(0);

    // Real LCP timing where the API is available (Chromium).
    let lcpMs = null;
    if (testInfo.project.name === 'chromium') {
      lcpMs = await page.evaluate(() => new Promise((resolve) => {
        let last = null;
        try {
          const po = new PerformanceObserver((list) => {
            for (const e of list.getEntries()) last = e.renderTime || e.loadTime || e.startTime;
          });
          po.observe({ type: 'largest-contentful-paint', buffered: true });
        } catch (e) { /* unsupported */ }
        setTimeout(() => resolve(last), 600);
      }));
    }

    results.push({
      site: p.site, path: p.path, browser: testInfo.project.name,
      transferredBytes: bytes, requests, lcpMs,
    });

    // eslint-disable-next-line no-console
    console.log(`[perf] ${p.site}${p.path} [${testInfo.project.name}] bytes=${bytes} requests=${requests} lcpMs=${lcpMs}`);

    expect(bytes, `transferred bytes ${bytes} over budget ${BUDGET.maxBytes}`).toBeLessThan(BUDGET.maxBytes);
    expect(requests, `request count ${requests} over budget ${BUDGET.maxRequests}`).toBeLessThan(BUDGET.maxRequests);
  });
}
