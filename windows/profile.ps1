# PowerShell 7 profile. Paste into: notepad $PROFILE
# Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
# Mirrors devcon-dotfiles/shell/*.sh so muscle memory carries over from bash.
# Node comes from winget (OpenJS.NodeJS.LTS), so there is no fnm hook here.
# Each tool is only wired up if it's found, so a shell started with a stale
# PATH (e.g. VS Code opened before the winget installs) stays quiet instead of
# printing errors. Restart that app to pick the tools up.
#
# Startup speed: every program launched here is scanned by antivirus, so the
# starship/zoxide init scripts are generated once into ~/.cache/pwsh-init and
# reused; they're regenerated automatically when the tool's exe is updated.
# Delete that folder to force a refresh.

# -CommandType Application: only look at PATH. Without it, a miss makes
# PowerShell search every installed module, which can take seconds.
function Test-Command { param($Name) [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue) }

# Path to a cached init script for $Name, regenerated when the exe is newer
function Get-InitCache {
    param([string]$Name, [scriptblock]$Generate)
    $exe = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) { return $null }
    $cache = Join-Path $HOME ".cache\pwsh-init\$Name.ps1"
    $stale = -not (Test-Path $cache)
    if (-not $stale) { $stale = (Get-Item $exe.Source).LastWriteTime -gt (Get-Item $cache).LastWriteTime }
    if ($stale) {
        New-Item -ItemType Directory -Force -Path (Split-Path $cache) | Out-Null
        & $Generate | Out-File -FilePath $cache -Encoding utf8
    }
    return $cache
}

# Claude Code's installer puts claude.exe here
$localBin = Join-Path $HOME '.local\bin'
if ((Test-Path $localBin) -and (($env:PATH -split ';') -notcontains $localBin)) {
    $env:PATH = "$localBin;$env:PATH"
}

# eza / bat instead of ls / cat (these return text: use Get-ChildItem / Get-Content in pipelines)
if (Test-Command eza) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls   { eza --icons=auto @args }
    function ll   { eza -l --icons=auto --git @args }
    function la   { eza -la --icons=auto --git @args }
    function tree { eza --tree --icons=auto @args }
}
if (Test-Command bat) {
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    function cat { bat --paging=never @args }
}

# fzf lists files with fd; PSFzf gives Ctrl+R history, Ctrl+T files, Alt+C cd
if (Test-Command fd) {
    $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
    $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
    $env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --follow --exclude .git'
}
if (Test-Command fzf) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    if (Get-Module PSFzf) {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
        Set-PSReadLineKeyHandler -Key 'Alt+c' -ScriptBlock { Invoke-FuzzySetLocation }
    }
}

# zoxide: z <dir> jumps, zi picks
$zoxideInit = Get-InitCache zoxide { zoxide init powershell }
if ($zoxideInit) { . $zoxideInit }

# starship last (--print-full-init: the plain init would launch starship a second time)
$starshipInit = Get-InitCache starship { starship init powershell --print-full-init }
if ($starshipInit) { . $starshipInit }
