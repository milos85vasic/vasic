#!/usr/bin/env bash
# fixture: gate-like script below the scanroot depth that carries a real paired proof
proof() { echo "M1 caught"; return 0; }
case "${1:-}" in
    --prove-failure) proof; exit $? ;;
esac
exit 0
