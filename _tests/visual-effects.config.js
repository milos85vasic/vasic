const { defineConfig, devices } = require('@playwright/test');
const path = require('node:path');

// Focused config for the visual-effects evidence run: chromium only, serving
// just vasic.digital (so it never depends on milosvasic.ru/_site). Reuses an
// already-running :8401 server if present.
//
// The static root is derived from this config's own location (repo/_tests/ ->
// ..) so the run works from ANY checkout, never a hardcoded absolute path.
// VASIC_ROOT overrides the default when the repo root is elsewhere.
const REPO = process.env.VASIC_ROOT || path.resolve(__dirname, '..');
const VD_ROOT = path.join(REPO, 'vasic.digital');
// webServer.command is handed to a shell, so single-quote the interpolated path
// (escaping any embedded quote) — a repo path containing spaces still works.
const shq = (p) => `'${String(p).replace(/'/g, `'\\''`)}'`;
module.exports = defineConfig({
  testDir: __dirname,
  testMatch: 'visual-effects.spec.js',
  timeout: 60000,
  expect: { timeout: 7000 },
  reporter: [['list']],
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: `python3 -m http.server 8401 --directory ${shq(VD_ROOT)}`,
    port: 8401,
    reuseExistingServer: true,
    timeout: 30000,
  },
});
