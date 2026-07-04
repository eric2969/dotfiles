#!/usr/bin/env bash
# Sandboxed test suite for rcblock.sh, skills-sync.sh, and the make targets.
# Everything runs against a throwaway HOME; the real home is never touched.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

FAILURES=0
pass() { printf '  ok  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }
assert() { # assert <description> <command...>
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

# ---------- rcblock.sh ----------
echo "rcblock.sh"
RC="$SANDBOX/rc"
SRC="$SANDBOX/src"
printf 'export FOO=1\n' > "$SRC"

"$REPO/rcblock.sh" install "$SRC" "$RC"
assert "creates rc with managed block" grep -q 'export FOO=1' "$RC"
assert "block has begin marker" grep -q '>>> dotfiles managed block' "$RC"

printf '# user line\n' > "$RC"
"$REPO/rcblock.sh" install "$SRC" "$RC"
assert "appends block to user rc" grep -q '# user line' "$RC"
assert "appended block content present" grep -q 'export FOO=1' "$RC"

printf 'export FOO=2\n' > "$SRC"
"$REPO/rcblock.sh" install "$SRC" "$RC"
assert "re-install refreshes block content" grep -q 'export FOO=2' "$RC"
assert "re-install does not duplicate block" \
  test "$(grep -c '>>> dotfiles managed block' "$RC")" = 1
assert "re-install keeps user line" grep -q '# user line' "$RC"

"$REPO/rcblock.sh" remove "$RC"
assert "remove keeps user line" grep -q '# user line' "$RC"
assert "remove deletes block" bash -c "! grep -q 'export FOO=2' '$RC'"

"$REPO/rcblock.sh" install "$SRC" "$RC.only"
"$REPO/rcblock.sh" remove "$RC.only"
assert "remove deletes block-only file" test ! -f "$RC.only"

# ---------- skills-sync.sh ----------
echo "skills-sync.sh"
SKILLS_SRC="$SANDBOX/repo-skills"
SKILLS_DST="$SANDBOX/user-skills"
MANIFEST="$SKILLS_DST/.dotfiles-manifest"
mkdir -p "$SKILLS_SRC/alpha" "$SKILLS_SRC/beta"
printf 'v1\n' > "$SKILLS_SRC/alpha/SKILL.md"
printf 'v1\n' > "$SKILLS_SRC/beta/SKILL.md"

"$REPO/skills-sync.sh" install "$SKILLS_SRC" "$SKILLS_DST"
assert "fresh install copies skills" test -f "$SKILLS_DST/alpha/SKILL.md"
assert "fresh install writes manifest" grep -q '^alpha ' "$MANIFEST"

printf 'v2\n' > "$SKILLS_SRC/alpha/SKILL.md"
"$REPO/skills-sync.sh" install "$SKILLS_SRC" "$SKILLS_DST"
assert "repo update propagates to unmodified copy" grep -q 'v2' "$SKILLS_DST/alpha/SKILL.md"

printf 'user edit\n' > "$SKILLS_DST/beta/SKILL.md"
printf 'v2\n' > "$SKILLS_SRC/beta/SKILL.md"
"$REPO/skills-sync.sh" install "$SKILLS_SRC" "$SKILLS_DST"
assert "user-modified copy is kept" grep -q 'user edit' "$SKILLS_DST/beta/SKILL.md"

"$REPO/skills-sync.sh" install "$SKILLS_SRC" "$SKILLS_DST" 1
assert "force overwrites user-modified copy" grep -q 'v2' "$SKILLS_DST/beta/SKILL.md"

printf 'user edit again\n' > "$SKILLS_DST/beta/SKILL.md"
mkdir -p "$SKILLS_DST/user-own"
printf 'mine\n' > "$SKILLS_DST/user-own/SKILL.md"
"$REPO/skills-sync.sh" remove "$SKILLS_SRC" "$SKILLS_DST"
assert "remove deletes unmodified repo skill" test ! -d "$SKILLS_DST/alpha"
assert "remove keeps user-modified repo skill" grep -q 'user edit again' "$SKILLS_DST/beta/SKILL.md"
assert "remove keeps user-authored skill" test -f "$SKILLS_DST/user-own/SKILL.md"
assert "remove deletes manifest" test ! -f "$MANIFEST"

# ---------- make update / uninstall end-to-end ----------
echo "make update / uninstall"
FAKE_HOME="$SANDBOX/home"
mkdir -p "$FAKE_HOME/.claude/skills/my-own-skill"
printf 'mine\n' > "$FAKE_HOME/.claude/skills/my-own-skill/SKILL.md"

HOME="$FAKE_HOME" make -C "$REPO" update >/dev/null
assert "update installs repo skills" test -f "$FAKE_HOME/.claude/skills/skill-authoring/SKILL.md"
assert "update copies settings" test -f "$FAKE_HOME/.claude/settings.json"
assert "update writes rc block" grep -q '>>> dotfiles managed block' "$FAKE_HOME/.zshrc"

OUT=$(HOME="$FAKE_HOME" make -C "$REPO" update 2>&1)
assert "second update reports up to date" grep -q "up to date" <<<"$OUT"

HOME="$FAKE_HOME" make -C "$REPO" uninstall >/dev/null 2>&1
assert "uninstall removes repo skills" test ! -d "$FAKE_HOME/.claude/skills/skill-authoring"
assert "uninstall keeps user-authored skill" test -f "$FAKE_HOME/.claude/skills/my-own-skill/SKILL.md"
assert "uninstall removes rc block" bash -c "! grep -q '>>> dotfiles managed block' '$FAKE_HOME/.zshrc' 2>/dev/null"

# ---------- result ----------
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed." >&2
  exit 1
fi
echo "All tests passed."
