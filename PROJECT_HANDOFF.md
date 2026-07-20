# Project Handoff

## 1. Project Overview

- **Name:** agentic-cli-installer
- **Purpose and scope:** Cross-platform interactive installer for AI coding CLIs (install, update, remove) with Unix/WSL support via `install_coding_tools.sh` and Windows support via `install_coding_tools.bat`.
- **Last updated:** 2026-07-20 11:24 CDT
- **Last coding CLI used (informational):** Claude Code (Opus 4.8)
- **Cross-project wiki (distilled 2026-07-20):** `~/PROJECTS/wiki/concept/newest-published-version-is-not-installable.md` (a tool-manager must ask "will it run here?", not only "what is newest?"; the displayed and installed version must share one resolution), `~/PROJECTS/wiki/concept/fail-open-verification-harness-masking.md` (in a fail-open system a broken harness is indistinguishable from a broken fix; independent verification means testing a *different* property), `~/PROJECTS/wiki/concept/semver-prerelease-precedence-and-rcn.md` (suffix stripping, strict-ASCII `rcN` inversion, and the PowerShell `[version]` pre-release trap).
- **Cross-project wiki (consulted this session):** `~/PROJECTS/wiki/index.md` and the related `~/PROJECTS/wiki/concept/wsl-cmdexe-unc-cwd-testing.md` (WSL↔cmd.exe interop / UNC-cwd context).
- **Cross-project wiki (distilled this session):** `~/PROJECTS/wiki/concept/wsl-windows-user-detection-fallback.md` (when WSL interop is disabled, the `/mnt/c/Users` fallback must skip built-in accounts and prefer the writable, most-recently-used profile — never the alphabetically-first dir) and `~/PROJECTS/wiki/concept/native-cli-version-and-location-from-installer.md` (read a native CLI's own install.sh/install.cmd to find its version-manifest endpoint and its platform-specific install location — don't assume the Unix path on Windows).

## 2. Current State

