<#
.SYNOPSIS
  Removes Google Chrome and common components (Google Update services/tasks, leftovers).
.DESCRIPTION
  - Stops Chrome / Google Update processes
  - Uninstalls Chrome via registry uninstall strings and/or setup.exe with --force-uninstall
  - Removes Google Update scheduled tasks + services (gupdate/gupdatem)
  - Deletes common install/update folders and user data (by default)
  - Cleans common registry keys
  - Backs up registry keys before deletion

.PARAMETER RemoveUserData
  Removes per-user Chrome profiles under %LOCALAPPDATA%\Google\Chrome for all local user profiles.
  This is ON by default. Use -RemoveUserData:$false to preserve user data.

.PARAMETER Force
  Skips the confirmation prompt. Useful for automated/silent execution.

.PARAMETER LogPath
  Path to a log file. If specified, a transcript of all actions will be saved.

.PARAMETER SkipBackup
  Skips the registry backup step before deletion.

.PARAMETER WhatIf
  Shows actions without executing destructive steps.

.PARAMETER Quiet
  Minimizes output - only shows step headers and final summary.

.EXAMPLE
  .\Remove-ChromeFully.ps1
  # Full cleanup including user data (default behavior)

.EXAMPLE
  .\Remove-ChromeFully.ps1 -RemoveUserData:$false
  # Remove Chrome but preserve user profiles/bookmarks

.EXAMPLE
  .\Remove-ChromeFully.ps1 -Force -LogPath "C:\Logs\chrome-removal.log"
  # Silent execution with logging

.EXAMPLE
  .\Remove-ChromeFully.ps1 -Force -Quiet
  # Minimal output for automation
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$RemoveUserData = $true,
    [switch]$Force,
    [string]$LogPath,
    [switch]$SkipBackup,
    [switch]$Quiet
)

# Script-level constants
$script:ChromeProcessNames = @(
    "chrome",
    "chrome_proxy",
    "googleupdate",
    "googlecrashhandler",
    "googlecrashhandler64",
    "updater",
    "gupdatem",
    "gupdate",
    "elevation_service",
    "software_reporter_tool",
    "nacl64",
    "notification_helper"
)

$script:GoogleServiceNames = @(
    "gupdate",
    "gupdatem", 
    "GoogleChromeElevationService",
    "GoogleUpdaterService*",
    "GoogleUpdaterInternalService*"
)

# Chrome product variants (Beta, Dev, Canary, etc.)
$script:ChromeVariants = @(
    "Google Chrome",
    "Google Chrome Beta",
    "Google Chrome Dev",
    "Google Chrome Canary",
    "Google Chrome SxS",
    "Chrome"
)

# Removal statistics tracking
$script:RemovalStats = @{
    ProcessesStopped    = 0
    UninstallsRun       = 0
    FoldersRemoved      = 0
    RegistryKeysRemoved = 0
    TasksRemoved        = 0
    ServicesRemoved     = 0
    ShortcutsRemoved    = 0
    UserProfilesRemoved = 0
    DataSizeRemovedMB   = 0
    Warnings            = 0
    Errors              = 0
}

# Timing
$script:StartTime = $null
$script:StepTimes = @{}
$script:TotalSteps = 8

function Assert-Admin {
    # Using #Requires -RunAsAdministrator is preferred, but keep this for extra safety
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "This script requires Administrator privileges. Please run PowerShell as Administrator."
    }
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Progress', 'Detail')]
        [string]$Type = 'Info',
        [int]$Indent = 0
    )
    
    # In Quiet mode, only show Info level at indent 0 and Success/Error
    if ($Quiet -and $Type -eq 'Progress') { return }
    if ($Quiet -and $Type -eq 'Detail') { return }
    if ($Quiet -and $Indent -gt 1) { return }
    
    $prefix = "  " * $Indent
    switch ($Type) {
        'Info' { Write-Host "${prefix}$Message" -ForegroundColor White }
        'Success' { Write-Host "${prefix}✓ $Message" -ForegroundColor Green }
        'Warning' { 
            Write-Host "${prefix}⚠ $Message" -ForegroundColor Yellow
            $script:RemovalStats.Warnings++
        }
        'Error' { 
            Write-Host "${prefix}✗ $Message" -ForegroundColor Red
            $script:RemovalStats.Errors++
        }
        'Progress' { Write-Host "${prefix}→ $Message" -ForegroundColor DarkGray }
        'Detail' { Write-Host "${prefix}  $Message" -ForegroundColor DarkGray }
    }
}

function Write-StepHeader {
    param(
        [int]$StepNumber,
        [int]$TotalSteps,
        [string]$Description,
        [string]$Icon = "🔧"
    )
    
    $percentComplete = if ($TotalSteps -gt 0) { [math]::Round(($StepNumber / $TotalSteps) * 100) } else { 0 }
    $progressBar = "[" + ("█" * [math]::Floor($percentComplete / 10)) + ("░" * (10 - [math]::Floor($percentComplete / 10))) + "]"
    
    Write-Host ""
    Write-Host "$Icon Step $StepNumber of ${TotalSteps}: $Description" -ForegroundColor Cyan
    if (-not $Quiet) {
        Write-Host "   $progressBar $percentComplete%" -ForegroundColor DarkCyan
    }
    Write-Host ("─" * 50) -ForegroundColor DarkGray
}

function Start-StepTimer {
    param([string]$StepName)
    $script:StepTimes[$StepName] = [System.Diagnostics.Stopwatch]::StartNew()
}

