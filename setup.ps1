<#
.SYNOPSIS
    Windows installer for these dotfiles.
.DESCRIPTION
    install   - install dependencies (git, vim, choco, claude, codex, herdr, uv, nvm + Node LTS), Nerd Font, vim-plug, then copy configs
    update    - copy configs only
    upgrade   - upgrade installed packages and tools (winget, choco, claude, codex, herdr, uv, PowerShell modules for 7 and 5.1, vim plugins)
    reinstall - remove installed configs, then install fresh (uninstall + install)
    uninstall - remove configs installed by this script
    doctor    - report why the PowerShell prompt is not showing up (read-only)

    Node.js is owned by nvm-windows, mirroring setup.sh on Unix; nothing here
    installs Node through winget, because a second Node would shadow nvm's.

    'install' and 'reinstall' need an elevated shell (Chocolatey and nvm-windows
    install machine-wide). The other actions run fine as a normal user.
#>
param(
    [ValidateSet('install', 'update', 'upgrade', 'reinstall', 'uninstall', 'doctor')]
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
# PowerShell 7 profile, resolved via MyDocuments so OneDrive-redirected
# Documents folders are handled. Always the pwsh path, even when setup.ps1
# itself runs under Windows PowerShell 5.1.
$PwshProfile = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'
# Windows PowerShell 5.1 reads its own profile path and never sees the one
# above. It is symlinked to the pwsh profile so anything that still starts 5.1
# — herdr's fallback shell, older launchers — gets the same prompt and aliases.
$WinPsProfile = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'

function Test-Elevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Installers write PATH to the registry, which the running process never sees.
# Merge the registry entries in instead of replacing $env:PATH, so directories
# that only exist in this process (a just-run installer's own additions) survive.
function Update-SessionPath {
    $dirs = @($env:PATH -split ';' | Where-Object { $_ })
    foreach ($scope in 'Machine', 'User') {
        foreach ($dir in ([Environment]::GetEnvironmentVariable('PATH', $scope) -split ';')) {
            if ($dir -and $dirs -notcontains $dir) { $dirs += $dir }
        }
    }
    $env:PATH = $dirs -join ';'
}

function Install-Dependencies {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget not found. Install "App Installer" from the Microsoft Store first.'
    }
    Write-Host 'Installing dependencies via winget...' -ForegroundColor Yellow
    # PowerShell 7 first: the profile is installed into its Documents\PowerShell
    # folder, so on a machine with only Windows PowerShell 5.1 nothing would ever
    # read the file this script writes.
    winget install --id Microsoft.PowerShell -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install Microsoft.PowerShell exited with code $LASTEXITCODE" }
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install Git.Git exited with code $LASTEXITCODE" }
    winget install --id vim.vim -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install vim.vim exited with code $LASTEXITCODE" }
    winget install --id JanDeDobbeleer.OhMyPosh -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install JanDeDobbeleer.OhMyPosh exited with code $LASTEXITCODE" }
    Update-SessionPath
}

# Modules the profile prompt and line editor rely on; both degrade gracefully
# when missing, so a failed install is a warning rather than a hard error.
function Install-PsModules {
    foreach ($module in 'posh-git', 'PSReadLine') {
        if (Get-Module $module -ListAvailable) {
            Write-Host "PowerShell module '$module' already installed."
            continue
        }
        Write-Host "Installing PowerShell module '$module'..." -ForegroundColor Yellow
        try {
            Install-Module $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        } catch {
            Write-Warning "Install-Module $module failed: $_"
        }
    }
}

# The same two modules for Windows PowerShell 5.1, which has its own module path
# and therefore cannot see anything installed for pwsh. Now that both editions
# share one profile, 5.1 would otherwise sit on the in-box PSReadLine 2.0.0 (no
# predictions) with no posh-git at all.
function Install-WinPsModules([switch]$Update) {
    $winPs = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path $winPs)) {
        Write-Warning 'Windows PowerShell 5.1 not found, skipping its modules.'
        return
    }
    # Literal here-string: everything below is evaluated by 5.1, not by us.
    $script = @'
