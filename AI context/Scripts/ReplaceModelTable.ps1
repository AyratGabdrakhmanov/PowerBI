# Replace one model table with another everywhere: model (relationships, column properties, the table
# itself) and report (visuals, filters, bookmarks). The single entry point for a table swap; the report
# side is ReportFields.py (next to this script: sub-commands replace / drop-filters / refs).
#
# Three modes:
#   (default)     Desktop CLOSED - edits the TMDL on disk: relationships.tmdl (fromColumn / toColumn),
#                 model.tmdl "ref table" list, cultures\*.tmdl ("ConceptualEntity"), report, then deletes
#                 the old table's .tmdl (-KeepOldTableFile to keep it). Built for _LID -> LID (Model_v2).
#   -ReportOnly   report only (no model). The old table may already be gone from the TMDL (deleted /
#                 renamed via TOM) - then it is a pure rename of every column / level of -NewTable.
#   -Port N       Desktop OPEN, the whole swap live (ClientB Customers -> CustomersSmall -> Customers,
#                 2026-10-16). Never closes Desktop. Order (a Ctrl+S after TOM writes Desktop's in-memory
#                 report over the files, so report edits are applied in Desktop before any TOM change):
#                   0. checks: both tables in the model on this port; DAX (comments stripped) and report
#                      fields that use columns only the old table has -> stop (unless -Force);
#                      Desktop for this .pbip found (powerbi-desktop status), unsaved changes -> Ctrl+S
#                   1. backup SemanticModel + Report
#                   2. report: drop-filters (-DropFilters, list -> -FilterList), replace Old -> New
#                   3. powerbi-desktop reload (apply external changes)
#                   4. TOM: column properties Old -> New (SortByColumn, FormatString, IsHidden,
#                      DisplayFolder, Description, DataCategory, SummarizeBy) for shared columns;
#                      relationships of Old re-created on New with the same properties (except
#                      -SkipRelationships, or a column New lacks), -ActivateRelationships; Old deleted; -KeepName: New renamed
#                      to Old's name (+ its partition); RequestRefresh(Calculate)
#                   5. model errors (INFO.MEASURES / COLUMNS / RELATIONSHIPS via QueryOpenModel.ps1)
#                   6. Ctrl+S (SendKeys to the Desktop window), wait for the TMDL to change
#                   7. -KeepName: report renamed New -> Old (ReportFields.py replace, rename mode), reload
#                 DAX that uses Old-only columns and report fields Old-only columns other than filters -
#                 change them BEFORE the run (TOM / MS MCP; ReportFields.py replace); step 0 lists them.
#                 DAX text Old[...] stays valid with -KeepName.
#
# Options:
#   -DropFilters a,b       Old's columns whose report filters are dropped (ReportFields.py drop-filters)
#   -FilterList <file.md>  where the dropped-filters list goes (default: next to the .pbip,
#                          DroppedFilters_<Old>_<timestamp>.md)
#   -SkipRelationships a,b relationships NOT re-created on New, by the other side's column:
#                          'DocsPurchs.CastLicTradNum'
#   -ActivateRelationships a,b  (-Port) relationships to make active once Old's are dropped (a path that
#                          would be ambiguous before): 'DocsPurchs.CastLicTradNum->ETL_MD_LicTradNum.LicTradkEY'
#   -KeepName              (-Port) New takes Old's name
#   -Skip a,b              columns / hierarchies to leave on the old table (report)
#   -DryRun                -ReportOnly / -Port: checks + list what would change, write nothing
#   -Force                 -Port: go on although DAX / report use columns New lacks
#   -DesktopPid N          -Port: the Desktop process (default: found by the .pbip path)
#
#   pwsh -File ReplaceModelTable.ps1 -OldTable _LID -NewTable LID -RootPath <...>                  (Desktop closed)
#   pwsh -File ReplaceModelTable.ps1 -OldTable CustomersSmall -NewTable Customers -RootPath <...> -ReportOnly
#   pwsh -File ReplaceModelTable.ps1 -OldTable Customers -NewTable CustomersSmall -RootPath <...> -Port 52992 `
#        -KeepName -DropFilters CardType -SkipRelationships DocsPurchs.CastLicTradNum -DryRun
#
# SCRIPT_VERSION: 2026-10-16.3 - bump this whenever the script changes, so an
# old copy left elsewhere can be told apart by the version it prints.
param(
    [Parameter(Mandatory = $true)][string]$OldTable,
    [Parameter(Mandatory = $true)][string]$NewTable,
    [string]$RootPath = $PSScriptRoot,
    [switch]$KeepOldTableFile,
    [switch]$ReportOnly,
    [switch]$DryRun,
    [string]$Skip,
    [int]$Port,
    [int]$DesktopPid,
    [switch]$KeepName,
    [string]$DropFilters,
    [string]$FilterList,
    [string]$SkipRelationships,
    [string]$ActivateRelationships,
    [switch]$Force
)

