# Agentic CLI Installer

An interactive installer that manages multiple AI coding CLI tools from one place. It detects installed versions, fetches latest versions, and lets you install, update, or remove tools in a single run.

## Features

- Interactive TUI with per-tool actions (install, update, remove, skip)
- Detects installed versions for npm and uv tools
- Fetches latest versions from npm and PyPI
- Supports both macOS/Linux (`.sh`) and Windows (`.bat`)

## Supported Tools

- [MoAI Agent Development Kit](https://github.com/modu-ai/moai-adk) (`moai-adk`, uv)
- [Claude Code CLI](https://github.com/anthropics/claude-code) (`@anthropic-ai/claude-code`, npm)
- [OpenAI Codex CLI](https://github.com/openai/codex) (`@openai/codex`, npm)
- [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) (`@google/gemini-cli`, npm)
- [Google Jules CLI](https://github.com/google-labs-code/jules-awesome-list) (`@google/jules`, npm)
- [OpenCode AI CLI](https://github.com/opencode-ai/opencode) (`opencode-ai`, npm)
- [Mistral Vibe CLI](https://github.com/mistralai/mistral-vibe) (`mistral-vibe`, uv)

## Requirements

- `curl`
- For uv-managed tools: `uv`
- For npm-managed tools: `node` + `npm`

## Usage

macOS/Linux:

```bash
chmod +x install_coding_tools.sh
./install_coding_tools.sh
```

Windows (PowerShell):

```powershell
.\install_coding_tools.bat
```

## Notes

- If a conda environment is active, the script refuses to run in `base` for safety.
- Version checks use network calls; slow or blocked connections may show `Unknown` for latest versions.
