#!/usr/bin/env bash
# Offline fixtures; needs bash and jq. No real account settings are read.
set -euo pipefail
repo=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/home" CLAUDE_CONFIG_DIR="$fixture/config" TMPDIR="$fixture/tmp"
mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR" "$TMPDIR"
unset CLAUDE_CODE_AUTO_COMPACT_WINDOW
payload='{"model":{"display_name":"Fixture"},"context_window":{"used_percentage":25,"context_window_size":1000000}}'

check() {
  local name=$1 expected=$2 output actual
  output=$(printf '%s\n' "$payload" | bash "$repo/statusline.sh")
  # Discard ANSI colours and isolate the displayed context percentage.
  actual=$(printf '%s\n' "$output" | sed -E $'s/\033\[[0-9;]*m//g' | sed -E 's/.*ctx [^ ]+ ([0-9]+)%.*/\1/')
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL %s: expected %s%%, got %s\n' "$name" "$expected" "$actual" >&2
    exit 1
  fi
  printf 'PASS %s: %s%%\n' "$name" "$actual"
}

# "Fix: fall back to .autoCompactWindow from settings.json when the env var is unset."
printf '%s\n' '{"env":{"CLAUDE_CODE_AUTO_COMPACT_WINDOW":"250000"},"autoCompactWindow":500000}' >"$CLAUDE_CONFIG_DIR/settings.json"
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000
check 'process value wins over both settings' 62

# "Fix: fall back to .autoCompactWindow from settings.json when the env var is unset."
unset CLAUDE_CODE_AUTO_COMPACT_WINDOW
check 'settings env value wins over top-level value' 100

# "Main's diagnosis: ~/.claude/settings.json and ~/.claude-team/settings.json already set the top-level key "autoCompactWindow": 500000, so compaction already happens at 500K, but statusline.sh (lines ~113-117) reads only the env var CLAUDE_CODE_AUTO_COMPACT_WINDOW or .env.CLAUDE_CODE_AUTO_COMPACT_WINDOW in settings.json, so the ctx % is measured against the 1M window."
printf '%s\n' '{"autoCompactWindow":500000}' >"$CLAUDE_CONFIG_DIR/settings.json"
check '500K top-level setting against 1M window' 50

# "Fix: fall back to .autoCompactWindow from settings.json when the env var is unset."
for value in invalid '' 0 -1 1000000 2000000; do
  export CLAUDE_CODE_AUTO_COMPACT_WINDOW="$value"
  check "explicit process value '$value' keeps full window" 25
done
unset CLAUDE_CODE_AUTO_COMPACT_WINDOW

# "Fix: fall back to .autoCompactWindow from settings.json when the env var is unset."
for value in invalid '' 0 -1 1000000 2000000; do
  jq -n --arg value "$value" '{env:{CLAUDE_CODE_AUTO_COMPACT_WINDOW:$value},autoCompactWindow:500000}' >"$CLAUDE_CONFIG_DIR/settings.json"
  check "settings env value '$value' keeps full window" 25
done

# "Fix: fall back to .autoCompactWindow from settings.json when the env var is unset."
for value in invalid '' 0 -1 1000000 2000000; do
  jq -n --arg value "$value" '{autoCompactWindow:$value}' >"$CLAUDE_CONFIG_DIR/settings.json"
  check "top-level value '$value' keeps full window" 25
done

# "Fix: fall back to .autoCompactWindow from settings.json when the env var is unset."
rm "$CLAUDE_CONFIG_DIR/settings.json"
check 'missing settings keeps full window' 25
