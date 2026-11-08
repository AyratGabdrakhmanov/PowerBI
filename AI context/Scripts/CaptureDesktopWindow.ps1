# Screenshot of a whole Power BI Desktop window (ribbon, panes, banners, dialogs) - unlike
# `powerbi-desktop screenshot`, which captures only the report canvas. Also lists the process's top-level
# windows, so a modal dialog (save prompt, error box) shows up by name. Read-only: nothing is clicked.
# PrintWindow with PW_RENDERFULLCONTENT - works when the window is behind others; not when it is minimized.
#
# Usage:
#   pwsh -File CaptureDesktopWindow.ps1 -ProcessId 35084 [-Out C:\...\shot.png]
#   pwsh -File CaptureDesktopWindow.ps1 -Title "Model - Power BI Desktop"      (exact window title)
# Default -Out: %TEMP%\Desktop_<pid>_<timestamp>.png. Read the PNG (or OcrImage.ps1) to see the state.
#
# SCRIPT_VERSION: 2026-10-20.1
param([int]$ProcessId, [string]$Title, [string]$Out)
$ErrorActionPreference = 'Stop'
$p = if ($ProcessId) { Get-Process -Id $ProcessId } else { Get-Process PBIDesktop | Where-Object MainWindowTitle -eq $Title | Select-Object -First 1 }
if (-not $p) { Write-Host 'Desktop window not found.'; Get-Process PBIDesktop | ForEach-Object { "  {0} | {1}" -f $_.Id, $_.MainWindowTitle }; exit 1 }
if (-not $Out) { $Out = Join-Path ([IO.Path]::GetTempPath()) ("Desktop_{0}_{1:yyyyMMdd_HHmmss}.png" -f $p.Id, (Get-Date)) }

Add-Type -AssemblyName System.Drawing, UIAutomationClient, UIAutomationTypes
Add-Type @"
using System; using System.Runtime.InteropServices;
public class CdwNative {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  public struct RECT { public int L, T, R, B; }
}
"@
$h = $p.MainWindowHandle
if ([CdwNative]::IsIconic($h)) { Write-Host 'Window is minimized - restore it first.'; exit 1 }
$r = New-Object CdwNative+RECT; [void][CdwNative]::GetWindowRect($h, [ref]$r)
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
[void][CdwNative]::PrintWindow($h, $hdc, 2); $g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Host ("Saved {0} ({1}x{2}) - pid {3}: {4}" -f $Out, ($r.R - $r.L), ($r.B - $r.T), $p.Id, $p.MainWindowTitle)

$A = [System.Windows.Automation.AutomationElement]
$cond = New-Object System.Windows.Automation.PropertyCondition($A::ProcessIdProperty, $p.Id)
$wins = $A::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
Write-Host "Top-level windows of the process: $($wins.Count)"
foreach ($w in $wins) {
    Write-Host ("  {0} | {1}" -f $w.Current.Name, $w.Current.ControlType.ProgrammaticName)
    $dlg = $w.FindAll([System.Windows.Automation.TreeScope]::Children,
        (New-Object System.Windows.Automation.PropertyCondition($A::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)))
    foreach ($d in $dlg) { Write-Host ("    dialog: {0}" -f $d.Current.Name) }
}
