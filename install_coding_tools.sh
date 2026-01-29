#!/usr/bin/env bash
set -euo pipefail

#############################################
# Agentic Coders Installer v1.3.0
# Interactive installer for AI coding CLI tools
#############################################

# Non-interactive mode flag
AUTO_YES=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            AUTO_YES=true
            shift
            ;;
        --help|-h)
            printf "Usage: %s [--yes|-y] [--help|-h]\n" "$0"
            printf "\nOptions:\n"
            printf "  --yes, -y        Non-interactive mode (auto-proceed with defaults)\n"
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
readonly MIN_NPM_VERSION="25.2.1"

# Tool definitions: name, package manager, package name, description
declare -a TOOLS=(
    "moai-adk|uv|moai-adk|MoAI Agent Development Kit"
    "claude-code|native|claude-code|Claude Code CLI"
    "@openai/codex|npm|@openai/codex|OpenAI Codex CLI"
    "@google/gemini-cli|npm|@google/gemini-cli|Google Gemini CLI"
    "@google/jules|npm|@google/jules|Google Jules CLI"
    "opencode-ai|npm|opencode-ai|OpenCode AI CLI"
    "mistral-vibe|uv|mistral-vibe|Mistral Vibe CLI"
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

# Action states for tool selection
declare -a ACTIONS=("skip" "install" "remove")
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
    printf "${YELLOW}[WARNING]${NC} %s\n" "$*"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$*" >&2
}

print_header() {
    printf "\n${CYAN}${BOLD}%s${NC}\n" "$*"
}

print_sep() {
    # Get terminal width, default to 80 if unavailable
    local width
    width=$(tput cols 2>/dev/null || echo 80)
    # Create separator line that fills terminal width
    local sep=""
    for ((i=0; i<width; i++)); do
        sep+="─"
    done
    printf "${CYAN}%s${NC}\n" "$sep"
}

clear_screen() {
    clear
}

