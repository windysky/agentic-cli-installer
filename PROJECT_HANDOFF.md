# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-06-29 23:21 CDT
- **Last coding CLI used (informational):** Claude Code (Sonnet 4.6)
- **Cross-project wiki (consulted this session):** `~/PROJECTS/wiki/index.md` and the related `~/PROJECTS/wiki/concept/wsl-cmdexe-unc-cwd-testing.md` (WSL↔cmd.exe interop / UNC-cwd context).
- **Cross-project wiki (distilled this session):** `~/PROJECTS/wiki/concept/wsl-windows-user-detection-fallback.md` (when WSL interop is disabled, the `/mnt/c/Users` fallback must skip built-in accounts and prefer the writable, most-recently-used profile — never the alphabetically-first dir).

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.14.1: Antigravity latest-version detection | Completed + pushed | `get_latest_version` (`.sh`) / `:get_latest_native_version` (`.bat`) now query Antigravity's official release manifest (`…run.app/manifests/<platform>.json`, the endpoint its own installer uses) and parse `version`; platform detection mirrors the official installer. Previously "Latest: Unknown" (only claude-code/moai-adk had a source). Verified live on Linux (`get_latest_antigravity_version` → `1.0.14`). Committed `c15f6bd`, pushed. `.bat` powershell-manifest path needs a Windows run to confirm. Confirmed by user's 2026-06-29 Windows run: v1.14.0 deployed cleanly (7-tool menu, no Jules; Antigravity detected `1.0.14`). |
| v1.14.0: remove Google Jules CLI + Antigravity Windows fixes | Completed + pushed (Windows runtime verified for install/detect) | Removed `@google/jules` from both installers (`.sh` TOOLS array; `.bat` `TOOL_5` + property block, `TOOLS_COUNT` 7→6, renumbered 5/6) + README row. Antigravity Windows: remove path fixed to `%LOCALAPPDATA%\agy\bin\agy.exe`; version detection falls back to that path before a PATH-refreshing terminal restart. Suppressed a cosmetic claude-code-upgrade stderr leak. Committed `72f21a7`, pushed. Static-verified (bash -n, label resolution, paren balance, CRLF, structure); `.bat` runtime parse + the 3 Windows behaviors need a Windows run. Deployed `.bat` is still v1.13.0 — re-run `./setup.sh --force` to push v1.14.0 to `/mnt/c/Users/jung.hur/.local/bin`. See PROJECT_LOG.md 2026-06-29 23:00 CDT. |
| setup.sh WSL Windows-account detection fix (v1.13.1) | Completed + pushed | `get_windows_username()` rewritten so the WSL→Windows-side install no longer targets `Administrator` when WSL interop is disabled. Root cause: interop dead on the host (`/proc/sys/fs/binfmt_misc/WSLInterop` absent → `cmd.exe`/`powershell.exe` fail) → exec-based detection returned empty → old `/mnt/c/Users` fallback picked the alphabetically-first non-system dir (`Administrator`, non-writable → `mkdir` denied). Fix adds `WIN_USER` override + built-in-account skip list + writable/newest-`NTUSER.DAT` heuristic. Verified unit-level (RED `Administrator` → GREEN `jung.hur`) **and** by real deploy: `./setup.sh --force` detected `jung.hur` and copied the `.bat` to `/mnt/c/Users/jung.hur/.local/bin` (91454 bytes), no permission error. Released as **v1.13.1** (version-synced across all scripts + CHANGELOG + README), pushed to origin/master 2026-06-29. See PROJECT_LOG.md 2026-06-29 17:55 CDT. |
| v1.13.0 deferred-fix release (security + Windows parity + cleanups) | Completed + pushed | 8 commits on top of v1.12.0 (`4beae0a`): CRLF normalization (`49b401c`), consent-gated `-k` (`89d2ce0`), Authenticode HashMismatch gate (`7931922`), Windows `upgrade` action state (`d83a1e5`), oh-my-opencode provider-flag completeness (`f6cb6f9`), setup.bat divergence docs (`acd95dd`), independent-review fixes (`ce3190d`), release bump (`a3902cc`). Validated by two independent fresh-context reviews (security: SHIP, no must-fix; parity: SHIP WITH FIXES — all applied). Pushed to `origin/master` (`4beae0a..b63e920`) on 2026-06-29 at user direction; live runtime tests are now post-release verification. |
| v1.12.0 Antigravity replaces retired Gemini CLI | Completed + pushed | `4beae0a` on `origin/master`. Gemini CLI removed from both installers (tool index 4), replaced in-place with Antigravity CLI (`agy`, native bootstrapper). oh-my-opencode `--gemini` auto-detect + static `--gemini=no` purged. |
| v1.11.0 remove MoAI-ADK bootstrapper same-origin checksum | Completed | Preserved; MoAI-ADK's own downstream tarball verification remains. |
| v1.10.0 Windows Claude Code install fix | Completed | Third-party `install.cmd` runs in isolated child `cmd.exe`. |

