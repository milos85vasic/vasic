#!/usr/bin/env bash
# zero-gap-verify.sh — independent two-ref re-run of a closed item's recorded check
# (feature 010, task T039; covers FR-007, SC-004).
#
# Purpose
#   Closure of a gap item needs proof the check is REAL: it must FAIL on the state
#   before the fix (RED) and PASS on the state after (GREEN). A check that passes on
#   both refs ("hollow") proves nothing and REFUSES closure. Each run is captured as
#   a SEALED evidence record through scripts/zero-gap-evidence.sh (T013), in the
#   verifier role, so the pair can be re-verified by zero-gap-evidence-chain.sh.
#
# Usage
#   zero-gap-verify.sh --item ID [--root DIR] [--checks-dir DIR] [--store DIR]
#       [--streams DIR] [--session ID] [--tier instance|model|capability]
#       [--working-tree] [--verdict-role author|verifier]
#   zero-gap-verify.sh --prove-failure
#
# Check spec: <checks-dir>/<ID>.check   (default <root>/docs/zero-gap/checks)
#   Plain `key=value` lines, `#` comments and blank lines allowed. Keys (a missing
#   required key, an unknown key or a duplicate key is rc 2 — never ignored):
#     check_id         required  the id stored in both evidence records
#     pre_fix_ref      required  git ref of the state BEFORE the fix
#     cmd              required  one line run as `bash -c`, cwd = the checked-out
#                                tree; its OWN exit status is the verdict:
#                                0 holds, 1 violated, 2 cannot determine
#                                (anything else is recorded as outcome 2)
#     population_kind  optional  source|process|wire   (default process)
#     evidence_class   optional  runtime|artifact|source (default runtime)
#   The check must not write into the tree it runs in: the state fingerprint is
#   taken before and after, and drift makes that run outcome 2 (adapter rule).
#
# Refs
#   PRE  run: a scratch `git worktree` of pre_fix_ref under $ZG_SCRATCH (default
#            $TMPDIR, else /tmp), detached, removed (and pruned) on EVERY exit path.
#   CURRENT run: a scratch worktree of HEAD (deterministic); with --working-tree
#            the live checkout at --root instead (uncommitted fix; the fingerprint
#            of a tree under concurrent edit is then rc 2 by design).
#
# Inputs
#   --item ID        gap item id, ^[A-Z]{3}-[0-9]{3,}$ (the evidence schema's rule)
#   --session ID     / $ZG_SESSION_ID  the verifying session; REQUIRED, never invented.
#                    The caller must be a producer other than the fixer (§11.4.240).
#   --verdict-role   author | verifier (DEFAULT verifier). The label sealed into BOTH records.
#                    `author` is the FIXER's own run: V-G3 requires the closure's GREEN to be
#                    verdict_role=author and the verifier's re-run to be a separate, later,
#                    verifier-labelled record. Pass `author` ONLY when the caller is the fixer
#                    and --session is the fixer's own session handle; the label is a claim this
#                    script cannot check. The default is `verifier` because that label can never
#                    be mistaken for the fixer's run (the validator refuses it as a GREEN).
#                    Unknown/absent value is never guessed: rc 2, nothing sealed.
#   --store/--streams  passed to the adapter (its defaults apply when omitted).
#   $ZG_EVIDENCE     adapter path (default scripts/zero-gap-evidence.sh beside this file).
#
# Exit codes (three-valued; 2 is NEVER a pass; a finding outranks an undetermined)
#   0  RED on pre-fix AND GREEN on current: the check is real; both records sealed
#   1  closure REFUSED: hollow (passes on both), fix ineffective (fails on both),
#      regression (passes pre-fix, fails now), or current run violated
#   2  cannot determine: bad usage, missing/malformed spec, unresolvable ref, no
#      session, git/adapter fault, or either run's outcome was 2
#   Verdict table (pre, cur):  (1,0)->0   (0,0)->1 hollow   (1,1)->1   (0,1)->1
#                              (x,1)->1   anything else with a 2 -> 2
#
# Side effects
#   Appends TWO records (pre-fix, current) to the evidence store. Creates and
#   removes scratch worktrees (git metadata under .git/worktrees is pruned).
#
# Dependencies: bash, git, scripts/zero-gap-evidence.sh (+ its deps), mktemp.
# Cross-references: tasks.md T039, data-model.md "StateMachine", research.md D11.

