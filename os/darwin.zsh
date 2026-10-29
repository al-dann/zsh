# ~/.config/zsh/os/darwin.zsh — macOS host

# =========================================================
# OrbStack guests in Ghostty: one colour theme per machine
# =========================================================
# `orb` or `orb -m <machine>` (an interactive shell in a guest) switches this Ghostty
# split to the machine's theme, and restores the configured colours when orb returns,
# also on Ctrl+C. Everything else (`orb list`, `orb -m dev ls`) runs untouched.
# Themes are Ghostty theme names (`ghostty +list-themes`) or absolute paths; set them
# in local.zsh:
#   ORB_GHOSTTY_THEMES=( dev 'Monokai Pro' work 'TokyoNight' )
#   ORB_GHOSTTY_THEME_DEFAULT=''      # machines not listed: '' = leave colours alone
typeset -gA ORB_GHOSTTY_THEMES
typeset -g ORB_GHOSTTY_THEME_DEFAULT=Ubuntu

# orb's arguments -> REPLY: the machine a login shell is opened in ('' = the default
# machine). Returns 1 for anything else: a subcommand, a command to run, an unknown flag.
_orb_ghostty_machine() {
  REPLY=
  while (( $# )); do
    case $1 in
      -m|--machine)            (( $# > 1 )) || return 1; REPLY=$2; shift 2 ;;
      --machine=*)             REPLY=${1#*=}; shift ;;
      -m?*)                    REPLY=${1#-m}; shift ;;
      -u|--user|-w|--workdir)  (( $# > 1 )) || return 1; shift 2 ;;
      --user=*|--workdir=*|-u?*|-w?*) shift ;;
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
