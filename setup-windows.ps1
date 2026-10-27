#Requires -Version 7.0
<#
.SYNOPSIS
    Windows side of the dev setup. Read README.md first: it lists what to
    install by hand before running this.

.DESCRIPTION
    Run from a normal (NOT administrator) PowerShell 7 window, from the repo:

        pwsh -ExecutionPolicy Bypass -File .\setup-windows.ps1

    Safe to re-run: every step checks before it changes anything, and
    anything it can't do is listed at the end instead of aborting the run.
#>
[CmdletBinding()]
param(
    # Font face Windows Terminal uses. Must be a Nerd Font or prompt icons render as boxes.
    [string]$FontFace = 'JetBrainsMono Nerd Font',
    # Single source of truth for the prompt, shared with the Linux machines.
    [string]$StarshipConfigUrl = 'https://raw.githubusercontent.com/RitvikCS/devcon-dotfiles/main/config/starship.toml'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false  # check $LASTEXITCODE by hand
$RepoRoot = $PSScriptRoot
$Todo = [System.Collections.Generic.List[string]]::new()

function Write-Step { param($m) Write-Host "`n  > $m" -ForegroundColor Cyan }
function Write-Done { param($m) Write-Host "    [OK] $m" -ForegroundColor Green }
function Write-Skip { param($m) Write-Host "    [--] $m" -ForegroundColor DarkGray }
function Write-Info { param($m) Write-Host "    ...  $m" -ForegroundColor Gray }
function Write-Warn { param($m) Write-Host "    [!!] $m" -ForegroundColor Yellow }
function Add-Todo   { param($m) Write-Warn $m; $Todo.Add($m) }

function Update-SessionPath {
    $env:PATH = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# Appends to the user PATH via the registry so existing %VAR% entries stay
# REG_EXPAND_SZ ([Environment]::SetEnvironmentVariable would flatten them and
# break e.g. %USERPROFILE%\AppData\Local\Microsoft\WindowsApps, where winget lives).
function Add-UserPath {
    param([string]$Dir)
    $key = Get-Item 'HKCU:\Environment'
    $raw = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    if (($raw -split ';') -contains $Dir) { return }
    Set-ItemProperty 'HKCU:\Environment' -Name Path -Value (($raw.TrimEnd(';') + ";$Dir").TrimStart(';')) -Type ExpandString
    # Setting any user variable broadcasts WM_SETTINGCHANGE so new terminals pick it up
    [Environment]::SetEnvironmentVariable('WINDOWS_SETUP_PING', '1', 'User')
    [Environment]::SetEnvironmentVariable('WINDOWS_SETUP_PING', $null, 'User')
    Write-Info "added $Dir to your PATH"
}

function Install-WingetPackage {
    param([string]$Id, [string]$Name, [string]$Command)
    Write-Step $Name
    if ($Command -and (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Skip "already installed"; return
    }
    if ((winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String) -match [regex]::Escape($Id)) {
        Write-Skip "already installed"; return
    }
    Write-Info "installing via winget (accept the UAC prompt if one appears)..."
    winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq 0) { Write-Done "installed" }
    else { Add-Todo "$Name failed to install (winget exit $LASTEXITCODE). Retry by hand: winget install --id $Id -e" }
}

# Copies $Content to $Path, keeping a .bak of whatever was there if it differs.
function Write-ManagedFile {
    param([string]$Path, [string]$Content, [string]$Label)
    if ((Test-Path $Path) -and ((Get-Content $Path -Raw) -ceq $Content)) { Write-Skip "$Label up to date"; return }
    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    if (Test-Path $Path) { Copy-Item $Path "$Path.bak" -Force; Write-Info "backed up old $Label to $Path.bak" }
    Set-Content -Path $Path -Value $Content -Encoding utf8NoBOM -NoNewline
    Write-Done "$Label written to $Path"
}

function Set-Prop {
    param($Object, [string]$Name, $Value)
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

Clear-Host
Write-Host "`n  ==========================================" -ForegroundColor Magenta
Write-Host '      Windows Dev Environment Setup' -ForegroundColor Magenta
Write-Host "  ==========================================" -ForegroundColor Magenta

# --- Preflight ----------------------------------------------------------------
Write-Step 'Preflight checks'
if (-not $IsWindows) { throw 'This script is for Windows. Inside WSL run wsl/setup.sh instead.' }

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if ($identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this from a normal (non-administrator) window. Files created elevated in your profile end up owned by Administrators; winget asks for UAC itself when a package needs it.'
}
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    throw "PowerShell is in $($ExecutionContext.SessionState.LanguageMode) mode (set by IT policy). The profile this script installs needs FullLanguage - ask IT before going further."
}
foreach ($cmd in 'winget', 'git') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "$cmd not found. Install the prerequisites in README.md first, then open a NEW terminal and re-run."
    }
}
Write-Done 'non-admin, FullLanguage, winget and git present'

