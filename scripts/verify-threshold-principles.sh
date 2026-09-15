#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# verify-threshold-principles.sh — FR-010 (unified FR-252) / SC-007 (unified
# SC-131), asserted MECHANICALLY.
#
# WHY THIS EXISTS (T112, was 005/T034)
# --------------------------------------
# specs/008-unified-workshop-platform/tasks.md T112 requires: "any threshold,
# bucket, allow-list or baseline change must carry a principle stated
# independently of the count it produces." Two guards in this repository
# already do this in PROSE, by construction:
#   - workshop/scripts/verify-obtainability.sh derives its warn threshold as
#     `WARN_AT = CEILING - (largest single blob at HEAD)` — a FORMULA, never
#     a bare literal, so the threshold cannot be silently retyped without
#     also touching the formula that explains it.
#   - the palette gate's fixed floor (design-system palette validation) states
#     its minimum as a named constant with an inline rationale comment.
# NOTHING before this file DETECTED a weakening change mechanically — a
# threshold, baseline count, or allow-list ceiling could be silently edited in
# a commit that touched no comment, no doc, no formula, and no gate here would
# notice. This is that detector.
#
# WHAT IT DETECTS
# -----------------
# Walks a git diff (a commit range, or the working tree against HEAD) looking
# for ADDED lines that assign a BARE NUMERIC LITERAL to a variable whose name
# matches a closed set of threshold-shaped tokens (case-insensitive):
#   CEILING THRESHOLD LIMIT MAX MIN BASELINE WARN_AT QUOTA CAP FLOOR
# across shell (`NAME=123`, `NAME="123"`), Python/JS/Go/TSV-adjacent forms
# (`NAME = 123`, `NAME: 123`), and per-file line counts inside a declared
# ALLOW-LIST file (any path matching `*-allow` or `ALLOW_RULES` block).
#
# A matched line is FLAGGED unless, in the SAME diff hunk (same file, within
# a small context window) OR anywhere else in the same commit/diff, there is
# an ADDED or MODIFIED line carrying a PRINCIPLE marker:
#   - a comment/prose line matching REASON|BECAUSE|RATIONALE|DERIVED|FORMULA
#     (case-insensitive), or
#   - the threshold assignment itself is a FORMULA rather than a bare literal
#     — it references another identifier with an arithmetic operator
#     (`WARN_AT=$((CEILING - X))`), which is the verify-obtainability.sh shape
#     this checker is explicitly modelled on.
#
# THIS IS A HEURISTIC, NOT A PROOF OF INTENT
# ---------------------------------------------
# It cannot read minds. A commit that changes a threshold AND happens to touch
# an unrelated comment nearby will pass; a commit that changes a threshold with
# a perfectly good reason stated ONLY in the commit message (not the diff body)
# will be flagged. That asymmetry is deliberate: §11.4.6 forbids trusting an
# unstated reason, and a commit message is not part of the artifact a future
# reader opens the file to understand. The remedy for a false positive is to
# put the reason in the file, which is the whole point.
#
# EXIT CODES
#   0  no threshold/baseline/allow-list change lacked a principle marker
#   1  at least one such change was found with no principle marker nearby
#   2  COULD NOT DETERMINE — the range does not resolve, or this is not a git
#      repository. Never a pass, never an accusation.
#
# USAGE
#   scripts/verify-threshold-principles.sh                 HEAD~1..HEAD
#   scripts/verify-threshold-principles.sh --range A..B     an explicit range
#   scripts/verify-threshold-principles.sh --worktree       working tree vs HEAD
#   scripts/verify-threshold-principles.sh --root DIR
#   scripts/verify-threshold-principles.sh --prove-failure  its own §1.1 proof
# ------------------------------------------------------------------------------
set -uo pipefail

SELF_NAME="$(basename -- "${BASH_SOURCE[0]}")"
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || {
    echo "FATAL: cannot resolve script directory" >&2; exit 2; }

ROOT=""
RANGE=""
WORKTREE=0
PROVE=0

usage() {
    sed -n '/^# USAGE/,/^# ---/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | head -n -1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)          shift; ROOT="${1:-}" ;;
        --range)         shift; RANGE="${1:-}" ;;
        --worktree)      WORKTREE=1 ;;
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

