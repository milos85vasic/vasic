#!/usr/bin/env node
/*
 * Validator for _content/portfolio/portfolio.json (§ anti-bluff data gate).
 *
 * Asserts:
 *   1. No excluded project is present (by slug or name).
 *   2. No private:true entry exposes any repo URL.
 *   3. Every entry has all required fields (correctly typed, non-empty).
 *   4. Ordering is monotonic (strictly increasing) within each tier, and
 *      tiers appear in the canonical rank order in the array.
 *
 * Exit codes are THREE-VALUED, following this fleet's convention
 * (0 clean / 1 real finding / 2 could not determine — and 2 is NEVER a pass):
 *
 *   0 = PASS   — every assertion above was evaluated and every one holds.
 *   1 = FAIL   — the assertions were evaluated and at least one is VIOLATED.
 *   2 = COULD NOT DETERMINE — the dataset could not be read, parsed, or
 *       shaped into an evaluable list, so ZERO assertions were evaluated.
 *
 * WHY 2 EXISTS (§1.1 anti-bluff). This validator is mutation-paired: a
 * harness (_tools/portfolio/self-validate.sh) proves the gate can FAIL by
 * feeding it a golden-BAD fixture and requiring a non-zero exit. While
 * "cannot read / cannot parse" ALSO exited 1, a MISSING OR CORRUPT FIXTURE
 * was indistinguishable from a caught mutation — the harness reported
 * SATISFIED having proved nothing, which is precisely the rubber stamp its
 * own header warns about. Exit 1 must now mean, and only mean, "the
 * assertion machinery ran and found problems". Anything that prevents the
 * machinery from running at all is a HARNESS FAULT and exits 2.
 *
 * Mirrors the sibling convention in _tests/export/validate-pdf.js, whose
 * paired harness _tests/export/self-validate.sh already asserts `-eq 1`.
 */
'use strict';

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');

// Input contract: validates _content/portfolio/portfolio.json by default, but a
// caller may point it at any dataset via `--file <path>` (or a bare positional
// path). This override exists so the §1.1 mutation self-test can run the SAME
// gate against golden-good / golden-bad fixtures. Default is unchanged.
const DEFAULT_FILE = path.join(ROOT, '_content', 'portfolio', 'portfolio.json');
function resolveFileArg(argv) {
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--file' || a === '-f') return argv[i + 1] ? path.resolve(argv[i + 1]) : DEFAULT_FILE;
    if (!a.startsWith('-')) return path.resolve(a);
  }
  return DEFAULT_FILE;
}
const FILE = resolveFileArg(process.argv.slice(2));

const EXCLUSIONS = ['grabtube', 'shareconnect', 'panoptic', 'android-toolkit', 'asinka', 'yole'];
const TIERS = ['helix-primary', 'vasic-util-secondary', 'serverfactory-tertiary'];
const TIER_RANK = Object.fromEntries(TIERS.map((t, i) => [t, i]));
const REQUIRED_STRINGS = ['name', 'slug', 'tier', 'status', 'license', 'summary', 'tagline'];

const errors = [];
const fail = (msg) => errors.push(msg);

// A harness fault: the dataset could not be turned into something this gate
// can make ANY assertion about. Never exit 1 here — see the header.
const undetermined = (msg) => {
  console.error(`[validate] UNDETERMINED — ${msg}`);
  console.error('[validate] zero assertions were evaluated; this is a harness fault, NOT a detected violation (exit 2)');
  process.exit(2);
};

let raw;
try {
  raw = fs.readFileSync(FILE, 'utf8');
} catch (e) {
  undetermined(`cannot read ${FILE}: ${e.message}`);
}

let doc;
try {
  doc = JSON.parse(raw);
} catch (e) {
  undetermined(`cannot parse ${FILE}: ${e.message}`);
}

if (doc === null || typeof doc !== 'object' || Array.isArray(doc)) {
  undetermined(`${FILE} is not a JSON object (got ${doc === null ? 'null' : Array.isArray(doc) ? 'array' : typeof doc})`);
}

const entries = Array.isArray(doc.entries) ? doc.entries : null;
if (!entries) {
  undetermined(`${FILE} has no entries[] array — nothing to validate`);
}
if (entries.length === 0) {
  undetermined(`${FILE} has an EMPTY entries[] array — every assertion would vacuously hold`);
}

// --- 1. exclusions ---
for (const e of entries) {
  const slug = String(e.slug || '').toLowerCase();
  const nameSlug = String(e.name || '').toLowerCase().replace(/\s+/g, '-');
  if (EXCLUSIONS.includes(slug) || EXCLUSIONS.includes(nameSlug)) {
    fail(`excluded project present: ${e.slug || e.name}`);
  }
}

// --- 2 & 3. per-entry required fields + private/repo safety ---
for (const e of entries) {
  const id = e.slug || e.name || '(unknown)';

  for (const k of REQUIRED_STRINGS) {
    if (typeof e[k] !== 'string' || e[k].trim() === '') {
      fail(`${id}: missing/empty required field "${k}"`);
    }
  }
  if (!Number.isInteger(e.order)) fail(`${id}: "order" must be an integer`);
  if (typeof e.private !== 'boolean') fail(`${id}: "private" must be a boolean`);
  if (!TIERS.includes(e.tier)) fail(`${id}: unknown tier "${e.tier}"`);
  if (!Array.isArray(e.tech) || e.tech.length === 0) fail(`${id}: "tech" must be a non-empty array`);
  if (!Array.isArray(e.repos)) fail(`${id}: "repos" must be an array`);

  // A private entry must NOT leak any repo URL.
  if (e.private === true && Array.isArray(e.repos) && e.repos.length > 0) {
    fail(`${id}: private:true entry exposes ${e.repos.length} repo URL(s)`);
  }
  // Any listed repo must be an http(s) URL.
  for (const r of e.repos || []) {
    if (!/^https?:\/\/\S+$/.test(String(r))) fail(`${id}: invalid repo URL "${r}"`);
  }
}

// --- 4. ordering monotonic within tiers, tiers in canonical order ---
let lastTierRank = -1;
const perTierLastOrder = {};
for (const e of entries) {
  const rank = TIER_RANK[e.tier];
  if (rank === undefined) continue; // already reported above
  if (rank < lastTierRank) {
    fail(`tier ordering broken: "${e.tier}" appears after a higher-ranked tier`);
  }
  lastTierRank = Math.max(lastTierRank, rank);

  if (perTierLastOrder[e.tier] !== undefined && e.order <= perTierLastOrder[e.tier]) {
    fail(`order not strictly increasing within ${e.tier}: ${e.order} after ${perTierLastOrder[e.tier]} (${e.slug})`);
  }
  perTierLastOrder[e.tier] = e.order;
}

// --- report ---
const byTier = {};
for (const e of entries) byTier[e.tier] = (byTier[e.tier] || 0) + 1;

console.log(`[validate] file=${path.relative(ROOT, FILE)}`);
console.log(`[validate] entries=${entries.length}`);
for (const t of TIERS) console.log(`  - ${t.padEnd(24)} : ${byTier[t] || 0}`);
console.log(`[validate] exclusions enforced: ${EXCLUSIONS.join(', ')}`);

if (errors.length) {
  console.error(`\n[validate] FAIL — ${errors.length} problem(s):`);
  for (const m of errors) console.error(`  ✗ ${m}`);
  console.error('[validate] assertions were EVALUATED and violated (exit 1)');
  process.exit(1);
}
console.log('\n[validate] PASS — all assertions hold (exit 0)');
process.exit(0);
