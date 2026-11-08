# CleanUnused\Model.ps1 - part of CleanUnused.ps1, dot-sourced by it (same scope: shares its variables).
# Steps 0-8: qualify column refs, parse the model, Field Parameters, report usage, unused measures / calculated columns / tables; exemptions.
# Not runnable on its own. No `exit` here: an exit in a dot-sourced file does not stop CleanUnused.ps1.

# ---------------------------------------------------------------------------
# Step 0: qualify bare COLUMN references before any usage analysis. Every
# check below relies on this project's convention (Best Practice.txt: "Use
# table names before column names, avoid table names before the measures") -
# bare `[Name]` = measure, `Table[Name]` = column. DAX itself doesn't enforce
# it: a bare `[Name]` inside a row context (SUMX('DocsSales', ...[LineFactor]
# ...), or a calculated column reading its own table) is a COLUMN. Left as
# is, such a column looks unused and gets deleted while still in use - found
# the hard way 2026-09-24 (ClientB): Val_PayNoVat_Loc/_Sys read DocsSales
# [LIneFactor] as bare `[LineFactor]`, so LIneFactor and DocTotalTotal (read
# only by LIneFactor) were deleted, breaking Total_Paid_Acquitted. Fix the
# cause, not the symptom - bring the DAX in line with the convention first:
#   - bare [Name] matches a measure (case-insensitive) -> measure, untouched
#   - else matches exactly ONE column in the whole model -> rewritten in the
#     file as 'Table'[Name], then judged by the normal rules below
#   - else matches SEVERAL columns -> DAX untouched, and every one of those
#     columns is kept (never deleted) - can't tell which one is read
#   - else (no match) -> untouched, printed as FYI
# Only DAX is rewritten: measures, calculated columns, calculationItems and
# `partition X = calculated` - NOT `= m` partitions (Power Query `[Field]`
# is record access, not DAX). Metadata lines (`formatString: ...[Red]`,
# annotations, /// descriptions) and text inside "..." are skipped. A name
# that also appears as a "Name" string literal in the same expression is
# skipped too - most likely an ADDCOLUMNS/SELECTCOLUMNS/SUMMARIZE alias of a
# virtual-table column, which qualifying would silently re-point at a model
# column.
# ---------------------------------------------------------------------------
Write-Host "Qualifying bare [Column] references (Best Practice: table name before column name)..."
$bareRefPattern = "(?<![\w'\]])\[([^\[\]]+)\]"
$metadataLinePattern = '^\s*(?:[A-Za-z]+\s*:\s|annotation\s|changedProperty\s|///)'
$ambiguousBareColumns = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)   # "Table|Column" keys, never deleted
$q0Log = [System.Collections.Generic.List[string]]::new()

$q0Files = @()
foreach ($tf in (Get-ChildItem -Path $tablesPath -Filter "*.tmdl")) {
    $text = Get-Content $tf.FullName -Raw
    $tableNameMatch = [regex]::Match($text, "(?m)^table\s+(?:'([^']+)'|(\S+))")
    $tableName = if ($tableNameMatch.Groups[1].Success) { $tableNameMatch.Groups[1].Value } elseif ($tableNameMatch.Groups[2].Success) { $tableNameMatch.Groups[2].Value } else { $tf.BaseName }
    $q0Files += [PSCustomObject]@{ Path = $tf.FullName; Text = $text; Constructs = @(Get-TmdlConstructs -Text $text -FilePath $tf.FullName -TableName $tableName) }
}
$q0All = $q0Files | ForEach-Object { $_.Constructs }
$q0MeasureNames = [System.Collections.Generic.HashSet[string]]::new([string[]]($q0All | Where-Object { $_.IsMeasure -and $_.Name } | Select-Object -ExpandProperty Name), [StringComparer]::OrdinalIgnoreCase)
$q0Columns = @{}   # column name (case-insensitive, PowerShell hashtable default) -> every column with that name
foreach ($c in ($q0All | Where-Object { $_.Kind -eq 'column' -and $_.Name })) {
    if (-not $q0Columns.ContainsKey($c.Name)) { $q0Columns[$c.Name] = @() }
    $q0Columns[$c.Name] += [PSCustomObject]@{ Table = $c.Table; Name = $c.Name }
}

foreach ($f in $q0Files) {
    $changed = 0
    $sb = New-Object System.Text.StringBuilder
    $cursor = 0
    foreach ($c in ($f.Constructs | Sort-Object StartIdx)) {
        $isDax = $c.IsMeasure -or ($c.Kind -eq 'calculationItem') -or
                 ($c.Kind -eq 'column' -and $c.IsCalcDax) -or
                 ($c.Kind -eq 'partition' -and $c.Block -match '^\t*partition\s+(?:''[^'']+''|\S+)\s*=\s*calculated\b')
        if (-not $isDax) { continue }
        $where = "$($c.Table) / $($c.Kind) $($c.Name)"
        $lines = $c.Block -split '(?<=\n)'
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $metadataLinePattern) { continue }
            $line = $lines[$i]
            $lines[$i] = [regex]::Replace($line, $bareRefPattern, [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                if (($line.Substring(0, $m.Index).Split('"').Count - 1) % 2 -eq 1) { return $m.Value }   # inside "..."
                $refName = $m.Groups[1].Value
                if ($q0MeasureNames.Contains($refName)) { return $m.Value }
                $cols = $q0Columns[$refName]
                if (-not $cols) { $q0Log.Add("  FYI   $where : [$refName] - neither a measure nor a column, left as is"); return $m.Value }
                if ($cols.Count -gt 1) {
                    foreach ($col in $cols) { [void]$ambiguousBareColumns.Add("$($col.Table)|$($col.Name)") }
                    $q0Log.Add("  WARN  $where : [$refName] - column in $($cols.Count) tables ($(($cols.Table) -join ', ')), left as is, all kept")
                    return $m.Value
                }
                if ([regex]::IsMatch($c.Block, '(?i)"' + [regex]::Escape($refName) + '"')) {
                    $q0Log.Add("  WARN  $where : [$refName] - also a ""$refName"" string literal (virtual-table alias?), left as is")
                    return $m.Value
                }
                $qualified = "'" + ($cols[0].Table -replace "'", "''") + "'[" + $cols[0].Name + "]"
                $q0Log.Add("  FIX   $where : [$refName] -> $qualified")
                return $qualified
            })
        }
        $newBlock = $lines -join ''
        if ($newBlock -ne $c.Block) {
            $changed++
            [void]$sb.Append($f.Text.Substring($cursor, $c.StartIdx - $cursor))
            [void]$sb.Append($newBlock)
            $cursor = $c.EndIdx
        }
    }
    if ($changed -gt 0) {
        [void]$sb.Append($f.Text.Substring($cursor))
        $newText = $sb.ToString()
        if (Test-TmdlIntegrity -Text $newText -FilePath $f.Path) {
            [System.IO.File]::WriteAllText($f.Path, $newText, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  OK $($f.Path): qualified column reference(s) in $changed construct(s)"
        } else {
            Write-Host "  SKIPPED $($f.Path) - integrity check failed, file left untouched. Investigate before retrying." -ForegroundColor Red
        }
    }
}
$q0Log | Select-Object -Unique | ForEach-Object { Write-Host $_ }
if ($q0Log.Count -eq 0) { Write-Host "  No bare column references found." }
Write-Host ""

