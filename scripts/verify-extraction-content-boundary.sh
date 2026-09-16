#!/usr/bin/env bash
# ==============================================================================
# verify-extraction-content-boundary.sh — T494 (was: 007/T028)
#
# Mandatory content-boundary review gate for the reusable-code EXTRACTION
# pipeline (unified FR-051). It BLOCKS creation/push of a new public
# `vasic-digital/*` repository until the candidate extraction directory is
# confirmed to carry zero private-content matches against the private source
# it was cut from (`workshop` and/or `ai_interviewing`).
#
# WHAT THIS IS NOT
# -----------------
# It does NOT reimplement content-boundary detection. `scripts/verify-content-
# boundary.sh` at the umbrella root already does prose/short/name matching,
# direction subtraction, corpus fingerprinting — every detection primitive
# this gate needs. This script is a WRAPPER that invokes it with
# `--fleet-spec` (its own documented synthetic-fleet mechanism, used here for
# a real, not synthetic, purpose: neither the candidate directory nor the
# private source's role as "private" can be derived from `.gitmodules`,
# because the candidate is not yet a submodule of anything) over a throwaway
# root built for exactly this one candidate.
#
# ZERO TOLERANCE — the one deliberate divergence from the umbrella-wide gate
# ------------------------------------------------------------------------------
# The umbrella-wide gate honours `.content-boundary-allow`: a short, reviewed
# list of DECLARED exemptions for content that already flows between an
# established private/public pair for a stated reason (see the header of
# verify-content-boundary.sh, "declared exemption"). That mechanism is for an
# ALREADY-PUBLISHED, ALREADY-REVIEWED relationship. A candidate extraction
# about to become a NEW public repository has no such history and gets NO
# exemptions: this wrapper always passes `--allow <empty file>`, ignoring both
# the umbrella's own `.content-boundary-allow` and any file the candidate
# directory might itself carry. A leak here is never waved through.
#
# WHAT COUNTS AS "PRIVATE" AND "PUBLIC" HERE
# ------------------------------------------------------------------------------
#   private  one or more real private repositories the candidate was cut
#            from — by default both `workshop` and `ai_interviewing`
#            (the umbrella's private submodules), or explicit paths via
#            repeated --private.
#   public   the candidate extraction directory itself (--candidate).
#
# Both sides are addressed by SYMLINK into a throwaway `--root`, never by
# copying private content anywhere: `verify-content-boundary.sh`'s own
# `is_repo_root` check resolves a symlinked directory to its physical target
# before comparing it to `git rev-parse --show-toplevel`, so a symlinked repo
# is recognised identically to the real path (verified empirically before
# this script was written).
#
# If `--candidate` is not itself a git repository (a plain staged directory,
# which is the normal shape right before a first `git init && git push`),
# this script makes a THROWAWAY git-repo COPY of it in scratch space and
# scans that copy — the original candidate directory is never mutated.
#
# EXIT CONTRACT — three values, precedence 1 outranks 2, 2 is never a pass
#   0  CLEAR — the underlying gate found zero private-content matches against
#      the named private source(s), with zero exemptions in force. The
#      candidate MAY proceed to the rest of the extraction pipeline (other
#      gates, e.g. license/attribution, still apply — this gate answers only
#      the content-boundary question).
#   1  BLOCKED — LEAK: at least one private-content match was found. Creation
#      or push of the candidate's public repository MUST NOT proceed.
#   2  BLOCKED — COULD NOT DETERMINE (private source not a git checkout,
#      candidate directory missing, underlying gate could not run). Zero
#      tolerance means this is ALSO a block, never a pass.
#
# Usage:
#   scripts/verify-extraction-content-boundary.sh --candidate <dir> \
#       [--private <name-or-path>]...  [--window N] [--short-window N] \
#       [--no-short] [--no-names] [--json] [--prove-failure]
#
#   --private accepts the short names `workshop` and `ai_interviewing`
#   (resolved against this umbrella's own private submodules) or any
#   explicit path to a private git repository. Repeatable. Default, if none
#   given: both `workshop` and `ai_interviewing`.
# ==============================================================================
set -uo pipefail

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_ROOT="$(cd -- "$SELF/.." && pwd)"
UNDERLYING="$UMBRELLA_ROOT/scripts/verify-content-boundary.sh"

CANDIDATE=""
PRIVATE_ARGS=()
PASSTHROUGH=()
PROVE=0

usage() { sed -n '2,60p' "${BASH_SOURCE[0]}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --candidate) CANDIDATE="${2:-}"; shift 2 ;;
        --private)   PRIVATE_ARGS+=("${2:-}"); shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        --window|--short-window|--short-line-max|--name-rank|--name-ppm|--name-floor)
            PASSTHROUGH+=("$1" "${2:-}"); shift 2 ;;
        --no-short|--no-names|--json|--quiet)
            PASSTHROUGH+=("$1"); shift ;;
        *) echo "FATAL: unknown option '$1' (try --help)" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }

