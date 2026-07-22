#!/usr/bin/env bash
set -euo pipefail

#############################################
# Agentic Coders Installer v1.14.5
# Interactive installer for AI coding CLI tools
#
# Version history: v1.7.6 added security improvements, v1.7.12 fixed oh-my-opencode version detection
# v1.9.4 added ast-grep auto-installation after MoAI-ADK installation
# v1.9.5 version sync, error handling fixes, CHANGELOG cleanup
# v1.9.6 fix Windows action summary display, curl SSL fallback, npm check error suppression
# v1.9.7 reorder tools (Claude Code before MoAI-ADK), require Claude Code for MoAI-ADK install
# v1.9.9 fix conda detection in non-interactive script context (shell function vs binary)
# v1.9.10 fix tput failure on terminals with missing terminfo entries
# v1.9.11 setup.sh auto-configures PATH and CLI aliases
# v1.9.12 fix clear command failure when terminfo database is inaccessible
# v1.9.13 remove spurious Claude checksum warnings (Anthropic doesn't publish checksums)
# v1.10.0 fix Claude Code CLI installation failure on Windows (isolated child cmd.exe)
# v1.11.0 remove MoAI-ADK bootstrapper same-origin checksum (upstream doesn't publish .sha256;
#         check was security theater. MoAI-ADK's own downstream binary verification is preserved)
# v1.12.0 replace retired Gemini CLI with Antigravity CLI (native `agy` installer);
#         purge the Gemini CLI entry, its oh-my-opencode auto-detect, AND the static
#         --gemini=no flag (--gemini=no is the documented default in oh-my-opencode's install
#         guide, so omitting it is behaviorally safe; Gemini CLI is retired). Earlier
#         "v3.7.4+ requires --gemini" and "the flag never existed" notes were both inaccurate.
# v1.13.0 security + Windows parity: gate Windows insecure curl -k behind consent; block the Claude
#         binary on Authenticode HashMismatch; add distinct Windows "upgrade" action state (parity
#         with the .sh 4-state cycle); emit all 9 documented oh-my-opencode provider flags; normalize
#         install_coding_tools.bat to uniform CRLF; document setup.bat platform divergence.
# v1.13.1 fix setup.sh WSL Windows-account detection on interop-disabled hosts: the /mnt/c/Users
#         fallback no longer picks the alphabetically-first dir (Administrator, unwritable); add a
#         WIN_USER override + built-in-account skip list + writable/most-recently-used (NTUSER.DAT)
#         heuristic. setup.sh-only fix; other scripts version-synced.
# v1.14.0 remove Google Jules CLI from the tool menu (per user request). Windows .bat also: fix
#         Antigravity remove to target %LOCALAPPDATA%\agy\bin\agy.exe (the Windows install location,
#         not the Linux ~/.local/bin), detect agy there before a PATH-refreshing terminal restart,
#         and suppress a cosmetic stderr leak on the Claude Code upgrade path.
# v1.14.1 add Antigravity latest-version detection: query its official release manifest (the Cloud
#         Run auto-updater endpoint its installer uses) so the menu shows/compares Antigravity's
#         latest like the other tools; degrades to "Unknown" on fetch failure.
# v1.14.2 setup.sh now announces the deployed installer version in its summary (parsed from the
#         install_coding_tools.sh header), with the version shown inline next to each script.
# v1.14.3 self-heal broken conda node/npm: validate the conda env's OWN node (not the first node
#         on PATH), repair Node.js BEFORE touching npm, retry failed conda solves through a
#         3-step ladder (pinned install → update → unpinned install), and when npm is missing
#         or broken even though Node.js is current, bootstrap npm from the official registry
#         tarball using the env's node (automates the manual "update node, then install npm"
#         recovery). Windows .bat gains the same conda retry ladder + npm bootstrap fallback.
# - Secure temporary file creation with restrictive permissions
# - TLS-pinned downloads via curl --proto '=https' --tlsv1.2
#############################################

# Non-interactive mode flag
AUTO_YES=false
SKIP_SYSTEM_NPM=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            AUTO_YES=true
            shift
            ;;
        --skip-system-npm)
            SKIP_SYSTEM_NPM=true
            shift
            ;;
        --help|-h)
            printf "Usage: %s [--yes|-y] [--skip-system-npm] [--help|-h]\n" "$0"
            printf "\nOptions:\n"
            printf "  --yes, -y        Non-interactive mode (auto-proceed with defaults)\n"
            printf "  --skip-system-npm  Legacy no-op (kept for backward compatibility)\n"
            printf "  --help, -h       Show this help message\n"
            exit 0
            ;;
        *)
            printf "Unknown option: %s\n" "$1"
            printf "Use --help for usage information\n"
            exit 1
            ;;
    esac
done

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color
# Minimum versions (npm has its own versioning, separate from Node.js)
# Node.js 22.9.0+ is required for modern npm (npm 11.x)
# npm 10+ is sufficient for most modern tools
readonly MIN_NODEJS_VERSION="22.9.0"
readonly MIN_NPM_VERSION="10.0.0"
readonly STATE_DIR="$HOME/.local/share/agentic-cli-installer"
readonly MOAI_STATE_FILE="$STATE_DIR/moai-adk.path"
readonly CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
readonly MOAI_INSTALL_URL="https://raw.githubusercontent.com/modu-ai/moai-adk/main/install.sh"
readonly ANTIGRAVITY_INSTALL_URL="https://antigravity.google/cli/install.sh"
# Note: the MoAI-ADK bootstrapper is fetched over TLS from GitHub. The MoAI-ADK
# installer itself verifies the SHA-256 of the downloaded binary tarball against
# a hash committed to its release metadata, so redundant same-origin checksum
# verification of the bootstrapper was removed in v1.11.0.

# Tool definitions: name, package manager, package name, description
declare -a TOOLS=(
    "claude-code|native|claude-code|Claude Code CLI"
    "moai-adk|native|moai-adk|MoAI Agent Development Kit"
    "@openai/codex|npm|@openai/codex|OpenAI Codex CLI"
    "antigravity|native|antigravity|Antigravity CLI"
    "opencode-ai|npm|opencode-ai|OpenCode AI CLI"
    "oh-my-opencode|addon|oh-my-opencode|OpenCode - oh-my-opencode"
)

# Arrays to store tool information
declare -a TOOL_NAMES=()
declare -a TOOL_MANAGERS=()
declare -a TOOL_PACKAGES=()
declare -a TOOL_DESCRIPTIONS=()
declare -a INSTALLED_VERSIONS=()
declare -a LATEST_VERSIONS=()
declare -a SELECTED=()
declare -a LATEST_VERSION_CACHE=()
declare -a UPDATE_ONLY=()  # Flag for tools that can only be updated (not installed/removed)

# Cached version data to avoid repeated slow calls
UV_TOOL_LIST_CACHE=""
UV_TOOL_LIST_READY=0
NPM_LIST_JSON_CACHE=""
NPM_LIST_JSON_READY=0
CONDA_CMD=""  # Resolved conda command path (set by resolve_conda_cmd)

# PERF-003: Cache subprocess paths for npm/conda detection
_CACHED_NPM_BIN=""
_CACHED_NODE_BIN=""
_CACHED_CONDA_ROOT=""

# Action states for tool selection
declare -a ACTIONS=("skip" "install" "upgrade" "remove")
declare -a TOOL_ACTIONS=()

#############################################
# UTILITY FUNCTIONS
#############################################

log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$*"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$*" >&2
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$*" >&2
}

log_legacy_flags_note() {
    if [[ "$SKIP_SYSTEM_NPM" == true ]]; then
        log_info "--skip-system-npm is deprecated (no system npm check is performed)."
    fi
}

supports_utf8() {
    local locale="${LC_ALL:-}${LC_CTYPE:-}${LANG:-}"
    [[ "$locale" == *"UTF-8"* || "$locale" == *"utf8"* || "$locale" == *"UTF8"* ]]
}

# UI drawing characters (UTF-8 when available, ASCII fallback)
UI_HLINE="-"
UI_VLINE="|"
UI_TL="+"
UI_TR="+"
UI_BL="+"
UI_BR="+"

init_ui_chars() {
    if supports_utf8; then
        UI_HLINE="─"
        UI_VLINE="│"
        UI_TL="┌"
        UI_TR="┐"
        UI_BL="└"
        UI_BR="┘"
    fi
}

init_ui_chars

repeat_char() {
    local ch=$1
    local count=$2
    local out=""
    for ((i=0; i<count; i++)); do
        out+="$ch"
    done
    printf "%s" "$out"
}

print_section() {
    printf "\n${BOLD}[%s]${NC}\n" "$1"
}

print_box_header() {
    local title=$1
    local subtitle=$2

    local width
    width=$(tput cols 2>/dev/null || echo 80)
    if [[ "$width" -gt 92 ]]; then
        width=92
    elif [[ "$width" -lt 60 ]]; then
        width=60
    fi

    local inner=$((width - 2))
    printf "%s%s%s\n" "$UI_TL" "$(repeat_char "$UI_HLINE" "$inner")" "$UI_TR"
    printf "%s %-*s%s\n" "$UI_VLINE" "$((inner - 1))" "$title" "$UI_VLINE"
    printf "%s %-*s%s\n" "$UI_VLINE" "$((inner - 1))" "$subtitle" "$UI_VLINE"
    printf "%s%s%s\n" "$UI_BL" "$(repeat_char "$UI_HLINE" "$inner")" "$UI_BR"
}

print_header() {
    printf "\n${CYAN}${BOLD}%s${NC}\n" "$*"
}

print_sep() {
    # Get terminal width, default to 80 if unavailable
    local width
    width=$(tput cols 2>/dev/null || echo 80)
    # Create separator line that fills terminal width
    local sep
    sep=$(repeat_char "$UI_HLINE" "$width")
    printf "${CYAN}%s${NC}\n" "$sep"
}

clear_screen() {
    clear 2>/dev/null || printf '\033[2J\033[H'
}


require_cmd() {
    local cmd=$1
    local hint=${2:-}
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "$cmd not found. $hint"
        return 1
    fi
    return 0
}

get_conda_root() {
    if [[ -n "${CONDA_CMD:-}" ]]; then
        "$CONDA_CMD" info --base 2>/dev/null && return 0
    elif command -v conda >/dev/null 2>&1; then
        conda info --base 2>/dev/null && return 0
    fi
    # Fallback: Try to detect from common paths if conda command fails
    local conda_fallbacks=(
        "$HOME/miniconda3"
        "$HOME/anaconda3"
        "$HOME/miniforge3"
        "/opt/miniconda3"
        "/opt/anaconda3"
        "/usr/local/miniconda3"
        "/usr/local/anaconda3"
    )
    for path in "${conda_fallbacks[@]}"; do
        if [[ -d "$path" ]]; then
            printf "%s" "$path"
            return 0
        fi
    done
    return 1
}

