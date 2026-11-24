#!/usr/bin/env bash
# =============================================================================
# PAIRED MUTATION PROOF for _tests/tests/horizontal-overflow.spec.js (§1.1).
#
# Copies the real vasic.digital tree into a scratch directory and seeds ONE fault
# per mutation, as CSS DATA appended to the copied stylesheet (the spec itself is
# never edited). Each mutation must make the spec FAIL; the CONTROL (M0, the tree
# unmutated) must PASS, otherwise "every mutation was caught" is satisfied by a
# spec that fails unconditionally.
#
#   M0 control   unmutated tree                          spec must PASS
#   M1           the D2 fix reverted                     spec must FAIL
#                (overflow-wrap back to normal on the section title)
#   M2           a 200vw block injected into <main>      spec must FAIL
#   M3           hero clipping removed (aurora spills)   spec must FAIL
#
# Needs a tree that already carries the fix. VD_ROOT selects it (default: the
# umbrella's vasic.digital submodule).
#   exit 0  control green and every mutation caught
#   exit 1  a mutation slipped through, or the control failed
#   exit 2  the proof could not run (no node/playwright/python3, no tree)
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VD_ROOT="${VD_ROOT:-$HERE/../vasic.digital}"
CSS=assets/od/vasic-digital.css

command -v node >/dev/null 2>&1 || { echo "UNDETERMINED: node is not on PATH"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "UNDETERMINED: python3 is not on PATH"; exit 2; }
[[ -d "$HERE/node_modules/@playwright/test" ]] || { echo "UNDETERMINED: _tests/node_modules absent - run: (cd _tests && npm ci)"; exit 2; }
[[ -f "$VD_ROOT/$CSS" ]] || { echo "UNDETERMINED: $VD_ROOT/$CSS not found (submodule not initialised?)"; exit 2; }
grep -q 'overflow-wrap: break-word' "$VD_ROOT/$CSS" || { echo "UNDETERMINED: tree under test does not carry the D2 fix"; exit 2; }

T="$(mktemp -d)"; SRVPID=""
trap '[[ -n "$SRVPID" ]] && kill "$SRVPID" 2>/dev/null; rm -rf "$T"' EXIT
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')"
cat >"$T/cfg.js" <<CFG
module.exports = { testDir: '$HERE/tests', timeout: 60000, workers: 4, reporter: 'line',
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }] };
CFG

PASS=0; FAIL=0
run_spec() {  # $1 label  $2 expected (pass|fail)
  rm -rf "$T/site"; mkdir "$T/site"
  tar -C "$VD_ROOT" --exclude=.git -cf - . | tar -C "$T/site" -xf -
  case "$1" in
    M0) ;;
    M1) python3 - "$T/site/$CSS" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
assert s.count('overflow-wrap: break-word;')>=1; open(p,'w').write(s.replace('overflow-wrap: break-word;','overflow-wrap: normal;',1))
PY
        ;;
    M2) printf '\nmain::after{content:"";display:block;width:200vw;height:1px}\n' >>"$T/site/$CSS" ;;
    M3) printf '\n.vd-hero,.vd-hero__fx{overflow:visible!important}\n' >>"$T/site/$CSS" ;;
  esac
  python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$T/site" >/dev/null 2>&1 & SRVPID=$!
  sleep 1
  ( cd "$HERE" && VD_BASE="http://127.0.0.1:$PORT" npx playwright test --config "$T/cfg.js" horizontal-overflow >"$T/out-$1.txt" 2>&1 ); local rc=$?
  kill "$SRVPID" 2>/dev/null; wait "$SRVPID" 2>/dev/null; SRVPID=""
  local got=pass; [[ $rc -ne 0 ]] && got=fail
  if [[ "$got" == "$2" ]]; then PASS=$((PASS+1)); echo "ok   $1 spec ${got}ed as required (rc=$rc)"
  else FAIL=$((FAIL+1)); echo "FAIL $1 expected spec to $2 but it ${got}ed (rc=$rc)"; tail -15 "$T/out-$1.txt"; fi
}
run_spec M0 pass
run_spec M1 fail
run_spec M2 fail
run_spec M3 fail
echo "horizontal-overflow proof: $PASS ok, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
