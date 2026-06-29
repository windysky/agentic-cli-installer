# PROJECT_LOG.md (active) — agentic-cli-installer
Append-only history. Active file holds the most recent sessions; older ones live in logs/. Newest first.

## Archives
- logs/PROJECT_LOG_2026-H1.md — 9 sessions (2026-02 … 2026-02)

## Session Index (active, newest first)
- 2026-06-29 — v1.13.0: deferred-fix release (consent-gated -k, Authenticode tamper gate, Windows upgrade action state, oh-my-opencode flag completeness, CRLF normalization, setup.bat docs); 2 independent reviews; committed locally, push pending live tests
- 2026-06-27 21:06 CDT — v1.12.0: Antigravity CLI replaces retired Gemini CLI; --gemini=no purge; multi-expert review + fixes; .bat runtime smoke test
- 2026-04-23 — v1.11.0: Remove MoAI-ADK bootstrapper same-origin checksum verification
- 2026-03-14 — v1.9.11: Auto PATH configuration and CLI convenience aliases in setup.sh
- 2026-03-11 — v1.9.9: Fix conda command detection in non-interactive script context
- 2026-03-08 14:00 CDT — v1.9.7: Reorder tools (Claude Code before MoAI-ADK), add MoAI-ADK dependency check
- 2026-03-08 11:49 CDT — v1.9.6: Fix 3 Windows-specific bugs reported from live testing
- 2026-03-08 00:14 CST — v1.9.5: Comprehensive codebase review, version sync, error handling fixes, Windows parity
- 2026-02-19 — v1.9.2: oh-my-opencode installation bug fixes and feature improvements

---

## Session 2026-06-29

**Coding CLI used:** Claude Code CLI (claude-opus-4-8)

**Phase(s) worked on:**
- Phase 0: commit + push the previously-uncommitted v1.12.0 release
- v1.13.0: implement the deferred multi-expert-review findings (P1 security, P1 Windows parity, P2 cleanups)

