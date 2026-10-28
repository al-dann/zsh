# ~/.config/zsh/os/linux.zsh — Linux (Fedora: OrbStack guest or standalone)

# =========================================================
# DNF (Fedora 41+: `dnf` is dnf5)
# =========================================================

if (( $+commands[dnf] )); then
  alias dnfl='dnf list'                       # List packages
  alias dnfli='dnf list --installed'          # List installed packages
  alias dnfmc='dnf makecache'                 # Generate metadata cache
  alias dnfp='dnf info'                       # Show package information
  alias dnfs='dnf search'                     # Search package

  alias dnfu='sudo dnf upgrade'               # Upgrade package
  alias dnfur='sudo dnf upgrade --refresh'    # Upgrade package and refresh repos
  alias dnfi='sudo dnf install'               # Install package
  alias dnfr='sudo dnf remove'                # Remove package
  alias dnfc='sudo dnf clean all'             # Clean cache

  alias dnfgl='dnf group list'                # List package groups
  alias dnfgi='sudo dnf group install'        # Install package group
  alias dnfgr='sudo dnf group remove'         # Remove package group
fi
