#!/usr/bin/env bash
# ==============================================================================
# verify-decommission-precondition.sh — T484 (workshop) / T487 (ai_interviewing)
#
# WHY THIS EXISTS
# ----------------
# The umbrella-hosted copies of `workshop/` and `ai_interviewing/` are the
# OPERATIVE ones (§11.4.28 submodules-as-equal-codebase; unified FR-328). A
# standalone clone of either also exists on this host
# (../workshop, ../ai_interviewing, siblings of this umbrella's own parent
# directory), created under 007/T001-T004 to prove each module CAN run on its
# own. That standalone clone being merely PRESENT proves nothing: it has to
# actually build and actually pass its own tests, on its own, with nothing
# outside itself.
#
# This gate is the trigger the tasks describe: it refuses to certify the
# umbrella-hosted copy as decommissionable until the standalone clone clears
# BOTH its own install/build path and its own full test suite, run for real,
# right now. It never manufactures a green — a standalone clone that is
# stale, dirty, or genuinely broken (which, at the time this gate was
# written, both known clones are) gets a real NOT-SAFE verdict, not a
# hand-waved one.
#
# WHAT IT IS NOT
# ---------------
# It is NOT `<clone>/scripts/verify-standalone-clone.sh`. That module-local
# gate (T479) is STATIC: it checks the tracked sources for undeclared
# parent-project dependencies (relative `replace` targets, submodule
# gitlinks, remedy commands) and explicitly says so in its own header — "does
# NOT clone anything ... does NOT prove the clone builds". This gate is the
# other half that header names: it actually runs the install/build step and
# the test suite, against the real standalone checkout on this host.
#
# ENTRY POINTS, PER MODULE — investigated, not assumed
# ------------------------------------------------------
#   workshop          (github.com/milos85vasic/workshop_curriculum)
#     install/build  scripts/build.sh   (builds workshop-server + workshop-boot
#                     Go binaries; conditionally builds the Angular frontend
#                     when platform/frontend/package.json is present; builds
#                     doc exports; module's own three-valued contract: 0 built,
#                     1 a build genuinely failed, 2 toolchain unavailable)
#     test suite     `go test ./...` in platform/backend — the module's Go
#                     unit/integration suite. `scripts/verify.sh` exists and is
#                     a BROADER aggregation point (static + every
#                     platform/gates/verify-*.sh + runtime liveness probes);
#                     it is NOT used as the default TEST step here because it
#                     also re-checks properties (host readiness, a running
#                     stack) that are not "does the code's own test suite
#                     pass", and because several of its gates assume a
#                     superproject checkout. Run it explicitly with
#                     WORKSHOP_FULL_VERIFY=1 for the broader pass; its
#                     three-valued contract is preserved either way.
#
#   ai_interviewing   (github.com/milos85vasic/ai_interviewing)
#     install/build  platform/scripts/build.sh — builds the Go backend
#                     (`go build ./cmd/server`) and, when present, the Angular
#                     frontend via `npm ci && ng build`.
#     test suite     `go test ./...` in platform/backend.
#     HONEST GAP, recorded rather than hidden: this standalone clone has NO
#     top-level install script analogous to workshop's `scripts/setup.sh`
#     (no `<clone>/scripts/setup.sh` and no `bootstrap-standalone.sh`), and
#     `platform/qa/e2e` carries a Playwright end-to-end suite
#     (`npm test` -> `playwright test`) that is NOT run by this gate because
#     it needs browsers installed and a live server — that suite is a real,
#     separate, undischarged obligation and this gate says so rather than
#     silently calling itself "the full test suite".
#
# EXIT CONTRACT — three values, and 2 is never a pass, per this project's
# standing convention (§11.4 anti-bluff; precedence: 1 outranks 2)
#   0  SAFE TO DECOMMISSION — the standalone clone's own install/build AND its
#      own test suite were both run, right now, and both genuinely passed.
#   1  NOT SAFE — the clone exists and at least one required step was run and
#      genuinely FAILED (a real, observed red).
#   2  COULD NOT DETERMINE — the clone is absent, not a git checkout, or a
#      required entry point this script depends on does not exist on disk.
#      NEVER treated as a pass; NEVER treated as authorization to decommission.
#
# Usage:
#   scripts/verify-decommission-precondition.sh <workshop|ai_interviewing> \
#       [--clone <path>] [--json] [--prove-failure]
#
#   WORKSHOP_FULL_VERIFY=1   also run workshop's scripts/verify.sh (heavier)
#   DECOMM_BUILD_TIMEOUT=<s> bound each build step   (default 240)
#   DECOMM_TEST_TIMEOUT=<s>  bound each test step    (default 240)
# ==============================================================================
set -uo pipefail

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_ROOT="$(cd -- "$SELF/.." && pwd)"
PARENT_DIR="$(dirname -- "$UMBRELLA_ROOT")"

