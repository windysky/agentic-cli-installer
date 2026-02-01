# Agentic CLI Installer v1.4.0

**Last Modified:** January 31, 2026

An interactive installer that manages multiple AI coding CLI tools from one place. It detects installed versions, fetches latest versions, and lets you install, update, or remove tools in a single run.

## Quick Start

### Prerequisites

- `curl` (required for all installation methods)
- Python 3.11+ for moai-adk (automatically installed by the official installer)
- `uv` for mistral-vibe: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Node.js >= 22.9.0 for npm tools (automatically installed in conda environments)

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

## Features

- **Interactive TUI** with per-tool actions (install, update, remove, skip)
- **Multi-format version detection** for npm, uv, and native tools
- **Latest version fetching** from npm, PyPI, and GitHub releases
- **Cross-platform support** for macOS/Linux (`.sh`) and Windows (`.bat`)
- **Cross-platform deployment script** for easy installation
- **Non-interactive mode** with `--yes`/`-y` flag for automation
- **Auto-install script** for processing multiple conda environments

## Supported Tools

| Tool | Package | Manager | Installation Method |
|------|---------|----------|-------------------|
| [MoAI Agent Development Kit](https://github.com/modu-ai/moai-adk) | `moai-adk` | native | [Official installer](https://modu-ai.github.io/moai-adk/install.sh) |
| [Claude Code CLI](https://github.com/anthropics/claude-code) | `claude-code` | native | [Official installer](https://claude.ai/install.sh) |
| [OpenAI Codex CLI](https://github.com/openai/codex) | `@openai/codex` | npm | `npm install -g @openai/codex` |
| [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) | `@google/gemini-cli` | npm | `npm install -g @google/gemini-cli` |
| [Google Jules CLI](https://jules.google) | `@google/jules` | npm | `npm install -g @google/jules` |
| [OpenCode AI CLI](https://github.com/opencode-ai/opencode) | `opencode-ai` | native | [Official installer](https://opencode.ai/install) |
| [Mistral Vibe CLI](https://github.com/mistralai/mistral-vibe) | `mistral-vibe` | uv | `uv tool install mistral-vibe` |

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

### v1.4.0 - January 31, 2026

- **Non-Interactive Mode**: Added `--yes`/`-y` flag for automatic installation with default selections
- **Native Installers**: MoAI-ADK and OpenCode AI now use official install scripts
- **Node.js/npm Requirements**: Now requires Node.js 22.9.0+ (includes npm 10+ for modern tool compatibility)
- **Fixed uv Updates**: uv tools now properly update to latest versions (removed `--force` for initial installs)
- **Version Verification**: Improved npm/Node.js version detection in conda environments

### v1.3.0 - January 28, 2026

- **Auto Install Script**: Added `auto_install_coding_tools` script that automatically processes all conda environments
- **Enhanced Deployment**: The `setup.sh` script now installs both `install_coding_tools.sh` and `auto_install_coding_tools`

### v1.2.0 - January 20, 2026

- Initial release with interactive TUI
- Support for 7 AI coding CLI tools
- Cross-platform support (macOS/Linux/Windows)
