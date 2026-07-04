<#
.SYNOPSIS
    Windows installer for these dotfiles.
.DESCRIPTION
    install   - install dependencies (git, vim, choco, claude, uv, nvm), Nerd Font, vim-plug, then copy configs
    update    - copy configs only
    uninstall - remove configs installed by this script
#>
param(
    [ValidateSet('install', 'update', 'uninstall')]
    [string]$Action = 'install'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'

function Install-Dependencies {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget not found. Install "App Installer" from the Microsoft Store first.'
    }
    Write-Host 'Installing dependencies via winget...' -ForegroundColor Yellow
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install Git.Git exited with code $LASTEXITCODE" }
    winget install --id vim.vim -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install vim.vim exited with code $LASTEXITCODE" }
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

function Copy-Skills {
    # Install each skill only if not already present, so local edits are kept.
    $skillsDir = Join-Path $ClaudeDir 'skills'
    New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
    Get-ChildItem (Join-Path $RepoRoot '.claude\skills') -Directory | ForEach-Object {
        $dest = Join-Path $skillsDir $_.Name
        if (Test-Path $dest) {
            Write-Host "Skill '$($_.Name)' already installed, skipping."
        } else {
            Copy-Item $_.FullName $dest -Recurse
            Write-Host "Skill '$($_.Name)' installed."
        }
    }
}

function Copy-Configs {
    Write-Host 'Copying configs...' -ForegroundColor Yellow
    Copy-Item (Join-Path $RepoRoot '.vimrc') (Join-Path $env:USERPROFILE '_vimrc') -Force
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    Copy-Item (Join-Path $RepoRoot '.claude\settings.json') $ClaudeDir -Force
    Copy-Item (Join-Path $RepoRoot '.claude\CLAUDE.md') $ClaudeDir -Force
    Copy-Skills
    Write-Host 'Configs updated.'
}

function Remove-Configs {
    Write-Host 'Removing installed configs...' -ForegroundColor Yellow
    Remove-Item (Join-Path $env:USERPROFILE '_vimrc') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $ClaudeDir 'settings.json') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $ClaudeDir 'CLAUDE.md') -Force -ErrorAction SilentlyContinue
    # Only remove skills managed by this repo; keep user-authored skills.
    Get-ChildItem (Join-Path $RepoRoot '.claude\skills') -Directory | ForEach-Object {
        Remove-Item (Join-Path $ClaudeDir "skills\$($_.Name)") -Recurse -Force -ErrorAction SilentlyContinue
    }
    $skillsDir = Join-Path $ClaudeDir 'skills'
    if ((Test-Path $skillsDir) -and -not (Get-ChildItem $skillsDir)) {
        Remove-Item $skillsDir -Force
    }
    Remove-Item (Join-Path $env:USERPROFILE 'vimfiles\autoload\plug.vim') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:USERPROFILE 'vimfiles\plugged') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:USERPROFILE '.vim\plugged') -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Uninstalled. (The rest of ~\.claude was kept.)'
}

switch ($Action) {
    'install' {
        Install-Dependencies
        Install-Choco
        Install-Claude
        Install-Uv
        Install-Nvm
        Install-NerdFont
        Install-VimPlug
        Copy-Configs
        Write-Host 'Install finished. Restart your terminal to apply.' -ForegroundColor Green
    }
    'update'    { Copy-Configs }
    'uninstall' { Remove-Configs }
}
