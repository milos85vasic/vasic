#!/usr/bin/env bash
# FIXTURE (feature 010, class unsealed-evidence, planted case "mixed").
# Gate S is sealed in its OWN body (it runs through the evidence adapter's
# `record` subcommand). Gate A is PLANTED unsealed. run_gate carries the
# adapter only inside a COMMENT, which must not count as sealing.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOGDIR=$(mktemp -d)

GATE_IDS=(A S)

gate_A() { bash "$ROOT/scripts/audit.sh"; }

gate_S() {
    bash "$ROOT/scripts/zero-gap-evidence.sh" record --fp-dir "$ROOT" \
        --item-id ATM-001 --check-id gate-s --population-kind source \
        --verdict-role author --independence-tier instance \
        --evidence-class runtime --verdict-exit -- bash "$ROOT/scripts/audit.sh"
}

run_gate() {
    local id=$1
    # TODO: bash "$ROOT/scripts/zero-gap-evidence.sh" record ... -- "gate_$id"
    ( "gate_$id" ) >"$LOGDIR/gate-$id.log" 2>&1
}

for gid in "${GATE_IDS[@]}"; do run_gate "$gid"; done
