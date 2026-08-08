const { defineConfig, devices } = require('@playwright/test');

// Dedicated config for the PERMANENT v1.6.1 regression suite.
// Runs the restyle/SEO regression spec against LIVE production URLs (read-only).
// No webServer: we intentionally do NOT spin up local http.server instances so
// the suite is a pure external smoke of what is actually shipped. Chromium only
// (the task's required engine); override BASE via VASIC_BASE / MILOS_BASE env vars.
module.exports = defineConfig({
  testDir: './tests',
  testMatch: /(restyle-seo-regression|v170-fixes|v171-hardcoding)\.spec\.js/,
  timeout: 60000,
  expect: { timeout: 10000 },
  fullyParallel: true,
  retries: 1, // live network flake tolerance; assertions are deterministic
  reporter: [['list']],
  use: {
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    ignoreHTTPSErrors: false,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
