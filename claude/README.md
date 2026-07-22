# Claude Code status line

A two-line status bar shown inside [Claude Code](https://claude.com/claude-code) CLI sessions
(where your Starship prompt isn't visible — Claude Code owns the screen):

```
󱙺  Opus 4.8 (xhigh)  ❯  󰾆 █████░░░░░ 55%  ❯  $0.421
 » accl  ❯  ~/0_dev/accl/yt5k  ❯   dsa-3729-clean-int-tst [+●?]
```

| Line | Content |
|------|---------|
| 1 | AI session: model name · reasoning effort · context bar (colour-coded) · cumulative cost |
| 2 | Location: OS icon » hostname · shortened CWD · git branch + status flags |

- **Reasoning effort:** the model shows a dimmed `(xhigh)` pulled live from the session's `effort.level`
  (tracks mid-session `/effort` changes; hidden for models without effort support).
- **Git status flags:** `[+]` staged (green) · `[●]` modified (yellow) · `[?]` untracked (white) — colours mirror `starship.toml`.
- **Context bar colours:** green < 60% · yellow 60–84% · red ≥ 85%.
- **CWD shortening:** last 3 path components in full, everything above → first letter.

---

## Files

| File | Purpose |
|------|---------|
| `statusline.sh` | The status line script |
| `install.sh` | Wires the script into `~/.claude/settings.json` (idempotent) |
| `test_statusline.sh` | TDD harness (17 fixtures, 79 assertions) |

---

## Install

The `statusLine.command` in `~/.claude/settings.json` is run **through a shell**, so it uses a
`$HOME`-relative path that resolves correctly on both macOS (`/Users/…`) and the Fedora guest (`/home/…`):

```json
"statusLine": {
  "type": "command",
  "command": "$HOME/.config/zsh/claude/statusline.sh"
}
```

`install.sh` sets exactly that, merging **only** the `statusLine` key (it never clobbers other settings)
and creating `~/.claude/` if needed — so it's safe to run before Claude Code is even installed:

```sh
bash ~/.config/zsh/claude/install.sh   # requires jq
```

---

## Runtime dependencies

| Tool | Used for |
|------|----------|
| `jq` | Parse the JSON payload from Claude Code (and by `install.sh`) |
| `git` | `branch --show-current` and `status --porcelain` |
| Nerd Font | Render icons (JetBrains Mono / Hack Nerd Font recommended) |

---

## Platform behaviour (automatic, no config needed)

| Platform | `$HOME` | OS icon | CWD `~` prefix |
|----------|---------|---------|----------------|
| macOS native | `/Users/alex` | `` (Apple) | `/Users/alex/…` → `~/…` |
| Fedora Linux guest (OrbStack) | `/home/alex` | `` (Fedora) | `/home/alex/…` → `~/…` |
| Generic Linux | `/home/…` | `` (Tux) | `$HOME/…` → `~/…` |

macOS-mounted paths seen from inside the Linux guest (e.g. `/Users/alex/…`) are **not** rewritten to `~` —
they abbreviate normally to `/U/a/…`.

---

## Testing

```sh
bash ~/.config/zsh/claude/test_statusline.sh
```

Pipes 17 mock JSON payloads through the script and asserts the model name, effort suffix, shortened CWD,
git branch, cost, and git-status flags. The harness resolves `statusline.sh` from its own directory, so it
must stay in this folder next to the script.

---

## Icon encoding note

OS and branch icons (BMP Private Use Area: `` `` `` ``) are emitted via `printf` octal UTF-8 escapes
inside `statusline.sh` — e.g. `NF_APPLE=$(printf '\357\205\271')` for U+F179. This keeps the source ASCII
(so it survives copying through tools that mangle 3-byte PUA glyphs) **and** works on macOS's stock
bash 3.2.57, which does **not** support `$'\uXXXX'` escapes (added in bash 4.2). Supplementary-range icons
(`󱙺` `󰾆`) and separators (`❯` `»`) are stored as literal UTF-8 and are unaffected.
