const { defineConfig, devices } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// =============================================================================
// LIVE-PRODUCTION config — the four permanent suites that assert against what
// is ACTUALLY SHIPPED, read-only, over the public internet:
//
//   restyle-seo-regression.spec.js   v1.6.1 shipped-state regression
//   v170-fixes.spec.js               v1.7.0 six-fix regression
//   v171-hardcoding.spec.js          v1.7.1 hardcoded-content regression
//   all-languages-link-integrity.spec.js
//                                    exhaustive sitemap/link crawl, all 15 langs
//
// No webServer: we intentionally do NOT spin up local http.server instances, so
// the suite is a pure external smoke of what is deployed. Chromium only.
//
// ── DEFECT: the config claimed a spec it could not run ───────────────────────
// The first three specs read VASIC_BASE / MILOS_BASE and DEFAULT to the
// production origins, so they ran correctly here with no configuration at all.
// all-languages-link-integrity.spec.js reads DIFFERENT variables — VD_BASE /
// MV_BASE — and defaults to http://localhost:8401 / :8082, because its other
// home is playwright.config.js, which serves the local build on those ports.
// This config supplied neither those variables nor a webServer, so that spec
// hit localhost with nothing listening. Its own get() helper sets `last = 0` on
// a network throw, so the connection refusal arrived at the assertion as a
// status, and the run reported:
//
//     Error: sitemap.xml must resolve     Expected: 200   Received: 0
//
// MEASURED before this fix: 86 passed / 2 failed, and both failures were that
// one spec (once per site), while curl reached https://vasic.digital/ and
// https://milosvasic.ru/ with http=200. A connection refusal laundered through
// an expect() and reported as a production defect — exactly the confusion
// §11.4.6 forbids.
//
// FIX: point those variables at the deployed origins, which is what the spec's
// own header calls "Live mode". Not a webServer — that would serve the LOCAL
// build and silently turn a live smoke into a local one (and duplicate what
// playwright.config.js already does for this spec on three browsers). Not
// dropping it from testMatch either — _tools/deploy-langs.sh runs precisely
// this spec through this config after every deploy, and removing it would turn
// that into "No tests found", i.e. would silently delete the only post-deploy
// check the repository has against production.
// =============================================================================

// Umbrella root, one level up from _tests/ — derived, never hardcoded, so this
// config works from any checkout location (§ scripts/audit-hardcoded-paths.sh).
const REPO = path.resolve(__dirname, '..');

// The live origin of a site, read from the CNAME it actually publishes — the
// same source of truth _tools/deploy-langs.sh uses — falling back to the known
// domain when the submodule is not checked out. First readable, non-empty
// candidate wins.
function deployedOrigin(fallbackHost, ...cnameCandidates) {
  for (const rel of cnameCandidates) {
    try {
      const host = fs.readFileSync(path.join(REPO, rel), 'utf8').replace(/\s+/g, '');
      if (host) return `https://${host}`;
    } catch { /* absent in this checkout — try the next candidate */ }
  }
  return `https://${fallbackHost}`;
}

const VASIC_ORIGIN = deployedOrigin('vasic.digital', 'vasic.digital/CNAME');
const MILOS_ORIGIN = deployedOrigin('milosvasic.ru', 'milosvasic.ru/_site/CNAME', 'milosvasic.ru/CNAME');

// Defaults only — an explicitly exported value always wins, so staging runs
// (VASIC_BASE=https://staging... / VD_BASE=...) and deploy-langs.sh's own
// CNAME-derived exports are untouched. Assigning process.env here is the
// documented Playwright pattern for configuring specs (the same mechanism as
// dotenv in a config file): the config is evaluated in the main process before
// any worker is forked, and workers inherit its environment.
process.env.VASIC_BASE = process.env.VASIC_BASE || VASIC_ORIGIN; // restyle/v170/v171
process.env.MILOS_BASE = process.env.MILOS_BASE || MILOS_ORIGIN;
process.env.VD_BASE    = process.env.VD_BASE    || VASIC_ORIGIN; // link-integrity
process.env.MV_BASE    = process.env.MV_BASE    || MILOS_ORIGIN;

module.exports = defineConfig({
  testDir: './tests',
  testMatch: /(restyle-seo-regression|v170-fixes|v171-hardcoding|all-languages-link-integrity)\.spec\.js/,
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
