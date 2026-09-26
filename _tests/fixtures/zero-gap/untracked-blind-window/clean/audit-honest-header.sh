#!/usr/bin/env bash
# audit-honest-header.sh — scratch fixture.
# Scope: tracked files only. A file that is untracked and not ignored is NOT
# scanned; run `git add -N` first when it must be covered.
git ls-files | while IFS= read -r f; do
    grep -n 'TODO' -- "$f"
done
