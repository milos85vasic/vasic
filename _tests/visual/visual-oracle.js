#!/usr/bin/env node
/*
 * §11.4.170 host-rendered visual-proof harness.
 *
 * Renders an HTML file (or URL) in Chromium at a fixed viewport for BOTH
 * themes (light + dark via prefers-color-scheme AND [data-theme="dark"]),
 * captures a PNG per screen x theme, and runs a layout/legibility oracle:
 *   - element overlap (two meaningful elements covering the same pixels)
 *   - off-screen / clipped controls (control rect escapes the viewport)
 *   - unbounded "giant" widgets (control larger than a sane viewport fraction)
 *   - OCR / text-readability (via tesseract, if present) -> recorded evidence
 *
 * Verdict = FAIL if any layout finding of severity "error" is present.
 * OCR legibility is recorded and surfaced as a soft "warning" (never a false
 * FAIL, never a faked PASS).
 *
 * Usage:
 *   node visual-oracle.js --input <file|url> --out <dir> --name <name>
 *                         [--viewport 1280x800] [--themes light,dark]
 * Exit code: 0 = PASS, 1 = FAIL, 2 = harness error.
 */
'use strict';

const { chromium } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

function parseArgs(argv) {
  const a = { viewport: '1280x800', themes: 'light,dark', name: 'screen' };
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (k === '--input') a.input = argv[++i];
    else if (k === '--out') a.out = argv[++i];
    else if (k === '--name') a.name = argv[++i];
    else if (k === '--viewport') a.viewport = argv[++i];
    else if (k === '--themes') a.themes = argv[++i];
  }
  return a;
}

