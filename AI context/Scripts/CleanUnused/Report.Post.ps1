# CleanUnused\Report.Post.ps1 - part of CleanUnused.ps1, dot-sourced by it (same scope: shares its variables).
# Steps 9-11: report clean-up AFTER the model deletions (filter cards on missing fields, dead formatting, custom visuals).
# Not runnable on its own. No `exit` here: an exit in a dot-sourced file does not stop CleanUnused.ps1.

# ---------------------------------------------------------------------------
# Step 9 (2026-10-06, ClientE Sales Main): report filter cards that point at
# a measure / column / table that does NOT exist in the model (final state,
# after this run's deletions). Found as 29 leftover cards - e.g. a scatter
# chart filtered by `Pareto Demo` / its % of total, 5 hidden tables with
# SalesCurentyearByDocDate & co - from an older model version; Desktop shows
# them with a warning icon in the Filters pane.
# Only EMPTY cards (no "filter" condition) are removed - they can't affect
# data. A card WITH a condition is reported as WARN and left for manual review.
# Also removed (by request, same day): a VISUAL-level empty card on a field
# that exists in the model but isn't used by the visual itself (not in its
# projections/sortDefinition) - leftover filter fields from earlier
# development.
# Also removed (2026-10-15, ClientB - by request; was CleanReportFilters.py): a
# PAGE-level empty card on an existing field when (a) the Filters pane is
# hidden from viewers (report.json objects.outspacePane.visible = false - if it
# is visible, the card may be a tool for viewers: WARN, kept) and (b) no
# bookmark applies a condition to that card (same page + filter name). Its
# condition-less bookmark entries are removed in Step 10c. ClientB: 28 cards on 8
# pages + entries in 9 bookmarks. Report-level cards are never removed for this.
# Scope: filterConfig of visuals, pages and report.json - NOT bookmarks.
# Edits are text-level (the filter object is cut out by brace matching), so
# the rest of the JSON keeps its exact formatting.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 9: report filter cards pointing at missing model fields..."
$finalTables = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$finalColumns = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)   # "Table|Column"
$finalMeasures = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($tf in (Get-ChildItem -Path $tablesPath -Filter "*.tmdl")) {
    $text = Get-Content $tf.FullName -Raw
    $tm = [regex]::Match($text, "(?m)^table\s+(?:'([^']+)'|(\S+))")
    $tn = if ($tm.Groups[1].Success) { $tm.Groups[1].Value } else { $tm.Groups[2].Value }
    [void]$finalTables.Add($tn)
    foreach ($m in [regex]::Matches($text, "(?m)^\tcolumn\s+(?:'([^']+)'|([^\s=]+))")) { [void]$finalColumns.Add("$tn|$(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value })") }
    foreach ($m in [regex]::Matches($text, "(?m)^\tmeasure\s+(?:'([^']+)'|([^\s=]+))")) { [void]$finalMeasures.Add($(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value })) }
}
# Report-level measures (reportExtensions.json) exist too, even though not in
# the model - every "name" there is treated as existing (over-protects only).
foreach ($rx in (Get-ChildItem -Path $reportFolderPath -Recurse -Filter "reportExtensions.json" -File)) {
    foreach ($m in [regex]::Matches((Get-Content $rx.FullName -Raw), '"name"\s*:\s*"([^"]+)"')) { [void]$finalMeasures.Add($m.Groups[1].Value) }
}

