# setup-windows.ps1
# Run with: powershell -ExecutionPolicy Bypass -File setup-windows.ps1

# ── Helpers ────────────────────────────────────────────────────────────────────
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║        Windows Dev Environment Setup     ║" -ForegroundColor Magenta
    Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
}

function Write-Step   { param($msg) Write-Host "`n  ► $msg" -ForegroundColor Cyan }
function Write-Done   { param($msg) Write-Host "    ✓ $msg" -ForegroundColor Green }
function Write-Skip   { param($msg) Write-Host "    ✓ $msg (already done)" -ForegroundColor Yellow }
function Write-Fail   { param($msg) Write-Host "    ✗ $msg" -ForegroundColor Red; exit 1 }
function Write-Info   { param($msg) Write-Host "    · $msg" -ForegroundColor Gray }

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") `
              + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
}

function Is-Installed { param($id)
    $result = winget list --id $id --exact 2>$null | Select-String $id
    return $null -ne $result
}

# ── Start ──────────────────────────────────────────────────────────────────────
Write-Header

# ── winget ────────────────────────────────────────────────────────────────────
Write-Step "Checking winget..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}
Write-Done "winget is available"

# ── Packages ──────────────────────────────────────────────────────────────────
$packages = @(
    @{ Id = "Git.Git";      Name = "Git"                       },
    @{ Id = "GitHub.cli";   Name = "GitHub CLI (gh)"           },
    @{ Id = "wez.wezterm";  Name = "WezTerm"                   },
    @{ Id = "Schniz.fnm";   Name = "fnm (Node Version Manager)"}
)

foreach ($pkg in $packages) {
    Write-Step "Checking $($pkg.Name)..."
    if (Is-Installed $pkg.Id) {
        Write-Skip "$($pkg.Name) is already installed"
    } else {
        Write-Info "Installing $($pkg.Name) via winget..."
        winget install --id $pkg.Id --exact --silent `
            --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Fail "Failed to install $($pkg.Name)" }
        Write-Done "$($pkg.Name) installed"
    }
}

Refresh-Path

# ── GitHub Auth ───────────────────────────────────────────────────────────────
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

# ── Git Config ────────────────────────────────────────────────────────────────
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

# ── Node via fnm ──────────────────────────────────────────────────────────────
Write-Step "Checking Node.js..."
Refresh-Path

if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Skip "Node.js $(node --version) already installed"
} else {
    # Add fnm init to PowerShell profile if not already there
    if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -Force | Out-Null }
    $profileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
    if (-not ($profileContent -match "fnm env")) {
        Add-Content $PROFILE "`nfnm env --use-on-cd | Out-String | Invoke-Expression"
        Write-Info "Added fnm init to PowerShell profile"
    }

    Write-Info "Installing Node.js LTS via fnm..."
    fnm install --lts
    fnm use lts-latest
    fnm default lts-latest
    Refresh-Path
    Write-Done "Node.js $(node --version) installed"
}

# ── Claude Code ───────────────────────────────────────────────────────────────
Write-Step "Checking Claude Code..."
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Skip "Claude Code already installed"
} else {
    Write-Info "Installing Claude Code via npm..."
    npm install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -ne 0) { Write-Fail "Failed to install Claude Code" }
    Write-Done "Claude Code installed"
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║       Windows Setup Complete! 🎉         ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    • Restart your terminal so PATH changes take effect" -ForegroundColor Gray
Write-Host "    • Open WSL and run: bash setup-wsl.sh" -ForegroundColor Gray
Write-Host ""
