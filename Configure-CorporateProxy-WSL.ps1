#Requires -Version 5.1
<#
.SYNOPSIS
  Elevates itself, enables WSL 2 autoProxy/mirrored networking, resolves the
  Windows PAC for HTTP/HTTPS, and persists proxy settings for the default WSL
  user and root in Bash/POSIX and csh/tcsh startup files.

.NOTES
  PAC URL default: http://wpad.intel.com/wpad.dat
  The script creates backups before changing existing files.
  Run with a process-scoped bypass if corporate execution policy permits:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Configure-CorporateProxy-WSL.ps1
#>
[CmdletBinding()]
param(
    [string]$PacUrl = 'http://wpad.intel.com/wpad.dat',
    [string[]]$Distribution,
    [string]$NoProxy = 'localhost,127.0.0.1,::1,.intel.com,intel.com,10.0.0.0/8,192.168.0.0/16,134.134.0.0/16',
    [switch]$SkipWslUpdate,
    [switch]$SkipConnectivityTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text)   { Write-Host "[OK] $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Warning $Text }

# Self-elevate while faithfully forwarding common parameters.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Restarting elevated...' -ForegroundColor Yellow
    $forward = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $PSCommandPath),'-PacUrl',('"{0}"' -f $PacUrl),'-NoProxy',('"{0}"' -f $NoProxy))
    foreach ($d in $Distribution) { $forward += @('-Distribution', ('"{0}"' -f $d)) }
    if ($SkipWslUpdate) { $forward += '-SkipWslUpdate' }
    if ($SkipConnectivityTest) { $forward += '-SkipConnectivityTest' }
    Start-Process powershell.exe -Verb RunAs -ArgumentList ($forward -join ' ')
    exit
}

function Get-InternetSettings {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $p = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
    [pscustomobject]@{
        AutoConfigURL = [string]$p.AutoConfigURL
        ProxyEnable   = [int]$p.ProxyEnable
        ProxyServer   = [string]$p.ProxyServer
        ProxyOverride = [string]$p.ProxyOverride
    }
}

function Resolve-SystemProxy([uri]$Uri) {
    try {
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        $resolved = $proxy.GetProxy($Uri)
        if ($resolved -and $resolved.AbsoluteUri -ne $Uri.AbsoluteUri) {
            return $resolved.AbsoluteUri.TrimEnd('/')
        }
    } catch {
        Write-Warn "PAC resolution failed for $Uri : $($_.Exception.Message)"
    }
    return $null
}

function Set-IniKeys {
    param([string]$Path, [hashtable]$Sections)
    $lines = if (Test-Path $Path) { [Collections.Generic.List[string]](Get-Content $Path) } else { [Collections.Generic.List[string]]::new() }
    foreach ($sectionName in $Sections.Keys) {
        $header = "[$sectionName]"
        $start = -1
        for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -ieq $header) { $start=$i; break } }
        if ($start -lt 0) {
            if ($lines.Count -gt 0 -and $lines[$lines.Count-1] -ne '') { $lines.Add('') }
            $lines.Add($header); $start=$lines.Count-1
        }
        $end=$lines.Count
        for ($i=$start+1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -match '^\[.+\]$') { $end=$i; break } }
        foreach ($key in $Sections[$sectionName].Keys) {
            $newLine = "$key=$($Sections[$sectionName][$key])"
            $found=-1
            for ($i=$start+1; $i -lt $end; $i++) { if ($lines[$i] -match ('^\s*' + [regex]::Escape($key) + '\s*=')) { $found=$i; break } }
            if ($found -ge 0) { $lines[$found]=$newLine } else { $lines.Insert($end,$newLine); $end++ }
        }
    }
    if (Test-Path $Path) { Copy-Item $Path "$Path.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force }
    [IO.File]::WriteAllLines($Path, $lines, [Text.UTF8Encoding]::new($false))
}

Write-Step 'Checking WSL'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'wsl.exe was not found. Install WSL before running this script.' }
if (-not $SkipWslUpdate) {
    try { & wsl.exe --update | Out-Host } catch { Write-Warn "WSL update did not complete: $($_.Exception.Message)" }
}

Write-Step 'Reading Windows PAC configuration'
$inet = Get-InternetSettings
if ($inet.AutoConfigURL) { $PacUrl = $inet.AutoConfigURL }
Write-Host "PAC URL : $PacUrl"

