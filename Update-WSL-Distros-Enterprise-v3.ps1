#Requires -Version 5.1
<#+
.SYNOPSIS
  Repairs, fully updates, and installs essential tools in Ubuntu/Debian and
  SUSE/SLES WSL distributions. Designed for corporate proxy environments.

.DESCRIPTION
  - Self-elevates
  - Cleans hidden NUL/control characters from WSL distro names
  - Detects Linux family from /etc/os-release
  - Tries both WSL update channels, but never blocks distro updates on HTTP 403
  - Repairs APT/dpkg or Zypper/RPM state
  - Retries repository refresh
  - Installs packages one-by-one, skipping unavailable packages
  - Continues to the next distro after errors
  - Produces transcript and CSV summary reports

.EXAMPLE
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Update-WSL-Distros-Enterprise-v3.ps1
#>
[CmdletBinding()]
param(
    [string[]]$Distribution,
    [switch]$SkipWslPlatformUpdate,
    [switch]$SkipPackageInstall,
    [switch]$SkipConnectivityTest,
    [switch]$AllowSuseDistUpgrade
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    $forward = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
    foreach ($item in @($Distribution)) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $forward += @('-Distribution', ('"{0}"' -f $item))
        }
    }
    if ($SkipWslPlatformUpdate) { $forward += '-SkipWslPlatformUpdate' }
    if ($SkipPackageInstall) { $forward += '-SkipPackageInstall' }
    if ($SkipConnectivityTest) { $forward += '-SkipConnectivityTest' }
    if ($AllowSuseDistUpgrade) { $forward += '-AllowSuseDistUpgrade' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($forward -join ' ')
    exit
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportDirectory = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $PWD.Path }
$logPath = Join-Path $reportDirectory "WSL-Maintenance-$stamp.log"
$csvPath = Join-Path $reportDirectory "WSL-Maintenance-$stamp.csv"
$results = New-Object 'System.Collections.Generic.List[object]'
Start-Transcript -Path $logPath -Force | Out-Null

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Success([string]$Text) { Write-Host "[OK] $Text" -ForegroundColor Green }
function Write-ScriptWarning([string]$Text) { Write-Warning $Text }

function Add-Result {
    param([string]$Distro,[string]$Family,[string]$Stage,[string]$Status,[string]$Detail = '')
    $results.Add([pscustomobject]@{
        Time = (Get-Date).ToString('s')
        Distro = $Distro
        Family = $Family
        Stage = $Stage
        Status = $Status
        Detail = $Detail
    })
}

function ConvertTo-CleanDistroName {
    param([object]$InputObject)
    if ($null -eq $InputObject) { return '' }
    return (([string]$InputObject) -replace '[\x00-\x1F\x7F]', '').Trim()
}

function Invoke-WslRootScript {
    param(
        [Parameter(Mandatory=$true)][string]$Distro,
        [Parameter(Mandatory=$true)][string]$Script
    )
    # Base64 transport prevents PowerShell from interpreting Bash operators,
    # dollar signs, quotes, redirects, regexes, or command substitutions.
    $normalized = $Script -replace "`r`n", "`n"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($normalized))
    & wsl.exe --distribution $Distro --user root -- bash -lc "echo '$encoded' | base64 -d | bash"
    return $LASTEXITCODE
}

$ubuntuMaintenance = @'
set +e
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "[Ubuntu] Repairing package manager state"
dpkg --configure -a
apt-get -f install -y
apt-get clean
mkdir -p /var/lib/apt/lists/partial

