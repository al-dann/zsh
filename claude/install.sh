#!/usr/bin/env bash
# install.sh — wire this repo's Claude Code status line into ~/.claude/settings.json.
# Idempotent: merges ONLY the statusLine key, so it never clobbers other settings.
# Safe to run before Claude Code is installed (it just seeds ~/.claude/settings.json).
# Requires: jq.
set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "install.sh: jq is required (macOS: brew install jq; Fedora: sudo dnf install jq)" >&2
  exit 1
}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
settings="$HOME/.claude/settings.json"

# Home-relative on purpose: statusLine.command runs in a shell, so $HOME expands
# correctly on both macOS (/Users/...) and the Fedora guest (/home/...).
cmd='$HOME/.config/zsh/claude/statusline.sh'
block="$(jq -n --arg cmd "$cmd" '{type: "command", command: $cmd}')"

mkdir -p "$HOME/.claude"
if [ -f "$settings" ]; then
  tmp="$(mktemp)"
  jq --argjson sl "$block" '.statusLine = $sl' "$settings" >"$tmp"
  mv "$tmp" "$settings"
else
  jq -n --argjson sl "$block" '{statusLine: $sl}' >"$settings"
fi

chmod +x "$here/statusline.sh"
echo "install.sh: statusLine -> $cmd  (written to $settings)"
