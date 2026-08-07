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
 * Verdict = PASS only if every enabled hard check passes. Missing tools are
 * reported as SKIP-with-reason (never a faked PASS).
 *
 * Usage:
 *   node validate-pdf.js --pdf <file> --out <dir> --name <name>
 *        [--min-words 40] [--min-ocr-words 15] [--min-images 1]
 *        [--expect "phrase" ...]
 * Exit: 0 = PASS, 1 = FAIL, 2 = harness error.
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
function sh(cmd, args) { return execFileSync(cmd, args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }); }

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
    schema: 'export-validator/1', generatedAt: new Date().toISOString(),
    pdf, name: args.name, tools, thresholds: { minWords: args.minWords, minOcrWords: args.minOcrWords, minImages: args.minImages, expect: args.expect },
    checks: [], verdict: 'PASS',
  };
  const add = (id, family, status, detail) => {
    report.checks.push({ id, family, status, detail });
    if (status === 'FAIL') report.verdict = 'FAIL';
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
    const ppmBase = path.join(args.out, `${args.name}.page`);
    sh('pdftoppm', ['-r', '150', '-png', pdf, ppmBase]);
    const pages = fs.readdirSync(args.out).filter(f => f.startsWith(`${args.name}.page`) && f.endsWith('.png')).sort();
    let ocrText = '';
    for (const pg of pages) {
      const b = path.join(args.out, pg.replace(/\.png$/, '.ocr'));
      try { sh('tesseract', [path.join(args.out, pg), b, '--psm', '6']); ocrText += '\n' + fs.readFileSync(b + '.txt', 'utf8'); }
      catch (e) { /* record but continue */ ocrText += ''; }
    }
    const ocrWords = ocrText.split(/\s+/).filter(w => /[A-Za-z0-9]/.test(w));
    fs.writeFileSync(path.join(args.out, `${args.name}.ocr.combined.txt`), ocrText);
    add('visual.ocr', 'FULL-VISUAL', ocrWords.length >= args.minOcrWords ? 'PASS' : 'FAIL',
        `OCR of ${pages.length} rendered page(s) recovered ${ocrWords.length} legible words (min ${args.minOcrWords})`);
    report.ocrPages = pages.length;
  }

  const verdictPath = path.join(args.out, `${args.name}.verdict.json`);
  fs.writeFileSync(verdictPath, JSON.stringify(report, null, 2));

  console.log(`\n[export-validator] pdf=${pdf}`);
  console.log(`[export-validator] tools: ${Object.entries(tools).map(([k, v]) => k + '=' + (v ? 'ok' : 'MISSING')).join('  ')}`);
  for (const c of report.checks) console.log(`  [${c.status.padEnd(4)}] ${c.family}/${c.id} — ${c.detail}`);
  console.log(`[export-validator] verdict=${report.verdict}  report=${verdictPath}\n`);
  process.exit(report.verdict === 'PASS' ? 0 : 1);
}

try { run(); } catch (e) { console.error('[export-validator] HARNESS ERROR:', e); process.exit(2); }
