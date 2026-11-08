# Clear all data from a .pbix so the file gets small (publish / share / OneDrive); the next refresh loads it again.
# Model, measures, relationships, report and captions stay; calculated tables / columns come back with the refresh.
# Not a data refresh: TOM RequestRefresh(ClearValues) on the model, then Ctrl+S (SaveDesktop.ps1, confirmed by the
# file timestamp). Copies of this file sit next to the .pbix files (ClientB, ClientC); without -Pbix it takes the only .pbix
# in its own folder. Uses the window if the file is already open (save your work first), otherwise opens it and closes it after.
#   pwsh -File ClearPbixData.ps1 [-Pbix "<file.pbix>"]
# ⚠️ After this the report is EMPTY until a refresh succeeds.
# Change log:
#   2026-10-31 - created.
param([string]$Pbix)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Scripts = 'C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Scripts'
if (-not $Pbix) {
    $found = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.pbix -File)
    if ($found.Count -ne 1) { throw "Pass -Pbix: $($found.Count) .pbix files in $PSScriptRoot ($($found.Name -join ', '))" }
    $Pbix = $found[0].FullName
}
$Pbix = (Resolve-Path -LiteralPath $Pbix).Path
$name = [IO.Path]::GetFileNameWithoutExtension($Pbix)
$before = (Get-Item -LiteralPath $Pbix).Length

function Get-DesktopPid { @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "$name -*" -or $_.MainWindowTitle -eq $name }) }
$p = @(Get-DesktopPid)
$opened = $false
if ($p.Count -gt 1) { throw "$name is open in $($p.Count) windows - close the extra ones" }
if ($p.Count -eq 0) {
    Start-Process -FilePath $Pbix; $opened = $true
    $t0 = Get-Date
    do { Start-Sleep 5; $p = @(Get-DesktopPid) } until ($p.Count -eq 1 -or (Get-Date) -gt $t0.AddMinutes(5))
    if ($p.Count -ne 1) { throw "Desktop window for $name not found in 5 min" }
}
$desktopPid = $p[0].Id

# Analysis Services port of this window: msmdsrv child process -> its workspace folder -> msmdsrv.port.txt
$t0 = Get-Date; $port = $null
do {
    $as = Get-CimInstance Win32_Process -Filter "Name = 'msmdsrv.exe'" | Where-Object ParentProcessId -eq $desktopPid | Select-Object -First 1
    if ($as -and $as.CommandLine -match '-s\s+"([^"]+)"') {
        $pf = Join-Path $Matches[1] 'msmdsrv.port.txt'
        if (Test-Path -LiteralPath $pf) { $port = [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($pf)).Trim() }
    }
    if (-not $port) { Start-Sleep 3 }
} until ($port -or (Get-Date) -gt $t0.AddMinutes(5))
if (-not $port) { throw "No Analysis Services port for pid $desktopPid" }

[void][Reflection.Assembly]::LoadFrom('C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll')
$srv = New-Object Microsoft.AnalysisServices.Tabular.Server
$t0 = Get-Date
do {   # wait until Desktop has loaded the model
    try { $srv.Connect("Data Source=localhost:$port"); $ok = $srv.Databases.Count -gt 0 -and $srv.Databases[0].Model.Tables.Count -gt 0 } catch { $ok = $false }
    if (-not $ok) { if ($srv.Connected) { $srv.Disconnect() }; Start-Sleep 5 }
} until ($ok -or (Get-Date) -gt $t0.AddMinutes(5))
if (-not $ok) { throw "Model of $name did not load in 5 min" }
$m = $srv.Databases[0].Model
"$name : $($m.Tables.Count) tables, pid $desktopPid, port $port - clearing data"
$m.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::ClearValues)
$m.SaveChanges() | Out-Null
$srv.Disconnect()

& "$Scripts\SaveDesktop.ps1" -DesktopPid $desktopPid -SemanticModel $Pbix
if ($opened) {
    [void](Get-Process -Id $desktopPid).CloseMainWindow()
    try { Wait-Process -Id $desktopPid -Timeout 60 } catch { "window still open (pid $desktopPid) - close it by hand" }
}
$after = (Get-Item -LiteralPath $Pbix).Length
'{0}: {1:N1} MB -> {2:N1} MB. Refresh to load the data again.' -f $name, ($before / 1MB), ($after / 1MB)
