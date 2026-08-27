#!/usr/bin/env bash
# verify-all-constitution-rules.sh — the §11.4.32 post-constitution-pull
# validation sweep for the `vasic` umbrella.
#
# ── Purpose ──────────────────────────────────────────────────────────────────
# §11.4.32 (`submodules/constitution/Constitution.md:2026`) names this file
# verbatim:
#
#   "Validation sweep contract. The sweep is implemented as
#    `scripts/verify-all-constitution-rules.sh` (canonical name) which:
#     1. Re-runs the existing governance-cascade verifier
#        (`scripts/verify-governance-cascade.sh`) ...
#     2. For each rule whose enforcement gate is implementable
#        programmatically ... the sweep runs the corresponding gate against the
#        post-pull tree.
#     3. Any failure produces a directed FAIL entry naming the rule ...
#    Operator-explicit manual invocation MUST also be available
#    (`./scripts/verify-all-constitution-rules.sh`)."
#
# and its anti-bluff clause:
#
#   "A sweep that exits PASS without actually running every implementable gate
#    is a §11.4.32 violation."
#
# So: gates are DISCOVERED, never hardcoded. Add a gate upstream, pull the
# submodule, and this sweep picks it up with no edit here. Nothing is
# suppressed: a known-excluded finding still FAILs and still makes the sweep
# exit non-zero — exclusion is recorded in Constitution.md so a reader can tell
# an excluded finding from a regression, and is NEVER a verdict change.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-all-constitution-rules.sh [--root <project-root>] [--quiet]
#     --root <dir>   project root to sweep (default: this script's parent dir).
#                    Mirrors the flag every gate in the family already takes.
#     --quiet        one line per gate instead of the gate's own output;
#                    FAIL / ERROR detail is ALWAYS shown regardless.
#     --list         print the discovered gates + their resolved invocation and
#                    exit 0 without running anything.
#
#   Environment:
#     GATE_TIMEOUT   per-gate wall-clock cap in seconds (default 900). Applied
#                    only when coreutils `timeout` is on PATH; otherwise the
#                    sweep says so rather than pretending a cap is in force.
#     OD_THEME_GLOBS / OD_TOKEN_GLOBS / OD_VISREG_GLOBS / OD_MANIFEST_GLOBS
#                    consumer-registered inputs for CM-OPENDESIGN-UI-SYSTEM
#                    (§11.4.35). Bound below with this repository's real
#                    design-system layout; an operator export overrides them.
#
# ── How each gate's invocation is resolved (dynamically, from the gate) ──────
#   1. If the gate's arg parser offers `--selftest)`  -> run `--selftest`.
#      (This is how `lib/pointer_carrier.sh` — a sourced predicate, not a
#      standalone gate — documents its own runnable check.)
#   2. Else if it offers a `selfcheck)` subcommand    -> run `selfcheck <tmpdir>`.
#      (`gate_ledger.sh` is a multi-subcommand tool: invoked bare it prints its
#      usage and exits 2 — verified 2026-08-27 — so the sweep would score it
#      ERROR (a blind instrument, §11.4.201(7)(b)), never PASS. Either way a
#      bare invocation proves nothing, so its documented self-test is used
#      instead.)
#   3. Else, `--root` is resolved from the gate's OWN usage header, because the
#      family uses the same flag for two different things:
#        `--root <consumer-root>` / `<project-root>` -> the project root
#        `--root <constitution-root>`                -> submodules/constitution
#        (no --root in the header)                   -> the gate's own default
#   4. `--quiet` is appended only if the gate's parser offers it and --quiet
#      was requested.
#   Every resolved argv is printed, so the reader can check the resolution
#   rather than trust it (`--list`, or the per-gate line in non-quiet mode).
#
# ── Outputs ──────────────────────────────────────────────────────────────────
#   One line per gate (name, verdict, rc, elapsed, resolved argv) + a summary
#   with the pass/fail split, then the full output of every non-PASS gate.
#
# ── Side-effects ─────────────────────────────────────────────────────────────
#   None on this repository. The sweep itself only reads. Gates and mutation
#   tests under the constitution submodule create and trap-remove their own
#   `mktemp -d` sandboxes per their headers. `gate_ledger.sh selfcheck` is given
#   a scratch dir this script creates and removes. No git command that mutates
#   anything is run, and no submodule working tree is written to.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, POSIX find/grep/sed/awk, optional coreutils `timeout`. bash -n clean.
#
# ── Cross-references ─────────────────────────────────────────────────────────
#   §11.4.32 (this sweep), §11.4.164 (post-update hook that should call it),
#   §1.1 (the *_mutation_test.sh gates are the paired proofs and are run too),
#   §11.4.3 (SKIP with a reason, never a silent pass), §11.4.6 (report the
#   verified state), §11.4.201(7)(b) (rc=2 is a BLIND instrument, not a pass).
#
# ── Exit codes ───────────────────────────────────────────────────────────────
#   0 — every discovered gate exited 0.
#   1 — at least one gate FAILed (rc=1) or ERRORed (rc=2 / timeout / other).
#       An rc=2 gate is a blind instrument, never a pass — §11.4.201(7)(b).
#   2 — the sweep could not run at all (root missing, submodule not
#       initialised, gates directory absent, zero gates discovered).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

