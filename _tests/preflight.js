#!/usr/bin/env node
// =============================================================================
// HARNESS PREFLIGHT — answers "can this suite honestly run?", and NOTHING else.
//
// WHY THIS FILE EXISTS
// --------------------
// Measured 2026-09-06 on this host, `npx playwright test tests/ui-l10n-chrome.spec.js`
// reported 10 FAILED / 8 passed. Two completely different things were wearing
// the same red:
//
//   * 6 of the 10 were `browserType.launch: Host system is missing dependencies
//     to run browsers.` — the webkit project cannot start AT ALL here. Every
//     webkit test failed, INCLUDING the four vasic.digital ones that pass on
//     chromium. Nothing was tested; the suite said the site was broken.
//   * 2 of the 10 were `expect(200).toBe(404)` on
//     `${MV_BASE}/products/ru/catalogizer.html`. That page exists in the
//     milosvasic.ru SOURCE but not under `milosvasic.ru/_site`, which is the
//     directory playwright.config.js actually serves. `_site` holds EIGHT
//     tracked files and exactly one rendered page. The site was fine; the
//     served corpus was a fragment.
//
// Both are INFRASTRUCTURE faults reported as CONTENT failures. That inversion
// is the specific defect this file exists to prevent: it sends a reader hunting
// a site regression that is not there, and — the expensive direction — it
// teaches them that red in this suite means "environment again", which is how a
// real regression walks through.
//
// scripts/pre-push-gates.sh already had the right SHAPE for this: its
// `precondition()` returns a stated SKIP reason (§11.4.3) rather than a
// failure, and PREPUSH_STRICT=1 promotes a SKIP to a failure for a release
// sweep. What it lacked was evidence. It checked `_site/index.html` exists —
// which is true of the eight-file fragment too, so the one file a fragment is
// guaranteed to have was the whole test — and it never asked whether a browser
// could launch.
//
// THE CONTRACT
// ------------
// This program has TWO possible verdicts and deliberately no third:
//
//   0  READY            — every declared browser launches AND every route the
//                         non-ignored specs request exists under the root that
//                         will be served. Assertions that run now are ABOUT the
//                         sites.
//   2  CANNOT DETERMINE — something the suite needs is absent. Named, with the
//                         exact command that fixes it.
//
// It NEVER exits 1. Exit 1 is a claim about the CONTENT of a site, and a
// preflight has not looked at any content. Adding a 1 here would recreate the
// exact confusion the file exists to remove.
//
// NOTHING IS HARDCODED
// --------------------
// The browser list comes from playwright.config.js's own `projects`. The route
// list is DERIVED from the specs: each spec declares its bases on one line
// (`const { MV_BASE: MV } = require('../env.js')`), and every `page.goto()` in
// the file is resolved through that binding. A spec added tomorrow is covered
// without editing this file, and a roster that cannot drift is worth more than
// one that is merely correct today.
//
// USAGE
//   node preflight.js                 # human-readable, exit 0 or 2
//   node preflight.js --json          # machine-readable report on stdout
//   node preflight.js --project=chromium[,firefox]
//                                     # probe only these browsers (gate 6 runs
//                                     # chromium alone, so it must not be held
//                                     # to webkit's system libraries)
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');

const HERE = __dirname;
const REPO = path.resolve(HERE, '..');

// The roots playwright.config.js serves. Kept beside the config's own values
// rather than re-derived, because a preflight that checks a DIFFERENT directory
// from the one served is worse than no preflight: it would go green on a tree
// the suite cannot read.
const ROOTS = {
  VD_BASE: path.join(REPO, 'vasic.digital'),
  MV_BASE: path.join(REPO, 'milosvasic.ru', '_site'),
};

const argv = process.argv.slice(2);
const asJson = argv.includes('--json');
const projArg = argv.find((a) => a.startsWith('--project='));

// ---- 0. Registry contract: --prove-failure and --root -----------------------
// scripts/check-registry.tsv requires every registered check to expose its
// §1.1 paired proof under a flag, and to DEMONSTRATE a three-valued exit by
// being pointed at a root that does not exist. Both are honoured here so this
// check is registrable on the same terms as every other one, rather than
// arriving with an exemption.
const rootArg = argv.find((a) => a.startsWith('--root'));
if (argv.includes('--prove-failure')) {
  const { spawnSync } = require('child_process');
  const r = spawnSync('bash', [path.join(HERE, 'prove-preflight.sh')], { stdio: 'inherit' });
  process.exit(r.status === null ? 2 : r.status);
}
if (rootArg) {
  // A root this program cannot read is a CANNOT-DETERMINE, never a finding —
  // the same rule the rest of the file lives by.
  const idx = argv.indexOf(rootArg);
  const val = rootArg.includes('=') ? rootArg.split('=')[1] : argv[idx + 1];
  if (!val || !fs.existsSync(val)) {
    process.stdout.write(`CANNOT DETERMINE (2) — --root "${val || ''}" does not exist; nothing was inspected.\n`);
    process.exit(2);
  }
}

