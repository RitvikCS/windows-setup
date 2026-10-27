# PowerShell 7 profile. Paste into: notepad $PROFILE
# Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
# Mirrors devcon-dotfiles/shell/*.sh so muscle memory carries over from bash.
# Node comes from winget (OpenJS.NodeJS.LTS), so there is no fnm hook here.
# Each tool is only wired up if it's found, so a shell started with a stale
# PATH (e.g. VS Code opened before the winget installs) stays quiet instead of
# printing errors. Restart that app to pick the tools up.

function Test-Command { param($Name) [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

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
if ((Test-Command fzf) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Set-PSReadLineKeyHandler -Key 'Alt+c' -ScriptBlock { Invoke-FuzzySetLocation }
}

# zoxide: z <dir> jumps, zi picks
if (Test-Command zoxide) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# starship last
if (Test-Command starship) {
    Invoke-Expression (& starship init powershell)
}
