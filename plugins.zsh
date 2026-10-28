# ~/.config/zsh/plugins.zsh
# =========================================================
# Plugins — pinned to reviewed commits
# =========================================================
#
# Each plugin is fetched at an exact commit SHA (tags are mutable), so a
# compromised upstream cannot push code into this shell. To upgrade:
#   zplugin-outdated              # newest upstream tag per plugin
#   zplugin-diff <name> <ref>     # review the change before trusting it
# then edit the SHA below and start a new shell.

ZPLUGINDIR="${ZDOTDIR:-$HOME/.config/zsh}/plugins"

# Load order matters: zsh-vi-mode first, history-substring-search after syntax highlighting.
# repo                                         commit SHA                                  tag
typeset -ga ZPLUGINS=(
  jeffreytse/zsh-vi-mode                     80f78d9a3cc06843c776f60e4535b20bb857b1d4   # v0.12.0
  zsh-users/zsh-autosuggestions              e52ee8ca55bcc56a17c828767a3f98f22a68d4eb   # v0.7.1
  zdharma-continuum/fast-syntax-highlighting 5ecd353c81214f82bdeca5483fab6ccc5a2d5494   # v1.56
  zsh-users/zsh-history-substring-search     400e58a87f72ecec14f783fbd29bc6be4ff1641c   # v1.1.0
)

# zsh-autosuggestions: suggest from history only (the `completion` strategy runs
# completion functions in the background), and skip suggestions for long buffers
# such as large pastes (> 200 chars). Must be set before the plugin loads.
ZSH_AUTOSUGGEST_STRATEGY=(history)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=200

# Fetch exactly <sha> into <dir> (shallow).
_zplugin_fetch() {
  local repo=$1 sha=$2 dir=$3
  print -u2 "zplugin: installing ${repo}@${sha[1,12]}"
  rm -rf "$dir" && mkdir -p "$dir" || return 1
  git -C "$dir" init -q \
    && git -C "$dir" remote add origin "https://github.com/${repo}" \
    && git -C "$dir" fetch -q --depth=1 origin "$sha" \
    && git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD \
    || { print -u2 "zplugin: failed to install ${repo}"; rm -rf "$dir"; return 1; }
}

_zplugin_load() {
  local repo=$1 sha=$2 name=${1:t}
  local dir="${ZPLUGINDIR}/${name}" head=""
  # Read HEAD without forking git; a detached checkout stores the SHA there.
  [[ -r $dir/.git/HEAD ]] && head=$(<"$dir/.git/HEAD")
  if [[ $head != "$sha" ]]; then
    _zplugin_fetch "$repo" "$sha" "$dir" || return 1
  fi
  source "${dir}/${name}.plugin.zsh"
}

zplugin-outdated() {
  local repo sha latest i
  for (( i = 1; i < ${#ZPLUGINS}; i += 2 )); do
    repo=${ZPLUGINS[i]} sha=${ZPLUGINS[i+1]}
    latest=$(git ls-remote --tags --refs "https://github.com/${repo}" \
      | awk -F/ '{print $NF}' | sort -V | tail -1)
    print "${repo}: pinned ${sha[1,12]}, latest tag ${latest:-?}"
  done
}

# Show what changed between the pinned commit and <ref> (tag, branch or SHA).
zplugin-diff() {
  local name=$1 ref=$2 dir="${ZPLUGINDIR}/${1}"
  [[ -n $name && -n $ref && -d $dir/.git ]] || { print -u2 "usage: zplugin-diff <plugin-dir-name> <ref>"; return 1; }
  # Install fetches are shallow; deepen once so `log` shows real history.
  git -C "$dir" fetch -q --unshallow origin "$ref" 2>/dev/null \
    || git -C "$dir" fetch -q origin "$ref" || return 1
  git -C "$dir" log --oneline HEAD..FETCH_HEAD
  git -C "$dir" diff --stat HEAD FETCH_HEAD
  print "\nFull diff: git -C ${dir} diff HEAD FETCH_HEAD   (SHA: $(git -C "$dir" rev-parse FETCH_HEAD))"
}

() {
  local i
  for (( i = 1; i < ${#ZPLUGINS}; i += 2 )); do
    _zplugin_load "${ZPLUGINS[i]}" "${ZPLUGINS[i+1]}"
  done
}