$fontFiles = @("$env:LOCALAPPDATA\Microsoft\Windows\Fonts", "$env:WINDIR\Fonts") |
    ForEach-Object { Get-ChildItem $_ -Filter "$($FontFace -replace ' ', '*')*" -ErrorAction SilentlyContinue }
if ($fontFiles) { Write-Done "$FontFace is installed" }
else { Add-Todo "$FontFace not found - install it (README step 3) or prompt icons will render as boxes" }

# --- Apps -----------------------------------------------------------------------
$packages = @(
    @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal'; Command = 'wt' },
    @{ Id = 'GitHub.cli';                Name = 'GitHub CLI';       Command = 'gh' },
    @{ Id = 'Starship.Starship';         Name = 'Starship prompt';  Command = 'starship' },
    @{ Id = 'OpenJS.NodeJS.LTS';         Name = 'Node.js LTS';      Command = 'node' },
    @{ Id = 'ajeetdsouza.zoxide';        Name = 'zoxide (smarter cd)'; Command = 'zoxide' },
    @{ Id = 'junegunn.fzf';              Name = 'fzf (fuzzy finder)';  Command = 'fzf' },
    @{ Id = 'BurntSushi.ripgrep.MSVC';   Name = 'ripgrep';          Command = 'rg' },
    @{ Id = 'sharkdp.fd';                Name = 'fd (better find)';    Command = 'fd' },
    @{ Id = 'eza-community.eza';         Name = 'eza (better ls)';     Command = 'eza' },
    @{ Id = 'sharkdp.bat';               Name = 'bat (better cat)';    Command = 'bat' },
    @{ Id = 'jqlang.jq';                 Name = 'jq (JSON on the CLI)'; Command = 'jq' }
)
foreach ($p in $packages) { Install-WingetPackage @p }
Update-SessionPath

# PSFzf wires fzf into PSReadLine: Ctrl+R history, Ctrl+T files, Alt+C cd (same keys as bash)
Write-Step 'PSFzf (fzf keybindings for PowerShell)'
if (Get-Module -ListAvailable PSFzf) {
    Write-Skip 'already installed'
} else {
    try {
        Install-Module PSFzf -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop
        Write-Done 'installed'
    } catch {
        Add-Todo "PSFzf install failed ($($_.Exception.Message)) - fzf still works, just without Ctrl+R/Ctrl+T/Alt+C. Retry: Install-Module PSFzf -Scope CurrentUser"
    }
}

# --- Claude Code (native installer, auto-updates) -------------------------------
Write-Step 'Claude Code CLI'
$localBin = Join-Path $HOME '.local\bin'
# Check the native installer's path, not `claude` on PATH: the desktop app may register one too
if (Test-Path (Join-Path $localBin 'claude.exe')) {
    Write-Skip 'already installed'
} else {
    # Child process: the installer may call `exit`, which would end this script too
    & (Join-Path $PSHOME 'pwsh') -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex'
    if ($LASTEXITCODE -eq 0) { Write-Done 'installed (log in later by running: claude)' }
    else { Add-Todo 'Claude Code installer failed - see README troubleshooting (certificate errors usually mean a TLS-inspecting proxy)' }
}
if (Test-Path $localBin) { Add-UserPath $localBin }

# --- Prompt + profile -------------------------------------------------------------
Write-Step 'Starship config (from devcon-dotfiles)'
try {
    $starship = (Invoke-WebRequest $StarshipConfigUrl -UseBasicParsing).Content
    Write-ManagedFile -Path (Join-Path $HOME '.config\starship.toml') -Content $starship -Label 'starship.toml'
} catch {
    Add-Todo "Could not download starship.toml from $StarshipConfigUrl ($($_.Exception.Message))"
}

