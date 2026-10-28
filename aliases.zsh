# =========================================================
# Listing / viewing (only when the replacement tool is installed)
# =========================================================

if (( $+commands[eza] )); then
  alias ls='eza --icons'
  alias ll='eza -lh --icons --git'           # detailed listing
  alias la='eza -lah --icons --git'          # including hidden files
  alias tree='eza --tree --icons'
fi

if (( $+commands[bat] )); then
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

alias -- -='cd -'  # -- prevents - being parsed as a flag; cd - jumps to previous directory

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