**Concrete changes implemented:**
1. **Phase 0** — committed the entire uncommitted v1.12.0 working tree (Antigravity swap, --gemini purge, multi-expert fixes, log rotation, logs/ archive, .gitignore whitelist) as `4beae0a` and pushed to origin/master. The handoff had marked v1.12.0 "Completed" but it was code-complete and unpushed.
2. **CRLF normalization (`49b401c`)** — normalized `install_coding_tools.bat` from mixed `\r\r\n`/`\r\n` to uniform `\r\n` (2439 stray `\r` removed), proven content-safe by a byte-level identity assertion. This unblocked normal Edit-tool changes (no more Python byte-patchers) for the rest of the session.
3. **Consent-gated `-k` (`89d2ce0`, P1 security)** — added `:confirm_insecure_download` (y/N, default N → fails safe on closed stdin) before the insecure `curl -k` retry in all three `.bat` download paths (Claude/MoAI/Antigravity). `--ssl-no-revoke` first attempt unchanged.
4. **Authenticode tamper gate (`7931922`, P1 security)** — `:best_effort_verify_claude_signature` now returns non-zero on HashMismatch; both Claude install call sites delete the suspect `claude.exe` and `exit /b 1`. Valid passes; NotSigned/NotTrusted/UnknownError warn only. (A literal pre-exec gate on the installer is impossible: `install.cmd` is an unsignable `.cmd` and `claude.exe` doesn't exist until it runs — user accepted this framing.)
5. **Windows `upgrade` action state (`d83a1e5`, P1 parity)** — added `ACTION_UPGRADE=3` across default-action, toggle (outdated cycle skip→upgrade→remove→skip), `:print_tool` (cyan `[U]`), `:display_action_summary` ("Upgrade:" section), `:show_selected_tools` ([UPGRADE]), and the execution dispatch (ACT=3 → `:install_tool`, separate upgrade tally + "Upgraded:" result). Matches the `.sh` 4-state cycle. Sandbox/Playwright Windows port DEFERRED per user.
6. **oh-my-opencode provider flags (`f6cb6f9`, P2)** — added `--opencode-go=no --kimi-for-coding=no --vercel-ai-gateway=no` to `build_ohmy_flags_*` in both scripts, after verifying all three against the official install guide (per the wiki cli-flag-verification lesson).
7. **setup.bat docs (`acd95dd`, P2)** — header note + closing PATH hint documenting that the Windows deployer only copies the script (vs setup.sh auto-configuring PATH/aliases).
8. **Independent-review fixes (`ce3190d`)** — fixed the parity reviewer's one High finding: `resolve_addon_dependencies` auto-selected opencode-ai only for ACT=1 (install), missing ACT=3 (upgrade); now gates on install OR upgrade AND uses delayed `!op_inst!`/`!op_act!` (the prior parse-time `%var%` reads inside the block were stale). Plus the Medium/Low polish (dead-branch alignment to upgrade, state comment, menu hints in both scripts).
9. **Release bump (`a3902cc`)** — v1.12.0 → v1.13.0 across both installers + setup scripts + banners + version-history comments; v1.13.0 CHANGELOG and README change-log entries.

**Files/modules/functions touched:**
- `install_coding_tools.bat`: line-ending normalization; `:confirm_insecure_download`, `:download_claude_installer`, `:run_moai_installer`, `:download_antigravity_installer`, `:best_effort_verify_claude_signature` (+2 call sites), `ACTION_UPGRADE`, default-action, toggle handler, `:print_tool`, `:display_action_summary`, `:show_selected_tools`, install dispatch, `resolve_addon_dependencies`, `:build_ohmy_flags_auto`, headers/banner
- `install_coding_tools.sh`: `build_ohmy_flags_from_installed_tools`, menu hint, header/banner
- `setup.sh`, `setup.bat`, `README.md`, `CHANGELOG.md`, `PROJECT_HANDOFF.md`, `PROJECT_LOG.md`

**Key technical decisions and rationale:**
- Normalize CRLF FIRST as its own commit → all later `.bat` edits use the Edit tool cleanly instead of fragile byte-patchers.
- TLS policy = consent-gated `-k` (not fail-loud, not keep) per user: preserves corporate-proxy usability without silent MITM exposure.
- Authenticode = HashMismatch-only blocking per user: catches the one unambiguous tamper signal while never breaking unsigned/corporate-trust installs (safe regardless of Anthropic's signing status).
- Verified the 3 new oh-my-opencode flags against the official install guide before emitting (wiki lesson: don't trust package.json/assumptions for flag surface).
- Ran two independent fresh-context reviewers (expert-security + expert-devops) over `4beae0a..HEAD` before finalizing — caught a real auto-select regression I introduced.

**Problems encountered and resolutions:**
- WSL `cmd.exe` interop unavailable this session → could not run the `.bat` parse smoke test; relied on static checks (label resolution, paren balance unchanged, CRLF, content identity) + the two reviews; Windows runtime gate deferred to the user's live run.
- Parity reviewer found `resolve_addon_dependencies` missed the upgrade path (regression from adding ACT=3) AND a latent parse-time `%var%` read; fixed both with an install-OR-upgrade gate + delayed expansion.

**Items explicitly completed, resolved, or superseded:**
- Completed: v1.12.0 shipped (committed + pushed); v1.13.0 deferred-fix release (committed locally).
- Resolved (deferred review findings): Windows insecure TLS fallback (now consent-gated); Authenticode non-blocking (now a HashMismatch gate); `.sh`↔`.bat` 3-vs-4-state action divergence (added upgrade state); oh-my-opencode provider-flag incompleteness (all 9 emitted); `\r\r\n` normalization; setup.bat parity (documented).

**Verification performed:**
- `bash -n install_coding_tools.sh setup.sh` — pass.
- `.bat` uniform CRLF after every edit (lone `\n`=0, `\r\r\n`=0); CRLF normalization content-identical to prior commit.
- `.bat` label resolution: 0 unresolved; paren balance unchanged from baseline.
- Two independent reviews: security SHIP (no must-fix), parity SHIP WITH FIXES (all applied).
- v1.13.0 version consistency across all files; CHANGELOG descending, no dupes.

**Not yet verified (deferred to user live run):**
- Antigravity install + `agy --version` output on Linux/WSL and Windows.
- Windows `.bat` runtime parse + install/upgrade/remove flows; the new upgrade display; consent prompt + Authenticode gate in their trigger paths.
- `claude.exe` normal Authenticode status (gates the optional Finding-3 hardening).

**Push status:** v1.13.0 (8 commits) committed locally, NOT pushed — held pending live-test validation + explicit user go-ahead.

---

## Session 2026-06-27 21:06 CDT

**Coding CLI used:** Claude Code CLI (claude-opus-4-7)

**Phase(s) worked on:**
- v1.12.0: Replace retired Google Gemini CLI with Antigravity CLI

**Concrete changes implemented:**
1. `install_coding_tools.sh`:
   - Added `readonly ANTIGRAVITY_INSTALL_URL="https://antigravity.google/cli/install.sh"` next to the Claude/MoAI install URLs.
   - Replaced TOOLS entry index 4 (`@google/gemini-cli|npm|...`) in-place with `antigravity|native|antigravity|Antigravity CLI`.
   - Added `run_antigravity_installer()` (mirrors `run_claude_installer`: curl to temp, `bash` it; notes Antigravity's own SHA-512 manifest verification).
   - Added `antigravity` branch in `get_installed_native_version()` (`agy --version`).
   - Added `antigravity` branch in `install_tool()` native case (install/update via `run_antigravity_installer` + `~/.local/bin` PATH note).
   - Added `antigravity` branch in `remove_tool()` native case (`rm -f ~/.local/bin/agy`).
   - Purged oh-my-opencode gemini auto-detect: removed dead `OHMY_REQUIRED_FLAGS` constant and the `command -v gemini` block; replaced with static `flags="$flags --gemini=no"` (oh-my-opencode v3.7.4+ requires the flag).
   - Header + version-history comment bumped to v1.12.0.
2. `install_coding_tools.bat` (byte-safe Python patch preserving `\r\r\n`; 16 asserted-unique replacements):
   - Added `set "ANTIGRAVITY_INSTALL_URL=https://antigravity.google/cli/install.cmd"`.
   - Replaced TOOL_4 + NAME_4/MGR_4(native)/PKG_4(antigravity)/DESC_4/BIN_4(agy); VERARG_4 already `--version`.
   - Added antigravity branch in `:get_installed_native_version` (`where agy` → `:get_semver_from_command "agy" "--version"`).
   - Wired `:install_tool_native` dispatch: `if /I "!pkg!"=="antigravity" goto install_tool_antigravity`.
   - Added `:install_tool_antigravity` (install/update; downloads `aginstall.cmd` and runs via `:run_cmd_script_isolated`) and `:download_antigravity_installer` (curl `--ssl-no-revoke` then `-k` fallback, mirroring `:download_claude_installer`).
   - Added antigravity branch in `:remove_tool` native case (delete `%USERPROFILE%\.local\bin\agy.exe` and `…\agy`).
   - Purged `:build_ohmy_flags_auto` gemini auto-detect; static `--gemini=no` retained.
   - Header REM block + banner bumped to v1.12.0.
3. `setup.sh` / `setup.bat`: version comment 1.11.0 → 1.12.0.
4. `README.md`: header v1.12.0, Last Modified June 27 2026, Supported Tools table Gemini row → Antigravity row, prepended v1.12.0 changelog entry.
5. `CHANGELOG.md`: added `## [1.12.0] - 2026-06-27` (Added: Antigravity CLI native installer; Removed: Gemini CLI).
6. `PROJECT_HANDOFF.md`: full refresh to v1.12.0 current truth.

**Files/modules/functions touched:**
- `install_coding_tools.sh`: `ANTIGRAVITY_INSTALL_URL`, TOOLS array, `run_antigravity_installer`, `get_installed_native_version`, `install_tool`, `remove_tool`, `build_ohmy_flags_from_installed_tools`, header/banner
- `install_coding_tools.bat`: `ANTIGRAVITY_INSTALL_URL`, TOOL_4 block, `:get_installed_native_version`, `:install_tool_native`, `:install_tool_antigravity`, `:download_antigravity_installer`, `:remove_tool`, `:build_ohmy_flags_auto`, header/banner
- `setup.sh`, `setup.bat`, `README.md`, `CHANGELOG.md`, `PROJECT_HANDOFF.md`, `PROJECT_LOG.md`

**Key technical decisions and rationale:**
- Antigravity CLI is a native curl-bootstrapper tool (binary `agy` → `~/.local/bin`), NOT npm. So it follows the Claude Code / MoAI-ADK native-installer pattern, not the Gemini npm-array pattern. Verified from the official `google-antigravity/antigravity-cli` repo and the live `https://antigravity.google/cli/install.sh` (which itself does SHA-512 manifest verification — so no bootstrapper checksum, consistent with v1.11.0's same-origin-checksum removal philosophy).
- Chose to replace Gemini in-place at tool index 4 (rather than regroup natives) to minimize churn in the fragile `\r\r\n` `.bat`.
- oh-my-opencode purge: the v1.9.2 session log records that oh-my-opencode v3.7.4+ *requires* the `--gemini` argument. Removing it outright would break oh-my-opencode installation, so the dynamic `command -v gemini`/`where gemini` detection was purged but `--gemini=no` is emitted statically. Flagged as a partial-purge caveat.
- `.bat` edit done via latin-1 round-trip Python patcher (`/tmp` write blocked by sandbox → wrote scratch `_bat_patch_v1120.py` in-repo, deleted after). Each of 16 replacements asserted to match exactly once; the script aborted without writing on the first attempt because the `:run_cmd_script_isolated` region (added v1.10.0) uses single `\r\n`, not `\r\r\n` — corrected the anchor and re-ran successfully.
- Version: v1.12.0 (minor bump; removing a menu tool is breaking, but project convention uses minor bumps for tool-list changes).

**Problems encountered and resolutions:**
- `install_coding_tools.bat` uses `\r\r\n` (double-CR+LF) line endings; the Edit tool cannot match it. Solved with a byte-safe Python patcher (latin-1 decode → exact substring replace → latin-1 encode).
- Initial patcher run failed R12: the `REM Run third-party batch installers … so they cannot` line is `\r\n`-terminated (that whole `:run_cmd_script_isolated` block from v1.10.0 is single-CRLF, unlike the surrounding `\r\r\n`). Fixed the anchor terminator and re-ran; file on disk was never partially written (patcher writes only after all asserts pass).

**Items explicitly completed, resolved, or superseded in this session:**
- Completed: v1.12.0 — Antigravity CLI added, Gemini CLI removed, oh-my-opencode gemini auto-detect purged, version bump + docs.
- Resolved: Gemini CLI retired; installer now offers its Antigravity CLI replacement.

**Verification performed:**
- `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` — all pass.
- `file install_coding_tools.bat setup.bat` — CRLF/CR line endings preserved.
- `grep -rn 'gemini-cli\|@google/gemini' install_coding_tools.{sh,bat}` — zero matches.
- `grep antigravity/agy/ANTIGRAVITY_INSTALL_URL` — present at all expected sites in both installers.
- TOOLS_COUNT=7 (.bat) and 7-entry TOOLS array (.sh) confirmed.
- Version v1.12.0 consistent across all files; CHANGELOG descending with no duplicates.
- `./install_coding_tools.sh --help` exits 0.

**Not yet verified (deferred to user):** live `agy` install on Linux/WSL + Windows; `agy --version` actual output.

**Follow-up (same session, later turn) — `--gemini=no` full purge:**
- User asked to double-check oh-my-opencode's latest version re: the retired Gemini CLI. npm-registry audit (`https://registry.npmjs.org/oh-my-opencode`) confirmed: latest `4.13.0` (published 2026-06-22); CLI binary (`bin/oh-my-opencode.js`) first added in `v2.5.0` (2025-12-23); product rebranded to `oh-my-openagent` at `v4.0.0` (2026-05-07); install model is interactive or `--platform=opencode|codex|both`. **No `--gemini` install flag exists in any published version.** The v1.9.2 session log's "oh-my-opencode v3.7.4+ requires `--claude`/`--gemini`/`--copilot` flags" claim was incorrect.
- Conclusion: the static `--gemini=no` retained earlier this session is vestigial and actively harmful — passing an unknown flag to oh-my-opencode v4.x's commander-based CLI risks erroring out and breaking the install.
- User chose "Purge `--gemini=no` only" (targeted fix; sibling `--claude`/`--openai`/`--copilot` provider flags left for a separate follow-up).
- Changes: removed the static `--gemini=no` line + its rationale comment from `install_coding_tools.sh` (`build_ohmy_flags_from_installed_tools`) and `install_coding_tools.bat` (`:build_ohmy_flags_auto`, via byte-safe Python patcher for the `\r\r\n` endings); updated the v1.12.0 changelog comments in both script headers; rewrote the `:build_ohmy_flags_auto` header REM to drop the false "v3.7.4+ requires" claim; updated README v1.12.0 "Gemini CLI removed" bullet and CHANGELOG `[1.12.0]` Removed entry; flipped the PROJECT_HANDOFF risk row from Mitigated→Resolved and added a follow-up Outstanding item about the broader provider-flag staleness.
- Verified: `bash -n install_coding_tools.sh` PASS; `.bat` line endings preserved (`file` still CRLF/CR); zero functional `--gemini=no` flag code remains (grep hits are all in changelog comments describing the purge).
- Open follow-up (superseded by the multi-expert review below): the remaining `--claude`/`--openai`/`--copilot`/`--opencode-zen`/`--zai-coding-plan` flags in `build_ohmy_flags_*` — the review confirmed these ARE documented and valid, NOT vestigial.

**Follow-up (same session) — multi-expert review + high-confidence fixes:**
- User requested a team review of the whole project (logic vs. official docs, Antigravity correctness, prerequisites, with emphasis on Windows `.bat` ↔ Linux `.sh` parity). Spawned 4 parallel read-only agents: official-docs verifier (general-purpose + web), installer-logic/parity reviewer (expert-devops), security reviewer (expert-security), independent synthesis (evaluator-active).
- **Key conflict resolved:** the docs-verifier fetched the official oh-my-openagent install guide and found `--gemini=yes|no` (and the sibling provider flags) ARE documented — disproving the earlier "never existed" rationale (which was based on an npm-only audit; `package.json` doesn't list CLI flags). Corrected the rationale across CHANGELOG, README, PROJECT_HANDOFF, PROJECT_LOG, and both script headers. The `--gemini=no` removal itself stands (it's the redundant default; Gemini CLI retired).
- **Applied high-confidence fixes (all verified against code first):**
  - **P0** `.bat` MoAI-ADK Claude prereq: `where claude >/dev/null 2>nul` → `>nul 2>nul`. The Unix `/dev/null` on Windows silently defeated the prerequisite check (empirically confirmed). (logic-reviewer F1)
  - **P1** `.sh` menu banner `v1.11.0` → `v1.12.0` (parity regression missed by the v1.12.0 bump). (logic-reviewer F2, evaluator #3)
  - **P1** `.bat` removed duplicate `exit /b 0` at end of `:build_ohmy_flags_auto`. (logic-reviewer F7)
  - **P1** `.bat` removed `npm install -g oh-my-opencode@latest` upgrade step — official docs prohibit global install; `.sh` doesn't do it. (docs-verifier F3)
  - **P1** `.bat` Antigravity remove: added post-`del` existence checks (was unconditionally `exit /b 0`). (logic-reviewer F5, evaluator #4)
  - **P1** `.sh` Antigravity install: added `get_installed_native_version` post-install verify mirroring MoAI's `after_version` pattern. (evaluator #4)
  - **P2** `.bat` deleted dead `:get_installed_uv_version2` + `:get_installed_npm_version2` (zero callers; anchor-slice patcher). (logic-reviewer F6)
  - **P2** `.sh` deleted dead `validate_removal()` (zero callers). (logic-reviewer F18)
- **Verification:** `bash -n` PASS; `.bat` endings preserved (CRLF/CR); all 14 grep/structure checks pass; temp patchers deleted.
- **Deferred to report (lower confidence or policy/product decisions):** Windows `curl -k` + `--ssl-no-revoke` insecure fallback (security S1/S2 — real MITM risk, but removing may break corporate-proxy users; needs a product call); Authenticode check runs after execution and doesn't block (S3); dangerous aliases `ccdd`/`codexD` (S8 — deliberate feature); `.sh`↔`.bat` state-machine divergence 4-vs-3 actions (logic F3 — UX); Claude Code sandbox/Playwright setup missing on Windows (logic F4 — large feature gap); `agy --version` flag unverified (logic F9 — needs the live binary); setup.bat parity gap (logic F13); `\r\r\n` whole-file normalization (logic F15/sec S10 — dedicated commit); Codex/OpenCode use npm fallback rather than primary bootstrapper (docs F1/F2 — works, just not "recommended").

**Follow-up (same session) — `.bat` runtime smoke test (cmd.exe via WSL interop):**
- User asked whether the `.bat` is "completely functional" / thoroughly tested. Answer: **no** — but obtained new runtime evidence.
- Ran `cmd.exe /c install_coding_tools.bat` (stdin closed, timeout). **First run was invalid**: cmd.exe rejected the WSL UNC cwd, defaulted to `C:\Windows`, and executed a **stale PATH-deployed v1.11.0 copy** (banner showed v1.11.0, slot 4 "Google Gemini CLI"). Side finding: a stale v1.11.0 `install_coding_tools.bat` is deployed on the Windows PATH; the next `setup.bat` run refreshes it.
- Re-ran against the **actual working-tree file** (copied to `%TEMP%`, invoked by absolute Windows path): cmd.exe **parsed all 2500 lines and ran startup → prefetch → menu render** with no syntax error; banner read **v1.12.0**, slot 4 read **"Antigravity CLI"**; exited cleanly on closed stdin. Confirms the file is syntactically valid and the byte-safe review patches didn't corrupt parseability.
- **Still NOT exercised:** install/update/remove execution flows for any tool; the specific fixes in their trigger paths (MoAI prereq fires only on MoAI install; Antigravity verify only on Antigravity install/remove; oh-my-opencode npm-removal only on upgrade); `agy --version` correctness (Antigravity not installed here → showed "Unknown").
- User declined a live Antigravity install test (mutates Windows env); stopped here. All findings recorded in PROJECT_HANDOFF §6.

---

---

## Session 2026-04-23

**Coding CLI used:** Claude Code CLI (claude-opus-4-7)

**Phase(s) worked on:**
- v1.11.0: Remove MoAI-ADK bootstrapper same-origin checksum verification

**Concrete changes implemented:**
1. `install_coding_tools.sh`:
   - Removed `MOAI_CHECKSUM_URL` constant (previously at line 74).
   - Removed `fetch_moai_checksum()` function (GitHub API base64-decode logic).
   - Simplified `run_moai_installer()` to drop the fetch/verify block; inline comment explains that TLS to GitHub + MoAI-ADK's own downstream binary-tarball SHA-256 verification cover the real integrity concern.
   - Header comment block updated (removed "SHA-256 verification for MoAI-ADK installer" bullets).
2. `install_coding_tools.bat` (byte-safe Python patch to preserve `\r\r\n` line endings):
   - Removed `MOAI_CHECKSUM_URL` variable (previously at line 86).
   - Removed entire `:fetch_moai_checksum` label (~19 lines, including the PowerShell base64 + regex parser).
   - Removed the `call :fetch_moai_checksum` + `if defined MOAI_SHA256 ... verify_file_sha256 ... ) else ( ... proceeding without verification )` block from `:run_moai_installer`.
   - Updated REM header block: replaced "Security improvements (v1.7.12)" bullets that advertised "Dynamic checksum fetching for Claude and MoAI installers" and "SHA-256 verification for MoAI-ADK installer".
3. Version bump v1.10.0 -> v1.11.0:
   - `install_coding_tools.sh` header (line 5), version-history comment (line 18 adds v1.11.0 entry), banner `Agentic Coders CLI Installer v1.11.0`.
   - `install_coding_tools.bat` header (line 6), version-history REM block, banner at `%BOLD%v1.11.0%NC%`.
   - `setup.sh` and `setup.bat` version comment lines.
4. `CHANGELOG.md`: Added `## [1.11.0] - 2026-04-23` entry under "Removed" explaining the three defects (always-404, same-origin theater, redundant-with-downstream).
5. `README.md`: Updated header version to v1.11.0, `Last Modified` to April 23, 2026, prepended v1.11.0 changelog entry.
6. `PROJECT_HANDOFF.md`: Full refresh — was stale at v1.9.11 state (2026-03-14). Now reflects v1.9.12 / v1.9.13 ×2 / v1.10.0 / v1.11.0 truth, verification status, and records the reconciliation deficit note about missing intermediate log sessions.

**Files/modules/functions touched:**
- `install_coding_tools.sh`: header, `MOAI_CHECKSUM_URL`, `fetch_moai_checksum`, `run_moai_installer`, banner string
- `install_coding_tools.bat`: header, `MOAI_CHECKSUM_URL`, `:fetch_moai_checksum`, `:run_moai_installer`, banner string
- `setup.sh`, `setup.bat`: version comment
- `README.md`, `CHANGELOG.md`: documentation
- `PROJECT_HANDOFF.md`, `PROJECT_LOG.md`: state tracking

**Key technical decisions and rationale:**
- The upstream `modu-ai/moai-adk` repo does NOT publish `install.sh.sha256` or `install.ps1.sha256` (verified via `curl` returning HTTP 404 on both the `raw.githubusercontent.com/.../main/install.sh.sha256` path and the `api.github.com/repos/.../contents/install.sh.sha256` API endpoint). The feature was broken on every invocation since it was introduced.
- Even if the hash file existed, both bootstrapper and hash would live at the same trust root. Same-origin checksum verification adds no meaningful integrity guarantee (an attacker with write access to the repo could trivially tamper with both). Meaningful hash-based integrity requires an independent trust anchor (separate signing server, pinned hash, GPG-signed tag, etc.) — we chose not to implement Option B (pinned commit SHA) at this time.
- MoAI-ADK's own installer continues to verify the downloaded binary tarball (`moai-adk_<ver>_<platform>.tar.gz`) against a SHA-256 committed to its release metadata, visible in the run output as `[INFO] Verifying checksum... [SUCCESS] Checksum verified`. That verification, not the bootstrapper hash, is what actually protects the installed artifact.
- Net UX improvement: two spurious `[WARNING]` lines per install are removed; no loss of security.

**Problems encountered and resolutions:**
- `install_coding_tools.bat` uses `\r\r\n` (double-CR + LF) line endings. Used a byte-safe Python script inside the project directory to perform the surgical replacements while preserving the existing line-ending convention.

**Items explicitly completed, resolved, or superseded in this session:**
- Completed: v1.11.0 removal of MoAI-ADK bootstrapper same-origin checksum verification
- Resolved: "Failed to fetch MoAI checksum from GitHub API, skipping verification" / "MoAI-ADK installer checksum not available, proceeding without verification" spurious warnings on every install

**Verification performed:**
- `grep -rn 'MOAI_CHECKSUM_URL\|fetch_moai_checksum\|MOAI_SHA256'` across `install_coding_tools.{sh,bat}` — zero matches.
- `file install_coding_tools.bat setup.bat` — confirmed CRLF / CR line terminators preserved after byte-safe edit.
- Version string grep across all 4 script files — all show v1.11.0 in banners and headers.
- `CHANGELOG.md` descending-order + no-duplicate sanity check.

---

---

## Session 2026-03-14

**Coding CLI used:** Claude Code CLI (claude-opus-4-6)

**Phase(s) worked on:**
- v1.9.11: Auto PATH configuration and CLI convenience aliases in setup.sh
- v1.9.10: Fix tput crash on terminals with missing terminfo entries

**Concrete changes implemented:**
1. Added `tput colors >/dev/null 2>&1` probe to the color initialization guard in `setup.sh` so that when `tput` cannot query the terminal (missing terminfo), the script falls through to empty (no-color) strings instead of aborting

**Files/modules/functions touched:**
- `setup.sh`: Added `tput colors` probe to line 46 guard, version bump to v1.9.10
- `install_coding_tools.sh`: Version bump to v1.9.10 (header, version history comment, banner)
- `install_coding_tools.bat`: Version bump to v1.9.10 (3 locations, binary-safe Python edit)
- `setup.bat`: Version bump to v1.9.10
- `README.md`: Version bump, date update, added v1.9.10 changelog entry
- `CHANGELOG.md`: Added v1.9.10 entry
- `PROJECT_HANDOFF.md`: Full refresh to v1.9.10 state
- `PROJECT_LOG.md`: This entry

**Key technical decisions and rationale:**
- Root cause: `setup.sh` uses `set -euo pipefail`. When `tput setaf 1` fails (unknown terminal type), the entire script aborts. The existing guard checked `-t 1` (stdout is a terminal) and `command -v tput` (tput exists), but not whether tput can actually query the current terminal.
- Fix: `tput colors` is the lightest tput query that exercises the terminfo lookup. If it fails, terminal info is unavailable and all tput calls would fail, so we skip to empty strings.
- `install_coding_tools.sh` is unaffected because it uses raw ANSI escape codes, not `tput`.

**Problems encountered and resolutions:**
- User reported "tput: unknown terminal xterm" on fresh Ubuntu 24.04. Likely missing `ncurses-term` package (provides extended terminfo entries). Fix makes the script resilient regardless.

**v1.9.11 changes (same session):**
1. `setup.sh` now always runs `configure_path` (previously required `--configure-path` flag) — adds `~/.local/bin` to PATH in shell config if not already present
2. Added `configure_aliases()` function that idempotently adds three CLI aliases to shell config:
   - `ccdd` -> `claude --dangerously-skip-permissions`
   - `claudeD` -> `claude --dangerously-skip-permissions`
   - `codexD` -> `codex --dangerously-bypass-approvals-and-sandbox`
3. Both PATH and alias configuration are non-fatal (`|| warning`) to avoid aborting the install
4. Updated help text to document the new automatic behavior
5. `--configure-path` retained as legacy no-op

**Items explicitly completed, resolved, or superseded in this session:**
- Completed: v1.9.10 tput crash fix in setup.sh
- Completed: v1.9.11 auto PATH + CLI aliases in setup.sh

**Verification performed:**
- `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` — all pass
- Version consistency across all 6 files — all show v1.9.11
- CHANGELOG ordering — no duplicates, correct descending order

---

---

## Session 2026-03-11

**Coding CLI used:** Claude Code CLI (claude-opus-4-6)

**Phase(s) worked on:**
- v1.9.9: Fix conda command detection in non-interactive script context

**Concrete changes implemented:**
1. Added `resolve_conda_cmd()` function that finds conda binary via 4-tier fallback: `command -v conda` → `$CONDA_EXE` → `$CONDA_PREFIX` parent paths → common installation paths (`~/miniconda3`, `~/anaconda3`, `~/miniforge3`, etc.)
2. Added `CONDA_CMD` global variable, initialized in `main()` after `check_conda_environment`
3. Replaced all bare `conda` command invocations with `"$CONDA_CMD"` (6 call sites)
4. Replaced all `command -v conda` checks with `[[ -z "${CONDA_CMD:-}" ]]` (3 check sites)
5. Updated `get_conda_root()` to use `$CONDA_CMD` with fallback to bare `conda` for early calls
6. Added `miniforge3` to fallback detection paths

**Files/modules/functions touched:**
- `install_coding_tools.sh`:
  - Added `resolve_conda_cmd()` function (after `get_conda_root()`)
  - Added `CONDA_CMD=""` global declaration (line 100)
  - Updated `get_conda_root()` to use `$CONDA_CMD`
  - Updated `install_gh_cli()` to use `$CONDA_CMD`
  - Updated `install_jq()` to use `$CONDA_CMD`
  - Updated `ensure_npm_prerequisite()` to use `$CONDA_CMD` (4 conda calls)
  - Updated `main()` to initialize `CONDA_CMD` after conda environment check
  - Version bump to v1.9.9
- `install_coding_tools.bat`: Version bump to v1.9.9 (3 locations, binary-safe Python edit)
- `setup.sh`: Version bump to v1.9.9
- `setup.bat`: Version bump to v1.9.9
- `README.md`: Version bump, date update, added v1.9.9 changelog entry
- `CHANGELOG.md`: Added v1.9.9 entry
- `PROJECT_HANDOFF.md`: Full refresh to v1.9.9 state
- `PROJECT_LOG.md`: This entry

**Key technical decisions and rationale:**
- Root cause: `conda init bash` sets up conda as a shell function in `.bashrc`. When running `./install_coding_tools.sh` as a child process, `.bashrc` is not sourced (non-interactive bash), so the shell function is unavailable. However, `CONDA_PREFIX`, `CONDA_DEFAULT_ENV`, and `CONDA_EXE` are exported env vars that survive to child processes.
- `CONDA_EXE` is the most reliable fallback (set by conda activation to the actual binary path)
- `$CONDA_PREFIX` parent path derivation handles both base and named envs (strips `/envs/name` suffix)
- Common paths include `miniforge3` which was missing from previous fallbacks
- Global `CONDA_CMD` is initialized once and reused, avoiding repeated resolution

**Problems encountered and resolutions:**
- User reported "conda not found" on fresh Ubuntu 24.04 despite active conda env `(openai)`
  - Root cause: conda shell function not inherited by script subprocess
  - Resolution: `resolve_conda_cmd()` with multi-tier fallback

**Items explicitly completed, resolved, or superseded in this session:**
- Completed: v1.9.9 conda detection fix
- Resolved: "conda not found" error on fresh installs with active conda environment

**Verification performed:**
- `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` — all pass
- `file install_coding_tools.bat setup.bat` — CRLF confirmed
- Version consistency across all 6 files — all show v1.9.9
- `grep '^## \[' CHANGELOG.md` — no duplicates, correct descending order
- No bare `conda install/info/create` calls remain outside `resolve_conda_cmd` and `get_conda_root` fallback
- All `$CONDA_CMD` usage sites verified

---

---

## Session 2026-03-08 14:00 CDT

**Coding CLI used:** Claude Code CLI (claude-opus-4-6)

**Phase(s) worked on:**
- v1.9.7: Reorder tools (Claude Code before MoAI-ADK), add MoAI-ADK dependency check

**Concrete changes implemented:**
1. Swapped tool order so Claude Code CLI is listed before MoAI-ADK in both .sh and .bat installers (Claude Code is a prerequisite for MoAI-ADK)
2. Added dependency check: MoAI-ADK installation now requires `claude` CLI to be on PATH; shows error and aborts if missing

**Files/modules/functions touched:**
- `install_coding_tools.sh`:
  - Swapped first two entries in TOOLS array (claude-code now index 0, moai-adk now index 1)
  - Added `command -v claude` check in moai-adk installation elif branch
  - Version bump to v1.9.7
- `install_coding_tools.bat`:
  - Swapped TOOL_1/TOOL_2 definitions and all NAME/MGR/PKG/DESC/BIN/VERARG property blocks
  - Added `where claude >nul 2>nul` check at top of `:install_tool_moai`
  - Version bump to v1.9.7
- `setup.sh`: Version bump to v1.9.7
- `setup.bat`: Version bump to v1.9.7
- `README.md`: Version bump, added v1.9.7 changelog entry
- `CHANGELOG.md`: Added v1.9.7 entry
- `PROJECT_HANDOFF.md`: Full refresh to v1.9.7 state
- `PROJECT_LOG.md`: This entry

**Key technical decisions and rationale:**
- Tool reorder ensures Claude Code installs first when user selects both tools (npm prepends as tool #1, so menu order is: npm, claude-code, moai-adk, ...)
- Dependency check uses `command -v claude` (.sh) and `where claude` (.bat) — lightweight PATH checks without invoking the CLI
- Check returns error immediately rather than attempting partial install that would fail later

**Problems encountered and resolutions:**
- `.bat` file double-CR line endings required Python binary-safe scripts for modifications (same pattern as v1.9.6)

**Items explicitly completed, resolved, or superseded in this session:**
- Completed: Tool reorder in both installers
- Completed: MoAI-ADK dependency check in both installers
- Completed: v1.9.7 version bump across all files

**Verification performed:**
- `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` — all pass
- Version consistency across all 6 files — all show v1.9.7
- CHANGELOG ordering — no duplicates, correct descending order
- Tool order verified in both .sh and .bat
- Dependency check code reviewed in both .sh and .bat

---

---

## Session 2026-03-08 11:49 CDT

**Coding CLI used:** Claude Code CLI (claude-opus-4-6)

**Phase(s) worked on:**
- v1.9.6: Fix 3 Windows-specific bugs reported from live testing

**Concrete changes implemented:**
1. Fixed action summary displaying "2nst", "3nst", "4nst" instead of version strings — root cause: `%%inst%%` double-indirection inside `for /L %%i` loops caused `%%i` in `%%inst%%` to match the for-loop variable, replacing the version with the index + "nst"
2. Added curl SSL certificate fallback for Windows — first tries `--ssl-no-revoke`, then falls back to `-k` (insecure) with warning. Applied to both MoAI-ADK and Claude Code installer downloads
3. Added error suppression to `check_npm_claude_code` — wrapped `resolve_conda_npm` call and `for /f` npm check block with `2>nul` to suppress "filename, directory name, or volume label syntax is incorrect" error

**Files/modules/functions touched:**
- `install_coding_tools.bat`:
  - Removed 2 broken `call set "inst=%%inst%%"` lines inside action summary `for /L %%i` loops (lines ~1735, ~1752)
  - Added `--ssl-no-revoke` and `-k` fallback to curl in `:run_moai_installer` and `:download_claude_installer`
  - Added `2>nul` to `call :resolve_conda_npm` and wrapped `for /f` block in `:check_npm_claude_code`
  - Version bump to v1.9.6
- `install_coding_tools.sh`: Version bump to v1.9.6
- `setup.sh`: Version bump to v1.9.6
- `setup.bat`: Version bump to v1.9.6
- `README.md`: Version bump, added v1.9.6 changelog entry
- `CHANGELOG.md`: Added v1.9.6 entry
- `PROJECT_HANDOFF.md`: Full refresh to v1.9.6 state
- `PROJECT_LOG.md`: This entry

**Key technical decisions and rationale:**
- Removed double-indirection `call set "inst=%%inst%%"` rather than renaming the variable, because the first `call set "inst=%%INST_%%i%%"` already resolves correctly (%%I uppercase doesn't collide with %%i lowercase for-variable)
- curl SSL: `--ssl-no-revoke` is the standard Windows fix for CRL issues; `-k` is a last-resort fallback with user-visible warning
- Error suppression: `2>nul` at the right scope captures all stderr leakage from npm.cmd and underlying cmd.exe path resolution

**Problems encountered and resolutions:**
- `.bat` file has `\r\r\n` (double CR) line endings — Edit tool string matching fails. Used Python binary-safe scripts for all modifications.

**Items explicitly completed, resolved, or superseded in this session:**
- Resolved: Action summary "2nst" display bug
- Resolved: curl SSL certificate failure for MoAI-ADK on Windows
- Resolved: "filename, directory name" error during Claude Code installation on Windows

**Verification performed:**
- `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` — all pass
- `file install_coding_tools.bat setup.bat` — CRLF confirmed
- `grep` version consistency across all 6 files — all show v1.9.6
- `grep '^## \[' CHANGELOG.md` — no duplicates, correct descending order
- Confirmed 0 indented `%%inst%%` lines remain in .bat
- Confirmed `--ssl-no-revoke` present in both curl commands
- Confirmed `2>nul` present in check_npm_claude_code
- Git commit `1566742` pushed to origin/master

---

---

## Session 2026-03-08 00:14 CST

**Coding CLI used:** Claude Code CLI (claude-opus-4-6)

**Phase(s) worked on:**
- v1.9.5: Comprehensive codebase review, version sync, error handling fixes, Windows parity, documentation cleanup

**Concrete changes implemented:**
1. Fixed version display: `.sh` banner was showing v1.9.3, `.bat` banner was showing v1.8.1 — both now show v1.9.5
2. Synced version strings across all 6 files (install_coding_tools.sh, install_coding_tools.bat, setup.sh, setup.bat, README.md, CHANGELOG.md)
3. Fixed missing error checks on `remove_oh_my_opencode` calls during addon upgrade (line 2045) and opencode-ai removal (line 2293) — now warns on failure instead of silently continuing
4. Added GitHub CLI auto-installation (`:install_gh_cli`) and auth reminder (`:show_gh_auth_reminder`) to Windows `.bat` installer for moai-adk parity with Unix `.sh`
5. Cleaned up CHANGELOG.md: merged duplicate v1.7.20 entries (gh CLI was duplicated between v1.7.21 and v1.7.20), merged duplicate v1.7.0 entries, moved v1.7.1 to correct position before v1.7.0
6. Added oh-my-opencode to README.md Supported Tools table (was missing)
7. Added v1.9.4 and v1.9.5 changelog entries to README.md (v1.9.4 entry was missing)

**Files/modules/functions touched:**
- `install_coding_tools.sh`:
  - Updated version header and banner to v1.9.5
  - Added error checking for `remove_oh_my_opencode` calls at 2 locations (lines 2045, 2293)
- `install_coding_tools.bat`:
  - Updated version header and banner to v1.9.5
  - Added `:install_gh_cli` function (GitHub CLI auto-install via conda-forge)
  - Added `:show_gh_auth_reminder` function
  - Added calls in `:install_tool_moai` section
- `setup.sh`: Version bump to 1.9.5
- `setup.bat`: Version bump to 1.9.5
- `README.md`: Version bump, date update, added oh-my-opencode to tools table, added v1.9.4/v1.9.5 changelog entries
- `CHANGELOG.md`: Added v1.9.5 entry, merged duplicate v1.7.20 and v1.7.0 entries, fixed v1.7.1 ordering
- `PROJECT_HANDOFF.md`: Full refresh to v1.9.5 state
- `PROJECT_LOG.md`: This entry

**Key technical decisions and rationale:**
- Error handling fix uses warning (not error) when `remove_oh_my_opencode` fails during upgrade, because the subsequent reinstall may still succeed
- gh CLI install on Windows follows same pattern as Unix: conda-forge, non-blocking on failure
- CHANGELOG duplicate v1.7.20: Kept the line-ending fix entry (the real v1.7.20), removed the duplicate gh CLI entry (already covered by v1.7.21)
- CHANGELOG duplicate v1.7.0: Merged into single entry with Added, Changed, Security, and Fixed sections

**Problems encountered and resolutions:**
- `.bat` file has `\r\r\n` line endings (double CR), which caused Edit tool string matching to fail. Used Python script for binary-safe insertion.

**Items explicitly completed, resolved, or superseded in this session:**
- Completed: v1.9.5 release — version sync, error handling, Windows parity, documentation cleanup
- Resolved: Banner version mismatch (.sh v1.9.3, .bat v1.8.1)
- Resolved: Windows missing gh CLI auto-install for moai-adk
- Resolved: CHANGELOG duplicate entries (v1.7.20, v1.7.0) and wrong ordering (v1.7.1)
- Resolved: oh-my-opencode missing from README Supported Tools table

**Verification performed:**
- `bash -n install_coding_tools.sh setup.sh auto_install_coding_tools` — all pass
- `file install_coding_tools.bat setup.bat` — CRLF confirmed
- `grep` version consistency across all files — all show v1.9.5
- `grep '^## \[' CHANGELOG.md` — no duplicates, correct descending order
- `./install_coding_tools.sh --help` and `./setup.sh --help` — output correct
- Code review of error handling fixes and gh CLI function insertion

---

---

## Session 2026-02-19

**Coding CLI used:** Claude Code CLI (glm-5)

**Phase(s) worked on:**
- v1.9.2: oh-my-opencode installation bug fixes and feature improvements

**Concrete changes implemented:**
1. Fixed return codes in `install_oh_my_opencode()` and `remove_oh_my_opencode()` - now return 1 on failure instead of silently returning 0
2. Fixed exit codes in Windows batch file `:install_oh_my_opencode` and `:remove_oh_my_opencode`
3. Removed hardcoded `--XXX=no` flags - oh-my-opencode now auto-detects installed tools
4. Added config preservation on update - existing `oh-my-opencode.json` is preserved during reinstall
5. Added interactive provider prompt for new installations (`prompt_ohmy_providers()`)

**Files/modules/functions touched:**
- `install_coding_tools.sh`:
  - Changed `oh_my_opencode_flags` from all `--XXX=no` to just `--no-tui`
  - Added `prompt_ohmy_providers()` function for interactive provider selection
  - Modified `install_oh_my_opencode()` to preserve config on update and prompt on fresh install
  - Added `return 1` after warning logs in both install and remove functions
  - Version bump to v1.9.2
- `install_coding_tools.bat`:
  - Changed `OHMY_FLAGS` from all `--XXX=no` to just `--no-tui`
  - Added `:prompt_ohmy_providers` function for interactive provider selection
  - Modified `:install_oh_my_opencode` to preserve config and prompt on fresh install
  - Added `exit /b 1` after warning logs
  - Fixed caller code to propagate exit codes
  - Version bump to v1.9.2
- `README.md`: Version bump to v1.9.2, added changelog entry
- `CHANGELOG.md`: Added v1.9.2 entry
- `PROJECT_HANDOFF.md`: Updated current state to v1.9.2
- `PROJECT_LOG.md`: This entry

**Key technical decisions and rationale:**
- Return code fix: Silent failures were causing "Upgraded: 1" even when installation failed
- Auto-detect: Hardcoded `--XXX=no` flags were disabling all optional plugins including ones user actually uses
- Config preservation: Reinstall was potentially overwriting user's existing oh-my-opencode.json configuration
- Interactive prompt: Gives users control over which providers to configure on fresh installs

**Problems encountered and resolutions:**
- User reported oh-my-opencode upgrade showed success but version remained old
  - Root cause 1: `install_oh_my_opencode()` returned 0 even on failure (no return statement in else branch)
  - Root cause 2: Hardcoded flags disabled all providers, so installer ran but didn't configure anything useful
  - Resolution: Added proper return codes and removed restrictive flags

**Items completed in this session:**
- v1.9.2: oh-my-opencode installation bug fixes and feature improvements

**Verification performed:**
- `bash -n install_coding_tools.sh` - syntax check passed
- `file install_coding_tools.bat` - CRLF line endings confirmed
- `grep -B2 "return 1" install_coding_tools.sh` - verified return codes follow warnings
- `grep -B1 "exit /b 1" install_coding_tools.bat` - verified exit codes follow warnings
- Version consistency check across all files

**Additional fix (same session):**
- Discovered oh-my-opencode v3.7.4+ REQUIRES provider flags (`--claude`, `--gemini`, `--copilot`)
- Replaced interactive prompt with auto-detect function `build_ohmy_flags_from_installed_tools()`
- Auto-detect checks for installed tools (claude, codex, gemini) and sets flags accordingly
- Windows .bat file updated with `:build_ohmy_flags_auto` function
- Tested installation with auto-detected flags - success

**Third fix (same session):**
- User reported version still shows 3.3.1 after "successful" installation
- Root cause: oh-my-opencode is an `addon` type, installer only runs plugin registration but doesn't update npm package
- Fix: Added npm package update (`npm install -g oh-my-opencode@latest`) before plugin reinstall
- Both .sh and .bat updated with proper upgrade flow
- Verified npm update works: 3.3.1 → 3.7.4

---
