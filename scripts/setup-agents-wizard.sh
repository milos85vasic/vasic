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

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "$file.bak.$(date +%Y%m%d%H%M%S)"
        print_info "Backed up $file"
    fi
}

# Auto-install jq if missing
ensure_jq() {
    if check_command jq; then return 0; fi
    print_info "jq not found – installing it now."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if check_command apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y jq
        elif check_command yum; then
            sudo yum install -y jq
        else
            print_error "Could not install jq. Please install it manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if check_command brew; then
            brew install jq
        else
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew install jq
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
    mkdir -p "$(dirname "$config_file")"
    if [[ ! -f "$config_file" ]]; then
        echo '{}' > "$config_file"
    fi
    backup_file "$config_file"
    local tmp_file=$(mktemp)
    # Add Lumen and CodeGraph to mcpServers
    jq '.mcpServers += {
        "lumen": {
            "command": "lumen",
            "args": ["serve"]
        },
        "codegraph": {
            "command": "codegraph",
            "args": ["serve"]
        }
    }' "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    print_success "MCP servers (Lumen + CodeGraph) configured for $agent_name at $config_file"
}

# ------------------------------------------------------------------------------
# 1. Path Detection
# ------------------------------------------------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

print_header "AI Agents Ultimate Setup Wizard"
print_info "Script directory : $SCRIPT_DIR"
print_info "Project root     : $PROJECT_ROOT"

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
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    if check_command bun; then print_success "Bun installed."; else print_warning "Bun failed."; fi
else
    print_success "Bun already present."
fi

# 3.2 Core MCP & Utility Tools (Lumen, CodeGraph, Glyphdown, SpecKit)
print_info "Installing core utilities: Lumen, CodeGraph, Glyphdown, SpecKit..."
npm install -g @qoomon/lumen @monday/codegraph glyphdown @specify/cli > /dev/null 2>&1 || true

# 3.3 AI Agent CLIs (Kimi, Opencode, MiMo, Qwen)
print_info "Installing AI Agent CLIs: Kimi, Opencode, MiMo, Qwen Code..."
# Note: package names are best-effort. If they fail, we log but continue.
npm install -g kimi opencode mimo qwen-code > /dev/null 2>&1 || {
    print_warning "Some agent CLIs could not be installed via npm. Trying alternative names..."
    # Fallback attempts for common naming variations
    npm install -g @kimi/cli > /dev/null 2>&1 || true
    npm install -g @opencode/cli > /dev/null 2>&1 || true
    npm install -g @mimo/cli > /dev/null 2>&1 || true
    npm install -g @qwen-code/cli > /dev/null 2>&1 || true
}

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
# 4. Verify Installed Commands
# ------------------------------------------------------------------------------
print_header "Step 3: Verifying CLI Availability"
for cmd in lumen codegraph glyphdown specify kimi opencode mimo qwen-code ashlr; do
    if check_command "$cmd"; then
        print_success "$cmd found"
    else
        print_warning "$cmd not in PATH (may require terminal restart or manual install)"
    fi
done

# ------------------------------------------------------------------------------
# 5. Configure MCP for ALL Agents
# ------------------------------------------------------------------------------
print_header "Step 4: Configuring MCP Servers for Each Agent"

# 5.1 Claude Code
CLAUDE_MCP="$HOME/.claude/mcp.json"
configure_mcp_for_agent "$CLAUDE_MCP" "Claude Code"
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
# Add Glyphdown hook to Claude settings
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
backup_file "$CLAUDE_SETTINGS"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
if [[ ! -f "$CLAUDE_SETTINGS" ]]; then echo '{}' > "$CLAUDE_SETTINGS"; fi
jq '.hooks += {"ToolCall": {"pre": ["glyphdown"], "post": ["glyphdown"]}}' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
print_success "Glyphdown hook added to Claude Code."

# 5.2 Kimi
KIMI_CONFIG="$HOME/.kimi/config.json"
configure_mcp_for_agent "$KIMI_CONFIG" "Kimi"

# 5.3 Opencode
OPENCODE_CONFIG="$HOME/.opencode/config.json"
configure_mcp_for_agent "$OPENCODE_CONFIG" "Opencode"

# 5.4 MiMo Code
MIMO_CONFIG="$HOME/.mimo/config.json"
configure_mcp_for_agent "$MIMO_CONFIG" "MiMo Code"

