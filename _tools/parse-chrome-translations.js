#!/usr/bin/env node
// parse-chrome-translations.js — maps a numbered translated chrome list back to
// key=value pairs and emits a JS object-literal block for MV_I18N.
// Usage: node _tools/parse-chrome-translations.js <lang> <raw-translated.txt>
// Reads the EN keys from /tmp/en-chrome.txt (one key=value per line, stable order).

const fs = require('fs');
const path = require('path');

const lang = process.argv[2];
const rawFile = process.argv[3];
if (!lang || !rawFile) { console.error('usage: parse-chrome-translations.js <lang> <raw.txt>'); process.exit(2); }

// Load EN keys in order.
const enLines = fs.readFileSync('/tmp/en-chrome.txt', 'utf8').trim().split('\n');
const keys = enLines.map(l => l.slice(0, l.indexOf('=')));
const enValues = enLines.map(l => l.slice(l.indexOf('=') + 1));

// Load and clean the translated numbered list.
let lines = fs.readFileSync(rawFile, 'utf8').trim().split('\n');

// Digit classes: ASCII, Arabic-Indic (٠-٩ U+0660), Persian/Farsi (۰-۹ U+06F0).
const DIGIT = '[0-9٠-٩۰-۹]';
const DIGIT_RE = new RegExp('^' + DIGIT + '+[.)]\\s*');

// Convert any localized digit string to a JS integer.
function toInt(s) {
  // Normalize Arabic-Indic and Persian digits to ASCII before parseInt.
  return parseInt(s.replace(/[٠-٩]/g, c => c.charCodeAt(0) - 0x660)
                   .replace(/[۰-۹]/g, c => c.charCodeAt(0) - 0x6F0));
}

// Strip leading "Contents" artifact (localized: Содержание, Contenu, 目录, 목차, …)
// Heuristic: first non-empty line that is NOT a numbered entry.
while (lines.length && !DIGIT_RE.test(lines[0])) {
  lines.shift();
}

// Parse numbered entries. The engine may emit "N.text" or "N) text" or "N. text"
// with ASCII, Arabic-Indic, or Persian digits.
const numPat = new RegExp('^(' + DIGIT + '+)[.)]\\s*(.*)');
const translated = {};
for (const line of lines) {
  const m = line.match(numPat);
  if (m) translated[toInt(m[1])] = m[2];
}

// Build the JS object literal.
const entries = keys.map((k, i) => {
  const n = i + 1;
  let val = translated[n] || enValues[i]; // fallback to EN if missing
  // Escape backslashes and single quotes for JS string literal.
  val = val.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
  return `    '${k}': '${val}'`;
});

console.log(`  ${lang}: {\n${entries.join(',\n')}\n  },`);

// Report coverage.
const found = keys.filter((_, i) => translated[i + 1]).length;
console.error(`${lang}: ${found}/${keys.length} keys translated (${keys.length - found} fell back to EN)`);