set -u

ZGV_HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ZGV_EVIDENCE="${ZG_EVIDENCE:-$ZGV_HERE/zero-gap-evidence.sh}"
# admission controller (host-hang fix WP1); overridable like the adapter so a relocated copy (the proof's
# mutants) still finds the real one
ZGV_ADMIT="${ZG_ADMIT:-$ZGV_HERE/agent-admit.sh}"

zgv_say() { printf 'zero-gap-verify: %s\n' "$*" >&2; }

# zgv_parse_spec <file> — strict key=value parse into ZGV_* vars. rc 0 ok, 2 malformed.
zgv_parse_spec() {
    local f=$1 line k v n=0
    ZGV_CHECK_ID=''; ZGV_PRE=''; ZGV_CMD=''; ZGV_POP=process; ZGV_CLASS=runtime
    local seen=' '
    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n+1))
        case "$line" in ''|'#'*) continue ;; esac
        case "$line" in *=*) ;; *) zgv_say "$f:$n: not key=value"; return 2 ;; esac
        k=${line%%=*}; v=${line#*=}
        case "$seen" in *" $k "*) zgv_say "$f:$n: duplicate key '$k'"; return 2 ;; esac
        seen="$seen$k "
        case "$k" in
            check_id) ZGV_CHECK_ID=$v ;;
            pre_fix_ref) ZGV_PRE=$v ;;
            cmd) ZGV_CMD=$v ;;
            population_kind) ZGV_POP=$v ;;
            evidence_class) ZGV_CLASS=$v ;;
            *) zgv_say "$f:$n: unknown key '$k'"; return 2 ;;
        esac
    done < "$f"
    if [ -z "$ZGV_CHECK_ID" ] || [ -z "$ZGV_PRE" ] || [ -z "$ZGV_CMD" ]; then
        zgv_say "$f: check_id, pre_fix_ref and cmd are all required"; return 2
    fi
    case "$ZGV_POP" in source|process|wire) ;; *) zgv_say "$f: bad population_kind '$ZGV_POP'"; return 2 ;; esac
    case "$ZGV_CLASS" in runtime|artifact|source) ;; *) zgv_say "$f: bad evidence_class '$ZGV_CLASS'"; return 2 ;; esac
    return 0
}

# zgv_record <dir> <label> — seal one run of the check in <dir>; returns the
# adapter's rc (= the check's outcome 0|1|2, or 2 when it was not recorded).
zgv_record() {
    local dir=$1 label=$2 rc
    ( cd "$dir" && "$ZGV_EVIDENCE" record "${ZGV_STORE_ARGS[@]}" --fp-dir "$dir" \
        --item-id "$ZGV_ITEM" --check-id "$ZGV_CHECK_ID" --population-kind "$ZGV_POP" \
        --verdict-role "$ZGV_ROLE" --independence-tier "$ZGV_TIER" --evidence-class "$ZGV_CLASS" \
        --verdict-exit --session "$ZGV_SESSION" -- bash -c "$ZGV_CMD" ) >"$ZGV_TMP/$label.out" 2>&1
    rc=$?
    case "$rc" in 0|1|2) ;; *) rc=2 ;; esac
    if [ "$rc" -eq 2 ]; then zgv_say "$label run: outcome 2 or not recorded: $(tail -2 "$ZGV_TMP/$label.out" | tr '\n' ' ')"; fi
    return "$rc"
}

zgv_cleanup() {
    local w
    for w in "${ZGV_WORKTREES[@]:-}"; do
        [ -n "$w" ] || continue
        git -C "$ZGV_ROOT" worktree remove --force "$w" >/dev/null 2>&1 || rm -rf "$w"
    done
    git -C "$ZGV_ROOT" worktree prune >/dev/null 2>&1
    if [ -n "${ZGV_TMP:-}" ]; then rm -rf "$ZGV_TMP"; fi
}

