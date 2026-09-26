#!/usr/bin/env bash
# FIXTURE (feature 010, class unsealed-evidence, planted case "mixed").
# A daily runner that seals ONE check with a literal id, mentions another only
# in a comment, and seals a third only through a computed id.
ROOT=$(cd "$(dirname "$0")/.." && pwd)

bash "$ROOT/scripts/zero-gap-evidence.sh" record --fp-dir "$ROOT" \
    --item-id ATM-002 \
    --check-id sealed-x \
    --population-kind source --verdict-role author --independence-tier instance \
    --evidence-class runtime --verdict-exit -- bash "$ROOT/scripts/x.sh"

# bash "$ROOT/scripts/zero-gap-evidence.sh" record --check-id commented-y -- bash "$ROOT/scripts/y.sh"

for id in computed-z; do
    bash "$ROOT/scripts/zero-gap-evidence.sh" record --fp-dir "$ROOT" --item-id ATM-003 \
        --check-id "$id" --population-kind source --verdict-role author \
        --independence-tier instance --evidence-class runtime --verdict-exit -- bash "$ROOT/scripts/$id.sh"
done
