#!/usr/bin/env bash
# audit-loop-over-list.sh — scratch fixture: scans "the repo" for TODO markers.
set -u
root=${1:-.}
hits=0
while IFS= read -r f; do
    if grep -q 'TODO' -- "$root/$f"; then hits=$((hits + 1)); fi
done < <(git -C "$root" ls-files)
echo "todo files: $hits"
exit 0
