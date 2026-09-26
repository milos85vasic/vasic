#!/usr/bin/env bash
# fixture: the registry names --prove-failure but this script has no such case arm
case "${1:-}" in
    --root) [ -d "${2:-}" ] || exit 2 ;;
esac
exit 0