zgv_verify() {
    local -a zgv_argv=("$@")   # kept for the admission re-exec below
    ZGV_ITEM=''; ZGV_ROOT=''; local checks='' working=0 store='' streams=''
    ZGV_SESSION="${ZG_SESSION_ID:-}"; ZGV_TIER=instance; ZGV_TMP=''; ZGV_ROLE=verifier
    while [ "$#" -gt 0 ]; do
        # a value-taking option with no value would make `shift 2` fail and loop forever
        case "$1" in
            --item|--root|--checks-dir|--store|--streams|--session|--tier|--verdict-role)
                [ "$#" -ge 2 ] || { zgv_say "option '$1' needs a value"; return 2; } ;;
        esac
        case "$1" in
            --item) ZGV_ITEM=${2:-}; shift 2 ;;
            --root) ZGV_ROOT=${2:-}; shift 2 ;;
            --checks-dir) checks=${2:-}; shift 2 ;;
            --store) store=${2:-}; shift 2 ;;
            --streams) streams=${2:-}; shift 2 ;;
            --session) ZGV_SESSION=${2:-}; shift 2 ;;
            --tier) ZGV_TIER=${2:-}; shift 2 ;;
            --verdict-role) ZGV_ROLE=${2:-}; shift 2 ;;
            --working-tree) working=1; shift ;;
            *) zgv_say "unknown argument '$1' (see --help)"; return 2 ;;
        esac
    done
    [ -n "$ZGV_ROOT" ] || ZGV_ROOT=$(cd "$ZGV_HERE/.." && pwd)
    if ! printf '%s' "$ZGV_ITEM" | grep -Eq '^[A-Z]{3}-[0-9]{3,}$'; then zgv_say "--item must match ^[A-Z]{3}-[0-9]{3,}$"; return 2; fi
    [ -n "$ZGV_SESSION" ] || { zgv_say "no session id (--session or ZG_SESSION_ID): never invented"; return 2; }
    case "$ZGV_TIER" in instance|model|capability) ;; *) zgv_say "bad --tier"; return 2 ;; esac
    case "$ZGV_ROLE" in author|verifier) ;; *) zgv_say "bad --verdict-role '$ZGV_ROLE' (author|verifier)"; return 2 ;; esac
    if ! { [ -d "$ZGV_ROOT" ] && git -C "$ZGV_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; }; then
        zgv_say "root is not a git work tree: $ZGV_ROOT"; return 2
    fi
    ZGV_ROOT=$(cd "$ZGV_ROOT" && pwd)
    [ -n "$checks" ] || checks="$ZGV_ROOT/docs/zero-gap/checks"
    local spec="$checks/$ZGV_ITEM.check"
    [ -f "$spec" ] || { zgv_say "no recorded check for $ZGV_ITEM: $spec"; return 2; }
    zgv_parse_spec "$spec" || return 2
    ZGV_STORE_ARGS=()
    [ -z "$store" ] || ZGV_STORE_ARGS+=(--store "$store")
    [ -z "$streams" ] || ZGV_STORE_ARGS+=(--streams "$streams")
    local pre_sha cur_sha
    pre_sha=$(git -C "$ZGV_ROOT" rev-parse --verify --quiet "$ZGV_PRE^{commit}") \
        || { zgv_say "pre_fix_ref does not resolve to a commit: $ZGV_PRE"; return 2; }
    cur_sha=$(git -C "$ZGV_ROOT" rev-parse --verify --quiet "HEAD^{commit}") \
        || { zgv_say "HEAD does not resolve"; return 2; }
    [ -x "$ZGV_EVIDENCE" ] || { zgv_say "evidence adapter not executable: $ZGV_EVIDENCE"; return 2; }

    # Host-safety admission (2026-10-14 host-hang fix WP1): the two scratch worktrees and both check runs
    # are HEAVY work, so they run only inside scripts/agent-admit.sh (a heavy slot + pressure pre-checks +
    # bounded-run). Everything above is cheap validation and stays outside. A refusal, an undeterminable
    # pre-check or a bounded-run timeout is rc 2 — never a pass, never a refusal of closure.
    [ -f "$ZGV_ADMIT" ] || { zgv_say "admission controller missing: $ZGV_ADMIT"; return 2; }
    if ! bash "$ZGV_ADMIT" --is-admitted; then
        bash "$ZGV_ADMIT" --verdict3 --tag zero-gap-verify -- bash "$ZGV_HERE/zero-gap-verify.sh" "${zgv_argv[@]}"
        return $?
    fi

    ZGV_WORKTREES=()
    ZGV_TMP=$(mktemp -d "${ZG_SCRATCH:-${TMPDIR:-/tmp}}/zgv.XXXXXX") || { zgv_say "mktemp failed"; return 2; }
    trap 'zgv_cleanup' EXIT
    trap 'zgv_cleanup; exit 2' INT TERM HUP
    local pre_wt="$ZGV_TMP/pre" cur_wt="$ZGV_TMP/cur" cur_dir
    ZGV_WORKTREES+=("$pre_wt")
    git -C "$ZGV_ROOT" worktree add --detach -q "$pre_wt" "$pre_sha" >/dev/null 2>"$ZGV_TMP/wt.err" \
        || { zgv_say "cannot create pre-fix worktree: $(cat "$ZGV_TMP/wt.err")"; return 2; }
    if [ "$working" -eq 1 ]; then
        cur_dir=$ZGV_ROOT
    else
        ZGV_WORKTREES+=("$cur_wt")
        git -C "$ZGV_ROOT" worktree add --detach -q "$cur_wt" "$cur_sha" >/dev/null 2>"$ZGV_TMP/wt.err" \
            || { zgv_say "cannot create current worktree: $(cat "$ZGV_TMP/wt.err")"; return 2; }
        cur_dir=$cur_wt
    fi

    local pre_rc cur_rc
    zgv_record "$pre_wt" pre; pre_rc=$?
    zgv_record "$cur_dir" cur; cur_rc=$?
    zgv_say "item $ZGV_ITEM check $ZGV_CHECK_ID: pre-fix($pre_sha) outcome $pre_rc, current($cur_sha) outcome $cur_rc"

    if [ "$pre_rc" -eq 1 ] && [ "$cur_rc" -eq 0 ]; then
        zgv_say "VERIFIED: RED on pre-fix, GREEN on current — both runs sealed"; return 0
    fi
    if [ "$pre_rc" -eq 0 ] && [ "$cur_rc" -eq 0 ]; then
        zgv_say "REFUSED: HOLLOW check — passes on the pre-fix ref too, so it proves nothing"; return 1
    fi
    if [ "$cur_rc" -eq 1 ]; then
        zgv_say "REFUSED: the check is violated on the current ref (pre-fix outcome $pre_rc)"; return 1
    fi
    zgv_say "UNDETERMINED: a run could not be determined — not a pass"; return 2
}

