#!/usr/bin/env bash
# Runs BOTH §11.4.170 (visual) and §11.4.168 (export) self-validations.
#
# Three-valued, and it must STAY three-valued through this aggregator: a child
# returning 2 ("could not run") is not the same event as a child returning 1
# ("the gate is broken"), and collapsing both into a single FAIL destroys the
# distinction the children were changed to preserve. Mirrors the run_gate
# UNDET verdict in scripts/pre-push-gates.sh.
#
#   0 = both self-validations passed with full coverage
#   1 = at least one is a REAL finding
#   2 = no real finding, but at least one could not be carried out
# Precedence: 1 outranks 2 outranks 0, so an undetermined child can never mask
# a broken one.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/visual/self-validate.sh"; V=$?
bash "$HERE/export/self-validate.sh"; E=$?

verdict_of() { case "$1" in 0) echo PASS ;; 1) echo FAIL ;; 2) echo UNDETERMINED ;; *) echo "UNDETERMINED(unexpected rc=$1)" ;; esac; }

echo
echo "###################################################################"
echo " OVERALL:  visual self-validation rc=$V ($(verdict_of "$V"))   export self-validation rc=$E ($(verdict_of "$E"))"
if [ "$V" -eq 1 ] || [ "$E" -eq 1 ]; then
  echo " OVERALL RESULT: FAIL  (a self-validation is a real finding)"; exit 1
elif [ "$V" -ne 0 ] || [ "$E" -ne 0 ]; then
  echo " OVERALL RESULT: UNDETERMINED  (a self-validation could not be carried out — rc=2, NOT a pass)"; exit 2
fi
echo " OVERALL RESULT: PASS"; exit 0
