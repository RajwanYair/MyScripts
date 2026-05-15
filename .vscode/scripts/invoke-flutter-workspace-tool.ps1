param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,

    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'pub-get',
        'build-runner',
        'build-runner-watch',
        'analyze',
        'test',
        'test-coverage',
        'format-check',
        'format',
        'build-windows',
        'build-windows-release',
        'build-android-debug',
        'full-health-check',
        'domain-coverage-check',
        'pre-commit-run-all',
        'release-bump',
        'clean',
        'run-windows'
    )]
    [string]$Action,

    [ValidateSet('patch', 'minor', 'major')]
    [string]$BumpType,

    [int]$WallClockTimeoutSeconds = 0
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)

    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-CommandOrThrow {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $renderedCommand = @($FilePath) + $Arguments
    Write-Host ">> $($renderedCommand -join ' ')" -ForegroundColor DarkGray

    & $FilePath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $($renderedCommand -join ' ')"
    }
}

function Invoke-FlutterTest {
    param(
        [switch]$WithCoverage,
        [int]$TimeoutSeconds = 0
    )

    $flutterArguments = @('test', '--timeout', '30s')
    if ($WithCoverage) {
        $flutterArguments += '--coverage'
    }

    if ($TimeoutSeconds -le 0) {
        Invoke-CommandOrThrow 'flutter' $flutterArguments
        return
    }

    Write-Host ">> flutter $($flutterArguments -join ' ')  [wall-clock limit: ${TimeoutSeconds}s]" -ForegroundColor DarkGray

    $process = Start-Process -FilePath 'flutter' -ArgumentList $flutterArguments -WorkingDirectory (Get-Location).Path -NoNewWindow -PassThru

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try {
            Stop-Process -Id $process.Id -Force
        }
        catch {
        }

        throw "flutter test exceeded ${TimeoutSeconds}s wall-clock limit and was terminated."
    }

    if ($process.ExitCode -ne 0) {
        throw "flutter test failed with exit code $($process.ExitCode)."
    }
}

function Assert-DomainCoverage {
    $coveragePath = Join-Path (Get-Location) 'coverage\lcov.info'
    if (-not (Test-Path $coveragePath)) {
        throw "Coverage file not found: $coveragePath"
    }

    $insideDomainRecord = $false
    $uncoveredLines = 0

    foreach ($line in Get-Content $coveragePath) {
        if ($line -match '^SF:lib\\src\\domain\\') {
            $insideDomainRecord = $true
            continue
        }

        if ($line -eq 'end_of_record') {
            $insideDomainRecord = $false
            continue
        }

        if ($insideDomainRecord -and $line -match '^DA:\d+,0$') {
            $uncoveredLines++
        }
    }

    if ($uncoveredLines -gt 0) {
        throw "Domain coverage gap: $uncoveredLines uncovered lines"
    }

    Write-Host 'Domain: 100% covered' -ForegroundColor Green
}

$resolvedWorkspace = Resolve-Path $WorkspaceRoot

Push-Location $resolvedWorkspace
try {
    switch ($Action) {
        'pub-get' {
            Write-Step 'Installing dependencies'
            Invoke-CommandOrThrow 'flutter' @('pub', 'get')
        }
        'build-runner' {
            Write-Step 'Generating code'
            Invoke-CommandOrThrow 'dart' @('run', 'build_runner', 'build', '--delete-conflicting-outputs')
        }
        'build-runner-watch' {
            Write-Step 'Starting code generation watch'
            Invoke-CommandOrThrow 'dart' @('run', 'build_runner', 'watch', '--delete-conflicting-outputs')
        }
        'analyze' {
            Write-Step 'Running static analysis'
            Invoke-CommandOrThrow 'flutter' @('analyze', '--fatal-infos')
        }
        'test' {
            Write-Step 'Running tests'
            Invoke-FlutterTest -TimeoutSeconds $WallClockTimeoutSeconds
        }
        'test-coverage' {
            Write-Step 'Running tests with coverage'
            Invoke-FlutterTest -WithCoverage -TimeoutSeconds $WallClockTimeoutSeconds
        }
        'format-check' {
            Write-Step 'Checking formatting'
            Invoke-CommandOrThrow 'dart' @('format', '--set-exit-if-changed', 'lib', 'test')
        }
        'format' {
            Write-Step 'Formatting code'
            Invoke-CommandOrThrow 'dart' @('format', 'lib', 'test')
        }
        'build-windows' {
            Write-Step 'Building Windows debug bundle'
            Invoke-CommandOrThrow 'flutter' @('build', 'windows')
        }
        'build-windows-release' {
            Write-Step 'Building Windows release bundle'
            Invoke-CommandOrThrow 'flutter' @('build', 'windows', '--release')
        }
        'build-android-debug' {
            Write-Step 'Building Android debug APK'
            Invoke-CommandOrThrow 'flutter' @('build', 'apk', '--debug')
        }
        'full-health-check' {
            Write-Step 'Running health check'
            Invoke-CommandOrThrow 'flutter' @('analyze', '--fatal-infos')
            Invoke-CommandOrThrow 'dart' @('format', '--set-exit-if-changed', 'lib', 'test')
            Invoke-FlutterTest -WithCoverage -TimeoutSeconds $WallClockTimeoutSeconds
        }
        'domain-coverage-check' {
            Write-Step 'Running domain coverage check'
            Invoke-FlutterTest -WithCoverage -TimeoutSeconds $WallClockTimeoutSeconds
            Assert-DomainCoverage
        }
        'pre-commit-run-all' {
            Write-Step 'Running pre-commit hooks'
            Invoke-CommandOrThrow 'pre-commit' @('run', '--all-files')
        }
        'release-bump' {
            if (-not $BumpType) {
                throw 'BumpType is required for the release-bump action.'
            }

            Write-Step "Triggering release bump: $BumpType"
            Invoke-CommandOrThrow 'gh' @('workflow', 'run', 'bump-version.yml', '-f', "bump=$BumpType")
        }
        'clean' {
            Write-Step 'Cleaning build artifacts'
            Invoke-CommandOrThrow 'flutter' @('clean')
            Invoke-CommandOrThrow 'flutter' @('pub', 'get')
            Invoke-CommandOrThrow 'dart' @('run', 'build_runner', 'build', '--delete-conflicting-outputs')
        }
        'run-windows' {
            Write-Step 'Running on Windows'
            Invoke-CommandOrThrow 'flutter' @('run', '-d', 'windows')
        }
    }
}
finally {
    Pop-Location
}