$ScriptVersion = "2026-10-16.3"

# Requires PowerShell 7+ (pwsh) - consistent with the rest of this project's tooling.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        Write-Host "Relaunching under PowerShell 7+ (pwsh)..."
        # Forward the bound parameters explicitly - with a param() block @args
        # is empty, so -OldTable/-NewTable/-RootPath were dropped (2026-10-13).
        $fwd = foreach ($k in $PSBoundParameters.Keys) { $v = $PSBoundParameters[$k]; if ($v -is [switch]) { if ($v) { "-$k" } } else { "-$k"; "$v" } }
        & $pwshCmd.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @fwd
        exit $LASTEXITCODE
    } else {
        Write-Error "PowerShell 7+ (pwsh) is required but was not found. Install it from https://aka.ms/PSWindows and re-run this script."
        exit 1
    }
}
$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "ReplaceModelTable.ps1 version $ScriptVersion"
Write-Host "  OldTable = '$OldTable'   NewTable = '$NewTable'"
Write-Host ""

$semanticFolders = @(Get-ChildItem -Path $RootPath -Directory -Filter "*.SemanticModel")
$reportFolders = @(Get-ChildItem -Path $RootPath -Directory -Filter "*.Report")
if ($semanticFolders.Count -ne 1 -or $reportFolders.Count -ne 1) {
    Write-Error "Expected exactly one *.SemanticModel and one *.Report folder under: $RootPath (found $($semanticFolders.Count) / $($reportFolders.Count)). Pass -RootPath if this script isn't sitting next to them."
    exit 1
}
$semanticPath = $semanticFolders[0].FullName
$reportPath = $reportFolders[0].FullName

