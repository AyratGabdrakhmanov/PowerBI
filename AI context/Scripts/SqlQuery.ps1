# Read-only SQL query from this workstation: System.Data.SqlClient, integrated security, prints TSV (no install needed).
# Replaces Agency\ClientB\CentralCalendar\sqlq.ps1 (gone). Windows PowerShell 5.1 or pwsh.
#   powershell -File SqlQuery.ps1 -Server SAP-Server-1 -Database PowerLoader_KNTLY -Query "SELECT ..." [-QueryFile x.sql] [-Timeout 120]
# SCRIPT_VERSION: 2026-10-26.1
param([Parameter(Mandatory)][string]$Server, [Parameter(Mandatory)][string]$Database, [string]$Query, [string]$QueryFile, [int]$Timeout = 120)
$ErrorActionPreference = 'Stop'
if ($QueryFile) { $Query = [IO.File]::ReadAllText($QueryFile) }
if ($Query -match '(?i)\b(INSERT|UPDATE|DELETE|MERGE|DROP|ALTER|CREATE|TRUNCATE|EXEC|GRANT)\b') { throw 'read-only runner: only SELECT queries' }
$cn = New-Object System.Data.SqlClient.SqlConnection "Server=$Server;Database=$Database;Integrated Security=True;Connect Timeout=15;Application Name=SqlQuery.ps1"
$cn.Open()
try {
    $cmd = $cn.CreateCommand(); $cmd.CommandText = $Query; $cmd.CommandTimeout = $Timeout
    $r = $cmd.ExecuteReader()
    do {
        $names = for ($i = 0; $i -lt $r.FieldCount; $i++) { $r.GetName($i) }
        [Console]::Out.WriteLine(($names -join "`t"))
        while ($r.Read()) {
            $vals = for ($i = 0; $i -lt $r.FieldCount; $i++) { if ($r.IsDBNull($i)) { '' } else { ([string]$r.GetValue($i)) -replace "[`r`n`t]+", ' ' } }
            [Console]::Out.WriteLine(($vals -join "`t"))
        }
        [Console]::Out.WriteLine('')
    } while ($r.NextResult())
} finally { $cn.Close() }
