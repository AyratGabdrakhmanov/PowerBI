# Rename page and visual folders based on displayName/title (special characters
# stripped) and update pages.json + page.json/visual.json "name". Also rounds
# each visual's position.x/y/height/width to whole numbers, and enforces
# displayOption = "FitToPage" + objects.displayArea vertical-center on every
# page.json.
#
# Optional, off by default (-ShowMeasureDisplayFolders / -SetMeasureDisplayFolders):
# consolidates every measure's DisplayFolder under a single "__Measures" root
# in the sibling *.SemanticModel - ported from the "Add Display Folder"
# Tabular Editor Advanced Scripting macro (View/Apply actions) so it can run
# without opening Tabular Editor. See Part 4 below.
#
# -RootPath (2026-10-13): run the master copy against any project without
# copying the script next to it - pass the project folder (the one holding
# *.Report / *.SemanticModel) or the *.Report folder itself, e.g.
#   .\RenameObjects.ps1 -RootPath "...\Agency\ClientB\Report"
#   .\RenameObjects.ps1 -RootPath "...\Agency\ClientB\Report\Sales_ClientB.Report"
# Omitted -> the script's own folder (old behaviour).
#
# 2026-10-14.2: visual names are unique across the WHOLE report (one counter for
# all pages, pages in tab order) - not only within a page.
# SCRIPT_VERSION: 2026-10-15.1 - bump this whenever the script changes, so an
# old copy left in another folder (e.g. ClientA\_Context\) can be told apart by
# the version this prints at startup.
# 2026-10-14.1: bookmark visual renames are applied PER PAGE (see Part 3) -
# the old single global map broke slicer states in bookmarks on ClientB.
param(
    [string]$RootPath = $PSScriptRoot,    # project folder or *.Report folder (default: script's folder)
    [switch]$ShowMeasureDisplayFolders,  # Part 4 preview: print old -> new folder per measure, write nothing
    [switch]$SetMeasureDisplayFolders    # Part 4 apply: actually set each measure's DisplayFolder
)
$ScriptVersion = "2026-10-15.1"

# Requires PowerShell 7+ (pwsh): its ConvertTo-Json already produces clean,
# consistent 2-space indentation (verified even on deeply nested page.json
# structures). Windows PowerShell 5.1's ConvertTo-Json aligns indentation to
# content instead (unpredictable spacing) - see POWERBI_PBIP_STRUCTURE.md.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        Write-Host "Relaunching under PowerShell 7+ (pwsh)..."
        # Forward the bound parameters explicitly - with a param() block @args
        # is empty, so -RootPath/switches would be silently dropped.
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
    # *.Report folder passed directly - its parent is the project folder
    # (Part 4 looks for *.SemanticModel there, the BackUp folder sits next to it).
    $reportFolders = @(Get-Item -LiteralPath $RootPath)
    $RootPath = Split-Path $RootPath -Parent
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
    # (?:[^"\\]|\\.)* - a JSON string can contain an escaped quote (e.g. a
    # Hebrew company-name filter value ending in \"M in a bookmark). The old
    # "([^"]*)" ended the string at \", pairing every later quote out of phase,
    # so no name after it ever matched whole - found 2026-09-24 (ClientB, 2
    # bookmarks half-renamed).
    return [regex]::Replace($Text, '"((?:[^"\\]|\\.)*)"', {
        param($m)
        $key = $m.Groups[1].Value
        if ($Map.ContainsKey($key)) { return '"' + $Map[$key] + '"' }
        return $m.Value
    })
}