$tablesPath = Join-Path $semanticPath "definition\tables"
$oldTablePath = Join-Path $tablesPath "$OldTable.tmdl"
$newTablePath = Join-Path $tablesPath "$NewTable.tmdl"
$relationshipsPath = Join-Path $semanticPath "definition\relationships.tmdl"
$modelPath = Join-Path $semanticPath "definition\model.tmdl"
$py = Join-Path $PSScriptRoot "ReportFields.py"
if (-not (Test-Path $py)) { Write-Error "ReportFields.py not found next to this script: $py"; exit 1 }
$stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$backupRoot = Join-Path (Split-Path $RootPath -Parent) "BackUp"
$splitList = { param($s) @(($s -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

function Invoke-Fields {
    # ReportFields.py <sub-command> <report> <args>; stops the script when it fails.
    param([string]$Cmd, [string[]]$Rest)
    & python -X utf8 -I $py $Cmd $reportPath @Rest
    if ($LASTEXITCODE -ne 0) { Write-Error "ReportFields.py $Cmd failed (exit $LASTEXITCODE)"; exit 1 }
}
function Invoke-ReportSwap {
    param([string]$From, [string]$To, [switch]$Apply, [string]$BackupDir)
    $rest = @("--from", $From, "--to", $To)
    if ($Skip) { $rest += @("--skip", $Skip) }
    if ($BackupDir) { $rest += @("--backup-dir", $BackupDir) }
    if ($Apply) { $rest += "--apply" }
    Invoke-Fields replace $rest
}
function Invoke-DropFilters {
    param([switch]$Apply, [string]$BackupDir)
    $cols = & $splitList $DropFilters
    if (-not $cols) { return }
    $rest = @()
    foreach ($c in $cols) { $rest += @("--field", "$OldTable[$c]") }
    $list = if ($FilterList) { $FilterList } else { Join-Path $RootPath "DroppedFilters_${OldTable}_$stamp.md" }
    if ($Apply) { $rest += @("--list", $list, "--apply") }
    if ($BackupDir) { $rest += @("--backup-dir", $BackupDir) }
    Invoke-Fields drop-filters $rest
}
function Backup-Project {
    $dest = Join-Path $backupRoot "ReplaceModelTable_$stamp"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -Path $semanticPath, $reportPath -Destination $dest -Recurse -Force
    Write-Host "OK Backed up SemanticModel + Report to $dest"
    return $dest
}

# ===================================================================== -ReportOnly
if ($ReportOnly) {
    if (-not (Test-Path $newTablePath)) { Write-Error "New table definition not found: $newTablePath"; exit 1 }
    Write-Host "-ReportOnly: report side only (ReportFields.py makes its own backup)"
    Write-Host ""
    Invoke-DropFilters -Apply:(-not $DryRun)
    Invoke-ReportSwap -From $OldTable -To $NewTable -Apply:(-not $DryRun)
    exit 0
}

# ===================================================================== -Port: live swap
if ($Port) {
    [void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
    $srv = New-Object Microsoft.AnalysisServices.Tabular.Server
    $srv.Connect("Data Source=localhost:$Port")
    $model = $srv.Databases[0].Model
    foreach ($t in $OldTable, $NewTable) {
        if (-not $model.Tables.Contains($t)) { Write-Error "Table '$t' not in the model on port $Port - wrong port / file?"; exit 1 }
    }
    $old = $model.Tables[$OldTable]; $new = $model.Tables[$NewTable]
    $newCols = @{}; foreach ($c in $new.Columns) { if ($c.Type -ne 'RowNumber') { $newCols[$c.Name.ToLower()] = $c } }
    $oldOnly = @($old.Columns | Where-Object { $_.Type -ne 'RowNumber' -and -not $newCols.ContainsKey($_.Name.ToLower()) } | ForEach-Object Name)
    $dropCols = & $splitList $DropFilters
    $skipRels = & $splitList $SkipRelationships

    # --- 0. checks ---
    Write-Host "Step 0: checks"
    Write-Host "  columns only in ${OldTable}: $($oldOnly -join ', ')"
    $problems = @()
    $oldRe = "(?:'$([regex]::Escape($OldTable))'|(?<![\w'])$([regex]::Escape($OldTable)))\s*\[([^\]]+)\]"
    $exprs = foreach ($t in $model.Tables) {
        foreach ($m in $t.Measures) { [pscustomobject]@{ Name = "$($t.Name)[$($m.Name)]"; Expr = $m.Expression } }
        foreach ($c in $t.Columns) { if ($c.Type -eq 'Calculated') { [pscustomobject]@{ Name = "$($t.Name)[$($c.Name)]"; Expr = $c.Expression } } }
        foreach ($p in $t.Partitions) { if ($p.SourceType -eq 'Calculated') { [pscustomobject]@{ Name = "$($t.Name) (calculated table)"; Expr = $p.Source.Expression } } }
    }
    foreach ($e in $exprs) {
        if ($e.Name.StartsWith("$OldTable[")) { continue }
        $code = [regex]::Replace([string]$e.Expr, '/\*[\s\S]*?\*/|//[^\n]*|--[^\n]*', '')
        foreach ($m in [regex]::Matches($code, $oldRe)) {
            if ($oldOnly -contains $m.Groups[1].Value) { $problems += "DAX $($e.Name) uses $OldTable[$($m.Groups[1].Value)]" }
        }
    }
    $refLines = & python -X utf8 -I $py refs $reportPath --table $OldTable
    foreach ($line in $refLines) {
        if ($line -match '^\s*\d+ refs\s+\d+ files\s+(.+)$') {
            $col = $Matches[1]
            if ($oldOnly -contains $col -and $dropCols -notcontains $col) { $problems += "report uses $OldTable[$col] (not in $NewTable, not in -DropFilters): $line" }
        }
    }
    $problems | Select-Object -Unique | ForEach-Object { Write-Host "  !! $_" -ForegroundColor Yellow }
    if ($problems -and -not $Force) { Write-Host "Stopped: fix the above first (or -Force)."; $srv.Disconnect(); exit 1 }

    $status = (& powerbi-desktop status | Out-String | ConvertFrom-Json).instances
    $pbip = @(Get-ChildItem -Path $RootPath -Filter *.pbip)[0].FullName
    $inst = if ($DesktopPid) { $status | Where-Object pid -eq $DesktopPid } else { $status | Where-Object { $_.currentFilePath -eq $pbip } }
    if (@($inst).Count -ne 1) { Write-Error "Desktop with $pbip not found (powerbi-desktop status) - pass -DesktopPid"; exit 1 }
    $DesktopPid = $inst.pid
    Write-Host "  Desktop pid $DesktopPid, unsaved changes: $($inst.hasUnsavedChanges)"

    function Save-Desktop {
        # Ctrl+S to THIS Desktop window only: bring it forward, check the foreground window belongs to
        # $DesktopPid, only then send the keys (AppActivate alone left another window in front when two
        # "Sales_ClientB - Power BI Desktop" windows were open - the keys went elsewhere). Then wait until a
        # SemanticModel file on disk is newer than $since.
        if (-not ('Rmt.Win' -as [type])) {
            Add-Type -Namespace Rmt -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
'@
        }
        $h = (Get-Process -Id $DesktopPid).MainWindowHandle
        $fgPid = 0
        foreach ($try in 1..5) {
            [void][Rmt.Win]::ShowWindow($h, 9)                           # restore if minimized
            [Rmt.Win]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)          # Alt down/up: lets SetForegroundWindow work
            [Rmt.Win]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
            [void][Rmt.Win]::SetForegroundWindow($h)
            Start-Sleep -Milliseconds 500
            [uint32]$fg = 0; [void][Rmt.Win]::GetWindowThreadProcessId([Rmt.Win]::GetForegroundWindow(), [ref]$fg); $fgPid = $fg
            if ($fgPid -eq $DesktopPid) { break }
        }
        if ($fgPid -ne $DesktopPid) { Write-Error "Could not bring Desktop pid $DesktopPid to the front (foreground: pid $fgPid) - no keys sent; save it by hand, then re-run the rest"; exit 1 }
        $since = Get-Date
        (New-Object -ComObject WScript.Shell).SendKeys('^s')
        $newer = { @(Get-ChildItem $semanticPath -Recurse -File | Where-Object LastWriteTime -gt $since).Count -gt 0 }
        do { Start-Sleep 3 } until ((& $newer) -or (Get-Date) -gt $since.AddSeconds(120))
        if (-not (& $newer)) { Write-Error "Ctrl+S did not reach the files in 120 s - save in Desktop by hand, then re-run the rest"; exit 1 }
        Start-Sleep 5   # let Desktop finish writing every file
        Write-Host "OK Desktop saved"
    }
    function Apply-Desktop {
        $r = & powerbi-desktop reload --pid $DesktopPid | Out-String | ConvertFrom-Json
        if (-not $r.result.success) { Write-Error "powerbi-desktop reload failed"; exit 1 }
        Write-Host "OK Applied external changes (bridge)"
    }

    if ($DryRun) {
        Write-Host ""; Write-Host "-DryRun: report side preview"
        Invoke-DropFilters
        Invoke-ReportSwap -From $OldTable -To $NewTable
        foreach ($r in @($model.Relationships | Where-Object { $_.FromTable.Name -eq $OldTable -or $_.ToTable.Name -eq $OldTable })) {
            $other = if ($r.FromTable.Name -eq $OldTable) { "$($r.ToTable.Name).$($r.ToColumn.Name)" } else { "$($r.FromTable.Name).$($r.FromColumn.Name)" }
            $verb = if ($skipRels -contains $other) { 'drop (-SkipRelationships)' } else { 're-create on ' + $NewTable }
            Write-Host "  relationship $($r.FromTable.Name).$($r.FromColumn.Name) -> $($r.ToTable.Name).$($r.ToColumn.Name): $verb"
        }
        $srv.Disconnect(); exit 0
    }
    if ($inst.hasUnsavedChanges) { Save-Desktop }

    # --- 1-3. backup, report, apply ---
    $backupDir = Backup-Project
    Write-Host ""; Write-Host "Step 2: report"
    Invoke-DropFilters -Apply -BackupDir $backupDir
    Invoke-ReportSwap -From $OldTable -To $NewTable -Apply -BackupDir $backupDir
    Apply-Desktop

    # --- 4. TOM ---
    Write-Host ""; Write-Host "Step 4: model (TOM)"
    $srv.Disconnect(); $srv.Connect("Data Source=localhost:$Port")   # fresh view after the apply
    $model = $srv.Databases[0].Model
    $old = $model.Tables[$OldTable]; $new = $model.Tables[$NewTable]
    foreach ($oc in $old.Columns) {
        $nc = $newCols[$oc.Name.ToLower()]
        if (-not $nc -or $oc.Type -eq 'RowNumber') { continue }
        $nc = $new.Columns[$nc.Name]
        foreach ($prop in 'FormatString', 'IsHidden', 'DisplayFolder', 'Description', 'DataCategory', 'SummarizeBy') {
            if ($nc.$prop -ne $oc.$prop) { Write-Host "  $NewTable[$($nc.Name)].$prop = '$($oc.$prop)' (was '$($nc.$prop)')"; $nc.$prop = $oc.$prop }
        }
        if ($oc.SortByColumn -and $new.Columns.Contains($oc.SortByColumn.Name) -and $nc.SortByColumn.Name -ne $oc.SortByColumn.Name) {
            $nc.SortByColumn = $new.Columns[$oc.SortByColumn.Name]; Write-Host "  $NewTable[$($nc.Name)] sorted by $($oc.SortByColumn.Name)"
        }
    }
    $model.SaveChanges() | Out-Null
    $rels = @($model.Relationships | Where-Object { $_.FromTable.Name -eq $OldTable -or $_.ToTable.Name -eq $OldTable })
    $recreate = @()
    foreach ($r in $rels) {
        $oldIsFrom = $r.FromTable.Name -eq $OldTable
        $oldCol = if ($oldIsFrom) { $r.FromColumn.Name } else { $r.ToColumn.Name }
        $other = if ($oldIsFrom) { "$($r.ToTable.Name).$($r.ToColumn.Name)" } else { "$($r.FromTable.Name).$($r.FromColumn.Name)" }
        $text = "$($r.FromTable.Name).$($r.FromColumn.Name) -> $($r.ToTable.Name).$($r.ToColumn.Name)"
        if ($skipRels -contains $other) { Write-Host "  drop     $text (-SkipRelationships)" }
        elseif (-not $new.Columns.Contains($oldCol)) { Write-Host "  drop     $text ($NewTable has no $oldCol)" -ForegroundColor Yellow }
        else {
            $recreate += [pscustomobject]@{
                From = if ($oldIsFrom) { @($NewTable, $oldCol) } else { @($r.FromTable.Name, $r.FromColumn.Name) }
                To = if ($oldIsFrom) { @($r.ToTable.Name, $r.ToColumn.Name) } else { @($NewTable, $oldCol) }
                FromCard = $r.FromCardinality; ToCard = $r.ToCardinality; Cross = $r.CrossFilteringBehavior
                Active = $r.IsActive; Sec = $r.SecurityFilteringBehavior; Text = $text
            }
        }
        [void]$model.Relationships.Remove($r)
    }
    foreach ($spec in & $splitList $ActivateRelationships) {
        $r = $model.Relationships | Where-Object { "$($_.FromTable.Name).$($_.FromColumn.Name)->$($_.ToTable.Name).$($_.ToColumn.Name)" -eq $spec }
        if (-not $r) { Write-Error "-ActivateRelationships: '$spec' not found"; exit 1 }
        $r.IsActive = $true
        Write-Host "  activate $spec"
    }
    $model.SaveChanges() | Out-Null
    foreach ($x in $recreate) {
        $r = New-Object Microsoft.AnalysisServices.Tabular.SingleColumnRelationship
        $r.Name = [guid]::NewGuid().ToString()
        $r.FromColumn = $model.Tables[$x.From[0]].Columns[$x.From[1]]
        $r.ToColumn = $model.Tables[$x.To[0]].Columns[$x.To[1]]
        $r.FromCardinality = $x.FromCard; $r.ToCardinality = $x.ToCard
        $r.CrossFilteringBehavior = $x.Cross; $r.SecurityFilteringBehavior = $x.Sec; $r.IsActive = $x.Active
        $model.Relationships.Add($r)
        Write-Host "  re-create $($x.Text) on $NewTable (active: $($x.Active))"
    }
    $model.SaveChanges() | Out-Null
    [void]$model.Tables.Remove($old)
    $model.SaveChanges() | Out-Null
    Write-Host "OK $OldTable deleted"
    if ($KeepName) {
        $new.Name = $OldTable
        if ($new.Partitions.Contains($NewTable)) { $new.Partitions[$NewTable].Name = $OldTable }
        $model.SaveChanges() | Out-Null
        Write-Host "OK $NewTable renamed to $OldTable"
    }
    $model.RequestRefresh('Calculate')
    $model.SaveChanges() | Out-Null
    $srv.Disconnect()

    # --- 5. errors ---
    $q = Join-Path $PSScriptRoot "QueryOpenModel.ps1"
    $dax = 'EVALUATE ROW("measures", COUNTROWS(FILTER(INFO.MEASURES(), [State] <> 1)), "columns", COUNTROWS(FILTER(INFO.COLUMNS(), [Type] <> 3 && [State] <> 1)), "relationships", COUNTROWS(FILTER(INFO.RELATIONSHIPS(), [State] <> 1)))'
    $f = Join-Path $env:TEMP "ReplaceModelTable_check.dax"; Set-Content $f -Value $dax -Encoding utf8
    Write-Host ""; Write-Host "Step 5: objects in error (blank = 0)"
    & pwsh -NoProfile -File $q -Port $Port -QueryFile $f | Select-Object -Last 2

    # --- 6-7. save, rename in the report ---
    Save-Desktop
    if ($KeepName) {
        Write-Host ""; Write-Host "Step 7: report $NewTable -> $OldTable"
        Invoke-ReportSwap -From $NewTable -To $OldTable -Apply -BackupDir $backupDir
        Apply-Desktop
    }
    Write-Host ""; Write-Host "Done. Check: ReportFields.py refs --table $(if ($KeepName) { $OldTable } else { $NewTable })"
    exit 0
}

# ===================================================================== default: TMDL on disk (Desktop closed)
if (-not (Test-Path $oldTablePath)) { Write-Error "Old table definition not found: $oldTablePath"; exit 1 }
if (-not (Test-Path $newTablePath)) {
    Write-Error "New table definition not found: $newTablePath - create/import '$NewTable' in Power BI Desktop first, then re-run this script."
    exit 1
}
if ($DryRun) { Write-Error "-DryRun works only with -ReportOnly / -Port"; exit 1 }

# Backup - this mode edits relationships.tmdl / model.tmdl / cultures, deletes the old table's .tmdl and
# rewrites report JSON. The projects are not git repos, so the backup is the only revert path.
$backupDir = Backup-Project
Write-Host ""

# Step 0: compare column names / types, warn (don't block) - a column only on one side means measures /
# visuals may need manual review after the swap.
function Get-TmdlColumns {
    param([string]$Path)
    $text = (Get-Content $Path -Raw) -replace "`r`n", "`n"
    $cols = [ordered]@{}
    foreach ($m in [regex]::Matches($text, "(?m)^\tcolumn ('(?:[^']|'')+'|[^\s=]+)(?: =.*)?\n((?:\t\t.*\n|\n)*?)(?=^\t\S|\z)")) {
        $name = $m.Groups[1].Value -replace "^'|'$", ''
        $type = [regex]::Match($m.Groups[2].Value, '(?m)^\t\tdataType:\s*(\S+)')
        $cols[$name] = if ($type.Success) { $type.Groups[1].Value } else { "(calculated)" }
    }
    return $cols
}
Write-Host "Comparing columns..."
$oldCols = Get-TmdlColumns -Path $oldTablePath
$newColsT = Get-TmdlColumns -Path $newTablePath
foreach ($colName in $oldCols.Keys) {
    if (-not $newColsT.Contains($colName)) {
        Write-Host "  WARNING: column '$colName' exists on '$OldTable' but not on '$NewTable' - anything referencing it (measures, visuals) needs manual review." -ForegroundColor DarkYellow
    } elseif ($newColsT[$colName] -ne $oldCols[$colName]) {
        Write-Host "  NOTE: '$colName' dataType $($oldCols[$colName]) -> $($newColsT[$colName])" -ForegroundColor DarkYellow
    }
}
foreach ($colName in $newColsT.Keys) {
    if (-not $oldCols.Contains($colName)) { Write-Host "  NOTE: '$NewTable' has a new column '$colName' (nothing to migrate)." -ForegroundColor DarkYellow }
}
Write-Host ""
$oldEsc = [regex]::Escape($OldTable)
$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)

# Step 1: relationships.tmdl - repoint every fromColumn / toColumn naming OldTable (bare or quoted).
if (Test-Path $relationshipsPath) {
    $relText = Get-Content $relationshipsPath -Raw
    $pattern = "(?m)^(\s*(?:from|to)Column:\s*)(?:'$oldEsc'|$oldEsc)(\.\S+\s*)$"
    $n = [regex]::Matches($relText, $pattern).Count
    if ($n -gt 0) {
        [System.IO.File]::WriteAllText($relationshipsPath, [regex]::Replace($relText, $pattern, "`${1}$NewTable`${2}"), $utf8NoBOM)
        Write-Host "OK relationships.tmdl: repointed $n reference(s) to '$NewTable'"
    } else { Write-Host "  (relationships.tmdl: no references to '$OldTable')" }
}

# Step 2: model.tmdl "ref table" list - drop OldTable's line when NewTable is listed, else rename it.
if (Test-Path $modelPath) {
    $modelText = Get-Content $modelPath -Raw
    $oldRefPattern = "(?m)^ref table (?:'$oldEsc'|$oldEsc)\r?\n"
    $hasNewRef = [regex]::IsMatch($modelText, "(?m)^ref table (?:'$([regex]::Escape($NewTable))'|$([regex]::Escape($NewTable)))\s*$")
    if ([regex]::IsMatch($modelText, $oldRefPattern)) {
        $modelText = if ($hasNewRef) { [regex]::Replace($modelText, $oldRefPattern, "") }
                     else { [regex]::Replace($modelText, "(?m)^ref table (?:'$oldEsc'|$oldEsc)\s*$", "ref table $NewTable") }
        [System.IO.File]::WriteAllText($modelPath, $modelText, $utf8NoBOM)
        Write-Host "OK model.tmdl: 'ref table $OldTable' $(if ($hasNewRef) { 'removed' } else { "renamed to $NewTable" })"
    }
}

# Step 3: report - drop filters, then every shared column / level (ReportFields.py).
Invoke-DropFilters -Apply -BackupDir $backupDir
Invoke-ReportSwap -From $OldTable -To $NewTable -Apply -BackupDir $backupDir
Write-Host ""

# Step 4: Q&A linguistic schema (cultures\*.tmdl) - EXACT "ConceptualEntity": "OldTable" only (the file
# also has synonyms whose names merely CONTAIN the table name).
$culturesPath = Join-Path $semanticPath "definition\cultures"
if (Test-Path $culturesPath) {
    $entityPattern = "`"ConceptualEntity`":\s*`"$oldEsc`""
    foreach ($cf in Get-ChildItem -Path $culturesPath -Filter "*.tmdl") {
        $ctext = Get-Content $cf.FullName -Raw
        $n = [regex]::Matches($ctext, $entityPattern).Count
        if ($n -gt 0) {
            [System.IO.File]::WriteAllText($cf.FullName, [regex]::Replace($ctext, $entityPattern, "`"ConceptualEntity`": `"$NewTable`""), $utf8NoBOM)
            Write-Host "  OK $($cf.Name): $n translation binding(s) -> '$NewTable'"
        }
    }
}
# diagramLayout.json (table-box positions) is left alone - cosmetic, Desktop redraws it.

# Step 5: delete the old table's .tmdl.
if ($KeepOldTableFile) {
    Write-Host "  -KeepOldTableFile: old table definition left in place: $oldTablePath"
} else {
    Remove-Item -Path $oldTablePath -Force
    Write-Host "OK Deleted $oldTablePath"
}
Write-Host ""
Write-Host "Done!"
