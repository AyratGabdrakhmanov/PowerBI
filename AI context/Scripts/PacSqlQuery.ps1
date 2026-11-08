# Read-only SQL to ClientA / ClientA-Project DEV: SQL-Server-1 / ClientA-DB, SQL login powerbi - the fallback when the
# MCP sql-mcp (DBHub) did not start. Password: the DPAPI file of Set-DbHubLogin.ps1 (%USERPROFILE%\.dbhub\pac.pwd, only
# this Windows user on this PC can decrypt it) - never typed, never printed. VPN VPN must be up.
# Refuses non-SELECT text; ApplicationIntent=ReadOnly; prints every result set as TSV (first -MaxRows rows + row count).
#   powershell -NoProfile -ExecutionPolicy Bypass -File PacSqlQuery.ps1 -QueryFile "<file.sql>" [-MaxRows 200]
# Pass paths with Cyrillic as arguments (PowerShell 5.1 misreads them inside a BOM-less script).
# Change log:
# 2026-11-07.1  Created (BBack SQL test, custom-object survey on SQL-Server-1).
param([Parameter(Mandatory)][string]$QueryFile, [string]$Database = 'ClientA-DB', [int]$MaxRows = 200)
$ErrorActionPreference = 'Stop'
$sql = [IO.File]::ReadAllText($QueryFile)
if ($sql -match '(?i)\b(INSERT|UPDATE|DELETE|MERGE|DROP|ALTER|CREATE|EXEC|EXECUTE|TRUNCATE|GRANT)\b') { throw 'non-SELECT keyword found' }
$sec = Get-Content (Join-Path $env:USERPROFILE '.dbhub\pac.pwd') | ConvertTo-SecureString
$sec.MakeReadOnly()
$cred = New-Object System.Data.SqlClient.SqlCredential('powerbi', $sec)
$cn = New-Object System.Data.SqlClient.SqlConnection("Server=SQL-Server-1;Database=$Database;Encrypt=True;TrustServerCertificate=True;ApplicationIntent=ReadOnly;Connect Timeout=15;Application Name=PacSqlQuery", $cred)
$cn.Open()
$cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 600
$r = $cmd.ExecuteReader()
do {
    $names = for ($i = 0; $i -lt $r.FieldCount; $i++) { $r.GetName($i) }
    '--- ' + ($names -join "`t")
    $n = 0
    while ($r.Read()) {
        $n++; if ($n -gt $MaxRows) { continue }
        $vals = for ($i = 0; $i -lt $r.FieldCount; $i++) { if ($r.IsDBNull($i)) { '' } else { ([string]$r.GetValue($i)) -replace "[`r`n`t]+", ' ' } }
        $vals -join "`t"
    }
    "($n rows)"
} while ($r.NextResult())
$cn.Close()
