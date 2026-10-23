#!/usr/bin/env bash
# scripts/zero-gap-seal-checks.sh — runs every registered check THROUGH the sealing adapter (feature 010, T065 second
# half / VSC-379, FR-016).
#
# The sweep class `unsealed-evidence` credits a registered check as sealed only when a runner file carries a
# `zero-gap-evidence.sh record` call with the LITERAL `--check-id <id>` on the same line. The table between the
# GENERATED markers below is that literal set: one line per `check` row of scripts/check-registry.tsv, minus the
# checks in docs/zero-gap/check-denylist.tsv (heavy, networked or argument-requiring checks, each still owed a
# bespoke bounded run -- a denylisted check is NOT sealed by this runner and stays a finding of the class).
# `--regenerate` rewrites the table from the registry and the denylist; `--check-sync` fails when the table and the
# registry disagree in either direction (a new check with no line, a line for a removed check).
#
# Each line runs the check's own entry point bare (as the determinism census does) under `timeout`/`nice`, through
#   scripts/zero-gap-evidence.sh record ... --verdict-exit
# so the record carries timestamp, argv, state fingerprints, stream digests and the chain seal, and the outcome is the
# check's own exit status (0 holds, 1 violated, anything else 2). The adapter holds the store lock while a check runs, so
# this runner must NOT be invoked from inside another record (zero-gap-daily.sh runs it as a `raw:` step).
#
# USAGE  zero-gap-seal-checks.sh run [--only ID]... [--timeout SEC] [--root DIR]
#        zero-gap-seal-checks.sh --regenerate | --check-sync | --prove-failure
# EXIT   run: 0 every selected check recorded outcome 0; 1 some outcome 1 (outranks 2); 2 some record could not be
#        sealed or a check could not run. --check-sync: 0 in sync, 1 drift, 2 cannot determine.
# Writes: the evidence store only (untracked, .remember/logs/zero-gap/evidence).
set -uo pipefail
export LC_ALL=C LANG=C
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SELF="$HERE/$(basename -- "${BASH_SOURCE[0]}")"
MODE="" TMO=120 ONLY=()
while [ $# -gt 0 ]; do
    case "$1" in
        run|--regenerate|--check-sync|--prove-failure) MODE=$1; shift ;;
        --only) ONLY+=("${2:-}"); shift 2 ;;
        --timeout) TMO=${2:-}; shift 2 ;;
        --root) ROOT=${2:-}; shift 2 ;;
        *) echo "zero-gap-seal-checks: unknown argument '$1'" >&2; exit 2 ;;
    esac
done
STORE=${ZG_STORE_DIR:-$ROOT/.remember/logs/zero-gap/evidence}
FPA=$ROOT/.remember/logs/zero-gap/fp
SESSION=${ZG_SESSION_ID:-seal-checks-$$}

wanted() { # id -> 0 when selected
    [ "${#ONLY[@]}" -eq 0 ] && return 0
    case " ${ONLY[*]} " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}
WORST=0
note_rc() { # id rc
    case "$2" in 0) ;; 1) WORST=1 ;; *) [ "$WORST" -eq 1 ] || WORST=2 ;; esac
    printf 'SEALED %s outcome-rc=%s\n' "$1" "$2"
}
prepare() {
    [ -f "$ROOT/scripts/zero-gap-evidence.sh" ] || { echo "zero-gap-seal-checks: adapter absent"; return 2; }
    if [ ! -d "$FPA/.git" ]; then
        mkdir -p "$FPA" && ( cd "$FPA" && git init -q && echo anchor >README && git add -- README && git -c user.email=seal@localhost -c user.name=seal commit -q -m anchor ) >/dev/null 2>&1 || { echo "cannot create $FPA"; return 2; }
    fi
}

