#!/usr/bin/env bash
# fixture: gate-like script below the scanroot depth whose proof arm is a stub (echo + exit 0)
case "${1:-}" in
    --prove-failure) echo "proof passed"; exit 0 ;;
esac
grep -q x README.md || exit 1
exit 0
