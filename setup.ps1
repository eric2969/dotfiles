<#
.SYNOPSIS
    Windows installer for these dotfiles.
.DESCRIPTION
    install   - install dependencies (git, vim), Nerd Font, vim-plug, then copy configs
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

function Copy-Configs {
    Write-Host 'Copying configs...' -ForegroundColor Yellow
    Copy-Item (Join-Path $RepoRoot '.vimrc') (Join-Path $env:USERPROFILE '_vimrc') -Force
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    Copy-Item (Join-Path $RepoRoot '.claude\settings.json') $ClaudeDir -Force
    Copy-Item (Join-Path $RepoRoot '.claude\CLAUDE.md') $ClaudeDir -Force
    Copy-Item (Join-Path $RepoRoot '.claude\skills') $ClaudeDir -Recurse -Force
    Write-Host 'Configs updated.'
}

function Remove-Configs {
    Write-Host 'Removing installed configs...' -ForegroundColor Yellow
    Remove-Item (Join-Path $env:USERPROFILE '_vimrc') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $ClaudeDir 'settings.json') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $ClaudeDir 'CLAUDE.md') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $ClaudeDir 'skills') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:USERPROFILE 'vimfiles\autoload\plug.vim') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:USERPROFILE 'vimfiles\plugged') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:USERPROFILE '.vim\plugged') -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Uninstalled. (The rest of ~\.claude was kept.)'
}

switch ($Action) {
    'install' {
        Install-Dependencies
        Install-NerdFont
        Install-VimPlug
        Copy-Configs
        Write-Host 'Install finished. Restart your terminal to apply.' -ForegroundColor Green
    }
    'update'    { Copy-Configs }
    'uninstall' { Remove-Configs }
}
