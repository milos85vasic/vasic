// =============================================================================
// The ONE place this harness learns where to BIND and what to REQUEST.
//
// WHY THIS FILE EXISTS
// --------------------
// Until 2026-09-02 every spec carried its own `const BASE =
// 'http://localhost:8401'` and both configs carried their own `port: 8401`.
// scripts/audit-environment-assumptions.sh carried that as findings F13 and
// F14 — 45 baselined ENDPOINT occurrences across 22 files. Two consequences,
// neither hypothetical:
//
//   1. Two checkouts cannot run the suite at the same time. The second
//      webServer fails to bind, and playwright.config.js sets
//      `reuseExistingServer: false`, so the run dies rather than attaching to
//      whatever is already there.
//   2. Nothing tied the port a CONFIG binds to the base URL a SPEC requests.
//      Change one and forget the other and the whole suite talks to a port
//      with nothing listening — and, because a connection refusal reaches the
//      assertion as a status rather than as an error, the failure is reported
//      as a defect in the SITE. playwright.live.config.js already carries a
//      measured instance of exactly that confusion in its own header.
//
// Derived once, here; imported by both configs, every spec, and the two
// standalone drivers.
//
// OVERRIDES
// ---------
//   VD_PORT / MV_PORT          TCP ports the harness binds its static servers to
//   VD_BASE / MV_BASE          a base URL that already exists elsewhere. This is
//                              the pair playwright.live.config.js sets to the
//                              deployed origins before any worker is forked, and
//                              the pair _tools/deploy-langs.sh exports around the
//                              post-deploy run — both keep working unchanged.
//   MOTION_VD_PORT / MOTION_MV_PORT, MOTION_VD_BASE / MOTION_MV_BASE
//                              the read-only motion audit's own server pair
//   UI_L10N2_PORT / UI_L10N2_BASE
//                              the server ui-l10n2-verify.js attaches to
//   TEST_HOST                  the host name every derived base is built from
//
// Setting a PORT alone is enough: the matching BASE is derived FROM it, which
// is what makes the two impossible to disagree. Setting a BASE alone is also
// enough and wins outright — a base that points off-box has no local port to
// bind in the first place.
// =============================================================================

'use strict';

// A port is VALIDATED, never trusted. An unparseable value throws at require()
// time instead of falling back to the default, because silently binding a port
// the operator did not ask for is the precise silent-misbehaviour class the
// audit that produced this file exists to prevent — and a harness that listens
// somewhere unexpected still reports its results as if they were about the site.
function port(raw, fallback, name) {
  if (raw === undefined || raw === null || String(raw).trim() === '') return fallback;
  const n = Number(String(raw).trim());
  if (!Number.isInteger(n) || n < 1 || n > 65535) {
    throw new Error(`${name}="${raw}" is not a valid TCP port (1-65535)`);
  }
  return n;
}

const HOST = process.env.TEST_HOST || 'localhost';

// vasic.digital is committed static HTML; milosvasic.ru is the rendered _site.
const VD_PORT = port(process.env.VD_PORT, 8401, 'VD_PORT');
const MV_PORT = port(process.env.MV_PORT, 8082, 'MV_PORT');

// The motion audit runs its OWN pair on purpose, so it can be driven while the
// Playwright suite is holding the two above.
const MOTION_VD_PORT = port(process.env.MOTION_VD_PORT, 8481, 'MOTION_VD_PORT');
const MOTION_MV_PORT = port(process.env.MOTION_MV_PORT, 8482, 'MOTION_MV_PORT');

// ui-l10n2-verify.js attaches to a server somebody else already started.
const UI_L10N2_PORT = port(process.env.UI_L10N2_PORT, 8791, 'UI_L10N2_PORT');

const VD_BASE = process.env.VD_BASE || `http://${HOST}:${VD_PORT}`;
const MV_BASE = process.env.MV_BASE || `http://${HOST}:${MV_PORT}`;
const MOTION_VD_BASE = process.env.MOTION_VD_BASE || `http://${HOST}:${MOTION_VD_PORT}`;
const MOTION_MV_BASE = process.env.MOTION_MV_BASE || `http://${HOST}:${MOTION_MV_PORT}`;
const UI_L10N2_BASE = process.env.UI_L10N2_BASE || `http://${HOST}:${UI_L10N2_PORT}`;

module.exports = {
  HOST,
  VD_PORT, MV_PORT,
  VD_BASE, MV_BASE,
  MOTION_VD_PORT, MOTION_MV_PORT,
  MOTION_VD_BASE, MOTION_MV_BASE,
  UI_L10N2_PORT, UI_L10N2_BASE,
};
