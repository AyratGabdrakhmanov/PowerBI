# ReorderThemeColors.ps1 - reorder the theme palette (dataColors) and renumber every
# ThemeDataColor reference, so that every element colored "by palette number" keeps its color.
#
# Why (2026-10-16, Collector Assignment): similar colors stood next to each other in the palette
# (red/orange, blue/navy, purple/magenta) - charts with a legend got neighbouring series in
# almost the same color. The order of dataColors decides the series colors; changing it alone
# would also recolor every fixed element that references the palette by number.
#
# How a palette reference works in PBIR / theme JSON:
#   {"ThemeDataColor": {"ColorId": N, "Percent": P}}
#   ColorId 0 = background, 1 = foreground (text) - NOT palette entries, never renumbered;
#   ColorId 2..  = dataColors[N - 2]   (ColorId 2 = first palette color).
#   (Checked on Collector Assignment: ColorId 1 is used ~435x as text color and renders dark,
#    not as dataColors[1] orange.)
# The script moves the colors AND rewrites every ColorId >= 2 to the new position of the same
# color, so only the series order changes - fixed colors stay the same.
#
# Usage (PowerShell 7+):
#   # whole project (the custom theme from report.json + all report JSON: visuals, pages,
#   # bookmarks, the theme's own visualStyles):
#   .\ReorderThemeColors.ps1 -RootPath "C:\...\Collector Assignment" -Order 0,3,2,6,1,4,7,5
#   # a standalone theme file (a master copy) - its own references are renumbered too:
#   .\ReorderThemeColors.ps1 -ThemeFile "C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\Maket\ThemeWarm.json" -Order 0,3,2,6,1,4,7,5
#   # the same order by HEX (must be the palette's own colors, any case):
#   ... -Order '#C0392B','#099078','#F7BE0F','#6A4C93','#E85423','#0087B6','#B84A9C','#01238E'
#   -DryRun  : print the plan and the counts, write nothing.
#
# -Order lists the OLD position (0-based) or the HEX of each color in its NEW place. It may
# cover only the first K palette entries (a theme with generated shades keeps the rest as is).
# A backup goes to the nearest parent folder named "BackUp" (ClientA\BackUp for ClientA projects),
# otherwise to "<parent of RootPath>\BackUp". After writing, every reference is re-checked:
# old color of the old ColorId == new color of the new ColorId.
#
# Self-contained (no calls to neighbouring scripts - scripts here are often pasted into a console).
# SCRIPT_VERSION: 2026-10-16.1
param(
    [string]$RootPath,
    [string]$ThemeFile,
    [Parameter(Mandatory)][string[]]$Order,
    [switch]$DryRun
)

$ScriptVersion = "2026-10-16.1"
$ErrorActionPreference = 'Stop'
Write-Host "ReorderThemeColors.ps1 version $ScriptVersion"

if ([bool]$RootPath -eq [bool]$ThemeFile) { Write-Error "Pass exactly one of -RootPath (project folder with *.Report) or -ThemeFile."; exit 1 }