function Stop-StepTimer {
    param([string]$StepName)
    if ($script:StepTimes.ContainsKey($StepName)) {
        $script:StepTimes[$StepName].Stop()
        $elapsed = $script:StepTimes[$StepName].Elapsed.TotalSeconds
        if (-not $Quiet) {
            Write-Host "   ⏱ Completed in $([math]::Round($elapsed, 2))s" -ForegroundColor DarkGray
        }
    }
}

function Get-FormattedDuration {
    param([TimeSpan]$Duration)
    if ($Duration.TotalMinutes -ge 1) {
        return "{0:N0}m {1:N0}s" -f [math]::Floor($Duration.TotalMinutes), $Duration.Seconds
    }
    return "{0:N1}s" -f $Duration.TotalSeconds
}

function Start-Logging {
    if ($LogPath) {
        try {
            $logDir = Split-Path -Path $LogPath -Parent
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            Start-Transcript -Path $LogPath -Append -ErrorAction Stop
            Write-Verbose "Transcript logging started: $LogPath"
        } catch {
            Write-Warning "Failed to start transcript logging: $($_.Exception.Message)"
        }
    }
}

function Stop-Logging {
    if ($LogPath) {
        try {
            Stop-Transcript -ErrorAction SilentlyContinue
        } catch { }
    }
}

function Backup-RegistryKeys {
    if ($SkipBackup) {
        Write-Verbose "Skipping registry backup (-SkipBackup specified)"
        return
    }

    $backupDir = Join-Path $env:TEMP "ChromeRegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  
    try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
        $regPaths = @(
            "HKLM\SOFTWARE\Google",
            "HKLM\SOFTWARE\Wow6432Node\Google",
            "HKCU\SOFTWARE\Google"
        )
    
        $backedUp = 0
        foreach ($rp in $regPaths) {
            $safeName = ($rp -replace '\\', '_') -replace ':', ''
            $backupFile = Join-Path $backupDir "$safeName.reg"
      
            $null = reg query $rp 2>$null
            if ($LASTEXITCODE -eq 0) {
                reg export $rp $backupFile /y 2>$null | Out-Null
                if (Test-Path $backupFile) {
                    $backedUp++
                    Write-Verbose "Backed up: $rp -> $backupFile"
                }
            }
        }
    
        if ($backedUp -gt 0) {
            Write-Host "Registry backed up to: $backupDir" -ForegroundColor Green
        } else {
            Write-Verbose "No Google registry keys found to backup"
            Remove-Item -Path $backupDir -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Warning "Failed to backup registry: $($_.Exception.Message)"
    }
}

function Show-Summary {
    $totalDuration = if ($script:StartTime) { 
        (Get-Date) - $script:StartTime 
    } else { 
        [TimeSpan]::Zero 
    }
    
    # Calculate total items processed
    $totalItems = $script:RemovalStats.ProcessesStopped + 
    $script:RemovalStats.UninstallsRun + 
    $script:RemovalStats.ServicesRemoved +
    $script:RemovalStats.TasksRemoved +
    $script:RemovalStats.FoldersRemoved +
    $script:RemovalStats.RegistryKeysRemoved +
    $script:RemovalStats.ShortcutsRemoved +
    $script:RemovalStats.UserProfilesRemoved
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              CHROME REMOVAL SUMMARY                       ║" -ForegroundColor Cyan
    Write-Host "╠═══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    
    # Helper function for summary lines
    function Write-SummaryLine {
        param([string]$Label, [int]$Value, [int]$Width = 6)
        $icon = if ($Value -gt 0) { "✓" } else { "·" }
        $color = if ($Value -gt 0) { 'Green' } else { 'DarkGray' }
        Write-Host "║" -ForegroundColor Cyan -NoNewline
        Write-Host "  $icon $Label" -NoNewline -ForegroundColor $color
        Write-Host ("{0,$Width}" -f $Value) -ForegroundColor White -NoNewline
        $padding = 59 - 5 - $Label.Length - $Width
        Write-Host (" " * $padding) -NoNewline
        Write-Host "║" -ForegroundColor Cyan
    }
    
    Write-SummaryLine "Processes Stopped:     " $script:RemovalStats.ProcessesStopped
    Write-SummaryLine "Uninstalls Executed:   " $script:RemovalStats.UninstallsRun
    Write-SummaryLine "Services Removed:      " $script:RemovalStats.ServicesRemoved
    Write-SummaryLine "Scheduled Tasks:       " $script:RemovalStats.TasksRemoved
    Write-SummaryLine "Folders Removed:       " $script:RemovalStats.FoldersRemoved
    Write-SummaryLine "Registry Keys Removed: " $script:RemovalStats.RegistryKeysRemoved
    Write-SummaryLine "Shortcuts Removed:     " $script:RemovalStats.ShortcutsRemoved
    Write-SummaryLine "User Profiles Removed: " $script:RemovalStats.UserProfilesRemoved
    
    # Data size if applicable
    if ($script:RemovalStats.DataSizeRemovedMB -gt 0) {
        $sizeDisplay = if ($script:RemovalStats.DataSizeRemovedMB -gt 1024) {
            "{0:N1} GB" -f ($script:RemovalStats.DataSizeRemovedMB / 1024)
        } else {
            "{0:N0} MB" -f $script:RemovalStats.DataSizeRemovedMB
        }
        Write-Host "║" -ForegroundColor Cyan -NoNewline
        Write-Host "  💾 Disk Space Freed:    " -NoNewline -ForegroundColor Green
        Write-Host ("{0,-10}" -f $sizeDisplay) -ForegroundColor White -NoNewline
        Write-Host "                        ║" -ForegroundColor Cyan
    }
    
    Write-Host "╠═══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    
    # Totals row
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host "  Total Items Processed:   " -NoNewline
    Write-Host ("{0,-6}" -f $totalItems) -ForegroundColor White -NoNewline
    Write-Host "                          ║" -ForegroundColor Cyan
    
    # Warnings and Errors
    $warnColor = if ($script:RemovalStats.Warnings -gt 0) { 'Yellow' } else { 'Green' }
    $errColor = if ($script:RemovalStats.Errors -gt 0) { 'Red' } else { 'Green' }
    
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host "  Warnings: " -NoNewline
    Write-Host ("{0,-4}" -f $script:RemovalStats.Warnings) -ForegroundColor $warnColor -NoNewline
    Write-Host "   Errors: " -NoNewline
    Write-Host ("{0,-4}" -f $script:RemovalStats.Errors) -ForegroundColor $errColor -NoNewline
    Write-Host "                   ║" -ForegroundColor Cyan
    
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host "  Total Duration:          " -NoNewline
    Write-Host ("{0,-10}" -f (Get-FormattedDuration $totalDuration)) -ForegroundColor White -NoNewline
    Write-Host "                      ║" -ForegroundColor Cyan
    
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Show backup location if created
    $backupDirs = Get-ChildItem -Path $env:TEMP -Directory -Filter "ChromeRegistryBackup_*" -ErrorAction SilentlyContinue | 
    Sort-Object CreationTime -Descending | Select-Object -First 1
    if ($backupDirs) {
        Write-Host ""
        Write-Host "📁 Registry backup saved to:" -ForegroundColor DarkCyan
        Write-Host "   $($backupDirs.FullName)" -ForegroundColor Gray
        Write-Host "   To restore: reg import <file.reg>" -ForegroundColor DarkGray
    }
}

