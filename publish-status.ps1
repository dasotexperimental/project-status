[CmdletBinding()]
param(
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$RepositoryRoot = $PSScriptRoot
$ConfigurationPath = Join-Path $RepositoryRoot 'projects.local.json'
$StatusDirectory = Join-Path $RepositoryRoot 'status'
$Git = 'C:\Program Files\Git\cmd\git.exe'

if (-not (Test-Path -LiteralPath $Git)) {
    throw "Git was not found at $Git. Install Git for Windows before publishing status."
}
if (-not (Test-Path -LiteralPath $ConfigurationPath)) {
    throw "Missing configuration file: $ConfigurationPath"
}

$configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
$cutoff = (Get-Date).ToUniversalTime().AddDays(-180)

if (-not $NoPush) {
    $pendingChanges = @(& $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot status --porcelain)
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to inspect pending local status-repository changes.'
    }

    $statusRelativePath = "status/$($configuration.machine_id).json"
    $unexpectedChanges = @($pendingChanges | Where-Object {
        $_.Length -lt 4 -or $_.Substring(3) -ne $statusRelativePath
    })
    if ($unexpectedChanges.Count -gt 0) {
        throw "Refusing to publish while unrelated local changes exist: $($unexpectedChanges -join ', ')"
    }

    if ($pendingChanges.Count -gt 0) {
        & $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot add $statusRelativePath
        if ($LASTEXITCODE -ne 0) { throw 'Failed to stage the pending status file.' }
        & $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot commit -m "status($($configuration.machine_id)): retry pending update"
        if ($LASTEXITCODE -ne 0) { throw 'Failed to commit the pending status file.' }
    }

    & $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot pull --rebase
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to update the local status repository from GitHub before publishing.'
    }
}

function Invoke-GitText {
    param(
        [string]$ProjectPath,
        [string[]]$Arguments
    )

    $result = & $Git -c "safe.directory=$ProjectPath" -C $ProjectPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed in ${ProjectPath}: $($result -join [Environment]::NewLine)"
    }
    return ($result -join "`n").Trim()
}

function Get-RecentFiles {
    param([string]$ProjectPath)

    $excludedDirectories = @('.git', '.venv', 'venv', '.pytest_cache', '.pytest_tmp', '__pycache__', 'data_raw', 'data_processed', 'logs')
    Get-ChildItem -LiteralPath $ProjectPath -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTimeUtc -ge $cutoff -and
            ($_.FullName.Substring($ProjectPath.Length).Split([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) | Where-Object { $excludedDirectories -contains $_ }).Count -eq 0
        } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 50 |
        ForEach-Object {
            [ordered]@{
                path = $_.FullName.Substring($ProjectPath.Length).TrimStart('\', '/')
                modified_at = $_.LastWriteTimeUtc.ToString('o')
            }
        }
}

$projectReports = foreach ($project in $configuration.projects) {
    if (-not (Test-Path -LiteralPath $project.path)) {
        [ordered]@{
            id = $project.id
            display_name = $project.display_name
            state = 'missing_local_folder'
            warning = "Configured path is unavailable on $($configuration.machine_id)."
        }
        continue
    }

    $branch = Invoke-GitText -ProjectPath $project.path -Arguments @('branch', '--show-current')
    $commit = Invoke-GitText -ProjectPath $project.path -Arguments @('rev-parse', 'HEAD')
    $commitTime = Invoke-GitText -ProjectPath $project.path -Arguments @('log', '-1', '--format=%cI')
    $workingTree = Invoke-GitText -ProjectPath $project.path -Arguments @('status', '--porcelain=v1')
    $changeCount = if ([string]::IsNullOrWhiteSpace($workingTree)) { 0 } else { @($workingTree -split "`n").Count }
    $recentFiles = @(Get-RecentFiles -ProjectPath $project.path)

    [ordered]@{
        id = $project.id
        display_name = $project.display_name
        state = if ($changeCount -eq 0) { 'clean' } else { 'dirty' }
        git = [ordered]@{
            branch = $branch
            commit = $commit
            last_commit_at = $commitTime
            dirty = ($changeCount -gt 0)
            uncommitted_change_count = $changeCount
        }
        sync = [ordered]@{
            state = 'not_configured'
            detail = 'Syncthing/NAS synchronization has not been configured yet.'
        }
        recent_files = $recentFiles
        warning = $null
    }
}

$report = [ordered]@{
    schema_version = 1
    generated_at = (Get-Date).ToUniversalTime().ToString('o')
    machine_id = $configuration.machine_id
    projects = @($projectReports)
}

New-Item -ItemType Directory -Path $StatusDirectory -Force | Out-Null
$statusFile = Join-Path $StatusDirectory "$($configuration.machine_id).json"

function Get-SemanticJson {
    param([object]$Value)

    $copy = $Value | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $copy.PSObject.Properties.Remove('generated_at')
    return ($copy | ConvertTo-Json -Depth 8 -Compress)
}

$needsStatusWrite = $true
if (Test-Path -LiteralPath $statusFile) {
    $previous = Get-Content -LiteralPath $statusFile -Raw | ConvertFrom-Json
    if ((Get-SemanticJson -Value $previous) -eq (Get-SemanticJson -Value $report)) {
        $needsStatusWrite = $false
    }
}

if ($needsStatusWrite) {
    $json = $report | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($statusFile, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

if ($NoPush) {
    if ($needsStatusWrite) {
        Write-Host "Wrote $statusFile without committing or pushing."
    } else {
        Write-Host 'Status is unchanged; no write, commit, or push required.'
    }
    exit 0
}

& $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot add 'status/*.json'
if ($LASTEXITCODE -ne 0) { throw 'Failed to stage the status file.' }

& $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    & $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot push
    if ($LASTEXITCODE -ne 0) { throw 'Failed to push pending local status-repository commits.' }
    Write-Host 'Status is unchanged; pushed any pending local commits.'
    exit 0
}
if ($LASTEXITCODE -ne 1) { throw 'Unable to determine whether status changed.' }

& $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot commit -m "status($($configuration.machine_id)): update"
if ($LASTEXITCODE -ne 0) { throw 'Failed to commit the status update.' }
& $Git -c "safe.directory=$RepositoryRoot" -C $RepositoryRoot push
if ($LASTEXITCODE -ne 0) { throw 'Failed to push the status update.' }

Write-Host "Published $statusFile."