echo "[Ubuntu] Refreshing repositories"
apt_rc=1
attempt=1
while [ "$attempt" -le 3 ]; do
    apt-get -o Acquire::Retries=3 update
    apt_rc=$?
    [ "$apt_rc" -eq 0 ] && break
    echo "APT refresh attempt $attempt failed; clearing partial metadata"
    rm -rf /var/lib/apt/lists/partial/*
    apt-get clean
    attempt=$((attempt + 1))
done
[ "$apt_rc" -eq 0 ] || exit 20

echo "[Ubuntu] Performing full upgrade"
apt-get -o Dpkg::Options::="--force-confold" -y full-upgrade
upgrade_rc=$?
dpkg --configure -a
apt-get -f install -y
[ "$upgrade_rc" -eq 0 ] || exit 21

exit 0
'@

$ubuntuPackages = @'
set +e
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
packages="build-essential gcc g++ make cmake ninja-build pkg-config git git-lfs curl wget rsync unzip zip p7zip-full tar jq python3 python3-pip python3-venv python3-dev pipx openssh-client ca-certificates gnupg net-tools dnsutils iputils-ping traceroute nmap vim nano tmux screen htop tree lsof strace ripgrep fd-find ccache shellcheck"
ok=0
failed=0
skipped=0
for p in $packages; do
    if apt-cache show "$p" >/dev/null 2>&1; then
        if apt-get install -y "$p"; then
            ok=$((ok + 1))
        else
            echo "WARN failed package: $p"
            failed=$((failed + 1))
        fi
    else
        echo "SKIP unavailable package: $p"
        skipped=$((skipped + 1))
    fi
done
apt-get autoremove -y
apt-get autoclean
echo "Package summary: installed_or_confirmed=$ok failed=$failed unavailable=$skipped"
exit 0
'@

$suseMaintenance = @'
set +e

echo "[SUSE] Repairing RPM and Zypper state"
rm -f /var/run/zypp.pid /var/run/zypp.pid.lock
rpm --rebuilddb
zypper --non-interactive clean --all

echo "[SUSE] Refreshing repositories"
refresh_rc=1
attempt=1
while [ "$attempt" -le 3 ]; do
    zypper --non-interactive --gpg-auto-import-keys refresh --force
    refresh_rc=$?
    [ "$refresh_rc" -eq 0 ] && break
    echo "Zypper refresh attempt $attempt failed; clearing cached metadata"
    rm -rf /var/cache/zypp/raw/* /var/cache/zypp/solv/*
    zypper --non-interactive clean --all
    attempt=$((attempt + 1))
done
[ "$refresh_rc" -eq 0 ] || exit 30

zypper --non-interactive verify || true
zypper --non-interactive patch --with-update --auto-agree-with-licenses || true
zypper --non-interactive update --auto-agree-with-licenses
update_rc=$?
[ "$update_rc" -eq 0 ] || exit 31
exit 0
'@

$suseDistUpgrade = @'
set +e
zypper --non-interactive dup --auto-agree-with-licenses --allow-vendor-change
exit $?
'@

$susePackages = @'
set +e
packages="gcc gcc-c++ make cmake ninja pkg-config git git-lfs curl wget rsync unzip zip p7zip tar jq python3 python3-pip python3-devel openssh ca-certificates net-tools bind-utils iputils traceroute nmap vim nano tmux screen htop tree lsof strace ripgrep ccache gawk grep sed which"
ok=0
failed=0
skipped=0
for p in $packages; do
    search_output=$(zypper --non-interactive search --match-exact "$p" 2>/dev/null)
    if echo "$search_output" | grep -Fq "$p"; then
        if zypper --non-interactive install --auto-agree-with-licenses "$p"; then
            ok=$((ok + 1))
        else
            echo "WARN failed package: $p"
            failed=$((failed + 1))
        fi
    else
        echo "SKIP unavailable package: $p"
        skipped=$((skipped + 1))
    fi
done
zypper --non-interactive clean --all
echo "Package summary: installed_or_confirmed=$ok failed=$failed unavailable=$skipped"
exit 0
'@

$healthCheck = @'
set +e
. /etc/os-release 2>/dev/null
echo "OS: ${PRETTY_NAME:-unknown}"
echo "Kernel: $(uname -r)"
echo "Disk:"
df -h /
echo "Memory:"
free -h 2>/dev/null || true
python3 --version 2>/dev/null || true
git --version 2>/dev/null || true
cmake --version 2>/dev/null | head -n 1 || true
if [ -f /var/run/reboot-required ]; then echo "Reboot recommended"; fi
exit 0
'@

try {
    Write-Step 'Validating WSL installation'
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw 'wsl.exe was not found.'
    }
    & wsl.exe --status 2>&1 | Out-Host

    if (-not $SkipWslPlatformUpdate) {
        Write-Step 'Updating the Windows WSL platform'
        $platformUpdated = $false
        & wsl.exe --update 2>&1 | Out-Host
        if ($LASTEXITCODE -eq 0) {
            $platformUpdated = $true
        } else {
            Write-ScriptWarning "Default WSL update failed with exit code $LASTEXITCODE. Trying web-download."
            & wsl.exe --update --web-download 2>&1 | Out-Host
            if ($LASTEXITCODE -eq 0) { $platformUpdated = $true }
        }
        if ($platformUpdated) {
            Add-Result 'WSL platform' '' 'Platform update' 'Success'
        } else {
            Write-ScriptWarning 'WSL platform update is blocked. Linux distro updates will continue.'
            Add-Result 'WSL platform' '' 'Platform update' 'Warning' 'Both update methods failed; likely corporate download policy or proxy restriction'
        }
    }

    Write-Step 'Discovering installed WSL distributions'
    $installed = @(
        & wsl.exe --list --quiet 2>$null |
        ForEach-Object { ConvertTo-CleanDistroName $_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )

    if (@($Distribution).Count -gt 0) {
        $requested = @(
            $Distribution |
            ForEach-Object { ConvertTo-CleanDistroName $_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
        $distros = @($requested | Where-Object { $installed -contains $_ })
        foreach ($missing in @($requested | Where-Object { $installed -notcontains $_ })) {
            Write-ScriptWarning "Requested distro was not found: [$missing]"
            Add-Result $missing 'Unknown' 'Discovery' 'Skipped' 'Not installed'
        }
    } else {
        $distros = $installed
    }

    if ($distros.Count -eq 0) { throw 'No valid WSL distributions were found.' }
    foreach ($d in $distros) { Write-Host "  [$d]" }

    & wsl.exe --shutdown 2>&1 | Out-Host
    Start-Sleep -Seconds 2

    foreach ($distro in $distros) {
        Write-Step "Processing [$distro]"
        try {
            $osLines = @(& wsl.exe --distribution $distro --user root -- sh -c 'cat /etc/os-release' 2>&1)
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to start distro or read /etc/os-release: $($osLines -join ' ')"
            }
            $osText = $osLines -join "`n"
            $id = ''
            if ($osText -match '(?m)^ID=["'']?([^"''\r\n]+)') { $id = $Matches[1].ToLowerInvariant() }
            if (($id -match '^(ubuntu|debian)$') -or ($osText -match '(?im)^ID_LIKE=.*debian')) {
                $family = 'Debian'
            } elseif (($id -match 'sles|suse|opensuse') -or ($osText -match '(?im)^ID_LIKE=.*suse')) {
                $family = 'SUSE'
            } else {
                $family = 'Unknown'
            }
            Write-Host "Family: $family; ID: $id"

            if ($family -eq 'Unknown') {
                Write-ScriptWarning "Unsupported distro type: [$distro]"
                Add-Result $distro $family 'Detection' 'Skipped' "ID=$id"
                continue
            }

            if (-not $SkipConnectivityTest) {
                $proxyTest = @'
set +e
echo "HTTPS proxy: ${HTTPS_PROXY:-${https_proxy:-not-set}}"
if command -v curl >/dev/null 2>&1; then
    curl -fsSI --max-time 15 https://www.microsoft.com/ >/dev/null 2>&1
    exit $?
fi
exit 0
'@
                $testCode = Invoke-WslRootScript -Distro $distro -Script $proxyTest
                if ($testCode -ne 0) {
                    Write-ScriptWarning "Initial HTTPS test failed in [$distro]. Repository repair will still be attempted."
                    Add-Result $distro $family 'Connectivity' 'Warning' "Exit $testCode"
                }
            }

            if ($family -eq 'Debian') {
                $code = Invoke-WslRootScript -Distro $distro -Script $ubuntuMaintenance
                if ($code -ne 0) {
                    throw "APT repair/update/upgrade failed with exit code $code. Package installation was skipped safely."
                }
                Add-Result $distro $family 'Repair and full upgrade' 'Success'
                Write-Success 'APT repair and full upgrade completed'

                if (-not $SkipPackageInstall) {
                    [void](Invoke-WslRootScript -Distro $distro -Script $ubuntuPackages)
                    Add-Result $distro $family 'Essential packages' 'Completed' 'Individual package failures are listed in the transcript'
                }
            } else {
                $code = Invoke-WslRootScript -Distro $distro -Script $suseMaintenance
                if ($code -ne 0) {
                    throw "Zypper repair/refresh/update failed with exit code $code. Package installation was skipped safely."
                }
                Add-Result $distro $family 'Repair and update' 'Success'
                Write-Success 'Zypper repair and update completed'

                if ($AllowSuseDistUpgrade) {
                    $dupCode = Invoke-WslRootScript -Distro $distro -Script $suseDistUpgrade
                    if ($dupCode -eq 0) {
                        Add-Result $distro $family 'Distribution upgrade' 'Success'
                    } else {
                        Add-Result $distro $family 'Distribution upgrade' 'Warning' "Exit $dupCode"
                    }
                }

                if (-not $SkipPackageInstall) {
                    [void](Invoke-WslRootScript -Distro $distro -Script $susePackages)
                    Add-Result $distro $family 'Essential packages' 'Completed' 'Individual package failures are listed in the transcript'
                }
            }

            Write-Step "Health verification for [$distro]"
            [void](Invoke-WslRootScript -Distro $distro -Script $healthCheck)
            Add-Result $distro $family 'Health verification' 'Completed'
        }
        catch {
            Write-ScriptWarning "[$distro] $($_.Exception.Message)"
            Add-Result $distro 'Unknown' 'Distro processing' 'Failed' $_.Exception.Message
            continue
        }
    }
}
catch {
    Write-Error $_
    Add-Result 'Script' '' 'Fatal' 'Failed' $_.Exception.Message
}
finally {
    $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    try { Stop-Transcript | Out-Null } catch {}
    Write-Host "`nDetailed log: $logPath" -ForegroundColor Yellow
    Write-Host "CSV summary: $csvPath" -ForegroundColor Yellow
    Write-Host 'Completed. Failures in one distro do not block the remaining distros.' -ForegroundColor Green
}
