#!/usr/bin/env bash
# shellcheck disable=SC2088  # '~/...' strings are expected display text
# test_zsh-doctor.sh — tests for bin/zsh-doctor against a fake $HOME holding a copy of
# this repo. Plugins are stubbed at their pinned SHAs, so no network is needed.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$(cd "$here/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0

check() { # check <name> <output> <expected substring> [second substring on the same line]
  if printf '%s\n' "$2" | grep -F -- "$3" | grep -qF -- "${4:-$3}"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s: expected %s\n' "$1" "$3"
  fi
}
absent() { # absent <name> <output> <unexpected substring>
  if printf '%s\n' "$2" | grep -qF -- "$3"; then
    fail=$((fail + 1))
    printf 'FAIL %s: unexpected %s\n' "$1" "$3"
  else
    pass=$((pass + 1))
  fi
}

# ---------- fake home with a copy of the working tree ----------
home="$tmp/home"
zdir="$home/.config/zsh"
mkdir -p "$zdir"
(cd "$src" && git ls-files -co --exclude-standard -z | xargs -0 tar cf -) | (cd "$zdir" && tar xf -)
git -C "$zdir" init -q
(cd "$zdir" && git add -A && env HOME="$tmp" git -c user.name=t -c user.email=t@example.com \
  -c commit.gpgsign=false commit -qm init)