function Show-PreflightCheck {
    <#
    .SYNOPSIS
        Shows a discovery summary of what will be removed before taking action.
    #>
    Write-Host ""
    Write-Host "┌─────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "│  🔍 PRE-FLIGHT DISCOVERY                                │" -ForegroundColor Yellow
    Write-Host "└─────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    
    $discoveryItems = @{
        Processes       = 0
        Installations   = 0
        Services        = 0
        Tasks           = 0
        Folders         = 0
        UserProfiles    = 0
        EstimatedSizeMB = 0
    }
    
    # Check processes
    foreach ($processName in $script:ChromeProcessNames) {
        $procs = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($procs) { $discoveryItems.Processes += @($procs).Count }
    }
    
    # Check installations
    $variantPattern = ($script:ChromeVariants | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($p in $uninstallPaths) {
        $entries = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -and ($_.DisplayName -match $variantPattern) }
        if ($entries) { $discoveryItems.Installations += @($entries).Count }
    }
    
    # Check services
    foreach ($serviceName in $script:GoogleServiceNames) {
        if ($serviceName -match '\*') {
            $svcs = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($svcs) { $discoveryItems.Services += @($svcs).Count }
        } else {
            $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($svc) { $discoveryItems.Services++ }
        }
    }
    
    # Check scheduled tasks
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | 
    Where-Object { $_.TaskName -like "GoogleUpdateTask*" -or $_.TaskPath -like "\Google*" }
    if ($tasks) { $discoveryItems.Tasks = @($tasks).Count }
    
    # Check folders (quick scan)
    $chromeSubfolders = @("Chrome", "Chrome Beta", "Chrome Dev", "Chrome SxS", "Update")
    foreach ($subfolder in $chromeSubfolders) {
        if (Test-Path "$env:ProgramFiles\Google\$subfolder") { $discoveryItems.Folders++ }
        if (Test-Path "${env:ProgramFiles(x86)}\Google\$subfolder") { $discoveryItems.Folders++ }
    }
    
    # Check user profiles and estimate size
    if ($RemoveUserData) {
        $systemProfiles = @("Public", "Default", "Default User", "All Users")
        $userRoots = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $systemProfiles -and -not $_.Name.StartsWith(".") }
        
        foreach ($u in $userRoots) {
            foreach ($variant in @("Chrome", "Chrome Beta", "Chrome Dev", "Chrome SxS")) {
                $localPath = Join-Path $u.FullName "AppData\Local\Google\$variant"
                if (Test-Path $localPath) {
                    $discoveryItems.UserProfiles++
                    # Estimate size (quick method - get first level size estimation)
                    $size = (Get-ChildItem $localPath -Recurse -File -ErrorAction SilentlyContinue | 
                        Select-Object -First 1000 | Measure-Object -Property Length -Sum).Sum
                    $discoveryItems.EstimatedSizeMB += [math]::Round($size / 1MB, 0)
                }
            }
        }
    }
    
    # Display discovery results
    Write-Host "   Processes running:      $($discoveryItems.Processes)" -ForegroundColor $(if ($discoveryItems.Processes -gt 0) { 'White' } else { 'DarkGray' })
    Write-Host "   Installations found:    $($discoveryItems.Installations)" -ForegroundColor $(if ($discoveryItems.Installations -gt 0) { 'White' } else { 'DarkGray' })
    Write-Host "   Services found:         $($discoveryItems.Services)" -ForegroundColor $(if ($discoveryItems.Services -gt 0) { 'White' } else { 'DarkGray' })
    Write-Host "   Scheduled tasks:        $($discoveryItems.Tasks)" -ForegroundColor $(if ($discoveryItems.Tasks -gt 0) { 'White' } else { 'DarkGray' })
    Write-Host "   Installation folders:   $($discoveryItems.Folders)" -ForegroundColor $(if ($discoveryItems.Folders -gt 0) { 'White' } else { 'DarkGray' })
    
    if ($RemoveUserData) {
        Write-Host "   User profiles:          $($discoveryItems.UserProfiles)" -ForegroundColor $(if ($discoveryItems.UserProfiles -gt 0) { 'White' } else { 'DarkGray' })
        if ($discoveryItems.EstimatedSizeMB -gt 0) {
            $sizeDisplay = if ($discoveryItems.EstimatedSizeMB -gt 1024) {
                "{0:N1} GB+" -f ($discoveryItems.EstimatedSizeMB / 1024)
            } else {
                "{0:N0} MB+" -f $discoveryItems.EstimatedSizeMB
            }
            Write-Host "   Estimated data size:    $sizeDisplay" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   User profiles:          (preserved)" -ForegroundColor Green
    }
    
    $totalItems = $discoveryItems.Processes + $discoveryItems.Installations + $discoveryItems.Services + 
    $discoveryItems.Tasks + $discoveryItems.Folders + $discoveryItems.UserProfiles
    
    if ($totalItems -eq 0) {
        Write-Host ""
        Write-Host "   ℹ️  No Chrome components detected on this system." -ForegroundColor Green
        return $false
    }
    
    Write-Host ""
    return $true
}

