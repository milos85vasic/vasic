#!/usr/bin/env bash
# §1.1 paired proof for _tools/watch-deploy.sh's exit-code contract.
#
# WHY THIS EXISTS. The watcher discarded `$?` from every deploy cycle. It could
# loop 240 times against a deploy failing every single time and still exit 0.
# The fix is only worth something if it DETECTS -- so each assertion below drives
# the watcher with a stub deploy that returns a chosen code, and requires the
# watcher's own exit code to carry the right verdict.
#
# MUTATIONS ARE DATA. Every case varies WATCH_DEPLOY_CMD (a stub script) and the
# WATCH_* knobs. The watcher's source is never edited, and this proof asserts
# that: its sha256 is captured before the battery and re-checked after.
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT" || exit 2
WATCHER="_tools/watch-deploy.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BEFORE="$(sha256sum "$WATCHER" | cut -d' ' -f1)"

pass=0; fail=0
# A stub whose exit codes are read from a DATA file, one per line, cycling.
mkstub() { printf '#!/usr/bin/env bash\nn=$(cat "%s/n" 2>/dev/null || echo 0)\nn=$((n+1)); echo "$n" > "%s/n"\nsed -n "${n}p" "%s/codes" | grep -q . || { sed -n "$p" "%s/codes"; exit "$(tail -1 "%s/codes")"; }\nexit "$(sed -n "${n}p" "%s/codes")"\n' "$TMP" "$TMP" "$TMP" "$TMP" "$TMP" "$TMP" > "$TMP/stub.sh"; chmod +x "$TMP/stub.sh"; }

run() { # name  expected_rc  codes...  (codes are the DATA)
  local name="$1" want="$2"; shift 2
  : > "$TMP/n"; printf '%s\n' "$@" > "$TMP/codes"; mkstub
  WATCH_DEPLOY_CMD="$TMP/stub.sh" WATCH_CYCLES="${CYC:-3}" WATCH_SLEEP=0 WATCH_FINAL_SLEEP=0 \
    WATCH_FATAL_LIMIT="${LIM:-3}" bash "$WATCHER" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then echo "  PASS $name (rc=$got)"; pass=$((pass+1))
  else echo "  FAIL $name expected rc $want, got $got"; fail=$((fail+1)); fi
}

echo "watch-deploy verdict proof — mutations are DATA (stub exit codes)"
run "M0 CONTROL: every cycle clean must stay 0"                0  0 0 0
run "M1 a could-not-run cycle is 2, NEVER 0"                   2  0 2 0
run "M2 a failing cycle is 5"                                  5  0 5 0
run "M3 PRECEDENCE: a later clean cycle cannot mask a failure" 5  5 0 0
run "M4 PRECEDENCE: a failure outranks a could-not-determine"  5  2 5 0
run "M5 a clean cycle cannot mask a could-not-determine"       2  2 0 0
LIM=2 run "M6 consecutive failures abort at the limit"         5  5 5 0
CYC=0 run "M7 VACUITY: zero cycles observed nothing -> rc 2"   2  0

AFTER="$(sha256sum "$WATCHER" | cut -d' ' -f1)"
if [ "$BEFORE" != "$AFTER" ]; then echo "  FAIL watcher source CHANGED during the battery — mutations must be data"; fail=$((fail+1));
else echo "  PASS watcher source byte-identical across the battery (${BEFORE:0:12})"; pass=$((pass+1)); fi

echo "$pass passed / $fail failed, 8 mutations"
[ "$fail" -eq 0 ] || exit 1