# Missing Measure/Column/HierarchyLevel refs anywhere inside a filter's "field".
function Get-MissingFieldRefs {
    param($Node)
    $out = @()
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $Node.PSObject.Properties) {
            $v = $p.Value
            if ($p.Name -in 'Measure', 'Column' -and $v -is [System.Management.Automation.PSCustomObject] -and $v.Property) {
                $ent = $v.Expression.SourceRef.Entity
                if ($ent) {
                    $ok = if ($p.Name -eq 'Measure') { $finalMeasures.Contains($v.Property) } else { $finalColumns.Contains("$ent|$($v.Property)") }
                    if (-not $ok) { $out += "$ent[$($v.Property)]" }
                }
            } elseif ($p.Name -eq 'HierarchyLevel' -and $v.Expression.Hierarchy.Expression.SourceRef.Entity) {
                $ent = $v.Expression.Hierarchy.Expression.SourceRef.Entity
                if (-not $finalTables.Contains($ent)) { $out += "$ent (hierarchy $($v.Expression.Hierarchy.Hierarchy))" }
            }
            $out += Get-MissingFieldRefs -Node $v
        }
    } elseif ($Node -is [System.Array]) {
        foreach ($x in $Node) { $out += Get-MissingFieldRefs -Node $x }
    }
    return $out
}

# Every Measure/Column ref ("Entity|Property") anywhere under $Node, existing or not.
function Get-AllFieldRefs {
    param($Node)
    $out = @()
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $Node.PSObject.Properties) {
            $v = $p.Value
            if ($p.Name -in 'Measure', 'Column' -and $v -is [System.Management.Automation.PSCustomObject] -and $v.Property -and $v.Expression.SourceRef.Entity) {
                $out += "$($v.Expression.SourceRef.Entity)|$($v.Property)"
            }
            $out += Get-AllFieldRefs -Node $v
        }
    } elseif ($Node -is [System.Array]) {
        foreach ($x in $Node) { $out += Get-AllFieldRefs -Node $x }
    }
    return $out
}

$filterFiles = @($jsonFiles | Where-Object { $_.FullName -notmatch '[\\/]bookmarks[\\/]' })
$cardsRemoved = 0; $filesChanged = 0; $cardsWarned = 0