function Stop-Processes {
    $foundProcesses = @()
    
    foreach ($processName in $script:ChromeProcessNames) {
        $procs = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($procs) {
            $foundProcesses += $procs
        }
    }
    
    # De-duplicate by PID (in case multiple names match same process)
    $foundProcesses = $foundProcesses | Sort-Object Id -Unique
    
    if ($foundProcesses.Count -eq 0) {
        Write-Status "No Chrome-related processes running" -Type Progress -Indent 1
        return
    }
    
    Write-Status "Found $($foundProcesses.Count) process(es) to terminate" -Type Info -Indent 1
    
    # Group by process name for cleaner output
    $groupedProcesses = $foundProcesses | Group-Object Name
    
    foreach ($group in $groupedProcesses) {
        Write-Status "$($group.Name): $($group.Count) instance(s)" -Type Progress -Indent 2
        
        foreach ($proc in $group.Group) {
            if ($PSCmdlet.ShouldProcess("$($proc.Name) (PID $($proc.Id))", "Stop-Process")) {
                try {
                    # Use taskkill for more forceful termination with tree kill
                    $null = & taskkill.exe /F /T /PID $proc.Id 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $script:RemovalStats.ProcessesStopped++
                    } else {
                        # Fallback to Stop-Process
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                        $script:RemovalStats.ProcessesStopped++
                    }
                } catch {
                    Write-Status "Failed to stop PID $($proc.Id): $($_.Exception.Message)" -Type Warning -Indent 3
                }
            }
        }
    }
    
    # Brief wait for processes to fully terminate
    Start-Sleep -Milliseconds 750
}

function Get-ChromeUninstallEntries {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    # Build regex pattern from variants
    $variantPattern = ($script:ChromeVariants | ForEach-Object { [regex]::Escape($_) }) -join '|'
    
    $entries = foreach ($p in $paths) {
        Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -and ($_.DisplayName -match $variantPattern)
        } |
        Select-Object DisplayName, DisplayVersion, UninstallString, QuietUninstallString, PSPath, @{
            Name       = 'InstallLocation'
            Expression = { $_.InstallLocation }
        }
    }

    # De-dup by uninstall string + displayname
    $result = $entries | Sort-Object DisplayName, UninstallString -Unique
    
    if ($result) {
        Write-Status "Found $(@($result).Count) Chrome installation(s) in registry" -Type Info -Indent 1
        foreach ($entry in $result) {
            Write-Status "$($entry.DisplayName) v$($entry.DisplayVersion)" -Type Progress -Indent 2
        }
    }
    
    return $result
}

