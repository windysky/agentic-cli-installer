# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.3] - 2026-02-06

### Changed

- Windows batch installer no longer checks for system-level npm; npm is conda-only on Windows.
- npm installs/updates now use conda npm only; npm updates use `npm install -g npm@latest` within the active conda environment.
- System npm check remains in the shell installer for macOS/Linux/WSL.

### Fixed

- Windows semver extraction now correctly parses tool output (fixes "The string is X.Y.Z" display).
- Windows conda npm detection now resolves npm from conda env paths (Scripts/Library) and avoids false missing warnings.

---

## [1.7.0] - 2026-02-05

### Security

#### Medium - Download Security Documentation (SHELL-002, BAT-001)

- Added comments documenting installer download sources (Anthropic official, npmjs.com)
- Added Cache-Control headers for more reliable cache-busting in version queries
- Added file size validation for JSON parsing (max 10MB limit to prevent memory exhaustion)

### Fixed

#### Code Quality Improvements

- **SHELL-005**: Fixed regex escaping to properly handle `]` character in package names
- **SHELL-006**: Fixed path comparison logic to use trailing slash for proper prefix matching (avoids false matches like `/home/conda2` matching `/home/conda`)
- **SHELL-007**: Improved version parsing fallback to use word boundaries (`grep -w`) to avoid false positives
- **SHELL-008**: Added error tracking and logging for parallel subprocess failures in version prefetch

- **BAT-002**: Added documentation for encoded PowerShell commands explaining the purpose and encoding necessity
- **BAT-003**: Documented PATH manipulation behavior for conda path filtering
- **BAT-004**: Added JSON file size validation before parsing npm list output

- **SETUP-001**: Added timestamp format validation to ensure proper backup filename generation
- **AUTO-001**: Fixed environment filtering to use exact match for "base" environment (avoids excluding environments like "database" or "my-base-env")
- **FIX-001**: Added JSON file size validation (max 10MB) to prevent memory exhaustion

---

## [1.7.0] - 2026-02-05

### Added

- npm (Node Package Manager) restored to the interactive menu as an update-only tool for visibility and manual updates.

### Changed

- System-level npm check remains mandatory for Claude MCP servers, but npm is also ensured inside the active conda environment when npm-managed tools are selected.

---

## [1.7.1] - 2026-02-05

### Changed

- System npm check is now non-fatal: if installation/update is declined or fails, the installer warns and continues (Claude MCP features may not work until system npm is installed).
- Added `--skip-system-npm` flag for automation scenarios (e.g., `auto_install_coding_tools`) to bypass the system npm check explicitly.

---

## [1.6.0] - 2026-02-05

### Changed

- System npm is now required and checked at startup on macOS/Linux/WSL; if missing or outdated, it is installed/updated via `curl -q https://www.npmjs.com/install.sh | sudo bash`.
- npm is no longer listed as an installable tool inside the interactive menu; only user-facing CLIs remain.

### Fixed

- Simplified npm prerequisite handling to avoid conda-only npm paths and ensure system-level availability.

---

## [1.5.1] - 2026-02-04

### Fixed

- Bash `printf` errors when printing bullet-style lines in the action summary/result sections (format strings starting with `-`)

---

## [1.5.0] - 2026-02-04

### Changed

- MoAI-ADK is now installed/updated via `uv tool` for consistent behavior across shells and to avoid upstream installer ANSI issues
- OpenCode AI CLI is now installed/updated via npm for consistent version detection and updates

### Fixed

- Windows batch parsing robustness when running `call :label` from `for (...) do (...)` blocks
- Duplicate `opencode-ai` native version-detection branch and brittle native parsing for `claude --version`
- `setup.bat` backup timestamps are now locale-independent

---

## [1.4.0] - 2026-01-31

### Added

- Non-interactive mode via `--yes` / `-y`
- Node.js and npm prerequisite checks with conda-friendly install/update behavior

### Changed

- Updated minimum Node.js / npm requirements for modern CLI tooling
- Improved uv tool upgrade behavior (initial install vs forced update)

---

## [1.3.0] - 2026-01-28

### Added

- `auto_install_coding_tools` to process multiple conda environments
- Deployment improvements in `setup.sh` to install helper scripts

---

## [1.2.0] - 2026-01-24

### Security

This release contains important security improvements.

#### High - GitHub API Rate Limit Handling (CRIT-002)

- Implemented exponential backoff (1s, 2s, 4s, 8s, 16s) for GitHub API calls
- Added rate limit tracking with automatic retry (max 5 retries)
- Improved error messages when rate limits are exceeded

#### Medium - Package Name Injection Prevention (MED-001)

- Fixed code injection vulnerability in package name handling
- Package names are now passed as command-line arguments instead of string interpolation
- Eliminated risk of malicious package name exploitation

#### Low - Semantic Version Comparison (LOW-01)

- Implemented proper semantic version comparison (major.minor.patch)
- Added handling for pre-release tags (-alpha, -beta, etc.)
- Fixed incorrect version ordering (e.g., 1.10.0 > 1.2.0)

### Changed

- SHA256 verification for downloaded installers is now **optional** with user confirmation prompt
- If `CLAUDE_INSTALLER_SHA256` is set, the installer will verify against that hash
- If not set, the installer shows the computed hash and prompts for confirmation before execution

### Fixed

- GitHub API rate limit errors causing installation failures
- Code injection vulnerability in package name handling
- Incorrect version comparison leading to wrong update decisions
- Windows batch parsing errors during prefetch/install (avoids `... was unexpected at this time.`)

### References

- Security fixes implemented from [SPEC-SECURITY-001](.moai/specs/SPEC-SECURITY-001/spec.md)
- Based on [OWASP Top 10 2021: A03:2021 - Injection](https://owasp.org/Top10/A03_2021-Injection/)
- Based on [CWE-20: Improper Input Validation](https://cwe.mitre.org/data/definitions/20.html)

---

## [1.1.0] - Previous Release

### Added

- Cross-platform deployment script (setup.sh) with automatic platform detection
- WSL dual-filesystem support
- Backup of existing installations
- Automatic PATH configuration helper
- Native Claude Code installer support (npm method deprecated)

### Features

- Interactive TUI with per-tool actions (install, update, remove, skip)
- Detects installed versions for npm and uv tools
- Fetches latest versions from npm and PyPI
- Supports both macOS/Linux (.sh) and Windows (.bat)

---

## [1.0.0] - Initial Release

### Features

- Initial release of the Agentic CLI Installer
- Support for multiple AI coding CLI tools
- Basic version detection and installation capabilities
