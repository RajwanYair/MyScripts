#requires -version 5.1
<#
.SYNOPSIS
  Audits and installs all applicable Windows Update driver and firmware packages on Windows 11.
.DESCRIPTION
  Self-elevates, records hardware/firmware/driver inventory, scans the Windows Update source allowed
  by local enterprise policy, downloads and installs applicable updates, repeats scans, and writes
  CSV/JSON/transcript logs. It does not bypass WSUS, Intune, Windows Update for Business, or OEM policy.
.PARAMETER AuditOnly
  Scan and report without downloading or installing updates.
.PARAMETER AutoReboot
  Restart automatically when an installed update requires it. Default is to report and exit.
.PARAMETER MaxPasses
  Maximum scan/install passes. Some firmware updates expose a follow-on package after installation.
.PARAMETER IncludePreview
  Include preview updates. Disabled by default.
.PARAMETER ForceOnBattery
  Allow installation while the computer is on battery. Not recommended for firmware updates.
.EXAMPLE
  .\Update-AllWindows11-FirmwareAndDrivers.ps1
.EXAMPLE
  .\Update-AllWindows11-FirmwareAndDrivers.ps1 -AuditOnly
.EXAMPLE
  .\Update-AllWindows11-FirmwareAndDrivers.ps1 -AutoReboot
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$AuditOnly,
    [switch]$AutoReboot,
    [ValidateRange(1,10)][int]$MaxPasses = 4,
    [switch]$IncludePreview,
    [switch]$ForceOnBattery
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $PSCommandPath))
    foreach ($name in @('AuditOnly','AutoReboot','IncludePreview','ForceOnBattery')) {
        if ((Get-Variable -Name $name -ValueOnly)) { $argList += "-$name" }
    }
    $argList += @('-MaxPasses', $MaxPasses)
    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -ArgumentList $argList
    exit
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = Join-Path $env:ProgramData "FirmwareDriverUpdate\$stamp"
New-Item -ItemType Directory -Path $root -Force | Out-Null
$transcript = Join-Path $root 'Run.log'
Start-Transcript -Path $transcript -Force | Out-Null

function Write-Log {
    param([string]$Message,[ValidateSet('INFO','WARN','ERROR','OK')][string]$Level='INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Level,$Message
    Write-Host $line -ForegroundColor (@{INFO='Cyan';WARN='Yellow';ERROR='Red';OK='Green'}[$Level])
}

function Get-SystemSnapshot {
    param([string]$Stage)
    $computer = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $baseboard = Get-CimInstance Win32_BaseBoard
    $os = Get-CimInstance Win32_OperatingSystem
    $secureBoot = try { Confirm-SecureBootUEFI } catch { $null }
    $tpm = try { Get-Tpm } catch { $null }
    [pscustomobject]@{
        Stage = $Stage
        Collected = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        SystemType = $computer.SystemType
        BIOSManufacturer = $bios.Manufacturer
        BIOSVersion = ($bios.SMBIOSBIOSVersion -join '; ')
        BIOSReleaseDate = if ($bios.ReleaseDate) { ([datetime]$bios.ReleaseDate).ToString('o') } else { $null }
        BaseBoardManufacturer = $baseboard.Manufacturer
        BaseBoardProduct = $baseboard.Product
        OS = $os.Caption
        OSVersion = $os.Version
        OSBuild = $os.BuildNumber
        SecureBootEnabled = $secureBoot
        TpmPresent = if ($tpm) { $tpm.TpmPresent } else { $null }
        TpmReady = if ($tpm) { $tpm.TpmReady } else { $null }
        TpmManufacturerVersion = if ($tpm) { $tpm.ManufacturerVersion } else { $null }
    }
}

function Export-DeviceInventory {
    param([string]$Stage)
    $drivers = Get-CimInstance Win32_PnPSignedDriver | Sort-Object DeviceClass,DeviceName | ForEach-Object {
        [pscustomobject]@{
            Stage=$Stage; DeviceName=$_.DeviceName; DeviceClass=$_.DeviceClass; Manufacturer=$_.Manufacturer
            DriverProvider=$_.DriverProviderName; DriverVersion=$_.DriverVersion
            DriverDate=if ($_.DriverDate) { ([datetime]$_.DriverDate).ToString('yyyy-MM-dd') } else { $null }
            InfName=$_.InfName; DeviceId=$_.DeviceID; IsSigned=$_.IsSigned
        }
    }
    $drivers | Export-Csv -Path (Join-Path $root "Drivers-$Stage.csv") -NoTypeInformation -Encoding UTF8

    $firmware = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.Class -eq 'Firmware' -or $_.FriendlyName -match 'firmware|BIOS|UEFI|embedded controller|management engine' } |
        ForEach-Object {
            $ver = $null
            try { $ver = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction Stop).Data } catch {}
            [pscustomobject]@{ Stage=$Stage; Status=$_.Status; Class=$_.Class; FriendlyName=$_.FriendlyName; InstanceId=$_.InstanceId; DriverVersion=$ver }
        }
    $firmware | Export-Csv -Path (Join-Path $root "FirmwareDevices-$Stage.csv") -NoTypeInformation -Encoding UTF8
}