function Invoke-ChromeSetupUninstall {
    param(
        [Parameter(Mandatory = $true)][string]$SetupExe,
        [string[]]$Arguments
    )
    if (-not (Test-Path $SetupExe)) { 
        Write-Verbose "Setup executable not found: $SetupExe"
        return $false 
    }

    $argLine = ($Arguments -join " ")
    Write-Verbose "Running: `"$SetupExe`" $argLine"
    if ($PSCmdlet.ShouldProcess($SetupExe, "Start-Process $argLine")) {
        try {
            $p = Start-Process -FilePath $SetupExe -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            $script:RemovalStats.UninstallsRun++
            if ($p.ExitCode -eq 0) {
                Write-Verbose "Uninstall completed successfully (exit code 0)"
                return $true
            } else {
                Write-Warning "Uninstall completed with exit code: $($p.ExitCode)"
                return $false
            }
        } catch {
            Write-Warning "Failed to run uninstaller: $($_.Exception.Message)"
            return $false
        }
    }
    return $true
}

function Uninstall-Chrome {
    $entries = Get-ChromeUninstallEntries
    if (-not $entries) {
        Write-Status "No Chrome uninstall entries found in registry" -Type Progress -Indent 1
        Write-Status "Will attempt folder-based removal..." -Type Progress -Indent 1
    }

    foreach ($e in $entries) {
        $u = $e.QuietUninstallString
        if ([string]::IsNullOrWhiteSpace($u)) { $u = $e.UninstallString }

        if ([string]::IsNullOrWhiteSpace($u)) { continue }

        # Common case: uninstall string points to setup.exe in versioned Installer folder.
        # Example flags commonly used: --uninstall --multi-install/--msi --system-level --force-uninstall [1](https://learn.microsoft.com/en-us/answers/questions/523822/how-to-uninstall-google-chrome-using-command-line)[2](https://support.google.com/chrome/thread/311416788/silent-uninstall-for-google-chrome-enterprise?hl=en)
        if ($u -match "setup\.exe") {
            # Extract EXE path (handles quotes)
            $exe = $null
            if ($u -match '^\s*"(.*?)"\s*(.*)$') { $exe = $matches[1]; $rest = $matches[2] }
            else {
                $parts = $u.Split(" ", 2)
                $exe = $parts[0]
                $rest = if ($parts.Count -gt 1) { $parts[1] } else { "" }
            }

            # Build arguments: keep existing args and ensure force-uninstall
            $uninstallArgs = @()
            if (-not [string]::IsNullOrWhiteSpace($rest)) {
                # naive split respecting quotes is overkill; for typical chrome args this works well
                $uninstallArgs += ($rest -split '\s+(?=(?:[^"]*"[^"]*")*[^"]*$)') | Where-Object { $_ -ne "" }
            }
            if ($uninstallArgs -notcontains "--force-uninstall" -and $uninstallArgs -notcontains "--force_uninstall") {
                $uninstallArgs += "--force-uninstall"
            }

            Write-Verbose "Uninstalling via setup.exe for: $($e.DisplayName) $($e.DisplayVersion)"
            [void](Invoke-ChromeSetupUninstall -SetupExe $exe -Arguments $uninstallArgs)
            continue
        }

        # MSI case: msiexec /x {GUID}
        if ($u -match "MsiExec\.exe" -or $u -match "msiexec") {
            # Try to extract product code {GUID}
            $guid = ($u | Select-String -Pattern '\{[0-9A-Fa-f\-]{36}\}' -AllMatches).Matches.Value | Select-Object -First 1
            if ($guid) {
                $msiArgs = "/x $guid /qn /norestart"
                Write-Verbose "Uninstalling MSI for: $($e.DisplayName) $($e.DisplayVersion) ($guid)"
                if ($PSCmdlet.ShouldProcess("msiexec.exe", "$msiArgs")) {
                    try {
                        $p = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                        $script:RemovalStats.UninstallsRun++
                        if ($p.ExitCode -ne 0) {
                            Write-Warning "MSI uninstall returned exit code: $($p.ExitCode)"
                        }
                    } catch {
                        Write-Warning "Failed to run MSI uninstall: $($_.Exception.Message)"
                    }
                }
            }
            continue
        }

        Write-Warning "Skipping unknown uninstall string format for $($e.DisplayName): $u"
    }

    # Folder-based fallback: locate setup.exe under common install roots and run standard uninstall args.
    # Known working pattern: setup.exe --uninstall --multi-install --chrome --msi --system-level --verbose-logging --force-uninstall
    $candidateRoots = @(
        "$env:ProgramFiles\Google\Chrome\Application",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application"
    ) | Where-Object { Test-Path $_ }

    foreach ($root in $candidateRoots) {
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $setup = Join-Path $_.FullName "Installer\setup.exe"
            if (Test-Path $setup) {
                $fallbackArgs = @("--uninstall", "--chrome", "--msi", "--system-level", "--verbose-logging", "--force-uninstall")
                Write-Verbose "Fallback uninstall via: $setup"
                [void](Invoke-ChromeSetupUninstall -SetupExe $setup -Arguments $fallbackArgs)
            }
        }
    }
}

function Remove-GoogleUpdateTasks {
    # Google Update tasks often start with GoogleUpdateTask*
    try {
        $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -like "GoogleUpdateTask*" -or $_.TaskPath -like "\Google*" })
        
        if ($tasks.Count -eq 0) {
            Write-Status "No Google scheduled tasks found" -Type Progress -Indent 1
            return
        }
        
        Write-Status "Found $($tasks.Count) scheduled task(s) to remove" -Type Info -Indent 1
        
        foreach ($t in $tasks) {
            if ($PSCmdlet.ShouldProcess("$($t.TaskPath)$($t.TaskName)", "Unregister-ScheduledTask")) {
                try {
                    Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false -ErrorAction Stop
                    $script:RemovalStats.TasksRemoved++
                    Write-Status "Removed: $($t.TaskName)" -Type Progress -Indent 2
                } catch {
                    Write-Status "Failed to remove task $($t.TaskName): $($_.Exception.Message)" -Type Warning -Indent 2
                }
            }
        }
    } catch {
        Write-Status "Failed to enumerate scheduled tasks: $($_.Exception.Message)" -Type Warning -Indent 1
    }
}

function Remove-GoogleUpdateServices {
    $foundServices = @()
    
    foreach ($serviceName in $script:GoogleServiceNames) {
        # Support wildcard patterns in service names
        if ($serviceName -match '\*') {
            $svcs = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($svcs) { $foundServices += $svcs }
        } else {
            $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($svc) { $foundServices += $svc }
        }
    }
    
    # De-duplicate by service name
    $foundServices = $foundServices | Sort-Object Name -Unique
    
    if ($foundServices.Count -eq 0) {
        Write-Status "No Google services found" -Type Progress -Indent 1
        return
    }
    
    Write-Status "Found $($foundServices.Count) service(s) to remove" -Type Info -Indent 1
    
    foreach ($svc in $foundServices) {
        $serviceName = $svc.Name
        
        if ($PSCmdlet.ShouldProcess($serviceName, "Stop-Service")) {
            try { 
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Status "Stopped: $serviceName" -Type Progress -Indent 2
            } catch {
                Write-Status "Failed to stop ${serviceName}: $($_.Exception.Message)" -Type Warning -Indent 2
            }
        }
        
        if ($PSCmdlet.ShouldProcess($serviceName, "Delete service")) {
            $scResult = & sc.exe delete $serviceName 2>&1
            if ($LASTEXITCODE -eq 0) {
                $script:RemovalStats.ServicesRemoved++
                Write-Status "Deleted: $serviceName" -Type Success -Indent 2
            } else {
                Write-Status "Failed to delete ${serviceName}: $scResult" -Type Warning -Indent 2
            }
        }
    }
}

function Remove-LeftoverFolders {
    # All Chrome variant folders including Beta, Dev, Canary
    $chromeSubfolders = @("Chrome", "Chrome Beta", "Chrome Dev", "Chrome SxS", "Update", "CrashReports")
    
    $allPaths = @()
    foreach ($subfolder in $chromeSubfolders) {
        $allPaths += "$env:ProgramFiles\Google\$subfolder"
        $allPaths += "${env:ProgramFiles(x86)}\Google\$subfolder"
        $allPaths += "$env:ProgramData\Google\$subfolder"
    }
    
    # Add temp folders that Chrome uses
    $allPaths += "$env:TEMP\scoped_dir*"
    $allPaths += "$env:TEMP\chrome_*"
    
    # Filter to existing paths
    $paths = @()
    foreach ($p in $allPaths) {
        if ($p -match '\*') {
            # Wildcard path - resolve it
            $resolved = Get-ChildItem -Path (Split-Path $p) -Filter (Split-Path $p -Leaf) -ErrorAction SilentlyContinue
            $paths += $resolved.FullName
        } elseif ($p -and (Test-Path $p)) {
            $paths += $p
        }
    }
    
    if ($paths.Count -eq 0) {
        Write-Status "No leftover folders found" -Type Progress -Indent 1
    } else {
        Write-Status "Found $($paths.Count) folder(s) to remove" -Type Info -Indent 1
        
        foreach ($p in $paths) {
            if ($PSCmdlet.ShouldProcess($p, "Remove-Item -Recurse -Force")) {
                try { 
                    Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
                    $script:RemovalStats.FoldersRemoved++
                    $shortName = $p -replace [regex]::Escape($env:ProgramFiles), '%ProgramFiles%' `
                        -replace [regex]::Escape(${env:ProgramFiles(x86)}), '%ProgramFiles(x86)%' `
                        -replace [regex]::Escape($env:ProgramData), '%ProgramData%' `
                        -replace [regex]::Escape($env:TEMP), '%TEMP%'
                    Write-Status "Removed: $shortName" -Type Progress -Indent 2
                } catch {
                    Write-Status "Failed to remove ${p}: $($_.Exception.Message)" -Type Warning -Indent 2
                }
            }
        }
    }

    # Common shortcuts (include all Chrome variants)
    $shortcutPaths = @()
    foreach ($variant in $script:ChromeVariants) {
        $shortcutPaths += "$env:Public\Desktop\$variant.lnk"
        $shortcutPaths += "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$variant.lnk"
        $shortcutPaths += "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$variant"
    }
    
    $existingShortcuts = $shortcutPaths | Where-Object { Test-Path $_ }
    
    if ($existingShortcuts.Count -gt 0) {
        Write-Status "Removing $($existingShortcuts.Count) shortcut(s)" -Type Info -Indent 1
        
        foreach ($sp in $existingShortcuts) {
            if ($PSCmdlet.ShouldProcess($sp, "Remove shortcut/folder")) {
                try {
                    Remove-Item -Path $sp -Recurse -Force -ErrorAction Stop
                    $script:RemovalStats.ShortcutsRemoved++
                    Write-Status "Removed: $(Split-Path $sp -Leaf)" -Type Progress -Indent 2
                } catch {
                    Write-Status "Failed to remove shortcut: $($_.Exception.Message)" -Type Warning -Indent 2
                }
            }
        }
    }
}

