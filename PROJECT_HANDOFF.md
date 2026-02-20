# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-02-19
- **Last coding CLI used (informational):** OpenCode

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.9.3 maintenance release | Completed | oh-my-opencode npm package update on upgrade, required provider flags, upstream bug workaround. Completed in Session 2026-02-19. |
| v1.9.2 maintenance release | Completed | oh-my-opencode installation bug fixes, auto-detect providers, config preservation. Completed in Session 2026-02-19. |
| v1.9.1 micro release | Completed | oh-my-opencode installed version precedence fixed. Completed in Session 2026-02-18. |

## 3. Execution Plan Status

| Phase / Milestone | Status | Last updated | Note |
|---|---|---|---|
| Phase 1: Fix oh-my-opencode return codes | Completed | 2026-02-19 | Added proper return 1 on failure in both .sh and .bat |
| Phase 2: Auto-detect providers | Completed | 2026-02-19 | Removed hardcoded --XXX=no flags, oh-my-opencode auto-detects installed tools |
| Phase 3: Preserve config on update | Completed | 2026-02-19 | Existing oh-my-opencode.json preserved during reinstall |
| Phase 4: npm package update on upgrade | Completed | 2026-02-19 | Added `npm install -g oh-my-opencode@latest` before plugin reinstall |
| Phase 5: Release and documentation sync | Completed | 2026-02-19 | v1.9.3 release ready for commit |

## 4. Outstanding Work

- **No active items.**
  - Status: Completed
  - Last updated: 2026-02-19
  - Reference: `PROJECT_LOG.md` Session 2026-02-19

## 5. Risks, Open Questions, and Assumptions

| Item | Status | Date opened | Resolution / assumption in effect |
|---|---|---|---|
| moai-adk settings.json corruption when jq unavailable (upstream #381) | Mitigated | 2026-02-15 | Installer auto-installs `jq` before moai-adk flow when needed. |
| moai output-style localization issue (upstream #382) | Open | 2026-02-15 | Upstream issue remains open; installer-side default behavior unchanged. |
| oh-my-opencode installed-version mismatch in menu | Resolved | 2026-02-18 | v1.9.1 uses npm global installed version first, then cache/spec fallbacks. |
| oh-my-opencode installation reporting fake success | Resolved | 2026-02-19 | v1.9.2 adds proper return codes on failure. |
| oh-my-opencode version not updating on upgrade | Resolved | 2026-02-19 | v1.9.3 adds npm package update before plugin reinstall. |

## 6. Verification Status

### Verified

| Item | Verification method | Result | Date/time verified |
|---|---|---|---|
| v1.9.3 npm package update | `npm list -g oh-my-opencode` | Pass (3.7.4 installed) | 2026-02-19 |
| v1.9.3 return codes in .sh | `grep -B2 "return 1" install_coding_tools.sh` | Pass (warnings followed by return 1) | 2026-02-19 |
| v1.9.3 exit codes in .bat | `grep -B1 "exit /b 1" install_coding_tools.bat` | Pass (warnings followed by exit /b 1) | 2026-02-19 |
| Script syntax | `bash -n install_coding_tools.sh` | Pass | 2026-02-19 |
| Batch line endings | `file install_coding_tools.bat` | CRLF confirmed | 2026-02-19 |
| Version consistency | `grep -rn "v1.9.3"` | Pass (all files updated) | 2026-02-19 |

### Not yet verified

- Windows runtime execution of v1.9.3 installer flow in a live Windows shell.
  - Why not yet verified: current session executed in Linux/WSL environment.

## 7. Restart Instructions

- **Exact starting point:**
  1. Check uncommitted changes with `git status`.
  2. Run quick sanity checks: `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` and `./install_coding_tools.sh --help`.
  3. Commit v1.9.3 changes when ready.
- **Recommended next actions:**
  1. Test oh-my-opencode installation with the new upgrade flow.
  2. Perform Windows live validation for v1.9.3 installer flow.
  3. Monitor upstream issues #381 and #382 for closure and remove mitigations only when safe.
- **Last updated:** 2026-02-19
