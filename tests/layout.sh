#!/usr/bin/env bash
# Offline layout fixtures; no real account settings or auth commands are read.
set -euo pipefail
repo=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/home" CLAUDE_CONFIG_DIR="$fixture/config" TMPDIR="$fixture/tmp"
mkdir -p "$HOME/.config" "$CLAUDE_CONFIG_DIR" "$TMPDIR"
unset CLAUDE_CODE_AUTO_COMPACT_WINDOW
payload='{"model":{"display_name":"Opus 5.5 (1M context)"},"effort":{"level":"high"},"context_window":{"used_percentage":50,"context_window_size":1000000},"cost":{"total_cost_usd":1629.43},"rate_limits":{"five_hour":{"used_percentage":99,"resets_at":4102444800},"seven_day":{"used_percentage":99,"resets_at":4102444800}}}'
suffix=" │ Opus 5.5 · high │ ctx ▰▰▰▰▰▱▱▱▱▱ 50% │ \$1,629.43"

check() {
  local name=$1 expected=$2 actual
  actual=$(printf '%s\n' "$payload" | bash "$repo/statusline.sh" | sed -E $'s/\033\[[0-9;]*m//g')
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL %s: expected %s, got %s\n' "$name" "$expected" "$actual" >&2
    exit 1
  fi
  printf 'PASS %s: %s\n' "$name" "$actual"
}

printf 'max %s\n' "$CLAUDE_CONFIG_DIR" >"$HOME/.config/claude-accounts"
check 'existing max slot displays ultra without quota bars or hints' "ultra$suffix"
printf 'team %s/\n' "$CLAUDE_CONFIG_DIR" >"$HOME/.config/claude-accounts"
check 'team slot keeps team without quota bars or hints' "team$suffix"
printf 'personal %s\n' "$CLAUDE_CONFIG_DIR" >"$HOME/.config/claude-accounts"
check 'personal slot displays only ultra' "ultra$suffix"
payload=$(jq 'del(.rate_limits)' <<<"$payload")
check 'absent quota data does not add placeholders' "ultra$suffix"
rm "$HOME/.config/claude-accounts"
check 'missing accounts file defaults to ultra' "ultra$suffix"
printf 'team ~/.claude-team\n' >"$HOME/.config/claude-accounts"
check 'unmatched slot defaults to ultra' "ultra$suffix"
mkdir -p "$HOME/.claude-team"
export CLAUDE_CONFIG_DIR="$HOME/.claude-team/"
check 'tilde team path matches' "team$suffix"
unset CLAUDE_CONFIG_DIR
check 'default personal config displays ultra' "ultra$suffix"

printf 'max ~/.claude expected@example.com\n' >"$HOME/.config/claude-accounts"
payload=$(jq '.session_id = "layout-auth"' <<<"$payload")
printf 'other@example.com\n' >"$TMPDIR/claude-statusline-email.layout-auth"
check 'personal email mismatch still warns' "ultra WRONG ACCOUNT$suffix"
printf 'expected@example.com\n' >"$TMPDIR/claude-statusline-email.layout-auth"
check 'matching email keeps the ordinary label' "ultra$suffix"
payload=$(jq 'del(.context_window)' <<<"$payload")
check 'session context cache survives payload field removal' "ultra${suffix/50%/~50%}"

payload='{"model":{"display_name":"Opus 5.5"},"fast_mode":true,"cost":{"total_cost_usd":0}}'
check 'empty effort and context preserve fast mode and cost' "ultra │ Opus 5.5 fast │ \$0.00"
