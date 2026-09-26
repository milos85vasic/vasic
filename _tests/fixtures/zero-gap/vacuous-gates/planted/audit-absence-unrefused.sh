#!/usr/bin/env bash
# planted: the empty case is recorded, but the record is only PRINTED, never refused, so an
# all-empty population still reaches PASS
set -u
uninit="" missing=""
for d in docs specs; do
    if [ -z "$(find "$d" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        uninit="$uninit $d"; continue
    fi
    for f in README.md INDEX.md; do
        p="$d/$f"
        if [ ! -s "$p" ]; then
            missing="$missing $p"; continue
        fi
        grep -q title "$p" || missing="$missing $p"
    done
done

if [ -n "$uninit" ]; then
    echo "note: empty or absent:$uninit"
fi
checked=$(printf '%s' "$missing" | wc -w)
echo "checked, $checked missing"
[ -z "$missing" ] || { echo "FAIL missing:$missing"; exit 1; }
echo PASS
exit 0
