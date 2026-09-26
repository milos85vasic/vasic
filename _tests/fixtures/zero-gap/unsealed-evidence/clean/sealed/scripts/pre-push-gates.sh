#!/usr/bin/env bash
# FIXTURE (feature 010, class unsealed-evidence, clean case "sealed").
# Every gate runs through the evidence adapter inside run_gate, so every gate
# result is a sealed record. The class must report NOTHING for this case.
ROOT=$(cd "$(dirname "$0")/.." && pwd)

GATE_IDS=(E 0 1)

gate_E() { git -C "$ROOT" ls-files '.github/workflows/*'; }
gate_0() { bash "$ROOT/scripts/audit.sh"; }
gate_1() { bash "$ROOT/scripts/unit.sh"; }

run_gate() {
    local id=$1
    bash "$ROOT/scripts/zero-gap-evidence.sh" record --fp-dir "$ROOT" \
        --item-id ATM-010 --check-id "gate-$id" --population-kind source \
        --verdict-role author --independence-tier instance \
        --evidence-class runtime --verdict-exit -- bash "$0" --one "$id"
}

for gid in "${GATE_IDS[@]}"; do run_gate "$gid"; done
