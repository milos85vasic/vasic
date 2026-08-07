#!/usr/bin/env node
/*
 * Normalize _content/products/*.md (frontmatter + body) into the unified
 * _content/portfolio/portfolio.json — one entry per product.
 *
 * The unified set is IDENTICAL for both sites (vasic.digital + milosvasic.ru).
 * User exclusions are honoured: excluded projects never enter the set.
 * PUBLIC repos only are carried; a private:true entry must carry NO repo URLs.
 *
 * Usage: node generate.mjs   (writes portfolio.json, prints a per-tier count)
 */
'use strict';

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const PRODUCTS_DIR = path.join(ROOT, '_content', 'products');
const OUT = path.join(ROOT, '_content', 'portfolio', 'portfolio.json');

// User exclusions — never shown on either site (match by slug OR name, case-insensitive).
const EXCLUSIONS = ['grabtube', 'shareconnect', 'panoptic', 'android-toolkit', 'asinka', 'yole'];

// Tier ordering: Helix primary first, utilities second, Server Factory last.
const TIER_RANK = {
  'helix-primary': 0,
  'vasic-util-secondary': 1,
  'serverfactory-tertiary': 2,
};

// --- minimal, sufficient frontmatter parser for our simple YAML subset ---
function parse(md) {
  const m = md.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) throw new Error('no frontmatter');
  const fmRaw = m[1];
  const body = m[2];

  const fm = {};
  const lines = fmRaw.split('\n');
  let listKey = null;
  for (const line of lines) {
    if (/^\s+-\s+/.test(line) && listKey) {
      fm[listKey].push(line.replace(/^\s+-\s+/, '').trim());
      continue;
    }
    const kv = line.match(/^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/);
    if (!kv) continue;
    const key = kv[1];
    const val = kv[2];
    if (val === '') { fm[key] = []; listKey = key; }
    else { fm[key] = val; listKey = null; }
  }
  return { fm, body };
}

function tagline(body) {
  for (const raw of body.split('\n')) {
    const l = raw.trim();
    const b = l.match(/^\*\*(.+)\*\*$/);
    if (b) return b[1].trim();
  }
  return '';
}

function summary(body) {
  const lines = body.split('\n');
  let inSummary = false;
  for (const raw of lines) {
    if (/^##\s+Summary\s*$/.test(raw)) { inSummary = true; continue; }
    if (inSummary) {
      if (/^#/.test(raw)) break;
      if (raw.trim().length) return raw.trim();
    }
  }
  return '';
}

// Reduce verbose frontmatter status strings to a single badge token.
function normStatus(raw) {
  const s = String(raw || '').toLowerCase().trim();
  if (s.startsWith('production')) return 'production';
  if (s.startsWith('beta')) return 'beta';
  if (s.startsWith('in-development')) return 'in-development';
  if (s.startsWith('roadmap')) return 'roadmap';
  if (s.startsWith('shipped')) return 'shipped';
  if (s.startsWith('stable')) return 'stable';
  if (s.startsWith('active')) return 'active';
  if (s.startsWith('p1') || s.includes('scaffold')) return 'scaffold';
  if (s.startsWith('mixed')) return 'mixed';
  return (s.split(/[\s(]/)[0] || 'unknown');
}

const files = fs.readdirSync(PRODUCTS_DIR).filter((f) => f.endsWith('.md'));
const entries = [];

for (const file of files) {
  const md = fs.readFileSync(path.join(PRODUCTS_DIR, file), 'utf8');
  const { fm, body } = parse(md);

  const slug = String(fm.slug || '').trim();
  const name = String(fm.name || '').trim();

  // Honour exclusions.
  if (EXCLUSIONS.includes(slug.toLowerCase()) ||
      EXCLUSIONS.includes(name.toLowerCase().replace(/\s+/g, '-'))) {
    continue;
  }

  const isPrivate = String(fm.private).trim() === 'true';
  const repos = Array.isArray(fm.repos) ? fm.repos.slice() : [];

  entries.push({
    name,
    slug,
    tier: String(fm.tier || '').trim(),
    order: Number(fm.order),
    status: normStatus(fm.status),
    license: String(fm.license || '').trim(),
    private: isPrivate,
    tech: Array.isArray(fm.tech) ? fm.tech.slice() : [],
    // PUBLIC only: a private entry carries no repo URLs.
    repos: isPrivate ? [] : repos,
    summary: summary(body),
    tagline: tagline(body),
    source: path.join('_content', 'products', file),
  });
}

// Sort: tier rank, then order within tier.
entries.sort((a, b) => {
  const ta = TIER_RANK[a.tier] ?? 99;
  const tb = TIER_RANK[b.tier] ?? 99;
  if (ta !== tb) return ta - tb;
  return a.order - b.order;
});

const doc = {
  schema: 'portfolio/1',
  generatedAt: new Date().toISOString().slice(0, 10),
  unified: true,
  shared_by: ['vasic.digital', 'milosvasic.ru'],
  tiers: ['helix-primary', 'vasic-util-secondary', 'serverfactory-tertiary'],
  excluded: EXCLUSIONS,
  count: entries.length,
  entries,
};

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(doc, null, 2) + '\n');

const byTier = {};
for (const e of entries) byTier[e.tier] = (byTier[e.tier] || 0) + 1;
console.log(`[generate] wrote ${OUT}`);
console.log(`[generate] total=${entries.length}`);
for (const t of doc.tiers) console.log(`  - ${t.padEnd(24)} : ${byTier[t] || 0}`);
