#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# AI Agents Ultimate Auto-Setup Wizard (Safe Stack)
# Supports: Claude Code, Kimi, Opencode, MiMo Code, Qwen Code
# Shared stack: Lumen, CodeGraph, ashlr, WOZCODE, Glyphdown,
# Claude Cost Optimizer, Fix Claude Code, SpecKit, SuperSpec.
# 
# This script is MEANT to be placed inside the 'scripts/' directory.
# It auto-detects the project root (parent of the scripts/ folder).
# ------------------------------------------------------------------------------

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------
print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

check_command() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------------------
# Transactional backup / rollback
# ------------------------------------------------------------------------------
# Every mutation this wizard performs is recorded in a per-run manifest so that
# scripts/rollback-agents-wizard.sh can undo it exactly - either wholesale or
# for one component (lumen, shell, claude, kimi, opencode, qwen, npm).
#
#   MODIFIED : the file existed; a byte-exact copy (mode preserved) is stored
#              and rollback restores it.
#   CREATED  : the file did not exist; rollback deletes it.
#   ACTION   : a non-file change (an npm global install, a `claude mcp` entry)
#              with an explicit documented undo command.
WIZARD_STATE_DIR="${WIZARD_STATE_DIR:-$HOME/.local/share/setup-agents-wizard}"
BACKUP_ROOT="$WIZARD_STATE_DIR/backups"
BACKUP_SESSION=""
MANIFEST=""

_sha() { if [[ -f "$1" ]]; then sha256sum "$1" 2>/dev/null | cut -d" " -f1; else echo "-"; fi; }

backup_init() {
    # Resolve the state directory at CALL time, not at source time, so that
    # exporting WIZARD_STATE_DIR after sourcing (library mode, wrappers, tests)
    # actually takes effect.
    WIZARD_STATE_DIR="${WIZARD_STATE_DIR:-$HOME/.local/share/setup-agents-wizard}"
    BACKUP_ROOT="$WIZARD_STATE_DIR/backups"
    BACKUP_SESSION="$BACKUP_ROOT/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$BACKUP_SESSION/files"
    MANIFEST="$BACKUP_SESSION/manifest.tsv"
    printf 'component\taction\ttarget\tbackup\tsha256_before\ttimestamp\n' > "$MANIFEST"
    ln -sfn "$BACKUP_SESSION" "$BACKUP_ROOT/latest"
    print_info "Backup session: $BACKUP_SESSION"
    print_info "Undo everything later with: $SCRIPT_DIR/rollback-agents-wizard.sh"
}

# snapshot_before <component> <target-path>
# Captures the pre-change state. The FIRST snapshot in a session wins, so a
# file touched by several steps still rolls back to its true original.
snapshot_before() {
    local component="$1" target="$2" action backup sha key
    [[ -n "$MANIFEST" ]] || return 0
    if awk -F'\t' -v t="$target" 'NR>1 && $3==t {f=1} END{exit !f}' "$MANIFEST" 2>/dev/null; then
        return 0
    fi
    if [[ -e "$target" ]]; then
        action="MODIFIED"
        key=$(printf '%s' "$target" | sha256sum | cut -c1-16)
        backup="$BACKUP_SESSION/files/${key}__$(basename "$target")"
        cp -p "$target" "$backup" 2>/dev/null || { print_warning "Could not back up $target"; return 1; }
        sha=$(_sha "$target")
    else
        action="CREATED"; backup="-"; sha="-"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$component" "$action" "$target" "$backup" "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$MANIFEST"
}

# record_action <component> <undo-command> - for changes that are not files
record_action() {
    [[ -n "$MANIFEST" ]] || return 0
    printf '%s\tACTION\t%s\t-\t-\t%s\n' "$1" "$2" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$MANIFEST"
}

# backup_file <path> [component]
# Keeps the familiar sibling .bak.<timestamp> copy AND registers the file in
# the rollback manifest.
backup_file() {
    local file="$1" component="${2:-misc}"
    snapshot_before "$component" "$file"
    if [[ -f "$file" ]]; then
        cp -p "$file" "$file.bak.$(date +%Y%m%d%H%M%S)"
        print_info "Backed up $file"
    fi
}

# Auto-install jq if missing
ensure_jq() {
    if check_command jq; then return 0; fi
    print_info "jq not found – installing it now."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if check_command apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y jq || true
        elif check_command yum; then
            sudo yum install -y jq || true
        else
            print_error "Could not install jq. Please install it manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if check_command brew; then
            brew install jq
        else
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
                || print_warning "Homebrew installer exited non-zero."
            brew install jq || true
        fi
    else
        print_error "Unsupported OS. Please install jq manually."
        exit 1
    fi
    if check_command jq; then print_success "jq installed."; else print_error "jq failed. Exiting."; exit 1; fi
}

# Safely add MCP servers to an agent's config file
configure_mcp_for_agent() {
    local config_file="$1"
    local agent_name="$2"
    local component="${3:-misc}"
    mkdir -p "$(dirname "$config_file")"
    # Snapshot BEFORE seeding the file. Seeding first would make a file that
    # never existed look MODIFIED, and rollback would leave an empty `{}`
    # behind instead of removing it.
    snapshot_before "$component" "$config_file"
    if [[ ! -f "$config_file" ]]; then
        echo '{}' > "$config_file"
    fi
    backup_file "$config_file" "$component"
    local tmp_file
    tmp_file=$(mktemp)
    # Add Lumen and CodeGraph to mcpServers.
    #
    # Lumen's MCP subcommand is `stdio` (NOT `serve` - that command does not
    # exist and produces: Error: unknown command "serve" for "lumen").
    #
    # The command is written as an ABSOLUTE path on purpose: agents spawn MCP
    # servers from non-interactive shells, where ~/.local/bin is often absent
    # from PATH, so a bare "lumen" would fail to launch.
    jq --arg lumen_bin "$LUMEN_WRAPPER" '.mcpServers += {
        "lumen": {
            "command": $lumen_bin,
            "args": ["stdio"]
        },
        "codegraph": {
            "command": "codegraph",
            "args": ["serve"]
        }
    }' "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    print_success "MCP servers (Lumen + CodeGraph) configured for $agent_name at $config_file"
}

