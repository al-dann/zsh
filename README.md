# zsh

Zsh configuration.

## Dependencies

### Fedora

Add repo to install starship:

```sh
sudo dnf copr enable atim/starship
```

```sh
sudo dnf install git bat zsh eza fd fzf zoxide starship ripgrep
sudo dnf install python nodejs jq neovim golang golangci-lint gh
sudo dnf install shellcheck direnv make pre-commit
```

### macOS

```sh
brew install git zsh neovim eza bat fd fzf zoxide starship ripgrep
```

## Setup

**1. Clone the repo**

```sh
git clone https://github.com/al-dann/zsh ~/.config/zsh
```

**2. Point zsh at the config directory**

Add the following configuratio to a `zshenv` file:

    - `/etc/zsh/zshenv` (macOS?)
    - `/etc/zshenv` (Fedora - you might need 'sudo' permissions)`

```sh
if [[ -z "$XDG_CONFIG_HOME" ]]
then
    export XDG_CONFIG_HOME="$HOME/.config"
fi

if [[ -d "$XDG_CONFIG_HOME/zsh" ]]
then
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi
```

**3. Set zsh as your default shell**

Simple case:

```sh
chsh -s $(which zsh)
```

Or:

```sh
sudo chsh -s $(which zsh) $USER
```

if required add zsh into the list of shells:

```sh
echo $(which zsh) | sudo tee -a /etc/shells
```
check results:

```sh
getent passwd $USER
```

```sh
chsh -s $(which zsh)
```

**4. Create required directories**

```sh
mkdir -p ~/.local/state/zsh   # history
mkdir -p ~/.cache/zsh         # completion cache
mkdir -p ~/.config/lf         # for the `lf` file manager
```

and download icons if requried:

```sh
curl -sS https://raw.githubusercontent.com/gokcehan/lf/master/etc/icons.example -o ~/.config/lf/icons
```

**5. Start a new shell**

Plugins are installed automatically on first launch via the built-in plugin manager.

## Plugins

Managed without a third-party plugin manager. Plugins are cloned into `$ZDOTDIR/plugins/` on first launch.

| Plugin | Purpose |
|--------|---------|
| [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) | Syntax highlighting |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-style inline suggestions |
| [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) | Up/down arrow history filtering |
| [zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode) | Vi keybindings |

To update all plugins:

```sh
zplugin-update
```

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl+R` | Fuzzy history search (fzf) |
| `Ctrl+T` | Fuzzy file search including hidden files (fzf + fd) |
| `Ctrl+F` | Fuzzy file search excluding hidden files (fzf + fd) |
| `Ctrl+→` | Move forward one word |
| `Ctrl+←` | Move backward one word |
| `↑` / `↓` | History search by prefix |
| `Ctrl+\` | Toggle autosuggestions |

## Starship Config

Included in the repo at [`starship.toml`](./starship.toml) and loaded automatically via `STARSHIP_CONFIG` in `.zshenv`. Requires a [Nerd Font](https://www.nerdfonts.com) in your terminal.
