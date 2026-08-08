// v1.8.0 before/after diff.
//
// For each before/after pair (same filename), reports:
//   - before dims (WxH), after dims (WxH)
//   - dims-match (yes/no)  <-- the geometry assertion
//   - % pixels changed
// and writes a diff PNG into diff/.
//
// If dims differ, pixelmatch can't compare full frames, so we diff the common
// top-left region (min width x min height) and clearly flag the mismatch. A
// dims mismatch OR a large %-change is a real layout regression.
//
// Usage: node _tests/evidence/v180-visual/diff.mjs

import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';
import { readFileSync, writeFileSync, readdirSync, mkdirSync } from 'node:fs';
import { dirname, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const BEFORE = resolve(__dirname, 'before');
const AFTER = resolve(__dirname, 'after');
const DIFF = resolve(__dirname, 'diff');
mkdirSync(DIFF, { recursive: true });

const THRESHOLD = 0.1; // per-pixel color-distance sensitivity (pixelmatch default)

const files = readdirSync(BEFORE).filter((f) => f.endsWith('.png')).sort();

const rows = [];
for (const f of files) {
  const bPath = resolve(BEFORE, f);
  const aPath = resolve(AFTER, f);
  let after;
  try {
    after = PNG.sync.read(readFileSync(aPath));
  } catch (e) {
    rows.push({ name: f, before: '?', after: 'MISSING', dimsMatch: 'no', pct: 'n/a' });
    continue;
  }
  const before = PNG.sync.read(readFileSync(bPath));

  const dimsMatch = before.width === after.width && before.height === after.height;
  const w = Math.min(before.width, after.width);
  const h = Math.min(before.height, after.height);

  // Build equal-sized buffers over the common region so pixelmatch can run
  // even when full dims differ.
  const bReg = cropToRGBA(before, w, h);
  const aReg = cropToRGBA(after, w, h);
  const diff = new PNG({ width: w, height: h });

  const changed = pixelmatch(bReg, aReg, diff.data, w, h, {
    threshold: THRESHOLD,
    includeAA: false,
    alpha: 0.4,
    diffColor: [255, 0, 0],
  });
  const totalPx = w * h;
  const pct = (changed / totalPx) * 100;

  writeFileSync(resolve(DIFF, f), PNG.sync.write(diff));

  rows.push({
    name: basename(f, '.png'),
    before: `${before.width}x${before.height}`,
    after: `${after.width}x${after.height}`,
    dimsMatch: dimsMatch ? 'yes' : 'NO',
    pct: pct.toFixed(3),
    changed,
    totalPx,
  });
}

// crop a PNG's pixel data to a (w x h) top-left RGBA buffer
function cropToRGBA(png, w, h) {
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = (png.width * y + x) * 4;
      const di = (w * y + x) * 4;
      out[di] = png.data[si];
      out[di + 1] = png.data[si + 1];
      out[di + 2] = png.data[si + 2];
      out[di + 3] = png.data[si + 3];
    }
  }
  return out;
}

// --- report ---
const pad = (s, n) => String(s).padEnd(n);
console.log('\nv1.8.0 before/after diff\n');
console.log(
  pad('page/variant', 34) +
    pad('before', 12) +
    pad('after', 12) +
    pad('dims-match', 12) +
    '%changed'
);
console.log('-'.repeat(78));
let anyDimMismatch = false;
let maxPct = 0;
for (const r of rows) {
  if (r.dimsMatch === 'NO') anyDimMismatch = true;
  const p = parseFloat(r.pct);
  if (!Number.isNaN(p) && p > maxPct) maxPct = p;
  console.log(
    pad(r.name, 34) + pad(r.before, 12) + pad(r.after, 12) + pad(r.dimsMatch, 12) + r.pct + '%'
  );
}
console.log('-'.repeat(78));
console.log(`pairs: ${rows.length}`);
console.log(`dimension mismatches: ${anyDimMismatch ? 'YES (see NO rows)' : 'none'}`);
console.log(`max %-changed on any pair: ${maxPct.toFixed(3)}%`);
console.log(`diff images: ${DIFF}`);