# Resolve conda command path - handles shell function vs binary detection.
# When a script runs as a child process (./script.sh or bash script.sh),
# conda shell functions from .bashrc are NOT inherited even though
# CONDA_PREFIX and CONDA_EXE env vars are. This function finds the actual
# conda binary so the installer can invoke conda commands reliably.
resolve_conda_cmd() {
    # 1. Shell function or PATH binary
    if command -v conda >/dev/null 2>&1; then
        printf "conda"
        return 0
    fi
    # 2. CONDA_EXE is set by conda activation
    if [[ -n "${CONDA_EXE:-}" && -x "$CONDA_EXE" ]]; then
        printf "%s" "$CONDA_EXE"
        return 0
    fi
    # 3. Derive from CONDA_PREFIX (works for both base and named envs)
    if [[ -n "${CONDA_PREFIX:-}" ]]; then
        local conda_base="$CONDA_PREFIX"
        # Named env path: .../miniconda3/envs/myenv -> .../miniconda3
        if [[ "$conda_base" == */envs/* ]]; then
            conda_base="${conda_base%/envs/*}"
        fi
        for subpath in condabin/conda bin/conda; do
            if [[ -x "$conda_base/$subpath" ]]; then
                printf "%s" "$conda_base/$subpath"
                return 0
            fi
        done
    fi
    # 4. Common installation paths
    local fallbacks=(
        "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3"
        "/opt/miniconda3" "/opt/anaconda3"
        "/usr/local/miniconda3" "/usr/local/anaconda3"
    )
    for base in "${fallbacks[@]}"; do
        for subpath in condabin/conda bin/conda; do
            if [[ -x "$base/$subpath" ]]; then
                printf "%s" "$base/$subpath"
                return 0
            fi
        done
    done
    return 1
}

get_conda_env_bin_dir() {
    # Resolve the active conda environment's bin directory. Unlike
    # get_conda_npm_path, this succeeds even when npm/node are not yet
    # installed in the environment (needed to repair such environments).
    if [[ -n "${CONDA_PREFIX:-}" ]]; then
        # Verify CONDA_PREFIX is a valid directory with bin subdirectory
        if [[ ! -d "$CONDA_PREFIX/bin" ]]; then
            log_warning "CONDA_PREFIX/bin does not exist: $CONDA_PREFIX"
            return 1
        fi
        printf "%s" "$CONDA_PREFIX/bin"
        return 0
    fi
    if [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
        local conda_root
        conda_root=$(get_conda_root)
        if [[ -n "$conda_root" ]]; then
            local env_path="$conda_root/envs/$CONDA_DEFAULT_ENV"
            # Verify environment directory exists
            if [[ ! -d "$env_path" ]]; then
                log_warning "CONDA_DEFAULT_ENV points to non-existent environment: $CONDA_DEFAULT_ENV"
                return 1
            fi
            printf "%s" "$env_path/bin"
            return 0
        fi
    fi
    return 1
}

get_conda_npm_path() {
    # Get npm path from active conda environment
    local env_bin
    env_bin=$(get_conda_env_bin_dir) || return 1
    # Check if npm exists in the conda environment
    if [[ ! -x "$env_bin/npm" ]]; then
        # npm not installed in this conda environment (not an error)
        return 1
    fi
    printf "%s" "$env_bin/npm"
    return 0
}

get_conda_node_path() {
    # Node.js binary belonging to the active conda environment. Checked
    # explicitly by path: a newer system/nvm node earlier on PATH must not
    # mask an outdated conda node (and vice versa).
    local env_bin
    env_bin=$(get_conda_env_bin_dir) || return 1
    if [[ ! -x "$env_bin/node" ]]; then
        return 1
    fi
    printf "%s" "$env_bin/node"
    return 0
}

get_npm_bin() {
    local npm_path
    npm_path=$(get_conda_npm_path || true)
    if [[ -n "$npm_path" && -x "$npm_path" ]]; then
        printf "%s" "$npm_path"
        return 0
    fi
    return 1
}

get_npm_node_bin() {
    local npm_bin
    npm_bin=$(get_npm_bin) || return 1
    local node_bin
    node_bin="$(dirname "$npm_bin")/node"
    if [[ -x "$node_bin" ]]; then
        printf "%s" "$node_bin"
        return 0
    fi
    return 1
}

get_npm_version_from_path() {
    local npm_path=$1
    if [[ -x "$npm_path" ]]; then
        "$npm_path" --version 2>/dev/null | head -n1 || true
    fi
}

sha256_file() {
    local file=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi
    return 1
}

verify_file_sha256() {
    local file=$1
    local expected=$2
    local actual
    actual=$(sha256_file "$file" 2>/dev/null || true)
    if [[ -z "$actual" ]]; then
        log_error "No SHA-256 tool available to verify installer integrity."
        return 1
    fi
    if [[ "$actual" != "$expected" ]]; then
        log_error "Installer checksum mismatch. expected=$expected actual=$actual"
        return 1
    fi
    return 0
}

record_moai_install_path() {
    local moai_bin
    moai_bin=$(command -v moai 2>/dev/null || true)
    if [[ -z "$moai_bin" ]]; then
        return 1
    fi
    mkdir -p "$STATE_DIR"
    printf "%s\n" "$moai_bin" > "$MOAI_STATE_FILE"
    return 0
}

#############################################
# HTTP CLIENT AND VERSION UTILITIES
#############################################

# Shared HTTP client with connection pooling for API calls
make_http_request() {
    local url="$1"
    local timeout="${2:-10}"
    local max_retries="${3:-1}"
    local retry_delay="${4:-0}"

    for attempt in $(seq 1 $max_retries); do
        if [[ $attempt -gt 1 ]]; then
            sleep $retry_delay
        fi

        if ! response=$(curl -fsSL --connect-timeout 5 --max-time $timeout "$url" 2>/dev/null); then
            if [[ $attempt -eq $max_retries ]]; then
                return 1
            fi
        else
            echo "$response"
            return 0
        fi
    done
    return 1
}

#############################################
# CLAUDE CODE SANDBOX DEPENDENCIES
#############################################

# Check for bubblewrap availability and warn if missing
check_bubblewrap() {
    if command -v bwrap >/dev/null 2>&1; then
        return 0
    fi

    # bubblewrap not found - show warning with installation instructions
    printf "\n  ${YELLOW}[WARNING]${NC} bubblewrap (bwrap) is not installed\n"
    printf "  ${YELLOW}[WARNING]${NC} This is optional but recommended for Claude Code sandbox security\n\n"
    printf "  ${CYAN}To install bubblewrap:${NC}\n"
    printf "    ${GREEN}sudo apt install bubblewrap${NC}\n\n"
    printf "  ${YELLOW}Note: Installation will continue without bubblewrap${NC}\n\n"
    return 0
}

# Install or update seccomp filter for Claude Code sandbox
install_seccomp_filter() {
    local npm_bin
    npm_bin=$(get_npm_bin || true)

    if [[ -z "$npm_bin" ]]; then
        log_warning "npm not found, skipping seccomp filter installation"
        return 0
    fi

    local package="@anthropic-ai/sandbox-runtime"
    local current_version=""
    local latest_version=""

    # Check if currently installed
    if current_version=$("$npm_bin" list -g --depth=0 --json 2>/dev/null | grep -o "\"$package\":\"[^\"]*\"" | cut -d'"' -f4); then
        if [[ "$current_version" != "null" && -n "$current_version" ]]; then
            printf "  ${BLUE}[INFO]${NC} seccomp filter already installed (${current_version})\n"
            # Try to get latest version
            latest_version=$(curl -s "https://registry.npmjs.org/$package" | grep -o '"latest":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
            if [[ -n "$latest_version" && "$current_version" != "$latest_version" ]]; then
                printf "  ${BLUE}[INFO]${NC} Updating seccomp filter (${current_version} -> ${latest_version})...\n"
                if "$npm_bin" install -g "$package@latest" >/dev/null 2>&1; then
                    log_success "seccomp filter updated to ${latest_version}"
                else
                    log_warning "Failed to update seccomp filter (continuing anyway)"
                fi
            fi
            return 0
        fi
    fi

    # Not installed - install it
    printf "  ${BLUE}[INFO]${NC} Installing seccomp filter for Claude Code sandbox...\n"
    if "$npm_bin" install -g "$package" >/dev/null 2>&1; then
        log_success "seccomp filter installed"
    else
        log_warning "Failed to install seccomp filter (continuing anyway)"
    fi
    return 0
}

# Setup Claude Code sandbox dependencies (called after installation)
setup_claude_sandbox() {
    printf "\n${CYAN}[CLAUDE CODE SANDBOX SETUP]${NC}\n"

    # Check bubblewrap (optional, just warn if missing)
    check_bubblewrap

    # Install/update seccomp filter (automatic)
    install_seccomp_filter

    # Install/update Playwright CLI (automatic)
    install_playwright_cli

    # Install/enable Playwright MCP globally (automatic)
    install_playwright_mcp

    printf "${GREEN}[SUCCESS]${NC} Claude Code sandbox setup complete\n\n"
}

# Install or update GitHub CLI via conda (required for moai-adk)
install_gh_cli() {
    printf "\n${CYAN}[MOAI DEPENDENCY]${NC} Checking GitHub CLI...\n"

    # Check if gh is already installed
    if command -v gh >/dev/null 2>&1; then
        local current_version
        current_version=$(gh --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown")
        printf "  ${GREEN}[OK]${NC} GitHub CLI already installed (${current_version})\n"
        return 0
    fi

    # Check if conda is available
    if [[ -z "${CONDA_CMD:-}" ]]; then
        log_warning "conda not found, cannot install GitHub CLI"
        printf "  ${YELLOW}Please install manually: conda install -c conda-forge gh${NC}\n"
        return 0
    fi

    # Install gh via conda-forge
    printf "  ${BLUE}[INFO]${NC} Installing GitHub CLI via conda-forge...\n"
    if "$CONDA_CMD" install -y -c conda-forge gh 2>/dev/null; then
        if command -v gh >/dev/null 2>&1; then
            local new_version
            new_version=$(gh --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "installed")
            log_success "GitHub CLI installed (${new_version})"
            return 0
        else
            log_warning "GitHub CLI installed but 'gh' command not found in PATH"
            printf "  ${YELLOW}You may need to restart your terminal or activate conda environment${NC}\n"
            return 0
        fi
    else
        log_warning "Failed to install GitHub CLI via conda"
        printf "  ${YELLOW}Please install manually: conda install -c conda-forge gh${NC}\n"
        return 0
    fi
}

# Show GitHub CLI authentication reminder
show_gh_auth_reminder() {
    printf "\n${CYAN}[IMPORTANT]${NC} GitHub CLI Authentication Required\n"
    printf "  ${YELLOW}Before running moai commands, authenticate with GitHub:${NC}\n"
    printf "  ${GREEN}gh auth login${NC}\n"
    printf "  This will allow moai-adk to interact with GitHub repositories.\n\n"
}

# Install or verify jq (required for moai-adk to safely edit settings.json)
# Without jq, moai-adk falls back to sed-based JSON editing which corrupts pretty-printed JSON
install_jq() {
    printf "\n${CYAN}[MOAI DEPENDENCY]${NC} Checking jq (JSON processor)...\n"

    # Check if jq is already installed
    if command -v jq >/dev/null 2>&1; then
        local current_version
        current_version=$(jq --version 2>/dev/null | head -n1 || echo "unknown")
        printf "  ${GREEN}[OK]${NC} jq already installed (${current_version})\n"
        return 0
    fi

    # Check if conda is available
    if [[ -z "${CONDA_CMD:-}" ]]; then
        log_warning "conda not found, cannot install jq"
        printf "  ${YELLOW}[WARNING] Without jq, moai-adk may corrupt ~/.claude/settings.json${NC}\n"
        printf "  ${YELLOW}Please install manually: conda install -c conda-forge jq${NC}\n"
        return 0
    fi

    # Install jq via conda-forge
    printf "  ${BLUE}[INFO]${NC} Installing jq via conda-forge...\n"
    printf "  ${BLUE}[INFO]${NC} (jq is required to safely edit Claude Code settings.json)${NC}\n"
    if "$CONDA_CMD" install -y -c conda-forge jq 2>/dev/null; then
        if command -v jq >/dev/null 2>&1; then
            local new_version
            new_version=$(jq --version 2>/dev/null | head -n1 || echo "installed")
            log_success "jq installed (${new_version})"
            return 0
        else
            log_warning "jq installed but command not found in PATH"
            printf "  ${YELLOW}You may need to restart your terminal or activate conda environment${NC}\n"
            return 0
        fi
    else
        log_warning "Failed to install jq via conda"
        printf "  ${YELLOW}[WARNING] Without jq, moai-adk may corrupt ~/.claude/settings.json${NC}\n"
        printf "  ${YELLOW}Please install manually: conda install -c conda-forge jq${NC}\n"
        return 0
    fi
}

# Install or verify ast-grep (required for MoAI-ADK security scanning)
# ast-grep provides AST-based code analysis for security and quality scans
install_ast_grep() {
    printf "\n${CYAN}[MOAI DEPENDENCY]${NC} Checking ast-grep (AST-based code analysis)...\n"

    # Check if ast-grep is already installed
    if command -v ast-grep >/dev/null 2>&1; then
        local current_version
        current_version=$(ast-grep --version 2>/dev/null | head -n1 || echo "unknown")
        printf "  ${GREEN}[OK]${NC} ast-grep already installed (${current_version})\n"
        return 0
    fi

    # Check for npm (required for installation)
    local npm_bin
    npm_bin=$(get_npm_bin || true)
    if [[ -z "$npm_bin" ]]; then
        log_warning "npm not found, cannot install ast-grep"
        printf "  ${YELLOW}[WARNING] Without ast-grep, MoAI-ADK security scanning will be disabled${NC}\n"
        printf "  ${YELLOW}Please install manually: npm install -g @ast-grep/cli${NC}\n"
        return 0
    fi

    # Install ast-grep via npm
    printf "  ${BLUE}[INFO]${NC} Installing ast-grep via npm...\n"
    printf "  ${BLUE}[INFO]${NC} (ast-grep is required for MoAI-ADK security scanning)${NC}\n"
    if "$npm_bin" install -g @ast-grep/cli 2>/dev/null; then
        if command -v ast-grep >/dev/null 2>&1; then
            local new_version
            new_version=$(ast-grep --version 2>/dev/null | head -n1 || echo "installed")
            log_success "ast-grep installed (${new_version})"
            return 0
        else
            log_warning "ast-grep installed but command not found in PATH"
            printf "  ${YELLOW}You may need to restart your terminal${NC}\n"
            return 0
        fi
    else
        log_warning "Failed to install ast-grep via npm"
        printf "  ${YELLOW}[WARNING] Without ast-grep, MoAI-ADK security scanning will be disabled${NC}\n"
        printf "  ${YELLOW}Please install manually: npm install -g @ast-grep/cli${NC}\n"
        return 0
    fi
}

# Install or update Playwright CLI for Claude Code browser automation
install_playwright_cli() {
    local npm_bin
    npm_bin=$(get_npm_bin || true)

    if [[ -z "$npm_bin" ]]; then
        log_warning "npm not found, skipping Playwright CLI installation"
        return 0
    fi

    local package="@playwright/cli"
    local current_version=""
    local latest_version=""

    # Check if currently installed
    if current_version=$("$npm_bin" list -g --depth=0 --json 2>/dev/null | grep -o "\"$package\":\"[^\"]*\"" | cut -d'"' -f4); then
        if [[ "$current_version" != "null" && -n "$current_version" ]]; then
            printf "  ${BLUE}[INFO]${NC} Playwright CLI already installed (${current_version})\n"
            # Try to get latest version
            latest_version=$(curl -s "https://registry.npmjs.org/$package" | grep -o '"latest":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
            if [[ -n "$latest_version" && "$current_version" != "$latest_version" ]]; then
                printf "  ${BLUE}[INFO]${NC} Updating Playwright CLI (${current_version} -> ${latest_version})...\n"
                if "$npm_bin" install -g "$package@latest" >/dev/null 2>&1; then
                    log_success "Playwright CLI updated to ${latest_version}"
                else
                    log_warning "Failed to update Playwright CLI (continuing anyway)"
                fi
            fi
            return 0
        fi
    fi

    # Not installed - install it
    printf "  ${BLUE}[INFO]${NC} Installing Playwright CLI for Claude Code browser automation...\n"
    if "$npm_bin" install -g "$package" >/dev/null 2>&1; then
        log_success "Playwright CLI installed"
    else
        log_warning "Failed to install Playwright CLI (continuing anyway)"
    fi
    return 0
}

# Install or enable Playwright MCP server globally (for Claude Code browser automation)
install_playwright_mcp() {
    local claude_json="$HOME/.claude.json"

    # Check if playwright MCP is already configured globally
    if [[ -f "$claude_json" ]]; then
        # Check if playwright exists in mcpServers
        if grep -q '"playwright"' "$claude_json" 2>/dev/null; then
            # Check if it's in the mcpServers section (not just a project reference)
            if python3 -c "import json; data = json.load(open('$claude_json')); print('playwright' in data.get('mcpServers', {}))" 2>/dev/null; then
                printf "  ${BLUE}[INFO]${NC} Playwright MCP already configured globally\n"
                return 0
            fi
        fi
    fi

    # Playwright MCP not configured - add it globally
    printf "  ${BLUE}[INFO]${NC} Installing Playwright MCP globally...\n"

    # Use claude mcp add command with --scope user flag
    if command -v claude >/dev/null 2>&1; then
        if claude mcp add playwright /bin/bash -l -c "exec npx -y @playwright/mcp@latest" --scope user >/dev/null 2>&1; then
            log_success "Playwright MCP added globally (available in all projects)"
        else
            # Fallback: try simpler command
            if claude mcp add playwright npx @playwright/mcp@latest --scope user >/dev/null 2>&1; then
                log_success "Playwright MCP added globally"
            else
                log_warning "Failed to add Playwright MCP via claude mcp command (continuing anyway)"
            fi
        fi
    else
        log_warning "claude command not found, skipping Playwright MCP installation"
        log_info "  To manually install: claude mcp add playwright npx @playwright/mcp@latest --scope user"
    fi
    return 0
}

# Consolidated version parsing function
parse_version() {
    local version=$1
    local format="${2:-standard}"

    # Remove common prefixes
    version="${version#v}"
    version="${version#V}"

    case "$format" in
        "npm")
            # Extract version from npm output (e.g., "npm@10.8.0" -> "10.8.0")
            version=$(echo "$version" | sed -E 's/.*@([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || echo "$version")
            ;;
        "claude")
            # Extract from Claude output (e.g., "claude-code 1.2.3" -> "1.2.3")
            version=$(echo "$version" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || echo "$version")
            ;;
    esac

    # Extract major, minor, patch
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    # Strip build metadata (everything after '+') then pre-release tags
    # (everything after '-'). Both must go: the callers feed these fields to
    # arithmetic comparison, which errors out on non-numeric input.
    # Note: this yields the NUMERIC CORE only. Callers that need SemVer
    # pre-release precedence must use semver_compare_core instead.
    minor="${minor%%+*}"
    patch="${patch%%+*}"
    minor="${minor%%-*}"
    patch="${patch%%-*}"
    echo "$major $minor $patch"
}

# Version comparison helper
version_ge() {
    local installed="$1"
    local required="$2"

    # Parse versions into components
    local installed_major installed_minor installed_patch
    local required_major required_minor required_patch

    read -r installed_major installed_minor installed_patch <<< "$(parse_version "$installed")"
    read -r required_major required_minor required_patch <<< "$(parse_version "$required")"

    # Handle empty components (default to 0)
    installed_major=${installed_major:-0}
    installed_minor=${installed_minor:-0}
    installed_patch=${installed_patch:-0}
    required_major=${required_major:-0}
    required_minor=${required_minor:-0}
    required_patch=${required_patch:-0}

    # Compare major version
    if [[ $installed_major -gt $required_major ]]; then
        return 0
    elif [[ $installed_major -lt $required_major ]]; then
        return 1
    fi

    # Compare minor version
    if [[ $installed_minor -gt $required_minor ]]; then
        return 0
    elif [[ $installed_minor -lt $required_minor ]]; then
        return 1
    fi

    # Compare patch version
    if [[ $installed_patch -ge $required_patch ]]; then
        return 0
    else
        return 1
    fi
}

run_claude_installer() {
    local tmp
    if ! tmp=$(mktemp); then
        log_error "Failed to create temporary file for installer."
        return 1
    fi

    # Secure temporary file with restrictive permissions
    chmod 600 "$tmp" 2>/dev/null || true

    # Download Claude Code installer from immutable trusted URL
    # Note: Anthropic does not publish checksums for install.sh; HTTPS/TLS 1.2 provides transport integrity
    if ! curl -fsSL --proto '=https' --tlsv1.2 "$CLAUDE_INSTALL_URL" -o "$tmp"; then
        log_error "Failed to download Claude Code installer."
        rm -f "$tmp"
        return 1
    fi

    if bash "$tmp"; then
        rm -f "$tmp"
        # Setup sandbox dependencies after successful installation
        setup_claude_sandbox
        return 0
    fi

    local rc=$?
    rm -f "$tmp"
    return "$rc"
}

run_moai_installer() {
    local tmp
    if ! tmp=$(mktemp); then
        log_error "Failed to create temporary file for installer."
        return 1
    fi

    # Secure temporary file with restrictive permissions
    chmod 600 "$tmp" 2>/dev/null || true

    # Download MoAI-ADK installer from upstream main branch.
    # Integrity is provided by TLS to GitHub. The MoAI-ADK installer itself
    # verifies the SHA-256 of the downloaded binary tarball against a hash
    # committed to its release metadata, which is the check that actually
    # protects the installed artifact.
    if ! curl -fsSL --proto '=https' --tlsv1.2 "$MOAI_INSTALL_URL" -o "$tmp"; then
        log_error "Failed to download MoAI-ADK installer."
        rm -f "$tmp"
        return 1
    fi

    if bash "$tmp"; then
        rm -f "$tmp"
        return 0
    fi

    local rc=$?
    rm -f "$tmp"
    return "$rc"
}

run_antigravity_installer() {
    local tmp
    if ! tmp=$(mktemp); then
        log_error "Failed to create temporary file for installer."
        return 1
    fi

    chmod 600 "$tmp" 2>/dev/null || true

    # Download the Antigravity CLI installer from the official Google URL.
    # Integrity is provided by TLS plus the Antigravity installer's own
    # SHA-512 manifest verification of the downloaded native binary
    # (it writes the `agy` binary to ~/.local/bin and self-updates in the background).
    if ! curl -fsSL --proto '=https' --tlsv1.2 "$ANTIGRAVITY_INSTALL_URL" -o "$tmp"; then
        log_error "Failed to download Antigravity CLI installer."
        rm -f "$tmp"
        return 1
    fi

    if bash "$tmp"; then
        rm -f "$tmp"
        return 0
    fi

    local rc=$?
    rm -f "$tmp"
    return "$rc"
}

#############################################
# VERSION QUERY FUNCTIONS
#############################################

# GitHub API rate limit tracking
GITHUB_RATE_LIMIT_REMAINING=60
GITHUB_RATE_LIMIT_RESET=0

check_github_rate_limit() {
    local response_headers=$1

    # Extract rate limit info from headers
    local remaining
    local reset

    remaining=$(echo "$response_headers" | grep -i "x-ratelimit-remaining:" | awk '{print $2}' | tr -d '\r')
    reset=$(echo "$response_headers" | grep -i "x-ratelimit-reset:" | awk '{print $2}' | tr -d '\r')

    if [[ -n "$remaining" ]]; then
        GITHUB_RATE_LIMIT_REMAINING=$remaining
    fi

    if [[ -n "$reset" ]]; then
        GITHUB_RATE_LIMIT_RESET=$reset
    fi
}

github_api_get_with_retry() {
    local url=$1
    local max_retries=5
    local retry_delay=1

    for attempt in $(seq 1 $max_retries); do
        local response
        local http_code

        # Make request with headers captured
        response=$(curl -fsSL -i --max-time 10 "$url" 2>/dev/null)
        http_code=$(echo "$response" | grep -i "^HTTP/" | awk '{print $2}')

        # Check rate limit from headers
        check_github_rate_limit "$response"

        # Handle rate limiting
        if [[ "$http_code" == "403" ]] && [[ "$GITHUB_RATE_LIMIT_REMAINING" -lt 5 ]]; then
            if [[ $attempt -lt $max_retries ]]; then
                log_warning "GitHub API rate limit low ($GITHUB_RATE_LIMIT_REMAINING remaining). Retrying in ${retry_delay}s..."
                sleep "$retry_delay"
                retry_delay=$((retry_delay * 2))
                continue
            else
                log_error "GitHub API rate limit exceeded. Please try again later."
                return 1
            fi
        fi

        # Extract body and return
        local body
        body=$(echo "$response" | sed -n '/^{/,$p')
        echo "$body"
        return 0
    done

    return 1
}

get_installed_uv_version() {
    local pkg=$1
    if ! command -v uv >/dev/null 2>&1; then
        return 0
    fi
    local output
    if [[ "$UV_TOOL_LIST_READY" -eq 0 ]]; then
        UV_TOOL_LIST_CACHE=$(uv tool list 2>/dev/null || true)
        UV_TOOL_LIST_READY=1
    fi
    output="$UV_TOOL_LIST_CACHE"
    if [[ -z "$output" ]]; then
        return 0
    fi

    # Parse uv tool list output to find package version, strip 'v' prefix
    # uv tool list output format: "package-name version" or "package-name v1.0.0"
    # Example formats:
    #   @anthropic-ai/claude-code 2.1.2

    # Try multiple matching approaches for robustness
    local version=""

    # Method 1: Exact match with word boundary
    version=$(echo "$output" | awk -v pkg="^${pkg}[[:space:]]" '$1 ~ pkg {
        v = $2
        sub(/^v/, "", v)
        print v
    }' | head -n1)

    # Method 2: If method 1 failed, try substring match (handles escaped names)
    if [[ -z "$version" ]]; then
        # Escape special regex characters in package name (including ])
        local escaped_pkg=$(printf '%s\n' "$pkg" | sed 's/[[\.*^$()+?{|\\]/\\&/g')
        version=$(echo "$output" | grep -E "${escaped_pkg}[[:space:]]+v?[0-9]" | head -n1 | sed -E 's/.*[[:space:]]+v?([0-9][^[:space:]]*).*/\1/')
    fi

    # Method 3: Last resort - use word boundary matching to avoid false positives
    if [[ -z "$version" ]]; then
        version=$(echo "$output" | grep -w "${pkg}" | head -n1 | awk '{print $2}' | sed 's/^v//')
    fi

    echo "$version"
}

get_installed_npm_version() {
    local pkg=$1
    local npm_bin
    npm_bin=$(get_npm_bin) || return 0
    if [[ -z "$npm_bin" ]]; then
        return 0
    fi
    local json
    if [[ "$NPM_LIST_JSON_READY" -eq 0 ]]; then
        NPM_LIST_JSON_CACHE=$("$npm_bin" list -g --depth=0 --json 2>/dev/null || true)
        NPM_LIST_JSON_READY=1
    fi
    json="$NPM_LIST_JSON_CACHE"
    if [[ -z "$json" ]]; then
        return 0
    fi
    # SAFE: Pass package name as CLI argument instead of interpolating into code
    local node_bin
    node_bin=$(get_npm_node_bin || true)
    if [[ -n "$node_bin" ]]; then
        "$node_bin" -e "
            const obj = JSON.parse(process.argv[1]);
            const pkg = process.argv[2];
            if (obj && obj.dependencies && obj.dependencies[pkg] && obj.dependencies[pkg].version) {
                console.log(obj.dependencies[pkg].version);
            }
        " "$json" "$pkg" 2>/dev/null || true
    fi
}

get_latest_pypi_version() {
    local pkg=$1
    if ! command -v curl >/dev/null 2>&1; then
        return 0
    fi
    # Cache-bust to avoid stale CDN responses
    # Using both Cache-Control header and timestamp query parameter for maximum compatibility
    local cache_bust
    cache_bust=$(date +%s)
    if command -v python3 >/dev/null 2>&1; then
        {
            curl -fsSL --connect-timeout 2 --max-time 10 --retry 1 --retry-delay 0 --retry-max-time 10 \
                -H "Cache-Control: no-cache" \
                "https://pypi.org/pypi/${pkg}/json?ts=${cache_bust}" 2>/dev/null || echo -n ""
        } | python3 -c "import sys, json; data = sys.stdin.read().strip(); print(json.loads(data)['info']['version']) if data else None" 2>/dev/null || true
    elif command -v node >/dev/null 2>&1; then
        {
            curl -fsSL --connect-timeout 2 --max-time 10 --retry 1 --retry-delay 0 --retry-max-time 10 \
                -H "Cache-Control: no-cache" \
                "https://pypi.org/pypi/${pkg}/json?ts=${cache_bust}" 2>/dev/null || echo -n ""
        } | node -e "const data = require('fs').readFileSync(0, 'utf8').trim(); if(data) console.log(JSON.parse(data).info.version);" 2>/dev/null || true
    fi
}

get_latest_npm_version() {
    local pkg=$1
    if ! command -v curl >/dev/null 2>&1; then
        return 0
    fi
    # Cache-bust to avoid stale CDN responses
    # Using both Cache-Control header and timestamp query parameter for maximum compatibility
    local cache_bust
    cache_bust=$(date +%s)
    if command -v node >/dev/null 2>&1; then
        {
            curl -fsSL --max-time 10 -H "Cache-Control: no-cache" \
                "https://registry.npmjs.org/${pkg}/latest?ts=${cache_bust}" 2>/dev/null || echo -n ""
        } | node -e "const data = require('fs').readFileSync(0, 'utf8').trim(); if(data) console.log(JSON.parse(data).version);" 2>/dev/null || true
    fi
}

# Get npm's own installed version
get_installed_npm_self_version() {
    local npm_bin
    npm_bin=$(get_npm_bin) || return 0
    if [[ -z "$npm_bin" ]]; then
        return 0
    fi
    "$npm_bin" --version 2>/dev/null | head -n1 || true
}

# Diagnostic for the npm engine check. Every fallback here is a normal
# operating condition (offline, unknown range syntax, no conda node), not an
# error: the caller always degrades to the dist-tag latest, so surfacing these
# as warnings would be noise. Set DEBUG=1 to see them.
npm_engine_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        printf "${BLUE}[DEBUG]${NC} %s\n" "$*" >&2
    fi
}

# Node binary used purely to parse registry JSON. The conda environment's node
# is preferred so a missing PATH node does not silently disable the check.
get_json_parser_node() {
    local n
    n=$(get_conda_node_path || true)
    if [[ -n "$n" && -x "$n" ]]; then
        printf "%s" "$n"
        return 0
    fi
    if command -v node >/dev/null 2>&1; then
        command -v node
        return 0
    fi
    return 1
}

# Read a single-version registry document (stdin), emit "version<TAB>engines.node".
npm_version_and_engines() {
    local node_bin="$1"
    "$node_bin" -e '
const fs = require("fs");
let d;
try { d = JSON.parse(fs.readFileSync(0, "utf8")); } catch (e) { process.exit(1); }
if (!d || typeof d.version !== "string") process.exit(1);
const e = d.engines;
const n = e && typeof e.node === "string" ? e.node : "";
process.stdout.write(d.version + "\t" + n + "\n");
' 2>/dev/null
}

# Transform an abbreviated npm packument (stdin) into a "version<TAB>engines.node"
# table: newest first, stable releases only, never above the dist-tag latest.
# Line 1 is therefore always the dist-tag latest.
npm_packument_table() {
    local node_bin="$1"
    "$node_bin" -e '
const fs = require("fs");
let doc;
try { doc = JSON.parse(fs.readFileSync(0, "utf8")); } catch (e) { process.exit(1); }
const latest = doc && doc["dist-tags"] && doc["dist-tags"].latest;
if (!latest || !doc.versions) process.exit(1);
const trip = (s) => s.split(".").map(Number);
const cmp = (a, b) => {
  const x = trip(a), y = trip(b);
  for (let i = 0; i < 3; i++) { if (x[i] !== y[i]) return x[i] - y[i]; }
  return 0;
};
const rows = Object.keys(doc.versions)
  .filter((v) => /^[0-9]+\.[0-9]+\.[0-9]+$/.test(v))
  .filter((v) => cmp(v, latest) <= 0)
  .sort((a, b) => cmp(b, a));
if (!rows.length || rows[0] !== latest) process.exit(1);
for (const v of rows) {
  const e = doc.versions[v].engines;
  const n = e && typeof e.node === "string" ? e.node : "";
  process.stdout.write(v + "\t" + n + "\n");
  }
' 2>/dev/null
}

# Newest npm release in $2 (a table from npm_packument_table) whose
# engines.node accepts node version $1. Prints the dist-tag latest on every
# uncertainty; prints nothing only when the table itself is unusable.
npm_select_compatible_version() {
    local node_ver="$1" table="$2"
    if [[ ! -s "$table" ]]; then
        npm_engine_debug "npm engines: version table unavailable"
        return 0
    fi
    local latest_ver rest
    IFS=$'\t' read -r latest_ver rest < "$table"
    if [[ -z "$latest_ver" ]]; then
        npm_engine_debug "npm engines: version table has no dist-tag latest"
        return 0
    fi
    if [[ -z "$node_ver" ]]; then
        npm_engine_debug "npm engines: node version unknown; using dist-tag latest ${latest_ver}"
        printf "%s" "$latest_ver"
        return 0
    fi

    local ver rng rc
    while IFS=$'\t' read -r ver rng; do
        if [[ -z "$ver" ]]; then
            continue
        fi
        # A release with no engines field is considered compatible.
        if semver_range_satisfied "$node_ver" "$rng"; then rc=0; else rc=$?; fi
        if [[ $rc -eq 0 ]]; then
            if [[ "$ver" != "$latest_ver" ]]; then
                npm_engine_debug "npm engines: node ${node_ver} is excluded by npm ${latest_ver}; selecting npm ${ver}"
            fi
            printf "%s" "$ver"
            return 0
        fi
        if [[ $rc -eq 2 ]]; then
            npm_engine_debug "npm engines: unreadable range '${rng}' on npm ${ver}; using dist-tag latest ${latest_ver}"
            printf "%s" "$latest_ver"
            return 0
        fi
    done < "$table"

    npm_engine_debug "npm engines: no npm release accepts node ${node_ver}; using dist-tag latest ${latest_ver}"
    printf "%s" "$latest_ver"
}

# Newest npm version installable on a node of version $2.
#
# The dist-tag "latest" is not necessarily installable: npm 12 declares
# engines.node "^22.22.2 || ^24.15.0 || >=26.0.0", which excludes odd-numbered
# non-LTS lines such as node 25, and installing it there aborts with EBADENGINE.
# Offering or force-installing that version is a guaranteed failure, so pick the
# newest release the target node actually accepts.
#
# Fails OPEN by design: no curl, no node, no network, an unparseable document,
# a range syntax this evaluator does not implement, or no match at all all fall
# back to the dist-tag latest, i.e. exactly the pre-check behavior.
npm_pick_installable_version() {
    local node_bin="$1" env_node="$2"

    if ! command -v curl >/dev/null 2>&1; then
        return 0
    fi

    # Stage 1: the single-version document is small (~65 KB) and already carries
    # engines, so the common "latest is fine" path costs one small request and
    # the 2 MB packument below is fetched only on affected machines.
    local cache_bust
    cache_bust=$(date +%s)
    local latest_line latest_ver latest_range
    latest_line=$(curl -fsSL --proto '=https' --tlsv1.2 --max-time 10 \
        -H "Cache-Control: no-cache" \
        "https://registry.npmjs.org/npm/latest?ts=${cache_bust}" 2>/dev/null \
        | npm_version_and_engines "$node_bin" || true)
    IFS=$'\t' read -r latest_ver latest_range <<< "$latest_line"
    if [[ -z "${latest_ver:-}" ]]; then
        npm_engine_debug "npm engines: could not read npm/latest from the registry"
        return 0
    fi

    if [[ -z "$env_node" ]]; then
        npm_engine_debug "npm engines: node version unknown; using dist-tag latest ${latest_ver}"
        printf "%s" "$latest_ver"
        return 0
    fi

    local rc
    if semver_range_satisfied "$env_node" "${latest_range:-}"; then rc=0; else rc=$?; fi
    if [[ $rc -eq 2 ]]; then
        npm_engine_debug "npm engines: unreadable range '${latest_range:-}'; using dist-tag latest ${latest_ver}"
        printf "%s" "$latest_ver"
        return 0
    fi
    if [[ $rc -eq 0 ]]; then
        printf "%s" "$latest_ver"
        return 0
    fi

    # Stage 2: latest is incompatible with this node. Walk the abbreviated
    # packument (carries engines, ~10% the size of the full document) downwards.
    local table
    if ! table=$(mktemp); then
        printf "%s" "$latest_ver"
        return 0
    fi
    local picked=""
    if curl -fsSL --proto '=https' --tlsv1.2 --max-time 25 \
        -H "Accept: application/vnd.npm.install-v1+json" \
        -H "Cache-Control: no-cache" \
        "https://registry.npmjs.org/npm" 2>/dev/null \
        | npm_packument_table "$node_bin" > "$table" 2>/dev/null; then
        picked=$(npm_select_compatible_version "$env_node" "$table")
    fi
    rm -f "$table"

    if [[ -n "$picked" ]]; then
        printf "%s" "$picked"
        return 0
    fi
    npm_engine_debug "npm engines: packument unavailable; using dist-tag latest ${latest_ver}"
    printf "%s" "$latest_ver"
}

# Memoized npm_pick_installable_version. Stage 2 downloads a ~2 MB packument,
# and a single run can reach the picker more than once (npm bootstrap followed
# by the below-minimum upgrade). The key is the node binary PLUS its version, so
# a cached answer can never leak into a different environment; empty results are
# never cached, so a transient network failure does not poison the run.
NPM_PICK_CACHE_KEY=""
NPM_PICK_CACHE_VALUE=""
npm_pick_installable_version_cached() {
    local node_bin="$1" env_node="$2"
    local key="${node_bin}|${env_node}"
    # Read with :- defaults so the function stays correct under `set -u` even if
    # the declarations above have not been evaluated.
    if [[ "$key" == "${NPM_PICK_CACHE_KEY:-}" ]] && [[ -n "${NPM_PICK_CACHE_VALUE:-}" ]]; then
        printf "%s" "$NPM_PICK_CACHE_VALUE"
        return 0
    fi
    local picked
    picked=$(npm_pick_installable_version "$node_bin" "$env_node")
    if [[ -n "$picked" ]]; then
        NPM_PICK_CACHE_KEY="$key"
        NPM_PICK_CACHE_VALUE="$picked"
    fi
    printf "%s" "$picked"
}

# Resolve which npm the installer should actually install, as an explicit
# version rather than the "latest" tag.
#
# $1 = a version already resolved elsewhere (the menu's own figure), or empty.
#
# Installing "npm@latest" is what produced the reported EBADENGINE: the menu can
# correctly offer 11.18.0 while the tag resolves to 12.0.1, so the promise and
# the action disagree. Preferring the already-resolved figure also keeps the two
# in sync without a second registry round trip.
#
# Prints a concrete version, or the literal "latest" when nothing better is
# known. The caller always installs "npm@<result>", so a failed lookup degrades
# to exactly today's command instead of blocking the upgrade.
npm_install_target() {
    local preferred="${1:-}"
    if [[ "$preferred" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        printf "%s" "$preferred"
        return 0
    fi

    local node_bin picked=""
    if node_bin=$(get_json_parser_node); then
        picked=$(npm_pick_installable_version_cached "$node_bin" "$(get_conda_node_version)")
    fi
    if [[ "$picked" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        printf "%s" "$picked"
        return 0
    fi

    npm_engine_debug "npm engines: no installable version resolved; using the latest tag"
    printf "latest"
}

# Get the newest npm version this environment can actually install.
get_latest_npm_self_version() {
    local node_bin
    if ! node_bin=$(get_json_parser_node); then
        return 0
    fi
    # The conda environment's own node, not the first node on PATH: a newer
    # system/nvm node must not decide compatibility for the conda npm.
    npm_pick_installable_version "$node_bin" "$(get_conda_node_version)"
}

# Extract a version token from a tool's --version output (reads stdin).
#
# Recognizes X.Y.Z plus an optional SemVer pre-release suffix (-rc12, -beta.1).
# The pre-release suffix MUST be preserved: SemVer 2.0.0 section 11 ranks
# 3.0.0-rc12 BELOW 3.0.0, so discarding it makes a pre-release install look
# current when a stable release is already published. Build metadata (+...) is
# excluded because SemVer section 10 says it is ignored for precedence.
# Input with no recognizable version passes through unchanged, matching the
# previous inline sed behavior.
extract_version_token() {
    sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?).*/\1/'
}

get_installed_native_version() {
    local pkg=$1
    # Check for claude binary
    if [[ "$pkg" == "claude-code" ]]; then
        if command -v claude >/dev/null 2>&1; then
            claude --version 2>/dev/null | head -n1 | extract_version_token || true
        fi
    elif [[ "$pkg" == "moai-adk" ]]; then
        if command -v moai >/dev/null 2>&1; then
            local moai_out=""
            moai_out=$(moai --version 2>/dev/null | head -n1 || true)
            if [[ -z "$moai_out" ]]; then
                moai_out=$(moai version 2>/dev/null | head -n1 || true)
            fi
            if [[ -n "$moai_out" ]]; then
                echo "$moai_out" | extract_version_token || true
            fi
        fi
    elif [[ "$pkg" == "antigravity" ]]; then
        # Antigravity CLI installs the `agy` binary to ~/.local/bin
        if command -v agy >/dev/null 2>&1; then
            agy --version 2>/dev/null | head -n1 | extract_version_token || true
        fi
    fi
}

get_installed_addon_version() {
    local pkg=$1
    if [[ "$pkg" == "oh-my-opencode" ]]; then
        local opencode_config="$HOME/.config/opencode/opencode.json"
        local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
        local cache_pkg_json="${cache_root}/package.json"
        local cache_module_pkg_json="${cache_root}/node_modules/${pkg}/package.json"

        if [[ ! -f "$opencode_config" ]]; then
            return 1
        fi

        local plugin_spec=""
        if command -v python3 >/dev/null 2>&1; then
            plugin_spec=$(python3 -c 'import json,sys; p=sys.argv[1]; pkg=sys.argv[2]; obj=json.load(open(p,"r",encoding="utf-8")); arr=obj.get("plugin") or []; print(next((s for s in arr if isinstance(s,str) and s.startswith(pkg)), ""), end="")' "$opencode_config" "$pkg" 2>/dev/null || true)
        elif command -v jq >/dev/null 2>&1; then
            plugin_spec=$(jq -r --arg pkg "$pkg" '.plugin // [] | map(select(startswith($pkg))) | .[0] // empty' "$opencode_config" 2>/dev/null || true)
        else
            if grep -q '"oh-my-opencode' "$opencode_config" 2>/dev/null; then
                plugin_spec="${pkg}"
            fi
        fi

        if [[ -z "$plugin_spec" ]]; then
            return 1
        fi

        local resolved=""
        resolved=$(get_installed_npm_version "$pkg" || true)
        if [[ -n "$resolved" ]]; then
            echo "$resolved"
            return 0
        fi

        if [[ -f "$cache_pkg_json" ]] && command -v python3 >/dev/null 2>&1; then
            resolved=$(python3 -c 'import json,sys; p=sys.argv[1]; pkg=sys.argv[2]; obj=json.load(open(p,"r",encoding="utf-8")); dep=(obj.get("dependencies") or {}).get(pkg) or ""; print(dep.strip() if isinstance(dep,str) else "", end="")' "$cache_pkg_json" "$pkg" 2>/dev/null || true)
        elif [[ -f "$cache_pkg_json" ]] && command -v jq >/dev/null 2>&1; then
            resolved=$(jq -r --arg pkg "$pkg" '.dependencies[$pkg] // empty' "$cache_pkg_json" 2>/dev/null || true)
        fi

        if [[ -z "$resolved" ]] && [[ -f "$cache_module_pkg_json" ]] && command -v python3 >/dev/null 2>&1; then
            resolved=$(python3 -c 'import json,sys; p=sys.argv[1]; obj=json.load(open(p,"r",encoding="utf-8")); v=obj.get("version") or ""; print(v.strip() if isinstance(v,str) else "", end="")' "$cache_module_pkg_json" 2>/dev/null || true)
        elif [[ -z "$resolved" ]] && [[ -f "$cache_module_pkg_json" ]] && command -v jq >/dev/null 2>&1; then
            resolved=$(jq -r '.version // empty' "$cache_module_pkg_json" 2>/dev/null || true)
        fi

        if [[ -n "$resolved" ]]; then
            echo "$resolved"
            return 0
        fi

        local pinned=""
        if [[ "$plugin_spec" == "${pkg}@"* ]]; then
            pinned="${plugin_spec#${pkg}@}"
            if [[ -n "$pinned" && "$pinned" != "latest" ]]; then
                echo "$pinned"
                return 0
            fi
        fi

        echo "Unknown"
        return 0
    fi

    return 1
}

# Check for npm-installed Claude Code (for migration)
check_npm_claude_code() {
    local npm_bin
    npm_bin=$(get_npm_bin) || return 1
    if [[ -n "$npm_bin" ]]; then
        local json
        json=$("$npm_bin" list -g --depth=0 --json 2>/dev/null || true)
        if [[ -n "$json" ]]; then
            # SAFE: Use grep instead of JavaScript code interpolation
            if echo "$json" | grep -q "@anthropic-ai/claude-code"; then
                return 0  # npm version found
            fi
        fi
    fi
    return 1  # no npm version found
}

get_tool_version() {
    local manager=$1
    local pkg=$2
    local installed

    case "$manager" in
        uv)
            installed=$(get_installed_uv_version "$pkg")
            ;;
        npm)
            installed=$(get_installed_npm_version "$pkg")
            ;;
        npm-self)
            installed=$(get_installed_npm_self_version)
            ;;
        native)
            installed=$(get_installed_native_version "$pkg")
            ;;
        addon)
            installed=$(get_installed_addon_version "$pkg")
            ;;
    esac

    if [[ -n "$installed" ]]; then
        echo "$installed"
    else
        echo "Not Installed"
    fi
}

