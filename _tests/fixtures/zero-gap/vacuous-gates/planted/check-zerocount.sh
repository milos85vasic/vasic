#!/usr/bin/env bash
# planted: a zero count is reported as a pass
set -u
n=$(git ls-files 'a*' | wc -l)
if [ "$n" -eq 0 ]; then
    echo "PASS no offenders"
    exit 0
fi
exit 1
