# Project Log

## Session 2026-02-14 (Evening)

**Coding CLI used:** Claude Code CLI (claude-opus-4-6)

**Phase(s) worked on:**
- v1.8.0: Windows oh-my-opencode detection and cache fixes

**Concrete changes implemented:**
1. Fixed oh-my-opencode detection on Windows - added fallback text search using `findstr`
2. Added post-installation verification for oh-my-opencode to confirm plugin registration
3. Fixed npm version comparison to use delayed expansion (`!NPM_VERSION!` instead of `%NPM_VERSION%`)
4. Added npm cache invalidation after package removal to prevent stale "installed" status

**Files/modules/functions touched:**
- `install_coding_tools.bat`:
  - Updated version header to v1.8.0
  - Modified `get_oh_my_opencode_plugin_spec` to add findstr fallback
  - Modified `install_oh_my_opencode` to add verification after installation
  - Fixed `ensure_npm_prerequisite` to use delayed expansion for version comparison
  - Added cache invalidation in npm removal section (`NPM_LIST_JSON_READY=0`)
- `install_coding_tools.sh`: Version bump to v1.8.0
- `CHANGELOG.md`: Added v1.8.0 entry
- `README.md`: Version bump and changelog update
- `setup.sh`: Version bump to v1.8.0
- `PROJECT_HANDOFF.md`: Updated current state
- `PROJECT_LOG.md`: This entry

**Key technical decisions and rationale:**
- Fallback detection uses `findstr` for simple text search when PowerShell JSON parsing fails
- Cache invalidation ensures fresh version data after removal operations
- Delayed expansion fix ensures version variables are evaluated at runtime, not parse time

**Problems encountered and resolutions:**
- User reported oh-my-opencode showed "Not Installed" after successful installation
  - Root cause: PowerShell JSON parsing might fail silently
  - Resolution: Added findstr fallback detection
- User reported Jules showed "Installed" after removal
  - Root cause: npm list cache not invalidated after removal
  - Resolution: Clear cache flags after npm uninstall

**Items completed in this session:**
- v1.8.0: Windows detection and cache fixes

**Verification performed:**
- Code review of all changes
- Version consistency check across all files

---

## Session 2026-02-14 (Afternoon)

**Coding CLI used:** Claude Code CLI (claude-opus-4-6)

**Phase(s) worked on:**
- v1.7.20: Line ending normalization and version sync
- v1.7.21: GitHub CLI auto-installation for moai-adk

**Concrete changes implemented:**
1. Normalized `install_coding_tools.bat` line endings from mixed CRLF/LF to consistent CRLF
2. Added `install_gh_cli()` function to check and install GitHub CLI via conda-forge
3. Added `show_gh_auth_reminder()` function to display authentication instructions
4. Integrated gh CLI installation into moai-adk installation flow

**Files/modules/functions touched:**
- `install_coding_tools.sh`:
  - Added `install_gh_cli()` function (lines 444-483)
  - Added `show_gh_auth_reminder()` function (lines 485-491)
  - Modified moai-adk installation section to call gh CLI functions
- `install_coding_tools.bat`: Normalized line endings to CRLF
- `CHANGELOG.md`: Added v1.7.20 and v1.7.21 entries
- `README.md`: Updated version and changelog
- `setup.sh`: Version bump to v1.7.21

**Key technical decisions and rationale:**
- GitHub CLI is installed via conda-forge to maintain consistency with the project's conda-first approach
- gh CLI check runs before moai installer to ensure dependency is available
- Authentication reminder shown after successful installation as a non-blocking message

**Problems encountered and resolutions:**
- Mixed line endings in .bat file caused git diff to show 512 insertions/deletions
- Resolved by normalizing to CRLF using dos2unix/unix2dos

**Items completed in this session:**
- v1.7.20: Line ending normalization
- v1.7.21: GitHub CLI auto-installation for moai-adk

**Verification performed:**
- `file install_coding_tools.bat` confirmed CRLF-only line endings
- `git status` confirmed sync with origin/master
- Code review of new functions

---

## Session 2026-02-14 (Morning)

**Coding CLI used:** Claude Code CLI

**Phase(s) worked on:**
- Documentation review and version synchronization after external changes

**Concrete changes implemented:**
1. Reviewed changes made to `install_coding_tools.bat` by another agent
2. Identified v1.7.18-1.7.19 changes: Node.js floor enforcement, tool list updates, moai installer improvements
3. Updated all project files to consistent v1.7.20 version

**Files touched:**
- `README.md`: Version and changelog updates
- `CHANGELOG.md`: Version entries
- `setup.sh`: Version bump
- `install_coding_tools.bat`: Version bump

---

## Session 2026-02-12

**Coding CLI used:** Claude Code CLI

**Phase(s) worked on:**
- Windows installer alignment with Unix features
- oh-my-opencode as first-class menu item

**Concrete changes implemented:**
1. Fixed `auto_install_coding_tools` script location resolution
2. Added `oh-my-opencode` as standalone menu item in Windows batch file
3. Improved addon installation skip logic when already registered

---

## Session 2026-02-07 to 2026-02-09

**Coding CLI used:** Claude Code CLI

**Phase(s) worked on:**
- v1.7.13-1.7.19: Multiple bug fixes and feature additions

