#!/usr/bin/env bash
#
# Agentic CLI Installer Deployment Script
# Cross-platform installation script for install_coding_tools.sh/bat
#
# Features:
# - Platform detection (WSL, Linux, macOS)
# - WSL dual-filesystem handling
# - Backup of existing files
# - Executable permission setting
# - PATH configuration helper
#
# Usage:
#   ./setup.sh [--configure-path] [--force]
#
# Options:
#   --configure-path    Add ~/.local/bin to PATH in shell config
#   --force             Skip confirmation prompts
#
# Version: 1.5.1
# License: MIT

set -euo pipefail

#######################################
# Configuration
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT_SH="${SCRIPT_DIR}/install_coding_tools.sh"
SOURCE_SCRIPT_BAT="${SCRIPT_DIR}/install_coding_tools.bat"
SOURCE_SCRIPT_AUTO="${SCRIPT_DIR}/auto_install_coding_tools"
TARGET_DIR="${HOME}/.local/bin"
BACKUP_DIR="${HOME}/.local/bin.backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FORCE="false"

# Colors for output
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NC=""
fi

#######################################
# Utility Functions
#######################################

# Print info message
info() {
    echo "${BLUE}[INFO]${NC} $*"
}

# Print success message
success() {
    echo "${GREEN}[SUCCESS]${NC} $*"
}

# Print warning message
warning() {
    echo "${YELLOW}[WARNING]${NC} $*"
}

# Print error message
error() {
    echo "${RED}[ERROR]${NC} $*" >&2
}

# Print header
header() {
    echo "${BOLD}$*${NC}"
}

# Check if command exists
command_exists() {
    command -v "$@" >/dev/null 2>&1
}

# Prompt user for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    local yn
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -rp "$prompt" yn
    case $yn in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        "") [[ "$default" == "y" ]] && return 0 || return 1 ;;
        *) return 1 ;;
    esac
}

#######################################
# Platform Detection
#######################################

detect_platform() {
    local platform="unknown"

    # Check for WSL first (WSL1 or WSL2)
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -f /proc/version ]] && grep -qi microsoft /proc/version >/dev/null 2>&1; then
        platform="wsl"
    # Check for macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        platform="macos"
    # Check for Linux
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        platform="linux"
    # Check for Windows (Git Bash, MSYS2, Cygwin)
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        platform="windows"
    fi

    echo "$platform"
}

