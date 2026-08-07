#!/usr/bin/env bash
# Runs BOTH §11.4.170 (visual) and §11.4.168 (export) self-validations.
# Exit 0 only if both pass their good=PASS / bad=FAIL assertions.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/visual/self-validate.sh"; V=$?
bash "$HERE/export/self-validate.sh"; E=$?
echo
echo "###################################################################"
echo " OVERALL:  visual self-validation rc=$V   export self-validation rc=$E"
[ "$V" -eq 0 ] && [ "$E" -eq 0 ] && { echo " OVERALL RESULT: PASS"; exit 0; }
echo " OVERALL RESULT: FAIL"; exit 1
