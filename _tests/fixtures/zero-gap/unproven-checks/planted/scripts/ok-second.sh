#!/usr/bin/env bash
# fixture check with a real paired-proof arm and a real undetermined probe
set -uo pipefail
run_proof() { echo "M1 mutation caught"; return 0; }
case "${1:-}" in
    --prove-failure) run_proof; exit $? ;;
    --root) [ -d "${2:-}" ] || { echo "COULD NOT DETERMINE: no root"; exit 2; } ;;
esac
exit 0
