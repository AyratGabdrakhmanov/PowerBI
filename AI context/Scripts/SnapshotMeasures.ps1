# Values snapshot of measures in the OPEN model (read-only), to compare before / after a change with
# CompareSnapshots.py. Evaluates every given measure at the grand total and grouped by each -By column.
#   pwsh -File SnapshotMeasures.ps1 -Port <port> -Out before.txt [-Measures "[A];[B]"] [-By "'Calendar'[Year];'Calendar'[Month Year]"] [-Filter "TREATAS ( { 2 }, 'CT_Currency'[CurrencyID] )"]
# Lists are ONE string split by ";" (pwsh -File passes "a","b" as a single string).
# -Measures omitted = every measure of the model (TOM). A query that fails (measure in error) is written as an
# ERROR line, so a broken measure shows up as a difference instead of stopping the run.
# -Filter: CALCULATETABLE filter arguments for every query (e.g. a selector state); labels stay the same, so snapshots
# taken with different filter columns (before / after a selector rebuild) compare section by section.
# SCRIPT_VERSION: 2026-10-28.1
# Change log:
# 2026-10-28.1  -Filter.
param(
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][string]$Out,
    [string]$Measures = '',
    [string]$By = '',
    [string]$Filter = ''
)
Set-StrictMode -Version Latest
$MeasureList = @($Measures -split ';' | ForEach-Object Trim | Where-Object { $_ }); $ByList = @($By -split ';' | ForEach-Object Trim | Where-Object { $_ })
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.AdomdClient.dll")
if (-not $MeasureList) {
    $srv = New-Object Microsoft.AnalysisServices.Tabular.Server; $srv.Connect("Data Source=localhost:$Port")
    $MeasureList = @(foreach ($t in $srv.Databases[0].Model.Tables) { foreach ($m in $t.Measures) { '[' + $m.Name.Replace(']', ']]') + ']' } })
    $srv.Disconnect() }
$cn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$Port"); $cn.Open()
$lines = [Collections.Generic.List[string]]::new()
function Run([string]$label, [string]$dax) {
    $lines.Add("## $label")
    try { $c = $cn.CreateCommand(); $c.CommandText = $dax; $r = $c.ExecuteReader()
          while ($r.Read()) { $lines.Add((@(0..($r.FieldCount - 1) | ForEach-Object { "$($r.GetValue($_))" }) -join ' | ')) }; $r.Close() }
    catch { $lines.Add("ERROR $($_.Exception.InnerException.Message)") } }
foreach ($ms in $MeasureList) {
    $name = '"' + $ms.Replace('"', '""') + '"'
    $q = "ROW($name, $ms)"; if ($Filter) { $q = "CALCULATETABLE($q, $Filter)" }
    Run "$ms total" "EVALUATE $q"
    foreach ($b in $ByList) {
        $q = "SUMMARIZECOLUMNS($b, $name, $ms)"; if ($Filter) { $q = "CALCULATETABLE($q, $Filter)" }
        Run "$ms by $b" "EVALUATE $q ORDER BY $b" } }
$cn.Close()
$lines | Set-Content -Encoding UTF8 $Out
"measures: $($MeasureList.Count)  lines: $($lines.Count)  errors: $(@($lines | Where-Object { $_ -like 'ERROR*' }).Count)  -> $Out"