root="${REPO_ROOT}"
quiet=""
list_only=""

while [ $# -gt 0 ]; do
    case "$1" in
        --root)  root="${2:-}"; shift 2 ;;
        --quiet) quiet="1"; shift ;;
        --list)  list_only="1"; shift ;;
        -h|--help) sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "verify-all-constitution-rules.sh: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

[ -n "$root" ] && [ -d "$root" ] || { echo "SWEEP-ERROR: project root not found: '${root}'" >&2; exit 2; }
root="$(cd "$root" && pwd)"

CONSTITUTION_ROOT="${root}/submodules/constitution"
GATES_DIR="${CONSTITUTION_ROOT}/scripts/gates"
GATE_TIMEOUT="${GATE_TIMEOUT:-900}"

# ── §11.4.35 consumer-registered gate inputs — CM-OPENDESIGN-UI-SYSTEM ──────
# `cm_opendesign_ui_system.sh` is project-agnostic BY DESIGN (§11.4.28): its
# built-in OD_*_GLOBS describe a generic layout (`src/theme/*`, `tokens.json`,
# `tests/visual/*`). Not one of those patterns matches this repository, so with
# nothing bound all three lists came back EMPTY, the gate took its
# no-UI-surface branch, and it SKIPped with the reason "no UI surface detected"
# — about a repository that ships eight OpenDesign stylesheets under
# `design-system/`. §11.4.3 permits an HONEST skip; that one was factually
# false, and the sweep scored it PASS.
#
# §11.4.35 puts the fix HERE, in the consumer, never in the gate: the gate owns
# the generic defaults, the consumer registers its own layout as DATA. These
# are exported so the gate inherits them through the plain `bash "$g" $argv`
# invocation in STEP 2 below. Each is overridable from the environment.
#
#   OD_THEME_GLOBS    the CONSUMING layer — stylesheets that MUST resolve every
#                     colour through a token. Sub-check (b) scans these for
#                     ad-hoc hex, and they carry none.
#   OD_TOKEN_GLOBS    the §11.4.216 canonical token sources — the files whose
#                     `:root {}` / `[data-theme="dark"]` blocks DEFINE the
#                     `--od-*` / `--lk-*` custom properties. A token definition
#                     is the ONE place a colour literal legitimately lives, so
#                     the gate does not scan these for hex.
#   OD_VISREG_GLOBS   the real §11.4.170 host-rendered visual-proof harness
#                     (`_tests/visual/visual-oracle.js` + its self-validation +
#                     the Playwright visual-effects spec).
#                     `design-system/preview/*` is deliberately NOT bound: a
#                     preview page is not a pixel-diff harness, and binding it
#                     would buy sub-check (d) with something that cannot fail.
#   OD_MANIFEST_GLOBS the gate's own default list PLUS `helix-deps.yaml`, which
#                     is where this repo declares its dependencies (§11.4.31);
#                     it already declares the §11.4.162 OpenDesign engine.
#
# Honest scope, stated rather than left to be discovered (§11.4.6):
#   * The two brand stylesheets are registered as TOKEN sources because they
#     ARE this repository's §11.4.216 canonical token files. They also carry
#     component rules, which the gate therefore does not scan. At binding time
#     those rules held ZERO colour literals — checkable in one command:
#       grep -nE '#[0-9A-Fa-f]{6}\b' design-system/brand-*/*.css \
#         | grep -vE -- '--[A-Za-z0-9-]+[[:space:]]*:'
#     It returns exactly FIVE lines and every one of them is PROSE inside a CSS
#     comment — a §11.4.201(7)(a) carrier, not a colour: the measured-contrast
#     and brand-hue notes at milosvasic.css:2,647,648,688 and
#     vasic-digital.css:6. No declaration value in either file holds a literal.
#   * First-party CSS OUTSIDE `design-system/` is NOT registered, and is an
#     enumerated gap rather than a silent one: `ai_interviewing/assets/theme.css`
#     (53 literals) and `design-toolkit/proposed/**` (107) are separate UI
#     surfaces; `design-toolkit/qa/fixtures/golden-bad-tokens.css` (20) is a
#     golden-BAD fixture that MUST keep its literals; `<site>/assets/od/*.css`
#     are build-synced copies of the files already registered above.
export OD_THEME_GLOBS="${OD_THEME_GLOBS:-design-system/*.css design-system/fonts/*.css design-system/learning-kit/learning-kit.css design-system/motion/*.css}"
export OD_TOKEN_GLOBS="${OD_TOKEN_GLOBS:-design-system/brand-*/*.css design-system/learning-kit/kit-tokens.css}"
export OD_VISREG_GLOBS="${OD_VISREG_GLOBS:-_tests/visual/* _tests/visual-effects.spec.js}"
export OD_MANIFEST_GLOBS="${OD_MANIFEST_GLOBS:-helix-deps.yaml .mcp.json package.json go.mod Cargo.toml pubspec.yaml requirements.txt opencode.json .qwen/settings.json}"