function Remove-RegistryLeftovers {
    $regPaths = @(
        "HKLM:\SOFTWARE\Google",
        "HKLM:\SOFTWARE\Wow6432Node\Google",
        "HKCU:\SOFTWARE\Google",
        "HKCU:\SOFTWARE\Wow6432Node\Google",
        "HKLM:\SOFTWARE\Policies\Google\Chrome",
        "HKCU:\SOFTWARE\Policies\Google\Chrome"
    )
    
    $existingKeys = $regPaths | Where-Object { Test-Path $_ }
    
    if ($existingKeys.Count -eq 0) {
        Write-Status "No Google registry keys found" -Type Progress -Indent 1
    } else {
        Write-Status "Found $($existingKeys.Count) registry key(s) to remove" -Type Info -Indent 1
        
        foreach ($rp in $existingKeys) {
            if ($PSCmdlet.ShouldProcess($rp, "Remove-Item -Recurse -Force")) {
                try {
                    Remove-Item -Path $rp -Recurse -Force -ErrorAction Stop
                    $script:RemovalStats.RegistryKeysRemoved++
                    $shortPath = $rp -replace 'HKLM:\\', 'HKLM\' -replace 'HKCU:\\', 'HKCU\'
                    Write-Status "Removed: $shortPath" -Type Progress -Indent 2
                } catch {
                    Write-Status "Failed to remove ${rp}: $($_.Exception.Message)" -Type Warning -Indent 2
                }
            }
        }
    }

    # Attempt to remove per-user keys for loaded profiles (HKU:\S-1-5-21-*)
    Write-Status "Scanning other user profiles..." -Type Progress -Indent 1
    
    try {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
        $userKeys = Get-ChildItem HKU:\ -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'S-1-5-21-' -and $_.Name -notmatch '_Classes$' }
        
        $perUserCount = 0
        foreach ($userKey in $userKeys) {
            $k = Join-Path $userKey.PSPath "Software\Google"
            if (Test-Path $k) {
                if ($PSCmdlet.ShouldProcess($k, "Remove per-user Google registry key")) {
                    try {
                        Remove-Item -Path $k -Recurse -Force -ErrorAction Stop
                        $script:RemovalStats.RegistryKeysRemoved++
                        $perUserCount++
                    } catch {
                        Write-Status "Failed to remove per-user key: $($_.Exception.Message)" -Type Warning -Indent 2
                    }
                }
            }
        }
        
        if ($perUserCount -gt 0) {
            Write-Status "Removed $perUserCount per-user registry key(s)" -Type Success -Indent 2
        }
    } catch {
        Write-Status "Could not access other user profiles: $($_.Exception.Message)" -Type Warning -Indent 2
    }
}