# Same single-pass safety as Rename-QuotedRefsOnce, for fields whose value
# isn't a bare quoted string but a single-quoted literal nested inside one
# ("navigationSection"/"section"/"drillthroughSection": {... "Value": "'PageName'" ...}).
# drillthroughSection is the page-navigation.Report target field for an
# actionButton whose visualLink.type is "Drillthrough" (the plain
# "navigationSection" field is ALSO present alongside it on those buttons,
# but drillthroughSection is the one Power BI actually uses to resolve the
# Destination page - found 2026-09-15 after a rename left it pointing at a
# folder name that no longer existed, showing as a blank Destination in the
# Action pane).
function Rename-PageRefsOnce {
    param([string]$Text, [hashtable]$Map)
    if ($Map.Count -eq 0) { return $Text }
    $sq = "'"
    $pattern = '(?s)("(?:navigationSection|section|drillthroughSection)"\s*:\s*\{.*?"Value"\s*:\s*")' + $sq + '([^' + $sq + ']*)' + $sq + '(")'
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
    if ($safeDisplay -and $displayName -notmatch '[^\x00-\x7F]') {
        # displayName is pure ASCII and sanitizes to a usable name - use it.
        $baseName = $safeDisplay
    } else {
        # displayName contains at least one non-ASCII character (e.g. Hebrew,
        # even mixed with Latin text) or gives nothing usable - don't keep a
        # half-stripped leftover, fall back to "Page<position>", numbered by this page's
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
        BaseName    = $c.BaseName
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
    if ($item.NewName -eq $item.BaseName) {
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
    #   - visualLink.drillthroughSection ("Drillthrough" button target - the
    #     field Power BI actually uses to resolve the Destination page; the
    #     button also carries a navigationSection alongside it, but that one
    #     is not what drives the Destination dropdown for this action type)
    #   - visualTooltip.section ("Report page" custom tooltip target)
    # All three point to a target page by its folder "name" (same identifier
    # system as pages.json/page.json), but this was never updated by any
    # rename in this script historically - leaving buttons/tooltips pointing
    # at pages that no longer exist after any rename (see
    # POWERBI_PBIP_STRUCTURE.md).
    # Each key is matched non-greedily up to its OWN nested "Value" so we never
    # touch an unrelated string literal that happens to equal a page name.
    Write-Host ""
    Write-Host "Fixing page-reference fields (navigationSection, drillthroughSection, tooltip section) in visuals..."
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

# (2026-10-15, ClientB - user rule "vertical alignment Middle ALWAYS") the custom
# theme carries the default for NEW pages too: visualStyles.page.*.displayArea
# = [{ verticalAlignment: "Middle" }] (syntax as in the Fluent2 base theme, see
# PBIP_Scripts.md). Inserted as text after "visualStyles": { so the rest of the
# theme file keeps its exact formatting; skipped if the theme already has a
# "page" style (it is then reported, not edited).
$reportJsonForTheme = Join-Path $reportFolders[0].FullName "definition\report.json"
if (Test-Path $reportJsonForTheme) {
    $ct = (Get-Content $reportJsonForTheme -Raw | ConvertFrom-Json).themeCollection.customTheme
    $themeFile = if ($ct -and $ct.type -eq 'RegisteredResources') { Join-Path $reportFolders[0].FullName "StaticResources\RegisteredResources\$($ct.name)" }
    if ($themeFile -and (Test-Path $themeFile)) {
        $traw = [System.IO.File]::ReadAllText($themeFile)
        $vs = [regex]::Match($traw, '"visualStyles"\s*:\s*\{')
        $themeObj = $traw | ConvertFrom-Json -AsHashtable
        $pageStyle = $themeObj.visualStyles.page
        if (-not $vs.Success) {
            Write-Host "  WARN theme $($ct.name): no visualStyles block - page vertical alignment not set in the theme" -ForegroundColor DarkYellow
        } elseif ($pageStyle) {
            $tv = $pageStyle['*'].displayArea | ForEach-Object { $_.verticalAlignment }
            if ($tv -contains 'Middle') { Write-Host "  Theme: page vertical alignment = Middle (already)" }
            else { Write-Host "  WARN theme $($ct.name) has a 'page' style without displayArea Middle - review by hand" -ForegroundColor DarkYellow }
        } else {
            $nl = if ($traw.Contains("`r`n")) { "`r`n" } else { "`n" }
            $after = $traw.Substring($vs.Index + $vs.Length)
            $ind = [regex]::Match($after, '^\s*?\r?\n([ \t]*)"').Groups[1].Value   # indentation of the first style key
            if (-not $ind) { $ind = '    ' }
            $step = if ($ind.Length -ge 2) { $ind.Substring(0, $ind.Length / 2) } else { '  ' }
            $block = "$nl$ind`"page`": {$nl$ind$step`"*`": {$nl$ind$step$step`"displayArea`": [$nl$ind$step$step$step{$nl$ind$step$step$step$step`"verticalAlignment`": `"Middle`"$nl$ind$step$step$step}$nl$ind$step$step]$nl$ind$step}$nl$ind},"
            $newRaw = $traw.Substring(0, $vs.Index + $vs.Length) + $block + $after
            try { $null = $newRaw | ConvertFrom-Json -AsHashtable } catch { Write-Host "  SKIPPED theme edit - result is not valid JSON" -ForegroundColor Red; $newRaw = $null }
            if ($newRaw) {
                [System.IO.File]::WriteAllText($themeFile, $newRaw, (New-Object System.Text.UTF8Encoding($false)))
                Write-Host "  OK Theme $($ct.name): added visualStyles.page.*.displayArea verticalAlignment = Middle (default for new pages)"
            }
        }
    }
}

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
# header. A title/header containing any non-ASCII character (e.g. Hebrew) is
# skipped rather than stripped, so it falls through to the next source.
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
            # Any non-ASCII character (e.g. Hebrew) - don't use a half-stripped
            # leftover, fall through to the header / visualType fallback.
            if ($clean -match '[^\x00-\x7F]') { continue }
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
            if ($clean -match '[^\x00-\x7F]') { continue }
            $clean = Get-SafeName $clean
            if ($clean) { return $clean }
        }
    }
    return $null
}

