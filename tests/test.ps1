# Sandboxed test suite for setup.ps1. Everything runs against a throwaway
# USERPROFILE and a throwaway profile path; the real home is never touched.
# Nothing here needs an elevated shell - that is precisely what it verifies.

$ErrorActionPreference = 'Stop'

$Repo = Split-Path $PSScriptRoot -Parent
$Sandbox = Join-Path ([IO.Path]::GetTempPath()) ("dotfiles-test-" + [guid]::NewGuid().ToString('n'))
$Failures = 0

function Pass([string]$Desc) { Write-Host "  ok  $Desc" }
function Fail([string]$Desc) { Write-Host "FAIL  $Desc" -ForegroundColor Red; $script:Failures++ }

function Assert([string]$Desc, [scriptblock]$Condition) {
    try {
        if (& $Condition) { Pass $Desc } else { Fail $Desc }
    } catch {
        Fail "$Desc (threw: $_)"
    }
}

function Assert-Throws([string]$Desc, [scriptblock]$Action, [string]$Match) {
    try {
        & $Action | Out-Null
        Fail "$Desc (did not throw)"
    } catch {
        if ($_.Exception.Message -match $Match) { Pass $Desc }
        else { Fail "$Desc (message was: $($_.Exception.Message))" }
    }
}

New-Item -ItemType Directory -Force -Path $Sandbox | Out-Null
$Home_ = Join-Path $Sandbox 'home'
New-Item -ItemType Directory -Force -Path $Home_ | Out-Null

# Can this account create symlinks at all? Without Developer Mode or admin it
# cannot, and the skill-link assertions below would be testing Windows, not us.
$CanSymlink = $false
try {
    $probe = Join-Path $Sandbox 'symlink-probe'
    New-Item -ItemType SymbolicLink -Path $probe -Target $Home_ -ErrorAction Stop | Out-Null
    Remove-Item $probe -Force
    $CanSymlink = $true
} catch {
    Write-Warning 'Symbolic links unavailable (no Developer Mode / admin), skipping skill-link assertions.'
}

# Dot-sourcing loads the functions without running an action; USERPROFILE must
# be redirected first because setup.ps1 derives its target paths from it.
$RealUserProfile = $env:USERPROFILE
$env:USERPROFILE = $Home_
try {
    . (Join-Path $Repo 'setup.ps1')
} finally {
    $env:USERPROFILE = $RealUserProfile
}
# MyDocuments ignores USERPROFILE, so point the profile at the sandbox by hand.
$env:USERPROFILE = $Home_
$PwshProfile = Join-Path $Home_ 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
$WinPsProfile = Join-Path $Home_ 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'

