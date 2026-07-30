# Instructions for Claude

You are being asked to install a custom status line for Claude Code on this
machine. Everything you need is in this folder. Follow these steps.

## 1. Tell the user what this changes, and confirm

Before running anything, state plainly:

- This writes a renderer script to `~/.claude/` and adds a `statusLine` key to
  `~/.claude/settings.json`.
- That is a **user-level** setting: it applies to **every** Claude Code project
  on this machine, not just the current folder.
- It is additive and reversible. Existing keys in `settings.json` are preserved,
  a `.bak` copy is made, and removing the `statusLine` key reverts it.
- The status line is read-only and informational. It renders data the harness
  already pipes to it and takes no action of its own.

Then ask whether to proceed. **Do not install without a clear yes.**

## 2. Check for an existing status line

Read `~/.claude/settings.json` if it exists. If it already contains a
`statusLine` block, show the user the current command and confirm separately
that they want it replaced. The installers will also prompt, but the user should
hear it from you first.

## 3. Run the installer for their platform

**Windows:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-windows.ps1
```

**macOS / Linux:**

```bash
bash install-unix.sh
```

The Unix renderer needs `jq` on PATH. If it is missing, tell the user how to get
it (`brew install jq` on macOS, `sudo apt install jq` on Debian/Ubuntu) — do not
install packages without asking.

If the user prefers not to run a script, `README.md` documents the manual steps:
copy the renderer into `~/.claude/` and add the `statusLine` block to
`settings.json` yourself.

## 4. Verify

Confirm that the renderer file exists in `~/.claude/` and that
`settings.json` is valid JSON containing the `statusLine` block. Report both
paths back to the user.

## 5. Tell them to restart

The status line appears after Claude Code reloads settings. Restarting Claude
Code or opening a new session is the reliable way to see it.

## Notes

- Do not modify the user's project repo. This package installs to the home
  directory only; nothing here belongs in version control for their project.
- Do not copy these files into the project folder as a permanent artifact.
  Once installed, the unzipped folder can be deleted.
- If the user asks to change what the status line shows, edit the renderer at
  `~/.claude/statusline-command.ps1` (or `.sh`). The color thresholds and
  segment layout are documented in `README.md`.
