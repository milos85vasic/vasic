#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Exhaustive test-suite for scripts/setup-agents-wizard.sh
#
# Every assertion records machine-readable evidence: expected value, actual
# value, exit code and a timestamp. Nothing here mutates the real environment -
# unit tests run against a throwaway $HOME and throwaway git repositories.
#
#   ./scripts/test-setup-agents-wizard.sh            # run everything
#   ./scripts/test-setup-agents-wizard.sh --no-live  # skip live network/daemon
#   ./scripts/test-setup-agents-wizard.sh --root DIR # test the wizard in DIR
#   ./scripts/test-setup-agents-wizard.sh --prove-failure   # its own §1.1 proof
#
# Evidence is written to <root>/.test-evidence/<UTC timestamp>/
#
# EXIT CODES — three-valued, like every other check in this repository
#   0  every assertion held
#   1  at least one assertion FAILED — a real regression in the wizard
#   2  COULD NOT DETERMINE: the wizard under test could not be located, read or
#      is empty, or the evidence directory could not be created. Nothing was
#      tested, and "nothing was tested" is neither a pass nor a failure
#      (§11.4.6 / SC-013). A suite that records nothing has not certified
#      anything, so it must never return 0 from that state.
# ------------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# ABSOLUTE, and resolved before anything can change the working directory: the
# paired proof re-invokes this file from inside its sandbox, and a relative
# BASH_SOURCE stops resolving the moment the cwd moves (measured: rc 127).
SELF_PATH="$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

RUN_LIVE=1
PROVE=0
ROOT_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-live)       RUN_LIVE=0 ;;
        --root)          shift; ROOT_OVERRIDE="${1:-}" ;;
        --prove-failure) PROVE=1 ;;
        -h|--help)       sed -n '2,25p' "$SELF_PATH" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "test-setup-agents-wizard: unknown option '$1'" >&2
           echo "usage: $0 [--no-live] [--root DIR] [--prove-failure]" >&2
           exit 2 ;;
    esac
    shift
done

# COULD NOT DETERMINE. Every path here means the suite never got as far as
# asserting anything, which is a different state from "the wizard is fine".
undet() {
    printf 'test-setup-agents-wizard: COULD NOT DETERMINE — %s\n' "$1" >&2
    printf '  Nothing was tested, so this is neither a pass nor a failure (§11.4.6 / SC-013).\n' >&2
    exit 2
}

if [[ -n "$ROOT_OVERRIDE" ]]; then
    PROJECT_ROOT=$(cd -- "$ROOT_OVERRIDE" &> /dev/null && pwd) \
        || undet "the target root '$ROOT_OVERRIDE' is not a directory, so the wizard under test cannot be located"
    SCRIPT_DIR="$PROJECT_ROOT/scripts"
fi
WIZARD="$SCRIPT_DIR/setup-agents-wizard.sh"