# ---------------------------------------------------------------------------
# Step 1: parse every table .tmdl - collect all constructs (measures,
# calculated columns, calculated-table partitions, calculation-group items)
# and all .Report json files, up front - Field Parameter, measure, and
# other-table analysis below all read from these same two collections.
# ---------------------------------------------------------------------------
Write-Host "Scanning $tablesPath ..."
$allConstructs = @()
$existingTableNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$tableFiles = Get-ChildItem -Path $tablesPath -Filter "*.tmdl"
foreach ($tf in $tableFiles) {
    $text = Get-Content $tf.FullName -Raw
    $tableNameMatch = [regex]::Match($text, "(?m)^table\s+(?:'([^']+)'|(\S+))")
    $tableName = if ($tableNameMatch.Groups[1].Success) { $tableNameMatch.Groups[1].Value } elseif ($tableNameMatch.Groups[2].Success) { $tableNameMatch.Groups[2].Value } else { $tf.BaseName }
    [void]$existingTableNames.Add($tableName)
    $allConstructs += Get-TmdlConstructs -Text $text -FilePath $tf.FullName -TableName $tableName
}
Write-Host "  Found $($tableFiles.Count) table file(s)."
$jsonFiles = Get-ChildItem -Path $reportFolderPath -Recurse -Include "*.json" -File

# Report text used for every USAGE check below (Field Parameters, measures,
# calculated columns, tables): the file with its EMPTY filter cards cut out
# (filterConfig objects with no "filter" condition; bookmarks kept as is).
# An empty card filters nothing, so it is not usage - and Step 9 deletes it.
# Before this (2026-10-06, ClientE Sales Main) a measure kept alive only by
# such a card survived the pass in which Step 9 removed the card, and needed
# a second run (5 measures: Target balance, Daily Target Balance, ...).
# (2026-10-15, ClientB) bookmarks too: a bookmark filter entry with no condition
# (byExpr item / byName entry without "filter" - the saved "empty" state of a
# filter card) filters nothing, so it is not usage either. Before this the
# empty bookmark entries of the empty page card Projects[ProjectName] (Page2)
# kept table Projects alive in pass 1; Step 10c removed them, and only pass 2
# deleted the table. Everything else in a bookmark (visual states, slicer
# selections, sort, projections) still counts.
function Remove-EmptyBookmarkFilters { param($Filters)
    if (-not $Filters) { return }
    if ($Filters.byExpr) { $Filters.byExpr = @(@($Filters.byExpr) | Where-Object { $_.PSObject.Properties.Name -contains 'filter' }) }
    if ($Filters.byName) {
        foreach ($p in @($Filters.byName.PSObject.Properties)) {
            if (-not ($p.Value.PSObject.Properties.Name -contains 'filter')) { $Filters.byName.PSObject.Properties.Remove($p.Name) }
        }
    }
}
$usageText = @{}
foreach ($jf in $jsonFiles) {
    $text = Get-Content $jf.FullName -Raw
    if ($jf.FullName -match '[\\/]bookmarks[\\/]' -and $jf.Name -like '*.bookmark.json') {
        try {
            $bo = $text | ConvertFrom-Json
            $es = $bo.explorationState
            if ($es) {
                Remove-EmptyBookmarkFilters $es.filters
                foreach ($sec in @($es.sections.PSObject.Properties)) {
                    Remove-EmptyBookmarkFilters $sec.Value.filters
                    foreach ($vc in @($sec.Value.visualContainers.PSObject.Properties)) { Remove-EmptyBookmarkFilters $vc.Value.filters }
                }
                $text = $bo | ConvertTo-Json -Depth 100
            }
        } catch { }   # unreadable bookmark: use the raw text (over-protects only)
    }
    if ($jf.FullName -notmatch '[\\/]bookmarks[\\/]') {
        foreach ($fc in @([regex]::Matches($text, '"filterConfig"\s*:\s*\{\s*"filters"\s*:\s*\[')) | Sort-Object Index -Descending) {
            $spans = Get-JsonArrayObjectSpans -Text $text -ArrayStart ($fc.Index + $fc.Length - 1)
            for ($k = $spans.Count - 1; $k -ge 0; $k--) {
                $s = $spans[$k]
                if (-not [regex]::IsMatch($text.Substring($s[0], $s[1] - $s[0] + 1), '"filter"\s*:')) {
                    $text = $text.Remove($s[0], $s[1] - $s[0] + 1)
                }
            }
        }
    }
    $usageText[$jf.FullName] = $text
}

# Thin reports (-ThinReports, 2026-11-06): live-connected reports of the published model. Their usage counts
# (visuals, filters, bookmarks - raw text, empty cards included: over-protects only), but their files are
# never edited - they are NOT in $jsonFiles, which Report.Post edits. Usage loops below read $usageFiles.
$thinJsonFiles = @()
foreach ($tr in $thinReportFolders) { $thinJsonFiles += @(Get-ChildItem -Path $tr -Recurse -Include "*.json" -File) }
foreach ($jf in $thinJsonFiles) { $usageText[$jf.FullName] = Get-Content $jf.FullName -Raw }
$usageFiles = @($jsonFiles) + @($thinJsonFiles)
if ($thinJsonFiles.Count -gt 0) { Write-Host "  Thin report(s): $($thinReportFolders.Count) folder(s), $($thinJsonFiles.Count) json file(s) - usage only, not edited." }

# RLS roles (definition\roles\*.tmdl): `tablePermission <Table> = <DAX filter>`.
# Unconditional usage - the table a role filters and anything its filter DAX
# reads (measures, Table[Column]) must survive. Found 2026-10-06 in ClientE
# Sales Main: RLS_Agents (no report/DAX usage, only a role filter + a
# relationship) was deleted, leaving both roles pointing at a missing table.
$roleText = ""
if (Test-Path $rolesPath) {
    $roleText = (Get-ChildItem -Path $rolesPath -Filter "*.tmdl" | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
}
$roleTables = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($m in [regex]::Matches($roleText, "(?m)^\s*tablePermission\s+(?:'([^']+)'|(\S+))\s*=")) {
    [void]$roleTables.Add($(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }))
}
foreach ($t in (Get-QualifiedTableRefs -Text $roleText)) { [void]$roleTables.Add($t) }
if ($roleTables.Count -gt 0) { Write-Host "  RLS roles filter/read table(s): $($roleTables -join ', ') - kept unconditionally." }
Write-Host ""

