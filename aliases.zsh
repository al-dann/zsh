# Better ls
alias ls='eza --icons'

# Detailed listing
alias ll='eza -lh --icons --git'

# Detailed listing including hidden files
alias la='eza -lah --icons --git'

# Tree view
alias tree='eza --tree --icons'

# Reuse ls completions for eza (avoids defining a separate completion function)
compdef eza=ls

# Better cat
alias cat='bat'

# History with date and time
alias history='fc -il 1'

# =========================================================
# Core utilities
# =========================================================

alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

# =========================================================
# Navigation
# =========================================================

alias -- -='cd -'  # -- prevents - being parsed as a flag; cd - jumps to previous directory

lf() { # zsh follow lf navigation
    tmp=$(mktemp)
    command lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir=$(cat "$tmp")
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
}

# =========================================================
# Editor
# =========================================================

alias vim='nvim'

# =========================================================
# Git
# =========================================================

alias glog='PAGER="less -F -X" git log'                              # -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# =========================================================
# DNF
# =========================================================

local dnfprog="dnf"

# Prefer dnf5 if installed
command -v dnf5 > /dev/null && dnfprog=dnf5

alias dnfl="${dnfprog} list"                       # List packages
alias dnfli="${dnfprog} list --installed"          # List installed packages
alias dnfmc="${dnfprog} makecache"                 # Generate metadata cache
alias dnfp="${dnfprog} info"                       # Show package information
alias dnfs="${dnfprog} search"                     # Search package

alias dnfu="sudo ${dnfprog} upgrade"               # Upgrade package
alias dnfur="sudo ${dnfprog} upgrade --refresh"    # Upgrade package and refresh repos
alias dnfi="sudo ${dnfprog} install"               # Install package
alias dnfr="sudo ${dnfprog} remove"                # Remove package
alias dnfc="sudo ${dnfprog} clean all"             # Clean cache

# Conditional aliases based on dnfprog value
if [[ "${dnfprog}" == "dnf5" ]]; then
    alias dnfgl="${dnfprog} group list"            # List package groups (dnf5)
    alias dnfgi="sudo ${dnfprog} group install"    # Install package group (dnf5)
    alias dnfgr="sudo ${dnfprog} group remove"     # Remove package group (dnf5)
else
    alias dnfgl="${dnfprog} grouplist"             # List package groups (dnf)
    alias dnfgi="sudo ${dnfprog} groupinstall"     # Install package group (dnf)
    alias dnfgr="sudo ${dnfprog} groupremove"      # Remove package group (dnf)
fi
