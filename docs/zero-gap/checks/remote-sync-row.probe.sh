#!/usr/bin/env bash
# Shared probe for gitlink-freshness items: run from the root of the tree under test.
#   usage: remote-sync-row.probe.sh <gitlink path>
# Runs the repository's own scripts/verify-submodule-remote-sync.sh (a network read: git ls-remote) and
# requires the row for <path> to read CURRENT. Exit 0 CURRENT / 1 any other verdict / 2 cannot determine
# (gate absent, no row for the path, or the gate could not run).
set -u
p=${1:-}
[ -n "$p" ] || { echo "usage: $0 <gitlink path>"; exit 2; }
export TMPDIR=${TMPDIR:-/tmp}
[ -f scripts/verify-submodule-remote-sync.sh ] || { echo "gate absent"; exit 2; }
out=$(bash scripts/verify-submodule-remote-sync.sh 2>&1); rc=$?
row=$(printf '%s\n' "$out" | awk -v p="$p" '$1==p && NF>=4 {print; exit}')
[ -n "$row" ] || { echo "no row for $p (gate rc $rc)"; exit 2; }
echo "$row"
v=$(printf '%s\n' "$row" | awk '{print $NF}')
case "$v" in
  CURRENT) exit 0 ;;
  UNDETERMINED) exit 2 ;;
  *) exit 1 ;;
esac
