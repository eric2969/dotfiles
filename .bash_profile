
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