resolve_private() { # $1 name-or-path -> prints absolute path, or empty + FATAL
    local p="$1"
    case "$p" in
        workshop) printf '%s\n' "$UMBRELLA_ROOT/workshop" ;;
        ai_interviewing) printf '%s\n' "$UMBRELLA_ROOT/ai_interviewing" ;;
        *) printf '%s\n' "$p" ;;
    esac
}

# ------------------------------------------------------------------------------
# core: run the wrapped gate over (candidate dir, list of private dirs)
# returns the underlying gate's own rc (0/1/2)
# ------------------------------------------------------------------------------
run_gate() { # $1 candidate-dir  $2.. private-dirs
    local cand="$1"; shift
    local -a privs=("$@")
    local tmp rc
    tmp="$(mktemp -d)" || { say "FATAL: mktemp failed"; return 2; }

    local cand_abs
    cand_abs="$(cd -- "$cand" 2>/dev/null && pwd)" || { say "FATAL: candidate '$cand' does not exist"; rm -rf "$tmp"; return 2; }

    local pub_link="$tmp/root/candidate"
    mkdir -p "$tmp/root"
    if git -C "$cand_abs" rev-parse --show-toplevel >/dev/null 2>&1 \
        && [[ "$(cd -- "$cand_abs" && pwd -P)" == "$(git -C "$cand_abs" rev-parse --show-toplevel 2>/dev/null)" ]]; then
        ln -s "$cand_abs" "$pub_link"
        say "  candidate is already a git repository — scanned in place (symlinked, read-only): $cand_abs"
    else
        say "  candidate is NOT a git repository — making a THROWAWAY tracked copy in scratch space (original left untouched)"
        mkdir -p "$pub_link"
        # Exclude any pre-existing .git so the copy gets a fresh, fully-tracked
        # history of exactly what is really on disk right now.
        (cd "$cand_abs" && tar --exclude='.git' -cf - .) | (cd "$pub_link" && tar -xf -)
        git -C "$pub_link" init -q
        git -C "$pub_link" config user.email extraction-gate@example.invalid
        git -C "$pub_link" config user.name extraction-gate
        git -C "$pub_link" add -A
        git -C "$pub_link" -c commit.gpgsign=false commit -qm 'throwaway snapshot for content-boundary review' --allow-empty
    fi

    local spec="$tmp/spec.tsv"; : > "$spec"
    printf 'candidate\tpublic\n' >> "$spec"

    local i=0 p_abs p_link
    for p in "${privs[@]}"; do
        p_abs="$(cd -- "$p" 2>/dev/null && pwd)" || { say "FATAL: private source '$p' does not exist"; rm -rf "$tmp"; return 2; }
        if ! git -C "$p_abs" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            say "FATAL: private source '$p_abs' is not a git checkout (submodule not initialised?)"; rm -rf "$tmp"; return 2
        fi
        i=$((i+1))
        p_link="$tmp/root/private_$i"
        ln -s "$p_abs" "$p_link"
        printf 'private_%d\tprivate\n' "$i" >> "$spec"
        say "  private source $i: $p_abs (symlinked, read-only)"
    done
    [[ $i -ge 1 ]] || { say "FATAL: no private source resolved — nothing to compare against"; rm -rf "$tmp"; return 2; }

    local empty_allow="$tmp/empty-allow"
    printf '# ZERO TOLERANCE: extraction candidates get no exemptions.\n' > "$empty_allow"

    say
    say "  invoking: $UNDERLYING --root $tmp/root --fleet-spec $spec --allow $empty_allow ${PASSTHROUGH[*]:-}"
    say
    bash "$UNDERLYING" --root "$tmp/root" --fleet-spec "$spec" --allow "$empty_allow" "${PASSTHROUGH[@]}"
    rc=$?
    rm -rf "$tmp"
    return $rc
}

