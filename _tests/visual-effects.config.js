const { defineConfig, devices } = require('@playwright/test');

// Focused config for the visual-effects evidence run: chromium only, serving
// just vasic.digital (so it never depends on milosvasic.ru/_site). Reuses an
// already-running :8401 server if present.
module.exports = defineConfig({
  testDir: __dirname,
  testMatch: 'visual-effects.spec.js',
  timeout: 60000,
  expect: { timeout: 7000 },
  reporter: [['list']],
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'python3 -m http.server 8401 --directory /Volumes/T7/Projects/vasic/vasic.digital',
    port: 8401,
    reuseExistingServer: true,
    timeout: 30000,
  },
});