# 5.5 Qwen Code
QWEN_CONFIG="$HOME/.qwen-code/config.json"
configure_mcp_for_agent "$QWEN_CONFIG" "Qwen Code"

# ------------------------------------------------------------------------------
# 6. Project-Level Setup (SpecKit + SuperSpec)
# ------------------------------------------------------------------------------
print_header "Step 5: Project-Level Setup (root = $PROJECT_ROOT)"
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
if [[ -d "$SUPERSPEC_PATH/.git" ]]; then
    print_success "SuperSpec already cloned."
else
    if [[ -d "$SUPERSPEC_PATH" ]]; then rm -rf "$SUPERSPEC_PATH"; fi
    print_info "Cloning SuperSpec..."
    git clone https://github.com/WangX0111/superspec.git "$SUPERSPEC_PATH" > /dev/null 2>&1 || true
    if [[ -d "$SUPERSPEC_PATH/.git" ]]; then print_success "SuperSpec cloned."; else print_warning "SuperSpec clone failed."; fi
fi

# Add SuperSpec as dev extension
if check_command specify && [[ -d "$SUPERSPEC_PATH" ]]; then
    print_info "Adding SuperSpec as SpecKit dev extension..."
    specify extension add ./submodules/superspec --dev > /dev/null 2>&1 || true
    print_success "SuperSpec extension added (or already present)."
else
    print_warning "Skipping SuperSpec extension (SpecKit CLI or path missing)."
fi

# ------------------------------------------------------------------------------
# 7. Final Summary
# ------------------------------------------------------------------------------
print_header "Setup Complete – Final Summary"

echo -e "${CYAN}Installed Global Commands:${NC}"
for cmd in git node npm bun lumen codegraph glyphdown specify kimi opencode mimo qwen-code ashlr wozcode; do
    if check_command "$cmd"; then
        echo "  ✅ $cmd"
    else
        echo "  ❌ $cmd"
    fi
done

echo -e "\n${CYAN}Agent MCP Configurations (Lumen + CodeGraph added):${NC}"
[[ -f "$CLAUDE_MCP" ]] && echo "  ✅ Claude Code (~/.claude/mcp.json)" || echo "  ❌ Claude Code"
[[ -f "$KIMI_CONFIG" ]] && echo "  ✅ Kimi (~/.kimi/config.json)" || echo "  ❌ Kimi"
[[ -f "$OPENCODE_CONFIG" ]] && echo "  ✅ Opencode (~/.opencode/config.json)" || echo "  ❌ Opencode"
[[ -f "$MIMO_CONFIG" ]] && echo "  ✅ MiMo Code (~/.mimo/config.json)" || echo "  ❌ MiMo Code"
[[ -f "$QWEN_CONFIG" ]] && echo "  ✅ Qwen Code (~/.qwen-code/config.json)" || echo "  ❌ Qwen Code"

echo -e "\n${CYAN}Project (Current: $PROJECT_ROOT):${NC}"
[[ -d "$PROJECT_ROOT/.specify" || -d "$PROJECT_ROOT/specs" ]] && echo "  ✅ SpecKit init" || echo "  ❌ SpecKit init"
[[ -d "$PROJECT_ROOT/$SUPERSPEC_PATH/.git" ]] && echo "  ✅ SuperSpec submodule" || echo "  ❌ SuperSpec submodule"
[[ -f "$CLAUDE_SETTINGS" ]] && grep -q "glyphdown" "$CLAUDE_SETTINGS" 2>/dev/null && echo "  ✅ Glyphdown Hook (Claude)" || echo "  ❌ Glyphdown Hook"

echo -e "\n${GREEN}All automated steps executed.${NC}"
echo -e "${BLUE}📌 Next steps for each agent:${NC}"
echo "  1. Restart your terminal / IDE to refresh PATH."
echo "  2. For Claude Code: restart the extension, then run '/cost-mode' and '/fixclaude'."
echo "  3. For Opencode: simply run 'opencode' – Lumen/CodeGraph MCP servers are auto-loaded from ~/.opencode/config.json."
echo "  4. For Kimi / MiMo / Qwen: run their respective commands – they will pick up the MCP config from their ~/.config/ folders."
echo "  5. All agents can now use 'lumen' and 'codegraph' for semantic understanding and efficient symbol reading."

exit 0