# ------------------------------------------------------------------------------
# §1.1 paired-mutation proof: a synthetic private-shaped string, never real
# ------------------------------------------------------------------------------
run_prove() {
    local tmp
    tmp="$(mktemp -d)"
    trap "rm -rf '$tmp'" RETURN
    P_PASS=0; P_FAIL=0
    p_case() {
        local name="$1" expect="$2" got="$3"
        if [[ "$expect" == "$got" ]]; then P_PASS=$((P_PASS+1)); echo "  PASS: $name"
        else P_FAIL=$((P_FAIL+1)); echo "  FAIL: $name (expected $expect, got $got)"; fi
    }

    echo "paired mutation proof for $(basename "${BASH_SOURCE[0]}")"
    echo

    # ---- synthetic private repo -------------------------------------------
    mkdir -p "$tmp/priv"
    git -C "$tmp/priv" init -q
    git -C "$tmp/priv" config user.email p@example.invalid
    git -C "$tmp/priv" config user.name p
    # Ten-plus-token synthetic sentence, invented for this proof, never real
    # private content — mirrors the shape verify-content-boundary.sh's own
    # fixture uses (the long-pass window is 10 tokens by default).
    cat > "$tmp/priv/notes.txt" <<'EOF'
The synthetic escalation runbook for this proof describes a fictitious rollback
window that nobody outside this fixture has ever written down anywhere real.
EOF
    git -C "$tmp/priv" add -A
    git -C "$tmp/priv" -c commit.gpgsign=false commit -qm seed

    # ---- clean candidate: unrelated benign text ----------------------------
    mkdir -p "$tmp/clean_candidate"
    printf 'This candidate module has nothing to do with the private fixture above.\n' \
        > "$tmp/clean_candidate/README.md"

    out="$(run_gate "$tmp/clean_candidate" "$tmp/priv" 2>&1)"; rc=$?
    p_case "clean candidate -> CLEAR (rc 0)" "0" "$rc"
    [[ $rc -ne 0 ]] && echo "$out" | tail -20 | sed 's/^/    | /'

    # ---- leaking candidate: verbatim copy of the synthetic private line ---
    mkdir -p "$tmp/leaky_candidate"
    cat > "$tmp/leaky_candidate/README.md" <<'EOF'
The synthetic escalation runbook for this proof describes a fictitious rollback
window that nobody outside this fixture has ever written down anywhere real.
EOF
    out="$(run_gate "$tmp/leaky_candidate" "$tmp/priv" 2>&1)"; rc=$?
    p_case "leaking candidate -> BLOCKED (rc 1)" "1" "$rc"
    [[ $rc -ne 1 ]] && echo "$out" | tail -20 | sed 's/^/    | /'

    # ---- non-git candidate directory (plain staged tree) -------------------
    mkdir -p "$tmp/plain_candidate"
    printf 'A plain, not-yet-git-initialised candidate directory: benign text only.\n' \
        > "$tmp/plain_candidate/README.md"
    out="$(run_gate "$tmp/plain_candidate" "$tmp/priv" 2>&1)"; rc=$?
    p_case "non-git candidate directory -> still scanned, CLEAR (rc 0)" "0" "$rc"
    [[ $rc -ne 0 ]] && echo "$out" | tail -20 | sed 's/^/    | /'

    # ---- private source not a git checkout ---------------------------------
    mkdir -p "$tmp/not_a_repo"
    out="$(run_gate "$tmp/clean_candidate" "$tmp/not_a_repo" 2>&1)"; rc=$?
    p_case "private source not a git checkout -> BLOCKED-UNDETERMINED (rc 2)" "2" "$rc"

    # ---- zero-tolerance: allow file inside candidate is IGNORED -----------
    mkdir -p "$tmp/leaky_candidate_with_allow"
    cat > "$tmp/leaky_candidate_with_allow/README.md" <<'EOF'
The synthetic escalation runbook for this proof describes a fictitious rollback
window that nobody outside this fixture has ever written down anywhere real.
EOF
    cat > "$tmp/leaky_candidate_with_allow/.content-boundary-allow" <<'EOF'
# REASON: an attempted self-exemption — this file must be IGNORED by the gate.
notes.txt	README.md	attempted self-exemption
EOF
    out="$(run_gate "$tmp/leaky_candidate_with_allow" "$tmp/priv" 2>&1)"; rc=$?
    p_case "candidate's own .content-boundary-allow is ignored -> still BLOCKED (rc 1)" "1" "$rc"

    echo
    echo "proof: $P_PASS passed, $P_FAIL failed, 5 mutations run"
    [[ $P_FAIL -eq 0 ]]
}

if [[ $PROVE -eq 1 ]]; then
    run_prove
    exit $?
fi

[[ -x "$UNDERLYING" || -f "$UNDERLYING" ]] || { say "FATAL: underlying gate not found: $UNDERLYING"; exit 2; }
[[ -n "$CANDIDATE" ]] || { say "FATAL: --candidate is required"; usage; exit 2; }

if [[ ${#PRIVATE_ARGS[@]} -eq 0 ]]; then
    PRIVATE_ARGS=(workshop ai_interviewing)
fi
PRIVATE_DIRS=()
for p in "${PRIVATE_ARGS[@]}"; do
    PRIVATE_DIRS+=("$(resolve_private "$p")")
done

say "=== extraction content-boundary review ==="
say "candidate: $CANDIDATE"
say "private source(s): ${PRIVATE_ARGS[*]}"
say

run_gate "$CANDIDATE" "${PRIVATE_DIRS[@]}"
rc=$?

say
case $rc in
    0) say "VERDICT: CLEAR — zero private-content matches, zero exemptions in force." ;;
    1) say "VERDICT: BLOCKED — LEAK found. Creation/push of the candidate's public repository MUST NOT proceed." ;;
    *) say "VERDICT: BLOCKED — COULD NOT DETERMINE. Zero tolerance: never treated as a pass." ;;
esac
exit $rc
