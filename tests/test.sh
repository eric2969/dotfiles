#!/usr/bin/env bash
# Sandboxed test suite for rcblock.sh, skill syncing/linking, and make targets.
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

# ---------- skills-sync.sh pruning of removed repo skills ----------
echo "skills-sync.sh pruning"
mkdir -p "$SKILLS_SRC/gamma" "$SKILLS_SRC/delta"
printf 'v1\n' > "$SKILLS_SRC/gamma/SKILL.md"
printf 'v1\n' > "$SKILLS_SRC/delta/SKILL.md"
"$REPO/skills-sync.sh" install "$SKILLS_SRC" "$SKILLS_DST" 1
rm -rf "$SKILLS_SRC/gamma" "$SKILLS_SRC/delta"
printf 'local tweak\n' > "$SKILLS_DST/delta/SKILL.md"
"$REPO/skills-sync.sh" install "$SKILLS_SRC" "$SKILLS_DST"
assert "prune removes skill dropped from repo" test ! -d "$SKILLS_DST/gamma"
assert "prune keeps modified skill dropped from repo" grep -q 'local tweak' "$SKILLS_DST/delta/SKILL.md"
assert "prune drops manifest entry of kept skill" bash -c "! grep -q '^delta ' '$MANIFEST'"

# ---------- skills-sync.sh single-file mode ----------
echo "skills-sync.sh install-file / remove-file"
FILE_SRC="$SANDBOX/repo-file.md"
FILE_DST_DIR="$SANDBOX/file-target"
FILE_DST="$FILE_DST_DIR/managed.md"
FILE_MANIFEST="$FILE_DST_DIR/.dotfiles-manifest"
printf 'v1\n' > "$FILE_SRC"

"$REPO/skills-sync.sh" install-file "$FILE_SRC" "$FILE_DST"
assert "install-file copies file" grep -q 'v1' "$FILE_DST"
assert "install-file writes manifest" grep -q '^managed.md ' "$FILE_MANIFEST"

printf 'v2\n' > "$FILE_SRC"
"$REPO/skills-sync.sh" install-file "$FILE_SRC" "$FILE_DST"
assert "install-file updates unmodified copy" grep -q 'v2' "$FILE_DST"

printf 'user edit\n' > "$FILE_DST"
printf 'v3\n' > "$FILE_SRC"
"$REPO/skills-sync.sh" install-file "$FILE_SRC" "$FILE_DST"
assert "install-file keeps user-modified copy" grep -q 'user edit' "$FILE_DST"

"$REPO/skills-sync.sh" install-file "$FILE_SRC" "$FILE_DST" 1
assert "install-file force overwrites modified copy" grep -q 'v3' "$FILE_DST"

printf 'user edit again\n' > "$FILE_DST"
"$REPO/skills-sync.sh" remove-file "$FILE_SRC" "$FILE_DST"
assert "remove-file keeps user-modified copy" grep -q 'user edit again' "$FILE_DST"

printf 'v3\n' > "$FILE_DST"
"$REPO/skills-sync.sh" install-file "$FILE_SRC" "$FILE_DST"
"$REPO/skills-sync.sh" remove-file "$FILE_SRC" "$FILE_DST"
assert "remove-file deletes unmodified copy" test ! -f "$FILE_DST"

# ---------- herdr agent skill ----------
# The skill is generated from the installed binary, so a stub herdr stands in
# for the real one and keeps the test independent of what is on this machine.
echo "setup.sh skill"
HERDR_HOME="$SANDBOX/herdr-home"
STUB_BIN="$SANDBOX/stub-bin"
mkdir -p "$STUB_BIN" "$HERDR_HOME"
cat > "$STUB_BIN/herdr" <<'STUB'
#!/usr/bin/env bash
[ "$1" = "--skill" ] || exit 1
echo "# herdr skill v1"
STUB
chmod +x "$STUB_BIN/herdr"

# stdin is detached so a machine with a real, not-yet-agreed fm cannot prompt.
HOME="$HERDR_HOME" PATH="$STUB_BIN:$PATH" "$REPO/setup.sh" skill </dev/null >/dev/null
assert "skill writes the herdr skill from the binary"   grep -q 'herdr skill v1' "$HERDR_HOME/.agents/skills/herdr/SKILL.md"

cat > "$STUB_BIN/herdr" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
BROKEN_HOME="$SANDBOX/herdr-broken-home"
mkdir -p "$BROKEN_HOME"
HOME="$BROKEN_HOME" PATH="$STUB_BIN:$PATH" "$REPO/setup.sh" skill </dev/null >/dev/null 2>&1
assert "failing herdr --skill leaves no partial skill"   test ! -e "$BROKEN_HOME/.agents/skills/herdr/SKILL.md"

