# Claude Code sources this config once per session and replays its aliases and options
# in the shell its Bash tool uses (CLAUDECODE=1 is set in shells it spawns). Aliases that
# change a standard command's flags or output are for humans only: `eza -lt` is not
# `ls -lt`. Check what Claude Code sees by asking it to run: alias; setopt
[[ -z $CLAUDECODE ]] && _human_shell=1 || _human_shell=

# =========================================================
# Listing / viewing (only when the replacement tool is installed)
# =========================================================

if [[ -n $_human_shell ]] && (( $+commands[eza] )); then
  alias ls='eza --icons'
  alias ll='eza -lh --icons --git'           # detailed listing
  alias la='eza -lah --icons --git'          # including hidden files
  alias tree='eza --tree --icons'
fi

if [[ -n $_human_shell ]] && (( $+commands[bat] )); then
  alias cat='bat'
fi

# History with date and time (needs EXTENDED_HISTORY)
alias history='fc -il 1'

# =========================================================
# Core utilities
# =========================================================

# grep stays grep: aliasing it to rg silently changes flag meanings (-r = --replace).
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

# =========================================================
# Navigation
# =========================================================

# -- prevents - being parsed as a flag; cd - jumps to previous directory.
# Human-only: Claude Code has had trouble replaying aliases whose name starts with '-'.
[[ -n $_human_shell ]] && alias -- -='cd -'

# lf: cd into the directory lf was in on exit
if (( $+commands[lf] )); then
  lf() {
    local tmp dir
    tmp=$(mktemp) || return
    command lf -last-dir-path="$tmp" "$@"
    if [[ -f $tmp ]]; then
      dir=$(<"$tmp")
      rm -f "$tmp"
      [[ -d $dir && $dir != "$PWD" ]] && cd "$dir"
    fi
  }
fi

# =========================================================
# Editor
# =========================================================

(( $+commands[nvim] )) && alias vim='nvim'

# =========================================================
# Git
# =========================================================

alias glog='PAGER="less -F -X" git log'                              # -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

unset _human_shell
