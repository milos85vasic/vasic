#!/usr/bin/env node
/*
 * §11.4.168 exported-document validator.
 *
 * Given a PDF, runs three families of checks and produces a verdict + JSON:
 *   (1) CONTENT   — pdftotext yields non-empty, faithful text
 *                   (min word count; optional required phrases via --expect).
 *   (2) TEXTUAL   — no raw markup / no raw Mermaid source leaking as body text
 *                   (gantt, graph TD, flowchart, dateFormat, section, :done,
 *                    :active,, :crit,, -->, code fences, raw HTML tags).
 *   (3) FULL-VISUAL — pdfimages confirms >= N embedded images present, AND
 *                     pdftoppm -> tesseract OCR confirms legible rendered text.
 *
 * Verdict is THREE-VALUED, following this fleet's convention
 * (0 clean / 1 real finding / 2 could not determine — 2 is NEVER a pass):
 *
 *   PASS         (0) — every check ran and every one passed.
 *   FAIL         (1) — a check ran and FAILED. A real finding.
 *   UNDETERMINED (2) — no check FAILED, but at least one could not RUN
 *                      (missing toolchain). Coverage is incomplete.
 *
 * Precedence: FAIL (1) outranks UNDETERMINED (2) outranks PASS (0), matching
 * scripts/verify-provider-ci.sh and scripts/verify-content-boundary.sh — so a
 * skipped check can never MASK a real finding, and a real finding is never
 * downgraded to "could not determine".
 *
 * WHY UNDETERMINED EXISTS. A SKIP used to be reported honestly per-check and
 * then silently absorbed: `verdict` was initialised to 'PASS' and only ever
 * moved by a FAIL, so a run in which an ENTIRE check family never executed
 * still ended `GATE: CM-EXPORTED-DOC-VISUALLY-VALIDATED (§11.4.168) —
 * SATISFIED`, exit 0. Measured on a host without tesseract: both fixtures
 * printed `[SKIP] FULL-VISUAL/visual.ocr` and the gate reported SATISFIED,
 * while the COMMITTED evidence for the same fixtures records
 * `"tesseract": true` and `"OCR ... recovered 109 legible words"`. Coverage
 * that is counted but not performed is exactly the bluff §11.4.6 forbids.
 *
 * Usage:
 *   node validate-pdf.js --pdf <file> --out <dir> --name <name>
 *        [--min-words 40] [--min-ocr-words 15] [--min-images 1]
 *        [--expect "phrase" ...]
 * Exit: 0 = PASS, 1 = FAIL, 2 = UNDETERMINED / harness error.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

function parseArgs(argv) {
  const a = { minWords: 40, minOcrWords: 15, minImages: 1, expect: [], name: 'doc' };
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (k === '--pdf') a.pdf = argv[++i];
    else if (k === '--out') a.out = argv[++i];
    else if (k === '--name') a.name = argv[++i];
    else if (k === '--min-words') a.minWords = Number(argv[++i]);
    else if (k === '--min-ocr-words') a.minOcrWords = Number(argv[++i]);
    else if (k === '--min-images') a.minImages = Number(argv[++i]);
    else if (k === '--expect') a.expect.push(argv[++i]);
  }
  return a;
}

function hasTool(n) { try { execFileSync('which', [n], { stdio: 'pipe' }); return true; } catch { return false; } }

/*
 * Collect the page images pdftoppm just wrote, in TRUE PAGE ORDER.
 *
 * `dir` must be a directory this run created and emptied, so the listing is
 * exactly this invocation's output and cannot pick up committed evidence or a
 * previous, longer document's leftovers.
 *
 * pdftoppm names pages `<base>-<n>.png`, zero-padding <n> to the width of the
 * highest page number — so a 12-page document yields page-01 .. page-12 while a
 * 9-page one yields page-1 .. page-9. A plain `.sort()` is LEXICOGRAPHIC and
 * orders the unpadded case 1, 10, 11, 12, 2, 3 ... Sorting on the parsed
 * integer is correct for both paddings.
 *
 * Exported for direct testing; see the mutation proof in the session notes.
 */
function collectPages(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .map(f => ({ f, m: /^page-(\d+)\.png$/.exec(f) }))
    .filter(x => x.m !== null)
    .sort((a, b) => Number(a.m[1]) - Number(b.m[1]))
    .map(x => x.f);
}
module.exports = { collectPages };
function sh(cmd, args) { return execFileSync(cmd, args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }); }