# ---------- apple-fm optional skill ----------
# Stub uname and fm decide what the machine looks like, so every branch of the
# gate runs the same way on macOS, Linux and CI.
echo "setup.sh skill (apple-fm gate)"
AFM_STUB="$SANDBOX/afm-stub"
mkdir -p "$AFM_STUB"
cat > "$AFM_STUB/uname" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -s) echo "${STUB_UNAME_S:-Darwin}" ;;
  -m) echo "${STUB_UNAME_M:-arm64}" ;;
  *)  echo "${STUB_UNAME_S:-Darwin}" ;;
esac
STUB
cat > "$AFM_STUB/fm" <<'STUB'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "license --status")
    if [ "${STUB_FM_LICENSE:-agreed}" = agreed ]; then
      echo "Agreed to license FM1 version 1.1 on 2026-01-01."
    else
      echo "Not yet agreed to license FM1."
      exit 1
    fi ;;
  "license "*) echo "fm license must not be run without a terminal" >&2; exit 3 ;;
  "models "*)
    if [ "${STUB_FM_MODEL:-ready}" = ready ]; then mark="✓"; else mark="✗"; fi
    printf 'Apple Foundation Models\n  %s system (Stub)\n  ✗ pcc (not available)\n' "$mark"
    exit 1 ;;
  *) exit 2 ;;
esac
STUB
chmod +x "$AFM_STUB/uname" "$AFM_STUB/fm"

afm_setup() { # afm_setup <home> [VAR=value...]
  local home=$1; shift
  mkdir -p "$home"
  env HOME="$home" PATH="$AFM_STUB:$PATH" "$@" "$REPO/setup.sh" skill </dev/null >/dev/null 2>&1
}

AFM_HOME="$SANDBOX/afm-home"
afm_setup "$AFM_HOME"
assert "supported Mac installs apple-fm" test -f "$AFM_HOME/.agents/skills/apple-fm/SKILL.md"
assert "installed afm CLI is executable" test -x "$AFM_HOME/.agents/skills/apple-fm/scripts/afm"
assert "installed afm symlink still resolves" test -f "$AFM_HOME/.agents/skills/apple-fm/scripts/afm"
assert "optional skills use their own manifest" grep -q '^apple-fm ' "$AFM_HOME/.agents/skills/.dotfiles-manifest-optional"

"$REPO/skills-sync.sh" install "$REPO/.agents/skills" "$AFM_HOME/.agents/skills" >/dev/null
assert "regular skill sync does not prune apple-fm" test -f "$AFM_HOME/.agents/skills/apple-fm/SKILL.md"
afm_setup "$AFM_HOME"
assert "optional skill sync does not prune regular skills" test -f "$AFM_HOME/.agents/skills/verify/SKILL.md"

afm_setup "$AFM_HOME" STUB_FM_MODEL=unavailable
assert "model no longer ready removes apple-fm" test ! -d "$AFM_HOME/.agents/skills/apple-fm"
assert "removing apple-fm keeps regular skills" test -f "$AFM_HOME/.agents/skills/verify/SKILL.md"

afm_setup "$SANDBOX/afm-linux" STUB_UNAME_S=Linux STUB_UNAME_M=x86_64
assert "Linux skips apple-fm" test ! -d "$SANDBOX/afm-linux/.agents/skills/apple-fm"

afm_setup "$SANDBOX/afm-intel" STUB_UNAME_M=x86_64
assert "Intel Mac skips apple-fm" test ! -d "$SANDBOX/afm-intel/.agents/skills/apple-fm"

afm_setup "$SANDBOX/afm-nolicense" STUB_FM_LICENSE=pending
assert "unagreed license without a terminal skips apple-fm" test ! -d "$SANDBOX/afm-nolicense/.agents/skills/apple-fm"

mkdir -p "$SANDBOX/afm-edited"
afm_setup "$SANDBOX/afm-edited"
printf 'local tweak\n' >> "$SANDBOX/afm-edited/.agents/skills/apple-fm/SKILL.md"
afm_setup "$SANDBOX/afm-edited"
assert "locally modified apple-fm is kept" grep -q 'local tweak' "$SANDBOX/afm-edited/.agents/skills/apple-fm/SKILL.md"
afm_setup "$SANDBOX/afm-edited" FORCE=1
assert "FORCE=1 overwrites modified apple-fm" bash -c "! grep -q 'local tweak' '$SANDBOX/afm-edited/.agents/skills/apple-fm/SKILL.md'"

echo "apple-fm CLI (python unittest)"
if command -v python3 >/dev/null 2>&1; then
  assert "afm CLI test suite" python3 -m unittest discover -s "$REPO/tests/apple-fm"
  assert "tests leave no bytecode in the skill dir" bash -c "! find '$REPO/.agents/skills-optional' -name __pycache__ | grep -q ."
else
  echo "  (skipped: python3 not found)"
fi

# ---------- make update / uninstall end-to-end ----------
# make is not part of a stock Windows install; the setup.ps1 suite below covers
# the same install/uninstall policies there.
if ! command -v make >/dev/null 2>&1; then
  echo "make update / uninstall (skipped: make not found)"
