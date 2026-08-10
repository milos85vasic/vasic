const { defineConfig, devices } = require('@playwright/test');
const path = require('path');

// Resolve the two static site roots RELATIVE to this config (repo/_tests/..),
// so the suite runs from ANY checkout location (fresh clone, CI runner) without
// hardcoded absolute paths. REPO is the umbrella root one level up from _tests/.
const REPO = path.resolve(__dirname, '..');
const VD_ROOT = path.join(REPO, 'vasic.digital');
const MV_ROOT = path.join(REPO, 'milosvasic.ru', '_site');

module.exports = defineConfig({
  testDir: './tests',
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
      command: `python3 -m http.server 8401 --directory ${VD_ROOT}`,
      port: 8401, reuseExistingServer: false, timeout: 30000,
    },
    {
      command: `python3 -m http.server 8082 --directory ${MV_ROOT}`,
      port: 8082, reuseExistingServer: false, timeout: 30000,
    },
  ],
});
