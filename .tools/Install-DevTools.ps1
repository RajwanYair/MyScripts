#requires -Version 7.0
<#
.SYNOPSIS
    One-shot installer for the MyScripts shared dev toolchain (Windows).

.DESCRIPTION
    Installs (idempotently):
      - Node 26 LTS via nvm-windows
      - npm @ latest + corepack
      - GitHub CLI (gh)
      - Playwright browsers (chromium + firefox, system deps)
      - @lhci/cli for Lighthouse CI
      - stylelint + stylelint-config-standard (global)

    Skips any tool already installed at the right version. Safe to re-run.

.NOTES
    Run from any directory. No state is written to the project — all caches
    land under %LOCALAPPDATA% or the system tool's default location.
#>
[CmdletBinding()]
param(
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Write-Step($msg) { Write-Host "[+] $msg" -ForegroundColor Cyan }
function Write-Skip($msg) { Write-Host "[=] $msg" -ForegroundColor DarkGray }
function Write-Done($msg) { Write-Host "[✓] $msg" -ForegroundColor Green }

# ── Node 22 LTS via nvm-windows ─────────────────────────────────────────────
if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
    Write-Step 'Installing nvm-windows via winget...'
    winget install --id CoreyButler.NVMforWindows --silent --accept-package-agreements --accept-source-agreements
} else {
    Write-Skip 'nvm-windows already installed.'
}

$nodeVersion = '26.3.0'
$currentNode = (node --version 2>$null)
if (-not $currentNode -or $currentNode -notlike "v26.*") {
    Write-Step "Installing Node $nodeVersion via nvm..."
    nvm install $nodeVersion
    nvm use $nodeVersion
} else {
    Write-Skip "Node $currentNode already active."
}

# ── npm + corepack ──────────────────────────────────────────────────────────
Write-Step 'Updating npm to latest...'
npm install -g npm@latest 2>&1 | Out-Null
Write-Step 'Enabling corepack...'
corepack enable 2>&1 | Out-Null

# ── GitHub CLI ──────────────────────────────────────────────────────────────
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Step 'Installing GitHub CLI via winget...'
    winget install --id GitHub.cli --silent --accept-package-agreements --accept-source-agreements
} else {
    Write-Skip "GitHub CLI already installed ($(gh --version | Select-Object -First 1))."
}

# ── Stylelint baseline (global) ─────────────────────────────────────────────
Write-Step 'Installing stylelint + tailwindcss config globally...'
npm install -g stylelint stylelint-config-standard stylelint-config-tailwindcss 2>&1 | Out-Null

# ── Lighthouse CI ───────────────────────────────────────────────────────────
Write-Step 'Installing @lhci/cli globally...'
npm install -g @lhci/cli 2>&1 | Out-Null

# ── Playwright browsers ─────────────────────────────────────────────────────
Write-Step 'Installing Playwright browsers (chromium + firefox)...'
npx --yes playwright@latest install chromium firefox 2>&1 | Out-Null

# ── ripgrep (required by VS Code extensions and workspace search) ───────────
if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
    Write-Step 'Installing ripgrep via scoop...'
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Step 'Installing scoop package manager...'
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    }
    scoop install ripgrep
} else {
    Write-Skip "ripgrep already installed ($(rg --version | Select-Object -First 1))."
}

Write-Done 'All shared dev tools are installed.'
Write-Host ''
Write-Host 'Verify:' -ForegroundColor Yellow
Write-Host '  node --version      → v26.x'
Write-Host '  npm --version       → 11.x'
Write-Host '  gh --version        → 2.87+'
Write-Host '  lhci --version      → 0.15+'
Write-Host '  stylelint --version → 17+'
Write-Host '  rg --version        → 15.x'