# registry -> "id<TAB>entry" minus the denylist
selected_checks() { # root
    local denyf="$1/docs/zero-gap/check-denylist.tsv"
    awk -F'\t' -v dn="$denyf" 'BEGIN{while((getline l < dn)>0){ if (l !~ /^#/){split(l,a,"\t"); d[a[1]]=1}}} $1=="check" && !($2 in d){print $2"\t"$3}' "$1/scripts/check-registry.tsv"
}
gen_lines() { # root -> the table lines
    local id entry
    while IFS=$'\t' read -r id entry; do
        printf '%s\n' "wanted $id && { cd \"\$ROOT\" && bash \"\$ROOT/scripts/zero-gap-evidence.sh\" record --store \"\$STORE\" --streams \"\$STORE/streams\" --fp-dir \"\$FPA\" --item-id SWEEP --check-id $id --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session \"\$SESSION\" -- timeout -k 5 \"\$TMO\" nice bash $entry; note_rc $id \$?; }"
    done < <(selected_checks "$1")
}
BEGIN_MARK='# >>> GENERATED seal table (scripts/zero-gap-seal-checks.sh --regenerate); do not edit by hand'
END_MARK='# <<< GENERATED seal table'

table_ids() { sed -n "/^$(printf '%s' "$BEGIN_MARK" | sed 's/[][\.*^$/]/\\&/g')/,/^$END_MARK/p" "$1" | sed -n 's/^wanted \([^ ]*\) &&.*/\1/p'; }

regenerate() {
    local tmp; tmp=$(mktemp) || return 2
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v gen="$(gen_lines "$ROOT")" '
        $0==b {print; print gen; skip=1; next}
        $0==e {skip=0}
        !skip {print}' "$SELF" >"$tmp" || { rm -f "$tmp"; return 2; }
    cat "$tmp" >"$SELF"; rm -f "$tmp"; echo "regenerated: $(table_ids "$SELF" | wc -l) line(s)"
}

check_sync() {
    local want have rc=0
    want=$(selected_checks "$ROOT" | cut -f1 | LC_ALL=C sort); have=$(table_ids "$SELF" | LC_ALL=C sort)
    [ -n "$want" ] || { echo "COULD-NOT-DETERMINE the registry yields no check"; return 2; }
    local missing extra
    missing=$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$have")); extra=$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$have"))
    [ -z "$missing" ] || { printf 'FINDING a registered, non-denylisted check has no sealing line: %s\n' "$(echo $missing)"; rc=1; }
    [ -z "$extra" ] || { printf 'FINDING a sealing line names a check that is no longer registered/selected: %s\n' "$(echo $extra)"; rc=1; }
    [ "$rc" -ne 0 ] || echo "in sync: $(printf '%s\n' "$want" | wc -l) check(s)"
    return $rc
}

