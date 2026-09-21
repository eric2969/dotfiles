#!/usr/bin/env bash
set -euo pipefail

NVM_VERSION=v0.40.3

YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { printf "${YELLOW}%s${NC}\n" "$*"; }
warn()  { printf "${RED}%s${NC}\n" "$*" >&2; }
ok()    { printf "${GREEN}%s${NC}\n" "$*"; }

install_ssh_key() {
    if [ ! -t 0 ]; then
        echo "Non-interactive session, skipping SSH key setup."
        return 0
    fi
    local pub_key
    read -rp "Input your SSH public key (n/N to skip): " pub_key
    if [[ "$pub_key" == [nN] || -z "$pub_key" ]]; then
        echo "Skipping SSH key setup."
        return 0
    fi
    if [[ "$pub_key" != ssh-* ]]; then
        warn "Invalid public key format (expected ssh-rsa / ssh-ed25519 ...), skipping."
        return 0
    fi
    local auth_keys="$HOME/.ssh/authorized_keys"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$auth_keys"
    chmod 600 "$auth_keys"
    if grep -Fxq "$pub_key" "$auth_keys"; then
        echo "Public key already present."
    else
        echo "$pub_key" >> "$auth_keys"
        ok "Public key added to $auth_keys"
    fi
}

install_deps() {
    # Fast path: skip the package manager entirely when everything is present.
    local tool missing=false
    for tool in curl git zsh vim tmux btop; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing=true
            break
        fi
    done
    if [ "$missing" = false ]; then
        echo "Dependencies already installed."
        return 0
    fi
    info "Installing dependencies..."
    if command -v brew >/dev/null 2>&1; then      # macOS
        brew update
        brew install curl git zsh vim tmux btop gcc
    elif command -v apt-get >/dev/null 2>&1; then # Debian / Ubuntu
        sudo apt-get update
        sudo apt-get install -y curl git zsh vim tmux btop fontconfig unzip build-essential
    elif command -v dnf >/dev/null 2>&1; then     # Fedora
        sudo dnf install -y curl git zsh vim tmux btop util-linux-user fontconfig unzip gcc-c++
    elif command -v pacman >/dev/null 2>&1; then  # Arch
        sudo pacman -S --needed --noconfirm curl git zsh vim tmux btop fontconfig unzip base-devel
    else
        warn "Unknown OS: no brew/apt/dnf/pacman found."
        exit 1
    fi
}

install_font() {
    info "Installing Sauce Code Pro Nerd Font..."
    if command -v brew >/dev/null 2>&1; then
        brew install --cask font-sauce-code-pro-nerd-font
        return 0
    fi
    local font_dir="$HOME/.local/share/fonts"
    if compgen -G "$font_dir/SauceCodePro*.ttf" > /dev/null; then
        echo "Font already installed."
        return 0
    fi
    local tmp_dir
    tmp_dir=$(mktemp -d)
    curl -fsSL -o "$tmp_dir/SourceCodePro.zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SourceCodePro.zip
    mkdir -p "$font_dir"
    unzip -o "$tmp_dir/SourceCodePro.zip" '*.ttf' -d "$font_dir"
    rm -rf "$tmp_dir"
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir"
    fi
}

install_zinit() {
    local zinit_home="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    if [ -d "$zinit_home" ]; then
        echo "zinit already installed."
        return 0
    fi
    info "Installing zinit..."
    mkdir -p "$(dirname "$zinit_home")"
    git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$zinit_home"
}

install_vim_plug() {
    local plug="$HOME/.vim/autoload/plug.vim"
    if [ -f "$plug" ]; then
        echo "vim-plug already installed."
        return 0
    fi
    info "Installing vim-plug..."
    curl -fsSLo "$plug" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}

install_claude() {
    if command -v claude >/dev/null 2>&1; then
        echo "Claude Code already installed."
        return 0
    fi
    info "Installing Claude Code..."
    # Claude's installer uses bash-only syntax; pipe to bash, not sh (dash on Debian).
    curl -fsSL https://claude.ai/install.sh | bash
}

install_uv() {
    if command -v uv >/dev/null 2>&1; then
        echo "uv already installed."
        return 0
    fi
    info "Installing uv..."
    # PATH is handled by .bash_profile; keep the installer from editing rc files.
    curl -fsSL https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
}

install_nvm() {
    if [ -d "${NVM_DIR:-$HOME/.nvm}" ]; then
        echo "nvm already installed."
        return 0
    fi
    info "Installing nvm..."
    # nvm init lives in .bash_profile; PROFILE=/dev/null stops the installer
    # from appending its own lines to rc files.
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | PROFILE=/dev/null bash
}

install_codex() {
    if command -v codex >/dev/null 2>&1; then
        echo "Codex CLI already installed."
        return 0
    fi
    if ! command -v npm >/dev/null 2>&1; then
        local nvm_sh="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
        if [ ! -s "$nvm_sh" ]; then
            warn "npm not found, cannot install Codex CLI."
            return 1
        fi
        info "Installing Node.js LTS for Codex CLI..."
        # shellcheck source=/dev/null
        source "$nvm_sh"
        nvm install --lts
    fi
    info "Installing Codex CLI..."
    npm install -g @openai/codex
}

