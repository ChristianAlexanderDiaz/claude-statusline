#!/usr/bin/env bash
# Claude Code status line. Wired up via `statusLine` in ~/.claude/settings.json.
# Reads the session JSON on stdin; see https://code.claude.com/docs/en/statusline
set -uo pipefail

input=$(cat)

# Rose Pine Moon, matching the tmux status bar and the WezTerm theme. The whole
# palette stays defined even where a colour is not used yet.
r()    { printf '\033[38;2;%sm' "$1"; }
# shellcheck disable=SC2034
{
  TEXT=$(r '224;222;244');  SUBTLE=$(r '144;140;170'); MUTED=$(r '110;106;134')
  LOVE=$(r '235;111;146');  GOLD=$(r '246;193;119');   ROSE=$(r '234;154;151')
  PINE=$(r '62;143;176');   FOAM=$(r '156;207;216');   IRIS=$(r '196;167;231')
  GREEN=$(r '156;207;140')
}
OFF='\033[0m'

# Split on a unit separator, not a tab: tab is IFS whitespace, so bash would
# collapse consecutive tabs and silently shift every field after an empty one.
IFS=$'\x1f' read -r MODEL EFFORT FAST PCT RL5 RL5_AT RL7 RL7_AT SID WINDOW COST <<<"$(
  jq -r '[
    .model.display_name // "?",
    .effort.level // "",
    (if .fast_mode then "1" else "" end),
    (.context_window.used_percentage // -1),
    (.rate_limits.five_hour.used_percentage // -1),
    (.rate_limits.five_hour.resets_at // 0),
    (.rate_limits.seven_day.used_percentage // -1),
    (.rate_limits.seven_day.resets_at // 0),
    (.session_id // ""),
    (.context_window.context_window_size // 0),
    (.cost.total_cost_usd // -1)
  ] | map(tostring) | join("\u001f")' <<<"$input"
)"

# 1789350600 -> 4h53m of runway left; prints nothing once the moment has passed
eta() {
  awk -v t="$1" -v now="$(date +%s)" 'BEGIN{
    s = t - now;
    if (t <= 0 || s <= 0) exit;
    d = int(s/86400); h = int((s%86400)/3600); m = int((s%3600)/60);
    if (d)      printf "%dd%dh", d, h;
    else if (h) printf "%dh%dm", h, m;
    else        printf "%dm", (m > 0 ? m : 1)
  }'
}

# Filled cells and percentages show fullness; empty cells stay muted.
GAP=" ${MUTED}│${OFF} "

# Which account this session is on: CLAUDE_CONFIG_DIR (unset means ~/.claude)
# looked up against ~/.config/claude-accounts, one "<name> <config folder>
# [expected email]" per line (see home/.config/claude-accounts.example). Falls
# back to the config folder's basename when the file, or a matching line, is
# missing.
accounts_file="$HOME/.config/claude-accounts"
cfg_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
cfg_dir="${cfg_dir%/}"
ACCOUNT=""
EXPECTED=""
if [ -r "$accounts_file" ]; then
  while IFS=' ' read -r name folder email _; do
    case "$name" in ''|'#'*) continue ;; esac
    [ -z "$folder" ] && continue
    folder="${folder/#\~/$HOME}"
    folder="${folder%/}"
    if [ "$folder" = "$cfg_dir" ]; then
      ACCOUNT="$name"
      EXPECTED="$email"
      break
    fi
  done <"$accounts_file"
fi
[ -z "$ACCOUNT" ] && ACCOUNT="$(basename "$cfg_dir")"

# A login typed in the wrong place lands on whatever account the browser holds,
# so check who this slot is really signed in as. Once per session: the answer
# is cached in $TMPDIR by session id, and an empty answer (claude missing or
# signed out) is cached too, so a failing check never runs on every render.
WRONG=""
if [ -n "$EXPECTED" ] && [ -n "$SID" ]; then
  email_cache="${TMPDIR:-/tmp}/claude-statusline-email.${SID}"
  if [ ! -e "$email_cache" ]; then
    claude auth status 2>/dev/null | jq -r '.email // ""' 2>/dev/null >"$email_cache"
  fi
  read -r signed_in <"$email_cache" 2>/dev/null || signed_in=""
  if [ -n "$signed_in" ] && [ "$signed_in" != "$EXPECTED" ]; then
    WRONG=1
  fi
fi

# The team account must never run into paid extra usage, so it gets "stop"
# instead of "switch" once a quota is nearly spent. Name it "team" in the
# accounts file to opt in.
IS_TEAM=""
[ "$ACCOUNT" = "team" ] && IS_TEAM=1

line="${SUBTLE}${ACCOUNT}${OFF}${GAP}"
[ -n "$WRONG" ] && line="${LOVE}${ACCOUNT} WRONG ACCOUNT${OFF}${GAP}"

# The window size is implied by the percent, so drop "(1M context)".
line+="${TEXT}${MODEL% (*}${OFF}"
[ -n "$EFFORT" ] && line+=" ${MUTED}·${OFF} ${SUBTLE}${EFFORT}${OFF}"
[ -n "$FAST" ]   && line+=" ${GOLD}fast${OFF}"

# The payload drops its context_window numbers between a /compact and the next
# API response. Keep the last real reading per session and show it marked "~"
# instead; the next response overwrites it with live numbers.
ctx_cache="${TMPDIR:-/tmp}/claude-statusline-ctx.${SID:-none}"
stale=""
# An explicitly set process value takes precedence, including an invalid value.
compact_window="${CLAUDE_CODE_AUTO_COMPACT_WINDOW-}"
if [ "${CLAUDE_CODE_AUTO_COMPACT_WINDOW+x}" != x ]; then
  compact_window=$(jq -r '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW // ""' "$cfg_dir/settings.json" 2>/dev/null) || compact_window=""
fi
if [ "${PCT%.*}" -ge 0 ] 2>/dev/null; then
  PCT=$(awk -v pct="$PCT" -v window="$WINDOW" -v compact="$compact_window" 'BEGIN {
    limit = window;
    if (compact ~ /^[0-9]+([.][0-9]+)?$/ && compact + 0 > 0 && compact < limit)
      limit = compact;
    if (limit > 0) pct = pct * window / limit;
    if (pct > 100) pct = 100;
    printf "%.6f", pct;
  }')
fi
if [ "${PCT%.*}" -ge 0 ] 2>/dev/null; then
  printf '%s\n' "${PCT}" >"$ctx_cache" 2>/dev/null
elif [ -n "$SID" ] && [ -r "$ctx_cache" ]; then
  read -r PCT <"$ctx_cache"
  stale="~"
fi

# Colour for fullness: green below 50%, gold below 80%, then love.
heat() {
  if   [ "$1" -ge 80 ]; then printf '%s' "$LOVE"
  elif [ "$1" -ge 50 ]; then printf '%s' "$GOLD"
  else                       printf '%s' "$GREEN"
  fi
}

# Round to the nearest cell and clamp to the bar's width.
bar() {
  awk -v pct="$1" -v width="$2" -v color="${3:-$SUBTLE}" -v muted="$MUTED" 'BEGIN{
    filled = int(pct * width / 100 + 0.5);
    if (filled < 0) filled = 0;
    if (filled > width) filled = width;
    for (i = 0; i < width; i++) printf "%s%s", (i < filled ? color : muted), (i < filled ? "▰" : "▱");
  }'
}

if [ "${PCT%.*}" -ge 0 ] 2>/dev/null; then
  p=${PCT%.*}
  color=$(heat "$p")
  line+="${GAP}${color}ctx $(bar "$PCT" 10 "$color") ${color}${stale}${p}%${OFF}"
fi

# Session spend, shown only when the payload carries it. Muted while cheap, then
# gold from $10 and love from $25, so a runaway session stands out.
# jq prints tiny values in exponent form, so accept that; -1 means absent.
if awk -v c="$COST" 'BEGIN{exit !(c ~ /^-?[0-9.]+([eE][-+]?[0-9]+)?$/ && c + 0 >= 0)}'; then
  cost_color=$(awk -v c="$COST" -v muted="$MUTED" -v gold="$GOLD" -v love="$LOVE" \
    'BEGIN{printf "%s", (c >= 25 ? love : (c >= 10 ? gold : muted))}')
  line+="${GAP}${cost_color}$(awk -v c="$COST" 'BEGIN{printf "$%.2f", c}')${OFF}"
fi

# At 95%, add "switch" for normal accounts or "stop" for the team account,
# since that one must never run into paid extra usage. The reset countdown shows
# from 50%, muted until 75%, then gold, then love from 90%.
quota() {
  local label=$1 pct=${2%.*} at=$3 color text left tcolor
  if ! [ "$pct" -ge 0 ] 2>/dev/null; then
    printf '%s' "${SUBTLE}${label} $(bar 0 5) ${SUBTLE}?${OFF}"
    return 0
  fi

  color=$(heat "$pct")
  if [ "$pct" -ge 95 ] 2>/dev/null; then
    color=$LOVE
    text=$([ -n "$IS_TEAM" ] && printf ' stop' || printf ' switch')
  else
    text=""
  fi
  printf '%s' "${color}${label} $(bar "$2" 5 "$color")${color}${text}${OFF}"
  if [ "$pct" -ge 50 ] 2>/dev/null; then
    if   [ "$pct" -ge 90 ]; then tcolor=$LOVE
    elif [ "$pct" -ge 75 ]; then tcolor=$GOLD
    else                         tcolor=$MUTED
    fi
    left=$(eta "$at"); [ -n "$left" ] && printf '%s' " ${tcolor}↻${left}${OFF}"
  fi
  return 0
}
# Both windows stay visible; reset timers appear once a window is half spent.
line+="${GAP}$(quota 5h "$RL5" "$RL5_AT") $(quota 7d "$RL7" "$RL7_AT")"

printf '%b\n' "$line"
