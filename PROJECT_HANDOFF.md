# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-06-27 21:06 CDT
- **Last coding CLI used (informational):** Claude Code (Opus 4.7)
- **Cross-project wiki (distilled this session):** `~/PROJECTS/wiki/concept/wsl-cmdexe-unc-cwd-testing.md` (cmd.exe UNC-cwd → stale PATH copy when testing a .bat from WSL) and `~/PROJECTS/wiki/concept/cli-flag-verification-install-guide.md` (verify CLI flags against the install guide, not package.json).

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.12.0 replace retired Gemini CLI with Antigravity CLI | Completed | Gemini CLI (`@google/gemini-cli`, npm, binary `gemini`) removed from both installers (tool index 4). Replaced in-place with Antigravity CLI (`antigravity`, native, binary `agy`) installed via Google's official bootstrapper (`https://antigravity.google/cli/install.sh` Unix / `install.cmd` Windows). New `run_antigravity_installer()` (.sh) and `:install_tool_antigravity` + `:download_antigravity_installer` (.bat) mirror the Claude Code native pattern. oh-my-opencode `--gemini` auto-detect **and** static `--gemini=no` both purged — `--gemini=no` is the documented default (Gemini CLI retired), so omitting it is behaviorally safe. (An earlier npm-only audit wrongly claimed the flag never existed; the install guide documents it.) |
| v1.12.0 multi-expert review + high-confidence fixes | Completed | 4-agent review (docs-verifier, devops/parity, security, evaluator). Applied: **P0** `.bat` MoAI Claude-prereq `/dev/null`→`nul` (was a silent no-op on Windows); **P1** `.sh` banner v1.11.0→v1.12.0; **P1** `.bat` rm duplicate `exit /b 0`; **P1** `.bat` rm `npm install -g oh-my-opencode@latest` (officially prohibited); **P1** `.bat` Antigravity remove post-del verify; **P1** `.sh` Antigravity install post-install verify; **P2** deleted dead `.bat` `*_version2` funcs + dead `.sh` `validate_removal()`. Also corrected the `--gemini` "never existed" rationale across all docs (the flag IS documented). Deferred items tracked in §4. |
| v1.11.0 remove MoAI-ADK bootstrapper same-origin checksum | Completed | `fetch_moai_checksum` / `MOAI_CHECKSUM_URL` removed from `.sh` and `.bat`. MoAI-ADK's own downstream binary tarball verification is preserved. |
| v1.10.0 Windows Claude Code install fix | Completed | Third-party `install.cmd` executed in isolated child `cmd.exe` via `:run_cmd_script_isolated`; Antigravity's `install.cmd` now reuses this same isolation. |
| v1.9.13 Claude checksum warning removal | Completed | `fetch_claude_checksum` removed from both installers. |
| v1.9.13 shell config detection fix | Completed | Shell config detection writes to the correct file. |
| v1.9.12 clear command fix | Completed | `clear` falls back to ANSI escape sequence when terminfo is inaccessible. |
| v1.9.11 auto PATH + aliases | Completed | `setup.sh` auto-configures `~/.local/bin` in PATH and adds CLI convenience aliases. |

## 3. Execution Plan Status

| Phase / Milestone | Status | Last updated | Note |
|---|---|---|---|
| Add Antigravity CLI native installer path (`.sh`) | Completed | 2026-06-27 | `ANTIGRAVITY_INSTALL_URL`, `run_antigravity_installer()`, branches in `get_installed_native_version` / `install_tool` / `remove_tool`. |
| Add Antigravity CLI native installer path (`.bat`) | Completed | 2026-06-27 | `ANTIGRAVITY_INSTALL_URL`, `:install_tool_antigravity`, `:download_antigravity_installer`, `:install_tool_native` dispatch, version + remove branches. Byte-safe Python patch preserving `\r\r\n`. |
| Remove Gemini CLI entry + oh-my-opencode `--gemini` auto-detect + static `--gemini=no` | Completed | 2026-06-27 | Tool index 4 replaced in-place; dynamic gemini detection purged; static `--gemini=no` also purged (it is the documented default; Gemini CLI retired). |
| Version bump v1.11.0 -> v1.12.0 | Completed | 2026-06-27 | All 4 script files + README + CHANGELOG. |
| Documentation updates | Completed | 2026-06-27 | README tools table (Gemini row -> Antigravity) + v1.12.0 changelog; CHANGELOG `## [1.12.0]` entry. |
| `PROJECT_HANDOFF.md` + `PROJECT_LOG.md` updated | Completed | 2026-06-27 | This refresh; log session 2026-06-27 prepended. |
| Upcoming work | None | 2026-06-27 | — |

## 4. Outstanding Work

- **No active items.**
  - Status: Completed
  - Last updated: 2026-06-27
  - Reference: `PROJECT_LOG.md` Session 2026-06-27