Write-Step 'PowerShell profile'
$profileTarget = Join-Path $HOME '.config\powershell\profile.ps1'
Write-ManagedFile -Path $profileTarget -Content (Get-Content (Join-Path $RepoRoot 'windows\profile.ps1') -Raw) -Label 'profile.ps1'

$hookLine = ". `"$profileTarget`"  # windows-setup"
$documents = [Environment]::GetFolderPath('MyDocuments')  # follows OneDrive redirection
$hostProfiles = @(
    $PROFILE.CurrentUserCurrentHost,                                            # PowerShell 7
    (Join-Path $documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1') # Windows PowerShell 5.1
)
foreach ($hp in $hostProfiles) {
    if ((Test-Path $hp) -and (Select-String -Path $hp -SimpleMatch '# windows-setup' -Quiet)) { Write-Skip "hooked: $hp"; continue }
    New-Item -ItemType Directory -Force -Path (Split-Path $hp) | Out-Null
    Add-Content -Path $hp -Value "`n$hookLine"
    Write-Done "hooked: $hp"
}

# Windows PowerShell 5.1 defaults to Restricted, which silently skips profiles.
# PowerShell 7 keeps its own policy and already defaults to RemoteSigned.
$ps5Policy = powershell.exe -NoProfile -Command 'Get-ExecutionPolicy' 2>$null
if ($ps5Policy -in 'Restricted', 'Undefined') {
    powershell.exe -NoProfile -Command 'Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force' 2>$null
    $ps5Policy = powershell.exe -NoProfile -Command 'Get-ExecutionPolicy' 2>$null
    if ($ps5Policy -eq 'RemoteSigned') { Write-Done 'Windows PowerShell 5.1 execution policy: RemoteSigned (your user only)' }
    else { Add-Todo "Windows PowerShell 5.1 policy is $ps5Policy (likely set by IT) - its profile won't load; PowerShell 7 is unaffected" }
}

# --- Git + GitHub -------------------------------------------------------------------
Write-Step 'Git identity'
$gitName = git config --global user.name
$gitEmail = git config --global user.email
if ($gitName -and $gitEmail) {
    Write-Skip "$gitName <$gitEmail>"
} else {
    if (-not $gitName) { $gitName = Read-Host '    Full name for commits'; git config --global user.name $gitName }
    if (-not $gitEmail) { $gitEmail = Read-Host '    Default (work) email for commits'; git config --global user.email $gitEmail }
    Write-Done "$gitName <$gitEmail>"
}
if (git config --global --get 'includeIf.gitdir:~/personal/.path') {
    Write-Skip 'personal email for ~/personal/ already configured'
} else {
    $personal = Read-Host '    Personal email for repos under ~/personal/ (Enter to skip)'
    if ($personal) {
        git config --file (Join-Path $HOME '.gitconfig-personal') user.email $personal
        git config --global 'includeIf.gitdir:~/personal/.path' '~/.gitconfig-personal'
        Write-Done "repos under ~/personal/ commit as $personal"
    }
}

Write-Step 'GitHub CLI login'
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh auth status *> $null
    if ($LASTEXITCODE -eq 0) { Write-Skip 'already logged in' }
    else {
        gh auth login
        if ($LASTEXITCODE -eq 0) { Write-Done 'logged in' } else { Add-Todo 'GitHub login did not finish - run: gh auth login' }
    }
} else {
    Add-Todo 'gh missing, skipped GitHub login'
}

