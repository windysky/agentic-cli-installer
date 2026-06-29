# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-06-29
- **Last coding CLI used (informational):** Claude Code (Opus 4.8)
- **Cross-project wiki (consulted this session):** `~/PROJECTS/wiki/concept/wsl-cmdexe-unc-cwd-testing.md` and `~/PROJECTS/wiki/concept/cli-flag-verification-install-guide.md` (the latter drove verifying the oh-my-opencode provider flags against the official install guide before emitting them).

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.13.0 deferred-fix release (security + Windows parity + cleanups) | Completed (committed locally, NOT yet pushed) | 8 commits on top of v1.12.0 (`4beae0a`): CRLF normalization (`49b401c`), consent-gated `-k` (`89d2ce0`), Authenticode HashMismatch gate (`7931922`), Windows `upgrade` action state (`d83a1e5`), oh-my-opencode provider-flag completeness (`f6cb6f9`), setup.bat divergence docs (`acd95dd`), independent-review fixes (`ce3190d`), release bump (`a3902cc`). Validated by two independent fresh-context reviews (security: SHIP, no must-fix; parity: SHIP WITH FIXES — all applied). **Push pending** live-test validation + user go-ahead. |
| v1.12.0 Antigravity replaces retired Gemini CLI | Completed + pushed | `4beae0a` on `origin/master`. Gemini CLI removed from both installers (tool index 4), replaced in-place with Antigravity CLI (`agy`, native bootstrapper). oh-my-opencode `--gemini` auto-detect + static `--gemini=no` purged. |
| v1.11.0 remove MoAI-ADK bootstrapper same-origin checksum | Completed | Preserved; MoAI-ADK's own downstream tarball verification remains. |
| v1.10.0 Windows Claude Code install fix | Completed | Third-party `install.cmd` runs in isolated child `cmd.exe`. |

## 3. Execution Plan Status

| Phase / Milestone | Status | Last updated | Note |
|---|---|---|---|
| Phase 0: commit + push v1.12.0 | Completed | 2026-06-29 | Pushed `56d91dd..4beae0a`. Closed the "code-complete but uncommitted" gap. |
| Phase 2a: P1 security (consent-gated `-k` + Authenticode tamper gate) | Completed | 2026-06-29 | Consent prompt before any `-k` (fails safe on closed stdin); Authenticode blocks on HashMismatch only (warns on unsigned/untrusted). Security reviewer verdict: SHIP, no must-fix. |
| Phase 2b: P1 Windows `upgrade` action-state parity | Completed | 2026-06-29 | `ACTION_UPGRADE=3` across render/toggle/summary/dispatch/result. Sandbox/Playwright Windows port DEFERRED per user decision. |
| Phase 3: P2 cleanups | Completed | 2026-06-29 | CRLF normalization; all 9 oh-my-opencode provider flags (verified vs official install guide); setup.bat divergence documented. |
| Independent two-reviewer pass + fixes | Completed | 2026-06-29 | Fixed the one High finding (oh-my-opencode→opencode-ai auto-select missed the upgrade path + latent parse-time `%var%` read) and the Medium/Low polish. |
| v1.13.0 version bump + CHANGELOG + README | Completed | 2026-06-29 | All version sites consistent at v1.13.0. |
| Phase 1: live runtime verification (Linux/WSL + Windows) | In progress (user-run) | 2026-06-29 | User can run both. Awaiting `agy --version` output (Linux) and the Windows full-flow + Authenticode-status capture. |
| Push v1.13.0 to origin/master | Pending | 2026-06-29 | Held until live tests validate + user confirms. |

## 4. Outstanding Work

- **Push v1.13.0** (8 local commits) to `origin/master` — pending live-test validation and explicit user go-ahead.
- **Live runtime verification (Phase 1, user-run):**
  - Linux/WSL: install Antigravity (slot 4); confirm `agy` in `~/.local/bin` and capture `agy --version` output (the one unverified assumption — `--version` is hardcoded in `VERARG_4` and the `.sh` `agy --version` call; patch if the flag differs).
  - Windows: run the `.bat` via the absolute-`%TEMP%`-path method (NOT a PATH-resolved name — see wiki `wsl-cmdexe-unc-cwd-testing`); confirm banner v1.13.0, slot 4 Antigravity, Gemini absent; verify the new `upgrade` display (cyan `[U]`, "Upgrade:" summary, "Upgraded:" result) on an outdated tool; capture `claude.exe` Authenticode status: `powershell -Command "(Get-AuthenticodeSignature \"$env:USERPROFILE\.local\bin\claude.exe\").Status"`.
  - cmd.exe parse smoke test could NOT be run this session (WSL `cmd.exe` interop unavailable); the Windows live run is the runtime gate.

