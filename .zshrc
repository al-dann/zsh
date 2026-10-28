# ~/.config/zsh/.zshrc — interactive shells

# =========================================================
# Terminal
# =========================================================

# Keep the terminal's own TERM (xterm-ghostty, tmux-256color, ...) and fall back
# only when this machine has no terminfo entry for it, e.g. an OrbStack guest
# without ncurses-term reached via `orb -m <machine>` from Ghostty.
if (( $+commands[infocmp] )) && ! infocmp "$TERM" &>/dev/null; then
  export TERM=xterm-256color
fi

export GPG_TTY=$TTY

# =========================================================
# History
# =========================================================

HISTFILE="$XDG_STATE_HOME/zsh/history"
[[ -d ${HISTFILE:h} ]] || mkdir -p -m 700 "${HISTFILE:h}"
HISTSIZE=110000   # must exceed SAVEHIST for HIST_EXPIRE_DUPS_FIRST to have room
SAVEHIST=100000

setopt EXTENDED_HISTORY        # timestamps + durations; `history` alias shows them
setopt SHARE_HISTORY           # implies incremental append; don't add APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE       # leading space = not recorded
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY             # !! expansions are shown before running

# Keep likely secrets out of the history FILE (return 2 = this session's
# in-memory history only). Prefix a command with a space to skip history entirely.
zshaddhistory() {
  emulate -L zsh
  [[ ${1:l} == *(token|secret|passw|api_key|apikey|bearer|authorization:)* ]] && return 2
  return 0
}

# =========================================================
# Shell behaviour
# =========================================================

setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT  # sort file10 after file9, not after file1

# =========================================================
# Pager
# =========================================================

if (( $+commands[bat] )); then
  export MANPAGER="bat -plman"
elif (( $+commands[batcat] )); then
  export MANPAGER="batcat -plman"
fi

# =========================================================
# Completion
# =========================================================

autoload -Uz compinit
() {
  local dump="$XDG_CACHE_HOME/zsh/zcompdump"
  [[ -d ${dump:h} ]] || mkdir -p "${dump:h}"
  # Full run (incl. compaudit security check) at most once a day; trust the dump otherwise.
  local -a fresh=("$dump"(N.mh-24))
  if (( $#fresh )); then
    compinit -C -d "$dump"
  else
    compinit -d "$dump" && touch "$dump"
  fi
}

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # case-insensitive

# gcloud completion: tarball, Homebrew cask, Fedora RPM
() {
  local sdk
  for sdk in "$HOME/google-cloud-sdk" "${HOMEBREW_PREFIX:-/nonexistent}/share/google-cloud-sdk" \
             /usr/lib64/google-cloud-sdk /usr/lib/google-cloud-sdk; do
    [[ -r $sdk/completion.zsh.inc ]] && { source "$sdk/completion.zsh.inc"; break; }
  done
}

# =========================================================
# Modular config files
# =========================================================

source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/fzf.zsh"
source "$ZDOTDIR/bindings.zsh"   # defines zvm_config / zvm_after_init before the plugin loads
source "$ZDOTDIR/plugins.zsh"
source "$ZDOTDIR/prompt.zsh"

case $OSTYPE in
  darwin*) [[ -r $ZDOTDIR/os/darwin.zsh ]] && source "$ZDOTDIR/os/darwin.zsh" ;;
  linux*)
    source "$ZDOTDIR/os/linux.zsh"
    [[ -d /opt/orbstack-guest ]] && source "$ZDOTDIR/os/orbstack.zsh"
    ;;
esac

# =========================================================
# Tool hooks (each optional)
# =========================================================

(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

# zoxide must come after compinit (zoxide README)
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# Machine-local interactive overrides (git-ignored; environment goes in local.zshenv).
# Same ownership/permission check as local.zshenv.
_zlocal=( "$ZDOTDIR"/local.zsh(N.U^IW) ); (( $#_zlocal )) && source "$_zlocal[1]"; unset _zlocal
