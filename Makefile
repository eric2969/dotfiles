SHELL := /bin/bash
CONFIGS := .zshrc .vimrc .p10k.zsh .tmux.conf .bash_profile

.PHONY: install bootstrap update uninstall

install: bootstrap update ## Full install: deps + tools + configs + vim plugins
	vim +PlugInstall +qall
	@echo "Install finished. Restart your terminal to apply."

bootstrap: ## Install dependencies and tools (zinit, vim-plug, fonts, claude)
	./setup.sh

update: ## Copy config files into $$HOME (repeatable)
	cp $(CONFIGS) $(HOME)/
	mkdir -p $(HOME)/.claude/skills
	cp .claude/settings.json .claude/CLAUDE.md .claude/statusline-command.sh $(HOME)/.claude/
	cp -R .claude/skills/. $(HOME)/.claude/skills/
	@echo "Configs updated."

uninstall: ## Remove installed configs and plugin managers (keeps ~/.claude history)
	rm -f $(addprefix $(HOME)/,$(CONFIGS))
	rm -f $(HOME)/.claude/settings.json $(HOME)/.claude/CLAUDE.md $(HOME)/.claude/statusline-command.sh
	rm -rf $(HOME)/.claude/skills
	rm -rf $(HOME)/.vim/plugged $(HOME)/.vim/autoload/plug.vim
	rm -rf $${XDG_DATA_HOME:-$(HOME)/.local/share}/zinit
	@echo "Uninstalled. (~/.zsh_history and the rest of ~/.claude were kept.)"