version_ge() {
    # Returns success if $1 >= $2 using version sort
    local ver=$1
    local min_ver=$2
    [[ "$(printf '%s\n%s\n' "$min_ver" "$ver" | sort -V | head -n1)" == "$min_ver" ]]
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

run_claude_installer() {
    local tmp
    if ! tmp=$(mktemp); then
        log_error "Failed to create temporary file for installer."
        return 1
    fi

    if ! curl -fsSL --proto '=https' --tlsv1.2 https://claude.ai/install.sh -o "$tmp"; then
        log_error "Failed to download Claude Code installer."
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
    #   moai-adk v0.41.2
    #   mistral-vibe 1.3.4
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
        # Escape special regex characters in package name
        local escaped_pkg=$(printf '%s\n' "$pkg" | sed 's/[[\.*^$()+?{|]/\\&/g')
        version=$(echo "$output" | grep -E "${escaped_pkg}[[:space:]]+v?[0-9]" | head -n1 | sed -E 's/.*[[:space:]]+v?([0-9][^[:space:]]*).*/\1/')
    fi

    # Method 3: Last resort - simple grep and extract
    if [[ -z "$version" ]]; then
        version=$(echo "$output" | grep "${pkg}" | head -n1 | awk '{print $2}' | sed 's/^v//')
    fi

    echo "$version"
}

get_installed_npm_version() {
    local pkg=$1
    if ! command -v npm >/dev/null 2>&1; then
        return 0
    fi
    local json
    if [[ "$NPM_LIST_JSON_READY" -eq 0 ]]; then
        NPM_LIST_JSON_CACHE=$(npm list -g --depth=0 --json 2>/dev/null || true)
        NPM_LIST_JSON_READY=1
    fi
    json="$NPM_LIST_JSON_CACHE"
    if [[ -z "$json" ]]; then
        return 0
    fi
    # SAFE: Pass package name as CLI argument instead of interpolating into code
    if command -v node >/dev/null 2>&1; then
        node -e "
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
    local cache_bust
    cache_bust=$(date +%s)
    if command -v python3 >/dev/null 2>&1; then
        {
            curl -fsSL --connect-timeout 2 --max-time 10 --retry 1 --retry-delay 0 --retry-max-time 10 \
                "https://pypi.org/pypi/${pkg}/json?ts=${cache_bust}" 2>/dev/null || echo -n ""
        } | python3 -c "import sys, json; data = sys.stdin.read().strip(); print(json.loads(data)['info']['version']) if data else None" 2>/dev/null || true
    elif command -v node >/dev/null 2>&1; then
        {
            curl -fsSL --connect-timeout 2 --max-time 10 --retry 1 --retry-delay 0 --retry-max-time 10 \
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
    local cache_bust
    cache_bust=$(date +%s)
    if command -v node >/dev/null 2>&1; then
        {
            curl -fsSL --max-time 10 "https://registry.npmjs.org/${pkg}/latest?ts=${cache_bust}" 2>/dev/null || echo -n ""
        } | node -e "const data = require('fs').readFileSync(0, 'utf8').trim(); if(data) console.log(JSON.parse(data).version);" 2>/dev/null || true
    fi
}

# Get npm's own installed version
get_installed_npm_self_version() {
    if ! command -v npm >/dev/null 2>&1; then
        return 0
    fi
    npm --version 2>/dev/null | head -n1 || true
}

# Get npm's own latest version
get_latest_npm_self_version() {
    if ! command -v curl >/dev/null 2>&1; then
        return 0
    fi
    # Cache-bust to avoid stale CDN responses
    local cache_bust
    cache_bust=$(date +%s)
    if command -v node >/dev/null 2>&1; then
        {
            curl -fsSL --max-time 10 "https://registry.npmjs.org/npm/latest?ts=${cache_bust}" 2>/dev/null || echo -n ""
        } | node -e "const data = require('fs').readFileSync(0, 'utf8').trim(); if(data) console.log(JSON.parse(data).version);" 2>/dev/null || true
    fi
}

get_installed_native_version() {
    local pkg=$1
    # Check for claude binary
    if [[ "$pkg" == "claude-code" ]]; then
        if command -v claude >/dev/null 2>&1; then
            claude --version 2>/dev/null | head -n1 | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || true
        fi
    fi
}

# Check for npm-installed Claude Code (for migration)
check_npm_claude_code() {
    if command -v npm >/dev/null 2>&1; then
        local json
        json=$(npm list -g --depth=0 --json 2>/dev/null || true)
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
    esac

    if [[ -n "$installed" ]]; then
        echo "$installed"
    else
        echo "Not Installed"
    fi
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
            # For native Claude Code, check the GitHub releases with rate limit handling
            if [[ "$pkg" == "claude-code" ]] && command -v curl >/dev/null 2>&1; then
                local cache_bust
                cache_bust=$(date +%s)
                if command -v python3 >/dev/null 2>&1; then
                    local response
                    if response=$(github_api_get_with_retry "https://api.github.com/repos/anthropics/claude-code/releases/latest?ts=${cache_bust}"); then
                        echo "$response" | python3 -c "import sys, json; data = sys.stdin.read().strip(); print(json.loads(data)['tag_name'].lstrip('v')) if data else None" 2>/dev/null || true
                    fi
                fi
            fi
            ;;
    esac
}

version_parse() {
    local version=$1
    # Remove 'v' prefix
    version="${version#v}"
    # Extract major, minor, patch
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    # Strip pre-release tags (everything after hyphen)
    minor="${minor%%-*}"
    patch="${patch%%-*}"
    echo "$major $minor $patch"
}

version_compare() {
    local installed=$1
    local latest=$2

    # Handle "Not Installed" case
    if [[ "$installed" == "Not Installed" ]]; then
        echo "missing"
        return
    fi

    # Handle empty latest version
    if [[ -z "$latest" ]]; then
        echo "unknown"
        return
    fi

    # Parse versions into components
    local installed_major installed_minor installed_patch
    local latest_major latest_minor latest_patch

    read -r installed_major installed_minor installed_patch <<< "$(version_parse "$installed")"
    read -r latest_major latest_minor latest_patch <<< "$(version_parse "$latest")"

    # Handle empty components (default to 0)
    installed_major=${installed_major:-0}
    installed_minor=${installed_minor:-0}
    installed_patch=${installed_patch:-0}
    latest_major=${latest_major:-0}
    latest_minor=${latest_minor:-0}
    latest_patch=${latest_patch:-0}

    # Compare major version
    if [[ "$installed_major" -gt "$latest_major" ]]; then
        echo "current"
        return
    elif [[ "$installed_major" -lt "$latest_major" ]]; then
        echo "update"
        return
    fi

    # Compare minor version
    if [[ "$installed_minor" -gt "$latest_minor" ]]; then
        echo "current"
        return
    elif [[ "$installed_minor" -lt "$latest_minor" ]]; then
        echo "update"
        return
    fi

    # Compare patch version
    if [[ "$installed_patch" -ge "$latest_patch" ]]; then
        echo "current"
    else
        echo "update"
    fi
}

prefetch_latest_versions() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local -a pids=()

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
                esac
                if [[ -n "$latest" ]]; then
                    break
                fi
                sleep 1
            done
            printf "%s" "$latest" >"$out"
        ) &
        pids+=("$!")
    done

    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done

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
    # Conditionally add npm to the tool list (only if detected)
    if command -v npm >/dev/null 2>&1; then
        TOOL_NAMES+=("npm")
        TOOL_MANAGERS+=("npm-self")
        TOOL_PACKAGES+=("npm")
        TOOL_DESCRIPTIONS+=("npm (Node Package Manager)")
        UPDATE_ONLY+=(1)  # npm is update-only
    fi

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
            # Set action from ACTIONS array based on status
            TOOL_ACTIONS+=("${ACTIONS[1]}")  # ACTIONS[1] = "install"
        else
            SELECTED+=(0)
            TOOL_ACTIONS+=("${ACTIONS[0]}")  # ACTIONS[0] = "skip"
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

    printf "${BOLD}${CYAN}Agentic Coders CLI Installer${NC} ${BOLD}v1.2.0${NC}\n\n"
    printf "Toggle tools: ${CYAN}skip${NC} -> ${GREEN}install${NC} -> ${RED}remove${NC} (press number multiple times)\n"
    printf "Numbers are ${BOLD}comma-separated${NC} (e.g., ${CYAN}1,3,5${NC}). Press ${BOLD}Q${NC} to quit.\n\n"

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
                        # Outdated: skip -> install (update)
                        new_action="install"
                        SELECTED[$idx]=1
                        TOOL_ACTIONS[$idx]="install"
                        log_info "Selected for update: ${TOOL_NAMES[$idx]}"
                    else
                        # Not installed or up-to-date: skip remains skip (with message)
                        log_info "${TOOL_NAMES[$idx]} is $installed - no action available"
                    fi
                    ;;
                install)
                    # install -> skip
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
                        # Outdated: skip -> install
                        new_action="install"
                        SELECTED[$idx]=1
                        TOOL_ACTIONS[$idx]="install"
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
                        # Installed (outdated): install -> remove
                        new_action="remove"
                        SELECTED[$idx]=1
                        TOOL_ACTIONS[$idx]="remove"
                        log_info "Selected for removal: ${TOOL_NAMES[$idx]}"
                    fi
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
                        new_action="install"
                    fi
                    SELECTED[$idx]=1
                    TOOL_ACTIONS[$idx]="$new_action"
                    log_info "Selected: ${TOOL_NAMES[$idx]}"
                    ;;
            esac
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

        printf "\n${CYAN}Enter selection (numbers, Enter to proceed, P if Enter fails, Q to quit):${NC} "
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

            log_success "Starting installation/upgrade of $selected_count tool(s)..."
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