## 3. Execution Plan Status

| Phase / Milestone | Status | Last updated | Note |
|---|---|---|---|
| v1.14.1 release (Antigravity latest-version detection) | Completed + pushed | 2026-06-29 23:21 CDT | `c15f6bd`. Manifest query in both installers; Linux live-verified (`1.0.14`); `.bat` powershell path needs a Windows run. |
| v1.14.0 release (Jules removal + Antigravity Windows fixes) | Completed + pushed; Windows install/detect confirmed | 2026-06-29 23:00 CDT | `72f21a7`. Static-verified; Windows runtime re-test pending (re-deploy via `./setup.sh --force`). |
| setup.sh Windows-account detection fix | Completed | 2026-06-29 22:21 CDT | `get_windows_username()` rewrite verified unit-level + real-deploy (`jung.hur`, `.bat` copied, no permission error). |
| v1.13.1 release (setup.sh fix) | Completed + pushed | 2026-06-29 22:21 CDT | Version-synced across all 4 scripts + CHANGELOG `## [1.13.1]` + README entry; committed + pushed to origin/master. |
| Phase 0: commit + push v1.12.0 | Completed | 2026-06-29 | Pushed `56d91dd..4beae0a`. Closed the "code-complete but uncommitted" gap. |
| Phase 2a: P1 security (consent-gated `-k` + Authenticode tamper gate) | Completed | 2026-06-29 | Consent prompt before any `-k` (fails safe on closed stdin); Authenticode blocks on HashMismatch only (warns on unsigned/untrusted). Security reviewer verdict: SHIP, no must-fix. |
| Phase 2b: P1 Windows `upgrade` action-state parity | Completed | 2026-06-29 | `ACTION_UPGRADE=3` across render/toggle/summary/dispatch/result. Sandbox/Playwright Windows port DEFERRED per user decision. |
| Phase 3: P2 cleanups | Completed | 2026-06-29 | CRLF normalization; all 9 oh-my-opencode provider flags (verified vs official install guide); setup.bat divergence documented. |
| Independent two-reviewer pass + fixes | Completed | 2026-06-29 | Fixed the one High finding (oh-my-opencode→opencode-ai auto-select missed the upgrade path + latent parse-time `%var%` read) and the Medium/Low polish. |
| v1.13.0 version bump + CHANGELOG + README | Completed | 2026-06-29 | All version sites consistent at v1.13.0. |
| Phase 1: live runtime verification (Linux/WSL + Windows) | In progress (user-run) | 2026-06-29 | User can run both. Awaiting `agy --version` output (Linux) and the Windows full-flow + Authenticode-status capture. |
| Push v1.13.0 to origin/master | Completed | 2026-06-29 | Pushed `4beae0a..b63e920` at user direction (ahead of live tests). |

## 4. Outstanding Work