# Get Windows username in WSL
get_windows_username() {
    local username=""

    # Try multiple methods to get Windows username
    if [[ -n "${USERPROFILE:-}" ]]; then
        username=$(basename "$USERPROFILE")
    elif [[ -n "${WSL_USER:-}" ]]; then
        username="$WSL_USER"
    elif command_exists powershell.exe; then
        username=$(powershell.exe -NoProfile -Command "[Environment]::UserName" 2>/dev/null | tr -d '\r')
    elif [[ -d /mnt/c/Users ]]; then
        # Try to find first user directory
        for user_dir in /mnt/c/Users/*/; do
            if [[ -d "$user_dir" ]]; then
                username=$(basename "$user_dir")
                break
            fi
        done
    fi

    echo "$username"
}

#######################################
# Directory Management
#######################################

create_directory() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        info "Creating directory: $dir"
        if mkdir -p "$dir"; then
            success "Directory created: $dir"
        else
            error "Failed to create directory: $dir"
            return 1
        fi
    else
        info "Directory already exists: $dir"
    fi
}

backup_file() {
    local source="$1"
    local backup_dir="$2"

    if [[ ! -f "$source" ]]; then
        return 0
    fi

    local filename
    filename=$(basename "$source")
    local backup_path="${backup_dir}/${filename}.${TIMESTAMP}"

    info "Backing up existing file: $source"
    if cp "$source" "$backup_path"; then
        success "Backup created: $backup_path"
        return 0
    else
        error "Failed to create backup: $backup_path"
        return 1
    fi
}

#######################################
# Installation Functions
#######################################

install_unix_script() {
    local source="$1"
    local target="$2"

    info "Installing Unix script: $(basename "$source")"

    # Verify source exists
    if [[ ! -f "$source" ]]; then
        error "Source script not found: $source"
        return 1
    fi

    # Check if target exists
    if [[ -f "$target" ]]; then
        warning "Target file already exists: $target"
        if ! confirm "Overwrite existing file?"; then
            info "Installation cancelled for: $(basename "$source")"
            return 0
        fi

        # Create backup
        if ! backup_file "$target" "$BACKUP_DIR"; then
            error "Backup failed, aborting installation"
            return 1
        fi
    fi

    # Copy file
    info "Copying: $source -> $target"
    if cp "$source" "$target"; then
        success "File copied successfully"
    else
        error "Failed to copy file"
        return 1
    fi

    # Set executable permission
    info "Setting executable permission: $target"
    if chmod +x "$target"; then
        success "Permission set: executable (+x)"
    else
        warning "Failed to set executable permission (may need manual: chmod +x $target)"
    fi

    # Verify installation
    if [[ -f "$target" ]] && [[ -x "$target" ]]; then
        success "$(basename "$source") installed successfully!"
        return 0
    else
        error "Installation verification failed"
        return 1
    fi
}

install_windows_script() {
    local source="$1"
    local target_dir="$2"

    info "Installing Windows script to: $target_dir"

    # Verify source exists
    if [[ ! -f "$source" ]]; then
        error "Source script not found: $source"
        return 1
    fi

    # Create target directory
    if ! create_directory "$target_dir"; then
        return 1
    fi

    local target="${target_dir}/$(basename "$source")"

    # Check if target exists
    if [[ -f "$target" ]]; then
        warning "Target file already exists: $target"
        if ! confirm "Overwrite existing file?"; then
            info "Installation cancelled for: $(basename "$source")"
            return 0
        fi
    fi

    # Copy file (convert line endings if needed)
    info "Copying: $source -> $target"
    if cp "$source" "$target"; then
        success "File copied successfully"
    else
        error "Failed to copy file"
        return 1
    fi

    success "$(basename "$source") installed to Windows filesystem!"
}

#######################################
# PATH Configuration
#######################################

detect_shell_config() {
    # Detect shell configuration file
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ -f "$HOME/.zshrc" ]]; then
        echo "$HOME/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]] || [[ -f "$HOME/.bashrc" ]]; then
        echo "$HOME/.bashrc"
    elif [[ -f "$HOME/.profile" ]]; then
        echo "$HOME/.profile"
    else
        echo ""
    fi
}

configure_path() {
    local shell_config
    shell_config=$(detect_shell_config)

    if [[ -z "$shell_config" ]]; then
        warning "Could not detect shell configuration file"
        info "Manually add the following line to your shell profile:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        return 1
    fi

    info "Detected shell config: $shell_config"

    # Check if PATH is already configured
    local path_entry="export PATH=\"$TARGET_DIR:\$PATH\""
    if grep -qF "$path_entry" "$shell_config" 2>/dev/null; then
        info "PATH already configured in $shell_config"
        return 0
    fi

    # Check for similar pattern
    if grep -qF "$TARGET_DIR" "$shell_config" 2>/dev/null; then
        info "PATH entry already exists (different format) in $shell_config"
        return 0
    fi

    # Add PATH configuration
    info "Adding $TARGET_DIR to PATH in $shell_config"

    {
        echo ""
        echo "# Added by Agentic CLI Installer ($(date +%Y-%m-%d))"
        echo "$path_entry"
    } >> "$shell_config"

    success "PATH configuration added!"
    info "Restart your shell or run 'source $shell_config' to apply changes"
}

#######################################
# WSL-Specific Handling
#######################################

handle_wsl() {
    local platform="$1"
    local windows_username

    info "WSL environment detected"

    # Get Windows username
    windows_username=$(get_windows_username)

    if [[ -z "$windows_username" ]]; then
        warning "Could not detect Windows username"
        info "Skipping Windows filesystem installation"

        # Only install Unix script
        install_unix_script "$SOURCE_SCRIPT_SH" "${TARGET_DIR}/install_coding_tools.sh"
        return $?
    fi

    success "Detected Windows user: $windows_username"

    local windows_bin_dir="/mnt/c/Users/${windows_username}/.local/bin"

    # Install Unix script to Linux filesystem
    install_unix_script "$SOURCE_SCRIPT_SH" "${TARGET_DIR}/install_coding_tools.sh" || return $?

    # Install auto install script to Linux filesystem
    if [[ -f "$SOURCE_SCRIPT_AUTO" ]]; then
        install_unix_script "$SOURCE_SCRIPT_AUTO" "${TARGET_DIR}/auto_install_coding_tools" || return $?
    else
        info "Auto install script not found, skipping: $SOURCE_SCRIPT_AUTO"
    fi

    # Install Windows script to Windows filesystem
    if [[ -f "$SOURCE_SCRIPT_BAT" ]]; then
        install_windows_script "$SOURCE_SCRIPT_BAT" "$windows_bin_dir" || return $?
    else
        info "Windows batch script not found, skipping: $SOURCE_SCRIPT_BAT"
    fi

    info "WSL installation complete!"
    info "Unix script: ${TARGET_DIR}/install_coding_tools.sh"
    info "Windows script: $windows_bin_dir/install_coding_tools.bat"

    return 0
}

#######################################
# Main Installation Flow
#######################################

main() {
    local platform
    local configure_path="false"
    local force="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --configure-path)
                configure_path="true"
                shift
                ;;
            --force)
                force="true"
                FORCE="true"
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--configure-path] [--force]"
                echo ""
                echo "Cross-platform installation script for Agentic CLI Installer"
                echo ""
                echo "Options:"
                echo "  --configure-path    Add ~/.local/bin to PATH in shell config"
                echo "  --force             Skip confirmation prompts"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                              # Interactive installation"
                echo "  $0 --configure-path             # Install and configure PATH"
                echo "  $0 --force --configure-path     # Non-interactive with PATH config"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done

    header "=== Agentic CLI Installer Deployment ==="
    echo ""

    # Detect platform
    platform=$(detect_platform)
    info "Detected platform: $platform"

    if [[ "$platform" == "unknown" ]]; then
        error "Unable to detect platform"
        error "This script supports: WSL, Linux, macOS"
        exit 1
    fi

    # Create target and backup directories
    echo ""
    info "Setting up directories..."
    create_directory "$TARGET_DIR" || exit 1
    create_directory "$BACKUP_DIR" || exit 1

    # Platform-specific installation
    echo ""
    case "$platform" in
        wsl)
            handle_wsl "$platform" || exit 1
            ;;
        linux|macos)
            install_unix_script "$SOURCE_SCRIPT_SH" "${TARGET_DIR}/install_coding_tools.sh" || exit 1
            # Install auto install script to Linux filesystem
            if [[ -f "$SOURCE_SCRIPT_AUTO" ]]; then
                install_unix_script "$SOURCE_SCRIPT_AUTO" "${TARGET_DIR}/auto_install_coding_tools" || exit 1
            else
                info "Auto install script not found, skipping: $SOURCE_SCRIPT_AUTO"
            fi
            ;;
        windows)
            error "This deployment script is for Unix-like systems only"
            error "On Windows, please run install_coding_tools.bat directly"
            exit 1
            ;;
    esac

    # Configure PATH if requested
    if [[ "$configure_path" == "true" ]]; then
        echo ""
        configure_path
    fi

    # Final summary
    echo ""
    header "=== Installation Summary ==="
    echo ""
    success "Deployment completed successfully!"
    echo ""
    echo "Installed scripts:"
    echo "  Unix:   ${TARGET_DIR}/install_coding_tools.sh"
    if [[ -f "$SOURCE_SCRIPT_AUTO" ]]; then
        echo "  Auto:   ${TARGET_DIR}/auto_install_coding_tools"
    fi
    if [[ "$platform" == "wsl" ]] && [[ -f "$SOURCE_SCRIPT_BAT" ]]; then
        local windows_username
        windows_username=$(get_windows_username)
        echo "  Windows: /mnt/c/Users/${windows_username}/.local/bin/install_coding_tools.bat"
    fi
    echo ""
    echo "Backup location: $BACKUP_DIR"
    echo ""

    # PATH configuration reminder
    if [[ "$configure_path" == "false" ]]; then
        if [[ ":$PATH:" != *":$TARGET_DIR:"* ]]; then
            warning "$TARGET_DIR is not in your PATH"
            echo ""
            echo "To add it to your PATH, run:"
            echo "  $0 --configure-path"
            echo ""
            echo "Or manually add to your shell profile:"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
        fi
    fi

    echo "Run the installer with:"
    if [[ "$platform" == "wsl" ]]; then
        echo "  ~/.local/bin/install_coding_tools.sh"
    else
        echo "  ~/.local/bin/install_coding_tools.sh"
    fi
    echo ""

    trap - EXIT
    exit 0
}

# Cleanup on exit
cleanup() {
    local exit_code=$?
    # Add any cleanup logic here if needed
    exit $exit_code
}

trap cleanup EXIT

# Run main function
main "$@"
