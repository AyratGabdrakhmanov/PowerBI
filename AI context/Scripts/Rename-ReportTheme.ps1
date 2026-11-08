# Rename-ReportTheme.ps1 version 2026-09-19.1
#
# Deploys a new custom theme JSON into a PBIP report's
# StaticResources\RegisteredResources, then repoints every internal
# report.json reference to the theme by file name (themeCollection.customTheme.name
# and the matching resourcePackages item's name/path) to the new file, and removes
# the old theme file. Backs up report.json and the old theme file first.
#
# Usage:
#   pwsh -File Rename-ReportTheme.ps1 -ReportPath "...\Collector Assignment.Report" -NewThemeFile "...\ThemeWarm.json"

param(
  [Parameter(Mandatory = $true)][string]$ReportPath,
  [Parameter(Mandatory = $true)][string]$NewThemeFile
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
  if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    & pwsh -File $PSCommandPath @PSBoundParameters
    exit $LASTEXITCODE
  } else {
    Write-Error "This script requires PowerShell 7+ (pwsh). Install: https://aka.ms/PSWindows"
    exit 1
  }
}

$ScriptVersion = "2026-09-19.1"
Write-Host "Rename-ReportTheme.ps1 version $ScriptVersion"

$ErrorActionPreference = "Stop"

$ReportPath = (Resolve-Path $ReportPath).Path
$NewThemeFile = (Resolve-Path $NewThemeFile).Path

$reportJsonPath = Join-Path $ReportPath "definition\report.json"
$registeredResourcesPath = Join-Path $ReportPath "StaticResources\RegisteredResources"

if (-not (Test-Path $reportJsonPath)) { throw "report.json not found at $reportJsonPath" }
if (-not (Test-Path $NewThemeFile)) { throw "New theme file not found at $NewThemeFile" }

$reportJson = Get-Content $reportJsonPath -Raw
$reportObj = $reportJson | ConvertFrom-Json -AsHashTable

$oldThemeFileName = $reportObj.themeCollection.customTheme.name
if (-not $oldThemeFileName) { throw "Could not find themeCollection.customTheme.name in report.json" }

$newThemeFileName = Split-Path $NewThemeFile -Leaf
$oldThemeFilePath = Join-Path $registeredResourcesPath $oldThemeFileName
$newThemeFileDest = Join-Path $registeredResourcesPath $newThemeFileName

Write-Host "Old theme file: $oldThemeFileName"
Write-Host "New theme file: $newThemeFileName"

if ($oldThemeFileName -eq $newThemeFileName) {
  throw "Old and new theme file names are identical ($oldThemeFileName) - nothing to rename."
}

# Sanity check before touching anything on disk
$occurrences = ([regex]::Matches($reportJson, [regex]::Escape($oldThemeFileName))).Count
if ($occurrences -eq 0) {
  throw "Old theme file name '$oldThemeFileName' not found anywhere in report.json - aborting."
}
Write-Host "Found $occurrences reference(s) to '$oldThemeFileName' in report.json."

# Backup before any write - project convention: <project folder>\_BackUp\<ScriptName>_<timestamp>\
$backupRoot = Join-Path (Split-Path $ReportPath -Parent) "_BackUp"
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$backupDir = Join-Path $backupRoot "Rename-ReportTheme_$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $reportJsonPath (Join-Path $backupDir "report.json")
if (Test-Path $oldThemeFilePath) {
  Copy-Item $oldThemeFilePath (Join-Path $backupDir $oldThemeFileName)
}
Write-Host "Backed up report.json and old theme file to $backupDir"

# Deploy new theme file
Copy-Item $NewThemeFile $newThemeFileDest -Force
Write-Host "Copied new theme file to $newThemeFileDest"

# Text-level replace of the filename string throughout report.json - avoids
# round-tripping the whole file through ConvertTo-Json (see POWERBI_PBIP_STRUCTURE.md
# re: number/formatting corruption risk on full re-serialization of large report.json).
$updatedJson = $reportJson.Replace($oldThemeFileName, $newThemeFileName)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($reportJsonPath, $updatedJson, $utf8NoBom)
Write-Host "Updated $occurrences reference(s) in report.json: '$oldThemeFileName' -> '$newThemeFileName'"

# Remove old theme file now that report.json no longer references it
if (Test-Path $oldThemeFilePath) {
  Remove-Item $oldThemeFilePath -Force
  Write-Host "Removed old theme file $oldThemeFilePath (backed up above)"
}

Write-Host "Done. Re-open the report in Power BI Desktop to verify the theme loads correctly."