# Query Antigravity's official release manifest for the latest version.
# Source is the same Cloud Run auto-updater endpoint that Antigravity's own
# install.sh uses; platform detection mirrors that script. Degrades silently
# to empty output (rendered as "Unknown") on any failure.
get_latest_antigravity_version() {
    command -v curl >/dev/null 2>&1 || return 0
    local base="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
    local os arch platform
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        *) return 0 ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) return 0 ;;
    esac
    if [[ "$os" == "linux" ]]; then
        if [[ -f /lib/libc.musl-x86_64.so.1 ]] || [[ -f /lib/libc.musl-aarch64.so.1 ]] || ldd /bin/ls 2>&1 | grep -q musl; then
            platform="linux_${arch}_musl"
        else
            platform="linux_${arch}"
        fi
    else
        platform="${os}_${arch}"
    fi
    local manifest
    manifest=$(curl -fsSL --max-time 10 "${base}/manifests/${platform}.json" 2>/dev/null) || return 0
    [[ -n "$manifest" ]] || return 0
    local version=""
    if command -v python3 >/dev/null 2>&1; then
        version=$(printf '%s' "$manifest" | python3 -c "import sys, json; print(json.load(sys.stdin).get('version', ''))" 2>/dev/null || true)
    else
        version=$(printf '%s' "$manifest" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')
    fi
    version=${version#v}
    [[ -n "$version" ]] && echo "$version"
    return 0
}

get_latest_version() {
    local manager=$1
    local pkg=$2

    case "$manager" in
        uv)
            get_latest_pypi_version "$pkg"
            ;;
        npm)
            get_latest_npm_version "$pkg"
            ;;
        npm-self)
            get_latest_npm_self_version
            ;;
        native)
            if [[ "$pkg" == "antigravity" ]]; then
                get_latest_antigravity_version
                return 0
            fi
            local cache_bust
            cache_bust=$(date +%s)

            # For native tools, check GitHub releases with rate limit handling
            if command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
                local response
                local repo=""

                case "$pkg" in
                    claude-code)
                        repo="anthropics/claude-code"
                        ;;
                    moai-adk)
                        repo="modu-ai/moai-adk"
                        ;;
                esac

                if [[ -n "$repo" ]]; then
                    if response=$(github_api_get_with_retry "https://api.github.com/repos/${repo}/releases/latest?ts=${cache_bust}"); then
                        local tag
                        tag=$(echo "$response" | python3 -c "import sys, json; data = sys.stdin.read().strip(); print(json.loads(data)['tag_name']) if data else None" 2>/dev/null || true)
                        if [[ "$tag" == "None" ]] || [[ "$tag" == "null" ]]; then
                            tag=""
                        fi
                        tag=${tag#go-}
                        tag=${tag#v}
                        if [[ -n "$tag" ]]; then
                            echo "$tag"
                        fi
                    fi
                fi
            fi
            ;;
        addon)
            # For addons, query npm registry for the latest version
            get_latest_npm_version "$pkg"
            ;;
    esac
}

