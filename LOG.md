# Log

## 2026-02-12

- Fix `auto_install_coding_tools` installer path resolution for out-of-repo execution.
- Add `oh-my-opencode` as a standalone Windows menu option and align addon behavior with the Unix installer.
- Fix Claude Code native installer on Windows/Linux when `claude.ai/checksums/*` is blocked (skip installer-script verification when checksum is unavailable; add best-effort signed-binary check on Windows).