Write-Host ""
Write-Host "Scanning and renaming visuals..."

# Re-list page folders now that pages themselves may have been renamed above.
# In report tab order (pages.json pageOrder, already updated), then any folder
# not listed - a stable order, so the report-wide numbering below is the same
# on every run (idempotent).
$pageFoldersForVisuals = @(Get-ChildItem -Path $pagesPath -Directory)
$orderIndex = @{}; for ($i = 0; $i -lt $pagesJson.pageOrder.Count; $i++) { $orderIndex[$pagesJson.pageOrder[$i]] = $i }
$pageFoldersForVisuals = $pageFoldersForVisuals | Sort-Object { if ($orderIndex.ContainsKey($_.Name)) { $orderIndex[$_.Name] } else { 100000 } }, Name

# Visual names are UNIQUE ACROSS THE WHOLE REPORT (2026-10-14.2, user decision):
# one name registry for all pages, so "slicer3" exists once in the report, not on
# every page. Then a name alone identifies a visual - bookmarks, interactions and
# any tool keyed by visual name can no longer mix up visuals of different pages.
$usedNames = @{}

# Per page (new page folder name -> @{ oldVisualName -> newVisualName }), for
# the bookmark fix-up pass further below. Visual names are unique only WITHIN a
# page ("slicer3" exists on many pages), so the renames must stay scoped to
# their page - one merged map (last page wins) rewrote bookmark slicer states
# onto the wrong slicers (ClientB 2026-10-13: 27 of 30 states on "דוח התחשבנות").
$visualRenameMapByPage = @{}

