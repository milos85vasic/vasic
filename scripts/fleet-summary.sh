#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# fleet-summary.sh — the two-number statement about this repository's own
# governance fleet, NEVER merged into one.
#
# WHY THIS EXISTS (T109, was 005/T031)
# -------------------------------------
# specs/008-unified-workshop-platform/tasks.md FR-009 (unified FR-251) and
# SC-008 (unified SC-132) require the fleet's state to be reported as TWO
# numbers: the count of UNEXPLAINED reds ("defect") and the count of reds
# that are a DECLARED, evidenced, still-valid condition ("declared"). No
# instrument merged these into one number before this file existed — every
# gate in scripts/check-registry.tsv reports its OWN verdict, and nothing
# aggregated them. SC-008 wants "unexplained reds reaches 0, from a baseline
# of 11" to become a computable claim; this script is what makes it
# computable, by actually RUNNING the registered `check` rows and classifying
# every non-zero result against docs/findings/declared-reds.tsv.
#
# WHAT COUNTS AS A "CHECK" HERE
# ------------------------------
# Only `check` rows from scripts/check-registry.tsv — the rows already
# verified (by scripts/verify-check-registry.sh) to carry a paired §1.1 proof
# and a real three-valued exit. `exempt` and `debt` rows are NOT run here:
# they describe whether a SCRIPT is registered as a check at all, not whether
# a registered check's live invocation currently exits non-zero — a `debt`
# row is already a declared, counted non-conformance by construction (see
# scripts/verify-check-registry.sh's own R4), so folding it into this
# script's numbers would double-count exactly the distinction FR-009 exists
# to keep apart.
#
# HOW A CHECK IS INVOKED
# -----------------------
# Bare: `bash <entry-point>` with no extra arguments — the same invocation
# scripts/pre-push-gates.sh uses for the gates it runs (see its GATE_CMDS
# table). This is "how the check is normally run", not the paired-proof
# invocation (`--prove-failure`) and not the rc-2 probe invocation
# (`--root /nonexistent` etc) — those two are what
# scripts/verify-check-registry.sh already verifies exist and behave
# correctly; this script asks the THIRD, previously-unasked question: what
# does the check say about THIS TREE, RIGHT NOW?
#
# CLASSIFICATION
#   rc 0    CLEAN
#   rc 2    COULD-NOT-DETERMINE (the check's own three-valued contract)
#   timeout COULD-NOT-DETERMINE (bounded by --timeout, default 120s; a check
#           that cannot finish in the budget cannot be classified defect or
#           declared without guessing, and guessing is forbidden — §11.4.6)
#   other   RED — looked up by id in docs/findings/declared-reds.tsv:
#             present AND next_review >= today  -> DECLARED
#             absent, OR next_review has elapsed -> DEFECT
#           An EXPIRED declaration is treated exactly like no declaration:
#           this is deliberate (see the ledger's own header) and is what lets
#           T116's cadence discipline and this script's numbers reinforce
#           each other instead of drifting apart.
#
# THE HEADLINE, STATED THE WAY FR-009 REQUIRES
# ----------------------------------------------
#   "N unexplained red(s) (defect), M declared-condition red(s), of R total
#   reds; C clean; U could-not-determine; T checks run"
# N and M are NEVER added together and NEVER printed as one combined figure.
#
# EXIT CODE — three-valued, like every other instrument in this fleet
#   0  zero unexplained reds AND zero could-not-determine results
#   1  at least one unexplained red (a real, nameable defect)
#   2  zero unexplained reds, but at least one check could not be run to a
#      verdict — this is NOT a pass; SC-008's "reaches 0" is not yet PROVEN
#
# USAGE
#   scripts/fleet-summary.sh                 default 120s per-check timeout
#   scripts/fleet-summary.sh --timeout N     override the per-check timeout
#   scripts/fleet-summary.sh --only id,id    run only these check ids (fast
#                                             iteration / CI budget control)
#   scripts/fleet-summary.sh --list          print the parsed fleet, run
#                                             nothing
#   scripts/fleet-summary.sh --root DIR      summarise another checkout
#   scripts/fleet-summary.sh --quiet         suppress per-check lines
#   scripts/fleet-summary.sh --prove-failure its own §1.1 paired proof
#
# HONEST BOUNDARY (§11.4.6)
# ---------------------------
# This is a LIVE-RUN instrument, not a cache reader. No existing capture
# mechanism in this tree stores a structured, machine-readable "last verdict"
# per registered check (docs/qa/ holds end-user evidence for shipped
# features, not gate exit codes; CONTINUATION.md and CLAUDE.md hold prose).
# So there is nothing to read INSTEAD of running — every run of this script
# is a fresh measurement, and it can be SLOW: several registered checks scan
# the whole 14-repository fleet. The --timeout bound exists because of that,
# and a timeout is reported as COULD-NOT-DETERMINE, never silently dropped
# and never folded into either headline number.
# ------------------------------------------------------------------------------
set -uo pipefail

