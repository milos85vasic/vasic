#!/usr/bin/env bash
# planted: while loop fed by process substitution over git ls-files; zero files => PASS
set -u
while IFS= read -r f; do
    grep -q title "$f" || { echo "FAIL $f"; exit 1; }
done < <(git ls-files '*.md')
echo PASS
exit 0