# ------------------------------------------------------------------------------
# Lumen Semantic Search - constants and setup helpers
# ------------------------------------------------------------------------------
# Lumen is NOT an npm package. It ships as a Claude Code plugin binary at:
#   ~/.claude-shared/plugins/cache/<marketplace>/lumen/<version>/bin/lumen-<os>-<arch>
# The <version> component changes on every plugin update, so we install a
# version-agnostic wrapper on PATH instead of symlinking a pinned path that
# would silently break at the next upgrade.

LUMEN_WRAPPER="$HOME/.local/bin/lumen"
LUMEN_COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
LUMEN_EMBED_MODEL="${LUMEN_EMBED_MODEL:-ordis/jina-embeddings-v2-base-code}"

LUMEN_BLOCK_START="# >>> lumen semantic search (managed by Claude Code) >>>"
LUMEN_BLOCK_END="# <<< lumen semantic search <<<"
USERBIN_BLOCK_START="# >>> user bin on PATH (managed by Claude Code) >>>"
USERBIN_BLOCK_END="# <<< user bin on PATH <<<"

# Remove a marker-delimited managed block, preserving the file's mode/inode.
# (awk instead of sed: the markers contain regex metacharacters.)
strip_managed_block() {
    local file="$1" start="$2" end="$3"
    [[ -f "$file" ]] || return 0
    grep -qF "$start" "$file" || return 0
    awk -v s="$start" -v e="$end" '
        index($0, s) == 1 { skip = 1 }
        !skip             { print }
        index($0, e) == 1 { skip = 0 }
    ' "$file" > "$file.lumen.tmp" || return 1
    cat "$file.lumen.tmp" > "$file"
    rm -f "$file.lumen.tmp"
}

install_lumen_wrapper() {
    mkdir -p "$(dirname "$LUMEN_WRAPPER")"
    backup_file "$LUMEN_WRAPPER" lumen
    cat > "$LUMEN_WRAPPER" <<'LUMEN_WRAPPER_EOF'
#!/usr/bin/env bash
#
# lumen — version-agnostic launcher for the Claude Code Lumen plugin CLI.
#
# The plugin ships its binary at a VERSION-PINNED path:
#   ~/.claude-shared/plugins/cache/<marketplace>/lumen/<version>/bin/lumen-<os>-<arch>
#
# A symlink or a hardcoded PATH entry to that path breaks the moment the plugin
# updates (the old version directory is removed). This wrapper resolves the
# highest installed version at call time instead, so `lumen` keeps working
# across plugin upgrades with no shell reconfiguration.
#
# Override the resolution entirely by exporting LUMEN_BIN=/path/to/binary.
#
# Managed by Claude Code. Safe to delete; re-create to restore `lumen` on PATH.

set -uo pipefail

# 1. Explicit override always wins.
if [ -n "${LUMEN_BIN:-}" ]; then
    if [ ! -x "$LUMEN_BIN" ]; then
        printf 'lumen: LUMEN_BIN is set but not executable: %s\n' "$LUMEN_BIN" >&2
        exit 127
    fi
    exec "$LUMEN_BIN" "$@"
fi

# 2. Map the host to the plugin's binary naming convention.
case "$(uname -s)" in
    Linux)  __os=linux ;;
    Darwin) __os=darwin ;;
    *)      printf 'lumen: unsupported OS: %s\n' "$(uname -s)" >&2; exit 127 ;;
esac
case "$(uname -m)" in
    x86_64|amd64)  __arch=amd64 ;;
    aarch64|arm64) __arch=arm64 ;;
    *)             printf 'lumen: unsupported arch: %s\n' "$(uname -m)" >&2; exit 127 ;;
esac

shopt -s nullglob

# 3. Of the candidates handed in, pick the highest version (sort -V).
#    Path shape: .../lumen/<version>/bin/<binary>
__lumen_pick() {
    local f v
    for f in "$@"; do
        [ -x "$f" ] || continue
        v=${f%/bin/*}
        v=${v##*/}
        printf '%s\t%s\n' "$v" "$f"
    done | sort -V -k1,1 | tail -n1 | cut -f2
}

# Fast path: the canonical shared plugin cache.
__lumen_resolved=$(__lumen_pick \
    "$HOME"/.claude-shared/plugins/cache/*/lumen/*/bin/lumen-"$__os"-"$__arch")

# Fallback: any per-account Claude config dir carrying its own plugin cache.
if [ -z "$__lumen_resolved" ]; then
    __lumen_resolved=$(__lumen_pick \
        "$HOME"/.claude*/plugins/cache/*/lumen/*/bin/lumen-"$__os"-"$__arch")
fi

if [ -z "$__lumen_resolved" ]; then
    cat >&2 <<'MSG'
lumen: could not locate the Lumen plugin binary.

Looked under:
  ~/.claude-shared/plugins/cache/*/lumen/*/bin/
  ~/.claude*/plugins/cache/*/lumen/*/bin/

Is the Lumen plugin installed? In Claude Code run:  /plugin
Or point at the binary directly:  export LUMEN_BIN=/path/to/lumen-linux-amd64
MSG
    exit 127
fi

exec "$__lumen_resolved" "$@"
LUMEN_WRAPPER_EOF
    chmod 755 "$LUMEN_WRAPPER"
    print_success "Lumen launcher installed: $LUMEN_WRAPPER"
}

install_lumen_completion() {
    if [[ ! -x "$LUMEN_WRAPPER" ]]; then
        print_warning "Skipping Lumen completions (launcher missing)."
        return 0
    fi
    mkdir -p "$LUMEN_COMPLETION_DIR"
    snapshot_before lumen "$LUMEN_COMPLETION_DIR/lumen"
    if "$LUMEN_WRAPPER" completion bash > "$LUMEN_COMPLETION_DIR/lumen" 2>/dev/null; then
        print_success "Bash completions installed (lazy-loaded, no shell-startup cost)."
    else
        rm -f "$LUMEN_COMPLETION_DIR/lumen"
        print_warning "Could not generate Lumen bash completions."
    fi
}

