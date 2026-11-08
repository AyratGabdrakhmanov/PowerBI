# Model part of moving measures to another home table in the OPEN model (TOM): Clone -> Remove -> Add, with the
# culture captions carried over (a translation pointing at the removed measure blocks SaveChanges), DAX refs
# 'From'[Measure] rewritten to [Measure], optional deletion of the source table when it is left empty (a pure
# measure table: no columns). Dry run by default.
#   pwsh -File MoveMeasures.ps1 -Port <port> -From KeyData -To _Measures [-Measures "A;B"]   (";"-separated) [-Hide] [-DeleteSource] [-Apply]
# -Measures omitted = all measures of -From. -Hide: set IsHidden (when the source table was hidden, so the field
# list stays the same). Report side afterwards: MoveMeasureRefs.py (same -From / -To / names), CheckReportRefs.py,
# bridge reload, SaveDesktop.ps1. Folders, formats, descriptions, lineage tags move with the clone.
# SCRIPT_VERSION: 2026-10-24.1
param(
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][string]$From,
    [Parameter(Mandatory)][string]$To,
    [string]$Measures = '',
    [switch]$Hide,
    [switch]$DeleteSource,
    [switch]$Apply
)
Set-StrictMode -Version Latest
$Names = @($Measures -split ';' | ForEach-Object Trim | Where-Object { $_ })
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
$srv = New-Object Microsoft.AnalysisServices.Tabular.Server; $srv.Connect("Data Source=localhost:$Port"); $m = $srv.Databases[0].Model
$src = $m.Tables[$From]; $dst = $m.Tables[$To]; $cap = [Microsoft.AnalysisServices.Tabular.TranslatedProperty]::Caption
if (-not $src -or -not $dst) { throw "table not found: $From / $To" }
if (-not $Names) { $Names = @($src.Measures | ForEach-Object Name) }
$missing = @($Names | Where-Object { -not $src.Measures.ContainsName($_) }); if ($missing) { throw "not in ${From}: $($missing -join ', ')" }
$clash = @($Names | Where-Object { $dst.Measures.ContainsName($_) }); if ($clash) { throw "already in ${To}: $($clash -join ', ')" }
$q = [regex]::Escape($From)
$pattern = "(?<![\w'])(?:'$q'|$q)\s*(?=\[(?:" + (($Names | ForEach-Object { [regex]::Escape($_.Replace(']', ']]')) }) -join '|') + ")\])"
$dax = @(foreach ($t in $m.Tables) { $t.Measures; $t.Columns | Where-Object { $_.Type -eq 'Calculated' } }) | Where-Object { $_.Expression -match $pattern }
"move $($Names.Count) measure(s) $From -> $To; DAX objects with '$From'[...] refs: $(@($dax).Count)"
$dax | ForEach-Object { "  rewrite: $($_.Name)" }
$leftCols = @($src.Columns | Where-Object { $_.Type -ne 'RowNumber' }).Count
if ($DeleteSource -and ($leftCols -or $src.Measures.Count -ne $Names.Count)) { throw "-DeleteSource: $From keeps $leftCols column(s) / other measures" }
if (-not $Apply) { "dry run - add -Apply"; $srv.Disconnect(); return }
foreach ($o in $dax) { $o.Expression = [regex]::Replace($o.Expression, $pattern, '') }
$moved = 0
foreach ($name in $Names) {
    $ms = $src.Measures[$name]
    $caps = @{}; foreach ($cu in $m.Cultures) { $tr = $cu.ObjectTranslations[$ms, $cap]; if ($tr) { $caps[$cu.Name] = $tr.Value } }
    foreach ($cu in $m.Cultures) { foreach ($ot in @($cu.ObjectTranslations | Where-Object { $_.Object -eq $ms })) { [void]$cu.ObjectTranslations.Remove($ot) } }
    $c = $ms.Clone(); [void]$src.Measures.Remove($ms); if ($Hide) { $c.IsHidden = $true }; $dst.Measures.Add($c)
    foreach ($k in $caps.Keys) { $m.Cultures[$k].ObjectTranslations.SetTranslation($c, $cap, $caps[$k]) }
    $moved++ }
if ($moved -ne $Names.Count) { throw "moved $moved of $($Names.Count)" }
$m.SaveChanges() | Out-Null; "moved: $moved"
if ($DeleteSource) {
    foreach ($cu in $m.Cultures) { foreach ($ot in @($cu.ObjectTranslations | Where-Object { $_.Object -eq $src })) { [void]$cu.ObjectTranslations.Remove($ot) } }
    [void]$m.Tables.Remove($src); $m.SaveChanges() | Out-Null; "deleted table $From" }
$srv.Disconnect()