# (2026-10-15) page-level empty cards: Filters pane visibility + bookmark conditions
$paneVisible = $true
$reportJsonPath = Join-Path $reportFolderPath "definition\report.json"
if (Test-Path $reportJsonPath) {
    foreach ($op in @((Get-Content $reportJsonPath -Raw | ConvertFrom-Json).objects.outspacePane)) {
        if ($op.properties.visible.expr.Literal.Value -eq 'false') { $paneVisible = $false }
    }
}
$bmCondCards = [System.Collections.Generic.HashSet[string]]::new()   # "Page|FilterName" a bookmark gives a condition to
foreach ($bf in (Get-ChildItem -Path $bmPath -Filter "*.bookmark.json" -File -ErrorAction SilentlyContinue)) {
    $bsec = (Get-Content $bf.FullName -Raw | ConvertFrom-Json).explorationState.sections
    foreach ($sec in @($bsec.PSObject.Properties)) {
        $bfl = $sec.Value.filters
        foreach ($x in @($bfl.byExpr)) { if ($x -and $x.PSObject.Properties.Name -contains 'filter') { [void]$bmCondCards.Add("$($sec.Name)|$($x.name)") } }
        foreach ($p in @($bfl.byName.PSObject.Properties)) { if ($p.Value.PSObject.Properties.Name -contains 'filter') { [void]$bmCondCards.Add("$($sec.Name)|$($p.Name)") } }
    }
}
$s9PageCardsRemoved = @{}   # page folder -> HashSet of removed card names (for Step 10c bookmarks)
foreach ($jf in $filterFiles) {
    $raw = [System.IO.File]::ReadAllText($jf.FullName)
    if ($raw -notmatch '"filterConfig"') { continue }
    $obj = $raw | ConvertFrom-Json
    $filters = @($obj.filterConfig.filters)
    if ($filters.Count -eq 0) { continue }
    # Visual files only: fields the visual itself shows/sorts by (query = projections + sortDefinition).
    $isVisual = $jf.Name -eq 'visual.json'
    $visualFields = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if ($isVisual -and $obj.visual.query) { foreach ($r in (Get-AllFieldRefs -Node $obj.visual.query)) { [void]$visualFields.Add($r) } }
    $toRemove = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($f in $filters) {
        $rel = $jf.FullName.Substring($reportFolderPath.Length + 1)
        $hasCondition = $f.PSObject.Properties.Name -contains 'filter'
        # (2026-11-01) drillthrough fields of a drillthrough page are empty by design - never removed
        if (($f.PSObject.Properties.Name -contains 'howCreated') -and $f.howCreated -eq 'Drillthrough') { continue }
        $missing = @(Get-MissingFieldRefs -Node $f.field | Select-Object -Unique)
        if ($missing.Count -gt 0) {
            if ($hasCondition) {
                Write-Host "  WARN  $rel : filter '$($f.name)' on $($missing -join ', ') HAS a condition - left as is, review manually" -ForegroundColor DarkYellow
                $cardsWarned++
            } else {
                [void]$toRemove.Add($f.name)
                Write-Host "  DEL   $rel : empty filter card on missing field $($missing -join ', ')"
            }
            continue
        }
        # (2026-10-06, by request) visual-level EMPTY card on a field the visual
        # doesn't use - leftover of earlier development, no effect on data.
        if ($isVisual -and -not $hasCondition) {
            $refs = @(Get-AllFieldRefs -Node $f.field | Select-Object -Unique)
            $notInVisual = @($refs | Where-Object { -not $visualFields.Contains($_) })
            if ($refs.Count -gt 0 -and $notInVisual.Count -gt 0) {
                [void]$toRemove.Add($f.name)
                Write-Host "  DEL   $rel : empty filter card on field not in visual $(($notInVisual -replace '\|', '[') -join '], ')]"
            }
        }
        # (2026-10-15, by request) page-level EMPTY card - filters nothing, viewers can't see the pane
        if ($jf.Name -eq 'page.json' -and -not $hasCondition) {
            $fld = (@(Get-AllFieldRefs -Node $f.field | Select-Object -Unique) -replace '\|', '[') -join '], '
            if ($bmCondCards.Contains("$($jf.Directory.Name)|$($f.name)")) { continue }
            if ($paneVisible) {
                Write-Host "  WARN  $rel : empty page filter card on $fld] kept - the Filters pane is visible to viewers" -ForegroundColor DarkYellow
                $cardsWarned++
            } else {
                [void]$toRemove.Add($f.name)
                Write-Host "  DEL   $rel : empty page filter card on $fld] (Filters pane hidden, no bookmark condition)"
            }
        }
    }
    if ($toRemove.Count -eq 0) { continue }

    $fc = [regex]::Match($raw, '"filterConfig"\s*:\s*\{\s*"filters"\s*:\s*\[')
    if (-not $fc.Success) { Write-Host "  SKIPPED $($jf.FullName) - filterConfig.filters not found as expected" -ForegroundColor Red; continue }
    $arrStart = $fc.Index + $fc.Length - 1
    $spans = Get-JsonArrayObjectSpans -Text $raw -ArrayStart $arrStart
    $keep = @(); $removedHere = 0
    foreach ($s in $spans) {
        $objText = $raw.Substring($s[0], $s[1] - $s[0] + 1)
        $nm = [regex]::Match($objText, '^\{\s*"name"\s*:\s*"([^"]+)"')
        if ($nm.Success -and $toRemove.Contains($nm.Groups[1].Value)) { $removedHere++ } else { $keep += $objText }
    }
    if ($removedHere -ne $toRemove.Count) { Write-Host "  SKIPPED $($jf.FullName) - matched $removedHere of $($toRemove.Count) card(s) in text, file left untouched" -ForegroundColor Red; continue }
    $arrEnd = if ($spans.Count) { $raw.IndexOf(']', $spans[-1][1]) } else { $raw.IndexOf(']', $arrStart) }
    $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $indent = if ($spans.Count) { [regex]::Match($raw.Substring(0, $spans[0][0]), '[ \t]*$').Value } else { '' }
    $closeIndent = [regex]::Match($raw.Substring(0, $arrEnd), '[ \t]*$').Value
    $newArr = if ($keep.Count) { "[" + $nl + $indent + ($keep -join ("," + $nl + $indent)) + $nl + $closeIndent + "]" } else { "[]" }
    $newRaw = $raw.Substring(0, $arrStart) + $newArr + $raw.Substring($arrEnd + 1)
    try { $null = $newRaw | ConvertFrom-Json } catch { Write-Host "  SKIPPED $($jf.FullName) - result is not valid JSON, file left untouched" -ForegroundColor Red; continue }
    [System.IO.File]::WriteAllText($jf.FullName, $newRaw, (New-Object System.Text.UTF8Encoding($false)))
    $cardsRemoved += $removedHere; $filesChanged++
    if ($jf.Name -eq 'page.json') { $s9PageCardsRemoved[$jf.Directory.Name] = $toRemove }
}
Write-Host "  Filter cards removed: $cardsRemoved in $filesChanged file(s); with a condition (left as is): $cardsWarned."
Write-Host "  NOTE: bookmark filters are handled by Step 10 below."
if ($cardsRemoved -gt 0) {
    Write-Host "  .Report was changed on disk - if Desktop is open: close it WITHOUT saving (or use the reload banner), then re-open."
}