function toUrl(input) {
  if (/^https?:\/\//i.test(input)) return input;
  const abs = path.resolve(input);
  if (!fs.existsSync(abs)) throw new Error('input not found: ' + abs);
  return 'file://' + abs;
}

// Deterministic provenance stamp for the verdict JSON.
//
// A caller-pinned SOURCE_DATE_EPOCH — the reproducible-builds convention this
// repo already follows in _tools/gen/build.sh and _tools/pdf/build-pdfs.sh —
// yields a real, reproducible `generatedAt`. With it unset we OMIT the field
// rather than embed a wall clock: these verdicts are COMMITTED evidence
// (_tests/GATES.md cites them for the visual §11.4.170 proof), and an embedded
// clock made every regeneration a spurious diff. Mirrors the sibling convention
// in design-toolkit/qa/run-checks.mjs (`generatedAt_omitted_for_determinism`).
function provenance() {
  const sde = process.env.SOURCE_DATE_EPOCH;
  return (sde && /^[0-9]+$/.test(sde))
    ? { generatedAt: new Date(Number(sde) * 1000).toISOString() }
    : { generatedAt_omitted_for_determinism: true };
}

function hasTool(name) {
  try { execFileSync('which', [name], { stdio: 'pipe' }); return true; }
  catch { return false; }
}

// The oracle runs inside the page; it must be self-contained (no closures).
function oracleInPage(cfg) {
  const vw = window.innerWidth, vh = window.innerHeight;
  const TOL = 2;                 // px slack for viewport edges
  const GIANT_W = cfg.giantW;    // fraction of viewport width
  const GIANT_H = cfg.giantH;    // fraction of viewport height
  const OVERLAP_FRAC = cfg.overlapFrac;

  const interactiveSel = 'button, a[href], [role="button"], input, select, textarea';
  const meaningfulSel = interactiveSel + ', label, h1, h2, h3, h4, h5, h6, p';

  function visible(el) {
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || parseFloat(cs.opacity) === 0) return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  }
  function label(el) {
    const t = (el.getAttribute('data-testid') || el.id || (el.textContent || '').trim().slice(0, 30) || el.tagName).toString();
    return el.tagName.toLowerCase() + (t ? '[' + t + ']' : '');
  }

  const meaningful = [...document.querySelectorAll(meaningfulSel)].filter(visible);
  const controls = [...document.querySelectorAll(interactiveSel)].filter(visible);

  const findings = [];

  // --- giant / unbounded controls ---
  for (const el of controls) {
    const r = el.getBoundingClientRect();
    const overW = r.width > vw * GIANT_W;
    const overH = r.height > vh * GIANT_H;
    if (overW || overH) {
      findings.push({
        type: 'giant-widget', severity: 'error', element: label(el),
        detail: `control ${Math.round(r.width)}x${Math.round(r.height)}px exceeds sane fraction of ${vw}x${vh} viewport` +
                (overW ? ` (width>${Math.round(GIANT_W * 100)}%vw)` : '') +
                (overH ? ` (height>${Math.round(GIANT_H * 100)}%vh)` : ''),
        rect: { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) },
      });
    }
  }

  // --- off-screen / clipped controls ---
  for (const el of controls) {
    const r = el.getBoundingClientRect();
    const off = [];
    if (r.left < -TOL) off.push('left');
    if (r.top < -TOL) off.push('top');
    if (r.right > vw + TOL) off.push('right');
    if (r.bottom > vh + TOL) off.push('bottom');
    if (off.length) {
      findings.push({
        type: 'offscreen-clipped', severity: 'error', element: label(el),
        detail: `control escapes viewport on: ${off.join(', ')} (rect right=${Math.round(r.right)} bottom=${Math.round(r.bottom)} vs ${vw}x${vh})`,
        rect: { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) },
      });
    }
    // ancestor overflow clipping
    let p = el.parentElement;
    while (p && p !== document.body) {
      const cs = getComputedStyle(p);
      if (/(hidden|clip|auto|scroll)/.test(cs.overflow + cs.overflowX + cs.overflowY)) {
        const pr = p.getBoundingClientRect();
        if (r.right > pr.right + TOL || r.bottom > pr.bottom + TOL || r.left < pr.left - TOL || r.top < pr.top - TOL) {
          findings.push({
            type: 'ancestor-clipped', severity: 'error', element: label(el),
            detail: `control overflows clipping ancestor ${label(p)}`,
            rect: { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) },
          });
          break;
        }
      }
      p = p.parentElement;
    }
  }

  // --- overlap between meaningful, non-nested elements ---
  const rects = meaningful.map(el => ({ el, r: el.getBoundingClientRect() }));
  for (let i = 0; i < rects.length; i++) {
    for (let j = i + 1; j < rects.length; j++) {
      const A = rects[i], B = rects[j];
      if (A.el.contains(B.el) || B.el.contains(A.el)) continue;
      const ix = Math.max(0, Math.min(A.r.right, B.r.right) - Math.max(A.r.left, B.r.left));
      const iy = Math.max(0, Math.min(A.r.bottom, B.r.bottom) - Math.max(A.r.top, B.r.top));
      const inter = ix * iy;
      if (inter <= 0) continue;
      const areaA = A.r.width * A.r.height, areaB = B.r.width * B.r.height;
      const frac = inter / Math.min(areaA, areaB);
      if (frac >= OVERLAP_FRAC) {
        findings.push({
          type: 'overlap', severity: 'error',
          element: label(A.el) + ' <> ' + label(B.el),
          detail: `elements overlap ${Math.round(frac * 100)}% of the smaller box`,
          rect: { x: Math.round(Math.max(A.r.left, B.r.left)), y: Math.round(Math.max(A.r.top, B.r.top)), w: Math.round(ix), h: Math.round(iy) },
        });
      }
    }
  }

  const textLen = meaningful.reduce((n, el) => n + ((el.textContent || '').trim().length), 0);
  return {
    viewport: { w: vw, h: vh },
    scrollW: document.documentElement.scrollWidth,
    counts: { meaningful: meaningful.length, controls: controls.length, textChars: textLen },
    findings,
  };
}

