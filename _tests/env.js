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
//
// DYNAMIC PORT DISCOVERY (added 2026-09-19)
// ------------------------------------------
// A bare hardcoded fallback (the ONLY behaviour this file had before) still
// collides with whatever else happens to be listening on that literal port on
// a given host — measured live: an unrelated `llama-server` process holding
// 8082 made vasic's own pre-push gate 6 fail with a bind error, not a real
// site defect. The Containers Submodule's own CLAUDE.md names "service
// discovery" and "endpoint discovery" among the capabilities a consuming
// project MUST consume rather than reimplement (§11.4.76(1)/(4)); this file
// now asks it, via `_tools/containers/cmd/port-discover` (a thin CLI front
// for `pkg/serviceregistry.FindAvailablePort`/`Discover`, mirroring the exact
// pattern `_tools/containers/cmd/runtime-probe` already established for
// runtime detection). An explicit env var (VD_PORT/MV_PORT/...) still wins
// outright, unchanged — discovery only replaces the LITERAL FALLBACK, never
// an operator's explicit choice. Discovery finds a genuinely free port near
// the historical default (reusing the SAME port across repeated runs when it
// is still free, so the suite does not needlessly churn through the range),
// and REGISTERS it in a shared, disk-persisted registry
// (`$VASIC_ROOT/.service-registry/services.json`) so any OTHER process can
// discover which port this run picked, by name, without re-deriving it.
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync, execFileSync } = require('child_process');

// A port is VALIDATED, never trusted. An unparseable value throws at require()
// time instead of falling back to the default, because silently binding a port
// the operator did not ask for is the precise silent-misbehaviour class the
// audit that produced this file exists to prevent — and a harness that listens
// somewhere unexpected still reports its results as if they were about the site.
function port(raw, fallback, name) {
  if (raw === undefined || raw === null || String(raw).trim() === '') return discoverPort(fallback, name);
  const n = Number(String(raw).trim());
  if (!Number.isInteger(n) || n < 1 || n > 65535) {
    throw new Error(`${name}="${raw}" is not a valid TCP port (1-65535)`);
  }
  return n;
}

// attachPort is `port()` WITHOUT dynamic discovery, for the one variable that
// names an ALREADY-RUNNING server this harness attaches to rather than one it
// starts itself (UI_L10N2_PORT — discovering a fresh free port for it would
// be actively wrong: it would report a port with nothing listening on it,
// rather than the real port whatever started that server actually used).
function attachPort(raw, fallback, name) {
  if (raw === undefined || raw === null || String(raw).trim() === '') return fallback;
  const n = Number(String(raw).trim());
  if (!Number.isInteger(n) || n < 1 || n > 65535) {
    throw new Error(`${name}="${raw}" is not a valid TCP port (1-65535)`);
  }
  return n;
}

// findRepoRoot mirrors _tests/export/validate-pdf.js's own parent-walk (the
// established convention in this tree for locating the umbrella root from a
// file that may be required from several different depths).
function findRepoRoot(start) {
  for (let dir = start; ;) {
    if (fs.existsSync(path.join(dir, '.gitmodules')) && fs.existsSync(path.join(dir, '_tools'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

function hasTool(n) { try { execFileSync('which', [n], { stdio: 'pipe' }); return true; } catch { return false; } }

// discoverPort asks port-discover for a genuinely free port near `fallback`,
// building the CLI on demand if needed (never `go run` — see runtime-probe's
// own header for why that would collapse this command's three-valued exit
// codes into one). On ANY failure to discover dynamically (no repo root
// found, no `go` toolchain, a build error, or the tool itself reporting
// exitUndetermined/exitFail), this degrades to the historical hardcoded
// literal — LOUDLY, on stderr, never silently, matching this file's own
// standing rule above ("silently binding a port... is the precise
// silent-misbehaviour class... this file exists to prevent").
function discoverPort(fallback, name) {
  const root = findRepoRoot(__dirname);
  if (!root) {
    process.stderr.write(`[env.js] WARNING: could not locate the umbrella root from ${__dirname}; ` +
      `falling back to the hardcoded ${name} default ${fallback} (dynamic discovery skipped)\n`);
    return fallback;
  }
  const mod = path.join(root, '_tools', 'containers');
  const bin = path.join(mod, 'bin', 'port-discover');
  if (!fs.existsSync(bin)) {
    if (!hasTool('go')) {
      process.stderr.write(`[env.js] WARNING: ${path.relative(root, bin)} is not built and go is absent; ` +
        `falling back to the hardcoded ${name} default ${fallback} (dynamic discovery skipped)\n`);
      return fallback;
    }
    try {
      execFileSync('go', ['build', '-o', bin, './cmd/port-discover'], { cwd: mod, stdio: 'pipe' });
    } catch (e) {
      process.stderr.write(`[env.js] WARNING: building port-discover failed (${String(e.message || e).split('\n')[0]}); ` +
        `falling back to the hardcoded ${name} default ${fallback} (dynamic discovery skipped)\n`);
      return fallback;
    }
  }
  const serviceName = `vasic-tests-${name.toLowerCase()}`;
  const r = spawnSync(bin, [serviceName, String(fallback)], { encoding: 'utf8' });
  if (r.error || r.status !== 0) {
    process.stderr.write(`[env.js] WARNING: port-discover for ${name} exited ${r.status} ` +
      `(${(r.stderr || '').trim()}); falling back to the hardcoded default ${fallback}\n`);
    return fallback;
  }
  const discovered = Number(String(r.stdout).trim());
  if (!Number.isInteger(discovered) || discovered < 1 || discovered > 65535) {
    process.stderr.write(`[env.js] WARNING: port-discover for ${name} printed a non-port value ` +
      `${JSON.stringify(r.stdout)}; falling back to the hardcoded default ${fallback}\n`);
    return fallback;
  }
  return discovered;
}

const HOST = process.env.TEST_HOST || 'localhost';

// vasic.digital is committed static HTML; milosvasic.ru is the rendered _site.
const VD_PORT = port(process.env.VD_PORT, 8401, 'VD_PORT');
const MV_PORT = port(process.env.MV_PORT, 8082, 'MV_PORT');

// The motion audit runs its OWN pair on purpose, so it can be driven while the
// Playwright suite is holding the two above.
const MOTION_VD_PORT = port(process.env.MOTION_VD_PORT, 8481, 'MOTION_VD_PORT');
const MOTION_MV_PORT = port(process.env.MOTION_MV_PORT, 8482, 'MOTION_MV_PORT');

// ui-l10n2-verify.js attaches to a server somebody else already started —
// attachPort(), never discoverPort(): allocating a fresh free port here would
// report a port nothing is listening on.
const UI_L10N2_PORT = attachPort(process.env.UI_L10N2_PORT, 8791, 'UI_L10N2_PORT');

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
