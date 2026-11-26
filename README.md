# Claude Code status line

`ultra │ Opus 5.5 · high │ ctx ▰▰▰▰▰▱▱▱▱▱ 50% │ $1,629.43`

- **account**: `team` for a slot named `team` in `~/.config/claude-accounts`; `ultra` for personal accounts, including slots previously named `max`. An unlisted slot also displays `ultra`.
- **ctx**: context used, measured against auto-compact. Green under 50%, gold under 80%, red after.
- **$cost**: what this chat has cost so far, with comma thousands separators and two decimal places. Muted under $10, gold from $10, red from $25.

Quota windows and switch hints are handled by quota-axi.

Colors are Rose Pine Moon. Needs `bash` and `jq`.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ChristianAlexanderDiaz/claude-statusline/main/install.sh | bash
```

It installs `jq` with Homebrew if it is missing, saves the script to `~/.claude/statusline.sh`, and sets `statusLine` in `~/.claude/settings.json` without touching your other settings. Restart Claude Code afterwards.

To identify your team slot, create `~/.config/claude-accounts` (each line is a name, config folder, and optional expected email):

```
ultra ~/.claude
team ~/.claude-team
```

Run the install line again to update.
