#!/usr/bin/env bash
# FIXTURE (feature 010, class unsealed-evidence, clean case "sealed").
# Seals both registered checks, one with a quoted id, one with the --flag=value form.
ROOT=$(cd "$(dirname "$0")/.." && pwd)

bash "$ROOT/scripts/zero-gap-evidence.sh" record --fp-dir "$ROOT" --item-id ATM-011 --check-id 'sealed-a' \
    --population-kind source --verdict-role author --independence-tier instance \
    --evidence-class runtime --verdict-exit -- bash "$ROOT/scripts/a.sh"

bash "$ROOT/scripts/zero-gap-evidence.sh" record --fp-dir "$ROOT" --item-id ATM-012 --check-id=sealed-b \
    --population-kind source --verdict-role author --independence-tier instance \
    --evidence-class runtime --verdict-exit -- bash "$ROOT/scripts/b.sh"
