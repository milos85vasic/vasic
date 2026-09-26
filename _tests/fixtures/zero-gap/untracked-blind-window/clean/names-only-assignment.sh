#!/usr/bin/env bash
# names-only-assignment.sh — scratch fixture: derives tokens from tracked FILENAMES only.
names="$(git ls-files chapters)"
printf '%s\n' "$names" | sed 's#.*/##' | sort -u
