#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference='Continue'

function Invoke-WSL {
 param($Distro,$Cmd)
 wsl -d $Distro -- bash -lc "$Cmd"
}

$distros=(wsl -l -q | % {$_.Trim()} | ? {$_})

Write-Host 'Detected distros:' -ForegroundColor Cyan
$distros | % { Write-Host "  $_" }

try { wsl --update } catch {}

foreach($d in $distros){
 Write-Host "\n===== Processing $d =====" -ForegroundColor Yellow

 $lower=$d.ToLower()

 if($lower -match 'ubuntu'){
   Invoke-WSL $d @'
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoclean
sudo apt-get install -y \
 build-essential gcc g++ make cmake ninja-build pkg-config \
 git git-lfs curl wget rsync unzip zip p7zip-full tar jq yq \
 python3 python3-pip python3-venv python3-dev pipx \
 openssh-client openssh-server net-tools dnsutils iputils-ping \
 tcpdump traceroute nmap inetutils-tools \
 vim nano tmux screen htop tree lsof strace ripgrep fd-find \
 ca-certificates gnupg software-properties-common
sudo snap refresh || true
'@
 }
 elseif($lower -match 'sles|suse'){
   wsl -d $d -u root -- bash -lc '
zypper --gpg-auto-import-keys refresh
zypper update -y
zypper install -y \
 gcc gcc-c++ make cmake ninja pkg-config \
 git git-lfs curl wget rsync unzip zip p7zip tar jq \
 python3 python3-pip python3-devel \
 openssh net-tools bind-utils iputils traceroute \
 vim nano tmux screen htop tree lsof strace \
 ca-certificates gawk grep sed which
zypper clean --all
'
 }
 else {
   Write-Warning "Unknown distro type: $d"
 }
}

Write-Host '\nRunning final verification...' -ForegroundColor Green
foreach($d in $distros){
 Write-Host "\n$d"
 wsl -d $d -- sh -lc 'uname -a; python3 --version 2>/dev/null || true; git --version 2>/dev/null || true; cmake --version 2>/dev/null | head -1 || true'
}

Write-Host '\nCompleted.' -ForegroundColor Green
