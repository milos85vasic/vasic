#!/usr/bin/env bash
# fixture: the proof arm only echoes and exits 0
case "${1:-}" in
    --prove-failure) echo "proof passed"; exit 0 ;;
    --root) [ -d "${2:-}" ] || exit 2 ;;
esac
exit 0
