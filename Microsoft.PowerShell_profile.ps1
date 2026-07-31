# PowerShell 7 profile — Windows counterpart of .zshrc / .bash_profile.
# Every section is a no-op when the tool it configures is not installed.

##############################
#          EXPORTS           #
##############################

$env:EDITOR = 'vim'

# UTF-8 in and out, so non-ASCII output from native tools is not mangled.
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# claude and uv install here; keep in sync with .bash_profile.
$LocalBin = Join-Path $HOME '.local\bin'
if ((Test-Path $LocalBin) -and ($env:PATH -split ';' -notcontains $LocalBin)) {
    $env:PATH = "$LocalBin;$env:PATH"
}

##############################
#         PSREADLINE         #
##############################

if (Get-Module PSReadLine -ListAvailable) {
    Import-Module PSReadLine

    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount 100000
    Set-PSReadLineOption -BellStyle None
    # Predictions need a real terminal; setting them errors out when output is
    # redirected (pwsh -c, editor tasks, CI).
    if (-not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
        # ListView needs PSReadLine 2.2+; older versions only know InlineView.
        if ((Get-Module PSReadLine).Version -ge [version]'2.2.0') {
            Set-PSReadLineOption -PredictionViewStyle ListView
        }
    }

    # Arrow keys search history by what is already typed (zsh-autosuggestions feel).
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
}

##############################
#          ALIASES           #
##############################

# Mirrors the aliases in .bash_profile. PowerShell resolves aliases before
# functions, so the built-in gc/gl/gp/gr aliases must be dropped first.
$GitShortcuts = [ordered]@{
    ga  = 'add'
    gc  = 'commit'
    gp  = 'push'
    gl  = 'pull'
    gr  = 'reset'
    grh = 'reset --hard'
}
foreach ($name in $GitShortcuts.Keys) {
    if (Test-Path "Alias:$name") { Remove-Item "Alias:$name" -Force }
    Set-Item "Function:global:$name" ([scriptblock]::Create("git $($GitShortcuts[$name]) `@args"))
}
Remove-Variable GitShortcuts, name

function l { Get-ChildItem -Force @args }
function ptt { ssh bbsu@ptt.cc }
function which { (Get-Command @args -ErrorAction SilentlyContinue).Source }

##############################
#           PROMPT           #
##############################

if (Get-Module posh-git -ListAvailable) {
    Import-Module posh-git
}

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $Theme = Join-Path $env:POSH_THEMES_PATH 'clean-detailed.omp.json'
    if (Test-Path $Theme) {
        oh-my-posh init pwsh --config $Theme | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
    Remove-Variable Theme
}
