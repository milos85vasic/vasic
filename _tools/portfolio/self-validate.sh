#!/usr/bin/env bash
# §1.1 anti-bluff mutation self-test for the portfolio DATA validator.
#
# A gate that cannot FAIL is a rubber stamp. This harness proves the portfolio
# validator (_tools/portfolio/validate.mjs) is mutation-paired:
#   - golden-GOOD fixture MUST PASS  (validate.mjs exits 0)
#   - golden-BAD  fixture MUST FAIL  (validate.mjs exits non-zero)
# It exits 0 only if BOTH hold, and writes verdict evidence JSON under
# _tests/evidence/harness/portfolio/ (good.verdict.json, bad.verdict.json),
# mirroring the export/visual self-validate evidence style.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FIX="$HERE/selfvalidate-fixtures"
VALIDATOR="$HERE/validate.mjs"
OUT="${1:-$ROOT/_tests/evidence/harness/portfolio}"
mkdir -p "$OUT"

# Run validate.mjs against a fixture, capture output + rc, and emit a verdict
# JSON. Args: <fixture-path> <name> <expected-verdict PASS|FAIL>
run_case() {
  fixture="$1"; name="$2"; expect="$3"
  log="$OUT/$name.output.txt"
  node "$VALIDATOR" --file "$fixture" >"$log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then verdict="PASS"; else verdict="FAIL"; fi
  node -e '
    const fs = require("node:fs");
    const [fixture, name, expect, rcStr, verdict, logFile, outFile] = process.argv.slice(1);
    const lines = fs.readFileSync(logFile, "utf8").split("\n").filter(Boolean);
    const doc = {
      schema: "portfolio-validator/1",
      generatedAt: new Date().toISOString(),
      validator: "_tools/portfolio/validate.mjs",
      fixture,
      name,
      expected: expect,
      rc: Number(rcStr),
      verdict,
      match: (verdict === expect),
      output: lines,
    };
    fs.writeFileSync(outFile, JSON.stringify(doc, null, 2) + "\n");
  ' "$fixture" "$name" "$expect" "$rc" "$verdict" "$log" "$OUT/$name.verdict.json"
  echo "$rc"
}

echo "=================================================================="
echo " §1.1 PORTFOLIO DATA VALIDATOR — MUTATION SELF-VALIDATION"
echo "=================================================================="

echo; echo ">>> GOLDEN-GOOD (expect PASS) ......................................"
GOOD_RC="$(run_case "$FIX/good.json" golden-good PASS)"
cat "$OUT/golden-good.output.txt"

echo; echo ">>> GOLDEN-BAD  (expect FAIL) ......................................"
BAD_RC="$(run_case "$FIX/bad.json" golden-bad FAIL)"
cat "$OUT/golden-bad.output.txt"

echo; echo "=================================================================="
echo " ASSERTIONS"
echo "=================================================================="
FAILED=0
if [ "$GOOD_RC" -eq 0 ]; then
  echo "  PASS: golden-good verdict=PASS (rc=$GOOD_RC)"
else
  echo "  FAIL: golden-good expected PASS but rc=$GOOD_RC"; FAILED=1
fi
if [ "$BAD_RC" -ne 0 ]; then
  echo "  PASS: golden-bad verdict=FAIL (rc=$BAD_RC)"
else
  echo "  FAIL: golden-bad expected FAIL (rc!=0) but rc=$BAD_RC"; FAILED=1
fi

echo
echo "Evidence:"
echo "  $OUT/golden-good.verdict.json"
echo "  $OUT/golden-bad.verdict.json"
echo
if [ "$FAILED" -eq 0 ]; then
  echo "SELF-VALIDATION RESULT: PASS  (good=PASS, bad=FAIL as required)"
  exit 0
else
  echo "SELF-VALIDATION RESULT: FAIL  (validator is not mutation-paired)"
  exit 1
fi