# Resolve representative HTTP and HTTPS destinations through Windows PAC.
$httpProxy  = Resolve-SystemProxy ([uri]'http://www.msftconnecttest.com/connecttest.txt')
$httpsProxy = Resolve-SystemProxy ([uri]'https://www.microsoft.com/')
if (-not $httpProxy -and $httpsProxy) { $httpProxy=$httpsProxy }
if (-not $httpsProxy -and $httpProxy) { $httpsProxy=$httpProxy }
Write-Host "HTTP proxy resolved by Windows : $(if($httpProxy){$httpProxy}else{'DIRECT / unresolved'})"
Write-Host "HTTPS proxy resolved by Windows: $(if($httpsProxy){$httpsProxy}else{'DIRECT / unresolved'})"

Write-Step 'Creating or safely updating .wslconfig'
$wslConfigPath = Join-Path $env:USERPROFILE '.wslconfig'
Set-IniKeys -Path $wslConfigPath -Sections @{
    wsl2 = [ordered]@{
        networkingMode = 'mirrored'
        dnsTunneling    = 'true'
        autoProxy       = 'true'
        firewall        = 'true'
    }
}
Write-Ok $wslConfigPath

Write-Step 'Restarting WSL so global networking and autoProxy settings take effect'
& wsl.exe --shutdown
Start-Sleep -Seconds 2

$allDistros = @(& wsl.exe --list --quiet | ForEach-Object { ($_ -replace "`0",'').Trim() } | Where-Object { $_ })
$targets = if ($Distribution -and $Distribution.Count) { $Distribution } else { $allDistros }
if (-not $targets -or $targets.Count -eq 0) { throw 'No installed WSL distributions were found.' }