install_tool() {
    local name=$1
    local manager=$2
    local pkg=$3
    local installed_version=$4

    printf "\n${CYAN}Processing: ${name}${NC}\n"

    case "$manager" in
        uv)
            if [[ "$installed_version" == "Not Installed" ]]; then
                printf "  Installing ${pkg}...\n"
                if uv tool install "$pkg" --force; then
                    log_success "Installed ${name}"
                    return 0
                else
                    log_error "Failed to install ${name}"
                    return 1
                fi
            else
                printf "  Updating ${pkg}...\n"
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
            if [[ "$installed_version" == "Not Installed" ]]; then
                printf "  Installing ${pkg}...\n"
                if npm install -g "$pkg"; then
                    log_success "Installed ${name}"
                    return 0
                else
                    log_error "Failed to install ${name}"
                    return 1
                fi
            else
                printf "  Updating ${pkg}...\n"
                if npm install -g "$pkg@latest"; then
                    log_success "Updated ${name}"
                    return 0
                else
                    log_error "Failed to update ${name}"
                    return 1
                fi
            fi
            ;;
        native)
            if [[ "$pkg" == "claude-code" ]]; then
                # Check for npm-installed version and migrate
                if check_npm_claude_code; then
                    printf "  ${YELLOW}Detected npm-installed Claude Code (deprecated method)${NC}\n"
                    printf "  ${YELLOW}The npm installation method is deprecated. Migrating to native installer...${NC}\n"
                    printf "  Removing npm version...\n"
                    if npm uninstall -g "@anthropic-ai/claude-code" 2>/dev/null; then
                        printf "  ${GREEN}npm version removed successfully${NC}\n"
                    else
                        printf "  ${YELLOW}Warning: Failed to remove npm version, continuing anyway...${NC}\n"
                    fi
                    # Proceed with native installation
                    installed_version="Not Installed"
                fi

                if [[ "$installed_version" == "Not Installed" ]]; then
                    printf "  Installing Claude Code (native installer)...\n"
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
                    printf "  Updating Claude Code...\n"
                    if claude update 2>/dev/null; then
                        log_success "Updated ${name}"
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
            fi
            ;;
        npm-self)
            # npm-self should only be "update" action, never "install" from scratch
            # If npm is not installed, this should have been handled via conda
            printf "  Updating npm...\n"
            if npm install -g npm@latest; then
                log_success "Updated npm"
                return 0
            else
                log_error "Failed to update npm"
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

    printf "\n${CYAN}Processing: ${name}${NC}\n"

    # Validate tool is installed
    if [[ "$installed_version" == "Not Installed" ]]; then
        log_error "Cannot remove ${name}: Not installed"
        return 1
    fi

    case "$manager" in
        uv)
            printf "  Uninstalling ${pkg}...\n"
            if uv tool uninstall "$pkg"; then
                log_success "Removed ${name}"
                return 0
            else
                log_error "Failed to remove ${name}"
                return 1
            fi
            ;;
        npm)
            printf "  Uninstalling ${pkg}...\n"
            if npm uninstall -g "$pkg"; then
                log_success "Removed ${name}"
                return 0
            else
                log_error "Failed to remove ${name}"
                return 1
            fi
            ;;
        native)
            if [[ "$pkg" == "claude-code" ]]; then
                printf "  Uninstalling Claude Code (native)...\n"
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
            fi
            ;;
        npm-self)
            # npm-self should never be removable (update-only tool)
            log_error "Cannot remove npm: npm is a core tool (update-only)"
            return 1
            ;;
    esac
}

