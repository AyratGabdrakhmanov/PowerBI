# CleanUnused\Report.Pre.ps1 - part of CleanUnused.ps1, dot-sourced by it (same scope: shares its variables).
# Step R: report clean-up BEFORE the model analysis (dead / unused bookmarks, hidden visuals no bookmark shows).
# Not runnable on its own. No `exit` here: an exit in a dot-sourced file does not stop CleanUnused.ps1.

# ---------------------------------------------------------------------------
# Step R (2026-10-06, by request - ClientE Sales Main): report clean-up,
# BEFORE any model analysis, so measures/tables kept alive only by what is
# removed here go in this same run.
#   R1. Bookmark whose page (explorationState.activeSection) doesn't exist -
#       dead (24 of 24 in Sales Main pointed at deleted/copied pages).
#   R2. Bookmark not called by anything - no button/shape visualLink and no
#       bookmark navigator (its own name or its group's name appears nowhere
#       under pages\). NOTE: a bookmark meant only for the Bookmarks pane
#       goes too.
#   R3. Hidden visual (itself or an ancestor group isHidden) that is NOT
#       USED - no surviving bookmark shows it, and it is not a slicer that
#       still acts while hidden (saved selection = filters the page; or a
#       sync group). Legacy buttons/tables/popups (e.g. 'popupOLD', hidden
#       By-Agent/By-Item tables replaced by Field Parameter tabs, tables on
#       old-model fields). Children of a deleted group go with it; the page's
#       visualInteractions entries for them are removed.
#   bookmarks.json is rebuilt. A VISIBLE button pointing at a deleted or
#   missing bookmark is only reported (WARN), never deleted.
# ---------------------------------------------------------------------------
Write-Host "Step R: report clean-up (dead/unused bookmarks, hidden visuals no bookmark shows)..."
$pagesPath = Join-Path $reportFolderPath "definition\pages"
$bmPath = Join-Path $reportFolderPath "definition\bookmarks"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$existingPages = @(Get-ChildItem -Path $pagesPath -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
$pagesText = (Get-ChildItem -Path $pagesPath -Recurse -Filter "*.json" -File -ErrorAction SilentlyContinue | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
$bmIndexPath = Join-Path $bmPath "bookmarks.json"
$bmIndex = if (Test-Path $bmIndexPath) { Get-Content $bmIndexPath -Raw | ConvertFrom-Json } else { $null }
$bmGroupOf = @{}
if ($bmIndex) { foreach ($it in $bmIndex.items) { foreach ($c in @($it.children)) { if ($c) { $bmGroupOf[$c] = $it.name } } } }
$bookmarks = @{}
foreach ($bf in (Get-ChildItem -Path $bmPath -Filter "*.bookmark.json" -File -ErrorAction SilentlyContinue)) {
    $b = Get-Content $bf.FullName -Raw | ConvertFrom-Json
    $bookmarks[$b.name] = [PSCustomObject]@{ Obj = $b; File = $bf.FullName }
}
# (2026-11-01) visuals named in ANY bookmark - dead ones included - are never deleted as "no bookmark shows them":
# a popup whose bookmark points at a missing page is still a feature to re-link (ClientF Sales v2: 9 commission /
# document popups and, through them, their measures were deleted)
$namedInAnyBookmark = [System.Collections.Generic.HashSet[string]]::new()
foreach ($bk in $bookmarks.Values) {
    foreach ($sec in @($bk.Obj.explorationState.sections.PSObject.Properties)) {
        foreach ($g in @($sec.Value.visualContainerGroups.PSObject.Properties)) { if ($g) { [void]$namedInAnyBookmark.Add($g.Name) } }
        foreach ($v in @($sec.Value.visualContainers.PSObject.Properties)) { if ($v) { [void]$namedInAnyBookmark.Add($v.Name) } }
    }
}
$bmDeleted = 0
foreach ($name in @($bookmarks.Keys)) {
    $b = $bookmarks[$name].Obj
    $reason = $null
    if ($existingPages -notcontains $b.explorationState.activeSection) { $reason = "page $($b.explorationState.activeSection) doesn't exist" }
    elseif (-not $pagesText.Contains($name) -and -not ($bmGroupOf[$name] -and $pagesText.Contains($bmGroupOf[$name]))) { $reason = "not called by any button/navigator" }
    if ($reason) {
        Remove-Item $bookmarks[$name].File -Force
        Write-Host "  DEL bookmark '$($b.displayName)' ($name): $reason"
        $bookmarks.Remove($name); $bmDeleted++
    }
}
if ($bmIndex -and $bmDeleted -gt 0) {
    $items = @()
    foreach ($it in $bmIndex.items) {
        if ($it.PSObject.Properties.Name -contains 'children') {
            $kids = @($it.children | Where-Object { $bookmarks.ContainsKey($_) })
            if ($kids.Count) { $it.children = $kids; $items += $it }
        } elseif ($bookmarks.ContainsKey($it.name)) { $items += $it }
    }
    $bmIndex.items = $items
    [System.IO.File]::WriteAllText($bmIndexPath, (($bmIndex | ConvertTo-Json -Depth 20) -replace "`r?`n", "`r`n") + "`r`n", $utf8)
    Write-Host "  OK bookmarks.json rebuilt: $($items.Count) item(s)"
}

# Visuals any surviving bookmark shows: a group with isHidden=false, or a
# visual listed without display mode 'hidden'.
# NOTE (2026-10-13, ClientB): matched by visual NAME only, not "Page|Visual" - so a
# bookmark showing e.g. pivotTable2 on one page also protects hidden
# same-named visuals on other pages (copied navigation). Deliberately kept
# conservative: an exact page match would have deleted 45 more hidden visuals
# in ClientB (tab On/Off buttons + helper matrices on pages 12-16) - a decision for
# the user, not a silent clean-up.
$shownByBookmark = [System.Collections.Generic.HashSet[string]]::new()
foreach ($bk in $bookmarks.Values) {
    foreach ($sec in @($bk.Obj.explorationState.sections.PSObject.Properties)) {
        foreach ($g in @($sec.Value.visualContainerGroups.PSObject.Properties)) { if ($g -and -not $g.Value.isHidden) { [void]$shownByBookmark.Add($g.Name) } }
        foreach ($v in @($sec.Value.visualContainers.PSObject.Properties)) { if ($v -and $v.Value.singleVisual.display.mode -ne 'hidden') { [void]$shownByBookmark.Add($v.Name) } }
    }
}
$visDeleted = 0
foreach ($pg in $existingPages) {
    $vdir = Join-Path $pagesPath "$pg\visuals"
    if (-not (Test-Path $vdir)) { continue }
    $vis = @{}
    foreach ($vf in (Get-ChildItem -Path $vdir -Recurse -Filter "visual.json" -File)) { $o = Get-Content $vf.FullName -Raw | ConvertFrom-Json; $vis[$o.name] = [PSCustomObject]@{ Obj = $o; Dir = $vf.DirectoryName } }
    $ancestors = { param($n) $out = @(); $p = $vis[$n].Obj.parentGroupName; while ($p -and $vis.ContainsKey($p)) { $out += $p; $p = $vis[$p].Obj.parentGroupName }; $out }
    $toDelete = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($n in $vis.Keys) {
        $chain = @($n) + @(& $ancestors $n)
        $hidden = @($chain | Where-Object { $vis[$_].Obj.isHidden }).Count -gt 0
        $shown = @($chain | Where-Object { $shownByBookmark.Contains($_) }).Count -gt 0
        if ($hidden -and -not $shown) { [void]$toDelete.Add($n) }
    }
    # Hidden but still USED: a slicer with a saved selection keeps filtering
    # the page while invisible, and a synced slicer drives other pages. Keep
    # it - and its ancestor groups, so it isn't left with a dangling parent.
    foreach ($n in @($toDelete)) {
        $o = $vis[$n].Obj
        $hasSelection = @($o.visual.objects.general | Where-Object { $_.properties.filter }).Count -gt 0
        $isSynced = $null -ne $o.visual.syncGroup
        if ($hasSelection -or $isSynced) {
            Write-Host "  KEEP hidden visual $n ($($o.visual.visualType)): $(if ($hasSelection) { 'slicer with a saved selection - still filters the page' } else { 'synced slicer' })"
            foreach ($k in (@($n) + @(& $ancestors $n))) { [void]$toDelete.Remove($k) }
        }
    }
    # a page whose buttons call a bookmark that is missing / deleted above: its hidden visuals are the popups those
    # bookmarks showed (old bookmarks may name them by pre-PBIR ids, so the name check alone misses them)
    $pageText = ($vis.Values | ForEach-Object { $_.Obj | ConvertTo-Json -Depth 40 -Compress }) -join "`n"
    $callsDeadBm = @([regex]::Matches($pageText, "'(Bookmark[0-9a-f]{20})'") | Where-Object { -not $bookmarks.ContainsKey($_.Groups[1].Value) }).Count -gt 0
    foreach ($n in @($toDelete)) {
        if ($callsDeadBm -or @(@($n) + @(& $ancestors $n) | Where-Object { $namedInAnyBookmark.Contains($_) }).Count -gt 0) {
            Write-Host "  WARN  hidden visual $pg/$n kept: its bookmark is missing / dead - re-link it with a new bookmark or delete it by hand" -ForegroundColor DarkYellow
            foreach ($k in (@($n) + @(& $ancestors $n))) { [void]$toDelete.Remove($k) }
        }
    }
    if ($toDelete.Count -eq 0) { continue }
    foreach ($n in $toDelete) { Remove-Item $vis[$n].Dir -Recurse -Force -ErrorAction SilentlyContinue }
    $pageJsonPath = Join-Path $pagesPath "$pg\page.json"
    $pageObj = Get-Content $pageJsonPath -Raw | ConvertFrom-Json
    if ($pageObj.visualInteractions) {
        $before = @($pageObj.visualInteractions).Count
        $pageObj.visualInteractions = @($pageObj.visualInteractions | Where-Object { -not $toDelete.Contains($_.source) -and -not $toDelete.Contains($_.target) })
        if (@($pageObj.visualInteractions).Count -ne $before) {
            [System.IO.File]::WriteAllText($pageJsonPath, (($pageObj | ConvertTo-Json -Depth 50) -replace "`r?`n", "`r`n") + "`r`n", $utf8)
        }
    }
    Write-Host "  DEL $($toDelete.Count) hidden visual(s) on page '$($pageObj.displayName.Trim())' that no bookmark shows"
    $visDeleted += $toDelete.Count
}
# Visible callers of bookmarks that don't exist (after R1/R2) - report only.
foreach ($vf in (Get-ChildItem -Path $pagesPath -Recurse -Filter "visual.json" -File -ErrorAction SilentlyContinue)) {
    foreach ($m in [regex]::Matches((Get-Content $vf.FullName -Raw), "'(Bookmark[0-9a-f]{20})'")) {
        if (-not $bookmarks.ContainsKey($m.Groups[1].Value)) { Write-Host "  WARN visual $($vf.Directory.Name) calls missing bookmark $($m.Groups[1].Value) - left as is" -ForegroundColor DarkYellow }
    }
}
# (2026-10-13, ClientB) navigation buttons - report only, never changed:
#  - tab pair <X>On / <X>Off: "On" is the highlighted current tab (a bookmark
#    shows it instead of "Off" on the same spot) - it must link to the same
#    bookmark as its "Off". ClientB Page2: 4 "On" linked to missing bookmarks,
#    2 to another tab's bookmark (clicking the current tab switched views).
#  - a VISIBLE button whose bookmark opens another page (activeSection is not
#    the button's page) - usually navigation copied with a page; ask whether
#    it is intended (ClientB: "Return to default" on 3 pages).
$bmLinkOf = { param($o) $t = $o | ConvertTo-Json -Depth 40 -Compress; $m = [regex]::Match($t, '"bookmark":\{"expr":\{"Literal":\{"Value":"''([^'']+)''"'); if ($m.Success) { $m.Groups[1].Value } }
foreach ($pg in $existingPages) {
    $vdir = Join-Path $pagesPath "$pg\visuals"
    if (-not (Test-Path $vdir)) { continue }
    $btn = @{}
    foreach ($vf in (Get-ChildItem -Path $vdir -Recurse -Filter "visual.json" -File)) {
        $o = Get-Content $vf.FullName -Raw | ConvertFrom-Json
        if ($o.visual.visualType -eq 'actionButton') { $btn[$o.name] = $o }
    }
    foreach ($n in @($btn.Keys)) {
        $link = & $bmLinkOf $btn[$n]
        if ($n.EndsWith('On')) {
            $pair = $n.Substring(0, $n.Length - 2) + 'Off'
            if ($btn.ContainsKey($pair)) {
                $pairLink = & $bmLinkOf $btn[$pair]
                if ($pairLink -and $link -ne $pairLink) { Write-Host "  WARN tab button $pg/$n links to '$link', its pair $pair to '$pairLink' - should be the same bookmark, left as is" -ForegroundColor DarkYellow }
            }
        }
        if ($link -and $bookmarks.ContainsKey($link) -and -not $btn[$n].isHidden) {
            $act = $bookmarks[$link].Obj.explorationState.activeSection
            if ($act -and $act -ne $pg) { Write-Host "  WARN visible button $pg/$n opens another page ($act) via bookmark '$($bookmarks[$link].Obj.displayName)' - intended? left as is" -ForegroundColor DarkYellow }
        }
    }
}
Write-Host "  Bookmarks deleted: $bmDeleted, hidden visuals deleted: $visDeleted"
Write-Host ""