# Legacy function - now uses consolidated parse_version
version_parse() {
    parse_version "$1" "standard"
}

# Isolate the SemVer core "X.Y.Z[-prerelease]" from arbitrary text.
# Build metadata (+...) is dropped: SemVer 2.0.0 section 10 excludes it from
# precedence. Prints nothing when no version is present.
semver_extract() {
    local raw="$1"
    raw="${raw#v}"
    raw="${raw#V}"
    local re='([0-9]+\.[0-9]+\.[0-9]+)(-[0-9A-Za-z.-]+)?'
    if [[ "$raw" =~ $re ]]; then
        printf '%s%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    fi
}

# Compare two version strings per SemVer 2.0.0 section 11 precedence.
# Prints "lt", "eq" or "gt" describing $1 relative to $2.
# Returns 1 without output when either side has no parseable version.
semver_compare_core() {
    local a b
    a="$(semver_extract "$1")"
    b="$(semver_extract "$2")"
    if [[ -z "$a" ]] || [[ -z "$b" ]]; then
        return 1
    fi

    # Split "X.Y.Z-pre" into numeric core and pre-release remainder.
    local a_core="${a%%-*}" b_core="${b%%-*}"
    local a_pre="" b_pre=""
    [[ "$a" == *-* ]] && a_pre="${a#*-}"
    [[ "$b" == *-* ]] && b_pre="${b#*-}"

    local a_major a_minor a_patch b_major b_minor b_patch
    IFS='.' read -r a_major a_minor a_patch <<< "$a_core"
    IFS='.' read -r b_major b_minor b_patch <<< "$b_core"

    # Section 11.2: major, minor, patch compared numerically in that order.
    local field lhs rhs
    for field in major minor patch; do
        case "$field" in
            major) lhs=$a_major; rhs=$b_major ;;
            minor) lhs=$a_minor; rhs=$b_minor ;;
            patch) lhs=$a_patch; rhs=$b_patch ;;
        esac
        # 10# forces base-10 so leading zeros are not read as octal.
        lhs=$((10#${lhs:-0}))
        rhs=$((10#${rhs:-0}))
        if (( lhs > rhs )); then echo "gt"; return 0; fi
        if (( lhs < rhs )); then echo "lt"; return 0; fi
    done

    # Section 11.3: a version WITHOUT a pre-release outranks one WITH it.
    if [[ -z "$a_pre" ]] && [[ -z "$b_pre" ]]; then echo "eq"; return 0; fi
    if [[ -z "$a_pre" ]]; then echo "gt"; return 0; fi
    if [[ -z "$b_pre" ]]; then echo "lt"; return 0; fi

    # Section 11.4: compare dot-separated pre-release identifiers left to right.
    local -a a_ids=() b_ids=()
    IFS='.' read -r -a a_ids <<< "$a_pre"
    IFS='.' read -r -a b_ids <<< "$b_pre"

    local count=${#a_ids[@]}
    (( ${#b_ids[@]} > count )) && count=${#b_ids[@]}

    local i a_id b_id a_numeric b_numeric
    for (( i = 0; i < count; i++ )); do
        a_id="${a_ids[i]-}"
        b_id="${b_ids[i]-}"

        # Section 11.4.4: when all preceding identifiers are equal, the version
        # with MORE identifiers outranks the one with fewer.
        if [[ -z "$a_id" ]]; then echo "lt"; return 0; fi
        if [[ -z "$b_id" ]]; then echo "gt"; return 0; fi
        [[ "$a_id" == "$b_id" ]] && continue

        a_numeric=0; b_numeric=0
        [[ "$a_id" =~ ^[0-9]+$ ]] && a_numeric=1
        [[ "$b_id" =~ ^[0-9]+$ ]] && b_numeric=1

        # Section 11.4.1: numeric identifiers compare numerically (rc2 < rc10
        # only holds when the digits are compared as numbers, not as text).
        if (( a_numeric == 1 && b_numeric == 1 )); then
            if (( 10#$a_id > 10#$b_id )); then echo "gt"; else echo "lt"; fi
            return 0
        fi

        # Section 11.4.3: numeric identifiers always rank LOWER than
        # alphanumeric identifiers.
        if (( a_numeric == 1 )); then echo "lt"; return 0; fi
        if (( b_numeric == 1 )); then echo "gt"; return 0; fi

        # Section 11.4.2: alphanumeric identifiers compare in ASCII sort order,
        # with one documented refinement. Strict ASCII ranks "rc10" BELOW "rc2"
        # (byte '1' < '2'), which inverts every undotted rcN scheme -- including
        # this project's own moai-adk 3.0.0-rc1..rc12 line. So an identifier is
        # first split into an alphabetic prefix and a trailing numeric run: the
        # prefixes compare by ASCII, and equal prefixes fall through to a
        # NUMERIC comparison of the trailing digits (rc2 < rc10). Identifiers
        # without a trailing numeric run compare by plain ASCII, unchanged.
        local a_stem="$a_id" b_stem="$a_id" a_num="" b_num=""
        b_stem="$b_id"
        local split_re='^(.*[^0-9])([0-9]+)$'
        if [[ "$a_id" =~ $split_re ]]; then
            a_stem="${BASH_REMATCH[1]}"; a_num="${BASH_REMATCH[2]}"
        fi
        if [[ "$b_id" =~ $split_re ]]; then
            b_stem="${BASH_REMATCH[1]}"; b_num="${BASH_REMATCH[2]}"
        fi

        if [[ "$a_stem" == "$b_stem" ]] && [[ -n "$a_num" ]] && [[ -n "$b_num" ]]; then
            if (( 10#$a_num > 10#$b_num )); then echo "gt"; else echo "lt"; fi
            return 0
        fi

        # LC_ALL=C in a subshell forces byte order instead of locale collation.
        if ( LC_ALL=C; [[ "$a_id" > "$b_id" ]] ); then echo "gt"; else echo "lt"; fi
        return 0
    done

    echo "eq"
}

# Evaluate ONE npm range comparator against a concrete version.
# Returns: 0 satisfied, 1 not satisfied, 2 unsupported syntax.
# Callers MUST treat 2 as "cannot decide" and fail open — never as "no".
semver_comparator_satisfied() {
    local ver="$1" comp="$2"

    # An empty or wildcard comparator matches everything.
    case "$comp" in
        ''|'*'|'x'|'X') return 0 ;;
    esac

    local op rest
    case "$comp" in
        '>='*) op='>=' ; rest="${comp:2}" ;;
        '<='*) op='<=' ; rest="${comp:2}" ;;
        '>'*)  op='>'  ; rest="${comp:1}" ;;
        '<'*)  op='<'  ; rest="${comp:1}" ;;
        '^'*)  op='^'  ; rest="${comp:1}" ;;
        '~'*)  op='~'  ; rest="${comp:1}" ;;
        '='*)  op='='  ; rest="${comp:1}" ;;
        *)     op='='  ; rest="$comp"     ;;
    esac
    rest="${rest#v}"
    rest="${rest#V}"

    # Only plain numeric forms are supported: X, X.Y, X.Y.Z. Anything else
    # (x-ranges like 1.2.x, hyphen ranges, pre-release comparators) is
    # deliberately reported as unsupported so the caller fails open.
    if [[ ! "$rest" =~ ^[0-9]+(\.[0-9]+)?(\.[0-9]+)?$ ]]; then
        return 2
    fi

    local maj min pat parts
    IFS='.' read -r maj min pat <<< "$rest"
    parts=1
    if [[ -n "${min:-}" ]]; then parts=2; fi
    if [[ -n "${pat:-}" ]]; then parts=3; fi
    min="${min:-0}"
    pat="${pat:-0}"

    local lower="${maj}.${min}.${pat}"
    local upper=""   # exclusive upper bound; "" = unbounded, __exact__ = equality

    case "$op" in
        '^')
            # Caret allows changes that do not modify the left-most non-zero
            # element, so 0.x and 0.0.x are narrower than the X>0 case.
            if [[ $parts -eq 1 ]] || [[ $((10#$maj)) -gt 0 ]]; then
                upper="$((10#$maj + 1)).0.0"
            elif [[ $((10#$min)) -gt 0 ]]; then
                upper="0.$((10#$min + 1)).0"
            elif [[ $parts -eq 3 ]]; then
                upper="0.0.$((10#$pat + 1))"
            else
                upper="0.1.0"
            fi
            ;;
        '~')
            if [[ $parts -eq 1 ]]; then
                upper="$((10#$maj + 1)).0.0"
            else
                upper="${maj}.$((10#$min + 1)).0"
            fi
            ;;
        '=')
            # A partial bare version is an X-range: "14.17" means >=14.17.0 <14.18.0
            if [[ $parts -eq 1 ]]; then
                upper="$((10#$maj + 1)).0.0"
            elif [[ $parts -eq 2 ]]; then
                upper="${maj}.$((10#$min + 1)).0"
            else
                upper="__exact__"
            fi
            ;;
    esac

    local cmp
    if ! cmp=$(semver_compare_core "$ver" "$lower"); then
        return 2
    fi

    case "$op" in
        '>=')
            if [[ "$cmp" == "lt" ]]; then return 1; fi
            return 0
            ;;
        '>')
            if [[ "$cmp" == "gt" ]]; then return 0; fi
            return 1
            ;;
        '<')
            if [[ "$cmp" == "lt" ]]; then return 0; fi
            return 1
            ;;
        '<=')
            if [[ "$cmp" == "gt" ]]; then return 1; fi
            return 0
            ;;
    esac

    # '^', '~', '=' share the half-open interval [lower, upper).
    if [[ "$cmp" == "lt" ]]; then
        return 1
    fi
    if [[ "$upper" == "__exact__" ]]; then
        if [[ "$cmp" == "eq" ]]; then return 0; fi
        return 1
    fi
    if ! cmp=$(semver_compare_core "$ver" "$upper"); then
        return 2
    fi
    if [[ "$cmp" == "lt" ]]; then
        return 0
    fi
    return 1
}

# Evaluate a full npm engines-style range against a concrete version.
# Supports the subset npm actually publishes plus the common extras:
#   '||' alternation, space-separated conjunction, ^ ~ >= > <= < =,
#   bare and partial versions (X, X.Y, X.Y.Z), and '*'.
# Returns: 0 satisfied, 1 not satisfied, 2 unsupported syntax (fail open).
semver_range_satisfied() {
    local ver="$1" range="$2"

    # Trim surrounding whitespace.
    range="${range#"${range%%[![:space:]]*}"}"
    range="${range%"${range##*[![:space:]]}"}"
    if [[ -z "$range" ]] || [[ "$range" == "*" ]]; then
        return 0
    fi

    local unsupported=0 alt comp rc all_ok
    local -a comps=()
    while IFS= read -r alt; do
        alt="${alt#"${alt%%[![:space:]]*}"}"
        alt="${alt%"${alt##*[![:space:]]}"}"
        if [[ -z "$alt" ]]; then
            # An empty alternative means the expression was malformed.
            unsupported=1
            continue
        fi
        comps=()
        read -r -a comps <<< "$alt"
        all_ok=1
        local alt_unsupported=0
        # Every comparator is evaluated, with no short-circuit on a merely
        # unsatisfied one: stopping early would hide an unsupported comparator
        # later in the same conjunction and report a confident "no" for an
        # expression this evaluator cannot actually read. That would fail
        # CLOSED, which the caller must never do.
        for comp in "${comps[@]}"; do
            if semver_comparator_satisfied "$ver" "$comp"; then
                rc=0
            else
                rc=$?
            fi
            if [[ $rc -eq 2 ]]; then
                alt_unsupported=1
            elif [[ $rc -ne 0 ]]; then
                all_ok=0
            fi
        done
        if [[ $alt_unsupported -eq 1 ]]; then
            # Undecidable conjunction: it can neither prove nor disprove.
            unsupported=1
            continue
        fi
        # A fully satisfied alternative proves the range: OR wins even when a
        # different alternative used syntax this evaluator cannot read.
        if [[ $all_ok -eq 1 ]]; then
            return 0
        fi
    done <<< "${range//||/$'\n'}"

    if [[ $unsupported -eq 1 ]]; then
        return 2
    fi
    return 1
}

version_compare() {
    local installed=$1
    local latest=$2

    # Handle "Not Installed" case
    if [[ "$installed" == "Not Installed" ]]; then
        echo "missing"
        return
    fi

    if [[ -z "$installed" ]] || [[ "$installed" == "Unknown" ]]; then
        echo "unknown"
        return
    fi
    if ! echo "$installed" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'; then
        echo "unknown"
        return
    fi

    # Handle empty latest version
    if [[ -z "$latest" ]] || [[ "$latest" == "Unknown" ]]; then
        echo "unknown"
        return
    fi
    if ! echo "$latest" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'; then
        echo "unknown"
        return
    fi

    # Full SemVer 2.0.0 precedence, including pre-release ordering. A bare
    # major/minor/patch comparison is not enough: 3.0.0-rc12 must rank BELOW
    # 3.0.0 even though the numeric cores are identical.
    local order
    if ! order=$(semver_compare_core "$installed" "$latest"); then
        echo "unknown"
        return
    fi

    if [[ "$order" == "lt" ]]; then
        echo "update"
    else
        echo "current"
    fi
}

prefetch_latest_versions() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local -a pids=()
    local -a pids_to_tool=()
    local failed_count=0

    for i in "${!TOOL_NAMES[@]}"; do
        local manager="${TOOL_MANAGERS[$i]}"
        local pkg="${TOOL_PACKAGES[$i]}"
        local out="${tmp_dir}/${i}"

        (
            local latest=""
            local attempt
            local jitter_ms
            local jitter_s
            jitter_ms=$((RANDOM % 500 + 100))
            printf -v jitter_s "0.%03d" "$jitter_ms"
            sleep "$jitter_s"
            for attempt in 1 2; do
                case "$manager" in
                    uv)
                        latest=$(get_latest_pypi_version "$pkg")
                        ;;
                    npm)
                        latest=$(get_latest_npm_version "$pkg")
                        ;;
                    npm-self)
                        latest=$(get_latest_npm_self_version)
                        ;;
                    native)
                        latest=$(get_latest_version "$manager" "$pkg")
                        ;;
                    addon)
                        # For addons, query npm registry for the latest version
                        latest=$(get_latest_npm_version "$pkg")
                        ;;
                esac
                if [[ -n "$latest" ]]; then
                    break
                fi
                sleep 1
            done
            printf "%s" "$latest" >"$out"
        ) &
        pids+=("$!")
        pids_to_tool[$i]=$!
    done

    # Track which subprocesses failed
    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        if ! wait "$pid"; then
            log_warning "Failed to fetch version for tool ${TOOL_NAMES[$i]}"
            failed_count=$((failed_count + 1))
        fi
    done

    # Log warning if all fetches failed
    if [[ $failed_count -eq ${#TOOL_NAMES[@]} ]]; then
        log_warning "All version fetches failed - network may be unavailable"
    fi

    for i in "${!TOOL_NAMES[@]}"; do
        local out="${tmp_dir}/${i}"
        if [[ -f "$out" ]]; then
            LATEST_VERSION_CACHE[$i]=$(<"$out")
        else
            LATEST_VERSION_CACHE[$i]=""
        fi
    done

    rm -rf "$tmp_dir"
}

#############################################
# INITIALIZATION
#############################################

initialize_tools() {
    # Always add npm to the tool list (users can install it via conda if not present)
    TOOL_NAMES+=("npm")
    TOOL_MANAGERS+=("npm-self")
    TOOL_PACKAGES+=("npm")
    TOOL_DESCRIPTIONS+=("npm (Node Package Manager)")
    UPDATE_ONLY+=(0)  # npm can be installed or updated

    # Add regular tools
    for tool_info in "${TOOLS[@]}"; do
        IFS='|' read -r name manager pkg description <<< "$tool_info"

        TOOL_NAMES+=("$name")
        TOOL_MANAGERS+=("$manager")
        TOOL_PACKAGES+=("$pkg")
        TOOL_DESCRIPTIONS+=("$description")
        UPDATE_ONLY+=(0)  # Regular tools can be installed/removed
    done

    prefetch_latest_versions

    for i in "${!TOOL_NAMES[@]}"; do
        local manager="${TOOL_MANAGERS[$i]}"
        local pkg="${TOOL_PACKAGES[$i]}"
        local description="${TOOL_DESCRIPTIONS[$i]}"
        local is_update_only="${UPDATE_ONLY[$i]}"

        # Show progress
        printf "\r${BLUE}[INFO]${NC} Checking: ${CYAN}%-35s${NC}" "$description"

        # Get installed version
        local installed
        installed=$(get_tool_version "$manager" "$pkg")
        INSTALLED_VERSIONS+=("$installed")

        # Get latest version
        local latest
        latest="${LATEST_VERSION_CACHE[$i]}"
        LATEST_VERSIONS+=("${latest:-"Unknown"}")

        # Set default selection
        # For update-only tools (npm): select only if update available
        # For regular tools: select only if update available (not new installs)
        local status
        status=$(version_compare "$installed" "$latest")
        if [[ "$status" == "update" ]]; then
            SELECTED+=(1)
            # Use "upgrade" action for installed tools, "install" for new
            if [[ "$installed" == "Not Installed" ]]; then
                TOOL_ACTIONS+=("${ACTIONS[1]}")  # "install"
            else
                TOOL_ACTIONS+=("${ACTIONS[2]}")  # "upgrade"
            fi
        else
            SELECTED+=(0)
            TOOL_ACTIONS+=("${ACTIONS[0]}")  # "skip"
        fi
    done
    # Clear the progress line
    printf "\r%80s\r" " "
}

#############################################
# MENU RENDERING
#############################################

render_menu() {
    clear_screen

    print_box_header \
        "Agentic Coders CLI Installer v1.14.5" \
        "Toggle: skip->install/upgrade->remove | Input: 1,3,5 | Enter/P=proceed | Q=quit"

    print_section "MENU"
    print_sep

    # Header
    printf " ${BOLD}%2s${NC}  ${BOLD}%-30s${NC} ${BOLD}%14s${NC} ${BOLD}%10s${NC}  ${BOLD}%10s${NC}  ${BOLD}Select${NC}\n" "#" "Tool" "Installed" "Latest" "Action"
    print_sep

    # Tool list
    for i in "${!TOOL_NAMES[@]}"; do
        local num=$((i + 1))
        local name="${TOOL_DESCRIPTIONS[$i]}"
        local installed="${INSTALLED_VERSIONS[$i]}"
        local latest="${LATEST_VERSIONS[$i]}"
        local action="${TOOL_ACTIONS[$i]}"

        # Determine colors for versions
        local installed_color="" latest_color=""
        if [[ "$installed" == "Not Installed" ]]; then
            installed_color="$RED"
        elif [[ "$installed" == "$latest" ]]; then
            installed_color="$GREEN"
        else
            installed_color="$YELLOW"
        fi

        # Determine action color and checkbox
        local action_color checkbox
        case "$action" in
            install)
                action_color="$GREEN"
                checkbox="${GREEN}[✓]${NC}"
                ;;
            upgrade)
                action_color="$CYAN"
                checkbox="${CYAN}[↑]${NC}"
                ;;
            remove)
                action_color="$RED"
                checkbox="${RED}[✗]${NC}"
                ;;
            skip)
                action_color="$CYAN"
                checkbox="${CYAN}[ ]${NC}"
                ;;
            *)
                action_color="$NC"
                checkbox="${CYAN}[ ]${NC}"
                ;;
        esac

        # Print with proper alignment (colors applied after width formatting)
        printf " ${BOLD}%2d${NC}  %-30s ${installed_color}%14s${NC} %10s  ${action_color}%10s${NC}  %b\n" \
            "$num" \
            "$name" \
            "$installed" \
            "${latest:-Unknown}" \
            "$action" \
            "$checkbox"
    done

    print_sep
}

