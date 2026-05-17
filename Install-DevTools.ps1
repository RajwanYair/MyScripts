#Requires -Version 7.0
<#
.SYNOPSIS
    Install and update all development tools for MyScripts projects.

.DESCRIPTION
    Installs or updates the complete toolchain required for ExplorerLens and
    all other projects in the MyScripts workspace. Run this script once on a
    fresh machine or to update an existing setup.

    Tools installed:
      - C++: MSVC v145 (via VS BuildTools), CMake, Ninja, LLVM/Clang
      - Version control: Git, GitHub CLI (gh)
      - Runtime: Python 3.14, Node.js LTS, PowerShell 7
      - Python tools: ruff, mkdocs-material, pymdown-extensions
      - Node tools: markdownlint-cli, markdownlint-cli2, npm
      - Package managers: Scoop, NuGet, vcpkg

.PARAMETER UpdateOnly
    Only update already-installed tools; do not install new ones.

.PARAMETER Offline
    Skip network operations (useful when behind firewall).

.EXAMPLE
    .\Install-DevTools.ps1
    .\Install-DevTools.ps1 -UpdateOnly
#>
param(
    [switch]$UpdateOnly,
    [switch]$Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$script:Installed = 0
$script:Skipped = 0
$script:Failed = 0

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green; $script:Installed++ }
function Write-Skip { param([string]$Message) Write-Host "  [-] $Message" -ForegroundColor DarkGray; $script:Skipped++ }
function Write-Fail { param([string]$Message) Write-Host "  [!] $Message" -ForegroundColor Red; $script:Failed++ }

function Test-Command { param([string]$Name) $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

function Assert-ScoopPackage {
    param([string]$Package, [string]$BucketHint = '')

    if (scoop list 2>&1 | Select-String -Quiet "^  $Package ") {
        if ($UpdateOnly) { scoop update $Package 2>&1 | Out-Null; Write-Ok "scoop/$Package (updated)" }
        else { Write-Skip "scoop/$Package (already installed)" }
    } elseif (-not $UpdateOnly) {
        if ($BucketHint) { scoop bucket add $BucketHint 2>&1 | Out-Null }
        scoop install $Package 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok "scoop/$Package" }
        else { Write-Fail "scoop/$Package" }
    }
}

function Assert-PipPackage {
    param([string]$Package, [string]$Extras = '')

    $installed = pip show $Package 2>&1 | Select-String -Quiet '^Name:'
    if ($installed -and $UpdateOnly) {
        pip install --upgrade $Package 2>&1 | Out-Null
        Write-Ok "pip/$Package (upgraded)"
    } elseif ($installed) {
        Write-Skip "pip/$Package (already installed)"
    } elseif (-not $UpdateOnly) {
        $installArgs = if ($Extras) { "$Package[$Extras]" } else { $Package }
        pip install $installArgs 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok "pip/$Package" }
        else { Write-Fail "pip/$Package" }
    }
}

function Assert-NpmGlobalPackage {
    param([string]$Package)

    $installed = npm list -g $Package 2>&1 | Select-String -Quiet "^└"
    if ($installed -and $UpdateOnly) {
        npm update -g $Package 2>&1 | Out-Null
        Write-Ok "npm/$Package (updated)"
    } elseif ($installed) {
        Write-Skip "npm/$Package (already installed)"
    } elseif (-not $UpdateOnly) {
        npm install -g $Package 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok "npm/$Package" }
        else { Write-Fail "npm/$Package" }
    }
}

# ── Prerequisite: Scoop ──────────────────────────────────────────────────────
Write-Step "Checking Scoop package manager"
if (-not (Test-Command 'scoop')) {
    Write-Host "  Installing Scoop..."
    if (-not $Offline) {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
        Write-Ok "scoop"
    } else { Write-Fail "scoop (offline mode — install manually)" }
} else {
    Write-Skip "scoop (already installed)"
    if ($UpdateOnly -and -not $Offline) { scoop update 2>&1 | Out-Null }
}

# ── Scoop buckets ────────────────────────────────────────────────────────────
Write-Step "Scoop buckets"
if (-not $Offline) {
    foreach ($bucket in @('main', 'extras', 'versions')) {
        $exists = scoop bucket list 2>&1 | Select-String -Quiet $bucket
        if (-not $exists) { scoop bucket add $bucket 2>&1 | Out-Null; Write-Ok "bucket/$bucket" }
        else { Write-Skip "bucket/$bucket" }
    }
}

