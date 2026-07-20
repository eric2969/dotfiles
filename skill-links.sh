#!/usr/bin/env bash
# Link centrally managed skills into an agent-specific skills directory.
set -euo pipefail

MANIFEST_NAME='.dotfiles-links'

install_links() {
  local src_root=$1 dst_root=$2 force=${3:-0}
  local manifest="$dst_root/$MANIFEST_NAME" src name dst target
  mkdir -p "$dst_root"
  touch "$manifest"

  for src in "$src_root"/*/; do
    name=$(basename "$src")
    src=${src%/}
    dst="$dst_root/$name"
    if [[ -L $dst ]]; then
      target=$(readlink "$dst")
      if [[ $target == "$src" ]]; then
        echo "Skill link '$name' up to date."
      elif [[ $force == 1 ]]; then
        rm "$dst"
        ln -s "$src" "$dst"
        echo "Skill link '$name' updated."
      else
        echo "Skill '$name' points elsewhere, keeping it (run with FORCE=1 to relink)." >&2
        continue
      fi
    elif [[ -e $dst ]]; then
      echo "Skill '$name' already exists in $dst_root, keeping it." >&2
      continue
    else
      ln -s "$src" "$dst"
      echo "Skill link '$name' installed."
    fi
    if ! grep -Fxq "$name" "$manifest"; then printf '%s\n' "$name" >> "$manifest"; fi
  done

  while IFS= read -r name; do
    [[ -n $name && ! -e "$src_root/$name" ]] || continue
    dst="$dst_root/$name"
    [[ -L $dst ]] && rm "$dst"
    sed -i.bak "/^${name}$/d" "$manifest"
    rm -f "$manifest.bak"
    echo "Skill link '$name' no longer managed, removed."
  done < <(cat "$manifest")
  [[ -s $manifest ]] || rm -f "$manifest"
}

remove_links() {
  local src_root=$1 dst_root=$2 manifest="$2/$MANIFEST_NAME"
  local name dst target
  [[ -f $manifest ]] || return 0
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    dst="$dst_root/$name"
    if [[ -L $dst ]]; then
      target=$(readlink "$dst")
      if [[ $target == "$src_root/$name" ]]; then
        rm "$dst"
        echo "Skill link '$name' removed."
      else
        echo "Skill link '$name' changed locally, keeping it." >&2
      fi
    fi
  done < "$manifest"
  rm -f "$manifest"
  rmdir "$dst_root" 2>/dev/null || true
}

case ${1:-} in
  install) install_links "$2" "$3" "${4:-0}" ;;
  remove)  remove_links "$2" "$3" ;;
  *)
    echo "usage: $0 install <shared skills dir> <agent skills dir> [force]" >&2
    echo "       $0 remove <shared skills dir> <agent skills dir>" >&2
    exit 2 ;;
esac
