# PowerShell profile, dot-sourced from $PROFILE in both PowerShell 7 and
# Windows PowerShell 5.1. setup-windows.ps1 copies it to
# ~/.config/powershell/profile.ps1 - edit the repo copy and re-run the script.
# Keep this file ASCII-only: 5.1 reads BOM-less files as ANSI.

# Claude Code's native installer puts claude.exe here
$localBin = Join-Path $HOME '.local\bin'
if ((Test-Path $localBin) -and (($env:PATH -split ';') -notcontains $localBin)) {
    $env:PATH = "$localBin;$env:PATH"
}

# fnm: node version per directory (.nvmrc / .node-version), switches on cd
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}

# zoxide: z <dir> jumps, zi picks interactively (uses fzf)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# starship last so nothing below clobbers the prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}
