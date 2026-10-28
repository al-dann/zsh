# =========================================================
# fzf
# =========================================================
# Key bindings (Ctrl+R/T, Alt+C) are loaded in zvm_after_init (bindings.zsh).

# Never export FZF_CTRL_T_COMMAND / FZF_ALT_C_COMMAND as empty strings: fzf treats an
# empty value as "disable this key binding". Without fd they stay unset and fzf's
# built-in walker is used (hidden files included, .git and node_modules skipped).
if (( $+commands[fd] )); then
  # strip-cwd-prefix removes the leading ./ from results
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --strip-cwd-prefix'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git --strip-cwd-prefix'
fi

# UI
export FZF_DEFAULT_OPTS='
  --height=60%
  --layout=reverse
  --border=rounded
  --prompt="  "
  --pointer="  "
  --preview-window=right:65%:wrap:border-left
  --color=fg+:reverse:bold,bg+:-1
'
# Current line in reverse video: readable on any terminal theme, unlike the default
# dark-grey bg+ which can be nearly invisible on dark themes.

if (( $+commands[bat] )); then
  export _FZF_PREVIEW_CMD='bat --color=always --style=plain,numbers --line-range=:500 {}'
else
  export _FZF_PREVIEW_CMD='head -500 {}'
fi
export FZF_CTRL_T_OPTS="--preview '$_FZF_PREVIEW_CMD'"

# Ctrl+F: file picker excluding hidden files
_fzf_file_no_hidden() {
  local result
  if (( $+commands[fd] )); then
    result=$(fd --type f --strip-cwd-prefix | fzf --preview "$_FZF_PREVIEW_CMD")
  else
    result=$(find . -type f -not -path '*/.*' | fzf --preview "$_FZF_PREVIEW_CMD")
  fi
  # (q) quotes spaces/metacharacters; LBUFFER is the text left of the cursor
  [[ -n $result ]] && LBUFFER+="${(q)result}"
  zle reset-prompt
}
zle -N _fzf_file_no_hidden
