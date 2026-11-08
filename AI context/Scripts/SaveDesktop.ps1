# Ctrl+S to ONE Power BI Desktop window: bring it forward (ShowWindow + Alt + SetForegroundWindow), check that the
# foreground window belongs to -DesktopPid, only then SendKeys ^s; wait until a file of the semantic model is newer
# than the keypress (120 s). Never clicks UI buttons (user rule 2026-10-23). After a bridge apply Desktop flags
# "unsaved" by itself - confirm saves by these timestamps, not by hasUnsavedChanges. Same logic as Save-Desktop in
# ReplaceModelTable.ps1 / CleanUnused.ps1.
#   pwsh -File SaveDesktop.ps1 -DesktopPid <pid> -SemanticModel "<...\X.SemanticModel>" [-Expect "definition\tables\X.tmdl|regex;definition\tables\Y.tmdl|regex2"]
# -Expect (2026-10-24): content check per file (path relative to -SemanticModel, then | and a regex that must
# match; several checks separated by ";" - pwsh -File passes "a","b" as one string). A Ctrl+S sent right after a TOM edit can write the OLD value with a NEW timestamp (ClientB 2026-10-24, twice) -
# when a check fails the script saves once more, then throws.
# SCRIPT_VERSION: 2026-10-24.1
param([Parameter(Mandatory)][int]$DesktopPid, [Parameter(Mandatory)][string]$SemanticModel, [string]$Expect = '')
$ErrorActionPreference = 'Stop'
$Checks = @($Expect -split ';' | Where-Object { $_.Trim() })
if (-not ('Rmt.Win' -as [type])) {
    Add-Type -Namespace Rmt -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
'@
}
function Send-Save {
    $h = (Get-Process -Id $DesktopPid).MainWindowHandle; $fgPid = 0
    foreach ($try in 1..5) {
        [void][Rmt.Win]::ShowWindow($h, 9)                                   # restore if minimized
        [Rmt.Win]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [Rmt.Win]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)   # Alt: lets SetForegroundWindow work
        [void][Rmt.Win]::SetForegroundWindow($h); Start-Sleep -Milliseconds 500
        [uint32]$fg = 0; [void][Rmt.Win]::GetWindowThreadProcessId([Rmt.Win]::GetForegroundWindow(), [ref]$fg); $fgPid = $fg
        if ($fgPid -eq $DesktopPid) { break }
    }
    if ($fgPid -ne $DesktopPid) { throw "Foreground is pid $fgPid, not $DesktopPid - no keys sent; save by hand" }
    $since = Get-Date
    (New-Object -ComObject WScript.Shell).SendKeys('^s')
    $newer = { @(Get-ChildItem $SemanticModel -Recurse -File | Where-Object LastWriteTime -gt $since).Count -gt 0 }
    do { Start-Sleep 3 } until ((& $newer) -or (Get-Date) -gt $since.AddSeconds(120))
    if (-not (& $newer)) { throw "Ctrl+S did not reach the files in 120 s - save by hand" }
    Start-Sleep 5   # let Desktop finish writing every file
}
function Get-Stale {
    @(foreach ($e in $Checks) { $rel, $rx = $e -split '\|', 2
        $f = Join-Path $SemanticModel $rel
        if (-not (Test-Path -LiteralPath $f) -or -not ([IO.File]::ReadAllText($f) -match $rx)) { $e } })
}
Send-Save
$stale = Get-Stale
if ($stale) { "content check failed ($($stale -join '; ')) - saving again"; Send-Save; $stale = Get-Stale }
if ($stale) { throw "saved, but the files still lack: $($stale -join '; ')" }
"OK saved $(Get-Date -Format HH:mm:ss)$(if ($Checks) { " - content checks: $($Checks.Count)" })"