function Remove-UserDataIfRequested {
    if (-not $RemoveUserData) { 
        Write-Status "User data preservation enabled - skipping profile removal" -Type Progress -Indent 1
        return 
    }

    # Remove Chrome user profiles from each user under C:\Users (best-effort)
    $systemProfiles = @("Public", "Default", "Default User", "All Users")
    $userRoots = @(Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.Name -notin $systemProfiles -and 
            -not $_.Name.StartsWith(".") -and
            (Test-Path (Join-Path $_.FullName "NTUSER.DAT"))
        })
    
    if ($userRoots.Count -eq 0) {
        Write-Status "No user profiles found to clean" -Type Progress -Indent 1
        return
    }
    
    Write-Status "Scanning $($userRoots.Count) user profile(s)" -Type Info -Indent 1
    
    # Chrome variant data folders
    $chromeDataFolders = @("Chrome", "Chrome Beta", "Chrome Dev", "Chrome SxS")
    
    foreach ($u in $userRoots) {
        foreach ($variant in $chromeDataFolders) {
            # Local AppData
            $localPath = Join-Path $u.FullName "AppData\Local\Google\$variant"
            if (Test-Path $localPath) {
                if ($PSCmdlet.ShouldProcess($localPath, "Remove-Item -Recurse -Force")) {
                    try {
                        # Calculate size before removal (for reporting)
                        $size = (Get-ChildItem $localPath -Recurse -File -ErrorAction SilentlyContinue | 
                            Measure-Object -Property Length -Sum).Sum
                        $sizeMB = [math]::Round($size / 1MB, 1)
                        
                        Remove-Item -Path $localPath -Recurse -Force -ErrorAction Stop
                        $script:RemovalStats.UserProfilesRemoved++
                        $script:RemovalStats.DataSizeRemovedMB += $sizeMB
                        Write-Status "$($u.Name): $variant (${sizeMB}MB)" -Type Progress -Indent 2
                    } catch {
                        Write-Status "Failed: $($u.Name)\$variant - $($_.Exception.Message)" -Type Warning -Indent 2
                    }
                }
            }
            
            # Roaming AppData
            $roamingPath = Join-Path $u.FullName "AppData\Roaming\Google\$variant"
            if (Test-Path $roamingPath) {
                if ($PSCmdlet.ShouldProcess($roamingPath, "Remove-Item -Recurse -Force")) {
                    try {
                        $roamingSize = (Get-ChildItem $roamingPath -Recurse -File -ErrorAction SilentlyContinue | 
                            Measure-Object -Property Length -Sum).Sum
                        Remove-Item -Path $roamingPath -Recurse -Force -ErrorAction Stop
                        $script:RemovalStats.DataSizeRemovedMB += [math]::Round($roamingSize / 1MB, 1)
                        Write-Status "$($u.Name): $variant (roaming)" -Type Progress -Indent 2
                    } catch {
                        Write-Status "Failed roaming data: $($_.Exception.Message)" -Type Warning -Indent 2
                    }
                }
            }
        }
        
        # Chrome extension shortcuts in AppData\Local\Google\Chrome User Data (already removed above)
        # But let's clean crash reports too
        $crashReports = Join-Path $u.FullName "AppData\Local\Google\CrashReports"
        if (Test-Path $crashReports) {
            if ($PSCmdlet.ShouldProcess($crashReports, "Remove crash reports")) {
                try {
                    Remove-Item -Path $crashReports -Recurse -Force -ErrorAction Stop
                    Write-Status "$($u.Name): Crash reports" -Type Progress -Indent 2
                } catch { }
            }
        }
    }
}

