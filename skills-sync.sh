#!/usr/bin/env bash
# Sync repo-managed Claude skills into ~/.claude/skills.
# A content-hash manifest (.dotfiles-manifest in the target dir) tells apart
# "user modified the installed copy" (kept) from "installed copy is just an
# older repo version" (updated) — same philosophy as rcblock.sh for rc files.
set -euo pipefail

MANIFEST_NAME='.dotfiles-manifest'

sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi
}

# hash_dir <dir> — deterministic hash of file names + contents of a skill dir
hash_dir() {
  (
    cd "$1"
    {
      find . -type f | LC_ALL=C sort
      find . -type f | LC_ALL=C sort | xargs cat
    } | sha | cut -d' ' -f1
  )
}

# manifest_get <manifest> <name> — print recorded hash, empty if none
manifest_get() {
  local file=$1 name=$2
  [[ -f $file ]] || return 0
  awk -v n="$name" '$1 == n { print $2 }' "$file"
}

# manifest_set <manifest> <name> <hash>
manifest_set() {
  local file=$1 name=$2 hash=$3 tmp
  tmp=$(mktemp)
  if [[ -f $file ]]; then
    awk -v n="$name" '$1 != n' "$file" > "$tmp"
  fi
  printf '%s %s\n' "$name" "$hash" >> "$tmp"
  mv "$tmp" "$file"
}

# install_skills <repo skills dir> <target skills dir> [force]
install_skills() {
  local src_root=$1 dst_root=$2 force=${3:-0}
  local manifest="$dst_root/$MANIFEST_NAME"
  local src name dst repo_hash cur_hash rec_hash
  mkdir -p "$dst_root"
  for src in "$src_root"/*/; do
    name=$(basename "$src")
    dst="$dst_root/$name"
    repo_hash=$(hash_dir "$src")
    if [[ ! -d $dst ]]; then
      cp -R "$src" "$dst"
      manifest_set "$manifest" "$name" "$repo_hash"
      echo "Skill '$name' installed."
      continue
    fi
    cur_hash=$(hash_dir "$dst")
    rec_hash=$(manifest_get "$manifest" "$name")
    if [[ $cur_hash == "$repo_hash" ]]; then
      manifest_set "$manifest" "$name" "$repo_hash"
      echo "Skill '$name' up to date."
    elif [[ $force == 1 || $cur_hash == "$rec_hash" ]]; then
      rm -rf "$dst"
      cp -R "$src" "$dst"
      manifest_set "$manifest" "$name" "$repo_hash"
      echo "Skill '$name' updated."
    else
      echo "Skill '$name' modified locally, keeping it (run with FORCE=1 to overwrite)." >&2
    fi
  done
}

# remove_skills <repo skills dir> <target skills dir>
# Remove repo-managed skills; keep copies the user modified.
remove_skills() {
  local src_root=$1 dst_root=$2
  local manifest="$dst_root/$MANIFEST_NAME"
  local src name dst cur_hash rec_hash repo_hash
  for src in "$src_root"/*/; do
    name=$(basename "$src")
    dst="$dst_root/$name"
    [[ -d $dst ]] || continue
    cur_hash=$(hash_dir "$dst")
    rec_hash=$(manifest_get "$manifest" "$name")
    repo_hash=$(hash_dir "$src")
    if [[ $cur_hash == "$rec_hash" || $cur_hash == "$repo_hash" ]]; then
      rm -rf "$dst"
      echo "Skill '$name' removed."
    else
      echo "Skill '$name' modified locally, keeping it." >&2
    fi
  done
  rm -f "$manifest"
  rmdir "$dst_root" 2>/dev/null || true
}

case ${1:-} in
  install) install_skills "$2" "$3" "${4:-0}" ;;
  remove)  remove_skills "$2" "$3" ;;
  *) echo "usage: $0 install <repo skills dir> <target skills dir> [force] | remove <repo skills dir> <target skills dir>" >&2; exit 2 ;;
esac
