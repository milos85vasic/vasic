#!/usr/bin/env bash
# §11.4.168 self-validation: golden-GOOD PDF must PASS, golden-BAD PDF must be
# DETECTED. Builds fixtures if missing, runs the validator on both.
#
# A SKIPPED CHECK FAMILY IS NOT COVERAGE (§11.4.6).
# validate-pdf.js reported missing tools honestly per-check and then let the
# run end SATISFIED anyway: its verdict only ever moved on a FAIL. Measured on
# a host without tesseract, BOTH fixtures printed
# `[SKIP] FULL-VISUAL/visual.ocr` — the entire OCR-legibility family never ran —
# and this script still printed
# `GATE: CM-EXPORTED-DOC-VISUALLY-VALIDATED (§11.4.168) — SATISFIED`, exit 0.
# Meanwhile the COMMITTED evidence for the same two fixtures records
# `"tesseract": true` and `"OCR ... recovered 109 legible words"`, so the gate
# was claiming coverage this host demonstrably did not perform.
#
# validate-pdf.js now returns 2 for UNDETERMINED (no FAIL, but a check could
# not RUN), and this harness surfaces that instead of banking it.
#
# Three-valued exit (2 is NEVER a pass):
#   0 = both arms behaved as required, with full coverage
#   1 = the validator is not mutation-paired (a real finding about the gate)
#   2 = the self-test could not be fully carried out (missing toolchain)
# Precedence: a real finding (1) outranks could-not-determine (2).
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
# GATE: CM-EXPORTED-DOC-VISUALLY-VALIDATED (§11.4.168) — this self-validation IS
# the check that satisfies that constitution gate (see _tests/GATES.md).
echo "GATE: CM-EXPORTED-DOC-VISUALLY-VALIDATED (§11.4.168)"

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
UNDET=0

# rc 2 on the GOOD arm = no check failed, but at least one never ran. The
# fixture is not proved good; part of the gate simply did not execute.
if [ "$GOOD_RC" -eq 0 ]; then
  echo "  PASS: golden-good verdict=PASS (rc=0, full coverage)"
elif [ "$GOOD_RC" -eq 2 ]; then
  echo "  UNDET: golden-good verdict=UNDETERMINED (rc=2) — a check family did NOT RUN;"
  echo "         coverage is incomplete, so this arm is not a pass"; UNDET=1
else
  echo "  FAIL: golden-good expected PASS (rc=0) but rc=$GOOD_RC"; FAILED=1
fi

# rc 1 on the BAD arm is the DETECTION code. rc 2 means the seeded defects were
# not all reachable by the checks that actually ran.
if [ "$BAD_RC" -eq 1 ]; then
  echo "  PASS: golden-bad DETECTED (rc=1 — checks ran and failed as required)"
elif [ "$BAD_RC" -eq 2 ]; then
  echo "  UNDET: golden-bad verdict=UNDETERMINED (rc=2) — no check FAILED and at"
  echo "         least one did not run; the mutation was not proved detectable"; UNDET=1
else
  echo "  FAIL: golden-bad expected DETECTION (rc=1) but rc=$BAD_RC"; FAILED=1
fi

echo
if [ "$FAILED" -ne 0 ]; then
  echo "SELF-VALIDATION RESULT: FAIL  (validator did not behave as required)"
  echo "GATE: CM-EXPORTED-DOC-VISUALLY-VALIDATED (§11.4.168) — NOT SATISFIED"
  exit 1
elif [ "$UNDET" -ne 0 ]; then
  echo "SELF-VALIDATION RESULT: UNDETERMINED  (a check family could not run on this host)"
  echo "GATE: CM-EXPORTED-DOC-VISUALLY-VALIDATED (§11.4.168) — COULD NOT DETERMINE (rc=2, NOT a pass)"
  echo "Evidence: $OUT"
  exit 2
else
  echo "SELF-VALIDATION RESULT: PASS  (good=PASS rc=0, bad=DETECTED rc=1 as required)"
  echo "GATE: CM-EXPORTED-DOC-VISUALLY-VALIDATED (§11.4.168) — SATISFIED"
  echo "Evidence: $OUT"
  exit 0
fi