| Component | Status | Current truth |
|---|---|---|
| v1.14.4: engine-aware npm selection + pre-release comparison | Completed + pushed + deployed (Linux verified, Windows NOT) | Two defects fixed. (1) npm upgrades ignored `engines.node`: the installer offered npm's `latest` dist-tag without checking the conda env's Node could run it, so an odd-numbered non-LTS Node (25.x) got `EBADENGINE` (npm 12 supports only `^22.22.2 \|\| ^24.15.0 \|\| >=26.0.0`). Now resolves the newest npm whose `engines.node` accepts the env's own node (`get_conda_node_path`, not PATH) and installs that pinned version at **all four** install sites, so menu and action cannot disagree; `bootstrap_npm_from_registry` selects through the same path. Fails open to the `latest` tag on any lookup failure. (2) Pre-release comparison: `3.0.0-rc12` compared equal to `3.0.0` and read as up to date; now implements SemVer 2.0.0 precedence with undotted `rcN` sorting numerically. Committed `a494117`, pushed, deployed to Linux + Windows targets. **Linux verified** (SemVer 30/30; live-registry selection 5/5; menu-vs-action 6/6 on this host's real env — node 25.2.1, npm 11.18.0). **Windows never executed** — see §5. |
| v1.14.3: self-healing conda Node.js/npm | Completed + pushed | `ensure_npm_prerequisite` rewritten as a node-first repair sequence: env-local node check (`get_conda_node_path`/`get_conda_env_bin_dir`), conda retry ladder (`conda_install_nodejs`), npm validated by execution rather than existence, and a registry-tarball fallback (`bootstrap_npm_from_registry`). Committed `f368841` 2026-07-12. **No live run on either platform** — static-verified only. Note: as shipped in v1.14.3 the bootstrap fetched npm's unfiltered `latest`, which v1.14.4 corrected. |
| Repo ignore policy restored | Completed + pushed | A `moai update` on 2026-07-12 rewrote `.gitignore` and dropped two deliberate decisions: the `!logs/` + `!logs/PROJECT_LOG_*.md` negations (rotation archives were being silently ignored) and the User-Custom-Patterns block ignoring `.moai/`, `.claude/`, `.agency/` (~8.1 MB of agent tooling had become untracked). Both restored, trailing newline restored. Verified with real files: a new `logs/PROJECT_LOG_*.md` is visible to git while `logs/*.log` stays ignored. Committed `358273b`. `.mcp.json` (sequential-thinking removed, context7 `alwaysLoad`) and `CLAUDE.md` (newer MoAI template; 366 removed lines audited, all generic template prose) committed alongside. `.github/`, `scripts/`, `Makefile`, `.git_hooks/`, `.claudeignore` intentionally remain untracked. |
| v1.14.2: setup.sh announces deployed installer version | Completed + pushed | `setup.sh` deployment summary now prints `Installed installer version: vX.Y.Z` + the version inline next to each deployed script (new `get_installer_version` helper parses the `Agentic Coders Installer vX.Y.Z` header). **Verified live** — `./setup.sh --force` summary shows `v1.14.2`. Committed `481dadc`, pushed. That run also re-deployed v1.14.2 to Linux `~/.local/bin` and Windows `/mnt/c/Users/jung.hur/.local/bin` (so the Windows `.bat` is now v1.14.2 with all Antigravity work). |
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
| v1.14.4 release (engine-aware npm + pre-release comparison) | Completed + pushed + deployed | 2026-07-20 | `a494117`. Linux verified end-to-end; Windows `.bat` static-verified only. |
| Repo ignore-policy reconciliation | Completed + pushed | 2026-07-20 | `358273b`. Closes the `moai update` drift from 2026-07-12. |
| CHANGELOG `[1.14.2]` heading restored | Completed | 2026-07-20 | The v1.14.2 entry had been folded under `[1.14.3]`; headings now match README. |
| v1.14.3 release (self-healing conda node/npm) | Completed + pushed | 2026-07-12 | `f368841`. Live verification still outstanding on both platforms. |
| v1.14.2 release (setup.sh version announcement) | Completed + pushed | 2026-06-29 23:32 CDT | `481dadc`. Verified live (summary shows `v1.14.2`). Also re-deployed v1.14.2 to Linux + Windows targets. |
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

**Current priorities (as of 2026-07-20), in order:**

1. **Windows live verification — now the single largest open risk.** Three separate bodies of code have never been executed by `cmd.exe`, and they have accumulated across three releases. The v1.14.4 `.bat` is already deployed to `/mnt/c/Users/jung.hur/.local/bin`. Run it and confirm, in one pass:
   - The menu renders at all (a parse error in the new base64-encoded JS payload or the new labels `:get_npm_installable_version` / `:npm_install_target` / `:npmpick_legacy` would break it outright).
   - The npm row shows an engine-compatible Latest, and selecting it installs that pinned version rather than `npm@latest`.
   - MoAI-ADK's row no longer reports "up to date" while on a release candidate.
   - v1.14.3's npm self-heal (never run anywhere) and v1.14.2's Antigravity manifest query (`Latest = 1.0.14`, not "Unknown").
   - The Antigravity **remove** path (`%LOCALAPPDATA%\agy\bin\agy.exe`) and the `remove` flow generally.
   - Capture `claude.exe` Authenticode status: `powershell -Command "(Get-AuthenticodeSignature \"$env:USERPROFILE\.local\bin\claude.exe\").Status"`.
   - Invoke via the absolute `%TEMP%` path method, never a PATH-resolved name — see wiki `wsl-cmdexe-unc-cwd-testing`.
