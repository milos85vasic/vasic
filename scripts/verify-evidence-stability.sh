#!/usr/bin/env bash
# verify-evidence-stability.sh — UG-15: an ordinary test run must not rewrite
# TRACKED volatile evidence (_tests/evidence/test-types/perf-budget.json and
# _tests/evidence/homepages/*.png).
#
# What it checks (all by EXECUTING the real modules, no stand-ins):
#   S1  _tests/tools/evidence-paths.cjs, run with EVIDENCE_REFRESH unset, resolves
#       both directories OUTSIDE _tests/evidence/ (the scratch tree);
#   S2  with EVIDENCE_REFRESH=1 it resolves them INSIDE _tests/evidence/;
#   S3  the real perf-budget-rows.cjs global teardown, driven in a copy of the
#       _tests/ tools with a row present and EVIDENCE_REFRESH unset, leaves the
#       tracked perf-budget.json byte-identical, and with =1 rewrites it;
#   S4  no spec under _tests/tests/ composes a path into evidence/homepages or
#       evidence/test-types by any route other than evidence-paths.cjs.
#
# Exit codes (three-valued; 2 is NEVER a pass):
#   0 all checks held   1 a check failed   2 could not determine (root missing,
#   node absent, a required file missing)
# Usage: verify-evidence-stability.sh [--root DIR] | --prove-failure
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PROVE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