#############################################
# USER INPUT HANDLING
#############################################

parse_selection() {
    local input=$1
    local -a selections

    # Split by comma
    IFS=',' read -ra selections <<< "$input"

    for num in "${selections[@]}"; do
        # Trim whitespace
        num=$(echo "$num" | xargs)

        # Skip empty
        [[ -z "$num" ]] && continue

        # Validate numeric
        if ! [[ "$num" =~ ^[0-9]+$ ]]; then
            log_error "Invalid input: '$num' is not a number"
            return 1
        fi

        # Validate range
        if [[ "$num" -lt 1 || "$num" -gt "${#TOOL_NAMES[@]}" ]]; then
            log_error "Invalid selection: '$num' is out of range (1-${#TOOL_NAMES[@]})"
            return 1
        fi

        # Cycle through actions based on tool status
        local idx=$((num - 1))
        local current_action="${TOOL_ACTIONS[$idx]}"
        local new_action
        local installed="${INSTALLED_VERSIONS[$idx]}"
        local latest="${LATEST_VERSIONS[$idx]}"
        local is_update_only="${UPDATE_ONLY[$idx]}"

        # Determine tool state and valid transitions
        # For update-only tools (npm):
        #   - Can only update if outdated, otherwise skip
        #   - Never allow remove
        # For regular tools:
        #   State 1: Not Installed -> can only install or skip (no remove)
        #   State 2: Up-to-date (installed == latest) -> can only remove or skip (no install)
        #   State 3: Outdated (installed != latest) -> can install, update, or remove

        local not_installed=false
        local up_to_date=false

        if [[ "$installed" == "Not Installed" ]]; then
            not_installed=true
        elif [[ "$installed" == "$latest" ]]; then
            up_to_date=true
        fi

        # Handle update-only tools specially
        if [[ "$is_update_only" -eq 1 ]]; then
            case "$current_action" in
                skip)
                    if [[ "$not_installed" == false && "$up_to_date" == false ]]; then
                        # Outdated: skip -> upgrade (update)
                        new_action="upgrade"
                        SELECTED[$idx]=1
                        TOOL_ACTIONS[$idx]="upgrade"
                        log_info "Selected for update: ${TOOL_NAMES[$idx]}"
                    else
                        # Not installed or up-to-date: skip remains skip (with message)
                        log_info "${TOOL_NAMES[$idx]} is $installed - no action available"
                    fi
                    ;;
                upgrade)
                    # upgrade -> skip
                    new_action="skip"
                    SELECTED[$idx]=0
                    TOOL_ACTIONS[$idx]="skip"
                    log_info "Deselected: ${TOOL_NAMES[$idx]}"
                    ;;
                *)
                    # Default to skip
                    new_action="skip"
                    SELECTED[$idx]=0
                    TOOL_ACTIONS[$idx]="skip"
                    ;;
            esac
        else
            # Regular tools handling
            case "$current_action" in
                skip)
                    if [[ "$not_installed" == true ]]; then
                        # Not installed: skip -> install
                        new_action="install"
                        SELECTED[$idx]=1
                        TOOL_ACTIONS[$idx]="install"
                        log_info "Selected for install: ${TOOL_NAMES[$idx]}"
                    elif [[ "$up_to_date" == true ]]; then
                        # Up-to-date: skip -> remove
                        new_action="remove"
                        SELECTED[$idx]=1
                        TOOL_ACTIONS[$idx]="remove"
                        log_info "Selected for removal: ${TOOL_NAMES[$idx]}"
                    else
                        # Outdated: skip -> upgrade
                        new_action="upgrade"
                        SELECTED[$idx]=1
                        TOOL_ACTIONS[$idx]="upgrade"
                        log_info "Selected for update: ${TOOL_NAMES[$idx]}"
                    fi
                    ;;
                install)
                    if [[ "$not_installed" == true ]]; then
                        # Not installed: install -> skip (no remove option)
                        new_action="skip"
                        SELECTED[$idx]=0
                        TOOL_ACTIONS[$idx]="skip"
                        log_info "Deselected: ${TOOL_NAMES[$idx]}"
                    else
                        # Installed (outdated): install -> upgrade
                        new_action="upgrade"
                        SELECTED[$idx]=1
                        TOOL_ACTIONS[$idx]="upgrade"
                        log_info "Changed to upgrade: ${TOOL_NAMES[$idx]}"
                    fi
                    ;;
                upgrade)
                    # upgrade -> remove (installed tools)
                    new_action="remove"
                    SELECTED[$idx]=1
                    TOOL_ACTIONS[$idx]="remove"
                    log_info "Selected for removal: ${TOOL_NAMES[$idx]}"
                    ;;
                remove)
                    # Remove always goes to skip
                    # (remove is only valid for installed tools)
                    new_action="skip"
                    SELECTED[$idx]=0
                    TOOL_ACTIONS[$idx]="skip"
                    log_info "Deselected: ${TOOL_NAMES[$idx]}"
                    ;;
                *)
                    # Default action based on tool state
                    if [[ "$not_installed" == true ]]; then
                        new_action="install"
                    elif [[ "$up_to_date" == true ]]; then
                        new_action="remove"
                    else
                        new_action="upgrade"
                    fi
                    SELECTED[$idx]=1
                    TOOL_ACTIONS[$idx]="$new_action"
                    log_info "Selected: ${TOOL_NAMES[$idx]}"
                    ;;
            esac
        fi
    done

    # Dependency resolution: if oh-my-opencode is selected, ensure opencode-ai is selected
    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${TOOL_NAMES[$i]}" == "oh-my-opencode" && "${SELECTED[$i]}" -eq 1 ]]; then
            # Find opencode-ai index
            for j in "${!TOOL_NAMES[@]}"; do
                if [[ "${TOOL_NAMES[$j]}" == "opencode-ai" ]]; then
                    local opencode_installed="${INSTALLED_VERSIONS[$j]}"
                    # If opencode-ai is not installed, automatically select it
                    if [[ "$opencode_installed" == "Not Installed" ]]; then
                        SELECTED[$j]=1
                        TOOL_ACTIONS[$j]="install"
                        log_info "Auto-selected opencode-ai (required for oh-my-opencode)"
                    fi
                    break
                fi
            done
            break
        fi
    done

    return 0
}

