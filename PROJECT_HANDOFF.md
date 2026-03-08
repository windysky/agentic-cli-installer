# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-03-08 14:00 CDT
- **Last coding CLI used (informational):** Claude Code

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.9.7 tool reorder release | Completed | Claude Code CLI now listed before MoAI-ADK; MoAI-ADK installation requires Claude Code CLI. Completed in Session 2026-03-08 14:00 CDT. |
| v1.9.6 bug fix release | Completed | Fixed Windows action summary display, curl SSL fallback, npm check error suppression. Committed and pushed as `1566742`. |
| v1.9.5 maintenance release | Completed | Version sync, error handling fixes, Windows gh CLI parity, CHANGELOG cleanup. |

## 3. Execution Plan Status

| Phase / Milestone | Status | Last updated | Note |
|---|---|---|---|
| Tool reorder: Claude Code before MoAI-ADK | Completed | 2026-03-08 14:00 CDT | Swapped tool order in both .sh TOOLS array and .bat TOOL definitions |
| MoAI-ADK dependency check | Completed | 2026-03-08 14:00 CDT | Added `claude` CLI availability check before MoAI-ADK install in both .sh and .bat |
| Version bump to v1.9.7 | Completed | 2026-03-08 14:00 CDT | All 6 files updated |
| Documentation updates | Completed | 2026-03-08 14:00 CDT | README.md and CHANGELOG.md updated with v1.9.7 entries |

## 4. Outstanding Work

- **No active items.**
  - Status: Completed
  - Last updated: 2026-03-08 14:00 CDT
  - Reference: `PROJECT_LOG.md` Session 2026-03-08 14:00 CDT

## 5. Risks, Open Questions, and Assumptions

| Item | Status | Date opened | Resolution / assumption in effect |
|---|---|---|---|
| moai-adk settings.json corruption when jq unavailable (upstream #381) | Mitigated | 2026-02-15 | Installer auto-installs `jq` before moai-adk flow when needed. |
| moai output-style localization issue (upstream #382) | Open | 2026-02-15 | Upstream issue remains open; installer-side default behavior unchanged. |
| Windows action summary showing "2nst" instead of versions | Resolved | 2026-03-08 | v1.9.6 removes broken `%%inst%%` double-indirection in `for /L %%i` loops. |
| Windows curl SSL certificate failure for MoAI-ADK download | Resolved | 2026-03-08 | v1.9.6 adds `--ssl-no-revoke` and `-k` fallback. |
| Windows "filename, directory name" error during Claude install | Resolved | 2026-03-08 | v1.9.6 adds `2>nul` stderr suppression in `check_npm_claude_code`. |
| MoAI-ADK requires Claude Code CLI | Resolved | 2026-03-08 | v1.9.7 reorders tools and adds dependency check. |

## 6. Verification Status

### Verified

| Item | Verification method | Result | Date/time verified |
|---|---|---|---|
| Script syntax (.sh) | `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` | Pass | 2026-03-08 14:00 CDT |
| Batch line endings | `file install_coding_tools.bat setup.bat` | CRLF confirmed | 2026-03-08 14:00 CDT |
| Version consistency | `grep` across all 6 files for v1.9.7 | Pass (all files show v1.9.7) | 2026-03-08 14:00 CDT |
| CHANGELOG ordering | `grep '^## \[' CHANGELOG.md` | Pass (no duplicates, descending order) | 2026-03-08 14:00 CDT |
| Tool order | Claude Code listed before MoAI-ADK in both .sh and .bat | Pass | 2026-03-08 14:00 CDT |
| Dependency check (.sh) | `command -v claude` check before MoAI-ADK install | Pass | 2026-03-08 14:00 CDT |
| Dependency check (.bat) | `where claude` check before MoAI-ADK install | Pass | 2026-03-08 14:00 CDT |

### Not yet verified

- Windows runtime execution of v1.9.7 installer flow in a live Windows shell.
  - Why not yet verified: current session executed in Linux/WSL environment.

## 7. Restart Instructions

- **Exact starting point:**
  1. `git pull origin master` to get latest v1.9.7 commit.
  2. Run quick sanity checks: `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` and `./install_coding_tools.sh --help`.
- **Recommended next actions:**
  1. Perform Windows live validation for v1.9.7 installer flow (tool order and dependency check).
  2. Monitor upstream issues #381 and #382 for closure and remove mitigations only when safe.
- **Last updated:** 2026-03-08 14:00 CDT
