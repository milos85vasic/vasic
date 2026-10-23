#!/usr/bin/env bash
# scripts/zero-gap-module-page-check.sh — automated half of the SC-010 module-page walk-through
# (feature 010, task T037, FR-024).
#
# SC-010: an operator opens ONE page and answers, per module, "what is open, what is closed and how do I
# know" within two minutes. The HUMAN timed read is an operator act and is NOT claimed here. This script
# measures what a machine can: it runs `workable-items-vsc report --by-module` against the register,
# times it, and checks that the page can answer the question:
#   P1 the page is produced (non-empty) within --limit seconds (default 120, the SC-010 bound)
#   P2 every roster module (docs/workable-items/sub-projects.tsv, prefix column) has its own
#      `## <PREFIX> — ` section
#   P3 every module section that lists items carries the `### Open` / `### Classified` / `### Closed`
#      sub-sections it needs, and the header carries the open/classified/closed counts
#   P4 the page states the T068 honesty notice while chain binding is not proven (never silently dropped)
# The register's own problems (report rc 1) are INFORMATION for this check, not a defect of the page:
# they are printed with their count.
# USAGE  zero-gap-module-page-check.sh [--root DIR] [--limit SEC] [--keep FILE]
#        zero-gap-module-page-check.sh --prove-failure
# ENV    ZG_MODPAGE_BIN  a prebuilt workable-items-vsc (else built offline from _tools/workable-items)
# EXIT   0 the page answers the question for every module within the limit; 1 a page defect or too slow;
#        2 could not determine (no toolchain, register unmigrated or unreadable, empty roster).
set -uo pipefail
export LC_ALL=C LANG=C
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT="" LIMIT=120 KEEP="" PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT=${2:-}; shift 2 ;;
        --limit) LIMIT=${2:-}; shift 2 ;;
        --keep) KEEP=${2:-}; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        *) echo "zero-gap-module-page-check: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

check_page() { # page-file root elapsed-ms -> prints findings, returns 0/1/2
    local page=$1 root=$2 ms=$3 roster rc=0 pfx
    roster="$root/docs/workable-items/sub-projects.tsv"
    [ -s "$page" ] || { echo "COULD-NOT-DETERMINE the page is empty"; return 2; }
    [ -f "$roster" ] || { echo "COULD-NOT-DETERMINE roster $roster absent"; return 2; }
    local n=0
    if [ "$ms" -gt $((LIMIT * 1000)) ]; then echo "FINDING P1 generating the page took ${ms} ms, over the ${LIMIT} s limit"; rc=1; fi
    while IFS=$'\t' read -r pfx _; do
        case "$pfx" in ''|'#'*|prefix) continue ;; esac
        n=$((n+1))
        if ! grep -q "^## $pfx — " "$page"; then echo "FINDING P2 roster module $pfx has no section in the page"; rc=1; fi
    done <"$roster"
    [ "$n" -gt 0 ] || { echo "COULD-NOT-DETERMINE the roster names no module"; return 2; }
    grep -qE '^- gap items: [0-9]+ · open [0-9]+ · classified [0-9]+ · closed [0-9]+' "$page" || { echo "FINDING P3 the header lacks the open/classified/closed counts"; rc=1; }
    # a section that lists an item must sit under one of the three sub-sections
    awk '
        /^## / { sec=$0; items=0; sub_=0 }
        /^### (Open|Classified|Closed)/ { sub_=1 }
        /^- \*\*[A-Z]{3}-[0-9]+\*\*|^#### [A-Z]{3}-[0-9]+/ { if (!sub_) { print "FINDING P3 an item is listed outside Open/Classified/Closed in: " sec; bad=1 } }
        END { exit bad }' "$page" || rc=1
    grep -q 'NOT independently proven until T068 chain binding' "$page" || { echo "FINDING P4 the honesty notice about chain binding is missing"; rc=1; }
    printf 'INFO modules=%s page_bytes=%s elapsed_ms=%s\n' "$n" "$(wc -c <"$page")" "$ms"
    return $rc
}

build_bin() { # prints the binary path
    if [ -n "${ZG_MODPAGE_BIN:-}" ]; then echo "$ZG_MODPAGE_BIN"; return 0; fi
    command -v go >/dev/null 2>&1 || return 2
    local out; out=$(mktemp -d) || return 2
    ( cd "$ROOT/_tools/workable-items" && GOFLAGS=-mod=mod GOPROXY=off GOTOOLCHAIN=local go build -o "$out/wivsc" . ) >"$out/build.log" 2>&1 || { cat "$out/build.log" >&2; return 2; }
    echo "$out/wivsc"
}

