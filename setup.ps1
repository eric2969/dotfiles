<#
.SYNOPSIS
    Windows installer for these dotfiles.
.DESCRIPTION
    install   - install dependencies (git, vim, choco, claude, uv, nvm), Nerd Font, vim-plug, then copy configs
    update    - copy configs only
    reinstall - remove installed configs, then install fresh (uninstall + install)
    uninstall - remove configs installed by this script
#>
param(
    [ValidateSet('install', 'update', 'reinstall', 'uninstall')]
    [string]$Action = 'install',
    # Overwrite locally modified skills on update (mirrors FORCE=1 for make).
    [switch]$Force,
    # Skip winget dependency installation (mirrors setup.sh -n).
    [switch]$SkipDeps
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

# A content-hash manifest tells apart "user modified the installed copy" (kept)
# from "installed copy is just an older repo version" (updated).
$SkillsDir = Join-Path $ClaudeDir 'skills'
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

function Get-Manifest {
    $manifest = @{}
    if (Test-Path $ManifestPath) {
        Get-Content $ManifestPath | ForEach-Object {
            $parts = $_ -split ' ', 2
            if ($parts.Count -eq 2) { $manifest[$parts[0]] = $parts[1] }
        }
    }
    $manifest
}

function Save-Manifest($Manifest) {
    $Manifest.GetEnumerator() | Sort-Object Key |
        ForEach-Object { "$($_.Key) $($_.Value)" } | Set-Content $ManifestPath
}

function Copy-Skills {
    New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
    $manifest = Get-Manifest
    Get-ChildItem (Join-Path $RepoRoot '.claude\skills') -Directory | ForEach-Object {
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
    Save-Manifest $manifest
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
    # Only remove repo-managed skills; keep user-authored or user-modified ones.
    $manifest = Get-Manifest
    Get-ChildItem (Join-Path $RepoRoot '.claude\skills') -Directory | ForEach-Object {
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
    Install-NerdFont
    Install-VimPlug
    Copy-Configs
    Write-Host 'Install finished. Restart your terminal to apply.' -ForegroundColor Green
}

switch ($Action) {
    'install'   { Invoke-Install }
    'update'    { Copy-Configs }
    'reinstall' { Remove-Configs; Invoke-Install }
    'uninstall' { Remove-Configs }
}
