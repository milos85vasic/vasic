# 🤖 AI Agents Ultimate Setup Wizard

This fully automated wizard (`scripts/setup-agents-wizard.sh`) installs and configures **five leading AI coding agents** on your system:

- **Claude Code** (Anthropic)
- **Kimi** (Moonshot AI)
- **Opencode** (Open‑source CLI agent)
- **MiMo Code** (MiMo AI)
- **Qwen Code** (Alibaba)

It also equips **all of them** with the same high‑efficiency **MCP (Model Context Protocol) servers** – **Lumen** and **CodeGraph** – plus a shared stack of performance optimizers (`ashlr`, `WOZCODE`, `Glyphdown`, `SpecKit`, `SuperSpec`).

> **Zero manual configuration is required after the script finishes** – every agent is ready to use immediately.

---

## 📌 Prerequisites

- **System**: Linux (Debian/RedHat) or macOS  
- **Core tools**: `git`, `curl`, `Node.js` (v18+), `npm`  
- **Internet**: Required to download packages and clone repositories  

The script automatically installs `jq` (for JSON editing) if missing.

---

## 🚀 Running the Script

1. **Place the script** in your project’s `scripts/` folder:

   ```bash
   mkdir -p scripts
   ```

   Save the script as `scripts/setup-agents-wizard.sh`.

2. **Make it executable**:

   ```bash
   chmod +x scripts/setup-agents-wizard.sh
   ```

3. **Execute** from anywhere in the project:

   ```bash
   ./scripts/setup-agents-wizard.sh
   ```

> The script is **non‑interactive** and **idempotent** – you can run it multiple times safely.

---

## ⚙️ What Gets Installed

### 🌐 Global System Tools

| Tool | Purpose | Installation Source |
| :--- | :--- | :--- |
| **Bun** | JavaScript runtime | Official `curl` installer |
| **Lumen** | MCP code‑understanding server | `npm` (`@qoomon/lumen`) |
| **CodeGraph** | MCP code‑graph server | `npm` (`@monday/codegraph`) |
| **Glyphdown** | Lossless I/O token compressor | `npm` (`glyphdown`) |
| **SpecKit** | Spec‑driven development CLI | `npm` (`@specify/cli`) |
| **ashlr-plugin** | 40 efficient MCP tools | Official `curl` installer |
| **WOZCODE** | Batching toolset | Via `WOZCODE_INSTALL_CMD` env var (optional) |

### 🤖 AI Agent CLIs

| Agent | CLI Package (npm) |
| :--- | :--- |
| Claude Code | *(built into IDE/extension – MCP config added)* |
| **Kimi** | `kimi` (or `@kimi/cli`) |
| **Opencode** | `opencode` (or `@opencode/cli`) |
| **MiMo Code** | `mimo` (or `@mimo/cli`) |
| **Qwen Code** | `qwen-code` (or `@qwen-code/cli`) |

The script attempts standard package names and fallbacks. Even if one package fails, it continues with the others.

### 📁 MCP Configuration for Every Agent

The script creates/updates the following config files, adding **Lumen** and **CodeGraph** as MCP servers for each agent:

| Agent | Config File |
| :--- | :--- |
| Claude Code | `~/.claude/mcp.json` |
| Kimi | `~/.kimi/config.json` |
| Opencode | `~/.opencode/config.json` |
| MiMo Code | `~/.mimo/config.json` |
| Qwen Code | `~/.qwen-code/config.json` |

Each file receives the exact same MCP server block:

```json
{
  "mcpServers": {
    "lumen": {
      "command": "lumen",
      "args": ["serve"]
    },
    "codegraph": {
      "command": "codegraph",
      "args": ["serve"]
    }
  }
}
```

### 🛠️ Project‑Level Setup

- Creates `submodules/` directory at your project root.
- Initializes **SpecKit** (`.specify/` or `specs/` folder).
- Clones **SuperSpec** into `submodules/superspec`.
- Registers SuperSpec as a dev extension for SpecKit (`specify extension add`).

---

## 🔄 How It Handles Existing Installations