if [[ $PROVE -eq 1 ]]; then
    # ══════════════════════════════════════════════════════════════════════════
    # §1.1 PAIRED MUTATION PROOF  —  --prove-failure
    #
    # WHAT IS UNDER TEST. This SUITE. Until now it asserted three-valued
    # behaviour in the wizard it tests (K23b/K25) while implementing none for
    # itself, and nothing anywhere demonstrated that it goes red when the wizard
    # regresses. Both halves are closed here: the rc-2 states above are exercised
    # as U1..U4, and M1..M4 seed real regressions and require the suite to catch
    # each one BY NAME.
    #
    # WHY THE CONTROL IS THE REAL WIZARD, BYTE-COPIED. A synthetic wizard cannot
    # be the control: 217 assertions describe this specific file, so a stand-in
    # would fail the control and the battery would never start. The copy is made
    # from the real tree and only the ROOT is redirected, so the control run is
    # simultaneously the evidence that the suite passes on real material — while
    # every mutation is applied to the COPY and the real wizard is never opened
    # for writing.
    #
    # WHY EACH MUTATION IS NAMED, not merely counted. A suite can go red for the
    # wrong reason. Every case below asserts the SPECIFIC assertion that must
    # fail, so "it turned red" cannot stand in for "it caught this".
    #
    # The pre-flight runs the REAL suite against the REAL root, then removes ONLY
    # the evidence directory that run created — reported, never gating.
    # ══════════════════════════════════════════════════════════════════════════
    P_PASS=0; P_FAIL=0
    p_ok()  { P_PASS=$((P_PASS+1)); printf '✅ %-30s %s\n' "$1" "$2"; }
    p_bad() { P_FAIL=$((P_FAIL+1)); printf '❌ %-30s %s\n' "$1" "$2"; }

    echo "SETUP-AGENTS-WIZARD-SUITE §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    [[ -f "$WIZARD" ]] || undet "the wizard under test is not at $WIZARD, so no specimen can be built"

    # ---- PRE-FLIGHT: the REAL suite against the REAL root --------------------
    pf_out="$(timeout 900 bash "$SELF_PATH" --no-live 2>&1)"; pf_rc=$?
    pf_ev="$(printf '%s' "$pf_out" | sed -n 's|^ *results\.tsv *: *\(.*\)/results\.tsv$|\1|p' | tail -1)"
    case "$pf_rc" in
        0|1|2) printf 'ℹ %-30s the real suite ran against the real root and returned rc=%s — %s.\n' \
                      "PRE-FLIGHT live-run" "$pf_rc" \
                      "$(printf '%s' "$pf_out" | grep -oE 'total=[0-9]+ passed=[0-9]+ failed=[0-9]+ skipped=[0-9]+' | tail -1)"
               printf '%-32s REPORTED, never gating.\n' "" ;;
        124)   p_bad "PRE-FLIGHT live-run" "the real suite TIMED OUT on the real root — it cannot start, so it cannot guard anything" ;;
        *)     p_bad "PRE-FLIGHT live-run" "the real suite exited rc=${pf_rc}, outside its own 0/1/2 contract" ;;
    esac
    # Leave the tree as it was found. Guarded so this can only ever remove a
    # directory this run created under the root's own .test-evidence/.
    case "$pf_ev" in
        "$PROJECT_ROOT"/.test-evidence/*) rm -rf -- "$pf_ev"
            printf '%-32s (its evidence directory was removed; the tree is as it was found)\n' "" ;;
    esac

    WSB="$(mktemp -d "${TMPDIR:-/tmp}/wizard-suite-proof.XXXXXX")" || {
        echo "test-setup-agents-wizard: UNDETERMINED — cannot create a sandbox" >&2; exit 2; }
    trap 'rm -rf "${WSB:-}"' EXIT INT TERM     # cleanup: every specimen lives and dies inside $WSB
    echo "  sandbox: $WSB"

    SPEC_ROOT="$WSB/root"
    SPEC_WIZ="$SPEC_ROOT/scripts/setup-agents-wizard.sh"

    build_specimen() {
        rm -rf "$SPEC_ROOT"
        mkdir -p "$SPEC_ROOT" || return 1
        # The suite reads many siblings through SCRIPT_DIR (rollback, remediation,
        # reindex, doctor, the hardcoded-path audit, and `"$SCRIPT_DIR"/*.sh` in
        # J8), so the whole directory is mirrored rather than one file cherry-picked.
        cp -a "$SCRIPT_DIR" "$SPEC_ROOT/scripts" || return 1
        [[ -s "$SPEC_WIZ" ]] || return 1
        return 0
    }

    # _wz_exact <file> <exact-line> <replacement-line>
    # awk + mv, deliberately NOT `sed -i`: an in-place sed is a GNU/BSD
    # portability assumption that scripts/audit-environment-assumptions.sh flags
    # by rule, and a new proof must not add a finding to a sibling gate.
    _wz_exact() {
        awk -v want="$2" -v rep="$3" \
            '$0==want { print rep; n++; next } { print } END { if (n==0) exit 3 }' \
            "$1" > "$1.mut" || { rm -f "$1.mut"; return 1; }
        mv "$1.mut" "$1"
    }

    run_suite() { ( cd "$WSB" && timeout 900 bash "$SELF_PATH" --root "$SPEC_ROOT" --no-live 2>&1 ) }

    # assert_mutation <label> <assertion-name> <mutate-fn>
    # Requires rc=1 AND that the NAMED assertion is the one reported failing.
    assert_mutation() {
        local label="$1" name="$2" fn="$3" out rc
        if ! build_specimen; then
            p_bad "$label" "the specimen could not be built — nothing was proved by this case"; return
        fi
        if ! "$fn"; then
            p_bad "$label" "the mutation could not be applied (the anchor line is gone — update this proof)"; return
        fi
        out="$(run_suite)"; rc=$?
        if [[ $rc -ne 1 ]]; then
            p_bad "$label" "expected rc=1 (a real regression), got rc=${rc}"
            printf '%s' "$out" | grep -E 'total=|❌' | tail -4 | sed 's/^/        /'
            return
        fi
        if ! printf '%s' "$out" | grep -F '❌' | grep -qF -- "$name"; then
            p_bad "$label" "the suite went red, but NOT on '${name}' — a red suite is not evidence it caught this"
            printf '%s' "$out" | grep -F '❌' | head -4 | sed 's/^/        /'
            return
        fi
        p_ok "$label" "rc=1, and the failing assertion is '${name}'"
    }

    # ---- CONTROL: the real wizard, byte-copied, must pass its own suite ------
    if ! build_specimen; then
        echo "test-setup-agents-wizard: UNDETERMINED — the specimen could not be built" >&2; exit 2
    fi
    _ctl_out="$(run_suite)"; _ctl_rc=$?
    if [[ $_ctl_rc -eq 0 ]]; then
        p_ok "CONTROL real-wizard-copy  " "rc=0 — $(printf '%s' "$_ctl_out" | grep -oE 'total=[0-9]+ passed=[0-9]+ failed=[0-9]+ skipped=[0-9]+' | tail -1)"
    else
        p_bad "CONTROL real-wizard-copy " "rc=${_ctl_rc} on an UNMUTATED copy of the real wizard"
        printf '%s' "$_ctl_out" | grep -F '❌' | head -6 | sed 's/^/        /'
        echo "----------------------------------------------------------------------"
        echo "❌ SETUP-AGENTS-WIZARD-SUITE §1.1 PROOF: ABORTED — the control did not pass, so"
        echo "   ZERO mutations ran and nothing below would have been proved. Fix the wizard"
        echo "   (or the suite) first; this is not a statement about either mutation battery."
        exit 1
    fi

    # ---- M1  the ensure_lumen CALL SITE is deleted --------------------------
    # A9 exists because exactly this happened once: an audit removed the only
    # call and the assertion that was supposed to notice still passed, because it
    # matched the DEFINITION. It now counts call sites; this proves that it does.
    m1() { _wz_exact "$SPEC_WIZ" "ensure_lumen" "# ensure_lumen  <- call site deleted by the paired proof"; }
    assert_mutation "M1 ensure_lumen-uncalled  " "A9 ensure_lumen is actually CALLED" m1

    # ---- M2  the lumen MCP subcommand regresses to the bogus one ------------
    m2() { _wz_exact "$SPEC_WIZ" '            "args": ["stdio"]' '            "args": ["serve"]'; }
    assert_mutation "M2 lumen-mcp-bogus-subcmd " "A3 lumen MCP uses the real 'stdio' subcommand" m2

    # ---- M3  a guessed npm package name comes back on an EXECUTABLE line ----
    # The assertion deliberately ignores comments, so the seeded line must be
    # real code. It is placed in a function nothing calls, so the ONLY thing it
    # can change is the static-analysis verdict.
    m3() {
        printf '\n_proof_seeded_regression() { npm install -g @specify/cli; }\n' >> "$SPEC_WIZ"
    }
    assert_mutation "M3 bogus-npm-package-back " "A12 no executable line installs bogus package @specify/cli" m3

    # ---- M4  a delegated-probe CALL SITE is deleted (a different group) -----
    m4() { _wz_exact "$SPEC_WIZ" "tune_ollama_step" "# tune_ollama_step  <- call site deleted by the paired proof"; }
    assert_mutation "M4 tune-step-uncalled     " "K21 tune_ollama_step is actually CALLED" m4

    # ---- U1..U4  the three-valued half ---------------------------------------
    # None of these is a bad-usage error: each is a state in which the suite RAN
    # and could not test anything. "Nothing was tested" must never read as 0.
    u_case() {                          # u_case <label> <needle> <argv...>
        local label="$1" needle="$2"; shift 2
        local out rc
        out="$( ( cd "$WSB" && timeout 300 bash "$SELF_PATH" "$@" 2>&1 ) )"; rc=$?
        if [[ $rc -eq 2 ]] && printf '%s' "$out" | grep -qF -- "$needle"; then
            p_ok "$label" "rc=2, and it named the reason"
        else
            p_bad "$label" "expected rc=2 naming '${needle}', got rc=${rc}"
            printf '%s\n' "$out" | tail -3 | sed 's/^/        /'
        fi
    }
    build_specimen >/dev/null 2>&1
    u_case "U1 root-does-not-exist     " "is not a directory" --root "$WSB/no-such-root" --no-live
    mkdir -p "$WSB/no-wizard/scripts"
    u_case "U2 wizard-absent           " "is not at" --root "$WSB/no-wizard" --no-live
    mkdir -p "$WSB/empty-wizard/scripts" && : > "$WSB/empty-wizard/scripts/setup-agents-wizard.sh"
    u_case "U3 wizard-empty            " "is empty" --root "$WSB/empty-wizard" --no-live
    # A regular FILE where the evidence directory must go: mkdir -p cannot
    # succeed against it for ANY uid, so this case does not quietly pass as root.
    mkdir -p "$WSB/no-evidence/scripts" \
        && cp "$WIZARD" "$WSB/no-evidence/scripts/setup-agents-wizard.sh" \
        && printf 'not a directory\n' > "$WSB/no-evidence/.test-evidence"
    u_case "U4 evidence-unwritable     " "cannot be created" --root "$WSB/no-evidence" --no-live

    # ---- RESTORED CONTROL ----------------------------------------------------
    build_specimen >/dev/null 2>&1
    _rst_out="$(run_suite)"; _rst_rc=$?
    if [[ $_rst_rc -eq 0 ]]; then
        p_ok "CONTROL restored          " "rc=0 — the unmutated copy is still green after the battery"
    else
        p_bad "CONTROL restored         " "rc=${_rst_rc}; a mutation leaked out of its specimen"
    fi

    echo "----------------------------------------------------------------------"
    if [[ $P_FAIL -gt 0 ]]; then
        echo "❌ SETUP-AGENTS-WIZARD-SUITE §1.1 MUTATION PROOF: FAIL — ${P_FAIL} case(s) did not hold."
        exit 1
    fi
    echo "✅ SETUP-AGENTS-WIZARD-SUITE §1.1 MUTATION PROOF: PASS — the real suite ran against"
    echo "   the real root (reported, never gating), an unmutated byte-copy of the real wizard"
    echo "   passed as the control, and 8 mutations were each caught with the right"
    echo "   three-valued verdict: 4 real regressions as rc=1, each matched to the SPECIFIC"
    echo "   assertion that must fail rather than to a red run, and 4 could-not-determine"
    echo "   states as rc=2 — an absent root, an absent wizard, an empty wizard and an"
    echo "   unwritable evidence directory — none of which may read as a pass."
    exit 0
fi

[[ -d "$SCRIPT_DIR" ]] || undet "the scripts directory '$SCRIPT_DIR' does not exist"
[[ -f "$WIZARD" ]] || undet "the wizard under test is not at $WIZARD"
[[ -r "$WIZARD" ]] || undet "the wizard at $WIZARD is not readable"
[[ -s "$WIZARD" ]] || undet "the wizard at $WIZARD is empty — there is nothing to test"

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
EVIDENCE_DIR="$PROJECT_ROOT/.test-evidence/$STAMP"
mkdir -p "$EVIDENCE_DIR" 2>/dev/null \
    || undet "the evidence directory $EVIDENCE_DIR cannot be created; a run that records nothing proves nothing"
RESULTS="$EVIDENCE_DIR/results.tsv"
RUNLOG="$EVIDENCE_DIR/run.log"
printf 'id\tgroup\tname\tstatus\texpected\tactual\ttimestamp\n' > "$RESULTS"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0; TID=0
CURRENT_GROUP="-"

group() { CURRENT_GROUP="$1"; echo -e "\n${CYAN}== $1 ==${NC}" | tee -a "$RUNLOG"; }

# record <name> <status> <expected> <actual>
record() {
    local name="$1" status="$2" expected="$3" actual="$4"
    TID=$((TID+1))
    # collapse newlines/tabs so the TSV stays one row per test
    expected=$(printf '%s' "$expected" | tr '\n\t' '  ' | cut -c1-300)
    actual=$(printf '%s' "$actual"   | tr '\n\t' '  ' | cut -c1-300)
    printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$TID" "$CURRENT_GROUP" "$name" "$status" "$expected" "$actual" "$(date -u +%H:%M:%SZ)" >> "$RESULTS"
    case "$status" in
        PASS) PASS=$((PASS+1)); echo -e "  ${GREEN}✅ [$TID] $name${NC}" | tee -a "$RUNLOG" ;;
        FAIL) FAIL=$((FAIL+1)); echo -e "  ${RED}❌ [$TID] $name${NC}\n      expected: $expected\n      actual:   $actual" | tee -a "$RUNLOG" ;;
        SKIP) SKIP=$((SKIP+1)); echo -e "  ${YELLOW}⏭  [$TID] $name (skipped: $actual)${NC}" | tee -a "$RUNLOG" ;;
    esac
}

assert_eq()       { [[ "$2" == "$3" ]] && record "$1" PASS "$2" "$3" || record "$1" FAIL "$2" "$3"; }
assert_contains() { [[ "$3" == *"$2"* ]] && record "$1" PASS "contains: $2" "found" || record "$1" FAIL "contains: $2" "$3"; }
assert_absent()   { [[ "$3" != *"$2"* ]] && record "$1" PASS "absent: $2" "absent" || record "$1" FAIL "absent: $2" "PRESENT"; }
skip()            { record "$1" SKIP "-" "$2"; }

# Run a snippet inside an isolated $HOME with the wizard sourced in library mode.
in_sandbox() {
    local box; box=$(mktemp -d)
    HOME="$box" SETUP_WIZARD_LIB_ONLY=1 bash -c "
        set -uo pipefail
        . '$WIZARD'
        # The wizard sets 'set -euo pipefail' at its top, and sourcing it leaks
        # errexit into this shell. Tests deliberately run commands that exit
        # non-zero (127 checks), so errexit must be off or the shell dies
        # before the assertion can report.
        set +e
        $1
    " 2>&1
    rm -rf "$box"
}

{
echo "Test run $STAMP"
echo "wizard: $WIZARD"
echo "bash:   $BASH_VERSION"
echo "uname:  $(uname -s)/$(uname -m)"
} | tee -a "$RUNLOG"

# ==============================================================================
group "A. Static analysis of the wizard"
# ==============================================================================
out=$(bash -n "$WIZARD" 2>&1); rc=$?
assert_eq "A1 wizard is syntactically valid bash" "0" "$rc"

src=$(cat "$WIZARD")
# Strip comments: the wizard intentionally NAMES the bad package in a comment
# explaining why it was removed. The invariant is that no *executable* line
# installs it.
src_code=$(grep -vE '^[[:space:]]*#' "$WIZARD")
assert_absent "A2 no executable line installs the non-existent @qoomon/lumen" "@qoomon/lumen" "$src_code"
assert_contains "A3 lumen MCP uses the real 'stdio' subcommand" '"args": ["stdio"]' "$src"
assert_absent  "A4 lumen MCP no longer uses the bogus 'serve' subcommand" '"command": "lumen",' "$src"
assert_contains "A5 lumen MCP command is an absolute path var" '--arg lumen_bin "$LUMEN_WRAPPER"' "$src"
assert_contains "A6 submodule presence test uses -e (gitlink is a FILE)" '[[ -e "$sub_path/.git" ]]' "$src"
assert_contains "A7 library-mode guard present" 'SETUP_WIZARD_LIB_ONLY' "$src"
assert_contains "A8 setup_superspec extracted as a function" "setup_superspec() {" "$src"
# Must match a CALL SITE, not the definition: an audit deleted the only call
# and this assertion still passed.
calls=$(printf '%s\n' "$src_code" | grep -cE '^[[:space:]]*ensure_lumen[[:space:]]*$')
assert_eq "A9 ensure_lumen is actually CALLED, not just defined" "1" "$calls"

# Guessed npm names either 404 or resolve to unrelated software. Assert that no
# EXECUTABLE line installs any of them (comments documenting them are fine).
for bad in "@monday/codegraph" "@specify/cli" "@kimi/cli" "@opencode/cli" "@mimo/cli"; do
    assert_absent "A12 no executable line installs bogus package $bad" "$bad" "$src_code"
done
# `npm install -g kimi|opencode|mimo|qwen-code` (bare names) must be gone:
bare=$(printf '%s\n' "$src_code" | grep -cE 'npm install -g (kimi|opencode|mimo|qwen-code)( |$)')
assert_eq "A13 no bare-name agent CLI npm installs" "0" "$bare"
assert_contains "A14 codegraph installed from the real package" "@colbymchenry/codegraph" "$src_code"
assert_contains "A15 qwen-code installed from the real package" "@qwen-code/qwen-code" "$src_code"
assert_contains "A16 specify installed via uv, not npm" "uv tool install specify-cli" "$src_code"
assert_contains "A17 installs are guarded by a missing-check helper" "npm_install_if_missing()" "$src_code"
# Under `set -euo pipefail` an unguarded third-party installer aborts the run.
unguarded=$(printf '%s\n' "$src_code" | grep -E 'curl .*\| *(bash|sh)$' | grep -vc '||' || true)
assert_eq "A18 no unguarded 'curl | bash' can abort the wizard" "0" "$unguarded"
assert_contains "A19 glyphdown hook has a documented opt-out" "WIZARD_SKIP_GLYPHDOWN_HOOK" "$src_code"
# Must match the jq hook writer, not a banner string: an audit rewrote the hook
# to a bogus event and this assertion still passed.
# grep -c counts LINES; both ensure() calls sit on one line, so count
# OCCURRENCES with -o instead.
ev=$(printf '%s\n' "$src_code" | grep -oE 'ensure\("(Pre|Post)ToolUse"\)' | sort -u | wc -l)
assert_eq "A20 glyphdown hook writes real PreToolUse/PostToolUse events" "2" "$ev"
assert_absent  "A21 no invalid 'ToolCall' hook event" '"ToolCall"' "$src_code"
# @qwen-code/qwen-code installs a binary named `qwen`; probing `qwen-code`
# produced a false "install failed" for software that was already working.
assert_absent  "A22 does not probe the wrong qwen binary name" "npm_install_if_missing qwen-code" "$src_code"
assert_contains "A23 agent MCP paths are the verified real ones" ".kimi-code/mcp.json" "$src_code"
assert_contains "A24 opencode uses its .mcp schema, not .mcpServers" ".mcp.lumen =" "$src_code"
assert_contains "A25 project indexing is opt-in via WIZARD_INDEX_PROJECT" "WIZARD_INDEX_PROJECT" "$src_code"
# `codegraph index` DESTROYS the existing DB before rebuilding; the wizard must
# prefer the incremental `sync` when an index already exists.
assert_contains "A26 codegraph uses incremental sync when an index exists" "codegraph sync" "$src_code"
# Trailing-space grep was evadable by `codegraph index` at end-of-line.
# `codegraph init` IS used (builds where none exists); only `index` rebuilds
# destructively, deleting the DB first.
destructive=$(printf '%s\n' "$src_code" | grep -cE 'codegraph[[:space:]]+index([[:space:]]|$)')
assert_eq "A27 wizard never runs destructive 'codegraph index'" "0" "$destructive"
# Every install must be undoable: specify was the one that recorded no ACTION.
assert_contains "A28 specify install records an undo action" "uv tool uninstall specify-cli" "$src_code"
# ashlr is a Claude Code PLUGIN and never creates a binary; probing PATH for it
# produced a permanent false failure.
assert_absent  "A42 does not probe PATH for the ashlr plugin as if it were a CLI" "check_command ashlr" "$src_code"
assert_contains "A43 ashlr verified by its plugin directory" "ashlr-marketplace/ashlr" "$src_code"
# MCP registration must reach the DEFAULT config, not only the active
# CLAUDE_CONFIG_DIR, or inheriting tools (MiMo) never see Lumen.
assert_contains "A44 lumen mirrored into the default ~/.claude.json" "CLAUDE_DEFAULT_JSON" "$src_code"
# MiMo DOES support MCP (it inherits from ~/.claude.json and ships `mimo mcp`).
# The old "no documented MCP config file" text was simply untrue.
assert_absent  "A45 no stale claim that MiMo lacks MCP config" "no documented MCP config file" "$src_code"
assert_contains "A46 MiMo status is probed with 'mimo mcp list'" "mimo mcp list" "$src_code"
# A probe that can block forever is not a probe: an unbounded `lumen search`
# once hung the wizard for 10 minutes because an index run held the backend.
# A47 previously covered ONLY `lumen search`, so unbounded journalctl,
# `claude mcp`, `ollama list/ps` and `mimo mcp` probes went unnoticed - an
# independent verifier found four of them. It now covers every PROBE command.
# Long-running WORK is deliberately excluded and named: `ollama pull` downloads
# ~320MB and `lumen index` is the indexing itself; bounding those would abort
# legitimate progress.
# Only count REAL invocations. These names also appear inside strings the
# wizard PRINTS (instructions, summary lines) and inside `record_action` undo
# commands, which are stored as text and never executed here - counting those
# produced 7 false positives.
_probes='lumen search|journalctl|claude mcp|mimo mcp|ollama (list|ps)'
_pl=$(printf '%s\n' "$src_code" \
      | grep -E "(^|[^a-z0-9_-])($_probes)" \
      | grep -vE 'timeout [0-9]+ ' \
      | grep -vE '(echo |print_(info|warning|success|error)|record_action|check_command)' \
      | wc -l)
assert_eq "A47 every executed PROBE in the wizard is timeout-bounded" "0" "$_pl"
# The exclusion of long-running WORK must be deliberate and stated. This checks
# the RAW source, not $src_code, because the rationale lives in a comment and
# $src_code strips comments.
raw_src=$(cat "$WIZARD")
assert_contains "A51 long-running work is documented as deliberately unbounded" "DELIBERATELY UNBOUNDED" "$raw_src"

# WOZCODE has no public installer (npm 404). It must not be advertised as part
# of the stack, but the opt-in env hook must remain usable.
assert_absent  "A52 WOZCODE is not advertised in the stack header" "ashlr, WOZCODE" "$raw_src"
assert_contains "A53 WOZCODE_INSTALL_CMD hook is retained" "WOZCODE_INSTALL_CMD" "$src_code"

# /plugin and `claude mcp` write to the ACTIVE config dir. Detection and the
# summary must agree, or they contradict each other on a non-default dir.
_hc=$(printf '%s\n' "$src_code" | grep -c 'HOME/\.claude/' || true)
assert_eq "A54 wizard honours CLAUDE_CONFIG_DIR (no hardcoded ~/.claude)" "0" "$_hc"

# The CI gate that stops hardcoded paths coming back.
CI_YML="$PROJECT_ROOT/.github/workflows/ci.yml"
if [[ -f "$CI_YML" ]]; then
    ci=$(cat "$CI_YML")
    assert_contains "A55 CI runs the hardcoded-path audit" "audit-hardcoded-paths.sh" "$ci"
    # The old header claimed playwright.config.js hardcodes paths. It does not.
    assert_absent  "A56 CI no longer claims playwright.config.js hardcodes paths" "hard-codes the two static roots" "$ci"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import yaml,sys; yaml.safe_load(open('$CI_YML'))" 2>/dev/null \
            && record "A57 ci.yml is valid YAML" PASS "parses" "parses" \
            || record "A57 ci.yml is valid YAML" FAIL "parses" "YAML error"
    else
        skip "A57 ci.yml is valid YAML" "python3/yaml unavailable"
    fi
else
    for t in A55 A56 A57; do skip "$t CI workflow check" "ci.yml not present"; done
fi
assert_contains "A48 wizard reports steps it cannot perform itself" "ACTION REQUIRED" "$src_code"
assert_contains "A49 manual steps are persisted to a file" "MANUAL-STEPS.md" "$src_code"
# Detection must distinguish a cloned plugin from an ACTIVATED one.
assert_contains "A50 ashlr activation detected via the marketplaces dir" "plugins/marketplaces/ashlr-marketplace" "$src_code"
assert_contains "A29 telemetry opt-out is wired into the run" "configure_telemetry_optout" "$src_code"
assert_contains "A30 telemetry opt-out has an escape hatch" "WIZARD_KEEP_TELEMETRY" "$src_code"
assert_contains "A31 exports the cross-tool DO_NOT_TRACK standard" "export DO_NOT_TRACK=1" "$src_code"
# jq `//` on a boolean is a footgun: `false // "x"` yields "x". Reading a
# boolean setting must use tostring (or has()), never the // default operator.
badjq=$(printf '%s\n' "$src_code" | grep -c 'usageStatisticsEnabled // ' || true)
assert_eq "A32 boolean settings are not read with jq's // operator" "0" "$badjq"
# /api/tags answers 200 while embeddings are wedged returning NaN, so health
# must be proven with a real round-trip, not reachability.
assert_contains "A33 backend health uses a real embedding round-trip" "/api/embed" "$src_code"
assert_contains "A34 wedged-NaN backend is detected and named" "NaN" "$src_code"

# A round-trip that returns a vector still proves nothing about the vectors the
# INDEXER gets: on a Vulkan iGPU a context-filling chunk comes back as an
# all-zero vector under HTTP 200. The wizard therefore also probes the backend
# placement - and the whole value of that warning is that it is PROBED. A
# hardcoded "you are on Vulkan" would be a claim about something never measured,
# which is worse than saying nothing. See docs/setup-agents-wizard/OLLAMA-REMEDIATION.md.
assert_contains "A35 GPU residency is probed via /api/ps, not assumed" "/api/ps" "$src_code"
assert_contains "A36 backend library is read from ollama's own log line" "inference compute" "$src_code"
assert_contains "A37 the Vulkan verdict is gated on the value actually read" '"$lib" == "Vulkan"' "$src_code"
assert_contains "A38 an unreadable backend library is reported as unknown" "neither confirmed nor ruled out" "$src_code"
assert_contains "A39 the Vulkan warning points at the remediation runbook" "OLLAMA-REMEDIATION.md" "$src_code"
# The coupling itself: if the wizard names a backend anywhere in executable
# code, the probe that justifies the name must be there too.
mentions_backend=$(printf '%s\n' "$src_code" | grep -c 'Vulkan' || true)
# Count the probe MECHANISM, not the phrase: the phrase also appears in the
# message that reports an unreadable journal, which would satisfy a naive grep.
probes_backend=$(printf '%s\n' "$src_code" | grep -c 'journalctl -u ollama' || true)
if   [[ "$mentions_backend" -eq 0 ]]; then backend_claim="no-backend-claim"
elif [[ "$probes_backend"   -ge 1 ]]; then backend_claim="probed"
else                                       backend_claim="HARDCODED"; fi
assert_eq "A40 wizard never names a backend it did not probe" "probed" "$backend_claim"
# The detection is allowed to warn and NOTHING else. Restarting ollama would
# interrupt a running index; writing /etc/sysconfig/ollama or pinning
# GGML_VK_VISIBLE_DEVICES needs root. All three are the operator's call.
unsafe_remediation=$(printf '%s\n' "$src_code" \
    | grep -cE 'systemctl restart|/etc/sysconfig/ollama|GGML_VK_VISIBLE_DEVICES' || true)
assert_eq "A41 wizard never applies the remediation itself (no restart, no /etc write)" "0" "$unsafe_remediation"

steps=$(grep -oE 'print_header "Step [0-9]+' "$WIZARD" | grep -oE '[0-9]+' | tr '\n' ',')
# Step 8 (project indexing) is opt-in: its header only prints when
# WIZARD_INDEX_PROJECT is set, but the literal must still be in sequence.
# Step 7 = ollama concurrency tuning, Step 9 = provider-side CI verification.
assert_eq "A10 step headers are sequential 1..9" "1,2,3,4,5,6,7,8,9," "$steps"

# The whole point of delegating to scripts/ollama-tune.sh is that the value is
# COMPUTED on this host. A literal concurrency number in the wizard would be a
# per-host constant smuggled back in - the exact failure A40 forbids for the
# backend library. (Comments are stripped: $src_code.)
_pinned=$(printf '%s\n' "$src_code" | grep -cE 'OLLAMA_NUM_PARALLEL[[:space:]]*=[[:space:]]*[0-9]' || true)
assert_eq "A58 wizard pins no per-host ollama concurrency value" "0" "$_pinned"

if command -v shellcheck >/dev/null 2>&1; then
    sc=$(shellcheck -S error -f gcc "$WIZARD" 2>&1 | head -5)
    [[ -z "$sc" ]] && record "A11 shellcheck (severity=error) clean" PASS "no errors" "clean" \
                   || record "A11 shellcheck (severity=error) clean" FAIL "no errors" "$sc"
else
    skip "A11 shellcheck (severity=error) clean" "shellcheck not installed"
fi

# ==============================================================================
group "B. Lumen launcher unit tests (isolated \$HOME)"
# ==============================================================================
out=$(in_sandbox 'install_lumen_wrapper >/dev/null 2>&1; [[ -x "$LUMEN_WRAPPER" ]] && echo EXEC || echo NOTEXEC')
assert_eq "B1 install_lumen_wrapper produces an executable" "EXEC" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'install_lumen_wrapper >/dev/null 2>&1; bash -n "$LUMEN_WRAPPER" && echo VALID')
assert_eq "B2 generated launcher is syntactically valid bash" "VALID" "$(echo "$out" | tail -1)"

# highest-version selection: lexical sort would wrongly choose 0.0.9
out=$(in_sandbox '
    install_lumen_wrapper >/dev/null 2>&1
    for v in 0.0.9 0.0.41 0.0.100; do
        d="$HOME/.claude-shared/plugins/cache/mkt/lumen/$v/bin"
        mkdir -p "$d"
        printf "#!/bin/sh\necho %s\n" "$v" > "$d/lumen-linux-amd64"
        chmod +x "$d/lumen-linux-amd64"
    done
    "$LUMEN_WRAPPER"')
assert_eq "B3 launcher selects highest version (sort -V, not lexical)" "0.0.100" "$(echo "$out" | tail -1)"

out=$(in_sandbox '
    install_lumen_wrapper >/dev/null 2>&1
    d="$HOME/.claude-other/plugins/cache/mkt/lumen/1.2.3/bin"; mkdir -p "$d"
    printf "#!/bin/sh\necho fallback-ok\n" > "$d/lumen-linux-amd64"; chmod +x "$d/lumen-linux-amd64"
    "$LUMEN_WRAPPER"')
assert_eq "B4 launcher falls back to ~/.claude*/plugins/cache" "fallback-ok" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'install_lumen_wrapper >/dev/null 2>&1; LUMEN_BIN=/bin/echo "$LUMEN_WRAPPER" override-ok')
assert_eq "B5 LUMEN_BIN override is honoured" "override-ok" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'install_lumen_wrapper >/dev/null 2>&1; LUMEN_BIN=/nope/missing "$LUMEN_WRAPPER" version >/dev/null 2>&1; echo "rc=$?"')
assert_eq "B6 non-executable LUMEN_BIN fails with exit 127" "rc=127" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'install_lumen_wrapper >/dev/null 2>&1; "$LUMEN_WRAPPER" version 2>&1 >/dev/null | head -1')
assert_contains "B7 missing plugin yields an actionable error" "could not locate the Lumen plugin binary" "$out"

