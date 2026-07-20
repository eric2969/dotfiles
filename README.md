# Dotfiles

Personal environment setup: zsh (zinit + powerlevel10k), vim (vim-plug), tmux, Claude Code, and Codex CLI.

Configs and shared skills are copied into `$HOME`, so this repo can be deleted after installation. Only the agent-facing skill entries are symlinks, and they point to `~/.agents/skills` rather than back to this repo.

## Install (macOS / Linux)

```sh
git clone https://github.com/eric2969/dotfiles.git && cd dotfiles
make install
```

| Command | What it does |
|---------|--------------|
| `make` / `make help` | List available targets |
| `make install` | Install dependencies + tools, copy configs, install vim plugins |
| `make update` | Copy configs into `$HOME` only (re-run any time); `FORCE=1` overwrites locally modified skills and CLAUDE.md |
| `make upgrade` | Upgrade installed OS packages, curl-installed tools (claude, uv, nvm), zinit, and vim plugins |
| `make reinstall` | Clean out installed configs and plugin managers, then install fresh (`uninstall` + `install`) |
| `make uninstall` | Remove installed configs and plugin managers |
| `make test` | Run the sandboxed test suite (never touches your real `$HOME`) |

**How each config is managed on update / uninstall:**

| Files | Policy |
|-------|--------|
| `~/.vimrc`, `~/.p10k.zsh`, `~/.tmux.conf`, `~/.claude/settings.json`, `~/.claude/statusline-command.sh` | Wholly repo-owned: overwritten on update, removed on uninstall — edit them in the repo |
| `~/.zshrc`, `~/.bash_profile` | Block-managed: only the marked block (`# >>> dotfiles managed block >>> … <<<`) is rewritten/removed; your own lines are always kept |
| `~/.claude/CLAUDE.md`, `~/.agents/skills/*` | Manifest-managed: unmodified copies auto-update, copies you edited locally are kept (use `FORCE=1` to overwrite) |
| `~/.claude/skills/*`, `~/.codex/skills/*` | Symlinks to the shared copies in `~/.agents/skills`; unrelated and system skills are kept |

To skip OS package installation, run the bootstrap directly: `./setup.sh -n`.

## Install (Windows)

```powershell
git clone https://github.com/eric2969/dotfiles.git; cd dotfiles
.\setup.ps1                          # install
.\setup.ps1 -SkipDeps                # install without winget packages
.\setup.ps1 -Action update           # copy configs only
.\setup.ps1 -Action update -Force    # also overwrite locally modified skills / CLAUDE.md
.\setup.ps1 -Action upgrade          # upgrade installed packages and tools
.\setup.ps1 -Action reinstall        # remove, then install fresh
.\setup.ps1 -Action uninstall        # remove
```

Shared skills live in `~/.agents/skills` and follow the same manifest policy as on Unix. Both `~/.claude/skills` and `~/.codex/skills` link to those shared copies; locally modified or unrelated skills are preserved. The installer enables Windows Developer Mode so non-elevated processes can create symbolic links (run setup from an elevated PowerShell for the registry change).

Windows installs git/vim/Node.js LTS (winget), Chocolatey, Claude Code, Codex CLI, uv, nvm-windows (choco), the Nerd Font, vim-plug, `_vimrc`, and agent settings. zsh/tmux configs are Unix-only. Run the install from an elevated PowerShell (Chocolatey and Developer Mode setup need admin).

## What's inside

- `setup.sh` — Unix bootstrapper: OS packages, Sauce Code Pro Nerd Font, zinit, vim-plug, Claude Code, uv, nvm, default shell
- `rcblock.sh` — manages the marked dotfiles block inside `~/.zshrc` / `~/.bash_profile`
- `skills-sync.sh` — manifest-based sync of shared skills into `~/.agents/skills`, plus single-file mode (`install-file` / `remove-file`) used for `~/.claude/CLAUDE.md`
- `skill-links.sh` — links shared skills into both `~/.claude/skills` and `~/.codex/skills`
- `setup.ps1` — Windows installer
- `Makefile` — help / install / update / upgrade / reinstall / uninstall / test entry points
- `tests/test.sh` — sandboxed test suite; the `verify` skill runs it (plus shellcheck) before every commit
- `.zshrc` — zsh-only layer (see below)
- `.bash_profile` — shared shell layer (see below)
- `.vimrc` — vim-plug plugins
- `.tmux.conf` — tmux config
- `.agents/skills/` — shared skills used by Claude Code and Codex
- `.claude/` — Claude Code-specific settings and CLAUDE.md

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