install_herdr() {
    if command -v herdr >/dev/null 2>&1; then
        echo "herdr already installed."
        return 0
    fi
    info "Installing herdr..."
    if command -v brew >/dev/null 2>&1; then
        brew install herdr
    else
        curl -fsSL https://herdr.dev/install.sh | sh
    fi
}

# herdr's installer drops the binary in ~/.local/bin, which only lands on PATH
# once .bash_profile is re-sourced; look there too so the skill can be written
# in the same run that installed herdr.
herdr_bin() {
    if command -v herdr >/dev/null 2>&1; then
        command -v herdr
        return 0
    fi
    if [ -x "$HOME/.local/bin/herdr" ]; then
        echo "$HOME/.local/bin/herdr"
        return 0
    fi
    return 1
}

# herdr ships an agent skill matched to the installed binary, so it is generated
# instead of vendored. Writing it into the shared skills dir lets skill-links.sh
# expose it to Claude and Codex like every other skill.
install_herdr_skill() {
    local bin dir tmp
    if ! bin=$(herdr_bin); then
        echo "herdr not installed, skipping its agent skill."
        return 0
    fi
    dir="$HOME/.agents/skills/herdr"
    mkdir -p "$dir"
    tmp="$dir/SKILL.md.tmp"
    # stdin is detached so herdr cannot swallow input typed ahead for the
    # interactive 'fm license' prompt that may follow in the same run.
    if "$bin" --skill < /dev/null > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        mv "$tmp" "$dir/SKILL.md"
        ok "Skill 'herdr' synced from the installed binary."
    else
        rm -f "$tmp"
        warn "herdr --skill failed, skipping its agent skill."
        rmdir "$dir" 2>/dev/null || true
    fi
}

# Skills under .agents/skills-optional only make sense on some machines, so they
# are installed by the checks below instead of by the unconditional skill sync.
# They keep their own manifest: sharing one would make each sync prune the
# other's skills as "no longer in repo".
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OPTIONAL_SKILLS_SRC="$REPO_DIR/.agents/skills-optional"
OPTIONAL_SKILLS_MANIFEST='.dotfiles-manifest-optional'

sync_optional_skills() { # sync_optional_skills <install|remove>
    local action=$1
    if [ "$action" = install ]; then
        SKILLS_MANIFEST_NAME="$OPTIONAL_SKILLS_MANIFEST" "$REPO_DIR/skills-sync.sh" \
            install "$OPTIONAL_SKILLS_SRC" "$HOME/.agents/skills" "${FORCE:-0}"
        return
    fi
    # Nothing to remove unless an earlier run installed them.
    [ -f "$HOME/.agents/skills/$OPTIONAL_SKILLS_MANIFEST" ] || return 0
    SKILLS_MANIFEST_NAME="$OPTIONAL_SKILLS_MANIFEST" "$REPO_DIR/skills-sync.sh" \
        remove "$OPTIONAL_SKILLS_SRC" "$HOME/.agents/skills"
}

# Prints why this machine cannot run Apple Foundation Models and returns 1, or
# prints nothing and returns 0. Apple's on-device model needs Apple silicon.
apple_fm_platform_check() {
    if [ "$(uname -s)" != Darwin ]; then
        echo "not macOS"
        return 1
    fi
    if [ "$(uname -m)" != arm64 ]; then
        echo "not Apple silicon"
        return 1
    fi
    if ! command -v fm >/dev/null 2>&1; then
        echo "the fm CLI is not installed (it ships with recent macOS releases)"
        return 1
    fi
}

fm_license_agreed() {
    # Captured rather than piped: under pipefail, grep -q closing the pipe early
    # could turn a positive answer into a SIGPIPE failure.
    local status
    status=$(NO_COLOR=1 fm license --status 2>/dev/null || true)
    grep -q '^Agreed to license' <<<"$status"
}

# fm refuses to be scripted past its Legal Notice & Terms: there is no flag to
# agree, only an interactive prompt. So the agreement happens here, as part of
# setup, with the terms on screen and the answer typed by the person.
ensure_fm_license() {
    if fm_license_agreed; then
        return 0
    fi
    if [ ! -t 0 ]; then
        echo "fm Legal Notice & Terms not agreed to and this session is non-interactive."
        echo "Run 'fm license' in a terminal, then 'make update' again."
        return 1
    fi
    info "The Foundation Models CLI asks you to agree to its Legal Notice & Terms:"
    fm license || warn "fm license exited with an error"
    fm_license_agreed
}

# 'fm models' exits non-zero whenever any listed model is unavailable, Private
# Cloud Compute included, so readiness is read from its text.
apple_fm_model_ready() {
    local listing
    listing=$(NO_COLOR=1 fm models 2>&1 || true)
    grep -Eq '✓ +system' <<<"$listing"
}

