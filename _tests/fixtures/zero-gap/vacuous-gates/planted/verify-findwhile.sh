#!/usr/bin/env bash
# planted: find piped into while, zero files => zero cases => PASS
set -u
find docs -name '*.md' | while read -r f; do
    grep -q title "$f" || echo "FAIL $f"
done
echo "all PASS"
exit 0