foreach ($page in $pageFoldersForVisuals) {
    $visualsPath = Join-Path $page.FullName "visuals"
    if (-not (Test-Path $visualsPath)) { continue }

    # Natural sort (slicer2 before slicer10) - plain Sort-Object Name put
    # slicer10 first, so every run renumbered slicer10 -> slicer2, slicer2 ->
    # slicer3 ... and rotated all suffixed names again (found 2026-10-13, ClientB:
    # 338 files changed by a repeat run with nothing to rename).
    $visualFolders = Get-ChildItem -Path $visualsPath -Directory | Sort-Object { [regex]::Replace($_.Name, '\d+', { $args[0].Value.PadLeft(10, '0') }) }
    if ($visualFolders.Count -eq 0) { continue }

    # Pass A: decide the target name for every visual before touching the
    # filesystem. Target names can legitimately collide with OTHER visuals'
    # current (pre-rename) names on this page (e.g. renaming "shape10" to
    # "shape2" while a folder literally called "shape2" still exists,
    # awaiting its own rename later in this loop) - a direct one-shot
    # Rename-Item would fail/skip in that case. Two-phase rename (via a
    # unique temp name first) avoids that entirely.
    # ($usedNames is report-wide - declared before the page loop.)
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
        # POWERBI_PBIP_STRUCTURE.md, "Numeric serialization in PowerShell (rounding gotcha)"). Absorbed from the
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

        $visualRenameMapByPage[$page.Name] = $visualRenameMap
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
#
# Page names are unique report-wide -> one text pass over the whole file.
# Visual names are unique only per page -> applied per section: the state
# under sections.<Page> gets ONLY <Page>'s visual renames, and
# options.targetVisualNames gets the renames of the bookmark's activeSection.
# ---------------------------------------------------------------------------
$bookmarksPath = Join-Path $reportFolders[0].FullName "definition\bookmarks"
if ((Test-Path $bookmarksPath) -and (($renameMap.Count -gt 0) -or ($visualRenameMapByPage.Count -gt 0))) {
    Write-Host ""
    Write-Host "Fixing page/visual references in bookmarks..."
    $bookmarkFixCount = 0
    $utf8NoBOM = New-Object System.Text.UTF8Encoding($false)

    Get-ChildItem -Path $bookmarksPath -Filter "*.bookmark.json" -File | ForEach-Object {
        $bmText = Get-Content $_.FullName -Raw
        # 1) page names (activeSection, sections keys, navigation targets)
        $pageFixedText = Rename-QuotedRefsOnce -Text $bmText -Map $renameMap

        # 2) visual names, scoped to their own page
        $bm = $pageFixedText | ConvertFrom-Json -DateKind String
        $visualChanged = $false
        $es = $bm.explorationState
        if ($es -and $es.sections) {
            foreach ($sec in @($es.sections.PSObject.Properties)) {
                $map = $visualRenameMapByPage[$sec.Name]
                if (-not $map) { continue }
                $secText = $sec.Value | ConvertTo-Json -Depth 100 -Compress
                $newSecText = Rename-QuotedRefsOnce -Text $secText -Map $map
                if ($newSecText -ne $secText) {
                    $sec.Value = $newSecText | ConvertFrom-Json -DateKind String
                    $visualChanged = $true
                }
            }
        }
        $activeMap = if ($es) { $visualRenameMapByPage[$es.activeSection] } else { $null }
        if ($activeMap -and $bm.options -and $bm.options.targetVisualNames) {
            $old = @($bm.options.targetVisualNames)
            $new = @($old | ForEach-Object { if ($activeMap.ContainsKey($_)) { $activeMap[$_] } else { $_ } })
            if (($old -join '|') -ne ($new -join '|')) {
                $bm.options.targetVisualNames = $new
                $visualChanged = $true
            }
        }

        if ($visualChanged) {
            Save-JsonNoBom -Object $bm -Path $_.FullName
        } elseif ($pageFixedText -ne $bmText) {
            [System.IO.File]::WriteAllText($_.FullName, $pageFixedText, $utf8NoBOM)
        } else {
            return
        }
        Write-Host "  OK Fixed bookmark: '$($_.Name)'"
        $bookmarkFixCount++
    }
    if ($bookmarkFixCount -eq 0) { Write-Host "  (none needed updating)" }
}

# ---------------------------------------------------------------------------
# Part 4 (opt-in, off by default - pass -ShowMeasureDisplayFolders or
# -SetMeasureDisplayFolders): consolidate every measure's DisplayFolder under
# a single "__Measures" root, in the sibling *.SemanticModel. Ported from the
# "Add Display Folder" Tabular Editor Advanced Scripting macro (View/Apply
# actions, saved in C:\Users\ayrat\AppData\Local\TabularEditor\
# MacroActions.json) so it can run against the TMDL files directly, without
# opening Tabular Editor. Unlike Parts 1-3 (report-side only, always run),
# this touches the semantic model - a model-structure change the project
# treats as reviewed/confirmed per run, not automatic (see ClientA\CLAUDE.md) -
# so it stays off unless explicitly requested.
#
# Rules (identical to the TE macro):
#   - empty DisplayFolder              -> "__Measures"
#   - already starts with "__Measures" -> skip (already migrated, idempotent)
#   - exactly "_Measures" / "Measures" -> "__Measures"
#   - starts with "_Measures\"         -> "__Measures\<rest>"
#   - starts with "Measures\"          -> "__Measures\<rest>"
#   - anything else                    -> "__Measures\<existing folder>"
# Skips the table named "_Measures" and any table starting with "FP_" or
# "CT_" (same exclusions as the macro).
# ---------------------------------------------------------------------------
if ($ShowMeasureDisplayFolders -or $SetMeasureDisplayFolders) {
    Write-Host ""
    $semanticFolders = @(Get-ChildItem -LiteralPath $RootPath -Directory -Filter "*.SemanticModel")
    if ($semanticFolders.Count -ne 1) {
        Write-Error "Expected exactly one *.SemanticModel folder under: $RootPath (found $($semanticFolders.Count)) - skipping measure display-folder step."
    } else {
        $semanticPath = $semanticFolders[0].FullName
        $tablesPath = Join-Path $semanticPath "definition\tables"

        if ($SetMeasureDisplayFolders) {
            # This step writes to *.SemanticModel table files - unlike the rest
            # of this script (report-side only). Always back up the WHOLE
            # *.SemanticModel folder to ClientA\BackUp\ first, unconditionally, same
            # as ReplaceModelTable.ps1/CleanUnused.ps1 - this project isn't a
            # git repo, no other local revert path (feedback_backup_before_changes).
            $backupRoot = Join-Path (Split-Path $RootPath -Parent) "BackUp"
            $backupDest = Join-Path $backupRoot ("RenameObjects_DisplayFolders_" + (Get-Date -Format "yyyy-MM-dd_HHmmss") + "\" + $semanticFolders[0].Name)
            New-Item -ItemType Directory -Path $backupDest -Force | Out-Null
            Copy-Item -Path (Join-Path $semanticPath "*") -Destination $backupDest -Recurse -Force
            Write-Host "OK Backed up $($semanticFolders[0].Name) to $backupDest"
            Write-Host ""
        }

        function Get-DisplayFolderTarget {
            param([string]$Current)
            if ([string]::IsNullOrEmpty($Current)) { return "__Measures" }
            if ($Current.StartsWith("__Measures")) { return $null }
            if ($Current -eq "_Measures" -or $Current -eq "Measures") { return "__Measures" }
            if ($Current.StartsWith("_Measures\")) { return "__Measures\" + $Current.Substring("_Measures\".Length) }
            if ($Current.StartsWith("Measures\")) { return "__Measures\" + $Current.Substring("Measures\".Length) }
            return "__Measures\" + $Current
        }

        Write-Host $(if ($SetMeasureDisplayFolders) { "Setting measure display folders..." } else { "Previewing measure display folder changes (dry run, no files written)..." })

        $dfTotalChanged = 0
        Get-ChildItem -Path $tablesPath -Filter "*.tmdl" | ForEach-Object {
            $tableFile = $_
            $fileText = Get-Content $tableFile.FullName -Raw
            $tableNameMatch = [regex]::Match($fileText, "^table\s+(?:'([^']+)'|(\S+))")
            $tableName = if ($tableNameMatch.Groups[1].Success) { $tableNameMatch.Groups[1].Value } elseif ($tableNameMatch.Groups[2].Success) { $tableNameMatch.Groups[2].Value } else { $tableFile.BaseName }
            if ($tableName -eq "_Measures" -or $tableName.StartsWith("FP_") -or $tableName.StartsWith("CT_")) { return }

            $measureStarts = [regex]::Matches($fileText, '(?m)^\tmeasure\s')
            if ($measureStarts.Count -eq 0) { return }

            $edits = @()
            for ($i = 0; $i -lt $measureStarts.Count; $i++) {
                $startIdx = $measureStarts[$i].Index
                $endIdx = if ($i + 1 -lt $measureStarts.Count) { $measureStarts[$i + 1].Index } else { $fileText.Length }
                $block = $fileText.Substring($startIdx, $endIdx - $startIdx)

                $nameMatch = [regex]::Match($block, "^\tmeasure\s+(?:'([^']+)'|(\S+?))\s*=")
                if (-not $nameMatch.Success) {
                    $nameMatch = [regex]::Match($block, "^\tmeasure\s+(?:'([^']+)'|(\S+))\s*(?:\r?\n|$)")
                }
                $measureName = if ($nameMatch.Groups[1].Success) { $nameMatch.Groups[1].Value } elseif ($nameMatch.Groups[2].Success) { $nameMatch.Groups[2].Value } else { "<unparsed measure in $($tableFile.Name)>" }

                $dfMatch = [regex]::Match($block, '(?m)^\t+displayFolder:[ \t]*(.*?)\r?$')
                if ($dfMatch.Success) {
                    $current = $dfMatch.Groups[1].Value
                    $target = Get-DisplayFolderTarget -Current $current
                    if ($null -eq $target) { continue }   # already under __Measures
                    $edits += [PSCustomObject]@{
                        Start   = $startIdx + $dfMatch.Groups[1].Index
                        End     = $startIdx + $dfMatch.Groups[1].Index + $dfMatch.Groups[1].Length
                        Text    = $target
                        New     = $target
                        Measure = $measureName
                        Old     = $current
                    }
                } else {
                    $ltMatch = [regex]::Match($block, '(?m)^(\t+)lineageTag:')
                    if (-not $ltMatch.Success) {
                        Write-Host "  WARNING: '$measureName' in $($tableFile.Name) has no displayFolder and no lineageTag to anchor an insert - skipped." -ForegroundColor DarkYellow
                        continue
                    }
                    $target = Get-DisplayFolderTarget -Current ""
                    $insertAt = $startIdx + $ltMatch.Index
                    $edits += [PSCustomObject]@{
                        Start   = $insertAt
                        End     = $insertAt
                        Text    = $ltMatch.Groups[1].Value + "displayFolder: $target`r`n"
                        New     = $target
                        Measure = $measureName
                        Old     = "(none)"
                    }
                }
            }

            if ($edits.Count -eq 0) { return }

            foreach ($e in ($edits | Sort-Object Start)) {
                Write-Host "  $tableName : [$($e.Measure)]  '$($e.Old)' -> '$($e.New)'"
            }
            $dfTotalChanged += $edits.Count

            if ($SetMeasureDisplayFolders) {
                $sb = New-Object System.Text.StringBuilder
                $cursor = 0
                foreach ($e in ($edits | Sort-Object Start)) {
                    [void]$sb.Append($fileText.Substring($cursor, $e.Start - $cursor))
                    [void]$sb.Append($e.Text)
                    $cursor = $e.End
                }
                [void]$sb.Append($fileText.Substring($cursor))
                $newText = $sb.ToString()

                # Same CRLF + fence-parity integrity check as CleanUnused.ps1 -
                # run after every write so a corrupted file is caught
                # immediately, not discovered later when Power BI Desktop fails
                # to open it.
                $bareLf = [regex]::Matches($newText, "(?<!\r)\n").Count
                $fenceCount = ([regex]::Matches($newText, '```')).Count
                if ($bareLf -eq 0 -and ($fenceCount % 2 -eq 0)) {
                    [System.IO.File]::WriteAllText($tableFile.FullName, $newText, (New-Object System.Text.UTF8Encoding($false)))
                } else {
                    Write-Host "  FAIL integrity check: $($tableFile.Name) (bare LF: $bareLf, fence count: $fenceCount) - file left untouched." -ForegroundColor Red
                }
            }
        }

        Write-Host ""
        if ($dfTotalChanged -eq 0) {
            Write-Host "  (no measures needed a display-folder change)"
        } elseif ($SetMeasureDisplayFolders) {
            Write-Host "OK Updated $dfTotalChanged measure(s)."
        } else {
            Write-Host "$dfTotalChanged measure(s) would change - re-run with -SetMeasureDisplayFolders to apply."
        }
    }
}

Write-Host ""
Write-Host "Done!"