SELF_NAME="$(basename -- "${BASH_SOURCE[0]}")"
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || {
    echo "FATAL: cannot resolve script directory" >&2; exit 2; }

ROOT=""
TIMEOUT="${FLEET_SUMMARY_TIMEOUT:-120}"
ONLY=""
LIST=0
QUIET=0
PROVE=0

usage() {
    sed -n '/^# USAGE/,/^# HONEST BOUNDARY/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | sed '$d'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)          shift; ROOT="${1:-}" ;;
        --timeout)       shift; TIMEOUT="${1:-120}" ;;
        --only)          shift; ONLY="${1:-}" ;;
        --list)          LIST=1 ;;
        --quiet)         QUIET=1 ;;
        --prove-failure) PROVE=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "$SELF_NAME: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ -n "$ROOT" ]]; then
    ROOT="$(cd -- "$ROOT" 2>/dev/null && pwd)" || {
        echo "UNDET  target root does not exist: it cannot be inspected, so this is neither a pass nor a fail" >&2
        exit 2; }
else
    ROOT="$(cd -- "$SELF_DIR/.." && pwd)" || {
        echo "FATAL: cannot derive repository root" >&2; exit 2; }
fi

REGISTRY="$ROOT/scripts/check-registry.tsv"
LEDGER="$ROOT/docs/findings/declared-reds.tsv"