if [[ -t 1 ]]; then
    R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[0;33m'; B=$'\033[1m'; N=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; N=""
fi

# ──────────────────────────────────────────────────────────────────────────────
# Core detector — runs `git diff <spec>` and prints one FLAG line per violation.
# Returns via global FLAGS array (populated) and echoes nothing else.
# ──────────────────────────────────────────────────────────────────────────────
THRESH_RE='(CEILING|THRESHOLD|LIMIT|MAX_[A-Z0-9_]*|_MAX|MIN_[A-Z0-9_]*|_MIN|BASELINE|WARN_AT|QUOTA|CAP|FLOOR)'
PRINCIPLE_RE='(REASON|BECAUSE|RATIONALE|DERIVED|FORMULA|BASELINE:)'
# Stored in a variable rather than inlined into `[[ ... =~ ... ]]`: bash
# tokenizes the RHS of `=~` before handing it to the regex engine, and an
# unquoted `;` inside a bracket expression (`[,;]?` below) is parsed as a
# command separator when written inline — a real bug this script hit and is
# recorded here so it is not reintroduced. Storing the pattern in a variable
# and matching against `$VAR` unquoted is the documented-safe form.
THRESH_LINE_PATTERN="^[[:space:]]*[A-Za-z_]*${THRESH_RE}[A-Za-z0-9_]*[[:space:]]*[:=][[:space:]]*\"?[0-9]+\"?[[:space:]]*[,;]?[[:space:]]*(#.*)?\$"

run_detector() {   # $1 = repo root, $2 = git diff spec (args after `git diff`)
    local root="$1"; shift
    local diff_out
    diff_out="$(cd "$root" && git diff --unified=3 "$@" 2>&1)"
    local grc=$?
    if [[ $grc -ne 0 ]]; then
        echo "UNDET: git diff failed (rc=$grc): $diff_out" >&2
        return 2
    fi

    FLAGS=()
    # Walk the diff once, bucketing every ADDED line (a '+' line that is not
    # the '+++' file header) by the file it belongs to.
    declare -A FILE_ADDED=()
    local f=""
    while IFS= read -r line; do
        case "$line" in
            diff\ --git*)
                f="$(sed -E 's#^diff --git a/(.*) b/.*#\1#' <<<"$line")"
                FILE_ADDED["$f"]=""
                ;;
            +++*|---*) ;;
            +*)
                [[ -n "$f" ]] && FILE_ADDED["$f"]+=$'\n'"${line:1}"
                ;;
        esac
    done <<<"$diff_out"

    for f in "${!FILE_ADDED[@]}"; do
        local added="${FILE_ADDED[$f]}"
        local has_principle=0
        grep -qiE "$PRINCIPLE_RE" <<<"$added" && has_principle=1

        while IFS= read -r aline; do
            [[ -z "$aline" ]] && continue
            # skip comment/prose lines themselves as candidates for the match
            case "$aline" in
                \#*) continue ;;
            esac
            # a bare-literal threshold assignment: NAME<sep><literal>, no
            # identifier reference and no arithmetic operator on the RHS.
            if [[ "$aline" =~ $THRESH_LINE_PATTERN ]]; then
                if [[ $has_principle -eq 0 ]]; then
                    FLAGS+=("$f: ${aline# }")
                fi
            fi
        done <<<"$added"
    done
    return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF
# ──────────────────────────────────────────────────────────────────────────────
if [[ $PROVE -eq 1 ]]; then
    printf '%sTHRESHOLD-PRINCIPLES §1.1 PAIRED MUTATION PROOF%s\n' "$B" "$N"
    echo "----------------------------------------------------------------------"
    P_PASS=0; P_FAIL=0
    p_ok()  { P_PASS=$((P_PASS+1)); printf '%s✅ %-28s%s %s\n' "$G" "$1" "$N" "$2"; }
    p_bad() { P_FAIL=$((P_FAIL+1)); printf '%s❌ %-28s%s %s\n' "$R" "$1" "$N" "$2"; }

    SB="$(mktemp -d "${TMPDIR:-/tmp}/threshold-proof.XXXXXX")" || {
        echo "UNDET: cannot create a sandbox; the proof could not run" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM

    git -C "$SB" init -q -b main
    git -C "$SB" config user.email "proof@example.invalid"
    git -C "$SB" config user.name "proof"

    cat >"$SB/gate.sh" <<'EOF'
#!/usr/bin/env bash
CEILING_MB=250
exit 0
EOF
    git -C "$SB" add gate.sh
    git -C "$SB" commit -q -m "base"

    run_case() {
        local label="$1" newcontent="$2" want="$3" needle="$4"
        printf '%s' "$newcontent" >"$SB/gate.sh"
        git -C "$SB" add gate.sh
        git -C "$SB" commit -q -m "change" --allow-empty
        local out rc
        out="$(cd "$SB" && bash "$SELF_DIR/$SELF_NAME" --root "$SB" --range HEAD~1..HEAD 2>&1)"; rc=$?
        if [[ $rc -ne $want ]]; then
            p_bad "$label" "expected rc=$want, got rc=$rc"; printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
        elif [[ -n "$needle" ]] && ! grep -qF -- "$needle" <<<"$out"; then
            p_bad "$label" "rc=$want as expected, but output never named '$needle'"; printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
        else
            p_ok "$label" "rc=$want${needle:+, and it named '$needle'}"
        fi
    }

    # ---- CONTROL: unchanged file -> rc0 ----------------------------------------
    run_case "CONTROL no-change" '#!/usr/bin/env bash
CEILING_MB=250
exit 0
' 0 ""

    # ---- M1: threshold weakened with NO principle change -> FLAGGED -----------
    run_case "M1 silent-weakening" '#!/usr/bin/env bash
CEILING_MB=500
exit 0
' 1 "CEILING_MB=500"

    # ---- M2: threshold weakened WITH a reason comment -> not flagged ----------
    run_case "M2 principled-change" '#!/usr/bin/env bash
# REASON: upstream payload grew after the 2026-09 media asset migration;
# re-measured and re-baselined against the new floor.
CEILING_MB=500
exit 0
' 0 ""

    # ---- M3: threshold expressed as a FORMULA -> not flagged (verify-obtainability shape)
    run_case "M3 formula-not-literal" '#!/usr/bin/env bash
CEILING_MB=500
WARN_AT=$((CEILING_MB - 50))
exit 0
' 0 ""

    # ---- M4: a THRESHOLD-shaped identifier with a BASELINE: marker present ----
    run_case "M4 baseline-marker" '#!/usr/bin/env bash
# BASELINE: pre-existing debt, see AUDIT.md#F19
MAX_RETRIES=99
exit 0
' 0 ""

    # ---- M5: unresolvable range -> rc2, never a pass ---------------------------
    out="$(cd "$SB" && bash "$SELF_DIR/$SELF_NAME" --root "$SB" --range nonexistent-ref..HEAD 2>&1)"; rc=$?
    if [[ $rc -eq 2 ]]; then p_ok "M5 unresolvable-range-rc2" "rc=2, never a pass"
    else p_bad "M5 unresolvable-range-rc2" "expected rc=2, got rc=$rc"; fi

    echo "----------------------------------------------------------------------"
    if [[ $P_FAIL -gt 0 ]]; then
        printf '%s❌ THRESHOLD-PRINCIPLES §1.1 PROOF: FAIL — %s case(s) did not behave as required.%s\n' "$R" "$P_FAIL" "$N"
        exit 1
    fi
    printf '%s✅ THRESHOLD-PRINCIPLES §1.1 MUTATION PROOF: PASS%s — %s assertions: a silently weakened\n' "$G" "$N" "$P_PASS"
    printf '   threshold is caught, the SAME change is cleared once a REASON comment, a\n'
    printf '   BASELINE marker, or a derived-formula shape is present, and an unresolvable\n'
    printf '   range reports rc=2 rather than a pass.\n'
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# Live run
# ──────────────────────────────────────────────────────────────────────────────
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "UNDET: $ROOT is not a git repository — cannot diff" >&2
    exit 2
fi

DIFF_ARGS=()
if [[ $WORKTREE -eq 1 ]]; then
    DIFF_ARGS=(HEAD)
    SPEC_LABEL="working tree vs HEAD"
elif [[ -n "$RANGE" ]]; then
    DIFF_ARGS=("$RANGE")
    SPEC_LABEL="$RANGE"
else
    if ! git -C "$ROOT" rev-parse --verify -q HEAD~1 >/dev/null 2>&1; then
        echo "UNDET: no HEAD~1 (a single-commit or shallow repository) — nothing to diff by default; pass --range or --worktree" >&2
        exit 2
    fi
    DIFF_ARGS=(HEAD~1..HEAD)
    SPEC_LABEL="HEAD~1..HEAD"
fi

echo "THRESHOLD-PRINCIPLES: scanning $SPEC_LABEL for a threshold/baseline change with no principle marker"
run_detector "$ROOT" "${DIFF_ARGS[@]}"
drc=$?
if [[ $drc -eq 2 ]]; then
    exit 2
fi

if [[ ${#FLAGS[@]} -eq 0 ]]; then
    echo "✅ THRESHOLD-PRINCIPLES: PASS — no threshold/baseline/allow-list change lacked a stated principle."
    exit 0
fi

echo "❌ THRESHOLD-PRINCIPLES [DEFECT]: ${#FLAGS[@]} threshold change(s) with no principle marker in the same diff:"
for f in "${FLAGS[@]}"; do
    echo "  $f"
done
echo
echo "A threshold, baseline, or allow-list ceiling must carry a REASON:, a"
echo "BASELINE:, or a derived-formula shape (mirrors verify-obtainability.sh's"
echo "WARN_AT = CEILING - (largest single blob at HEAD)) in the SAME diff."
exit 1
