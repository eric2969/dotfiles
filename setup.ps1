<#
.SYNOPSIS
    Windows installer for these dotfiles.
.DESCRIPTION
    install   - install dependencies (git, vim, node, choco, claude, codex, uv, nvm), Nerd Font, vim-plug, then copy configs
    update    - copy configs only
    upgrade   - upgrade installed packages and tools (winget, choco, claude, codex, uv, vim plugins)
    reinstall - remove installed configs, then install fresh (uninstall + install)
    uninstall - remove configs installed by this script
#>
param(
    [ValidateSet('install', 'update', 'upgrade', 'reinstall', 'uninstall')]
    [string]$Action = 'install',
    # Overwrite locally modified skills and CLAUDE.md on update (mirrors FORCE=1 for make).
    [switch]$Force,
    # Skip winget dependency installation (mirrors setup.sh -n).
    [switch]$SkipDeps
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$AgentsDir = Join-Path $env:USERPROFILE '.agents'
$CodexDir = Join-Path $env:USERPROFILE '.codex'

function Install-Dependencies {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget not found. Install "App Installer" from the Microsoft Store first.'
    }
    Write-Host 'Installing dependencies via winget...' -ForegroundColor Yellow
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install Git.Git exited with code $LASTEXITCODE" }
    winget install --id vim.vim -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install vim.vim exited with code $LASTEXITCODE" }
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install OpenJS.NodeJS.LTS exited with code $LASTEXITCODE" }
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
}

function Install-Choco {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host 'Chocolatey already installed.'
        return
    }
    Write-Host 'Installing Chocolatey (requires an elevated shell)...' -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Install-Claude {
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Host 'Claude Code already installed.'
        return
    }
    Write-Host 'Installing Claude Code...' -ForegroundColor Yellow
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
}

function Install-Uv {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host 'uv already installed.'
        return
    }
    Write-Host 'Installing uv...' -ForegroundColor Yellow
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
}

function Install-Nvm {
    if (Get-Command nvm -ErrorAction SilentlyContinue) {
        Write-Host 'nvm already installed.'
        return
    }
    Write-Host 'Installing nvm-windows via Chocolatey...' -ForegroundColor Yellow
    choco install nvm -y
    if ($LASTEXITCODE -ne 0) { Write-Warning "choco install nvm exited with code $LASTEXITCODE" }
}

function Install-Codex {
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        Write-Host 'Codex CLI already installed.'
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw 'npm not found. Install Node.js LTS before installing Codex CLI.'
    }
    Write-Host 'Installing Codex CLI...' -ForegroundColor Yellow
    npm install -g '@openai/codex'
    if ($LASTEXITCODE -ne 0) { throw "npm install @openai/codex exited with code $LASTEXITCODE" }
}

function Enable-SymbolicLinks {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    Write-Host 'Enabling Windows Developer Mode for symbolic links...' -ForegroundColor Yellow
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -PropertyType DWord -Value 1 -Force | Out-Null
}

function Install-NerdFont {
    $userFonts   = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter 'SauceCodePro*.ttf' -ErrorAction SilentlyContinue
    $systemFonts = Get-ChildItem "$env:windir\Fonts" -Filter 'SauceCodePro*.ttf' -ErrorAction SilentlyContinue
    if ($userFonts -or $systemFonts) {
        Write-Host 'Nerd Font already installed.'
        return
    }
    Write-Host 'Installing Sauce Code Pro Nerd Font...' -ForegroundColor Yellow
    $zip = Join-Path $env:TEMP 'SourceCodePro.zip'
    $dir = Join-Path $env:TEMP 'SourceCodePro'
    Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SourceCodePro.zip' -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    $shell = New-Object -ComObject Shell.Application
    $fonts = $shell.Namespace(0x14)  # Fonts special folder
    Get-ChildItem $dir -Filter '*.ttf' | ForEach-Object {
        $fonts.CopyHere($_.FullName, 0x10)  # 0x10 = overwrite without prompt
    }
    Remove-Item $zip, $dir -Recurse -Force -ErrorAction SilentlyContinue
}

function Install-VimPlug {
    $plug = Join-Path $env:USERPROFILE 'vimfiles\autoload\plug.vim'
    if (Test-Path $plug) {
        Write-Host 'vim-plug already installed.'
        return
    }
    Write-Host 'Installing vim-plug...' -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path (Split-Path $plug) | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' -OutFile $plug
}

# A content-hash manifest tells apart "user modified the installed copy" (kept)
# from "installed copy is just an older repo version" (updated).
$SkillsDir = Join-Path $AgentsDir 'skills'
$ManifestPath = Join-Path $SkillsDir '.dotfiles-manifest'