out=$(in_sandbox 'install_lumen_wrapper >/dev/null 2>&1; "$LUMEN_WRAPPER" version >/dev/null 2>&1; echo "rc=$?"')
assert_eq "B8 missing plugin exits 127 (not 0 - no silent success)" "rc=127" "$(echo "$out" | tail -1)"

# ==============================================================================
group "C. Shell configuration unit tests (isolated \$HOME)"
# ==============================================================================
out=$(in_sandbox 'configure_lumen_shell >/dev/null 2>&1; grep -cF "$LUMEN_BLOCK_START" "$HOME/.bashrc"')
assert_eq "C1 .bashrc receives exactly one lumen block" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'configure_lumen_shell >/dev/null 2>&1; grep -cF "$USERBIN_BLOCK_START" "$HOME/.bash_profile"')
assert_eq "C2 .bash_profile receives the login-shell PATH block" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'configure_lumen_shell >/dev/null 2>&1; configure_lumen_shell >/dev/null 2>&1; configure_lumen_shell >/dev/null 2>&1; grep -cF "$LUMEN_BLOCK_START" "$HOME/.bashrc"')
assert_eq "C3 idempotent: 3 runs still leave exactly one .bashrc block" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'configure_lumen_shell >/dev/null 2>&1; configure_lumen_shell >/dev/null 2>&1; grep -cF "$USERBIN_BLOCK_START" "$HOME/.bash_profile"')
assert_eq "C4 idempotent: .bash_profile block not duplicated" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'configure_lumen_shell >/dev/null 2>&1; bash -n "$HOME/.bashrc" && echo VALID')
assert_eq "C5 generated .bashrc is syntactically valid bash" "VALID" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'configure_lumen_shell >/dev/null 2>&1; bash -n "$HOME/.bash_profile" && echo VALID')
assert_eq "C6 generated .bash_profile is syntactically valid bash" "VALID" "$(echo "$out" | tail -1)"