function Test-OnACPower {
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if (-not $battery) { return $true }
    return -not (($battery.BatteryStatus -eq 1) -or ($battery.BatteryStatus -eq 4) -or ($battery.BatteryStatus -eq 5))
}

function Get-UpdateIdentity {
    param($Update)
    $kb = @($Update.KBArticleIDs) -join ','
    [pscustomobject]@{
        Title = [string]$Update.Title
        KB = $kb
        UpdateId = [string]$Update.Identity.UpdateID
        Revision = [int]$Update.Identity.RevisionNumber
        Type = [string]$Update.Type
        Categories = (@($Update.Categories | ForEach-Object Name) -join '; ')
        DriverClass = [string]$Update.DriverClass
        DriverManufacturer = [string]$Update.DriverManufacturer
        DriverModel = [string]$Update.DriverModel
        DriverVerDate = if ($Update.DriverVerDate) { ([datetime]$Update.DriverVerDate).ToString('o') } else { $null }
        Downloaded = [bool]$Update.IsDownloaded
        Mandatory = [bool]$Update.IsMandatory
        RebootBehavior = [string]$Update.InstallationBehavior.RebootBehavior
        EulaAccepted = [bool]$Update.EulaAccepted
    }
}

function New-UpdateSession {
    $session = New-Object -ComObject Microsoft.Update.Session
    $session.ClientApplicationID = 'Windows 11 Firmware and Driver Maintenance'
    return $session
}

function Find-ApplicableUpdates {
    param($Session)
    Write-Log 'Scanning the policy-approved Windows Update source...'
    $searcher = $Session.CreateUpdateSearcher()
    $result = $searcher.Search("IsInstalled=0 and IsHidden=0")
    $selected = New-Object -ComObject Microsoft.Update.UpdateColl
    $report = @()

    foreach ($u in @($result.Updates)) {
        $identity = Get-UpdateIdentity $u
        $isPreview = $u.Title -match '(?i)preview'
        $isRelevant = ($u.Type -eq 'Driver') -or
                      ($identity.Categories -match '(?i)driver|firmware') -or
                      ($u.Title -match '(?i)firmware|BIOS|UEFI|embedded controller|management engine|driver')
        if ($isRelevant -and ($IncludePreview -or -not $isPreview)) {
            [void]$selected.Add($u)
            $report += $identity
        }
    }
    return [pscustomobject]@{ Collection=$selected; Report=$report; SearchResultCode=[int]$result.ResultCode }
}

function Install-UpdateCollection {
    param($Session,$Collection,[int]$Pass)
    if ($Collection.Count -eq 0) { return [pscustomobject]@{ RebootRequired=$false; Results=@() } }

    foreach ($u in @($Collection)) {
        if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch { Write-Log "Could not accept EULA for $($u.Title): $($_.Exception.Message)" WARN } }
    }

    Write-Log "Downloading $($Collection.Count) update(s) in pass $Pass..."
    $downloader = $Session.CreateUpdateDownloader()
    $downloader.Updates = $Collection
    $downloadResult = $downloader.Download()
    Write-Log "Download result code: $([int]$downloadResult.ResultCode)"

    $ready = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($u in @($Collection)) {
        if ($u.IsDownloaded) { [void]$ready.Add($u) }
        else { Write-Log "Not downloaded: $($u.Title)" WARN }
    }
    if ($ready.Count -eq 0) { return [pscustomobject]@{ RebootRequired=$false; Results=@() } }

    Write-Log "Installing $($ready.Count) downloaded update(s)..."
    $installer = $Session.CreateUpdateInstaller()
    $installer.Updates = $ready
    $result = $installer.Install()
    $items = for ($i=0; $i -lt $ready.Count; $i++) {
        $r = $result.GetUpdateResult($i)
        [pscustomobject]@{
            Pass=$Pass; Title=$ready.Item($i).Title; ResultCode=[int]$r.ResultCode
            HResult=('0x{0:X8}' -f ($r.HResult -band 0xffffffff)); RebootRequired=[bool]$r.RebootRequired
        }
    }
    return [pscustomobject]@{ RebootRequired=[bool]$result.RebootRequired; Results=$items }
}