function Get-SkillHash([string]$Dir) {
    $sb = [System.Text.StringBuilder]::new()
    Get-ChildItem $Dir -Recurse -File | Sort-Object FullName | ForEach-Object {
        [void]$sb.AppendLine($_.FullName.Substring($Dir.Length))
        [void]$sb.AppendLine((Get-FileHash $_.FullName -Algorithm SHA256).Hash)
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    ([System.BitConverter]::ToString($hash) -replace '-', '').ToLower()
}

function Get-Manifest([string]$Path = $ManifestPath) {
    $manifest = @{}
    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            $parts = $_ -split ' ', 2
            if ($parts.Count -eq 2) { $manifest[$parts[0]] = $parts[1] }
        }
    }
    $manifest
}

function Save-Manifest($Manifest, [string]$Path = $ManifestPath) {
    if ($Manifest.Count -eq 0) {
        Remove-Item $Path -Force -ErrorAction SilentlyContinue
        return
    }
    $Manifest.GetEnumerator() | Sort-Object Key |
        ForEach-Object { "$($_.Key) $($_.Value)" } | Set-Content $Path
}

# Single-file variant of the skills manifest policy, used for CLAUDE.md.
$ClaudeManifestPath = Join-Path $ClaudeDir '.dotfiles-manifest'

function Get-SingleFileHash([string]$File) {
    (Get-FileHash $File -Algorithm SHA256).Hash.ToLower()
}

function Install-ManagedFile([string]$Source, [string]$Dest) {
    $name = Split-Path $Dest -Leaf
    $manifest = Get-Manifest $ClaudeManifestPath
    $repoHash = Get-SingleFileHash $Source
    if (-not (Test-Path $Dest)) {
        Copy-Item $Source $Dest
        $manifest[$name] = $repoHash
        Save-Manifest $manifest $ClaudeManifestPath
        Write-Host "File '$name' installed."
        return
    }
    $curHash = Get-SingleFileHash $Dest
    if ($curHash -eq $repoHash) {
        $manifest[$name] = $repoHash
        Write-Host "File '$name' up to date."
    } elseif ($Force -or $curHash -eq $manifest[$name]) {
        Copy-Item $Source $Dest -Force
        $manifest[$name] = $repoHash
        Write-Host "File '$name' updated."
    } else {
        Write-Warning "File '$name' modified locally, keeping it (use -Force to overwrite)."
    }
    Save-Manifest $manifest $ClaudeManifestPath
}

function Remove-ManagedFile([string]$Source, [string]$Dest) {
    $name = Split-Path $Dest -Leaf
    if (-not (Test-Path $Dest)) { return }
    $manifest = Get-Manifest $ClaudeManifestPath
    $curHash = Get-SingleFileHash $Dest
    if ($curHash -eq $manifest[$name] -or $curHash -eq (Get-SingleFileHash $Source)) {
        Remove-Item $Dest -Force
        Write-Host "File '$name' removed."
    } else {
        Write-Warning "File '$name' modified locally, keeping it."
    }
    $manifest.Remove($name)
    Save-Manifest $manifest $ClaudeManifestPath
}

function Copy-Skills {
    New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
    $manifest = Get-Manifest
    Get-ChildItem (Join-Path $RepoRoot '.agents\skills') -Directory | ForEach-Object {
        $dest = Join-Path $SkillsDir $_.Name
        $repoHash = Get-SkillHash $_.FullName
        if (-not (Test-Path $dest)) {
            Copy-Item $_.FullName $dest -Recurse
            $manifest[$_.Name] = $repoHash
            Write-Host "Skill '$($_.Name)' installed."
            return
        }
        $curHash = Get-SkillHash $dest
        if ($curHash -eq $repoHash) {
            $manifest[$_.Name] = $repoHash
            Write-Host "Skill '$($_.Name)' up to date."
        } elseif ($Force -or $curHash -eq $manifest[$_.Name]) {
            Remove-Item $dest -Recurse -Force
            Copy-Item $_.FullName $dest -Recurse
            $manifest[$_.Name] = $repoHash
            Write-Host "Skill '$($_.Name)' updated."
        } else {
            Write-Warning "Skill '$($_.Name)' modified locally, keeping it (use -Force to overwrite)."
        }
    }
    # Prune skills that were repo-managed but no longer exist in the repo.
    $repoNames = (Get-ChildItem (Join-Path $RepoRoot '.agents\skills') -Directory).Name
    @($manifest.Keys) | Where-Object { $repoNames -notcontains $_ } | ForEach-Object {
        $dest = Join-Path $SkillsDir $_
        if (Test-Path $dest) {
            if ((Get-SkillHash $dest) -eq $manifest[$_]) {
                Remove-Item $dest -Recurse -Force
                Write-Host "Skill '$_' no longer in repo, removed."
            } else {
                Write-Warning "Skill '$_' no longer in repo but modified locally, keeping it."
            }
        }
        $manifest.Remove($_)
    }
    Save-Manifest $manifest
}

