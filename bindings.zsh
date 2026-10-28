# =========================================================
# Keybindings
# =========================================================

# Called by zsh-vi-mode after its defaults are set (so $ZVM_CURSOR_* exist here).
zvm_config() {
  # Cursor shape per vi mode
  ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
  ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
  ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK

  # Disable command mode line highlight
  ZVM_VI_HIGHLIGHT_BACKGROUND=none
  ZVM_VI_HIGHLIGHT_FOREGROUND=none
  ZVM_VI_HIGHLIGHT_EXTRASTYLE=none
}

# zsh-vi-mode resets all keymaps when it initialises (lazily, at the first
# prompt), so every custom binding — including fzf's — must be registered here.
zvm_after_init() {
  # fzf: Ctrl+R history, Ctrl+T files, Alt+C cd (needs fzf >= 0.48).
  # Not `$+commands[fzf]`: zsh-vi-mode runs this hook from a function with a local
  # variable named `commands`, which hides zsh's $commands table here.
  command -v fzf >/dev/null && source <(fzf --zsh)

  # Ctrl+Right / Ctrl+Left -> word movement
  bindkey '^[[1;5C' forward-word
  bindkey '^[[1;5D' backward-word

  # Ctrl+F -> fzf file picker (no hidden files)
  bindkey '^F' _fzf_file_no_hidden

  # Ctrl+\ -> toggle autosuggestions (useful for screen recordings)
  bindkey '^\' autosuggest-toggle

  # Up/Down -> history substring search. Bind both normal (^[[A) and
  # application-mode (^[OA / terminfo) sequences; k/j in vi command mode.
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey '^[OA' history-substring-search-up
  bindkey '^[OB' history-substring-search-down
  [[ -n ${terminfo[kcuu1]} ]] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
  [[ -n ${terminfo[kcud1]} ]] && bindkey "${terminfo[kcud1]}" history-substring-search-down
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
}