2. **Linux live verification of v1.14.3's npm self-heal.** Static-verified only. Exercising it needs an environment with a deliberately broken or missing npm; the registry-tarball bootstrap path downloads and executes remote code, so it deserves a real run before anyone relies on it.
3. **Confirm the `agy --version` output format.** v1.14.4 preserves version suffixes, so if Antigravity prints something like `1.0.0-linux-x64` it would now be read as a pre-release and rank permanently below the manifest's plain version, showing a perpetual "update". `agy` is not installed on the dev host, so this could not be closed. Check on any machine that has it.
4. **Deferred, decision pending: generalise the engine check.** An audit found no *current* exposure among the other npm-managed tools — `@openai/codex >=16`, `claude-code >=22.0.0`, `qwen-code >=22.0.0`, `gemini-cli >=20`, `opencode-ai` and `oh-my-opencode` declare none. All are open-ended lower bounds, which cannot exclude a newer node, and the installer already gates at `MIN_NODEJS_VERSION=22.9.0`. npm's caret-per-LTS-line range is the only upper-bounded one in play. Latent sites that still install `@latest` unchecked: `.sh:2663`/`.bat:2614` (generic npm tool upgrade), `.sh:2707`/`.bat:1102` (oh-my-opencode addon), `.sh:524`, `.sh:720`, `.sh:761/765` (seccomp + Playwright helpers). If any of those packages adopts an upper-bounded range, the identical defect reappears with nothing to detect it. `semver_range_satisfied` is generic and would extend.

