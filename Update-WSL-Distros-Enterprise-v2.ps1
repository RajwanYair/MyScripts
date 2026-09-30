#Requires -Version 5.1
<#+
Enterprise-grade WSL updater for Ubuntu and SUSE Linux Enterprise.
- Self-elevates
- Sanitizes UTF-16/control characters from `wsl --list --quiet`
- Identifies distro family from /etc/os-release, not the registered name
- Updates WSL with safe fallbacks and never aborts distro maintenance on a 403
- Repairs package-manager state, refreshes repositories, upgrades packages
- Installs available essential tools individually so one missing package cannot block all others
- Writes detailed TXT and CSV reports beside this script
#>
[CmdletBinding()]
param(
    [string[]]$Distribution,
    [switch]$SkipWslUpdate,
    [switch]$SkipPackageInstall,
    [switch]$SkipConnectivityTest,
    [switch]$AllowSuseDup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Self-elevate and preserve parameters.
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$admin = ([Security.Principal.WindowsPrincipal]::new($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $PSCommandPath))
    foreach ($d in $Distribution) { $args += @('-Distribution',('"{0}"' -f $d)) }
    foreach ($s in 'SkipWslUpdate','SkipPackageInstall','SkipConnectivityTest','AllowSuseDup') {
        if (Get-Variable -Name $s -ValueOnly) { $args += "-$s" }
    }
    Start-Process powershell.exe -Verb RunAs -ArgumentList ($args -join ' ')
    exit
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Split-Path -Parent $PSCommandPath
if (-not $outDir) { $outDir = $PWD.Path }
$log = Join-Path $outDir "WSL-Update-$stamp.log"
$csv = Join-Path $outDir "WSL-Update-$stamp.csv"
$results = [Collections.Generic.List[object]]::new()
Start-Transcript -Path $log -Force | Out-Null

function Info($s) { Write-Host "`n==> $s" -ForegroundColor Cyan }
function Good($s) { Write-Host "[OK] $s" -ForegroundColor Green }
function Warn($s) { Write-Warning $s }
function Clean-Name([object]$Value) {
    if ($null -eq $Value) { return '' }
    # WSL output can contain NUL and other invisible Unicode format/control characters.
    return (([string]$Value) -replace '[\p{Cc}\p{Cf}]','').Trim()
}
function Run-Wsl {
    param([string]$Distro,[string]$Command,[string]$User='root')
    & wsl.exe --distribution $Distro --user $User -- bash -lc $Command
    return $LASTEXITCODE
}
function Add-Result($Distro,$Family,$Stage,$Status,$Detail='') {
    $results.Add([pscustomobject]@{Time=(Get-Date).ToString('s');Distro=$Distro;Family=$Family;Stage=$Stage;Status=$Status;Detail=$Detail})
}

try {
    Info 'Validating WSL'
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'wsl.exe is not installed or is not in PATH.' }
    & wsl.exe --status 2>&1 | Out-Host

    if (-not $SkipWslUpdate) {
        Info 'Updating the WSL platform'
        $wslUpdated = $false
        foreach ($attempt in @(
            @('--update'),
            @('--update','--web-download')
        )) {
            & wsl.exe @attempt 2>&1 | Out-Host
            if ($LASTEXITCODE -eq 0) { $wslUpdated=$true; break }
            Warn "WSL platform update attempt failed with exit code $LASTEXITCODE. Continuing to Linux distro updates."
        }
        if (-not $wslUpdated) {
            Warn 'WSL platform update remains blocked, commonly by corporate proxy, Store policy, GitHub/API restriction, or TLS inspection. Distro maintenance will continue.'
            Add-Result 'WSL platform' '' 'WSL update' 'Warning' 'Default and web-download update paths failed'
        } else { Add-Result 'WSL platform' '' 'WSL update' 'Success' }
    }

    Info 'Discovering installed distributions'
    $raw = @(& wsl.exe --list --quiet 2>$null)
    $installed = @($raw | ForEach-Object { Clean-Name $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($Distribution -and $Distribution.Count) {
        $wanted = @($Distribution | ForEach-Object { Clean-Name $_ } | Where-Object { $_ } | Sort-Object -Unique)
        $distros = @($wanted | Where-Object { $installed -contains $_ })
        foreach ($missing in @($wanted | Where-Object { $installed -notcontains $_ })) { Warn "Requested distro not installed: [$missing]" }
    } else { $distros = $installed }
    if ($distros.Count -eq 0) { throw 'No valid installed WSL distributions were found.' }
    $distros | ForEach-Object { Write-Host "  [$_]" }

    # Stop all instances to release package database locks, then start each one explicitly.
    & wsl.exe --shutdown 2>&1 | Out-Host
    Start-Sleep -Seconds 2

    foreach ($d in $distros) {
        Info "Processing [$d]"
        $osRaw = @(& wsl.exe --distribution $d --user root -- sh -c 'cat /etc/os-release 2>/dev/null' 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Warn "Cannot start distro [$d]. Check with: wsl -l -v"
            Add-Result $d 'Unknown' 'Start' 'Failed' ($osRaw -join ' ')
            continue
        }
        $osText = $osRaw -join "`n"
        $idValue = if ($osText -match '(?m)^ID=["'']?([^"''\r\n]+)') { $Matches[1].ToLowerInvariant() } else { '' }
        $family = if ($idValue -match '^(ubuntu|debian)$' -or $osText -match '(?im)^ID_LIKE=.*debian') { 'Debian' }
                  elseif ($idValue -match '(sles|suse|opensuse)' -or $osText -match '(?im)^ID_LIKE=.*suse') { 'SUSE' }
                  else { 'Unknown' }
        Write-Host "Detected family: $family; OS ID: $idValue"
        if ($family -eq 'Unknown') { Warn "Unsupported distro family for [$d]."; Add-Result $d $family 'Detection' 'Skipped' $idValue; continue }

        # Confirm active proxy and DNS. Existing proxy profile from the prior script is sourced by bash -l.
        if (-not $SkipConnectivityTest) {
            $test = Run-Wsl $d 'echo "Proxy: ${HTTPS_PROXY:-${https_proxy:-not-set}}"; getent hosts archive.ubuntu.com >/dev/null 2>&1 || getent hosts download.opensuse.org >/dev/null 2>&1 || true; if command -v curl >/dev/null 2>&1; then curl -fsSI --max-time 15 https://www.microsoft.com/ >/dev/null; else true; fi'
            if ($test -ne 0) { Warn "Initial HTTPS test failed in [$d]. Package-manager diagnostics and retries will still run." }
        }

        if ($family -eq 'Debian') {
            $repair = @'
set +e
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock 2>/dev/null || true
dpkg --configure -a
apt-get -f install -y
apt-get clean
# Convert plain HTTP Ubuntu archive/security entries to HTTPS when present.
grep -RIl '^deb .*http://\(archive\.ubuntu\.com\|security\.ubuntu\.com\)' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | while read -r f; do cp -p "$f" "$f.pre-wsl-update.bak"; sed -i 's#http://archive\.ubuntu\.com#https://archive.ubuntu.com#g;s#http://security\.ubuntu\.com#https://security.ubuntu.com#g' "$f"; done
apt-get -o Acquire::Retries=3 update
rc=$?
if [ $rc -ne 0 ]; then
  apt-get clean
  rm -rf /var/lib/apt/lists/partial
  mkdir -p /var/lib/apt/lists/partial
  apt-get -o Acquire::Retries=5 update
  rc=$?
fi
exit $rc
'@
            $rc = Run-Wsl $d $repair
            if ($rc -ne 0) { Warn "APT repair/update failed in [$d]; upgrade and install are skipped to avoid corrupting package state."; Add-Result $d $family 'APT refresh/repair' 'Failed' "Exit $rc"; continue }
            Good 'APT repair and metadata refresh completed'

            $rc = Run-Wsl $d 'export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a; apt-get -o Dpkg::Options::="--force-confold" -y full-upgrade; rc=$?; dpkg --configure -a; apt-get -f install -y; exit $rc'
            if ($rc -ne 0) { Warn "APT full-upgrade returned $rc; repair was attempted."; Add-Result $d $family 'Full upgrade' 'Warning' "Exit $rc" } else { Good 'Full upgrade completed'; Add-Result $d $family 'Full upgrade' 'Success' }

            if (-not $SkipPackageInstall) {
                $packages = 'build-essential gcc g++ make cmake ninja-build pkg-config git git-lfs curl wget rsync unzip zip p7zip-full tar jq python3 python3-pip python3-venv python3-dev pipx openssh-client ca-certificates gnupg net-tools dnsutils iputils-ping traceroute nmap vim nano tmux screen htop tree lsof strace ripgrep fd-find ccache shellcheck'.Split(' ')
                $pkgArg = $packages -join ' '
                $install = "set +e; export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a; ok=0; fail=0; for p in $pkgArg; do if apt-cache show \"`$p\" >/dev/null 2>&1; then apt-get install -y \"`$p\" && ok=`$((ok+1)) || { echo \"WARN: failed: `$p\"; fail=`$((fail+1)); }; else echo \"SKIP unavailable: `$p\"; fi; done; echo \"Package summary: installed/confirmed=`$ok failed=`$fail\"; exit 0"
                [void](Run-Wsl $d $install)
                Add-Result $d $family 'Essential packages' 'Completed' 'Unavailable or failed packages logged individually'
            }
            [void](Run-Wsl $d 'export DEBIAN_FRONTEND=noninteractive; apt-get autoremove -y; apt-get autoclean; true')
        }
        elseif ($family -eq 'SUSE') {
            $repair = @'
set +e
rm -f /var/run/zypp.pid /var/run/zypp.pid.lock 2>/dev/null || true
rpm --rebuilddb
zypper --non-interactive clean --all
zypper --non-interactive --gpg-auto-import-keys refresh --force
rc=$?
if [ $rc -ne 0 ]; then
  echo 'Repository refresh failed; retrying after cache cleanup...'
  rm -rf /var/cache/zypp/raw/* /var/cache/zypp/solv/* 2>/dev/null || true
  zypper --non-interactive --gpg-auto-import-keys refresh --force
  rc=$?
fi
zypper --non-interactive verify || true
exit $rc
'@
            $rc = Run-Wsl $d $repair
            if ($rc -ne 0) { Warn "Zypper refresh failed in [$d]. This can indicate registration, repository DNS, proxy, or internal mirror failure. Upgrade/install skipped safely."; Add-Result $d $family 'Zypper refresh/repair' 'Failed' "Exit $rc"; continue }
            Good 'Zypper repair and repository refresh completed'

            [void](Run-Wsl $d 'zypper --non-interactive patch --with-update --auto-agree-with-licenses || true')
            $upgradeCmd = if ($AllowSuseDup) { 'zypper --non-interactive dup --auto-agree-with-licenses --allow-vendor-change' } else { 'zypper --non-interactive update --auto-agree-with-licenses' }
            $rc = Run-Wsl $d $upgradeCmd
            if ($rc -ne 0) { Warn "SUSE package upgrade returned $rc."; Add-Result $d $family 'Upgrade' 'Warning' "Exit $rc" } else { Good 'SUSE package upgrade completed'; Add-Result $d $family 'Upgrade' 'Success' }

            if (-not $SkipPackageInstall) {
                $packages = 'gcc gcc-c++ make cmake ninja pkg-config git git-lfs curl wget rsync unzip zip p7zip tar jq python3 python3-pip python3-devel openssh ca-certificates net-tools bind-utils iputils traceroute nmap vim nano tmux screen htop tree lsof strace ripgrep ccache gawk grep sed which'.Split(' ')
                $pkgArg = $packages -join ' '
                $install = "set +e; ok=0; fail=0; for p in $pkgArg; do if zypper --non-interactive search --match-exact \"`$p\" 2>/dev/null | grep -Eq '^[[:space:]]*[i ]*[|].*[|][[:space:]]*'\"`$p\"'[[:space:]]*[|]'; then zypper --non-interactive install --auto-agree-with-licenses \"`$p\" && ok=`$((ok+1)) || { echo \"WARN: failed: `$p\"; fail=`$((fail+1)); }; else echo \"SKIP unavailable: `$p\"; fi; done; echo \"Package summary: installed/confirmed=`$ok failed=`$fail\"; exit 0"
                [void](Run-Wsl $d $install)
                Add-Result $d $family 'Essential packages' 'Completed' 'Unavailable or failed packages logged individually'
            }
            [void](Run-Wsl $d 'zypper --non-interactive clean --all; true')
        }

        Info "Health verification for [$d]"
        [void](Run-Wsl $d 'printf "OS: "; . /etc/os-release; echo "$PRETTY_NAME"; printf "Kernel: "; uname -r; printf "Disk: "; df -h / | tail -1; printf "Python: "; python3 --version 2>/dev/null || true; printf "Git: "; git --version 2>/dev/null || true; printf "CMake: "; cmake --version 2>/dev/null | head -1 || true; if [ -f /var/run/reboot-required ]; then echo "Reboot recommended"; fi')
        Add-Result $d $family 'Verification' 'Completed'
    }
}
catch {
    Write-Error $_
    Add-Result 'Script' '' 'Fatal' 'Failed' $_.Exception.Message
}
finally {
    $results | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
    Stop-Transcript | Out-Null
    Write-Host "`nLog: $log" -ForegroundColor Yellow
    Write-Host "Report: $csv" -ForegroundColor Yellow
    Write-Host 'Completed. Review Warning/Failed records; successful distros were not blocked by failures in others.' -ForegroundColor Green
}
