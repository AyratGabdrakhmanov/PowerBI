# "save pbix": save a PBIP as a .pbix next to it WITHOUT data, ready for the user's refresh.
# Steps: guards -> backup of the existing .pbix to the nearest BackUp folder (SavePbix_<time>\) -> open the PBIP in its
# own Desktop window -> TOM RequestRefresh(ClearValues) (not a source refresh) -> F12 (Save As) after the foreground
# check of SaveDesktop.ps1 -> type = .pbix, file name = full path, Enter, overwrite = Yes -> wait for the new .pbix ->
# close the window. The PBIP files are never saved (checked by timestamps at the end).
#   pwsh -File SavePbipAsPbix.ps1 -Pbip "<X.pbip>" [-Pbix "<target.pbix>"]
# After it: user refreshes the .pbix, then ConvertPbixToPbip.ps1 brings model + data back into the PBIP.
# Change log:
#   2026-11-01 - created (ClientC Sales NEW; F12 = Save As confirmed in Desktop 2.158; open + clear + F12 tested,
#                the Enter / overwrite step not yet - the user finished the test saves by hand).
#   2026-11-01 - Save As may propose .pbip (last used type): ask the user to pick .pbix in the dialog and wait, not throw.
#   2026-11-02 - type switch fixed: list opened with Alt+Down and closed with Enter on the .pbix entry (arrows on the
#                closed list never changed the name); Enter only while the list is open; Save only when the name is .pbix.
#   -ResumePid <pid>: continue in a window this script already opened and cleared (after a foreground failure).
param([Parameter(Mandatory)][string]$Pbip, [string]$Pbix, [int]$ResumePid)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Pbip = (Resolve-Path -LiteralPath $Pbip).Path
$dir = Split-Path $Pbip
$name = [IO.Path]::GetFileNameWithoutExtension($Pbip)
if (-not $Pbix) { $Pbix = Join-Path $dir "$name.pbix" }
$started = Get-Date

if ($ResumePid) { $desktopPid = $ResumePid }
# guards: no Desktop window with this name (PBIP and .pbix share the title)
elseif (@(Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "$name -*" -or $_.MainWindowTitle -eq $name }).Count) {
    throw "$name is open in Desktop - save and close it first" }

if (-not $ResumePid) {
# backup of the existing .pbix
if (Test-Path -LiteralPath $Pbix) {
    $b = $dir; while ($b -and -not (Test-Path -LiteralPath (Join-Path $b 'BackUp'))) { $b = Split-Path $b }
    if (-not $b) { $b = $dir; New-Item -ItemType Directory (Join-Path $b 'BackUp') | Out-Null }
    $bk = Join-Path $b ("BackUp\SavePbix_{0:yyyy-MM-dd_HHmmss}" -f $started)
    New-Item -ItemType Directory $bk | Out-Null
    Copy-Item -LiteralPath $Pbix -Destination $bk
    "backup: $bk"
}

# open the PBIP
Start-Process -FilePath $Pbip
$t0 = Get-Date
do { Start-Sleep 5; $p = @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "$name -*" }) } until ($p.Count -eq 1 -or (Get-Date) -gt $t0.AddMinutes(5))
if ($p.Count -ne 1) { throw "Desktop window for $name not found in 5 min (sign-in window? see AI_Tools_MCP_CLI.md)" }
$desktopPid = $p[0].Id

# clear the data (same as ClearPbixData.ps1)
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
do {
    try { $srv.Connect("Data Source=localhost:$port"); $ok = $srv.Databases.Count -gt 0 -and $srv.Databases[0].Model.Tables.Count -gt 0 } catch { $ok = $false }
    if (-not $ok) { if ($srv.Connected) { $srv.Disconnect() }; Start-Sleep 5 }
} until ($ok -or (Get-Date) -gt $t0.AddMinutes(5))
if (-not $ok) { throw "Model of $name did not load in 5 min" }
$m = $srv.Databases[0].Model
"$name : $($m.Tables.Count) tables, pid $desktopPid - clearing data"
$m.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::ClearValues)
$m.SaveChanges() | Out-Null
$srv.Disconnect()
Start-Sleep 5
}

