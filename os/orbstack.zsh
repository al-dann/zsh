# ~/.config/zsh/os/orbstack.zsh — OrbStack Linux guest (sourced when /opt/orbstack-guest exists)

# Docker engine of the macOS host, exposed inside the guest
[[ -S /opt/orbstack-guest/run/docker.sock ]] \
  && export DOCKER_HOST=unix:///opt/orbstack-guest/run/docker.sock
