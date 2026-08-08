#!/usr/bin/env node
// Surgical token-VALUE replacement — apply the crimson-anchored hybrid candidate
// to the LIVE milosvasic brand CSS while PRESERVING the TERMINAL BRUTALIST design
// (Anton display) and matching the approved STAGE-mv preview (== current live look).
//
// WHAT GETS THE CANDIDATE VALUE (in the three BASE blocks):
//   accent ramp (--od-accent-50..900), neutrals (bg/surface/surface-2/text/
//   text-muted/border — NEUTRALIZED to warm-neutral, de-greened), accent
//   semantics (accent/hover/active/on-accent/focus), status (success/warning/
//   danger/shadow-color), radius (--od-radius-*), shadow recipes (--od-shadow-*).
//
// WHAT IS PRESERVED AT LIVE VALUES (NOT replaced) — these are the brutalist
// design system's rhythm/identity and are NOT re-declared by the trailing
// brutalist :root override, so replacing them would break the layout / identity:
//   fonts (--od-font-*), type-scale (--od-fs-*), spacing (--od-space-*),
//   line-height (--od-lh-*), tracking (--od-tracking-*), motion (--od-dur-*,
//   --od-ease-*), z-index (--od-z-*), --od-container-max.
//   (Proof: replacing --od-fs-* / --od-space-* blows up the hero lede & spacing,
//    35% pixel diff vs STAGE — see evidence/v180-apply.)
//
// BRUTALIST OVERRIDE (2nd :root): only --od-accent-700 is repointed to the
// candidate crimson #93474f so the *computed* accent ramp is crimson-anchored
// (verification gate). The primary --od-accent stays #a31e39 (STAGE-exact), and
// Anton / sharp radius / hard print-shadows / warm-cream neutrals are untouched.
//
// Usage: node apply-tokens.mjs <candidate.css> <live.css> <out.css>
import { readFileSync, writeFileSync } from 'node:fs';

const [candPath, livePath, outPath] = process.argv.slice(2);
if (!candPath || !livePath || !outPath) {
  console.error('usage: apply-tokens.mjs <candidate.css> <live.css> <out.css>');
  process.exit(2);
}
const cand = readFileSync(candPath, 'utf8');
const live = readFileSync(livePath, 'utf8');

// Tokens PRESERVED at live values (skip replacement in base blocks).
const PRESERVE = (name) =>
  name.startsWith('--od-font-') ||
  name.startsWith('--od-fs-') ||
  name.startsWith('--od-space-') ||
  name.startsWith('--od-lh-') ||
  name.startsWith('--od-tracking-') ||
  name.startsWith('--od-dur-') ||
  name.startsWith('--od-ease-') ||
  name.startsWith('--od-z-') ||
  name === '--od-container-max';

// Neutralized (de-greened, warm-neutral) surface/neutral values — replace the
// candidate's faintly-green MCU-Expressive neutrals. Accent ramp untouched.
const NEUTRALS_LIGHT = {
  '--od-bg': '#faf9f7', '--od-surface': '#f4f2ef', '--od-surface-2': '#eeebe7',
  '--od-text': '#1c1a17', '--od-text-muted': '#4a453f', '--od-border': '#c8c3bc',
};
const NEUTRALS_DARK = {
  '--od-bg': '#12100e', '--od-surface': '#1b1917', '--od-surface-2': '#211e1b',
  '--od-text': '#e7e3dd', '--od-text-muted': '#c3bcb2', '--od-border': '#453f38',
};

function blockBody(src, headerRe) {
  const m = headerRe.exec(src);
  if (!m) throw new Error('block not found: ' + headerRe);
  const open = src.indexOf('{', m.index);
  let depth = 0, i = open;
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}') { depth--; if (depth === 0) break; }
  }
  return { start: open + 1, end: i, body: src.slice(open + 1, i) };
}
function tokenMap(body) {
  const map = new Map();
  const re = /(--od-[a-z0-9-]+)\s*:\s*([^;]+);/gi; let m;
  while ((m = re.exec(body))) map.set(m[1], m[2].trim());
  return map;
}

