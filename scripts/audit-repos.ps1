<#
.SYNOPSIS
Audit all Git repositories under a workspace umbrella folder (each subfolder is a separate repo).

.DESCRIPTION
Scans each immediate child directory containing a ".git" folder and validates:
- index.html exists at repo root
- README.md exists and mentions the repo's GitHub Pages URL
- .gitignore exists
- Pages workflow exists under .github/workflows (heuristic detection)
- Pages workflow uses actions/upload-pages-artifact@v3 and actions/deploy-pages@v4 (best effort)
- index.html avoids absolute root asset paths (href="/", src="/") which often break on GitHub Pages project sites

.PARAMETER Root
Umbrella root folder containing many repos.

.PARAMETER GitHubUser
GitHub username for expected Pages URL (default: rajwanyair).

.PARAMETER RecurseDepth
How deep to scan for .git repos (default: 1 = immediate subfolders only).

.PARAMETER OutputJson
Write results to JSON file.

.PARAMETER OutputCsv
Write results to CSV file.

.PARAMETER FailOnWarn
If set, warnings also cause non-zero exit.

.EXAMPLE
.\audit-repos.ps1 -Root "C:\Users\ryair\OneDrive - Intel Corporation\Documents\MyScripts" -OutputJson ".\audit.json"
#>

[CmdletBinding()]
param(
    [string]$Root = "C:\Users\ryair\OneDrive - Intel Corporation\Documents\MyScripts",
    [string]$GitHubUser = "rajwanyair",
    [ValidateRange(1,10)]
    [int]$RecurseDepth = 1,
    [string]$OutputJson,
    [string]$OutputCsv,
    [switch]$FailOnWarn
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoCandidates {
    param([string]$RootPath, [int]$Depth)

    if ($Depth -le 1) {
        return @(Get-ChildItem -LiteralPath $RootPath -Directory -ErrorAction SilentlyContinue)
    }

    $dirs = New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]
    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue(@($RootPath, 0))

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        $path = [string]$item[0]
        $level = [int]$item[1]

        if ($level -ge $Depth) { continue }

        foreach ($d in @(Get-ChildItem -LiteralPath $path -Directory -ErrorAction SilentlyContinue)) {
            $dirs.Add($d) | Out-Null
            $queue.Enqueue(@($d.FullName, $level + 1))
        }
    }
    return @($dirs)
}

function Test-ContainsPagesActions {
    param([string]$WorkflowText)

    [pscustomobject]@{
        HasUploadPagesArtifactV3 = ($WorkflowText -match 'actions\/upload-pages-artifact@v3')
        HasDeployPagesV4         = ($WorkflowText -match 'actions\/deploy-pages@v4')
    }
}

function Find-PagesWorkflow {
    param([string]$RepoPath)

    $wfDir = Join-Path $RepoPath ".github\workflows"
    if (-not (Test-Path -LiteralPath $wfDir)) { return $null }

    $wfFiles = @(Get-ChildItem -LiteralPath $wfDir -File -Include *.yml,*.yaml -ErrorAction SilentlyContinue)
    foreach ($wf in $wfFiles) {
        $txt = Get-Content -LiteralPath $wf.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($txt)) { continue }

        $looksLikePages =
            ($txt -match 'pages:\s*write') -or
            ($txt -match 'actions\/deploy-pages@') -or
            ($txt -match 'actions\/upload-pages-artifact@') -or
            ($txt -match 'environment:\s*[\r\n]+\s*name:\s*github-pages') -or
            ($txt -match 'github-pages')

        if ($looksLikePages) {
            $actions = Test-ContainsPagesActions -WorkflowText $txt
            return [pscustomobject]@{
                Path      = $wf.FullName
                LooksLike = $true
                Actions   = $actions
            }
        }
    }
    return $null
}

function Test-IndexHtmlForAbsoluteAssetPaths {
    param([string]$IndexPath)

    if (-not (Test-Path -LiteralPath $IndexPath)) {
        return [pscustomobject]@{ HasProblem = $false; Snippets = @() }
    }

    $html = Get-Content -LiteralPath $IndexPath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($html)) {
        return [pscustomobject]@{ HasProblem = $false; Snippets = @() }
    }

    # Detect href="/..." or src="/..." but NOT //cdn...
    $regex = '(?i)(href|src)\s*=\s*["'']\/(?!\/)'
    $matches = [regex]::Matches($html, $regex)

    $snips = @()
    foreach ($m in $matches) {
        $start = [math]::Max(0, $m.Index - 40)
        $len   = [math]::Min(140, $html.Length - $start)
        $snips += ($html.Substring($start, $len) -replace "\r|\n", " ")
        if ($snips.Count -ge 8) { break }
    }

    [pscustomobject]@{
        HasProblem = ($matches.Count -gt 0)
        Snippets   = $snips
    }
}