# PATH wiring. Two files are needed, for two different reasons:
#   ~/.bashrc       - interactive shells
#   ~/.bash_profile - login shells: /etc/profile resets PATH, and ~/.bashrc
#                     returns early when non-interactive, so `ssh host '<cmd>'`,
#                     cron and systemd user units would otherwise never see
#                     ~/.local/bin at all.
configure_lumen_shell() {
    local bashrc="$HOME/.bashrc"
    local profile="$HOME/.bash_profile"

    backup_file "$bashrc" shell
    strip_managed_block "$bashrc" "$LUMEN_BLOCK_START" "$LUMEN_BLOCK_END"
    cat >> "$bashrc" <<LUMEN_RC_EOF

$LUMEN_BLOCK_START
#
# \`lumen\` is provided by $LUMEN_WRAPPER - a version-agnostic wrapper that
# resolves the newest installed plugin binary at call time. Do NOT replace it
# with a symlink into the versioned plugin directory: that path changes on
# every plugin update. Override with: export LUMEN_BIN=/path/to/binary
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$HOME/.local/bin:\$PATH";; esac

# Completions are lazy-loaded by bash-completion on the first \`lumen<TAB>\`.
# Source by hand only when that lazy loader is unavailable.
if ! declare -F _completion_loader >/dev/null 2>&1; then
    [ -r "\$HOME/.local/share/bash-completion/completions/lumen" ] && \\
        . "\$HOME/.local/share/bash-completion/completions/lumen"
fi

# Tuning knobs - intentionally left UNSET. The CLI and the agent MCP servers
# share built-in defaults; pinning a value here desyncs them on a plugin
# update, and a model mismatch makes Lumen build a SECOND index per project.
#export LUMEN_BACKEND=ollama                                 # ollama | lmstudio
#export LUMEN_EMBED_MODEL=$LUMEN_EMBED_MODEL
#export OLLAMA_HOST=http://localhost:11434
#export LUMEN_REINDEX_TIMEOUT=600   # seconds; raise for very large repositories
#export LUMEN_FRESHNESS_TTL=300     # seconds before an index is treated as stale
#export LUMEN_LOG_LEVEL=info        # debug | info | warn | error
$LUMEN_BLOCK_END
LUMEN_RC_EOF
    print_success "Configured $bashrc (PATH + completions)."

    backup_file "$profile" shell
    strip_managed_block "$profile" "$USERBIN_BLOCK_START" "$USERBIN_BLOCK_END"
    cat >> "$profile" <<USERBIN_EOF

$USERBIN_BLOCK_START
# Login shells start from the PATH set by /etc/profile, and ~/.bashrc - where
# ~/.local/bin is normally added - returns early for NON-interactive shells.
# Without this guard, \`lumen\` and every other ~/.local/bin tool is missing
# from \`bash -lc\`, \`ssh host '<cmd>'\`, cron jobs and systemd user units.
# Idempotent: a no-op for interactive shells, the fix for everything else.
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$HOME/.local/bin:\$PATH";; esac
$USERBIN_BLOCK_END
USERBIN_EOF
    print_success "Configured $profile (login-shell PATH)."

    export PATH="$HOME/.local/bin:$PATH"
}

PRIVACY_BLOCK_START="# >>> telemetry opt-out (managed by Claude Code) >>>"
PRIVACY_BLOCK_END="# <<< telemetry opt-out <<<"

# Disable analytics/telemetry across the installed tooling.
# ON by default; set WIZARD_KEEP_TELEMETRY=1 to leave everything untouched.
# Every knob below was verified against the installed package, not guessed:
#   DO_NOT_TRACK        - the cross-tool standard; @colbymchenry/codegraph
#                         reads it (confirmed by grepping its bundle)
#   CODEGRAPH_TELEMETRY - CodeGraph's own switch
#   usageStatisticsEnabled - read by @qwen-code/qwen-code (found in its chunks)
# Lumen was checked and ships NO telemetry at all (zero analytics strings in
# the binary), so there is nothing to disable for it.
configure_telemetry_optout() {
    if [[ -n "${WIZARD_KEEP_TELEMETRY:-}" ]]; then
        print_warning "WIZARD_KEEP_TELEMETRY set - leaving telemetry settings alone."
        return 0
    fi

    local bashrc="$HOME/.bashrc"
    backup_file "$bashrc" shell
    strip_managed_block "$bashrc" "$PRIVACY_BLOCK_START" "$PRIVACY_BLOCK_END"
    cat >> "$bashrc" <<PRIVACY_EOF

$PRIVACY_BLOCK_START
# Opt out of usage analytics for locally installed developer tooling.
# DO_NOT_TRACK is the cross-tool convention (consoledonottrack.com).
export DO_NOT_TRACK=1
export CODEGRAPH_TELEMETRY=0
$PRIVACY_BLOCK_END
PRIVACY_EOF
    export DO_NOT_TRACK=1 CODEGRAPH_TELEMETRY=0
    print_success "Telemetry opt-out exported in $bashrc"

    if check_command codegraph; then
        if codegraph telemetry off >/dev/null 2>&1; then
            print_success "CodeGraph telemetry disabled (buffered data deleted)."
        else
            print_warning "Could not disable CodeGraph telemetry."
        fi
    fi

    # Qwen Code: settings key verified present in the installed package.
    local qwen_cfg="$HOME/.qwen/settings.json"
    if [[ -f "$qwen_cfg" ]] && check_command jq; then
        if [[ "$(jq -r '.usageStatisticsEnabled | tostring' "$qwen_cfg" 2>/dev/null)" == "false" ]]; then
            print_success "Qwen usage statistics already disabled."
        else
            backup_file "$qwen_cfg" qwen
            local t; t=$(mktemp)
            if jq '.usageStatisticsEnabled = false' "$qwen_cfg" > "$t" && [[ -s "$t" ]]; then
                mv "$t" "$qwen_cfg"; print_success "Qwen usage statistics disabled."
            else
                rm -f "$t"; print_warning "Could not update $qwen_cfg."
            fi
        fi
    fi
}