$ErrorActionPreference = 'Continue'
# 5.1 negotiates TLS 1.0 by default; the PowerShell Gallery rejects it.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null
}
# PSReadLine ships in-box at 2.0.0, so "is it installed" is a version question:
# -PredictionSource needs 2.1+. posh-git is absent entirely, any version will do.
$wanted = [ordered]@{ 'posh-git' = [version]'0.0'; 'PSReadLine' = [version]'2.1.0' }
foreach ($module in $wanted.Keys) {
    $have = Get-Module $module -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if ($have -and $have.Version -ge $wanted[$module]) {
        if (-not $DoUpdate) {
            Write-Host "PowerShell 5.1 module '$module' already installed ($($have.Version))."
            continue
        }
        Write-Host "Updating PowerShell 5.1 module '$module'..."
        try { Update-Module $module -Force -ErrorAction Stop }
        catch { Write-Warning "Update-Module $module (5.1) failed: $_" }
        continue
    }
    Write-Host "Installing PowerShell 5.1 module '$module'..."
    try {
        # The in-box PSReadLine is signed by a different publisher than the
        # gallery build, which blocks the side-by-side install without this.
        Install-Module $module -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
    } catch {
        Write-Warning "Install-Module $module (5.1) failed: $_"
    }
}
'@
    $prelude = "`$DoUpdate = `$$($Update.IsPresent)"
    & $winPs -NoProfile -ExecutionPolicy Bypass -Command "$prelude`n$script"
}

function Install-Choco {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host 'Chocolatey already installed.'
        return
    }
    if (-not (Test-Elevated)) {
        Write-Warning 'Chocolatey needs an elevated shell, skipping. Re-run setup.ps1 as Administrator to install it.'
        return
    }
    Write-Host 'Installing Chocolatey...' -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    # The installer only puts choco on the registry PATH; without this the very
    # next step (Install-Nvm) would not find the command it just installed.
    Update-SessionPath
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
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Warning 'Chocolatey not available, skipping nvm-windows.'
        return
    }
    Write-Host 'Installing nvm-windows via Chocolatey...' -ForegroundColor Yellow
    choco install nvm -y
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "choco install nvm exited with code $LASTEXITCODE"
        return
    }
    # nvm-windows drives Node through NVM_HOME / NVM_SYMLINK, which the installer
    # writes to the registry only; import them so Install-Codex can use nvm now.
    foreach ($name in 'NVM_HOME', 'NVM_SYMLINK') {
        $value = [Environment]::GetEnvironmentVariable($name, 'Machine')
        if ($value) { Set-Item "Env:$name" $value }
    }
    Update-SessionPath
}

# Mirrors install_codex in setup.sh: nvm provides Node, Node provides npm,
# npm provides Codex. A missing link is a warning, never a failed install.
function Install-Codex {
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        Write-Host 'Codex CLI already installed.'
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
            Write-Warning 'Neither npm nor nvm found, skipping Codex CLI.'
            return
        }
        Write-Host 'Installing Node.js LTS via nvm...' -ForegroundColor Yellow
        nvm install lts
        if ($LASTEXITCODE -ne 0) { Write-Warning "nvm install lts exited with code $LASTEXITCODE" }
        nvm use lts
        if ($LASTEXITCODE -ne 0) { Write-Warning "nvm use lts exited with code $LASTEXITCODE" }
        Update-SessionPath
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Write-Warning 'npm still not on PATH, skipping Codex CLI. Restart the terminal and re-run setup.ps1.'
            return
        }
    }
    Write-Host 'Installing Codex CLI...' -ForegroundColor Yellow
    npm install -g '@openai/codex'
    if ($LASTEXITCODE -ne 0) { Write-Warning "npm install @openai/codex exited with code $LASTEXITCODE" }
}