**Key changes:**
- v1.7.13: oh-my-opencode plugin detection fix (.plugin singular)
- v1.7.14: log_warning() stderr output fix
- v1.7.15: Seccomp filter auto-installation
- v1.7.16: Playwright CLI auto-installation
- v1.7.17: Playwright MCP global auto-installation
- v1.7.18: Node.js floor enforcement, removed mistral-vibe
- v1.7.19: Windows tool index fix with dynamic TOOLS_COUNT

---

## Session 2026-02-15

**Coding CLI used:** Claude Code CLI (glm-4.7)

**Phase(s) worked on:**
- v1.8.1: jq auto-installation for moai-adk
- Version consistency verification
- External GitHub issue creation for moai-adk bugs

**Concrete changes implemented:**
1. Added `install_jq()` function to check and install jq via conda-forge before moai-adk installation
2. Added jq auto-installation to both Unix/WSL and Windows installers
3. Updated setup.bat version from v1.7.6 to v1.8.1 (was missed in previous release)
4. Created GitHub issue #381 for moai-adk settings.json corruption bug
5. Created GitHub issue #382 for moai-adk MoAI output style localization bug

**Files/modules/functions touched:**
- `install_coding_tools.sh`:
  - Added `install_jq()` function (after `show_gh_auth_reminder()`)
  - Modified moai-adk installation to call `install_jq` before `install_gh_cli`
  - Version bump to v1.8.1
- `install_coding_tools.bat`:
  - Added `:install_jq` function (after Claude installation section)
  - Modified `:install_tool_moai` to call `install_jq` before running moai installer
  - Version bump to v1.8.1
- `setup.bat`: Version bump from v1.7.6 to v1.8.1
- `setup.sh`: Version bump to v1.8.1
- `CHANGELOG.md`: Added v1.8.1 entry
- `README.md`: Version bump to v1.8.1, added changelog entry
- `PROJECT_HANDOFF.md`: Updated current state to v1.8.1
- `PROJECT_LOG.md`: This entry

**Key technical decisions and rationale:**
- jq is installed via conda-forge to maintain consistency with the project's conda-first approach
- jq check runs before moai-adk installer to prevent settings.json corruption
- If conda is unavailable, shows warning but continues (non-blocking)
- setup.bat version was outdated (v1.7.6) - now synchronized to v1.8.1

**Problems encountered and resolutions:**
- User reported moai-adk installation corrupts `~/.claude/settings.json` when jq is not installed
  - Root cause: moai-adk's installer falls back to sed-based JSON editing which corrupts pretty-printed JSON
  - Resolution: Added jq auto-installation before moai-adk runs
  - External: Created GitHub issue #381 documenting the upstream bug

**Items completed in this session:**
- v1.8.1: jq auto-installation for moai-adk
- GitHub issue #381: moai-adk settings.json corruption bug report
- GitHub issue #382: moai-adk MoAI output style localization bug report
- Version consistency fix: setup.bat updated to v1.8.1

**Verification performed:**
- Code review of install_jq() function in both .sh and .bat
- grep search for version consistency across all files
- git commit and push to origin/master (commit: 1bcd512)

**External issues reported:**
- moai-adk issue #381: https://github.com/modu-ai/moai-adk/issues/381
- moai-adk issue #382: https://github.com/modu-ai/moai-adk/issues/382

**Deferred items:**
- uv self-update functionality: Not implemented as no tools in TOOLS array use uv as their package manager

---

## Session 2026-02-18

**Coding CLI used:** OpenCode (this session)

**Phase(s) worked on:**
- Post-release maintenance (v1.9.0)

**Concrete changes implemented:**
1. Fixed `oh-my-opencode` installed version reporting in `install_coding_tools.sh` to read the resolved version from OpenCode cache instead of mirroring npm registry `latest`.
2. Restored compatibility for the documented legacy flag `--skip-system-npm` in `install_coding_tools.sh` (deprecated no-op).
3. Added minimal safety guard rails to `setup.sh` (non-interactive prompt handling, shell config backup, refusal to overwrite symlinks/non-file targets, non-fatal WSL Windows-path install failure).
4. Version bumped to v1.9.0 across docs and scripts touched.

**Files/modules/functions touched:**
- `install_coding_tools.sh`:
  - Added `--skip-system-npm` argument support and a deprecation note
  - Updated `get_installed_addon_version()` to resolve installed addon version from OpenCode cache (`$XDG_CACHE_HOME/opencode`)
  - Updated `version_compare()` to handle unknown/non-semver values safely
  - Added forced reinstall path for oh-my-opencode reinstall flow
- Version bump to v1.9.0
- `setup.sh`:
  - Fixed timestamp validation error path before logger initialization
  - Non-interactive prompt behavior uses default without blocking
  - Shell config backup before PATH modification
  - Refuse overwrite of symlinks/non-file targets
  - WSL Windows-path install failure becomes non-fatal
- Version bump to v1.9.0
- `README.md`: Version bump to v1.9.0 and changelog entry
- `CHANGELOG.md`: Added v1.9.0 entry
- `PROJECT_HANDOFF.md`: Updated current state to v1.9.0
- `PROJECT_LOG.md`: This entry

**Verification performed:**
- `bash -n` on `install_coding_tools.sh`, `setup.sh`, and `auto_install_coding_tools`
- `./setup.sh --help` and `./install_coding_tools.sh --help`
- `./setup.sh --force --configure-path` in a temp HOME (deploy + PATH edit)
- Simulated `oh-my-opencode` cache state and verified installed version display
- Verified CRLF line endings for `setup.bat` and `install_coding_tools.bat`