// Deterministic provenance stamp for the verdict JSON.
//
// A caller-pinned SOURCE_DATE_EPOCH — the reproducible-builds convention this
// repo already follows in _tools/gen/build.sh and _tools/pdf/build-pdfs.sh —
// yields a real, reproducible `generatedAt`. With it unset we OMIT the field
// rather than embed a wall clock: these verdicts are COMMITTED evidence
// (_tests/GATES.md cites them for the export §11.4.168 proof), and an embedded
// clock made every regeneration a spurious diff. Mirrors the sibling convention
// in design-toolkit/qa/run-checks.mjs (`generatedAt_omitted_for_determinism`).
// ── CHECKOUT-INDEPENDENT PATHS IN COMMITTED EVIDENCE ────────────────────────
// These verdict files are TRACKED. Recording an absolute path makes them a
// function of WHERE the repository happens to sit, so a run from a different
// checkout rewrites tracked files and the diff is pure noise.
//
// It had already happened: the committed verdicts carried
// `/run/media/.../DATA4TB/Projects/vasic/...`, a checkout that is not this one
// — while the SAME FILE carried `"generatedAt_omitted_for_determinism": true`.
// The timestamp was removed for determinism and the path was not, which is what
// says this was an oversight rather than a decision. It sits beside
// `provenance()` because the two exist for one reason.
//
// Applied at the ONE PLACE the report is serialised, not at each assignment, so
// a field added later is covered without anyone having to remember.
//
// A path OUTSIDE the repository is left absolute on purpose: rewriting it
// relative would emit a `../../..` string, which is MORE checkout-dependent,
// not less.
const REPO_ROOT = path.resolve(__dirname, '..', '..');
function repoRelativePaths(value) {
  if (Array.isArray(value)) return value.map(repoRelativePaths);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = repoRelativePaths(v);
    return out;
  }
  if (typeof value === 'string' && path.isAbsolute(value)) {
    const rel = path.relative(REPO_ROOT, value);
    if (rel && !rel.startsWith('..')) return rel;
  }
  return value;
}

function provenance() {
  const sde = process.env.SOURCE_DATE_EPOCH;
  return (sde && /^[0-9]+$/.test(sde))
    ? { generatedAt: new Date(Number(sde) * 1000).toISOString() }
    : { generatedAt_omitted_for_determinism: true };
}

