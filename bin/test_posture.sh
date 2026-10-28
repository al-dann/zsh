#!/usr/bin/env bash
# shellcheck disable=SC2088  # '~/...' strings are expected display text
# test_posture.sh — tests for bin/posture against a fake $HOME and stubbed OS tools.
# Runs on Linux and macOS; the macOS branch is exercised with stub commands on PATH.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
posture="$here/posture"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0

check() { # check <name> <output> <expected substring> [second substring on the same line]
  if printf '%s\n' "$2" | grep -F -- "$3" | grep -qF -- "${4:-$3}"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s: expected %s\n' "$1" "$3"
  fi
}
absent() { # absent <name> <output> <unexpected substring>
  if printf '%s\n' "$2" | grep -qF -- "$3"; then
    fail=$((fail + 1))
    printf 'FAIL %s: unexpected %s\n' "$1" "$3"
  else
    pass=$((pass + 1))
  fi
}

# ---------- fake home with known problems ----------
home="$tmp/home"
mkdir -p "$home/.ssh" "$home/Downloads/keys" "$home/.config/gcloud" "$home/.config/zsh" "$home/.docker"
chmod 755 "$home/.ssh"
if command -v ssh-keygen >/dev/null 2>&1; then
  ssh-keygen -q -t ed25519 -N '' -f "$home/.ssh/id_plain" -C t >/dev/null
  ssh-keygen -q -t ed25519 -N '' -f "$home/.ssh/id_open" -C t >/dev/null
  ssh-keygen -q -t ed25519 -N 'pw-for-test' -f "$home/.ssh/id_locked" -C t >/dev/null
  chmod 644 "$home/.ssh/id_plain"
  have_keygen=1
else
  have_keygen=0
fi
printf '{"type": "service_account", "private_key": "placeholder"}\n' >"$home/Downloads/keys/proj-123.json"
printf '{"type": "authorized_user", "refresh_token": "x"}\n' >"$home/.config/gcloud/application_default_credentials.json"
chmod 644 "$home/.config/gcloud/application_default_credentials.json"
printf 'https://u:p@example.com\n' >"$home/.git-credentials"
printf '{"auths": {"r.example.com": {"auth": "dTpw"}}}\n' >"$home/.docker/config.json"
printf 'export X=1\n' >"$home/.config/zsh/local.zshenv"
chmod 666 "$home/.config/zsh/local.zshenv"

run() { # run [extra env...] -- posture args
  env -i PATH="$PATH" HOME="$home" TERM=dumb "$@"
}

# ---------- current OS (Linux in CI) ----------
out=$(run FAKE_API_TOKEN=s3cr3t-value bash "$posture")
rc=$?
check "header" "$out" "posture: "
check "ssh dir perms" "$out" "WARN  ~/.ssh permissions"
if [ "$have_keygen" -eq 1 ]; then
  check "key perms" "$out" "~/.ssh/id_plain is 644"
  check "no passphrase" "$out" "~/.ssh/id_open has no passphrase" "WARN"
  check "passphrase ok" "$out" "~/.ssh/id_locked protected" "PASS"
  check "loose key not tested" "$out" "~/.ssh/id_plain: fix its permissions first" "SKIP"
fi
check "sa key file" "$out" "~/Downloads/keys/proj-123.json"
check "adc user" "$out" "INFO  gcloud ADC"
check "adc perms" "$out" "WARN  gcloud ADC permissions"
check "git-credentials" "$out" "WARN  ~/.git-credentials"
check "docker auth" "$out" "WARN  Docker registry login"
check "env secret name" "$out" "FAKE_API_TOKEN"
absent "env secret value" "$out" "s3cr3t-value"
check "local.zshenv perms" "$out" "local.zshenv permissions"
check "exit code = warnings" "$out" "$rc warning(s)."
absent "no network without --updates" "$out" "Pending"

# ---------- macOS branch with stub tools ----------
stubs="$tmp/stubs"
mkdir -p "$stubs"
stub() { # stub <name> <output> [exit code]
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\nexit %s\n' "$2" "${3:-0}" >"$stubs/$1"
  chmod +x "$stubs/$1"
}
stub uname "Darwin"
stub fdesetup "FileVault is Off."
stub socketfilterfw "Firewall is enabled. (State = 1)"
stub spctl "assessments enabled"
stub csrutil "System Integrity Protection status: enabled."
stub sysadminctl "screenLock delay is immediate"
stub profiles "Enrolled via DEP: No\nMDM enrollment: Yes (User Approved)"
stub softwareupdate "No new software available."
cat >"$stubs/defaults" <<'EOF'
#!/bin/sh
# Managed prefs: CriticalUpdateInstall=0 forced by MDM; nothing else set.
case "$1 $2 $3" in
  "read /Library/Managed Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall") echo 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$stubs/defaults"

out=$(env -i PATH="$stubs:$PATH" HOME="$home" TERM=dumb bash "$posture" --updates)
check "mac header" "$out" "posture: Darwin"
check "filevault off" "$out" "WARN  Disk encryption (FileVault)"
check "firewall on" "$out" "PASS  Firewall"
check "gatekeeper" "$out" "PASS  Gatekeeper"
check "sip" "$out" "PASS  System Integrity Protection"
check "managed update off" "$out" "Auto security updates" "WARN"
check "managed source shown" "$out" "off (managed by MDM)"
check "default xprotect on" "$out" "Auto XProtect/data updates" "on (default)"
check "screen lock" "$out" "PASS  Screen lock"
check "mdm" "$out" "INFO  MDM"
check "updates opt-in" "$out" "PASS  Pending OS updates"

stub sysadminctl "screenLock delay is 5 seconds"
out=$(env -i PATH="$stubs:$PATH" HOME="$home" TERM=dumb bash "$posture")
check "5 s screen lock ok" "$out" "Screen lock" "PASS"
stub sysadminctl "screenLock delay is 300 seconds"
out=$(env -i PATH="$stubs:$PATH" HOME="$home" TERM=dumb bash "$posture")
check "5 min screen lock warns" "$out" "Screen lock" "WARN"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
