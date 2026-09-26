#!/usr/bin/env bash
# planted: enumeration loop whose emptiness passes
set -u
for f in $(git ls-files 'x*'); do
    grep -q marker "$f" || { echo "FAIL $f"; exit 1; }
done
echo PASS
exit 0