prove_failure() {
    local T fails=0 o rc; T=$(mktemp -d) || return 2; trap 'rm -rf "$T"' RETURN
    mkdir -p "$T/r/scripts" "$T/r/docs/zero-gap"
    printf 'check\talpha\tscripts/alpha.sh\tflag\tx\ty\ncheck\tbeta\tscripts/beta.sh\tflag\tx\ty\ncheck\tgamma\tscripts/gamma.sh\tflag\tx\ty\n' >"$T/r/scripts/check-registry.tsv"
    printf '# d\ngamma\theavy\n' >"$T/r/docs/zero-gap/check-denylist.tsv"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$T/r/scripts/alpha.sh"; printf '#!/usr/bin/env bash\nexit 1\n' >"$T/r/scripts/beta.sh"
    cp "$SELF" "$T/r/scripts/zero-gap-seal-checks.sh"
    # stub adapter: runs the command, logs "<check-id> rc"
    cat >"$T/r/scripts/zero-gap-evidence.sh" <<'EOF'
#!/usr/bin/env bash
cid=""; while [ $# -gt 0 ]; do case "$1" in --check-id) cid=$2; shift 2 ;; --) shift; break ;; *) shift ;; esac; done
"$@"; rc=$?; echo "$cid $rc" >>"$(dirname "$0")/../sealed.log"; exit "$rc"
EOF
    ( cd "$T/r" && git init -q )
    local S="$T/r/scripts/zero-gap-seal-checks.sh"
    bash "$S" --root "$T/r" --check-sync >"$T/o" 2>&1; rc=$?
    if [ "$rc" -eq 1 ] && grep -q 'no sealing line: alpha beta' "$T/o"; then echo "  ok   M1 a registered check with no sealing line is drift (rc 1)"; else echo "  FAIL M1 rc=$rc: $(cat "$T/o")"; fails=$((fails+1)); fi
    bash "$S" --root "$T/r" --regenerate >/dev/null 2>&1
    bash "$S" --root "$T/r" --check-sync >"$T/o" 2>&1; rc=$?
    if [ "$rc" -eq 0 ] && grep -q 'in sync: 2' "$T/o"; then echo "  ok   C1 after --regenerate the table is in sync and omits the denylisted check"; else echo "  FAIL C1 rc=$rc: $(cat "$T/o")"; fails=$((fails+1)); fi
    bash "$S" --root "$T/r" run --timeout 10 >"$T/o" 2>&1; rc=$?
    if [ "$rc" -eq 1 ] && grep -qx 'alpha 0' "$T/r/sealed.log" && grep -qx 'beta 1' "$T/r/sealed.log" && ! grep -q gamma "$T/r/sealed.log"; then echo "  ok   M2 every selected check is sealed with its own outcome (alpha 0, beta 1), the failure outranks (rc 1), the denylisted check is not run"; else echo "  FAIL M2 rc=$rc: $(cat "$T/r/sealed.log" 2>&1)"; fails=$((fails+1)); fi
    rm -f "$T/r/sealed.log"
    bash "$S" --root "$T/r" run --only alpha >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ] && [ "$(wc -l <"$T/r/sealed.log")" -eq 1 ]; then echo "  ok   C2 --only seals exactly the named check (rc 0)"; else echo "  FAIL C2 rc=$rc"; fails=$((fails+1)); fi
    printf 'check\tdelta\tscripts/delta.sh\tflag\tx\ty\n' >>"$T/r/scripts/check-registry.tsv"
    bash "$S" --root "$T/r" --check-sync >"$T/o" 2>&1; rc=$?
    if [ "$rc" -eq 1 ] && grep -q 'delta' "$T/o"; then echo "  ok   M3 a newly registered check is drift until regenerated"; else echo "  FAIL M3 rc=$rc"; fails=$((fails+1)); fi
    rm -f "$T/r/scripts/zero-gap-evidence.sh"
    bash "$S" --root "$T/r" run --only alpha >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 2 ]; then echo "  ok   M4 no adapter => rc 2 (nothing is run unsealed)"; else echo "  FAIL M4 rc=$rc"; fails=$((fails+1)); fi
    if [ "$fails" -gt 0 ]; then echo "prove-failure: $fails case(s) failed"; return 1; fi
    echo "prove-failure: all cases passed"; return 0
}

case "$MODE" in
    --prove-failure) prove_failure; exit $? ;;
    --regenerate) regenerate; exit $? ;;
    --check-sync) check_sync; exit $? ;;
    run) ;;
    *) echo "usage: zero-gap-seal-checks.sh run|--regenerate|--check-sync|--prove-failure" >&2; exit 2 ;;
