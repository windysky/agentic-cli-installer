# Agentic CLI Installer v1.7.21

**Last Modified:** February 14, 2026

An interactive installer that manages multiple AI coding CLI tools from one place. It detects installed versions, fetches latest versions, and lets you install, update, or remove tools in a single run.

## Quick Start

### Prerequisites

- `curl` (required for all installation methods)
- Active conda environment with Node.js >= 22.9.0 (installed via conda-forge; npm self-updates run inside the env)
- `bunx` or `npx` for oh-my-opencode addon (comes with Node/npm)

Note: npm operations use the active conda environment's npm/Node. No uv-managed tools are included.

### Installation

**Option 1: Using the deployment script (recommended)**

```bash
# Clone the repository
git clone https://github.com/windysky/agentic-cli-installer.git
cd agentic-cli-installer

# Run the deployment script
chmod +x setup.sh
./setup.sh --configure-path
```

**Option 2: Manual installation**

```bash
# Clone the repository
git clone https://github.com/windysky/agentic-cli-installer.git
cd agentic-cli-installer

# Make the script executable
chmod +x install_coding_tools.sh

# Run the installer (interactive mode)
./install_coding_tools.sh

# Or run in non-interactive mode (auto-proceed with defaults)
./install_coding_tools.sh --yes
```

**Windows:**

```powershell
# Clone the repository
git clone https://github.com/windysky/agentic-cli-installer.git
cd agentic-cli-installer

# Run the batch script
.\install_coding_tools.bat

# Or run in non-interactive mode
.\install_coding_tools.bat --yes
```

Note: Run the Windows installer from an Anaconda Prompt with a non-base conda environment active.

## Features

- **Interactive TUI** with per-tool actions (install, update, remove, skip)
- **Multi-format version detection** for npm, uv, and native tools
- **Latest version fetching** from npm, PyPI, and GitHub releases
- **Cross-platform support** for macOS/Linux (`.sh`) and Windows (`.bat`)
- **Cross-platform deployment script** for easy installation
- **Non-interactive mode** with `--yes`/`-y` flag for automation
- **Auto-install script** for processing multiple conda environments
- **Conda-scoped npm** on Windows (no system npm check)
- **Installer integrity checks** using SHA-256 verification before running remote installers
- **Managed uninstall safety** for MoAI-ADK using installer-owned path markers

## Supported Tools

