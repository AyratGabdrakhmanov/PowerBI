# QueryOpenModel.ps1
# Runs a DAX query (EVALUATE ...) against the model currently open in Power BI
# Desktop, via its local Analysis Services engine (msmdsrv.exe) and ADOMD.NET.
# Read-only: the script never changes the model.
#
# Examples:
#   powershell -ExecutionPolicy Bypass -File QueryOpenModel.ps1 -Query "EVALUATE ROW(""Rows"", COUNTROWS(Doc_ItemName))"
#   powershell -ExecutionPolicy Bypass -File QueryOpenModel.ps1 -QueryFile q1.dax
#   powershell -ExecutionPolicy Bypass -File QueryOpenModel.ps1 -ListInstances
#
# Details: POWERBI_PBIP_STRUCTURE.md, section "Querying the open Power BI Desktop model".

param(
    [string]$Query,
    [string]$QueryFile,
    [int]$Port,
    [switch]$ListInstances
)

$ScriptVersion = "2026-10-04.1"
Write-Host "QueryOpenModel.ps1 version $ScriptVersion"

# --- ADOMD.NET: taken from an installed DAX Studio / Tabular Editor ---
$dll = @(
    "C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.AdomdClient.dll",
    "C:\Program Files (x86)\DAX Studio\bin\Microsoft.AnalysisServices.AdomdClient.dll",
    "C:\Program Files\Tabular Editor 3\Microsoft.AnalysisServices.AdomdClient.dll",
    "C:\Program Files (x86)\Tabular Editor\Microsoft.AnalysisServices.AdomdClient.dll"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dll) { throw "Microsoft.AnalysisServices.AdomdClient.dll not found (install DAX Studio or Tabular Editor)." }
# LoadFrom, not Add-Type: Add-Type enumerates all types and fails noisily under Windows PowerShell 5.1
[void][Reflection.Assembly]::LoadFrom($dll)

# --- Port: Desktop writes it to msmdsrv.port.txt (UTF-16) in its workspace folder ---
$roots = @(
    "$env:USERPROFILE\Microsoft\Power BI Desktop Store App\AnalysisServicesWorkspaces",
    "$env:LOCALAPPDATA\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces"
)
$instances = foreach ($f in Get-ChildItem $roots -Recurse -Filter msmdsrv.port.txt -ErrorAction SilentlyContinue) {
    $p = [int]([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($f.FullName)).Trim())
    # The file can outlive a closed Desktop - keep only ports that are actually listening
    if (Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue) {
        [pscustomobject]@{ Port = $p; Started = $f.LastWriteTime; Workspace = $f.Directory.Parent.Name }
    }
}

if ($ListInstances) { $instances | Format-Table -AutoSize; return }

if (-not $Port) {
    if (-not $instances) { throw "No open Power BI Desktop found (no listening msmdsrv.port.txt)." }
    if (@($instances).Count -gt 1) {
        $instances | Format-Table -AutoSize
        throw "Several Power BI Desktop files are open - pass -Port."
    }
    $Port = $instances.Port
}

if ($QueryFile) { $Query = [IO.File]::ReadAllText((Resolve-Path $QueryFile), [Text.Encoding]::UTF8) }
if (-not $Query) { throw "Pass -Query or -QueryFile." }

$cn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection "Data Source=localhost:$Port"
$cn.Open()
try {
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = $Query
    $r = $cmd.ExecuteReader()
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    # Only the first EVALUATE result is printed - one query per call
    (0..($r.FieldCount - 1) | ForEach-Object { $r.GetName($_) }) -join "`t"
    while ($r.Read()) {
        (0..($r.FieldCount - 1) | ForEach-Object { $r.GetValue($_) }) -join "`t"
    }
    $r.Close()
}
finally { $cn.Close() }
