# ~/.config/zsh/os/darwin.zsh — macOS host

# =========================================================
# Homebrew
# =========================================================
# The aliases of oh-my-zsh's brew plugin (ohmyzsh/ohmyzsh@b509b1c6,
# plugins/brew/README.md), written out in full instead of chaining aliases.
# The plugin's PATH, HOMEBREW_PREFIX and completion setup is done by .zshenv.

if (( $+commands[brew] )); then
  alias ba='brew autoremove'                                     # Uninstall unneeded dependencies
  alias bcfg='brew config'                                       # Homebrew and system config
  alias bdr='brew doctor'                                        # Check for problems
  alias bcn='brew cleanup'                                       # Remove old versions and caches

  alias bi='brew install'                                        # Install formula
  alias bih='brew install --HEAD'                                # Install formula from HEAD
  alias br='brew reinstall'                                      # Reinstall formula
  alias brh='brew reinstall --HEAD'                              # Reinstall formula from HEAD
  alias bl='brew list'                                           # List installed formulae and casks
  alias bs='brew search'                                         # Search formulae and casks
  alias brewp='brew pin'                                         # Pin formula (no upgrades)
  alias brewsp='brew list --pinned'                              # List pinned formulae

  alias bu='brew update'                                         # Update Homebrew and its metadata
  alias bo='brew outdated'                                       # List outdated formulae and casks
  alias bup='brew upgrade'                                       # Upgrade outdated, unpinned
  alias bfu='brew upgrade --formula'                             # Upgrade formulae only
  alias bubo='brew update && brew outdated'                      # Update, then list outdated
  alias bubu='brew update && brew outdated && brew upgrade'      # Update, list, upgrade
  alias bubc='brew upgrade && brew cleanup'                      # Upgrade, then clean up (older oh-my-zsh)
  alias bugbc='brew upgrade --greedy && brew cleanup'            # Upgrade incl. auto-updating casks, clean up
  alias bubug='brew update && brew outdated && brew upgrade --greedy && brew cleanup'

  alias bci='brew info --cask'                                   # Cask info
  alias bcin='brew install --cask'                               # Install cask
  alias bcrin='brew reinstall --cask'                            # Reinstall cask
  alias bcl='brew list --cask'                                   # List installed casks
  alias bco='brew outdated --cask'                               # List outdated casks
  alias bcup='brew upgrade --cask'                               # Upgrade casks
  alias bcubo='brew update && brew outdated --cask'              # Update, then list outdated casks
  alias bcubc='brew upgrade --cask && brew cleanup'              # Upgrade casks, then clean up
  alias buz='brew uninstall --zap'                               # Uninstall cask with all its files

  alias bsl='brew services list'                                 # List services
  alias bson='brew services start'                               # Start and register at login
  alias bsona='brew services start --all'
  alias bsoff='brew services stop'                               # Stop and unregister
  alias bsoffa='brew services stop --all'
  alias bsr='brew services run'                                  # Run without registering
  alias bsra='brew services run --all'

  # Leaf formulae with their installed dependencies (blue), then casks.
  brews() {
    local -a leaves=( ${(f)"$(brew leaves)"} )
    local line blue=$'\e[34m' off=$'\e[0m'
    print -P '%F{blue}==>%f %BFormulae%b'
    if (( $#leaves )); then
      for line in ${(f)"$(brew deps --installed --for-each $leaves)"}; do
        print -r -- "${line/:/$blue}$off"   # "name: deps" -> name, deps in blue
      done
    fi
    print -P '\n%F{blue}==>%f %BCasks%b'
    brew list --cask 2>/dev/null
  }
fi

# =========================================================
# OrbStack guests in Ghostty: one colour theme per machine
# =========================================================
# `orb` or `orb -m <machine>` (an interactive shell in a guest; also `orb shell`, `orb -s`)
# switches this Ghostty split to the machine's theme, and restores the configured colours
# when orb returns, also on Ctrl+C. Everything else (`orb list`, `orb -m dev ls`) runs
# untouched.
# Themes are Ghostty theme names (`ghostty +list-themes`) or absolute paths; set them
# in local.zsh:
#   ORB_GHOSTTY_THEMES=( dev 'Monokai Pro' work 'TokyoNight' )
#   ORB_GHOSTTY_THEME_DEFAULT=''      # machines not listed: '' = leave colours alone
typeset -gA ORB_GHOSTTY_THEMES
typeset -g ORB_GHOSTTY_THEME_DEFAULT=Ubuntu

# orb's arguments -> REPLY: the machine a login shell is opened in ('' = the default
# machine). Returns 1 for anything else: a subcommand, a command to run, an unknown flag.
# Flags as `orb run --help` lists them; `run`, `exec` and `shell` are the same command.
_orb_ghostty_machine() {
  REPLY=
  case $1 in run|exec|shell) shift ;; esac
  while (( $# )); do
    case $1 in
      -m|--machine)            (( $# > 1 )) || return 1; REPLY=$2; shift 2 ;;
      --machine=*)             REPLY=${1#*=}; shift ;;
      -m?*)                    REPLY=${1#-m}; shift ;;
      -u|--user|-w|--workdir)  (( $# > 1 )) || return 1; shift 2 ;;
      --user=*|--workdir=*|-u?*|-w?*) shift ;;
      -s|--shell|-p|--path)    shift ;;
      *) return 1 ;;
    esac
  done
}

# Machine -> REPLY: its theme ('' = none).
_orb_ghostty_theme() {
  local machine=$1
  # Bare `orb` enters the default machine; ask OrbStack which one that is.
  [[ -z $machine ]] && (( $+commands[orbctl] )) && machine=$(command orbctl default 2>/dev/null)
  REPLY=${ORB_GHOSTTY_THEMES[$machine]-$ORB_GHOSTTY_THEME_DEFAULT}
}

# Theme -> REPLY: the OSC sequences that apply it (palette, foreground, background,
# cursor). Looks where Ghostty does: user themes first, then the app's own
# (GHOSTTY_RESOURCES_DIR is set by Ghostty). Parsed in zsh: no forks.
_orb_ghostty_osc() {
  emulate -L zsh
  setopt extended_glob
  local file= dir line key val idx seq=
  if [[ $1 == /* ]]; then
    file=$1
  else
    for dir in "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/themes" ${GHOSTTY_RESOURCES_DIR:+$GHOSTTY_RESOURCES_DIR/themes}; do
      [[ -r $dir/$1 ]] && { file=$dir/$1; break }
    done
  fi
  [[ -n $file && -f $file && -r $file ]] || return 1

  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line == *=* ]] || continue
    key=${${line%%=*}//[[:space:]]/}
    val=${${line#*=}##[[:space:]]#}
    val=${${${val%%[[:space:]]#}#\"}%\"}
    [[ -n $val && $val != *[[:cntrl:]]* ]] || continue   # never relay escape bytes
    case $key in
      palette)
        idx=${${val%%=*}//[[:space:]]/} val=${${val#*=}##[[:space:]]#}
        [[ $idx == <0-255> && -n $val ]] && seq+=$'\e]4;'$idx\;$val$'\a'
        ;;
      foreground)   seq+=$'\e]10;'$val$'\a' ;;
      background)   seq+=$'\e]11;'$val$'\a' ;;
      # cell-foreground / cell-background are not colours. Ghostty has no OSC for
      # cursor-text, and ignores OSC 17/19, so selection colours stay the host's.
      cursor-color) [[ $val != cell-* ]] && seq+=$'\e]12;'$val$'\a' ;;
    esac
  done <"$file"

  [[ -n $seq ]] && REPLY=$seq
}

# TERM_PROGRAM is ghostty only directly in Ghostty: inside tmux, VS Code or
# Terminal.app the wrapper is not defined and `orb` is OrbStack's own.
if [[ $TERM_PROGRAM == ghostty ]] && (( $+commands[orb] )); then
  orb() {
    local REPLY theme
    if [[ -t 0 && -t 1 ]] && _orb_ghostty_machine "$@"; then
      _orb_ghostty_theme "$REPLY"
      theme=$REPLY
      if [[ -n $theme ]] && _orb_ghostty_osc "$theme"; then
        print -rn -- "$REPLY"
        # `always` also runs on Ctrl+C, and keeps orb's exit status.
        # OSC 104/110/111/112: back to the configured palette, fg, bg, cursor.
        { command orb "$@" } always { print -rn -- $'\e]104\a\e]110\a\e]111\a\e]112\a' }
        return
      fi
      [[ -n $theme ]] && print -ru2 -- "orb: Ghostty theme not found: $theme"
    fi
    command orb "$@"
  }
fi
