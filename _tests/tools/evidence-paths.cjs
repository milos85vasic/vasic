/* =============================================================================
 * evidence-paths.cjs — the ONE place that decides where volatile test evidence
 * is written (UG-15, docs/operator/umbrella-gap-register-2026-11-24.md).
 *
 * THE DEFECT THIS CLOSES
 * ----------------------
 * Two kinds of TRACKED files under _tests/evidence/ were rewritten by every
 * ordinary Playwright run:
 *   * evidence/test-types/perf-budget.json — transferred bytes measured against
 *     whatever the sites serve that day (the milosvasic.ru rows moved ~26 KB
 *     between two runs with no change to this repository);
 *   * evidence/homepages/*.png — full-page screenshots of the live-served sites.
 * A routine run therefore left the working tree dirty with changes that are a
 * function of the served content and the host, not of this repository. The
 * churn buried real regressions and made "git status clean" meaningless.
 * scripts/pre-push-gates.sh papered over it by restoring the directory after a
 * passing run; a manual run had no such protection.
 *
 * THE RULE
 * --------
 * Tracked evidence is rewritten ONLY by a deliberate refresh:
 *     EVIDENCE_REFRESH=1 npx playwright test ...
 * Every other run writes the same artifacts under _tests/test-results/
 * evidence-scratch/ (git-ignored), so the run still produces its numbers and
 * images — they are simply never silently promoted to tracked evidence.
 *
 * scripts/verify-evidence-stability.sh enforces the rule: it executes this
 * module in both modes and fails if a spec writes into evidence/ by any other
 * route.
 * ========================================================================== */
'use strict';

const path = require('path');

const TESTS_ROOT = path.join(__dirname, '..');
const TRACKED = path.join(TESTS_ROOT, 'evidence');
const SCRATCH = path.join(TESTS_ROOT, 'test-results', 'evidence-scratch');

function refreshRequested(env) {
  return (env || process.env).EVIDENCE_REFRESH === '1';
}

// sub: 'homepages' | 'test-types'. Returns the directory a writer must use.
function evidenceDir(sub, env) {
  return path.join(refreshRequested(env) ? TRACKED : SCRATCH, sub);
}

module.exports = { evidenceDir, refreshRequested, TRACKED, SCRATCH };
