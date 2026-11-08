# Renames every page/visual folder (and internal "name" field) that contains
# non-ASCII characters (Hebrew, etc.) to a generated hex ID - the same style
# of internal name Power BI Desktop itself uses for natively-created pages/
# visuals. displayName/title text is left untouched (still non-ASCII in the UI).
#
# Why: publishing/exporting a template fails with "Part URI is not valid per
# rules defined in the Open Packaging Conventions specification." on every
# page whose folder name (and therefore its position in
# definition/pages/<name>/...) contains non-ASCII text - regardless of which
# page. Pages/visuals with an ASCII-only name (and any freshly created
# Desktop page, which always gets a hex name) never trigger it. This is a
# ONE-OFF MIGRATION script for a project that already has non-ASCII page/
# visual names from before this was understood - rename_pages.ps1 itself
# already prevents new non-ASCII names going forward (ASCII-only
# Get-SafeName + Page<position> fallback), so this script should not be
# needed in a project that's only ever been touched by the current
# rename_pages.ps1. See POWERBI_PBIP_STRUCTURE.md ("Part URI is not valid" /
# non-ASCII names section) for the full writeup.
#
# -RootPath (2026-10-13): the project folder (holding *.Report) or the
# *.Report folder itself - no need to copy the script next to the report.
# Omitted -> the script's own folder (old behaviour).
param(
    [string]$RootPath = $PSScriptRoot
)

# Requires PowerShell 7+ (pwsh) - see rename_pages.ps1 for why.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        Write-Host "Relaunching under PowerShell 7+ (pwsh)..."
        $fwd = foreach ($k in $PSBoundParameters.Keys) { $v = $PSBoundParameters[$k]; if ($v -is [switch]) { if ($v) { "-$k" } } else { "-$k"; "$v" } }
        & $pwshCmd.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @fwd
        exit $LASTEXITCODE
    } else {
        Write-Error "PowerShell 7+ (pwsh) is required but was not found. Install it from https://aka.ms/PSWindows and re-run this script."
        exit 1
    }
}

if (-not $RootPath -or -not (Test-Path -LiteralPath $RootPath -PathType Container)) {
    Write-Error "Folder not found: '$RootPath' - pass -RootPath <project folder or *.Report folder>."
    exit
}
$RootPath = (Resolve-Path -LiteralPath $RootPath).Path
if ((Split-Path $RootPath -Leaf) -like "*.Report") {
    $reportFolders = @(Get-Item -LiteralPath $RootPath)
} else {
    $reportFolders = @(Get-ChildItem -LiteralPath $RootPath -Directory -Filter "*.Report")
}
if ($reportFolders.Count -eq 0) {
    Write-Error "No *.Report folder found under: $RootPath"
    exit
}
if ($reportFolders.Count -gt 1) {
    Write-Error "Multiple *.Report folders found under: $RootPath - $($reportFolders.Name -join ', ') - pass the *.Report folder itself as -RootPath."
    exit
}

$pagesPath = Join-Path $reportFolders[0].FullName "definition\pages"
$pagesJsonPath = Join-Path $pagesPath "pages.json"

if (-not (Test-Path $pagesPath)) {
    Write-Error "Pages folder not found: $pagesPath"
    exit
}

function Save-JsonNoBom {
    param([object]$Object, [string]$Path)
    $jsonOutput = $Object | ConvertTo-Json -Depth 100
    $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $jsonOutput, $utf8NoBOM)
}

# True if the string contains any character outside the printable ASCII range.
function Test-HasNonAscii {
    param([string]$Text)
    if (-not $Text) { return $false }
    return [regex]::IsMatch($Text, '[^\x20-\x7E]')
}

# 20 lowercase hex characters - matches the style Power BI Desktop itself
# uses for natively-created page/visual folder names (e.g. "577c6991bc39d800dd20").
function New-HexId {
    return ([guid]::NewGuid().ToString("N")).Substring(0, 20)
}

Write-Host ""
Write-Host "Scanning pages for non-ASCII folder names..."

$pagesJson = Get-Content $pagesJsonPath -Raw | ConvertFrom-Json
$pageRenameMap = @{}

$pageFolders = Get-ChildItem -Path $pagesPath -Directory | Sort-Object Name
$usedPageNames = @{}
foreach ($f in $pageFolders) { $usedPageNames[$f.Name] = $true }

