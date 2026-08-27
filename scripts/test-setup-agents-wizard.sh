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
#
# Evidence is written to .test-evidence/<UTC timestamp>/
# Exit status is non-zero if any test fails.
# ------------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
WIZARD="$SCRIPT_DIR/setup-agents-wizard.sh"

RUN_LIVE=1
[[ "${1:-}" == "--no-live" ]] && RUN_LIVE=0

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
EVIDENCE_DIR="$PROJECT_ROOT/.test-evidence/$STAMP"
mkdir -p "$EVIDENCE_DIR"
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
unbounded=$(printf '%s\n' "$src_code" | grep -cE '(^|[^a-z0-9_-])lumen search ' | head -1)
bounded=$(printf '%s\n' "$src_code" | grep -cE 'timeout [0-9]+ lumen search ')
assert_eq "A47 every 'lumen search' probe in the wizard is timeout-bounded" "$unbounded" "$bounded"
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
# Step 7 (project indexing) is opt-in: its header only prints when
# WIZARD_INDEX_PROJECT is set, but the literal must still be in sequence.
assert_eq "A10 step headers are sequential 1..7" "1,2,3,4,5,6,7," "$steps"

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
