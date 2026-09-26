#!/usr/bin/env bash
# audit-command-substitution.sh — scratch fixture: enumerates into a variable, then loops.
files="$(git ls-files -- '*.sh')"
for f in $files; do
    grep -n 'secret' "$f"
done
