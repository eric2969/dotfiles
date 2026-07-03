# Dotfiles

Personal environment setup: zsh (zinit + powerlevel10k), vim (vim-plug), tmux, and Claude Code settings.

Configs are **copied** into `$HOME` (not symlinked), so this repo can be deleted after installation.

## Install (macOS / Linux)

```sh
git clone https://github.com/eric2969/dotfiles.git && cd dotfiles
make install
```

| Command | What it does |
|---------|--------------|
| `make install` | Install dependencies + tools, copy configs, install vim plugins |
| `make update` | Copy configs into `$HOME` only (re-run any time) |
| `make uninstall` | Remove installed configs and plugin managers |

**Note:** `make update` overwrites `~/.zshrc`, `~/.vimrc`, etc. with the repo versions — local edits to those files are lost. Edit configs in the repo (or back them up) before running it.

To skip OS package installation, run the bootstrap directly: `./setup.sh -n`.

## Install (Windows)

```powershell
git clone https://github.com/eric2969/dotfiles.git; cd dotfiles
.\setup.ps1                      # install
.\setup.ps1 -Action update      # copy configs only
.\setup.ps1 -Action uninstall   # remove
```

Windows installs git/vim (winget), the Nerd Font, vim-plug, `_vimrc`, and Claude Code settings. zsh/tmux configs are Unix-only.

## What's inside

- `setup.sh` — Unix bootstrapper: OS packages, Sauce Code Pro Nerd Font, zinit, vim-plug, Claude Code, default shell
- `setup.ps1` — Windows installer
- `Makefile` — install / update / uninstall entry points
- `.zshrc` — zinit + powerlevel10k (`.p10k.zsh`)
- `.vimrc` — vim-plug plugins
- `.tmux.conf`, `.bash_profile` (aliases)
- `.claude/` — Claude Code settings, CLAUDE.md, skills

After installing, set your terminal font to **SauceCodePro Nerd Font** and restart the terminal.
