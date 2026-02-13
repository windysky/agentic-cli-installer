# Project Handoff

## Repo

- Name: agentic-cli-installer
- Purpose: Install/update/remove AI coding CLIs via `install_coding_tools.sh` (Unix) or `install_coding_tools.bat` (Windows)

## Recent Changes (2026-02-12)

- Fixed `auto_install_coding_tools` so it reliably locates `install_coding_tools.sh` when invoked from outside the project directory (prefers the script next to `auto_install_coding_tools`, e.g. `~/.local/bin/install_coding_tools.sh`).
- Aligned Windows installer with Unix feature set by adding `oh-my-opencode` as a first-class menu item in `install_coding_tools.bat`.
  - Selecting `oh-my-opencode` auto-selects `opencode-ai` if it is not installed.
  - `oh-my-opencode` no longer auto-installs/removes as a side-effect of installing/removing `opencode-ai`.
  - Addon install skips if it is already registered in `opencode.json`.
- Claude Code native installer now succeeds even when `https://claude.ai/checksums/*` returns 403 (installer-script checksum verification is skipped when checksum is unavailable; Windows does a best-effort Authenticode signature check of `claude.exe`).

## How To Deploy Locally

- Unix/WSL: `./setup.sh --force --configure-path`
- Windows: run `setup.bat` to copy `install_coding_tools.bat` into `%USERPROFILE%\.local\bin\install_coding_tools.bat`

## Quick Verification

- From any directory:
  - `~/.local/bin/auto_install_coding_tools` should find and execute `~/.local/bin/install_coding_tools.sh`.
- On Windows:
  - `install_coding_tools.bat` menu should include `OpenCode - oh-my-opencode`.