# --- target files -----------------------------------------------------------------------------
if ($RootPath) {
    $reports = @(Get-ChildItem -Path $RootPath -Directory -Filter "*.Report")
    if ($reports.Count -ne 1) { Write-Error "Expected exactly one *.Report folder under $RootPath (found $($reports.Count))."; exit 1 }
    $reportDir = $reports[0].FullName
    $rj = Get-Content (Join-Path $reportDir "definition\report.json") -Raw | ConvertFrom-Json
    $ct = $rj.themeCollection.customTheme
    if (-not $ct) { Write-Error "report.json has no customTheme - nothing to reorder."; exit 1 }
    $themePath = Join-Path $reportDir ("StaticResources\" + $ct.type + "\" + $ct.name)
    if (-not (Test-Path $themePath)) { Write-Error "Custom theme file not found: $themePath"; exit 1 }
    $files = @(Get-ChildItem -Path $reportDir -Recurse -File -Filter "*.json" | Where-Object { $_.FullName -notmatch '\\\.pbi\\' })
    $backupSource = $reportDir
} else {
    if (-not (Test-Path $ThemeFile)) { Write-Error "Theme file not found: $ThemeFile"; exit 1 }
    $themePath = (Resolve-Path $ThemeFile).Path
    $files = @(Get-Item $themePath)
    $backupSource = $themePath
}
Write-Host "Theme: $themePath"

# --- palette and the new order ----------------------------------------------------------------
$themeText = [System.IO.File]::ReadAllText($themePath)
$arr = [regex]::Match($themeText, '"dataColors"\s*:\s*\[(?<body>[^\]]*)\]')
if (-not $arr.Success) { Write-Error "No dataColors array in the theme."; exit 1 }
$hexMatches = [regex]::Matches($arr.Groups['body'].Value, '"(#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?)"')
$old = @($hexMatches | ForEach-Object { $_.Groups[1].Value })
$K = $Order.Count
if ($K -lt 2 -or $K -gt $old.Count) { Write-Error "-Order has $K entries; the palette has $($old.Count)."; exit 1 }

$perm = foreach ($o in $Order) {        # $perm[newPos] = oldPos
    $o = $o.Trim()
    if ($o -match '^#') {
        $i = [Array]::FindIndex([string[]]$old[0..($K - 1)], [Predicate[string]]{ param($c) $c -ieq $o })
        if ($i -lt 0) { Write-Error "Color $o is not among the first $K palette colors."; exit 1 }
        $i
    } elseif ($o -match '^\d+$' -and [int]$o -lt $K) { [int]$o }
    else { Write-Error "Bad -Order item '$o' (an old position 0..$($K - 1) or a palette HEX)."; exit 1 }
}
if (@($perm | Sort-Object -Unique).Count -ne $K) { Write-Error "-Order is not a permutation (repeats)."; exit 1 }

$new = [string[]]$old.Clone()
for ($p = 0; $p -lt $K; $p++) { $new[$p] = $old[$perm[$p]] }
$idMap = @{}                             # old ColorId -> new ColorId (palette part only)
for ($p = 0; $p -lt $K; $p++) { $idMap[$perm[$p] + 2] = $p + 2 }

Write-Host ""
Write-Host "Palette (position: old -> new):"
for ($p = 0; $p -lt $K; $p++) { Write-Host ("  {0}: {1} -> {2}" -f ($p + 1), $old[$p], $new[$p]) }
if ($old.Count -gt $K) { Write-Host "  (positions $($K + 1)..$($old.Count) unchanged)" }
Write-Host "ColorId remap (only where it changes):"
$idMap.Keys | Sort-Object | Where-Object { $idMap[$_] -ne $_ } | ForEach-Object { Write-Host ("  ColorId {0} -> {1}  ({2})" -f $_, $idMap[$_], $old[$_ - 2]) }

# --- plan: count references per file ----------------------------------------------------------
$rx = [regex]'("ColorId"\s*:\s*)(\d+)'
$plan = @()
$usage = @{}
foreach ($f in $files) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    $n = 0
    foreach ($m in $rx.Matches($t)) {
        $id = [int]$m.Groups[2].Value
        $usage[$id] = 1 + [int]$usage[$id]
        if ($idMap.ContainsKey($id) -and $idMap[$id] -ne $id) { $n++ }
    }
    $isTheme = ($f.FullName -eq $themePath)
    if ($n -gt 0 -or $isTheme) { $plan += [PSCustomObject]@{ File = $f.FullName; Changes = $n; IsTheme = $isTheme } }
}
Write-Host "ColorId usage before: " (($usage.Keys | Sort-Object | ForEach-Object { "$_=$($usage[$_])" }) -join ', ')
Write-Host ("References to renumber: {0} in {1} file(s)" -f (($plan | Measure-Object Changes -Sum).Sum), @($plan | Where-Object Changes -gt 0).Count)
$beyond = @($usage.Keys | Where-Object { $_ -ge $old.Count + 2 })
if ($beyond) { Write-Host "  WARN ColorId beyond the palette ($($beyond -join ', ')) - left as is." -ForegroundColor DarkYellow }

