# setup-windows.ps1
# Run with: powershell -ExecutionPolicy Bypass -File setup-windows.ps1

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor Magenta
    Write-Host "      Windows Dev Environment Setup" -ForegroundColor Magenta
    Write-Host "  ==========================================" -ForegroundColor Magenta
    Write-Host ""
}

function Write-Step   { param($msg) Write-Host "`n  > $msg" -ForegroundColor Cyan }
function Write-Done   { param($msg) Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Skip   { param($msg) Write-Host "    [--] $msg (already done)" -ForegroundColor Yellow }
function Write-Info   { param($msg) Write-Host "    ... $msg" -ForegroundColor Gray }
function Write-Fail   { param($msg) Write-Host "    [!!] $msg" -ForegroundColor Red; exit 1 }

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

function Is-Installed { param($id)
    $result = winget list --id $id --exact 2>$null | Select-String $id
    return $null -ne $result
}

Write-Header

# winget check
Write-Step "Checking winget..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}
Write-Done "winget is available"

# Packages via winget
$packages = @(
    @{ Id = "Git.Git";    Name = "Git"                        },
    @{ Id = "GitHub.cli"; Name = "GitHub CLI (gh)"            },
    @{ Id = "wez.wezterm"; Name = "WezTerm"                   },
    @{ Id = "Schniz.fnm"; Name = "fnm (Node Version Manager)" }
)

foreach ($pkg in $packages) {
    Write-Step "Checking $($pkg.Name)..."
    if (Is-Installed $pkg.Id) {
        Write-Skip "$($pkg.Name) is already installed"
    } else {
        Write-Info "Installing $($pkg.Name) via winget..."
        winget install --id $pkg.Id --exact --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Fail "Failed to install $($pkg.Name)" }
        Write-Done "$($pkg.Name) installed"
    }
}

Refresh-Path

# winget sometimes installs fnm without adding it to PATH — fix that
if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    $fnmExe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "fnm.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($fnmExe) {
        $fnmDir = $fnmExe.DirectoryName
        $env:PATH += ";$fnmDir"
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$fnmDir*") {
            [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$fnmDir", "User")
        }
        Write-Info "Added fnm to PATH manually (winget didn't do it)"
    }
}

# Scoop (needed for Starship — winget doesn't install it properly)
Write-Step "Checking Scoop..."
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Skip "Scoop already installed"
} else {
    Write-Info "Installing Scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Refresh-Path
    Write-Done "Scoop installed"
}

# Starship via Scoop
Write-Step "Checking Starship..."
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Write-Skip "Starship already installed"
} else {
    Write-Info "Installing Starship via Scoop..."
    scoop install starship
    Refresh-Path
    Write-Done "Starship installed"
}

# GitHub auth
Write-Step "Checking GitHub authentication..."
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Skip "Already logged into GitHub"
} else {
    Write-Info "Opening GitHub login..."
    gh auth login
    if ($LASTEXITCODE -ne 0) { Write-Fail "GitHub login failed" }
    Write-Done "GitHub login complete"
}

# Git config
Write-Step "Checking git identity..."
$gitName  = git config --global user.name  2>$null
$gitEmail = git config --global user.email 2>$null

if ($gitName -and $gitEmail) {
    Write-Skip "Git identity already set to '$gitName <$gitEmail>'"
} else {
    Write-Host ""
    if (-not $gitName) {
        $gitName = Read-Host "    Enter your name for git commits"
        git config --global user.name $gitName
    }
    if (-not $gitEmail) {
        $gitEmail = Read-Host "    Enter your email for git commits"
        git config --global user.email $gitEmail
    }
    Write-Done "Git identity set to '$gitName <$gitEmail>'"
}

# Node via fnm
Write-Step "Checking Node.js..."
Refresh-Path

if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Skip "Node.js $(node --version) already installed"
} else {
    if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -Force | Out-Null }
    $profileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
    if (-not ($profileContent -match "fnm env")) {
        $fnmProfileBlock = @'

# Add fnm to PATH (winget doesn't do this automatically)
$fnmExe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "fnm.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($fnmExe) { $env:PATH += ";$($fnmExe.DirectoryName)" }

# Activate fnm
fnm env --use-on-cd | Out-String | Invoke-Expression

# Add claude to PATH
$env:PATH += ";$env:USERPROFILE\.local\bin"

# Starship prompt (Scoop puts it in PATH automatically)
Invoke-Expression (&starship init powershell)
'@
        Add-Content $PROFILE $fnmProfileBlock
        Write-Info "Added profile setup (fnm, claude, starship)"
    }
    Write-Info "Installing Node.js LTS via fnm..."
    fnm env --use-on-cd | Out-String | Invoke-Expression
    fnm install --lts
    fnm use lts-latest
    fnm default lts-latest
    Refresh-Path
    Write-Done "Node.js installed"
}

# Claude Code
Write-Step "Checking Claude Code..."
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Skip "Claude Code already installed"
} else {
    Write-Info "Installing Claude Code..."
    try {
        irm https://claude.ai/install.ps1 | iex
    } catch {
        Write-Fail "Failed to install Claude Code: $_"
    }
    $localBin = "$env:USERPROFILE\.local\bin"
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$localBin*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$localBin", "User")
        $env:PATH += ";$localBin"
        Write-Info "Added $localBin to PATH"
    }
    Write-Done "Claude Code installed"
}

# Starship config
Write-Step "Copying Starship config..."
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$starshipSrc = Join-Path $scriptDir "starship.toml"
if (Test-Path $starshipSrc) {
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config" | Out-Null
    Copy-Item $starshipSrc "$env:USERPROFILE\.config\starship.toml" -Force
    Write-Done "Starship config copied"
} else {
    Write-Info "starship.toml not found next to script, skipping"
}

# Done
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host "        Windows Setup Complete!" -ForegroundColor Green
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    - Restart your terminal so PATH changes take effect" -ForegroundColor Gray
Write-Host "    - Open WSL and run: bash setup-wsl.sh" -ForegroundColor Gray
Write-Host ""