// ---- 1. What does the config declare? ---------------------------------------
// Read from the config itself so that adding a project there is automatically
// probed here. A require() failure is itself a CANNOT-DETERMINE, not a crash:
// the point of this program is to explain, not to stack-trace.
function readConfig() {
  try {
    const cfg = require(path.join(HERE, 'playwright.config.js'));
    const c = cfg && cfg.default ? cfg.default : cfg;
    return {
      projects: Array.isArray(c.projects) ? c.projects.map((p) => p.name).filter(Boolean) : [],
      testIgnore: c.testIgnore || null,
      testDir: c.testDir || 'tests',
    };
  } catch (e) {
    return { error: `playwright.config.js could not be loaded: ${e.message}` };
  }
}

// ---- 2. Which specs will actually run? --------------------------------------
// testIgnore is honoured. Demanding that `_site` carry a route only the LIVE
// config requests would fail this host for a file it is right not to have.
function specsInScope(cfg) {
  const dir = path.join(HERE, cfg.testDir);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.spec.js'))
    .filter((f) => !(cfg.testIgnore instanceof RegExp && cfg.testIgnore.test(f)))
    .map((f) => path.join(dir, f));
}

// ---- 3. Which routes do those specs request? --------------------------------
// Two steps, because an alias is local to its file: first learn what this file
// calls MV_BASE and VD_BASE, then resolve every goto() through that binding.
function bindingsFor(src) {
  // `const { MV_BASE: MV, VD_BASE } = require('../env.js')` — captures both the
  // renamed and the bare form.
  const out = {};
  const m = src.match(/const\s*\{([^}]*)\}\s*=\s*require\(\s*['"]\.\.\/env\.js['"]\s*\)/);
  if (!m) return out;
  for (const part of m[1].split(',')) {
    const p = part.trim();
    if (!p) continue;
    const renamed = p.match(/^(\w+)\s*:\s*(\w+)$/);
    if (renamed) {
      if (ROOTS[renamed[1]]) out[renamed[2]] = renamed[1];
    } else if (ROOTS[p]) {
      out[p] = p;
    }
  }
  return out;
}

function routesFor(file) {
  const src = fs.readFileSync(file, 'utf8');
  const bind = bindingsFor(src);
  const found = [];
  if (Object.keys(bind).length === 0) return found;

  // `page.goto(`${MV}/products/ru/catalogizer.html`)` and `page.goto(MV)`.
  // A template carrying a second ${...} is a COMPUTED route (a loop over
  // languages, say); it is reported as unresolved rather than guessed at,
  // because a preflight that invents a path can go green on a route no spec
  // ever requests.
  const tpl = /goto\(\s*`\$\{(\w+)\}([^`]*)`/g;
  let m;
  while ((m = tpl.exec(src)) !== null) {
    const base = bind[m[1]];
    if (!base) continue;
    const p = m[2];
    if (p.includes('${')) {
      found.push({ base, route: p, computed: true });
      continue;
    }
    found.push({ base, route: p || '/', computed: false });
  }

  const bare = /goto\(\s*(\w+)\s*[),]/g;
  while ((m = bare.exec(src)) !== null) {
    const base = bind[m[1]];
    if (base) found.push({ base, route: '/', computed: false });
  }

  // TABLE-DRIVEN specs — the dominant shape here, and the one a goto-only
  // reader is blind to. seo-meta, security-hardening and interactive-behavior
  // all declare rows like
  //     { site: 'milosvasic.ru', base: MV_BASE, path: '/portfolio/' }
  // and then loop `page.goto(p.base + p.path)`. The goto carries no literal at
  // all, so extracting only from goto() found 2 missing routes on a tree where
  // the suite went on to fail 69 tests. Under-reporting the size of a gap is
  // its own dishonesty: it invites "only two pages missing, ship it".
  //
  // Each row is read as ONE object literal, so `base` and `path` are paired by
  // the braces that actually contain them rather than by nearness in the file.
  const objs = src.match(/\{[^{}]*\}/g) || [];
  for (const o of objs) {
    const b = o.match(/\bbase\s*:\s*(\w+)/);
    const p = o.match(/\bpath\s*:\s*['"]([^'"]*)['"]/);
    if (!b || !p) continue;
    const base = bind[b[1]];
    if (!base) continue;
    found.push({ base, route: p[1] || '/', computed: false });
  }
  return found;
}

// A URL path becomes a file the static server can serve. `python3 -m
// http.server` resolves a directory to its index.html, so the check mirrors
// that exactly rather than approximating it.
function resolves(rootDir, route) {
  const clean = route.split('?')[0].split('#')[0];
  const rel = clean.replace(/^\/+/, '');
  const target = path.join(rootDir, rel);
  if (rel === '' ) return fs.existsSync(path.join(rootDir, 'index.html'));
  if (fs.existsSync(target)) {
    if (fs.statSync(target).isDirectory()) return fs.existsSync(path.join(target, 'index.html'));
    return true;
  }
  return false;
}

// ---- 4. Can each declared browser actually start? ---------------------------
// The npm package being installed is NOT evidence that a browser runs: on this
// host `@playwright/test` is present and webkit still cannot launch, because
// the failure is in the system libraries the browser binary links against.
// Checking the package was checking the wrong thing.
async function probeBrowsers(names) {
  const results = [];
  let pw;
  try {
    pw = require('@playwright/test');
  } catch (e) {
    return names.map((n) => ({
      name: n,
      ok: false,
      reason: '@playwright/test is not installed — run: (cd _tests && npm ci)',
    }));
  }
  for (const n of names) {
    if (!pw[n]) {
      results.push({ name: n, ok: false, reason: `playwright exposes no browser type "${n}"` });
      continue;
    }
    try {
      const b = await pw[n].launch();
      await b.close();
      results.push({ name: n, ok: true, reason: 'launched and closed cleanly' });
    } catch (e) {
      // Playwright's launch error puts the headline on line 1 and the ACTUAL
      // cause several lines down, inside a box-drawn banner. Taking line 1
      // alone yields the bare string "browserType.launch:" — a reason that
      // states nothing, in a file whose entire purpose is to state the reason.
      // So: first line, plus the first line that carries real prose.
      const lines = String(e.message)
        .split('\n')
        .map((s) => s.replace(/[║╔╗╚╝═│┌┐└┘─]/g, '').trim())
        .filter(Boolean);
      const head = lines[0] || 'launch failed';
      const cause = lines.slice(1).find((s) => /[a-z]{3}/.test(s) && s !== head);
      results.push({
        name: n,
        ok: false,
        reason: `${head}${cause ? ' ' + cause : ''} — run: (cd _tests && npx playwright install --with-deps ${n})`,
      });
    }
  }
  return results;
}

// ---- main -------------------------------------------------------------------
(async function main() {
  const report = { ready: false, browsers: [], routes: { missing: [], computed: [], checked: 0 }, notes: [] };

  const cfg = readConfig();
  if (cfg.error) {
    report.notes.push(cfg.error);
    emit(report, 2);
    return;
  }

  const wanted = projArg ? projArg.split('=')[1].split(',').map((s) => s.trim()).filter(Boolean) : cfg.projects;
  if (wanted.length === 0) report.notes.push('playwright.config.js declares no projects — nothing to probe');
  report.browsers = await probeBrowsers(wanted);

  for (const [key, dir] of Object.entries(ROOTS)) {
    if (!fs.existsSync(dir)) {
      report.notes.push(
        `${key} serves ${path.relative(REPO, dir)}, which does not exist — ` +
          (key === 'MV_BASE'
            ? 'run: (cd milosvasic.ru && bundle exec jekyll build --destination _site)'
            : 'run: git submodule update --init vasic.digital')
      );
    }
  }

  for (const file of specsInScope(cfg)) {
    for (const r of routesFor(file)) {
      const rootDir = ROOTS[r.base];
      if (!rootDir || !fs.existsSync(rootDir)) continue;
      if (r.computed) {
        report.routes.computed.push({ spec: path.basename(file), base: r.base, route: r.route });
        continue;
      }
      report.routes.checked += 1;
      if (!resolves(rootDir, r.route)) {
        report.routes.missing.push({
          spec: path.basename(file),
          base: r.base,
          route: r.route,
          servedFrom: path.relative(REPO, rootDir),
        });
      }
    }
  }

  const browsersOk = report.browsers.every((b) => b.ok);
  const routesOk = report.routes.missing.length === 0;
  report.ready = browsersOk && routesOk && report.notes.length === 0;
  emit(report, report.ready ? 0 : 2);
})();

function emit(report, code) {
  if (asJson) {
    process.stdout.write(JSON.stringify(report, null, 2) + '\n');
    process.exit(code);
  }
  const say = (s) => process.stdout.write(s + '\n');
  say('=== harness preflight ===');
  for (const b of report.browsers) say(`  browser ${b.ok ? 'OK     ' : 'BLOCKED'} ${b.name}: ${b.reason}`);
  say(`  routes checked: ${report.routes.checked}`);
  if (report.routes.computed.length) {
    say(`  routes computed at run time (not checkable here): ${report.routes.computed.length}`);
  }
  for (const m of report.routes.missing) {
    say(`  route MISSING  ${m.route}  requested by ${m.spec}  served from ${m.servedFrom}`);
  }
  if (report.routes.missing.length) {
    // Units, stated, because the two numbers differ by an order of magnitude
    // and the smaller one invites "only a few pages, ship it". Measured
    // 2026-09-06: SIX missing PAGES produced SIXTY-NINE failing TESTS, because
    // each page carries many assertions — seo-meta.spec.js alone reconciles
    // exactly, 2 pages x 6 tests = 12 failures. A count here is PAGES.
    say(
      `  ^ that is ${report.routes.missing.length} missing PAGE(s), not ${report.routes.missing.length} failing tests — ` +
        'each page carries many assertions, and specs that navigate INTO a missing page fail downstream where no static reader can see it.'
    );
  }
  for (const n of report.notes) say(`  note: ${n}`);
  say(
    code === 0
      ? 'READY (0) — every declared browser launches and every derivable route exists.'
      : 'CANNOT DETERMINE (2) — the suite cannot honestly run. Nothing above is a claim about site content.'
  );
  process.exit(code);
}