function Install-Herdr {
    if (Get-Command herdr -ErrorAction SilentlyContinue) {
        Write-Host 'herdr already installed.'
        return
    }
    Write-Host 'Installing herdr...' -ForegroundColor Yellow
    Invoke-RestMethod https://herdr.dev/install.ps1 | Invoke-Expression
    # The installer only writes PATH to the registry; import it so the agent
    # skill can be generated in this same run.
    Update-SessionPath
}

# Developer Mode lets non-elevated processes create the skill symlinks. Writing
# it needs admin, so this only reports the problem: it must never take the whole
# config copy down with it, and it is a no-op once the value is already set.
function Enable-SymbolicLinks {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    $name = 'AllowDevelopmentWithoutDevLicense'
    if ((Get-ItemProperty $key -Name $name -ErrorAction SilentlyContinue).$name -eq 1) {
        Write-Host 'Windows Developer Mode already enabled.'
        return
    }
    Write-Host 'Enabling Windows Developer Mode for symbolic links...' -ForegroundColor Yellow
    try {
        New-Item -Path $key -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -Path $key -Name $name -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Could not enable Developer Mode ($_). Skill symlinks may fail; re-run setup.ps1 as Administrator."
    }
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

# herdr ships an agent skill matched to the installed binary, so it is generated
# instead of vendored. Writing it into the shared skills dir lets Sync-SkillLinks
# expose it to Claude and Codex like every other skill.
function Install-HerdrSkill {
    # herdr's installer writes PATH to the registry only, so a shell started
    # before the install (or by 'update' on its own) would not see the binary.
    Update-SessionPath
    $herdr = Get-Command herdr -ErrorAction SilentlyContinue
    if (-not $herdr) {
        Write-Host 'herdr not installed, skipping its agent skill.'
        return
    }
    $skill = & $herdr.Source --skill 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $skill) {
        Write-Warning 'herdr --skill failed, skipping its agent skill.'
        return
    }
    $dir = Join-Path $SkillsDir 'herdr'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Set-Content -Path (Join-Path $dir 'SKILL.md') -Value $skill
    Write-Host "Skill 'herdr' synced from the installed binary."
}

