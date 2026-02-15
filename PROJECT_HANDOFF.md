# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose:** Interactive installer for AI coding CLI tools (install/update/remove)
- **Scripts:** `install_coding_tools.sh` (Unix/WSL), `install_coding_tools.bat` (Windows)
- **Last updated:** 2026-02-15
- **Last coding CLI used:** Claude Code CLI (glm-4.7)

## 2. Current State

| Component | Status | Notes |
|-----------|--------|-------|
| v1.8.1 Release | Completed | jq auto-installation for moai-adk |
| v1.8.0 Release | Completed | Windows oh-my-opencode detection and cache fixes |
| v1.7.21 Release | Completed | GitHub CLI auto-installation for moai-adk |
| v1.7.20 Release | Completed | Line ending normalization |
| v1.7.19 Release | Completed | Windows tool index fix |
| v1.7.18 Release | Completed | Node.js floor enforcement |
| v1.7.17 Release | Completed | Playwright MCP auto-installation |
| v1.7.13-1.7.16 | Completed | oh-my-opencode fixes, sandbox dependencies |

## 3. Execution Plan Status

All planned features for v1.7.x, v1.8.0, and v1.8.1 are complete.

| Version | Status | Date |
|---------|--------|------|
| v1.8.1 | Completed | 2026-02-15 |
| v1.8.0 | Completed | 2026-02-14 |
| v1.7.21 | Completed | 2026-02-14 |
| v1.7.20 | Completed | 2026-02-14 |
| v1.7.19 | Completed | 2026-02-11 |
| v1.7.18 | Completed | 2026-02-09 |

## 4. Outstanding Work

No active work items. All requested features have been implemented and pushed to `origin/master`.

## 5. Risks, Open Questions, and Assumptions

| Item | Status | Notes |
|------|--------|-------|
| Claude installer checksum API | Mitigated | Falls back to hardcoded checksum when API returns 403 |
| oh-my-opencode upstream bug | Mitigated | Skips install when already registered in opencode.json |
| Mixed line endings in .bat | Resolved | Normalized to CRLF in v1.7.20 |
| Windows oh-my-opencode detection | Resolved | Added fallback text search in v1.8.0 |
| Windows npm version comparison | Resolved | Fixed delayed expansion in v1.8.0 |
| Windows npm cache invalidation | Resolved | Clear cache after removal in v1.8.0 |
| moai-adk settings.json corruption | Mitigated | jq auto-installation added in v1.8.1 |

## 6. Verification Status

| Feature | Verification | Result | Date |
|---------|-------------|--------|------|
| v1.8.1 jq auto-installation | Code review | install_jq() function added | 2026-02-15 |
| v1.8.1 version consistency | grep search | All files updated to v1.8.1 | 2026-02-15 |
| Windows oh-my-opencode detection | Code review | Fallback findstr added | 2026-02-14 |
| Windows npm comparison | Code review | Delayed expansion fixed | 2026-02-14 |
| Windows cache invalidation | Code review | Cache cleared after removal | 2026-02-14 |
| GitHub CLI auto-install | Code review | Implemented correctly | 2026-02-14 |
| Line ending normalization | `file` command | CRLF only | 2026-02-14 |
| Git push | `git status` | Synced with origin | 2026-02-15 |

## 7. Restart Instructions

**Starting Point:**
- Repository is at v1.8.1, all changes committed and pushed
- No pending work items

**Recommended Next Actions:**
1. Test the installer with moai-adk to verify jq is auto-installed when missing
2. Test on Windows to verify jq installation works via conda-forge
3. Verify moai-adk installer no longer corrupts settings.json when jq is present

**External Issues Reported:**
- moai-adk issue #381: settings.json corruption when jq unavailable (upstream bug)
- moai-adk issue #382: MoAI output style template localization bug (upstream bug)

## How To Deploy Locally

- Unix/WSL: `./setup.sh --force --configure-path`
- Windows: run `setup.bat` to copy `install_coding_tools.bat` into `%USERPROFILE%\.local\bin\`

## Quick Verification

- From any directory:
  - `~/.local/bin/auto_install_coding_tools` should find and execute `~/.local/bin/install_coding_tools.sh`
- On Windows:
  - `install_coding_tools.bat` menu should include `OpenCode - oh-my-opencode`
