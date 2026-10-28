#!/usr/bin/env bash
# install.sh — put this repo's files in place on a new machine. Idempotent.
#
# Creates symlinks and missing files only. It never overwrites or edits an existing
# file: when something is in the way it says so and leaves it for you to merge.
# Works with macOS's bash 3.2.
#
# Usage: ./install.sh [--dry-run]
# In the OrbStack guest, run it from the macOS checkout, e.g.
#   /Users/<you>/.config/zsh/install.sh
# and ~/.config/zsh becomes a symlink to it.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
zsh_dir="$config_home/zsh"
dry=0
[ "${1:-}" = "--dry-run" ] && dry=1
problems=0

say() { printf '%s\n' "$*"; }
warn() {
  printf 'ACTION  %s\n' "$*" >&2
  problems=$((problems + 1))
}
run() { if [ "$dry" -eq 1 ]; then say "would   $*"; else "$@"; fi; }

# link <source> <target>: create target -> source unless something is already there.
link() {
  local src=$1 dst=$2
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      say "ok      $dst"
    else
      warn "$dst already links to $(readlink "$dst"); remove it to relink to $src"
    fi
    return 0
  fi
  if [ -e "$dst" ]; then
    warn "$dst exists and is not a symlink; merge it into $src by hand, then remove it"
    return 0
  fi
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
  [ "$dry" -eq 1 ] || say "linked  $dst -> $src"
}

# create <file> <mode> <content>: write a new file; never touch an existing one.
create() {
  local file=$1 mode=$2 content=$3
  if [ "$dry" -eq 1 ]; then
    say "would   create $file"
    return 0
  fi
  (umask 077 && printf '%s' "$content" >"$file")
  chmod "$mode" "$file"
  say "created $file"
}

# ---------- zsh ----------
if [ "$repo" != "$zsh_dir" ]; then
  link "$repo" "$zsh_dir"
fi

# shellcheck disable=SC2016  # written literally; expands when ~/.zshenv runs
bootstrap='export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -r $ZDOTDIR/.zshenv ]] && source "$ZDOTDIR/.zshenv"
'
if [ ! -e "$HOME/.zshenv" ]; then
  create "$HOME/.zshenv" 644 "$bootstrap"
elif grep -q 'ZDOTDIR' "$HOME/.zshenv"; then
  say "ok      $HOME/.zshenv (sets ZDOTDIR)"
else
  warn "$HOME/.zshenv exists without ZDOTDIR; add these lines to it:"
  printf '%s' "$bootstrap" | sed 's/^/          /' >&2
fi

# ---------- git ----------
# ~/.gitconfig must exist, or `git config --global` writes into this repo's git/config.
if [ ! -e "$HOME/.gitconfig" ]; then
  create "$HOME/.gitconfig" 600 '# Per-machine git settings: identity, signing, credentials (see README).
'
else
  say "ok      $HOME/.gitconfig"
fi
link "$zsh_dir/git/config" "$config_home/git/config"
link "$zsh_dir/git/ignore" "$config_home/git/ignore"
if command -v git >/dev/null 2>&1; then
  excludes="$(git config --global --get core.excludesFile || true)"
  if [ -n "$excludes" ]; then
    warn "core.excludesFile is set ($excludes), so git skips $config_home/git/ignore; unset it or merge the files"
  fi
fi

# ---------- ssh ----------
ssh_include='Match all
  Include ~/.config/zsh/ssh/baseline.conf
'
if [ ! -d "$HOME/.ssh" ]; then
  run mkdir -m 700 "$HOME/.ssh"
fi
if [ ! -e "$HOME/.ssh/config" ]; then
  create "$HOME/.ssh/config" 600 "# Host-specific settings go ABOVE the baseline include (first value wins).

$ssh_include"
elif grep -q 'zsh/ssh/baseline.conf' "$HOME/.ssh/config"; then
  say "ok      $HOME/.ssh/config (includes the baseline)"
else
  warn "add these lines at the END of $HOME/.ssh/config:"
  printf '%s' "$ssh_include" | sed 's/^/          /' >&2
fi

# ---------- summary ----------
say ""
say "Optional: Claude Code status line -> bash $zsh_dir/claude/install.sh"
if [ "$problems" -gt 0 ]; then
  say "$problems item(s) need your attention (ACTION lines above)."
  exit 1
fi
say "Done. Start a new shell."
