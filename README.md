# Agentic CLI Installer

An interactive installer that manages multiple AI coding CLI tools from one place. It detects installed versions, fetches latest versions, and lets you install, update, or remove tools in a single run.

## Features

- Interactive TUI with per-tool actions (install, update, remove, skip)
- Detects installed versions for npm and uv tools
- Fetches latest versions from npm and PyPI
- Supports both macOS/Linux (`.sh`) and Windows (`.bat`)

## Supported Tools

- MoAI Agent Development Kit (`moai-adk`, uv)
- Claude Code CLI (`@anthropic-ai/claude-code`, npm)
- OpenAI Codex CLI (`@openai/codex`, npm)
- Google Gemini CLI (`@google/gemini-cli`, npm)
- Google Jules CLI (`@google/jules`, npm)
- OpenCode AI CLI (`opencode-ai`, npm)
- Mistral Vibe CLI (`mistral-vibe`, uv)

## Requirements

- `curl`
- For uv-managed tools: `uv`
- For npm-managed tools: `node` + `npm`

## Usage

macOS/Linux:

```bash
chmod +x install_agentic_tools.sh
./install_agentic_tools.sh
```

Windows (PowerShell):

```powershell
.\install_agentic_tools.bat
```

## Notes

- If a conda environment is active, the script refuses to run in `base` for safety.
- Version checks use network calls; slow or blocked connections may show `Unknown` for latest versions.
