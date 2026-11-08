# Rename the single partition of each table to the table name in the OPEN model (TOM) - BPA
# PARTITION_NAME_SHOULD_MATCH_TABLE_NAME_FOR_SINGLE_PARTITION_TABLES (Desktop default names "Table-<guid>").
# Metadata only: partitions stay Ready, no refresh, Desktop saves without a "pending changes" banner (ClientB 2026-10-25).
# Dry run by default.
#   pwsh -File RenamePartitions.ps1 -Port <port> [-Tables "A;B"] [-Apply]      (-Tables omitted = every mismatched one)
# Then SaveDesktop.ps1 -Expect "definition\tables\A.tmdl|partition A = m;…".
# SCRIPT_VERSION: 2026-10-25.1
param([Parameter(Mandatory)][int]$Port, [string]$Tables = '', [switch]$Apply)
Set-StrictMode -Version Latest
$Names = @($Tables -split ';' | ForEach-Object Trim | Where-Object { $_ })
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
$srv = New-Object Microsoft.AnalysisServices.Tabular.Server; $srv.Connect("Data Source=localhost:$Port"); $m = $srv.Databases[0].Model
if (-not $Names) { $Names = @($m.Tables | Where-Object { $_.Partitions.Count -eq 1 -and $_.Partitions[0].Name -ne $_.Name } | ForEach-Object Name) }
$todo = @()
foreach ($n in $Names) {
    $t = $m.Tables[$n]; if (-not $t) { throw "table not found: $n" }
    if ($t.Partitions.Count -ne 1) { throw "$n has $($t.Partitions.Count) partitions" }
    $p = $t.Partitions[0]
    if ($p.Name -ne $n) { $todo += $p; "{0} -> {1}  ({2}, {3})" -f $p.Name, $n, $p.SourceType, $p.State } }
"to rename: $($todo.Count)"
if (-not $Apply -or -not $todo) { if (-not $Apply) { "dry run - add -Apply" }; $srv.Disconnect(); return }
foreach ($p in $todo) { $p.Name = $p.Table.Name }
$m.SaveChanges() | Out-Null
foreach ($p in $todo) { "after: {0} | {1}" -f $p.Name, $p.State }
$srv.Disconnect()
