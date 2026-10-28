# zsh

Zsh configuration for four targets, from one repo:

| Target | Notes |
|--------|-------|
| macOS, personal laptop | Admin rights, Homebrew |
| macOS, company laptop | No admin rights, externally managed; everything installs under `$HOME` |
| Fedora, OrbStack guest (primary Linux target) | Reached with `orb -m <machine>` from the macOS host |
| Fedora, standalone | Same as the guest, plus fonts |

The config never assumes a tool is installed: every external tool is guarded, so a
fresh or locked-down machine gets a working shell and gains features as tools appear.

## Layout

| File | Loaded by | Purpose |
|------|-----------|---------|
| `.zshenv` | every zsh | Environment only: XDG, editor, Go, PATH (incl. Homebrew prefix detection) |
| `.zprofile` | login shells | macOS: restores PATH order after `path_helper` |
| `.zshrc` | interactive shells | Terminal, history, completion, then the files below |
| `aliases.zsh`, `fzf.zsh`, `bindings.zsh`, `plugins.zsh`, `prompt.zsh` | `.zshrc` | Modules |
| `os/linux.zsh` | `.zshrc` on Linux | dnf aliases |
| `os/orbstack.zsh` | `.zshrc` inside an OrbStack guest | `DOCKER_HOST` for the host's engine |
| `local.zsh` | `.zshrc`, last | Machine-local, git-ignored (see `local.zsh.example`) |
| `tools/gup.json` | `gup import` | Go-installed CLI tools, versions recorded |
| `git/ignore` | git (via `~/.config/git/ignore` symlink) | Global gitignore |

## 1. Install packages