if [ ! -s "${CONSTITUTION_ROOT}/Constitution.md" ]; then
    echo "SWEEP-ERROR: constitution submodule not initialised at ${CONSTITUTION_ROOT}" >&2
    echo "             fix: git submodule update --init submodules/constitution" >&2
    exit 2
fi
if [ ! -d "$GATES_DIR" ]; then
    echo "SWEEP-ERROR: gates directory absent: ${GATES_DIR}" >&2
    exit 2
fi

TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="timeout ${GATE_TIMEOUT}"

# ── Discovery — never a hardcoded list ──────────────────────────────────────
GATES="$(find "$GATES_DIR" -type f -name '*.sh' 2>/dev/null | sort)"
if [ -z "${GATES//[$' \t\r\n']/}" ]; then
    echo "SWEEP-ERROR: zero gates discovered under ${GATES_DIR}" >&2
    exit 2
fi
GATE_COUNT="$(printf '%s\n' "$GATES" | grep -c . )"

# resolve_argv <gate-path> -> echoes the arguments to pass (may be empty)
resolve_argv() {
    local g="$1" argv="" root_kind
    if grep -qE '^[[:space:]]*--selftest\)' "$g"; then
        printf '%s' "--selftest"; return
    fi
    if grep -qE '^[[:space:]]*selfcheck\)' "$g"; then
        printf '%s' "selfcheck"; return
    fi
    if grep -qE '^[[:space:]]*--root\)' "$g"; then
        root_kind="$(grep -oE -m1 -- '--root <[a-z-]+>' "$g" | head -1 | sed -E 's/.*<(.*)>/\1/')"
        case "$root_kind" in
            constitution-root) argv="--root ${CONSTITUTION_ROOT}" ;;
            consumer-root|project-root) argv="--root ${root}" ;;
            *) argv="" ;;   # header does not say which root it means -> use the gate's own default
        esac
    fi
    if [ -n "$quiet" ] && grep -qE '^[[:space:]]*--quiet\)' "$g"; then
        argv="${argv} --quiet"
    fi
    printf '%s' "$argv"
}