# Lumen cannot chunk or search anything without a local embedding backend.
ensure_ollama() {
    if ! check_command ollama; then
        print_info "Ollama not found - installing Lumen's embedding backend..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -fsSL https://ollama.com/install.sh | sh >/dev/null 2>&1 || true
        elif [[ "$OSTYPE" == "darwin"* ]] && check_command brew; then
            brew install ollama >/dev/null 2>&1 || true
        fi
    fi

    if ! check_command ollama; then
        print_warning "Ollama unavailable - Lumen cannot index or search without it."
        print_warning "Install from https://ollama.com/download, then re-run this script."
        return 1
    fi
    print_success "Ollama present."

    if check_command systemctl; then
        if ! systemctl is-active --quiet ollama 2>/dev/null; then
            print_info "Starting and enabling the ollama service..."
            sudo systemctl enable --now ollama >/dev/null 2>&1 || true
        fi
        if systemctl is-active --quiet ollama 2>/dev/null; then
            print_success "ollama service active (and enabled at boot)."
        else
            print_warning "ollama service is not active - start it before indexing."
        fi
    fi

    if ollama list 2>/dev/null | grep -qF "$LUMEN_EMBED_MODEL"; then
        print_success "Embedding model present: $LUMEN_EMBED_MODEL"
    else
        print_info "Pulling embedding model $LUMEN_EMBED_MODEL (~320 MB, one-time)..."
        if ollama pull "$LUMEN_EMBED_MODEL" >/dev/null 2>&1; then
            print_success "Embedding model pulled."
        else
            print_warning "Model pull failed - Lumen indexing stays broken until it succeeds."
        fi
    fi
}

verify_lumen() {
    local rc=0

    if [[ -x "$LUMEN_WRAPPER" ]] && "$LUMEN_WRAPPER" version >/dev/null 2>&1; then
        print_success "lumen $("$LUMEN_WRAPPER" version 2>/dev/null) responds at $LUMEN_WRAPPER"
    else
        print_error "Lumen launcher is not runnable - is the Claude Code Lumen plugin installed?"
        rc=1
    fi

    # PATH must resolve `lumen` in a LOGIN shell too, not just this one.
    if bash -lc 'command -v lumen' >/dev/null 2>&1; then
        print_success "lumen resolves on PATH in a login shell."
    else
        print_warning "lumen not on PATH in a login shell - open a new terminal to pick it up."
    fi

    if curl -sf --max-time 5 "${OLLAMA_HOST:-http://localhost:11434}/api/tags" >/dev/null 2>&1; then
        print_success "Embedding backend reachable at ${OLLAMA_HOST:-http://localhost:11434}"
    else
        print_warning "Embedding backend unreachable - Lumen will fail to index."
        rc=1
    fi

    return $rc
}

ensure_lumen() {
    configure_telemetry_optout
    install_lumen_wrapper
    install_lumen_completion
    configure_lumen_shell
    ensure_ollama || true
    verify_lumen || print_warning "Lumen setup finished with warnings (see above)."
}

# SuperSpec checkout. Extracted into a function so the regression test for the
# submodule data-loss bug can exercise it directly.
setup_superspec() {
    local root="$1" sub_path="$2"
    # DATA-LOSS FIX: for a registered git submodule, "<path>/.git" is a FILE (a
    # gitlink), never a directory. The previous test was `[[ -d .../.git ]]`, which
    # is therefore ALWAYS false for a submodule checkout - so the `rm -rf` below it
    # deleted the registered submodule on every single run, then replaced it with a
    # plain clone, corrupting the parent repository's submodule state.
    # Test with -e, and never delete a path that git tracks as a submodule.
    if [[ -e "$sub_path/.git" ]]; then
        if [[ -f "$sub_path/.git" ]]; then
            print_success "SuperSpec already present (git submodule)."
        else
            print_success "SuperSpec already present (standalone clone)."
        fi
    elif git -C "$root" submodule status "$sub_path" >/dev/null 2>&1; then
        print_info "SuperSpec is a registered submodule but not checked out - initializing..."
        if git -C "$root" submodule update --init --recursive "$sub_path" >/dev/null 2>&1; then
            print_success "SuperSpec submodule initialized."
        else
            print_warning "SuperSpec submodule init failed."
        fi
    else
        if [[ -d "$sub_path" ]]; then
            print_warning "Removing stale non-git directory at $sub_path"
            rm -rf "$sub_path"
        fi
        print_info "Cloning SuperSpec..."
        git clone https://github.com/WangX0111/superspec.git "$sub_path" > /dev/null 2>&1 || true
        if [[ -e "$sub_path/.git" ]]; then print_success "SuperSpec cloned."; else print_warning "SuperSpec clone failed."; fi
    fi
}