# ---------------------------------------------------------------------------
# Step 2: Field Parameter tables - evaluated and deleted FIRST (see ORDER
# MATTERS in the header comment). Detected generically, not by a hardcoded
# name list: a Field Parameter is a calculated table whose partition source
# DAX is a row constructor of NAMEOF(...) entries - the shape Power BI
# Desktop itself always generates, so this also catches any Field Parameter
# added later.
# ---------------------------------------------------------------------------
Write-Host "Scanning for Field Parameter tables..."
$fpTables = foreach ($p in ($allConstructs | Where-Object { $_.Kind -eq 'partition' -and $_.Block -match 'NAMEOF\s*\(' })) {
    [PSCustomObject]@{
        Name            = $p.Table
        FilePath        = $p.FilePath
        CalendarRelated = [regex]::IsMatch($p.Block, "NAMEOF\s*\(\s*(?:'Calendar'|Calendar)\[")
    }
}
$fpTableNames = [System.Collections.Generic.HashSet[string]]::new([string[]]@($fpTables | Select-Object -ExpandProperty Name), [StringComparer]::OrdinalIgnoreCase)
Write-Host "  Found $($fpTables.Count) Field Parameter table(s): $(($fpTables | Select-Object -ExpandProperty Name) -join ', ')"
$excludedFP = $fpTables | Where-Object { $_.CalendarRelated }
if ($excludedFP) {
    Write-Host "  Excluded (Calendar-related, never auto-deleted): $(($excludedFP | Select-Object -ExpandProperty Name) -join ', ')"
}
Write-Host ""

Write-Host "Scanning $reportFolderPath for Field Parameter table usage..."
$fpCandidates = $fpTables | Where-Object { -not $_.CalendarRelated }
$fpUsed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($jf in $usageFiles) {
    $text = $usageText[$jf.FullName]   # empty filter cards excluded - see $usageText
    foreach ($fp in $fpCandidates) {
        if ($fpUsed.Contains($fp.Name)) { continue }
        if ([regex]::IsMatch($text, '(?i)"Entity"\s*:\s*"' + [regex]::Escape((ConvertTo-JsonStringBody $fp.Name)) + '"')) {
            [void]$fpUsed.Add($fp.Name)
        }
    }
}
$unusedFP = $fpCandidates | Where-Object { -not $fpUsed.Contains($_.Name) }
Write-Host "Field Parameter tables: $($fpCandidates.Count) checked (excluding Calendar-related), used: $($fpUsed.Count), unused: $($unusedFP.Count)"
Write-Host ""

$fpNamesToRemove = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if ($unusedFP.Count -eq 0) {
    Write-Host "No unused Field Parameter tables to delete."
} else {
    Write-Host "Deleting $($unusedFP.Count) unused Field Parameter table(s): $(($unusedFP | Select-Object -ExpandProperty Name) -join ', ')"
    foreach ($n in ($unusedFP | Select-Object -ExpandProperty Name)) { [void]$fpNamesToRemove.Add($n) }
    Remove-TablesCompletely -NamesToRemove $fpNamesToRemove -FilePaths ($unusedFP | Select-Object -ExpandProperty FilePath) -ModelPath $modelPath -RelationshipsPath $relationshipsPath -CulturesPath $culturesPath
}
Write-Host ""

# Exclude deleted Field Parameters' own constructs (their partition DAX -
# the NAMEOF(...) entries) from everything measure-related below, so a
# measure that was ONLY "used" via a Field Parameter this run just deleted
# does NOT get treated as still used. This is the actual fix for the ordering
# bug described in the header comment.
if ($fpNamesToRemove.Count -gt 0) {
    $allConstructs = $allConstructs | Where-Object { -not $fpNamesToRemove.Contains($_.Table) }
}

$measures = $allConstructs | Where-Object { $_.IsMeasure -and $_.Name }
$measureNames = [System.Collections.Generic.HashSet[string]]::new([string[]]($measures | Select-Object -ExpandProperty Name), [StringComparer]::OrdinalIgnoreCase)
Write-Host "  Found $($measures.Count) measures across $($tableFiles.Count) table files."
Write-Host ""

