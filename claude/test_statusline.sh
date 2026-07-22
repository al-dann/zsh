#!/usr/bin/env bash
# test_statusline.sh — TDD harness for statusline.sh
# Pipes 15 mock JSON payloads into the script and asserts:
#   host indicator · model name · shortened CWD · git branch · cost · git status flags

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/statusline.sh"
PASS=0
FAIL=0
TMPDIRS=()
trap 'rm -rf "${TMPDIRS[@]}"' EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────

strip_ansi() {
  sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
}

# Identical algorithm to the one in statusline.sh — last 3 components full,
# rest abbreviated to first letter; $HOME → ~.
shorten_cwd() {
  local path="$1"
  [[ "$path" == "$HOME"* ]] && path="~${path#$HOME}"
  local prefix="" remainder="$path"
  if [[ "$path" == "~"* ]]; then
    prefix="~"; remainder="${path:1}"
  fi
  if [[ -z "$remainder" ]]; then
    echo "$prefix"; return
  fi
  IFS='/' read -ra parts <<< "${remainder:1}"
  local n=${#parts[@]} result="$prefix"
  for ((i=0; i<n; i++)); do
    [[ -z "${parts[$i]}" ]] && continue
    if (( n - i <= 3 )); then
      result="${result}/${parts[$i]}"
    else
      result="${result}/${parts[$i]:0:1}"
    fi
  done
  echo "$result"
}

# Create a bare git repo (no commits); git branch --show-current reads from HEAD.
make_git_repo() {
  local branch="$1" basedir="${2:-/tmp}"
  local dir
  dir=$(mktemp -d "${basedir}/tst_sl_XXXXXX")
  TMPDIRS+=("$dir")
  git -C "$dir" init -q
  git -C "$dir" symbolic-ref HEAD "refs/heads/$branch"
  echo "$dir"
}

make_plain_dir() {
  local basedir="${1:-/tmp}"
  local dir
  dir=$(mktemp -d "${basedir}/tst_sl_XXXXXX")
  TMPDIRS+=("$dir")
  echo "$dir"
}

# Repo with staged (index-only) new file — porcelain shows "A  staged.txt"
make_git_repo_staged() {
  local branch="$1" basedir="${2:-/tmp}"
  local dir
  dir=$(make_git_repo "$branch" "$basedir")
  printf 'staged\n' > "${dir}/staged.txt"
  git -C "$dir" add "${dir}/staged.txt"
  echo "$dir"
}

# Repo with one untracked file — porcelain shows "?? untracked.txt"
make_git_repo_untracked() {
  local branch="$1" basedir="${2:-/tmp}"
  local dir
  dir=$(make_git_repo "$branch" "$basedir")
  printf 'untracked\n' > "${dir}/untracked.txt"
  echo "$dir"
}

# Repo with all three states: staged new file + unstaged modified file + untracked file.
# Requires an initial commit so the tracked file can be modified.
make_git_repo_all_states() {
  local branch="$1" basedir="${2:-/tmp}"
  local dir
  dir=$(make_git_repo "$branch" "$basedir")
  # Initial commit — tracked file
  printf 'original\n' > "${dir}/tracked.txt"
  git -C "$dir" add "${dir}/tracked.txt"
  git -C "$dir" -c user.name=CI -c user.email=ci@ci.test commit -q -m init
  # Unstaged modification to tracked file
  printf 'modified\n' > "${dir}/tracked.txt"
  # Staged new file
  printf 'new\n' > "${dir}/staged.txt"
  git -C "$dir" add "${dir}/staged.txt"
  # Untracked file
  printf 'untracked\n' > "${dir}/untracked.txt"
  echo "$dir"
}

assert_contains() {
  local label="$1" output="$2" expected="$3"
  if printf '%s' "$output" | grep -qF -- "$expected"; then
    printf '    \033[32mPASS\033[0m %s\n' "$label"
    (( PASS++ )) || true
  else
    printf '    \033[31mFAIL\033[0m %s\n         expected : %s\n         in output : %s\n' \
      "$label" "$expected" "$(printf '%s' "$output" | tr '\n' '|')"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local label="$1" output="$2" unexpected="$3"
  if printf '%s' "$output" | grep -qF -- "$unexpected"; then
    printf '    \033[31mFAIL\033[0m %s\n         did NOT expect : %s\n         in output : %s\n' \
      "$label" "$unexpected" "$(printf '%s' "$output" | tr '\n' '|')"
    (( FAIL++ )) || true
  else
    printf '    \033[32mPASS\033[0m %s\n' "$label"
    (( PASS++ )) || true
  fi
}

# run_fixture <name> <cwd> <model|"null"> <ctx_pct> <branch|""> <cost> <exp_model> [git_flags]
#   git_flags: optional literal string expected in output, e.g. "[+]" "[+!?]"
run_fixture() {
  local name="$1" cwd="$2" model="$3" ctx_pct="$4" branch="$5" cost="$6" exp_model="$7"
  local git_flags="${8:-}"

  local payload
  if [[ "$model" == "null" ]]; then
    payload=$(printf '{"model":null,"context_window":{"used_percentage":%s},"cost":{"total_cost_usd":%s},"cwd":"%s"}' \
      "$ctx_pct" "$cost" "$cwd")
  else
    payload=$(printf '{"model":{"display_name":"%s"},"context_window":{"used_percentage":%s},"cost":{"total_cost_usd":%s},"cwd":"%s"}' \
      "$model" "$ctx_pct" "$cost" "$cwd")
  fi

  local raw output
  raw=$(printf '%s' "$payload" | bash "$SCRIPT" 2>/dev/null)
  output=$(printf '%s\n' "$raw" | strip_ansi)

  local cost_str cwd_short
  cost_str=$(printf '$%.3f' "$cost")
  cwd_short=$(shorten_cwd "$cwd")

  printf '\n\033[1mFixture: %s\033[0m\n' "$name"
  printf '  %s\n' "$output"

  assert_contains "host ($(hostname -s))"  "$output" "$(hostname -s)"
  assert_contains "model ($exp_model)"      "$output" "$exp_model"
  assert_contains "CWD ($cwd_short)"        "$output" "$cwd_short"
  [[ -n "$branch"    ]] && assert_contains "branch ($branch)"       "$output" "$branch"
  assert_contains "cost ($cost_str)"        "$output" "$cost_str"
  [[ -n "$git_flags" ]] && assert_contains "git status ($git_flags)" "$output" "$git_flags"
}

# ── Fixtures F1–F12: feature coverage ────────────────────────────────────────

# F1 — Baseline: Sonnet 4.6, low context, main branch
d=$(make_git_repo main)
run_fixture "F1  Sonnet 4.6  20%  main  \$0.042" \
  "$d" "Claude Sonnet 4.6" 20 "main" 0.042 "Sonnet 4.6"

# F2 — Opus, medium context, feature branch
d=$(make_git_repo feat/new-auth)
run_fixture "F2  Opus 4.7  65%  feat/new-auth  \$1.500" \
  "$d" "Claude Opus 4.7" 65 "feat/new-auth" 1.500 "Opus 4.7"

# F3 — Haiku, high context (red bar), HOME subdir — tests ~ prefix
d=$(make_git_repo hotfix/critical-bug "$HOME")
run_fixture "F3  Haiku 4.5  92%  hotfix/critical-bug  \$0.003  (HOME subdir)" \
  "$d" "Claude Haiku 4.5" 92 "hotfix/critical-bug" 0.003 "Haiku 4.5"

# F4 — 3.5 Sonnet, zero context (empty bar), release branch
d=$(make_git_repo release/v2.1.0)
run_fixture "F4  3.5 Sonnet  0%  release/v2.1.0  \$5.200" \
  "$d" "Claude 3.5 Sonnet" 0 "release/v2.1.0" 5.200 "3.5 Sonnet"

# F5 — Opus, 100% context (full red bar), real branch name from this repo
d=$(make_git_repo dsa-3729-clean-int-tst)
run_fixture "F5  Opus 4.7  100%  dsa-3729-clean-int-tst  \$12.000" \
  "$d" "Claude Opus 4.7" 100 "dsa-3729-clean-int-tst" 12.000 "Opus 4.7"

# F6 — HOME itself; no git repo → branch absent (no assertion)
run_fixture "F6  Haiku 4.5  45%  \$HOME (no git, branch skipped)  \$0.001" \
  "$HOME" "Claude Haiku 4.5" 45 "" 0.001 "Haiku 4.5"

# F7 — Sonnet, yellow bar range (60–84%), chore branch
d=$(make_git_repo chore/update-deps)
run_fixture "F7  Sonnet 4.6  78%  chore/update-deps  \$0.750" \
  "$d" "Claude Sonnet 4.6" 78 "chore/update-deps" 0.750 "Sonnet 4.6"

# F8 — null model → "unknown"; zero cost
d=$(make_git_repo main)
run_fixture "F8  null model → unknown  55%  main  \$0.000" \
  "$d" "null" 55 "main" 0.000 "unknown"

# F9 — Second HOME-subdir test with different branch (fix branch type)
d=$(make_git_repo fix/login-redirect "$HOME")
run_fixture "F9  Sonnet 4.6  33%  fix/login-redirect  \$0.250  (HOME subdir)" \
  "$d" "Claude Sonnet 4.6" 33 "fix/login-redirect" 0.250 "Sonnet 4.6"

# F10 — Very long branch name (line-width stress test)
d=$(make_git_repo feature/JIRA-12345-implement-oauth2-pkce-flow)
run_fixture "F10  Opus 4.7  88%  very long branch  \$3.750" \
  "$d" "Claude Opus 4.7" 88 "feature/JIRA-12345-implement-oauth2-pkce-flow" 3.750 "Opus 4.7"

# F11 — Non-git directory → branch absent (no assertion)
d=$(make_plain_dir)
run_fixture "F11  Haiku 4.5  10%  non-git dir  \$0.100  (no branch)" \
  "$d" "Claude Haiku 4.5" 10 "" 0.100 "Haiku 4.5"

# F12 — Large cost formatting
d=$(make_git_repo main)
run_fixture "F12  Sonnet 4.6  30%  main  \$99.500  (large cost)" \
  "$d" "Claude Sonnet 4.6" 30 "main" 99.500 "Sonnet 4.6"

# ── Fixtures F13–F15: git status flags ───────────────────────────────────────

# F13 — Staged new file → [+]
d=$(make_git_repo_staged main)
run_fixture "F13  staged new file → [+]" \
  "$d" "Claude Sonnet 4.6" 50 "main" 0.500 "Sonnet 4.6" "[+]"

# F14 — Untracked file → [?]
d=$(make_git_repo_untracked main)
run_fixture "F14  untracked file → [?]" \
  "$d" "Claude Haiku 4.5" 25 "main" 0.010 "Haiku 4.5" "[?]"

# F15 — Staged + unstaged modified + untracked → [+●?]
d=$(make_git_repo_all_states develop)
run_fixture "F15  staged + modified + untracked → [+●?]" \
  "$d" "Claude Opus 4.7" 70 "develop" 2.250 "Opus 4.7" "[+●?]"

# ── Fixtures F16–F17: reasoning-effort suffix on model ───────────────────────

# F16 — effort.level present → "(xhigh)" appended to model name
d=$(make_git_repo main)
raw=$(printf '{"model":{"display_name":"Claude Opus 4.8"},"effort":{"level":"xhigh"},"context_window":{"used_percentage":40},"cost":{"total_cost_usd":0.100},"cwd":"%s"}' "$d" | bash "$SCRIPT" 2>/dev/null)
output=$(printf '%s\n' "$raw" | strip_ansi)
printf '\n\033[1mFixture: F16  effort xhigh → "Opus 4.8 (xhigh)"\033[0m\n'
printf '  %s\n' "$output"
assert_contains "model+effort (Opus 4.8 (xhigh))" "$output" "Opus 4.8 (xhigh)"

# F17 — effort absent → no parenthetical suffix
raw=$(printf '{"model":{"display_name":"Claude Haiku 4.5"},"context_window":{"used_percentage":10},"cost":{"total_cost_usd":0.001},"cwd":"%s"}' "$d" | bash "$SCRIPT" 2>/dev/null)
output=$(printf '%s\n' "$raw" | strip_ansi)
printf '\n\033[1mFixture: F17  no effort → no "(...)" suffix\033[0m\n'
printf '  %s\n' "$output"
assert_contains     "model present (Haiku 4.5)" "$output" "Haiku 4.5"
assert_not_contains "no effort parens"          "$output" "("

# ── Summary ───────────────────────────────────────────────────────────────────

total=$(( PASS + FAIL ))
printf '\n\033[1m'
if (( FAIL == 0 )); then
  printf '═══ Results: %d/%d PASS ✓ All green ═══\033[0m\n' "$PASS" "$total"
else
  printf '═══ Results: %d/%d PASS, %d FAIL ✗ ═══\033[0m\n' "$PASS" "$total" "$FAIL"
fi

(( FAIL == 0 ))
