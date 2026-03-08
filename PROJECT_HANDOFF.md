# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-03-08 11:30 CST
- **Last coding CLI used (informational):** Claude Code

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.9.6 bug fix release | Completed | Fixed Windows action summary display, curl SSL fallback, npm check error suppression. Completed in Session 2026-03-08 11:30 CST. |
| v1.9.5 maintenance release | Completed | Version sync, error handling fixes, Windows gh CLI parity, CHANGELOG cleanup. Completed in Session 2026-03-08 00:14 CST. |
| v1.9.4 maintenance release | Completed | ast-grep auto-installation for MoAI-ADK security scanning. Completed in Session 2026-02-26. |

## 3. Execution Plan Status

| Phase / Milestone | Status | Last updated | Note |
|---|---|---|---|
| Fix 1: Action summary %%inst%% collision | Completed | 2026-03-08 11:30 CST | Removed broken double-indirection `%%inst%%` inside `for /L %%i` loops |
| Fix 2: curl SSL fallback | Completed | 2026-03-08 11:30 CST | Added `--ssl-no-revoke` and `-k` fallback for both MoAI and Claude curl downloads |
| Fix 3: npm check error suppression | Completed | 2026-03-08 11:30 CST | Added `2>nul` to `resolve_conda_npm` and wrapped `for /f` block in `check_npm_claude_code` |
| Fix 4: Version bump to v1.9.6 | Completed | 2026-03-08 11:30 CST | All 6 files updated |

## 4. Outstanding Work

- **No active items.**
  - Status: Completed
  - Last updated: 2026-03-08 11:30 CST
  - Reference: `PROJECT_LOG.md` Session 2026-03-08 11:30 CST

## 5. Risks, Open Questions, and Assumptions

| Item | Status | Date opened | Resolution / assumption in effect |
|---|---|---|---|
| moai-adk settings.json corruption when jq unavailable (upstream #381) | Mitigated | 2026-02-15 | Installer auto-installs `jq` before moai-adk flow when needed. |
| moai output-style localization issue (upstream #382) | Open | 2026-02-15 | Upstream issue remains open; installer-side default behavior unchanged. |
| Windows action summary showing "2nst" instead of versions | Resolved | 2026-03-08 | v1.9.6 removes broken `%%inst%%` double-indirection in `for /L %%i` loops. |
| Windows curl SSL certificate failure for MoAI-ADK download | Resolved | 2026-03-08 | v1.9.6 adds `--ssl-no-revoke` and `-k` fallback. |
| Windows "filename, directory name" error during Claude install | Resolved | 2026-03-08 | v1.9.6 adds `2>nul` stderr suppression in `check_npm_claude_code`. |

## 6. Verification Status

### Verified

| Item | Verification method | Result | Date/time verified |
|---|---|---|---|
| Script syntax (.sh) | `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` | Pass | 2026-03-08 11:30 CST |
| Batch line endings | `file install_coding_tools.bat setup.bat` | CRLF confirmed | 2026-03-08 11:30 CST |
| Version consistency | `grep` across all 6 files for v1.9.6 | Pass | 2026-03-08 11:30 CST |
| CHANGELOG ordering | `grep '^## \[' CHANGELOG.md` | Pass (no duplicates, descending order) | 2026-03-08 11:30 CST |
| %%inst%% removal | Confirmed 0 indented `%%inst%%` lines remain in .bat | Pass | 2026-03-08 11:30 CST |
| SSL fallback | `--ssl-no-revoke` present in both curl commands | Pass | 2026-03-08 11:30 CST |
| Error suppression | `2>nul` present in check_npm_claude_code | Pass | 2026-03-08 11:30 CST |

### Not yet verified

- Windows runtime execution of v1.9.6 installer flow in a live Windows shell.
  - Why not yet verified: current session executed in Linux/WSL environment.

## 7. Restart Instructions

- **Exact starting point:**
  1. Check uncommitted changes with `git status`.
  2. Run quick sanity checks: `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` and `./install_coding_tools.sh --help`.
- **Recommended next actions:**
  1. Perform Windows live validation for v1.9.6 installer flow.
  2. Monitor upstream issues #381 and #382 for closure and remove mitigations only when safe.
- **Last updated:** 2026-03-08 11:30 CST
