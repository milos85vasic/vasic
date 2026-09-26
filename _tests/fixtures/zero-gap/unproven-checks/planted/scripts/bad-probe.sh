#!/usr/bin/env bash
# fixture: real proof arm, but --root /nonexistent exits 0 (unable-to-verify reported as a pass)
run_proof() { echo "M1 caught"; return 0; }
case "${1:-}" in
    --prove-failure) run_proof; exit $? ;;
    --root) exit 0 ;;
esac
exit 0
