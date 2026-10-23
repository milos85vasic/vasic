#!/usr/bin/env bash
# scripts/zero-gap-determinism-registry.sh — five-repeat determinism harness over EVERY registered check
# (feature 010, task T064, FR-015, SC-006).
#
# For each `check` row of scripts/check-registry.tsv it runs the check's entry point N times (default 5)
# on an UNCHANGED frozen real copy of the tree (rsync, never hardlinks: some checks are generators that
# rewrite tracked files) and compares the VERDICTS (exit status). A check whose runs disagree is
# UNSTABLE: it is written to docs/zero-gap/unstable-checks.tsv (cycle-2 intake; the register is frozen at
# cycle 1) and MUST NOT be used as evidence until fixed. Output text is hashed after normalising dates,
# durations, temp paths and pids; a differing hash with an identical verdict is reported as output-varies
# (informational: FR-015 is about verdicts).
#
# STATES per check:
#   STABLE     every run finished and all N exit statuses are equal
#   UNSTABLE   every run finished and the exit statuses differ        -> exit 1
#   TIMEOUT    at least one run exceeded --timeout; not a verdict     -> counts as NOT-RUN
#   NOT-RUN    deliberately not executed bare (heavy or side-effecting); the reason is printed. The
#              denylist is DATA below, each entry with its reason; a denylisted check is still owed a
#              bespoke determinism run and is listed in the output, never silently dropped.
# EXIT 0 every registered check ran N times and is STABLE; 1 at least one UNSTABLE (outranks 2);
#      2 no UNSTABLE but at least one check was NOT-RUN/TIMEOUT or the harness could not run (an
#      incomplete census is not a pass).
#
# USAGE  zero-gap-determinism-registry.sh [--root DIR] [--runs N] [--timeout SEC] [--only ID]... [--out DIR]
#        zero-gap-determinism-registry.sh --prove-failure
set -uo pipefail
export LC_ALL=C LANG=C

HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT="" RUNS=5 TMO=60 OUT="" PROVE=0 REG_REL=scripts/check-registry.tsv
ONLY=()
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT=${2:-}; shift 2 ;;
        --runs) RUNS=${2:-}; shift 2 ;;
        --timeout) TMO=${2:-}; shift 2 ;;
        --only) ONLY+=("${2:-}"); shift 2 ;;
        --out) OUT=${2:-}; shift 2 ;;
        --registry) REG_REL=${2:-}; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        *) echo "zero-gap-determinism-registry: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

# check-id<TAB>reason : not run bare. DATA in docs/zero-gap/check-denylist.tsv (shared with scripts/zero-gap-seal-checks.sh).
# Each reason names why a bare, repeated, copy-local run is unsafe or unbounded; a denylisted check is still owed a bespoke run.
DENY_FILE_REL=docs/zero-gap/check-denylist.tsv

normalise() { # stdin -> stdout, volatile tokens removed
    sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:.]+Z?/<ts>/g; s#/tmp/[A-Za-z0-9._-]+#<tmp>#g; s#/home/[A-Za-z0-9._/-]+#<home>#g; s/\b[0-9]+(\.[0-9]+)? ?(ms|s|sec|seconds)\b/<dur>/g; s/pid[= ][0-9]+/pid=<n>/g; s/\b[0-9a-f]{12,64}\b/<hex>/g'
}

registry_checks() { # reg-file -> "id<TAB>entry" lines
    awk -F'\t' '$1=="check"{print $2"\t"$3}' "$1"
}

