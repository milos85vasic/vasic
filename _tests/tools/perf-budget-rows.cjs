/* =============================================================================
 * perf-budget.spec.js row store — makes evidence/test-types/perf-budget.json a
 * function of exactly ONE run.
 *
 * WHY THIS FILE EXISTS
 * --------------------
 * perf-budget.spec.js used to accumulate its rows in a module-level array and
 * write the tracked JSON from an `afterAll`. Under `fullyParallel: true` with no
 * `workers:` pin there is one module instance — and therefore one `afterAll` —
 * PER WORKER PROCESS, and each of them did a read-modify-write of the same file,
 * merging whatever it found there with its own subset. Two consequences, both
 * measured on the committed artifact before this change:
 *
 *   1. The file was a UNION OVER HISTORY, not a measurement. The committed copy
 *      held 12 rows spanning chromium + firefox + webkit while its own comment
 *      said the gate runs chromium only — rows left behind by earlier runs on
 *      other browsers, kept alive indefinitely by the merge.
 *   2. Concurrent read-modify-write of one path from several processes has no
 *      defined outcome. Nothing serialised those writers.
 *
 * The fix is to stop merging. Each test drops ONE row as its own file in a
 * run-scoped directory; a single global teardown — which Playwright runs once,
 * after every worker has exited — collects that directory and writes the tracked
 * JSON from it, then deletes it. Global setup clears the directory first, so a
 * row can only be present because THIS run produced it. Nothing is inherited
 * from a previous run, and no two processes ever write the same path.
 *
 * Wired in playwright.config.js as `globalSetup`; the setup returns the teardown,
 * which is Playwright's documented way to get both from one module.
 * ========================================================================== */
'use strict';

const fs = require('fs');
const path = require('path');

const EVIDENCE = path.join(__dirname, '..', 'evidence', 'test-types');
// Dot-prefixed and deleted by the teardown: a scratch directory, never evidence.
const ROWS_DIR = path.join(EVIDENCE, '.perf-budget-rows');
const OUT_FILE = path.join(EVIDENCE, 'perf-budget.json');

// One row per site+path+browser. The name is the identity, so a retry of the
// same test overwrites its own row instead of appending a second one.
function rowFile(row) {
  const key = `${row.site}${row.path}|${row.browser}`;
  return path.join(ROWS_DIR, key.replace(/[^\w.=-]+/g, '_') + '.json');
}

// Only the STABLE, budget-meaningful fields reach the tracked file. `lcpMs` is a
// wall-clock timing that moves with host load on every run and is not asserted
// against, so persisting it made this committed evidence permanently dirty. It
// is still measured, printed on the per-test console line, and carried in the
// HTML report.
function stable(r) {
  return {
    site: r.site,
    path: r.path,
    browser: r.browser,
    transferredBytes: r.transferredBytes,
    requests: r.requests,
    unsizedRequests: r.unsizedRequests,
  };
}

function writeRow(row) {
  fs.mkdirSync(ROWS_DIR, { recursive: true });
  fs.writeFileSync(rowFile(row), JSON.stringify(stable(row), null, 2) + '\n');
}

function collect() {
  let names = [];
  try { names = fs.readdirSync(ROWS_DIR).filter((n) => n.endsWith('.json')); }
  catch (e) { return null; } // no rows at all -> this run measured nothing
  const rows = [];
  for (const n of names) {
    try { rows.push(JSON.parse(fs.readFileSync(path.join(ROWS_DIR, n), 'utf8'))); }
    catch (e) { /* a truncated row is not evidence; skip it */ }
  }
  // Deterministic order, so two identical runs produce byte-identical output.
  rows.sort((a, b) => `${a.browser}|${a.site}|${a.path}`.localeCompare(`${b.browser}|${b.site}|${b.path}`));
  return rows;
}

function clearRows() {
  fs.rmSync(ROWS_DIR, { recursive: true, force: true });
}

// globalSetup: clear the scratch dir, and hand Playwright the teardown.
function globalSetup() {
  clearRows();
  return function globalTeardown() {
    const rows = collect();
    clearRows();
    // A run that produced no rows (the whole spec filtered out by --grep, or
    // every test skipped) must NOT overwrite the committed evidence with an
    // empty array — that would be a claim this run did not make.
    if (!rows || rows.length === 0) return;
    fs.mkdirSync(EVIDENCE, { recursive: true });
    fs.writeFileSync(OUT_FILE, JSON.stringify(rows, null, 2) + '\n');
  };
}

module.exports = globalSetup;
module.exports.default = globalSetup;
module.exports.writeRow = writeRow;
module.exports.ROWS_DIR = ROWS_DIR;
module.exports.OUT_FILE = OUT_FILE;