# ------------------------------------------------------------------------------
# 1. Path Detection
# ------------------------------------------------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Library mode: let the test-suite source this file for its helper functions
# WITHOUT running the wizard. Everything above this line is pure definitions.
#   SETUP_WIZARD_LIB_ONLY=1 . scripts/setup-agents-wizard.sh
if [[ -n "${SETUP_WIZARD_LIB_ONLY:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

print_header "AI Agents Ultimate Setup Wizard"
print_info "Script directory : $SCRIPT_DIR"
print_info "Project root     : $PROJECT_ROOT"
backup_init

# ------------------------------------------------------------------------------
# 2. Prerequisites Check
# ------------------------------------------------------------------------------
print_header "Step 1: Checking System Prerequisites"

MISSING_PREREQS=0
if ! check_command git; then print_error "git missing"; MISSING_PREREQS=1; fi
if ! check_command curl; then print_error "curl missing"; MISSING_PREREQS=1; fi
if ! check_command node; then print_error "Node.js missing"; MISSING_PREREQS=1; fi
if ! check_command npm; then print_error "npm missing"; MISSING_PREREQS=1; fi

if [[ $MISSING_PREREQS -eq 1 ]]; then
    print_error "Please install missing prerequisites and re-run."
    exit 1
fi
print_success "All core prerequisites met."
ensure_jq

# ------------------------------------------------------------------------------
# 3. System-Level Installations (Global CLIs)
# ------------------------------------------------------------------------------
print_header "Step 2: Installing / Updating Global CLI Tools"

# 3.1 Bun
if ! check_command bun; then
    print_info "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash \
        || print_warning "Bun installer exited non-zero - continuing without it."
    export PATH="$HOME/.bun/bin:$PATH"
    if check_command bun; then print_success "Bun installed."; else print_warning "Bun failed."; fi
else
    print_success "Bun already present."
fi

# 3.2 Core MCP & Utility Tools (Lumen, CodeGraph, Glyphdown, SpecKit)
# Package names below were verified against the npm registry. Several names
# previously used here were wrong, and `|| true` hid every failure so the final
# summary reported success for tools that something else had installed:
#
#   @qoomon/lumen      -> 404. Lumen is a Claude Code plugin (see Step 3).
#   @monday/codegraph  -> 404. Real package: @colbymchenry/codegraph
#   @specify/cli       -> 404. Real tool: specify-cli, installed via `uv tool`
#   opencode           -> 404. Ships its own installer (~/.opencode/bin)
#   kimi               -> EXISTS but is a state-animation library, NOT the Kimi
#                         agent. The real agent installs to ~/.kimi-code/bin
#   mimo               -> EXISTS but is a minimal mobile build tool, NOT MiMo
#                         Code. The real agent installs to ~/.mimocode/bin
#   qwen-code          -> a v0.0.5 stub. Real package: @qwen-code/qwen-code
#
# Installing by guessed name pollutes the global npm prefix with unrelated
# software. Everything below therefore installs ONLY what is actually missing,
# and reports honestly when a tool has to be installed by its own vendor.

npm_install_if_missing() {
    local cmd="$1" pkg="$2"
    if check_command "$cmd"; then
        print_success "$cmd already present - leaving the existing install alone."
        return 0
    fi
    print_info "Installing $pkg (provides '$cmd')..."
    if npm install -g "$pkg" >/dev/null 2>&1 && check_command "$cmd"; then
        record_action npm "npm uninstall -g $pkg"
        print_success "$cmd installed from $pkg."
    else
        print_warning "Could not install $pkg - '$cmd' stays unavailable."
    fi
}

print_info "Installing core utilities: CodeGraph, Glyphdown..."
npm_install_if_missing codegraph "@colbymchenry/codegraph"
npm_install_if_missing glyphdown "glyphdown"

# SpecKit is a Python tool distributed with uv, not an npm package.
if check_command specify; then
    print_success "specify already present - leaving the existing install alone."
elif check_command uv; then
    print_info "Installing SpecKit CLI via uv..."
    uv tool install specify-cli >/dev/null 2>&1 || true
    if check_command specify; then
        record_action speckit "uv tool uninstall specify-cli"
        print_success "specify installed."
    else
        print_warning "specify install failed."
    fi
else
    print_warning "specify missing and uv unavailable - install uv, then: uv tool install specify-cli"
fi

# 3.3 AI Agent CLIs
# Kimi, Opencode and MiMo Code each ship their OWN installer and are not on
# npm under those names. We detect them and point at the vendor rather than
# installing an unrelated package that merely shares the name.
print_info "Checking AI Agent CLIs..."
npm_install_if_missing qwen "@qwen-code/qwen-code"   # binary is `qwen`, not `qwen-code`

for pair in "kimi:Kimi:https://kimi.moonshot.cn" \
            "opencode:Opencode:https://opencode.ai" \
            "mimo:MiMo Code:https://github.com/XiaomiMiMo"; do
    cmd=${pair%%:*}; rest=${pair#*:}; label=${rest%%:*}; url=${rest#*:}
    if check_command "$cmd"; then
        print_success "$label present ($(command -v "$cmd"))."
    else
        print_warning "$label not installed - it ships its own installer: $url"
    fi
done

# 3.4 ashlr-plugin
if check_command bun; then
    print_info "Installing ashlr-plugin..."
    curl -fsSL https://plugin.ashlr.ai/install.sh | bash > /dev/null 2>&1 || true
    export PATH="$HOME/.ashlr/bin:$PATH"
    if check_command ashlr; then print_success "ashlr-plugin installed."; else print_warning "ashlr-plugin may need restart."; fi
else
    print_warning "Skipping ashlr-plugin (Bun required)."
fi

# 3.5 WOZCODE (optional via env var)
if check_command wozcode; then
    print_success "WOZCODE already installed."
else
    if [[ -n "${WOZCODE_INSTALL_CMD:-}" ]]; then
        print_info "Installing WOZCODE from provided command..."
        eval "$WOZCODE_INSTALL_CMD" || true
        if check_command wozcode; then print_success "WOZCODE installed."; else print_warning "WOZCODE failed."; fi
    else
        print_warning "WOZCODE not installed. Set WOZCODE_INSTALL_CMD to auto-install."
    fi
fi

# ------------------------------------------------------------------------------
# 4. Lumen Semantic Search (launcher, PATH, completions, embedding backend)
# ------------------------------------------------------------------------------
print_header "Step 3: Lumen Semantic Search Setup"
ensure_lumen

# ------------------------------------------------------------------------------
# 5. Verify Installed Commands
# ------------------------------------------------------------------------------
print_header "Step 4: Verifying CLI Availability"
for cmd in lumen codegraph glyphdown specify kimi opencode mimo qwen ashlr; do
    if check_command "$cmd"; then
        print_success "$cmd found"
    else
        print_warning "$cmd not in PATH (may require terminal restart or manual install)"
    fi
done

# ------------------------------------------------------------------------------
# 6. Configure MCP for ALL Agents
# ------------------------------------------------------------------------------
print_header "Step 5: Configuring MCP Servers for Each Agent"

# Agent config locations and schemas were verified on disk. The paths this
# script used previously were wrong for every agent except Opencode's
# directory, so it created orphan files that no agent ever reads while the
# summary still printed a success tick for each one:
#
#   Claude Code : ~/.claude/mcp.json      -> does not exist. Claude Code keeps
#                 MCP servers in ~/.claude.json; use the `claude mcp` CLI.
#   Kimi        : ~/.kimi/config.json     -> real: ~/.kimi-code/mcp.json
#   MiMo Code   : ~/.mimo/config.json     -> real dir is ~/.mimocode, which has
#                 no discoverable MCP config schema; we warn instead of guessing
#   Qwen Code   : ~/.qwen-code/config.json-> real: ~/.qwen/settings.json
#   Opencode    : ~/.opencode/config.json -> real: ~/.config/opencode/opencode.json
#                 AND it uses a ".mcp" object, not ".mcpServers"

# 5.1 Claude Code - configured through its own CLI rather than hand-editing
# ~/.claude.json, which also holds session and project state.
if check_command claude; then
    if claude mcp get lumen >/dev/null 2>&1; then
        print_success "Lumen MCP already registered with Claude Code."
    elif claude mcp add-json lumen \
            "{\"command\":\"$LUMEN_WRAPPER\",\"args\":[\"stdio\"]}" \
            -s user >/dev/null 2>&1; then
        record_action claude "claude mcp remove lumen -s user"
        print_success "Lumen MCP registered with Claude Code (user scope)."
    else
        print_warning "Could not register Lumen with Claude Code - add it manually:"
        print_warning "  claude mcp add-json lumen '{\"command\":\"$LUMEN_WRAPPER\",\"args\":[\"stdio\"]}' -s user"
    fi
else
    print_warning "claude CLI not found - skipping Claude Code MCP registration."
fi

# Also ensure marketplace plugins are cloned for Claude
CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins/marketplaces"
mkdir -p "$CLAUDE_PLUGINS_DIR"
if [[ ! -d "$CLAUDE_PLUGINS_DIR/Sagargupta16/claude-cost-optimizer" ]]; then
    mkdir -p "$CLAUDE_PLUGINS_DIR/Sagargupta16"
    git clone https://github.com/Sagargupta16/claude-cost-optimizer.git "$CLAUDE_PLUGINS_DIR/Sagargupta16/claude-cost-optimizer" > /dev/null 2>&1 || true
fi
if [[ ! -d "$CLAUDE_PLUGINS_DIR/JCodesMore/jcodesmore-plugins" ]]; then
    mkdir -p "$CLAUDE_PLUGINS_DIR/JCodesMore"
    git clone https://github.com/JCodesMore/jcodesmore-plugins.git "$CLAUDE_PLUGINS_DIR/JCodesMore/jcodesmore-plugins" > /dev/null 2>&1 || true
fi
# Glyphdown hook.
# "ToolCall" is NOT a Claude Code hook event - the real events are PreToolUse
# and PostToolUse, each an array of {matcher, hooks:[{type,command}]}. The old
# shape wrote a key Claude Code ignores. We also refuse to register a hook for
# a binary that is not installed, which would fire and fail on every tool call.
# Opt-out: WIZARD_SKIP_GLYPHDOWN_HOOK=1 installs glyphdown but does NOT wire it
# into Claude Code. The hook fires on every tool call, so registering an
# unvetted binary there can disrupt a running session; this flag lets you defer
# that decision without skipping the rest of the setup.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [[ -n "${WIZARD_SKIP_GLYPHDOWN_HOOK:-}" ]]; then
    print_warning "WIZARD_SKIP_GLYPHDOWN_HOOK is set - glyphdown hook NOT registered."
    print_info "Enable it later by re-running without that variable."
elif ! check_command glyphdown; then
    print_warning "glyphdown not installed - skipping its Claude Code hook."
else
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    # Same ordering rule as configure_mcp_for_agent: snapshot before seeding.
    snapshot_before claude "$CLAUDE_SETTINGS"
    [[ -f "$CLAUDE_SETTINGS" ]] || echo '{}' > "$CLAUDE_SETTINGS"
    backup_file "$CLAUDE_SETTINGS" claude
    tmp=$(mktemp)
    if jq '
        def ensure($ev):
            .hooks[$ev] //= []
            | if ([.hooks[$ev][]?.hooks[]?.command] | index("glyphdown"))
              then .
              else .hooks[$ev] += [{"matcher":"*","hooks":[{"type":"command","command":"glyphdown"}]}]
              end;
        .hooks //= {} | ensure("PreToolUse") | ensure("PostToolUse")
    ' "$CLAUDE_SETTINGS" > "$tmp" && [[ -s "$tmp" ]]; then
        mv "$tmp" "$CLAUDE_SETTINGS"
        print_success "Glyphdown PreToolUse/PostToolUse hooks ensured for Claude Code."
    else
        rm -f "$tmp"
        print_warning "Could not update $CLAUDE_SETTINGS - left unchanged."
    fi
fi

# 5.2 Kimi - ~/.kimi-code/mcp.json, ".mcpServers" schema (verified on disk)
KIMI_CONFIG="$HOME/.kimi-code/mcp.json"
if [[ -d "$HOME/.kimi-code" ]]; then
    configure_mcp_for_agent "$KIMI_CONFIG" "Kimi" kimi
else
    print_warning "Kimi not installed (~/.kimi-code absent) - skipping its MCP config."
fi

# 5.3 Opencode - ~/.config/opencode/opencode.json, ".mcp" schema (NOT .mcpServers)
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
if [[ -f "$OPENCODE_CONFIG" ]]; then
    backup_file "$OPENCODE_CONFIG" opencode
    tmp=$(mktemp)
    if jq --arg bin "$LUMEN_WRAPPER" '
        .mcp //= {}
        | .mcp.lumen = {"type":"local","command":[$bin,"stdio"],"enabled":true}
    ' "$OPENCODE_CONFIG" > "$tmp" && [[ -s "$tmp" ]]; then
        mv "$tmp" "$OPENCODE_CONFIG"
        print_success "Lumen MCP configured for Opencode at $OPENCODE_CONFIG"
    else
        rm -f "$tmp"
        print_warning "Could not update $OPENCODE_CONFIG - left unchanged."
    fi
else
    print_warning "Opencode config not found at $OPENCODE_CONFIG - skipping."
fi

# 5.4 MiMo Code - ~/.mimocode exists but exposes no documented MCP config file.
# Guessing a path would create an orphan file and a false success tick.
MIMO_CONFIG=""
if [[ -d "$HOME/.mimocode" ]]; then
    print_warning "MiMo Code: no documented MCP config file - configure Lumen manually:"
    print_warning "  command: $LUMEN_WRAPPER   args: [\"stdio\"]"
else
    print_warning "MiMo Code not installed - skipping."
fi

# 5.5 Qwen Code - ~/.qwen/settings.json, ".mcpServers" schema (verified on disk)
QWEN_CONFIG="$HOME/.qwen/settings.json"
if [[ -d "$HOME/.qwen" ]]; then
    configure_mcp_for_agent "$QWEN_CONFIG" "Qwen Code" qwen
else
    print_warning "Qwen Code not installed (~/.qwen absent) - skipping its MCP config."
fi

# ------------------------------------------------------------------------------
# 7. Project-Level Setup (SpecKit + SuperSpec)
# ------------------------------------------------------------------------------
print_header "Step 6: Project-Level Setup (root = $PROJECT_ROOT)"
cd "$PROJECT_ROOT"

mkdir -p "submodules"
print_success "submodules directory ready."

# SpecKit Init
if check_command specify; then
    if [[ -d ".specify" ]] || [[ -d "specs" ]]; then
        print_success "SpecKit already initialized."
    else
        print_info "Initializing SpecKit..."
        specify init --force > /dev/null 2>&1 || specify init -y > /dev/null 2>&1 || true
        if [[ -d ".specify" ]] || [[ -d "specs" ]]; then print_success "SpecKit initialized."; else print_warning "SpecKit init may have failed."; fi
    fi
else
    print_warning "SpecKit CLI missing – skipping project init."
fi

# SuperSpec Submodule
SUPERSPEC_PATH="submodules/superspec"
setup_superspec "$PROJECT_ROOT" "$SUPERSPEC_PATH"

# Add SuperSpec as dev extension
if check_command specify && [[ -d "$SUPERSPEC_PATH" ]]; then
    print_info "Adding SuperSpec as SpecKit dev extension..."
    specify extension add ./submodules/superspec --dev > /dev/null 2>&1 || true
    print_success "SuperSpec extension added (or already present)."
else
    print_warning "Skipping SuperSpec extension (SpecKit CLI or path missing)."
fi

# ------------------------------------------------------------------------------
# 7b. Optional: build the code-intelligence indexes for this project
# ------------------------------------------------------------------------------
# Installing the indexers does not index anything. Both are OPT-IN here because
# a first Lumen pass on a large repository is CPU-bound on the embedding backend
# and can run for hours; CodeGraph is far quicker but still non-trivial.
#   WIZARD_INDEX_PROJECT=1   build/refresh both indexes for PROJECT_ROOT
if [[ -n "${WIZARD_INDEX_PROJECT:-}" ]]; then
    print_header "Step 7: Indexing This Project"

    if check_command codegraph; then
        if [[ -f "$PROJECT_ROOT/.codegraph/codegraph.db" ]]; then
            print_info "CodeGraph index exists - running incremental sync..."
            codegraph sync "$PROJECT_ROOT" 2>&1 | tail -3 || print_warning "codegraph sync failed."
        else
            print_info "No CodeGraph index yet - building it (this writes to .codegraph/)..."
            codegraph init "$PROJECT_ROOT" 2>&1 | tail -3 || print_warning "codegraph init failed."
        fi
        print_success "CodeGraph index step finished."
    else
        print_warning "codegraph not installed - skipping its index."
    fi

    if check_command lumen; then
        print_info "Lumen indexing $PROJECT_ROOT (incremental; may take a long time)..."
        if lumen index "$PROJECT_ROOT" 2>&1 | tail -3; then
            print_success "Lumen index step finished."
        else
            print_warning "lumen index failed - check the embedding backend."
        fi
    else
        print_warning "lumen not installed - skipping its index."
    fi
else
    print_info "Skipping project indexing (set WIZARD_INDEX_PROJECT=1 to build indexes)."
fi

# ------------------------------------------------------------------------------
# 8. Final Summary
# ------------------------------------------------------------------------------
print_header "Setup Complete – Final Summary"

echo -e "${CYAN}Installed Global Commands:${NC}"
for cmd in git node npm bun lumen codegraph glyphdown specify kimi opencode mimo qwen ashlr wozcode; do
    if check_command "$cmd"; then
        echo "  ✅ $cmd"
    else
        echo "  ❌ $cmd"
    fi
done

echo -e "\n${CYAN}Agent MCP Configurations (Lumen):${NC}"
# Each line reports what was ACTUALLY verified, not merely that a file exists.
# "n/a" means the agent is not installed; a warning above explains any gap.
if check_command claude && claude mcp get lumen >/dev/null 2>&1; then
    echo "  ✅ Claude Code   (registered via 'claude mcp', user scope)"
elif check_command claude; then
    echo "  ❌ Claude Code   (claude CLI present, lumen not registered)"
else
    echo "  ➖ Claude Code   n/a (claude CLI not installed)"
fi

if [[ -f "$KIMI_CONFIG" ]] && jq -e '.mcpServers.lumen' "$KIMI_CONFIG" >/dev/null 2>&1; then
    echo "  ✅ Kimi          ($KIMI_CONFIG)"
elif [[ -d "$HOME/.kimi-code" ]]; then
    echo "  ❌ Kimi          (installed, but lumen missing from $KIMI_CONFIG)"
else
    echo "  ➖ Kimi          n/a (not installed)"
fi

if [[ -f "$OPENCODE_CONFIG" ]] && jq -e '.mcp.lumen' "$OPENCODE_CONFIG" >/dev/null 2>&1; then
    echo "  ✅ Opencode      ($OPENCODE_CONFIG)"
elif [[ -f "$OPENCODE_CONFIG" ]]; then
    echo "  ❌ Opencode      (config present, lumen not added)"
else
    echo "  ➖ Opencode      n/a (config not found)"
fi

if [[ -d "$HOME/.mimocode" ]]; then
    echo "  ⚠️  MiMo Code     manual step required (no documented MCP config file)"
else
    echo "  ➖ MiMo Code     n/a (not installed)"
fi

if [[ -f "$QWEN_CONFIG" ]] && jq -e '.mcpServers.lumen' "$QWEN_CONFIG" >/dev/null 2>&1; then
    echo "  ✅ Qwen Code     ($QWEN_CONFIG)"
elif [[ -d "$HOME/.qwen" ]]; then
    echo "  ❌ Qwen Code     (installed, but lumen missing from $QWEN_CONFIG)"
else
    echo "  ➖ Qwen Code     n/a (not installed)"
fi

echo -e "\n${CYAN}Lumen Semantic Search:${NC}"
[[ -x "$LUMEN_WRAPPER" ]] && echo "  ✅ launcher ($LUMEN_WRAPPER)" || echo "  ❌ launcher"
[[ -r "$LUMEN_COMPLETION_DIR/lumen" ]] && echo "  ✅ bash completions" || echo "  ❌ bash completions"
grep -qF "$LUMEN_BLOCK_START" "$HOME/.bashrc" 2>/dev/null && echo "  ✅ ~/.bashrc block" || echo "  ❌ ~/.bashrc block"
grep -qF "$USERBIN_BLOCK_START" "$HOME/.bash_profile" 2>/dev/null && echo "  ✅ ~/.bash_profile login-shell PATH" || echo "  ❌ ~/.bash_profile login-shell PATH"
check_command ollama && echo "  ✅ ollama backend" || echo "  ❌ ollama backend"

ollama list 2>/dev/null | grep -qF "$LUMEN_EMBED_MODEL" && echo "  ✅ embedding model ($LUMEN_EMBED_MODEL)" || echo "  ❌ embedding model"

echo -e "\n${CYAN}Telemetry / analytics:${NC}"
if [[ -n "${WIZARD_KEEP_TELEMETRY:-}" ]]; then
    echo "  ➖ left untouched on request (WIZARD_KEEP_TELEMETRY)"
else
    grep -qF "$PRIVACY_BLOCK_START" "$HOME/.bashrc" 2>/dev/null \
        && echo "  ✅ DO_NOT_TRACK / CODEGRAPH_TELEMETRY exported in ~/.bashrc" \
        || echo "  ❌ shell opt-out block missing"
    if [[ -f "$HOME/.codegraph/telemetry.json" ]] && check_command jq; then
        [[ "$(jq -r '.enabled' "$HOME/.codegraph/telemetry.json" 2>/dev/null)" == "false" ]] \
            && echo "  ✅ CodeGraph telemetry disabled" || echo "  ❌ CodeGraph telemetry still enabled"
    fi
    if [[ -f "$HOME/.qwen/settings.json" ]] && check_command jq; then
        [[ "$(jq -r '.usageStatisticsEnabled | tostring' "$HOME/.qwen/settings.json")" == "false" ]] \
            && echo "  ✅ Qwen usage statistics disabled" || echo "  ⚠️  Qwen usage statistics not disabled"
    fi
    echo "  ➖ Lumen ships no telemetry (verified: no analytics strings in binary)"
fi

echo -e "\n${CYAN}Project (Current: $PROJECT_ROOT):${NC}"
[[ -d "$PROJECT_ROOT/.specify" || -d "$PROJECT_ROOT/specs" ]] && echo "  ✅ SpecKit init" || echo "  ❌ SpecKit init"
[[ -e "$PROJECT_ROOT/$SUPERSPEC_PATH/.git" ]] && echo "  ✅ SuperSpec submodule" || echo "  ❌ SuperSpec submodule"
if [[ -f "$CLAUDE_SETTINGS" ]] && grep -q "glyphdown" "$CLAUDE_SETTINGS" 2>/dev/null; then
    echo "  ✅ Glyphdown Hook (Claude)"
elif [[ -n "${WIZARD_SKIP_GLYPHDOWN_HOOK:-}" ]]; then
    echo "  ➖ Glyphdown Hook  skipped on request (WIZARD_SKIP_GLYPHDOWN_HOOK)"
else
    echo "  ❌ Glyphdown Hook"
fi

echo -e "\n${GREEN}All automated steps executed.${NC}"
echo -e "${BLUE}📌 Next steps for each agent:${NC}"
echo "  1. Restart your terminal / IDE to refresh PATH."
echo "  2. For Claude Code: restart the extension, then run '/cost-mode' and '/fixclaude'."
echo "  3. For Opencode: run 'opencode' – Lumen is loaded from ~/.config/opencode/opencode.json (.mcp)."
echo "  4. For Kimi: ~/.kimi-code/mcp.json   Qwen: ~/.qwen/settings.json   (both .mcpServers)."
echo "     MiMo Code has no documented MCP config file - add Lumen manually if you use it."
echo "  5. All agents can now use 'lumen' and 'codegraph' for semantic understanding and efficient symbol reading."
echo "  6. Index this project once:  lumen index \"$PROJECT_ROOT\""
echo "     Then search it:           lumen search \"how does X work\" -p \"$PROJECT_ROOT\""
echo "     Indexing is incremental - re-run it after large external edits."

exit 0