run_census() { # $1 root(copy) $2 out dir
    local root=$1 out=$2 reg="$1/$REG_REL" id entry reason i rcs hashes rc nrun state tmo_hit
    mkdir -p "$out"
    [ -f "$reg" ] || { echo "zero-gap-determinism-registry: registry $reg absent"; return 2; }
    local tsv="$out/determinism-registry.tsv" uns="$out/unstable-checks.tsv"
    printf '# determinism census (T064): id\tstate\truns\tverdicts\tdistinct_outputs\tnote\n' >"$tsv"
    printf '# UNSTABLE checks (T064): excluded from evidence until fixed; cycle-2 intake. id\tverdicts\tentry\n' >"$uns"
    local n_stable=0 n_unstable=0 n_notrun=0 total=0
    while IFS=$'\t' read -r id entry; do
        [ -n "$id" ] || continue
        if [ "${#ONLY[@]}" -gt 0 ]; then case " ${ONLY[*]} " in *" $id "*) ;; *) continue ;; esac; fi
        total=$((total+1))
        reason=$(awk -F'\t' -v k="$id" '!/^#/ && $1==k{print $2}' "$root/$DENY_FILE_REL" 2>/dev/null)
        if [ -n "${ZG_DET_DENY_EXTRA:-}" ]; then
            [ -z "$reason" ] && reason=$(printf '%s' "$ZG_DET_DENY_EXTRA" | tr ',' '\n' | awk -F: -v k="$id" '$1==k{print $2}')
        fi
        if [ -n "$reason" ]; then
            printf '%s\tNOT-RUN\t0\t-\t-\t%s\n' "$id" "$reason" >>"$tsv"; n_notrun=$((n_notrun+1)); continue
        fi
        if [ ! -f "$root/$entry" ]; then
            printf '%s\tNOT-RUN\t0\t-\t-\tentry point %s absent in the copy\n' "$id" "$entry" >>"$tsv"; n_notrun=$((n_notrun+1)); continue
        fi
        rcs=() hashes=() tmo_hit=0
        for i in $(seq 1 "$RUNS"); do
            ( cd "$root" && timeout -k 5 "$TMO" nice bash "$entry" >"$out/.run.txt" 2>&1 ); rc=$?
            if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then tmo_hit=1; break; fi
            rcs+=("$rc"); hashes+=("$(normalise <"$out/.run.txt" | sha256sum | cut -c1-12)")
        done
        if [ "$tmo_hit" -eq 1 ]; then
            printf '%s\tTIMEOUT\t%s\t%s\t-\trun %s exceeded %ss; no verdict (not run to completion)\n' "$id" "${#rcs[@]}" "${rcs[*]:-}" "$((${#rcs[@]}+1))" "$TMO" >>"$tsv"
            n_notrun=$((n_notrun+1)); continue
        fi
        nrun=${#rcs[@]}
        local drc dh; drc=$(printf '%s\n' "${rcs[@]}" | sort -u | wc -l); dh=$(printf '%s\n' "${hashes[@]}" | sort -u | wc -l)
        if [ "$drc" -gt 1 ]; then
            printf '%s\tUNSTABLE\t%s\t%s\t%s\tverdicts differ across identical runs on an unchanged copy\n' "$id" "$nrun" "${rcs[*]}" "$dh" >>"$tsv"
            printf '%s\t%s\t%s\n' "$id" "${rcs[*]}" "$entry" >>"$uns"; n_unstable=$((n_unstable+1))
        else
            state=STABLE; note=""
            [ "$dh" -gt 1 ] && note="output-varies (verdict identical)"
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$state" "$nrun" "${rcs[0]}x$nrun" "$dh" "$note" >>"$tsv"; n_stable=$((n_stable+1))
        fi
    done < <(registry_checks "$reg")
    rm -f "$out/.run.txt"
    printf 'CENSUS checks=%s stable=%s unstable=%s not-run=%s runs=%s timeout=%ss\n' "$total" "$n_stable" "$n_unstable" "$n_notrun" "$RUNS" "$TMO"
    if [ "$total" -eq 0 ]; then echo "VERDICT UNDETERMINED (rc 2): no registered check was selected"; return 2; fi
    if [ "$n_unstable" -gt 0 ]; then echo "VERDICT VIOLATED (rc 1): $n_unstable UNSTABLE check(s); see $uns"; return 1; fi
    if [ "$n_notrun" -gt 0 ]; then echo "VERDICT UNDETERMINED (rc 2): $n_notrun check(s) NOT-RUN/TIMEOUT; the census is incomplete, which is not a pass"; return 2; fi
    echo "VERDICT HOLDS (rc 0): every registered check ran $RUNS times with identical verdicts"; return 0
}

frozen_copy() { # $1 root $2 dest
    local list; list=$(mktemp) || return 2
    git -C "$1" ls-files -z --cached --others --exclude-standard >"$list.raw" 2>/dev/null || { rm -f "$list" "$list.raw"; return 2; }
    : >"$list"
    while IFS= read -r -d '' p; do
        [ -d "$1/$p" ] && [ ! -L "$1/$p" ] && continue
        { [ -e "$1/$p" ] || [ -L "$1/$p" ]; } || continue
        printf '%s\0' "$p" >>"$list"
    done <"$list.raw"
    rsync -a --from0 --files-from="$list" "$1/" "$2/" >/dev/null 2>&1; local rc=$?
    ( cd "$2" && git init -q && git -c user.email=zgdr@localhost -c user.name=zgdr add -f --pathspec-from-file="$list" --pathspec-file-nul && git -c user.email=zgdr@localhost -c user.name=zgdr commit -q -m copy ) >/dev/null 2>&1 || rc=2
    rm -f "$list" "$list.raw"; return "$rc"
}

