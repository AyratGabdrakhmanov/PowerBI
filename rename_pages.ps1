# Rename page and visual folders based on displayName/title (special characters
# stripped) and update pages.json + page.json/visual.json "name". Also rounds
# each visual's position.x/y/height/width to whole numbers, and enforces
# displayOption = "FitToPage" + objects.displayArea vertical-center on every
# page.json.
#
# SCRIPT_VERSION: 2026-09-08.1 - bump this whenever the script changes, so an
# old copy left in another folder (e.g. Max\_Context\) can be told apart by
# the version this prints at startup.
$ScriptVersion = "2026-09-08.1"

# Requires PowerShell 7+ (pwsh): its ConvertTo-Json already produces clean,
# consistent 2-space indentation (verified even on deeply nested page.json
# structures). Windows PowerShell 5.1's ConvertTo-Json aligns indentation to
# content instead (unpredictable spacing) - see POWERBI_PBIP_STRUCTURE.md.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        Write-Host "Relaunching under PowerShell 7+ (pwsh)..."
        & $pwshCmd.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @args
        exit $LASTEXITCODE
    } else {
        Write-Error "PowerShell 7+ (pwsh) is required but was not found. Install it from https://aka.ms/PSWindows and re-run this script."
        exit 1
    }
}

$reportFolders = Get-ChildItem -Path $PSScriptRoot -Directory -Filter "*.Report"
if ($reportFolders.Count -eq 0) {
    Write-Error "No *.Report folder found under: $PSScriptRoot"
    exit
}
if ($reportFolders.Count -gt 1) {
    Write-Error "Multiple *.Report folders found under: $PSScriptRoot - $($reportFolders.Name -join ', ')"
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

# Folder/name-safe sanitizer: keeps only ASCII letters and digits, strips
# everything else - spaces, #, %, ., -, (), /, non-ASCII (Hebrew, etc.), etc.
# The original text (with punctuation, any script) stays intact in
# displayName / title.text for the UI - only the on-disk folder name gets
# sanitized. Must be ASCII-only, not just "any letter": Power BI Desktop's
# own template/publish packaging throws "Part URI is not valid per rules
# defined in the Open Packaging Conventions specification." for ANY page or
# visual whose folder name (part of its path inside the package) contains
# non-ASCII text - confirmed by testing (Hebrew-named pages/visuals always
# failed publish; ASCII-named ones - including every page Desktop itself
# creates, which always gets a hex name - never did). See fix_nonascii_names.ps1
# for the one-off migration that converted the whole project to this scheme.
function Get-SafeName {
    param([string]$Text)
    if (-not $Text) { return $Text }
    return ($Text -replace '[^A-Za-z0-9]', '')
}

# Single-pass, order-independent replacement for literal quoted references
# like "oldVisualName" -> "newVisualName" (visualInteractions, bookmarks).
# Matches every quoted string in $Text against the ORIGINAL text ONCE via a
# MatchEvaluator lookup, instead of looping per old-name on a mutating
# string. The per-key-loop approach is unsafe whenever old/new name spaces
# overlap - e.g. "visual5" renamed to "visual3" while a separate, unrelated
# "visual3" is renamed to "shape2" in the same pass: a later iteration's
# pattern for old="visual3" can match the "visual3" text that a previous
# iteration just wrote (meant for the renamed visual5), silently rewriting
# it again to "shape2" - a reference now points at the wrong object with no
# error. A single regex pass over the untouched input can't do this: every
# match is resolved against $Map exactly once, from the original text.
# Found in practice 2026-09: dozens of parentGroupName references corrupted
# this way after repeated renames (generic "visualN" names collide easily).
function Rename-QuotedRefsOnce {
    param([string]$Text, [hashtable]$Map)
    if ($Map.Count -eq 0) { return $Text }
    return [regex]::Replace($Text, '"([^"]*)"', {
        param($m)
        $key = $m.Groups[1].Value
        if ($Map.ContainsKey($key)) { return '"' + $Map[$key] + '"' }
        return $m.Value
    })
}

# Same single-pass safety as Rename-QuotedRefsOnce, for the one field whose
# value isn't a bare quoted string but a single-quoted literal nested inside
# one ("navigationSection"/"section": {... "Value": "'PageName'" ...}).
function Rename-PageRefsOnce {
    param([string]$Text, [hashtable]$Map)
    if ($Map.Count -eq 0) { return $Text }
    $sq = "'"
    $pattern = '(?s)("(?:navigationSection|section)"\s*:\s*\{.*?"Value"\s*:\s*")' + $sq + '([^' + $sq + ']*)' + $sq + '(")'
    return [regex]::Replace($Text, $pattern, {
        param($m)
        $key = $m.Groups[2].Value
        if ($Map.ContainsKey($key)) { return $m.Groups[1].Value + $sq + $Map[$key] + $sq + $m.Groups[3].Value }
        return $m.Value
    })
}

Write-Host ""
Write-Host "rename_pages.ps1 version $ScriptVersion"
Write-Host ""
Write-Host "Scanning and renaming pages..."

# Load pages.json to update it later
$pagesJson = Get-Content $pagesJsonPath -Raw | ConvertFrom-Json
$renameMap = @{}

# 1-based position of each page id within pageOrder, so a Hebrew-only page
# falling back to "PageN" gets a number matching its actual place among the
# other pages, not just an arbitrary collision counter.
$pageOrderIndex = @{}
for ($i = 0; $i -lt $pagesJson.pageOrder.Count; $i++) {
    $pageOrderIndex[$pagesJson.pageOrder[$i]] = $i + 1
}

$pageFolders = Get-ChildItem -Path $pagesPath -Directory | Sort-Object Name

# Pass 1: read every page.json and compute each folder's desired base name
# (spaces stripped from displayName). Two different pages can share the same
# displayName (e.g. both set to "Overview") - that's real project content,
# not a script bug, so we resolve it here with a numeric suffix rather than
# silently skipping the rename.
$candidates = @()
$usedNames = @{}
$orphanedFolders = @()

foreach ($folder in $pageFolders) {
    $pageJsonPath = Join-Path $folder.FullName "page.json"
    if (-not (Test-Path $pageJsonPath)) {
        # Folder has no page.json at all - it's not a real page (e.g. a
        # half-written duplicate-page save that got interrupted). Do NOT
        # reserve its name in $usedNames: an orphan sitting on the "clean"
        # name (e.g. "Details1") would otherwise permanently force the real
        # page with that displayName into a suffixed name ("Details12")
        # every time this script runs. Report it instead so the user can
        # decide whether to delete it manually.
        $orphanedFolders += $folder.Name
        continue
    }

    try {
        $pageContent = Get-Content $pageJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Error processing $($folder.Name): $_"
        $usedNames[$folder.Name] = $true
        continue
    }

    $displayName = $pageContent.displayName
    $safeDisplay = if ($displayName) { Get-SafeName $displayName } else { "" }
    if ($safeDisplay) {
        # displayName sanitizes to a usable ASCII name - use it.
        $baseName = $safeDisplay
    } else {
        # displayName is non-ASCII-only (e.g. Hebrew) and gives nothing
        # usable - fall back to "Page<position>", numbered by this page's
        # actual place in pageOrder (not an arbitrary collision counter or a
        # generated hex id), so every non-ASCII-titled page consistently
        # ends up as Page1, Page2, etc. This is stable/idempotent across
        # runs since the position doesn't change just from re-running.
        $position = $pageOrderIndex[$folder.Name]
        $baseName = if ($position) { "Page$position" } else { "Page" }
    }

    $candidates += [PSCustomObject]@{
        OldName     = $folder.Name
        BaseName    = $baseName
        DisplayName = $displayName
        PageContent = $pageContent
    }
}

if ($orphanedFolders.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNING: found page folder(s) with no page.json (not a real page, ignored):"
    foreach ($o in $orphanedFolders) { Write-Host "  - $o" }
    Write-Host "  These are not referenced by pages.json and won't show up in Power BI." -ForegroundColor DarkYellow
    Write-Host "  Likely leftovers from an interrupted save (e.g. duplicate-page action)." -ForegroundColor DarkYellow
    Write-Host "  Safe to delete manually if their 'visuals' folder only duplicates content" -ForegroundColor DarkYellow
    Write-Host "  that already exists in another (real) page." -ForegroundColor DarkYellow
}

# Pass 2: let folders that are already sitting on their correct name keep it
# first, so an "intruder" with a duplicate displayName gets the suffix
# instead of accidentally bumping the page that was already named correctly.
foreach ($c in ($candidates | Where-Object { $_.BaseName -eq $_.OldName })) {
    $usedNames[$c.OldName] = $true
}

# Pass 3: assign deduped target names to the folders that actually need a rename.
$plan = @()
foreach ($c in ($candidates | Where-Object { $_.BaseName -ne $_.OldName })) {
    $safeName = $c.BaseName
    $suffix = 2
    while ($usedNames.ContainsKey($safeName)) {
        $safeName = "$($c.BaseName)$suffix"
        $suffix++
    }
    $usedNames[$safeName] = $true

    $plan += [PSCustomObject]@{
        OldName     = $c.OldName
        NewName     = $safeName
        TempName    = "__tmp_" + [guid]::NewGuid().ToString("N")
        DisplayName = $c.DisplayName
        PageContent = $c.PageContent
    }
}

foreach ($c in ($candidates | Where-Object { $_.BaseName -eq $_.OldName })) {
    Write-Host "  OK Already correct: '$($c.OldName)'"
}

# Pass 4: two-phase rename (temp name first) so a target name can never
# collide with another page folder that hasn't been renamed yet this run.
foreach ($item in $plan) {
    Rename-Item -Path (Join-Path $pagesPath $item.OldName) -NewName $item.TempName
}
foreach ($item in $plan) {
    Rename-Item -Path (Join-Path $pagesPath $item.TempName) -NewName $item.NewName
    if ($item.NewName -eq (Get-SafeName $item.DisplayName)) {
        Write-Host "  OK Renamed: '$($item.OldName)' -> '$($item.NewName)' (displayName: '$($item.DisplayName)')"
    } else {
        Write-Host "  OK Renamed: '$($item.OldName)' -> '$($item.NewName)' (displayName: '$($item.DisplayName)', suffixed due to duplicate)"
    }
    $renameMap[$item.OldName] = $item.NewName

    # Keep page.json "name" in sync with the new folder name
    $item.PageContent.name = $item.NewName
    $newPageJsonPath = Join-Path $pagesPath $item.NewName "page.json"
    Save-JsonNoBom -Object $item.PageContent -Path $newPageJsonPath
}

# Second pass: update pages.json with new names
if ($renameMap.Count -gt 0) {
    Write-Host ""
    Write-Host "Updating pages.json..."

    $newPageOrder = @()
    foreach ($pageId in $pagesJson.pageOrder) {
        if ($renameMap.ContainsKey($pageId)) {
            $newPageOrder += $renameMap[$pageId]
            Write-Host "  Updated: '$pageId' -> '$($renameMap[$pageId])'"
        } else {
            $newPageOrder += $pageId
        }
    }
    $pagesJson.pageOrder = $newPageOrder

    if ($renameMap.ContainsKey($pagesJson.activePageName)) {
        $oldActive = $pagesJson.activePageName
        $pagesJson.activePageName = $renameMap[$oldActive]
        Write-Host "  activePageName: '$oldActive' -> '$($renameMap[$oldActive])'"
    }

    if ($renameMap.ContainsKey($pagesJson.landingPageName)) {
        $oldLanding = $pagesJson.landingPageName
        $pagesJson.landingPageName = $renameMap[$oldLanding]
        Write-Host "  landingPageName: '$oldLanding' -> '$($renameMap[$oldLanding])'"
    }

    Save-JsonNoBom -Object $pagesJson -Path $pagesJsonPath

    Write-Host ""
    Write-Host "OK pages.json saved"

    # Fix page-by-name references in visuals ACROSS ALL PAGES:
    #   - visualLink.navigationSection ("Page navigation" button target)
    #   - visualTooltip.section ("Report page" custom tooltip target)
    # Both point to a target page by its folder "name" (same identifier system
    # as pages.json/page.json), but this was never updated by any rename in
    # this script historically - leaving buttons/tooltips pointing at pages
    # that no longer exist after any rename (see POWERBI_PBIP_STRUCTURE.md).
    # Each key is matched non-greedily up to its OWN nested "Value" so we never
    # touch an unrelated string literal that happens to equal a page name.
    Write-Host ""
    Write-Host "Fixing page-reference fields (navigationSection, tooltip section) in visuals..."
    $navFixCount = 0
    Get-ChildItem -Path $pagesPath -Directory | ForEach-Object {
        $visualsPathForNav = Join-Path $_.FullName "visuals"
        if (-not (Test-Path $visualsPathForNav)) { return }
        Get-ChildItem -Path $visualsPathForNav -Directory | ForEach-Object {
            $vjPathForNav = Join-Path $_.FullName "visual.json"
            if (-not (Test-Path $vjPathForNav)) { return }
            $text = Get-Content $vjPathForNav -Raw
            if ($text -notmatch '"navigationSection"|"section"') { return }

            $newText = Rename-PageRefsOnce -Text $text -Map $renameMap
            if ($newText -ne $text) {
                $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($vjPathForNav, $newText, $utf8NoBOM)
                Write-Host "  OK Fixed page reference: $($vjPathForNav.Substring($pagesPath.Length))"
                $navFixCount++
            }
        }
    }
    if ($navFixCount -eq 0) { Write-Host "  (none needed updating)" }
}

Write-Host ""
Write-Host "Done renaming pages!"

# ---------------------------------------------------------------------------
# Part 1b: enforce standard page display settings on EVERY page.json (not
# just ones renamed above) - displayOption = "FitToPage" and
# objects.displayArea[0].properties.verticalAlignment = 'Middle' (keeps page
# content vertically centered when the canvas doesn't match the report's
# aspect ratio). Standing project convention - checked/fixed on every run.
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Checking page display settings (FitToPage / vertical-center)..."

$displayFixCount = 0
Get-ChildItem -Path $pagesPath -Directory | ForEach-Object {
    $pageJsonPathForDisplay = Join-Path $_.FullName "page.json"
    if (-not (Test-Path $pageJsonPathForDisplay)) { return }

    try {
        $pc = Get-Content $pageJsonPathForDisplay -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Error reading $($pageJsonPathForDisplay): $_"
        return
    }

    $changed = $false

    if ($pc.displayOption -ne "FitToPage") {
        $pc | Add-Member -MemberType NoteProperty -Name displayOption -Value "FitToPage" -Force
        $changed = $true
    }

    if (-not $pc.objects) {
        $pc | Add-Member -MemberType NoteProperty -Name objects -Value ([PSCustomObject]@{}) -Force
        $changed = $true
    }

    $currentVal = $null
    if ($pc.objects.PSObject.Properties.Name -contains 'displayArea') {
        $da = $pc.objects.displayArea
        if ($da -and $da.Count -ge 1) {
            $currentVal = $da[0].properties.verticalAlignment.expr.Literal.Value
        }
    }

    if ($currentVal -ne "'Middle'") {
        $displayAreaEntry = [PSCustomObject]@{
            properties = [PSCustomObject]@{
                verticalAlignment = [PSCustomObject]@{
                    expr = [PSCustomObject]@{
                        Literal = [PSCustomObject]@{
                            Value = "'Middle'"
                        }
                    }
                }
            }
        }
        $pc.objects | Add-Member -MemberType NoteProperty -Name displayArea -Value @($displayAreaEntry) -Force
        $changed = $true
    }

    if ($changed) {
        Save-JsonNoBom -Object $pc -Path $pageJsonPathForDisplay
        Write-Host "  OK Fixed display settings: '$($_.Name)'"
        $displayFixCount++
    }
}
if ($displayFixCount -eq 0) { Write-Host "  (all pages already correct)" }

# ---------------------------------------------------------------------------
# Part 2: rename visual folders within each page, and round each visual's
# position.x/y/height/width to whole numbers (absorbed from the retired
# normalize_visuals.ps1 - see POWERBI_PBIP_STRUCTURE.md).
#
# Preferred name source: visualContainerObjects.title.text (the same field
# that drives the visual's name in Power BI Desktop's Selection/Layers pane -
# see POWERBI_PBIP_STRUCTURE.md). If that's empty, falls back to
# objects.header.text (the visual's own header label - most slicers set this
# even without a container title). Falls back to visual.visualType when
# neither is set, e.g. shapes/tables that were never given a custom title or
# header.
# ---------------------------------------------------------------------------

function Get-VisualTitleName {
    param($VisualJson)

    $titleArr = $VisualJson.visual.visualContainerObjects.title
    if (-not $titleArr) { return $null }

    foreach ($t in $titleArr) {
        $val = $t.properties.text.expr.Literal.Value
        if ($val) {
            # Literal string values are wrapped in single quotes, e.g. "'Page1'"
            $clean = $val -replace "^'", '' -replace "'$", ''
            $clean = Get-SafeName $clean
            if ($clean) { return $clean }
        }
    }
    return $null
}

# Second-tier fallback for visuals without a container title (e.g. slicers,
# which usually rely on objects.header instead of visualContainerObjects.title).
function Get-VisualHeaderName {
    param($VisualJson)

    $headerArr = $VisualJson.visual.objects.header
    if (-not $headerArr) { return $null }

    foreach ($h in $headerArr) {
        $val = $h.properties.text.expr.Literal.Value
        if ($val) {
            $clean = $val -replace "^'", '' -replace "'$", ''
            $clean = Get-SafeName $clean
            if ($clean) { return $clean }
        }
    }
    return $null
}

Write-Host ""
Write-Host "Scanning and renaming visuals..."

# Re-list page folders now that pages themselves may have been renamed above
$pageFoldersForVisuals = Get-ChildItem -Path $pagesPath -Directory

# Accumulated across all pages, for the bookmark fix-up pass further below -
# a bookmark can target visuals on any page, keyed only by visual "name".
$allVisualRenameMap = @{}

foreach ($page in $pageFoldersForVisuals) {
    $visualsPath = Join-Path $page.FullName "visuals"
    if (-not (Test-Path $visualsPath)) { continue }

    $visualFolders = Get-ChildItem -Path $visualsPath -Directory | Sort-Object Name
    if ($visualFolders.Count -eq 0) { continue }

    # Pass A: decide the target name for every visual before touching the
    # filesystem. Target names can legitimately collide with OTHER visuals'
    # current (pre-rename) names on this page (e.g. renaming "shape10" to
    # "shape2" while a folder literally called "shape2" still exists,
    # awaiting its own rename later in this loop) - a direct one-shot
    # Rename-Item would fail/skip in that case. Two-phase rename (via a
    # unique temp name first) avoids that entirely.
    $usedNames = @{}
    $plan = @()

    foreach ($vf in $visualFolders) {
        $vjPath = Join-Path $vf.FullName "visual.json"
        if (-not (Test-Path $vjPath)) { continue }

        try {
            $vjson = Get-Content $vjPath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Error "Error reading $($vf.FullName): $_"
            continue
        }

        # Preferred: title text. Then: objects.header text (slicers, etc).
        # Fallback: visualType (previous logic).
        $baseName = Get-VisualTitleName -VisualJson $vjson
        if (-not $baseName) { $baseName = Get-VisualHeaderName -VisualJson $vjson }
        if (-not $baseName) {
            $baseName = $vjson.visual.visualType
            if (-not $baseName) { $baseName = "visual" }
            $baseName = Get-SafeName $baseName
            if (-not $baseName) { $baseName = "visual" }
        }

        $safeName = $baseName
        $suffix = 2
        while ($usedNames.ContainsKey($safeName)) {
            $safeName = "$baseName$suffix"
            $suffix++
        }
        $usedNames[$safeName] = $true

        # Round position.x/y/height/width to whole numbers - Power BI often
        # writes fractional coordinates from mouse-dragging in the UI (e.g.
        # 496.667). Cast to [long] (not left as [double]) so ConvertTo-Json
        # serializes a clean integer (497) instead of "497.0" (see
        # POWERBI_PBIP_STRUCTURE.md, "ловушка округления"). Absorbed from the
        # now-retired normalize_visuals.ps1.
        $positionChanged = $false
        if ($vjson.position) {
            foreach ($key in @('x', 'y', 'height', 'width')) {
                if ($vjson.position.PSObject.Properties.Name -contains $key) {
                    $rounded = [long][Math]::Round([double]$vjson.position.$key, 0)
                    if ($rounded -ne $vjson.position.$key) {
                        $vjson.position.$key = $rounded
                        $positionChanged = $true
                    }
                }
            }
        }

        $plan += [PSCustomObject]@{
            OldName  = $vf.Name
            NewName  = $safeName
            TempName = "__tmp_" + [guid]::NewGuid().ToString("N")
            VisualJson = $vjson
            PositionChanged = $positionChanged
        }
    }

    # Pass B: move every visual that needs a rename to a unique temp name,
    # clearing the namespace so Pass C can never hit a real collision.
    $toRename = $plan | Where-Object { $_.NewName -ne $_.OldName }
    foreach ($item in $toRename) {
        Rename-Item -Path (Join-Path $visualsPath $item.OldName) -NewName $item.TempName
    }

    # Pass C: move each temp-named folder to its real final name, sync
    # visual.json's own "name" field, and record the rename for page.json.
    $visualRenameMap = @{}
    foreach ($item in $toRename) {
        Rename-Item -Path (Join-Path $visualsPath $item.TempName) -NewName $item.NewName
        Write-Host "  OK Renamed visual: '$($item.OldName)' -> '$($item.NewName)' (page: '$($page.Name)')"
        $visualRenameMap[$item.OldName] = $item.NewName

        $item.VisualJson.name = $item.NewName
        $newVjPath = Join-Path $visualsPath $item.NewName "visual.json"
        Save-JsonNoBom -Object $item.VisualJson -Path $newVjPath
    }

    # Visuals that keep their current name but had position.x/y/height/width
    # rounded still need their visual.json rewritten (Pass C above only saves
    # the ones that got renamed).
    foreach ($item in ($plan | Where-Object { $_.NewName -eq $_.OldName -and $_.PositionChanged })) {
        $vjPath = Join-Path $visualsPath $item.OldName "visual.json"
        Save-JsonNoBom -Object $item.VisualJson -Path $vjPath
        Write-Host "  OK Rounded position: '$($item.OldName)' (page: '$($page.Name)')"
    }

    # Fix visualInteractions source/target references within this page's page.json
    if ($visualRenameMap.Count -gt 0) {
        $pageJsonPathForVisuals = Join-Path $page.FullName "page.json"
        if (Test-Path $pageJsonPathForVisuals) {
            $pageText = Get-Content $pageJsonPathForVisuals -Raw
            $newPageText = Rename-QuotedRefsOnce -Text $pageText -Map $visualRenameMap
            if ($newPageText -ne $pageText) {
                $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($pageJsonPathForVisuals, $newPageText, $utf8NoBOM)
                Write-Host "  OK Updated visual references in '$($page.Name)\page.json'"
            }
        }

        # Fix parentGroupName references in every visual.json on this page: a
        # grouped visual points to its parent group container by the parent's
        # folder "name" (same identifier renamed above). This was never
        # updated by any rename in this script historically - leaving grouped
        # visuals pointing at a group name that no longer exists after a
        # group container gets renamed (its title/header is usually empty, so
        # it falls back to a generic "visual"/"visualN" name and gets
        # renamed on every run). Power BI Desktop silently drops the visual
        # from its group next time it saves such a dangling reference.
        Get-ChildItem -Path $visualsPath -Directory | ForEach-Object {
            $vjPathForGroup = Join-Path $_.FullName "visual.json"
            if (-not (Test-Path $vjPathForGroup)) { return }
            $vtext = Get-Content $vjPathForGroup -Raw
            if ($vtext -notmatch '"parentGroupName"') { return }

            $pattern = '("parentGroupName"\s*:\s*")([^"]*)(")'
            $newVtext = [regex]::Replace($vtext, $pattern, {
                param($m)
                $key = $m.Groups[2].Value
                if ($visualRenameMap.ContainsKey($key)) { return $m.Groups[1].Value + $visualRenameMap[$key] + $m.Groups[3].Value }
                return $m.Value
            })
            if ($newVtext -ne $vtext) {
                $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($vjPathForGroup, $newVtext, $utf8NoBOM)
                Write-Host "  OK Fixed parentGroupName reference: $($_.Name)"
            }
        }

        foreach ($k in $visualRenameMap.Keys) { $allVisualRenameMap[$k] = $visualRenameMap[$k] }
    }
}

# ---------------------------------------------------------------------------
# Part 3: fix page/visual name references inside bookmarks. A bookmark
# captures its state by page "name" (explorationState.activeSection,
# explorationState.sections keys) and by visual "name"
# (options.targetVisualNames, and per-visual overrides under
# sections.<page>.visualContainers). None of this was ever updated by any
# rename in this script historically - leaving bookmarks pointing at pages/
# visuals that no longer exist after a rename, so they silently fail to
# navigate/apply in Power BI.
# ---------------------------------------------------------------------------
$bookmarksPath = Join-Path $reportFolders[0].FullName "definition\bookmarks"
if ((Test-Path $bookmarksPath) -and (($renameMap.Count -gt 0) -or ($allVisualRenameMap.Count -gt 0))) {
    Write-Host ""
    Write-Host "Fixing page/visual references in bookmarks..."
    $bookmarkFixCount = 0
    # Combined into one map/one pass: page names and visual names are
    # distinct generated-name spaces in practice, but merging them costs
    # nothing and guarantees a single safe pass regardless.
    $bookmarkRenameMap = @{}
    foreach ($k in $renameMap.Keys) { $bookmarkRenameMap[$k] = $renameMap[$k] }
    foreach ($k in $allVisualRenameMap.Keys) { $bookmarkRenameMap[$k] = $allVisualRenameMap[$k] }

    Get-ChildItem -Path $bookmarksPath -Filter "*.bookmark.json" -File | ForEach-Object {
        $bmText = Get-Content $_.FullName -Raw
        $newBmText = Rename-QuotedRefsOnce -Text $bmText -Map $bookmarkRenameMap
        if ($newBmText -ne $bmText) {
            $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($_.FullName, $newBmText, $utf8NoBOM)
            Write-Host "  OK Fixed bookmark: '$($_.Name)'"
            $bookmarkFixCount++
        }
    }
    if ($bookmarkFixCount -eq 0) { Write-Host "  (none needed updating)" }
}

Write-Host ""
Write-Host "Done!"