# ---------------------------------------------------------------------------
# Step 10 (2026-10-13, ClientB Sales_ClientB - by request): leftovers of an older model
# version that neither Desktop nor the steps above remove. Found in ClientB: 138
# references to missing tables/fields (Targets, תאריכים - dates,
# DateTypeToChooseFrom, מימד מתחלף - changing dimension, ...ByDocDate
# measures, ETL_SA_IncomeFromACC_41004) + ~1,000 dead formatting entries;
# removed by hand in 3 rounds, now in one pass:
#   10a. Visual formatting entries (visual.objects.<card>[i]) that reference a
#        missing field (e.g. conditional-format icons on Targets[...]), or whose
#        selector is only {"metadata": X} where X is not a queryRef of the
#        visual's own fields (width/format of a field removed from the visual).
#   10b. A HIDDEN visual (itself or an ancestor group) whose query uses a
#        missing field (e.g. Charges on a deleted table) -> deleted, with its
#        visualInteractions on the page and its state in bookmarks. A VISIBLE
#        visual with a missing field is only reported (WARN), never deleted.
#   10c. Bookmarks: saved filters (byExpr items / byName entries) and saved
#        sort items (singleVisual.orderBy) on missing fields -> removed; states
#        of visuals deleted by 10b (and the name in options.targetVisualNames)
#        -> removed.
# Field check = Step 9's ($finalTables/$finalColumns/$finalMeasures,
# case-insensitive like Power BI). Files are re-written with ConvertTo-Json
# (2-space indent, as RenameObjects.ps1 does), only when something changed.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 10: dead formatting, hidden visuals and bookmark state on missing fields..."
function Read-JsonFile { param([string]$Path)
    $raw = [System.IO.File]::ReadAllText($Path)
    try { return ($raw | ConvertFrom-Json -DateKind String) } catch { return ($raw | ConvertFrom-Json) }
}
function Save-JsonFile { param($Obj, [string]$Path)
    $json = $Obj | ConvertTo-Json -Depth 100
    $null = $json | ConvertFrom-Json   # never write invalid JSON
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}
$s10Formatting = 0; $s10Visuals = 0; $s10BmItems = 0; $s10BmFiles = 0; $s10Warn = 0
$s10DeadVisuals = [System.Collections.Generic.HashSet[string]]::new()   # "Page|Visual"

