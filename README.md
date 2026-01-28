# Agentic CLI Installer v1.3.0

**Last Modified:** January 28, 2026

An interactive installer that manages multiple AI coding CLI tools from one place. It detects installed versions, fetches latest versions, and lets you install, update, or remove tools in a single run.

## Features

- Interactive TUI with per-tool actions (install, update, remove, skip)
- Detects installed versions for npm and uv tools
- Fetches latest versions from npm and PyPI
- Supports both macOS/Linux (`.sh`) and Windows (`.bat`)
- **Cross-platform deployment script for easy installation**

## Supported Tools

- [MoAI Agent Development Kit](https://github.com/modu-ai/moai-adk) (`moai-adk`, uv)
- [Claude Code CLI](https://github.com/anthropics/claude-code) (`@anthropic-ai/claude-code`, npm)
- [OpenAI Codex CLI](https://github.com/openai/codex) (`@openai/codex`, npm)
- [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) (`@google/gemini-cli`, npm)
- [Google Jules CLI](https://github.com/google-labs-code/jules-awesome-list) (`@google/jules`, npm)
- [OpenCode AI CLI](https://github.com/opencode-ai/opencode) (`opencode-ai`, npm)
- [Mistral Vibe CLI](https://github.com/mistralai/mistral-vibe) (`mistral-vibe`, uv)

## Requirements

- `curl`
- For uv-managed tools: `uv`
- For npm-managed tools: `node` + `npm`

## Quick Start (Deployment Script)

The recommended way to install the Agentic CLI Installer is using the deployment script:

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
./install_coding_tools.sh
```

Windows (PowerShell):

```powershell
.\install_coding_tools.bat
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
