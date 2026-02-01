# Agentic CLI Installer v1.4.0

**Last Modified:** January 31, 2026

An interactive installer that manages multiple AI coding CLI tools from one place. It detects installed versions, fetches latest versions, and lets you install, update, or remove tools in a single run.

## Features

- Interactive TUI with per-tool actions (install, update, remove, skip)
- Detects installed versions for npm, uv, and native tools
- Fetches latest versions from npm, PyPI, and GitHub releases
- Supports both macOS/Linux (`.sh`) and Windows (`.bat`)
- **Cross-platform deployment script for easy installation**

## Supported Tools

- [MoAI Agent Development Kit](https://github.com/modu-ai/moai-adk) (`moai-adk`, native) - [Official installer](https://modu-ai.github.io/moai-adk/install.sh)
- [Claude Code CLI](https://github.com/anthropics/claude-code) (`claude-code`, native) - [Official installer](https://claude.ai/install.sh)
- [OpenAI Codex CLI](https://github.com/openai/codex) (`@openai/codex`, npm)
- [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) (`@google/gemini-cli`, npm)
- [Google Jules CLI](https://jules.google) (`@google/jules`, npm)
- [OpenCode AI CLI](https://github.com/opencode-ai/opencode) (`opencode-ai`, native) - [Official installer](https://opencode.ai/install)
- [Mistral Vibe CLI](https://github.com/mistralai/mistral-vibe) (`mistral-vibe`, uv)

## Requirements

- `curl`
- For uv-managed tools: `uv` (mistral-vibe)
- For npm-managed tools: `node` >= 22.9.0 (includes npm >= 10.0.0)
- For native tools: No additional package manager required
  - If in conda environment, Node.js will be automatically installed if needed

## Quick Start (Deployment Script)

The recommended way to install the Agentic CLI Installer is using the deployment script:

### What's New in v1.4.0

- **Non-Interactive Mode**: Added `--yes`/`-y` flag for automatic installation with default selections
- **Native Installers**: MoAI-ADK and OpenCode AI now use official install scripts (curl)
- **Node.js/npm Requirements**: Now requires Node.js 22.9.0+ (includes npm 10+ for modern tool compatibility)
- **Fixed uv Updates**: uv tools now properly update to latest versions (removed `--force` for initial installs)
- **Version Verification**: Improved npm/Node.js version detection in conda environments

### What's New in v1.3.0

- **Auto Install Script**: Added `auto_install_coding_tools` script that automatically processes all conda environments
- **Enhanced Deployment**: The `setup.sh` script now installs both `install_coding_tools.sh` and `auto_install_coding_tools`

```bash
# Clone or download the repository
cd agentic-cli-installer

# Run the deployment script (recommended)
chmod +x setup.sh
./setup.sh --configure-path

# Now you can run the installer from anywhere
install_coding_tools.sh
```

### Deployment Script Features

The `setup.sh` script provides:
- **Automatic platform detection** - WSL, Linux, macOS
- **WSL dual-filesystem support** - Installs both Unix and Windows scripts
- **Backup of existing files** - Preserves your current installations
- **Executable permissions** - Automatically sets chmod +x
- **PATH configuration** - Optional helper to add `~/.local/bin` to your PATH

### Deployment Script Options

```bash
./setup.sh                           # Interactive installation
./setup.sh --configure-path          # Install and configure PATH
./setup.sh --force                   # Skip confirmation prompts
./setup.sh --force --configure-path  # Non-interactive with PATH config
./setup.sh --help                    # Show help message
```

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

## Auto Install Script

The `auto_install_coding_tools` script automates the installation process across multiple conda environments:

```bash
# Run the auto installer (processes all conda environments except base)
auto_install_coding_tools
```

### Features

- **Multi-environment support**: Automatically processes all conda environments (excluding `base`)
- **Seamless integration**: Uses the same installation logic as `install_coding_tools.sh`
- **Conda environment detection**: Finds conda installations in standard locations
- **Safety first**: Skips the `base` environment to avoid conflicts

### Requirements

- Conda or Miniconda installed
- Multiple conda environments set up
- Same requirements as `install_coding_tools.sh` (curl, uv, npm)

## Manual Installation

If you prefer not to use the deployment script:

macOS/Linux:

```bash
chmod +x install_coding_tools.sh
# Interactive mode
./install_coding_tools.sh

# Non-interactive mode (auto-proceed with defaults)
./install_coding_tools.sh --yes
# or
./install_coding_tools.sh -y
```

Windows (PowerShell):

```powershell
# Interactive mode
.\install_coding_tools.bat

# Non-interactive mode
.\install_coding_tools.bat --yes
# or
.\install_coding_tools.bat -y
```

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
