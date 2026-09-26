#!/usr/bin/env bash
# clean: a fixed, straight-line proof battery; every case runs on every invocation, so the
# "no failures => exit 0" verdict cannot be reached with zero executed cases
set -u
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "PASS $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
if [ -f README.md ]; then ok "readme present"; else bad "readme absent"; fi
out=$(bash ./check-plain.sh 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then ok "plain rc 0"; else bad "plain rc=$rc: $out"; fi
for m in alpha beta gamma; do
    if [ -n "$m" ]; then ok "literal case $m"; else bad "literal case $m"; fi
done
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] && exit 0
exit 1
