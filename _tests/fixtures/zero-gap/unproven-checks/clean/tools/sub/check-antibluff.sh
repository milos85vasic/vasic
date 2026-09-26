#!/usr/bin/env bash
# fixture: gate-like script whose paired proof is an --anti-bluff-mutate flag tested with [[ ]]
if [[ "${1:-}" == "--anti-bluff-mutate" ]]; then
    tmp=$(mktemp); : >"$tmp"
    if [ -s "$tmp" ]; then echo "mutation survived"; rm -f "$tmp"; exit 1; fi
    rm -f "$tmp"; echo "mutation caught"; exit 0
fi
[ -s README.md ] || exit 1
exit 0