async function run() {
  const args = parseArgs(process.argv);
  if (!args.input || !args.out) {
    console.error('usage: node visual-oracle.js --input <file|url> --out <dir> --name <name> [--viewport WxH] [--themes light,dark]');
    process.exit(2);
  }
  fs.mkdirSync(args.out, { recursive: true });
  const [vwv, vhv] = args.viewport.split('x').map(Number);
  const themes = args.themes.split(',').map(s => s.trim());
  const url = toUrl(args.input);
  const tesseract = hasTool('tesseract');

  const cfg = { giantW: 0.85, giantH: 0.6, overlapFrac: 0.4 };

  const browser = await chromium.launch();
  const report = {
    schema: 'visual-oracle/1', ...provenance(),
    input: url, name: args.name, viewport: { w: vwv, h: vhv }, themes,
    tesseractPresent: tesseract, thresholds: cfg,
    perTheme: {}, verdict: 'PASS',
  };

  try {
    for (const theme of themes) {
      const ctx = await browser.newContext({
        viewport: { width: vwv, height: vhv },
        colorScheme: theme === 'dark' ? 'dark' : 'light',
        deviceScaleFactor: 1,
      });
      const page = await ctx.newPage();
      await page.goto(url, { waitUntil: 'networkidle' });
      if (theme === 'dark') {
        await page.evaluate(() => document.documentElement.setAttribute('data-theme', 'dark'));
      } else {
        await page.evaluate(() => document.documentElement.removeAttribute('data-theme'));
      }
      await page.waitForTimeout(150);

      const pngPath = path.join(args.out, `${args.name}.${theme}.png`);
      await page.screenshot({ path: pngPath, fullPage: true });

      const oracle = await page.evaluate(oracleInPage, cfg);

      // OCR (evidence + soft legibility signal)
      let ocr = { ran: false };
      if (tesseract) {
        try {
          const base = path.join(args.out, `${args.name}.${theme}.ocr`);
          execFileSync('tesseract', [pngPath, base, '--psm', '6'], { stdio: 'pipe' });
          const txt = fs.readFileSync(base + '.txt', 'utf8');
          const words = txt.split(/\s+/).filter(w => /[A-Za-z0-9]/.test(w));
          ocr = { ran: true, txtFile: base + '.txt', wordCount: words.length, sample: words.slice(0, 12).join(' ') };
          if (oracle.counts.textChars > 20 && words.length === 0) {
            oracle.findings.push({ type: 'ocr-illegible', severity: 'warning', element: '(page)', detail: 'page has visible text but OCR recovered zero words' });
          }
        } catch (e) {
          ocr = { ran: false, error: String(e.message || e).split('\n')[0] };
        }
      }

      const errors = oracle.findings.filter(f => f.severity === 'error');
      const warnings = oracle.findings.filter(f => f.severity === 'warning');
      const themeVerdict = errors.length === 0 ? 'PASS' : 'FAIL';
      if (themeVerdict === 'FAIL') report.verdict = 'FAIL';

      report.perTheme[theme] = {
        screenshot: pngPath, ocr, oracle,
        errorCount: errors.length, warningCount: warnings.length, verdict: themeVerdict,
      };
      await ctx.close();
    }
  } finally {
    await browser.close();
  }

  const verdictPath = path.join(args.out, `${args.name}.verdict.json`);
  fs.writeFileSync(verdictPath, JSON.stringify(report, null, 2));

  console.log(`\n[visual-oracle] input=${url}`);
  console.log(`[visual-oracle] tesseract=${tesseract ? 'present' : 'MISSING'}  viewport=${vwv}x${vhv}  themes=${themes.join(',')}`);
  for (const theme of themes) {
    const t = report.perTheme[theme];
    console.log(`  - ${theme.padEnd(5)} : ${t.verdict}  (errors=${t.errorCount} warnings=${t.warningCount}) png=${path.basename(t.screenshot)} ocrWords=${t.ocr.ran ? t.ocr.wordCount : 'n/a'}`);
    for (const f of t.oracle.findings) {
      console.log(`        [${f.severity}] ${f.type}: ${f.element} — ${f.detail}`);
    }
  }
  console.log(`[visual-oracle] verdict=${report.verdict}  report=${verdictPath}\n`);
  process.exit(report.verdict === 'PASS' ? 0 : 1);
}

run().catch(e => { console.error('[visual-oracle] HARNESS ERROR:', e); process.exit(2); });