# 10b - hidden visuals with a missing field
foreach ($pageDir in (Get-ChildItem -Path $pagesPath -Directory)) {
    $vdir = Join-Path $pageDir.FullName "visuals"
    if (-not (Test-Path $vdir)) { continue }
    $vis = @{}
    foreach ($d in (Get-ChildItem -Path $vdir -Directory)) {
        $vp = Join-Path $d.FullName "visual.json"
        if (Test-Path $vp) { $vis[$d.Name] = Read-JsonFile $vp }
    }
    foreach ($n in @($vis.Keys)) {
        $o = $vis[$n]
        if (-not $o.visual.query) { continue }
        $missing = @(Get-MissingFieldRefs -Node $o.visual.query | Select-Object -Unique)
        if ($missing.Count -eq 0) { continue }
        $hidden = [bool]$o.isHidden; $p = $o.parentGroupName
        while (-not $hidden -and $p -and $vis.ContainsKey($p)) { $hidden = [bool]$vis[$p].isHidden; $p = $vis[$p].parentGroupName }
        if ($hidden) {
            Remove-Item -LiteralPath (Join-Path $vdir $n) -Recurse -Force
            [void]$s10DeadVisuals.Add("$($pageDir.Name)|$n"); $s10Visuals++
            Write-Host "  DEL   hidden visual $($pageDir.Name)/$n : uses missing $($missing -join ', ')"
        } else {
            Write-Host "  WARN  visible visual $($pageDir.Name)/$n uses missing $($missing -join ', ') - left as is, fix manually" -ForegroundColor DarkYellow
            $s10Warn++
        }
    }
    $deadHere = @($s10DeadVisuals | Where-Object { $_.StartsWith("$($pageDir.Name)|") } | ForEach-Object { $_.Split('|')[1] })
    if ($deadHere.Count -gt 0) {
        $pjPath = Join-Path $pageDir.FullName "page.json"
        $pj = Read-JsonFile $pjPath
        if ($pj.visualInteractions) {
            $keepVi = @($pj.visualInteractions | Where-Object { $_.source -notin $deadHere -and $_.target -notin $deadHere })
            if ($keepVi.Count -ne @($pj.visualInteractions).Count) { $pj.visualInteractions = $keepVi; Save-JsonFile $pj $pjPath }
        }
    }
}

# 10a - formatting entries
foreach ($vf in (Get-ChildItem -Path $pagesPath -Recurse -Filter "visual.json" -File)) {
    $o = Read-JsonFile $vf.FullName
    if (-not $o.visual.objects) { continue }
    $refs = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($role in @($o.visual.query.queryState.PSObject.Properties)) { foreach ($pr in @($role.Value.projections)) { if ($pr.queryRef) { [void]$refs.Add($pr.queryRef) } } }
    $changed = $false
    foreach ($card in @($o.visual.objects.PSObject.Properties)) {
        $entries = @($card.Value)
        $keep = @($entries | Where-Object {
            $sel = $_.selector
            $deadSel = $sel -and @($sel.PSObject.Properties.Name).Count -eq 1 -and $sel.metadata -and -not $refs.Contains($sel.metadata)
            -not ($deadSel -or @(Get-MissingFieldRefs -Node $_).Count -gt 0)
        })
        if ($keep.Count -ne $entries.Count) {
            $s10Formatting += $entries.Count - $keep.Count; $changed = $true
            if ($keep.Count) { $o.visual.objects.($card.Name) = $keep } else { $o.visual.objects.PSObject.Properties.Remove($card.Name) }
        }
    }
    if ($changed) { Save-JsonFile $o $vf.FullName }
}
Write-Host "  Formatting entries removed (missing field / field not in visual): $s10Formatting"