- **Reconciliation deficit (informational, mostly resolved this session):**
  - `PROJECT_LOG.md` was upgraded to the bounded active+archive layout this session (2026-06-27): 8 newest sessions kept in the active file; 9 older sessions (≤ 2026-02-18) moved verbatim to `logs/PROJECT_LOG_2026-H1.md`. The active file now has an Archives pointer + Session Index.
  - Still outstanding (minor): `PROJECT_LOG.md` lacks session entries for commits `fddafd1` (v1.9.12), `921e686` / `7ed0553` (v1.9.13 ×2), `35d51c5` (v1.10.0), and the `1091497` chore commit. Not blocking; commit messages carry the context.

- **oh-my-opencode provider-flag set is incomplete (follow-up, low priority):**
  - The multi-expert review (2026-06-27) cross-checked the official oh-my-openagent install guide and confirmed the provider flags ARE valid: `--claude`, `--openai`, `--gemini`, `--copilot`, `--opencode-zen`, `--zai-coding-plan`, plus three the installer does NOT yet emit: `--opencode-go`, `--kimi-for-coding`, `--vercel-ai-gateway`. All default to `no`, so omitting them is behaviorally safe; adding them is optional completeness. No urgency.

- **Deferred multi-expert-review findings (not applied; see PROJECT_LOG 2026-06-27 for detail):**
  - **Security — Windows insecure TLS fallback (P1, needs product call):** `.bat` download paths fall back to `curl -k` (cert-checking disabled) + `--ssl-no-revoke` on first failure (`install_coding_tools.bat` Claude/MoAI/Antigravity download sites). Real MITM risk; but removing may break corporate-proxy users. Options: drop `-k` and fail loudly, or gate behind explicit consent. `.sh` has no such fallback.
  - **Security — Authenticode check is post-execution and non-blocking (P1):** `:best_effort_verify_claude_signature` runs after `install.cmd` executes and only warns. If intended as a gate, must run before execution and `exit /b 1` on failure.
  - **Parity — `.sh` 4-state vs `.bat` 3-state action cycle (P1, UX):** `.sh` distinguishes install/upgrade/remove; `.bat` folds upgrade into install. Windows users can't visually distinguish new-install from update.
  - **Feature gap — Claude Code sandbox/Playwright setup missing on Windows (P1):** `.sh` runs `setup_claude_sandbox` (seccomp filter, Playwright CLI+MCP) after Claude install; `.bat` only does Authenticode. Large port; schedule separately.
  - **Assumption — `agy --version` flag unverified (P2):** both scripts hardcode `--version` with no `version` fallback (MoAI has a fallback). Confirm against the live binary; adjust `VERARG_4`/`.sh` branch if different.
  - **Parity — `setup.bat` thin vs `setup.sh` full (P2):** `setup.bat` only copies the script; `setup.sh` also configures PATH + aliases + WSL dual-filesystem deploy. Acceptable platform divergence; document or close.
  - **Craft — `\r\r\n` whole-file normalization (P2):** `.bat` mixes `\r\r\n` (legacy) and `\r\n` (v1.10.0 region). Tolerated by cmd.exe but fragile. Dedicated one-off commit to normalize to `\r\n`.
  - **Docs — Codex/OpenCode use npm fallback (P2):** both tools' official primary method is now a curl/PowerShell bootstrapper; the installer uses npm (a documented fallback). Works; not "recommended." Optional enhancement.

## 5. Risks, Open Questions, and Assumptions

