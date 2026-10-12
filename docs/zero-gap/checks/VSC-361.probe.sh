#!/usr/bin/env bash
# VSC-361 probe: run from the root of the tree under test. The known-open-decisions class must report
# NO finding located in docs/OPERATOR-DECISIONS-2026-09-07.md (decision #16 was recorded PENDING with
# no execution evidence), and the #16 row must name what superseded/executed it.
# Exit 0 holds / 1 violated / 2 cannot determine.
set -u
export TMPDIR=${TMPDIR:-/tmp}
out=$(bash scripts/zero-gap-class-known-open-decisions.sh --root "$PWD" 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] || ! printf '%s\n' "$out" | grep -q '^INSPECTED [1-9]'; then echo "class could not run (rc $rc)"; exit 2; fi
bad=0
if printf '%s\n' "$out" | grep -E '^(FINDING|COULD-NOT-INSPECT) .*OPERATOR-DECISIONS-2026-09-07\.md' >/dev/null; then
  echo "the class still reports decision #16 of 2026-09-07"; bad=1
fi
row=$(grep -E '^\| 16 \|' docs/OPERATOR-DECISIONS-2026-09-07.md || true)
[ -n "$row" ] || { echo "no #16 row"; exit 2; }
if printf '%s' "$row" | grep -qE '\| PENDING \|$'; then echo "#16 row still ends in a bare PENDING status"; bad=1; fi
[ "$bad" -eq 0 ] && echo "decision #16 of 2026-09-07 is no longer a bare PENDING"
[ "$bad" -eq 0 ]
