#!/usr/bin/env bash
# Probe for VSC-377: the verdict of scripts/test-setup-agents-wizard.sh must not be rc 0
# when every case was skipped. Extracts the tree's own summary block (from `^TOTAL=` to
# EOF) and executes it with planted counters. Exit: 0 holds, 1 violated, 2 undetermined.
set -u
src="$PWD/scripts/test-setup-agents-wizard.sh"
[ -f "$src" ] || { echo "probe: $src missing"; exit 2; }
t=$(mktemp -d) || exit 2
trap 'rm -rf "$t"' EXIT
awk '/^TOTAL=/{f=1} f' "$src" > "$t/block.sh"
[ -s "$t/block.sh" ] || { echo "probe: no summary block found"; exit 2; }
runblock() { # $1 PASS $2 FAIL $3 SKIP -> echoes rc
  ( PASS=$1 FAIL=$2 SKIP=$3 STAMP=probe WIZARD=probe HERE=probe
    EVIDENCE_DIR="$t/ev"; RESULTS="$t/ev/results.tsv"; RUNLOG="$t/ev/run.log"
    mkdir -p "$t/ev"; : > "$RUNLOG"
    . "$t/block.sh" ) >/dev/null 2>&1
  echo $?
}
ctl=$(runblock 3 0 1)
[ "$ctl" = 0 ] || { echo "probe: control (3 pass, 0 fail) gave rc $ctl, expected 0"; exit 2; }
red=$(runblock 3 1 0)
[ "$red" = 1 ] || { echo "probe: control (1 fail) gave rc $red, expected 1"; exit 2; }
allskip=$(runblock 0 0 7)
echo "all-skipped run rc=$allskip (0 = vacuous pass, 2 = could not determine)"
[ "$allskip" = 2 ] && exit 0
[ "$allskip" = 0 ] && exit 1
exit 2