BUILD_TIMEOUT="${DECOMM_BUILD_TIMEOUT:-240}"
TEST_TIMEOUT="${DECOMM_TEST_TIMEOUT:-240}"
JSON=0
PROVE=0
MODULE=""
CLONE_OVERRIDE=""

usage() { sed -n '2,70p' "${BASH_SOURCE[0]}"; }

ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clone) CLONE_OVERRIDE="${2:-}"; shift 2 ;;
        --json) JSON=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done
[[ ${#ARGS[@]} -ge 1 ]] && MODULE="${ARGS[0]}"

say() { printf '%s\n' "$*"; }
ok()   { say "  [OK]      $*"; }
bad()  { say "  [FAIL]    $*"; FOUND_FAIL=1; }
unk()  { say "  [UNDET]   $*"; FOUND_UNDET=1; }

run_bounded() { # $1 timeout  $2 label  $3.. cmd
    local t="$1" label="$2"; shift 2
    say "  \$ (timeout ${t}s) $* "
    # NOTE: the command runs OUTSIDE any `if` condition on purpose. `if cmd;
    # then ...; fi` with no `else` returns exit status ZERO when `cmd` fails
    # (POSIX: an `if` with no taken branch and no `else` exits 0) — that would
    # silently launder every failing install/test step into rc=0 here, which
    # is exactly the false-pass shape this whole gate exists to refuse.
    timeout "$t" "$@" > "$TMPD/last.log" 2>&1
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        return 0
    fi
    if [[ $rc -eq 124 ]]; then
        say "      TIMEOUT after ${t}s — treated as a real failure, never a pass"
    fi
    tail -n 25 "$TMPD/last.log" | sed 's/^/      | /'
    return $rc
}

# ------------------------------------------------------------------------------
# §1.1 paired-mutation proof
# ------------------------------------------------------------------------------
run_prove() {
    local tmp rc_pass rc_fail
    tmp="$(mktemp -d)"
    trap "rm -rf '$tmp'" RETURN

    # Fixture: a throwaway "standalone clone" with a real git checkout, a
    # `scripts/install.sh` and a `scripts/test.sh`, wired through a tiny
    # per-module config the harness reads via DECOMM_FIXTURE_SPEC.
    mkdir -p "$tmp/clone_pass/scripts" "$tmp/clone_fail/scripts"
    for d in clone_pass clone_fail; do
        git -C "$tmp/$d" init -q
        git -C "$tmp/$d" config user.email proof@example.invalid
        git -C "$tmp/$d" config user.name proof
        printf '#!/usr/bin/env bash\necho install-ok\nexit 0\n' >"$tmp/$d/scripts/install.sh"
        chmod +x "$tmp/$d/scripts/install.sh"
    done
    printf '#!/usr/bin/env bash\necho test-ok\nexit 0\n' >"$tmp/clone_pass/scripts/test.sh"
    chmod +x "$tmp/clone_pass/scripts/test.sh"
    printf '#!/usr/bin/env bash\necho test-fail >&2\nexit 1\n' >"$tmp/clone_fail/scripts/test.sh"
    chmod +x "$tmp/clone_fail/scripts/test.sh"
    for d in clone_pass clone_fail; do
        (cd "$tmp/$d" && git add -A && git -c commit.gpgsign=false commit -qm seed)
    done

    local spec="$tmp/spec.env"
    P_PASS=0; P_FAIL=0
    p_case() {
        local name="$1" expect="$2" got="$3"
        if [[ "$expect" == "$got" ]]; then P_PASS=$((P_PASS+1)); say "  PASS: $name"
        else P_FAIL=$((P_FAIL+1)); say "  FAIL: $name (expected $expect, got $got)"; fi
    }

    echo "paired mutation proof for $(basename "${BASH_SOURCE[0]}")"
    echo

    # M1: clean clone -> SAFE (rc 0)
    DECOMM_FIXTURE_INSTALL="scripts/install.sh" DECOMM_FIXTURE_TEST="scripts/test.sh" \
        bash "${BASH_SOURCE[0]}" fixture --clone "$tmp/clone_pass" >/dev/null 2>&1
    p_case "M1 clean install+test -> SAFE (rc 0)" "0" "$?"

    # M2: failing test suite -> NOT SAFE (rc 1), never silently green
    DECOMM_FIXTURE_INSTALL="scripts/install.sh" DECOMM_FIXTURE_TEST="scripts/test.sh" \
        bash "${BASH_SOURCE[0]}" fixture --clone "$tmp/clone_fail" >/dev/null 2>&1
    p_case "M2 failing test suite -> NOT SAFE (rc 1)" "1" "$?"

    # M3: broken install step -> NOT SAFE (rc 1)
    printf '#!/usr/bin/env bash\necho install-fail >&2\nexit 1\n' >"$tmp/clone_pass/scripts/install.sh"
    DECOMM_FIXTURE_INSTALL="scripts/install.sh" DECOMM_FIXTURE_TEST="scripts/test.sh" \
        bash "${BASH_SOURCE[0]}" fixture --clone "$tmp/clone_pass" >/dev/null 2>&1
    p_case "M3 broken install -> NOT SAFE (rc 1)" "1" "$?"
    # restore
    printf '#!/usr/bin/env bash\necho install-ok\nexit 0\n' >"$tmp/clone_pass/scripts/install.sh"
    (cd "$tmp/clone_pass" && git add -A && git -c commit.gpgsign=false commit -qm restore)

    # M4: absent clone directory -> COULD NOT DETERMINE (rc 2), never a pass
    bash "${BASH_SOURCE[0]}" workshop --clone "$tmp/does-not-exist" >/dev/null 2>&1
    p_case "M4 absent clone -> UNDETERMINED (rc 2)" "2" "$?"

    # M5: clone present but not a git checkout -> UNDETERMINED (rc 2)
    mkdir -p "$tmp/not_a_repo"
    bash "${BASH_SOURCE[0]}" workshop --clone "$tmp/not_a_repo" >/dev/null 2>&1
    p_case "M5 non-git clone dir -> UNDETERMINED (rc 2)" "2" "$?"

    # M6: unknown module name -> UNDETERMINED (rc 2), refuses to guess
    bash "${BASH_SOURCE[0]}" not-a-real-module >/dev/null 2>&1
    p_case "M6 unknown module -> UNDETERMINED (rc 2)" "2" "$?"

    echo
    echo "proof: $P_PASS passed, $P_FAIL failed, 6 mutations run"
    [[ $P_FAIL -eq 0 ]]
}

if [[ $PROVE -eq 1 ]]; then
    run_prove
    exit $?
fi

# ------------------------------------------------------------------------------
# Module resolution
# ------------------------------------------------------------------------------
FOUND_FAIL=0
FOUND_UNDET=0
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

INSTALL_STEPS=()
TEST_STEPS=()
CLONE=""

case "$MODULE" in
    workshop)
        CLONE="${CLONE_OVERRIDE:-$PARENT_DIR/workshop}"
        INSTALL_STEPS=("scripts/build.sh")
        TEST_STEPS=("platform/backend:go test ./...")
        [[ "${WORKSHOP_FULL_VERIFY:-0}" == "1" ]] && TEST_STEPS+=(".:scripts/verify.sh")
        ;;
    ai_interviewing)
        CLONE="${CLONE_OVERRIDE:-$PARENT_DIR/ai_interviewing}"
        INSTALL_STEPS=("platform/scripts/build.sh")
        TEST_STEPS=("platform/backend:go test ./...")
        ;;
    fixture)
        # Used only by --prove-failure: a synthetic module whose install/test
        # relative paths are supplied via env, never real umbrella modules.
        CLONE="${CLONE_OVERRIDE:-}"
        INSTALL_STEPS=("${DECOMM_FIXTURE_INSTALL:-scripts/install.sh}")
        TEST_STEPS=(".:${DECOMM_FIXTURE_TEST:-scripts/test.sh}")
        ;;
    *)
        say "FATAL: unknown module '$MODULE' (expected: workshop | ai_interviewing)"
        usage
        exit 2
        ;;
