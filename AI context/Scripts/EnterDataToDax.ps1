# "Enter data" / internal M tables -> DAX DATATABLE calculated tables, live in an open Desktop model (TOM).
# Generalised from Translation\tom_to_dax_tables.ps1 (ClientB): the rows are read from the open model (the final M
# result, not the encoded Source), the DATATABLE text is generated (aligned, "{" on its own line), relationships
# are carried over, lineage tags are kept. Calculate-only - no source refresh.
#
#   pwsh -File EnterDataToDax.ps1 -Port <port> -Tables 'AR Periods','DocumentTypes' [-Columns @{ 'T' = 'A','B' }] [-DryRun]
#
# -Columns: per table, the columns to keep (others are dropped). Default: all columns.
# Per table: temp DAX table -> types / row count / values compared both ways (EXCEPT) -> one SaveChanges swap
# (old relationships + translations + measures out, old table out, temp renamed, measures + relationships in)
# -> column properties (format, summarize, hidden, folder, description, sort-by, lineage tag) -> captions.
# Save Desktop afterwards (TOM edits live in the open model until saved).
# SCRIPT_VERSION: 2026-10-23.1
param(
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][string[]]$Tables,
    [hashtable]$Columns = @{},
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$bin = 'C:\Program Files\DAX Studio\bin'
[void][Reflection.Assembly]::LoadFrom("$bin\Microsoft.AnalysisServices.Tabular.dll")
[void][Reflection.Assembly]::LoadFrom("$bin\Microsoft.AnalysisServices.AdomdClient.dll")
$TOM = 'Microsoft.AnalysisServices.Tabular'
$srv = New-Object "$TOM.Server"; $srv.Connect("Data Source=localhost:$Port")
$model = $srv.Databases[0].Model
$cn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection "Data Source=localhost:$Port"; $cn.Open()

function Invoke-Dax([string]$q) {
    # a List, returned with "," - a one-row result must stay a list of rows (PowerShell unrolls it otherwise)
    $cmd = $cn.CreateCommand(); $cmd.CommandText = $q; $r = $cmd.ExecuteReader()
    $rows = [System.Collections.Generic.List[object]]::new()
    while ($r.Read()) { $rows.Add([object[]]@(for ($i = 0; $i -lt $r.FieldCount; $i++) { $r.GetValue($i) })) }
    $r.Close(); return , $rows
}
function Q([string]$name) { "'" + $name.Replace("'", "''") + "'" }
$daxType = @{ String = 'STRING'; Int64 = 'INTEGER'; Double = 'DOUBLE'; Decimal = 'CURRENCY'; DateTime = 'DATETIME'; Boolean = 'BOOLEAN' }
function Lit($v, [string]$type) {
    if ($v -is [DBNull] -or $null -eq $v) { return 'BLANK ()' }
    switch ($type) {
        'String'   { '"' + ([string]$v).Replace('"', '""') + '"' }
        'Boolean'  { if ($v) { 'TRUE' } else { 'FALSE' } }
        'DateTime' { '"' + ([datetime]$v).ToString('yyyy-MM-dd HH:mm:ss') + '"' }
        default    { [string]([System.Convert]::ToString($v, [Globalization.CultureInfo]::InvariantCulture)) }
    }
}

