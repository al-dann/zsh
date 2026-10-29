#!/usr/bin/env zsh
# test_darwin.zsh — tests for the OrbStack/Ghostty theme wrapper in os/darwin.zsh.
# Runs on Linux and macOS: fake orb/orbctl on PATH, fake Ghostty theme dirs, and a
# pseudo-terminal (zsh/zpty) for the paths that only run on a terminal.
emulate -R zsh
zmodload zsh/zpty || exit 1

here=${0:A:h}
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
integer pass=0 fail=0

check() { # check <name> <actual> <expected>
  if [[ $2 == "$3" ]]; then
    (( pass++ ))
  else
    (( fail++ ))
    print -r -- "FAIL $1: expected ${(q+)3}, got ${(q+)2}"
  fi
}

# ---------- fakes ----------
mkdir -p "$tmp/bin" "$tmp/config/ghostty/themes" "$tmp/resources/themes"
cat >"$tmp/bin/orb" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$FAKE_DIR/orb.args"
echo ORB-RAN
exit "${FAKE_ORB_RC:-0}"
EOF
cat >"$tmp/bin/orbctl" <<'EOF'
#!/bin/sh
[ "$1" = default ] && [ -n "$FAKE_DEFAULT" ] && echo "$FAKE_DEFAULT"
EOF
chmod +x "$tmp/bin/orb" "$tmp/bin/orbctl"

# Bundled theme in Ghostty's format, plus lines the parser must skip or tidy.
cat >"$tmp/resources/themes/Res" <<'EOF'
# comment = ignored
palette = 0=#2d2a2e
palette=1 = #ff6188
palette = 256=#ffffff
background = "#300a24"
foreground =   #eeeeec
cursor-color = #bbbbbb
cursor-text = #ffffff
selection-background = #b5d5ff
EOF
printf 'background = #111111\ncursor-color = cell-foreground\nforeground = #222222' \
  >"$tmp/resources/themes/NoNewline"
printf 'background = #333333\n' >"$tmp/resources/themes/Shadowed"
printf 'background = #444444\n' >"$tmp/config/ghostty/themes/Shadowed"
printf 'background = #555555\nforeground = #66\e]0;x\a\n' >"$tmp/resources/themes/Escape"
printf 'cursor-text = #ffffff\n' >"$tmp/resources/themes/Empty"

export FAKE_DIR=$tmp XDG_CONFIG_HOME=$tmp/config GHOSTTY_RESOURCES_DIR=$tmp/resources
path=("$tmp/bin" $path)

# Not in Ghostty: no wrapper, `orb` stays OrbStack's command.
TERM_PROGRAM=tmux source "$here/darwin.zsh"
check "no wrapper outside ghostty" "$(whence -w orb)" "orb: command"

TERM_PROGRAM=ghostty source "$here/darwin.zsh"
check "wrapper in ghostty" "$(whence -w orb)" "orb: function"

# ---------- argument parsing ----------
machine() { # machine <args...> -> "rc:machine"
  local REPLY
  _orb_ghostty_machine "$@"
  print -r -- "$?:$REPLY"
}
check "bare orb"          "$(machine)"                         "0:"
check "-m"                "$(machine -m dev)"                  "0:dev"
check "--machine"         "$(machine --machine dev)"           "0:dev"
check "--machine="        "$(machine --machine=dev)"           "0:dev"
check "-mNAME"            "$(machine -mdev)"                   "0:dev"
check "user and workdir"  "$(machine -u root -m dev -w /tmp)"  "0:dev"
check "--user="           "$(machine --user=root -m dev)"      "0:dev"
check "-m without name"   "$(machine -m)"                      "1:"
check "subcommand"        "${$(machine list)%%:*}"             "1"
check "command in guest"  "${$(machine -m dev ls)%%:*}"        "1"
check "help"              "${$(machine -h)%%:*}"               "1"
check "unknown flag"      "${$(machine -x -m dev)%%:*}"        "1"
check "-- command"        "${$(machine -m dev -- ls)%%:*}"     "1"