| Item | Status | Date opened | Resolution / assumption in effect |
|---|---|---|---|
| Antigravity CLI `agy --version` flag | Assumed-OK | 2026-06-27 | Used `--version` for native version detection (consistent with claude/moai). If `agy` uses a different flag, adjust `VERARG_4` (.bat) / the `agy --version` call (.sh). Awaiting live runtime confirmation. |
| Antigravity Windows binary path/extension | Assumed-OK | 2026-06-27 | Removal checks both `%USERPROFILE%\.local\bin\agy.exe` and `…\agy`. Install delegates pathing to Google's `install.cmd`. |
| oh-my-opencode `--gemini` requirement | Resolved | 2026-06-27 | Static `--gemini=no` **purged**. The `--gemini=yes\|no` flag IS documented in oh-my-opencode's official install guide (configures Gemini model integration); `--gemini=no` is the default, so omitting it is behaviorally safe, and with Gemini CLI retired `=no` is the desired value. The sibling provider flags (`--claude`, `--openai`, `--copilot`, `--opencode-zen`, `--zai-coding-plan`) are also documented and remain in `build_ohmy_flags_*`. (An earlier npm-only audit wrongly claimed `--gemini` never existed; corrected after the multi-expert review cross-checked the official install guide.) |
| moai-adk settings.json corruption when jq unavailable (upstream #381) | Mitigated | 2026-02-15 | Installer auto-installs `jq` before moai-adk flow when needed. |
| moai output-style localization issue (upstream #382) | Open | 2026-02-15 | Upstream issue remains open; installer-side default behavior unchanged. |
| MoAI bootstrapper same-origin checksum noise | Resolved | 2026-04-23 | v1.11.0 removes the fetch entirely. |

## 6. Verification Status

### Verified

| Item | Verification method | Result | Date/time verified |
|---|---|---|---|
| Script syntax (.sh) | `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` | Pass (all three) | 2026-06-27 |
| `.bat` line endings preserved | `file install_coding_tools.bat setup.bat` (still CRLF/CR) | Pass | 2026-06-27 |
| Version consistency | grep `v1.12.0` / `1.12.0` across all 4 scripts + README + CHANGELOG | Pass | 2026-06-27 |
| Gemini fully removed from installers | grep `gemini-cli`/`@google/gemini` in `install_coding_tools.{sh,bat}` | Pass (zero matches) | 2026-06-27 |
| Antigravity wired in both installers | grep `antigravity` / `agy` / `ANTIGRAVITY_INSTALL_URL` | Pass (URL const, TOOL_4, version detect, install, download, remove) | 2026-06-27 |
| `TOOLS_COUNT` / TOOLS array still 7 entries | grep TOOL_1..7 (.bat) and TOOLS array (.sh) | Pass | 2026-06-27 |
| CHANGELOG ordering | `grep '^## \[' CHANGELOG.md` (1.12.0 → 1.11.0 → …, no dupes) | Pass | 2026-06-27 |
| `--help` exits cleanly | `./install_coding_tools.sh --help` | Pass (exit 0) | 2026-06-27 |
| `.bat` review-fix label/structure sanity | goto/call label resolution (89/89 resolve); paren balance matches v1.11.0 baseline (1-paren echo-decoration, pre-existing); `setlocal`/`endlocal` balanced | Pass | 2026-06-27 |
| `.bat` runtime parse + startup (NEW) | `cmd.exe /c` against a copy of the working-tree v1.12.0 `.bat` (stdin closed, 25s timeout) | **Pass** — cmd.exe parsed all 2500 lines, ran prefetch + menu render; banner reads `v1.12.0`, slot 4 reads "Antigravity CLI"; exited cleanly on closed stdin. (First attempt ran a stale PATH-deployed v1.11.0 copy — re-run via explicit Windows temp path confirmed the live file.) | 2026-06-27 |

### Not yet verified

- `.bat` **install / update / remove execution flows** for any tool. The runtime smoke test (above) only confirmed parse + prefetch + menu render. The specific review fixes are in code but their triggering paths are unexercised: the MoAI `/dev/null`→`nul` prereq fix only fires on MoAI *install*; the Antigravity install/remove verify only fires on Antigravity *install/remove*; the oh-my-opencode npm-removal only fires on oh-my-opencode *upgrade*.
  - Why not yet verified: user declined a live install test (mutates the Windows env); awaiting user re-run on a Windows host.
- Live runtime install of Antigravity CLI via `install_coding_tools.sh` (confirm `agy` lands in `~/.local/bin`, version detects, menu shows it in slot 4).
  - Why not yet verified: installer is interactive + system-mutating; awaiting user re-run on a target host.
- Live runtime install via `install_coding_tools.bat` on a real Windows host (confirm `install.cmd` isolation + `agy.exe`/`agy` placement + `--ssl-no-revoke` path).
  - Why not yet verified: user declined live test; awaiting re-run on a Windows host.
- `agy --version` actual output format/flag (assumed `--version`). Smoke test showed "Unknown" because Antigravity isn't installed here — doesn't validate the flag.

## 7. Restart Instructions

- **Exact starting point:**
  1. `git pull origin master` (or work on the current uncommitted v1.12.0 changes — see `git status`).
  2. Sanity: `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` and `./install_coding_tools.sh --help`.
  3. Regression grep: `grep -rn 'gemini-cli\|@google/gemini' install_coding_tools.*` should return zero; `grep -n antigravity install_coding_tools.*` should show the new wiring.
- **Recommended next actions:**
  1. Re-run `./install_coding_tools.sh` on a Linux/WSL host; select Antigravity CLI (slot 4); confirm `agy` installs to `~/.local/bin` and `agy --version` reports a version. Confirm Gemini no longer appears in the menu.
  2. Run `install_coding_tools.bat` on a Windows host to confirm the same.
  3. If `agy` uses a version flag other than `--version`, update `VERARG_4` (.bat) and the `.sh` `agy --version` call.
  4. Monitor upstream moai-adk #382 (output-style localization) for closure.
- **Last updated:** 2026-06-27 21:06 CDT
