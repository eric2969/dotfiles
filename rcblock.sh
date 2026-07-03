#!/usr/bin/env bash
# Manage the dotfiles-managed block inside shell rc files (~/.zshrc, ~/.bash_profile).
# Repo content lives between BEGIN/END markers; everything outside is user-owned
# and is never touched by install/update/uninstall.
set -euo pipefail

BEGIN='# >>> dotfiles managed block — do not edit, "make update" rewrites it >>>'
END='# <<< dotfiles managed block <<<'

# install_block <repo config> <target rc>
# Insert or refresh the managed block in the target rc file.
install_block() {
  local src=$1 dst=$2 block out
  block=$(mktemp)
  {
    printf '%s\n' "$BEGIN"
    cat "$src"
    printf '%s\n' "$END"
  } > "$block"

  # No rc yet, or it is a full copy left by an older "make update":
  # the whole file becomes the managed block.
  if [[ ! -f $dst ]] || cmp -s "$src" "$dst"; then
    mv "$block" "$dst"
    return
  fi

  out=$(mktemp)
  if grep -qF "$BEGIN" "$dst"; then
    # Replace the existing block in place, keeping its position.
    awk -v begin="$BEGIN" -v end="$END" -v blockfile="$block" '
      $0 == begin { while ((getline line < blockfile) > 0) print line; skip = 1; next }
      $0 == end   { skip = 0; next }
      !skip
    ' "$dst" > "$out"
  else
    # First run against a user-authored rc: append the block at the end.
    cat "$dst" > "$out"
    printf '\n' >> "$out"
    cat "$block" >> "$out"
  fi
  mv "$out" "$dst"
  rm -f "$block"
}

# remove_block <target rc>
# Delete the managed block; drop the file only if nothing else remains.
remove_block() {
  local dst=$1 out
  [[ -f $dst ]] || return 0
  grep -qF "$BEGIN" "$dst" || return 0
  out=$(mktemp)
  awk -v begin="$BEGIN" -v end="$END" '
    $0 == begin { skip = 1; next }
    $0 == end   { skip = 0; next }
    !skip
  ' "$dst" > "$out"
  if grep -q '[^[:space:]]' "$out"; then
    mv "$out" "$dst"
  else
    rm -f "$out" "$dst"
  fi
}

case ${1:-} in
  install) install_block "$2" "$3" ;;
  remove)  remove_block "$2" ;;
  *) echo "usage: $0 install <repo config> <target rc> | remove <target rc>" >&2; exit 2 ;;
esac
