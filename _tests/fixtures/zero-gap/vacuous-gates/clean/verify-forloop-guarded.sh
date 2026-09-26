#!/usr/bin/env bash
# clean: counts what the loop walked and refuses an empty population
set -u
n=0
for f in $(git ls-files 'x*'); do
    n=$((n + 1))
    grep -q marker "$f" || { echo "FAIL $f"; exit 1; }
done
if [ "$n" -eq 0 ]; then
    echo "COULD NOT DETERMINE: no files matched"
    exit 2
fi
echo PASS
exit 0
