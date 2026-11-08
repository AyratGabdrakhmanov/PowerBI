# Offline check that a PBIP semantic model (TMDL folder) loads - the same TOM TMDL loader the MS Power BI
# Modeling MCP (ConnectFolder) and Tabular Editor use. Prints tables / measures / relationships, or the error.
# Works on a scratch copy: zero-width hierarchy level names (Calendar: level U+200B x N), which this loader
# rejects as duplicates although Desktop accepts them, are replaced with quoted NBSP x N in the copy only.
# The model files are never changed.
#
# Usage:
#   pwsh -File ValidateTmdl.ps1 -Path "<X.SemanticModel>"          (or its "definition" folder)
#   pwsh -File ValidateTmdl.ps1 -Path "<X.SemanticModel>" -TomDll "<...\Microsoft.AnalysisServices.Tabular.dll>"
# Exit code: 0 = loads, 1 = error.
#
# SCRIPT_VERSION: 2026-10-20.1
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$TomDll = "C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll"
)
$ErrorActionPreference = 'Stop'
$def = if (Test-Path (Join-Path $Path 'definition')) { Join-Path $Path 'definition' } else { $Path }
if (-not (Test-Path (Join-Path $def 'model.tmdl'))) { Write-Host "No model.tmdl in $def"; exit 1 }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ValidateTmdl_" + [guid]::NewGuid().ToString('N'))
Copy-Item $def $tmp -Recurse
try {
    $zw = [string][char]0x200B; $nbsp = [string][char]0xA0
    $patched = 0
    foreach ($f in Get-ChildItem (Join-Path $tmp 'tables') -Filter *.tmdl) {
        $t = [IO.File]::ReadAllText($f.FullName)
        $n = [regex]::Replace($t, "(?m)^(\t\tlevel )($zw+)(\r?)$", {
            param($m) $m.Groups[1].Value + "'" + ($nbsp * $m.Groups[2].Value.Length) + "'" + $m.Groups[3].Value })
        if ($n -ne $t) { [IO.File]::WriteAllText($f.FullName, $n, (New-Object Text.UTF8Encoding $false)); $patched++ }
    }
    if ($patched) { Write-Host "Zero-width level names patched in the scratch copy: $patched table(s)" }

    [void][Reflection.Assembly]::LoadFrom($TomDll)
    $db = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeDatabaseFromFolder($tmp)
    $m = $db.Model
    $measures = ($m.Tables | ForEach-Object { $_.Measures.Count } | Measure-Object -Sum).Sum
    $calc = @($m.Tables | Where-Object { $_.Partitions.Count -and $_.Partitions[0].SourceType -eq 'Calculated' }).Count
    Write-Host ("OK  tables={0} (calculated {1})  measures={2}  relationships={3}  expressions={4}" -f `
        $m.Tables.Count, $calc, $measures, $m.Relationships.Count, $m.Expressions.Count)
    exit 0
} catch {
    $e = $_.Exception; while ($e.InnerException) { $e = $e.InnerException }
    Write-Host "ERROR: $($e.Message)"
    exit 1
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
