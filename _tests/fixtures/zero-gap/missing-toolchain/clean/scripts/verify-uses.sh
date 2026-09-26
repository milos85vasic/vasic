#!/usr/bin/env bash
# comment: command -v commentedtool is not a precondition
command -v presenttool >/dev/null 2>&1 || exit 2
command -v presenttool2 >/dev/null 2>&1 || exit 2
cat <<'TXT'
command -v inheredoc
TXT