prove_failure() {
    command -v rsync >/dev/null && command -v git >/dev/null || { echo "prove-failure: rsync/git missing"; return 2; }
    local T fails=0 rc o; T=$(mktemp -d) || return 2; trap 'rm -rf "$T"' RETURN
    local R="$T/r"; mkdir -p "$R/scripts"
    cat >"$R/scripts/stable.sh" <<'EOF'
#!/usr/bin/env bash
echo "stable at $(date +%s)"; exit 0
EOF
    cat >"$R/scripts/flaky.sh" <<'EOF'
#!/usr/bin/env bash
c=$(cat "$(dirname "$0")/.n" 2>/dev/null || echo 0); echo $((c+1)) >"$(dirname "$0")/.n"; [ $((c % 2)) -eq 0 ] && exit 0 || exit 1
EOF
    cat >"$R/scripts/slow.sh" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
    cat >"$R/scripts/heavy.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    printf 'check\tstable\tscripts/stable.sh\tflag\t--prove-failure\tx\ncheck\tflaky\tscripts/flaky.sh\tflag\t--prove-failure\tx\n' >"$R/scripts/check-registry.tsv"
    ( cd "$R" && git init -q && git add -f -- scripts && git -c user.email=t@t -c user.name=t commit -q -m init )
    local base=(bash "$HERE/zero-gap-determinism-registry.sh" --runs 4 --timeout 3)
    o=$(cd "$T" && "${base[@]}" --root "$R" --out "$T/o1" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && grep -q 'flaky.UNSTABLE' "$T/o1/determinism-registry.tsv" && grep -q 'stable.STABLE' "$T/o1/determinism-registry.tsv" && grep -q '^flaky' "$T/o1/unstable-checks.tsv"; then echo "  ok   M1 a check whose verdict alternates is UNSTABLE (rc 1), a constant one STABLE, and the flaky one is queued as intake"; else echo "  FAIL M1 rc=$rc"; echo "$o"|sed 's/^/    /'; fails=$((fails+1)); fi
    # stable only => rc 0
    o=$(cd "$T" && "${base[@]}" --root "$R" --only stable --out "$T/o2" 2>&1); rc=$?
    if [ "$rc" -eq 0 ]; then echo "  ok   C1 a stable-only census holds (rc 0)"; else echo "  FAIL C1 rc=$rc"; fails=$((fails+1)); fi
    # timeout => rc 2, not a pass
    printf 'check\tslow\tscripts/slow.sh\tflag\t--prove-failure\tx\n' >"$R/scripts/check-registry.tsv"; ( cd "$R" && git add -f scripts && git -c user.email=t@t -c user.name=t commit -q -m slow )
    o=$(cd "$T" && "${base[@]}" --root "$R" --out "$T/o3" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q 'slow.TIMEOUT' "$T/o3/determinism-registry.tsv"; then echo "  ok   M2 a check that never finishes is TIMEOUT and the census is rc 2 (never a pass)"; else echo "  FAIL M2 rc=$rc"; fails=$((fails+1)); fi
    # denylisted => NOT-RUN with a reason, rc 2
    printf 'check\theavy\tscripts/heavy.sh\tflag\t--prove-failure\tx\n' >"$R/scripts/check-registry.tsv"; ( cd "$R" && git add -f scripts && git -c user.email=t@t -c user.name=t commit -q -m heavy )
    o=$(cd "$T" && ZG_DET_DENY_EXTRA="heavy:needs a bespoke run" "${base[@]}" --root "$R" --out "$T/o4" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q 'heavy.NOT-RUN.*needs a bespoke run' "$T/o4/determinism-registry.tsv"; then echo "  ok   M3 a denylisted check is listed NOT-RUN with its reason, rc 2"; else echo "  FAIL M3 rc=$rc"; fails=$((fails+1)); fi
    # empty selection => rc 2
    o=$(cd "$T" && "${base[@]}" --root "$R" --only nothing --out "$T/o5" 2>&1); rc=$?
    if [ "$rc" -eq 2 ]; then echo "  ok   M4 an empty selection is rc 2"; else echo "  FAIL M4 rc=$rc"; fails=$((fails+1)); fi
    # absent registry => rc 2
    o=$(cd "$T" && "${base[@]}" --root "$T/none" --out "$T/o6" 2>&1); rc=$?
    if [ "$rc" -eq 2 ]; then echo "  ok   M5 an absent root is rc 2"; else echo "  FAIL M5 rc=$rc"; fails=$((fails+1)); fi
    if [ "$fails" -gt 0 ]; then echo "prove-failure: $fails case(s) failed"; return 1; fi
    echo "prove-failure: all cases passed"; return 0
}

if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi
[ -n "$ROOT" ] || ROOT=$(cd "$HERE/.." && pwd)
[ -d "$ROOT" ] || { echo "zero-gap-determinism-registry: root absent"; echo "VERDICT UNDETERMINED (rc 2)"; exit 2; }
ROOT=$(cd "$ROOT" && pwd)
OUT=${OUT:-$ROOT/docs/zero-gap}
COPY=$(mktemp -d "${TMPDIR:-/tmp}/zgdr.XXXXXX") || exit 2
trap 'rm -rf "$COPY"' EXIT
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "root is not a git work tree"; echo "VERDICT UNDETERMINED (rc 2)"; exit 2; fi
# run on a frozen real copy; results are written to --out (default: the live docs/zero-gap, the only tracked write)
frozen_copy "$ROOT" "$COPY" || { echo "cannot make the frozen copy"; echo "VERDICT UNDETERMINED (rc 2)"; exit 2; }
run_census "$COPY" "$OUT"
exit $?
