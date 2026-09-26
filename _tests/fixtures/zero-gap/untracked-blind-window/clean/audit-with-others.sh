#!/usr/bin/env bash
# audit-with-others.sh — scratch fixture: sees tracked AND untracked-not-ignored files.
{
    git ls-files
    git ls-files --others --exclude-standard
} | sort -u | while IFS= read -r f; do
    grep -n 'TODO' -- "$f"
done