if [ -n "$list_only" ]; then
    echo "Discovered ${GATE_COUNT} gate script(s) under ${GATES_DIR#"$root"/}:"
    while IFS= read -r g; do
        [ -n "$g" ] || continue
        printf '  %-64s  argv: %s\n' "${g#"$GATES_DIR"/}" "$(resolve_argv "$g")"
    done <<< "$GATES"
    echo
    echo "Project-side gate: tests/test_constitution_inheritance.sh  argv: --root ${root}"
    echo
    echo "§11.4.35 consumer-registered env for CM-OPENDESIGN-UI-SYSTEM:"
    echo "  OD_THEME_GLOBS    : ${OD_THEME_GLOBS}"
    echo "  OD_TOKEN_GLOBS    : ${OD_TOKEN_GLOBS}"
    echo "  OD_VISREG_GLOBS   : ${OD_VISREG_GLOBS}"
    echo "  OD_MANIFEST_GLOBS : ${OD_MANIFEST_GLOBS}"
    exit 0
fi

echo "======================================================================"
echo "§11.4.32 VALIDATION SWEEP — verify-all-constitution-rules.sh"
echo "======================================================================"
echo "project root        : ${root}"
echo "constitution        : ${CONSTITUTION_ROOT}"
echo "constitution HEAD   : $(git -C "$CONSTITUTION_ROOT" rev-parse HEAD 2>/dev/null || echo 'unknown (not a git worktree)')"
echo "gates discovered    : ${GATE_COUNT} (dynamically, under scripts/gates/**)"
echo "OD_* gate inputs    : §11.4.35 consumer-registered (see the block above the discovery section)"
echo "  OD_THEME_GLOBS    : ${OD_THEME_GLOBS}"
echo "  OD_TOKEN_GLOBS    : ${OD_TOKEN_GLOBS}"
echo "  OD_VISREG_GLOBS   : ${OD_VISREG_GLOBS}"
echo "  OD_MANIFEST_GLOBS : ${OD_MANIFEST_GLOBS}"
if [ -n "$TIMEOUT_BIN" ]; then
    echo "per-gate timeout    : ${GATE_TIMEOUT}s"
else
    echo "per-gate timeout    : NOT ENFORCED — coreutils 'timeout' is not on PATH"
fi
echo

# ── §11.4.32 step 1 — the governance-cascade verifier ───────────────────────
echo "---- STEP 1 — governance-cascade verifier (§11.4.32 step 1) ----------"
CASCADE="${root}/scripts/verify-governance-cascade.sh"
step1_state="skip"
if [ -x "$CASCADE" ] || [ -r "$CASCADE" ]; then
    echo "running: ${CASCADE#"$root"/}"
    if [ -n "$quiet" ]; then
        $TIMEOUT_BIN bash "$CASCADE" >/dev/null 2>&1
    else
        $TIMEOUT_BIN bash "$CASCADE"
    fi
    if [ $? -eq 0 ]; then step1_state="pass"; echo "✅ STEP1 PASS"; else step1_state="fail"; echo "❌ STEP1 FAIL"; fi
else
    step1_state="skip"
    echo "⏭ STEP1 SKIP — scripts/verify-governance-cascade.sh does not exist in this"
    echo "               repository. §11.4.32 step 1 requires the sweep to re-run it;"
    echo "               writing it is outstanding work. This is an explicit SKIP with"
    echo "               a reason (§11.4.3), NOT a pass, and it is recorded as open"
    echo "               conflict OC-3 in Constitution.md."
fi
echo

# ── §11.4.32 step 2 — run every discovered gate ─────────────────────────────
echo "---- STEP 2 — every gate under submodules/constitution/scripts/gates --"
pass=0; fail=0; err=0
FAIL_NAMES=""; ERR_NAMES=""
DETAIL_DIR="$(mktemp -d)"
trap 'rm -rf "$DETAIL_DIR"' EXIT INT TERM