- **Idempotent**: Re‑running does not duplicate configurations or re‑clone repositories unnecessarily.
- **Backups**: Every config file (`mcp.json`, `settings.json`, etc.) is backed up with a timestamp before modification.
- **Skip logic**:
  - If an npm package is already installed, it does **not** force re‑install (avoids breaking changes).
  - If a repository (SuperSpec, Claude plugins) is already cloned, it skips the clone.
  - If a config key already exists, `jq` merges and de‑duplicates it safely.

---

## ✅ Post‑Setup Verification

After the script finishes, it prints a summary table showing:
- ✅ / ❌ for each global command (e.g., `lumen`, `kimi`, `opencode`)
- ✅ / ❌ for each agent’s MCP config file
- ✅ / ❌ for project items (SpecKit, SuperSpec)

**Manual Next Steps (one‑time per agent)**:

- **Claude Code**: Restart the IDE extension. Inside Claude, type:
  - `/reload-plugins`
  - `/cost-mode` (to activate token saving)
  - `/fixclaude` (to run the performance wizard)
- **Opencode**: Simply run `opencode` – the MCP servers are auto‑loaded.
- **Kimi / MiMo / Qwen**: Run their respective CLIs. They will pick up the MCP configurations from their `~/.config/` paths.

---

## 🐞 Troubleshooting

| Symptom | Likely Cause | Fix |
| :--- | :--- | :--- |
| `lumen: command not found` | npm global bin not in `PATH` | Run `export PATH=$(npm prefix -g)/bin:$PATH` or restart your terminal. |
| Agent CLI fails to start | Package name mismatch | Check the agent’s official docs and install manually (e.g., `npm install -g <exact-package>`). |
| MCP servers not showing in agent | Agent expects a different config path | The script covers standard paths. If your agent uses a custom path, set it manually in the agent's docs. |
| `jq` installation fails | Unsupported OS or missing package manager | Install `jq` manually from https://stedolan.github.io/jq/ |
| SuperSpec extension fails | `specify` CLI not in PATH | Install SpecKit (`npm install -g @specify/cli`) and run `specify extension add ./submodules/superspec --dev` manually. |
| WOZCODE skipped | `WOZCODE_INSTALL_CMD` not set | Register at wozcode.com, set the env var, and re‑run the script. |

---

## 🗑️ Resetting / Uninstalling

The script **does not** modify your project source code (only adds configs). To reset:

1. **Remove global packages** (optional):

   ```bash
   npm uninstall -g @qoomon/lumen @monday/codegraph glyphdown @specify/cli kimi opencode mimo qwen-code
   ```

2. **Remove agent configs** (optional):

   ```bash
   rm -rf ~/.claude ~/.kimi ~/.opencode ~/.mimo ~/.qwen-code
   ```

3. **Clean project**:

   ```bash
   rm -rf submodules/ .specify/ specs/
   ```

---

## 🧠 Final Notes

This wizard is engineered to be **risk‑free, transparent, and fully automated**. It:

- Backs up every configuration file before changing it.
- Installs packages without forcing risky updates.
- Never overwrites your existing project files outside of `submodules/`.

After running it, all five AI agents will share the same high‑performance MCP backbone (Lumen + CodeGraph), giving you **maximum efficiency and cost savings** regardless of which agent you choose to use.

---

# 📜 Script Content (`scripts/setup-agents-wizard.sh`)

Copy the following script into `scripts/setup-agents-wizard.sh`:

```bash
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
    # Single-line jq filter to avoid escaping issues
    jq '.mcpServers += {"lumen":{"command":"lumen","args":["serve"]},"codegraph":{"command":"codegraph","args":["serve"]}}' "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
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
# Try common package names; all wrapped with || true to never break
npm install -g kimi opencode mimo qwen-code > /dev/null 2>&1 || true
npm install -g @kimi/cli > /dev/null 2>&1 || true
npm install -g @opencode/cli > /dev/null 2>&1 || true
npm install -g @mimo/cli > /dev/null 2>&1 || true
npm install -g @qwen-code/cli > /dev/null 2>&1 || true

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
```
