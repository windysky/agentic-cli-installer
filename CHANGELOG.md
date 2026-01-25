# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