# ---------------------------------------------------------------------------
# --prove-failure: paired mutation proof (§1.1). Builds a throwaway repo with two
# commits (tag zg-prefix = BUG present; HEAD = fixed) and drives the real verifier
# plus the real evidence adapter against the fixture corpus
# _tests/fixtures/zero-gap/verify/. Exit 0 all cases behave, 1 one slipped, 2 cannot run.
# ---------------------------------------------------------------------------
zgv_prove_failure() (
    set -u
    pass=0; fail=0
    ok()  { pass=$((pass+1)); echo "  PASS $*"; }
    bad() { fail=$((fail+1)); echo "  FAIL $*"; }
    for t in git go jq; do
        command -v "$t" >/dev/null 2>&1 || { echo "prove-failure: UNDETERMINED: $t absent"; exit 2; }
    done
    FIX="$ZGV_HERE/../_tests/fixtures/zero-gap/verify"
    [ -d "$FIX" ] || { echo "prove-failure: UNDETERMINED: fixture corpus absent: $FIX"; exit 2; }
    T=$(mktemp -d) || exit 2
    trap 'rm -rf "$T"' EXIT
    R="$T/repo"; mkdir -p "$R"
    ( cd "$R" && git init -q . && git config user.email t@example.invalid && git config user.name t \
        && printf 'BUG\n' > app.txt && git add app.txt && git commit -qm pre && git tag zg-prefix \
        && printf 'OK\n' > app.txt && git commit -qam fix ) || { echo "prove-failure: UNDETERMINED: fixture repo"; exit 2; }
    bins=$("$ZGV_EVIDENCE" --build-bins "$T/bin") || { echo "prove-failure: UNDETERMINED: cannot build adapter binaries"; exit 2; }
    export ZG_CHAIN_BIN=${bins%% *}
    S="$T/store"; ST="$T/streams"
    lines() { if [ -f "$S/sidecar.jsonl" ]; then wc -l < "$S/sidecar.jsonl"; else echo 0; fi; }
    wt_clean() { [ "$(git -C "$R" worktree list | wc -l)" -eq 1 ]; }
    # run <item> [extra args] ; sets rc and sealed (records added)
    run() {
        local item=$1; shift; local b; b=$(lines)
        out=$("$ZGV_HERE/zero-gap-verify.sh" --item "$item" --root "$R" --checks-dir "$FIX" \
              --store "$S" --streams "$ST" --session prove-session "$@" 2>&1); rc=$?
        sealed=$(( $(lines) - b ))
    }
    case_rc() { # label item want_rc want_sealed [extra]
        local label=$1 item=$2 wrc=$3 wsealed=$4; shift 4
        run "$item" "$@"
        if [ "$rc" -eq "$wrc" ] && [ "$sealed" -eq "$wsealed" ] && wt_clean; then
            ok "$label (rc $rc, $sealed record(s) sealed, scratch worktrees removed)"
        else
            bad "$label (rc $rc want $wrc; sealed $sealed want $wsealed; worktrees $(git -C "$R" worktree list | wc -l)): $(echo "$out" | tail -3 | tr '\n' '|')"
        fi
    }
    case_rc "C0 control: real check fails pre-fix, passes current" TST-001 0 2
    case_rc "M1 hollow check (passes on both refs) refuses closure" TST-002 1 2
    case_rc "M2 ineffective fix (fails on both refs) refuses closure" TST-003 1 2
    case_rc "M3 regression (passes pre-fix, fails current) refuses closure" TST-004 1 2
    case_rc "M4 unresolvable pre-fix ref is rc 2, nothing run or sealed" TST-005 2 0
    case_rc "M5 missing check spec is rc 2, nothing sealed" TST-099 2 0
    case_rc "M6 check cannot determine on current is rc 2 (never a pass)" TST-006 2 2
    case_rc "M7 exit status outside the 0|1|2 contract is rc 2" TST-007 2 2
    case_rc "M8 unknown key in the spec is rc 2, nothing sealed" TST-008 2 0
    case_rc "M9 malformed item id is rc 2, nothing sealed" tst-1 2 0
    # M10 no session: refused, never invented
    b=$(lines)
    out=$(env -u ZG_SESSION_ID "$ZGV_HERE/zero-gap-verify.sh" --item TST-001 --root "$R" --checks-dir "$FIX" --store "$S" --streams "$ST" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && [ "$(lines)" -eq "$b" ]; then ok "M10 no session id is rc 2, nothing sealed"; else bad "M10 session (rc $rc)"; fi
    # M11 the pair is bound to the check: last two sidecar lines carry the fixture check id and outcomes 1 then 0
    case_rc "C1 control re-run of the real check" TST-001 0 2
    pair=$(tail -n 2 "$S/sidecar.jsonl" | jq -r '[.check_id,.item_id,.outcome,.verdict_role]|join(",")' | tr '\n' ' ')
    if [ "$pair" = "fx-real,TST-001,1,verifier fx-real,TST-001,0,verifier " ]; then
        ok "M11 sealed pair is RED(1) then GREEN(0), same check id, verifier role"
    else bad "M11 sealed pair: $pair"; fi
    # M12 the sealed store verifies natively (adapter invariants + upstream chain walk)
    "$ZG_CHAIN_BIN" verify --store "$S" --schema "$ZGV_HERE/../specs/010-zero-gap-verified-closure/contracts/evidence-record.schema.json" >"$T/v" 2>&1; vrc=$?
    if [ "$vrc" -eq 0 ] && [ "$(lines)" -ge 2 ]; then ok "M12 store written by the verifier passes every adapter invariant and the chain walk"; else bad "M12 store verify rc $vrc: $(tail -3 "$T/v" | tr '\n' '|')"; fi
    # M13 detector sensitivity: a verifier whose hollow branch returns 0 MUST be caught by case M1
    sed 's/HOLLOW check — passes on the pre-fix ref too, so it proves nothing"; return 1/HOLLOW check"; return 0/' "$0" > "$T/mutant.sh"
    if cmp -s "$0" "$T/mutant.sh"; then bad "M13 mutation did not apply (anchor text moved)"; else
        out=$(ZG_EVIDENCE="$ZGV_EVIDENCE" bash "$T/mutant.sh" --item TST-002 --root "$R" --checks-dir "$FIX" --store "$S" --streams "$ST" --session prove-session 2>&1); rc=$?
        if [ "$rc" -eq 0 ]; then ok "M13 mutant (hollow branch returns 0) would pass M1's hollow fixture — M1 expects rc 1, so it detects the mutant"
        else bad "M13 mutant still refused the hollow check (rc $rc)"; fi
    fi
    # R1..R4 explicit --verdict-role (author|verifier). The fixer's own GREEN must be sealed as
    # `author` (V-G3 refuses a verifier-labelled GREEN); the default stays `verifier`, the label that
    # can never be mistaken for the fixer's run.
    lastpair() { tail -n 2 "$S/sidecar.jsonl" | jq -r '[.check_id,.item_id,.outcome,.verdict_role]|join(",")' | tr '\n' ' '; }
    case_rc "R1 --verdict-role author: real check seals a pair" TST-001 0 2 --verdict-role author
    if [ "$(lastpair)" = "fx-real,TST-001,1,author fx-real,TST-001,0,author " ]; then
        ok "R1b sealed pair carries verdict_role author on both records"
    else bad "R1b sealed pair: $(lastpair)"; fi
    case_rc "R2 --verdict-role verifier is the explicit spelling of the default" TST-001 0 2 --verdict-role verifier
    if [ "$(lastpair)" = "fx-real,TST-001,1,verifier fx-real,TST-001,0,verifier " ]; then
        ok "R2b sealed pair carries verdict_role verifier"
    else bad "R2b sealed pair: $(lastpair)"; fi
    case_rc "R3 unknown --verdict-role value is rc 2, nothing sealed" TST-001 2 0 --verdict-role reviewer
    case_rc "R4 --verdict-role with no value is rc 2, nothing sealed" TST-001 2 0 --verdict-role
    # R5 detector sensitivity: a verifier that ignores the flag (always verifier) MUST be caught by R1b
    sed 's/--verdict-role "\$ZGV_ROLE"/--verdict-role verifier/' "$0" > "$T/mutant2.sh"
    if cmp -s "$0" "$T/mutant2.sh"; then bad "R5 mutation did not apply (anchor text moved)"; else
        ZG_EVIDENCE="$ZGV_EVIDENCE" bash "$T/mutant2.sh" --item TST-001 --root "$R" --checks-dir "$FIX" --store "$S" --streams "$ST" --session prove-session --verdict-role author >/dev/null 2>&1
        if [ "$(lastpair)" != "fx-real,TST-001,1,author fx-real,TST-001,0,author " ]; then ok "R5 mutant (flag ignored, always verifier) is caught by R1b's role check"
        else bad "R5 mutant still sealed author records"; fi
    fi
    echo "prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ] && exit 0
    exit 1
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        --prove-failure)
            # the battery drives ~20 verifier runs (worktrees + adapter builds): admitted as ONE heavy unit, so
            # its child runs nest inside the held slot instead of each competing for one
            [ -f "$ZGV_ADMIT" ] || { zgv_say "admission controller missing: $ZGV_ADMIT"; exit 2; }
            if bash "$ZGV_ADMIT" --is-admitted; then export ZG_ADMIT="$ZGV_ADMIT"; zgv_prove_failure; exit $?; fi
            bash "$ZGV_ADMIT" --verdict3 --tag zero-gap-verify-prove -- bash "$ZGV_HERE/zero-gap-verify.sh" --prove-failure
            exit $? ;;
        -h|--help)       sed -n '2,68p' "$0"; exit 0 ;;
        *)               zgv_verify "$@"; exit $? ;;
    esac
fi
