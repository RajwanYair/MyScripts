param(
    [string]$WorkspaceRoot,
    [string]$WorkspaceBootstrap,
    [switch]$SkipWorkspaceBootstrap,
    [switch]$LoadMsvcEnv,
    [string]$MsvcToolsetVersion = '14.50.35717'
)

$ErrorActionPreference = 'Stop'

# Apply this for all sessions, even if the bootstrap has already run.
$env:MSBUILDDISABLENODEREUSE = '1'

function Add-PathEntry {
    param([string]$Dir)

    $resolved = [System.Environment]::ExpandEnvironmentVariables($Dir)
    if (-not (Test-Path $resolved -PathType Container)) {
        return
    }

    $current = $env:PATH -split ';'
    if ($current -notcontains $resolved) {
        $env:PATH = "$resolved;$env:PATH"
    }
}

function Import-MsvcEnvironment {
    param([string]$ToolsetVersion)

    $vcvarsPath = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path $vcvarsPath -PathType Leaf)) {
        return
    }

    $vcvarsOutput = cmd /c "\"$vcvarsPath\" -vcvars_ver=$ToolsetVersion >nul 2>&1 && set"
    foreach ($line in $vcvarsOutput) {
        if ($line -match '^(.+?)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
}

if ($LoadMsvcEnv) {
    Import-MsvcEnvironment -ToolsetVersion $MsvcToolsetVersion
}

if ($env:MYSCRIPTS_COMMON_TOOLS_LOADED -ne '1') {
    Add-PathEntry "$env:USERPROFILE\scoop\shims"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\git\current\bin"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\git\current\cmd"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\git\current\usr\bin"
    Add-PathEntry "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64"
    Add-PathEntry "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\amd64"
    Add-PathEntry "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64"
    Add-PathEntry "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\vcpkg"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\cmake\current\bin"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\nuget\current"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\mingw\current\bin"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\llvm\current\bin"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\perl\current\perl\bin"
    Add-PathEntry "$env:PROGRAMFILES\PowerShell\7"
    Add-PathEntry "$env:PROGRAMFILES\dotnet"
    Add-PathEntry "$env:USERPROFILE\.dotnet\tools"
    Add-PathEntry "$env:LOCALAPPDATA\Python\bin"
    Add-PathEntry "$env:LOCALAPPDATA\Programs\Python\Python314\Scripts"
    Add-PathEntry "$env:LOCALAPPDATA\Programs\Python\Python313\Scripts"
    # Python user scripts (ruff, mkdocs, etc. installed via pip --user)
    Add-PathEntry "$env:APPDATA\Python\Python314\Scripts"
    Add-PathEntry "$env:APPDATA\Python\Python313\Scripts"
    Add-PathEntry "$env:APPDATA\Python\Scripts"
    Add-PathEntry "$env:PROGRAMFILES\nodejs"
    Add-PathEntry "$env:APPDATA\npm"
    Add-PathEntry "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    Add-PathEntry "$env:PROGRAMDATA\chocolatey\bin"
    Add-PathEntry "$env:PROGRAMFILES\GitHub CLI"
    Add-PathEntry "$env:PROGRAMFILES\Docker\Docker\resources\bin"
    Add-PathEntry "$env:USERPROFILE\.cargo\bin"
    Add-PathEntry "$env:PROGRAMFILES\Microsoft VS Code"
    Add-PathEntry "$env:USERPROFILE\scoop\apps\inno-setup\current"

    $env:HTTP_PROXY = ''
    $env:HTTPS_PROXY = ''
    $env:http_proxy = ''
    $env:https_proxy = ''
    $env:NO_PROXY = 'localhost,127.0.0.1,::1'

    $_gitExe = "$env:USERPROFILE\scoop\apps\git\current\bin\git.exe"
    if (Test-Path $_gitExe -PathType Leaf) {
        function global:git { & $_gitExe @args }
    }

    $setPSReadLineOption = Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue
    $setPSReadLineKeyHandler = Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue
    if ($setPSReadLineOption) {
        if ($setPSReadLineOption.Parameters.ContainsKey('PredictionSource')) {
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction SilentlyContinue
        }

        if ($setPSReadLineOption.Parameters.ContainsKey('PredictionViewStyle')) {
            Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
        }
    }

    if ($setPSReadLineKeyHandler) {
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    }

    function global:prompt {
        $exitCode = $LASTEXITCODE
        $duration = ''
        if ((Get-History -Count 1 -ErrorAction SilentlyContinue) -is [Microsoft.PowerShell.Commands.HistoryInfo]) {
            $last = Get-History -Count 1
            $ms = ($last.EndExecutionTime - $last.StartExecutionTime).TotalMilliseconds
            if ($ms -ge 1000) {
                $duration = " ($([math]::Round($ms / 1000, 1))s)"
            } elseif ($ms -ge 100) {
                $duration = " ($([int]$ms)ms)"
            }
        }

        $branch = ''
        try {
            $b = & "$env:USERPROFILE\scoop\apps\git\current\bin\git.exe" rev-parse --abbrev-ref HEAD 2>$null
            if ($b) {
                $branch = " ($b)"
            }
        } catch {
        }

        $cwd = (Get-Location).Path -replace [regex]::Escape($HOME), '~'
        $arrow = if ($exitCode -eq 0 -or $null -eq $exitCode) { "`e[32m❯`e[0m" } else { "`e[31m❯`e[0m" }
        $global:LASTEXITCODE = $exitCode
        "`e[36m$cwd`e[33m$branch`e[90m$duration`e[0m`n$arrow "
    }

    $env:MYSCRIPTS_COMMON_TOOLS_LOADED = '1'
}

if (-not $SkipWorkspaceBootstrap -and $WorkspaceBootstrap -and (Test-Path $WorkspaceBootstrap -PathType Leaf)) {
    . $WorkspaceBootstrap -SkipCommonBootstrap
    return
}

$pathCount = ($env:PATH -split ';').Count
$scopeLabel = if ($WorkspaceRoot) { $WorkspaceRoot } else { 'session' }
Write-Host "[common-tools] Loaded shared tooling for $scopeLabel - $pathCount PATH entries" -ForegroundColor DarkCyan
