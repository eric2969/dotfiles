# Dotfiles

Personal environment setup: zsh (zinit + powerlevel10k), vim (vim-plug), tmux, Claude Code, Codex CLI, and herdr.

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
| `make upgrade` | Upgrade installed OS packages, curl-installed tools (claude, uv, nvm, herdr), zinit, and vim plugins |
| `make reinstall` | Clean out installed configs and plugin managers, then install fresh (`uninstall` + `install`) |
| `make uninstall` | Remove installed configs and plugin managers |
| `make test` | Run the sandboxed test suite (never touches your real `$HOME`); on Windows run `tests/test.sh` or `tests/test.ps1` directly |

**How each config is managed on update / uninstall:**

| Files | Policy |
|-------|--------|
| `~/.vimrc`, `~/.p10k.zsh`, `~/.tmux.conf`, `~/.claude/settings.json`, `~/.claude/statusline-command.sh`, `~/.codex/config.toml` | Wholly repo-owned: overwritten on update, removed on uninstall — edit them in the repo |
| `~/.zshrc`, `~/.bash_profile`, `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` | Block-managed: only the marked block (`# >>> dotfiles managed block >>> … <<<`) is rewritten/removed; your own lines are always kept |
| `~/.claude/CLAUDE.md`, `~/.agents/skills/*` | Manifest-managed: unmodified copies auto-update, copies you edited locally are kept (use `FORCE=1` to overwrite) |
| `~/.claude/skills/*`, `~/.codex/skills/*` | Symlinks to the shared copies in `~/.agents/skills`; unrelated and system skills are kept |
| `Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1` | Symlink to the pwsh 7 profile so Windows PowerShell 5.1 shares it; a profile you wrote yourself is kept (use `-Force` to replace it with the link) |
| `~/.agents/skills/herdr` | Generated from the installed binary (`herdr --skill`) on every update/upgrade, so it always matches the herdr release; removed on uninstall |

To skip OS package installation, run the bootstrap directly: `./setup.sh -n`.

## Install (Windows)

```powershell
git clone https://github.com/eric2969/dotfiles.git; cd dotfiles
.\setup.ps1                          # install (elevated shell required)
.\setup.ps1 -SkipDeps                # install without winget packages (elevated shell required)
.\setup.ps1 -Action update           # copy configs only
.\setup.ps1 -Action update -Force    # also overwrite locally modified skills / CLAUDE.md
.\setup.ps1 -Action upgrade          # upgrade installed packages and tools
.\setup.ps1 -Action reinstall        # remove, then install fresh (elevated shell required)
.\setup.ps1 -Action uninstall        # remove
.\setup.ps1 -Action doctor           # report why the prompt is not showing up
```

`install` and `reinstall` refuse to run outside an elevated PowerShell, because
Chocolatey, nvm-windows and Developer Mode all install machine-wide. Everything
else — `update`, `upgrade`, `uninstall` — works as a normal user, so config-only
runs never need admin.

Shared skills live in `~/.agents/skills` and follow the same manifest policy as on Unix. Both `~/.claude/skills` and `~/.codex/skills` link to those shared copies; locally modified or unrelated skills are preserved. The installer enables Windows Developer Mode so non-elevated processes can create symbolic links; that registry write needs admin, and when it is unavailable the run warns and keeps going — every config is still copied, only the skill symlinks may fail.

Windows installs PowerShell 7/git/vim/oh-my-posh (winget), Chocolatey, Claude Code, Codex CLI, herdr, uv, nvm-windows (choco), the posh-git and PSReadLine modules, the Nerd Font, vim-plug, `_vimrc`, the PowerShell 7 profile, and agent settings. zsh/tmux configs are Unix-only. **Node.js is owned by nvm-windows**, mirroring Unix: nothing is installed through winget, and `nvm install lts` provides the npm that Codex CLI needs. A tool that cannot be installed (no Chocolatey, no nvm) is reported as a warning and skipped — it never aborts the rest of the run.

The PowerShell profile is installed into `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` (resolved through the real Documents folder, so OneDrive redirection works) as a managed block, the same policy `.zshrc` gets on Unix — anything you add outside the markers survives updates and uninstall. Windows PowerShell 5.1 reads a different path (`Documents/WindowsPowerShell/…`), so that one is symlinked to the pwsh profile — a single file serves both editions and they cannot drift apart. The profile therefore has to run on 5.1 too: PSReadLine predictions are version-guarded, because 5.1 ships PSReadLine 2.0.0 and only 2.1+ knows `-PredictionSource`.