**Historical (kept for provenance):**

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
| v1.14.4 `.bat` has never been parsed by cmd.exe | Open (highest risk) | 2026-07-20 | Shipped ahead of live Windows testing at user direction, per the v1.13.0 precedent; fix-forward if a run reveals a problem. Static verification passed: 98 labels all resolve, uniform CRLF, paren balance unchanged, no multi-line `( )` block in the new picker (so every `%var%` read is parse-time correct), embedded JS byte-identical to a payload exercised live under Linux node, and it passes `node --check`. None of that proves cmd.exe will parse the file. |
| Windows version status may never have been computed at all (pre-v1.14.4) | Open, unverifiable here | 2026-07-20 | The old `:version_compare_semver` guard was `if "%installed%"=="Not Installed" echo missing& exit /b 0`. In cmd, `&` is not scoped to a single-line `if`, so `exit /b 0` likely ran unconditionally — the label would have returned before comparing anything, leaving the status variable unset on every Windows row. It also `echo`ed rather than setting the out-variable. v1.14.4 rewrites this with standalone guards. If the hypothesis is right, Windows version display was broken for longer than anyone noticed. Needs a cmd.exe run to confirm or dismiss. |
| `agy --version` output format unknown | Open | 2026-07-20 | v1.14.4 preserves version suffixes. A non-SemVer suffix (`1.0.0-linux-x64`) would now be parsed as a pre-release and rank permanently below the manifest's plain version → perpetual "update" for Antigravity. `agy` absent on the dev host. The `.bat` already had this exposure before v1.14.4 (its extraction regex always kept suffixes), so the change makes the platforms consistent rather than introducing a novel failure. |
| Engine-aware npm check is silently skippable | Accepted by design | 2026-07-20 | Six conditions fail open to the `latest` dist-tag: no network, no curl, no resolvable conda node, unparseable registry document, unsupported range syntax, no compatible match. On a slow link the stage-2 fetch (2.3 MB, `--max-time 25`) times out and the user silently gets the old broken suggestion back. Deliberate — a version lookup must never block an install — but the only signal is `DEBUG=1`. |
| Two range-evaluator implementations can drift | Open (structural) | 2026-07-20 | The bash `semver_range_satisfied` and the base64-embedded JS in the `.bat` were cross-checked at 208/208 pairs across all 11 distinct `engines.node` strings npm has published. Nothing mechanically enforces they stay in sync; a future edit to one will fail no check. The `.bat` comment names its `.sh` twin — documentation, not a gate. |
| PATH node masks the conda env's node on the dev host | Environment, informative | 2026-07-20 | `/usr/bin/node` is v18.19.1 while `$CONDA_PREFIX/bin/node` is **v25.2.1** (npm 11.18.0). This host is itself an instance of the reported EBADENGINE configuration. Any diagnostic that reads bare `node -v` measures the wrong binary — the exact masking v1.14.3's env-local check exists to prevent, and it produced one wrong reading during this session before being caught. |
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
| Pre-release comparison (Defect B) | orchestrator harness `awk`-extracting the live functions from the shared checkout, 30 cases | 0 failures. `3.0.0-rc12` vs `3.0.0` → `update`; `rc9 < rc10 < rc12`; `3.1.0-rc1` vs `3.0.0` → `current` (no downgrade); normal releases unchanged; `version_ge` node-gate semantics preserved | 2026-07-20 |
| Engine-aware npm selection (Defect C) | orchestrator harness, **live registry**, stubbed conda nodes | 0 failures. node 25.6.0 → npm 11.18.0; 22.22.2 / 26.0.0 → 12.0.1; 18.19.1 → 10.9.8; no conda env → dist-tag latest (fail-open) | 2026-07-20 |
| Menu-vs-action agreement | orchestrator harness against this host's **real** conda env (node 25.2.1, npm 11.18.0) | 0 failures. Menu Latest = 11.18.0; action target = `npm@11.18.0` whether the menu value is passed through, `Unknown`, empty, or `Not Installed`; no curl → literal `latest` | 2026-07-20 |
| Deployed copy behaves | extracted the same functions from `~/.local/bin/install_coding_tools.sh` after `setup.sh --force` | menu latest = 11.18.0, action target = `npm@11.18.0` | 2026-07-20 |
| No `npm@latest` install command remains | `grep -n 'install -g npm@latest'` across both installers | 0 matches | 2026-07-20 |
| `.bat` structural integrity | label-resolution scan; CRLF byte check | 98 labels, 0 unresolved; crlf 2837, lone-`\n` 0, `\r\r\n` 0 | 2026-07-20 |
| `.sh` syntax | `bash -n install_coding_tools.sh setup.sh` | Pass | 2026-07-20 |
| Version consistency at v1.14.4 | grep all banners/headers + CHANGELOG + README | All at v1.14.4; no stale v1.14.3 banners; CHANGELOG headings gapless and matching README | 2026-07-20 |
| `logs/` archive negation restored | created a real `logs/PROJECT_LOG_2026-H2.md` and a `logs/scratch.log` | archive visible to git as untracked; `.log` correctly ignored | 2026-07-20 |
| `CLAUDE.md` lost no project content | audited all 366 removed lines for installer-specific terms | all generic MoAI template prose | 2026-07-20 |
| Deployment | `./setup.sh --force` | Summary reports `v1.14.4`; both Linux and Windows targets confirmed at v1.14.4 by header grep | 2026-07-20 |
| v1.14.2 version announcement (live) | `./setup.sh --force` on this host | Summary printed `Installed installer version: v1.14.2` + `(v1.14.2)` inline next to Unix and Windows scripts | 2026-06-29 23:32 CDT |
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

### Not yet verified (as of 2026-07-20)

- **The entire Windows surface of v1.14.2 / v1.14.3 / v1.14.4.** No `cmd.exe` or `powershell.exe` exists on the dev host (WSL interop disabled), so none of the `.bat` changes across three releases have ever been executed. Everything Windows-side is static analysis. This is the dominant open risk.
- **v1.14.3's npm self-heal on any platform** — the conda retry ladder, the broken-npm detection, and the registry-tarball bootstrap have never been run against a genuinely broken environment. No real `npm install` was performed at any point; verification covered the *command line* that would be issued, not that it succeeds.
- **`agy --version` output format** (see §5) and, consequently, whether Antigravity now shows a perpetual "update".
- **Whether PowerShell 5.1's `maxJsonLength` actually rejects the 2.3 MB packument.** That limit is the stated reason the `.bat` parses the registry response with the conda `node.exe` rather than PowerShell. The packument size was measured (2.32 MB); the limit itself was not observed. The design is sound either way, but the *rationale* is unconfirmed.

