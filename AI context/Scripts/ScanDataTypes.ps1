# Data type scan of the OPEN model (read-only) for the "Data types" refactoring step (Refactoring.md step 5):
#   DOUBLE   - every Double column: distinct values, non-integer values (0 = can be Whole number), the largest
#              loss when rounded to 4 decimals (= what Currency / Fixed decimal would cut);
#   DATETIME - every Date/time column: values with a time part (0 = can be Date), current
#              UnderlyingDateTimeDataType annotation and format.
#   pwsh -File ScanDataTypes.ps1 -Port <port> [-SkipTables "Calendar;Calendar Comparison"]   (";"-separated)
# SCRIPT_VERSION: 2026-10-24.1
param(
    [Parameter(Mandatory)][int]$Port,
    [string]$SkipTables = ''
)
Set-StrictMode -Version Latest
$Skip = @($SkipTables -split ';' | ForEach-Object Trim | Where-Object { $_ })
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.AdomdClient.dll")
$srv = New-Object Microsoft.AnalysisServices.Tabular.Server; $srv.Connect("Data Source=localhost:$Port"); $m = $srv.Databases[0].Model
$cn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$Port"); $cn.Open()
function Q([string]$dax) { $c = $cn.CreateCommand(); $c.CommandText = $dax; $r = $c.ExecuteReader(); [void]$r.Read()
    $v = @(0..($r.FieldCount - 1) | ForEach-Object { $r.GetValue($_) }); $r.Close(); , $v }
foreach ($t in $m.Tables) {
    if ($Skip -contains $t.Name) { continue }
    foreach ($c in $t.Columns) {
        if ($c.Type -eq 'RowNumber') { continue }
        $ref = "'" + $t.Name.Replace("'", "''") + "'[" + $c.Name.Replace(']', ']]') + "]"
        $kind = "$($c.Type)" -replace 'Column$', ''
        if ($c.DataType -eq 'Double') {
            $v = Q "EVALUATE ROW(""d"", COUNTROWS(DISTINCT($ref)), ""frac"", COUNTROWS(FILTER(DISTINCT($ref), $ref <> INT($ref))), ""lost"", MAXX(DISTINCT($ref), ABS($ref - ROUND($ref, 4))), ""max"", MAXX(DISTINCT($ref), ABS($ref)))"
            "DOUBLE   | $($t.Name)[$($c.Name)] | $kind | distinct=$($v[0]) | nonInteger=$($v[1]) | maxRoundLoss4=$($v[2]) | maxAbs=$($v[3]) | fmt=$($c.FormatString)"
        } elseif ($c.DataType -eq 'DateTime') {
            $ann = @($c.Annotations | Where-Object { $_.Name -eq 'UnderlyingDateTimeDataType' }) | Select-Object -First 1
            $u = if ($ann) { $ann.Value } else { '-' }
            $v = Q "EVALUATE ROW(""d"", COUNTROWS(DISTINCT($ref)), ""t"", COUNTROWS(FILTER(DISTINCT($ref), NOT ISBLANK($ref) && $ref <> INT($ref))))"
            "DATETIME | $($t.Name)[$($c.Name)] | $kind | distinct=$($v[0]) | withTime=$($v[1]) | underlying=$u | fmt=$($c.FormatString)"
        } } }
$cn.Close(); $srv.Disconnect()
