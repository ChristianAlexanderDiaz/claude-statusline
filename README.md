# Claude Code status line

![status line](statusline.png)

`account │ model · effort │ ctx bar % │ $cost │ 5h bar 7d bar`

- **account**: which Claude login this session is on (from `~/.config/claude-accounts`, else the config folder name).
- **ctx**: context used, measured against auto-compact. Green under 50%, gold under 80%, red after.
- **$cost**: what this chat has cost so far. Muted under $10, gold from $10, red from $25.
- **5h / 7d**: usage windows. The reset countdown (`↻2h10m`) stays hidden under 50%, shows muted from 50%, gold from 75%, red from 90%. At 95% it says `switch` (or `stop` for an account named `team`).

Colors are Rose Pine Moon. Needs `bash` and `jq`.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ChristianAlexanderDiaz/claude-statusline/main/install.sh | bash
```

It installs `jq` with Homebrew if it is missing, saves the script to `~/.claude/statusline.sh`, and sets `statusLine` in `~/.claude/settings.json` without touching your other settings. Restart Claude Code afterwards.

Optional, to name your accounts, create `~/.config/claude-accounts`:

```
work ~/.claude
```

Run the install line again to update.
