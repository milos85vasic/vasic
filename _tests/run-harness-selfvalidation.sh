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
#
# Options (VSC-374, so the aggregation itself has a paired proof and an executed could-not-determine probe):
#   --children DIR   run DIR/visual/self-validate.sh and DIR/export/self-validate.sh instead of the siblings
#                    of this file; a missing child is rc 127, which is UNDETERMINED (exit 2), never a pass
#   --prove-failure  drive the aggregation with stub children over every (visual, export) rc pair and assert
#                    the documented precedence; exit 0 all asserted, 1 a case differed, 2 could not run
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CHILDREN="$HERE"
SELF="$HERE/$(basename "$0")"
case "${1:-}" in
  --prove-failure)
    T=$(mktemp -d) || { echo "prove-failure: cannot create a scratch directory"; exit 2; }
    trap 'rm -rf "$T"' EXIT
    mkdir -p "$T/visual" "$T/export" || exit 2
    pass=0; fail=0
    for v in 0 1 2; do for e in 0 1 2; do
      printf '#!/usr/bin/env bash\nexit %s\n' "$v" >"$T/visual/self-validate.sh"
      printf '#!/usr/bin/env bash\nexit %s\n' "$e" >"$T/export/self-validate.sh"
      if [ "$v" -eq 1 ] || [ "$e" -eq 1 ]; then want=1; elif [ "$v" -ne 0 ] || [ "$e" -ne 0 ]; then want=2; else want=0; fi
      bash "$SELF" --children "$T" >/dev/null 2>&1; got=$?
      if [ "$got" -eq "$want" ]; then pass=$((pass+1)); echo "PASS visual=$v export=$e -> $got"
      else fail=$((fail+1)); echo "FAIL visual=$v export=$e -> $got (want $want)"; fi
    done; done
    # an unexpected child rc (e.g. a crash, 7) must be UNDETERMINED, never a pass
    printf '#!/usr/bin/env bash\nexit 7\n' >"$T/visual/self-validate.sh"; printf '#!/usr/bin/env bash\nexit 0\n' >"$T/export/self-validate.sh"
    bash "$SELF" --children "$T" >/dev/null 2>&1; got=$?
    if [ "$got" -eq 2 ]; then pass=$((pass+1)); echo "PASS unexpected child rc 7 -> 2"; else fail=$((fail+1)); echo "FAIL unexpected child rc 7 -> $got (want 2)"; fi
    # a missing child must be UNDETERMINED
    bash "$SELF" --children "$T/absent" >/dev/null 2>&1; got=$?
    if [ "$got" -eq 2 ]; then pass=$((pass+1)); echo "PASS missing children -> 2"; else fail=$((fail+1)); echo "FAIL missing children -> $got (want 2)"; fi
    echo "prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ] && exit 0 || exit 1 ;;
  --children) CHILDREN="${2:-}"; [ -n "$CHILDREN" ] || { echo "--children needs a directory"; exit 2; } ;;
esac
bash "$CHILDREN/visual/self-validate.sh"; V=$?
bash "$CHILDREN/export/self-validate.sh"; E=$?

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