# ---------------------------------------------------------------------------
# Step 2b: a measure that references a table which doesn't exist in this
# model (e.g. LoanData - absent by design in a narrower report copy such as
# Collector Assignment\Report) is deleted REGARDLESS of usage - it cannot
# evaluate, so being "used" in a visual/report doesn't make it viable.
# Excluded from $measureNames (not from $measures - they must still go
# through Step 5/6 to actually be deleted) so neither root usage nor another
# measure's reference to it can mark it "used"; this is deliberately the same
# exclude-from-$measureNames mechanism Step 2 uses for deleted Field
# Parameters, for the same reason - it must not be able to keep anything else
# alive either.
# LIMITATION: this only catches a measure's OWN direct table reference. If
# measure X (itself fine) references measure Y (deleted here for referencing
# a missing table), X now has a dangling MEASURE reference in its DAX after
# Y is removed - not detected by this check (which only looks at table
# names). Re-running the script won't catch it either, since a measure-to-
# measure reference to an already-deleted name is simply invisible (not a
# missing-table reference). Review X manually if this matters.
# ---------------------------------------------------------------------------
$brokenMeasures = foreach ($m in $measures) {
    $referencedTables = Get-QualifiedTableRefs -Text $m.Block | Select-Object -Unique
    $missingTables = $referencedTables | Where-Object { -not $existingTableNames.Contains($_) }
    if ($missingTables) {
        [PSCustomObject]@{ Name = $m.Name; MissingTables = $missingTables }
    }
}
if ($brokenMeasures) {
    Write-Host "  Found $($brokenMeasures.Count) measure(s) referencing a nonexistent table - deleted regardless of usage:"
    foreach ($bm in $brokenMeasures) { Write-Host "    $($bm.Name)  (missing: $($bm.MissingTables -join ', '))" }
    foreach ($bm in $brokenMeasures) { [void]$measureNames.Remove($bm.Name) }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Step 3: measure -> measure reference edges (for propagation), and root
# usage from the UNCONDITIONAL non-measure DAX sources - calculated tables'
# partitions, calc-group calculationItems, and any Field Parameter that
# SURVIVED Step 2. Calculated COLUMNS are deliberately NOT folded in here
# anymore (see the "Used" (calculated DAX columns) header comment) - a
# column's contribution to measure root usage is conditional on the column
# itself being used, decided together with measures in Step 3c's fixed point.
# ---------------------------------------------------------------------------
$measureRefs = @{}   # measure name -> HashSet of measure names it references
$rootUsageBase = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$calcColumns = @()   # candidates for Step 3c - calculated columns only
$cultureColumns = @()   # culture-aware translation columns (DAX uses USERCULTURE) - kept unconditionally (user, 2026-10-24)

foreach ($c in $allConstructs) {
    if (-not $c.IsCalcDax) { continue }
    if ($c.IsMeasure -and -not $c.Name) {
        $firstLine = ($c.Block -split "`r?`n")[0]
        Write-Host "  WARNING: could not parse a measure name in $($c.FilePath) - skipped. First line: $firstLine" -ForegroundColor DarkYellow
        continue
    }
    if ($c.IsMeasure) {
        $refs = Get-BracketRefs -Text $c.Block | Where-Object { $measureNames.Contains($_) } | Select-Object -Unique
        $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($r in $refs) { if ($r -ne $c.Name) { [void]$set.Add($r) } }
        $measureRefs[$c.Name] = $set
    } elseif ($c.Kind -eq 'column' -and $c.Block -match '(?i)\bUSERCULTURE\s*\(') {
        $cultureColumns += $c
        $refs = Get-BracketRefs -Text $c.Block | Where-Object { $measureNames.Contains($_) } | Select-Object -Unique
        foreach ($r in $refs) { [void]$rootUsageBase.Add($r) }
    } elseif ($c.Kind -eq 'column') {
        $calcColumns += $c
    } else {
        # partition (calculated table / surviving Field Parameter) or
        # calculationItem (calculation group) - unconditional root usage for
        # measures, exactly as before this change.
        $refs = Get-BracketRefs -Text $c.Block | Where-Object { $measureNames.Contains($_) } | Select-Object -Unique
        foreach ($r in $refs) { [void]$rootUsageBase.Add($r) }
    }
}
# RLS role filter DAX - unconditional root usage, same as calculated tables.
foreach ($r in (Get-BracketRefs -Text $roleText | Where-Object { $measureNames.Contains($_) })) { [void]$rootUsageBase.Add($r) }
# Report-level measures of thin reports (reportExtensions.json): their DAX reads model measures - root usage.
foreach ($jf in @($thinJsonFiles | Where-Object { $_.Name -eq 'reportExtensions.json' })) {
    foreach ($r in (Get-BracketRefs -Text $usageText[$jf.FullName] | Where-Object { $measureNames.Contains($_) })) { [void]$rootUsageBase.Add($r) }
}
Write-Host "  Found $($calcColumns.Count) calculated column(s) (candidates for Step 3c)."
Write-Host "  Kept unconditionally - culture-aware columns (USERCULTURE): $($cultureColumns.Count)."
Write-Host ""

# ---------------------------------------------------------------------------
# Step 4: Report-side usage.
#
# PRIMARY pattern anchors on the "Measure" JSON WRAPPER KEY, not the Entity
# VALUE. Found the hard way: a measure physically defined inside a data table
# (e.g. CollectorAssignmentSnapshot, Excel, CT_ReportType - any of the 16
# tables that host local measures, not just the dedicated "Measure" table)
# shows "Entity": "<that table's name>" in every reference to it, never the
# literal string "Measure". The actual signal that a field is a measure (vs.
# a column) is the "Measure": {...} wrapper key itself - Entity only says
# which table hosts it, and is irrelevant to usage detection since measure
# names are globally unique regardless of host table. An earlier version of
# this script required Entity == "Measure" literally (generalized from one
# example that happened to be Measure-table-hosted) and wrongly deleted 23+
# measures that were actually referenced hundreds of times across the report
# (e.g. "Show Existing CollectorAssignmentSnapshot", used in 93 files, as a
# visual-level FILTER - filters use this exact same "Measure"-wrapper shape).
#
# SECONDARY patterns (queryRef/metadata "Measure.Name") only fire for
# Measure-table-hosted measures - confirmed queryRef for a locally-hosted one
# is an arbitrary/unreliable legacy string (e.g. "CollectorAssignmentEvents.
# Payment Received" for a measure actually in CollectorAssignmentSnapshot),
# not a trustworthy "Table.Column" identifier. Kept anyway as a harmless
# supplementary signal - it only ever ADDS root usage, never removes it.
# ---------------------------------------------------------------------------
Write-Host "Scanning $reportFolderPath for measure usage in visuals/pages/filters..."
$reportUsagePatterns = @(
    '"Measure"\s*:\s*\{\s*"Expression"\s*:\s*\{\s*"SourceRef"\s*:\s*\{\s*"(?:Entity|Source)"\s*:\s*"(?:[^"\\]|\\.)*"\s*\}\s*\}\s*,\s*"Property"\s*:\s*"' + $JsonStr + '"'
    '"queryRef"\s*:\s*"Measure\.' + $JsonStr + '"'
    '"metadata"\s*:\s*"Measure\.' + $JsonStr + '"'
)
foreach ($jf in $usageFiles) {
    $text = $usageText[$jf.FullName]   # empty filter cards excluded - see $usageText
    foreach ($pat in $reportUsagePatterns) {
        foreach ($m in [regex]::Matches($text, $pat)) {
            [void]$rootUsageBase.Add((ConvertFrom-JsonStringBody $m.Groups[1].Value))
        }
    }
}
# User rule 2026-10-15: measures in the "Color" display folder (and its
# subfolders) are a palette kept on purpose - never deleted, even if unused.
$colorMeasures = $measures | Where-Object { $_.Block -match "(?m)^\s*displayFolder:\s*'?_{0,2}Color(\\[^'\r\n]*)?'?\s*`$" }
foreach ($m in $colorMeasures) { [void]$rootUsageBase.Add($m.Name) }
Write-Host "  Kept unconditionally - measures in the 'Color' display folder: $(@($colorMeasures).Count)."
Write-Host "  Root usage found so far (report + calc-tables/calc-group items/surviving FPs): $($rootUsageBase.Count) measure(s)."
Write-Host ""

# ---------------------------------------------------------------------------
# Step 3c: unified fixed point for measures + calculated columns. A
# calculated column can grant a measure root usage (MileageColumn ->
# [Mileage Avg]), and a measure or another calculated column can just as
# easily grant a calculated column usage (Table[Column] reference) - each can
# protect the other, so both sides are re-evaluated together, excluding
# whatever the OTHER side has already confirmed dead, until a full pass finds
# nothing new on either side. Same shape as the CT_ExcludeLenders /
# Field-Parameter-ordering fixed points elsewhere in this file (see ORDER
# MATTERS at the top, and the Step 8 header comment) - just spanning two
# different kinds of construct instead of one. See the "Used" (calculated DAX
# columns) header comment for exactly what counts as usage for a column.
# ---------------------------------------------------------------------------
Write-Host "Scanning $reportFolderPath for calculated-column usage in visuals/pages/filters..."
$columnReportUsed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)   # "Table|Column" keys
# SourceRef is either {"Entity": "Table"} or {"Source": "alias"} - the alias
# is declared in the query's From list as {"Name": "alias", "Entity":
# "Table"} (603 column refs in ClientB use this shape - bookmarks, subqueries,
# textbox expressions). An alias is resolved to EVERY table declared under
# that name in the same file - aliases are per-query, and a file can reuse
# "d"/"p" for different tables; over-protecting is the safe side.
$colReportPattern = '"Column"\s*:\s*\{\s*"Expression"\s*:\s*\{\s*"SourceRef"\s*:\s*\{\s*"(Entity|Source)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*\}\s*\}\s*,\s*"Property"\s*:\s*"' + $JsonStr + '"'
$aliasDeclPattern = '"Name"\s*:\s*"' + $JsonStr + '"\s*,\s*"Entity"\s*:\s*"' + $JsonStr + '"'
foreach ($jf in $usageFiles) {
    $text = $usageText[$jf.FullName]   # empty filter cards excluded - see $usageText
    $aliases = @{}
    foreach ($a in [regex]::Matches($text, $aliasDeclPattern)) {
        if (-not $aliases.ContainsKey($a.Groups[1].Value)) { $aliases[$a.Groups[1].Value] = @() }
        $aliases[$a.Groups[1].Value] += (ConvertFrom-JsonStringBody $a.Groups[2].Value)
    }
    foreach ($m in [regex]::Matches($text, $colReportPattern)) {
        $entities = if ($m.Groups[1].Value -eq 'Entity') { @(ConvertFrom-JsonStringBody $m.Groups[2].Value) } else { $aliases[$m.Groups[2].Value] }
        $colName = ConvertFrom-JsonStringBody $m.Groups[3].Value
        if (-not $entities) { Write-Host "  WARNING: $($jf.FullName): column alias ""$($m.Groups[2].Value)"" has no From declaration - column $colName not counted" -ForegroundColor DarkYellow }
        foreach ($e in $entities) { [void]$columnReportUsed.Add("$e|$colName") }
    }
}
Write-Host "  Found $($columnReportUsed.Count) distinct table|column pair(s) placed in a visual/filter."
# Relationship keys (2026-10-28, ClientC): every fromColumn/toColumn of any
# relationship, active or inactive, counts as used - `Table.Column`, either
# part optionally quoted (a quoted column name can contain a dot:
# Items.'Tbl_Family.קוד אב').
$relKeyColumns = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)   # "Table|Column" keys
if (Test-Path $relationshipsPath) {
    foreach ($m in [regex]::Matches((Get-Content $relationshipsPath -Raw), "(?m)^\s*(?:from|to)Column:\s*(?:'((?:[^']|'')+)'|([^.'\s]+))\.(?:'((?:[^']|'')+)'|(\S+))\s*`$")) {
        $t = if ($m.Groups[1].Success) { $m.Groups[1].Value -replace "''", "'" } else { $m.Groups[2].Value }
        $c = if ($m.Groups[3].Success) { $m.Groups[3].Value -replace "''", "'" } else { $m.Groups[4].Value }
        [void]$relKeyColumns.Add("$t|$c")
    }
}
Write-Host "  Found $($relKeyColumns.Count) relationship key column(s) - counted as used."
Write-Host ""

