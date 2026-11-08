# Launcher next to a .pbix (ClientB, ClientC). The user only refreshes data in the .pbix, never edits its report, so:
#   - a PBIP with the same name next to the .pbix -> UPDATE it from the .pbix: model definition + data cache only
#     (definition\ and .pbi\cache.abf). Report, diagramLayout.json, .platform, .pbism, .pbi settings stay.
#   - no PBIP yet -> full conversion into this folder.
# No Desktop window: the master PbixToPbip.ps1 (ClientA\_Documentation\Scripts, with PbixToPbip_msmdsrv.ini) converts into a
# temp folder (hidden engine); the .pbix is only read.
# Guards: stops if Desktop has the PBIP open, or if any PBIP model file is newer than the .pbix (work done in the PBIP
# after the .pbix was saved would be lost - ClientB 2026-10-19); -Force skips the age check. The PBIP is backed up to
# <project>\BackUp\PbixToPbip_<yyyy-MM-dd_HHmmss> first. A report that differs from the PBIP is only listed, never written.
#   pwsh -File ConvertPbixToPbip.ps1 [-Pbix "<file.pbix>"] [-Force]
# Change log:
#   2026-10-31 - (2) default = update the PBIP model + data only (user: report is never changed in the .pbix).
#   2026-10-31 - (1) created (output into a new FromPbix_<time> folder).
param([string]$Pbix, [switch]$Force)
$ErrorActionPreference = 'Stop'
$Master = 'C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Scripts\PbixToPbip.ps1'
if (-not $Pbix) {
    $found = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.pbix -File)
    if ($found.Count -ne 1) { throw "Pass -Pbix: $($found.Count) .pbix files in $PSScriptRoot ($($found.Name -join ', '))" }
    $Pbix = $found[0].FullName
}
$Pbix = (Resolve-Path -LiteralPath $Pbix).Path
$dir = Split-Path $Pbix -Parent
$name = [IO.Path]::GetFileNameWithoutExtension($Pbix)
$ts = Get-Date -Format 'yyyy-MM-dd_HHmmss'

if (-not (Test-Path -LiteralPath (Join-Path $dir "$name.pbip"))) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Master -Pbix $Pbix -OutDir $dir
    if ($LASTEXITCODE) { throw "PbixToPbip.ps1 failed (exit $LASTEXITCODE)" }
    return
}

$sm = Join-Path $dir "$name.SemanticModel"
$rp = Join-Path $dir "$name.Report"
# Guard 1: the PBIP is not open in Desktop (Desktop would save its own model back over the new files)
$open = @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "$name -*" -or $_.MainWindowTitle -eq $name })
if ($open.Count) { throw "Close '$name' in Power BI Desktop first (pid $($open.Id -join ', '))." }
# Guard 2: nothing in the PBIP model is newer than the .pbix
$pbixTime = (Get-Item -LiteralPath $Pbix).LastWriteTime
$newer = @(Get-ChildItem -LiteralPath (Join-Path $sm 'definition') -Recurse -File | Where-Object LastWriteTime -gt $pbixTime)
if ($newer.Count -and -not $Force) {
    $newer | Select-Object -First 10 | ForEach-Object { '  newer in PBIP: {0}  {1:dd.MM HH:mm}' -f $_.FullName.Substring($sm.Length + 1), $_.LastWriteTime }
    throw "$($newer.Count) PBIP model files are newer than the .pbix ($('{0:dd.MM HH:mm}' -f $pbixTime)) - their changes would be lost. Save the .pbix again, or use -Force."
}

# Convert into a temp folder
$tmp = Join-Path $env:TEMP "PbixToPbip_$ts"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Master -Pbix $Pbix -OutDir $tmp
if ($LASTEXITCODE) { throw "PbixToPbip.ps1 failed (exit $LASTEXITCODE)" }
try {
    $newSm = Join-Path $tmp "$name.SemanticModel"
    # Report: compare by content (JSON parsed), list differences, never write
    $newRp = Join-Path $tmp "$name.Report\definition"
    $diff = @(foreach ($f in Get-ChildItem -LiteralPath (Join-Path $rp 'definition') -Recurse -File) {
        $rel = $f.FullName.Substring((Join-Path $rp 'definition').Length + 1)
        $g = Join-Path $newRp $rel
        if (-not (Test-Path -LiteralPath $g)) { "only in PBIP: $rel"; continue }
        $a = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8; $b = Get-Content -LiteralPath $g -Raw -Encoding UTF8
        if ($f.Extension -eq '.json') {
            try { $a = $a | ConvertFrom-Json | ConvertTo-Json -Depth 100 -Compress; $b = $b | ConvertFrom-Json | ConvertTo-Json -Depth 100 -Compress } catch { }
        }
        if ($a -ne $b -and $rel -ne 'pages\pages.json') { "differs: $rel" }   # pages.json: only the start page
    })
    if ($diff.Count) { "WARNING: the .pbix report differs from the PBIP in $($diff.Count) files - the PBIP report is kept:"; $diff | Select-Object -First 15 | ForEach-Object { "  $_" } }
    else { 'Report: same as the PBIP (kept).' }

    # Model: list changed TMDL files
    $old = Join-Path $sm 'definition'; $new = Join-Path $newSm 'definition'
    $changed = @(foreach ($f in Get-ChildItem -LiteralPath $new -Recurse -File) {
        $rel = $f.FullName.Substring($new.Length + 1); $o = Join-Path $old $rel
        if (-not (Test-Path -LiteralPath $o)) { "added: $rel" }
        elseif ((Get-Content -LiteralPath $o -Raw) -ne (Get-Content -LiteralPath $f.FullName -Raw)) { "changed: $rel" }
    }) + @(foreach ($f in Get-ChildItem -LiteralPath $old -Recurse -File) {
        $rel = $f.FullName.Substring($old.Length + 1); if (-not (Test-Path -LiteralPath (Join-Path $new $rel))) { "removed: $rel" } })
    "Model: $($changed.Count) files differ"; $changed | ForEach-Object { "  $_" }

    # Backup, then replace definition\ and the data cache
    $root = $dir; while ($root -and -not (Test-Path -LiteralPath (Join-Path $root 'BackUp'))) { $root = Split-Path $root -Parent }
    $bk = Join-Path $(if ($root) { Join-Path $root 'BackUp' } else { Join-Path $dir 'BackUp' }) "PbixToPbip_$ts"
    [void](New-Item -ItemType Directory -Force -Path $bk)
    Copy-Item -LiteralPath $sm, $rp, (Join-Path $dir "$name.pbip") -Destination $bk -Recurse
    Remove-Item -LiteralPath $old -Recurse -Force
    Copy-Item -LiteralPath $new -Destination $sm -Recurse
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $sm '.pbi'))
    Copy-Item -LiteralPath (Join-Path $newSm '.pbi\cache.abf') -Destination (Join-Path $sm '.pbi\cache.abf') -Force
    "Done: PBIP model + data updated from the .pbix. Backup: $bk"
}
finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
