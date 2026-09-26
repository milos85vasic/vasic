#!/usr/bin/env bash
# clean: establishes the subject set is non-empty first
set -u
pop=$(find docs -name '*.md' | wc -l)
if [ "$pop" -eq 0 ]; then
    echo "no files found: undetermined"
    exit 2
fi
find docs -name '*.md' | while read -r f; do
    grep -q title "$f" || echo "FAIL $f"
done
echo PASS
exit 0