# ===================== MAIN =====================
try {
    Assert-Admin
    Start-Logging
    $script:StartTime = Get-Date
    
    # Banner (skip in quiet mode)
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
        Write-Host "║     🧹  GOOGLE CHROME COMPLETE REMOVAL TOOL  🧹           ║" -ForegroundColor Magenta
        Write-Host "║         Removes Chrome, Updates, and User Data            ║" -ForegroundColor Magenta
        Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    } else {
        Write-Host "Chrome Removal Tool - Starting..." -ForegroundColor Cyan
    }

    # Pre-flight discovery (shows what will be removed)
    if (-not $Quiet) {
        $hasComponents = Show-PreflightCheck
        if (-not $hasComponents -and -not $WhatIfPreference) {
            Write-Host "Nothing to remove. Exiting." -ForegroundColor Green
            exit 0
        }
    }

    # Confirmation prompt unless -Force or -WhatIf
    if (-not $Force -and -not $WhatIfPreference) {
        Write-Host ""
        Write-Host "⚠️  WARNING" -ForegroundColor Yellow
        Write-Host "   This will completely remove Google Chrome and all related components:" -ForegroundColor Yellow
        Write-Host "   • All Chrome installations (Stable, Beta, Dev, Canary)" -ForegroundColor White
        Write-Host "   • Google Update services and scheduled tasks" -ForegroundColor White
        Write-Host "   • Registry entries and shortcuts" -ForegroundColor White
        if ($RemoveUserData) {
            Write-Host "   • User profiles, bookmarks, passwords, and browsing data" -ForegroundColor Red
        } else {
            Write-Host "   • User data will be PRESERVED" -ForegroundColor Green
        }
        Write-Host ""
        $confirm = Read-Host "Are you sure you want to continue? (Y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Host ""
            Write-Host "❌ Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "┌─────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
        Write-Host "│  Configuration                                      │" -ForegroundColor DarkCyan
        Write-Host "├─────────────────────────────────────────────────────┤" -ForegroundColor DarkCyan
        $rmUserDataIcon = if ($RemoveUserData) { "🗑️  Yes" } else { "💾 No" }
        $skipBackupIcon = if ($SkipBackup) { "⏭️  Yes" } else { "💾 No" }
        $whatIfIcon = if ($WhatIfPreference) { "👁️  Yes (DRY RUN)" } else { "🔧 No" }
        Write-Host "│  Remove User Data:  $rmUserDataIcon" -ForegroundColor DarkCyan
        Write-Host "│  Skip Backup:       $skipBackupIcon" -ForegroundColor DarkCyan
        Write-Host "│  WhatIf Mode:       $whatIfIcon" -ForegroundColor DarkCyan
        Write-Host "└─────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
    }

    # Backup registry before making changes
    if (-not $SkipBackup) {
        Write-StepHeader -StepNumber 0 -TotalSteps 8 -Description "Backing up registry" -Icon "💾"
        Start-StepTimer "Backup"
        Backup-RegistryKeys
        Stop-StepTimer "Backup"
    }

    # Step 1: Stop processes
    Write-StepHeader -StepNumber 1 -TotalSteps 8 -Description "Stopping Chrome processes" -Icon "⏹️"
    Start-StepTimer "StopProcesses1"
    Stop-Processes
    Stop-StepTimer "StopProcesses1"

    # Step 2: Run uninstallers
    Write-StepHeader -StepNumber 2 -TotalSteps 8 -Description "Running Chrome uninstallers" -Icon "🗑️"
    Start-StepTimer "Uninstall"
    Uninstall-Chrome
    Stop-StepTimer "Uninstall"

    # Step 3: Stop remaining processes
    Write-StepHeader -StepNumber 3 -TotalSteps 8 -Description "Stopping remaining processes" -Icon "⏹️"
    Start-StepTimer "StopProcesses2"
    Stop-Processes
    Stop-StepTimer "StopProcesses2"

    # Step 4: Remove scheduled tasks
    Write-StepHeader -StepNumber 4 -TotalSteps 8 -Description "Removing scheduled tasks" -Icon "📅"
    Start-StepTimer "Tasks"
    Remove-GoogleUpdateTasks
    Stop-StepTimer "Tasks"

    # Step 5: Remove services
    Write-StepHeader -StepNumber 5 -TotalSteps 8 -Description "Removing Google services" -Icon "⚙️"
    Start-StepTimer "Services"
    Remove-GoogleUpdateServices
    Stop-StepTimer "Services"

    # Step 6: Remove folders
    Write-StepHeader -StepNumber 6 -TotalSteps 8 -Description "Removing installation folders" -Icon "📁"
    Start-StepTimer "Folders"
    Remove-LeftoverFolders
    Stop-StepTimer "Folders"

    # Step 7: Clean registry
    Write-StepHeader -StepNumber 7 -TotalSteps 8 -Description "Cleaning registry entries" -Icon "🔑"
    Start-StepTimer "Registry"
    Remove-RegistryLeftovers
    Stop-StepTimer "Registry"

    # Step 8: User data
    Write-StepHeader -StepNumber 8 -TotalSteps 8 -Description "Processing user data" -Icon "👤"
    Start-StepTimer "UserData"
    Remove-UserDataIfRequested
    Stop-StepTimer "UserData"

    # Summary
    Show-Summary

    # Final message
    Write-Host ""
    if ($script:RemovalStats.Errors -gt 0) {
        Write-Host "⚠️  Completed with $($script:RemovalStats.Errors) error(s). Review warnings above." -ForegroundColor Yellow
    } else {
        Write-Host "✅ Chrome removal completed successfully!" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "💡 Recommendation: Restart your computer to release any locked files." -ForegroundColor Cyan
    Write-Host ""
  
} catch {
    Write-Host ""
    Write-Host "❌ SCRIPT FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Line:  $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor DarkGray
    exit 1
} finally {
    Stop-Logging
}