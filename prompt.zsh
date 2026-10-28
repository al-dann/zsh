# ~/.config/zsh/prompt.zsh

# Prevent Python virtualenv from polluting the prompt
export VIRTUAL_ENV_DISABLE_PROMPT=1

if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
else
  # Minimal fallback, e.g. a managed laptop before starship is installed
  PROMPT='%F{yellow}%m%f %F{cyan}%~%f %(?.%F{green}.%F{red})❯%f '
fi
