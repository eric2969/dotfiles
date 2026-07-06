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
  prune_skills "$src_root" "$dst_root"
}

# prune_skills <repo skills dir> <target skills dir>
# Remove installed skills that were once repo-managed (listed in the manifest)
# but no longer exist in the repo. User-modified copies are kept.
prune_skills() {
  local src_root=$1 dst_root=$2
  local manifest="$dst_root/$MANIFEST_NAME"
  local name rec_hash cur_hash tmp
  [[ -f $manifest ]] || return 0
  while read -r name rec_hash; do
    [[ -n $name && ! -d "$src_root/$name" ]] || continue
    if [[ -d "$dst_root/$name" ]]; then
      cur_hash=$(hash_dir "$dst_root/$name")
      if [[ $cur_hash == "$rec_hash" ]]; then
        rm -rf "${dst_root:?}/$name"
        echo "Skill '$name' no longer in repo, removed."
      else
        # Keep the copy and drop its manifest entry: it is user-owned from now on.
        echo "Skill '$name' no longer in repo but modified locally, keeping it." >&2
      fi
    fi
    tmp=$(mktemp)
    awk -v n="$name" '$1 != n' "$manifest" > "$tmp"
    mv "$tmp" "$manifest"
  done < <(cat "$manifest")
}

# install_file <repo file> <target file> [force]
# Same manifest policy as skills, for a single file. The manifest lives in the
# target file's directory.
install_file() {
  local src=$1 dst=$2 force=${3:-0}
  local dst_dir name manifest repo_hash cur_hash rec_hash
  dst_dir=$(dirname "$dst")
  name=$(basename "$dst")
  manifest="$dst_dir/$MANIFEST_NAME"
  mkdir -p "$dst_dir"
  repo_hash=$(sha < "$src" | cut -d' ' -f1)
  if [[ ! -f $dst ]]; then
    cp "$src" "$dst"
    manifest_set "$manifest" "$name" "$repo_hash"
    echo "File '$name' installed."
    return
  fi
  cur_hash=$(sha < "$dst" | cut -d' ' -f1)
  rec_hash=$(manifest_get "$manifest" "$name")
  if [[ $cur_hash == "$repo_hash" ]]; then
    manifest_set "$manifest" "$name" "$repo_hash"
    echo "File '$name' up to date."
  elif [[ $force == 1 || $cur_hash == "$rec_hash" ]]; then
    cp "$src" "$dst"
    manifest_set "$manifest" "$name" "$repo_hash"
    echo "File '$name' updated."
  else
    echo "File '$name' modified locally, keeping it (run with FORCE=1 to overwrite)." >&2
  fi
}

# remove_file <repo file> <target file>
# Remove a repo-managed file; keep it if the user modified it.
remove_file() {
  local src=$1 dst=$2
  local dst_dir name manifest repo_hash cur_hash rec_hash tmp
  dst_dir=$(dirname "$dst")
  name=$(basename "$dst")
  manifest="$dst_dir/$MANIFEST_NAME"
  [[ -f $dst ]] || return 0
  cur_hash=$(sha < "$dst" | cut -d' ' -f1)
  rec_hash=$(manifest_get "$manifest" "$name")
  repo_hash=$(sha < "$src" | cut -d' ' -f1)
  if [[ $cur_hash == "$rec_hash" || $cur_hash == "$repo_hash" ]]; then
    rm -f "$dst"
    echo "File '$name' removed."
  else
    echo "File '$name' modified locally, keeping it." >&2
  fi
  if [[ -f $manifest ]]; then
    tmp=$(mktemp)
    awk -v n="$name" '$1 != n' "$manifest" > "$tmp"
    if [[ -s $tmp ]]; then mv "$tmp" "$manifest"; else rm -f "$tmp" "$manifest"; fi
  fi
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
  install)      install_skills "$2" "$3" "${4:-0}" ;;
  remove)       remove_skills "$2" "$3" ;;
  install-file) install_file "$2" "$3" "${4:-0}" ;;
  remove-file)  remove_file "$2" "$3" ;;
  *)
    echo "usage: $0 install <repo skills dir> <target skills dir> [force]" >&2
    echo "       $0 remove <repo skills dir> <target skills dir>" >&2
    echo "       $0 install-file <repo file> <target file> [force]" >&2
    echo "       $0 remove-file <repo file> <target file>" >&2
    exit 2 ;;
esac