function Sync-SkillLinks([string]$TargetRoot) {
    New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
    $linkManifest = Join-Path $TargetRoot '.dotfiles-links'
    $managed = @()
    if (Test-Path $linkManifest) { $managed = @(Get-Content $linkManifest) }

    # Linked from the installed shared dir, not from the repo, so generated
    # skills (herdr) are covered too — this is what skill-links.sh does on Unix.
    Get-ChildItem $SkillsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
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
    $sharedNames = @(Get-ChildItem $SkillsDir -Directory -ErrorAction SilentlyContinue).Name
    @($managed) | Where-Object { $sharedNames -notcontains $_ } | ForEach-Object {
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

# Managed-block policy for the PowerShell profile, mirroring rcblock.sh on Unix:
# only the marked region belongs to the repo, anything the user adds is kept.
$BlockBegin = '# >>> dotfiles managed block - do not edit, "setup.ps1 -Action update" rewrites it >>>'
$BlockEnd = '# <<< dotfiles managed block <<<'

function Install-RcBlock([string]$Source, [string]$Dest) {
    $block = @($BlockBegin) + (Get-Content $Source) + @($BlockEnd)
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null

    if (-not (Test-Path $Dest)) {
        Set-Content $Dest $block
        Write-Host "Profile '$(Split-Path $Dest -Leaf)' installed."
        return
    }

    $lines = @(Get-Content $Dest)
    $begin = [array]::IndexOf($lines, $BlockBegin)
    if ($begin -ge 0) {
        $end = [array]::IndexOf($lines, $BlockEnd, $begin)
        if ($end -lt 0) { throw "Unterminated dotfiles block in $Dest" }
        # Replace in place so the block keeps its position in the file.
        $head = if ($begin -gt 0) { $lines[0..($begin - 1)] } else { @() }
        $lines = @($head) + $block + @($lines | Select-Object -Skip ($end + 1))
    } else {
        $lines = $lines + @('') + $block
    }
    Set-Content $Dest $lines
    Write-Host "Profile '$(Split-Path $Dest -Leaf)' updated."
}

function Remove-RcBlock([string]$Dest) {
    if (-not (Test-Path $Dest)) { return }
    $lines = @(Get-Content $Dest)
    $begin = [array]::IndexOf($lines, $BlockBegin)
    if ($begin -lt 0) { return }
    $end = [array]::IndexOf($lines, $BlockEnd, $begin)
    if ($end -lt 0) { throw "Unterminated dotfiles block in $Dest" }
    $head = if ($begin -gt 0) { $lines[0..($begin - 1)] } else { @() }
    $kept = @($head) + @($lines | Select-Object -Skip ($end + 1))
    if ($kept -match '\S') {
        Set-Content $Dest $kept
        Write-Host "Profile block removed from '$(Split-Path $Dest -Leaf)'."
    } else {
        Remove-Item $Dest -Force
        Write-Host "Profile '$(Split-Path $Dest -Leaf)' removed."
    }
}

# Point the Windows PowerShell 5.1 profile at the pwsh one, the same policy the
# skill links get: a symlink we own is refreshed, a real file the user wrote is
# never touched. The managed block still lives in a single file, so 5.1 and 7
# cannot drift apart.
function Sync-ProfileLink {
    if (-not (Test-Path $PwshProfile)) { return }
    if (Test-Path $WinPsProfile) {
        $item = Get-Item $WinPsProfile -Force
        if ($item.LinkType -eq 'SymbolicLink' -and @($item.Target)[0] -eq $PwshProfile) {
            Write-Host 'Windows PowerShell 5.1 profile link up to date.'
            return
        }
        if ($item.LinkType -eq 'SymbolicLink' -and $Force) {
            Remove-Item $WinPsProfile -Force
        } else {
            Write-Warning "A Windows PowerShell 5.1 profile already exists at $WinPsProfile, keeping it (use -Force to replace it with the link)."
            return
        }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $WinPsProfile) | Out-Null
    try {
        New-Item -ItemType SymbolicLink -Path $WinPsProfile -Target $PwshProfile -ErrorAction Stop | Out-Null
        Write-Host 'Windows PowerShell 5.1 profile linked to the pwsh profile.'
    } catch {
        Write-Warning "Could not link the Windows PowerShell 5.1 profile ($_). Enable Developer Mode or re-run as Administrator."
    }
}

function Remove-ProfileLink {
    if (-not (Test-Path $WinPsProfile)) { return }
    $item = Get-Item $WinPsProfile -Force
    if ($item.LinkType -eq 'SymbolicLink' -and @($item.Target)[0] -eq $PwshProfile) {
        Remove-Item $WinPsProfile -Force
        Write-Host 'Windows PowerShell 5.1 profile link removed.'
    } else {
        Write-Warning "The Windows PowerShell 5.1 profile at $WinPsProfile is not our link, keeping it."
    }
}

# A Restricted or AllSigned policy makes PowerShell skip the profile without a
# word, which looks exactly like "the prompt config did nothing". Only the
# CurrentUser scope is touched, so this needs no elevation.
function Enable-ProfileExecution {
    if ((Get-ExecutionPolicy) -notin 'Restricted', 'AllSigned') { return }
    Write-Host 'Allowing local scripts to run (ExecutionPolicy RemoteSigned, current user)...' -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
    } catch {
        Write-Warning "Could not relax the execution policy ($_). The profile will not load until it is set to RemoteSigned."
    }
}

# Read-only report for the one failure this script cannot fix from here: the
# profile is on disk but the shell never loads it. Returns the problem count.
function Invoke-Doctor {
    Write-Host 'PowerShell profile checkup' -ForegroundColor Yellow

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    $onDisk = Test-Path $PwshProfile
    $policy = Get-ExecutionPolicy
    $fonts = @(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter 'SauceCodePro*.ttf' -ErrorAction SilentlyContinue) +
             @(Get-ChildItem "$env:windir\Fonts" -Filter 'SauceCodePro*.ttf' -ErrorAction SilentlyContinue)

    $checks = @(
        [pscustomobject]@{
            Ok      = [bool]$pwsh
            Message = "PowerShell 7 installed$(if ($pwsh) { " ($($pwsh.Source))" })"
            Fix     = 'winget install --id Microsoft.PowerShell -e, then open the "PowerShell" (not "Windows PowerShell") terminal'
        }
        [pscustomobject]@{
            Ok      = $PSVersionTable.PSEdition -eq 'Core'
            Message = "this shell is PowerShell 7 (running $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion))"
            Fix     = 'not fatal: 5.1 shares this profile through the link checked below, but PSReadLine predictions need pwsh 7'
        }
        [pscustomobject]@{
            Ok      = (Test-Path $WinPsProfile) -and (Get-Item $WinPsProfile -Force).LinkType -eq 'SymbolicLink'
            Message = "Windows PowerShell 5.1 profile links to the pwsh one ($WinPsProfile)"
            Fix     = 'run: .\setup.ps1 -Action update (creating the link needs Developer Mode or admin)'
        }
        [pscustomobject]@{
            Ok      = $onDisk
            Message = "profile file exists ($PwshProfile)"
            Fix     = 'run: .\setup.ps1 -Action update'
        }
        [pscustomobject]@{
            Ok      = $onDisk -and ((Get-Content $PwshProfile) -contains $BlockBegin)
            Message = 'profile contains the dotfiles managed block'
            Fix     = 'run: .\setup.ps1 -Action update'
        }
        [pscustomobject]@{
            Ok      = $policy -notin 'Restricted', 'AllSigned'
            Message = "execution policy allows the profile to run (is: $policy)"
            Fix     = 'run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser'
        }
        [pscustomobject]@{
            Ok      = [bool](Get-Command oh-my-posh -ErrorAction SilentlyContinue)
            Message = 'oh-my-posh installed'
            Fix     = 'winget install --id JanDeDobbeleer.OhMyPosh -e, then restart the terminal'
        }
        [pscustomobject]@{
            Ok      = $fonts.Count -gt 0
            Message = 'SauceCodePro Nerd Font installed'
            Fix     = 'run install again, then set the terminal font to "SauceCodePro Nerd Font" or the prompt icons stay as empty boxes'
        }
    )

    foreach ($check in $checks) {
        if ($check.Ok) {
            Write-Host "  ok    $($check.Message)"
        } else {
            Write-Host "  FIX   $($check.Message)" -ForegroundColor Red
            Write-Host "        -> $($check.Fix)"
        }
    }

    $problems = @($checks | Where-Object { -not $_.Ok }).Count
    if ($problems -eq 0) {
        Write-Host 'No problems found. Open a new PowerShell 7 tab to see the prompt.' -ForegroundColor Green
    } else {
        Write-Host "$problems problem(s) found; fix the lines marked FIX above." -ForegroundColor Red
    }
    $problems
}

function Copy-Configs {
    Write-Host 'Copying configs...' -ForegroundColor Yellow
    Enable-ProfileExecution
    Copy-Item (Join-Path $RepoRoot '.vimrc') (Join-Path $env:USERPROFILE '_vimrc') -Force
    Install-RcBlock (Join-Path $RepoRoot 'Microsoft.PowerShell_profile.ps1') $PwshProfile
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    Copy-Item (Join-Path $RepoRoot '.claude\settings.json') $ClaudeDir -Force
    New-Item -ItemType Directory -Force -Path $CodexDir | Out-Null
    Copy-Item (Join-Path $RepoRoot '.codex\config.toml') $CodexDir -Force
    Install-ManagedFile (Join-Path $RepoRoot '.claude\CLAUDE.md') (Join-Path $ClaudeDir 'CLAUDE.md')
    Copy-Skills
    Install-HerdrSkill
    Remove-LegacyClaudeSkillCopies
    # Only the symlinks below need Developer Mode, so everything above is already
    # on disk even when this cannot be enabled.
    Enable-SymbolicLinks
    Sync-ProfileLink
    Sync-SkillLinks (Join-Path $ClaudeDir 'skills')
    Sync-SkillLinks (Join-Path $CodexDir 'skills')
    Write-Host 'Configs updated.'
}

function Remove-Configs {
    Write-Host 'Removing installed configs...' -ForegroundColor Yellow
    Remove-Item (Join-Path $env:USERPROFILE '_vimrc') -Force -ErrorAction SilentlyContinue
    Remove-ProfileLink
    Remove-RcBlock $PwshProfile
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
    # Generated by Install-HerdrSkill rather than copied from the repo, so the
    # manifest never covers it; remove it by name.
    $herdrSkill = Join-Path $SkillsDir 'herdr'
    if (Test-Path $herdrSkill) {
        Remove-Item $herdrSkill -Recurse -Force
        Write-Host "Skill 'herdr' removed."
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
        winget upgrade --id Microsoft.PowerShell -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "winget upgrade Microsoft.PowerShell exited with code $LASTEXITCODE" }
        winget upgrade --id Git.Git -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "winget upgrade Git.Git exited with code $LASTEXITCODE" }
        winget upgrade --id vim.vim -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "winget upgrade vim.vim exited with code $LASTEXITCODE" }
        winget upgrade --id JanDeDobbeleer.OhMyPosh -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "winget upgrade JanDeDobbeleer.OhMyPosh exited with code $LASTEXITCODE" }
    } else {
        Write-Warning 'winget not found, skipping winget upgrades.'
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        if (Test-Elevated) {
            Write-Host 'Upgrading Chocolatey packages...' -ForegroundColor Yellow
            choco upgrade nvm -y
            if ($LASTEXITCODE -ne 0) { Write-Warning "choco upgrade nvm exited with code $LASTEXITCODE" }
        } else {
            Write-Warning 'Chocolatey upgrades need an elevated shell, skipping nvm.'
        }
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
    if (Get-Command herdr -ErrorAction SilentlyContinue) {
        Write-Host 'Updating herdr...' -ForegroundColor Yellow
        herdr update
        if ($LASTEXITCODE -ne 0) { Write-Warning "herdr update exited with code $LASTEXITCODE" }
        Install-HerdrSkill
    }
    Write-Host 'Updating PowerShell modules...' -ForegroundColor Yellow
    foreach ($module in 'posh-git', 'PSReadLine') {
        if (-not (Get-Module $module -ListAvailable)) { continue }
        try {
            Update-Module $module -Force -ErrorAction Stop
        } catch {
            Write-Warning "Update-Module $module failed: $_"
        }
    }
    Write-Host 'Updating Windows PowerShell 5.1 modules...' -ForegroundColor Yellow
    Install-WinPsModules -Update
    Write-Host 'Updating vim plugins...' -ForegroundColor Yellow
    vim +PlugUpdate +qall
    Write-Host 'Upgrade finished. Restart your terminal to apply.' -ForegroundColor Green
}

function Invoke-Install {
    if (-not (Test-Elevated)) {
        throw 'Run install from an elevated PowerShell (Chocolatey, nvm-windows and Developer Mode need admin). Use "setup.ps1 -Action update" to copy configs only.'
    }
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
    Install-Herdr
    Install-PsModules
    Install-WinPsModules
    Install-NerdFont
    Install-VimPlug
    Copy-Configs
    Write-Host 'Install finished. Open a new PowerShell 7 ("pwsh") tab to apply.' -ForegroundColor Green
    Write-Host 'If the prompt still looks plain, run: .\setup.ps1 -Action doctor' -ForegroundColor Green
}

# Dot-sourcing loads the functions without running anything, which is how
# tests/test.ps1 exercises them against a sandbox HOME.
if ($MyInvocation.InvocationName -ne '.') {
    switch ($Action) {
        'install'   { Invoke-Install }
        'update'    { Copy-Configs }
        'upgrade'   { Invoke-Upgrade }
        'reinstall' { Remove-Configs; Invoke-Install }
        'uninstall' { Remove-Configs }
        'doctor'    { Invoke-Doctor | Out-Null }
    }
}
