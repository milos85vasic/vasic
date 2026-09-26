#!/usr/bin/env bash
# state-only.sh — scratch fixture: verifies git STATE, reads no file content.
if git ls-files --error-unmatch -- settings.json >/dev/null 2>&1; then echo tracked; fi
gitlink=$(git ls-files -s -- sub | awk '$1=="160000"{print $2}')
echo "$gitlink"
