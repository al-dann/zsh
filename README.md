# zsh

Zsh configuration for four targets, from one repo:

| Target | Notes | Setup |
|--------|-------|-------|
| macOS, personal laptop | Admin rights, Homebrew | [New Mac](#new-mac-personal), step by step |
| macOS, company laptop | No admin rights, externally managed; everything installs under `$HOME` | [Other targets](#other-targets) |
| Fedora, OrbStack guest | Reached with `orb -m <machine>` from the macOS host | [Other targets](#other-targets) |
| Fedora, standalone | Same as the guest, plus fonts | [Other targets](#other-targets) |

The config never assumes a tool is installed: every external tool is guarded, so a
fresh or locked-down machine gets a working shell and gains features as tools appear.

## Layout

| File | Loaded by | Purpose |
|------|-----------|---------|
| `.zshenv` | every zsh | Environment only: XDG, editor, Go, PATH (incl. Homebrew prefix detection) |
| `.zprofile` | login shells | macOS: restores PATH order after `path_helper` (incl. `local.zshenv` entries) |
| `.zshrc` | interactive shells | Terminal, history, completion, then the files below |
| `aliases.zsh`, `fzf.zsh`, `bindings.zsh`, `plugins.zsh`, `prompt.zsh` | `.zshrc` | Modules |
| `os/linux.zsh` | `.zshrc` on Linux | dnf update aliases |
| `os/orbstack.zsh` | `.zshrc` inside an OrbStack guest | `DOCKER_HOST` for the host's engine |
| `os/darwin.zsh` | `.zshrc` on macOS | brew update aliases; `orb` in Ghostty: colour theme per OrbStack machine |
| `local.zshenv` | end of `.zshenv` (every zsh) | Machine-local environment: proxy, CA bundle, `GOPRIVATE` (git-ignored; see `local.zshenv.example`) |
| `local.zsh` | `.zshrc`, last | Machine-local interactive overrides (git-ignored; see `local.zsh.example`) |
| `tools/gup.json` | `gup import --file=...` | Go CLI tools every machine gets; versions are the baseline |
| `git/ignore`, `git/config` | git (via `~/.config/git/` symlinks) | Global gitignore and git defaults; `~/.gitconfig` overrides |
| `ssh/baseline.conf` | `~/.ssh/config` (`Include` at the end) | SSH client defaults |
| `install.sh` | you, once per machine | Links and bootstrap files; never overwrites |
| `bin/posture` | you, on demand (on PATH) | Read-only security check |
| `bin/zsh-doctor` | you, on demand (on PATH) | Read-only check that this config is installed as described here |

## New Mac (personal)

Follow the steps in order: each one needs the one before. Use Terminal.app until Ghostty
is installed in step 3.

### 1. Homebrew

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

The installer ([brew.sh](https://brew.sh)) asks for your password and installs Apple's
Command Line Tools, which bring `git`. When it finishes it prints *Next steps* that append a
`brew shellenv` line to a `.zprofile`. **Skip them.** Run only this, in the current window:

```sh
eval "$(/opt/homebrew/bin/brew shellenv)"
```

From step 2 on, `.zshenv` finds Homebrew in every new shell by itself. If you already ran
the *Next steps*, the line went to `~/.zprofile` (before step 2; `install.sh` flags it) or
to this repo's `.zprofile` (after step 2, because the installer follows `ZDOTDIR`;
`zsh-doctor` flags it). Delete `~/.zprofile`, or undo the repo change with
`git -C ~/.config/zsh checkout -- .zprofile`.

### 2. The config

```sh
git clone https://github.com/al-dann/zsh ~/.config/zsh
```

HTTPS, because there is no SSH key yet; step 5 switches the remote to SSH.

```sh
~/.config/zsh/install.sh --dry-run    # shows what it would do
~/.config/zsh/install.sh
```

It creates `~/.zshenv`, `~/.gitconfig` and `~/.ssh/config` where they don't exist, and links
`~/.config/git/config` and `~/.config/git/ignore` ([details](#what-installsh-sets-up)). It
never overwrites: anything in the way is printed as an `ACTION` line, with exit status 1.
Fix each one and run it again until it ends with `Done`. On a new Mac the usual one is
`~/.zprofile`, written by Homebrew or OrbStack: zsh no longer reads it once this config is
in place, and `.zshenv` already does what its lines did, so delete it.

Open a new window. The first start downloads the plugins (a few seconds, once).

### 3. Packages

```sh
brew install git jq neovim bat eza fd fzf ripgrep zoxide starship direnv lf go shellcheck pre-commit gh
brew install --cask ghostty orbstack gcloud-cli
brew install --cask font-jetbrains-mono-nerd-font   # for VS Code's terminal and Terminal.app; Ghostty has the icons built in
```

Homebrew owns every tool it carries, and `bubu` updates them all
([aliases](#package-manager-aliases)). Never `go install` one of them as well: `~/go/bin`
comes first on PATH, so that copy silently wins (`zsh-doctor` reports any tool found twice).
macOS's own zsh 5.9 is used; Homebrew's zsh is not needed.

Quit Terminal.app and continue in Ghostty. New shells pick up the new tools (prompt,
fzf keys, `eza`, ...).

### 4. Go tools

Go CLIs that Homebrew does not carry come from `go install` and are updated with
[`gup`](https://github.com/nao1215/gup). The shared set is [`tools/gup.json`](./tools/gup.json):

```sh
go install github.com/nao1215/gup@latest
gup import --file="$ZDOTDIR/tools/gup.json"   # the shared set, at the recorded versions
gup update                                    # then the latest of each
```

`gup import` prints a line only as each tool finishes, and cosign's first build takes
several minutes; `--timeout 20m` turns a stall into an error that names the `go install`
to retry. Then check the binaries for known vulnerabilities (one binary per run; exit
status 3 means findings):

```sh
for b in ~/go/bin/*; do echo "== ${b##*/}"; govulncheck -mode=binary "$b"; done
```

`tenv`, in the set, owns `terraform`, `tofu`, `terragrunt`, `terramate` and `atmos`: don't
install those with Homebrew, nor Homebrew's `tenv`. Policy for the set: [Go tools](#go-tools).

### 5. Git identity and signing

One SSH key per machine, for GitHub and for signing commits. A private key never leaves the
machine it was made on.

```sh
ssh-keygen -t ed25519 -C "$USER@$(hostname -s)"
```

Give it a passphrase; the SSH baseline stores it in the macOS keychain the first time the
key is used. On GitHub (Settings → SSH and GPG keys → New SSH key) add
`~/.ssh/id_ed25519.pub` **twice**: as an *Authentication Key* and as a *Signing Key*.
Without the second, GitHub shows your signed commits as *Unverified*.

Add a GitHub block to `~/.ssh/config`, **above** the `Match all` lines `install.sh` wrote
there (ssh keeps the first value it finds, so the baseline below only fills gaps):

```
Host github.com
  IdentityFile ~/.ssh/id_ed25519.pub   # the public key is enough: the agent holds the private one
  IdentitiesOnly yes
```

Fill in `~/.gitconfig` (`install.sh` created it nearly empty; it overrides the shared
[`git/config`](./git/config)). For the email, your GitHub no-reply address (GitHub →
Settings → Emails) keeps your own address out of public commits:

```ini
[user]
	name = Your Name
	email = 12345678+you@users.noreply.github.com
	signingkey = ~/.ssh/id_ed25519.pub
[gpg]
	format = ssh
[gpg "ssh"]
	allowedSignersFile = ~/.config/git/allowed_signers   # lets `git log --show-signature` verify
[commit]
	gpgsign = true
[tag]
	gpgsign = true
```

```sh
echo "$(git config user.email) $(<~/.ssh/id_ed25519.pub)" >| ~/.config/git/allowed_signers
```

(`>|` because this config sets `NO_CLOBBER`, which makes `>` refuse to replace a file.)

Switch this repo to SSH, then check:

```sh
git -C ~/.config/zsh remote set-url origin git@github.com:al-dann/zsh.git
ssh -T git@github.com    # "Hi <you>! You've successfully authenticated ..."
```

Then the CLIs: `gh auth login` (its token goes to the keychain), and gcloud with your own
login plus impersonation, see [gcloud without key files](#gcloud-without-key-files).

### 6. Ghostty and OrbStack

Ghostty: with a non-US keyboard layout, `Alt+C` (fuzzy `cd`) needs one line in
`~/.config/ghostty/config` (why: [Keybindings](#keybindings)):

```
keybind = alt+c=esc:c
```

OrbStack: its first-launch setup can add `source ~/.orbstack/shell/init.zsh` to a
`.zprofile`. It is not needed (`.zshenv` puts `orb` on PATH and adds its completions), and
`install.sh` or `zsh-doctor` flags it; remove it as in step 1. A colour theme per machine:
[OrbStack machines in Ghostty](#orbstack-machines-in-ghostty).

### 7. Optional

- Claude Code: the native installer (a binary in `~/.local/bin`), then its
  [status line](#claude-code-status-line): `bash ~/.config/zsh/claude/install.sh`.
- `lf` icons, pinned to a release tag. lf shows them only with `set icons true` in its `lfrc`:

  ```sh
  mkdir -p ~/.config/lf
  curl -fsSL https://raw.githubusercontent.com/gokcehan/lf/r42/etc/icons.example -o ~/.config/lf/icons
  echo 'set icons true' >>| ~/.config/lf/lfrc
  ```

- Changing this repo: `pre-commit install` in `~/.config/zsh` ([Development](#development)).

### 8. Check

```sh
zsh-doctor   # this setup, as described here
posture      # security: FileVault, firewall, keys, credentials
```

`zsh-doctor` should end with `0 warning(s)`. `INFO` lines for `git` and `jq` found twice
are expected: Homebrew's copies win over Apple's.

## Other targets

Not yet rewritten as a step-by-step sequence like the [New Mac](#new-mac-personal) one; the
order is the same (config, then packages, then Go tools, then identity). Where Homebrew is
missing, the Go CLIs it would carry (`fzf`, `direnv`, `lf`) come from `go install` instead.

### macOS — company laptop (no admin)

Nothing below needs `sudo`. Check your company's software policy first: endpoint protection
may block or report unsigned binaries.

- **Company proxy / TLS interception**: export the proxy and CA variables in the current
  window *before* anything downloads (clone, Homebrew, Go), then put them in
  `local.zshenv` (from `local.zshenv.example`) right after the clone and before
  `install.sh`, so every new shell and the plugin download use them. Both local files are
  loaded only if owned by you and not group/world-writable (`chmod 600`).
- **Homebrew** — use it if the company provides it (Self Service / pre-installed); then follow
  the personal list. A user-local Homebrew in `~/homebrew` is detected too, but it is
  unsupported upstream and builds most formulae from source.
- **Go** — official tarball into `~/.local/go` (`.zshenv` adds `~/.local/go/bin` when it
  exists, so open a new window after unpacking). Compare the SHA-256 with the one listed on
  <https://go.dev/dl/>. To update, remove `~/.local/go` first: unpacking over an existing
  tree leaves a broken Go ([go.dev/doc/install](https://go.dev/doc/install)).

  ```sh
  v=go1.27.3   # current release from https://go.dev/dl/
  curl -fsSLO "https://go.dev/dl/${v}.darwin-arm64.tar.gz"
  shasum -a 256 "${v}.darwin-arm64.tar.gz"
  mkdir -p ~/.local && rm -rf ~/.local/go && tar -C ~/.local -xzf "${v}.darwin-arm64.tar.gz"
  ```

- **Go-based tools** — [`gup import`](#4-go-tools), plus:

  ```sh
  go install github.com/junegunn/fzf@latest
  go install github.com/direnv/direnv/v2@latest
  go install github.com/gokcehan/lf@latest      # lf tags (rNN) are not semver, so not in gup.json
  ```

- **Rust-based tools** (`starship`, `zoxide`, `eza`, `fd`, `ripgrep`, `bat`) — upstream release
  binaries for `aarch64-apple-darwin` into `~/.local/bin`, verifying each release's checksum.
  All of them are optional.
- **Nerd Font** — copy the `.ttf` files into `~/Library/Fonts` (per-user, no admin).
- **Shell** — zsh is already the default login shell on macOS; nothing to change.

### Fedora — OrbStack guest

```sh
sudo dnf install zsh git jq neovim ripgrep fd-find fzf zoxide bat eza direnv
sudo dnf install shellcheck pre-commit gh
```

- `eza` is in Fedora 43+ (it was retired in Fedora 42; on 42 use the upstream binary).
- `lf`: `go install github.com/gokcehan/lf@latest` after Go is installed (below).
- Install the config from the **Mac's** checkout (OrbStack mounts `/Users` at the same path).
  It links `~/.config/zsh` to it, so host and guest never drift, while history and caches
  stay per machine:

  ```sh
  /Users/<you>/.config/zsh/install.sh
  ```

- Make zsh the login shell (`install.sh` does not):

  ```sh
  sudo usermod --shell "$(command -v zsh)" "$USER"
  ```

- Ghostty's terminfo entry (`xterm-ghostty`) is not in the guest: Fedora 44's `ncurses-term`
  6.6 does not include it. Copy it from the Mac, where Ghostty ships it, once per machine (run
  on the Mac, in Ghostty):

  ```sh
  infocmp -x xterm-ghostty | orb -m <machine> tic -x -
  ```

  This writes `~/.terminfo` in the guest, so it covers your user only, not `sudo`. Check with
  `infocmp xterm-ghostty` in the guest. Without it, `.zshrc` falls back to
  `TERM=xterm-256color`, which works but loses Ghostty-specific terminal features.
- No fonts needed: the macOS terminal renders the glyphs.
- Per-machine environment (e.g. `GOOGLE_CLOUD_PROJECT` for a client's machine) goes in
  `local.zshenv`, keyed on `$HOST` (see `local.zshenv.example`). That file is shared with the
  Mac, and this way it reaches every shell in the guest, not only those opened with `orb`.
- Git and SSH: the guest uses the Mac's forwarded SSH agent, so it has no key files. In its
  `~/.gitconfig` set `signingkey` to the key itself (`key::ssh-ed25519 AAAA...`). For HTTPS
  (no keyring in the guest) use `gh auth setup-git`.

Starship and Go come from COPRs:

```sh
sudo dnf copr enable atim/starship        # the COPR starship.rs points to for Fedora
sudo dnf install starship
```

```sh
sudo dnf copr enable @go-sig/golang-rawhide   # Fedora Go SIG: Rawhide's Go on stable Fedora
sudo dnf install golang
```

COPRs are not reviewed by Fedora. A COPR repo file with a `priority=` line can silently replace
Fedora packages of the same name; after enabling, this should print nothing:

```sh
grep -H '^priority' /etc/yum.repos.d/_copr*.repo
```

Why the newest Go rather than stock Fedora Go: gopls, golangci-lint and govulncheck type-check your
code with the standard library of the Go that *built* them. `GOTOOLCHAIN=auto` (set in `.zshenv`)
covers `go build`, but not tools built with an older toolchain.

### Fedora — standalone

As the guest, except: clone the repo and run `install.sh` from the clone (as on the Mac);
Ghostty's terminfo comes with Ghostty; HTTPS credentials via `git-credential-libsecret`
with a desktop session. Plus a Nerd Font (pinned release, checksum verified):

```sh
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/JetBrainsMono.tar.xz" \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz
echo "04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf  $tmp/JetBrainsMono.tar.xz" | sha256sum -c -
mkdir -p ~/.local/share/fonts/JetBrainsMono
tar -C ~/.local/share/fonts/JetBrainsMono -xJf "$tmp/JetBrainsMono.tar.xz" && fc-cache -f
rm -rf "$tmp"
```

## Reference

### What `install.sh` sets up

`install.sh` is idempotent and never overwrites or edits an existing file. It:
- links `~/.config/zsh` (when the repo lives elsewhere), `~/.config/git/config` and `~/.config/git/ignore`;
- creates `~/.zshenv` (the bootstrap below), an empty `~/.gitconfig` and `~/.ssh/config`
  (with the SSH baseline include) only if they don't exist;
- prints an `ACTION` line, and exits 1, for anything already in the way: an existing file at a
  link location, `~/.zshenv` without `ZDOTDIR`, a set `core.excludesFile`, or an existing
  `~/.ssh/config` without the baseline include, or an existing `~/.zprofile`, `~/.zshrc`,
  `~/.zlogin` or `~/.zlogout`. Once `ZDOTDIR` is set, zsh no longer reads those from your home
  directory, so their contents (a PATH line, for example) must move into `local.zshenv` or
  `local.zsh`.

The rest of this section describes what it sets up, for doing it by hand or merging.

**Bootstrap** — `~/.zshenv` (works everywhere, no admin needed):

```sh
cat > ~/.zshenv <<'EOF'
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -r $ZDOTDIR/.zshenv ]] && source "$ZDOTDIR/.zshenv"
EOF
```

zsh reads `~/.zshenv` before `ZDOTDIR` is known, which is why it sources the repo's `.zshenv`
itself; `.zprofile` and `.zshrc` are then read from `ZDOTDIR` automatically. Installers that
follow `ZDOTDIR` (Homebrew's *Next steps*, for one) therefore write into this repo's
`.zprofile`; `git -C ~/.config/zsh status` should stay clean.

**Global git baseline** — [`git/ignore`](./git/ignore) (files no repo should ever commit:
OS metadata, editor swap files, per-user AI agent settings, direnv cache, `.local/` scratch,
local env overrides, Terraform state/plans) and [`git/config`](./git/config) (defaults:
`pull.ff=only`, `fetch.prune`, `transfer.fsckObjects`, `merge.conflictStyle=zdiff3`, rerere,
`rebase.autoSquash/updateRefs`, histogram diffs, ...).

```sh
git config --global --get core.excludesFile   # must print nothing, or git skips git/ignore
touch ~/.gitconfig                            # must exist, or `git config --global` writes into the repo
mkdir -p ~/.config/git
ln -s ~/.config/zsh/git/ignore ~/.config/git/ignore
ln -s ~/.config/zsh/git/config ~/.config/git/config
```

Git reads `~/.config/git/config` first and `~/.gitconfig` second, so `~/.gitconfig` overrides
the baseline and holds what differs per machine: `user.name`/`user.email` (personal vs
company), commit signing, credential helpers, `url.*.insteadOf`. A pre-commit hook rejects
those keys in `git/config`. Check where a value comes from with
`git config --show-origin --get <key>`.

A separate company identity for everything under `~/work/`, in `~/.gitconfig`:

```ini
[includeIf "gitdir:~/work/"]            # trailing / = everything below; repos only, not the dir itself
	path = ~/.config/git/work.inc          # [user] email / signingkey for the company
```

Credentials: prefer SSH remotes. For HTTPS, macOS uses the keychain (`osxkeychain`, Apple git's
default); on Fedora with a desktop session use `git-credential-libsecret`; in the OrbStack guest
(no keyring) use `gh auth setup-git`, and check `gh auth status` for where the token is stored.

Both files are a personal safety net: teammates and CI don't see them, so each repo still
needs its own `.gitignore` for project files.

**SSH client baseline** — [`ssh/baseline.conf`](./ssh/baseline.conf): `AddKeysToAgent`,
`ForwardAgent no`, `ForwardX11 no`, `HashKnownHosts`, keep-alives, macOS keychain passphrases.
Include it at the **end** of `~/.ssh/config`; ssh takes the first value it finds, so host blocks
above it override the defaults:

```
Host github.com
  IdentityFile ~/.ssh/id_ed25519.pub   # the public key is enough when the agent holds the private one
  IdentitiesOnly yes

Match all
  Include ~/.config/zsh/ssh/baseline.conf
```

`IdentitiesOnly` and connection sharing (`ControlMaster`) are per host on purpose: a global
`IdentitiesOnly` offers no keys where they exist only in an agent (the OrbStack guest uses the Mac's
forwarded agent), and a shared master socket lets any process running as you reuse an
authenticated connection.

### Go tools

Rule: one owner per tool. The platform package manager owns what it carries; `go install`
(updated with `gup`) covers the rest. Never both: `~/go/bin` is first on PATH and silently wins.

Each machine updates at its own pace with `gup update`, which writes nothing to the repo.
`tools/gup.json` is the set every machine gets: adding or removing a tool, or raising the recorded
versions, is a repo change on a branch with a PR. Tools only one machine needs are installed with
`go install` and stay out of it. `gup export --output` prints this machine's set as a starting
point; drop its machine-only tools before committing.

### gcloud without key files

Use your own login plus service-account impersonation instead of downloaded service-account
keys; credentials are short-lived and nothing sits on disk to leak:

```sh
gcloud auth login
gcloud auth application-default login --impersonate-service-account=SA@PROJECT.iam.gserviceaccount.com
gcloud config configurations create <client-project>   # one configuration per client/project
gcloud config set auth/impersonate_service_account SA@PROJECT.iam.gserviceaccount.com
```

You need `roles/iam.serviceAccountTokenCreator` on the service account. Separate configurations
keep clients apart: `gcloud config configurations activate <name>`, or per directory with
`export CLOUDSDK_ACTIVE_CONFIG_NAME=<name>` in that project's `.envrc`.

## Updating a machine

macOS and standalone Fedora pull; OrbStack guests use the Mac's checkout and skip the pull.

```sh
old=$(git -C ~/.config/zsh rev-parse HEAD)
git -C ~/.config/zsh pull                    # fast-forward only (git/config)
git -C ~/.config/zsh diff --stat "$old" HEAD # what changed
```

Then, by what changed:

| Changed | Do |
|---------|----|
| anything | Start a new shell. Plugins whose pinned SHA changed are fetched again |
| `install.sh` | Run it again, in each OrbStack guest too (idempotent; adds new links) |
| `local.zshenv.example`, `local.zsh.example` | `git -C ~/.config/zsh diff "$old" HEAD -- '*.example'`; copy what applies into the local files |
| `tools/gup.json` | `gup import --file="$ZDOTDIR/tools/gup.json"`, then `gup update`: import installs the recorded versions, which can be older than this machine's |

Packages themselves: `bubu` / `dnfur` (see [aliases](#package-manager-aliases)) and `gup update`
([Go tools](#go-tools)). Then `zsh-doctor`: a package update can rewrite a startup file
(Homebrew, OrbStack) or add a second copy of a tool.

## OrbStack machines in Ghostty

On the Mac, in Ghostty, `orb` (default machine) and `orb -m <machine>` switch the current
split to the machine's colour theme and restore Ghostty's configured colours when the guest
shell exits, also on Ctrl+C, keeping the exit status ([`os/darwin.zsh`](./os/darwin.zsh)).
The same goes for `orb run`/`exec`/`shell` and the `-u`, `-w`, `-s` and `-p` flags. Only opening
a shell is themed: `orb list`, `orb -m <machine> <command>` and any form it does not recognise
run untouched. Outside Ghostty (Terminal.app, VS Code, tmux) `orb` is not wrapped.

Map machines to themes in `local.zsh`:

```zsh
ORB_GHOSTTY_THEMES=( dev 'Monokai Pro' work 'TokyoNight' scratch '' )   # '' = no theme
ORB_GHOSTTY_THEME_DEFAULT='Ubuntu'   # machines not listed (the default); '' = off
```

- Names as `ghostty +list-themes` prints them, or an absolute path to a theme file. Looked up
  where Ghostty looks: `~/.config/ghostty/themes/`, then the app's bundled themes. A name that
  stops resolving (bundled themes come from iTerm2-Color-Schemes and can be renamed) prints
  `orb: Ghostty theme not found: <name>` and runs `orb` unthemed.
- Applied: palette, foreground, background, cursor colour. Ghostty implements no escape
  sequence for selection colours, so those stay the host's.
- Not covered: `ssh <machine>@orb`, IDE remotes, or anything else that does not go through `orb`.

**`orb` on PATH.** OrbStack's shell integration puts `source ~/.orbstack/shell/init.zsh` in
`~/.zprofile`, which zsh no longer reads once `ZDOTDIR` is set (`install.sh` flags the file).
`.zshenv` does what that file does (appends `~/.orbstack/bin` to PATH and its completions to
`fpath`), so the line can be dropped.

## Security check (`posture`)

`posture` (in [`bin/`](./bin/posture), on PATH) reports this machine's security state. It is
read-only: it changes nothing, never uses `sudo`, and prints names and paths but never secret
values. Run it when you like; it is not part of shell startup.

```sh
posture             # about a second
posture --updates   # also lists pending OS updates (network, 10-30 s)
```

Each line is `PASS`, `WARN`, `INFO` or `SKIP`; the exit code is the number of `WARN`s.

| Where | Checks |
|-------|--------|
| macOS | FileVault, firewall and stealth mode, Gatekeeper, SIP, automatic security and XProtect updates (and whether the MDM manages them), screen lock, SSH server listening, MDM enrolment |
| Fedora standalone | LUKS disk encryption, firewalld, SELinux, dnf-automatic |
| OrbStack guest | SELinux; disk and firewall are skipped (the Mac provides them) |
| Everywhere | `~/.ssh` and key permissions, keys without a passphrase (FIDO2 `-sk` keys noted), gcloud default credentials (key file vs user login vs impersonation), service-account key files in `~` or `~/Downloads`, `gh` token in the keyring or a plain file, `~/.git-credentials`, `~/.netrc`, Docker registry logins stored in the config file, secret-looking environment variable names, permissions of `local.zshenv`/`local.zsh` |

On a company laptop it only reports; settings managed by the MDM are labelled as such and are
fixed through IT. Commands that turn out to need admin rights report `SKIP`, never a false `PASS`.

## Setup check (`zsh-doctor`)

`zsh-doctor` (in [`bin/`](./bin/zsh-doctor), on PATH) checks that this machine is set up as
this README describes. It starts one login shell with a clean environment, as a new terminal
window does, and reports what that shell gets: `ZDOTDIR`, PATH order (Homebrew before
`/usr/bin`, `~/go/bin` present), plugins, startup errors, and every tool found twice on PATH
(a copy under `~` next to a package manager's breaks the one-owner rule). It also checks the
files `install.sh` manages, startup files in `~` that zsh no longer reads, the login shell,
local file permissions, git identity and signing, and the SSH baseline include's position.
Read-only like `posture`: it never prints file contents, and the exit code is the number of
`WARN`s.

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

`Alt+C` on macOS: with a non-US keyboard layout (British, for one) Ghostty sends *Option*+C as
`ç`, so the binding never fires. `macos-option-as-alt = true` fixes that but also stops
*Option*+3 typing `#`; instead make only *Option*+C act as *Alt*, in the Ghostty config:

```
keybind = alt+c=esc:c
```

## History

- Stored in `~/.local/state/zsh/history` (mode 600) with timestamps; `history` shows them.
- A command starting with a space is not recorded.
- Lines containing `token`, `secret`, `passw`, `api_key`, `bearer`, `authorization:` stay in the
  session's memory but are not written to the file.

## Package manager aliases

Update and maintenance only; install and search are typed in full. Names from oh-my-zsh's brew
and dnf plugins. Defined only where the package manager is installed.

| Step | macOS (`os/darwin.zsh`) | Fedora (`os/linux.zsh`) |
|------|-------------------------|-------------------------|
| Refresh metadata | `bu` | `dnfmc` |
| List pending upgrades | `bo` | `dnfcu` (exit status 100 if any) |
| Refresh, then list | `bubo` | |
| Upgrade | `bup` | `dnfu` |
| Refresh, list, upgrade | `bubu` | `dnfur` (refresh, upgrade) |
| Upgrade incl. self-updating casks, then clean up | `bugbc` | |
| Remove unneeded dependencies | `ba` | `dnfa` |
| Clean caches | `bcn` | `dnfc` |
| Check for problems | `bdr` | |

`brew upgrade` and `brew outdated` refresh metadata themselves once it is 24 h old, dnf once a
repo's `metadata_expire` (48 h by default) has passed; the refresh aliases force it. Casks marked
`auto_updates` (gcloud-cli, OrbStack, Ghostty) are skipped by `bup` and upgraded by `bugbc`.

## Starship config

[`starship.toml`](./starship.toml), loaded via `STARSHIP_CONFIG` in `.zshenv`. Requires a
[Nerd Font](https://www.nerdfonts.com) in the terminal. Without starship a minimal prompt is used.

## Claude Code status line

Install Claude Code with the native installer (a standalone binary in `~/.local/bin`, no Node.js);
`claude doctor` shows the install method. An old npm install can be removed once the native one works.

Claude Code sources this zsh config once per session and replays its aliases and options in the
shell its Bash tool uses. Human-only behaviour (`ls`/`cat` replacements, the `-` alias, `NO_CLOBBER`,
`RM_STAR_WAIT`) is skipped when `CLAUDECODE` is set. Check what Claude's shell actually gets by asking
Claude Code to run `alias; setopt`: `ls` should not be `eza`, and `noclobber` should not be listed.


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
| Guards | every commit (`pre-commit install`) | gitleaks, private keys, large files, case conflicts, merge markers, YAML/TOML/JSON parse, shebangs, whitespace/EOF, `zsh -n`, conventional commit messages, blocks on committing `local.zsh`, `local.zshenv`, `.claude/`, `.copilot/`, `.gemini/`, `.local/`, `plugins/`, and on identity/credentials in `git/config` |
| Judgements | `pre-commit run --hook-stage manual --all-files` | shellcheck, shfmt (diff and write), actionlint, status line, posture, zsh-doctor and `orb` wrapper tests |

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
