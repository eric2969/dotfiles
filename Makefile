SHELL := /bin/bash
# Wholly repo-owned configs: copied as-is (overwritten on update, removed on uninstall).
CONFIGS := .vimrc .p10k.zsh .tmux.conf
# Shell rc files: only the marked block inside them is managed; local edits are kept.
RC_CONFIGS := .zshrc .bash_profile
# FORCE=1 overwrites locally modified shared skills and CLAUDE.md on update.
FORCE ?= 0

.DEFAULT_GOAL := help
.PHONY: help install bootstrap update upgrade reinstall uninstall test

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

install: bootstrap update ## Full install: deps + tools + configs + vim plugins
	vim +PlugInstall +qall
	@echo "Install finished. Restart your terminal to apply."

bootstrap: ## Install dependencies and tools (zinit, vim-plug, fonts, claude, codex)
	./setup.sh

update: ## Copy config files into $$HOME (repeatable)
	cp $(CONFIGS) $(HOME)/
	@for rc in $(RC_CONFIGS); do ./rcblock.sh install "$$rc" "$(HOME)/$$rc"; done
	mkdir -p $(HOME)/.claude
	cp .claude/settings.json .claude/statusline-command.sh $(HOME)/.claude/
	./skills-sync.sh install-file .claude/CLAUDE.md "$(HOME)/.claude/CLAUDE.md" "$(FORCE)"
	./skills-sync.sh install .agents/skills "$(HOME)/.agents/skills" "$(FORCE)"
	@if [ -f "$(HOME)/.claude/skills/.dotfiles-manifest" ]; then ./skills-sync.sh remove .agents/skills "$(HOME)/.claude/skills"; fi
	./skill-links.sh install "$(HOME)/.agents/skills" "$(HOME)/.claude/skills" "$(FORCE)"
	./skill-links.sh install "$(HOME)/.agents/skills" "$(HOME)/.codex/skills" "$(FORCE)"
	@echo "Configs updated."

upgrade: ## Upgrade installed packages, tools, zinit, and vim plugins
	./setup.sh upgrade
	vim +PlugUpdate +qall
	@echo "Upgrade finished. Restart your terminal to apply."

reinstall: uninstall install ## Clean out installed configs, then install fresh

uninstall: ## Remove installed configs and plugin managers (keeps ~/.claude history)
	rm -f $(addprefix $(HOME)/,$(CONFIGS))
	@for rc in $(RC_CONFIGS); do ./rcblock.sh remove "$(HOME)/$$rc"; done
	rm -f $(HOME)/.claude/settings.json $(HOME)/.claude/statusline-command.sh
	./skills-sync.sh remove-file .claude/CLAUDE.md "$(HOME)/.claude/CLAUDE.md"
	./skill-links.sh remove "$(HOME)/.agents/skills" "$(HOME)/.claude/skills"
	./skill-links.sh remove "$(HOME)/.agents/skills" "$(HOME)/.codex/skills"
	./skills-sync.sh remove .agents/skills "$(HOME)/.agents/skills"
	rm -rf $(HOME)/.vim/plugged $(HOME)/.vim/autoload/plug.vim
	rm -rf $${XDG_DATA_HOME:-$(HOME)/.local/share}/zinit
	@echo "Uninstalled. (~/.zsh_history and the rest of ~/.claude were kept.)"

test: ## Run the sandboxed test suite
	./tests/test.sh
