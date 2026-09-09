$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
Set-Location (Split-Path -Parent $PSScriptRoot)

# ============================================================
# TimeTrail GitHub Bootstrap (version read from package.json)
# ASCII-only script text for Windows PowerShell 5.1 compatibility.
# Project JSON/HTML files are still read explicitly as UTF-8.
# ============================================================
$ConfiguredOwner = if ($env:TT_REPO_OWNER) { $env:TT_REPO_OWNER.Trim() } else { '' }
$ConfiguredRepoName = if ($env:TT_REPO_NAME) { $env:TT_REPO_NAME.Trim() } else { '' }
$RepoVisibility = if ($env:TT_REPO_VISIBILITY) { $env:TT_REPO_VISIBILITY.Trim() } else { 'public' }
$RepoDescription = if ($env:TT_REPO_DESCRIPTION) { $env:TT_REPO_DESCRIPTION } else { 'Interactive historical map for exploring places, people and events through time.' }
$RepoTopics = if ($env:TT_REPO_TOPICS) { @($env:TT_REPO_TOPICS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @('history','maplibre','javascript','openstreetmap','github-pages','education','timeline') }
$DefaultBranch = 'main'
$CommitMessage = 'feat: expand TimeTrail historical data pipeline and learning content'
$WorkflowFile = 'deploy.yml'
$ApiVersion = '2022-11-28'
$MinimumEvents = 80
$MinimumBackbone = 200
$MinimumStories = 30
$MinimumCities = 24

$ProjectRoot = (Get-Location).Path
$ProjectVersion = 'unknown'
$ReleaseTag = ''
$ExpectedBuild = ''
$LogFile = Join-Path $ProjectRoot 'github-bootstrap.log'
$TranscriptStarted = $false

function Write-Stage([string]$Message) { Write-Host "[CHECK] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Recovery([string]$Message) { Write-Host "[RECOVERY] $Message" -ForegroundColor Yellow }
function Stop-WithError([string]$Message, [string]$Recovery = '') {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    if ($Recovery) { Write-Recovery $Recovery }
    throw $Message
}

function Invoke-Native {
    param(
        [Parameter(Mandatory=$true)][string]$File,
        [string[]]$Arguments = @()
    )
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $File $($Arguments -join ' ')"
    }
}

function Test-Native {
    param([string]$File, [string[]]$Arguments = @())
    & $File @Arguments *> $null
    return ($LASTEXITCODE -eq 0)
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path','Machine')
    $user = [Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = "$machine;$user"
}

function Ensure-Command {
    param([string]$Command, [string]$DisplayName, [string]$WingetId)
    Write-Stage "$DisplayName availability"
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Ok "$DisplayName found"
        return
    }
    Write-Warn "$DisplayName was not found."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Stop-WithError "$DisplayName is missing and winget is unavailable." "Install $DisplayName, then run github-bootstrap.cmd again."
    }
    Write-Stage "Installing $DisplayName with winget"
    & winget install --id $WingetId -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "$DisplayName automatic installation failed." "Run: winget install --id $WingetId -e"
    }
    Refresh-Path
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Stop-WithError "$DisplayName installed, but PATH was not refreshed in this console." "Close this window and run github-bootstrap.cmd again."
    }
    Write-Ok "$DisplayName installed/found"
}

function Parse-GitHubRemote([string]$RemoteUrl) {
    if (-not $RemoteUrl) { return $null }
    $u = $RemoteUrl.Trim()
    $m = [regex]::Match($u, 'github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?$')
    if (-not $m.Success) { return $null }
    return [pscustomobject]@{ Owner = $m.Groups[1].Value; Name = $m.Groups[2].Value }
}

function Get-OriginUrl {
    $remotes = @(& git remote 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not ($remotes -contains 'origin')) { return '' }
    $url = (& git remote get-url origin 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $url) { return '' }
    return ([string]$url).Trim()
}