# ── Version control ──────────────────────────────────────────────────────────
Write-Step "Version control"
Assert-ScoopPackage 'git'
if (-not (Test-Command 'gh') -and -not $UpdateOnly) {
    if (Test-Path 'C:\Program Files\GitHub CLI\gh.exe') { Write-Skip "gh (system install)" }
    else { Assert-ScoopPackage 'gh' }
} else { Assert-ScoopPackage 'gh' }

# Secret scanning (WoodworkingShop CI uses gitleaks; local runs need the binary)
Assert-ScoopPackage 'gitleaks'

# ── C++ Build toolchain ──────────────────────────────────────────────────────
Write-Step "C++ build tools"
Assert-ScoopPackage 'cmake'
Assert-ScoopPackage 'ninja'
Assert-ScoopPackage 'llvm'
Assert-ScoopPackage 'nuget'

# MSVC via Visual Studio BuildTools is expected to be pre-installed
$vcvarsPath = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
if (Test-Path $vcvarsPath) { Write-Skip "MSVC BuildTools v145 (system install)" }
else { Write-Fail "MSVC BuildTools v145 — install Visual Studio 18 BuildTools with v145 toolset from https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" }

# ── Python environment ───────────────────────────────────────────────────────
Write-Step "Python and pip tools"
if (-not (Test-Command 'python')) { Write-Fail "python not found — install Python 3.14 from https://python.org" }
else {
    Write-Skip "python ($(python --version 2>&1))"

    # Ensure pip is up to date
    python -m pip install --upgrade pip 2>&1 | Out-Null

    # Core documentation tools
    Assert-PipPackage 'mkdocs-material'
    Assert-PipPackage 'pymdown-extensions'
    Assert-PipPackage 'mkdocs-get-deps'

    # Code quality
    Assert-PipPackage 'ruff'
}

# ── Node.js and npm tools ────────────────────────────────────────────────────
Write-Step "Node.js and npm global tools"
if (-not (Test-Command 'node')) { Write-Fail "node not found — install Node.js LTS from https://nodejs.org" }
else {
    Write-Skip "node ($(node --version))"
    Write-Skip "npm ($(npm --version))"

    # Markdown linting (both CLI variants used by different projects)
    Assert-NpmGlobalPackage 'markdownlint-cli'
    Assert-NpmGlobalPackage 'markdownlint-cli2'

    # WoodworkingShop tooling: Lighthouse CI, commitlint (run via npx in CI but
    # handy as globals for local audit runs).
    Assert-NpmGlobalPackage '@lhci/cli'
    Assert-NpmGlobalPackage '@commitlint/cli'
    Assert-NpmGlobalPackage '@commitlint/config-conventional'
}

# ── Playwright browsers (WoodworkingShop E2E) ────────────────────────────────
Write-Step "Playwright browsers"
if (Test-Command 'npx') {
    if (-not $UpdateOnly) {
        Write-Host "  Installing chromium + firefox for Playwright (one-time, ~200 MB)..."
        Push-Location $PSScriptRoot
        if (Test-Path 'WoodworkingShop\package.json') {
            Set-Location 'WoodworkingShop'
            npx --yes playwright install chromium firefox 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok 'playwright/chromium+firefox' }
            else { Write-Fail 'playwright browsers' }
            Set-Location ..
        } else {
            Write-Skip 'playwright (run `npx playwright install chromium firefox` inside any Playwright project)'
        }
        Pop-Location
    } else {
        Write-Skip 'playwright (update via project npx)'
    }
} else {
    Write-Skip 'playwright (npx not available)'
}

# ── PowerShell modules ───────────────────────────────────────────────────────
Write-Step "PowerShell modules"
foreach ($module in @('PSReadLine', 'posh-git')) {
    if (Get-Module -Name $module -ListAvailable -ErrorAction SilentlyContinue) {
        if ($UpdateOnly) {
            Update-Module $module -Force -ErrorAction SilentlyContinue
            Write-Ok "$module (updated)"
        } else { Write-Skip "$module (already installed)" }
    } elseif (-not $UpdateOnly) {
        Install-Module $module -Force -Scope CurrentUser -ErrorAction SilentlyContinue
        Write-Ok "$module"
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
Write-Host "Dev tools setup complete" -ForegroundColor White
Write-Host "  Installed/updated : $($script:Installed)" -ForegroundColor Green
Write-Host "  Skipped (present) : $($script:Skipped)" -ForegroundColor DarkGray
Write-Host "  Failed            : $($script:Failed)" -ForegroundColor $(if ($script:Failed -gt 0) { 'Red' } else { 'DarkGray' })
Write-Host "`nRestart your terminal for PATH changes to take effect." -ForegroundColor Yellow