function Sync-SkillLinks([string]$TargetRoot) {
    New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
    $linkManifest = Join-Path $TargetRoot '.dotfiles-links'
    $managed = @()
    if (Test-Path $linkManifest) { $managed = @(Get-Content $linkManifest) }

    Get-ChildItem (Join-Path $RepoRoot '.agents\skills') -Directory | ForEach-Object {
        $name = $_.Name
        $source = Join-Path $SkillsDir $name
        $dest = Join-Path $TargetRoot $name
        if (Test-Path $dest) {
            $item = Get-Item $dest -Force
            $target = @($item.Target)[0]
            if ($item.LinkType -eq 'SymbolicLink' -and $target -eq $source) {
                Write-Host "Skill link '$name' up to date."
            } elseif ($item.LinkType -eq 'SymbolicLink' -and $Force) {
                Remove-Item $dest -Force
                New-Item -ItemType SymbolicLink -Path $dest -Target $source | Out-Null
                Write-Host "Skill link '$name' updated."
            } else {
                Write-Warning "Skill '$name' already exists in $TargetRoot, keeping it."
                return
            }
        } else {
            New-Item -ItemType SymbolicLink -Path $dest -Target $source | Out-Null
            Write-Host "Skill link '$name' installed."
        }
        if ($managed -notcontains $name) { $managed += $name }
    }
    $repoNames = @(Get-ChildItem (Join-Path $RepoRoot '.agents\skills') -Directory).Name
    @($managed) | Where-Object { $repoNames -notcontains $_ } | ForEach-Object {
        $dest = Join-Path $TargetRoot $_
        if ((Test-Path $dest) -and (Get-Item $dest -Force).LinkType -eq 'SymbolicLink') {
            Remove-Item $dest -Force
            Write-Host "Skill link '$_' no longer managed, removed."
        }
        $removedName = $_
        $managed = @($managed | Where-Object { $_ -ne $removedName })
    }
    if ($managed.Count) { $managed | Sort-Object -Unique | Set-Content $linkManifest }
    else { Remove-Item $linkManifest -Force -ErrorAction SilentlyContinue }
}

function Remove-LegacyClaudeSkillCopies {
    $legacyRoot = Join-Path $ClaudeDir 'skills'
    $legacyManifest = Join-Path $legacyRoot '.dotfiles-manifest'
    if (-not (Test-Path $legacyManifest)) { return }
    $manifest = Get-Manifest $legacyManifest
    Get-ChildItem (Join-Path $RepoRoot '.agents\skills') -Directory | ForEach-Object {
        $dest = Join-Path $legacyRoot $_.Name
        if (-not (Test-Path $dest)) { return }
        $curHash = Get-SkillHash $dest
        if ($curHash -eq $manifest[$_.Name] -or $curHash -eq (Get-SkillHash $_.FullName)) {
            Remove-Item $dest -Recurse -Force
            Write-Host "Legacy Claude skill '$($_.Name)' migrated to shared skills."
        } else {
            Write-Warning "Legacy Claude skill '$($_.Name)' was modified locally, keeping it."
        }
    }
    Remove-Item $legacyManifest -Force
}

function Remove-SkillLinks([string]$TargetRoot) {
    $linkManifest = Join-Path $TargetRoot '.dotfiles-links'
    if (-not (Test-Path $linkManifest)) { return }
    Get-Content $linkManifest | ForEach-Object {
        $dest = Join-Path $TargetRoot $_
        if (Test-Path $dest) {
            $item = Get-Item $dest -Force
            if ($item.LinkType -eq 'SymbolicLink' -and @($item.Target)[0] -eq (Join-Path $SkillsDir $_)) {
                Remove-Item $dest -Force
                Write-Host "Skill link '$_' removed."
            }
        }
    }
    Remove-Item $linkManifest -Force
    if ((Test-Path $TargetRoot) -and -not (Get-ChildItem $TargetRoot -Force)) { Remove-Item $TargetRoot -Force }
}

