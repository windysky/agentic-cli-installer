# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-04-23
- **Last coding CLI used (informational):** Claude Code (Opus 4.7)

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.11.0 remove MoAI-ADK bootstrapper same-origin checksum | Completed | `fetch_moai_checksum` / `MOAI_CHECKSUM_URL` removed from `.sh` and `.bat`. Upstream never published `install.sh.sha256`, so the fetch always failed; the check was also same-origin security theater. MoAI-ADK's own downstream binary tarball verification is preserved. |
| v1.10.0 Windows Claude Code install fix | Completed | Third-party `install.cmd` is now executed in an isolated child `cmd.exe` via `:run_cmd_script_isolated` so it cannot corrupt the parent session; npm global list check syntax fixed. |
| v1.9.13 Claude checksum warning removal | Completed | `fetch_claude_checksum` and related Claude-checksum logic removed from both installers; Anthropic does not publish checksums for `install.sh` / `install.cmd`. |
| v1.9.13 shell config detection fix | Completed | Shell config detection now writes to the correct file. |
| v1.9.12 clear command fix | Completed | `clear` falls back to ANSI escape sequence when terminfo is inaccessible. |
| v1.9.11 auto PATH + aliases | Completed | `setup.sh` auto-configures `~/.local/bin` in PATH and adds CLI convenience aliases. |
| v1.9.10 tput fix | Completed | `setup.sh` gracefully degrades to no-color on terminals with missing terminfo. |
| v1.9.9 conda detection fix | Completed | `resolve_conda_cmd()` finds the conda binary when the shell function is unavailable in script context. |

## 3. Execution Plan Status

| Phase / Milestone | Status | Last updated | Note |
|---|---|---|---|
| Remove MoAI same-origin checksum fetch (`.sh` + `.bat`) | Completed | 2026-04-23 | Option A applied; `fetch_moai_checksum`, `MOAI_CHECKSUM_URL`, `MOAI_SHA256` removed. |
| Version bump v1.10.0 -> v1.11.0 | Completed | 2026-04-23 | All 4 script files + README + CHANGELOG. |
| Documentation updates | Completed | 2026-04-23 | README.md v1.11.0 entry + CHANGELOG.md v1.11.0 entry added. |
| `PROJECT_HANDOFF.md` reconciled to current reality | Completed | 2026-04-23 | Previously stale at v1.9.11 (2026-03-14); refreshed to reflect v1.9.12, v1.9.13, v1.10.0, v1.11.0. |
| `PROJECT_LOG.md` session appended | Completed | 2026-04-23 | Session 2026-04-23 entry records v1.11.0 removal; prior gap (v1.9.12 / v1.9.13 / v1.10.0 sessions missing from log) noted as reconciliation deficit. |
| Upcoming work | None | 2026-04-23 | — |

## 4. Outstanding Work

- **No active items.**
  - Status: Completed
  - Last updated: 2026-04-23
  - Reference: `PROJECT_LOG.md` Session 2026-04-23

- **Reconciliation deficit (informational):**
  - `PROJECT_LOG.md` has no session entries for commits `fddafd1` (v1.9.12), `921e686` / `7ed0553` (v1.9.13 ×2), `35d51c5` (v1.10.0), or the `1091497` chore commit. Those ship-ready changes landed in the repo but were never retro-logged. Not blocking; the commit messages themselves carry the context.
  - Action if needed later: append reconstructed entries, each marked with the source commit SHA.

## 5. Risks, Open Questions, and Assumptions

| Item | Status | Date opened | Resolution / assumption in effect |
|---|---|---|---|
| moai-adk settings.json corruption when jq unavailable (upstream #381) | Mitigated | 2026-02-15 | Installer auto-installs `jq` before moai-adk flow when needed. |
| moai output-style localization issue (upstream #382) | Open | 2026-02-15 | Upstream issue remains open; installer-side default behavior unchanged. |
| MoAI bootstrapper same-origin checksum noise | Resolved | 2026-04-23 | v1.11.0 removes the fetch entirely; TLS to GitHub + MoAI-ADK's downstream binary SHA-256 verification cover the real integrity needs. |
| Claude installer checksum noise | Resolved | 2026-03-14 | v1.9.13 removed `fetch_claude_checksum` (Anthropic does not publish checksums). |
| Windows Claude Code install session corruption | Resolved | 2026-03-22 | v1.10.0 runs `install.cmd` via isolated child `cmd.exe`. |
| Conda shell function not available in script context | Resolved | 2026-03-11 | v1.9.9 adds `resolve_conda_cmd()` with `CONDA_EXE` and path fallbacks. |
| tput crash on missing terminfo | Resolved | 2026-03-14 | v1.9.10 adds `tput colors` probe to guard in `setup.sh`. |
| `clear` command crash on missing terminfo database | Resolved | 2026-03-14 | v1.9.12 adds ANSI escape fallback. |

## 6. Verification Status

### Verified

| Item | Verification method | Result | Date/time verified |
|---|---|---|---|
| Script syntax (.sh) | `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` | (pending, see below) | 2026-04-23 |
| No remaining `MOAI_CHECKSUM_URL` / `fetch_moai_checksum` / `MOAI_SHA256` | `grep -rn` across all scripts | Pass (zero matches) | 2026-04-23 |
| `.bat` line endings preserved | `file install_coding_tools.bat setup.bat` shows CRLF / CR terminators | Pass | 2026-04-23 |
| Version consistency | `grep` across all 4 script files for v1.11.0 banner/header strings | Pass | 2026-04-23 |
| CHANGELOG ordering | `grep '^## \[' CHANGELOG.md` (descending, no duplicates) | Pass | 2026-04-23 |

### Not yet verified

- Live runtime test of `install_coding_tools.sh` end-to-end MoAI-ADK install (confirm the two warning lines are gone).
  - Why not yet verified: fix committed from a WSL session without a pristine target env; awaiting user re-run.
- Windows runtime execution of v1.11.0 installer flow on a real Windows host.
  - Why not yet verified: current session executed in Linux/WSL.

## 7. Restart Instructions

- **Exact starting point:**
  1. `git pull origin master` to get the latest v1.11.0 commit.
  2. Quick sanity checks: `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` and `./install_coding_tools.sh --help`.
  3. Grep for regressions: `grep -rn 'MOAI_CHECKSUM_URL\|fetch_moai_checksum\|MOAI_SHA256' install_coding_tools.*` should return zero matches.
- **Recommended next actions:**
  1. Re-run `./install_coding_tools.sh` on a Linux/WSL host and confirm the two `[WARNING]` lines before the MoAI-ADK banner are gone.
  2. Run `install_coding_tools.bat` on a Windows host to confirm the same.
  3. Monitor upstream moai-adk #382 (output-style localization) for closure.
- **Last updated:** 2026-04-23
