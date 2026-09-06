const { test, expect } = require('@playwright/test');
const { VD_BASE, MV_BASE } = require('../env.js');
const { writeRow } = require('../tools/perf-budget-rows.cjs');

// Performance budget (§11.4.169). Lighthouse/LHCI is NOT a declared dependency
// of this repo and is not assumed installable in CI, so — per the task's
// explicit allowance — this uses a DOCUMENTED lighter proxy instead of faking a
// Lighthouse score: a real transferred-bytes + request-count budget measured
// from Playwright's network layer, plus an LCP-candidate presence check and a
// render-blocking-script check. Real numbers are written to
// evidence/test-types/perf-budget.json.
//
// HOW THE EVIDENCE FILE IS WRITTEN — and why not from here.
// Each test drops its own row through ../tools/perf-budget-rows.cjs; one global
// teardown collects them after every worker has exited. The previous form —
// a module-level `results[]` plus an `afterAll` read-modify-write of the tracked
// file — ran once PER WORKER under `fullyParallel: true`, so the committed
// artifact was a union over history rather than a measurement of one run (it
// held 12 rows across three browsers while its own comment said chromium only).
// See that module's header for the full account.

const BUDGET = {
  maxBytes: 1_500_000, // measured homepage weight ~0.4–0.6 MB; generous, meaningful ceiling
  maxRequests: 45,
};

const PAGES = [
  { site: 'vasic.digital', base: VD_BASE, path: '/', lcp: '.od-hero__title' },
  { site: 'vasic.digital', base: VD_BASE, path: '/products/helixtrack.html', lcp: 'h1' },
  { site: 'milosvasic.ru', base: MV_BASE, path: '/', lcp: 'h1' },
  { site: 'milosvasic.ru', base: MV_BASE, path: '/products/helixtrack.html', lcp: 'h1' },
];

for (const p of PAGES) {
  test(`perf budget — ${p.site}${p.path}`, async ({ page }, testInfo) => {
    let bytes = 0;
    let requests = 0;
    let unsized = 0;

    // THE MEASUREMENT MUST BE COMPLETE BEFORE IT IS ASSERTED.
    // `req.sizes()` is async, so the `requestfinished` handler cannot finish
    // synchronously. Previously the handler was itself `async` and its promise
    // was dropped on the floor: `bytes` was asserted while an unknown number of
    // size lookups were still in flight, and every one of them could only ADD to
    // the total. The race was therefore ONE-SIDED — an unfinished handler made
    // the measured weight SMALLER, i.e. it could only ever push the page UNDER
    // budget. A budget that can only fail honestly is not a budget.
    //
    // The handler now stays synchronous in its bookkeeping and parks each size
    // lookup in `pending`, which is drained to a fixed point below.
    const pending = [];
    page.on('requestfinished', (req) => {
      requests++;
      pending.push((async () => {
        try {
          const s = await req.sizes();
          bytes += (s.responseBodySize || 0) + (s.responseHeadersSize || 0);
        } catch (e) {
          // A request whose size could not be read contributes 0 bytes, which
          // biases the total DOWNWARD — exactly the direction that lets a page
          // pass dishonestly. Count it and assert on it rather than swallowing it.
          unsized++;
        }
      })());
    });

    await page.goto(p.base + p.path, { waitUntil: 'load' });
    await page.waitForLoadState('networkidle');

    // Drain to a fixed point: awaiting the current batch can itself let further
    // `requestfinished` events land, so keep going until the queue stops growing.
    // After this loop every size lookup has resolved and `bytes` is final.
    for (let n = -1; n !== pending.length; ) {
      n = pending.length;
      await Promise.all(pending);
    }
    // Nothing may be added to the total after this point.
    page.removeAllListeners('requestfinished');

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

    writeRow({
      site: p.site, path: p.path, browser: testInfo.project.name,
      transferredBytes: bytes, requests, unsizedRequests: unsized,
    });

    // eslint-disable-next-line no-console
    console.log(`[perf] ${p.site}${p.path} [${testInfo.project.name}] bytes=${bytes} requests=${requests} unsized=${unsized} lcpMs=${lcpMs}`);

    // Assert the measurement is COMPLETE before asserting it is within budget:
    // an unsized request is a hole in the total, and a budget checked against an
    // incomplete total is not a budget.
    expect(unsized, `${unsized} of ${requests} request(s) reported no size — the byte total is incomplete and would under-report`).toBe(0);
    expect(bytes, `transferred bytes ${bytes} over budget ${BUDGET.maxBytes}`).toBeLessThan(BUDGET.maxBytes);
    expect(requests, `request count ${requests} over budget ${BUDGET.maxRequests}`).toBeLessThan(BUDGET.maxRequests);
  });
}
