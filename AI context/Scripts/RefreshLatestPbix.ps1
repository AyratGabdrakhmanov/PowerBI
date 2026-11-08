# Open the newest .pbix in a folder, refresh it in Power BI Desktop (Home > Refresh via UI Automation), save, close.
# Steps: newest *.pbix by LastWriteTime (not recursive) -> guard: not open in Desktop -> open in its own window ->
# wait for the enabled Home > Refresh button -> Invoke -> wait for the refresh dialog to close (error state =
# dialog with a "Close" button -> stop, nothing saved) -> Ctrl+S after the foreground check -> wait for a newer
# LastWriteTime -> close the window.
# Uses only Windows UI Automation (no DAX Studio / TOM), so it runs on a client RDP machine as is.
#   pwsh -File RefreshLatestPbix.ps1 [-Folder "<dir>" (default O:\BI_Install\PBIX\Work In Progress)] [-TimeoutMin 60]
# Change log:
#   2026-11-05 - default -Folder = O:\BI_Install\PBIX\Work In Progress.
#   2026-11-05 - created (not yet tested in Desktop).
param([string]$Folder = 'O:\BI_Install\PBIX\Work In Progress', [int]$TimeoutMin = 60)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$file = Get-ChildItem -LiteralPath $Folder -Filter *.pbix -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $file) { throw "No .pbix in $Folder" }
$pbix = $file.FullName
$name = $file.BaseName
"newest: $pbix ($($file.LastWriteTime))"
if (@(Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "$name -*" -or $_.MainWindowTitle -eq $name }).Count) {
    throw "$name is open in Desktop - save and close it first" }

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$A = [System.Windows.Automation.AutomationElement]
$TS = [System.Windows.Automation.TreeScope]
$CT = [System.Windows.Automation.ControlType]
function Cond($prop, $val) { New-Object System.Windows.Automation.PropertyCondition($prop, $val) }
function Find-Button($el, $btnName) {
    $c = New-Object System.Windows.Automation.AndCondition((Cond $A::NameProperty $btnName), (Cond $A::ControlTypeProperty $CT::Button))
    $el.FindFirst($TS::Descendants, $c)
}
if (-not ('Rfr.Win' -as [type])) {
    Add-Type -Namespace Rfr -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
'@
}

# open
Start-Process -FilePath $pbix
$t0 = Get-Date
do { Start-Sleep 5; $p = @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "$name -*" }) } until ($p.Count -eq 1 -or (Get-Date) -gt $t0.AddMinutes(5))
if ($p.Count -ne 1) { throw "Desktop window for $name not found in 5 min (sign-in window?)" }
$desktopPid = $p[0].Id
$h = $p[0].MainWindowHandle
$win = $A::FromHandle($h)

# Home > Refresh, once the model is loaded (button enabled)
$t0 = Get-Date
do { Start-Sleep 3; $btn = Find-Button $win 'Refresh' } until (($btn -and $btn.Current.IsEnabled) -or (Get-Date) -gt $t0.AddMinutes(5))
if (-not ($btn -and $btn.Current.IsEnabled)) { throw "Enabled Refresh button not found in 5 min (Home tab not active?) - pid $desktopPid" }
$started = Get-Date
"$name : pid $desktopPid - refresh started $($started.ToString('HH:mm:ss'))"
$btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()

# refresh dialog: appears, shows progress (Cancel), closes on success; on error it stays with a Close button
$seen = $false
do {
    Start-Sleep 3
    $dlg = $win.FindFirst($TS::Children, (New-Object System.Windows.Automation.AndCondition((Cond $A::NameProperty 'Refresh'), (Cond $A::ControlTypeProperty $CT::Window))))
    if ($dlg) {
        $seen = $true
        if (Find-Button $dlg 'Close') { throw "Refresh failed - errors in the Refresh dialog, nothing saved (pid $desktopPid)" }
    }
    $timeout = (Get-Date) -gt $started.AddMinutes($TimeoutMin)
} until ((-not $dlg -and ($seen -or (Get-Date) -gt $started.AddSeconds(30))) -or $timeout)
if ($timeout) { throw "Refresh still running after $TimeoutMin min - nothing saved (pid $desktopPid)" }
if (-not $seen) { 'note: Refresh dialog not seen (very fast refresh or click ignored) - check the data' }
'refresh done in {0:mm\:ss}' -f ((Get-Date) - $started)

# Ctrl+S only when the Desktop window is in the foreground
$fgPid = 0
foreach ($try in 1..60) {   # ~2 min: an active Remote Desktop window keeps the foreground until the user leaves it
    if ($try -eq 6) { 'waiting for the foreground - click the Power BI window' }
    if ($try -gt 5) { Start-Sleep 1.5 }
    [void][Rfr.Win]::ShowWindow($h, 9)
    [Rfr.Win]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [Rfr.Win]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [void][Rfr.Win]::SetForegroundWindow($h); Start-Sleep -Milliseconds 500
    [uint32]$fg = 0; [void][Rfr.Win]::GetWindowThreadProcessId([Rfr.Win]::GetForegroundWindow(), [ref]$fg); $fgPid = $fg
    if ($fgPid -eq $desktopPid) { break }
}
if ($fgPid -ne $desktopPid) { throw "Foreground is pid $fgPid, not $desktopPid - not saved; press Ctrl+S by hand" }
$since = Get-Date
(New-Object -ComObject WScript.Shell).SendKeys('^s')
$t0 = Get-Date
do { Start-Sleep 3; $done = (Get-Item -LiteralPath $pbix).LastWriteTime -gt $since } until ($done -or (Get-Date) -gt $t0.AddMinutes(10))
if (-not $done) { throw ".pbix not saved in 10 min - check the Desktop window (pid $desktopPid)" }
Start-Sleep 5

# close
[void](Get-Process -Id $desktopPid).CloseMainWindow()
try { Wait-Process -Id $desktopPid -Timeout 60 } catch { "window still open (pid $desktopPid) - close it by hand" }
$f = Get-Item -LiteralPath $pbix
'{0}: {1:N1} MB, saved {2:HH:mm:ss}' -f $pbix, ($f.Length / 1MB), $f.LastWriteTime
