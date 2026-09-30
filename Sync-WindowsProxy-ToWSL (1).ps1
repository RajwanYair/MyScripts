#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$Distro = ""
)

function Get-WindowsProxy {
    $reg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    $proxyEnabled = $reg.ProxyEnable
    $proxyServer  = $reg.ProxyServer

    $netsh = (netsh winhttp show proxy) 2>$null | Out-String

    $proxy = $null
    if ($proxyServer) {
        if ($proxyServer -match '=') {
            if ($proxyServer -match 'https=([^;]+)') { $proxy = $Matches[1] }
            elseif ($proxyServer -match 'http=([^;]+)') { $proxy = $Matches[1] }
        } else {
            $proxy = $proxyServer
        }
    }

    if (-not $proxy -and $netsh -match 'Proxy Server\(s\)\s*:\s*(.+)') {
        $proxy = $Matches[1].Trim()
    }

    return [pscustomobject]@{
        Enabled = [bool]$proxyEnabled
        Proxy   = $proxy
        Raw     = $proxyServer
    }
}

$proxyInfo = Get-WindowsProxy
if (-not $proxyInfo.Enabled -or -not $proxyInfo.Proxy) {
    Write-Warning 'No Windows proxy detected.'
    exit 1
}

$distros = if ($Distro) { @($Distro) } else { (wsl -l -q | Where-Object { $_.Trim() }) }

foreach ($d in $distros) {
    Write-Host "Configuring $d ..." -ForegroundColor Cyan

    $bash = @"
mkdir -p ~/.config/proxy
cat > ~/.config/proxy/proxy.sh <<EOF
export http_proxy=http://$($proxyInfo.Proxy)
export https_proxy=http://$($proxyInfo.Proxy)
export HTTP_PROXY=http://$($proxyInfo.Proxy)
export HTTPS_PROXY=http://$($proxyInfo.Proxy)
export ftp_proxy=http://$($proxyInfo.Proxy)
export no_proxy=localhost,127.0.0.1,.intel.com
export NO_PROXY=localhost,127.0.0.1,.intel.com
EOF

grep -q 'proxy/proxy.sh' ~/.bashrc 2>/dev/null || echo 'source ~/.config/proxy/proxy.sh' >> ~/.bashrc
grep -q 'proxy/proxy.sh' ~/.zshrc 2>/dev/null || echo 'source ~/.config/proxy/proxy.sh' >> ~/.zshrc

sudo mkdir -p /etc/profile.d
printf '%s\n' 'source $HOME/.config/proxy/proxy.sh 2>/dev/null || true' | sudo tee /etc/profile.d/windows-proxy.sh >/dev/null
"@

    wsl -d $d -- bash -lc $bash
}

Write-Host "Done. Restart WSL:" -ForegroundColor Green
Write-Host "wsl --shutdown"