### Not yet verified (historical, pre-2026-07-20)

- **Windows, still unverified** (confirmed on 2026-06-29: 6-tool menu w/o Jules, Antigravity install + version detection `1.0.14`): the Antigravity **remove** path (`%LOCALAPPDATA%\agy\bin\agy.exe`); the claude-code-upgrade **stderr suppression** (couldn't reproduce without cmd.exe); the **v1.14.1 `.bat` manifest query** (`:get_latest_native_antigravity` powershell path — Linux equivalent verified, Windows pending). Re-deploy v1.14.1 via `./setup.sh --force` first.
- Windows runtime: the `remove` flow for any tool; the consent prompt and Authenticode gate in their trigger paths.
- `claude.exe` Authenticode status on a real Windows host.

## 7. Restart Instructions

- **Exact starting point (2026-07-20):**
  1. **v1.14.4 is released, pushed, and deployed.** `origin/master` at `a494117`; local `master` in sync (`git rev-list --count --left-right origin/master...HEAD` → `0 0`). Both deployed copies are at v1.14.4: `~/.local/bin/install_coding_tools.sh` and `/mnt/c/Users/jung.hur/.local/bin/install_coding_tools.bat`.
  2. Working tree carries five intentionally untracked paths — `.github/`, `scripts/`, `Makefile`, `.git_hooks/`, `.claudeignore`. `.moai/`, `.claude/`, `.agency/` are ignored by policy. That is the expected steady state, not drift.
  3. Sanity: `bash -n install_coding_tools.sh setup.sh`; `file install_coding_tools.bat` should report CRLF.
  4. **The next action is Windows verification** (§4 item 1) — the `.bat` is deployed but has never been parsed by cmd.exe.
  5. Re-runnable verification harnesses from this session live in the session scratchpad and are disposable; they extract live functions from the installer rather than copying them, so they can be rebuilt from §6 if needed.
  6. **No paste needed to resume.** Just say **"resume"** (or "start session" / "continue where we left off") and the saved prompt in the auto-memory `next_session_prompt.md` drives the next session — it will summarize, confirm with you, verify the preconditions, and then run. The `.moai/handoff-next-session.md` twin carries the identical prompt inside the repo.

- **Superseded starting point (2026-06-30):**
  1. **v1.14.2 is released + pushed** (`origin/master` at `481dadc`; `git log --oneline`). Working tree clean. Recent: Google Jules removed + Antigravity Windows remove/detect + claude stderr suppression (v1.14.0); Antigravity latest-version detection via official manifest (v1.14.1); setup.sh announces deployed version (v1.14.2). v1.14.2 already deployed to Linux + Windows targets (`/mnt/c/Users/jung.hur/.local/bin/install_coding_tools.bat` is v1.14.2).
  2. Sanity: `bash -n install_coding_tools.sh setup.sh`; confirm `.bat` is uniform CRLF (`file install_coding_tools.bat`).
- **Recommended next actions (in order):**
  1. **Verify on Windows** (the v1.14.2 `.bat` is already deployed): run it and confirm the Antigravity row shows **Latest = `1.0.14`** (not "Unknown"); exercise Antigravity **remove** (deletes `%LOCALAPPDATA%\agy\bin\agy.exe`); confirm no "filename, directory name…" leak on a claude-code upgrade.
  2. Exercise the Windows `remove` flow generally and the consent prompt / Authenticode gate in their trigger paths; capture `claude.exe` Authenticode status.
  3. If `claude.exe` is normally `Valid`-signed, optionally implement the security Finding 3 `-k`-path hardening.
- **Last updated:** 2026-07-20