esac
prepare || exit 2
# >>> GENERATED seal table (scripts/zero-gap-seal-checks.sh --regenerate); do not edit by hand
wanted constitution-inheritance && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id constitution-inheritance --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash tests/test_constitution_inheritance.sh; note_rc constitution-inheritance $?; }
wanted governance-cascade && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id governance-cascade --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-governance-cascade.sh; note_rc governance-cascade $?; }
wanted manifest-pins && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id manifest-pins --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-manifest-pins.sh; note_rc manifest-pins $?; }
wanted continuation-sync && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id continuation-sync --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/continuation-check.sh; note_rc continuation-sync $?; }
wanted check-registry && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id check-registry --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-check-registry.sh; note_rc check-registry $?; }
wanted hardcoded-paths && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id hardcoded-paths --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/audit-hardcoded-paths.sh; note_rc hardcoded-paths $?; }
wanted content-boundary && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id content-boundary --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-content-boundary.sh; note_rc content-boundary $?; }
wanted content-boundary-judgement && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id content-boundary-judgement --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-content-boundary-judgement.sh; note_rc content-boundary-judgement $?; }
wanted environment-assumptions && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id environment-assumptions --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/audit-environment-assumptions.sh; note_rc environment-assumptions $?; }
wanted mutation-anchor-rot && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id mutation-anchor-rot --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-mutation-anchors.sh; note_rc mutation-anchor-rot $?; }
wanted private-object-exposure && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id private-object-exposure --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-private-object-exposure.sh; note_rc private-object-exposure $?; }
wanted remedy-executability && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id remedy-executability --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-remedy-executability.sh; note_rc remedy-executability $?; }
wanted name-in-path && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id name-in-path --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-name-in-path.sh; note_rc name-in-path $?; }
wanted docs-chain-sync && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id docs-chain-sync --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-docs-chain.sh; note_rc docs-chain-sync $?; }
wanted zero-findings-sweep && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-findings-sweep --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/audit/zero_findings_sweep.sh; note_rc zero-findings-sweep $?; }
wanted badge-computer && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id badge-computer --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/badges/compute_badges.sh; note_rc badge-computer $?; }
wanted directive-register && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id directive-register --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-directive-register.sh; note_rc directive-register $?; }
wanted claim-ledger && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id claim-ledger --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-claim-ledger.sh; note_rc claim-ledger $?; }
wanted workable-items && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id workable-items --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-workable-items.sh; note_rc workable-items $?; }
wanted hardcoded-content && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id hardcoded-content --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash _tools/audit-hardcoding.sh; note_rc hardcoded-content $?; }
wanted translate-reproducibility && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id translate-reproducibility --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash _tools/translate/reproducibility-selftest.sh; note_rc translate-reproducibility $?; }
wanted portfolio-data-integrity && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id portfolio-data-integrity --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash _tools/portfolio/self-validate.sh; note_rc portfolio-data-integrity $?; }
wanted pretooluse-guard && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id pretooluse-guard --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-pretooluse-guard.sh; note_rc pretooluse-guard $?; }
wanted fleet-summary && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id fleet-summary --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/fleet-summary.sh; note_rc fleet-summary $?; }
wanted sc162-requirement-traceability && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id sc162-requirement-traceability --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-sc162-requirement-traceability.sh; note_rc sc162-requirement-traceability $?; }
wanted shell-continuations && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id shell-continuations --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/verify-shell-continuations.sh; note_rc shell-continuations $?; }
wanted zero-gap-sweep && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-sweep --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-sweep.sh; note_rc zero-gap-sweep $?; }
wanted zero-gap-class-unregistered-scripts && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-unregistered-scripts --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-unregistered-scripts.sh; note_rc zero-gap-class-unregistered-scripts $?; }
wanted zero-gap-class-guard-gaps && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-guard-gaps --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-guard-gaps.sh; note_rc zero-gap-class-guard-gaps $?; }
wanted zero-gap-class-untracked-blind-window && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-untracked-blind-window --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-untracked-blind-window.sh; note_rc zero-gap-class-untracked-blind-window $?; }
wanted zero-gap-class-known-open-decisions && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-known-open-decisions --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-known-open-decisions.sh; note_rc zero-gap-class-known-open-decisions $?; }
wanted zero-gap-class-missing-toolchain && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-missing-toolchain --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-missing-toolchain.sh; note_rc zero-gap-class-missing-toolchain $?; }
wanted zero-gap-class-build-if-missing && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-build-if-missing --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-build-if-missing.sh; note_rc zero-gap-class-build-if-missing $?; }
wanted zero-gap-class-vacuous-gates && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-vacuous-gates --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-vacuous-gates.sh; note_rc zero-gap-class-vacuous-gates $?; }
wanted zero-gap-class-improvement-candidates && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-improvement-candidates --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-improvement-candidates.sh; note_rc zero-gap-class-improvement-candidates $?; }
wanted zero-gap-class-coverage-gaps && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-coverage-gaps --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-coverage-gaps.sh; note_rc zero-gap-class-coverage-gaps $?; }
wanted zero-gap-class-stale-figures && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-stale-figures --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-stale-figures.sh; note_rc zero-gap-class-stale-figures $?; }
wanted zero-gap-class-live-vs-source && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-live-vs-source --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-live-vs-source.sh; note_rc zero-gap-class-live-vs-source $?; }
wanted zero-gap-class-unproven-checks && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-unproven-checks --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-unproven-checks.sh; note_rc zero-gap-class-unproven-checks $?; }
wanted zero-gap-class-private-in-public && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-private-in-public --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-private-in-public.sh; note_rc zero-gap-class-private-in-public $?; }
wanted zero-gap-class-unsealed-evidence && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-unsealed-evidence --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-unsealed-evidence.sh; note_rc zero-gap-class-unsealed-evidence $?; }
wanted zero-gap-class-doc-count-drift && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-doc-count-drift --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-doc-count-drift.sh; note_rc zero-gap-class-doc-count-drift $?; }
wanted zero-gap-class-pointer-drift && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-pointer-drift --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-pointer-drift.sh; note_rc zero-gap-class-pointer-drift $?; }
wanted zero-gap-class-content-boundary-rows && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-content-boundary-rows --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-content-boundary-rows.sh; note_rc zero-gap-class-content-boundary-rows $?; }
wanted zero-gap-determinism && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-determinism --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-determinism.sh; note_rc zero-gap-determinism $?; }
wanted zero-gap-coverage && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-coverage --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-coverage.sh; note_rc zero-gap-coverage $?; }
wanted zero-gap-determinism-modules && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-determinism-modules --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-determinism-modules.sh; note_rc zero-gap-determinism-modules $?; }
wanted zero-gap-qa-readiness && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-qa-readiness --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-qa-readiness.sh; note_rc zero-gap-qa-readiness $?; }
wanted zero-gap-guard-checks && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-guard-checks --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-guard-checks.sh; note_rc zero-gap-guard-checks $?; }
wanted zero-gap-third-party-guard && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-third-party-guard --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-third-party-guard.sh; note_rc zero-gap-third-party-guard $?; }
wanted project-pretooluse-catalogue-guard && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id project-pretooluse-catalogue-guard --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/hooks/guard-project-catalogue.sh; note_rc project-pretooluse-catalogue-guard $?; }
wanted zero-gap-class-credentials-public-tree && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-class-credentials-public-tree --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-class-credentials-public-tree.sh; note_rc zero-gap-class-credentials-public-tree $?; }
wanted zero-gap-scan-records && { cd "$ROOT" && bash "$ROOT/scripts/zero-gap-evidence.sh" record --store "$STORE" --streams "$STORE/streams" --fp-dir "$FPA" --item-id SWEEP --check-id zero-gap-scan-records --population-kind process --verdict-role author --independence-tier instance --evidence-class runtime --verdict-exit --session "$SESSION" -- timeout -k 5 "$TMO" nice bash scripts/zero-gap-scan-records.sh; note_rc zero-gap-scan-records $?; }
# <<< GENERATED seal table
printf 'RUN-DONE worst=%s\n' "$WORST"
exit "$WORST"
