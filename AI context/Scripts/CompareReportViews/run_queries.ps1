# Run every traced visual query on its model; results -> results.json (id -> {cols, rows} or error). Read-only.
param([Parameter(Mandatory)][int]$CurPort, [Parameter(Mandatory)][int]$PdfPort)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.AdomdClient.dll")
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$qs = Get-Content -Raw -Encoding UTF8 "$here\queries.json" | ConvertFrom-Json
$cn = @{}
foreach ($k in @{ cur = $CurPort; pdf = $PdfPort }.GetEnumerator()) {
    $c = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$($k.Value)"); $c.Open(); $cn[$k.Key] = $c }
$out = [ordered]@{}
foreach ($q in $qs) {
    try {
        $cmd = $cn[$q.rep].CreateCommand(); $cmd.CommandText = $q.query; $r = $cmd.ExecuteReader()
        $sets = [Collections.Generic.List[object]]::new()
        do {   # matrix queries return several result sets (column headers, body)
            $cols = @(0..($r.FieldCount - 1) | ForEach-Object { $r.GetName($_) })
            $rows = [Collections.Generic.List[object]]::new()
            while ($r.Read()) { $rows.Add(@(0..($r.FieldCount - 1) | ForEach-Object { $v = $r.GetValue($_); if ($v -is [DBNull]) { $null } else { "$v" } })) }
            $sets.Add(@{ cols = $cols; rows = $rows })
        } while ($r.NextResult())
        $r.Close()
        $big = $sets | Sort-Object { $_.cols.Count * 100000 + $_.rows.Count } -Descending | Select-Object -First 1
        $out[$q.id] = @{ cols = $big.cols; rows = $big.rows; sets = $sets.Count }
    } catch { $out[$q.id] = @{ error = $_.Exception.InnerException.Message } }
}
foreach ($c in $cn.Values) { $c.Close() }
$out | ConvertTo-Json -Depth 6 -Compress | Set-Content -Encoding UTF8 "$here\results.json"
"queries: $($qs.Count)  errors: $(@($out.Values | Where-Object { $_.Contains('error') }).Count)"
