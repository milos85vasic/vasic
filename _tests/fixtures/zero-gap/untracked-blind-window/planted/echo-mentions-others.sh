#!/usr/bin/env bash
# echo-mentions-others.sh — scratch fixture: a MESSAGE names --others; the enumeration never reads them.
echo "note: this audit does not pass --others to git ls-files"
git ls-files | while IFS= read -r f; do grep -n 'TODO' -- "$f"; done