- **Deferred (explicitly, with rationale):**
  - **Claude Code sandbox/Playwright setup on Windows (P1 feature, deferred):** `setup_claude_sandbox` (seccomp + Playwright) is Linux-only for the seccomp half; only the Playwright CLI+MCP portion is portable. Schedule as a separate feature.
  - **Authenticode `-k`-path hardening (security Finding 3, evidence-gated):** when the consented `-k` path was used (TLS surrendered), escalate `NotSigned`/`NotTrusted` to blocking. Correctness depends on `claude.exe`'s normal Authenticode status — implement only if the Windows live test shows it is normally `Valid` (else escalation would break legitimate `-k` installs).
  - **Codex/OpenCode use npm rather than the primary bootstrapper (P2, accepted divergence):** npm is a documented fallback; works. Switching to the curl/PowerShell bootstrapper is an optional future enhancement (verify against each tool's install guide first).

## 5. Risks, Open Questions, and Assumptions

| Item | Status | Date opened | Resolution / assumption in effect |
|---|---|---|---|
| Antigravity `agy --version` flag | Assumed-OK | 2026-06-27 | `--version` hardcoded in `VERARG_4` (.bat) and the `.sh` call. Awaiting live confirmation; patch both if different. |
| `claude.exe` normal Authenticode status (Valid vs NotSigned) | Open | 2026-06-29 | Determines whether the security Finding 3 hardening (block on `-k` path) is safe. Capture in the Windows live test. The current HashMismatch-only gate is safe regardless. |
| Windows live install/upgrade/remove flows unexercised at runtime | Open | 2026-06-29 | Static checks (label resolution, paren balance, CRLF, content identity) + two independent reviews pass; runtime parse/flow pending the user's Windows run. |
| moai-adk output-style localization (upstream #382) | Open | 2026-02-15 | Upstream issue remains open; installer-side default unchanged. |

## 6. Verification Status

### Verified (this session)

| Item | Method | Result | Date |
|---|---|---|---|
| `.sh` syntax | `bash -n install_coding_tools.sh setup.sh` | Pass | 2026-06-29 |
| `.bat` uniform CRLF | byte-level check (lone `\n`=0, `\r\r\n`=0) after every edit | Pass | 2026-06-29 |
| CRLF normalization content-safe | `tr -d '\r'` diff vs prior commit identical | Pass | 2026-06-29 |
| `.bat` label resolution | all `call :`/`goto` targets resolve | Pass (0 unresolved) | 2026-06-29 |
| `.bat` paren balance | unchanged from baseline (pre-existing +1 echo-deco offset) | Pass | 2026-06-29 |
| Security changes | independent expert-security review of `4beae0a..HEAD` | SHIP, 0 must-fix | 2026-06-29 |
| Upgrade-state + flags + parity | independent expert-devops review | SHIP WITH FIXES (all applied) | 2026-06-29 |
| oh-my-opencode provider flags | cross-checked official install guide (code-yeongyu/oh-my-openagent) | All 9 documented; parity .sh/.bat | 2026-06-29 |
| Version consistency | grep v1.13.0 across 4 scripts + README + CHANGELOG | Pass; no stale banners | 2026-06-29 |

### Not yet verified

- Live install of Antigravity on Linux/WSL + Windows; actual `agy --version` output.
- Windows runtime: `.bat` parse + install/upgrade/remove flows; the new `upgrade` display; the consent prompt and Authenticode gate in their trigger paths.
- `claude.exe` Authenticode status on a real Windows host.

## 7. Restart Instructions

- **Exact starting point:**
  1. `git log --oneline 4beae0a..HEAD` shows the 8 local v1.13.0 commits (unpushed).
  2. Sanity: `bash -n install_coding_tools.sh setup.sh`; confirm `.bat` is uniform CRLF (`file install_coding_tools.bat`).
- **Recommended next actions:**
  1. Run the Linux/WSL live test (install Antigravity slot 4) and capture `agy --version`; patch `VERARG_4`/`.sh` if the flag differs.
  2. Run the Windows `.bat` via the absolute-`%TEMP%`-path method; verify the upgrade display and capture `claude.exe` Authenticode status.
  3. If live tests pass, `git push origin master` to ship v1.13.0.
  4. If `claude.exe` is normally `Valid`-signed, optionally implement the security Finding 3 `-k`-path hardening.
- **Last updated:** 2026-06-29