function Copy-Configs {
    Write-Host 'Copying configs...' -ForegroundColor Yellow
    Enable-SymbolicLinks
    Copy-Item (Join-Path $RepoRoot '.vimrc') (Join-Path $env:USERPROFILE '_vimrc') -Force
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    Copy-Item (Join-Path $RepoRoot '.claude\settings.json') $ClaudeDir -Force
    New-Item -ItemType Directory -Force -Path $CodexDir | Out-Null
    Copy-Item (Join-Path $RepoRoot '.codex\config.toml') $CodexDir -Force
    Install-ManagedFile (Join-Path $RepoRoot '.claude\CLAUDE.md') (Join-Path $ClaudeDir 'CLAUDE.md')
    Copy-Skills
    Remove-LegacyClaudeSkillCopies
    Sync-SkillLinks (Join-Path $ClaudeDir 'skills')
    Sync-SkillLinks (Join-Path $CodexDir 'skills')
    Write-Host 'Configs updated.'
}

function Remove-Configs {
    Write-Host 'Removing installed configs...' -ForegroundColor Yellow
    Remove-Item (Join-Path $env:USERPROFILE '_vimrc') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $ClaudeDir 'settings.json') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $CodexDir 'config.toml') -Force -ErrorAction SilentlyContinue
    Remove-ManagedFile (Join-Path $RepoRoot '.claude\CLAUDE.md') (Join-Path $ClaudeDir 'CLAUDE.md')
    # Only remove repo-managed skills; keep user-authored or user-modified ones.
    $manifest = Get-Manifest
    Remove-SkillLinks (Join-Path $ClaudeDir 'skills')
    Remove-SkillLinks (Join-Path $CodexDir 'skills')
    Get-ChildItem (Join-Path $RepoRoot '.agents\skills') -Directory | ForEach-Object {
        $dest = Join-Path $SkillsDir $_.Name
        if (-not (Test-Path $dest)) { return }
        $curHash = Get-SkillHash $dest
        if ($curHash -eq $manifest[$_.Name] -or $curHash -eq (Get-SkillHash $_.FullName)) {
            Remove-Item $dest -Recurse -Force
            Write-Host "Skill '$($_.Name)' removed."
        } else {
            Write-Warning "Skill '$($_.Name)' modified locally, keeping it."
        }
    }
    Remove-Item $ManifestPath -Force -ErrorAction SilentlyContinue
    if ((Test-Path $SkillsDir) -and -not (Get-ChildItem $SkillsDir -Force)) {
        Remove-Item $SkillsDir -Force
    }
    Remove-Item (Join-Path $env:USERPROFILE 'vimfiles\autoload\plug.vim') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:USERPROFILE 'vimfiles\plugged') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:USERPROFILE '.vim\plugged') -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Uninstalled. (The rest of ~\.claude was kept.)'
}

function Invoke-Upgrade {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host 'Upgrading winget packages...' -ForegroundColor Yellow
        winget upgrade --id Git.Git -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "winget upgrade Git.Git exited with code $LASTEXITCODE" }
        winget upgrade --id vim.vim -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "winget upgrade vim.vim exited with code $LASTEXITCODE" }
        winget upgrade --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "winget upgrade OpenJS.NodeJS.LTS exited with code $LASTEXITCODE" }
    } else {
        Write-Warning 'winget not found, skipping winget upgrades.'
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host 'Upgrading Chocolatey packages...' -ForegroundColor Yellow
        choco upgrade nvm -y
        if ($LASTEXITCODE -ne 0) { Write-Warning "choco upgrade nvm exited with code $LASTEXITCODE" }
    }
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Host 'Updating Claude Code...' -ForegroundColor Yellow
        claude update
    }
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host 'Updating uv...' -ForegroundColor Yellow
        uv self update
    }
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host 'Updating Codex CLI...' -ForegroundColor Yellow
        npm install -g '@openai/codex'
        if ($LASTEXITCODE -ne 0) { Write-Warning "Codex CLI update exited with code $LASTEXITCODE" }
    }
    Write-Host 'Updating vim plugins...' -ForegroundColor Yellow
    vim +PlugUpdate +qall
    Write-Host 'Upgrade finished. Restart your terminal to apply.' -ForegroundColor Green
}

function Invoke-Install {
    if ($SkipDeps) {
        Write-Warning 'Skipping dependency installation (-SkipDeps)'
    } else {
        Install-Dependencies
    }
    Install-Choco
    Install-Claude
    Install-Uv
    Install-Nvm
    Install-Codex
    Install-NerdFont
    Install-VimPlug
    Copy-Configs
    Write-Host 'Install finished. Restart your terminal to apply.' -ForegroundColor Green
}

switch ($Action) {
    'install'   { Invoke-Install }
    'update'    { Copy-Configs }
    'upgrade'   { Invoke-Upgrade }
    'reinstall' { Remove-Configs; Invoke-Install }
    'uninstall' { Remove-Configs }
}
