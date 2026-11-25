#!/usr/bin/env bash
# Offline cost fixtures; no real account settings are read.
set -euo pipefail
repo=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/home" CLAUDE_CONFIG_DIR="$fixture/config" TMPDIR="$fixture/tmp"
mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR" "$TMPDIR"

check() {
  local value=$1 expected=$2 color=${3:-} output plain actual
  output=$(printf '{"model":{"display_name":"Fixture"},"cost":{"total_cost_usd":%s}}\n' "$value" | bash "$repo/statusline.sh")
  plain=$(printf '%s\n' "$output" | sed -E $'s/\033\[[0-9;]*m//g')
  actual=$(printf '%s\n' "$plain" | sed -nE 's/.*(\$[0-9,]+\.[0-9]{2}).*/\1/p')
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL %s: expected %s, got %s\n' "$value" "$expected" "$plain" >&2
    exit 1
  fi
  if [ -n "$color" ] && [[ "$output" != *"${color}${expected}"* ]]; then
    printf 'FAIL %s: cost colour changed\n' "$value" >&2
    exit 1
  fi
  printf 'PASS %s: %s\n' "$value" "$plain"
}

muted=$'\033[38;2;110;106;134m'
gold=$'\033[38;2;246;193;119m'
love=$'\033[38;2;235;111;146m'
check 1617.51 "\$1,617.51" "$love"
check 12.30 "\$12.30" "$gold"
check 1234567.8 "\$1,234,567.80" "$love"
check 0 "\$0.00" "$muted"
check 9.99 "\$9.99" "$muted"
check 25 "\$25.00" "$love"
check 999.999 "\$1,000.00" "$love"
check 999999.999 "\$1,000,000.00" "$love"
check 1e-7 "\$0.00" "$muted"
check -1 ''
check null ''
check '"invalid"' ''
output=$(printf '{"model":{"display_name":"Fixture"}}\n' | bash "$repo/statusline.sh")
[[ "$output" != *'$'* ]] || { printf 'FAIL: missing cost was displayed\n' >&2; exit 1; }
printf 'PASS missing cost stays hidden\n'
