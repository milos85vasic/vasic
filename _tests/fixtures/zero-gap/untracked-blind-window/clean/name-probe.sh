#!/usr/bin/env bash
# name-probe.sh — scratch fixture: probes tracked NAMES only, opens no file.
active="$(git ls-files | grep -E '^\.github/workflows/.*\.ya?ml$' || true)"
[ -n "$(git ls-files 'docs/*.md')" ] && echo docs
echo "active workflows: ${active:-none}"
