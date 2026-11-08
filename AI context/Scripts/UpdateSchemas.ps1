# Daily check of the Power BI JSON schemas we keep, and install of new versions.
#
# 1. Local copies in ClientA\_Documentation\Context\PBIP\Schemas (checked against GitHub):
#      visualContainerSchema-<v>.json      microsoft/json-schemas  fabric/item/report/definition/visualContainer/<v>/schema.json
#      visualConfigurationSchema-<v>.json  microsoft/json-schemas  .../visualConfiguration/<v>/schema-embedded.json
#      page-<v>.json                       microsoft/json-schemas  .../page/<v>/schema.json
#      reportThemeSchema-<v>.json          microsoft/powerbi-desktop-samples  "Report Theme JSON Schema"
#    A newer version is downloaded, links to the old file name in Context\**\*.md are switched to the
#    new one, the old file is deleted, the CHANGELOG note of the new version goes to the log.
# 2. pbir's bundled schemas (report / semanticModel / theme): newer versions are downloaded into
#    pbir's schema folder, schema_summary.json is updated, then "pbir schema regenerate" runs
#    (pbir schema fetch is anonymous-only and hits the GitHub rate limit). A newer pbir release
#    is only logged.
#
# GitHub listing goes through "gh api" (authenticated, 5000/hour) when gh is signed in,
# otherwise anonymous Invoke-RestMethod. Log: Context\PBIP\Schemas\SchemaUpdates.log.
#
# Usage:
#   pwsh -File UpdateSchemas.ps1              # check + install now
#   pwsh -File UpdateSchemas.ps1 -WhatIf      # check only, change nothing
#   pwsh -File UpdateSchemas.ps1 -Register    # create/replace the daily scheduled task (09:00)
#
# SCRIPT_VERSION: 2026-11-08.1
#
# Change log:
#   2026-11-08.1  Schemas moved to Context\PBIP\Schemas; links switched in all Context .md files (recursive).
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ContextPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Context\PBIP\Schemas'),
    [switch]$Register,
    [string]$At = '09:00'
)

$ScriptVersion = '2026-10-15.2'
$TaskName = 'UpdatePowerBISchemas'
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

if ($Register) {
    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -WindowStyle Hidden -File `"$PSCommandPath`""
    $trigger = New-ScheduledTaskTrigger -Daily -At $At
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
    # runs as the signed-in user: gh keeps its token in the user's keyring
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
        -Description "Checks Power BI JSON schemas (Context copies + pbir cache) and installs new versions. $PSCommandPath" -Force | Out-Null
    Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State, @{n = 'NextRun'; e = { (Get-ScheduledTaskInfo $_).NextRunTime } }
    return
}

