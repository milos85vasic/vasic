const { defineConfig, devices } = require('@playwright/test');
const path = require('path');

// The ports are DERIVED, not frozen — VD_PORT / MV_PORT, from ./env.js, which
// is the same module every spec reads its base URL from. Binding here and
// requesting there used to be two independent literals; they are now one value,
// so they cannot drift apart, and two checkouts can run the suite at once with
//     VD_PORT=9401 MV_PORT=9082 npx playwright test
// See the header of ./env.js for the measured defect this replaced (F13/F14).
const { VD_PORT, MV_PORT } = require('./env.js');

// Resolve the two static site roots RELATIVE to this config (repo/_tests/..),
// so the suite runs from ANY checkout location (fresh clone, CI runner) without
// hardcoded absolute paths. REPO is the umbrella root one level up from _tests/.
const REPO = path.resolve(__dirname, '..');
const VD_ROOT = path.join(REPO, 'vasic.digital');
const MV_ROOT = path.join(REPO, 'milosvasic.ru', '_site');

module.exports = defineConfig({
  testDir: './tests',

  // Runs ONCE before any worker starts and — via the teardown it returns — ONCE
  // after every worker has exited. It is what makes
  // evidence/test-types/perf-budget.json a function of exactly one run: the
  // setup clears the per-run row directory, each perf-budget test drops its own
  // row file, and the teardown writes the tracked JSON from that directory
  // alone. The previous per-worker `afterAll` read-modify-write merged each
  // worker's subset into whatever was already on disk, which is why the
  // committed artifact accumulated rows from three browsers across many runs.
  globalSetup: require.resolve('./tools/perf-budget-rows.cjs'),

  // These THREE specs assert against the LIVE production sites over the public
  // internet (their VASIC_BASE/MILOS_BASE default to https://vasic.digital and
  // https://milosvasic.ru). They are claimed by playwright.live.config.js, whose
  // testMatch names these three PLUS all-languages-link-integrity — that fourth one
  // is deliberately NOT ignored here, because it is hermetic (it reads VD_BASE/
  // MV_BASE, defaulting to localhost) and gate 6 excludes it by --grep-invert
  // instead. This config previously had no testIgnore at all, so
  // it ran them too, giving the local suite a hidden dependency on public DNS.
  //
  // Measured consequence: a pre-push run produced 30 failures — 12 net::ERR_TIMED_OUT,
  // 8 net::ERR_NAME_NOT_RESOLVED, 5 getaddrinfo EAI_AGAIN, 77 60s page.goto timeouts —
  // and ZERO genuine assertion failures (0 'Error: expect(', 0 Expected:/Received:
  // pairs), while curl reached both sites with http=200 and a valid certificate.
  // That is a reachability problem on the runner, reported as a site defect.
  //
  // This is NOT relaxing them. They keep every assertion and still run, via
  //     npx playwright test --config=playwright.live.config.js
  // which is where live-production verification belongs — alongside deployment,
  // not gating a push of source that has not been deployed yet.
  testIgnore: /(restyle-seo-regression|v170-fixes|v171-hardcoding)\.spec\.js/,
  timeout: 60000,
  expect: { timeout: 7000 },
  fullyParallel: true,
  // Absorb load-induced flakiness (smooth-scroll/animation timing under parallel
  // CPU contention). A genuine failure still fails both attempts; Playwright
  // reports a pass-on-retry as "flaky" so it stays visible, never hidden.
  retries: 1,
  reporter: [['list'], ['html', { outputFolder: 'evidence/html-report', open: 'never' }]],
  use: { screenshot: 'only-on-failure', trace: 'retain-on-failure' },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox',  use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit',   use: { ...devices['Desktop Safari'] } },
  ],
  webServer: [
    {
      command: `python3 -m http.server ${VD_PORT} --directory ${VD_ROOT}`,
      port: VD_PORT, reuseExistingServer: false, timeout: 30000,
    },
    {
      command: `python3 -m http.server ${MV_PORT} --directory ${MV_ROOT}`,
      port: MV_PORT, reuseExistingServer: false, timeout: 30000,
    },
  ],
});
