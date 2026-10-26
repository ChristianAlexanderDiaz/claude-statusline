#!/usr/bin/env bash
# Installs the Claude Code status line into ~/.claude and wires it into
# ~/.claude/settings.json, keeping every other setting as it is.
set -euo pipefail

repo="https://raw.githubusercontent.com/ChristianAlexanderDiaz/claude-statusline/main"
dir="$HOME/.claude"
mkdir -p "$dir"

if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing jq (the status line needs it)..."
    brew install jq
  else
    echo "error: jq is required. Install it (https://jqlang.org) and run this again." >&2
    exit 1
  fi
fi

curl -fsSL "$repo/statusline.sh" -o "$dir/statusline.sh"
chmod +x "$dir/statusline.sh"

# An absolute path, so it works whether or not the command runs through a shell.
settings="$dir/settings.json"
[ -s "$settings" ] || echo '{}' > "$settings"
tmp="$(mktemp)"
jq --arg cmd "$dir/statusline.sh" '.statusLine = {type: "command", command: $cmd}' "$settings" > "$tmp"
mv "$tmp" "$settings"

echo "Installed. Restart Claude Code; the bar appears after your next message."