get_user_selection() {
    # Non-interactive mode: use defaults and proceed
    if [[ "$AUTO_YES" == true ]]; then
        printf "${BLUE}[INFO]${NC} Non-interactive mode: using default selections\n"

        # Check if any tools selected
        local selected_count=0
        for sel in "${SELECTED[@]}"; do
            selected_count=$((selected_count + sel))
        done

        if [[ "$selected_count" -eq 0 ]]; then
            log_warning "No tools selected by default (all tools up-to-date). Nothing to do."
            exit 0
        fi

        # Show what will be installed
        printf "\n"
        for i in "${!TOOL_NAMES[@]}"; do
            if [[ "${SELECTED[$i]}" -eq 1 ]]; then
                local action="${TOOL_ACTIONS[$i]}"
                local name="${TOOL_NAMES[$i]}"
                case "$action" in
                    install)
                        printf "  ${GREEN}[INSTALL]${NC} %s\n" "$name"
                        ;;
                    upgrade)
                        printf "  ${CYAN}[UPGRADE]${NC} %s\n" "$name"
                        ;;
                    remove)
                        printf "  ${RED}[REMOVE]${NC} %s\n" "$name"
                        ;;
                esac
            fi
        done
        printf "\n"

        log_success "Auto-proceeding with $selected_count tool(s)..."
        return 0
    fi

    # Interactive mode: show menu and get user input
    while true; do
        render_menu

        printf "\nEnter selection:\n> "
        read -r input

        # Trim input
        input=$(echo "$input" | xargs)

        # Allow explicit proceed token for terminals that cannot send an empty line
        if [[ "${input^^}" == "P" ]]; then
            input=""
        fi

        # Check for quit
        if [[ "${input^^}" == "Q" ]]; then
            log_info "Exiting without changes."
            exit 0
        fi

        # Check for proceed (empty input)
        if [[ -z "$input" ]]; then
            # Check if any tools selected
            local selected_count=0
            for sel in "${SELECTED[@]}"; do
                selected_count=$((selected_count + sel))
            done

            if [[ "$selected_count" -eq 0 ]]; then
                log_warning "No tools selected. Please select at least one tool or press Q to quit."
                read -rp "Press Enter to continue..."
                continue
            fi

            if [[ "$selected_count" -eq 1 ]]; then
                log_success "Starting installation/upgrade of 1 tool..."
            else
                log_success "Starting installation/upgrade of ${selected_count} tools..."
            fi
            return 0
        fi

        # Parse selection
        if parse_selection "$input"; then
            # Selection changed, menu will refresh automatically
            :
        else
            log_error "Invalid input. Please try again."
            read -rp "Press Enter to continue..."
        fi
    done
}

#############################################
# INSTALLATION FUNCTIONS
#############################################

# Build oh-my-opencode flags based on installed tools (auto-detect)
build_ohmy_flags_from_installed_tools() {
    local flags="--no-tui"

    # Auto-detect Claude Code
    if command -v claude >/dev/null 2>&1; then
        flags="$flags --claude=yes"
    else
        flags="$flags --claude=no"
    fi

    # Auto-detect OpenAI Codex
    if command -v codex >/dev/null 2>&1; then
        flags="$flags --openai=yes"
    else
        flags="$flags --openai=no"
    fi

    # GitHub Copilot - default to no (requires special setup)
    flags="$flags --copilot=no"

    # OpenCode Zen - default to no
    flags="$flags --opencode-zen=no"

    # ZAI Coding Plan - default to no (user can enable manually if needed)
    flags="$flags --zai-coding-plan=no"

    # Additional documented providers - default to no (user can enable manually)
    flags="$flags --opencode-go=no --kimi-for-coding=no --vercel-ai-gateway=no"

    echo "$flags"
}

install_oh_my_opencode() {
    local force_reinstall="${1:-false}"
    local opencode_config="$HOME/.config/opencode/opencode.json"
    local ohmy_config="$HOME/.config/opencode/oh-my-opencode.json"

    # Check if plugin is already registered
    if [[ -f "$opencode_config" ]]; then
        local has_plugin="false"
        if command -v jq >/dev/null 2>&1; then
            has_plugin=$(jq -r '.plugin // [] | any(startswith("oh-my-opencode"))' "$opencode_config" 2>/dev/null || echo "false")
        else
            if grep -q '"oh-my-opencode' "$opencode_config" 2>/dev/null; then
                has_plugin="true"
            fi
        fi

        if [[ "$has_plugin" == "true" ]]; then
            # Preserve config on update - skip reinstall if config exists
            if [[ -f "$ohmy_config" && "$force_reinstall" != "true" ]]; then
                printf "  oh-my-opencode already installed with existing configuration.\n"
                log_success "oh-my-opencode is already installed (config preserved)"
                return 0
            fi
            # Force reinstall but preserve config
            if [[ -f "$ohmy_config" && "$force_reinstall" == "true" ]]; then
                printf "  Preserving existing configuration during reinstall...\n"
            fi
        fi
    fi

    # Build flags with auto-detected provider settings
    OHMY_FLAGS=$(build_ohmy_flags_from_installed_tools)
    log_info "Using provider flags: $OHMY_FLAGS"

    # Plugin not registered - try to install
    local runner=()
    if command -v bunx >/dev/null 2>&1; then
        runner=(bunx oh-my-opencode install $OHMY_FLAGS)
    elif command -v npx >/dev/null 2>&1; then
        runner=(npx oh-my-opencode install $OHMY_FLAGS)
    else
        log_warning "Skipping oh-my-opencode install: neither bunx nor npx is available."
        return 0
    fi

    printf "  Installing oh-my-opencode via %s...\n" "${runner[0]}"
    # Suppress verbose output and minified code dumps - only show errors
    if "${runner[@]}" 2>/dev/null; then
        log_success "Installed oh-my-opencode"
        return 0
    else
        log_warning "oh-my-opencode installer had issues (command: ${runner[*]}). The plugin may need to be registered manually in ~/.config/opencode/opencode.json."
        return 1
    fi
}

remove_oh_my_opencode() {
    local runner=()
    if command -v bunx >/dev/null 2>&1; then
        runner=(bunx oh-my-opencode uninstall --no-tui)
    elif command -v npx >/dev/null 2>&1; then
        runner=(npx oh-my-opencode uninstall --no-tui)
    else
        log_warning "Skipping oh-my-opencode removal: neither bunx nor npx is available."
        return 0
    fi

    printf "  Removing oh-my-opencode via %s...\n" "${runner[0]}"
    # Suppress verbose output - only show errors
    if "${runner[@]}" 2>/dev/null; then
        log_success "Removed oh-my-opencode"
        return 0
    else
        log_warning "oh-my-opencode removal had issues. Manual cleanup may be required."
        return 1
    fi
}

