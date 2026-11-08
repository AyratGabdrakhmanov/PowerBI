Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## Correctness check

```powershell
# Check that all page.json files are valid and name matches the folder name
foreach ($folder in Get-ChildItem "Model_v2.Report\definition\pages" -Directory) {
    $pageJson = Join-Path $folder.FullName "page.json"
    try {
        $content = Get-Content $pageJson -Raw | ConvertFrom-Json
        if ($content.name -ne $folder.Name) {
            Write-Host "✗ $($folder.Name) - name mismatch: '$($content.name)'"
        } elseif ($folder.Name -match '\s') {
            Write-Host "✗ $($folder.Name) - folder name contains a space!"
        } else {
            Write-Host "✓ $($folder.Name)"
        }
    } catch {
        Write-Host "✗ $($folder.Name) - JSON error"
    }
}

# Check the encoding of pages.json (there must be no BOM)
$bytes = [System.IO.File]::ReadAllBytes("Model_v2.Report\definition\pages\pages.json")
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "❌ File has a BOM"
} else {
    Write-Host "✓ File without BOM"
}
```
