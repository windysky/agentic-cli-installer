# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-03-11
- **Last coding CLI used (informational):** Claude Code

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.9.9 conda detection fix | Completed | Added `resolve_conda_cmd()` to find conda binary when shell function is unavailable in script context. All bare `conda` calls replaced with `$CONDA_CMD`. |
| v1.9.7 tool reorder release | Completed | Claude Code CLI now listed before MoAI-ADK; MoAI-ADK installation requires Claude Code CLI. Completed in Session 2026-03-08 14:00 CDT. |
| v1.9.6 bug fix release | Completed | Fixed Windows action summary display, curl SSL fallback, npm check error suppression. Committed and pushed as `1566742`. |

## 3. Execution Plan Status

| Phase / Milestone | Status | Last updated | Note |
|---|---|---|---|
| Conda detection fix: resolve_conda_cmd() | Completed | 2026-03-11 | Added helper + global CONDA_CMD, replaced all bare conda calls |
| Version bump to v1.9.9 | Completed | 2026-03-11 | All 6 files updated |
| Documentation updates | Completed | 2026-03-11 | README.md and CHANGELOG.md updated with v1.9.9 entries |

## 4. Outstanding Work

- **No active items.**
  - Status: Completed
  - Last updated: 2026-03-11
  - Reference: `PROJECT_LOG.md` Session 2026-03-11

## 5. Risks, Open Questions, and Assumptions

| Item | Status | Date opened | Resolution / assumption in effect |
|---|---|---|---|
| moai-adk settings.json corruption when jq unavailable (upstream #381) | Mitigated | 2026-02-15 | Installer auto-installs `jq` before moai-adk flow when needed. |
| moai output-style localization issue (upstream #382) | Open | 2026-02-15 | Upstream issue remains open; installer-side default behavior unchanged. |
| Conda shell function not available in script context | Resolved | 2026-03-11 | v1.9.9 adds `resolve_conda_cmd()` with CONDA_EXE and path fallbacks. |
| Windows action summary showing "2nst" instead of versions | Resolved | 2026-03-08 | v1.9.6 removes broken `%%inst%%` double-indirection in `for /L %%i` loops. |
| Windows curl SSL certificate failure for MoAI-ADK download | Resolved | 2026-03-08 | v1.9.6 adds `--ssl-no-revoke` and `-k` fallback. |
| Windows "filename, directory name" error during Claude install | Resolved | 2026-03-08 | v1.9.6 adds `2>nul` stderr suppression in `check_npm_claude_code`. |
| MoAI-ADK requires Claude Code CLI | Resolved | 2026-03-08 | v1.9.7 reorders tools and adds dependency check. |

## 6. Verification Status

### Verified

| Item | Verification method | Result | Date/time verified |
|---|---|---|---|
| Script syntax (.sh) | `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` | Pass | 2026-03-11 |
| Batch line endings | `file install_coding_tools.bat setup.bat` | CRLF confirmed | 2026-03-11 |
| Version consistency | `grep` across all 6 files for v1.9.9 | Pass (all files show v1.9.9) | 2026-03-11 |
| CHANGELOG ordering | `grep '^## \[' CHANGELOG.md` | Pass (no duplicates, descending order) | 2026-03-11 |
| No bare conda calls remain | `grep` for bare `conda install/info` outside resolve_conda_cmd | Pass (only get_conda_root fallback) | 2026-03-11 |
| resolve_conda_cmd() function | Code review of 4-tier fallback logic | Pass | 2026-03-11 |

### Not yet verified

- Live runtime test on fresh Ubuntu 24.04 with conda env active (the original bug report scenario).
  - Why not yet verified: awaiting user confirmation on their target machine.
- Windows runtime execution of v1.9.9 installer flow.
  - Why not yet verified: current session executed in Linux/WSL environment.

## 7. Restart Instructions

- **Exact starting point:**
  1. `git pull origin master` to get latest v1.9.9 commit.
  2. Run quick sanity checks: `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` and `./install_coding_tools.sh --help`.
- **Recommended next actions:**
  1. Test on fresh Ubuntu 24.04 with active conda env to verify the conda detection fix.
  2. Monitor upstream issues #381 and #382 for closure and remove mitigations only when safe.
- **Last updated:** 2026-03-11