function Test-GitRef([string]$RefName) {
    & git rev-parse --verify --quiet $RefName *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-RemoteBranch([string]$RemoteName, [string]$BranchName) {
    & git ls-remote --exit-code --heads $RemoteName "refs/heads/$BranchName" *> $null
    return ($LASTEXITCODE -eq 0)
}

try {
    try {
        Start-Transcript -Path $LogFile -Force | Out-Null
        $TranscriptStarted = $true
    } catch {
        Write-Warn "Could not start transcript log: $($_.Exception.Message)"
    }

    Write-Host '============================================================'
    Write-Host 'TimeTrail deployment diagnostic bootstrap'
    Write-Host '============================================================'
    Write-Stage "Project folder: $ProjectRoot"

    $required = @(
        'index.html','app.js','styles.css','package.json','package-lock.json',
        'data/history-events.json','data/history-backbone.json','data/story-packs.json','data/cities.json',
        'scripts/build.mjs','scripts/configure-repo.mjs',
        ".github/workflows/$WorkflowFile"
    )
    foreach ($file in $required) {
        if (-not (Test-Path (Join-Path $ProjectRoot $file))) {
            Stop-WithError "Required project file is missing: $file" 'Extract the complete ZIP first, then run github-bootstrap.cmd from the extracted project root.'
        }
    }
    Write-Ok 'Complete project folder detected'

    $PackageInfo = Get-Content 'package.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    $ProjectVersion = if ($PackageInfo.version) { [string]$PackageInfo.version } else { 'unknown' }
    $ReleaseTag = if ($env:TT_INITIAL_TAG) { $env:TT_INITIAL_TAG } else { "v$ProjectVersion" }
    $IndexForBuild = Get-Content 'index.html' -Raw -Encoding UTF8
    $BuildMatch = [regex]::Match($IndexForBuild, 'timetrail-build" content="([^"]+)"')
    if (-not $BuildMatch.Success) {
        Stop-WithError 'index.html is missing the timetrail-build meta tag.' 'Use a complete TimeTrail package.'
    }
    $ExpectedBuild = $BuildMatch.Groups[1].Value
    Write-Ok "Release metadata: v$ProjectVersion / build $ExpectedBuild"

    Write-Stage 'Checking local TimeTrail dataset'
    $indexHtml = Get-Content 'index.html' -Raw -Encoding UTF8
    $appJs = Get-Content 'app.js' -Raw -Encoding UTF8
    $appBuildMatch = [regex]::Match($appJs, "DATA_VERSION='([^']+)'")
    if (-not $appBuildMatch.Success) {
        Stop-WithError 'app.js does not contain DATA_VERSION.' 'Use a complete package or restore app.js.'
    }
    if ($appBuildMatch.Groups[1].Value -ne $ExpectedBuild) {
        Stop-WithError "Release files disagree: index.html=$ExpectedBuild / app.js=$($appBuildMatch.Groups[1].Value)." 'Do not mix files from different TimeTrail ZIP releases.'
    }
    Write-Ok "Release consistency: v$ProjectVersion / build $ExpectedBuild"
    # Windows PowerShell 5.1 may preserve a top-level JSON array as one pipeline
    # object when ConvertFrom-Json is wrapped directly in @(...). Read first, then
    # inspect the actual CLR array length so 80 items are never misreported as 1.
    $events = Get-Content 'data/history-events.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    $backbone = Get-Content 'data/history-backbone.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    $stories = Get-Content 'data/story-packs.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    $cities = Get-Content 'data/cities.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    $eventCount = if ($null -eq $events) { 0 } elseif ($events -is [System.Array]) { $events.Length } else { 1 }
    $backboneCount = if ($null -eq $backbone) { 0 } elseif ($backbone -is [System.Array]) { $backbone.Length } else { 1 }
    $storyCount = if ($null -eq $stories) { 0 } elseif ($stories -is [System.Array]) { $stories.Length } else { 1 }
    $cityCount = if ($null -eq $cities) { 0 } elseif ($cities -is [System.Array]) { $cities.Length } else { 1 }
    $countryCount = @($events.country + $backbone.country | Sort-Object -Unique).Count
    $indexCount = 0
    if (Test-Path 'data/history-events-index.json') {
        $idx = Get-Content 'data/history-events-index.json' -Raw -Encoding UTF8 | ConvertFrom-Json
        $indexCount = if ($null -eq $idx) { 0 } elseif ($idx -is [System.Array]) { $idx.Length } else { 1 }
    }
    Write-Host "[DATA] Curated: $eventCount / Backbone: $backboneCount / Auto-index: $indexCount / Countries-regions: $countryCount / Story packs: $storyCount / Duel cities: $cityCount"
    if ($eventCount -lt $MinimumEvents -or $backboneCount -lt $MinimumBackbone -or $storyCount -lt $MinimumStories -or $cityCount -lt $MinimumCities) {
        Stop-WithError 'The local dataset is older/smaller than the expanded release.' "Extract the complete TimeTrail v$ProjectVersion ZIP into a new folder."
    }
    Write-Ok 'Expanded dataset is present locally'

    Ensure-Command 'git' 'Git' 'Git.Git'
    Ensure-Command 'node' 'Node.js' 'OpenJS.NodeJS.LTS'
    Ensure-Command 'npm' 'npm' 'OpenJS.NodeJS.LTS'
    Ensure-Command 'gh' 'GitHub CLI' 'GitHub.cli'

    Write-Host "[INFO] $(git --version)"
    Write-Host "[INFO] Node $(node --version)"
    Write-Host "[INFO] npm $(npm --version)"
    Write-Host "[INFO] $((gh --version | Select-Object -First 1))"

    Write-Stage 'Checking GitHub authentication'
    & gh auth status --hostname github.com
    if ($LASTEXITCODE -ne 0) {
        Write-Warn 'GitHub login is required. Starting browser login.'
        Invoke-Native 'gh' @('auth','login','--hostname','github.com','--git-protocol','https','--web')
    }
    Invoke-Native 'gh' @('auth','setup-git')
    Write-Ok 'GitHub authentication is ready'

    $existingOrigin = ''
    if (Test-Path '.git') {
        $existingOrigin = Get-OriginUrl
    }
    $remoteInfo = Parse-GitHubRemote $existingOrigin

    $RepoOwner = $ConfiguredOwner
    $RepoName = $ConfiguredRepoName
    if (-not $RepoOwner -and $remoteInfo) { $RepoOwner = $remoteInfo.Owner }
    if (-not $RepoName -and $remoteInfo) { $RepoName = $remoteInfo.Name }
    if (-not $RepoOwner) {
        $RepoOwner = (& gh api user --jq '.login').Trim()
        if ($LASTEXITCODE -ne 0 -or -not $RepoOwner) {
            Stop-WithError 'Could not resolve the active GitHub account.' 'Run: gh auth status --hostname github.com'
        }
    }
    if (-not $RepoName) { $RepoName = 'timetrail' }

    $FullRepo = "$RepoOwner/$RepoName"
    $RepoUrl = "https://github.com/$FullRepo.git"
    $PagesUrl = "https://$RepoOwner.github.io/$RepoName/"
    Write-Ok "Target repository: $FullRepo"
    if ($remoteInfo) { Write-Ok "Existing origin detected and reused: $existingOrigin" }
    Write-Ok "Expected Pages URL: $PagesUrl"

    $GitInitializedThisRun = $false
    if (-not (Test-Path '.git')) {
        Write-Stage 'Initializing local Git repository'
        Invoke-Native 'git' @('init')
        $GitInitializedThisRun = $true
    } else {
        Write-Ok 'Existing local Git repository found'
    }
    Invoke-Native 'git' @('branch','-M',$DefaultBranch)

    Write-Stage 'Checking Git author configuration'
    $gitName = (& git config user.name 2>$null)
    $gitEmail = (& git config user.email 2>$null)
    if (-not $gitName) {
        $gitName = $RepoOwner
        Invoke-Native 'git' @('config','user.name',$gitName)
        Write-Warn "Local git user.name was set to $gitName"
    }
    if (-not $gitEmail) {
        $gitEmail = "$RepoOwner@users.noreply.github.com"
        Invoke-Native 'git' @('config','user.email',$gitEmail)
        Write-Warn 'Local git user.email was set to the GitHub noreply address'
    }
    Write-Ok "Git author: $gitName <$gitEmail>"

    Write-Stage 'Configuring canonical, Open Graph, and sitemap URLs'
    Invoke-Native 'node' @('scripts/configure-repo.mjs',$RepoOwner,$RepoName)

    Write-Stage 'Running npm ci, check, and build'
    Invoke-Native 'npm' @('ci','--no-audit','--no-fund')
    Invoke-Native 'npm' @('run','check')
    Invoke-Native 'npm' @('run','build')
    Write-Ok 'Local checks and dist build passed'

    Write-Stage 'Checking GitHub repository'
    $repoExists = Test-Native 'gh' @('repo','view',$FullRepo)
    if (-not $repoExists) {
        Write-Stage "Creating GitHub repository: $FullRepo"
        $visibilityFlag = "--$RepoVisibility"
        Invoke-Native 'gh' @('repo','create',$FullRepo,$visibilityFlag,'--description',$RepoDescription)
        Write-Ok 'Remote repository created'
    } else {
        Write-Ok 'Existing GitHub repository will be reused'
    }

    $origin = Get-OriginUrl
    if (-not $origin) {
        Invoke-Native 'git' @('remote','add','origin',$RepoUrl)
        $origin = $RepoUrl
        Write-Ok "origin added: $RepoUrl"
    } else {
        $parsedOrigin = Parse-GitHubRemote $origin
        if (-not $parsedOrigin -or $parsedOrigin.Owner -ne $RepoOwner -or $parsedOrigin.Name -ne $RepoName) {
            Write-Warn "origin points elsewhere: $origin"
            Invoke-Native 'git' @('remote','set-url','origin',$RepoUrl)
            $origin = $RepoUrl
            Write-Ok "origin changed to: $RepoUrl"
        } else {
            Write-Ok "origin verified: $origin"
        }
    }

    # A freshly extracted ZIP has no Git history, while the GitHub repository may
    # already contain previous TimeTrail releases. Attach the remote history first
    # without overwriting the working tree. This makes the next commit a normal
    # fast-forward update instead of an unrelated-history push.
    if (Test-RemoteBranch 'origin' $DefaultBranch) {
        Write-Stage "Fetching existing origin/$DefaultBranch history"
        Invoke-Native 'git' @('fetch','origin',$DefaultBranch)
        $hasLocalHead = Test-GitRef 'HEAD'
        if (-not $hasLocalHead) {
            Invoke-Native 'git' @('reset','--mixed',"origin/$DefaultBranch")
            Write-Ok "Attached local branch to existing origin/$DefaultBranch history without replacing project files"
        } else {
            & git merge-base HEAD "origin/$DefaultBranch" *> $null
            if ($LASTEXITCODE -ne 0) {
                if ($GitInitializedThisRun) {
                    Invoke-Native 'git' @('reset','--mixed',"origin/$DefaultBranch")
                    Write-Ok "Rebased freshly initialized local history onto origin/$DefaultBranch"
                } else {
                    Stop-WithError 'The existing local Git history is unrelated to the target GitHub repository.' "Use a newly extracted TimeTrail folder, or manually reconcile the Git history before rerunning."
                }
            } else {
                Write-Ok "Local Git history is compatible with origin/$DefaultBranch"
            }
        }
    } else {
        Write-Ok "origin/$DefaultBranch does not exist yet; first push will create it"
    }

    Write-Stage 'Committing changed files'
    Invoke-Native 'git' @('add','-A')
    $changes = (& git status --porcelain)
    if ($changes) {
        Invoke-Native 'git' @('commit','-m',$CommitMessage)
        Write-Ok 'New commit created'
    } else {
        Write-Ok 'No new local changes to commit'
    }

    Write-Stage "Pushing $DefaultBranch"
    & git push -u origin $DefaultBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Warn 'Initial push failed. Trying a safe rebase once.'
        & git pull --rebase origin $DefaultBranch
        if ($LASTEXITCODE -ne 0) {
            Stop-WithError 'git pull --rebase failed. The script will not force-push.' "Resolve conflicts, then run: git push -u origin $DefaultBranch"
        }
        Invoke-Native 'git' @('push','-u','origin',$DefaultBranch)
    }
    Write-Ok 'GitHub push completed'

    Write-Stage 'Updating repository metadata'
    & gh repo edit $FullRepo --description $RepoDescription --homepage $PagesUrl --default-branch $DefaultBranch
    if ($LASTEXITCODE -ne 0) { Write-Warn 'Some repository metadata could not be updated.' }
    foreach ($topic in $RepoTopics) {
        & gh repo edit $FullRepo --add-topic $topic *> $null
    }
    Write-Ok 'Repository metadata update attempted'

    Write-Stage 'Enabling GitHub Pages with Actions'
    & gh api -H "X-GitHub-Api-Version: $ApiVersion" "repos/$FullRepo/pages" *> $null
    if ($LASTEXITCODE -eq 0) {
        & gh api --method PUT -H "X-GitHub-Api-Version: $ApiVersion" "repos/$FullRepo/pages" -f build_type=workflow *> $null
        if ($LASTEXITCODE -ne 0) {
            Stop-WithError 'Could not switch the existing Pages site to workflow mode.' "Open https://github.com/$FullRepo/settings/pages and select GitHub Actions."
        }
    } else {
        & gh api --method POST -H "X-GitHub-Api-Version: $ApiVersion" "repos/$FullRepo/pages" -f build_type=workflow *> $null
        if ($LASTEXITCODE -ne 0) {
            Stop-WithError 'Could not enable GitHub Pages.' "Open https://github.com/$FullRepo/settings/pages and select GitHub Actions, then run this script again."
        }
    }
    Write-Ok 'Pages source is GitHub Actions'

    Write-Stage 'Triggering a fresh deployment workflow'
    $previousRunId = (& gh run list --repo $FullRepo --workflow $WorkflowFile --event workflow_dispatch --branch $DefaultBranch --limit 1 --json databaseId --jq '.[0].databaseId' 2>$null).Trim()
    Invoke-Native 'gh' @('workflow','run',$WorkflowFile,'--repo',$FullRepo,'--ref',$DefaultBranch)

    $runId = $null
    for ($i = 0; $i -lt 30 -and -not $runId; $i++) {
        Start-Sleep -Seconds 2
        $latestRunId = (& gh run list --repo $FullRepo --workflow $WorkflowFile --event workflow_dispatch --branch $DefaultBranch --limit 1 --json databaseId --jq '.[0].databaseId' 2>$null).Trim()
        if ($latestRunId -and $latestRunId -ne $previousRunId) {
            $runId = $latestRunId
        }
    }
    if (-not $runId) {
        Stop-WithError 'Could not find the new workflow run ID.' "Run: gh run list --repo $FullRepo --workflow $WorkflowFile"
    }
    Write-Ok "Deployment run ID: $runId"

    Write-Stage "Waiting for GitHub Actions run $runId"
    & gh run watch $runId --repo $FullRepo --exit-status
    if ($LASTEXITCODE -ne 0) {
        Write-Recovery "Run: gh run view $runId --repo $FullRepo --log-failed"
        Stop-WithError 'GitHub Actions deployment failed.'
    }
    Write-Ok 'GitHub Actions deployment succeeded'

    $actualPagesUrl = (& gh api -H "X-GitHub-Api-Version: $ApiVersion" "repos/$FullRepo/pages" --jq '.html_url' 2>$null).Trim()
    if (-not $actualPagesUrl) { $actualPagesUrl = $PagesUrl }
    if (-not $actualPagesUrl.EndsWith('/')) { $actualPagesUrl += '/' }

    Write-Stage "Verifying deployed build $ExpectedBuild and expanded JSON dataset"
    $remoteOk = $false
    $remoteDataOk = $false
    $remoteEvents = @()
    for ($i = 0; $i -lt 36 -and (-not $remoteOk -or -not $remoteDataOk); $i++) {
        try {
            $buster = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $headers = @{ 'Cache-Control'='no-cache, no-store'; 'Pragma'='no-cache' }
            $page = Invoke-WebRequest -UseBasicParsing -Uri "$actualPagesUrl`?verify=$buster" -Headers $headers -TimeoutSec 20 -ErrorAction Stop
            $remoteOk = ($page.Content -match [regex]::Escape($ExpectedBuild))
            $data = Invoke-WebRequest -UseBasicParsing -Uri "${actualPagesUrl}data/history-events.json?v=$buster" -Headers $headers -TimeoutSec 20 -ErrorAction Stop
            $remoteEvents = $data.Content | ConvertFrom-Json
            $remoteEventCount = if ($null -eq $remoteEvents) { 0 } elseif ($remoteEvents -is [System.Array]) { $remoteEvents.Length } else { 1 }
            $remoteDataOk = ($remoteEventCount -ge $MinimumEvents)
            Write-Host "[VERIFY] Build=$remoteOk Events=$remoteEventCount"
        } catch {
            Write-Warn "Remote verification retry: $($_.Exception.Message)"
        }
        if (-not $remoteOk -or -not $remoteDataOk) { Start-Sleep -Seconds 5 }
    }
    if (-not $remoteOk) {
        Stop-WithError "The deployed HTML does not contain build $ExpectedBuild." "Open $actualPagesUrl`?verify=$ExpectedBuild and inspect github-bootstrap.log."
    }
    if (-not $remoteDataOk) {
        Stop-WithError "The deployed history-events.json has fewer than $MinimumEvents events." "Open ${actualPagesUrl}data/history-events.json in the browser."
    }
    Write-Ok "Remote verification passed: build $ExpectedBuild / events $remoteEventCount"

    Write-Stage "Checking release tag $ReleaseTag"
    & git fetch --tags origin *> $null
    & git rev-parse $ReleaseTag *> $null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Native 'git' @('tag','-a',$ReleaseTag,'-m',"TimeTrail $ReleaseTag")
        Invoke-Native 'git' @('push','origin',$ReleaseTag)
        Write-Ok "$ReleaseTag created and pushed"
    } else {
        Write-Ok "$ReleaseTag already exists"
    }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host '[OK] TimeTrail deployment and remote verification completed' -ForegroundColor Green
    Write-Host "[OK] Repository: https://github.com/$FullRepo" -ForegroundColor Green
    Write-Host "[OK] Pages: $actualPagesUrl" -ForegroundColor Green
    Write-Host "[OK] Verified events: $remoteEventCount" -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor Green

    try {
        Start-Process "$actualPagesUrl`?verify=$ExpectedBuild"
        Write-Ok 'Opened the deployed site in the default browser'
    } catch {
        Write-Warn "Could not open browser automatically: $($_.Exception.Message)"
    }

    if ($TranscriptStarted) { Stop-Transcript | Out-Null; $TranscriptStarted = $false }
    exit 0
}
catch {
    Write-Host ''
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Detailed log: $LogFile" -ForegroundColor Red
    Write-Host '[RECOVERY] The CMD wrapper will keep this window open. Read the last ERROR line above or in the log.' -ForegroundColor Yellow
    if ($TranscriptStarted) { try { Stop-Transcript | Out-Null } catch {}; $TranscriptStarted = $false }
    exit 1
}