# The PATH guard must survive into the file UNEXPANDED, else it hardcodes the
# installing user's home directory into every future shell.
out=$(in_sandbox 'configure_lumen_shell >/dev/null 2>&1; grep -c "case \":\$PATH:\"" "$HOME/.bashrc"')
assert_eq "C7 PATH guard written literally (\$PATH not expanded at install)" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox 'configure_lumen_shell >/dev/null 2>&1; n=$(bash -c ". \"$HOME/.bashrc\" 2>/dev/null; tr \":\" \"\n\" <<<\"\$PATH\" | grep -cx \"\$HOME/.local/bin\""); echo "$n"')
assert_eq "C8 sourcing .bashrc adds ~/.local/bin exactly once" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox '
    touch "$HOME/.bashrc"; chmod 600 "$HOME/.bashrc"
    configure_lumen_shell >/dev/null 2>&1
    configure_lumen_shell >/dev/null 2>&1
    stat -c %a "$HOME/.bashrc"')
assert_eq "C9 strip_managed_block preserves file mode 600" "600" "$(echo "$out" | tail -1)"

out=$(in_sandbox '
    printf "export SENTINEL=keepme\n" > "$HOME/.bashrc"
    configure_lumen_shell >/dev/null 2>&1
    configure_lumen_shell >/dev/null 2>&1
    grep -c "SENTINEL=keepme" "$HOME/.bashrc"')
assert_eq "C10 pre-existing .bashrc content is preserved across re-runs" "1" "$(echo "$out" | tail -1)"

# ==============================================================================
group "D. MCP configuration unit tests (isolated \$HOME)"
# ==============================================================================
if command -v jq >/dev/null 2>&1; then
    out=$(in_sandbox 'configure_mcp_for_agent "$HOME/.a/mcp.json" TestAgent >/dev/null 2>&1; jq -r ".mcpServers.lumen.args[0]" "$HOME/.a/mcp.json"')
    assert_eq "D1 lumen MCP args are [\"stdio\"]" "stdio" "$(echo "$out" | tail -1)"

    out=$(in_sandbox 'configure_mcp_for_agent "$HOME/.a/mcp.json" TestAgent >/dev/null 2>&1; jq -r ".mcpServers.lumen.command" "$HOME/.a/mcp.json"')
    assert_contains "D2 lumen MCP command is an absolute path" "/.local/bin/lumen" "$out"

    out=$(in_sandbox 'configure_mcp_for_agent "$HOME/.a/mcp.json" T >/dev/null 2>&1; jq -e . "$HOME/.a/mcp.json" >/dev/null && echo VALIDJSON')
    assert_eq "D3 produced config is valid JSON" "VALIDJSON" "$(echo "$out" | tail -1)"

    out=$(in_sandbox '
        mkdir -p "$HOME/.a"; printf "{\"existing\":\"keep\"}" > "$HOME/.a/mcp.json"
        configure_mcp_for_agent "$HOME/.a/mcp.json" T >/dev/null 2>&1
        jq -r ".existing" "$HOME/.a/mcp.json"')
    assert_eq "D4 pre-existing config keys are preserved" "keep" "$(echo "$out" | tail -1)"

    out=$(in_sandbox '
        configure_mcp_for_agent "$HOME/.a/mcp.json" T >/dev/null 2>&1
        configure_mcp_for_agent "$HOME/.a/mcp.json" T >/dev/null 2>&1
        jq -r ".mcpServers | keys | length" "$HOME/.a/mcp.json"')
    assert_eq "D5 idempotent: re-running does not duplicate MCP servers" "2" "$(echo "$out" | tail -1)"
else
    for t in D1 D2 D3 D4 D5; do skip "$t MCP config test" "jq not installed"; done
fi

# ==============================================================================
group "E. SuperSpec submodule safety (data-loss regression)"
# ==============================================================================
# E1 is THE regression test: a registered submodule has .git as a FILE, and the
# original `[[ -d .../.git ]]` test made the script rm -rf it on every run.
box=$(mktemp -d)
(
  cd "$box"
  git init -q parent && cd parent
  git config user.email t@t; git config user.name t
  mkdir -p submodules/superspec
  # simulate a submodule checkout: .git is a gitlink FILE, not a directory
  printf 'gitdir: ../../.git/modules/submodules/superspec\n' > submodules/superspec/.git
  printf 'canary\n' > submodules/superspec/IMPORTANT.txt
) >/dev/null 2>&1
out=$(cd "$box/parent" && SETUP_WIZARD_LIB_ONLY=1 bash -c ". '$WIZARD'; setup_superspec '$box/parent' 'submodules/superspec'" 2>&1)
canary_survived=$([[ -f "$box/parent/submodules/superspec/IMPORTANT.txt" ]] && echo SURVIVED || echo DELETED)
assert_eq "E1 REGRESSION: gitlink submodule is NOT deleted" "SURVIVED" "$canary_survived"
assert_contains "E2 gitlink submodule reported as a submodule" "git submodule" "$out"
rm -rf "$box"

# E3: a stale, non-git directory SHOULD still be replaced.
box=$(mktemp -d)
mkdir -p "$box/parent/submodules/superspec"
printf 'stale\n' > "$box/parent/submodules/superspec/stale.txt"
(cd "$box/parent" && git init -q . && git config user.email t@t && git config user.name t) >/dev/null 2>&1
out=$(cd "$box/parent" && SETUP_WIZARD_LIB_ONLY=1 bash -c ". '$WIZARD'; setup_superspec '$box/parent' 'submodules/superspec'" 2>&1)
assert_contains "E3 stale non-git directory is reported for removal" "stale non-git directory" "$out"
rm -rf "$box"

# ==============================================================================
group "F. Live integration (real environment)"
# ==============================================================================
if [[ $RUN_LIVE -eq 0 ]]; then
    for t in F1 F2 F3 F4 F5 F6 F7; do skip "$t live check" "--no-live"; done
else
    v=$(command -v lumen >/dev/null 2>&1 && lumen version 2>/dev/null || echo MISSING)
    [[ "$v" != "MISSING" && -n "$v" ]] && record "F1 lumen resolves on PATH and reports a version" PASS "a version" "$v" \
                                       || record "F1 lumen resolves on PATH and reports a version" FAIL "a version" "$v"

    for shell_desc in "login+noninteractive:-lc" "login+interactive:-lic" "interactive:-ic"; do
        d=${shell_desc%%:*}; f=${shell_desc##*:}
        r=$(TMX_SKIP=1 bash $f 'command -v lumen' 2>/dev/null | tail -1)
        [[ -n "$r" ]] && record "F2 lumen on PATH in $d shell" PASS "a path" "$r" \
                      || record "F2 lumen on PATH in $d shell" FAIL "a path" "NOT FOUND"
    done

    host="${OLLAMA_HOST:-http://localhost:11434}"
    if curl -sf --max-time 5 "$host/api/tags" >/dev/null 2>&1; then
        record "F3 embedding backend reachable" PASS "HTTP 200 from $host" "reachable"
    else
        record "F3 embedding backend reachable" FAIL "HTTP 200 from $host" "unreachable"
    fi

    model="${LUMEN_EMBED_MODEL:-ordis/jina-embeddings-v2-base-code}"
    if command -v ollama >/dev/null 2>&1 && ollama list 2>/dev/null | grep -qF "$model"; then
        record "F4 embedding model present" PASS "$model" "present"
    else
        record "F4 embedding model present" FAIL "$model" "absent"
    fi

    if command -v lumen >/dev/null 2>&1; then
        # Cobra emits TWO registration lines - one per compopt branch:
        #   complete -o default -F __start_lumen lumen
        #   complete -o default -o nospace -F __start_lumen lumen
        # Match both with a regex rather than an exact string.
        c=$(lumen completion bash 2>/dev/null | grep -cE "^[[:space:]]*complete .*-F __start_lumen lumen$")
        assert_eq "F5 bash completion registers __start_lumen (both compopt branches)" "2" "$c"
        f=$(lumen completion bash 2>/dev/null | grep -c "^__start_lumen()")
        assert_eq "F5b completion defines the __start_lumen function" "1" "$f"
    else
        skip "F5 bash completion registers" "lumen missing"
    fi

    # True end-to-end: index a fixture repo, then semantically search it.
    if command -v lumen >/dev/null 2>&1 && curl -sf --max-time 5 "$host/api/tags" >/dev/null 2>&1; then
        fx=$(mktemp -d 2>/dev/null)
        (cd "$fx" && git init -q .
         printf 'def verify_password(user, pw):\n    """Check the password against the stored bcrypt hash."""\n    return bcrypt.checkpw(pw, user.hash)\n' > auth.py
         printf 'def charge_invoice(cust, cents):\n    """Charge a saved card for an outstanding invoice."""\n    return stripe.Charge.create(customer=cust, amount=cents)\n' > billing.py
         git add -A && git -c user.email=t@t -c user.name=t commit -qm i) >/dev/null 2>&1
        # Timeouts are generous: embedding is CPU-bound and several projects can
        # be indexing concurrently against the same ollama backend, which has
        # been measured to stretch a 19s fixture index to 78s. A timeout here
        # means "backend saturated", NOT "feature broken" - so it is reported as
        # SKIP rather than a misleading FAIL.
        # Guard the fixture itself. If mktemp or the git init failed, `lumen
        # index ""` prints its usage text and the assertion below would report a
        # misleading product FAIL for a broken test fixture.
        if [[ -z "$fx" || ! -d "$fx" || ! -f "$fx/auth.py" ]]; then
            skip "F6 fixture repo indexes successfully" "fixture could not be created"
            skip "F7 semantic search returns the password function" "fixture could not be created"
            skip "F8 semantic search excludes the unrelated billing file" "fixture could not be created"
            idx_rc=0; idx_out="SKIPPED"; fx=""
        else
        idx_out=$(timeout 600 lumen index "$fx" 2>&1); idx_rc=$?
        if [[ $idx_rc -eq 124 || $idx_rc -eq 143 ]]; then
            busy=$(pgrep -fc "lumen-linux-amd64 index" 2>/dev/null || echo "?")
            skip "F6 fixture repo indexes successfully" "index timed out; $busy concurrent indexers"
            skip "F7 semantic search returns the password function" "index timed out"
            skip "F8 semantic search excludes the unrelated billing file" "index timed out"
        else
            assert_contains "F6 fixture repo indexes successfully" "Indexed" "$(echo "$idx_out" | tail -1)"
            res=$(timeout 300 lumen search "how are user passwords checked" --cwd "$fx" -p "$fx" -n 1 --summary 2>&1); s_rc=$?
            if [[ $s_rc -eq 124 || $s_rc -eq 143 ]]; then
                busy=$(pgrep -fc "lumen-linux-amd64 index" 2>/dev/null || echo "?")
                skip "F7 semantic search returns the password function" "search timed out; $busy concurrent indexers"
                skip "F8 semantic search excludes the unrelated billing file" "search timed out"
            elif [[ -z "${res//[[:space:]]/}" ]]; then
                # Guard against a false PASS on F8: an empty result set trivially
                # "excludes" billing.py while proving nothing.
                record "F7 semantic search returns the password function" FAIL "verify_password" "EMPTY RESULT SET"
                skip "F8 semantic search excludes the unrelated billing file" "no results to evaluate"
            else
                assert_contains "F7 semantic search returns the password function" "verify_password" "$res"
                assert_absent  "F8 semantic search excludes the unrelated billing file" "billing.py" "$res"
            fi
        fi
        fi
        if [[ -n "$fx" ]]; then
            lumen purge "$fx" >/dev/null 2>&1 || true
            rm -rf "$fx"
        fi
    else
        for t in F6 F7 F8; do skip "$t end-to-end index+search" "lumen or backend unavailable"; done
    fi
fi

# ==============================================================================
group "H. Telemetry opt-out (isolated \$HOME)"
# ==============================================================================
out=$(in_sandbox '
    export WIZARD_STATE_DIR="$HOME/state"; backup_init >/dev/null 2>&1
    configure_telemetry_optout >/dev/null 2>&1
    grep -cF "$PRIVACY_BLOCK_START" "$HOME/.bashrc"')
assert_eq "H1 writes exactly one telemetry opt-out block" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox '
    export WIZARD_STATE_DIR="$HOME/state"; backup_init >/dev/null 2>&1
    configure_telemetry_optout >/dev/null 2>&1
    configure_telemetry_optout >/dev/null 2>&1
    grep -cF "$PRIVACY_BLOCK_START" "$HOME/.bashrc"')
assert_eq "H2 idempotent across repeated runs" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox '
    export WIZARD_STATE_DIR="$HOME/state"; backup_init >/dev/null 2>&1
    configure_telemetry_optout >/dev/null 2>&1
    bash -n "$HOME/.bashrc" && echo VALID')
assert_eq "H3 generated .bashrc stays syntactically valid" "VALID" "$(echo "$out" | tail -1)"

out=$(in_sandbox '
    export WIZARD_STATE_DIR="$HOME/state"; backup_init >/dev/null 2>&1
    configure_telemetry_optout >/dev/null 2>&1
    bash -c ". \"$HOME/.bashrc\" >/dev/null 2>&1; echo \"$DO_NOT_TRACK/$CODEGRAPH_TELEMETRY\""')
assert_eq "H4 sourcing .bashrc actually exports the opt-out vars" "1/0" "$(echo "$out" | tail -1)"

out=$(in_sandbox '
    export WIZARD_STATE_DIR="$HOME/state"; backup_init >/dev/null 2>&1
    WIZARD_KEEP_TELEMETRY=1 configure_telemetry_optout >/dev/null 2>&1
    grep -cF "$PRIVACY_BLOCK_START" "$HOME/.bashrc" 2>/dev/null || echo 0')
assert_eq "H5 WIZARD_KEEP_TELEMETRY leaves settings untouched" "0" "$(echo "$out" | tail -1)"

if command -v jq >/dev/null 2>&1; then
    out=$(in_sandbox '
        export WIZARD_STATE_DIR="$HOME/state"; backup_init >/dev/null 2>&1
        mkdir -p "$HOME/.qwen"; printf "{\"model\":\"keep\"}" > "$HOME/.qwen/settings.json"
        configure_telemetry_optout >/dev/null 2>&1
        jq -c "{u:.usageStatisticsEnabled, m:.model}" "$HOME/.qwen/settings.json"')
    assert_eq "H6 disables Qwen usage stats without losing existing keys" '{"u":false,"m":"keep"}' "$(echo "$out" | tail -1)"
    # REGRESSION: jq's `//` operator returns the RHS when the LHS is null OR
    # FALSE, so `.usageStatisticsEnabled // "unset"` reads a correctly-set
    # `false` back as "unset". That made the wizard report "not disabled" for a
    # setting it had just disabled. Second run must detect it as already done.
    out=$(in_sandbox '
        export WIZARD_STATE_DIR="$HOME/state"; backup_init >/dev/null 2>&1
        mkdir -p "$HOME/.qwen"; printf "{\"usageStatisticsEnabled\":false}" > "$HOME/.qwen/settings.json"
        configure_telemetry_optout 2>&1 | grep -c "already disabled"')
    assert_eq "H7 REGRESSION: a value of false is read as false, not 'unset'" "1" "$(echo "$out" | tail -1)"
else
    for t in H6 H7; do skip "$t qwen usage stats opt-out" "jq not installed"; done
fi

# ==============================================================================
group "G. Backup manifest and rollback (isolated \$HOME)"
# ==============================================================================
ROLLBACK="$SCRIPT_DIR/rollback-agents-wizard.sh"
out=$(bash -n "$ROLLBACK" 2>&1); rc=$?
assert_eq "G1 rollback script is syntactically valid bash" "0" "$rc"

# Simulate a wizard run: snapshot an existing file, modify it, snapshot a file
# that does not exist yet, create it. Then roll the whole thing back.
sim='
    export WIZARD_STATE_DIR="$HOME/state"
    backup_init >/dev/null 2>&1
    printf "ORIGINAL\n" > "$HOME/existing.conf"; chmod 600 "$HOME/existing.conf"
    snapshot_before demo "$HOME/existing.conf"
    printf "MODIFIED-BY-WIZARD\n" > "$HOME/existing.conf"
    snapshot_before demo "$HOME/brand-new.conf"
    printf "CREATED-BY-WIZARD\n" > "$HOME/brand-new.conf"
    record_action demo "echo undo-me"
'

out=$(in_sandbox "$sim"'
    head -1 "$WIZARD_STATE_DIR/backups/latest/manifest.tsv"')
assert_contains "G2 manifest has a TSV header" "component" "$out"

out=$(in_sandbox "$sim"'
    awk -F"\t" "NR>1 && \$3 ~ /existing.conf/ {print \$2}" "$WIZARD_STATE_DIR/backups/latest/manifest.tsv"')
assert_eq "G3 pre-existing file recorded as MODIFIED" "MODIFIED" "$(echo "$out" | tail -1)"

out=$(in_sandbox "$sim"'
    awk -F"\t" "NR>1 && \$3 ~ /brand-new.conf/ {print \$2}" "$WIZARD_STATE_DIR/backups/latest/manifest.tsv"')
assert_eq "G4 not-yet-existing file recorded as CREATED" "CREATED" "$(echo "$out" | tail -1)"

# The stored copy must be the ORIGINAL content, not the post-change content.
out=$(in_sandbox "$sim"'
    b=$(awk -F"\t" "NR>1 && \$3 ~ /existing.conf/ {print \$4}" "$WIZARD_STATE_DIR/backups/latest/manifest.tsv"); cat "$b"')
assert_eq "G5 backup stores the ORIGINAL content" "ORIGINAL" "$(echo "$out" | tail -1)"

# Snapshotting the same file twice must keep the FIRST (true original).
out=$(in_sandbox "$sim"'
    printf "SECOND-CHANGE\n" > "$HOME/existing.conf"
    snapshot_before demo "$HOME/existing.conf"
    awk -F"\t" "NR>1 && \$3 ~ /existing.conf/" "$WIZARD_STATE_DIR/backups/latest/manifest.tsv" | wc -l')
assert_eq "G6 re-snapshotting keeps only the first (true original)" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox "$sim"'
    stat -c %a "$(awk -F"\t" "NR>1 && \$3 ~ /existing.conf/ {print \$4}" "$WIZARD_STATE_DIR/backups/latest/manifest.tsv")"')
assert_eq "G7 backup preserves file mode 600" "600" "$(echo "$out" | tail -1)"

# --- Actual rollback ---
out=$(in_sandbox "$sim"'
    '"$ROLLBACK"' --yes >/dev/null 2>&1; cat "$HOME/existing.conf"')
assert_eq "G8 rollback restores the modified file byte-exactly" "ORIGINAL" "$(echo "$out" | tail -1)"

out=$(in_sandbox "$sim"'
    '"$ROLLBACK"' --yes >/dev/null 2>&1; [[ -e "$HOME/brand-new.conf" ]] && echo STILL_THERE || echo DELETED')
assert_eq "G9 rollback deletes the file the wizard created" "DELETED" "$(echo "$out" | tail -1)"

out=$(in_sandbox "$sim"'
    '"$ROLLBACK"' --dry-run --yes >/dev/null 2>&1; cat "$HOME/existing.conf"')
assert_eq "G10 --dry-run changes nothing" "MODIFIED-BY-WIZARD" "$(echo "$out" | tail -1)"

# Component filter must not touch other components.
out=$(in_sandbox "$sim"'
    '"$ROLLBACK"' --component lumen --yes >/dev/null 2>&1; cat "$HOME/existing.conf"')
assert_eq "G11 component filter leaves other components alone" "MODIFIED-BY-WIZARD" "$(echo "$out" | tail -1)"

out=$(in_sandbox "$sim"'
    '"$ROLLBACK"' --component demo --yes >/dev/null 2>&1; cat "$HOME/existing.conf"')
assert_eq "G12 component filter rolls back the selected component" "ORIGINAL" "$(echo "$out" | tail -1)"

# Rollback must itself be reversible.
out=$(in_sandbox "$sim"'
    '"$ROLLBACK"' --yes >/dev/null 2>&1; ls -d "$WIZARD_STATE_DIR"/backups/*/pre-rollback-* 2>/dev/null | grep -v "/latest/" | wc -l')
# NOTE: the glob must exclude backups/latest, which is a symlink to the real
# session dir and would otherwise count the same snapshot twice.
assert_eq "G13 rollback saves a pre-rollback snapshot (reversible)" "1" "$(echo "$out" | tail -1)"

out=$(in_sandbox "$sim"'
    '"$ROLLBACK"' --yes 2>&1 | grep -c "manual .*echo undo-me"')
# Reported twice by design: once in the plan, once while applying. What matters
# is that it is REPORTED and never executed without --run-actions.
assert_eq "G14 non-file ACTION is reported, not silently executed" "2" "$(echo "$out" | tail -1)"

out=$(in_sandbox "$sim"'
    '"$ROLLBACK"' --list 2>&1 | grep -c "changes"')
assert_eq "G15 --list enumerates sessions" "1" "$(echo "$out" | tail -1)"

# REGRESSION: an agent config that did NOT exist must be recorded CREATED, not
# MODIFIED. The wizard used to seed `{}` before snapshotting, so rollback left
# an empty {} file behind instead of removing the file entirely.
if command -v jq >/dev/null 2>&1; then
    sim2='
        export WIZARD_STATE_DIR="$HOME/state"
        backup_init >/dev/null 2>&1
        configure_mcp_for_agent "$HOME/.newagent/mcp.json" TestAgent newagent >/dev/null 2>&1
    '
    out=$(in_sandbox "$sim2"'
        awk -F"\t" "NR>1 && \$3 ~ /newagent/ {print \$2}" "$WIZARD_STATE_DIR/backups/latest/manifest.tsv" | head -1')
    assert_eq "G16 REGRESSION: brand-new agent config recorded CREATED not MODIFIED" "CREATED" "$(echo "$out" | tail -1)"

    out=$(in_sandbox "$sim2"'
        '"$ROLLBACK"' --yes >/dev/null 2>&1
        [[ -e "$HOME/.newagent/mcp.json" ]] && echo STILL_THERE || echo DELETED')
    assert_eq "G17 REGRESSION: rollback deletes it rather than leaving an empty {}" "DELETED" "$(echo "$out" | tail -1)"

    # A config that DID exist must still be restored to its real content.
    sim3='
        export WIZARD_STATE_DIR="$HOME/state"
        backup_init >/dev/null 2>&1
        mkdir -p "$HOME/.oldagent"
        printf "{\"keepme\":1}" > "$HOME/.oldagent/mcp.json"
        configure_mcp_for_agent "$HOME/.oldagent/mcp.json" TestAgent oldagent >/dev/null 2>&1
    '
    out=$(in_sandbox "$sim3"'
        '"$ROLLBACK"' --yes >/dev/null 2>&1; jq -c . "$HOME/.oldagent/mcp.json"')
    assert_eq "G18 pre-existing config restores to its true original" '{"keepme":1}' "$(echo "$out" | tail -1)"
else
    for t in G16 G17 G18; do skip "$t manifest CREATED/MODIFIED regression" "jq not installed"; done
fi

# ==============================================================================
group "I. Operational scripts (remediation / reindex / doctor)"
# ==============================================================================
REMED="$SCRIPT_DIR/ollama-vulkan-remediation.sh"
REIDX="$SCRIPT_DIR/lumen-reindex.sh"
DOCTOR="$SCRIPT_DIR/lumen-index-doctor.sh"

for pair in "I1:$REMED:remediation" "I2:$REIDX:reindex" "I3:$DOCTOR:doctor"; do
    id=${pair%%:*}; rest=${pair#*:}; f=${rest%:*}; nm=${rest##*:}
    if [[ -x "$f" ]]; then
        bash -n "$f" 2>/dev/null && record "$id $nm script is executable and parses" PASS "rc=0" "rc=0" \
                                 || record "$id $nm script is executable and parses" FAIL "rc=0" "syntax error"
    else
        record "$id $nm script is executable and parses" FAIL "executable" "missing or not executable"
    fi
done

rsrc=$(cat "$REMED" 2>/dev/null)
# The remediation script is the ONLY place allowed to touch the service, and it
# must never do so without an explicit subcommand.
assert_contains "I4 remediation offers a read-only --check" "--check)" "$rsrc"
assert_contains "I5 remediation offers --rollback" "--rollback)" "$rsrc"
defaulted=$(printf '%s\n' "$rsrc" | grep -c 'case "${1:---check}"')
assert_eq "I6 remediation defaults to the read-only action" "1" "$defaulted"

# Failure mode 4 (stale duplicates) is invisible per-vector. Both the probe and
# the doctor must test AGGREGATE distinctness, or they repeat the audit's error.
assert_contains "I7 remediation probes aggregate vector distinctness" "distinct" "$rsrc"
dsrc=$(cat "$DOCTOR" 2>/dev/null)
assert_contains "I8 doctor checks duplicate-vector groups" "duplicate-vector group" "$dsrc"
assert_contains "I9 doctor still runs the per-vector NaN/zero checks" "all-zero" "$dsrc"
assert_contains "I10 doctor opens the DB read-only" "mode=ro" "$dsrc"

isrc=$(cat "$REIDX" 2>/dev/null)
assert_contains "I11 reindex refuses to start on a Vulkan backend" "REFUSING TO START" "$isrc"
# Behavioural, not a grep: --force must actually reach `lumen index -f`.
forcearm=$(printf '%s\n' "$isrc" | grep -c -- '--force)')
passesf=$(printf '%s\n' "$isrc" | grep -c 'args=(-f "\$PROJ")')
assert_eq "I12 reindex --force is parsed and reaches 'lumen index -f'" "1 1" "$forcearm $passesf"
# A corrupted file keeps its hash, so an incremental run skips it forever.
assert_contains "I13 reindex documents why --force is required after corruption" "skips them forever" "$isrc"
# No operational script may escalate privileges implicitly.
noesc=$(printf '%s\n' "$isrc" "$dsrc" | grep -c 'sudo ' || true)
assert_eq "I14 reindex and doctor never call sudo" "0" "$noesc"

# BEHAVIOURAL: a typo used to be silently ignored, giving an incremental run
# when a full rebuild was intended.
bash "$REIDX" /tmp --forse >/dev/null 2>&1; rc=$?
assert_eq "I15 reindex rejects an unknown flag instead of ignoring it" "2" "$rc"

# The Vulkan refusal is worthless if the library probe returns UNKNOWN on a busy
# host. It must scan from the service start, not a fixed journal tail.
assert_contains "I16 reindex reads library= from ActiveEnterTimestamp" "ActiveEnterTimestamp" "$isrc"
# NOTE: a substring check for "-n 400" also matches the new "-n 4000" fallback,
# so assert the fallback depth explicitly instead of asserting an absence.
assert_contains "I17 reindex fallback scans a deep journal window, not a short tail" "-n 4000" "$isrc"

# --check previously ALWAYS exited 0, so automation passed on a corrupting backend.
assert_contains "I18 remediation --check returns a real exit code" "return \$rc" "$rsrc"

# The doctor claimed to check dimensionality but never did.
assert_contains "I19 doctor reads vector width from the index" "vec_dimensions" "$dsrc"
assert_absent  "I20 doctor has no dead wrongdim variable" "wrongdim" "$dsrc"
# I21 WAS a grep of the doctor's source and ran it ZERO times. An independent
# verifier deleted the entire guard and the assertion stayed green. It is now
# BEHAVIOURAL: build an index that makes the decoder crash and require exit 2,
# because exit 1 means "corruption found" and a crash is not that.
if command -v python3 >/dev/null 2>&1; then
    dbox=$(mktemp -d); mkdir -p "$dbox/store/x"
    python3 - "$dbox" <<'PYX'
import sqlite3, sys, os
d = sys.argv[1]; db = os.path.join(d, "store", "x", "index.db")
c = sqlite3.connect(db)
c.execute("CREATE TABLE project_meta(key TEXT, value TEXT)")
c.execute("INSERT INTO project_meta VALUES('project_path',?)", (d,))
c.execute("CREATE TABLE files(path TEXT, hash TEXT)")
c.execute("CREATE TABLE chunks(id INTEGER, file_path TEXT, symbol TEXT, kind TEXT, start_line INT, end_line INT)")
c.commit(); c.close()
PYX
    LUMEN_STORE="$dbox/store" bash "$DOCTOR" "$dbox" >/dev/null 2>&1; rc=$?
    assert_eq "I21 doctor exits 2 (not 1) when it CANNOT inspect the index" "2" "$rc"

    # And a genuinely absent index must also be 2, never 1.
    ebox=$(mktemp -d)
    bash "$DOCTOR" "$ebox" >/dev/null 2>&1; rc=$?
    assert_eq "I22 doctor exits 2 when no index exists for the project" "2" "$rc"

    # REGRESSION: sqlite-vec allocates 1024-slot blocks and marks live slots in
    # a per-block `validity` bitmap. Freed/unwritten slots still hold bytes.
    # An earlier revision decoded ALL allocated slots and reported 43 duplicate
    # groups / 2.05% where the true live figure was 1 group / 0.32% - crying
    # corruption over garbage. Build an index whose FREED slots are byte-identical
    # and require the doctor to stay silent about them.
    vbox=$(mktemp -d); mkdir -p "$vbox/store/v"
    python3 - "$vbox" <<'PYV'
import sqlite3, sys, os, struct
d = sys.argv[1]; db = os.path.join(d, "store", "v", "index.db")
c = sqlite3.connect(db)
c.execute("CREATE TABLE project_meta(key TEXT, value TEXT)")
c.execute("INSERT INTO project_meta VALUES('project_path',?)", (d,))
c.execute("INSERT INTO project_meta VALUES('vec_dimensions','768')")
c.execute("CREATE TABLE files(path TEXT, hash TEXT)")
c.execute("INSERT INTO files VALUES('a.py','h1')")
c.execute("CREATE TABLE chunks(id INTEGER, file_path TEXT, symbol TEXT, kind TEXT, start_line INT, end_line INT)")
c.execute("CREATE TABLE vec_chunks_rowids(rowid INTEGER, chunk_id INTEGER, chunk_offset INTEGER)")
c.execute("CREATE TABLE vec_chunks_chunks(rowid INTEGER PRIMARY KEY, validity BLOB, rowids BLOB)")
c.execute("CREATE TABLE vec_chunks_vector_chunks00(rowid INTEGER PRIMARY KEY, vectors BLOB)")
DIM = 768
# 4 slots: 2 live and DISTINCT, 2 freed and IDENTICAL to each other.
live1 = struct.pack("<%df" % DIM, *([1.0] + [0.0]*(DIM-1)))
live2 = struct.pack("<%df" % DIM, *([0.0, 1.0] + [0.0]*(DIM-2)))
dead  = struct.pack("<%df" % DIM, *([0.5]*DIM))
blob = live1 + live2 + dead + dead
validity = bytearray(128)          # 1024 bits
validity[0] = 0b00000011           # slots 0,1 live; 2,3 freed
c.execute("INSERT INTO vec_chunks_chunks VALUES(1,?,?)", (bytes(validity), b"\0"*8192))
c.execute("INSERT INTO vec_chunks_vector_chunks00 VALUES(1,?)", (blob,))
for i in (1, 2):
    c.execute("INSERT INTO chunks VALUES(?,'a.py','s','function',1,2)", (i,))
    c.execute("INSERT INTO vec_chunks_rowids VALUES(?,?,0)", (i, i))
c.commit(); c.close()
PYV
    out=$(LUMEN_STORE="$vbox/store" bash "$DOCTOR" "$vbox" 2>&1); rc=$?
    assert_eq "I23 doctor ignores freed slots (identical dead vectors are NOT corruption)" "0" "$rc"
    assert_contains "I24 doctor reports how many slots were freed" "freed/unwritten" "$out"
    rm -rf "$dbox" "$ebox" "$vbox"
else
    for t in I21 I22; do skip "$t doctor exit-code behaviour" "python3 unavailable"; done
fi

# ==============================================================================
group "J. Hardcoded-path audit"
# ==============================================================================
AUDIT="$SCRIPT_DIR/audit-hardcoded-paths.sh"
# Built from fragments on purpose: writing the literal here would make this very
# file a violation of the rule it tests (J8). Concatenation keeps J8 exemption-free.
BADROOT="/Vol""umes/T7/Projects/vasic"
if [[ -x "$AUDIT" ]] && bash -n "$AUDIT" 2>/dev/null; then
    record "J1 audit script is executable and parses" PASS "rc=0" "rc=0"
else
    record "J1 audit script is executable and parses" FAIL "rc=0" "missing or syntax error"
fi

# Exercise it against throwaway repos so the verdicts are provable, not asserted.
mk_repo() {
    local d; d=$(mktemp -d)
    git -C "$d" init -q .
    git -C "$d" config user.email t@t; git -C "$d" config user.name t
    printf '%s' "$d"
}

# CLEAN repo -> must exit 0
box=$(mk_repo)
printf 'ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"\n' > "$box/ok.sh"
git -C "$box" add -A >/dev/null 2>&1
bash "$AUDIT" "$box" >/dev/null 2>&1; rc=$?
assert_eq "J2 exits 0 on a repo with no hardcoded paths" "0" "$rc"
rm -rf "$box"

# DIRTY repo -> must exit 1
box=$(mk_repo)
printf 'ROOT="%s"\n' "$BADROOT" > "$box/bad.sh"
git -C "$box" add -A >/dev/null 2>&1
bash "$AUDIT" "$box" >/dev/null 2>&1; rc=$?
assert_eq "J3 exits 1 when a machine-specific path is present" "1" "$rc"
rm -rf "$box"

# REGRESSION: a COMMENT describing the historical bug must not trip the audit
# that exists because of that bug. deploy-langs.sh carries exactly such a comment.
box=$(mk_repo)
printf '# ROOT was hardcoded to "%s" - a macOS path.\nROOT="$(pwd)"\n' "$BADROOT" > "$box/commented.sh"
git -C "$box" add -A >/dev/null 2>&1
bash "$AUDIT" "$box" >/dev/null 2>&1; rc=$?
assert_eq "J4 comment-only mentions do not count as violations" "0" "$rc"
rm -rf "$box"

# $HOME / ~ are not machine-specific and must be allowed
box=$(mk_repo)
printf 'STORE="${LUMEN_STORE:-$HOME/.local/share/lumen}"\nX=~/.config\n' > "$box/home.sh"
git -C "$box" add -A >/dev/null 2>&1
bash "$AUDIT" "$box" >/dev/null 2>&1; rc=$?
assert_eq "J5 \$HOME and ~ are not flagged" "0" "$rc"
rm -rf "$box"

# The allowlist must actually suppress a violation
box=$(mk_repo)
printf 'ROOT="%s"\n' "$BADROOT" > "$box/bad.sh"
printf '# unavoidable for reason X\nbad.sh\n' > "$box/.hardcoded-paths-allow"
git -C "$box" add -A >/dev/null 2>&1
bash "$AUDIT" "$box" >/dev/null 2>&1; rc=$?
assert_eq "J6 .hardcoded-paths-allow suppresses a listed file" "0" "$rc"
rm -rf "$box"

# Standard system paths must NOT be flagged - only somebody's home directory.
box=$(mk_repo)
printf 'ENVFILE=/etc/sysconfig/ollama\nB=/usr/bin/env\nT=/tmp/x\n' > "$box/sys.sh"
git -C "$box" add -A >/dev/null 2>&1
bash "$AUDIT" "$box" >/dev/null 2>&1; rc=$?
assert_eq "J7 /etc /usr /tmp are not treated as machine-specific" "0" "$rc"
rm -rf "$box"

# The scripts THIS suite ships must themselves be clean - no exemptions.
# The detector itself contains the patterns it searches for, so it is
# allowlisted by name rather than exempted from the rule.
# The pattern is assembled from fragments for the same reason as BADROOT:
# spelling it out would make this file the very violation J8 checks for.
_pat="(/Vol""umes/|/Us""ers/[A-Za-z]|/run/me""dia/[A-Za-z])"
own=$(for f in "$SCRIPT_DIR"/*.sh; do
        case "$f" in *audit-hardcoded-paths.sh) continue;; esac
        grep -vE '^[[:space:]]*#' "$f" 2>/dev/null \
          | grep -qE "$_pat" && echo "$f"
      done | wc -l)
assert_eq "J8 our own scripts contain no machine-specific paths" "0" "$own"

# ==============================================================================
group "K. Delegated host/provider probes wired into the wizard"
# ==============================================================================
# THESE ARE BEHAVIOURAL. A grep for a filename would stay green while the wiring
# is deleted - that already happened once in this suite (see I21). Every K
# assertion RUNS the wizard function against a throwaway stand-in script whose
# output carries a random token, and checks the observable result: what the
# stand-in was invoked with, what landed in the manual-step registry, and what
# landed in the rollback manifest.
#
# The stand-ins are NOT scripts/ollama-tune.sh or scripts/verify-provider-ci.sh.
# They live in a temp dir and are reached through the OLLAMA_TUNE_SCRIPT /
# PROVIDER_CI_SCRIPT overrides, so this suite never depends on those two
# scripts existing, never runs a real apply, and never restarts anything.

KBOX=$(mktemp -d)

# $1 dir  $2 token  $3 exit code for --apply  [$4 exit code for report and
# --print-commands, default 1]
#
# The real scripts/ollama-tune.sh documents a THREE-VALUED verdict in its own
# --help: `0 fine · 1 real problem · 2 COULD NOT DETERMINE`. So `1` is the
# normal "there is something to apply" case, NOT a failure — the stand-in
# defaults to it because that is the case the wizard has to get right. A first
# revision of this integration read any non-zero as "broken" and threw the
# recommendation away against the real script; K23 is the regression guard.
mk_tune_stub() {
    local dir="$1" token="$2" applyrc="$3" reportrc="${4:-1}"
    cat > "$dir/ollama-tune.sh" <<STUB
#!/usr/bin/env bash
echo "ARGS:\$*" >> "$dir/tune.log"
case "\${1:-}" in
  --print-commands)
      echo "manager=stand-in surface=$dir/ollama.conf writable=no"
      echo "── copy-pasteable commands for THIS host "
      echo "OLLAMA_NUM_PARALLEL=$token"
      echo "reload-and-restart-the-backend   # stand-in"
      echo "── exit "
      exit $reportrc ;;
  --apply)  echo "stand-in apply"; exit $applyrc ;;
  --revert) echo "stand-in revert" >> "$dir/tune.log"; exit 0 ;;
  *) echo "manager=stand-in surface=$dir/ollama.conf writable=no"
     echo "computed for this host: OLLAMA_NUM_PARALLEL=$token"
     exit $reportrc ;;
esac
STUB
    chmod +x "$dir/ollama-tune.sh"
    : > "$dir/tune.log"
}

# $1 dir  $2 exit code  $3 token
mk_provider_stub() {
    cat > "$1/verify-provider-ci.sh" <<STUB
#!/usr/bin/env bash
echo "provider finding $3"
exit $2
STUB
    chmod +x "$1/verify-provider-ci.sh"
}

# $1 dir  $2 exit code -> stands in for pgrep so "is an indexer running?" is
# decided by the test, not by whatever happens to run on the host right now.
mk_pgrep_shim() { printf '#!/usr/bin/env bash\nexit %s\n' "$2" > "$1/pgrep"; chmod +x "$1/pgrep"; }

# Everything the wizard registered as a manual step, and nothing else. Printing
# only the registry is what separates "it appeared in the manual step" from
# "it appeared somewhere in the console output".
DUMP_MANUALS='
    echo "===MANUALS==="
    if [[ ${#MANUAL_TITLES[@]} -gt 0 ]]; then
      for i in "${!MANUAL_TITLES[@]}"; do
        echo "TITLE: ${MANUAL_TITLES[$i]}"
        echo "${MANUAL_STEPS[$i]}"
      done
    fi
    echo "===END==="
    echo "MANUALCOUNT=${#MANUAL_TITLES[@]}"
'
registry() { printf '%s\n' "$1" | awk '/^===MANUALS===$/{f=1;next} /^===END===$/{f=0} f'; }

# Deterministic environment: ollama/gh are reported present so the tests
# exercise the wiring rather than this host's inventory, and the interactive
# confirmation is disabled so the suite can never block on a read.
KENV='
    export WIZARD_NONINTERACTIVE=1
    check_command() { case "$1" in ollama|gh) return 0;; *) command -v "$1" >/dev/null 2>&1;; esac; }
'

# ---- K1-K3: both delegates ABSENT. The wizard must survive and say so. -------
out=$(in_sandbox "$KENV"'
    export OLLAMA_TUNE_SCRIPT="'"$KBOX"'/definitely-absent-tune.sh"
    tune_ollama_step; echo "TUNE_RC=$?"
'"$DUMP_MANUALS")
assert_contains "K1 missing ollama tuner does not abort the wizard" "TUNE_RC=0" "$out"
assert_contains "K1b missing ollama tuner is reported, not silently skipped" "concurrency was NOT measured" "$out"
kreg=$(registry "$out")
assert_contains "K2 missing ollama tuner still registers a manual step" "UNTUNED and UNMEASURED" "$kreg"
# The failure this guards against: filling the gap with a plausible example.
_fab=$(printf '%s\n' "$kreg" | grep -cE 'OLLAMA_NUM_PARALLEL[[:space:]]*=[[:space:]]*[0-9]' || true)
assert_eq "K2b absent tuner yields NO fabricated concurrency value" "0" "$_fab"

out=$(in_sandbox "$KENV"'
    export PROVIDER_CI_SCRIPT="'"$KBOX"'/definitely-absent-provider.sh"
    verify_provider_ci_step; echo "PROV_RC=$?"
'"$DUMP_MANUALS")
assert_contains "K3 missing provider verifier does not abort the wizard" "PROV_RC=0" "$out"
kreg=$(registry "$out")
assert_contains "K3b missing provider verifier is reported UNVERIFIED" "UNVERIFIED" "$kreg"
assert_absent  "K3c missing provider verifier is never reported as clean" "no provider-generated triggering found" "$out"

# Both absent, back to back, in one run - the real degradation path.
out=$(in_sandbox "$KENV"'
    export OLLAMA_TUNE_SCRIPT="'"$KBOX"'/nope-a.sh" PROVIDER_CI_SCRIPT="'"$KBOX"'/nope-b.sh"
    tune_ollama_step && verify_provider_ci_step; echo "BOTH_RC=$?"
'"$DUMP_MANUALS")
assert_contains "K4 wizard survives BOTH delegates being absent" "BOTH_RC=0" "$out"
assert_contains "K4b both absences are recorded as manual steps" "MANUALCOUNT=2" "$out"

# ---- K5-K7: an UNWRITABLE ollama surface must produce THIS host's commands ---
KTUNE=$(mktemp -d); KTOK="tok$RANDOM$RANDOM"
mk_tune_stub "$KTUNE" "$KTOK" 1          # --apply fails: surface not writable
KPG=$(mktemp -d); mk_pgrep_shim "$KPG" 1 # no indexer running

out=$(in_sandbox "$KENV"'
    export PATH="'"$KPG"':$PATH"
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    tune_ollama_step; echo "TUNE_RC=$?"
'"$DUMP_MANUALS")
kreg=$(registry "$out")
assert_contains "K5 unwritable ollama surface registers a manual step" "TITLE: Apply the ollama concurrency" "$kreg"
# The point of the whole exercise: the step carries the value the delegate
# COMPUTED HERE. The token is random per run, so a hardcoded example cannot
# satisfy this assertion.
assert_contains "K5b manual step carries the delegate's computed value, not an example" "OLLAMA_NUM_PARALLEL=$KTOK" "$kreg"
assert_contains "K5c manual step explains why applying is not automatic" "aborts" "$kreg"
# Report mode must not have touched the host.
assert_absent  "K6 report mode never invokes --apply" "ARGS:--apply" "$(cat "$KTUNE/tune.log")"
assert_contains "K6b report mode DID ask the delegate for this host's commands" "ARGS:--print-commands" "$(cat "$KTUNE/tune.log")"

# ---- K7-K8: the destructive edge -------------------------------------------
# An indexer is running: applying would restart the backend and abort its
# in-flight embedding requests. Opt-in or not, it must not happen.
mk_tune_stub "$KTUNE" "$KTOK" 0
KPGBUSY=$(mktemp -d); mk_pgrep_shim "$KPGBUSY" 0
out=$(in_sandbox "$KENV"'
    export PATH="'"$KPGBUSY"':$PATH" WIZARD_TUNE_OLLAMA=1
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    tune_ollama_step
'"$DUMP_MANUALS")
assert_absent  "K7 opted-in apply is REFUSED while an indexer is in flight" "ARGS:--apply" "$(cat "$KTUNE/tune.log")"
assert_contains "K7b refusal names the running indexer as the reason" "indexing job is RUNNING" "$out"
assert_contains "K7c refusal still hands over the exact commands" "OLLAMA_NUM_PARALLEL=$KTOK" "$(registry "$out")"

# pgrep unavailable => "cannot tell", which must NOT be collapsed into "idle".
KPGNONE=$(mktemp -d)
mk_tune_stub "$KTUNE" "$KTOK" 0
out=$(in_sandbox "$KENV"'
    export WIZARD_TUNE_OLLAMA=1
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    _indexers_in_flight() { return 2; }
    tune_ollama_step
'"$DUMP_MANUALS")
assert_absent  "K8 apply is REFUSED when indexer state cannot be determined" "ARGS:--apply" "$(cat "$KTUNE/tune.log")"
assert_contains "K8b unknown indexer state is named as unknown" "cannot tell whether an indexer is running" "$out"

# ---- K9-K12: the opt-in path really works (so K6/K7/K8 are not vacuous) -----
mk_tune_stub "$KTUNE" "$KTOK" 0
out=$(in_sandbox "$KENV"'
    export PATH="'"$KPG"':$PATH" WIZARD_TUNE_OLLAMA=1 WIZARD_STATE_DIR="$HOME/state"
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    backup_init >/dev/null 2>&1
    tune_ollama_step >/dev/null 2>&1
    cat "$WIZARD_STATE_DIR/backups/latest/manifest.tsv"
')
assert_contains "K9 opted-in + idle + confirmed DOES apply (K6/K7/K8 are not vacuous)" "ARGS:--apply" "$(cat "$KTUNE/tune.log")"
# Read the ACTION row's target specifically. Grepping the whole manifest for
# "--revert" would also match the NOTE row's prose, so a deleted undo action
# would still look present.
kact=$(printf '%s\n' "$out" | awk -F'\t' '$1=="ollama" && $2=="ACTION"{print $3}')
assert_contains "K10 applying records the delegate's --revert as the undo command" "--revert" "$kact"
assert_contains "K10b the undo command targets the script the wizard RESOLVED, not a literal" "$KTUNE/ollama-tune.sh" "$kact"
# The restart aborted whatever was in flight. `--revert` restarts again; it
# cannot resurrect those requests. That must be in the manifest, or rollback
# would imply a clean reversal.
assert_contains "K11 applying records the irreversible restart as a NOTE" "NOTE" "$out"
assert_contains "K11b the NOTE says what cannot be restored" "cannot be restored" "$out"

# ---- K12-K13: rollback tells the truth about all of it ----------------------
KROLL='
    export PATH="'"$KPG"':$PATH" WIZARD_TUNE_OLLAMA=1 WIZARD_STATE_DIR="$HOME/state"
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    backup_init >/dev/null 2>&1
    tune_ollama_step >/dev/null 2>&1
'
out=$(in_sandbox "$KENV$KROLL"'
    '"$ROLLBACK"' --yes 2>&1')
assert_contains "K12 rollback reports the irreversible effect as NOT UNDONE" "NOT UNDONE" "$out"
assert_contains "K12b rollback refuses to be recorded as a full reversal" "Do not record this rollback as a full reversal" "$out"
# And it must not have executed the undo command without being asked.
assert_contains "K12c rollback leaves the undo command manual by default" "manual   [ollama]" "$out"

mk_tune_stub "$KTUNE" "$KTOK" 0
out=$(in_sandbox "$KENV$KROLL"'
    '"$ROLLBACK"' --yes --run-actions >/dev/null 2>&1')
assert_contains "K13 rollback --run-actions actually runs the delegate's --revert" "stand-in revert" "$(cat "$KTUNE/tune.log")"

# ---- K14-K18: the provider verifier's three-valued verdict stays three-valued
KPROV=$(mktemp -d); PTOK="ptok$RANDOM$RANDOM"

mk_provider_stub "$KPROV" 0 "$PTOK"
out=$(in_sandbox "$KENV"'
    export PROVIDER_CI_SCRIPT="'"$KPROV"'/verify-provider-ci.sh"
    verify_provider_ci_step
'"$DUMP_MANUALS")
assert_contains "K14 rc=0 is reported as measured, not assumed" "measured just now" "$out"
assert_contains "K14b rc=0 registers no manual step" "MANUALCOUNT=0" "$out"

mk_provider_stub "$KPROV" 1 "$PTOK"
out=$(in_sandbox "$KENV"'
    export PROVIDER_CI_SCRIPT="'"$KPROV"'/verify-provider-ci.sh"
    verify_provider_ci_step
'"$DUMP_MANUALS")
kreg=$(registry "$out")
assert_contains "K15 rc=1 (confirmed) becomes a manual step" "TITLE: Provider-side CI triggering was CONFIRMED" "$kreg"
assert_contains "K15b the manual step carries the verifier's OWN findings" "$PTOK" "$kreg"
assert_contains "K15c the manual step says it is operator-only in the provider UI" "provider UI" "$kreg"

# THE ONE THAT MATTERS MOST: "could not determine" is not "nothing found".
mk_provider_stub "$KPROV" 2 "$PTOK"
out=$(in_sandbox "$KENV"'
    export PROVIDER_CI_SCRIPT="'"$KPROV"'/verify-provider-ci.sh"
    verify_provider_ci_step; echo "PROV_RC=$?"
'"$DUMP_MANUALS")
assert_contains "K16 rc=2 is reported as COULD NOT BE DETERMINED" "COULD NOT BE DETERMINED" "$out"
assert_contains "K16b rc=2 is explicitly NOT a pass" "NOT a pass" "$out"
assert_absent  "K16c rc=2 never renders the rc=0 success line" "no provider-generated triggering found" "$out"
assert_contains "K16d rc=2 registers an UNVERIFIED manual step" "UNVERIFIED" "$(registry "$out")"
assert_contains "K16e rc=2 still lets the wizard continue" "PROV_RC=0" "$out"

# An unexpected exit code is also unknown, not success.
mk_provider_stub "$KPROV" 3 "$PTOK"
out=$(in_sandbox "$KENV"'
    export PROVIDER_CI_SCRIPT="'"$KPROV"'/verify-provider-ci.sh"
    verify_provider_ci_step
'"$DUMP_MANUALS")
assert_contains "K17 an unexpected exit code is treated as unverified" "COULD NOT BE DETERMINED" "$out"
assert_absent  "K17b an unexpected exit code is never a pass" "no provider-generated triggering found" "$out"

# ---- K18-K19: absent DEPENDENCIES degrade, they do not abort ----------------
mk_provider_stub "$KPROV" 0 "$PTOK"
out=$(in_sandbox '
    export WIZARD_NONINTERACTIVE=1
    check_command() { [[ "$1" != gh ]] && command -v "$1" >/dev/null 2>&1; }
    export PROVIDER_CI_SCRIPT="'"$KPROV"'/verify-provider-ci.sh"
    verify_provider_ci_step; echo "PROV_RC=$?"
'"$DUMP_MANUALS")
assert_contains "K18 absent 'gh' does not abort the wizard" "PROV_RC=0" "$out"
assert_contains "K18b absent 'gh' leaves the provider status UNVERIFIED" "UNVERIFIED" "$(registry "$out")"
assert_absent  "K18c absent 'gh' never renders a pass" "no provider-generated triggering found" "$out"

mk_tune_stub "$KTUNE" "$KTOK" 0
out=$(in_sandbox '
    export WIZARD_NONINTERACTIVE=1 OLLAMA_HOST="http://127.0.0.1:1"
    check_command() { [[ "$1" != ollama ]] && command -v "$1" >/dev/null 2>&1; }
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    tune_ollama_step; echo "TUNE_RC=$?"
'"$DUMP_MANUALS")
assert_contains "K19 absent ollama backend does not abort the wizard" "TUNE_RC=0" "$out"
assert_contains "K19b absent ollama backend is stated, not silently skipped" "no ollama backend was found" "$(registry "$out")"
assert_absent  "K19c absent ollama backend never invokes the tuner" "ARGS:" "$(cat "$KTUNE/tune.log")"

# ---- K20: a delegate that cannot decide must not read as "nothing to do" ----
printf '#!/usr/bin/env bash\nexit 7\n' > "$KBOX/broken-tune.sh"; chmod +x "$KBOX/broken-tune.sh"
out=$(in_sandbox "$KENV"'
    export OLLAMA_TUNE_SCRIPT="'"$KBOX"'/broken-tune.sh"
    tune_ollama_step; echo "TUNE_RC=$?"
'"$DUMP_MANUALS")
assert_contains "K20 an undecidable tuner is reported as COULD NOT DETERMINE" "COULD NOT DETERMINE" "$out"
assert_absent  "K20b an undecidable tuner never claims the host is already tuned" "already matches" "$out"
assert_contains "K20c an undecidable tuner still hands the operator something to run" "run it yourself" "$(registry "$out")"

# ---- K23-K25: the tuner's THREE-VALUED verdict must survive the wizard ------
# REGRESSION. The real scripts/ollama-tune.sh exits 1 for "a real problem /
# action required" — i.e. exactly when it HAS a recommendation. The first
# revision of this integration mapped every non-zero to "recommendation
# UNAVAILABLE" and discarded the commands against the real script, reporting a
# host that needed tuning as one whose state was unknown. Verified against the
# live script on 2026-08-31: report and --print-commands both exit 1 while
# printing a complete, correct recommendation.
mk_tune_stub "$KTUNE" "$KTOK" 0 1
out=$(in_sandbox "$KENV"'
    export PATH="'"$KPG"':$PATH"
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    tune_ollama_step
'"$DUMP_MANUALS")
assert_contains "K23 exit 1 means ACTION REQUIRED: the recommendation is surfaced" "OLLAMA_NUM_PARALLEL=$KTOK" "$(registry "$out")"
assert_absent  "K23b exit 1 is never mistaken for a broken tuner" "COULD NOT DETERMINE" "$out"
assert_absent  "K23c exit 1 is never mistaken for 'nothing to apply'" "already matches" "$out"

mk_tune_stub "$KTUNE" "$KTOK" 0 0
out=$(in_sandbox "$KENV"'
    export PATH="'"$KPG"':$PATH"
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    tune_ollama_step
'"$DUMP_MANUALS")
assert_contains "K24 exit 0 means nothing to apply" "already matches" "$out"
assert_contains "K24b exit 0 registers no manual step" "MANUALCOUNT=0" "$out"
assert_absent  "K24c exit 0 does not even ask for the commands" "ARGS:--print-commands" "$(cat "$KTUNE/tune.log")"

mk_tune_stub "$KTUNE" "$KTOK" 0 2
out=$(in_sandbox "$KENV"'
    export PATH="'"$KPG"':$PATH"
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    tune_ollama_step
'"$DUMP_MANUALS")
assert_contains "K25 exit 2 is COULD NOT DETERMINE, not a recommendation" "COULD NOT DETERMINE" "$out"
assert_absent  "K25b exit 2 never claims the host is already tuned" "already matches" "$out"

# ---- K26: the commands handed over are the delegate's, extracted not invented
# The real tuner prints a whole report and labels its command block. The wizard
# must lift that block; when a delegate labels nothing it must fall back to the
# delegate's full output — never to an example of the wizard's own.
mk_tune_stub "$KTUNE" "$KTOK" 0 1
out=$(in_sandbox "$KENV"'
    export PATH="'"$KPG"':$PATH"
    export OLLAMA_TUNE_SCRIPT="'"$KTUNE"'/ollama-tune.sh"
    tune_ollama_step
'"$DUMP_MANUALS")
kreg=$(registry "$out")
assert_contains "K26 the labelled command block is lifted out of the report" "reload-and-restart-the-backend" "$kreg"
assert_absent  "K26b the surrounding report prose is not dragged into the step" "manager=stand-in" "$kreg"

printf '#!/usr/bin/env bash\ncase "${1:-}" in --print-commands) echo "UNLABELLED-'"$KTOK"'"; exit 1;; *) echo r; exit 1;; esac\n' \
    > "$KBOX/unlabelled-tune.sh"; chmod +x "$KBOX/unlabelled-tune.sh"
out=$(in_sandbox "$KENV"'
    export PATH="'"$KPG"':$PATH"
    export OLLAMA_TUNE_SCRIPT="'"$KBOX"'/unlabelled-tune.sh"
    tune_ollama_step
'"$DUMP_MANUALS")
assert_contains "K26c an unlabelled delegate degrades to its full output, not to an example" "UNLABELLED-$KTOK" "$(registry "$out")"

# ---- K27: report says "action required" but the commands cannot be produced -
# The two calls are independent, so the second can fail on its own. That must
# still not become an invented value.
printf '#!/usr/bin/env bash\ncase "${1:-}" in --print-commands) exit 2;; *) echo "needs tuning"; exit 1;; esac\n' \
    > "$KBOX/nocmds-tune.sh"; chmod +x "$KBOX/nocmds-tune.sh"
out=$(in_sandbox "$KENV"'
    export PATH="'"$KPG"':$PATH"
    export OLLAMA_TUNE_SCRIPT="'"$KBOX"'/nocmds-tune.sh"
    tune_ollama_step; echo "TUNE_RC=$?"
'"$DUMP_MANUALS")
kreg=$(registry "$out")
assert_contains "K27 an unproducible command set still yields a manual step" "run the tuner yourself" "$kreg"
_fab=$(printf '%s\n' "$kreg" | grep -cE 'OLLAMA_NUM_PARALLEL[[:space:]]*=[[:space:]]*[0-9]' || true)
assert_eq "K27b that manual step contains NO fabricated concurrency value" "0" "$_fab"
assert_contains "K27c the wizard still continues" "TUNE_RC=0" "$out"

# ---- K21-K22: the wiring itself --------------------------------------------
# Everything above drives the two functions DIRECTLY, so it would all stay
# green if the call sites were deleted from the wizard's run. That is exactly
# how A9 got burned. Count CALL SITES, not definitions.
callsT=$(printf '%s\n' "$src_code" | grep -cE '^[[:space:]]*tune_ollama_step[[:space:]]*$')
assert_eq "K21 tune_ollama_step is actually CALLED, not just defined" "1" "$callsT"
callsP=$(printf '%s\n' "$src_code" | grep -cE '^[[:space:]]*verify_provider_ci_step[[:space:]]*$')
assert_eq "K22 verify_provider_ci_step is actually CALLED, not just defined" "1" "$callsP"

rm -rf "$KBOX" "$KTUNE" "$KPG" "$KPGBUSY" "$KPGNONE" "$KPROV"

# ==============================================================================
# Evidence summary
# ==============================================================================
TOTAL=$((PASS+FAIL+SKIP))
cat > "$EVIDENCE_DIR/summary.json" <<JSON
{
  "timestamp_utc": "$STAMP",
  "wizard": "$WIZARD",
  "host": {"uname": "$(uname -s)/$(uname -m)", "bash": "$BASH_VERSION"},
  "totals": {"total": $TOTAL, "passed": $PASS, "failed": $FAIL, "skipped": $SKIP},
  "exit_code": $([[ $FAIL -eq 0 ]] && echo 0 || echo 1)
}
JSON

{
echo
echo "================= EVIDENCE ================="
echo "  results.tsv : $RESULTS"
echo "  run.log     : $RUNLOG"
echo "  summary.json: $EVIDENCE_DIR/summary.json"
echo "  total=$TOTAL passed=$PASS failed=$FAIL skipped=$SKIP"
echo "============================================"
} | tee -a "$RUNLOG"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