const candRoot = tokenMap(blockBody(cand, /:root\s*\{/).body);
const candDark = tokenMap(blockBody(cand, /:root\[data-theme="dark"\]\s*\{/).body);
const candMediaOuter = blockBody(cand, /@media\s*\(prefers-color-scheme:\s*dark\)\s*\{/).body;
const candMedia = tokenMap(blockBody(candMediaOuter, /:root:not\(\[data-theme="light"\]\)\s*\{/).body);

// Apply neutral overrides onto candidate maps (so before/after is auditable).
for (const [k, v] of Object.entries(NEUTRALS_LIGHT)) if (candRoot.has(k)) candRoot.set(k, v);
for (const [k, v] of Object.entries(NEUTRALS_DARK)) { if (candDark.has(k)) candDark.set(k, v); if (candMedia.has(k)) candMedia.set(k, v); }

function rewriteBlock(src, headerRe, map, changed, { preserve = true } = {}) {
  const { start, end } = blockBody(src, headerRe);
  const before = src.slice(start, end);
  const after = before.replace(/(--od-[a-z0-9-]+)(\s*:\s*)([^;]+)(;)/gi, (full, name, sep, val, sc) => {
    if (preserve && PRESERVE(name)) return full;      // keep live rhythm/identity
    if (!map.has(name)) return full;
    const nv = map.get(name);
    if (val.trim() === nv) return full;
    changed.push({ name, from: val.trim(), to: nv });
    return name + sep + nv + sc;
  });
  return src.slice(0, start) + after + src.slice(end);
}

const changed = { root: [], dark: [], media: [], brutalist: [] };
let out = live;
out = rewriteBlock(out, /@media\s*\(prefers-color-scheme:\s*dark\)\s*\{[\s\S]*?:root:not\(\[data-theme="light"\]\)\s*\{/, candMedia, changed.media);
out = rewriteBlock(out, /:root\s*\{/, candRoot, changed.root);
out = rewriteBlock(out, /:root\[data-theme="dark"\]\s*\{/, candDark, changed.dark);

// Brutalist override: repoint ONLY --od-accent-700 to the candidate crimson so
// the computed accent ramp is crimson-anchored. Everything else in the brutalist
// blocks (Anton, radius, hard shadows, #a31e39 primary accent, warm neutrals) is
// left byte-for-byte. We patch the SECOND occurrence (the brutalist :root@683).
{
  const target = '--od-accent-700';
  const candVal = candRoot.get(target); // #93474f (accent ramp — not neutralized)
  // Find the brutalist light :root (the one that also sets --od-font-display:Anton)
  const bru = blockBody(out, /:root\{\n\s*--od-bg:#f4f1ea;/);
  const body = out.slice(bru.start, bru.end);
  const patched = body.replace(/(--od-accent-700\s*:\s*)([^;]+)(;)/i, (full, pfx, val, sc) => {
    if (val.trim() === candVal) return full;
    changed.brutalist.push({ name: target, from: val.trim(), to: candVal, block: 'brutalist :root' });
    return pfx + candVal + sc;
  });
  out = out.slice(0, bru.start) + patched + out.slice(bru.end);
}

writeFileSync(outPath, out);

const summarize = (label, arr) => {
  console.log(`\n[${label}] ${arr.length} changed`);
  for (const c of arr) console.log(`  ${c.name}: ${c.from}  ->  ${c.to}`);
};
summarize('base :root', changed.root);
summarize('base dark', changed.dark);
summarize('base @media dark', changed.media);
summarize('brutalist :root (accent anchor only)', changed.brutalist);
console.log(`\nwrote ${outPath} (${out.length} bytes; live was ${live.length} bytes)`);
