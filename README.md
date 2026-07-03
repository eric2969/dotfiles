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

**Note:** `~/.zshrc` and `~/.bash_profile` are managed via a marked block (`# >>> dotfiles managed block >>> … # <<< dotfiles managed block <<<`): `make update` rewrites only that block and `make uninstall` removes only that block, so your own lines outside the markers are always kept. The other configs (`~/.vimrc`, `~/.p10k.zsh`, `~/.tmux.conf`) are wholly repo-owned and still fully overwritten — edit those in the repo.

To skip OS package installation, run the bootstrap directly: `./setup.sh -n`.

## Install (Windows)

```powershell
git clone https://github.com/eric2969/dotfiles.git; cd dotfiles
.\setup.ps1                      # install
.\setup.ps1 -Action update      # copy configs only
.\setup.ps1 -Action uninstall   # remove
```

Windows installs git/vim (winget), Chocolatey, Claude Code, uv, nvm-windows (choco), the Nerd Font, vim-plug, `_vimrc`, and Claude Code settings. zsh/tmux configs are Unix-only. Run the install from an elevated PowerShell (Chocolatey needs admin).

## What's inside

- `setup.sh` — Unix bootstrapper: OS packages, Sauce Code Pro Nerd Font, zinit, vim-plug, Claude Code, uv, nvm, default shell
- `rcblock.sh` — manages the marked dotfiles block inside `~/.zshrc` / `~/.bash_profile`
- `setup.ps1` — Windows installer
- `Makefile` — install / update / uninstall entry points
- `.zshrc` — zsh-only layer (see below)
- `.bash_profile` — shared shell layer (see below)
- `.vimrc` — vim-plug plugins
- `.tmux.conf` — tmux config
- `.claude/` — Claude Code settings, CLAUDE.md, skills

## Shell config layout

The shell config is split into two layers; they cannot be merged into one file because
`.zshrc` uses zsh-only syntax that would break bash.

| File | Read by | Contents |
|------|---------|----------|
| `.bash_profile` | bash directly; zsh via `source` at the end of `.zshrc` | **Shared layer**, POSIX syntax only: common env vars (`TERM`, `EDITOR`, `LC_ALL`, …), `~/.local/bin` on PATH (claude, uv), nvm init, all aliases |
| `.zshrc` | zsh only | **zsh layer**: p10k instant prompt, zinit plugins, `compinit`, `setopt` history options, `HISTFILE` (`~/.zsh_history`), p10k theme |

Rule of thumb: anything both shells should see goes in `.bash_profile`; anything using
zsh syntax or configuring zsh itself goes in `.zshrc`.

After installing, set your terminal font to **SauceCodePro Nerd Font** and restart the terminal.