if [[ -t 1 ]]; then
    R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[0;33m'; B=$'\033[1m'; N=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; N=""
fi

say() { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*"; }

# ──────────────────────────────────────────────────────────────────────────────
# Load `check` rows from the registry — id + entry-point only, nothing else is
# needed for a live-run classification.
# ──────────────────────────────────────────────────────────────────────────────
load_checks() {
    [[ -f "$REGISTRY" ]] || { echo "UNDET: no registry at $REGISTRY" >&2; exit 2; }
    CHK_ID=(); CHK_ENTRY=()
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        [[ -z "${raw//[[:space:]]/}" ]] && continue
        [[ "${raw:0:1}" == "#" ]] && continue
        IFS=$'\t' read -r f1 f2 f3 _rest <<<"$raw"
        [[ "$f1" == "check" ]] || continue
        CHK_ID+=("$f2"); CHK_ENTRY+=("$f3")
    done < "$REGISTRY"
    [[ ${#CHK_ID[@]} -gt 0 ]] || { echo "UNDET: registry declares no check rows" >&2; exit 2; }
}

# ──────────────────────────────────────────────────────────────────────────────
# Load the declared-red ledger — id -> (next_review, evidence-first-line)
# ──────────────────────────────────────────────────────────────────────────────
declare -A LEDGER_NEXTREVIEW=()
declare -A LEDGER_EVIDENCE=()
load_ledger() {
    [[ -f "$LEDGER" ]] || return 0
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        [[ -z "${raw//[[:space:]]/}" ]] && continue
        [[ "${raw:0:1}" == "#" ]] && continue
        IFS=$'\t' read -r lid lauth levidence lnext _rest <<<"$raw"
        [[ -n "${lid:-}" ]] || continue
        LEDGER_NEXTREVIEW["$lid"]="${lnext:-}"
        LEDGER_EVIDENCE["$lid"]="${levidence:-}"
    done < "$LEDGER"
}

TODAY="$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"

classify_red() {
    # $1 = check id -> prints DECLARED, DEFECT, or REOPEN on stdout.
    # REOPEN is a DEFECT for counting purposes (an expired declaration is
    # exactly no declaration, per T116's cadence rule) but is reported
    # distinctly because it is the mechanical half of T114's reopen-ledger
    # wiring: a check that WAS declared (a prior closure exists) and is now
    # red with its cadence elapsed is precisely "a prior closure contradicted
    # by new evidence" — the definition of a reopen. This function does NOT
    # write to the ledger itself (see docs/findings/reopened-reds.jsonl's own
    # header and scripts/record-reopen.sh: a ledger write is a decided event,
    # not a side effect of a routine sweep); it only names the candidate.
    local id="$1" nr="${LEDGER_NEXTREVIEW[$1]:-}"
    if [[ -z "$nr" ]]; then printf 'DEFECT'; return; fi
    if [[ ! "$nr" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then printf 'DEFECT'; return; fi
    if [[ "$nr" < "$TODAY" ]]; then printf 'REOPEN'; return; fi
    printf 'DECLARED'
}

load_checks
load_ledger

if [[ -n "$ONLY" ]]; then
    IFS=',' read -ra WANT <<<"$ONLY"
    NEW_ID=(); NEW_ENTRY=()
    i=0
    while [[ $i -lt ${#CHK_ID[@]} ]]; do
        for w in "${WANT[@]}"; do
            if [[ "${CHK_ID[$i]}" == "$w" ]]; then NEW_ID+=("${CHK_ID[$i]}"); NEW_ENTRY+=("${CHK_ENTRY[$i]}"); fi
        done
        i=$((i+1))
    done
    CHK_ID=("${NEW_ID[@]}"); CHK_ENTRY=("${NEW_ENTRY[@]}")
fi

if [[ $LIST -eq 1 ]]; then
    printf 'checks (%s): %s\n' "${#CHK_ID[@]}" "${CHK_ID[*]}"
    printf 'declared-red ledger rows: %s\n' "${#LEDGER_NEXTREVIEW[@]}"
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF — --prove-failure
# ──────────────────────────────────────────────────────────────────────────────
if [[ $PROVE -eq 1 ]]; then
    printf '%sFLEET-SUMMARY §1.1 PAIRED MUTATION PROOF%s\n' "$B" "$N"
    echo "----------------------------------------------------------------------"
    SELF="$SELF_DIR/$SELF_NAME"
    P_PASS=0; P_FAIL=0
    p_ok()  { P_PASS=$((P_PASS+1)); printf '%s✅ %-28s%s %s\n' "$G" "$1" "$N" "$2"; }
    p_bad() { P_FAIL=$((P_FAIL+1)); printf '%s❌ %-28s%s %s\n' "$R" "$1" "$N" "$2"; }

    SB="$(mktemp -d "${TMPDIR:-/tmp}/fleet-summary-proof.XXXXXX")" || {
        echo "UNDET: cannot create a sandbox; the proof could not run" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM
    mkdir -p "$SB/scripts" "$SB/docs/findings"

    mk_check() {          # mk_check <path> <exit-code>
        printf '#!/usr/bin/env bash\nexit %s\n' "$2" >"$1"
        chmod 755 "$1"
    }
    mk_check "$SB/scripts/green-check.sh" 0
    mk_check "$SB/scripts/red-undeclared.sh" 1
    mk_check "$SB/scripts/red-declared.sh" 1
    mk_check "$SB/scripts/undet-check.sh" 2

    cat >"$SB/scripts/check-registry.tsv" <<EOF
scanroot	scripts
check	green	scripts/green-check.sh	flag	--prove-failure	--root /nonexistent
check	red-undeclared	scripts/red-undeclared.sh	flag	--prove-failure	--root /nonexistent
check	red-declared	scripts/red-declared.sh	flag	--prove-failure	--root /nonexistent
check	undet	scripts/undet-check.sh	flag	--prove-failure	--root /nonexistent
EOF

    write_ledger() {
        cat >"$SB/docs/findings/declared-reds.tsv" <<EOF
red-declared	operator	synthetic declared red for the proof	2099-01-01
EOF
    }
    write_ledger

    run_sb() { timeout 60 bash "$SELF" --root "$SB" "$@" 2>&1; }

    expect() {
        local label="$1" want="$2" needle="$3"; shift 3
        local out rc
        out="$("$@")"; rc=$?
        if [[ $rc -ne $want ]]; then
            p_bad "$label" "expected rc=$want, got rc=$rc"; printf '%s\n' "$out" | tail -6 | sed 's/^/        /'; return
        fi
        if [[ -n "$needle" ]] && ! grep -qF -- "$needle" <<<"$out"; then
            p_bad "$label" "rc=$want as expected, but output never named '$needle'"; printf '%s\n' "$out" | tail -6 | sed 's/^/        /'; return
        fi
        p_ok "$label" "rc=$want${needle:+, and it named '$needle'}"
    }

    # ---- CONTROL: 1 defect, 1 declared, 1 undet, 1 clean ----------------------
    expect "CONTROL mixed-fleet" 1 "1 unexplained" run_sb --quiet
    expect "CONTROL names defect id" 1 "red-undeclared" run_sb
    expect "CONTROL names declared id" 1 "red-declared" run_sb
    expect "CONTROL never merges counts" 1 "1 unexplained" run_sb

    # ---- M1  an all-clean fleet exits 0 ----------------------------------------
    cat >"$SB/scripts/check-registry.tsv" <<EOF
scanroot	scripts
check	green	scripts/green-check.sh	flag	--prove-failure	--root /nonexistent
EOF
    expect "M1 all-clean-exits-0" 0 "" run_sb --quiet

    # ---- M2  an expired declaration reverts to defect --------------------------
    cat >"$SB/scripts/check-registry.tsv" <<EOF
scanroot	scripts
check	red-declared	scripts/red-declared.sh	flag	--prove-failure	--root /nonexistent
EOF
    cat >"$SB/docs/findings/declared-reds.tsv" <<EOF
red-declared	operator	an EXPIRED declaration	2020-01-01
EOF
    expect "M2 expired-declaration-is-defect" 1 "1 unexplained" run_sb --quiet
    write_ledger
    cat >"$SB/scripts/check-registry.tsv" <<EOF
scanroot	scripts
check	green	scripts/green-check.sh	flag	--prove-failure	--root /nonexistent
check	red-undeclared	scripts/red-undeclared.sh	flag	--prove-failure	--root /nonexistent
check	red-declared	scripts/red-declared.sh	flag	--prove-failure	--root /nonexistent
check	undet	scripts/undet-check.sh	flag	--prove-failure	--root /nonexistent
EOF

    # ---- M3  could-not-determine alone -> exit 2, never a pass -----------------
    cat >"$SB/scripts/check-registry.tsv" <<EOF
scanroot	scripts
check	green	scripts/green-check.sh	flag	--prove-failure	--root /nonexistent
check	undet	scripts/undet-check.sh	flag	--prove-failure	--root /nonexistent
EOF
    expect "M3 undet-only-is-rc2-not-pass" 2 "could-not-determine" run_sb --quiet

    # ---- M4  a check that times out is COULD-NOT-DETERMINE, not silently dropped
    mk_check "$SB/scripts/hangs.sh" 0
    cat >"$SB/scripts/hangs.sh" <<'HANG'
#!/usr/bin/env bash
sleep 30
exit 0
HANG
    chmod 755 "$SB/scripts/hangs.sh"
    cat >"$SB/scripts/check-registry.tsv" <<EOF
scanroot	scripts
check	hangs	scripts/hangs.sh	flag	--prove-failure	--root /nonexistent
EOF
    out="$(timeout 20 bash "$SELF" --root "$SB" --timeout 1 --quiet 2>&1)"; rc=$?
    if [[ $rc -eq 2 ]] && grep -qF "hangs" <<<"$out" && grep -qF "could-not-determine" <<<"$out"; then
        p_ok "M4 timeout-is-undet-not-dropped" "rc=2, named 'hangs', and reported as could-not-determine"
    else
        p_bad "M4 timeout-is-undet-not-dropped" "expected rc=2 naming 'hangs' as could-not-determine, got rc=$rc"
        printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
    fi

    # ---- M5  a check that IGNORES SIGTERM still ends up as could-not-determine,
    # not as a red DEFECT. This is a REAL bug this script had and does not
    # anymore: `timeout -k` escalating to SIGKILL was measured on this host
    # (uutils coreutils 0.8.0) to report rc=137, not rc=124, and an earlier
    # version of this script counted that as an unexplained red.
    cat >"$SB/scripts/hangs.sh" <<'HANG'
#!/usr/bin/env bash
trap '' TERM
sleep 30
HANG
    chmod 755 "$SB/scripts/hangs.sh"
    out="$(timeout 30 bash "$SELF" --root "$SB" --timeout 1 --quiet 2>&1)"; rc=$?
    if [[ $rc -eq 2 ]] && grep -qF "hangs" <<<"$out" && grep -qF "could-not-determine" <<<"$out" && ! grep -qF "DEFECT" <<<"$out"; then
        p_ok "M5 sigterm-ignored-still-undet" "rc=2, named 'hangs' as could-not-determine, NOT as DEFECT"
    else
        p_bad "M5 sigterm-ignored-still-undet" "expected rc=2 naming 'hangs' as could-not-determine and NOT as DEFECT, got rc=$rc"
        printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
    fi

    # ---- RESTORED CONTROL ------------------------------------------------------
    write_ledger
    cat >"$SB/scripts/check-registry.tsv" <<EOF
scanroot	scripts
check	green	scripts/green-check.sh	flag	--prove-failure	--root /nonexistent
check	red-undeclared	scripts/red-undeclared.sh	flag	--prove-failure	--root /nonexistent
check	red-declared	scripts/red-declared.sh	flag	--prove-failure	--root /nonexistent
check	undet	scripts/undet-check.sh	flag	--prove-failure	--root /nonexistent
EOF
    expect "CONTROL restored" 1 "1 unexplained" run_sb --quiet

    echo "----------------------------------------------------------------------"
    if [[ $P_FAIL -gt 0 ]]; then
        printf '%s❌ FLEET-SUMMARY §1.1 PROOF: FAIL — %s case(s) did not behave as required.%s\n' "$R" "$P_FAIL" "$N"
        exit 1
    fi
    printf '%s✅ FLEET-SUMMARY §1.1 MUTATION PROOF: PASS%s — %s assertions: a mixed fleet is classified\n' "$G" "$N" "$P_PASS"
    printf '   into defect/declared/clean/undet without merging any of them, an expired\n'
    printf '   declaration reverts to defect, undet-only never reads as a pass, and a hung\n'
    printf '   check is reported as could-not-determine rather than silently dropped.\n'
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# Live run
# ──────────────────────────────────────────────────────────────────────────────
say "${B}FLEET-SUMMARY${N}: running ${#CHK_ID[@]} registered check(s), bare invocation, ${TIMEOUT}s timeout each"
say "  registry $REGISTRY"
say "  ledger   $LEDGER ($([[ -f "$LEDGER" ]] && echo "${#LEDGER_NEXTREVIEW[@]} declared row(s)" || echo "absent"))"
say "  root     $ROOT"
say "----------------------------------------------------------------------"

N_CLEAN=0; N_DEFECT=0; N_DECLARED=0; N_UNDET=0; N_SKIPPED_SELF=0
DEFECT_NAMES=(); DECLARED_NAMES=(); UNDET_NAMES=(); REOPEN_CANDIDATES=()

if ! command -v timeout >/dev/null 2>&1; then
    echo "UNDET: coreutils 'timeout' is unavailable — refusing to run checks unbounded" >&2
    exit 2
fi

i=0
while [[ $i -lt ${#CHK_ID[@]} ]]; do
    id="${CHK_ID[$i]}"; entry="${CHK_ENTRY[$i]}"
    abs="$ROOT/$entry"
    i=$((i+1))

    # This script is itself registered as a `check` row (so
    # scripts/verify-check-registry.sh's structural R-rules apply to it), but
    # a LIVE bare invocation of that row from inside this loop would spawn a
    # nested fleet-summary.sh that iterates the SAME registry — unbounded
    # recursion, not merely a slow re-run. Skip it by basename, not by id, so
    # a future rename does not silently re-enable the recursion.
    if [[ "$(basename -- "$entry")" == "$SELF_NAME" ]]; then
        N_SKIPPED_SELF=$((N_SKIPPED_SELF+1))
        say "${Y}··· SKIP${N}  [$id] self-referential — this row exists so verify-check-registry.sh's structural checks apply to this script; running it live from inside itself would recurse"
        continue
    fi

    if [[ ! -f "$abs" || ! -x "$abs" ]]; then
        N_UNDET=$((N_UNDET+1)); UNDET_NAMES+=("$id")
        printf '%s◍ UNDET%s [%s] entry point missing or not executable: %s\n' "$Y" "$N" "$id" "$entry"
        continue
    fi

    # `-k 15`: a plain `timeout N` sends SIGTERM to its immediate child only,
    # once, and simply WAITS if that child ignores or does not propagate it —
    # measured live against `scripts/verify-all-constitution-rules.sh` during
    # this script's own development, where the outer `bash` survived SIGTERM
    # for at least 13 minutes past its declared 150s budget with the fleet
    # summary run appearing to hang. `--kill-after` sends SIGKILL 15s after
    # the first signal if the process is still alive, turning "bounded in
    # principle" into "bounded in practice".
    #
    # OUTPUT VIA A FILE, NOT `$(...)` — a second, independent bug this script
    # had and does not anymore, found while proving the fix above. `$(cmd)`
    # makes bash wait for the PIPE to reach EOF, not merely for `cmd` to
    # exit — and a killed script's own ORPHANED grandchild (one that does not
    # die with it, e.g. a `sleep` it forked and left behind) can keep holding
    # that pipe's write end open, so the whole capture blocks until the
    # grandchild exits on its own, regardless of how aggressively `timeout`
    # killed the check itself. Redirecting to a file and reading it back
    # after `timeout` returns sidesteps this: bash's wait() for `timeout`'s
    # own exit does not depend on any file descriptor being closed.
    _out_f="$(mktemp "${TMPDIR:-/tmp}/fleet-summary-out.XXXXXX")" || {
        N_UNDET=$((N_UNDET+1)); UNDET_NAMES+=("$id")
        printf '%s◍ UNDET%s [%s] could not create a capture file for this run\n' "$Y" "$N" "$id"
        continue
    }
    ( cd "$ROOT" && timeout -k 15 "$TIMEOUT" bash "$abs" >"$_out_f" 2>&1 )
    rc=$?
    out="$(cat "$_out_f" 2>/dev/null)"
    rm -f "$_out_f"
    case $rc in
        0)
            N_CLEAN=$((N_CLEAN+1))
            say "${G}✅ CLEAN${N}  [$id]"
            ;;
        2)
            N_UNDET=$((N_UNDET+1)); UNDET_NAMES+=("$id")
            printf '%s◍ UNDET%s [%s] check reports COULD-NOT-DETERMINE (rc=2)\n' "$Y" "$N" "$id"
            ;;
        124|137|143)
            # 124: `timeout` reports "timed out, one signal was enough".
            # 137/143 (128+SIGKILL/128+SIGTERM): reachable ONLY because of the
            # `-k 15` kill-after hardening above — measured live on this host
            # (uutils coreutils 0.8.0's `timeout`): when a process ignores
            # SIGTERM and the kill-after escalation actually fires, THIS
            # `timeout` reports the killed process's own 128+signal exit
            # status instead of 124, unlike GNU coreutils' `timeout`. All
            # three are the SAME event from this script's point of view — the
            # check could not be bounded to a verdict in the time given — and
            # must not be treated as a red rc, or a hung check would silently
            # read as a DEFECT rather than as what it actually is.
            N_UNDET=$((N_UNDET+1)); UNDET_NAMES+=("$id")
            printf '%s◍ UNDET%s [%s] TIMED OUT after %ss (rc=%s) — reported as could-not-determine, never silently dropped\n' "$Y" "$N" "$id" "$TIMEOUT" "$rc"
            ;;
        *)
            kind="$(classify_red "$id")"
            if [[ "$kind" == "DECLARED" ]]; then
                N_DECLARED=$((N_DECLARED+1)); DECLARED_NAMES+=("$id")
                printf '%s⚠ DECLARED%s [%s] rc=%s — %s (next_review %s)\n' "$Y" "$N" "$id" "$rc" \
                    "${LEDGER_EVIDENCE[$id]:0:100}" "${LEDGER_NEXTREVIEW[$id]}"
            elif [[ "$kind" == "REOPEN" ]]; then
                N_DEFECT=$((N_DEFECT+1)); DEFECT_NAMES+=("$id"); REOPEN_CANDIDATES+=("$id")
                printf '%s❌ DEFECT%s   [%s] rc=%s — REOPEN CANDIDATE: this check was DECLARED (next_review %s, now elapsed) but is still red (T114/FR-026)\n' \
                    "$R" "$N" "$id" "$rc" "${LEDGER_NEXTREVIEW[$id]}"
                printf '           %sto record it:%s bash scripts/record-reopen.sh --instrument %s --prior-kind declared --evidence "rc=%s, %s" --closure-ref "docs/findings/declared-reds.tsv:%s"\n' \
                    "$Y" "$N" "$id" "$rc" "${LEDGER_EVIDENCE[$id]:0:80}" "$id"
            else
                N_DEFECT=$((N_DEFECT+1)); DEFECT_NAMES+=("$id")
                printf '%s❌ DEFECT%s   [%s] rc=%s — no valid declared-red entry (see docs/findings/declared-reds.tsv)\n' "$R" "$N" "$id" "$rc"
            fi
            ;;
    esac
done

TOTAL_RED=$((N_DEFECT + N_DECLARED))
N_RUN=$((N_CLEAN + N_DEFECT + N_DECLARED + N_UNDET))
say "----------------------------------------------------------------------"
printf '%sFLEET-SUMMARY%s: %s clean, %s red (%s defect + %s declared), %s could-not-determine, %s check(s) run of %s registered (%s self-referential, skipped)\n' \
    "$B" "$N" "$N_CLEAN" "$TOTAL_RED" "$N_DEFECT" "$N_DECLARED" "$N_UNDET" "$N_RUN" "${#CHK_ID[@]}" "$N_SKIPPED_SELF"

printf '\n%sHEADLINE (FR-009 / SC-008, defect and declared NEVER merged):%s\n' "$B" "$N"
printf '  %s%s unexplained red(s) (defect)%s : %s\n' "$R" "$N_DEFECT" "$N" "$([[ ${#DEFECT_NAMES[@]} -gt 0 ]] && printf '%s' "${DEFECT_NAMES[*]}" || echo "none")"
printf '  %s%s declared-condition red(s)%s   : %s\n' "$Y" "$N_DECLARED" "$N" "$([[ ${#DECLARED_NAMES[@]} -gt 0 ]] && printf '%s' "${DECLARED_NAMES[*]}" || echo "none")"
[[ $N_UNDET -gt 0 ]] && printf '  %s%s could-not-determine%s          : %s (NOT counted as red either way; SC-008 is not proven while any of these stand)\n' "$Y" "$N_UNDET" "$N" "${UNDET_NAMES[*]}"
if [[ ${#REOPEN_CANDIDATES[@]} -gt 0 ]]; then
    printf '\n%s%s reopen candidate(s)%s (T114/FR-026 — a prior DECLARED closure whose cadence elapsed while still red):\n' "$R" "${#REOPEN_CANDIDATES[@]}" "$N"
    printf '  %s\n' "${REOPEN_CANDIDATES[*]}"
    printf '  These are counted above as DEFECT (an expired declaration is no declaration —\n'
    printf '  T116). Recording one in docs/findings/reopened-reds.jsonl is a DECIDED action,\n'
    printf '  not automatic; the exact command to run was printed on that check'"'"'s line above.\n'
fi

echo
if [[ $N_DEFECT -gt 0 ]]; then
    printf '%s❌ FLEET-SUMMARY: %s unexplained red(s) — SC-008 is not met.%s\n' "$R" "$N_DEFECT" "$N"
    exit 1
fi
if [[ $N_UNDET -gt 0 ]]; then
    printf '%s◍ FLEET-SUMMARY: COULD NOT DETERMINE%s — 0 unexplained reds among what ran, but %s check(s) could not be classified. This is NOT a pass.\n' "$Y" "$N" "$N_UNDET"
    exit 2
fi
printf '%s✅ FLEET-SUMMARY: 0 unexplained reds (%s declared-condition red(s) remain, tracked separately).%s\n' "$G" "$N_DECLARED" "$N"
exit 0
