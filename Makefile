SHELL := /bin/bash
# Wholly repo-owned configs: copied as-is (overwritten on update, removed on uninstall).
CONFIGS := .vimrc .p10k.zsh .tmux.conf
# Shell rc files: only the marked block inside them is managed; local edits are kept.
RC_CONFIGS := .zshrc .bash_profile
# FORCE=1 overwrites locally modified skills on update.
FORCE ?= 0

.DEFAULT_GOAL := help
.PHONY: help install bootstrap update upgrade reinstall uninstall test

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

install: bootstrap update ## Full install: deps + tools + configs + vim plugins
	vim +PlugInstall +qall
	@echo "Install finished. Restart your terminal to apply."

bootstrap: ## Install dependencies and tools (zinit, vim-plug, fonts, claude)
	./setup.sh

update: ## Copy config files into $$HOME (repeatable)
	cp $(CONFIGS) $(HOME)/
	@for rc in $(RC_CONFIGS); do ./rcblock.sh install "$$rc" "$(HOME)/$$rc"; done
	mkdir -p $(HOME)/.claude
	cp .claude/settings.json .claude/CLAUDE.md .claude/statusline-command.sh $(HOME)/.claude/
	./skills-sync.sh install .claude/skills "$(HOME)/.claude/skills" "$(FORCE)"
	@echo "Configs updated."

upgrade: ## Upgrade installed packages, tools, zinit, and vim plugins
	./setup.sh upgrade
	vim +PlugUpdate +qall
	@echo "Upgrade finished. Restart your terminal to apply."

reinstall: uninstall install ## Clean out installed configs, then install fresh

uninstall: ## Remove installed configs and plugin managers (keeps ~/.claude history)
	rm -f $(addprefix $(HOME)/,$(CONFIGS))
	@for rc in $(RC_CONFIGS); do ./rcblock.sh remove "$(HOME)/$$rc"; done
	rm -f $(HOME)/.claude/settings.json $(HOME)/.claude/CLAUDE.md $(HOME)/.claude/statusline-command.sh
	./skills-sync.sh remove .claude/skills "$(HOME)/.claude/skills"
	rm -rf $(HOME)/.vim/plugged $(HOME)/.vim/autoload/plug.vim
	rm -rf $${XDG_DATA_HOME:-$(HOME)/.local/share}/zinit
	@echo "Uninstalled. (~/.zsh_history and the rest of ~/.claude were kept.)"

test: ## Run the sandboxed test suite
	./tests/test.sh