esac

say "=== decommission precondition: $MODULE ==="
say "standalone clone: $CLONE"

if [[ -z "$CLONE" || ! -d "$CLONE" ]]; then
    unk "standalone clone directory does not exist: '$CLONE'"
    say
    say "VERDICT: COULD NOT DETERMINE — no standalone clone to evaluate."
    say "         The umbrella-hosted copy of '$MODULE' remains the operative one."
    exit 2
fi
if ! git -C "$CLONE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    unk "'$CLONE' exists but is not a git checkout"
    say
    say "VERDICT: COULD NOT DETERMINE."
    exit 2
fi

HEAD="$(git -C "$CLONE" rev-parse --short=12 HEAD 2>/dev/null || echo '<none>')"
REMOTE="$(git -C "$CLONE" remote get-url origin 2>/dev/null || echo '<none>')"
DIRTY="$(git -C "$CLONE" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
say "  HEAD:   $HEAD"
say "  remote: $REMOTE"
say "  dirty:  $DIRTY uncommitted path(s)"
[[ "$DIRTY" != "0" ]] && unk "clone has $DIRTY uncommitted path(s) — a decommission decision on an uncommitted clone is not reproducible evidence"

say
say "--- install/build (own path) ---"
for step in "${INSTALL_STEPS[@]}"; do
    if [[ ! -x "$CLONE/$step" && ! -f "$CLONE/$step" ]]; then
        unk "install step '$step' does not exist in the standalone clone"
        continue
    fi
    if (cd "$CLONE" && run_bounded "$BUILD_TIMEOUT" "install:$step" bash "$step"); then
        ok "install step '$step' succeeded"
    else
        bad "install step '$step' FAILED"
    fi