// Raw markup / raw Mermaid source markers that must never appear as body text.
const LEAK_PATTERNS = [
  { name: 'mermaid:gantt', re: /\bgantt\b/i },
  { name: 'mermaid:flowchart', re: /\bflowchart\b/i },
  { name: 'mermaid:graph-dir', re: /\bgraph\s+(TD|LR|BT|RL|TB)\b/i },
  { name: 'mermaid:sequenceDiagram', re: /\bsequenceDiagram\b/i },
  { name: 'mermaid:classDiagram', re: /\bclassDiagram\b/i },
  { name: 'mermaid:pie/journey', re: /\b(pie\s+title|journey)\b/i },
  { name: 'mermaid:dateFormat', re: /\bdateFormat\b/i },
  { name: 'mermaid:section', re: /^\s*section\s+\S/im },
  { name: 'mermaid:task-done', re: /:done,/i },
  { name: 'mermaid:task-active', re: /:active,/i },
  { name: 'mermaid:task-crit', re: /:crit,/i },
  { name: 'mermaid:edge-arrow', re: /--&gt;|-->/ },
  { name: 'markup:code-fence', re: /```/ },
  { name: 'markup:html-tag', re: /<\/?(div|span|table|tr|td|th|p|h[1-6]|img|pre)\b[^>]*>/i },
  { name: 'markup:nbsp-entity', re: /&nbsp;|&lt;|&amp;lt;/i },
];

function run() {
  const args = parseArgs(process.argv);
  if (!args.pdf || !args.out) { console.error('usage: node validate-pdf.js --pdf <file> --out <dir> --name <name> [...]'); process.exit(2); }
  const pdf = path.resolve(args.pdf);
  if (!fs.existsSync(pdf)) { console.error('pdf not found: ' + pdf); process.exit(2); }
  fs.mkdirSync(args.out, { recursive: true });

  const tools = { pdftotext: hasTool('pdftotext'), pdfimages: hasTool('pdfimages'), pdftoppm: hasTool('pdftoppm'), tesseract: hasTool('tesseract') };
  const report = {
    schema: 'export-validator/1', ...provenance(),
    pdf, name: args.name, tools, thresholds: { minWords: args.minWords, minOcrWords: args.minOcrWords, minImages: args.minImages, expect: args.expect },
    checks: [], verdict: 'PASS',
  };
  // Verdict precedence: FAIL outranks UNDETERMINED outranks PASS. A SKIP is a
  // check that DID NOT RUN, so it can never leave the verdict at PASS — but it
  // must not overwrite a FAIL either, or a missing tool would launder a real
  // finding into "could not determine".
  const add = (id, family, status, detail) => {
    report.checks.push({ id, family, status, detail });
    if (status === 'FAIL') report.verdict = 'FAIL';
    else if (status === 'SKIP' && report.verdict !== 'FAIL') report.verdict = 'UNDETERMINED';
  };

  // ---- (1) CONTENT + (2) TEXTUAL: require pdftotext ----
  let text = '';
  if (!tools.pdftotext) {
    add('content.nonempty', 'CONTENT', 'SKIP', 'pdftotext missing — cannot extract text (SKIP-with-reason, not a PASS)');
    add('textual.no-leak', 'TEXTUAL', 'SKIP', 'pdftotext missing — cannot inspect body text');
  } else {
    const txtFile = path.join(args.out, `${args.name}.pdftotext.txt`);
    text = sh('pdftotext', ['-layout', pdf, '-']);
    fs.writeFileSync(txtFile, text);
    report.pdftotextFile = txtFile;
    const words = text.split(/\s+/).filter(w => /[A-Za-z0-9]/.test(w));

    add('content.nonempty', 'CONTENT', words.length >= args.minWords ? 'PASS' : 'FAIL',
        `extracted ${words.length} words (min ${args.minWords})`);

    for (const phrase of args.expect) {
      const present = text.includes(phrase);
      add(`content.faithful[${phrase}]`, 'CONTENT', present ? 'PASS' : 'FAIL',
          present ? `required phrase present: "${phrase}"` : `required phrase MISSING (content unfaithful/truncated): "${phrase}"`);
    }

    const hits = [];
    for (const p of LEAK_PATTERNS) {
      const m = text.match(p.re);
      if (m) hits.push(`${p.name}("${String(m[0]).trim().slice(0, 24)}")`);
    }
    add('textual.no-leak', 'TEXTUAL', hits.length === 0 ? 'PASS' : 'FAIL',
        hits.length === 0 ? 'no raw markup / mermaid source found in body text' : `raw markup/mermaid source leaked as body text: ${hits.join(', ')}`);
  }

  // ---- (3a) FULL-VISUAL: embedded images via pdfimages ----
  if (!tools.pdfimages) {
    add('visual.images', 'FULL-VISUAL', 'SKIP', 'pdfimages missing — cannot confirm embedded images');
  } else {
    const list = sh('pdfimages', ['-list', pdf]);
    fs.writeFileSync(path.join(args.out, `${args.name}.pdfimages.txt`), list);
    const rows = list.trim().split('\n').filter(l => /^\s*\d+\s+\d+\s+(image|smask|stencil)/.test(l));
    add('visual.images', 'FULL-VISUAL', rows.length >= args.minImages ? 'PASS' : 'FAIL',
        `pdfimages found ${rows.length} embedded image(s) (min ${args.minImages})`);
  }

  // ---- (3b) FULL-VISUAL: rasterise -> OCR legibility ----
  if (!tools.pdftoppm) {
    add('visual.ocr', 'FULL-VISUAL', 'SKIP', 'pdftoppm missing — cannot rasterise pages for OCR');
  } else if (!tools.tesseract) {
    add('visual.ocr', 'FULL-VISUAL', 'SKIP', 'tesseract missing — cannot OCR rendered pages');
  } else {
    // Rasterise into a DEDICATED, EMPTIED directory.
    //
    // Two defects lived in the previous form and both are fixed here.
    // (1) The input set was "whatever PNGs happen to be on disk": pdftoppm
    //     wrote alongside committed evidence, nothing was ever deleted, and
    //     `readdirSync(args.out)` then OCR'd every match it found — including
    //     git-TRACKED leftovers (golden-good.page-1/2.png, golden-bad.page-1.png)
    //     and any stragglers from an earlier, longer document. A 1-page PDF
    //     could be "proved legible" by a previous run's page 2.
    // (2) `.sort()` is LEXICOGRAPHIC, so a 12-page document ordered
    //     1, 10, 11, 12, 2, 3 ... — silently scrambling the OCR transcript.
    // The set is now exactly what THIS pdftoppm invocation produced, and it is
    // ordered by the page number pdftoppm itself assigned.
    const pageDir = path.join(args.out, `${args.name}.pages`);
    fs.rmSync(pageDir, { recursive: true, force: true });
    fs.mkdirSync(pageDir, { recursive: true });

    const ppmBase = path.join(pageDir, 'page');
    sh('pdftoppm', ['-r', '150', '-png', pdf, ppmBase]);

    const pages = collectPages(pageDir);
    let ocrText = '';
    const ocrErrors = [];
    for (const pg of pages) {
      const abs = path.join(pageDir, pg);
      const b = abs.replace(/\.png$/, '.ocr');
      try { sh('tesseract', [abs, b, '--psm', '6']); ocrText += '\n' + fs.readFileSync(b + '.txt', 'utf8'); }
      catch (e) { ocrErrors.push(`${pg}: ${String(e.message || e).split('\n')[0]}`); }
    }
    const ocrWords = ocrText.split(/\s+/).filter(w => /[A-Za-z0-9]/.test(w));
    fs.writeFileSync(path.join(args.out, `${args.name}.ocr.combined.txt`), ocrText);

    if (pages.length === 0) {
      // pdftoppm produced nothing: we cannot judge legibility either way.
      add('visual.ocr', 'FULL-VISUAL', 'SKIP', 'pdftoppm produced no page images — nothing to OCR');
    } else if (ocrErrors.length === pages.length) {
      add('visual.ocr', 'FULL-VISUAL', 'SKIP', `tesseract failed on all ${pages.length} page(s): ${ocrErrors[0]}`);
    } else {
      add('visual.ocr', 'FULL-VISUAL', ocrWords.length >= args.minOcrWords ? 'PASS' : 'FAIL',
          `OCR of ${pages.length} rendered page(s) [${pages.join(', ')}] recovered ${ocrWords.length} legible words (min ${args.minOcrWords})` +
          (ocrErrors.length ? ` — ${ocrErrors.length} page(s) errored` : ''));
    }
    report.ocrPages = pages.length;
    report.ocrPageFiles = pages;
    report.ocrPageDir = pageDir;
    if (ocrErrors.length) report.ocrErrors = ocrErrors;
  }

  const skipped = report.checks.filter(c => c.status === 'SKIP');
  const failed = report.checks.filter(c => c.status === 'FAIL');
  report.counts = { total: report.checks.length, pass: report.checks.filter(c => c.status === 'PASS').length, fail: failed.length, skip: skipped.length };
  report.skippedChecks = skipped.map(c => `${c.family}/${c.id}`);

  const verdictPath = path.join(args.out, `${args.name}.verdict.json`);
  fs.writeFileSync(verdictPath, JSON.stringify(repoRelativePaths(report), null, 2));

  console.log(`\n[export-validator] pdf=${pdf}`);
  console.log(`[export-validator] tools: ${Object.entries(tools).map(([k, v]) => k + '=' + (v ? 'ok' : 'MISSING')).join('  ')}`);
  for (const c of report.checks) console.log(`  [${c.status.padEnd(4)}] ${c.family}/${c.id} — ${c.detail}`);
  console.log(`[export-validator] checks: ${report.counts.pass} PASS / ${report.counts.fail} FAIL / ${report.counts.skip} SKIP of ${report.counts.total}`);
  // Say the quiet part out loud: a SKIP is missing coverage, not coverage.
  if (skipped.length) {
    console.log(`[export-validator] ${skipped.length} check(s) DID NOT RUN — coverage is incomplete, this is NOT a pass:`);
    for (const c of skipped) console.log(`      - ${c.family}/${c.id}: ${c.detail}`);
  }
  console.log(`[export-validator] verdict=${report.verdict}  report=${verdictPath}\n`);
  process.exit(report.verdict === 'PASS' ? 0 : report.verdict === 'FAIL' ? 1 : 2);
}

// Run only when invoked as a program. Requiring this file (to exercise
// collectPages directly) must not launch a validation.
if (require.main === module) {
  try { run(); } catch (e) { console.error('[export-validator] HARNESS ERROR:', e); process.exit(2); }
}