function New-Finding {
    param([string]$Level, [string]$Code, [string]$Message)
    [pscustomobject]@{ Level=$Level; Code=$Code; Message=$Message }
}

Write-Host "Auditing repos under: $Root" -ForegroundColor Cyan
Write-Host "GitHub Pages user: $GitHubUser" -ForegroundColor Cyan
Write-Host "Scan depth: $RecurseDepth" -ForegroundColor Cyan
Write-Host ""

$repoDirs = @(Get-RepoCandidates -RootPath $Root -Depth $RecurseDepth)

$repos = @()
foreach ($d in $repoDirs) {
    $gitDir = Join-Path $d.FullName ".git"
    if (Test-Path -LiteralPath $gitDir) { $repos += $d }
}

if ($repos.Count -eq 0) {
    Write-Warning "No git repos found under '$Root' (depth=$RecurseDepth)."
    exit 2
}

$results = @()

foreach ($repo in $repos) {
    $repoName = $repo.Name
    $repoPath = $repo.FullName
    $expectedUrl = "https://$GitHubUser.github.io/$repoName"
    $expectedUrlRegex = [regex]::Escape($expectedUrl)

    $findings = @()

    $indexPath = Join-Path $repoPath "index.html"
    if (-not (Test-Path -LiteralPath $indexPath)) {
        $findings += New-Finding "FAIL" "INDEX_MISSING" "Missing index.html at repo root (required for GitHub Pages entry)."
    }

    $readmePath = Join-Path $repoPath "README.md"
    if (-not (Test-Path -LiteralPath $readmePath)) {
        $findings += New-Finding "WARN" "README_MISSING" "Missing README.md (recommended)."
    } else {
        $readme = Get-Content -LiteralPath $readmePath -Raw -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($readme)) {
            if ($readme -notmatch $expectedUrlRegex) {
                $findings += New-Finding "WARN" "README_NO_PAGES_URL" "README.md does not mention expected GitHub Pages URL: $expectedUrl"
            }
        }
    }

    $gitignorePath = Join-Path $repoPath ".gitignore"
    if (-not (Test-Path -LiteralPath $gitignorePath)) {
        $findings += New-Finding "WARN" "GITIGNORE_MISSING" "Missing .gitignore (recommended)."
    }

    $wf = Find-PagesWorkflow -RepoPath $repoPath
    if (-not $wf) {
        $findings += New-Finding "WARN" "PAGES_WORKFLOW_MISSING" "No GitHub Pages workflow detected under .github/workflows (recommended)."
    } else {
        if (-not $wf.Actions.HasUploadPagesArtifactV3) {
            $findings += New-Finding "WARN" "PAGES_WORKFLOW_UPLOAD_NOT_V3" "Workflow found, but actions/upload-pages-artifact@v3 not detected."
        }
        if (-not $wf.Actions.HasDeployPagesV4) {
            $findings += New-Finding "WARN" "PAGES_WORKFLOW_DEPLOY_NOT_V4" "Workflow found, but actions/deploy-pages@v4 not detected."
        }
    }

    $assetCheck = Test-IndexHtmlForAbsoluteAssetPaths -IndexPath $indexPath
    if ($assetCheck.HasProblem) {
        $findings += New-Finding "WARN" "INDEX_ABSOLUTE_ASSET_PATHS" "index.html contains href/src starting with '/'. Prefer relative paths (./...) for GitHub Pages project sites."
    }

    $failCount = @($findings | Where-Object Level -eq "FAIL").Count
    $warnCount = @($findings | Where-Object Level -eq "WARN").Count

    $status = if ($failCount -gt 0) { "FAIL" } elseif ($warnCount -gt 0) { "WARN" } else { "PASS" }

    $color = switch ($status) { "PASS" { "Green" } "WARN" { "Yellow" } default { "Red" } }

    Write-Host ("[{0}] {1} ({2} fails, {3} warns) Pages: {4}" -f $status, $repoName, $failCount, $warnCount, $expectedUrl) -ForegroundColor $color
    if ($wf) { Write-Host ("      workflow: {0}" -f $wf.Path) -ForegroundColor DarkGray }
    if ($assetCheck.HasProblem) { Write-Host "      index.html: absolute asset paths detected" -ForegroundColor DarkGray }

    $results += [pscustomobject]@{
        RepoName         = $repoName
        RepoPath         = $repoPath
        ExpectedPagesUrl = $expectedUrl
        Status           = $status
        FailCount        = $failCount
        WarnCount        = $warnCount
        HasIndexHtml     = (Test-Path -LiteralPath $indexPath)
        HasReadme        = (Test-Path -LiteralPath $readmePath)
        ReadmeHasPagesUrl= (Test-Path -LiteralPath $readmePath) -and ((Get-Content -LiteralPath $readmePath -Raw -ErrorAction SilentlyContinue) -match $expectedUrlRegex)
        HasGitignore     = (Test-Path -LiteralPath $gitignorePath)
        PagesWorkflow    = if ($wf) { $wf.Path } else { $null }
        WorkflowHasUploadPagesArtifactV3 = if ($wf) { $wf.Actions.HasUploadPagesArtifactV3 } else { $false }
        WorkflowHasDeployPagesV4         = if ($wf) { $wf.Actions.HasDeployPagesV4 } else { $false }
        IndexHasAbsoluteAssetPaths       = $assetCheck.HasProblem
        IndexAbsoluteAssetPathSnippets   = $assetCheck.Snippets
        Findings         = $findings
    }
}