install_tool() {
    local name=$1
    local manager=$2
    local pkg=$3
    local installed_version=$4
    # The version the menu displayed as "latest" for this tool. Used by npm-self
    # so the action installs exactly what the menu promised; optional so older
    # call sites keep working.
    local menu_latest_version=${5:-}

    printf "\n- %s: " "$pkg"

    case "$manager" in
        uv)
            if [[ "$installed_version" == "Not Installed" ]]; then
                printf "Installing via uv...\n"
                # For initial install, do not use --force (recommended method)
                if uv tool install "$pkg"; then
                    log_success "Installed ${name}"
                    return 0
                else
                    log_error "Failed to install ${name}"
                    return 1
                fi
            else
                printf "Updating via uv...\n"
                # Use install --force instead of update to get the latest version
                # uv tool update only updates within original version constraints
                if uv tool install "$pkg" --force; then
                    log_success "Updated ${name}"
                    return 0
                else
                    log_error "Failed to update ${name}"
                    return 1
                fi
            fi
            ;;
        npm)
            local npm_bin
            npm_bin=$(get_npm_bin || true)
            if [[ -z "$npm_bin" ]]; then
                log_error "Conda npm not found. npm tools must use conda npm."
                return 1
            fi
            if [[ "$installed_version" == "Not Installed" ]]; then
                printf "Installing via npm...\n"
                if "$npm_bin" install -g "$pkg"; then
                    log_success "Installed ${name}"
                    return 0
                else
                    log_error "Failed to install ${name}"
                    return 1
                fi
            else
                printf "Updating via npm...\n"
                if "$npm_bin" install -g "$pkg@latest"; then
                    log_success "Updated ${name}"
                    return 0
                else
                    log_error "Failed to update ${name}"
                    return 1
                fi
            fi
            ;;
        addon)
            # Addon manager: for optional add-ons like oh-my-opencode
            # Check if the base package is installed (opencode-ai for oh-my-opencode)
            local base_package=""
            local base_check_cmd=""
            if [[ "$pkg" == "oh-my-opencode" ]]; then
                base_package="opencode-ai"
                base_check_cmd="opencode --version"
            fi

            # Check if base package is installed
            if [[ -n "$base_check_cmd" ]]; then
                if ! command -v "${base_check_cmd%% *}" >/dev/null 2>&1 && ! "${base_check_cmd}" >/dev/null 2>&1; then
                    log_error "Cannot install ${name}: ${base_package} must be installed first."
                    log_info "Please select ${base_package} for installation first."
                    return 1
                fi
            fi

            if [[ "$installed_version" == "Not Installed" ]]; then
                printf "Installing addon...\n"
                if [[ "$pkg" == "oh-my-opencode" ]]; then
                    install_oh_my_opencode
                    return $?
                fi
                log_error "Unknown addon: $pkg"
                return 1
            else
                printf "Addon is installed. Upgrading...\n"
                if [[ "$pkg" == "oh-my-opencode" ]]; then
                    # First update the npm package to latest version
                    local npm_bin
                    npm_bin=$(get_npm_bin || true)
                    if [[ -n "$npm_bin" ]]; then
                        printf "  Updating oh-my-opencode npm package...\n"
                        if "$npm_bin" install -g oh-my-opencode@latest 2>/dev/null; then
                            log_success "Updated oh-my-opencode npm package"
                        else
                            log_warning "Failed to update npm package"
                        fi
                    fi
                    # Then reinstall to update plugin registration
                    if ! remove_oh_my_opencode; then
                        log_warning "oh-my-opencode removal had issues during upgrade, continuing with reinstall..."
                    fi
                    install_oh_my_opencode "true"
                    return $?
                fi
                log_error "Unknown addon: $pkg"
                return 1
            fi
            ;;
        native)
            if [[ "$pkg" == "claude-code" ]]; then
                # Check for npm-installed version and migrate
                if check_npm_claude_code; then
                    printf "  ${YELLOW}Detected npm-installed Claude Code (deprecated method)${NC}\n"
                    printf "  ${YELLOW}The npm installation method is deprecated. Migrating to native installer...${NC}\n"
                    printf "  Removing npm version...\n"
                    local npm_bin
                    npm_bin=$(get_npm_bin || true)
                    if [[ -n "$npm_bin" ]] && "$npm_bin" uninstall -g "@anthropic-ai/claude-code" 2>/dev/null; then
                        printf "  ${GREEN}npm version removed successfully${NC}\n"
                    else
                        printf "  ${YELLOW}Warning: Failed to remove npm version, continuing anyway...${NC}\n"
                    fi
                    # Proceed with native installation
                    installed_version="Not Installed"
                fi

                if [[ "$installed_version" == "Not Installed" ]]; then
                    printf "Installing via native installer...\n"
                    if run_claude_installer; then
                        # Add ~/.local/bin to PATH if not already there
                        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                            printf "  ${YELLOW}Note: $HOME/.local/bin should be in your PATH${NC}\n"
                        fi
                        log_success "Installed ${name}"
                        return 0
                    else
                        log_error "Failed to install ${name}"
                        return 1
                    fi
                else
                    printf "Updating...\n"
                    if claude update 2>/dev/null; then
                        log_success "Updated ${name}"
                        # Setup sandbox dependencies after successful update
                        setup_claude_sandbox
                        return 0
                    else
                        # Try running the installer again if update fails
                        printf "  Update command failed, trying re-install...\n"
                        if run_claude_installer; then
                            log_success "Updated ${name}"
                            return 0
                        else
                            log_error "Failed to update ${name}"
                            return 1
                        fi
                    fi
                fi
            elif [[ "$pkg" == "moai-adk" ]]; then
                # MoAI-ADK requires Claude Code CLI
                if ! command -v claude &>/dev/null; then
                    log_error "Claude Code CLI is required for MoAI-ADK. Please install Claude Code CLI first."
                    return 1
                fi

                local before_version after_version
                before_version=$(get_installed_native_version "$pkg")

                # Install jq dependency for moai-adk (prevents settings.json corruption)
                install_jq

                # Install GitHub CLI dependency for moai-adk
                install_gh_cli

                if [[ "$installed_version" == "Not Installed" ]]; then
                    printf "Installing via native installer...\n"
                else
                    printf "Updating via native installer...\n"
                fi
                if run_moai_installer; then
                    after_version=$(get_installed_native_version "$pkg")
                    if [[ -z "$after_version" ]]; then
                        log_error "MoAI-ADK installer completed but moai command is not available."
                        return 1
                    fi
                    if [[ "$installed_version" != "Not Installed" ]] && [[ -n "$before_version" ]] && [[ "$after_version" == "$before_version" ]]; then
                        log_warning "MoAI-ADK version did not change after update attempt (${after_version})."
                    fi
                    if ! record_moai_install_path; then
                        log_warning "MoAI-ADK installed but installer ownership marker could not be written."
                    fi
                    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                        printf "  ${YELLOW}Note: $HOME/.local/bin should be in your PATH${NC}\n"
                    fi
                    log_success "Installed/updated ${name} (${after_version})"

                    # Show GitHub CLI authentication reminder
                    show_gh_auth_reminder

                    # Install ast-grep for MoAI-ADK security scanning
                    install_ast_grep

                    return 0
                else
                    log_error "Failed to install/update ${name}"
                    return 1
                fi
            elif [[ "$pkg" == "antigravity" ]]; then
                # Antigravity CLI: native installer -> ~/.local/bin/agy (self-updates in background)
                if [[ "$installed_version" == "Not Installed" ]]; then
                    printf "Installing via native installer...\n"
                else
                    printf "Updating via native installer...\n"
                fi
                if run_antigravity_installer; then
                    local agy_version
                    agy_version=$(get_installed_native_version "$pkg")
                    if [[ -z "$agy_version" ]]; then
                        log_error "Antigravity CLI installer completed but agy command is not available."
                        return 1
                    fi
                    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                        printf "  ${YELLOW}Note: $HOME/.local/bin should be in your PATH${NC}\n"
                    fi
                    log_success "Installed/updated ${name} (${agy_version})"
                    return 0
                else
                    log_error "Failed to install/update ${name}"
                    return 1
                fi
            fi
            ;;
        npm-self)
            # npm-self should only be "update" action, never "install" from scratch
            # If npm is not installed, this should have been handled via conda
            printf "Updating npm via conda npm...\n"
            local npm_bin
            npm_bin=$(get_npm_bin || true)
            if [[ -z "$npm_bin" ]]; then
                log_error "Conda npm not found. npm tools must use conda npm."
                return 1
            fi
            # Install the exact version the menu offered. Asking for the
            # "latest" tag instead lets npm resolve a release this node may not
            # satisfy: the menu can promise 11.18.0 while the tag resolves to
            # 12.0.1 and the install aborts with EBADENGINE.
            local npm_target
            npm_target=$(npm_install_target "$menu_latest_version")
            if "$npm_bin" install -g "npm@${npm_target}"; then
                log_success "Updated npm via conda npm (npm@${npm_target})"
                return 0
            else
                log_error "Failed to update npm via conda npm (npm@${npm_target})"
                return 1
            fi
            ;;
    esac
}

remove_tool() {
    local name=$1
    local manager=$2
    local pkg=$3
    local installed_version=$4

    printf "\n- %s: " "$pkg"

    # Validate tool is installed
    if [[ "$installed_version" == "Not Installed" ]]; then
        log_error "Cannot remove ${name}: Not installed"
        return 1
    fi

    case "$manager" in
        uv)
            printf "Uninstalling via uv...\n"
            if uv tool uninstall "$pkg"; then
                log_success "Removed ${name}"
                return 0
            else
                log_error "Failed to remove ${name}"
                return 1
            fi
            ;;
        npm)
            printf "Uninstalling via npm...\n"
            local npm_bin
            npm_bin=$(get_npm_bin || true)
            if [[ -z "$npm_bin" ]]; then
                log_error "Conda npm not found. npm tools must use conda npm."
                return 1
            fi
            if "$npm_bin" uninstall -g "$pkg"; then
                log_success "Removed ${name}"
                return 0
            else
                log_error "Failed to remove ${name}"
                return 1
            fi
            ;;
        addon)
            printf "Removing addon...\n"
            if [[ "$pkg" == "oh-my-opencode" ]]; then
                remove_oh_my_opencode
                return $?
            fi
            log_error "Unknown addon: $pkg"
            return 1
            ;;
        native)
            if [[ "$pkg" == "claude-code" ]]; then
                printf "Uninstalling (native)...\n"
                local removed=false
                # Remove the binary
                if [[ -f "$HOME/.local/bin/claude" ]]; then
                    rm -f "$HOME/.local/bin/claude"
                    removed=true
                fi
                # Remove the data directory
                if [[ -d "$HOME/.local/share/claude" ]]; then
                    rm -rf "$HOME/.local/share/claude"
                    removed=true
                fi
                if $removed; then
                    log_success "Removed ${name}"
                    return 0
                else
                    log_error "Failed to remove ${name}"
                    return 1
                fi
            elif [[ "$pkg" == "moai-adk" ]]; then
                printf "Uninstalling (native)...\n"
                local removed=false
                local failed=false
                local target=""
                if [[ -f "$MOAI_STATE_FILE" ]]; then
                    target=$(head -n1 "$MOAI_STATE_FILE" 2>/dev/null || true)
                fi
                if [[ -z "$target" ]]; then
                    log_error "Missing MoAI ownership marker at $MOAI_STATE_FILE. Refusing unsafe uninstall."
                    return 1
                fi
                if [[ -e "$target" ]]; then
                    if rm -f "$target"; then
                        if [[ -e "$target" ]]; then
                            failed=true
                        else
                            removed=true
                        fi
                    else
                        failed=true
                    fi
                fi
                if command -v moai >/dev/null 2>&1; then
                    local current_moai
                    current_moai=$(command -v moai 2>/dev/null || true)
                    if [[ "$current_moai" == "$target" ]]; then
                        failed=true
                    fi
                fi
                if [[ -f "$MOAI_STATE_FILE" ]]; then
                    rm -f "$MOAI_STATE_FILE" || failed=true
                fi
                if $failed; then
                    log_error "Failed to remove ${name}"
                    return 1
                fi
                if $removed; then
                    log_success "Removed ${name}"
                    return 0
                fi
                log_error "Failed to remove ${name}: managed binary not found at $target"
                return 1
            elif [[ "$pkg" == "opencode-ai" ]]; then
                printf "  Uninstalling OpenCode AI CLI...\n"
                # OpenCode AI CLI typically installs to ~/.local/bin
                local removed=false
                if [[ -f "$HOME/.local/bin/opencode" ]]; then
                    rm -f "$HOME/.local/bin/opencode"
                    removed=true
                fi
                if ! remove_oh_my_opencode; then
                    log_warning "oh-my-opencode removal had issues during opencode-ai removal"
                fi
                if $removed; then
                    log_success "Removed ${name}"
                    return 0
                else
                    log_error "Failed to remove ${name}"
                    return 1
                fi
            elif [[ "$pkg" == "antigravity" ]]; then
                # Antigravity CLI: remove the agy binary (installer writes to ~/.local/bin/agy)
                printf "Uninstalling (native)...\n"
                local removed=false
                if [[ -f "$HOME/.local/bin/agy" ]]; then
                    rm -f "$HOME/.local/bin/agy"
                    removed=true
                fi
                if $removed; then
                    log_success "Removed ${name}"
                    return 0
                else
                    log_error "Failed to remove ${name}"
                    return 1
                fi
            fi
            ;;
        npm-self)
            # npm-self should never be removable (update-only tool)
            log_error "Cannot remove npm: npm is a core tool (update-only)"
            return 1
            ;;
    esac
}

display_action_summary() {
    local install_count=0
    local upgrade_count=0
    local remove_count=0
    local -a install_items=()
    local -a upgrade_items=()
    local -a remove_items=()

    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${SELECTED[$i]}" -ne 1 ]]; then
            continue
        fi

        local action="${TOOL_ACTIONS[$i]}"
        local pkg="${TOOL_PACKAGES[$i]}"
        local installed="${INSTALLED_VERSIONS[$i]}"
        local latest="${LATEST_VERSIONS[$i]}"

        case "$action" in
            install)
                install_count=$((install_count + 1))
                install_items+=("${pkg}: ${installed} -> ${latest}")
                ;;
            upgrade)
                upgrade_count=$((upgrade_count + 1))
                upgrade_items+=("${pkg}: ${installed} -> ${latest}")
                ;;
            remove)
                remove_count=$((remove_count + 1))
                remove_items+=("${pkg}: ${installed}")
                ;;
        esac
    done

    print_section "ACTION SUMMARY"

    if [[ "$install_count" -eq 0 && "$upgrade_count" -eq 0 && "$remove_count" -eq 0 ]]; then
        printf -- "- No actions selected.\n"
        return 0
    fi

    if [[ "$install_count" -gt 0 ]]; then
        printf -- "- Install (%d):\n" "$install_count"
        for item in "${install_items[@]}"; do
            printf "  - %s\n" "$item"
        done
    fi

    if [[ "$upgrade_count" -gt 0 ]]; then
        printf -- "- Upgrade (%d):\n" "$upgrade_count"
        for item in "${upgrade_items[@]}"; do
            printf "  - %s\n" "$item"
        done
    fi

    if [[ "$remove_count" -gt 0 ]]; then
        printf -- "- Remove (%d):\n" "$remove_count"
        for item in "${remove_items[@]}"; do
            printf "  - %s\n" "$item"
        done
        printf "\n${RED}${BOLD}WARNING:${NC} removals cannot be undone.\n"
    fi
}

confirm_removals() {
    local has_removals=false

    for action in "${TOOL_ACTIONS[@]}"; do
        if [[ "$action" == "remove" ]]; then
            has_removals=true
            break
        fi
    done

    if [[ "$has_removals" == true ]]; then
        if [[ "$AUTO_YES" == true ]]; then
            printf "${YELLOW}[AUTO-YES]${NC} Proceeding with removals in non-interactive mode\n"
            return 0
        fi

        printf "Proceed with removals? [y/N]: "
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            *)
                log_warning "Cancelled by user"
                exit 0
                ;;
        esac
    fi

    return 0
}

