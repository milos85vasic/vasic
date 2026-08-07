#!/usr/bin/env bash
# §11.4.168 self-validation: golden-GOOD PDF must PASS, golden-BAD PDF must FAIL.
# Builds fixtures if missing, runs the validator on both, asserts good=PASS/bad=FAIL.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../evidence/harness/export}"
FIX="$HERE/fixtures"
mkdir -p "$OUT"

if [ ! -f "$FIX/golden-good.pdf" ] || [ ! -f "$FIX/golden-bad.pdf" ]; then
  echo ">>> building fixtures ..."; bash "$HERE/build-fixtures.sh"
fi

echo "=================================================================="
echo " §11.4.168 EXPORTED-DOCUMENT VALIDATOR — SELF-VALIDATION"
echo "=================================================================="

echo; echo ">>> GOLDEN-GOOD (expect PASS) ......................................"
node "$HERE/validate-pdf.js" --pdf "$FIX/golden-good.pdf" --out "$OUT" --name golden-good \
  --min-words 40 --min-ocr-words 15 --min-images 1 \
  --expect "Shipped" --expect "Release Q4"
GOOD_RC=$?

echo; echo ">>> GOLDEN-BAD  (expect FAIL) ......................................"
node "$HERE/validate-pdf.js" --pdf "$FIX/golden-bad.pdf" --out "$OUT" --name golden-bad \
  --min-words 40 --min-ocr-words 15 --min-images 1 \
  --expect "Shipped" --expect "Release Q4"
BAD_RC=$?

echo; echo "=================================================================="
echo " ASSERTIONS"
echo "=================================================================="
FAILED=0
if [ "$GOOD_RC" -eq 0 ]; then echo "  PASS: golden-good verdict=PASS (rc=$GOOD_RC)"; else echo "  FAIL: golden-good expected PASS but rc=$GOOD_RC"; FAILED=1; fi
if [ "$BAD_RC" -eq 1 ]; then echo "  PASS: golden-bad verdict=FAIL (rc=$BAD_RC)"; else echo "  FAIL: golden-bad expected FAIL (rc=1) but rc=$BAD_RC"; FAILED=1; fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "SELF-VALIDATION RESULT: PASS  (good=PASS, bad=FAIL as required)"
  echo "Evidence: $OUT"
  exit 0
else
  echo "SELF-VALIDATION RESULT: FAIL  (validator did not behave as required)"
  exit 1
fi
