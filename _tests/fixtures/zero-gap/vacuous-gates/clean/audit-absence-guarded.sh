#!/usr/bin/env bash
# clean: subject set proven non-empty before the absence assertion
set -u
if [ "$(git ls-files 'docs/*' | wc -l)" -gt 0 ]; then :; else
    echo "empty population: undetermined"
    exit 2
fi
if [ -z "$(grep -rn TODO docs)" ]; then
    echo PASS
    exit 0
fi
exit 1