awk '$1 ~ /^[^#]+\/[^ ]+$/ && $2 ~ /^[0-9a-f]{40}$/ { print $1, $2 }' "$zdir/plugins.zsh" |
  while read -r repo sha; do
    name=${repo##*/}
    mkdir -p "$zdir/plugins/$name/.git"
    printf '%s\n' "$sha" >"$zdir/plugins/$name/.git/HEAD"
    : >"$zdir/plugins/$name/$name.plugin.zsh"
  done

doctor() { # doctor [extra env...]
  (cd "$home" && env -i PATH="$PATH" HOME="$home" TERM=dumb "$@" bash "$zdir/bin/zsh-doctor")
}

# ---------- before install.sh ----------
out=$(doctor)
check "no bootstrap" "$out" "WARN  ~/.zshenv" "missing"
check "config not loaded" "$out" "WARN  ZDOTDIR" "not set"
check "git link missing" "$out" "WARN  ~/.config/git/config" "missing"
check "ssh config missing" "$out" "WARN  ~/.ssh/config" "missing"

# ---------- a clean install ----------
(cd "$home" && env -i PATH="$PATH" HOME="$home" bash "$zdir/install.sh" >/dev/null 2>&1)
out=$(doctor)
check "bootstrap" "$out" "PASS  ~/.zshenv" "sets ZDOTDIR"
check "checkout" "$out" "PASS  ~/.config/zsh" "git checkout"
# Host-dependent: GitHub's Ubuntu runners have a group-writable Linuxbrew, which .zshenv
# detects; compinit then asks about insecure directories, and the doctor rightly reports both.
if printf '%s\n' "$out" | grep -q '^WARN  Completion dirs'; then
  check "startup (insecure completion dirs on this host)" "$out" "WARN  Startup" "compinit"
else
  check "startup" "$out" "PASS  Startup" "clean"
fi
check "zdotdir" "$out" "PASS  ZDOTDIR" "loaded"
check "term" "$out" "PASS  TERM" "dumb"
check "repo bin on PATH" "$out" "PASS  PATH: repo scripts"
check "git config link" "$out" "PASS  ~/.config/git/config" "links to the repo"
check "git ignore link" "$out" "PASS  ~/.config/git/ignore" "links to the repo"
check "gitconfig" "$out" "PASS  ~/.gitconfig"
check "ssh include" "$out" "PASS  ~/.ssh/config" "for all hosts"
check "identity missing" "$out" "WARN  user.email" "git commit fails"
check "no go bin yet" "$out" "INFO  PATH: Go tools" "does not exist yet"
absent "no stray files" "$out" "never read with ZDOTDIR set"
absent "repo startup files clean" "$out" "Repo startup files"

# An installer appended to $ZDOTDIR/.zprofile, i.e. the repo's tracked file.
cp "$zdir/.zprofile" "$tmp/zprofile.orig"
printf '\n%s\n' "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >>"$zdir/.zprofile"
out=$(doctor)
check "installer wrote into repo" "$out" "WARN  Repo startup files" "checkout -- .zprofile"
printf 'export SECRET_X=hidden-value\n' >>"$zdir/.zprofile"
out=$(doctor)
check "unknown repo edit" "$out" "WARN  Repo startup files" "1 other added line(s)"
absent "repo edit not printed" "$out" "hidden-value"
cp "$tmp/zprofile.orig" "$zdir/.zprofile"

# ---------- known problems ----------
# shellcheck disable=SC2016  # literal file content
printf '%s\n' '# comment' 'eval "$(/opt/homebrew/bin/brew shellenv)"' 'export API_TOKEN=s3cr3t-value' >"$home/.zprofile"
mkdir -p "$home/go/bin" "$home/.local/bin" "$home/.config/lf"
printf '#!/bin/sh\n' >"$home/go/bin/fzf"
printf '#!/bin/sh\n' >"$home/.local/bin/fzf"
chmod +x "$home/go/bin/fzf" "$home/.local/bin/fzf"
: >"$home/.config/lf/icons"
printf 'export X=1\n' >"$zdir/local.zshenv"
chmod 666 "$zdir/local.zshenv"
printf '\nHost late.example\n  User x\n' >>"$home/.ssh/config"
printf '[user]\n\tsigningkey = ~/.ssh/nope.pub\n[gpg]\n\tformat = ssh\n[commit]\n\tgpgsign = true\n' >"$home/.gitconfig"

out=$(doctor TERM=no-such-terminal)
rc=$?
check "stray zprofile" "$out" "WARN  ~/.zprofile" "brew shellenv"
check "stray zprofile other lines" "$out" "WARN  ~/.zprofile" "1 other line(s)"
absent "never prints file contents" "$out" "s3cr3t-value"
check "two owners" "$out" "WARN  Two owners: fzf" "first wins: ~/.local/bin/fzf"

# /bin -> usr/bin (usrmerge: Fedora, Ubuntu): /bin/jq and /usr/bin/jq are one file, one owner.
if [ -L /bin ] && [ -x /usr/bin/jq ]; then
  printf '#!/bin/sh\n' >"$home/.local/bin/jq"
  chmod +x "$home/.local/bin/jq"
  out_jq=$(doctor)
  check "two owners, user copy vs system" "$out_jq" "WARN  Two owners: jq" "~/.local/bin/jq"
  absent "same file listed once" "$out_jq" "/bin/jq /usr/bin/jq"
  rm -f "$home/.local/bin/jq"
fi
check "machine-only go tool" "$out" "INFO  Go tools, this machine only" "fzf"
check "gup set missing" "$out" "WARN  Go tools (gup.json)" "gup import"
check "unknown TERM" "$out" "WARN  TERM" "no-such-terminal"
check "local perms" "$out" "WARN  local.zshenv" "writable by others"
check "ssh order" "$out" "WARN  ~/.ssh/config" "move the Include to the end"
check "signing key" "$out" "WARN  Commit signing" "does not exist"
check "lf icons" "$out" "WARN  lf icons" "set icons true"
warn_lines=$(printf '%s\n' "$out" | grep -c '^WARN')
if [ "$rc" -eq "$warn_lines" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL exit code: %s, expected %s (WARN lines)\n' "$rc" "$warn_lines"
fi

# Run from inside this checkout, whose own .git/config sets an identity: that must not count
# as the user's identity.
git -C "$zdir" config user.email repo-local@example.com
out=$(cd "$zdir" && env -i PATH="$PATH" HOME="$home" TERM=dumb bash "$zdir/bin/zsh-doctor")
check "identity ignores cwd repo" "$out" "WARN  user.email" "not set"
check "repo-local identity named" "$out" "INFO  Repo checkout identity" "user.email"
absent "repo-local value not printed" "$out" "repo-local@example.com"
git -C "$zdir" config --unset user.email

# Include inside a Host block applies to that host only.
printf 'Host github.com\n  User git\n  Include ~/.config/zsh/ssh/baseline.conf\n' >"$home/.ssh/config"
rm -f "$home/.gitconfig" "$home/.config/git/config"
: >"$home/.config/git/config"
out=$(doctor)
check "ssh scope" "$out" "WARN  ~/.ssh/config" "applies to that host only"
check "no gitconfig" "$out" "WARN  ~/.gitconfig" "missing"
check "git config not a link" "$out" "WARN  ~/.config/git/config" "regular file"

# ssh's agent: an IdentityAgent from ssh_config beats SSH_AUTH_SOCK, which ssh-add uses.
# ssh reads the passwd home's config, not $HOME's, so `ssh -G` is stubbed; ssh-add is real.
if command -v ssh-agent >/dev/null 2>&1 && command -v ssh-add >/dev/null 2>&1; then
  mkdir -p "$tmp/stub"
  # shellcheck disable=SC2016  # literal script content
  printf '#!/bin/sh\n[ "$1" = -G ] && [ -n "$STUB_IA" ] && printf "identityagent %%s\\n" "$STUB_IA"\nexit 0\n' >"$tmp/stub/ssh"
  chmod +x "$tmp/stub/ssh"
  eval "$(ssh-agent -a "$tmp/agent.sock" -s)" >/dev/null
  out=$(doctor PATH="$tmp/stub:$PATH" SSH_AUTH_SOCK="$tmp/agent.sock" STUB_IA="$tmp/nope.sock")
  check "ssh agent via IdentityAgent" "$out" "WARN  SSH agent" "IdentityAgent SSH_AUTH_SOCK"
  out=$(doctor PATH="$tmp/stub:$PATH" SSH_AUTH_SOCK="$tmp/agent.sock" STUB_IA=SSH_AUTH_SOCK)
  check "ssh agent reachable, empty" "$out" "INFO  SSH agent" "no keys loaded yet"
  out=$(doctor PATH="$tmp/stub:$PATH" STUB_IA="$tmp/nope.sock")
  check "ssh agent unreachable" "$out" "WARN  SSH agent" "not reachable"
  ssh-agent -k >/dev/null
fi

# IdentityFile paths that do not exist (a machine imported from another Mac).
: >"$home/.ssh/present.pub"
printf 'Host a\n  IdentityFile /Users/old.name/.ssh/k.pub\nHost b\n  IdentityFile=~/.ssh/present.pub\nHost c\n  IdentityFile ~/.ssh/id_%%r\n\nMatch all\n  Include ~/.config/zsh/ssh/baseline.conf\n' >"$home/.ssh/config"
out=$(doctor)
check "missing IdentityFile" "$out" "WARN  SSH IdentityFile" "/Users/old.name/.ssh/k.pub"
absent "present IdentityFile" "$out" "present.pub"
absent "token IdentityFile skipped" "$out" "id_%r"

# Commented-out include.
printf '# Include ~/.config/zsh/ssh/baseline.conf\n' >"$home/.ssh/config"
out=$(doctor)
check "ssh commented" "$out" "WARN  ~/.ssh/config" "commented out"

# ~/.config/zsh links to a path that is gone (a machine imported from another Mac).
mv "$zdir" "$tmp/moved"
ln -s /Users/old.name/.config/zsh "$zdir"
out=$(cd "$home" && env -i PATH="$PATH" HOME="$home" TERM=dumb bash "$tmp/moved/bin/zsh-doctor")
check "dangling config link" "$out" "WARN  ~/.config/zsh" "does not exist"
check "config not loaded" "$out" "WARN  Config loaded" "did not run"
absent "no PASS for ZDOTDIR" "$out" "PASS  ZDOTDIR"
check "broken git link" "$out" "WARN  ~/.config/git/ignore" "link is broken"
rm "$zdir"
mv "$tmp/moved" "$zdir"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