| Tool | Package | Manager | Installation Method |
|------|---------|----------|-------------------|
| [MoAI Agent Development Kit](https://github.com/modu-ai/moai-adk) | `moai-adk` | native | `curl -fsSL https://raw.githubusercontent.com/modu-ai/moai-adk/main/install.sh | bash` |
| [Claude Code CLI](https://github.com/anthropics/claude-code) | `claude-code` | native | [Official installer](https://claude.ai/install.sh) |
| [OpenAI Codex CLI](https://github.com/openai/codex) | `@openai/codex` | npm | `npm install -g @openai/codex` |
| [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) | `@google/gemini-cli` | npm | `npm install -g @google/gemini-cli` |
| [Google Jules CLI](https://jules.google) | `@google/jules` | npm | `npm install -g @google/jules` |
| [OpenCode AI CLI](https://github.com/opencode-ai/opencode) | `opencode-ai` | npm | `npm install -g opencode-ai` |

Note: npm installs run using the active conda environment's npm/Node (Windows does not use system npm). No uv-managed tools are included.

## Usage

### Interactive Mode

```bash
install_coding_tools.sh
```

This displays an interactive menu where you can:
- Toggle tool selection by pressing numbers (skip → install → remove)
- Press Enter to proceed with selected actions
- Press Q to quit

### Non-Interactive Mode

```bash
install_coding_tools.sh --yes
# or
install_coding_tools.sh -y
```

Automatically proceeds with default selections (tools with available updates).

### Auto-Install Across Environments

The `auto_install_coding_tools` script processes all conda environments:

```bash
auto_install_coding_tools
```

## Deployment Script

The `setup.sh` script provides automatic deployment:

```bash
./setup.sh                           # Interactive installation
./setup.sh --configure-path          # Install and configure PATH
./setup.sh --force                   # Skip confirmation prompts
./setup.sh --force --configure-path  # Non-interactive with PATH config
./setup.sh --help                    # Show help message
```

### Deployment Features

- **Automatic platform detection** - WSL, Linux, macOS
- **WSL dual-filesystem support** - Installs both Unix and Windows scripts
- **Backup of existing files** - Preserves your current installations
- **Executable permissions** - Automatically sets chmod +x
- **PATH configuration** - Optional helper to add `~/.local/bin` to your PATH

### Platform-Specific Behavior

**WSL (Windows Subsystem for Linux):**
- Installs `install_coding_tools.sh` to `~/.local/bin/`
- Installs `auto_install_coding_tools` to `~/.local/bin/`
- Installs `install_coding_tools.bat` to `/mnt/c/Users/<username>/.local/bin/`
- Creates backups in `~/.local/bin.backup/`

**Linux/macOS:**
- Installs `install_coding_tools.sh` to `~/.local/bin/`
- Installs `auto_install_coding_tools` to `~/.local/bin/`
- Creates backups in `~/.local/bin.backup/`

**Windows:**
- Run `install_coding_tools.bat` directly (no deployment script needed)

## Notes

- If a conda environment is active, the script refuses to run in `base` for safety.
- Version checks use network calls; slow or blocked connections may show `Unknown` for latest versions.
- The deployment script uses `~/.local/bin/` which follows the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html).

## Troubleshooting

### Command not found after installation

If you get `command not found: install_coding_tools.sh` after running the deployment script:

```bash
# Option 1: Re-run with PATH configuration
./setup.sh --configure-path

# Option 2: Manually add to PATH (add to your ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"

# Option 3: Use the full path
~/.local/bin/install_coding_tools.sh
```

### Permission denied

If you get "Permission denied" when running the installer:

```bash
chmod +x ~/.local/bin/install_coding_tools.sh
chmod +x ~/.local/bin/auto_install_coding_tools
```

### Installation Summary

After successful installation, you should see output similar to:

```
=== Installation Summary ===

[SUCCESS] Deployment completed successfully!

Installed scripts:
  Unix:   ~/.local/bin/install_coding_tools.sh
  Auto:   ~/.local/bin/auto_install_coding_tools
  Windows: /mnt/c/Users/username/.local/bin/install_coding_tools.bat (WSL only)

Backup location: ~/.local/bin.backup
```

## Change Log

### v1.7.21 - February 14, 2026

- **GitHub CLI auto-installation**: Automatically installs `gh` via conda-forge when moai-adk is selected
- **Authentication reminder**: Shows `gh auth login` reminder after moai-adk installation

### v1.7.20 - February 14, 2026

- **Line ending fix**: Normalized `install_coding_tools.bat` to consistent CRLF format (prevents mixed line ending issues)

### v1.7.19 - February 11, 2026

- **Windows tool index fix**: Replaced hardcoded shift index with dynamic `TOOLS_COUNT` in batch initialization, preventing index drift when tool lists change.
- **Release consistency update**: Version strings and release notes aligned across scripts and docs.
- **Documentation cleanup**: Removed stale installer references after tool list updates.

### v1.7.18 - February 9, 2026

- **Node floor enforcement**: Conda installs/updates `nodejs>=22.9.0` when npm tools are selected; npm self-update remains via `npm install -g npm@latest` inside the env.
- **Removed system npm requirement**: Startup system-npm probe removed; only conda npm/Node is required.
- **MoAI installer alignment**: MoAI uses the native installer (no uv); pip-installed moai-adk is removed before install/update.
- **Removed mistral-vibe**: Tool list trimmed to currently supported tools; uv is no longer needed.

### v1.7.17 - February 8, 2026

- **Playwright MCP auto-installation**: Automatically installs and enables Playwright MCP server globally when Claude Code is installed or updated
- **Global MCP configuration**: Uses `claude mcp add --scope user` for project-independent Playwright MCP availability

### v1.7.16 - February 7, 2026

- **Playwright CLI auto-installation**: Automatically installs and updates `@playwright/cli` for Claude Code browser automation

### v1.7.15 - February 7, 2026

- **Seccomp filter auto-installation**: Automatically installs `@anthropic-ai/sandbox-runtime` for Claude Code sandbox security
- **Bubblewrap availability check**: Warns if bubblewrap is missing (optional, non-blocking)
- **Sandbox dependency orchestration**: New `setup_claude_sandbox()` function for coordinated dependency management

### v1.7.14 - February 7, 2026

- **log_warning() fix**: Now outputs to stderr instead of stdout, preventing warning capture by command substitution
- **MoAI-ADK update fix**: Resolved checksum mismatch issue caused by log_warning output being captured

### v1.7.13 - February 7, 2026

- **oh-my-opencode fix**: Version detection now checks `.plugin` (singular) instead of `.plugins` (plural) in opencode.json
- **oh-my-opencode install fix**: Checks if plugin is already registered before attempting installation (avoids upstream bug)

### v1.7.12 - February 7, 2026

- **oh-my-opencode version detection**: Fixed version detection via plugin registration in ~/.config/opencode/opencode.json

### v1.7.5 - February 7, 2026

- **Installer security hardening**: Claude installer is checksum-verified before execution; MoAI installer uses upstream `main` as requested.
- **MoAI uninstall safety**: Uninstall now removes only installer-managed MoAI binary paths and fails on partial/unsafe deletion attempts.
- **MoAI install verification**: Native MoAI install/update now verifies `moai` is available afterward and records owned install path.

### v1.7.4 - February 6, 2026

- **Windows npm policy**: System-level npm check removed; npm operations use conda npm only.
- **Conda npm updates**: npm updates run via `npm install -g npm@latest` within the active conda environment.
- **Batch parser fix**: Removed a cmd.exe parsing edge case that could stop prefetch on Windows.

### v1.7.1 - February 5, 2026

- **System npm optional-but-warned**: If system npm is missing or outdated and the user declines installation, the installer now warns and continues (Claude MCP features may not work). Added `--skip-system-npm` flag for automation.

### v1.7.0 - February 5, 2026

- **Dual npm handling**: System-level npm is still required for Claude MCP servers and is ensured up front; npm is also back in the menu (update-only) and conda-aware checks will install/update Node.js/npm inside the active environment when needed.
- **Menu restored**: npm (Node Package Manager) appears again in the tool list for visibility and updates.

### v1.6.0 - February 5, 2026

- **System npm required**: The shell installer checks for system-level npm (outside conda) at startup and auto-installs/updates it via `curl -q https://www.npmjs.com/install.sh | sudo bash` if missing or outdated.

### v1.5.1 - February 4, 2026

- **Fixed installer output**: Resolved a Bash `printf` error when printing bullet-style lines in the action summary/result sections

### v1.5.0 - February 4, 2026

- **MoAI-ADK Install**: Switched to `uv tool install moai-adk` to avoid upstream installer ANSI issues and improve portability
- **OpenCode Install**: Switched to npm-managed install (`npm install -g opencode-ai`) for consistent versioning and updates

### v1.4.0 - January 31, 2026

- **Non-Interactive Mode**: Added `--yes`/`-y` flag for automatic installation with default selections
- **Tool Management**: Added native installer support where appropriate (e.g., Claude Code)
- **Node.js/npm Requirements**: Now requires Node.js 22.9.0+ (includes npm 10+ for modern tool compatibility)
- **Fixed uv Updates**: uv tools now properly update to latest versions (removed `--force` for initial installs)
- **Version Verification**: Improved npm/Node.js version detection in conda environments

### v1.3.0 - January 28, 2026

- **Auto Install Script**: Added `auto_install_coding_tools` script that automatically processes all conda environments
- **Enhanced Deployment**: The `setup.sh` script now installs both `install_coding_tools.sh` and `auto_install_coding_tools`

### v1.2.0 - January 24, 2026

- Initial release with interactive TUI
- Support for 7 AI coding CLI tools
- Cross-platform support (macOS/Linux/Windows)
