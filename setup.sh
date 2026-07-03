#!/usr/bin/env bash
set -euo pipefail

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
    info "Installing dependencies..."
    if command -v brew >/dev/null 2>&1; then      # macOS
        brew update
        brew install curl git zsh vim tmux htop gcc
    elif command -v apt-get >/dev/null 2>&1; then # Debian / Ubuntu
        sudo apt-get update
        sudo apt-get install -y curl git zsh vim tmux htop fontconfig unzip build-essential
    elif command -v dnf >/dev/null 2>&1; then     # Fedora
        sudo dnf install -y curl git zsh vim tmux htop util-linux-user fontconfig unzip gcc-c++
    elif command -v pacman >/dev/null 2>&1; then  # Arch
        sudo pacman -S --needed --noconfirm curl git zsh vim tmux htop fontconfig unzip base-devel
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
    curl -fsSL https://claude.ai/install.sh | sh
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
    set_default_shell
    ok "Bootstrap finished. Run 'make update' to copy configs, then restart your terminal."
}

main "$@"
