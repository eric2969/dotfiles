
# Shared env vars (read by both bash and zsh; .zshrc sources this file)
export TERM="xterm-256color"
export SSH_KEY_PATH="$HOME/.ssh/id_rsa"
export LC_ALL=en_US.UTF-8
export EDITOR="vim"

# Tool paths / init — each line is a no-op when the tool is not installed
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;; # claude, uv
esac
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if [ -n "${BASH_VERSION:-}" ] && [ -s "$NVM_DIR/bash_completion" ]; then
    . "$NVM_DIR/bash_completion" # bash only; zsh uses its own completion
fi

alias cls=clear
if ls --color=auto / >/dev/null 2>&1; then
    alias l="ls -la --color=auto"
else
    alias l="ls -laG" # BSD ls on older macOS
fi
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git pull"
alias gr="git reset"
alias grh="git reset --hard"
alias ptt="ssh bbsu@ptt.cc"
