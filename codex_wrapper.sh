#!/bin/sh
# codex entry point — runs the ONE nvm-managed copy, whatever conda env is active.
#
# node is resolved through ~/.local/bin/node, the symlink that sits beside
# ~/.local/bin/npm. That npm is the one `codex update` (a bare
# `npm install -g @openai/codex`), a plain global npm install, and
# install_coding_tools.sh all use, so they all land in the copy this runs.
# Interpreter and script are absolute: a stale node or codex inside a conda
# env can never shadow it (codex is ESM; an old node dies with SyntaxError).
#
# Previous version (ran the conda moai copy): ~/.local/bin.backup/codex.20261105-moai-wrapper
node_link="$HOME/.local/bin/node"
# readlink must resolve even when a caller hands over a stripped PATH; appending
# (not prepending) cannot change which node/npm codex itself later finds.
node_real=$(PATH="${PATH:+$PATH:}/usr/bin:/bin" readlink -f "$node_link" 2>/dev/null) || node_real=""
if [ -z "$node_real" ] || [ ! -x "$node_real" ]; then
    echo "codex: $node_link does not resolve to a node binary." >&2
    echo "       Point it at your nvm node, e.g.: ln -sf \"\$NVM_DIR/versions/node/<ver>/bin/node\" \"$node_link\"" >&2
    exit 127
fi
codex_js="${node_real%/bin/node}/lib/node_modules/@openai/codex/bin/codex.js"
if [ ! -f "$codex_js" ]; then
    echo "codex: @openai/codex is not installed under $node_real" >&2
    echo "       (an nvm Node change leaves globals in the old version dir)." >&2
    echo "       Reinstall: $HOME/.local/bin/npm install -g @openai/codex" >&2
    exit 127
fi
exec "$node_real" "$codex_js" "$@"