foreach ($name in $Tables) {
    $old = $model.Tables.Find($name)
    if (-not $old) { throw "No table $name" }
    if ($old.Partitions[0].SourceType -ne 'M') { "$name is already $($old.Partitions[0].SourceType) - skipped"; continue }
    $keep = if ($Columns.ContainsKey($name)) { @($Columns[$name]) } else { @($old.Columns | Where-Object Type -ne 'RowNumber' | ForEach-Object Name) }
    $colObjs = foreach ($k in $keep) { $c = $old.Columns.Find($k); if (-not $c) { throw "$name has no column $k" }; $c }

    # --- rows from the open model -> DATATABLE text ---
    $sel = ($colObjs | ForEach-Object { '"' + $_.Name.Replace('"', '""') + '", ' + (Q $name) + '[' + $_.Name.Replace(']', ']]') + ']' }) -join ', '
    $rows = Invoke-Dax "EVALUATE DISTINCT ( SELECTCOLUMNS ( $(Q $name), $sel ) )"
    $total = (Invoke-Dax "EVALUATE ROW ( ""n"", COUNTROWS ( $(Q $name) ) )")[0][0]
    if ($rows.Count -ne $total) { throw "$name : $total rows but $($rows.Count) distinct rows over the kept columns - dropping columns would merge rows" }
    $types = $colObjs | ForEach-Object { "$($_.DataType)" }
    $lits = foreach ($r in $rows) { , @(for ($i = 0; $i -lt $colObjs.Count; $i++) { Lit $r[$i] $types[$i] }) }
    $w = for ($i = 0; $i -lt $colObjs.Count; $i++) { ($lits | ForEach-Object { $_[$i].Length } | Measure-Object -Maximum).Maximum }
    $hdrW = ($colObjs | ForEach-Object { $_.Name.Length + 3 } | Measure-Object -Maximum).Maximum
    $hdr = for ($i = 0; $i -lt $colObjs.Count; $i++) { '    ' + ('"' + $colObjs[$i].Name + '",').PadRight($hdrW) + ' ' + $daxType[$types[$i]] + ',' }
    $body = for ($j = 0; $j -lt $lits.Count; $j++) {
        $cells = for ($i = 0; $i -lt $colObjs.Count; $i++) {
            $s = $lits[$j][$i]; $last = $i -eq $colObjs.Count - 1
            if ($types[$i] -eq 'String') { ($s + $(if ($last) { '' } else { ',' })).PadRight($w[$i] + 1) } else { $s.PadLeft($w[$i]) + $(if ($last) { '' } else { ',' }) }
        }
        '        { ' + (($cells -join ' ').TrimEnd()) + ' }' + $(if ($j -lt $lits.Count - 1) { ',' } else { '' })
    }
    $expr = "`nDATATABLE (`n" + ($hdr -join "`n") + "`n    {`n" + ($body -join "`n") + "`n    }`n)"
    "== $name : $($colObjs.Count) of $(@($old.Columns | Where-Object Type -ne 'RowNumber').Count) columns, $($rows.Count) rows, $($old.Measures.Count) measures"
    if ($DryRun) { $expr; continue }

    # --- capture ---
    $colProps = foreach ($c in $colObjs) { [pscustomobject]@{ Name = $c.Name; Type = "$($c.DataType)"; Sort = $c.SortByColumn.Name; Fmt = $c.FormatString; Hidden = $c.IsHidden; Sum = $c.SummarizeBy; Folder = $c.DisplayFolder; Desc = $c.Description; Tag = $c.LineageTag; Cat = $c.DataCategory } }
    $meas = foreach ($x in $old.Measures) { [pscustomobject]@{ Name = $x.Name; Expr = $x.Expression; Fmt = $x.FormatString; Folder = $x.DisplayFolder; Desc = $x.Description; Hidden = $x.IsHidden; Tag = $x.LineageTag } }
    $tr = foreach ($cul in $model.Cultures) { foreach ($o in @($cul.ObjectTranslations | Where-Object { $_.Object -eq $old -or $_.Object.Parent -eq $old })) {
        [pscustomobject]@{ Culture = $cul.Name; Kind = "$($o.Object.ObjectType)"; Obj = $o.Object.Name; Prop = $o.Property; Value = $o.Value; Ref = $o } } }
    $rels = foreach ($r in @($model.Relationships | Where-Object { $_.FromTable.Name -eq $name -or $_.ToTable.Name -eq $name })) {
        if ($keep -notcontains $(if ($r.FromTable.Name -eq $name) { $r.FromColumn.Name } else { $r.ToColumn.Name })) { throw "$name : relationship $($r.Name) uses a dropped column" }
        [pscustomobject]@{ Name = $r.Name; FT = $r.FromTable.Name; FC = $r.FromColumn.Name; TT = $r.ToTable.Name; TC = $r.ToColumn.Name; FCard = $r.FromCardinality; TCard = $r.ToCardinality
                           Cross = $r.CrossFilteringBehavior; Active = $r.IsActive; Sec = $r.SecurityFilteringBehavior; Ref = $r } }
    $tableTag = $old.LineageTag; $tmp = "$name`__dax"

    # --- temp DAX table, checked against the old one ---
    $t = New-Object "$TOM.Table"; $t.Name = $tmp; $t.IsHidden = $old.IsHidden; $t.Description = $old.Description
    $p = New-Object "$TOM.Partition"; $p.Name = $tmp
    $src = New-Object "$TOM.CalculatedPartitionSource"; $src.Expression = $expr; $p.Source = $src
    $t.Partitions.Add($p); $model.Tables.Add($t); $model.SaveChanges() | Out-Null
    $t.RequestRefresh('Calculate'); $model.SaveChanges() | Out-Null
    foreach ($cp in $colProps) {
        $nc = $t.Columns.Find($cp.Name); if (-not $nc) { throw "$name : DAX table has no column $($cp.Name)" }
        if ("$($nc.DataType)" -ne $cp.Type) { throw "$name[$($cp.Name)] type $($nc.DataType) <> $($cp.Type)" }
    }
    $selNew = ($colObjs | ForEach-Object { '"' + $_.Name.Replace('"', '""') + '", ' + (Q $tmp) + '[' + $_.Name.Replace(']', ']]') + ']' }) -join ', '
    $a = "SELECTCOLUMNS ( $(Q $name), $sel )"; $b = "SELECTCOLUMNS ( $(Q $tmp), $selNew )"
    $diff = (Invoke-Dax "EVALUATE ROW ( ""d"", COUNTROWS ( EXCEPT ( $a, $b ) ) + COUNTROWS ( EXCEPT ( $b, $a ) ) + 0, ""n"", COUNTROWS ( $(Q $tmp) ) )")[0]
    if ($diff[0] -ne 0 -or $diff[1] -ne $total) { [void]$model.Tables.Remove($t); $model.SaveChanges() | Out-Null; throw "$name : DAX table differs (diff rows $($diff[0]), rows $($diff[1]) vs $total) - temp table removed" }
    "   values match ($total rows)"

    # --- swap in one SaveChanges ---
    foreach ($x in $tr) { [void]$model.Cultures[$x.Culture].ObjectTranslations.Remove($x.Ref) }
    foreach ($x in @($old.Measures)) { [void]$old.Measures.Remove($x) }
    foreach ($r in $rels) { [void]$model.Relationships.Remove($r.Ref) }
    $model.SaveChanges() | Out-Null
    [void]$model.Tables.Remove($old)
    $t.Name = $name; $p.Name = $name
    foreach ($x in $meas) {
        $mm = New-Object "$TOM.Measure"; $mm.Name = $x.Name; $mm.Expression = $x.Expr; $mm.IsHidden = $x.Hidden; $mm.LineageTag = $x.Tag
        if ($x.Fmt) { $mm.FormatString = $x.Fmt }; if ($x.Folder) { $mm.DisplayFolder = $x.Folder }; if ($x.Desc) { $mm.Description = $x.Desc }
        $t.Measures.Add($mm)
    }
    foreach ($r in $rels) {
        $n = New-Object "$TOM.SingleColumnRelationship"; $n.Name = $r.Name
        $n.FromColumn = $model.Tables[$r.FT].Columns[$r.FC]; $n.ToColumn = $model.Tables[$r.TT].Columns[$r.TC]
        $n.FromCardinality = $r.FCard; $n.ToCardinality = $r.TCard; $n.CrossFilteringBehavior = $r.Cross; $n.IsActive = $r.Active; $n.SecurityFilteringBehavior = $r.Sec
        $model.Relationships.Add($n)
    }
    $model.SaveChanges() | Out-Null
    # --- column properties, lineage tags, captions ---
    $t.LineageTag = $tableTag
    foreach ($cp in $colProps) {
        $nc = $t.Columns[$cp.Name]
        $nc.FormatString = $cp.Fmt; $nc.IsHidden = $cp.Hidden; $nc.SummarizeBy = $cp.Sum; $nc.DisplayFolder = $cp.Folder; $nc.Description = $cp.Desc; $nc.LineageTag = $cp.Tag
        if ($cp.Cat) { $nc.DataCategory = $cp.Cat }
        if ($cp.Sort) { $nc.SortByColumn = $t.Columns[$cp.Sort] }
    }
    $model.SaveChanges() | Out-Null
    foreach ($x in $tr) {
        $obj = switch ($x.Kind) { 'Table' { $t } 'Column' { $t.Columns.Find($x.Obj) } 'Measure' { $t.Measures.Find($x.Obj) } }
        if ($obj) { $model.Cultures[$x.Culture].ObjectTranslations.SetTranslation($obj, $x.Prop, $x.Value) }
    }
    $model.SaveChanges() | Out-Null
    "OK $name -> DAX ($(@($rels).Count) relationship(s), $(@($meas).Count) measure(s) carried over)"
}
if (-not $DryRun) { $model.RequestRefresh('Calculate'); $model.SaveChanges() | Out-Null; "OK model recalculated (Calculate)" }
$cn.Close(); $srv.Disconnect()