$plan = @()
foreach ($folder in $pageFolders) {
    $pageJsonPath = Join-Path $folder.FullName "page.json"
    if (-not (Test-Path $pageJsonPath)) { continue }
    if (-not (Test-HasNonAscii $folder.Name)) { continue }

    $newId = New-HexId
    while ($usedPageNames.ContainsKey($newId)) { $newId = New-HexId }
    $usedPageNames[$newId] = $true

    $plan += [PSCustomObject]@{
        OldName  = $folder.Name
        NewName  = $newId
        TempName = "__tmp_" + [guid]::NewGuid().ToString("N")
    }
}

foreach ($item in $plan) {
    Rename-Item -Path (Join-Path $pagesPath $item.OldName) -NewName $item.TempName
}
foreach ($item in $plan) {
    Rename-Item -Path (Join-Path $pagesPath $item.TempName) -NewName $item.NewName
    $pageRenameMap[$item.OldName] = $item.NewName

    $pjPath = Join-Path $pagesPath $item.NewName "page.json"
    $pj = Get-Content $pjPath -Raw | ConvertFrom-Json
    $displayName = $pj.displayName
    $pj.name = $item.NewName
    Save-JsonNoBom -Object $pj -Path $pjPath
    Write-Host "  OK Renamed page: '$($item.OldName)' -> '$($item.NewName)' (displayName: '$displayName')"
}

if ($pageRenameMap.Count -gt 0) {
    Write-Host ""
    Write-Host "Updating pages.json..."
    $newPageOrder = @()
    foreach ($pageId in $pagesJson.pageOrder) {
        if ($pageRenameMap.ContainsKey($pageId)) { $newPageOrder += $pageRenameMap[$pageId] }
        else { $newPageOrder += $pageId }
    }
    $pagesJson.pageOrder = $newPageOrder
    if ($pageRenameMap.ContainsKey($pagesJson.activePageName)) {
        $pagesJson.activePageName = $pageRenameMap[$pagesJson.activePageName]
    }
    if ($pagesJson.PSObject.Properties.Name -contains 'landingPageName' -and $pageRenameMap.ContainsKey($pagesJson.landingPageName)) {
        $pagesJson.landingPageName = $pageRenameMap[$pagesJson.landingPageName]
    }
    Save-JsonNoBom -Object $pagesJson -Path $pagesJsonPath
    Write-Host "  OK pages.json saved"

    # Fix navigationSection ("Page navigation" buttons) and "section"
    # (custom tooltip page targets) across every visual in every page.
    Write-Host ""
    Write-Host "Fixing page-reference fields (navigationSection, tooltip section) in visuals..."
    $navKeys = @("navigationSection", "section")
    Get-ChildItem -Path $pagesPath -Directory | ForEach-Object {
        $visualsPathForNav = Join-Path $_.FullName "visuals"
        if (-not (Test-Path $visualsPathForNav)) { return }
        Get-ChildItem -Path $visualsPathForNav -Directory | ForEach-Object {
            $vjPathForNav = Join-Path $_.FullName "visual.json"
            if (-not (Test-Path $vjPathForNav)) { return }
            $text = Get-Content $vjPathForNav -Raw
            if ($text -notmatch '"navigationSection"|"section"') { return }
            $changed = $false
            foreach ($key in $navKeys) {
                foreach ($old in $pageRenameMap.Keys) {
                    $pattern = '(?s)("' + $key + '"\s*:\s*\{.*?"Value"\s*:\s*")' + [regex]::Escape("'$old'") + '(")'
                    if ($text -match $pattern) {
                        $newName = $pageRenameMap[$old]
                        $text = [regex]::Replace($text, $pattern, { param($m) $m.Groups[1].Value + "'$newName'" + $m.Groups[2].Value })
                        $changed = $true
                    }
                }
            }
            if ($changed) {
                $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($vjPathForNav, $text, $utf8NoBOM)
                Write-Host "  OK Fixed page reference: $($vjPathForNav.Substring($pagesPath.Length))"
            }
        }
    }
}

Write-Host ""
Write-Host "Scanning visuals for non-ASCII folder names..."

$allVisualRenameMap = @{}
$pageFoldersForVisuals = Get-ChildItem -Path $pagesPath -Directory

