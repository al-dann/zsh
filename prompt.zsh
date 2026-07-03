# ~/.config/zsh/prompt.zsh

# Prevent Python virtualenv from polluting the prompt
export VIRTUAL_ENV_DISABLE_PROMPT=1

FUNCNEST=100

eval "$(starship init zsh)"

# Google Cloud SDK completion (interactive)
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

# Mute zsh-autocomplete async race-condition errors on exit
autoload -Uz add-zsh-hook
_mute_exit_errors() {
  exec 2>/dev/null
}
add-zsh-hook zshexit _mute_exit_errors
export DOCKER_HOST=unix:///opt/orbstack-guest/run/docker.sock