# F12 = Save As, only when the Desktop window is in the foreground
if (-not ('Rmt.Win' -as [type])) {
    Add-Type -Namespace Rmt -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
'@
}
# is a drop-down list (ComboLBox) of this process open?
function Test-ListOpen([int]$procId) {
    $w = [IntPtr]::Zero
    while (($w = [Rmt.Win]::FindWindowEx([IntPtr]::Zero, $w, 'ComboLBox', $null)) -ne [IntPtr]::Zero) {
        [uint32]$wp = 0; [void][Rmt.Win]::GetWindowThreadProcessId($w, [ref]$wp)
        if ($wp -eq $procId -and [Rmt.Win]::IsWindowVisible($w)) { return $true }
    }
    $false
}
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$A = [System.Windows.Automation.AutomationElement]
$TS = [System.Windows.Automation.TreeScope]
function Find-ById($el, $id) { $el.FindFirst($TS::Descendants, (New-Object System.Windows.Automation.PropertyCondition($A::AutomationIdProperty, $id))) }
$h = (Get-Process -Id $desktopPid).MainWindowHandle; $fgPid = 0
foreach ($try in 1..60) {   # ~2 min: an active Remote Desktop window keeps the foreground until the user leaves it
    if ($try -eq 6) { 'waiting for the foreground - leave Remote Desktop / click the Power BI window' }
    if ($try -gt 5) { Start-Sleep 1.5 }
    [void][Rmt.Win]::ShowWindow($h, 9)
    [Rmt.Win]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [Rmt.Win]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [void][Rmt.Win]::SetForegroundWindow($h); Start-Sleep -Milliseconds 500
    [uint32]$fg = 0; [void][Rmt.Win]::GetWindowThreadProcessId([Rmt.Win]::GetForegroundWindow(), [ref]$fg); $fgPid = $fg
    if ($fgPid -eq $desktopPid) { break }
}
if ($fgPid -ne $desktopPid) { throw "Foreground is pid $fgPid, not $desktopPid - no keys sent; Save As by hand" }
$wsh = New-Object -ComObject WScript.Shell
$wsh.SendKeys('{F12}')
$t0 = Get-Date
do { Start-Sleep 1; $dlg = $A::FromHandle($h).FindFirst($TS::Descendants, (New-Object System.Windows.Automation.PropertyCondition($A::ClassNameProperty, '#32770'))) } until ($dlg -or (Get-Date) -gt $t0.AddSeconds(30))
if (-not $dlg) { throw 'Save As dialog did not open' }

# Save As opens in the PBIP folder with the last used type ("<name>.pbix" or "<name>.pbip"). The file name is never
# typed into (user 2026-11-01): when it is not .pbix, "Save as type" is changed - Alt+T, Alt+Down opens the list, Home
# (entry 0 = "Power BI file (*.pbix)"), Enter closes the list on it. The dialog swaps the extension only when the list
# closes - arrows on a closed list or CB_SETCURSEL do not (2026-11-02). Enter is sent only while the list is open
# (otherwise Enter = Save with the wrong type), and Save only when the name box (UIA id 1001) shows "<name>.pbix".
# Then Alt+N, Enter, Yes on "Confirm Save As". Stopping this script closes the Desktop window and the dialog.
$nameBox = Find-ById $dlg '1001'
$target = [IO.Path]::GetFileName($Pbix)
$proposed = if ($nameBox) { $nameBox.Current.Name } else { '' }
if ((Split-Path $Pbix) -ne $dir -or $proposed -notin @($target, "$name.pbip")) {
    throw "Save As proposes '$proposed' - not $name.pbix / .pbip in the PBIP folder; finish by hand (pid $desktopPid)" }
if ($proposed -ne $target) {
    $wsh.SendKeys('%t'); Start-Sleep -Milliseconds 500
    $wsh.SendKeys('%{DOWN}'); Start-Sleep -Milliseconds 700
    if (-not (Test-ListOpen $desktopPid)) { throw "Save as type list did not open - no Enter sent; finish by hand (pid $desktopPid)" }
    $wsh.SendKeys('{HOME}'); Start-Sleep -Milliseconds 400
    $wsh.SendKeys('{ENTER}'); Start-Sleep -Milliseconds 900
    if (Test-ListOpen $desktopPid) { throw "Save as type list still open - finish by hand (pid $desktopPid)" }
    $wsh.SendKeys('%n'); Start-Sleep -Milliseconds 500
}
$nameNow = (Find-ById $dlg '1001').Current.Name
if ($nameNow -ne $target) { throw "Name box shows '$nameNow', not $target - nothing saved; finish by hand (pid $desktopPid)" }
"Save As: proposed $proposed -> $nameNow"
$since = Get-Date
$wsh.SendKeys('{ENTER}'); Start-Sleep 2
$confirm = $A::FromHandle($h).FindFirst($TS::Descendants, (New-Object System.Windows.Automation.PropertyCondition($A::NameProperty, 'Confirm Save As')))
if ($confirm) { $wsh.SendKeys('%y') }

$t0 = Get-Date
do { Start-Sleep 3; $done = (Test-Path -LiteralPath $Pbix) -and (Get-Item -LiteralPath $Pbix).LastWriteTime -gt $since } until ($done -or (Get-Date) -gt $t0.AddMinutes(5))
if (-not $done) { throw ".pbix not written in 5 min - check the Desktop window (pid $desktopPid)" }
Start-Sleep 5
[void](Get-Process -Id $desktopPid).CloseMainWindow()
try { Wait-Process -Id $desktopPid -Timeout 60 } catch { "window still open (pid $desktopPid) - close it by hand" }

$touched = @(Get-ChildItem -LiteralPath (Join-Path $dir "$name.SemanticModel"), (Join-Path $dir "$name.Report") -Recurse -File | Where-Object { $_.LastWriteTime -gt $started -and $_.Name -notmatch '^(localSettings|editorSettings)\.json$' })
'{0}: {1:N1} MB, saved {2:HH:mm:ss}. PBIP files changed: {3}' -f $Pbix, ((Get-Item -LiteralPath $Pbix).Length / 1MB), (Get-Item -LiteralPath $Pbix).LastWriteTime, $touched.Count
if ($touched) { $touched.FullName }
