#!/usr/bin/env bash
# fixture: the proof arm sets a variable that nothing reads
case "${1:-}" in
    --prove-failure) PROVING=1; shift ;;
    --root) [ -d "${2:-}" ] || exit 2 ;;
esac
exit 0