Write-Host ""
Write-Host "==== Detailed Findings ====" -ForegroundColor Cyan

foreach ($r in $results) {
    if ($r.Status -eq "PASS") { continue }

    Write-Host ""
    Write-Host ("{0} - {1}" -f $r.RepoName, $r.ExpectedPagesUrl) -ForegroundColor Cyan

    foreach ($f in $r.Findings) {
        $c = if ($f.Level -eq "FAIL") { "Red" } else { "Yellow" }
        Write-Host ("  - [{0}] {1}: {2}" -f $f.Level, $f.Code, $f.Message) -ForegroundColor $c
    }

    if ($r.IndexHasAbsoluteAssetPaths -and $r.IndexAbsoluteAssetPathSnippets.Count -gt 0) {
        Write-Host "    snippets:" -ForegroundColor DarkGray
        foreach ($s in $r.IndexAbsoluteAssetPathSnippets) {
            Write-Host ("      ...{0}..." -f $s) -ForegroundColor DarkGray
        }
    }
}

if ($OutputJson) {
    $results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputJson -Encoding UTF8
    Write-Host ""
    Write-Host "Wrote JSON: $OutputJson" -ForegroundColor Green
}

if ($OutputCsv) {
    $flat = foreach ($r in $results) {
        [pscustomobject]@{
            RepoName   = $r.RepoName
            RepoPath   = $r.RepoPath
            Status     = $r.Status
            FailCount  = $r.FailCount
            WarnCount  = $r.WarnCount
            ExpectedPagesUrl = $r.ExpectedPagesUrl
            HasIndexHtml = $r.HasIndexHtml
            HasReadme    = $r.HasReadme
            ReadmeHasPagesUrl = $r.ReadmeHasPagesUrl
            HasGitignore = $r.HasGitignore
            PagesWorkflow = $r.PagesWorkflow
            WorkflowHasUploadPagesArtifactV3 = $r.WorkflowHasUploadPagesArtifactV3
            WorkflowHasDeployPagesV4         = $r.WorkflowHasDeployPagesV4
            IndexHasAbsoluteAssetPaths       = $r.IndexHasAbsoluteAssetPaths
            FindingCodes = (@($r.Findings | ForEach-Object Code) -join ";")
        }
    }
    $flat | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Wrote CSV: $OutputCsv" -ForegroundColor Green
}

$totalFails = (@($results | Measure-Object -Property FailCount -Sum).Sum)
$totalWarns = (@($results | Measure-Object -Property WarnCount -Sum).Sum)

Write-Host ""
Write-Host ("Summary: {0} repos | {1} FAILS | {2} WARNS" -f $results.Count, $totalFails, $totalWarns) -ForegroundColor Cyan

if ($totalFails -gt 0) { exit 1 }
if ($FailOnWarn -and $totalWarns -gt 0) { exit 1 }
exit 0