foreach ($distro in $targets) {
    if ($allDistros -notcontains $distro) { Write-Warn "Distribution not found, skipping: $distro"; continue }
    Write-Step "Configuring $distro"

    $defaultUser = (& wsl.exe -d $distro -- sh -lc 'id -un' 2>$null | Select-Object -First 1).Trim()
    if (-not $defaultUser) { Write-Warn "Could not determine default user for $distro; skipping."; continue }
    Write-Host "Default Linux user: $defaultUser"

    # Build files locally, transfer the payload as Base64 to avoid quoting/injection issues.
    $bashProxy = @"
# Managed by Configure-CorporateProxy-WSL.ps1
export WSL_PAC_URL='$PacUrl'
export AUTO_PROXY_URL='$PacUrl'
export auto_proxy='$PacUrl'
export no_proxy='$NoProxy'
export NO_PROXY='$NoProxy'
$(if($httpProxy){"export http_proxy='$httpProxy'`nexport HTTP_PROXY='$httpProxy'"}else{'# HTTP proxy is supplied dynamically by WSL autoProxy when available.'})
$(if($httpsProxy){"export https_proxy='$httpsProxy'`nexport HTTPS_PROXY='$httpsProxy'"}else{'# HTTPS proxy is supplied dynamically by WSL autoProxy when available.'})
"@
    $cshProxy = @"
# Managed by Configure-CorporateProxy-WSL.ps1
setenv WSL_PAC_URL '$PacUrl'
setenv AUTO_PROXY_URL '$PacUrl'
setenv auto_proxy '$PacUrl'
setenv no_proxy '$NoProxy'
setenv NO_PROXY '$NoProxy'
$(if($httpProxy){"setenv http_proxy '$httpProxy'`nsetenv HTTP_PROXY '$httpProxy'"}else{'# HTTP proxy is supplied dynamically by WSL autoProxy when available.'})
$(if($httpsProxy){"setenv https_proxy '$httpsProxy'`nsetenv HTTPS_PROXY '$httpsProxy'"}else{'# HTTPS proxy is supplied dynamically by WSL autoProxy when available.'})
"@

    $payload = @'
set -eu
user_name="$1"
b64_bash="$2"
b64_csh="$3"
user_home="$(getent passwd "$user_name" | cut -d: -f6)"
[ -n "$user_home" ] || { echo "Cannot find home for $user_name" >&2; exit 2; }
timestamp="$(date +%Y%m%d-%H%M%S)"

install_for_home() {
  target_home="$1"
  owner="$2"
  mkdir -p "$target_home/.config/proxy"
  for f in "$target_home/.config/proxy/windows-proxy.sh" "$target_home/.config/proxy/windows-proxy.csh"; do
    [ ! -f "$f" ] || cp -p "$f" "$f.bak-$timestamp"
  done
  printf '%s' "$b64_bash" | base64 -d > "$target_home/.config/proxy/windows-proxy.sh"
  printf '%s' "$b64_csh"  | base64 -d > "$target_home/.config/proxy/windows-proxy.csh"
  chmod 0644 "$target_home/.config/proxy/windows-proxy.sh" "$target_home/.config/proxy/windows-proxy.csh"

  for rc in .profile .bashrc .bash_profile; do
    touch "$target_home/$rc"
    grep -Fq '.config/proxy/windows-proxy.sh' "$target_home/$rc" || printf '\n# WSL/Windows corporate proxy\n[ -r "$HOME/.config/proxy/windows-proxy.sh" ] && . "$HOME/.config/proxy/windows-proxy.sh"\n' >> "$target_home/$rc"
  done
  for rc in .cshrc .tcshrc; do
    touch "$target_home/$rc"
    grep -Fq '.config/proxy/windows-proxy.csh' "$target_home/$rc" || printf '\n# WSL/Windows corporate proxy\nif ( -r "$HOME/.config/proxy/windows-proxy.csh" ) source "$HOME/.config/proxy/windows-proxy.csh"\n' >> "$target_home/$rc"
  done
  chown -R "$owner":"$(id -gn "$owner" 2>/dev/null || echo "$owner")" "$target_home/.config/proxy" "$target_home/.profile" "$target_home/.bashrc" "$target_home/.bash_profile" "$target_home/.cshrc" "$target_home/.tcshrc" 2>/dev/null || true
}

install_for_home "$user_home" "$user_name"
install_for_home /root root

# System-wide login-shell fallback. $HOME is evaluated when a shell starts.
cat > /etc/profile.d/windows-corporate-proxy.sh <<'EOF'
[ -r "$HOME/.config/proxy/windows-proxy.sh" ] && . "$HOME/.config/proxy/windows-proxy.sh"
EOF
chmod 0644 /etc/profile.d/windows-corporate-proxy.sh
printf 'Configured proxy profiles for %s and root.\n' "$user_name"
'@

    $b64Payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
    $b64Bash = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($bashProxy -replace "`r`n","`n")))
    $b64Csh  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($cshProxy -replace "`r`n","`n")))
    & wsl.exe -d $distro -u root -- sh -lc "printf '%s' '$b64Payload' | base64 -d | sh -s -- '$defaultUser' '$b64Bash' '$b64Csh'"
    if ($LASTEXITCODE -ne 0) { Write-Warn "Profile configuration failed for $distro (exit $LASTEXITCODE)."; continue }

    # Verify files and effective login-shell variables for both identities.
    foreach ($u in @($defaultUser,'root') | Select-Object -Unique) {
        Write-Host "Verification for $distro / $u"
        & wsl.exe -d $distro -u $u -- bash -lc "printf '  WSL_PAC_URL=%s\n  HTTP_PROXY=%s\n  HTTPS_PROXY=%s\n' \"`$WSL_PAC_URL\" \"`$HTTP_PROXY\" \"`$HTTPS_PROXY\"" 2>$null
    }

    if (-not $SkipConnectivityTest) {
        Write-Host 'Connectivity test:'
        & wsl.exe -d $distro -- sh -lc 'if command -v curl >/dev/null 2>&1; then curl -IsS --max-time 15 https://www.microsoft.com/ | head -n 1; elif command -v wget >/dev/null 2>&1; then wget -q --spider --timeout=15 https://www.microsoft.com/ && echo "wget: OK"; else echo "curl/wget unavailable; test skipped"; fi' 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-Warn "Connectivity test did not succeed in $distro. PAC metadata was installed, but Windows may have returned DIRECT/unresolved or corporate CA trust may still be required." }
    }
    Write-Ok "$distro configured"
}

Write-Step 'Final WSL restart'
& wsl.exe --shutdown
Write-Ok 'Completed. Start WSL normally; Bash and tcsh will load the managed proxy profiles.'
Write-Host "Backups: $wslConfigPath.bak-* and ~/.config/proxy/*.bak-*"
