#!/usr/bin/env bash
# fixture: proof arm dispatches to a real proof through a variable that IS read
PROVE=0
proof() { echo "M1 caught"; return 0; }
case "${1:-}" in
    --selftest) PROVE=1; shift ;;
    --root) [ -d "${2:-}" ] || exit 2 ;;
esac
if [ "$PROVE" -eq 1 ]; then proof; exit $?; fi
exit 0