install_apple_fm_skill() {
    local reason
    if [ ! -d "$OPTIONAL_SKILLS_SRC/apple-fm" ]; then
        return 0
    fi
    if ! reason=$(apple_fm_platform_check); then
        echo "Skill 'apple-fm' skipped: $reason."
        sync_optional_skills remove
        return 0
    fi
    if ! ensure_fm_license; then
        warn "Skill 'apple-fm' skipped: fm Legal Notice & Terms not agreed to."
        sync_optional_skills remove
        return 0
    fi
    if ! apple_fm_model_ready; then
        warn "Skill 'apple-fm' skipped: the on-device model is not ready (is Apple Intelligence enabled?)."
        sync_optional_skills remove
        return 0
    fi
    sync_optional_skills install
}

upgrade_deps() {
    info "Upgrading OS packages..."
    if command -v brew >/dev/null 2>&1; then      # macOS
        brew update
        brew upgrade curl git zsh vim tmux btop gcc
    elif command -v apt-get >/dev/null 2>&1; then # Debian / Ubuntu
        sudo apt-get update
        sudo apt-get install --only-upgrade -y curl git zsh vim tmux btop fontconfig unzip build-essential
    elif command -v dnf >/dev/null 2>&1; then     # Fedora
        sudo dnf upgrade -y curl git zsh vim tmux btop util-linux-user fontconfig unzip gcc-c++
    elif command -v pacman >/dev/null 2>&1; then  # Arch
        # Arch discourages partial upgrades; sync the whole system instead.
        sudo pacman -Syu --noconfirm
    else
        warn "Unknown OS: no brew/apt/dnf/pacman found."
        return 1
    fi
}

upgrade_tools() {
    if command -v claude >/dev/null 2>&1; then
        info "Updating Claude Code..."
        claude update || warn "claude update failed"
    fi
    if command -v uv >/dev/null 2>&1; then
        info "Updating uv..."
        uv self update || warn "uv self update failed"
    fi
    if command -v npm >/dev/null 2>&1; then
        info "Updating Codex CLI..."
        npm install -g @openai/codex || warn "Codex CLI update failed"
    fi
    if command -v herdr >/dev/null 2>&1; then
        info "Updating herdr..."
        herdr update || warn "herdr update failed"
        install_herdr_skill
    fi
    # nvm has no self-update; re-run the pinned installer to sync to NVM_VERSION.
    if [ -d "${NVM_DIR:-$HOME/.nvm}" ]; then
        info "Syncing nvm to $NVM_VERSION..."
        curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | PROFILE=/dev/null bash \
            || warn "nvm update failed"
    fi
}

upgrade_zinit() {
    local zinit_home="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    if [ ! -d "$zinit_home" ]; then
        echo "zinit not installed, skipping."
        return 0
    fi
    if ! command -v zsh >/dev/null 2>&1; then
        warn "zsh not found, skipping zinit update."
        return 0
    fi
    info "Updating zinit and plugins..."
    # zinit is loaded from .zshrc, so drive it through an interactive zsh.
    zsh -ic 'zinit self-update; zinit update --all' || warn "zinit update failed"
}

set_default_shell() {
    local zsh_path
    if ! zsh_path=$(command -v zsh); then
        warn "zsh not found on PATH, skipping default shell change."
        return 0
    fi
    if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
        if grep -qxF /bin/zsh /etc/shells 2>/dev/null; then
            zsh_path=/bin/zsh
        else
            if ! echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null; then
                warn "Could not register $zsh_path in /etc/shells, skipping default shell change."
                return 0
            fi
        fi
    fi
    if [ "${SHELL:-}" = "$zsh_path" ]; then
        echo "zsh is already the default shell."
        return 0
    fi
    info "Changing default shell to zsh (your password may be required)..."
    chsh -s "$zsh_path"
}

main() {
    # 'make update' calls this so the generated and machine-dependent skills are
    # refreshed alongside the repo-managed ones, without duplicating logic there.
    if [ "${1:-}" = "skill" ]; then
        install_herdr_skill
        install_apple_fm_skill
        return 0
    fi
    # 'make uninstall' calls this; optional skills use their own manifest.
    if [ "${1:-}" = "remove-optional-skills" ]; then
        sync_optional_skills remove
        return 0
    fi
    if [ "${1:-}" = "upgrade" ]; then
        upgrade_deps || warn "OS package upgrade encountered errors"
        upgrade_tools
        upgrade_zinit
        ok "Upgrade finished. Run 'make update' if configs changed, then restart your terminal."
        return 0
    fi
    local skip_deps=false
    if [ "${1:-}" = "-n" ]; then
        skip_deps=true
    fi
    install_ssh_key
    if [ "$skip_deps" = true ]; then
        warn "Skipping dependency installation (-n)"
    else
        install_deps
    fi
    install_font
    install_zinit
    install_vim_plug
    install_claude
    install_uv
    install_nvm
    install_codex
    install_herdr
    install_herdr_skill
    install_apple_fm_skill
    set_default_shell
    ok "Bootstrap finished. Run 'make update' to copy configs, then restart your terminal."
}

main "$@"
