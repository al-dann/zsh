#!/usr/bin/env bash
# statusline.sh — Claude Code status line (kept in the zsh dotfiles repo: ~/.config/zsh/claude/).
# 2-line layout, cross-platform (macOS + OrbStack Linux VM).
# Receives Claude session JSON on stdin.

input=$(cat)

# --- Parse JSON fields ---
model_name=$(echo "$input" | jq -r '.model.display_name // "unknown"')
used_pct=$(echo "$input"   | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input"       | jq -r '.cost.total_cost_usd // empty')
cwd=$(echo "$input"        | jq -r '.cwd // empty')
effort=$(echo "$input"     | jq -r '.effort.level // empty')

# Use cwd from JSON for git; fall back to process cwd
branch=$(git -C "${cwd:-.}" branch --show-current 2>/dev/null)

# --- ANSI escape codes (match Starship palette) ---
Y='\033[1;33m'   # bold yellow  — hostname colour in Starship
G='\033[1;32m'   # bold green   — success / staged
C='\033[1;36m'   # bold cyan    — directory
M='\033[1;35m'   # bold magenta — branch (Starship: bold purple)
R='\033[1;31m'   # bold red     — error / high usage
O='\033[1;33m'   # bold yellow  — unstaged modified (reuse Y)
W='\033[1;37m'   # bold white   — untracked
D='\033[2m'      # dim          — separator / brackets
Z='\033[0m'      # reset

# --- Nerd Font icons via printf octal UTF-8 (macOS bash 3.2 lacks $'\u' escape support; keeps source ASCII) ---
NF_BRANCH=$(printf '\356\202\240')   # U+E0A0  Powerline branch symbol
NF_APPLE=$(printf '\357\205\271')    # U+F179  macOS  (nf-fa-apple)
NF_FEDORA=$(printf '\357\214\212')   # U+F30A  Fedora  (nf-linux-fedora)
NF_TUX=$(printf '\357\205\274')      # U+F17C  Generic Linux / Tux  (nf-fa-linux)

# --- Host / OS icon ---
host=$(hostname -s 2>/dev/null)
os=$(uname -s)
case "$os" in
  Darwin)
    os_icon="$NF_APPLE" ;;
  Linux)
    distro=""
    [[ -r /etc/os-release ]] && distro=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")
    case "$distro" in
      fedora) os_icon="$NF_FEDORA" ;;
      *)      os_icon="$NF_TUX" ;;
    esac
    ;;
  *) os_icon="$NF_TUX" ;;
esac

# --- Model short form ---
# "Claude 3.5 Sonnet" → "3.5 Sonnet", strip trailing parenthetical suffixes.
short_model=$(echo "$model_name" \
  | sed -E 's/^Claude[[:space:]]+//i' \
  | sed -E 's/[[:space:]]+\([^)]*\)$//')

# --- CWD: replace $HOME→~, abbreviate all but last 3 path components ---
shorten_cwd() {
  local path="$1"
  [[ "$path" == "$HOME"* ]] && path="~${path#$HOME}"
  local prefix="" remainder="$path"
  if [[ "$path" == "~"* ]]; then
    prefix="~"; remainder="${path:1}"
  fi
  if [[ -z "$remainder" ]]; then
    echo "$prefix"; return
  fi
  IFS='/' read -ra parts <<< "${remainder:1}"
  local n=${#parts[@]} result="$prefix"
  for ((i=0; i<n; i++)); do
    [[ -z "${parts[$i]}" ]] && continue
    if (( n - i <= 3 )); then
      result="${result}/${parts[$i]}"
    else
      result="${result}/${parts[$i]:0:1}"
    fi
  done
  echo "$result"
}
cwd_short=$(shorten_cwd "$cwd")

# --- Context bar ---
ctx_out=""
if [ -n "$used_pct" ]; then
  pct=$(printf '%.0f' "$used_pct")

  if   [ "$pct" -lt 60 ]; then bar_esc="$G"
  elif [ "$pct" -lt 85 ]; then bar_esc="$Y"
  else                          bar_esc="$R"
  fi

  filled=$(( pct / 10 ))
  bar=""
  for i in $(seq 1 10); do
    [ "$i" -le "$filled" ] && bar="${bar}█" || bar="${bar}░"
  done

  ctx_out="${bar_esc}󰾆 ${bar} ${pct}%${Z}"
fi

# --- Cost ---
cost_out=""
if [ -n "$cost" ]; then
  cost_fmt=$(printf '%.3f' "$cost")
  cost_out="${D}\$${cost_fmt}${Z}"
fi

# --- Git status flags ([+!?] after branch name) ---
git_status_out=""
if [[ -n "$branch" ]]; then
  porcelain=$(git -C "${cwd:-.}" status --porcelain 2>/dev/null || true)
  staged=$(   printf '%s\n' "$porcelain" | grep -c '^[AMDRC]' || true)
  modified=$( printf '%s\n' "$porcelain" | grep -c '^.[MD]'   || true)
  untracked=$(printf '%s\n' "$porcelain" | grep -c '^??'       || true)
  flags=""
  [[ $staged    -gt 0 ]] && flags="${flags}${G}+${Z}"
  [[ $modified  -gt 0 ]] && flags="${flags}${O}●${Z}"
  [[ $untracked -gt 0 ]] && flags="${flags}${W}?${Z}"
  [[ -n "$flags" ]] && git_status_out=" ${D}[${Z}${flags}${D}]${Z}"
fi

# --- 2-line output ---
sep="${D} ❯ ${Z}"

# Line 1: AI session info — model · context bar · cost
line1="${Y}󱙺  ${short_model}${Z}"
[ -n "$effort"   ] && line1="${line1} ${D}(${effort})${Z}"
[ -n "$ctx_out"  ] && line1="${line1}${sep}${ctx_out}"
[ -n "$cost_out" ] && line1="${line1}${sep}${cost_out}"

# Line 2: Location — OS/host · shortened CWD · git branch + status
# "»" (U+00BB) acts as the ">>" marker between OS icon and hostname, in host colour
line2="${Y}${os_icon} » ${host}${Z}"
[ -n "$cwd_short" ] && line2="${line2}${sep}${C}${cwd_short}${Z}"
[ -n "$branch"    ] && line2="${line2}${sep}${M}${NF_BRANCH} ${branch}${Z}${git_status_out}"

printf "%b\n%b\n" "$line1" "$line2"
