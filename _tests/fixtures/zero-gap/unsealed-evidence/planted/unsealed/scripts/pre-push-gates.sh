#!/usr/bin/env bash
# FIXTURE (feature 010, class unsealed-evidence, planted case "unsealed").
# Shaped like the real scripts/pre-push-gates.sh: every gate result lives only
# in a temporary per-gate log and an in-memory SUMMARY row. No gate goes
# through the evidence adapter, so gates E and 0 are PLANTED unsealed.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOGDIR=$(mktemp -d)
SUMMARY=()

GATE_IDS=(E 0)

gate_E() { git -C "$ROOT" ls-files '.github/workflows/*'; }

gate_0() { bash "$ROOT/scripts/audit.sh"; }

run_gate() {
    local id=$1 rc
    ( "gate_$id" ) >"$LOGDIR/gate-$id.log" 2>&1
    rc=$?
    SUMMARY+=("$rc|$id")
    return "$rc"
}

for gid in "${GATE_IDS[@]}"; do run_gate "$gid"; done
