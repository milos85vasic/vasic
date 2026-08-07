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
 * Exit 0 = PASS, exit 1 = FAIL.
 */
'use strict';

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const FILE = path.join(ROOT, '_content', 'portfolio', 'portfolio.json');

const EXCLUSIONS = ['grabtube', 'shareconnect', 'panoptic', 'android-toolkit', 'asinka', 'yole'];
const TIERS = ['helix-primary', 'vasic-util-secondary', 'serverfactory-tertiary'];
const TIER_RANK = Object.fromEntries(TIERS.map((t, i) => [t, i]));
const REQUIRED_STRINGS = ['name', 'slug', 'tier', 'status', 'license', 'summary', 'tagline'];

const errors = [];
const fail = (msg) => errors.push(msg);

let doc;
try {
  doc = JSON.parse(fs.readFileSync(FILE, 'utf8'));
} catch (e) {
  console.error(`[validate] cannot read/parse ${FILE}: ${e.message}`);
  process.exit(1);
}

const entries = Array.isArray(doc.entries) ? doc.entries : null;
if (!entries) {
  console.error('[validate] portfolio.json has no entries[] array');
  process.exit(1);
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
  process.exit(1);
}
console.log('\n[validate] PASS — all assertions hold (exit 0)');
process.exit(0);
