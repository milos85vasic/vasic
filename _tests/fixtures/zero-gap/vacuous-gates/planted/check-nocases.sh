#!/usr/bin/env bash
# planted: counts failures only; zero executed cases exits 0
set -u
fail=0
for t in "$@"; do
    bash "$t" || fail=$((fail + 1))
done
[ "$fail" -eq 0 ] && exit 0
exit 1
