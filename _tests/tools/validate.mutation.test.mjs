#!/usr/bin/env node
/*
 * Mutation test for _tools/portfolio/validate.mjs (the anti-bluff data gate).
 *
 * §11.4.169 requires that safety validators be proven to actually FAIL on bad
 * input — a validator that always passes is bluff. This harness runs the REAL
 * validate.mjs source (copied verbatim, never re-implemented) against:
 *
 *   0. the real portfolio.json                 -> expect PASS (exit 0)
 *   1. an EXCLUDED project injected             -> expect FAIL (exit 1)
 *   2. a private:true entry that leaks repos    -> expect FAIL (exit 1)
 *   3. a tier-order break (non-monotonic order) -> expect FAIL (exit 1)
 *
 * validate.mjs resolves its target as <its-dir>/../../_content/portfolio/
 * portfolio.json, so each case builds a temp repo tree:
 *   <tmp>/_tools/portfolio/validate.mjs   (real source, copied)
 *   <tmp>/_content/portfolio/portfolio.json (mutated data)
 * and runs `node <tmp>/_tools/portfolio/validate.mjs`.
 *
 * Exit 0 = all cases behaved as expected; exit 1 = the validator failed to
 * catch a mutation (or falsely rejected the clean file).
 */
'use strict';

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '..', '..');
const REAL_VALIDATOR = path.join(REPO, '_tools', 'portfolio', 'validate.mjs');
const REAL_JSON = path.join(REPO, '_content', 'portfolio', 'portfolio.json');

const baseDoc = JSON.parse(fs.readFileSync(REAL_JSON, 'utf8'));

function runValidator(doc) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-mut-'));
  const vDir = path.join(tmp, '_tools', 'portfolio');
  const jDir = path.join(tmp, '_content', 'portfolio');
  fs.mkdirSync(vDir, { recursive: true });
  fs.mkdirSync(jDir, { recursive: true });
  fs.copyFileSync(REAL_VALIDATOR, path.join(vDir, 'validate.mjs'));
  fs.writeFileSync(path.join(jDir, 'portfolio.json'), JSON.stringify(doc, null, 2));
  let code = 0;
  let out = '';
  try {
    out = execFileSync('node', [path.join(vDir, 'validate.mjs')], { encoding: 'utf8' });
  } catch (e) {
    code = e.status === undefined ? 1 : e.status;
    out = `${e.stdout || ''}${e.stderr || ''}`;
  }
  fs.rmSync(tmp, { recursive: true, force: true });
  return { code, out };
}

// Deep clone helper.
const clone = (d) => JSON.parse(JSON.stringify(d));

const cases = [];

// Case 0: clean file must PASS.
cases.push({ name: 'clean portfolio.json', doc: clone(baseDoc), expectPass: true });

// Case 1: inject an excluded project (grabtube is on the exclusion list).
{
  const d = clone(baseDoc);
  const victim = clone(d.entries[0]);
  victim.name = 'GrabTube';
  victim.slug = 'grabtube';
  d.entries.push(victim);
  cases.push({ name: 'excluded project injected (grabtube)', doc: d, expectPass: false });
}

// Case 2: mark an entry private:true while it still lists repos (leak).
{
  const d = clone(baseDoc);
  // entries[0] (HelixTrack) has repos; flip its private flag without clearing repos.
  d.entries[0] = clone(d.entries[0]);
  d.entries[0].private = true;
  cases.push({ name: 'private:true entry leaks repo URLs', doc: d, expectPass: false });
}

// Case 3: break strictly-increasing order within a tier.
{
  const d = clone(baseDoc);
  // Find the first two entries sharing a tier and make the 2nd order <= 1st.
  const idxByTier = {};
  let broke = false;
  for (let i = 0; i < d.entries.length && !broke; i++) {
    const t = d.entries[i].tier;
    if (idxByTier[t] !== undefined) {
      d.entries[i] = clone(d.entries[i]);
      d.entries[i].order = d.entries[idxByTier[t]].order; // duplicate -> not strictly increasing
      broke = true;
    } else {
      idxByTier[t] = i;
    }
  }
  if (!broke) throw new Error('could not construct order-break mutation');
  cases.push({ name: 'tier order not strictly increasing', doc: d, expectPass: false });
}

let failed = 0;
const lines = [];
const log = (s) => { lines.push(s); console.log(s); };

log('# validate.mjs mutation test');
log(`# real validator: ${path.relative(REPO, REAL_VALIDATOR)}`);
log(`# real data:      ${path.relative(REPO, REAL_JSON)}`);
log('');

for (const c of cases) {
  const { code } = runValidator(c.doc);
  const passed = code === 0;
  const ok = passed === c.expectPass;
  if (!ok) failed++;
  const verdict = ok ? 'OK  ' : 'BAD ';
  const behaviour = passed ? 'PASS (exit 0)' : `FAIL (exit ${code})`;
  const expected = c.expectPass ? 'PASS' : 'FAIL';
  log(`[${verdict}] ${c.name.padEnd(42)} -> ${behaviour} (expected ${expected})`);
}

log('');
if (failed === 0) {
  log(`RESULT: PASS — validator caught every mutation and accepted the clean file (${cases.length}/${cases.length}).`);
  fs.writeFileSync(path.join(REPO, '_tests', 'evidence', 'test-types', 'validate-mutation.txt'), lines.join('\n') + '\n');
  process.exit(0);
} else {
  log(`RESULT: FAIL — ${failed} case(s) did not behave as expected.`);
  fs.writeFileSync(path.join(REPO, '_tests', 'evidence', 'test-types', 'validate-mutation.txt'), lines.join('\n') + '\n');
  process.exit(1);
}
