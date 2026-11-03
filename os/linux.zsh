# ~/.config/zsh/os/linux.zsh — Linux (Fedora: OrbStack guest or standalone)

# =========================================================
# DNF: the update cycle (Fedora 41+: `dnf` is dnf5)
# =========================================================
# Same rule as the brew aliases in os/darwin.zsh: update and maintenance only;
# install, search and groups are typed in full. Names from oh-my-zsh's dnf plugin,
# plus dnfcu and dnfa for the steps it has no alias for.
# `dnf upgrade` refreshes a repo's metadata only once it has expired (metadata_expire,
# 48 h unless the .repo file sets less); `dnfur` forces it.

if (( $+commands[dnf] )); then
  alias dnfmc='dnf makecache'                 # Refresh metadata now
  alias dnfcu='dnf check-upgrade'             # List available upgrades (exit 100 if any)
  alias dnfu='sudo dnf upgrade'               # Upgrade
  alias dnfur='sudo dnf upgrade --refresh'    # Refresh metadata, then upgrade
  alias dnfa='sudo dnf autoremove'            # Remove dependencies nothing needs
  alias dnfc='sudo dnf clean all'             # Remove cached metadata and packages
fi
