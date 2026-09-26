#!/usr/bin/env bash
# planted: the failure counter is only incremented inside a loop over DATA; an empty input
# runs zero cases and still reaches "no failures => exit 0"
set -u
fail=0
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
while IFS= read -r f; do
    [ -s "$f" ] || bad "$f is empty"
done < "$1"
[ "$fail" -eq 0 ] && exit 0
exit 1