$log = Join-Path $ContextPath 'SchemaUpdates.log'
function Write-Log([string]$msg) {
    $line = "{0:yyyy-MM-dd HH:mm}  {1}" -f (Get-Date), $msg
    Write-Host $line
    if (-not $WhatIfPreference) { Add-Content -Path $log -Value $line -Encoding utf8 }
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
$ghOk = $gh -and ((& gh auth status 2>&1) -match 'Logged in')
function Get-GitHubDir([string]$repo, [string]$path) {
    $p = ($path -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    # a type pbir knows may not exist in the repo (404) -> empty result, the caller skips it
    if ($ghOk) { $r = & gh api "repos/$repo/contents/$p" 2>$null; if ($LASTEXITCODE -ne 0 -or -not $r) { return @() }; return ($r | ConvertFrom-Json) }
    return Invoke-RestMethod "https://api.github.com/repos/$repo/contents/$p"
}
function Get-Raw([string]$repo, [string]$path) {
    $p = ($path -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    (Invoke-WebRequest "https://raw.githubusercontent.com/$repo/main/$p" -UseBasicParsing).Content
}
function ConvertTo-Ver([string]$s) { try { [version]$s } catch { $null } }

$def = 'fabric/item/report/definition'
$tracked = @(
    @{ Prefix = 'visualContainerSchema-';     Repo = 'microsoft/json-schemas'; Dir = "$def/visualContainer";     File = 'schema.json' }
    @{ Prefix = 'visualConfigurationSchema-'; Repo = 'microsoft/json-schemas'; Dir = "$def/visualConfiguration"; File = 'schema-embedded.json' }
    @{ Prefix = 'page-';                      Repo = 'microsoft/json-schemas'; Dir = "$def/page";                File = 'schema.json' }
    @{ Prefix = 'reportThemeSchema-';         Repo = 'microsoft/powerbi-desktop-samples'; Dir = 'Report Theme JSON Schema'; File = $null }
)

Write-Log "UpdateSchemas $ScriptVersion start (GitHub: $(if ($ghOk) { 'gh, authenticated' } else { 'anonymous' }))"
$changed = 0
foreach ($t in $tracked) {
    try {
        $local = Get-ChildItem $ContextPath -Filter "$($t.Prefix)*.json" | ForEach-Object {
            [pscustomobject]@{ File = $_; Ver = ConvertTo-Ver ($_.BaseName.Substring($t.Prefix.Length)) } } |
            Where-Object Ver | Sort-Object Ver | Select-Object -Last 1
        $items = Get-GitHubDir $t.Repo $t.Dir
        if ($t.File) {   # versioned folders
            $remote = $items | Where-Object type -eq 'dir' | ForEach-Object { ConvertTo-Ver $_.name } | Where-Object { $_ } | Sort-Object | Select-Object -Last 1
            $srcPath = "$($t.Dir)/$remote/$($t.File)"
        } else {         # versioned file names
            $remote = $items | Where-Object { $_.name -like "$($t.Prefix)*.json" } |
                ForEach-Object { ConvertTo-Ver ($_.name.Substring($t.Prefix.Length) -replace '\.json$') } | Where-Object { $_ } | Sort-Object | Select-Object -Last 1
            $srcPath = "$($t.Dir)/$($t.Prefix)$remote.json"
        }
        $localVer = if ($local) { $local.Ver } else { $null }
        if ($localVer -and $remote -le $localVer) { Write-Log "  ok      $($t.Prefix)$localVer (latest)"; continue }

        $newName = "$($t.Prefix)$remote.json"
        $note = ''
        if ($t.File) {
            $cl = try { Get-Raw $t.Repo "$($t.Dir)/CHANGELOG.md" } catch { '' }
            $m = [regex]::Match($cl, "###\s*$([regex]::Escape("$remote"))\s*(.*?)(?=\r?\n###|\z)", 'Singleline')
            if ($m.Success) { $note = (($m.Groups[1].Value -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()) }
        }
        if (-not $PSCmdlet.ShouldProcess($newName, "download (local: $(if ($localVer) { $localVer } else { 'none' }))")) {
            Write-Log "  NEW     $newName available (local $localVer) $note"; continue
        }
        $json = Get-Raw $t.Repo $srcPath
        $null = $json | ConvertFrom-Json -AsHashtable   # must be valid JSON before it replaces anything
        [IO.File]::WriteAllText((Join-Path $ContextPath $newName), $json, [Text.UTF8Encoding]::new($false))
        if ($local) {
            $old = $local.File.Name
            Get-ChildItem (Join-Path (Split-Path $PSScriptRoot -Parent) 'Context') -Filter '*.md' -Recurse | ForEach-Object {
                $txt = [IO.File]::ReadAllText($_.FullName)
                if ($txt.Contains($old)) { [IO.File]::WriteAllText($_.FullName, $txt.Replace($old, $newName), [Text.UTF8Encoding]::new($false)); Write-Log "          links $old -> $newName in $($_.Name)" }
            }
            Remove-Item $local.File.FullName
        }
        Write-Log "  UPDATED $newName (was $localVer) $note"
        $changed++
    } catch {
        Write-Log "  ERROR   $($t.Prefix): $($_.Exception.Message)"
    }
}

# --- pbir bundled schemas ---
# "pbir schema fetch" is anonymous (60 GitHub requests/hour per IP) and fails on the rate limit, so new
# versions go straight into pbir's bundled schema folder - the manual route pbir documents
# ("pbir schema regenerate: use this after manually updating raw schemas"), done on 2026-10-15:
#   <site-packages>\pbir_binary_wheel\runtime\pbir_object_model\schemas\
#     report\<type>\<version>\*.json         <- microsoft/json-schemas fabric/item/report/definition/<type>/<version>/
#     semanticModel\<type>\<version>\*.json  <- microsoft/json-schemas fabric/item/semanticModel/<type>/<version>/
#     theme\reportThemeSchema-<v>.json       <- microsoft/powerbi-desktop-samples "Report Theme JSON Schema"
#     schema_summary.json                    <- "version" per type = pbir's latest known version
# Only types pbir already knows are updated; older version folders stay. A pbir upgrade replaces the
# folder - the next run adds the newer versions again. Known limit: for a $schema version that is not
# published yet (visualContainer 2.13.0 in Oct 2026) pbir falls back to the version compiled into the
# binary (2.9.0 in pbir 0.9.32), not to the files added here.
$pbirCmd = Get-Command pbir -ErrorAction SilentlyContinue
if ($pbirCmd) {
    $pbirSchemas = Join-Path (Split-Path (Split-Path $pbirCmd.Source -Parent) -Parent) 'site-packages\pbir_binary_wheel\runtime\pbir_object_model\schemas'
    $summaryPath = Join-Path $pbirSchemas 'schema_summary.json'
    if (-not (Test-Path $summaryPath)) { Write-Log "  pbir    schema folder not found: $pbirSchemas" }
    else {
        $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
        $added = @()
        $families = @(
            @{ Key = 'report_schemas';         Local = 'report';        Repo = 'microsoft/json-schemas'; Remote = 'fabric/item/report/definition' }
            @{ Key = 'semantic_model_schemas'; Local = 'semanticModel'; Repo = 'microsoft/json-schemas'; Remote = 'fabric/item/semanticModel' }
        )
        foreach ($f in $families) {
            foreach ($type in $summary.($f.Key).PSObject.Properties.Name) {
                try {
                    $localDir = Join-Path $pbirSchemas "$($f.Local)\$type"
                    $localVer = Get-ChildItem $localDir -Directory -ErrorAction SilentlyContinue |
                        ForEach-Object { ConvertTo-Ver $_.Name } | Where-Object { $_ } | Sort-Object | Select-Object -Last 1
                    $remoteVer = Get-GitHubDir $f.Repo "$($f.Remote)/$type" | Where-Object type -eq 'dir' |
                        ForEach-Object { ConvertTo-Ver $_.name } | Where-Object { $_ } | Sort-Object | Select-Object -Last 1
                    if (-not $remoteVer -or ($localVer -and $remoteVer -le $localVer)) { continue }
                    if (-not $PSCmdlet.ShouldProcess("pbir $($f.Local)/$type $remoteVer", "install (pbir has $localVer)")) {
                        Write-Log "  pbir    NEW $($f.Local)/$type $remoteVer available (pbir has $localVer)"; continue
                    }
                    $files = Get-GitHubDir $f.Repo "$($f.Remote)/$type/$remoteVer" | Where-Object { $_.type -eq 'file' -and $_.name -like '*.json' }
                    $stage = @{}
                    foreach ($x in $files) {    # download + parse everything before writing anything
                        $c = Get-Raw $f.Repo "$($f.Remote)/$type/$remoteVer/$($x.name)"; $null = $c | ConvertFrom-Json -AsHashtable; $stage[$x.name] = $c
                    }
                    $dest = Join-Path $localDir "$remoteVer"
                    New-Item -ItemType Directory -Force $dest | Out-Null
                    foreach ($n in $stage.Keys) { [IO.File]::WriteAllText((Join-Path $dest $n), $stage[$n], [Text.UTF8Encoding]::new($false)) }
                    $entry = $summary.($f.Key).$type
                    $entry.version = "$remoteVer"; $entry.files = @($stage.Keys | Sort-Object); $entry.file_count = $stage.Count
                    $added += "$($f.Local)/$type $localVer->$remoteVer"
                } catch { Write-Log "  pbir    ERROR $($f.Local)/$type`: $($_.Exception.Message)" }
            }
        }
        # theme schema: one versioned file per version
        try {
            $tLocal = Get-ChildItem (Join-Path $pbirSchemas 'theme') -Filter 'reportThemeSchema-*.json' |
                ForEach-Object { ConvertTo-Ver ($_.BaseName -replace '^reportThemeSchema-') } | Where-Object { $_ } | Sort-Object | Select-Object -Last 1
            $tRemote = Get-GitHubDir 'microsoft/powerbi-desktop-samples' 'Report Theme JSON Schema' |
                ForEach-Object { ConvertTo-Ver ($_.name -replace '^reportThemeSchema-' -replace '\.json$') } | Where-Object { $_ } | Sort-Object | Select-Object -Last 1
            if ($tRemote -and $tRemote -gt $tLocal) {
                if ($PSCmdlet.ShouldProcess("pbir theme $tRemote", "install (pbir has $tLocal)")) {
                    $name = "reportThemeSchema-$tRemote.json"
                    $c = Get-Raw 'microsoft/powerbi-desktop-samples' "Report Theme JSON Schema/$name"; $null = $c | ConvertFrom-Json -AsHashtable
                    [IO.File]::WriteAllText((Join-Path $pbirSchemas "theme\$name"), $c, [Text.UTF8Encoding]::new($false))
                    $e = $summary.theme_schemas.reportThemeSchema; $e.version = "$tRemote"; $e.files = @($name); $e.file_count = 1
                    $added += "theme $tLocal->$tRemote"
                } else { Write-Log "  pbir    NEW theme $tRemote available (pbir has $tLocal)" }
            }
        } catch { Write-Log "  pbir    ERROR theme: $($_.Exception.Message)" }

        if ($added) {
            $bak = "$summaryPath.bak-$(Get-Date -Format yyyy-MM-dd)"
            if (-not (Test-Path $bak)) { Copy-Item $summaryPath $bak }
            [IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
            $regen = (& pbir schema regenerate 2>&1 | Out-String)
            $ok = $LASTEXITCODE -eq 0
            Write-Log "  pbir    installed: $($added -join ', '); regenerate $(if ($ok) { 'ok' } else { 'FAILED: ' + ($regen.Trim() -split "`n")[-1] })"
            $changed++
        } else { Write-Log '  pbir    bundled schemas up to date' }
    }
    # pbir itself: pbir writes its own update check here
    $uc = Join-Path $env:LOCALAPPDATA 'pbir-tools\Cache\update-check.json'
    $cur = ConvertTo-Ver (((& pbir --version 2>&1 | Out-String) -replace '[^\d.]', ' ').Trim() -split '\s+' | Select-Object -First 1)
    if (Test-Path $uc) {
        $latest = ConvertTo-Ver ((Get-Content $uc -Raw | ConvertFrom-Json).latest_version)
        if ($latest -and $cur -and $latest -gt $cur) { Write-Log "  pbir    NEW pbir $latest available (installed $cur) - not installed automatically" }
    }
} else { Write-Log '  pbir    not installed - skipped' }

Write-Log "done, $changed update(s)"
