#!/usr/bin/env bash
# §11.4.170 self-validation: golden-GOOD must PASS, golden-BAD must FAIL.
# Exits 0 only if BOTH assertions hold. Captures evidence under evidence/harness/visual.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../evidence/harness/visual}"
mkdir -p "$OUT"

echo "=================================================================="
echo " §11.4.170 VISUAL-PROOF HARNESS — SELF-VALIDATION"
echo "=================================================================="

echo; echo ">>> GOLDEN-GOOD (expect PASS) ......................................"
node "$HERE/visual-oracle.js" --input "$HERE/fixtures/good.html" --out "$OUT" --name golden-good --viewport 1280x800 --themes light,dark
GOOD_RC=$?

echo; echo ">>> GOLDEN-BAD  (expect FAIL) ......................................"
node "$HERE/visual-oracle.js" --input "$HERE/fixtures/bad.html" --out "$OUT" --name golden-bad --viewport 1280x800 --themes light,dark
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
  echo "SELF-VALIDATION RESULT: FAIL  (oracle did not behave as required)"
  exit 1
fi
