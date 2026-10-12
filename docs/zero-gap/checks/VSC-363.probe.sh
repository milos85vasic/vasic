#!/usr/bin/env bash
# VSC-363 probe: run from the root of the tree under test. Runs the six VSC-363 Go tests (the test
# file is taken from the MAIN checkout through `go test -overlay`, so the tree under test is never
# written to) against the workable-items module of THAT tree. When the tree predates the fix, the two
# symbols the tests need (openRegularHook, closePreBeginHook, errClosedConcurrently) are supplied by an
# overlay stub so the tests COMPILE and fail on behaviour, not on a missing name.
# Exit: 0 all six pass; 1 a case fails; 2 cannot determine (no module, fewer than six tests ran).
set -u
MAIN=$(cd "$(git rev-parse --git-common-dir)/.." && pwd) || exit 2
MOD=_tools/workable-items
TESTSRC="$MAIN/$MOD/internal/wi/gap_vsc363_test.go"
[ -f "$TESTSRC" ] || { echo "test file absent: $TESTSRC"; exit 2; }
[ -d "$MOD/internal/wi" ] || { echo "module absent in this tree"; exit 2; }
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
TREE=$(pwd)
{
  printf '{"Replace":{"%s/%s/internal/wi/gap_vsc363_test.go":"%s"' "$TREE" "$MOD" "$TESTSRC"
  if ! grep -rqs 'openRegularHook' "$MOD/internal/wi" --include=validate_gap.go; then
    cat >"$T/stub.go" <<'S'
package wi

var openRegularHook func(string)
S
    printf ',"%s/%s/internal/wi/zz_vsc363_stub1.go":"%s"' "$TREE" "$MOD" "$T/stub.go"
  fi
  if ! grep -qs 'closePreBeginHook' "$MOD/internal/wi/gapcmd.go"; then
    cat >"$T/stub2.go" <<'S'
package wi

import "errors"

var closePreBeginHook func()
var errClosedConcurrently = errors.New("closed concurrently")
S
    printf ',"%s/%s/internal/wi/zz_vsc363_stub2.go":"%s"' "$TREE" "$MOD" "$T/stub2.go"
  fi
  printf '}}'
} >"$T/overlay.json"
cd "$MOD" || exit 2
GOFLAGS=-mod=readonly GOPROXY=off GOTOOLCHAIN=local go test -count=1 -v -overlay "$T/overlay.json" -run 'VSC363' ./internal/wi/ >"$T/out.txt" 2>&1
rc=$?
ran=$(grep -cE '^--- (PASS|FAIL)' "$T/out.txt")
failed=$(grep -cE '^--- FAIL' "$T/out.txt")
echo "tests ran=$ran failed=$failed (go test rc=$rc)"
grep -E '^--- FAIL' "$T/out.txt" | head -8
if [ "$ran" -lt 6 ]; then head -5 "$T/out.txt"; exit 2; fi
[ "$failed" -eq 0 ] && [ "$rc" -eq 0 ]