try {

    # ---------- Update-SessionPath ----------
    Write-Host 'Update-SessionPath'
    $savedPath = $env:PATH
    $machine = @([Environment]::GetEnvironmentVariable('PATH', 'Machine') -split ';' | Where-Object { $_ })
    $processOnly = Join-Path $Sandbox 'process-only-bin'
    # Start from a known PATH: one process-only directory plus one entry that is
    # already in the registry, so duplication is unambiguous to detect.
    $env:PATH = "$processOnly;$($machine[0])"
    Update-SessionPath
    Assert 'keeps process-only PATH entries' { ($env:PATH -split ';') -contains $processOnly }
    Assert 'imports registry PATH entries' {
        $now = $env:PATH -split ';'
        -not (@($machine | Where-Object { $now -notcontains $_ }))
    }
    Assert 'does not re-add a directory already on PATH' {
        @($env:PATH -split ';' | Where-Object { $_ -eq $machine[0] }).Count -eq 1
    }
    $env:PATH = $savedPath

    # ---------- Enable-SymbolicLinks ----------
    Write-Host 'Enable-SymbolicLinks'
    Assert 'never throws, even unelevated' { Enable-SymbolicLinks 3>$null; $true }

    # ---------- Invoke-Install elevation guard ----------
    Write-Host 'Invoke-Install'
    if (Test-Elevated) {
        Write-Host '  skip  elevation guard (running elevated)'
    } else {
        Assert-Throws 'refuses to install unelevated' { Invoke-Install } 'elevated PowerShell'
    }

    # ---------- Copy-Configs ----------
    Write-Host 'Copy-Configs'
    # Stands in for a generated skill (herdr): it lives in the shared dir without
    # existing in the repo, and must still be linked into the agent dirs.
    $generatedSkill = Join-Path $Home_ '.agents\skills\generated-only'
    New-Item -ItemType Directory -Force -Path $generatedSkill | Out-Null
    Set-Content -Path (Join-Path $generatedSkill 'SKILL.md') -Value '# generated'
    Assert 'runs to completion unelevated' { Copy-Configs 3>$null | Out-Null; $true }
    Assert 'installs _vimrc' { Test-Path (Join-Path $Home_ '_vimrc') }
    Assert 'installs the profile block' {
        (Get-Content $PwshProfile) -contains '# <<< dotfiles managed block <<<'
    }
    Assert 'profile block carries the repo profile' {
        (Get-Content $PwshProfile) -contains '$env:EDITOR = ''vim'''
    }
    Assert 'installs Claude settings' { Test-Path (Join-Path $Home_ '.claude\settings.json') }
    Assert 'installs Codex config' { Test-Path (Join-Path $Home_ '.codex\config.toml') }
    Assert 'installs CLAUDE.md with manifest' {
        (Get-Content (Join-Path $Home_ '.claude\.dotfiles-manifest')) -match '^CLAUDE\.md '
    }
    Assert 'installs shared skills' {
        Test-Path (Join-Path $Home_ '.agents\skills\skill-authoring\SKILL.md')
    }
    if ($CanSymlink) {
        Assert 'links skills into Claude' {
            (Get-Item (Join-Path $Home_ '.claude\skills\skill-authoring') -Force).LinkType -eq 'SymbolicLink'
        }
        Assert 'links skills into Codex' {
            (Get-Item (Join-Path $Home_ '.codex\skills\skill-authoring') -Force).LinkType -eq 'SymbolicLink'
        }
        Assert 'links generated (non-repo) shared skills too' {
            (Get-Item (Join-Path $Home_ '.claude\skills\generated-only') -Force).LinkType -eq 'SymbolicLink'
        }
        Assert 'links the Windows PowerShell 5.1 profile to the pwsh one' {
            $item = Get-Item $WinPsProfile -Force
            $item.LinkType -eq 'SymbolicLink' -and @($item.Target)[0] -eq $PwshProfile
        }
        Assert '5.1 profile serves the same content as the pwsh one' {
            (Get-Content $WinPsProfile -Raw) -eq (Get-Content $PwshProfile -Raw)
        }
    }

    Write-Host 'Copy-Configs (repeat)'
    # Write-Host goes to the information stream; 6>&1 is what captures it.
    $out = Copy-Configs 6>&1 3>&1 | Out-String
    Assert 'second run reports up to date' { $out -match 'up to date' }

    # ---------- managed block keeps user lines ----------
    Write-Host 'Managed block'
    Add-Content $PwshProfile '# my own line'
    Copy-Configs 3>$null | Out-Null
    Assert 'update keeps lines outside the block' {
        (Get-Content $PwshProfile) -contains '# my own line'
    }
    Assert 'update does not duplicate the block' {
        @(Get-Content $PwshProfile | Where-Object { $_ -match '>>> dotfiles managed block' }).Count -eq 1
    }

    # ---------- Invoke-Doctor ----------
    Write-Host 'Invoke-Doctor'
    $doctorOut = ''
    Assert 'reports a healthy profile as installed' {
        $script:doctorOut = Invoke-Doctor 6>&1 | Out-String
        $script:doctorOut -match 'profile contains the dotfiles managed block'
    }
    Assert 'passes the managed-block check after an install' {
        $doctorOut -notmatch 'FIX +profile contains the dotfiles managed block'
    }
    Assert 'returns the problem count as a number' {
        $count = Invoke-Doctor 6>$null
        $count -is [int] -and $count -ge 0
    }

    # ---------- Enable-ProfileExecution ----------
    Write-Host 'Enable-ProfileExecution'
    $policyBefore = Get-ExecutionPolicy
    if ($policyBefore -in 'Restricted', 'AllSigned') {
        # Calling it here would really change the account's policy, so only the
        # guard is exercised; the branch that relaxes it is covered by the FIX
        # line Invoke-Doctor prints in exactly this situation.
        Write-Host '  skip  no-op guard (policy currently blocks scripts)'
        Assert 'doctor flags the blocking execution policy' {
            (Invoke-Doctor 6>&1 | Out-String) -match 'FIX +execution policy'
        }
    } else {
        Assert 'leaves a permitting execution policy untouched' {
            Enable-ProfileExecution 3>$null
            (Get-ExecutionPolicy) -eq $policyBefore
        }
    }

    # ---------- Remove-Configs ----------
    Write-Host 'Remove-Configs'
    # Generated by Install-HerdrSkill rather than copied from the repo, so it is
    # not covered by the manifest and must be removed by name.
    $herdrSkill = Join-Path $Home_ '.agents\skills\herdr'
    New-Item -ItemType Directory -Force -Path $herdrSkill | Out-Null
    Set-Content -Path (Join-Path $herdrSkill 'SKILL.md') -Value '# herdr skill'
    Assert 'runs to completion unelevated' { Remove-Configs 3>$null | Out-Null; $true }
    Assert 'removes the generated herdr skill' { -not (Test-Path $herdrSkill) }
    Assert 'removes the managed block' {
        -not ((Get-Content $PwshProfile) -match '>>> dotfiles managed block')
    }
    Assert 'keeps lines outside the block' { (Get-Content $PwshProfile) -contains '# my own line' }
    Assert 'removes _vimrc' { -not (Test-Path (Join-Path $Home_ '_vimrc')) }
    Assert 'removes Codex config' { -not (Test-Path (Join-Path $Home_ '.codex\config.toml')) }
    Assert 'removes shared skills' {
        -not (Test-Path (Join-Path $Home_ '.agents\skills\skill-authoring'))
    }
    Assert 'removes the 5.1 profile link' { -not (Test-Path $WinPsProfile) }
    Assert 'doctor flags the missing block after uninstall' {
        (Invoke-Doctor 6>&1 | Out-String) -match 'FIX +profile contains the dotfiles managed block'
    }

    Write-Host 'Sync-ProfileLink (user-written 5.1 profile)'
    New-Item -ItemType Directory -Force -Path (Split-Path $WinPsProfile) | Out-Null
    Set-Content -Path $WinPsProfile -Value '# my own 5.1 profile'
    Copy-Configs 3>$null | Out-Null
    Assert 'keeps a user-written 5.1 profile' {
        (Get-Content $WinPsProfile) -contains '# my own 5.1 profile'
    }
    Remove-Item $WinPsProfile -Force

} finally {
    $env:USERPROFILE = $RealUserProfile
    Remove-Item $Sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

if ($Failures -gt 0) {
    Write-Host "$Failures test(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host 'All tests passed.' -ForegroundColor Green