Write-Host "Running the measure/calculated-column fixed point..."
$deadColumns = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)   # "Table|Column" keys, confirmed unused
$used = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)           # measure names, recomputed every pass
$outerChanged = $true
$outerPasses = 0
while ($outerChanged) {
    $outerChanged = $false
    $outerPasses++

    # 3c.1: this pass's measure root usage = the unconditional sources plus
    # every calculated column NOT yet confirmed dead.
    $rootUsageThisPass = [System.Collections.Generic.HashSet[string]]::new($rootUsageBase, [StringComparer]::OrdinalIgnoreCase)
    foreach ($col in $calcColumns) {
        if ($deadColumns.Contains("$($col.Table)|$($col.Name)")) { continue }
        $refs = Get-BracketRefs -Text $col.Block | Where-Object { $measureNames.Contains($_) }
        foreach ($r in $refs) { [void]$rootUsageThisPass.Add($r) }
    }

    # 3c.2: fresh BFS measure -> measure from this pass's root usage.
    $used.Clear()
    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($r in $rootUsageThisPass) {
        if ($measureNames.Contains($r) -and $used.Add($r)) { $queue.Enqueue($r) }
    }
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if ($measureRefs.ContainsKey($current)) {
            foreach ($next in $measureRefs[$current]) {
                if ($used.Add($next)) { $queue.Enqueue($next) }
            }
        }
    }

    # 3c.3: evaluate every surviving calculated column. Protectors = the
    # unconditional non-measure constructs (calc tables/calc groups/surviving
    # FPs, already unconditional root usage above), every measure currently
    # live ($used, not just any measure - a column referenced only by an
    # already-dead-this-pass measure isn't protected either), and every OTHER
    # calculated column not yet confirmed dead.
    foreach ($col in $calcColumns) {
        $colKey = "$($col.Table)|$($col.Name)"
        if ($deadColumns.Contains($colKey)) { continue }
        if ($columnReportUsed.Contains($colKey)) { continue }
        if ($ambiguousBareColumns.Contains($colKey)) { continue }   # Step 0: read via an ambiguous bare [Name]
        if ($relKeyColumns.Contains($colKey)) { continue }          # relationship key (2026-10-28)

        $protectorBlocks = @($roleText)
        $protectorBlocks += ($allConstructs | Where-Object { $_.IsCalcDax -and -not $_.IsMeasure -and $_.Kind -ne 'column' } | ForEach-Object { $_.Block })
        $protectorBlocks += ($measures | Where-Object { $used.Contains($_.Name) } | ForEach-Object { $_.Block })
        $protectorBlocks += ($cultureColumns | ForEach-Object { $_.Block })
        $protectorBlocks += ($calcColumns | Where-Object {
            ("$($_.Table)|$($_.Name)" -ne $colKey) -and -not $deadColumns.Contains("$($_.Table)|$($_.Name)")
        } | ForEach-Object { $_.Block })
        $protectorDax = $protectorBlocks -join "`n"

        $inDax = $protectorDax -and ((Get-QualifiedColumnRefs -Text $protectorDax) | Where-Object { $_.Table -eq $col.Table -and $_.Column -eq $col.Name })

        # Deliberately loose bare-word fallback for sortByColumn/
        # groupByColumn/hierarchy `column:` targets, scoped to the column's
        # OWN table file (those metadata properties never cross tables in
        # TMDL) - see the header comment for why this stays generous.
        $ownTableText = Get-Content $col.FilePath -Raw
        $ownTableTextMinusOwnBlock = $ownTableText.Remove($col.StartIdx, $col.EndIdx - $col.StartIdx)
        $escapedColName = [regex]::Escape($col.Name)
        $inMetadata = [regex]::IsMatch($ownTableTextMinusOwnBlock, "(?im)^\s*(?:sortByColumn|groupByColumn|column):\s*(?:'$escapedColName'|$escapedColName)\s*`$")

        if (-not $inDax -and -not $inMetadata) {
            [void]$deadColumns.Add($colKey)
            $outerChanged = $true
        }
    }
}
Write-Host "  Fixed point reached after $outerPasses pass(es)."
Write-Host ""

$unused = $measures | Where-Object { -not $used.Contains($_.Name) }
$unusedColumns = $calcColumns | Where-Object { $deadColumns.Contains("$($_.Table)|$($_.Name)") }

