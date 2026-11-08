# Every measure with the same name in both models, at the total: no filter and invoices + credit notes. Read-only.
param([int]$CurPort, [int]$PdfPort)
Set-StrictMode -Version Latest
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.AdomdClient.dll")
function Open($p) { $c = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$p"); $c.Open(); $c }
function Val($c, $dax) { try { $cmd = $c.CreateCommand(); $cmd.CommandText = $dax; $r = $cmd.ExecuteReader(); $v = if ($r.Read()) { $r.GetValue(0) } else { $null }; $r.Close(); if ($v -is [DBNull]) { $null } else { $v } } catch { 'ERROR' } }
function Names($c) { $cmd = $c.CreateCommand(); $cmd.CommandText = 'EVALUATE SELECTCOLUMNS(INFO.MEASURES(), "N", [Name])'; $r = $cmd.ExecuteReader(); $l = while ($r.Read()) { $r.GetString(0) }; $r.Close(); $l }
$a = Open $CurPort; $b = Open $PdfPort
$common = @(Names $a | Where-Object { $_ -in @(Names $b) }) | Sort-Object
$doc = ', TREATAS ( { "חשבוניות מס", "זיכויים" }, DocumentTypes[DocumentType] )'
$filters = [ordered]@{ 'Sep 2026' = ', DATESBETWEEN ( {T}[Date], DATE ( 2026, 9, 1 ), DATE ( 2026, 9, 30 ) )'; 'Sep 2026 inv+cred' = ', DATESBETWEEN ( {T}[Date], DATE ( 2026, 9, 1 ), DATE ( 2026, 9, 30 ) )' + $doc
                       'Year 2026' = ', DATESBETWEEN ( {T}[Date], DATE ( 2026, 1, 1 ), DATE ( 2026, 12, 31 ) )'; 'Year 2026 inv+cred' = ', DATESBETWEEN ( {T}[Date], DATE ( 2026, 1, 1 ), DATE ( 2026, 12, 31 ) )' + $doc }
$bad = 0
foreach ($m in $common) {
    $ref = '[' + $m.Replace(']', ']]') + ']'
    foreach ($f in $filters.Keys) {
        $x = Val $a ("EVALUATE ROW ( ""v"", CALCULATE ( $ref" + $filters[$f].Replace('{T}', "'Calendar'") + ' ) )')
        $y = Val $b ("EVALUATE ROW ( ""v"", CALCULATE ( $ref" + $filters[$f].Replace('{T}', "'Date'") + ' ) )')
        $isNum = { param($v) $v -is [double] -or $v -is [decimal] -or $v -is [long] }
        $same = ("$x" -eq "$y") -or ((& $isNum $x) -and (& $isNum $y) -and [math]::Abs([double]$x - [double]$y) -le [math]::ClientA(0.01, [math]::Abs([double]$y) * 1e-9))
        if (-not $same) { $bad++; "DIFF [$m] ($f): cur $x | pdf $y" }
    }
}
"common measures: $($common.Count)  checks: $($common.Count * 4)  differing: $bad"
$a.Close(); $b.Close()