validate_removal() {
    local name=$1
    local installed_version=$2

    if [[ "$installed_version" == "Not Installed" ]]; then
        log_error "Cannot remove ${name}: Not installed"
        return 1
    fi

    return 0
}

display_action_summary() {
    local install_count=0
    local remove_count=0
    local install_tools=""
    local remove_tools=""

    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${SELECTED[$i]}" -eq 1 ]]; then
            local action="${TOOL_ACTIONS[$i]}"
            case "$action" in
                install)
                    install_count=$((install_count + 1))
                    if [[ -n "$install_tools" ]]; then
                        install_tools+=", "
                    fi
                    install_tools+="${TOOL_NAMES[$i]}"
                    ;;
                remove)
                    remove_count=$((remove_count + 1))
                    if [[ -n "$remove_tools" ]]; then
                        remove_tools+=", "
                    fi
                    remove_tools+="${TOOL_NAMES[$i]}"
                    ;;
            esac
        fi
    done

    print_sep
    print_header "Action Summary"
    print_sep
    printf "  ${GREEN}Install${NC}: %d tools" "$install_count"
    if [[ $install_count -gt 0 ]]; then
        printf " (%s)\n" "$install_tools"
    else
        printf "\n"
    fi

    if [[ $remove_count -gt 0 ]]; then
        printf "  ${RED}Remove${NC}: %d tools (%s)\n" "$remove_count" "$remove_tools"
        print_sep
        printf "\n"
        printf "${RED}${BOLD}WARNING: You are about to remove '%s'${NC}\n" "$remove_tools"
        printf "${RED}${BOLD}This action cannot be undone.${NC}\n"
        printf "\n"
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

        printf "Proceed? (y/N): "
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
    local remove_success=0
    local remove_fail=0

    print_sep
    print_header "Installation Progress"
    print_sep

    for i in "${!TOOL_NAMES[@]}"; do
        if [[ "${SELECTED[$i]}" -eq 1 ]]; then
            local action="${TOOL_ACTIONS[$i]}"

            case "$action" in
                install)
                    if install_tool \
                        "${TOOL_NAMES[$i]}" \
                        "${TOOL_MANAGERS[$i]}" \
                        "${TOOL_PACKAGES[$i]}" \
                        "${INSTALLED_VERSIONS[$i]}"; then
                        install_success=$((install_success + 1))
                    else
                        install_fail=$((install_fail + 1))
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

    print_sep
    print_header "Installation Summary"
    print_sep
    printf "  ${GREEN}Installed${NC}: %d\n" "$install_success"
    if [[ $install_fail -gt 0 ]]; then
        printf "  ${RED}Install Failed${NC}: %d\n" "$install_fail"
    fi
    printf "  ${GREEN}Removed${NC}: %d\n" "$remove_success"
    if [[ $remove_fail -gt 0 ]]; then
        printf "  ${RED}Remove Failed${NC}: %d\n" "$remove_fail"
    fi
    print_sep
}

