#!/usr/bin/env bash
# no-ls-files.sh — scratch fixture: enumerates the working tree directly.
find . -type f -name '*.sh' -print0 | xargs -0 grep -n 'TODO'
