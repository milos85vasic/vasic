#!/usr/bin/env bash
# ==============================================================================
# verify-additive-cutover.sh — T495 (was: 007/T029), the mechanically-checkable
# half of the additive-then-cutover extraction pattern (unified FR-053).
#
# THE RULE THIS PROTECTS (documentation half — see the report handed to the
# coordinator for the honest read of whether history actually followed it)
# ------------------------------------------------------------------------------
# When reusable code is extracted from `workshop` or `ai_interviewing` into a
# new public `vasic-digital/*` submodule, the extraction is ADDITIVE first:
# the original in-tree copy keeps working. CUTOVER — the consumer switching
# its imports to the extracted module — is a SEPARATE, later, confirmed step,
# only taken once the consumer is re-tested against the extracted version.
# Extraction is never a same-commit rip-and-replace.
#
# WHAT THIS SCRIPT MECHANICALLY CHECKS
# ------------------------------------------------------------------------------
# Given a consumer's go.mod (default: workshop/platform/backend) and a set of
# (import-path, expected-target-directory) pairs — default: the three already
# extracted reusables, passage/verdict/curriculum-kit — for EACH pair it
# verifies that the cutover GENUINELY happened, not merely that it was
# declared:
#
#   R  require      go.mod declares `require <import-path> <version>`
#   X  replace       go.mod declares a `replace <import-path> => <target>`
#                    directive (a local, in-tree cutover, the shape every
#                    extraction in this project has used so far)
#   T  target        the replace TARGET directory exists on disk and its own
#                    go.mod declares `module <import-path>` (catches a
#                    replace pointing at a renamed, moved, or never-published
#                    directory — declared but not actually resolving)
#   C  consumed      at least one NON-test .go file under the consumer module
#                    actually `import`s the path (catches the case this task
#                    names explicitly: extraction landed, go.mod even points
#                    somewhere that resolves, but nothing in the consumer was
#                    ever switched over to use it — additive with no cutover)
#
# All four must hold for a pair to be CUT OVER. This does NOT run `go build`
# or `go test` (scripts/verify-decommission-precondition.sh already exercises
# the real build+test path); it is a fast, static, mechanical proof that the
# DEPENDENCY GRAPH itself reflects a real cutover, runnable on every commit.
#
# EXIT CONTRACT — three values, precedence 1 outranks 2, 2 is never a pass
#   0  CUT OVER — every declared pair is required, replaced, resolving, AND
#      genuinely imported.
#   1  NOT CUT OVER — at least one pair failed R, X, T, or C on real, observed
#      evidence (go.mod content, filesystem, grep over tracked .go sources).
#   2  COULD NOT DETERMINE — the consumer's go.mod does not exist, or is not
#      readable.
#
# Usage:
#   scripts/verify-additive-cutover.sh [--consumer <dir>] [--json] \
#       [--pair <import-path>:<target-dir>]...  [--prove-failure]
#
#   Default consumer: workshop/platform/backend (relative to this umbrella).
#   Default pairs:
#     github.com/vasic-digital/passage       -> submodules/passage
#     github.com/vasic-digital/verdict       -> submodules/verdict
#     github.com/vasic-digital/curriculum-kit -> submodules/curriculum-kit
#   --pair may be repeated to replace the default set entirely.
# ==============================================================================
set -uo pipefail

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_ROOT="$(cd -- "$SELF/.." && pwd)"

CONSUMER=""
declare -a PAIRS=()
PROVE=0

usage() { sed -n '2,55p' "${BASH_SOURCE[0]}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --consumer) CONSUMER="${2:-}"; shift 2 ;;
        --pair) PAIRS+=("${2:-}"); shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "FATAL: unknown option '$1' (try --help)" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }
ok()  { say "  [OK]      $*"; }
bad() { say "  [FAIL]    $*"; FOUND_FAIL=1; }