run_installation() {
    local install_success=0
    local install_fail=0
    local upgrade_success=0
    local upgrade_fail=0
    local remove_success=0
    local remove_fail=0

    print_section "INSTALLATION"

    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${SELECTED[$i]}" -eq 1 ]]; then
            local action="${TOOL_ACTIONS[$i]}"

            case "$action" in
                install)
                    if install_tool \
                        "${TOOL_NAMES[$i]}" \
                        "${TOOL_MANAGERS[$i]}" \
                        "${TOOL_PACKAGES[$i]}" \
                        "${INSTALLED_VERSIONS[$i]}" \
                        "${LATEST_VERSIONS[$i]}"; then
                        install_success=$((install_success + 1))
                    else
                        install_fail=$((install_fail + 1))
                    fi
                    ;;
                upgrade)
                    if install_tool \
                        "${TOOL_NAMES[$i]}" \
                        "${TOOL_MANAGERS[$i]}" \
                        "${TOOL_PACKAGES[$i]}" \
                        "${INSTALLED_VERSIONS[$i]}" \
                        "${LATEST_VERSIONS[$i]}"; then
                        upgrade_success=$((upgrade_success + 1))
                    else
                        upgrade_fail=$((upgrade_fail + 1))
                    fi
                    ;;
                remove)
                    if remove_tool \
                        "${TOOL_NAMES[$i]}" \
                        "${TOOL_MANAGERS[$i]}" \
                        "${TOOL_PACKAGES[$i]}" \
                        "${INSTALLED_VERSIONS[$i]}"; then
                        remove_success=$((remove_success + 1))
                    else
                        remove_fail=$((remove_fail + 1))
                    fi
                    ;;
            esac
        fi
    done

    print_section "RESULT"
    printf -- "- Installed: %d\n" "$install_success"
    printf -- "- Upgraded:  %d\n" "$upgrade_success"
    printf -- "- Removed:   %d\n" "$remove_success"
    printf -- "- Failed:    %d\n" "$((install_fail + upgrade_fail + remove_fail))"
}

#############################################
# DEPENDENCY CHECKS
#############################################

get_conda_node_version() {
    # Version of the conda environment's own node (empty if absent/broken)
    local node_bin
    node_bin=$(get_conda_node_path || true)
    if [[ -z "$node_bin" ]]; then
        return 0
    fi
    "$node_bin" --version 2>/dev/null | sed 's/^v//' | head -n1 || true
}

conda_install_nodejs() {
    # Install/upgrade Node.js (conda-forge builds bundle npm) inside the
    # active conda environment. Older environments with pinned dependencies
    # can fail the pinned solve, so fall back through progressively looser
    # specs before giving up.
    printf "Installing Node.js + npm via conda (nodejs>=%s)...\n" "$MIN_NODEJS_VERSION"
    if "$CONDA_CMD" install -y -c conda-forge "nodejs>=${MIN_NODEJS_VERSION}"; then
        return 0
    fi
    log_warning "conda install \"nodejs>=${MIN_NODEJS_VERSION}\" failed (solver conflict?). Retrying with 'conda update nodejs'..."
    if "$CONDA_CMD" update -y -c conda-forge nodejs; then
        return 0
    fi
    log_warning "conda update failed. Retrying with an unpinned 'conda install nodejs'..."
    if "$CONDA_CMD" install -y -c conda-forge nodejs; then
        return 0
    fi
    log_error "All conda attempts to install/update Node.js failed."
    printf "  ${YELLOW}Try manually inside the env: conda install -c conda-forge \"nodejs>=${MIN_NODEJS_VERSION}\" -y${NC}\n"
    return 1
}

bootstrap_npm_from_registry() {
    # Manual npm (re)install for a conda environment whose Node.js is current
    # but whose npm is missing or broken — e.g. a stale npm left behind by a
    # Node.js upgrade, or a nodejs build that shipped without npm. Downloads
    # the official npm tarball and lets the environment's node install it
    # into the environment prefix (the "update node first, then install npm
    # manually" recovery, automated).
    local node_bin=$1

    # Pick the newest npm this very node can run. The install below uses
    # --force, so an EBADENGINE mismatch is not merely refused: a partial
    # forced install can leave the environment without a working npm, i.e. the
    # repair path would break what it was invoked to fix.
    local node_ver npm_ver
    node_ver=$("$node_bin" --version 2>/dev/null | sed 's/^v//' | head -n1 || true)
    npm_ver=$(npm_pick_installable_version "$node_bin" "$node_ver")
    if [[ -z "$npm_ver" ]]; then
        log_error "Could not determine an installable npm version from registry.npmjs.org."
        return 1
    fi

    local tmp_dir
    if ! tmp_dir=$(mktemp -d); then
        log_error "Failed to create temporary directory for the npm bootstrap."
        return 1
    fi

    printf "  ${BLUE}[INFO]${NC} Downloading npm %s from registry.npmjs.org...\n" "$npm_ver"
    if ! curl -fsSL --proto '=https' --tlsv1.2 \
        "https://registry.npmjs.org/npm/-/npm-${npm_ver}.tgz" -o "$tmp_dir/npm.tgz"; then
        log_error "Failed to download the npm ${npm_ver} tarball."
        rm -rf "$tmp_dir"
        return 1
    fi
    if ! tar -xzf "$tmp_dir/npm.tgz" -C "$tmp_dir"; then
        log_error "Failed to extract the npm tarball."
        rm -rf "$tmp_dir"
        return 1
    fi

    # npm installs itself into the prefix derived from the invoking node
    # binary's location ($CONDA_PREFIX); --force overwrites remnants of a
    # broken npm (bin symlinks, stale node_modules/npm).
    if ! "$node_bin" "$tmp_dir/package/bin/npm-cli.js" install -g --force "npm@${npm_ver}"; then
        log_error "Node.js failed to install npm ${npm_ver} into the conda environment."
        rm -rf "$tmp_dir"
        return 1
    fi
    rm -rf "$tmp_dir"
    return 0
}

ensure_npm_prerequisite() {
    local has_npm_tool=0
    for tool in "${TOOLS[@]}"; do
        IFS='|' read -r _ manager _ _ <<< "$tool"
        if [[ "$manager" == "npm" ]]; then
            has_npm_tool=1
            break
        fi
    done

    if [[ "$has_npm_tool" -eq 0 ]]; then
        return 0
    fi

    if [[ -z "${CONDA_PREFIX:-}" && -z "${CONDA_DEFAULT_ENV:-}" ]]; then
        log_error "Conda environment is not active. npm tools must use conda npm."
        printf "Activate a conda environment and re-run this installer.\n"
        return 1
    fi

    if [[ -z "${CONDA_CMD:-}" ]]; then
        log_error "conda command not found. npm tools require conda-provided Node.js/npm."
        printf "Ensure conda is installed and accessible (check CONDA_EXE or PATH).\n"
        return 1
    fi

    # STEP 1 — Node.js first. npm can only run once the environment's own
    # node meets the minimum, so node is validated and repaired before npm
    # is even considered (an outdated node is the usual reason npm breaks).
    local node_version
    node_version=$(get_conda_node_version)

    if [[ -z "$node_version" ]]; then
        log_warning "Node.js not found in the active conda environment. Installing nodejs>=${MIN_NODEJS_VERSION}..."
        conda_install_nodejs || return 1
    elif ! version_ge "$node_version" "$MIN_NODEJS_VERSION"; then
        log_warning "Node.js version ${node_version} is below required ${MIN_NODEJS_VERSION}. Updating via conda..."
        conda_install_nodejs || return 1
    fi

    hash -r 2>/dev/null || true
    node_version=$(get_conda_node_version)
    if [[ -z "$node_version" ]]; then
        log_error "Node.js is still unavailable in the conda environment after the conda install."
        return 1
    fi
    if ! version_ge "$node_version" "$MIN_NODEJS_VERSION"; then
        log_error "Node.js is still below the required version: ${node_version} < ${MIN_NODEJS_VERSION}"
        printf "  ${YELLOW}The conda solver kept an old nodejs. Try: conda install -c conda-forge \"nodejs>=${MIN_NODEJS_VERSION}\" -y${NC}\n"
        return 1
    fi
    log_success "Node.js ready (${node_version})"

    # STEP 2 — npm second, and it must actually RUN, not merely exist: a
    # stale npm left behind by a Node.js upgrade (or a nodejs build shipped
    # without npm) is repaired by bootstrapping npm from the official
    # registry tarball using the environment's node.
    local conda_npm npm_version node_bin
    node_bin=$(get_conda_node_path || true)
    conda_npm=$(get_conda_npm_path || true)
    npm_version=""
    if [[ -n "$conda_npm" ]]; then
        npm_version=$(get_npm_version_from_path "$conda_npm")
    fi

    if [[ -z "$npm_version" ]]; then
        if [[ -n "$conda_npm" ]]; then
            log_warning "npm exists in the conda environment but does not run (broken node/npm pairing)."
        else
            log_warning "npm is missing from the conda environment even though Node.js is installed."
        fi
        log_warning "Bootstrapping npm with the environment's Node.js..."
        bootstrap_npm_from_registry "$node_bin" || return 1
        hash -r 2>/dev/null || true
        conda_npm=$(get_conda_npm_path || true)
        npm_version=""
        if [[ -n "$conda_npm" ]]; then
            npm_version=$(get_npm_version_from_path "$conda_npm")
        fi
        if [[ -z "$npm_version" ]]; then
            log_error "npm bootstrap completed but npm is still not functional."
            printf "  ${YELLOW}Manual fallback (inside the conda env): curl -qL https://www.npmjs.com/install.sh | sh${NC}\n"
            return 1
        fi
        log_success "npm bootstrapped (${npm_version})"
    fi

    # STEP 3 — npm minimum version.
    if version_ge "$npm_version" "$MIN_NPM_VERSION"; then
        printf "${BLUE}[INFO]${NC} npm version %s detected (minimum required: %s)\n" "$npm_version" "$MIN_NPM_VERSION"
        return 0
    fi

    log_warning "npm version $npm_version is below required $MIN_NPM_VERSION. Updating via npm..."
    # Pin to a version this node can run. The "latest" tag may resolve to a
    # release whose engines.node excludes this node, and this is the
    # prerequisite chain: a failure here blocks every npm-managed tool.
    local npm_target
    npm_target=$(npm_install_target "")
    if ! "$conda_npm" install -g "npm@${npm_target}"; then
        log_error "npm update failed. Please run: npm install -g npm@${npm_target} (within the conda env)"
        return 1
    fi

    npm_version=$(get_npm_version_from_path "$conda_npm")
    if [[ -n "$npm_version" ]] && version_ge "$npm_version" "$MIN_NPM_VERSION"; then
        log_success "npm updated to version ${npm_version}"
        return 0
    fi

    log_error "npm update completed but version is still insufficient: ${npm_version:-unknown}"
    return 1
}

check_dependencies() {
    local missing=()

    # Check for required package managers
    for i in "${!TOOL_NAMES[@]}"; do
        local manager="${TOOL_MANAGERS[$i]}"
        if [[ "${SELECTED[$i]}" -eq 1 ]]; then
            case "$manager" in
                uv)
                    if ! command -v uv >/dev/null 2>&1; then
                        missing+=("uv (required for ${TOOL_NAMES[$i]})")
                    fi
                    ;;
                npm)
                    if ! get_npm_bin >/dev/null 2>&1; then
                        missing+=("npm (required for ${TOOL_NAMES[$i]})")
                    fi
                    ;;
                native)
                    # Native tools use their own installer, just need curl
                    if ! command -v curl >/dev/null 2>&1; then
                        missing+=("curl (required for ${TOOL_NAMES[$i]})")
                    fi
                    ;;
            esac
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies:"
        for dep in "${missing[@]}"; do
            printf "  - ${RED}%s${NC}\n" "$dep"
        done
        printf "\n"
        printf "Install missing dependencies:\n"
        printf "  ${CYAN}uv${NC}:   ${YELLOW}curl -LsSf https://astral.sh/uv/install.sh | sh${NC}\n"
        printf "  ${CYAN}npm${NC}:  ${YELLOW}conda install -c conda-forge \"nodejs>=${MIN_NODEJS_VERSION}\" -y${NC}\n"
        printf "  ${CYAN}curl${NC}: ${YELLOW}sudo apt install curl${NC} (Debian/Ubuntu)\n"
        return 1
    fi

    return 0
}

selection_requires_npm() {
    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${SELECTED[$i]}" -eq 1 ]]; then
            case "${TOOL_MANAGERS[$i]}" in
                npm|npm-self)
                    return 0
                    ;;
            esac
        fi
    done
    return 1
}

selection_requires_uv() {
    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${SELECTED[$i]}" -eq 1 ]]; then
            case "${TOOL_MANAGERS[$i]}" in
                uv)
                    return 0
                    ;;
            esac
        fi
    done
    return 1
}

ensure_uv_prerequisite() {
    if command -v uv >/dev/null 2>&1; then
        return 0
    fi

    log_error "uv is not installed but required for uv-managed tools."
    printf "Install uv with conda:\n"
    printf "  ${CYAN}conda install -c conda-forge uv${NC}\n"
    return 1
}

#############################################
# CONDA ENVIRONMENT CHECK
#############################################

check_conda_environment() {
    # Check if conda is active
    local conda_env="${CONDA_DEFAULT_ENV:-}"
    if [[ -n "$conda_env" ]]; then
        # Conda environment is active
        if [[ "$conda_env" == "base" ]]; then
            log_error "Cannot install tools in the base conda environment."
            printf "\n${YELLOW}For safety and to avoid conflicts, please create and use a non-base conda environment.${NC}\n\n"
            printf "To create a new environment:\n"
            printf "  ${CYAN}conda create -n agentic-tools python=3.11${NC}\n"
            printf "  ${CYAN}conda activate agentic-tools${NC}\n\n"
            printf "Then run this script again.\n\n"
            return 1
        else
            printf "${BLUE}[INFO]${NC} Using conda environment: ${CYAN}%s${NC}\n" "$conda_env"
        fi
    fi
    return 0
}

#############################################
# MAIN EXECUTION
#############################################

main() {
    # Check conda environment
    if ! check_conda_environment; then
        exit 1
    fi

    # Resolve conda command (shell function may not be available in script context)
    CONDA_CMD=$(resolve_conda_cmd 2>/dev/null || true)
    if [[ -n "$CONDA_CMD" ]]; then
        printf "${BLUE}[INFO]${NC} Conda command resolved: ${CYAN}%s${NC}\n" "$CONDA_CMD"
    fi

    # Check for curl
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed."
        printf "Install curl: ${CYAN}sudo apt install curl${NC} (Debian/Ubuntu)\n"
        printf "              ${CYAN}sudo yum install curl${NC} (RHEL/CentOS)\n"
        exit 1
    fi

    log_legacy_flags_note

    # Initialize tool information
    initialize_tools

    # Get user selection
    get_user_selection

    # Display action summary
    display_action_summary

    # Confirm removals if any
    confirm_removals

    # Ensure npm is available and recent if any npm tools are selected
    if selection_requires_npm; then
        if ! ensure_npm_prerequisite; then
            exit 1
        fi
    fi

    # Ensure uv is available if any uv tools are selected
    if selection_requires_uv; then
        if ! ensure_uv_prerequisite; then
            exit 1
        fi
    fi

    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi

    # Run installation
    run_installation

    printf "\n${GREEN}${BOLD}Installation complete!${NC}\n\n"
}

# Run main function
main "$@"