- **setup.sh Windows-account detection fix + v1.13.1 release — DONE this session (2026-06-29 22:21 CDT; ref PROJECT_LOG.md 2026-06-29 17:55 CDT):** fix verified unit-level + real deploy (`jung.hur`, `.bat` copied, no permission error); v1.13.1 version-synced + CHANGELOG + README; committed + pushed to origin/master. Caveat retained: this host has WSL Windows-interop **disabled** (binfmt `WSLInterop` unregistered), so the fix's `/mnt/c/Users` heuristic path is what runs here; on interop-working hosts the `cmd.exe`/`powershell.exe` methods take over (unchanged).

- **Push v1.13.0** — DONE (pushed `4beae0a..b63e920` on 2026-06-29). The live runtime verification below is now POST-RELEASE (user chose to push ahead of it); fix-forward if a live test reveals an issue.
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
| setup.sh picked `Administrator` as the Windows account (WSL) | Resolved (released v1.13.1) | 2026-06-29 | Root cause: WSL interop disabled on host → exec detection empty → alphabetical `/mnt/c/Users` fallback. Fixed via WIN_USER override + built-in skip list + writable/newest-NTUSER.DAT heuristic. Real-deploy proof passed (`jung.hur`); shipped in v1.13.1 (pushed). |
| WSL Windows-interop disabled on this host | Open (environment, not a code defect) | 2026-06-29 | `/proc/sys/fs/binfmt_misc/WSLInterop` absent; `cmd.exe`/`powershell.exe` give `command not found` / `Exec format error`. setup.sh now degrades correctly without interop. Re-enabling interop (WSL config) is a user OS-level action, out of installer scope. |
| Antigravity `agy --version` flag | Resolved | 2026-06-27 | Confirmed: Linux `agy --version` → `1.0.14` (2026-06-29). `--version` is correct in `VERARG_4` (.bat) and the `.sh` call; no patch needed. |
| `claude.exe` normal Authenticode status (Valid vs NotSigned) | Open | 2026-06-29 | Determines whether the security Finding 3 hardening (block on `-k` path) is safe. Capture in the Windows live test. The current HashMismatch-only gate is safe regardless. |
| Windows live install/upgrade/remove flows | Partially verified | 2026-06-29 | v1.13.0 `.bat` ran on Windows 2026-06-29: install (Antigravity) + upgrade (claude-code 2.1.195→2.1.196) succeeded; menu/parse OK. Still unexercised: remove flow; and the v1.14.0 changes (Jules-removal renumbering, Antigravity remove/detect, stderr suppression) need a fresh Windows run after re-deploy. |
| moai-adk output-style localization (upstream #382) | Open | 2026-02-15 | Upstream issue remains open; installer-side default unchanged. |

## 6. Verification Status

### Verified (this session)

| Item | Method | Result | Date |
|---|---|---|---|
| v1.14.0 on Windows (user run) | user re-deployed + ran the `.bat` | 7-tool menu, **no Google Jules**; Antigravity detected `1.0.14` (version-detection fix works); banner v1.14.0 | 2026-06-29 23:21 CDT |
| v1.14.1 Antigravity latest helper | extracted `get_latest_antigravity_version`, ran live (Linux) | `1.0.14` (matches installed → "up to date") | 2026-06-29 23:21 CDT |
| v1.14.1 `.bat` parse-safety | label resolution; dispatch+label present; CRLF byte-check | all resolve; `get_latest_native_antigravity` present; uniform CRLF | 2026-06-29 23:21 CDT |
| Antigravity install (Linux) | user ran `agy --version` | `1.0.14` (install works; `--version` flag correct) | 2026-06-29 23:00 CDT |
| v1.14.0 Jules removal structure | grep TOOLS_COUNT/TOOL_n/properties; `.sh` array; orphan `_7` scan | `TOOLS_COUNT=6`, `TOOL_1..6`, properties renumbered 5/6, no orphan `_7`; `.sh` array 6 entries; Jules purged from functional code | 2026-06-29 23:00 CDT |
| v1.14.0 `.bat` parse-safety | label resolution; paren balance on edited Antigravity blocks; CRLF byte-check | all labels resolve; blocks balanced; uniform CRLF (lone-`\n`=0, `\r\r\n`=0) | 2026-06-29 23:00 CDT |
| v1.14.0 version consistency | grep banners/headers; `bash -n`; CHANGELOG | all v1.14.0; bash -n pass; CHANGELOG descending | 2026-06-29 23:00 CDT |
| setup.sh real-deploy (WSL→Windows) | `./setup.sh --force` on this host | Detected `jung.hur`; `.bat` copied to `/mnt/c/Users/jung.hur/.local/bin` (91454 bytes), no permission error | 2026-06-29 22:21 CDT |
| v1.13.1 version consistency | grep banners/headers + CHANGELOG/README; `.bat` CRLF byte-check; `bash -n` | All at v1.13.1; `.bat` uniform CRLF; syntax OK; CHANGELOG descending | 2026-06-29 22:21 CDT |
| setup.sh `get_windows_username` reproduction | harness extracting the live function; RED current vs GREEN fixed | RED `Administrator` → GREEN `jung.hur` | 2026-06-29 17:55 CDT |
| setup.sh override + exact-match paths | `WIN_USER=`, `USERPROFILE=`, exact-`$USER` run via harness | All return expected account | 2026-06-29 17:55 CDT |
| setup.sh syntax (post-fix) | `bash -n setup.sh` | Pass | 2026-06-29 17:55 CDT |
| No duplicate Windows-user detection | `grep` `install_coding_tools.sh` / `auto_install_coding_tools` | None found (localized to setup.sh) | 2026-06-29 17:55 CDT |
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

- **Windows, still unverified** (confirmed on 2026-06-29: 6-tool menu w/o Jules, Antigravity install + version detection `1.0.14`): the Antigravity **remove** path (`%LOCALAPPDATA%\agy\bin\agy.exe`); the claude-code-upgrade **stderr suppression** (couldn't reproduce without cmd.exe); the **v1.14.1 `.bat` manifest query** (`:get_latest_native_antigravity` powershell path — Linux equivalent verified, Windows pending). Re-deploy v1.14.1 via `./setup.sh --force` first.
- Windows runtime: the `remove` flow for any tool; the consent prompt and Authenticode gate in their trigger paths.
- `claude.exe` Authenticode status on a real Windows host.

## 7. Restart Instructions

- **Exact starting point:**
  1. **v1.14.1 is released + pushed** (`origin/master` at `c15f6bd`; `git log --oneline`). Working tree clean. Recent: Google Jules removed (v1.14.0); Antigravity Windows remove/detect fixed (v1.14.0); claude-code-upgrade stderr suppressed (v1.14.0); Antigravity latest-version detection via official manifest (v1.14.1). Windows v1.14.0 confirmed by user (7-tool menu w/o Jules; Antigravity `1.0.14` detected).
  2. Sanity: `bash -n install_coding_tools.sh setup.sh`; confirm `.bat` is uniform CRLF (`file install_coding_tools.bat`).
- **Recommended next actions (in order):**
  1. **Re-deploy v1.14.1 to Windows:** `./setup.sh --force` (the deployed `.bat` is older). Then on Windows confirm: Antigravity menu shows a real "Latest" (e.g. `1.0.14`), not "Unknown"; Antigravity **remove** deletes `%LOCALAPPDATA%\agy\bin\agy.exe`; no "filename, directory name…" leak on a claude-code upgrade.
  2. Exercise the Windows `remove` flow generally and the consent prompt / Authenticode gate in their trigger paths; capture `claude.exe` Authenticode status.
  3. If `claude.exe` is normally `Valid`-signed, optionally implement the security Finding 3 `-k`-path hardening.
- **Last updated:** 2026-06-29 23:21 CDT