# ---------- theme per machine ----------
ORB_GHOSTTY_THEMES=( dev 'Monokai Pro' off '' )
theme() { local REPLY; _orb_ghostty_theme "$1"; print -r -- "$REPLY" }
check "listed machine"      "$(theme dev)"   "Monokai Pro"
check "unlisted -> default" "$(theme other)" "Ubuntu"
check "listed as ''"        "$(theme off)"   ""
check "default machine"     "$(FAKE_DEFAULT=dev theme '')" "Monokai Pro"
check "no default machine"  "$(theme '')"    "Ubuntu"
check "no default theme"    "$(ORB_GHOSTTY_THEME_DEFAULT= theme other)" ""

# ---------- theme file -> OSC ----------
osc() { local REPLY; _orb_ghostty_osc "$1" && print -rn -- "$REPLY" || print -rn -- "rc=$?" }
e=$'\e' b=$'\a'
check "bundled theme" "$(osc Res)" \
  "$e]4;0;#2d2a2e$b$e]4;1;#ff6188$b$e]11;#300a24$b$e]10;#eeeeec$b$e]12;#bbbbbb$b"
check "no trailing newline, cell-* cursor" "$(osc NoNewline)" "$e]11;#111111$b$e]10;#222222$b"
check "user dir before bundled" "$(osc Shadowed)" "$e]11;#444444$b"
check "absolute path" "$(osc "$tmp/resources/themes/Shadowed")" "$e]11;#333333$b"
check "escape bytes dropped" "$(osc Escape)" "$e]11;#555555$b"
check "nothing usable" "$(osc Empty)" "rc=1"
check "missing theme" "$(osc Nope)" "rc=1"
check "no path traversal to a dir" "$(osc ../themes)" "rc=1"

# ---------- wrapper, not on a terminal: passthrough ----------
out=$(FAKE_ORB_RC=3 orb -m dev 2>&1)
check "no tty: no escapes" "$out" "ORB-RAN"
FAKE_ORB_RC=3 orb -m dev >/dev/null
check "no tty: exit status" "$?" "3"

# ---------- wrapper on a terminal ----------
tty_run() { # tty_run <command> -> REPLY: what it wrote to the terminal, CRs removed
  local out= chunk=
  zpty t "$1"
  while zpty -r t chunk; do out+=$chunk; done
  zpty -d t
  REPLY=${out//$'\r'/}
}
reset="$e]104$b$e]110$b$e]111$b$e]112$b"
ORB_GHOSTTY_THEMES=( dev Res )

tty_run 'FAKE_ORB_RC=7 orb -m dev; print RC=$?'
check "tty: theme, orb, reset, status" "$REPLY" \
  "$e]4;0;#2d2a2e$b$e]4;1;#ff6188$b$e]11;#300a24$b$e]10;#eeeeec$b$e]12;#bbbbbb$b"$'ORB-RAN\n'"${reset}"$'RC=7\n'
check "tty: args passed verbatim" "$(<$tmp/orb.args)" $'-m\ndev'

tty_run 'orb -m dev ls -la; print RC=$?'
check "tty: command in guest untouched" "$REPLY" $'ORB-RAN\nRC=0\n'
check "tty: command args verbatim" "$(<$tmp/orb.args)" $'-m\ndev\nls\n-la'

tty_run 'ORB_GHOSTTY_THEMES[dev]=Nope; orb -m dev; print RC=$?'
check "tty: missing theme warns, still runs" "$REPLY" \
  $'orb: Ghostty theme not found: Nope\nORB-RAN\nRC=0\n'

tty_run 'ORB_GHOSTTY_THEME_DEFAULT=; orb -m other; print RC=$?'
check "tty: no theme, untouched" "$REPLY" $'ORB-RAN\nRC=0\n'

print -r -- "$pass passed, $fail failed"
(( fail == 0 ))
