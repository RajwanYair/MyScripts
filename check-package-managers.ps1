<#
.SYNOPSIS
    Checks and installs common package managers on Windows 11 with proxy support.
    Requires Administrator privileges.
#>

# Ensure script is running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script with elevated privileges..."
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Detect system proxy settings
$proxy = (netsh winhttp show proxy) -match "Proxy Server" | ForEach-Object {
    ($_ -split ":", 2)[1].Trim()
}
if ($proxy) {
    Write-Host "Detected proxy: $proxy"
} else {
    Write-Host "No proxy detected in WinHTTP settings."
}

# Helper: Check if command exists
function Test-Command {
    param([string]$cmd)
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

# Helper: Install via winget if available
function Install-WithWinget {
    param([string]$pkgName)
    if (Test-Command "winget") {
        Write-Host "Installing $pkgName via winget..."
        if ($proxy) {
            $env:HTTP_PROXY = "http://$proxy"
            $env:HTTPS_PROXY = "http://$proxy"
        }
        winget install --id $pkgName --silent --accept-source-agreements --accept-package-agreements
    } else {
        Write-Host "winget not found, skipping $pkgName."
    }
}

# Check and install Python pip
if (Test-Command "pip") {
    Write-Host "pip is installed."
} else {
    Write-Host "pip not found. Installing..."
    if (Test-Command "python") {
        python -m ensurepip --upgrade
        python -m pip install --upgrade pip
    } else {
        Install-WithWinget "Python.Python.3.11"
    }
}

# Check and install Perl CPAN
if (Test-Command "cpan") {
    Write-Host "CPAN is installed."
} else {
    Write-Host "CPAN not found. Installing Strawberry Perl..."
    Install-WithWinget "StrawberryPerl.StrawberryPerl"
}

# Check and install Node.js npm
if (Test-Command "npm") {
    Write-Host "npm is installed."
} else {
    Write-Host "npm not found. Installing Node.js..."
    Install-WithWinget "OpenJS.NodeJS"
}

# Check and install Chocolatey
if (Test-Command "choco") {
    Write-Host "Chocolatey is installed."
} else {
    Write-Host "Chocolatey not found. Installing..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    if ($proxy) {
        $env:HTTP_PROXY = "http://$proxy"
        $env:HTTPS_PROXY = "http://$proxy"
    }
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Check and install winget
if (Test-Command "winget") {
    Write-Host "winget is installed."
} else {
    Write-Host "winget not found. Please update Windows 11 to get winget."
}

Write-Host "`nAll checks complete."