foreach ($page in $pageFoldersForVisuals) {
    $visualsPath = Join-Path $page.FullName "visuals"
    if (-not (Test-Path $visualsPath)) { continue }

    $visualFolders = Get-ChildItem -Path $visualsPath -Directory | Sort-Object Name
    if ($visualFolders.Count -eq 0) { continue }

    $usedNames = @{}
    foreach ($vf in $visualFolders) { $usedNames[$vf.Name] = $true }

    $vplan = @()
    foreach ($vf in $visualFolders) {
        $vjPath = Join-Path $vf.FullName "visual.json"
        if (-not (Test-Path $vjPath)) { continue }
        if (-not (Test-HasNonAscii $vf.Name)) { continue }

        $newId = New-HexId
        while ($usedNames.ContainsKey($newId)) { $newId = New-HexId }
        $usedNames[$newId] = $true

        $vplan += [PSCustomObject]@{
            OldName  = $vf.Name
            NewName  = $newId
            TempName = "__tmp_" + [guid]::NewGuid().ToString("N")
        }
    }

    foreach ($item in $vplan) {
        Rename-Item -Path (Join-Path $visualsPath $item.OldName) -NewName $item.TempName
    }
    $visualRenameMap = @{}
    foreach ($item in $vplan) {
        Rename-Item -Path (Join-Path $visualsPath $item.TempName) -NewName $item.NewName
        $visualRenameMap[$item.OldName] = $item.NewName
        $allVisualRenameMap[$item.OldName] = $item.NewName

        $newVjPath = Join-Path $visualsPath $item.NewName "visual.json"
        $vjson = Get-Content $newVjPath -Raw | ConvertFrom-Json
        $vjson.name = $item.NewName
        Save-JsonNoBom -Object $vjson -Path $newVjPath
        Write-Host "  OK Renamed visual: '$($item.OldName)' -> '$($item.NewName)' (page: '$($page.Name)')"
    }

    if ($visualRenameMap.Count -eq 0) { continue }

    # Fix visualInteractions source/target references within this page's page.json
    $pageJsonPathForVisuals = Join-Path $page.FullName "page.json"
    if (Test-Path $pageJsonPathForVisuals) {
        $pageText = Get-Content $pageJsonPathForVisuals -Raw
        $changed = $false
        foreach ($old in $visualRenameMap.Keys) {
            $pattern = [regex]::Escape("`"$old`"")
            if ($pageText -match $pattern) {
                $pageText = $pageText -replace $pattern, "`"$($visualRenameMap[$old])`""
                $changed = $true
            }
        }
        if ($changed) {
            $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($pageJsonPathForVisuals, $pageText, $utf8NoBOM)
            Write-Host "  OK Updated visual references in '$($page.Name)\page.json'"
        }
    }

    # Fix parentGroupName references in every visual.json on this page
    Get-ChildItem -Path $visualsPath -Directory | ForEach-Object {
        $vjPathForGroup = Join-Path $_.FullName "visual.json"
        if (-not (Test-Path $vjPathForGroup)) { return }
        $vtext = Get-Content $vjPathForGroup -Raw
        if ($vtext -notmatch '"parentGroupName"') { return }
        $vchanged = $false
        foreach ($old in $visualRenameMap.Keys) {
            $pattern = '("parentGroupName"\s*:\s*")' + [regex]::Escape($old) + '(")'
            if ($vtext -match $pattern) {
                $newName = $visualRenameMap[$old]
                $vtext = [regex]::Replace($vtext, $pattern, { param($m) $m.Groups[1].Value + $newName + $m.Groups[2].Value })
                $vchanged = $true
            }
        }
        if ($vchanged) {
            $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($vjPathForGroup, $vtext, $utf8NoBOM)
            Write-Host "  OK Fixed parentGroupName reference: $($_.Name)"
        }
    }
}

# Fix page/visual name references inside bookmarks
$bookmarksPath = Join-Path $reportFolders[0].FullName "definition\bookmarks"
if ((Test-Path $bookmarksPath) -and (($pageRenameMap.Count -gt 0) -or ($allVisualRenameMap.Count -gt 0))) {
    Write-Host ""
    Write-Host "Fixing page/visual references in bookmarks..."
    Get-ChildItem -Path $bookmarksPath -Filter "*.bookmark.json" -File | ForEach-Object {
        $bmText = Get-Content $_.FullName -Raw
        $bmChanged = $false
        foreach ($old in $pageRenameMap.Keys) {
            $pattern = [regex]::Escape("`"$old`"")
            if ($bmText -match $pattern) {
                $bmText = $bmText -replace $pattern, "`"$($pageRenameMap[$old])`""
                $bmChanged = $true
            }
        }
        foreach ($old in $allVisualRenameMap.Keys) {
            $pattern = [regex]::Escape("`"$old`"")
            if ($bmText -match $pattern) {
                $bmText = $bmText -replace $pattern, "`"$($allVisualRenameMap[$old])`""
                $bmChanged = $true
            }
        }
        if ($bmChanged) {
            $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($_.FullName, $bmText, $utf8NoBOM)
            Write-Host "  OK Fixed bookmark: '$($_.Name)'"
        }
    }
}

Write-Host ""
Write-Host "Done! Renamed $($pageRenameMap.Count) page(s) and $($allVisualRenameMap.Count) visual(s) to ASCII names."