if ($DryRun) { Write-Host ""; Write-Host "-DryRun: nothing written."; exit 0 }

# --- backup -----------------------------------------------------------------------------------
$probe = Split-Path $backupSource -Parent
$backupRoot = $null
while ($probe) {
    $cand = Join-Path $probe "BackUp"
    if (Test-Path $cand -PathType Container) { $backupRoot = $cand; break }
    $probe = Split-Path $probe -Parent
}
if (-not $backupRoot) { $backupRoot = Join-Path (Split-Path (Split-Path $backupSource -Parent) -Parent) "BackUp" }
$dest = Join-Path $backupRoot ("ReorderThemeColors_" + (Get-Date -Format "yyyy-MM-dd_HHmmss"))
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item -Path $backupSource -Destination $dest -Recurse -Force
Write-Host ""
Write-Host "OK Backed up to $dest"

# --- write ------------------------------------------------------------------------------------
$utf8 = New-Object System.Text.UTF8Encoding($false)
$before = @{}                            # file -> list of old ColorIds in order (for the check)
foreach ($item in $plan) {
    $t = [System.IO.File]::ReadAllText($item.File)
    $before[$item.File] = @($rx.Matches($t) | ForEach-Object { [int]$_.Groups[2].Value })
    $t2 = $rx.Replace($t, { param($m) $id = [int]$m.Groups[2].Value; if ($idMap.ContainsKey($id)) { $m.Groups[1].Value + $idMap[$id] } else { $m.Value } })
    if ($item.IsTheme) {
        $a = [regex]::Match($t2, '"dataColors"\s*:\s*\[(?<body>[^\]]*)\]')
        $body = $a.Groups['body']
        $i = 0
        $newBody = [regex]::Replace($body.Value, '"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?"', { param($m) $r = '"' + $new[$script:i] + '"'; $script:i++; $r })
        $t2 = $t2.Substring(0, $body.Index) + $newBody + $t2.Substring($body.Index + $body.Length)
    }
    $null = $t2 | ConvertFrom-Json      # must still be valid JSON
    [System.IO.File]::WriteAllText($item.File, $t2, $utf8)
}

# --- check: every reference shows the same color as before ------------------------------------
$bad = 0
$check = [regex]::Match([System.IO.File]::ReadAllText($themePath), '"dataColors"\s*:\s*\[(?<body>[^\]]*)\]')
$now = @([regex]::Matches($check.Groups['body'].Value, '"(#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?)"') | ForEach-Object { $_.Groups[1].Value })
if (($now -join ',') -ne ($new -join ',')) { Write-Host "  FAIL palette on disk differs from the plan" -ForegroundColor Red; $bad++ }
foreach ($item in $plan) {
    $after = @($rx.Matches([System.IO.File]::ReadAllText($item.File)) | ForEach-Object { [int]$_.Groups[2].Value })
    for ($k = 0; $k -lt $after.Count; $k++) {
        $o = $before[$item.File][$k]; $n = $after[$k]
        if ($o -lt 2 -or $o -ge $old.Count + 2) { if ($o -ne $n) { $bad++ }; continue }
        if ($old[$o - 2] -ne $now[$n - 2]) { $bad++; Write-Host "  FAIL $($item.File): ColorId $o ($($old[$o - 2])) -> $n ($($now[$n - 2]))" -ForegroundColor Red }
    }
}
$done = ($plan | Measure-Object Changes -Sum).Sum
if ($bad) { Write-Host "Check FAILED ($bad) - restore from $dest" -ForegroundColor Red; exit 1 }
Write-Host "OK palette reordered; $done reference(s) renumbered; every reference keeps its color."
if ($RootPath) { Write-Host "Desktop open on this report: powerbi-desktop reload (theme + visuals are report files)." }