run_check() {
    [ -d "$ROOT" ] || { echo "COULD-NOT-DETERMINE root absent"; echo "VERDICT UNDETERMINED (rc 2)"; return 2; }
    local bin page t0 t1 rrc rc
    bin=$(build_bin) || { echo "COULD-NOT-DETERMINE cannot build workable-items-vsc"; echo "VERDICT UNDETERMINED (rc 2)"; return 2; }
    page=$(mktemp); t0=$(date +%s%N)
    "$bin" report --by-module --repo "$ROOT" >"$page" 2>"$page.err"; rrc=$?
    t1=$(date +%s%N)
    if [ "$rrc" -eq 2 ]; then head -3 "$page.err"; echo "COULD-NOT-DETERMINE the report exited 2 (no page)"; echo "VERDICT UNDETERMINED (rc 2)"; rm -f "$page" "$page.err"; return 2; fi
    echo "INFO report exit=$rrc (0 = register clean, 1 = the register has problems; the page is produced either way) $(grep -m1 'register problems' "$page" || true)"
    check_page "$page" "$ROOT" $(( (t1 - t0) / 1000000 )); rc=$?
    [ -z "$KEEP" ] || cp "$page" "$KEEP"
    rm -f "$page" "$page.err"
    case $rc in 0) echo "VERDICT HOLDS (rc 0): the page answers open/closed/how-do-I-know for every roster module within ${LIMIT}s (the human timed read is NOT claimed)";;
                1) echo "VERDICT VIOLATED (rc 1)";; *) echo "VERDICT UNDETERMINED (rc 2)";; esac
    return $rc
}

prove_failure() {
    local T fails=0 o rc; T=$(mktemp -d) || return 2; trap 'rm -rf "$T"' RETURN
    mkdir -p "$T/docs/workable-items"
    printf 'prefix\tpath\tclass\tratified\tnote\nAAA\ta\towned\toperator\tx\nBBB\tb\towned\toperator\ty\n' >"$T/docs/workable-items/sub-projects.tsv"
    local good="$T/good.md"
    cat >"$good" <<'EOP'
# Zero-gap register — per-module page
- gap items: 2 · open 1 · classified 0 · closed 1 · unknown disposition 0
- closed = structurally consistent + self-recorded digests; NOT independently proven until T068 chain binding
## AAA — `a` (owned)
### Open (1)
- **AAA-001** x
### Closed (1)
- **AAA-002** y
## BBB — `b` (owned)
EOP
    asrt() { # name want file ms
        o=$(check_page "$3" "$T" "$4"); rc=$?
        if [ "$rc" -eq "$2" ]; then echo "  ok   $1 (rc $rc)"; else echo "  FAIL $1: rc $rc want $2"; echo "$o" | sed 's/^/    /'; fails=$((fails+1)); fi
    }
    asrt "C0 a page that answers the question for every module holds" 0 "$good" 100
    grep -v '^## BBB' "$good" >"$T/nomod.md"; asrt "M1 a roster module with no section is caught" 1 "$T/nomod.md" 100
    asrt "M2 a page slower than the limit is caught" 1 "$good" 999999999
    grep -v 'NOT independently proven' "$good" >"$T/nonotice.md"; asrt "M3 a dropped honesty notice is caught" 1 "$T/nonotice.md" 100
    grep -v '^- gap items' "$good" >"$T/nocount.md"; asrt "M4 a header without counts is caught" 1 "$T/nocount.md" 100
    sed 's/^### Open (1)//' "$good" >"$T/nosub.md"; asrt "M5 an item outside Open/Classified/Closed is caught" 1 "$T/nosub.md" 100
    : >"$T/empty.md"; asrt "M6 an empty page is rc 2" 2 "$T/empty.md" 100
    rm -f "$T/docs/workable-items/sub-projects.tsv"; asrt "M7 an absent roster is rc 2" 2 "$good" 100
    if [ "$fails" -gt 0 ]; then echo "prove-failure: $fails case(s) failed"; return 1; fi
    echo "prove-failure: all cases passed"; return 0
}

if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi
[ -n "$ROOT" ] || ROOT=$(cd "$HERE/.." && pwd)
ROOT=$(cd "$ROOT" 2>/dev/null && pwd) || { echo "COULD-NOT-DETERMINE root absent"; echo "VERDICT UNDETERMINED (rc 2)"; exit 2; }
run_check
exit $?