# 10c - bookmarks
function Remove-BrokenFilters { param($Filters)
    $n = 0
    if (-not $Filters) { return 0 }
    if ($Filters.byExpr) {
        $all = @($Filters.byExpr); $keep = @($all | Where-Object { @(Get-MissingFieldRefs -Node $_).Count -eq 0 })
        if ($keep.Count -ne $all.Count) { $n += $all.Count - $keep.Count; $Filters.byExpr = $keep }
    }
    if ($Filters.byName) {
        foreach ($p in @($Filters.byName.PSObject.Properties)) {
            if (@(Get-MissingFieldRefs -Node $p.Value).Count -gt 0) { $Filters.byName.PSObject.Properties.Remove($p.Name); $n++ }
        }
    }
    return $n
}
# (2026-10-13, 2nd request) dead tails: a bookmark keeps the state of a visual
# that is no longer on its page (deleted by Step R / 10b / by hand - ClientB had 12
# bookmarks with such states, all only keeping a deleted hidden visual
# hidden) -> state removed; a section for a page that no longer exists (and is
# not the bookmark's activeSection) -> removed. Behaviour does not change.
$s10Tails = 0
$pageVisualNames = @{}
foreach ($pageDir in (Get-ChildItem -Path $pagesPath -Directory)) {
    $set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($d in (Get-ChildItem -Path (Join-Path $pageDir.FullName "visuals") -Directory -ErrorAction SilentlyContinue)) { [void]$set.Add($d.Name) }
    $pageVisualNames[$pageDir.Name] = $set
}
foreach ($bf in (Get-ChildItem -Path $bmPath -Filter "*.bookmark.json" -File -ErrorAction SilentlyContinue)) {
    $b = Read-JsonFile $bf.FullName; $es = $b.explorationState; $n = 0
    if (-not $es) { continue }
    $n += Remove-BrokenFilters $es.filters
    foreach ($sec in @($es.sections.PSObject.Properties)) {
        if (-not $pageVisualNames.ContainsKey($sec.Name)) {
            if ($sec.Name -ne $es.activeSection) { $es.sections.PSObject.Properties.Remove($sec.Name); $n++; $s10Tails++ }
            continue
        }
        $n += Remove-BrokenFilters $sec.Value.filters
        # (2026-10-15) condition-less entries of page cards removed by Step 9
        $gone = $s9PageCardsRemoved[$sec.Name]
        if ($gone -and $sec.Value.filters) {
            $sf = $sec.Value.filters
            if ($sf.byExpr) {
                $all = @($sf.byExpr); $keep = @($all | Where-Object { -not ($gone.Contains([string]$_.name) -and -not ($_.PSObject.Properties.Name -contains 'filter')) })
                if ($keep.Count -ne $all.Count) { $n += $all.Count - $keep.Count; $sf.byExpr = $keep }
            }
            if ($sf.byName) {
                foreach ($p in @($sf.byName.PSObject.Properties)) {
                    if ($gone.Contains($p.Name) -and -not ($p.Value.PSObject.Properties.Name -contains 'filter')) { $sf.byName.PSObject.Properties.Remove($p.Name); $n++ }
                }
            }
        }
        if (-not $sec.Value.visualContainers) { continue }
        foreach ($vc in @($sec.Value.visualContainers.PSObject.Properties)) {
            if ($s10DeadVisuals.Contains("$($sec.Name)|$($vc.Name)")) { $sec.Value.visualContainers.PSObject.Properties.Remove($vc.Name); $n++; continue }
            if (-not $pageVisualNames[$sec.Name].Contains($vc.Name)) { $sec.Value.visualContainers.PSObject.Properties.Remove($vc.Name); $n++; $s10Tails++; continue }
            $n += Remove-BrokenFilters $vc.Value.filters
            $sv = $vc.Value.singleVisual
            if ($sv -and $sv.orderBy) {
                $all = @($sv.orderBy); $keep = @($all | Where-Object { @(Get-MissingFieldRefs -Node $_).Count -eq 0 })
                if ($keep.Count -ne $all.Count) {
                    $n += $all.Count - $keep.Count
                    if ($keep.Count) { $sv.orderBy = $keep } else { $sv.PSObject.Properties.Remove('orderBy') }
                }
            }
        }
    }
    $tv = $b.options.targetVisualNames
    if ($tv) {
        $deadNames = @($s10DeadVisuals | ForEach-Object { $_.Split('|')[1] })
        $keepTv = @($tv | Where-Object { $_ -notin $deadNames })
        if ($keepTv.Count -ne @($tv).Count) { $b.options.targetVisualNames = $keepTv; $n++ }
    }
    if ($n -gt 0) { Save-JsonFile $b $bf.FullName; $s10BmItems += $n; $s10BmFiles++ }
    $left = @(Get-MissingFieldRefs -Node $b | Select-Object -Unique)
    if ($left.Count) { Write-Host "  WARN  bookmark $($bf.Name) still references missing $($left -join ', ') (outside filters/sort) - review manually" -ForegroundColor DarkYellow; $s10Warn++ }
}
Write-Host "  Hidden visuals deleted: $s10Visuals; bookmark items removed: $s10BmItems in $s10BmFiles bookmark(s) (of them dead visual/page states: $s10Tails); warnings: $s10Warn"

