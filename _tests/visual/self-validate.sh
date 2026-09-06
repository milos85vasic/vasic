#!/usr/bin/env bash
# §11.4.170 self-validation: golden-GOOD must PASS, golden-BAD must be DETECTED.
# Exits 0 only if BOTH assertions hold. Captures evidence under evidence/harness/visual.
#
# BOTH HALVES OF THE rc-2 CONTRACT MATTER (§1.1, §11.4.6).
# visual-oracle.js documents 0=PASS / 1=FAIL / 2=harness error, but until
# 2026-09-06 it loaded @playwright/test at TOP LEVEL, outside its own
# `run().catch(... exit(2))`. With `_tests/node_modules` absent — the ordinary
# state of a fresh clone — the module threw MODULE_NOT_FOUND and node exited
# **1**. This script's golden-BAD arm asserts rc 1, so a crash-at-load was
# recorded as a caught defect: `PASS: golden-bad verdict=FAIL (rc=1)` printed
# while the oracle had never opened the fixture.
# The oracle now exits 2 for any could-not-run condition, and this harness
# reports UNDETERMINED separately from DETECTED rather than banking it.
#
# Three-valued exit (2 is NEVER a pass):
#   0 = both arms behaved as required
#   1 = the oracle is not mutation-paired (a real finding about the gate)
#   2 = the self-test could not be carried out (dependency/toolchain fault)
# Precedence: a real finding (1) outranks could-not-determine (2).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../evidence/harness/visual}"
mkdir -p "$OUT"

echo "=================================================================="
echo " §11.4.170 VISUAL-PROOF HARNESS — SELF-VALIDATION"
echo "=================================================================="
# GATE: CM-HOST-RENDERED-UI-VISUAL-PROOF (§11.4.170) — this self-validation IS
# the check that satisfies that constitution gate (see _tests/GATES.md).
echo "GATE: CM-HOST-RENDERED-UI-VISUAL-PROOF (§11.4.170)"

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
UNDET=0

if [ "$GOOD_RC" -eq 0 ]; then
  echo "  PASS: golden-good verdict=PASS (rc=0)"
elif [ "$GOOD_RC" -eq 2 ]; then
  echo "  UNDET: golden-good COULD NOT BE RENDERED (rc=2) — oracle never ran"; UNDET=1
else
  echo "  FAIL: golden-good expected PASS (rc=0) but rc=$GOOD_RC"; FAILED=1
fi

# rc 1 is the DETECTION code and must not be conflated with a crash. rc 2
# means the oracle could not run, so this arm proves NOTHING about whether the
# seeded layout defect would be caught.
if [ "$BAD_RC" -eq 1 ]; then
  echo "  PASS: golden-bad DETECTED (rc=1 — oracle ran and found layout errors)"
elif [ "$BAD_RC" -eq 2 ]; then
  echo "  UNDET: golden-bad COULD NOT BE RENDERED (rc=2) — oracle never ran;"
  echo "         this run proves NOTHING about whether the defect is detected"; UNDET=1
else
  echo "  FAIL: golden-bad expected DETECTION (rc=1) but rc=$BAD_RC"; FAILED=1
fi

echo
if [ "$FAILED" -ne 0 ]; then
  echo "SELF-VALIDATION RESULT: FAIL  (oracle did not behave as required)"
  echo "GATE: CM-HOST-RENDERED-UI-VISUAL-PROOF (§11.4.170) — NOT SATISFIED"
  exit 1
elif [ "$UNDET" -ne 0 ]; then
  echo "SELF-VALIDATION RESULT: UNDETERMINED  (the self-test could not be carried out)"
  echo "GATE: CM-HOST-RENDERED-UI-VISUAL-PROOF (§11.4.170) — COULD NOT DETERMINE (rc=2, NOT a pass)"
  echo "Evidence: $OUT"
  exit 2
else
  echo "SELF-VALIDATION RESULT: PASS  (good=PASS rc=0, bad=DETECTED rc=1 as required)"
  echo "GATE: CM-HOST-RENDERED-UI-VISUAL-PROOF (§11.4.170) — SATISFIED"
  echo "Evidence: $OUT"
  exit 0
fi