try {
    Write-Log "Output folder: $root"
    if ([Environment]::OSVersion.Version.Build -lt 22000) { throw 'This script is intended for Windows 11 (build 22000 or later).' }
    if (-not $ForceOnBattery -and -not (Test-OnACPower)) { throw 'The machine is running on battery. Connect AC power or use -ForceOnBattery.' }

    Get-SystemSnapshot -Stage Before | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'System-Before.json') -Encoding UTF8
    Export-DeviceInventory -Stage Before

    $allFound = @()
    $allInstalled = @()
    $rebootRequired = $false

    for ($pass=1; $pass -le $MaxPasses; $pass++) {
        $session = New-UpdateSession
        $scan = Find-ApplicableUpdates -Session $session
        $scan.Report | ForEach-Object { $_ | Add-Member NoteProperty Pass $pass -Force; $allFound += $_ }
        $scan.Report | Export-Csv -Path (Join-Path $root "Available-Pass$pass.csv") -NoTypeInformation -Encoding UTF8

        if ($scan.Collection.Count -eq 0) { Write-Log "No applicable driver or firmware updates found in pass $pass." OK; break }
        Write-Log "Found $($scan.Collection.Count) applicable update(s) in pass $pass." OK
        foreach ($item in $scan.Report) { Write-Log ("Available: {0}" -f $item.Title) }

        if ($AuditOnly -or $WhatIfPreference) { Write-Log 'Audit-only/WhatIf mode: no updates will be installed.' WARN; break }
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"Install $($scan.Collection.Count) driver/firmware update(s)")) {
            $install = Install-UpdateCollection -Session $session -Collection $scan.Collection -Pass $pass
            $allInstalled += $install.Results
            if ($install.RebootRequired) { $rebootRequired = $true; Write-Log 'A restart is required before another reliable scan.' WARN; break }
        }
    }

    $allFound | Export-Csv -Path (Join-Path $root 'All-Applicable-Updates.csv') -NoTypeInformation -Encoding UTF8
    $allInstalled | Export-Csv -Path (Join-Path $root 'Installation-Results.csv') -NoTypeInformation -Encoding UTF8
    Get-SystemSnapshot -Stage After | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'System-After.json') -Encoding UTF8
    Export-DeviceInventory -Stage After

    $summary = [pscustomobject]@{
        Completed=(Get-Date).ToString('o'); Computer=$env:COMPUTERNAME; AuditOnly=[bool]$AuditOnly
        ApplicableRecords=$allFound.Count; InstallationRecords=$allInstalled.Count
        RebootRequired=$rebootRequired; OutputFolder=$root
        Note='Only updates approved and exposed by the configured Windows Update source can be installed.'
    }
    $summary | ConvertTo-Json | Set-Content (Join-Path $root 'Summary.json') -Encoding UTF8
    Write-Log ($summary | ConvertTo-Json -Compress) OK

    if ($rebootRequired) {
        if ($AutoReboot -and -not $AuditOnly) {
            Write-Log 'Restarting now because -AutoReboot was specified.' WARN
            Stop-Transcript | Out-Null
            Restart-Computer -Force
        } else {
            Write-Log 'Restart required. Re-run the script after restarting to detect follow-on updates.' WARN
        }
    }
}
catch {
    Write-Log $_.Exception.Message ERROR
    try { $_ | Out-String | Set-Content (Join-Path $root 'FatalError.txt') -Encoding UTF8 } catch {}
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