Write-Host "Total measures: $($measures.Count)   Used: $($used.Count)   Unused: $($unused.Count)"
Write-Host "Total calculated columns: $($calcColumns.Count)   Unused: $($unusedColumns.Count)"
Write-Host ""
Write-Host "=== CAVEATS - detection is heuristic, not a real DAX parser ==="
Write-Host "- Bare [Name] = measure reference, Table[Name] = column (this project's own"
Write-Host "  convention, Best Practice.txt). A bare [Name] that is not a measure is qualified"
Write-Host "  by Step 0 when exactly one column has that name; if several do, all of them are"
Write-Host "  kept. Review Step 0's FIX/WARN lines above - a FIX changes the DAX text."
Write-Host "- Calculation groups exist here (CG Dynamic Format, CG Time Intelligence, CG"
Write-Host "  Journal Entries). SELECTEDMEASURE()/SELECTEDMEASURENAME() usage never names a"
Write-Host "  measure literally and is invisible to this script."
Write-Host "- Calculated-column usage checks Table[Column] DAX refs, report Column/Property"
Write-Host "  placement, and sortByColumn/groupByColumn/hierarchy column: metadata - a column"
Write-Host "  read only via some OTHER mechanism (e.g. a Power Query M-level merge, or a"
Write-Host "  dynamically-built column name) is invisible to this check, same caveat as the"
Write-Host "  other-tables step below."
Write-Host "- RLS roles (definition\roles) are scanned: the filtered table and everything"
Write-Host "  the filter DAX reads are kept. Perspectives are NOT scanned."
Write-Host "- Auto date tables (LocalDateTable_*, DateTableTemplate_*) are never deleted -"
Write-Host "  Desktop owns them via column variations (turn off Auto date/time instead)."
Write-Host "- Hidden visuals: deleted only when NOT USED - no bookmark shows them AND they are"
Write-Host "  not a slicer that still filters while hidden (saved selection or sync group)."
Write-Host "  Hidden filter cards WITH a condition are never deleted (they filter the page)."
Write-Host "- Bookmarks: a bookmark not called by any button/navigator is deleted - one used"
Write-Host "  only from the Bookmarks pane in the Service goes too."
Write-Host "- Documentation (_Context/*.md, *.txt) is not scanned/updated - grep for a"
Write-Host "  deleted measure's/column's name there afterward if it might be documented."
Write-Host ""