done

say
say "--- test suite (own path) ---"
for spec in "${TEST_STEPS[@]}"; do
    dir="${spec%%:*}"; cmd="${spec#*:}"
    abs="$CLONE/$dir"
    if [[ ! -d "$abs" ]]; then
        unk "test directory '$dir' does not exist in the standalone clone"
        continue
    fi
    # shellcheck disable=SC2086
    if (cd "$abs" && run_bounded "$TEST_TIMEOUT" "test:$spec" bash -c "$cmd"); then
        ok "test step '$spec' succeeded"
    else
        bad "test step '$spec' FAILED"
    fi
done

if [[ "$MODULE" == "ai_interviewing" ]]; then
    say
    unk "platform/qa/e2e Playwright suite exists but is NOT executed by this gate (needs installed browsers + a live server) — a real, separate, undischarged obligation, disclosed rather than silently omitted"
fi

say
if [[ $FOUND_FAIL -eq 1 ]]; then
    say "VERDICT: NOT SAFE TO DECOMMISSION — a real install or test failure was observed just now."
    say "         The umbrella-hosted '$MODULE' copy remains the operative one (FR-328)."
    exit 1
elif [[ $FOUND_UNDET -eq 1 ]]; then
    say "VERDICT: COULD NOT DETERMINE — never treated as authorization to decommission."
    say "         The umbrella-hosted '$MODULE' copy remains the operative one (FR-328)."
    exit 2
else
    say "VERDICT: SAFE TO DECOMMISSION — the standalone clone's own install/build AND its"
    say "         own test suite both ran, right now, and both genuinely passed."
    exit 0
fi
