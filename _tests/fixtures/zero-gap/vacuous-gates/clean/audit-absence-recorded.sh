#!/usr/bin/env bash
# clean: an empty directory is RECORDED, and the record is refused later, far below the test
# (cannot be read => rc 2), so the emptiness test is not a vacuous pass
set -u
uninit="" checked=0 missing=""
for d in docs specs; do
    if [ -z "$(find "$d" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        uninit="$uninit $d"; continue
    fi
    for f in README.md INDEX.md; do
        p="$d/$f"
        if [ ! -s "$p" ]; then
            missing="$missing $p"; continue
        fi
        checked=$((checked + 1))
        grep -q title "$p" || missing="$missing $p"
    done
done

if [ -n "$uninit" ]; then
    echo "cannot determine: empty or absent:$uninit"
    exit 2
fi
[ -z "$missing" ] || { echo "FAIL missing:$missing"; exit 1; }
echo "PASS $checked"
exit 0
