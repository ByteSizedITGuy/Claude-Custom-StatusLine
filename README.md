# Claude Code Custom Status Line

A two-line, color-coded status line for Claude Code that shows your context
budget and your rate-limit windows at a glance.

```
Opus 4.8 (1M context) | 128.4k/1000k (13%) | high
5h 42%@3:15pm | 7d 61%@jul 12, 9:00am
```

**Example Status Line:**
![alt text](https://github.com/ByteSizedITGuy/Claude-Custom-StatusLine/blob/main/claude_status_example.png "Status Line Example")


**Line 1 — working state**

- Model display name (blue)
- Context window used: `usedK/maxK (pct%)`
- Effort level (magenta), when the harness reports one

**Line 2 — account rate-limit windows** (each shown only when reported)

- `5h` — five-hour rolling window: percent used, reset time appended as `@<time>`
- `7d` — seven-day window: percent used, reset time appended

**Color thresholds** apply to every percentage:

| Used % | Color  |
|--------|--------|
| < 50%  | green  |
| 50–69% | yellow |
| 70–89% | orange |
| ≥ 90%  | red    |

Reset times render as `3:15pm` for today, `jul 12, 9:00am` for a later day. If
the harness supplies no data at all, the renderer prints a dim `claude`
placeholder so the status line never goes blank.

## Easiest install: hand it to Claude

Unzip this folder, then in Claude Code say:

> Read `INSTALL-WITH-CLAUDE.md` in this folder and set up my status line.

Claude will confirm what it's changing, run the right installer for your OS, and
verify the result.

## Manual install

### Windows

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-windows.ps1
```

Writes the renderer to `%USERPROFILE%\.claude\statusline-command.ps1` and merges
the `statusLine` block into `%USERPROFILE%\.claude\settings.json`.

### macOS / Linux

Requires [`jq`](https://jqlang.github.io/jq/) on your PATH
(`brew install jq` / `sudo apt install jq`).

```bash
bash install-unix.sh
```

Copies `statusline-command.sh` to `~/.claude/` and merges the `statusLine` block
into `~/.claude/settings.json`.

### Fully by hand

Copy the renderer for your platform into `~/.claude/`, then add this to
`~/.claude/settings.json`, keeping any keys already there:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

On Windows the command is:

```
powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/<username>/.claude/statusline-command.ps1
```

Restart Claude Code (or open a new session) afterward so the settings watcher
picks it up.

## Scope and safety

- **User-level, not project-level.** `~/.claude/settings.json` is global harness
  config, so the status line applies to every Claude Code project on the machine.
- **Non-destructive.** Both installers merge rather than overwrite, back up an
  existing `settings.json` to `settings.json.bak`, and prompt before replacing a
  status line you already have.
- **Read-only.** The renderer only formats JSON that Claude Code pipes to it on
  stdin. It makes no network calls and changes nothing.

## Uninstall

1. Delete the `"statusLine"` key from `~/.claude/settings.json` (or restore
   `settings.json.bak`).
2. Optionally delete `~/.claude/statusline-command.ps1` or
   `~/.claude/statusline-command.sh`.
3. Restart Claude Code.

## Customizing

Everything is in one renderer file — `~/.claude/statusline-command.ps1` on
Windows, `~/.claude/statusline-command.sh` on macOS/Linux. Common edits:

- **Color thresholds** — the `Get-PctColor` function (PowerShell) or `pct_color`
  (bash). Both use 24-bit ANSI escapes like `\033[38;2;R;G;Bm`.
- **Which segments appear** — segments are pushed onto `line1` / `line2` arrays;
  comment out the ones you don't want.
- **One line instead of two** — join `line2` onto `line1` with the separator
  instead of a newline.

Fields available from the harness JSON include `model.display_name`,
`context_window.context_window_size`, `context_window.total_input_tokens`,
`context_window.used_percentage`, `effort.level`, and under `rate_limits`, the
`five_hour` and `seven_day` objects with `used_percentage` and `resets_at` (Unix
epoch seconds). Anything missing is simply omitted from the output.

## Files

| File | Purpose |
|------|---------|
| `README.md` | This document |
| `INSTALL-WITH-CLAUDE.md` | Instructions for Claude to do the install for you |
| `install-windows.ps1` | Windows installer (contains the PowerShell renderer) |
| `install-unix.sh` | macOS / Linux installer |
| `statusline-command.sh` | The bash renderer, installed by `install-unix.sh` |
