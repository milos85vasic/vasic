#!/usr/bin/env bash
# audit-co-short-options.sh — scratch fixture: -co is --cached plus --others in one short-option cluster.
git ls-files -co --exclude-standard | while IFS= read -r f; do grep -n 'TODO' -- "$f"; done
