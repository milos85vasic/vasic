#!/usr/bin/env bash
# clean: refuses a run that executed no case
set -u
fail=0 ran=0
for t in "$@"; do
    ran=$((ran + 1))
    bash "$t" || fail=$((fail + 1))
done
if [ "$ran" -eq 0 ]; then echo "could not determine: no cases"; exit 2; fi
[ "$fail" -eq 0 ] && exit 0
exit 1
