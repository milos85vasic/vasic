#!/usr/bin/env bash
# fixture: gate-like script whose paired proof is a POSITIONAL mode word ([normal|mutate])
MODE="${1:-normal}"
check() { grep -q title "${2:-README.md}"; }
case "$MODE" in
    normal) check || exit 1 ;;
    mutate) tmp=$(mktemp); printf 'none\n' >"$tmp"; if check x "$tmp"; then rm -f "$tmp"; echo "mutation survived"; exit 1; fi; rm -f "$tmp"; echo "mutation caught" ;;
esac
exit 0
