#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference='Continue'

function Get-Distros {
    $raw = wsl.exe -l -v 2>$null
    $list = @()
    foreach($line in $raw){
        $clean = ($line -replace "\x00",'').Trim()
        if(-not $clean){continue}
        if($clean -match '^NAME\s+STATE'){continue}
        $clean = $clean.TrimStart('*').Trim()
        if($clean -match '^(.*?)\s+(Running|Stopped)\s+\d+$'){
            $name = $Matches[1].Trim()
            if($name){$list += $name}
        }
    }
    $list | Sort-Object -Unique
}

function Invoke-WslScript($Distro,$Script){
  $b64=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Script))
  wsl.exe -d $Distro -u root -- bash -lc "echo '$b64' | base64 -d | bash"
  return $LASTEXITCODE
}

$distros = @(Get-Distros)
Write-Host 'Discovered distros:'
$distros | % { Write-Host " - $_" }

if($distros.Count -eq 0){
 Write-Error 'No WSL distros discovered. Run: wsl -l -v manually.'
 exit 1
}

$ubuntuScript=@'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -f install -y || true
apt-get -y full-upgrade
apt-get install -y git git-lfs curl wget rsync unzip zip python3 python3-pip cmake ninja-build build-essential htop tmux tree ripgrep ccache
apt-get autoremove -y
apt-get autoclean
'@

$suseScript=@'
zypper --gpg-auto-import-keys refresh || exit 1
zypper update -y
zypper install -y git git-lfs curl wget rsync unzip zip python3 python3-pip cmake ninja gcc gcc-c++ make htop tmux tree ripgrep ccache
zypper clean --all
'@

foreach($d in $distros){
  $os = (wsl.exe -d $d -- sh -c "grep '^ID=' /etc/os-release" 2>$null)
  Write-Host "Processing $d ($os)..."

  if($os -match 'ubuntu|debian'){
      Invoke-WslScript $d $ubuntuScript | Out-Host
  }
  elseif($os -match 'sles|suse|opensuse'){
      Invoke-WslScript $d $suseScript | Out-Host
  }
  else{
      Write-Warning "Unknown OS in $d : $os"
  }
}

Write-Host 'Completed.' -ForegroundColor Green