#############################################
# DEPENDENCY CHECKS
#############################################

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

    # Helper function to get npm from conda environment directly
    get_conda_npm_path() {
        if [[ -n "$CONDA_PREFIX" ]]; then
            echo "$CONDA_PREFIX/bin/npm"
        elif [[ -n "$CONDA_DEFAULT_ENV" ]]; then
            # Try to find conda prefix from environment name
            local conda_root
            conda_root=$(conda info --base 2>/dev/null || true)
            if [[ -n "$conda_root" ]]; then
                echo "$conda_root/envs/$CONDA_DEFAULT_ENV/bin/npm"
            fi
        fi
    }

    # Helper function to get npm version from specific path
    get_npm_version_from_path() {
        local npm_path=$1
        if [[ -x "$npm_path" ]]; then
            "$npm_path" --version 2>/dev/null | head -n1 || true
        fi
    }

    local conda_npm
    conda_npm=$(get_conda_npm_path)

    if ! command -v npm >/dev/null 2>&1; then
        # Check if we're in a conda environment
        if [[ -n "$CONDA_DEFAULT_ENV" && -n "$conda_npm" ]]; then
            log_warning "npm is not installed but required for npm-managed tools."
            printf "Attempting to install Node.js ${MIN_NPM_VERSION}+ via conda...\n"
            if conda install -y -c conda-forge "nodejs>=${MIN_NPM_VERSION}"; then
                # Clear any command hash cache
                hash -r npm 2>/dev/null || true
                # Verify using the conda npm directly
                if [[ -x "$conda_npm" ]]; then
                    local npm_version
                    npm_version=$(get_npm_version_from_path "$conda_npm")
                    log_success "Node.js + npm ${npm_version} installed via conda"
                    return 0
                else
                    log_error "npm installation via conda appeared successful but npm is still not available at: $conda_npm"
                    return 1
                fi
            else
                log_error "Failed to install Node.js via conda."
                printf "Install Node.js + npm manually:\n"
                printf "  ${CYAN}macOS${NC}:           ${YELLOW}brew install node${NC}\n"
                printf "  ${CYAN}Debian/Ubuntu${NC}:   ${YELLOW}curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash - && sudo apt-get install -y nodejs${NC}\n"
                printf "  ${CYAN}Other platforms${NC}: ${YELLOW}https://docs.npmjs.com/downloading-and-installing-node-js-and-npm${NC}\n"
                return 1
            fi
        else
            log_warning "npm is not installed but required for npm-managed tools."
            printf "Install Node.js ${MIN_NPM_VERSION}+ before continuing:\n"
            printf "  ${CYAN}macOS${NC}:           ${YELLOW}brew install node${NC}\n"
            printf "  ${CYAN}Debian/Ubuntu${NC}:   ${YELLOW}curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash - && sudo apt-get install -y nodejs${NC}\n"
            printf "  ${CYAN}Other platforms${NC}: ${YELLOW}https://docs.npmjs.com/downloading-and-installing-node-js-and-npm${NC}\n"
            return 1
        fi
    fi

    local npm_version
    npm_version=$(npm --version 2>/dev/null | head -n1 || true)
    if [[ -z "$npm_version" ]]; then
        log_error "Unable to determine npm version."
        return 1
    fi

    if version_ge "$npm_version" "$MIN_NPM_VERSION"; then
        printf "${BLUE}[INFO]${NC} npm version %s detected (minimum required: %s)\n" "$npm_version" "$MIN_NPM_VERSION"
        return 0
    fi

    # Version is too old, try to update via conda if available
    if [[ -n "$CONDA_DEFAULT_ENV" && -n "$conda_npm" ]]; then
        log_warning "npm version $npm_version is below required $MIN_NPM_VERSION. Updating via conda..."
        if conda install -y -c conda-forge "nodejs=${MIN_NPM_VERSION}" --force-reinstall; then
            # Clear command hash cache
            hash -r npm 2>/dev/null || true
            # Verify using the conda npm directly
            local updated_version
            updated_version=$(get_npm_version_from_path "$conda_npm")
            if [[ -n "$updated_version" ]] && version_ge "$updated_version" "$MIN_NPM_VERSION"; then
                log_success "Node.js + npm updated to version ${updated_version} via conda"
                return 0
            else
                log_error "Conda update completed but version is still insufficient: ${updated_version:-unknown}"
                return 1
            fi
        else
            log_warning "Conda update failed, trying npm self-update..."
        fi
    fi

    # Fallback to npm self-update (only if we have a compatible node version)
    log_warning "npm version $npm_version is below required $MIN_NPM_VERSION. Attempting to update via npm..."
    if npm install -g npm@latest; then
        local updated_version
        updated_version=$(npm --version 2>/dev/null | head -n1 || true)
        log_success "npm updated to version ${updated_version:-unknown}."
        return 0
    else
        log_error "npm update failed. Please run: npm install -g npm@latest"
        return 1
    fi
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
                    if ! command -v npm >/dev/null 2>&1; then
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
        printf "  ${CYAN}npm${NC}:   ${YELLOW}https://docs.npmjs.com/downloading-and-installing-node-js-and-npm${NC}\n"
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
    if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
        # Conda environment is active
        if [[ "$CONDA_DEFAULT_ENV" == "base" ]]; then
            log_error "Cannot install tools in the base conda environment."
            printf "\n${YELLOW}For safety and to avoid conflicts, please create and use a non-base conda environment.${NC}\n\n"
            printf "To create a new environment:\n"
            printf "  ${CYAN}conda create -n agentic-tools python=3.11${NC}\n"
            printf "  ${CYAN}conda activate agentic-tools${NC}\n\n"
            printf "Then run this script again.\n\n"
            return 1
        else
            printf "${BLUE}[INFO]${NC} Using conda environment: ${CYAN}%s${NC}\n" "$CONDA_DEFAULT_ENV"
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

    # Check for curl
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed."
        printf "Install curl: ${CYAN}sudo apt install curl${NC} (Debian/Ubuntu)\n"
        printf "              ${CYAN}sudo yum install curl${NC} (RHEL/CentOS)\n"
        exit 1
    fi

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
