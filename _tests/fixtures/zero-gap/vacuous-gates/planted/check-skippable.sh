#!/usr/bin/env bash
# planted: straight-line cases, but each can be SKIPPED; with every case skipped nothing ran and
# "no failures => exit 0" still passes
set -u
fail=0 skipped=0
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
skip_case() { skipped=$((skipped + 1)); echo "SKIP $1"; }
if command -v jq >/dev/null 2>&1; then
    jq -e . cfg.json >/dev/null 2>&1 || bad "cfg.json is not valid JSON"
else
    skip_case "jq missing"
fi
[ "$fail" -eq 0 ] && exit 0
exit 1
