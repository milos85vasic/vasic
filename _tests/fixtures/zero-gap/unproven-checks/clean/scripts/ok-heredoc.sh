#!/usr/bin/env bash
# fixture: a stub-looking arm inside a heredoc (a fixture gate written to a temp file) precedes the REAL arm;
# the class must judge the real arm and report nothing
mk_fixture() {
    cat <<'GATE'
case "${1:-}" in
  --prove-failure) echo "1 passed"; exit 0 ;;
esac
GATE
}
proof() { echo "M1 caught"; return 0; }
case "${1:-}" in
    --prove-failure) proof; exit $? ;;
    --root) [ -d "${2:-}" ] || exit 2 ;;
esac
exit 0