Rule of thumb: Go CLIs come from `go install` and are updated with [`gup`](https://github.com/nao1215/gup);
everything else comes from the platform package manager. One owner per tool: never install the
same tool both ways (`~/go/bin` is first on PATH and silently wins).

### macOS — personal (Homebrew)

```sh
brew install git jq neovim bat eza fd fzf ripgrep zoxide starship direnv lf
brew install go shellcheck pre-commit gh
brew install --cask font-jetbrains-mono-nerd-font
```

The system zsh (5.9) is used; installing Homebrew's zsh is unnecessary.

### macOS — company laptop (no admin)

Nothing below needs `sudo`. Check your company's software policy first: endpoint protection
may block or report unsigned binaries.

- **Homebrew** — use it if the company provides it (Self Service / pre-installed); then follow the
  personal list. A user-local Homebrew in `~/homebrew` is detected too, but it is unsupported
  upstream and builds most formulae from source.
- **Go** — official tarball into `~/.local/go` (`.zshenv` adds `~/.local/go/bin` when it exists).
  Compare the SHA-256 with the one listed on <https://go.dev/dl/>:

  ```sh
  v=go1.27.3   # current release from https://go.dev/dl/
  curl -fsSLO "https://go.dev/dl/${v}.darwin-arm64.tar.gz"
  shasum -a 256 "${v}.darwin-arm64.tar.gz"
  mkdir -p ~/.local && tar -C ~/.local -xzf "${v}.darwin-arm64.tar.gz"
  ```

- **Go-based tools** — `gup import` (below), plus `fzf`, `direnv`, `lf`:

  ```sh
  go install github.com/junegunn/fzf@latest
  go install github.com/direnv/direnv/v2@latest
  ```

- **Rust-based tools** (`starship`, `zoxide`, `eza`, `fd`, `ripgrep`, `bat`) — upstream release
  binaries for `aarch64-apple-darwin` into `~/.local/bin`, verifying each release's checksum.
  All of them are optional.
- **Nerd Font** — copy the `.ttf` files into `~/Library/Fonts` (per-user, no admin).
- **Shell** — zsh is already the default login shell on macOS; nothing to change.
- Company proxy / TLS interception: see `local.zsh.example`.

### Fedora — OrbStack guest

```sh
sudo dnf install zsh git jq neovim ripgrep fd-find fzf zoxide bat eza direnv
sudo dnf install ncurses-term shellcheck pre-commit gh
```

- `eza` is in Fedora 43+ (it was retired in Fedora 42; on 42 use the upstream binary).
- `ncurses-term` provides the `xterm-ghostty` terminfo entry (Fedora 42+), so Ghostty works
  through `orb -m <machine>` without overriding `TERM`. Check with `infocmp xterm-ghostty`.
  Alternative, per user, from the macOS host:
  `infocmp -x xterm-ghostty | orb -m <machine> tic -x -`.
  If neither is done, `.zshrc` falls back to `TERM=xterm-256color` automatically.
- No fonts needed: the macOS terminal renders the glyphs.

Starship and Go come from COPRs:

```sh
sudo dnf copr enable atim/starship        # the COPR starship.rs points to for Fedora
sudo dnf install starship
```

```sh
sudo dnf copr enable @go-sig/golang-rawhide   # Fedora Go SIG: Rawhide's Go on stable Fedora
sudo dnf install golang
```

Why the newest Go rather than stock Fedora Go: gopls, golangci-lint and govulncheck type-check your
code with the standard library of the Go that *built* them. `GOTOOLCHAIN=auto` (set in `.zshenv`)
covers `go build`, but not tools built with an older toolchain.

### Fedora — standalone

As the guest, plus a Nerd Font (pinned release, checksum verified):

```sh
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/JetBrainsMono.tar.xz" \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz
echo "04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf  $tmp/JetBrainsMono.tar.xz" | sha256sum -c -
mkdir -p ~/.local/share/fonts/JetBrainsMono
tar -C ~/.local/share/fonts/JetBrainsMono -xJf "$tmp/JetBrainsMono.tar.xz" && fc-cache -f
rm -rf "$tmp"
```

### Go tools (all targets)

```sh
go install github.com/nao1215/gup@latest
gup import --file="$ZDOTDIR/tools/gup.json"
go install github.com/gokcehan/lf@latest      # lf tags (rNN) are not semver, so not in gup.json
```

After updating (`gup update`), record and check:

```sh
gup export --output > "$ZDOTDIR/tools/gup.json"
govulncheck -mode=binary ~/go/bin/*
```

`tenv` owns `terraform`, `tofu` and `terragrunt`: do not install those with dnf/brew as well.

## 2. Install the config

**Clone** (macOS, standalone Fedora):

```sh
git clone https://github.com/al-dann/zsh ~/.config/zsh
```

**OrbStack guest** — reuse the macOS checkout (OrbStack mounts `/Users` at the same path), so host
and guest never drift; history and caches stay per machine:

```sh
mkdir -p ~/.config && ln -s /Users/<you>/.config/zsh ~/.config/zsh
```

**Point zsh at it** — `~/.zshenv` (works everywhere, no admin needed):

```sh
cat > ~/.zshenv <<'EOF'
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -r $ZDOTDIR/.zshenv ]] && source "$ZDOTDIR/.zshenv"
EOF
```

zsh reads `~/.zshenv` before `ZDOTDIR` is known, which is why it sources the repo's `.zshenv`
itself; `.zprofile` and `.zshrc` are then read from `ZDOTDIR` automatically.

**Default shell** (Fedora only; macOS already uses zsh):

```sh
sudo chsh -s "$(command -v zsh)" "$USER"
```

**Global gitignore** — machine-wide ignores for files no repo should ever commit
(OS metadata, editor swap files, per-user AI agent settings, direnv cache, `.local/`
scratch, local env overrides, Terraform state/plans). See [`git/ignore`](./git/ignore).

```sh
git config --global --get core.excludesFile   # must print nothing, or git ignores the file below
mkdir -p ~/.config/git && ln -s ~/.config/zsh/git/ignore ~/.config/git/ignore
```

It is a personal safety net: teammates and CI don't see it, so each repo still needs
its own `.gitignore` for project files.

## 3. Start a new shell

Plugins are fetched on first start. History (`~/.local/state/zsh`) and completion cache
(`~/.cache/zsh`) directories are created automatically.

Optional `lf` icons (pinned to a release tag):

```sh
mkdir -p ~/.config/lf
curl -fsSL https://raw.githubusercontent.com/gokcehan/lf/r42/etc/icons.example -o ~/.config/lf/icons
```

## Plugins

No third-party plugin manager. `plugins.zsh` fetches each plugin at a **pinned commit SHA** into
`$ZDOTDIR/plugins/`; changing a SHA re-fetches on the next shell start.

| Plugin | Purpose |
|--------|---------|
| [zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode) | Vi keybindings |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-style inline suggestions |
| [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) | Syntax highlighting |
| [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) | Up/down arrow history filtering |

Upgrading is review-then-pin:

```sh
zplugin-outdated                        # newest upstream tag per plugin
zplugin-diff zsh-vi-mode v0.13.0        # log + diffstat; prints the SHA to pin
```

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl+R` | Fuzzy history search (fzf) |
| `Ctrl+T` | Fuzzy file search including hidden files (fzf + fd) |
| `Alt+C` | Fuzzy `cd` (fzf + fd) |
| `Ctrl+F` | Fuzzy file search excluding hidden files |
| `Ctrl+→` / `Ctrl+←` | Move forward / backward one word |
| `↑` / `↓`, `k` / `j` (vi normal mode) | History search by substring |
| `Ctrl+\` | Toggle autosuggestions |

## History

- Stored in `~/.local/state/zsh/history` (mode 600) with timestamps; `history` shows them.
- A command starting with a space is not recorded.
- Lines containing `token`, `secret`, `passw`, `api_key`, `bearer`, `authorization:` stay in the
  session's memory but are not written to the file.

## Starship config

[`starship.toml`](./starship.toml), loaded via `STARSHIP_CONFIG` in `.zshenv`. Requires a
[Nerd Font](https://www.nerdfonts.com) in the terminal. Without starship a minimal prompt is used.

## Claude Code status line

A two-line status bar for [Claude Code](https://claude.com/claude-code) sessions lives in
[`claude/`](./claude/). Wire it into `~/.claude/settings.json` (idempotent, merges only `statusLine`):

```sh
bash ~/.config/zsh/claude/install.sh   # requires jq
```

See [`claude/README.md`](./claude/README.md).

## Development

Checks follow one rule: **guards** run on every commit, **judgements** run on demand.

| Set | When | Hooks |
|-----|------|-------|
| Guards | every commit (`pre-commit install`) | gitleaks, private keys, large files, case conflicts, merge markers, YAML/TOML/JSON parse, shebangs, whitespace/EOF, `zsh -n`, conventional commit messages, and blocks on committing `local.zsh`, `.claude/`, `.copilot/`, `.gemini/`, `.local/`, `plugins/` |
| Judgements | `pre-commit run --hook-stage manual --all-files` | shellcheck, shfmt (diff and write), actionlint, status line tests |

```sh
pre-commit install                                      # guards on commit + commit-msg
pre-commit run --hook-stage manual --all-files          # everything, as CI runs it
pre-commit run --hook-stage manual shfmt-write --all-files   # reformat claude/*.sh
```

CI (`.github/workflows/checks.yml`) runs the full set on every push to `main` and every PR,
so `--no-verify` does not skip anything. Hook revisions are frozen to commit SHAs; update
them with `pre-commit autoupdate --freeze` (check gitleaks by hand: its newest tag may not
be on the default branch).

This repo is a baseline for a new machine; individual repositories keep their own
`.pre-commit-config.yaml` and `.gitignore` on top.