else
echo "make update / uninstall"
FAKE_HOME="$SANDBOX/home"
mkdir -p "$FAKE_HOME/.claude/skills/my-own-skill"
printf 'mine\n' > "$FAKE_HOME/.claude/skills/my-own-skill/SKILL.md"
# Simulate an install made before shared skills moved from ~/.claude to ~/.agents.
"$REPO/skills-sync.sh" install "$REPO/.agents/skills" "$FAKE_HOME/.claude/skills" >/dev/null

# The apple-fm stubs present a supported Mac, so the optional skill is covered
# here regardless of the machine running the suite.
export PATH="$AFM_STUB:$PATH"
HOME="$FAKE_HOME" make -C "$REPO" update </dev/null >/dev/null
assert "update installs the optional apple-fm skill" test -f "$FAKE_HOME/.agents/skills/apple-fm/SKILL.md"
assert "update links apple-fm into Claude" test -L "$FAKE_HOME/.claude/skills/apple-fm"
assert "update links apple-fm into Codex" test -L "$FAKE_HOME/.codex/skills/apple-fm"
assert "update installs shared repo skills" test -f "$FAKE_HOME/.agents/skills/skill-authoring/SKILL.md"
assert "update links skills into Claude" test -L "$FAKE_HOME/.claude/skills/skill-authoring"
assert "update links skills into Codex" test -L "$FAKE_HOME/.codex/skills/skill-authoring"
assert "update migrates legacy Claude skill copies" test ! -f "$FAKE_HOME/.claude/skills/.dotfiles-manifest"
assert "update copies settings" test -f "$FAKE_HOME/.claude/settings.json"
assert "update copies Codex config" cmp -s "$REPO/.codex/config.toml" "$FAKE_HOME/.codex/config.toml"
assert "update installs CLAUDE.md with manifest" grep -q '^CLAUDE.md ' "$FAKE_HOME/.claude/.dotfiles-manifest"
assert "update writes rc block" grep -q '>>> dotfiles managed block' "$FAKE_HOME/.zshrc"

OUT=$(HOME="$FAKE_HOME" make -C "$REPO" update 2>&1)
assert "second update reports up to date" grep -q "up to date" <<<"$OUT"

printf '# my local rules\n' >> "$FAKE_HOME/.claude/CLAUDE.md"
HOME="$FAKE_HOME" make -C "$REPO" update >/dev/null 2>&1
assert "update keeps user-modified CLAUDE.md" grep -q '# my local rules' "$FAKE_HOME/.claude/CLAUDE.md"

HOME="$FAKE_HOME" make -C "$REPO" update FORCE=1 >/dev/null 2>&1
assert "FORCE=1 overwrites modified CLAUDE.md" bash -c "! grep -q '# my local rules' '$FAKE_HOME/.claude/CLAUDE.md'"

# Generated skills are not in the repo manifest, so uninstall removes them by name.
mkdir -p "$FAKE_HOME/.agents/skills/herdr"
printf '# herdr skill
' > "$FAKE_HOME/.agents/skills/herdr/SKILL.md"
HOME="$FAKE_HOME" make -C "$REPO" uninstall >/dev/null 2>&1
assert "uninstall removes the generated herdr skill" test ! -d "$FAKE_HOME/.agents/skills/herdr"
assert "uninstall removes the optional apple-fm skill" test ! -d "$FAKE_HOME/.agents/skills/apple-fm"
assert "uninstall removes the apple-fm Claude link" test ! -L "$FAKE_HOME/.claude/skills/apple-fm"
assert "uninstall removes the optional manifest" test ! -f "$FAKE_HOME/.agents/skills/.dotfiles-manifest-optional"
assert "uninstall removes shared repo skills" test ! -d "$FAKE_HOME/.agents/skills/skill-authoring"
assert "uninstall removes Codex skill links" test ! -L "$FAKE_HOME/.codex/skills/skill-authoring"
assert "uninstall removes Codex config" test ! -f "$FAKE_HOME/.codex/config.toml"
assert "uninstall removes CLAUDE.md" test ! -f "$FAKE_HOME/.claude/CLAUDE.md"
assert "uninstall keeps user-authored skill" test -f "$FAKE_HOME/.claude/skills/my-own-skill/SKILL.md"
assert "uninstall removes rc block" bash -c "! grep -q '>>> dotfiles managed block' '$FAKE_HOME/.zshrc' 2>/dev/null"
fi

# ---------- setup.ps1 (Windows only) ----------
if command -v pwsh >/dev/null 2>&1; then
  echo "setup.ps1"
  if pwsh -NoProfile -File "$REPO/tests/test.ps1"; then
    pass "setup.ps1 suite"
  else
    fail "setup.ps1 suite"
  fi
else
  echo "setup.ps1 (skipped: pwsh not found)"
fi

# ---------- result ----------
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed." >&2
  exit 1
fi
echo "All tests passed."