# ------------------------------------------------------------------------------
# check_pair — the R/X/T/C mechanical check, over one (import-path, target)
# pair, against one consumer directory (must contain go.mod).
# Prints its own findings; returns 0 if all four hold, 1 otherwise.
# ------------------------------------------------------------------------------
check_pair() { # $1 consumer-dir  $2 import-path  $3 target-dir (relative to consumer, or absolute)
    local consumer="$1" import_path="$2" target="$3"
    local gomod="$consumer/go.mod" pair_ok=1

    say "  pair: $import_path -> $target"

    # R — require line present
    if ! grep -Eq "^[[:space:]]*(require[[:space:]]+)?${import_path//./\\.}[[:space:]]" "$gomod" 2>/dev/null; then
        say "    [FAIL] R require: no 'require $import_path <version>' line in $gomod"
        pair_ok=0
    else
        say "    [OK]   R require: declared in $gomod"
    fi

    # X — replace line present, and capture its target
    local replace_line target_rel
    replace_line="$(grep -E "^[[:space:]]*replace[[:space:]]+${import_path//./\\.}[[:space:]]*=>" "$gomod" 2>/dev/null | head -1)"
    if [[ -z "$replace_line" ]]; then
        say "    [FAIL] X replace: no 'replace $import_path => ...' directive in $gomod"
        pair_ok=0
    else
        target_rel="$(printf '%s' "$replace_line" | sed -E 's/^[^=]*=>[[:space:]]*//' | awk '{print $1}')"
        say "    [OK]   X replace: '$import_path => $target_rel'"

        # T — the replace target resolves: directory exists, own go.mod
        #     declares the SAME module path (not a renamed/moved directory
        #     that happens to still be present).
        local target_abs
        if [[ "$target_rel" == /* ]]; then
            target_abs="$target_rel"
        else
            target_abs="$(cd -- "$consumer/$target_rel" 2>/dev/null && pwd)" || target_abs=""
        fi
        if [[ -z "$target_abs" || ! -f "$target_abs/go.mod" ]]; then
            say "    [FAIL] T target: '$target_rel' does not resolve to a directory with its own go.mod"
            pair_ok=0
        else
            local declared_module
            declared_module="$(awk '/^module[[:space:]]+/{print $2; exit}' "$target_abs/go.mod" 2>/dev/null)"
            if [[ "$declared_module" != "$import_path" ]]; then
                say "    [FAIL] T target: '$target_abs/go.mod' declares module '$declared_module', expected '$import_path'"
                pair_ok=0
            else
                say "    [OK]   T target: '$target_abs' resolves and declares module '$import_path'"
            fi
        fi
    fi

    # C — genuinely consumed: at least one non-test .go file imports the path
    local hit
    hit="$(grep -rl --include='*.go' "\"$import_path" "$consumer" 2>/dev/null | grep -v '_test\.go$' | head -1)"
    if [[ -z "$hit" ]]; then
        say "    [FAIL] C consumed: no non-test .go file under '$consumer' imports \"$import_path\""
        pair_ok=0
    else
        say "    [OK]   C consumed: imported at $hit"
    fi

    return $(( pair_ok == 1 ? 0 : 1 ))
}

# ------------------------------------------------------------------------------
# §1.1 paired-mutation proof
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

    build_target() { # $1 dir  $2 module-name
        mkdir -p "$1"
        printf 'module %s\n\ngo 1.22\n' "$2" > "$1/go.mod"
        printf 'package fixture\n\nfunc Hello() string { return "hi" }\n' > "$1/fixture.go"
    }

    # ---- M0 control: fully cut over (R+X+T+C all hold) ---------------------
    mkdir -p "$tmp/m0/consumer"
    build_target "$tmp/m0/target" "example.com/fixture"
    cat > "$tmp/m0/consumer/go.mod" <<EOF
module example.com/consumer

go 1.22

require example.com/fixture v0.0.0

replace example.com/fixture => ../target
EOF
    mkdir -p "$tmp/m0/consumer/pkg"
    cat > "$tmp/m0/consumer/pkg/user.go" <<'EOF'
package pkg

import "example.com/fixture"

var _ = fixture.Hello
EOF
    out="$(bash "${BASH_SOURCE[0]}" --consumer "$tmp/m0/consumer" --pair "example.com/fixture:../target" 2>&1)"; rc=$?
    p_case "M0 control: fully cut over -> rc 0" "0" "$rc"
    [[ $rc -ne 0 ]] && echo "$out" | sed 's/^/    | /'

    # ---- M1: require present, replace OMITTED ------------------------------
    mkdir -p "$tmp/m1/consumer"
    build_target "$tmp/m1/target" "example.com/fixture"
    cat > "$tmp/m1/consumer/go.mod" <<EOF
module example.com/consumer

go 1.22

require example.com/fixture v0.0.0
EOF
    mkdir -p "$tmp/m1/consumer/pkg"
    cp "$tmp/m0/consumer/pkg/user.go" "$tmp/m1/consumer/pkg/user.go"
    bash "${BASH_SOURCE[0]}" --consumer "$tmp/m1/consumer" --pair "example.com/fixture:../target" >/dev/null 2>&1
    p_case "M1 replace omitted -> rc 1 (caught)" "1" "$?"

    # ---- M2: replace present but target does not resolve --------------------
    mkdir -p "$tmp/m2/consumer/pkg"
    cat > "$tmp/m2/consumer/go.mod" <<EOF
module example.com/consumer

go 1.22

require example.com/fixture v0.0.0

replace example.com/fixture => ../does-not-exist
EOF
    cp "$tmp/m0/consumer/pkg/user.go" "$tmp/m2/consumer/pkg/user.go"
    bash "${BASH_SOURCE[0]}" --consumer "$tmp/m2/consumer" --pair "example.com/fixture:../does-not-exist" >/dev/null 2>&1
    p_case "M2 replace target missing -> rc 1 (caught)" "1" "$?"

    # ---- M3: replace resolves but target's own module name is WRONG --------
    mkdir -p "$tmp/m3/consumer/pkg"
    build_target "$tmp/m3/target" "example.com/renamed-fixture"
    cat > "$tmp/m3/consumer/go.mod" <<EOF
module example.com/consumer

go 1.22

require example.com/fixture v0.0.0

replace example.com/fixture => ../target
EOF
    cp "$tmp/m0/consumer/pkg/user.go" "$tmp/m3/consumer/pkg/user.go"
    bash "${BASH_SOURCE[0]}" --consumer "$tmp/m3/consumer" --pair "example.com/fixture:../target" >/dev/null 2>&1
    p_case "M3 target module name mismatch -> rc 1 (caught)" "1" "$?"

    # ---- M4: R+X+T all resolve, but NOTHING imports it (additive, no cutover)
    mkdir -p "$tmp/m4/consumer/pkg"
    build_target "$tmp/m4/target" "example.com/fixture"
    cat > "$tmp/m4/consumer/go.mod" <<EOF
module example.com/consumer

go 1.22

require example.com/fixture v0.0.0

replace example.com/fixture => ../target
EOF
    printf 'package pkg\n\nfunc Noop() {}\n' > "$tmp/m4/consumer/pkg/noop.go"
    bash "${BASH_SOURCE[0]}" --consumer "$tmp/m4/consumer" --pair "example.com/fixture:../target" >/dev/null 2>&1
    p_case "M4 declared+resolving but never imported -> rc 1 (caught)" "1" "$?"

    # ---- M5: consumer go.mod absent -> UNDETERMINED (rc 2) ------------------
    mkdir -p "$tmp/m5/consumer"
    bash "${BASH_SOURCE[0]}" --consumer "$tmp/m5/consumer" --pair "example.com/fixture:../target" >/dev/null 2>&1
    p_case "M5 consumer go.mod absent -> rc 2 (UNDETERMINED)" "2" "$?"

    echo
    echo "proof: $P_PASS passed, $P_FAIL failed, 6 mutations run"
    [[ $P_FAIL -eq 0 ]]
}

if [[ $PROVE -eq 1 ]]; then
    run_prove
    exit $?
fi

[[ -n "$CONSUMER" ]] || CONSUMER="$UMBRELLA_ROOT/workshop/platform/backend"
if [[ ${#PAIRS[@]} -eq 0 ]]; then
    PAIRS=(
        "github.com/vasic-digital/passage:$UMBRELLA_ROOT/submodules/passage"
        "github.com/vasic-digital/verdict:$UMBRELLA_ROOT/submodules/verdict"
        "github.com/vasic-digital/curriculum-kit:$UMBRELLA_ROOT/submodules/curriculum-kit"
    )
fi

say "=== additive-then-cutover check: $CONSUMER ==="
if [[ ! -f "$CONSUMER/go.mod" ]]; then
    say "  [UNDET] no go.mod at '$CONSUMER'"
    say
    say "VERDICT: COULD NOT DETERMINE."
    exit 2
fi
say

FOUND_FAIL=0
for pair in "${PAIRS[@]}"; do
    import_path="${pair%%:*}"
    target="${pair#*:}"
    check_pair "$CONSUMER" "$import_path" "$target"
    pair_rc=$?
    [[ $pair_rc -ne 0 ]] && FOUND_FAIL=1
    say
done

if [[ $FOUND_FAIL -eq 1 ]]; then
    say "VERDICT: NOT CUT OVER — at least one declared pair failed a real, observed check above."
    exit 1
else
    say "VERDICT: CUT OVER — every declared pair is required, replaced, resolving, and genuinely imported."
    exit 0
fi
