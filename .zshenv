# ~/.config/zsh/.zshenv
#
# Sourced by EVERY zsh, interactive or not (scripts, `zsh -c`, editors, IDEs).
# Environment only: no output, no external commands, nothing interactive.
# Interactive setup lives in .zshrc; macOS login-shell PATH repair in .zprofile.

: ${ZDOTDIR:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh}
export ZDOTDIR

# ---------- XDG base directories ----------
# Respect values already provided by the OS/session.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# ---------- Editor ----------
export EDITOR="nvim"
export VISUAL="nvim"

# ---------- Go ----------
export GOPATH="$HOME/go"
# Overrides Fedora's GOTOOLCHAIN=local (/usr/lib/golang/go.env): lets `go` fetch
# the toolchain a module's go.mod requires (verified against sum.golang.org).
export GOTOOLCHAIN="auto"

# ---------- Starship ----------
export STARSHIP_CONFIG="$ZDOTDIR/starship.toml"

# ---------- macOS Terminal.app ----------
# Stop /etc/zshrc_Apple_Terminal keeping per-session history copies in ~/.zsh_sessions.
[[ $OSTYPE == darwin* ]] && export SHELL_SESSIONS_DISABLE=1

# ---------- PATH ----------
typeset -U path PATH fpath FPATH

# Prepends user/Homebrew dirs. Called again from .zprofile on macOS, because
# /etc/zprofile runs path_helper, which moves these behind the system dirs.
_zsh_setup_path() {
  local prefix
  # Homebrew: Apple Silicon, Intel, user-local (no-admin) installs, Linuxbrew.
  for prefix in /opt/homebrew /usr/local "$HOME/homebrew" "$HOME/.homebrew" /home/linuxbrew/.linuxbrew; do
    if [[ -x $prefix/bin/brew ]]; then
      export HOMEBREW_PREFIX=$prefix
      path=("$prefix/bin" "$prefix/sbin" $path)
      fpath=("$prefix/share/zsh/site-functions" $fpath)
      break
    fi
  done

  # (N/) keeps a dir only if it exists, so absent tools leave no dead entries.
  path=(
    "$HOME"/.local/bin(N/)
    "$ZDOTDIR"/bin(N/)                             # this repo's scripts (posture)
    "$GOPATH"/bin(N/)
    "$HOME"/.local/go/bin(N/)                      # user-local Go tarball (no-admin macOS)
    "$HOME"/google-cloud-sdk/bin(N/)               # gcloud tarball install
    $path
  )
  # gcloud via Homebrew cask (Fedora RPM installs into /usr/bin already)
  [[ -n $HOMEBREW_PREFIX ]] && path=("$HOMEBREW_PREFIX"/share/google-cloud-sdk/bin(N/) $path)

  # OrbStack (macOS): what its ~/.orbstack/shell/init.zsh adds, sourced from ~/.zprofile,
  # which zsh no longer reads with ZDOTDIR set. Appended, as OrbStack does.
  path+=("$HOME"/.orbstack/bin(N/))
  fpath+=("$HOME"/.orbstack/shell/completions/zsh(N/))
}
_zsh_setup_path

# ---------- Homebrew ----------
if [[ -n $HOMEBREW_PREFIX ]]; then
  export HOMEBREW_NO_ANALYTICS=1
  # Refuse HTTPS -> HTTP redirects on downloads. Homebrew notes that some
  # SourceForge/GNU/GNOME-hosted sources then fail; unset for that one install.
  export HOMEBREW_NO_INSECURE_REDIRECT=1
fi

# ---------- Machine-local environment (git-ignored; see local.zshenv.example) ----------
# (N.U^IW): a plain file owned by you and not group/world-writable, else skipped.
_zlocal=( "$ZDOTDIR"/local.zshenv(N.U^IW) ); (( $#_zlocal )) && source "$_zlocal[1]"; unset _zlocal