if ($unused.Count -eq 0) {
    Write-Host "No unused measures to delete."
    Write-Host ""
} else {

# ---------------------------------------------------------------------------
# Step 6: delete every unused measure's block from its file, right away - no
# separate list/report step. Grouped per file and spliced in one pass (sorted
# by position) rather than repeated sequential replacements, for the same
# reason rename_pages.ps1 avoids repeated mutating replacements - safe
# regardless of how many measures in the same file are being removed at once.
# ---------------------------------------------------------------------------
Write-Host "Deleting $($unused.Count) unused measure(s)..."
$byFile = $unused | Group-Object FilePath
foreach ($group in $byFile) {
    $filePath = $group.Name
    $text = Get-Content $filePath -Raw
    $spans = $group.Group | Sort-Object StartIdx

    $sb = New-Object System.Text.StringBuilder
    $cursor = 0
    foreach ($span in $spans) {
        [void]$sb.Append($text.Substring($cursor, $span.StartIdx - $cursor))
        $cursor = $span.EndIdx
    }
    [void]$sb.Append($text.Substring($cursor))
    $newText = $sb.ToString()

    if (Test-TmdlIntegrity -Text $newText -FilePath $filePath) {
        [System.IO.File]::WriteAllText($filePath, $newText, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  OK $($filePath): removed $($spans.Count) measure(s) - $(($spans.Name) -join ', ')"
    } else {
        Write-Host "  SKIPPED $filePath - integrity check failed, file left untouched. Investigate before retrying." -ForegroundColor Red
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# Step 7: remove dangling entries for deleted measures from the TMDL-native
# `translations` block in definition\cultures\*.tmdl (e.g. `measure 'Name' /
# caption: ...` under `translations > model Model > table X`). This is a
# DIFFERENT, STRICTER thing than the linguisticMetadata Q&A JSON blob further
# down the same file (that one is tolerated/soft - "State": "Generated").
# The `translations` block is schema-validated TMDL: a caption entry left
# behind for a measure that no longer exists makes Power BI Desktop FAIL TO
# LOAD THE ENTIRE MODEL with "Cannot resolve all the paths while
# de-serializing Database... Property Object of object 'Translation in
# culture en-US' refers to an object which cannot be found" - found the hard
# way (2026-09-13) after this script deleted "Sales # Per Dealer" (correctly
# - genuinely unused) but left its caption entry behind, breaking the model
# load entirely on next open. Only the small `translations` header portion
# of the file (before `linguisticMetadata =`) is touched here.
# ---------------------------------------------------------------------------
Write-Host "Cleaning up dangling measure translation entries in definition\cultures\*.tmdl..."
$deletedNames = [System.Collections.Generic.HashSet[string]]::new([string[]]($unused | Select-Object -ExpandProperty Name), [StringComparer]::OrdinalIgnoreCase)
Remove-DanglingTranslations -CulturesPath $culturesPath -Keyword 'measure' -NamesToRemove $deletedNames -LabelSingular "dangling translation entry" -LabelPlural "dangling translation entries"

Write-Host ""

}

# ---------------------------------------------------------------------------
# Step 7b: delete every unused calculated column found by Step 3c - splice
# each column's block from its file (same grouped/sorted-span technique as
# Step 6 for measures), then drop any dangling cultures/*.tmdl translation
# entry. Relationships are never touched here - a relationship key column is
# never a candidate (2026-10-28, see Step 3c). Runs BEFORE Step 8 deliberately
# - Step 8 re-scans the tables folder fresh from disk at its start, so a
# table that was ONLY "used" via a calculated column deleted here correctly
# loses that protection with no extra code in Step 8 itself.
# ---------------------------------------------------------------------------
if ($unusedColumns.Count -eq 0) {
    Write-Host "No unused calculated columns to delete."
    Write-Host ""
} else {

Write-Host "Deleting $($unusedColumns.Count) unused calculated column(s): $(($unusedColumns | ForEach-Object { "$($_.Table)[$($_.Name)]" }) -join ', ')"
$byFile = $unusedColumns | Group-Object FilePath
foreach ($group in $byFile) {
    $filePath = $group.Name
    $text = Get-Content $filePath -Raw

    # Re-resolve fresh StartIdx/EndIdx against the file's CURRENT on-disk
    # content, not the stale ones from the single upfront $allConstructs scan
    # (before Step 6 ran) - if Step 6 already deleted a measure from this SAME
    # file, every position after it has shifted, and splicing at the old
    # offsets corrupts the file (found the hard way 2026-09-16: a measure +
    # calculated column removed from the same table truncated an unrelated
    # annotation mid-word and swallowed the next column's declaration line).
    # Matching by name against a fresh re-parse is the same fix Step 8 already
    # uses for this exact reason (see its own comment, a few lines above).
    $freshConstructs = Get-TmdlConstructs -Text $text -FilePath $filePath -TableName $group.Group[0].Table
    $namesToRemove = [System.Collections.Generic.HashSet[string]]::new([string[]]($group.Group | Select-Object -ExpandProperty Name), [StringComparer]::OrdinalIgnoreCase)
    $spans = $freshConstructs | Where-Object { $_.Kind -eq 'column' -and $namesToRemove.Contains($_.Name) } | Sort-Object StartIdx

    if ($spans.Count -ne $group.Group.Count) {
        Write-Host "  SKIPPED $filePath - expected $($group.Group.Count) column(s) but re-scan found $($spans.Count), file left untouched. Investigate before retrying." -ForegroundColor Red
        continue
    }

    $sb = New-Object System.Text.StringBuilder
    $cursor = 0
    foreach ($span in $spans) {
        [void]$sb.Append($text.Substring($cursor, $span.StartIdx - $cursor))
        $cursor = $span.EndIdx
    }
    [void]$sb.Append($text.Substring($cursor))
    $newText = $sb.ToString()

    if (Test-TmdlIntegrity -Text $newText -FilePath $filePath) {
        [System.IO.File]::WriteAllText($filePath, $newText, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  OK $($filePath): removed $($spans.Count) column(s) - $(($spans.Name) -join ', ')"
    } else {
        Write-Host "  SKIPPED $filePath - integrity check failed, file left untouched. Investigate before retrying." -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "Cleaning up dangling column translation entries in definition\cultures\*.tmdl..."
$deletedColumnNames = [System.Collections.Generic.HashSet[string]]::new([string[]]($unusedColumns | Select-Object -ExpandProperty Name), [StringComparer]::OrdinalIgnoreCase)
Remove-DanglingTranslations -CulturesPath $culturesPath -Keyword 'column' -NamesToRemove $deletedColumnNames -LabelSingular "dangling translation entry" -LabelPlural "dangling translation entries"

Write-Host ""

}

# ---------------------------------------------------------------------------
# Step 8: other tables - evaluated LAST, after measures are finalized, so the
# DAX-reference check below reads the model's final surviving state. HIGHER
# RISK than the steps above - see the "Used (other tables...)" section of the
# header comment for exactly what is and isn't checked, and its limits.
#
# Excluded from consideration: any table that hosts measures (protects the
# "Measure" table itself; until 2026-10-17 a '*Measure*' NAME match), and every Field Parameter table (detected fresh,
# same NAMEOF-based signature as Step 2 - regardless of whether it survived
# or was deleted there, since Field Parameters have their own dedicated
# handling and must not be double-processed here). CALCULATION GROUPS
# (detected structurally via the `calculationGroup` keyword, not by name -
# "CG "-prefixed names are just this project's convention) are NOT excluded -
# added 2026-09-13 by explicit request, they are now checked and deleted by
# these same rules, alongside ordinary tables. Before this, calc groups were
# excluded entirely and only used to gate whether their OWN calculationItem
# DAX could protect other tables - found the hard way 2026-09-13: 5 of the
# first 6 tables this step ever deleted - AutocountTargetDealer,
# CreditSummary, LoanCriteria, Operational, DateContext - turned out to be
# calculation groups (only the "CG "-prefixed ones happened to survive, by
# coincidence of also matching one of the checks below, not because they were
# recognized as calculation groups). All 5 were restored from backup. That
# risk is still live now that calc groups are deletable: one applied ONLY via
# SELECTEDMEASURE()/SELECTEDMEASURENAME() (never named literally, never
# placed as an "Entity") is invisible to every check below and can be wrongly
# deleted - review the CAVEATS output and cross-check against your own
# knowledge of the model's calc groups before trusting this step blindly.
# EXCEPTION (by explicit request, 2026-09-13): any table/calc group matching
# '*Time Intelligence*' is EXCLUDED UNCONDITIONALLY from this step, regardless
# of usage - same treatment as the Calendar-related Field Parameter exclusion
# in Step 2. Currently only matches "CG Time Intelligence" (itself already
# confirmed used via a direct DAX reference from Measure.tmdl, so this is a
# safety net for other copies of this model / future changes, not a rescue of
# something currently at risk).
#
# ALSO FIXED (same incident): the DAX-reference check below excludes each
# candidate's OWN constructs before searching - a table with a plain,
# unquoted, single-word name (e.g. parPTI) trivially "references itself" via
# its own `partition parPTI = calculated` declaration line, which contains
# the table's own name as a bare word. Searching the full construct set
# including the candidate's own falsely marks every such table "used" by
# itself - the search must run over every OTHER table's constructs only.
#
# ALSO (2026-09-13, DealerData example): a relationship alone no longer
# counts as "used" - see the "NOTE" paragraph in the header comment above.
# $inRelationship is still computed and printed per deleted table as an FYI.
#
# ALSO (2026-09-13, parVehicleAge example): a reference from INSIDE a
# calculation group's calculationItem DAX is treated the same way a
# relationship is - not enough on its own if the calc group itself has
# nothing protecting it. LoanCriteria (a calculation group) has
# calculationItem DAX containing `[parVehicleAge Value]`, `[parMileage
# Value]`, `[parLTV Value]`, `[parPTI Value]`, etc. - bare bracket syntax,
# which by this project's own convention means a MEASURE reference - but no
# measure by any of those names exists anywhere in this model OR in Model_v2
# (confirmed by grep). These are themselves dangling/broken references
# sitting inside LoanCriteria's own DAX, not real usage - yet that same
# broken text would still count as "used" for the parVehicleAge/parMileage/
# parLTV/parPTI TABLES via the bare-word fallback match, for as long as
# LoanCriteria itself stayed in the construct pool. Since calc groups are now
# full candidates in the SAME fixed-point loop below (see the CT_ExcludeLenders
# note further down), this resolves itself automatically once/if LoanCriteria
# is itself confirmed unused - no separate gating mechanism needed anymore.
#
# ALSO (2026-09-13, CT_ExcludeLenders example): the unused-table check runs
# to a FIXED POINT, not a single pass - CompetitorHouseDealer referenced
# CT_ExcludeLenders[Lender] and was itself deleted as unused in the same run,
# but a single static pass had already counted CompetitorHouseDealer's DAX as
# live protection for CT_ExcludeLenders before either was removed, so
# CT_ExcludeLenders survived for no good reason - two ordinary candidate
# tables protecting each other while both are actually dead. Same shape as
# the original Field-Parameter/measure ordering bug, recurring here. Fixed by
# iterating: each pass excludes every candidate confirmed unused so far from
# every remaining candidate's search, repeating until a pass finds nothing
# new to remove.
# ---------------------------------------------------------------------------
Write-Host "Re-scanning tables for whole-table usage (after measure deletion)..."
$currentTableInfos = @()
$currentConstructs = @()
$calcGroupNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
Get-ChildItem -Path $tablesPath -Filter "*.tmdl" | ForEach-Object {
    $text = Get-Content $_.FullName -Raw
    $tableNameMatch = [regex]::Match($text, "(?m)^table\s+(?:'([^']+)'|(\S+))")
    $tableName = if ($tableNameMatch.Groups[1].Success) { $tableNameMatch.Groups[1].Value } elseif ($tableNameMatch.Groups[2].Success) { $tableNameMatch.Groups[2].Value } else { $_.BaseName }
    $currentTableInfos += [PSCustomObject]@{ Name = $tableName; FilePath = $_.FullName }
    if ($text -match '(?m)^\tcalculationGroup\s*$') { [void]$calcGroupNames.Add($tableName) }
    $currentConstructs += Get-TmdlConstructs -Text $text -FilePath $_.FullName -TableName $tableName
}

$currentFPNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($p in ($currentConstructs | Where-Object { $_.Kind -eq 'partition' -and $_.Block -match 'NAMEOF\s*\(' })) {
    [void]$currentFPNames.Add($p.Table)
}
# Also excluded (2026-10-06, ClientE Sales Main): auto date tables
# (LocalDateTable_<guid>, DateTableTemplate_<guid>) - Desktop links them to
# date columns through a `variation` (defaultHierarchy) in the COLUMN's own
# table file, which this script doesn't remove; deleting the table alone left
# 9 dangling variations and a model that wouldn't load. And RLS role tables
# (see $roleTables, Step 1) - a role filter is real usage.
# Measure tables (2026-10-17, ClientB): a table that HOSTS measures is excluded -
# not any table whose name contains "Measure". The name match kept ClientB's
# MeasureTable (an "Enter data" list of measure names, no measures, used
# nowhere) for no reason.
$measureHostTables = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($c in ($currentConstructs | Where-Object IsMeasure)) { [void]$measureHostTables.Add($c.Table) }
# CT_BlankTable (2026-11-02, user, refactoring step 42): the info-icon table (CT_BlankTable[Info]) is a standard object of
# every model - kept even when no icon uses it yet.
$tableCandidates = $currentTableInfos | Where-Object { -not $measureHostTables.Contains($_.Name) -and $_.Name -notlike '*Time Intelligence*' -and -not $currentFPNames.Contains($_.Name) -and $_.Name -notlike 'LocalDateTable_*' -and $_.Name -notlike 'DateTableTemplate_*' -and -not $roleTables.Contains($_.Name) -and $_.Name -ne 'CT_BlankTable' }
Write-Host "  $($tableCandidates.Count) table(s)/calculation group(s) to check ($($currentTableInfos.Count - $tableCandidates.Count) excluded: hosts measures, '*Time Intelligence*' name match, Field Parameter, auto date table, RLS role table, or CT_BlankTable). Of these, $(($calcGroupNames | Where-Object { $tableCandidates.Name -contains $_ }).Count) are calculation groups: $(($calcGroupNames | Where-Object { $tableCandidates.Name -contains $_ }) -join ', ')"

$relTextForTables = if (Test-Path $relationshipsPath) { Get-Content $relationshipsPath -Raw } else { "" }

Write-Host "Scanning $reportFolderPath for whole-table usage..."
$tableReportUsed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($jf in $usageFiles) {
    $text = $usageText[$jf.FullName]   # empty filter cards excluded - see $usageText
    foreach ($t in $tableCandidates) {
        if ($tableReportUsed.Contains($t.Name)) { continue }
        if ([regex]::IsMatch($text, '(?i)"Entity"\s*:\s*"' + [regex]::Escape((ConvertTo-JsonStringBody $t.Name)) + '"')) {
            [void]$tableReportUsed.Add($t.Name)
        }
    }
}

# Fixed point, not a single pass: a candidate table can be protected ONLY by
# another candidate's DAX reference - and that protector can itself turn out
# unused. Found the hard way (2026-09-13, CT_ExcludeLenders example):
# CompetitorHouseDealer referenced CT_ExcludeLenders[Lender] and was itself
# deleted as unused in the very same run, but a single static pass had
# already "seen" CompetitorHouseDealer's DAX as live protection for
# CT_ExcludeLenders before either was removed, so CT_ExcludeLenders survived
# an extra run for no good reason - the exact same "mutual protection among
# condemned nodes" shape as the original Field-Parameter/measure ordering
# bug (see ORDER MATTERS at the top of this file), recurring here between
# two ordinary tables instead. Fixed the same way: iterate, excluding each
# newly-confirmed-unused candidate's own constructs from every remaining
# candidate's search, until a pass finds nothing new to remove.
$confirmedUnused = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$changed = $true
while ($changed) {
    $changed = $false
    foreach ($cand in $tableCandidates) {
        $candidateName = $cand.Name
        if ($confirmedUnused.Contains($candidateName)) { continue }
        $escaped = [regex]::Escape($candidateName)
        $otherDax = ($currentConstructs | Where-Object {
            $_.IsCalcDax -and $_.Table -ne $candidateName -and
            -not $confirmedUnused.Contains($_.Table)
        } | ForEach-Object { $_.Block }) -join "`n"
        # The bare-word fallback skips "..." string literals and comments
        # (2026-10-17, ClientB): `MAX ( Items[ItemGroup] ) = "הובלה"` (an item
        # group name) and `-- הובלה / other` kept the unused table הובלה
        # alive. One left-to-right pass, so a quote inside a comment or `//`
        # inside a string can't derail it. An M `#"Query Name"` is an
        # identifier, not a string: matched as its own token and kept (still
        # counted) - skipping just its `#` left its closing quote to open a
        # bogus string and swapped "inside"/"outside" for the rest of the text.
        $otherDaxNoStrings = [regex]::Replace($otherDax, '#"(?:[^"]|"")*"|"(?:[^"]|"")*"|/\*[\s\S]*?\*/|//[^\n]*|--[^\n]*', { param($m) if ($m.Value.StartsWith('#')) { $m.Value } else { ' ' } })
        $inDax = [regex]::IsMatch($otherDax, "(?i)(?:'$escaped'|$escaped)\[") -or [regex]::IsMatch($otherDaxNoStrings, "(?i)(?<![\w'])$escaped(?![\w'\[])")
        $inReport = $tableReportUsed.Contains($candidateName)
        # A relationship alone does NOT count as "used" - see header comment
        # (DealerData example, 2026-09-13). Only DAX references / report usage do.
        if (-not $inDax -and -not $inReport) {
            [void]$confirmedUnused.Add($candidateName)
            $changed = $true
        }
    }
}
$unusedTables = $tableCandidates | Where-Object { $confirmedUnused.Contains($_.Name) }
Write-Host "Other tables: $($tableCandidates.Count) checked, unused: $($unusedTables.Count)"
Write-Host ""

if ($unusedTables.Count -eq 0) {
    Write-Host "No unused tables to delete."
} else {
    Write-Host "Deleting $($unusedTables.Count) unused table(s)/calculation group(s): $(($unusedTables | Select-Object -ExpandProperty Name) -join ', ')"
    foreach ($t in $unusedTables) {
        $escaped = [regex]::Escape($t.Name)
        $inRel = [regex]::IsMatch($relTextForTables, "(?i)(?:from|to)Column:\s*(?:'$escaped'|$escaped)\.")
        if ($inRel) { Write-Host "    NOTE: $($t.Name) has relationship(s) being removed too - was kept alive by relationship-only presence (no DAX/report usage)." }
        if ($calcGroupNames.Contains($t.Name)) { Write-Host "    NOTE: $($t.Name) is a calculation group - its calculationItem DAX goes with it, which may un-protect other tables it referenced (re-evaluated by the fixed-point loop above)." }
    }
    $tableNamesToRemove = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($n in ($unusedTables | Select-Object -ExpandProperty Name)) { [void]$tableNamesToRemove.Add($n) }
    Remove-TablesCompletely -NamesToRemove $tableNamesToRemove -FilePaths ($unusedTables | Select-Object -ExpandProperty FilePath) -ModelPath $modelPath -RelationshipsPath $relationshipsPath -CulturesPath $culturesPath
}