### The prompt is not showing up

Run `.\setup.ps1 -Action doctor`. It is read-only and prints a `FIX` line with the
exact command for whatever is wrong. The usual causes, in order:

1. **You are in Windows PowerShell 5.1 and the profile link is missing.** 5.1 reads
   `Documents/WindowsPowerShell/`, which `update` symlinks to the pwsh profile; without
   Developer Mode or admin that link cannot be created and 5.1 finds nothing there.
   `doctor` reports it. The blue-icon "Windows PowerShell" and Win+X entries are 5.1.
2. **PowerShell 7 is not installed.** The installer now installs it, but a run from
   before that fix did not: `winget install --id Microsoft.PowerShell -e`.
3. **The execution policy is `Restricted` or `AllSigned`**, so the profile is skipped
   silently. `update` relaxes it for the current user; by hand it is
   `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`.
4. **The Nerd Font is missing or the terminal is not using it.** The prompt loads, but
   every icon renders as an empty box. Set the terminal font to *SauceCodePro Nerd Font*.

Note the Windows prompt is **oh-my-posh** with the `clean-detailed` theme, not
powerlevel10k — `.p10k.zsh` is zsh-only and is never installed on Windows, so the two
prompts do not look the same.

## What's inside

- `setup.sh` — Unix bootstrapper: OS packages, Sauce Code Pro Nerd Font, zinit, vim-plug, Claude Code, Codex CLI, herdr, uv, nvm, default shell (`./setup.sh skill` regenerates the herdr agent skill on its own)
- `rcblock.sh` — manages the marked dotfiles block inside `~/.zshrc` / `~/.bash_profile`
- `skills-sync.sh` — manifest-based sync of shared skills into `~/.agents/skills`, plus single-file mode (`install-file` / `remove-file`) used for `~/.claude/CLAUDE.md`
- `skill-links.sh` — links shared skills into both `~/.claude/skills` and `~/.codex/skills`
- `setup.ps1` — Windows installer; also manages the marked block inside the PowerShell profile
- `Microsoft.PowerShell_profile.ps1` — PowerShell 7 profile: prompt (posh-git + oh-my-posh), PSReadLine history/prediction, and the same aliases as `.bash_profile`
- `Makefile` — help / install / update / upgrade / reinstall / uninstall / test entry points
- `tests/test.sh` — sandboxed test suite; the `verify` skill runs it (plus shellcheck) before every commit. It also runs `tests/test.ps1` when `pwsh` is present, and skips the `make` section when `make` is not
- `tests/test.ps1` — sandboxed `setup.ps1` suite (throwaway `USERPROFILE`, needs no admin); run it directly with `pwsh -NoProfile -File tests/test.ps1`
- `.zshrc` — zsh-only layer (see below)
- `.bash_profile` — shared shell layer (see below)
- `.vimrc` — vim-plug plugins
- `.tmux.conf` — tmux config
- `.agents/skills/` — shared skills used by Claude Code and Codex
- `.claude/` — Claude Code-specific settings and CLAUDE.md
- `.codex/config.toml` — Codex CLI settings, including the TUI status line

## Shell config layout

The shell config is split into two layers; they cannot be merged into one file because
`.zshrc` uses zsh-only syntax that would break bash.

| File | Read by | Contents |
|------|---------|----------|
| `.bash_profile` | bash directly; zsh via `source` at the end of `.zshrc` | **Shared layer**, POSIX syntax only: common env vars (`TERM`, `EDITOR`, `LC_ALL`, …), `~/.local/bin` on PATH (claude, uv), nvm init, all aliases |
| `.zshrc` | zsh only | **zsh layer**: p10k instant prompt, zinit plugins, `compinit`, `setopt` history options, `HISTFILE` (`~/.zsh_history`), p10k theme |
| `Microsoft.PowerShell_profile.ps1` | PowerShell 7 only (Windows) | **PowerShell layer**: mirrors the `.bash_profile` env vars and aliases in PowerShell syntax, plus PSReadLine options and the posh-git / oh-my-posh prompt |

Rule of thumb: anything both shells should see goes in `.bash_profile`; anything using
zsh syntax or configuring zsh itself goes in `.zshrc`.

After installing, set your terminal font to **SauceCodePro Nerd Font** and restart the terminal.