# --- Windows Terminal ---------------------------------------------------------------
Write-Step 'Windows Terminal theme + font'
$wtSettings = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $wtSettings) {
    Add-Todo 'Open Windows Terminal once (it creates its settings file), close it, then re-run this script to theme it'
} else {
    $before = Get-Content $wtSettings -Raw
    $settings = $before | ConvertFrom-Json  # PowerShell 7 tolerates the // comments WT writes
    $scheme = Get-Content (Join-Path $RepoRoot 'windows\catppuccin-mocha.json') -Raw | ConvertFrom-Json

    Set-Prop $settings 'schemes' (@($settings.schemes | Where-Object { $_ -and $_.name -ne $scheme.name }) + $scheme)

    if ($settings.profiles -is [array]) {  # legacy flat list
        Set-Prop $settings 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = $settings.profiles })
    }
    if (-not $settings.profiles.defaults) { Set-Prop $settings.profiles 'defaults' ([pscustomobject]@{}) }
    $defaults = $settings.profiles.defaults
    Set-Prop $defaults 'colorScheme' $scheme.name
    if ($defaults.font) { Set-Prop $defaults.font 'face' $FontFace }
    else { Set-Prop $defaults 'font' ([pscustomobject]@{ face = $FontFace }) }

    # Default tab: Ubuntu once WSL exists, otherwise PowerShell 7 rather than 5.1
    $visible = @($settings.profiles.list | Where-Object { -not $_.hidden })
    $preferred = ($visible | Where-Object { $_.name -like 'Ubuntu*' } | Select-Object -First 1)
    if (-not $preferred) { $preferred = ($visible | Where-Object { $_.source -eq 'Windows.Terminal.PowershellCore' } | Select-Object -First 1) }
    if ($preferred) { Set-Prop $settings 'defaultProfile' $preferred.guid }

    $after = $settings | ConvertTo-Json -Depth 32
    if (($before | ConvertFrom-Json | ConvertTo-Json -Depth 32) -ceq $after) {
        Write-Skip 'already themed'
    } else {
        Copy-Item $wtSettings "$wtSettings.bak" -Force
        Set-Content -Path $wtSettings -Value $after -Encoding utf8NoBOM
        Write-Done "Catppuccin Mocha + $FontFace, default tab: $($preferred.name) (old settings: settings.json.bak)"
    }
}

# --- WSL ----------------------------------------------------------------------------
Write-Step 'WSL'
$env:WSL_UTF8 = '1'  # wsl.exe prints UTF-16 otherwise
$distros = @()
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    $distros = @(wsl.exe --list --quiet 2>$null | Where-Object { $_.Trim() })
    if ($LASTEXITCODE -ne 0) { $distros = @() }
}
$wslReady = [bool]($distros -match '^Ubuntu')
if ($wslReady) {
    Write-Done "distros: $($distros -join ', ')"
} else {
    Add-Todo 'WSL/Ubuntu not set up yet. Once IT is OK with it: admin PowerShell -> wsl --install -> reboot -> create your Linux user -> re-run this script (to make Ubuntu the default tab) -> run wsl/setup.sh'
}

$wslConfig = Join-Path $HOME '.wslconfig'
if (Test-Path $wslConfig) {
    Write-Skip "$wslConfig exists, leaving it alone"
} else {
    $vpn = Read-Host '    Do you use a corporate VPN on this laptop? Enables WSL mirrored networking [y/N]'
    $mode = if ($vpn -match '^[yY]') { 'networkingMode=mirrored' } else { '# networkingMode=mirrored   # uncomment if WSL loses internet on VPN, then: wsl --shutdown' }
    Set-Content -Path $wslConfig -Encoding utf8NoBOM -Value @"
# Written by windows-setup. Docs: https://learn.microsoft.com/windows/wsl/wsl-config
[wsl2]
$mode
"@
    Write-Done "wrote $wslConfig"
}

# --- Summary ------------------------------------------------------------------------
Write-Host "`n  ==========================================" -ForegroundColor Green
Write-Host '        Windows setup finished' -ForegroundColor Green
Write-Host "  ==========================================" -ForegroundColor Green
if ($Todo.Count) {
    Write-Host "`n  Still to do:" -ForegroundColor Yellow
    $Todo | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
}
Write-Host "`n  Next:" -ForegroundColor White
Write-Host '    1. Close this window and open a NEW Windows Terminal (PATH + profile changes)' -ForegroundColor Gray
Write-Host '    2. Run: claude   (log in once on Windows)' -ForegroundColor Gray
if ($wslReady) {
    $wslPath = '/mnt/' + $RepoRoot.Substring(0, 1).ToLower() + ($RepoRoot.Substring(2) -replace '\\', '/')
    Write-Host "    3. In Ubuntu run: bash '$wslPath/wsl/setup.sh'" -ForegroundColor Gray
} else {
    Write-Host '    3. Set up WSL (see "Still to do"), then run wsl/setup.sh inside Ubuntu' -ForegroundColor Gray
}
Write-Host ''
