# Put back into an OPEN Desktop model every table / column / measure / relationship that a TMDL backup has and the
# open model lacks (after a bridge apply removed them - ClientD Finance 2026-10-23, CleanUnused -Port). Objects are
# Clone()d from the deserialized backup (zero-width hierarchy level names patched in a scratch copy, as
# ValidateTmdl.ps1), sort-by restored after all columns exist, relationships re-created, Calculate refresh only
# (never a source refresh). M tables come back WITHOUT data: reopen the .pbip (data from .pbi\cache.abf, the files
# must be the backup state) or let the user refresh them.
#   pwsh -File RestoreOpenModelFromTmdl.ps1 -Port <port> -Backup "<...\X.SemanticModel\definition>"           (dry run)
#   pwsh -File RestoreOpenModelFromTmdl.ps1 -Port <port> -Backup "<...\X.SemanticModel\definition>" -Apply
# Save Desktop afterwards (SaveDesktop.ps1).
# SCRIPT_VERSION: 2026-10-23.1
param([Parameter(Mandatory)][int]$Port, [Parameter(Mandatory)][string]$Backup, [switch]$Apply)
$ErrorActionPreference = 'Stop'
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
$TOM = 'Microsoft.AnalysisServices.Tabular'

$tmp = Join-Path $env:TEMP ("RestoreTmdl_" + [guid]::NewGuid().ToString('N')); Copy-Item $Backup $tmp -Recurse
$zw = [string][char]0x200B; $nbsp = [string][char]0xA0
foreach ($f in Get-ChildItem (Join-Path $tmp 'tables') -Filter *.tmdl) {
    $t = [IO.File]::ReadAllText($f.FullName)
    $n = [regex]::Replace($t, "(?m)^(\t\tlevel )($zw+)(\r?)$", { param($m) $m.Groups[1].Value + "'" + ($nbsp * $m.Groups[2].Value.Length) + "'" + $m.Groups[3].Value })
    if ($n -ne $t) { [IO.File]::WriteAllText($f.FullName, $n, (New-Object Text.UTF8Encoding $false)) }
}
$src = ([Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeDatabaseFromFolder($tmp)).Model

$srv = New-Object "$TOM.Server"; $srv.Connect("Data Source=localhost:$Port")
$dst = $srv.Databases[0].Model

$plan = @()
$newTables = @($src.Tables | Where-Object { -not $dst.Tables.Find($_.Name) })
foreach ($t in $newTables) { $plan += "table  $($t.Name) [$($t.Partitions[0].SourceType)]" }
$newCols = @(); $newMeas = @()
foreach ($t in $src.Tables) {
    $d = $dst.Tables.Find($t.Name); if (-not $d) { continue }
    foreach ($c in $t.Columns) { if ($c.Type -ne 'RowNumber' -and -not $d.Columns.Find($c.Name)) { $newCols += , @($t.Name, $c); $plan += "column $($t.Name)[$($c.Name)] [$($c.Type)]" } }
    foreach ($m in $t.Measures) { if (-not $d.Measures.Find($m.Name)) { $newMeas += , @($t.Name, $m); $plan += "measure $($t.Name)[$($m.Name)]" } }
}
$newRels = @($src.Relationships | Where-Object { -not $dst.Relationships.Find($_.Name) })
foreach ($r in $newRels) { $plan += "relationship $($r.FromTable.Name)[$($r.FromColumn.Name)] -> $($r.ToTable.Name)[$($r.ToColumn.Name)]" }
$plan
"TOTAL: tables $($newTables.Count), columns $($newCols.Count), measures $($newMeas.Count), relationships $($newRels.Count)"
if (-not $Apply) { $srv.Disconnect(); exit 0 }

foreach ($t in $newTables) { $dst.Tables.Add($t.Clone()) }
foreach ($x in $newCols) { $c = $x[1].Clone(); $c.SortByColumn = $null; $dst.Tables[$x[0]].Columns.Add($c) }
foreach ($x in $newCols) { if ($x[1].SortByColumn) { $dst.Tables[$x[0]].Columns[$x[1].Name].SortByColumn = $dst.Tables[$x[0]].Columns[$x[1].SortByColumn.Name] } }
foreach ($x in $newMeas) { $dst.Tables[$x[0]].Measures.Add($x[1].Clone()) }
$dst.SaveChanges() | Out-Null
foreach ($r in $newRels) {
    $n = New-Object "$TOM.SingleColumnRelationship"; $n.Name = $r.Name
    $n.FromColumn = $dst.Tables[$r.FromTable.Name].Columns[$r.FromColumn.Name]
    $n.ToColumn   = $dst.Tables[$r.ToTable.Name].Columns[$r.ToColumn.Name]
    $n.FromCardinality = $r.FromCardinality; $n.ToCardinality = $r.ToCardinality
    $n.CrossFilteringBehavior = $r.CrossFilteringBehavior; $n.IsActive = $r.IsActive; $n.SecurityFilteringBehavior = $r.SecurityFilteringBehavior
    $dst.Relationships.Add($n)
}
$dst.SaveChanges() | Out-Null
foreach ($t in $newTables) { if ($t.Partitions[0].SourceType -eq 'Calculated') { $dst.Tables[$t.Name].RequestRefresh('Calculate') } }
foreach ($x in $newCols) { if ($x[1].Type -eq 'Calculated') { $dst.Tables[$x[0]].RequestRefresh('Calculate') } }
$dst.SaveChanges() | Out-Null
$dst.RequestRefresh('Calculate'); $dst.SaveChanges() | Out-Null

$cnt = { param($m) "tables $($m.Tables.Count), measures $(($m.Tables | ForEach-Object { $_.Measures.Count } | Measure-Object -Sum).Sum), columns $(($m.Tables | ForEach-Object { @($_.Columns | Where-Object Type -ne 'RowNumber').Count } | Measure-Object -Sum).Sum), relationships $($m.Relationships.Count)" }
"open model: " + (& $cnt $dst)
"backup:     " + (& $cnt $src)
$srv.Disconnect()
