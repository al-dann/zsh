# ~/.config/zsh/.zshrc — interactive shells

# Startup profiling, opt-in: ZSH_PROF=1 zsh -ic exit
[[ -n $ZSH_PROF ]] && zmodload zsh/zprof

# =========================================================
# Terminal
# =========================================================

# Keep the terminal's own TERM (xterm-ghostty, tmux-256color, ...) and fall back
# only when this machine has no terminfo entry for it, e.g. an OrbStack guest reached
# via `orb -m <machine>` from Ghostty before the entry was copied over (see README).
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
setopt NUMERIC_GLOB_SORT    # sort file10 after file9, not after file1
setopt INTERACTIVE_COMMENTS # allow `# comment` on the command line (pasted snippets)
setopt NO_FLOW_CONTROL      # Ctrl+S / Ctrl+Q reach zsh instead of freezing the terminal
setopt COMPLETE_IN_WORD     # complete at the cursor, not only at the end of the word
setopt ALWAYS_TO_END        # after completing inside a word, move to its end
WORDCHARS=${WORDCHARS//\//}  # Ctrl+W / Alt+B stop at '/', deleting one path segment at a time

autoload -Uz zmv            # pattern rename, e.g. zmv -n '(*).log' '$1.txt'  (-n = dry run)
# Human-only safety options. Claude Code replays this file's options in its Bash tool
# (CLAUDECODE=1 is set there); its own `cmd > file` must keep overwriting.
if [[ -z $CLAUDECODE ]]; then
  setopt NO_CLOBBER         # `>` refuses to overwrite an existing file; use `>|` to force
  setopt RM_STAR_WAIT       # 10 s pause before `rm *` / `rm path/*` can be confirmed
fi

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
  # Full run (incl. compaudit security check) at most once a day, or as soon as a
  # completion directory changed (e.g. `brew install` added a completion); otherwise
  # trust the dump.
  local -a fresh=("$dump"(N.mh-24))
  local dir
  for dir in $fpath; do
    [[ $dir -nt $dump ]] && { fresh=(); break }
  done
  if (( $#fresh )); then
    compinit -C -d "$dump"
  else
    compinit -d "$dump" && touch "$dump"
  fi
}

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # case-insensitive
# Cache for slow completers; the default path would be inside this repo ($ZDOTDIR)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"

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
  darwin*) source "$ZDOTDIR/os/darwin.zsh" ;;
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
# Store canonical paths, so the same directory reached via a symlink (e.g. the guest's
# ~/.config/zsh -> /Users/...) is one entry.
export _ZO_RESOLVE_SYMLINKS=1
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# Machine-local interactive overrides (git-ignored; environment goes in local.zshenv).
# Same ownership/permission check as local.zshenv.
_zlocal=( "$ZDOTDIR"/local.zsh(N.U^IW) ); (( $#_zlocal )) && source "$_zlocal[1]"; unset _zlocal

[[ -n $ZSH_PROF ]] && zprof