# ---------------------------------------------------------------------------
# Step 11 (2026-10-23, ClientD Finance - by request): custom visuals that no
# visual uses. A custom visual is registered in report.json - AppSource ones
# in "publicCustomVisuals" (a list of visual GUIDs), imported .pbiviz ones as a
# resourcePackages entry of type "CustomVisual" plus its folder
# <X>.Report\CustomVisuals\<name>\. A visual uses one through its
# "visualType" (= the GUID / package name). "Used" = that visualType appears in
# any visual.json OR any bookmark (bookmarks keep visual states with their
# visualType) - checked after Steps R/10 removed hidden visuals, so a custom
# visual kept alive only by a deleted visual goes too. Not counted for the
# extra-pass logic - removing a registration frees nothing else.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Step 11: custom visuals that no visual uses..."
$usedVisualTypes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($jf in (Get-ChildItem -Path (Join-Path $reportFolderPath "definition") -Recurse -File -Include "visual.json", "*.bookmark.json")) {
    foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($jf.FullName), '"visualType"\s*:\s*"((?:[^"\\]|\\.)+)"')) { [void]$usedVisualTypes.Add($m.Groups[1].Value) }
}
$s11Removed = @()
if (Test-Path $reportJsonPath) {
    $rj = Read-JsonFile $reportJsonPath
    $changed = $false
    if ($rj.PSObject.Properties['publicCustomVisuals']) {
        $all = @($rj.publicCustomVisuals)
        $keep = @($all | Where-Object { $usedVisualTypes.Contains($_) })
        if ($keep.Count -ne $all.Count) {
            $s11Removed += @($all | Where-Object { $_ -notin $keep } | ForEach-Object { "$_ (AppSource)" })
            if ($keep.Count) { $rj.publicCustomVisuals = $keep } else { $rj.PSObject.Properties.Remove('publicCustomVisuals') }
            $changed = $true
        }
    }
    if ($rj.PSObject.Properties['resourcePackages']) {
        $pk = @($rj.resourcePackages)
        $keepPk = @(foreach ($p in $pk) {
            $names = @($p.name) + @($p.items | ForEach-Object { $_.name })
            if ($p.type -eq 'CustomVisual' -and -not ($names | Where-Object { $usedVisualTypes.Contains([string]$_) })) {
                $s11Removed += "$($p.name) (imported .pbiviz)"
                $dir = Join-Path $reportFolderPath "CustomVisuals\$($p.name)"
                if (Test-Path $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
            } else { $p }
        })
        if ($keepPk.Count -ne $pk.Count) { $rj.resourcePackages = $keepPk; $changed = $true }
    }
    if ($changed) { Save-JsonFile $rj $reportJsonPath }
}
foreach ($x in $s11Removed) { Write-Host "  DEL custom visual $x" }
Write-Host "  Custom visuals removed: $($s11Removed.Count); visual types in use: $($usedVisualTypes.Count)"

