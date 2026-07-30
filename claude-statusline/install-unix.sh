#!/usr/bin/env bash
# install-unix.sh
# Installs the custom Claude Code status line on macOS or Linux.
#
# Usage:
#   bash install-unix.sh          # prompts before replacing an existing status line
#   bash install-unix.sh --force  # replaces without prompting
#
# What it does:
#   1. Copies statusline-command.sh to ~/.claude/statusline-command.sh (chmod +x)
#   2. Merges a "statusLine" block into ~/.claude/settings.json, preserving
#      every other key already in that file (a .bak copy is made first).
#
# This is a USER-LEVEL (machine-wide) setting: it applies to every Claude Code
# project on this machine. It is additive and reversible -- delete the
# "statusLine" key from settings.json to revert.
#
# Requires: jq (for the renderer) and python3 or jq (for the settings merge).

set -euo pipefail

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER_SRC="$SRC_DIR/statusline-command.sh"
CLAUDE_DIR="$HOME/.claude"
RENDERER_DST="$CLAUDE_DIR/statusline-command.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

if [ ! -f "$RENDERER_SRC" ]; then
  echo "Error: statusline-command.sh not found next to this installer." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Warning: jq is not on PATH. The status line needs it to parse harness"
  echo "         JSON. Install it (macOS: brew install jq / Debian: apt install jq)"
  echo "         and the status line will start working -- continuing anyway."
fi

mkdir -p "$CLAUDE_DIR"
cp "$RENDERER_SRC" "$RENDERER_DST"
chmod +x "$RENDERER_DST"

CMD="bash \"$RENDERER_DST\""

# --- Check for an existing status line ---
if [ -f "$SETTINGS" ] && grep -q '"statusLine"' "$SETTINGS" 2>/dev/null; then
  if [ "$FORCE" -ne 1 ]; then
    echo "A statusLine is already configured in $SETTINGS."
    read -r -p "Replace it? (y/N) " answer
    case "$answer" in
      y|Y|yes|YES) ;;
      *) echo "Aborted. Renderer was written to $RENDERER_DST but settings.json was not changed."; exit 0 ;;
    esac
  fi
fi

# --- Merge into settings.json ---
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak"

if command -v python3 >/dev/null 2>&1; then
  SETTINGS="$SETTINGS" CMD="$CMD" python3 - <<'PY'
import json, os

path = os.environ["SETTINGS"]
cmd = os.environ["CMD"]

data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        text = f.read().strip()
    if text:
        data = json.loads(text)

data["statusLine"] = {"type": "command", "command": cmd}

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
elif command -v jq >/dev/null 2>&1; then
  if [ -f "$SETTINGS" ]; then
    tmp=$(mktemp)
    jq --arg cmd "$CMD" '.statusLine = {type: "command", command: $cmd}' "$SETTINGS" > "$tmp"
    mv "$tmp" "$SETTINGS"
  else
    jq -n --arg cmd "$CMD" '{statusLine: {type: "command", command: $cmd}}' > "$SETTINGS"
  fi
else
  echo "Error: need python3 or jq to merge settings.json safely." >&2
  echo "Renderer is installed at $RENDERER_DST. Add this to $SETTINGS manually:" >&2
  echo "  \"statusLine\": { \"type\": \"command\", \"command\": \"$CMD\" }" >&2
  exit 1
fi

echo "Status line installed."
echo "  Renderer: $RENDERER_DST"
echo "  Settings: $SETTINGS"
[ -f "$SETTINGS.bak" ] && echo "  Backup:   $SETTINGS.bak"
echo "Restart Claude Code (or open a new session) to see it."