run_one() {
    local label="$1" cmd_display="$2"; shift 2
    local out rc start end ms
    start="$(date +%s%N)"
    out="$("$@" 2>&1)"; rc=$?
    end="$(date +%s%N)"; ms=$(( (end - start) / 1000000 ))
    local verdict
    case "$rc" in
        0) verdict="PASS"; pass=$((pass+1)) ;;
        1) verdict="FAIL"; fail=$((fail+1)); FAIL_NAMES="${FAIL_NAMES}${label}"$'\n' ;;
        *) verdict="ERROR"; err=$((err+1)); ERR_NAMES="${ERR_NAMES}${label} (rc=${rc})"$'\n' ;;
    esac
    if [ "$verdict" != "PASS" ]; then
        { echo "===== ${label}  [${verdict} rc=${rc}]"; echo "      argv: ${cmd_display}"; printf '%s\n' "$out"; echo; } \
            >> "${DETAIL_DIR}/detail.txt"
    fi
    printf '%-6s rc=%-3s %7sms  %-58s  %s\n' "$verdict" "$rc" "$ms" "$label" "$cmd_display"
    if [ -z "$quiet" ] && [ "$verdict" = "PASS" ]; then
        printf '%s\n' "$out" | sed 's/^/        /'
    fi
}

while IFS= read -r g; do
    [ -n "$g" ] || continue
    label="${g#"$GATES_DIR"/}"
    argv="$(resolve_argv "$g")"
    scratch=""
    if [ "$argv" = "selfcheck" ]; then
        scratch="$(mktemp -d)"
        run_one "$label" "selfcheck <scratch>" bash "$g" selfcheck "$scratch"
        rm -rf "$scratch"
    elif [ -n "$argv" ]; then
        # shellcheck disable=SC2086
        run_one "$label" "$argv" $TIMEOUT_BIN bash "$g" $argv
    else
        run_one "$label" "(gate defaults)" $TIMEOUT_BIN bash "$g"
    fi
done <<< "$GATES"

echo
echo "---- STEP 2b — project-side gates -------------------------------------"
INHERITANCE="${root}/tests/test_constitution_inheritance.sh"
if [ -r "$INHERITANCE" ]; then
    if [ -n "$quiet" ]; then
        run_one "tests/test_constitution_inheritance.sh" "--root <root> --quiet" $TIMEOUT_BIN bash "$INHERITANCE" --root "$root" --quiet
    else
        run_one "tests/test_constitution_inheritance.sh" "--root <root>" $TIMEOUT_BIN bash "$INHERITANCE" --root "$root"
    fi
    GATE_COUNT=$((GATE_COUNT+1))
else
    echo "⏭ SKIP — tests/test_constitution_inheritance.sh absent (§11.4.3 reasoned skip)"
fi

echo
echo "======================================================================"
echo "SUMMARY"
echo "======================================================================"
echo "gates run           : ${GATE_COUNT}"
echo "  PASS              : ${pass}"
echo "  FAIL   (rc=1)     : ${fail}"
echo "  ERROR  (rc!=0,1)  : ${err}"
echo "§11.4.32 step 1     : ${step1_state}"
if [ -n "$FAIL_NAMES" ]; then
    echo
    echo "FAILED:"
    printf '%s' "$FAIL_NAMES" | sed 's/^/  ❌ /'
fi
if [ -n "$ERR_NAMES" ]; then
    echo
    echo "ERRORED (blind instrument — §11.4.201(7)(b), never a pass):"
    printf '%s' "$ERR_NAMES" | sed 's/^/  ⚠ /'
fi

if [ -s "${DETAIL_DIR}/detail.txt" ]; then
    echo
    echo "======================================================================"
    echo "DETAIL — full output of every non-PASS gate"
    echo "======================================================================"
    cat "${DETAIL_DIR}/detail.txt"
fi

echo "======================================================================"
if [ $((fail + err)) -gt 0 ] || [ "$step1_state" = "fail" ]; then
    echo "❌ SWEEP: FAIL — ${fail} FAIL + ${err} ERROR out of ${GATE_COUNT} gate(s)."
    echo
    echo "Before treating any of these as a regression, read"
    echo "  Constitution.md -> 'Known-excluded gate findings'"
    echo "which names the five third-party / staged carriers the propagation"
    echo "gates report, and the four failures internal to the constitution"
    echo "submodule's own tree. Those are recorded, NOT suppressed: they still"
    echo "FAIL here and they still make this sweep exit non-zero."
    exit 1
fi
echo "✅ SWEEP: PASS — all ${GATE_COUNT} gate(s) exited 0."
exit 0