check_tree() {
    local root="$1" fails=0 tmp out
    [[ -d "$root/_tests/tools" ]] || { echo "UNDET root '$root' has no _tests/tools"; return 2; }
    command -v node >/dev/null 2>&1 || { echo "UNDET node is not installed"; return 2; }
    for f in tools/evidence-paths.cjs tools/perf-budget-rows.cjs; do
        [[ -f "$root/_tests/$f" ]] || { echo "UNDET missing _tests/$f"; return 2; }
    done
    tmp="$(mktemp -d)" || return 2
    mkdir -p "$tmp/_tests/tools" "$tmp/_tests/evidence/test-types"
    cp "$root/_tests/tools/evidence-paths.cjs" "$root/_tests/tools/perf-budget-rows.cjs" "$tmp/_tests/tools/"
    printf 'SENTINEL\n' > "$tmp/_tests/evidence/test-types/perf-budget.json"
    local T="$tmp/_tests/tools"

    out="$(env -u EVIDENCE_REFRESH node -e "const e=require('$T/evidence-paths.cjs');console.log(e.evidenceDir('homepages'),e.evidenceDir('test-types'))" 2>&1)" || { echo "UNDET node failed: $out"; rm -rf "$tmp"; return 2; }
    if [[ "$out" == *"$tmp/_tests/evidence/"* ]]; then echo "FAIL S1 no-refresh run resolves into tracked evidence/: $out"; fails=1; else echo "PASS S1 no-refresh resolves to scratch: $out"; fi

    out="$(EVIDENCE_REFRESH=1 node -e "const e=require('$T/evidence-paths.cjs');console.log(e.evidenceDir('homepages'),e.evidenceDir('test-types'))" 2>&1)" || { echo "UNDET node failed: $out"; rm -rf "$tmp"; return 2; }
    if [[ "$out" == "$tmp/_tests/evidence/homepages $tmp/_tests/evidence/test-types" ]]; then echo "PASS S2 refresh resolves to tracked evidence/"; else echo "FAIL S2 refresh did not resolve into evidence/: $out"; fails=1; fi

    drive='const m=require(process.argv[1]);const td=m();m.writeRow({site:"s",path:"/",browser:"chromium",transferredBytes:1,requests:1,unsizedRequests:0});td();'
    env -u EVIDENCE_REFRESH node -e "$drive" "$T/perf-budget-rows.cjs" 2>&1 || { echo "UNDET teardown (no refresh) crashed"; rm -rf "$tmp"; return 2; }
    if [[ "$(cat "$tmp/_tests/evidence/test-types/perf-budget.json")" == "SENTINEL" ]]; then echo "PASS S3a teardown without EVIDENCE_REFRESH left tracked perf-budget.json untouched"; else echo "FAIL S3a teardown without EVIDENCE_REFRESH rewrote tracked perf-budget.json"; fails=1; fi
    EVIDENCE_REFRESH=1 node -e "$drive" "$T/perf-budget-rows.cjs" 2>&1 || { echo "UNDET teardown (refresh) crashed"; rm -rf "$tmp"; return 2; }
    if grep -q '"transferredBytes": 1' "$tmp/_tests/evidence/test-types/perf-budget.json"; then echo "PASS S3b teardown with EVIDENCE_REFRESH=1 rewrote perf-budget.json"; else echo "FAIL S3b refresh did not rewrite perf-budget.json (a refresh path that cannot refresh is dead)"; fails=1; fi
    rm -rf "$tmp"

    local bad
    bad="$(grep -nE "evidence['\"/, ]+(\\.\\./)?['\"]?(homepages|test-types)|'evidence'" "$root"/_tests/tests/*.js 2>/dev/null | grep -v 'evidence-paths' | grep -E "join|writeFile|screenshot" )"
    if [[ -n "$bad" ]]; then echo "FAIL S4 a spec composes a tracked-evidence path itself:"; echo "$bad"; fails=1; else echo "PASS S4 no spec composes a tracked-evidence path outside evidence-paths.cjs"; fi
    [[ $fails -eq 0 ]] && return 0 || return 1
}

if [[ $PROVE -eq 1 ]]; then
    pf=0
    W="$(mktemp -d)" || exit 2
    mk() { rm -rf "$W/t"; mkdir -p "$W/t/_tests/tools" "$W/t/_tests/tests" "$W/t/_tests/evidence/test-types"; cp "$ROOT"/_tests/tools/evidence-paths.cjs "$ROOT"/_tests/tools/perf-budget-rows.cjs "$W/t/_tests/tools/"; : > "$W/t/_tests/tests/a.spec.js"; }
    mk; check_tree "$W/t" >/dev/null 2>&1; rc=$?
    [[ $rc -eq 0 ]] && echo "PASS control: unmutated copy exits 0" || { echo "PROOF FAIL control rc=$rc"; pf=1; }
    mk; sed -i.bak "s/refreshRequested(env) ? TRACKED : SCRATCH/TRACKED/" "$W/t/_tests/tools/evidence-paths.cjs" && rm -f "$W/t/_tests/tools/evidence-paths.cjs.bak"; check_tree "$W/t" >/dev/null 2>&1; rc=$?
    [[ $rc -eq 1 ]] && echo "PASS M1 always-tracked resolver caught (rc 1)" || { echo "PROOF FAIL M1 rc=$rc"; pf=1; }
    mk; sed -i.bak "s/refreshRequested(env) ? TRACKED : SCRATCH/SCRATCH/" "$W/t/_tests/tools/evidence-paths.cjs" && rm -f "$W/t/_tests/tools/evidence-paths.cjs.bak"; check_tree "$W/t" >/dev/null 2>&1; rc=$?
    [[ $rc -eq 1 ]] && echo "PASS M2 never-tracked (dead refresh) caught (rc 1)" || { echo "PROOF FAIL M2 rc=$rc"; pf=1; }
    mk; printf "const p=require('path');const S=p.join(__dirname,'..','evidence','homepages');\n" > "$W/t/_tests/tests/a.spec.js"; check_tree "$W/t" >/dev/null 2>&1; rc=$?
    [[ $rc -eq 1 ]] && echo "PASS M3 spec composing tracked path caught (rc 1)" || { echo "PROOF FAIL M3 rc=$rc"; pf=1; }
    mk; rm "$W/t/_tests/tools/perf-budget-rows.cjs"; check_tree "$W/t" >/dev/null 2>&1; rc=$?
    [[ $rc -eq 2 ]] && echo "PASS M4 missing module is rc 2, not a pass" || { echo "PROOF FAIL M4 rc=$rc"; pf=1; }
    check_tree "$W/nonexistent" >/dev/null 2>&1; rc=$?
    [[ $rc -eq 2 ]] && echo "PASS M5 absent root is rc 2" || { echo "PROOF FAIL M5 rc=$rc"; pf=1; }
    rm -rf "$W"
    [[ $pf -eq 0 ]] && { echo "prove-failure: 5 mutations + control all as expected"; exit 0; } || exit 1
fi

check_tree "$ROOT"; rc=$?
case $rc in 0) echo "OK: volatile evidence is refreshed only by EVIDENCE_REFRESH=1";; 1) echo "FAIL: see FAIL lines above";; *) echo "UNDETERMINED (rc 2): not a pass";; esac
exit $rc
