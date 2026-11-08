Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `Rename-ReportTheme.ps1` (added 2026-09-19)

[`ClientA\_Documentation\Scripts\Rename-ReportTheme.ps1`](<../../../Scripts/Rename-ReportTheme.ps1>) — deploys a new theme file
into `<Report>\StaticResources\RegisteredResources\` and switches all
three internal references in `report.json` to it (see "Three places in `report.json`
reference the theme file by name" above), then deletes the old theme file.
Parameters: `-ReportPath` (the `*.Report` folder), `-NewThemeFile` (path to the new
theme file; the script finds the old file name itself via
`themeCollection.customTheme.name`).

Steps: backup of `report.json` + the old theme file to `<project folder>\_BackUp\
Rename-ReportTheme_<timestamp>\` (the same pattern as
`Find-UnusedMeasures.ps1`/`CleanUnused.ps1` — **unconditionally**, not via a flag) →
copying the new theme file into place → targeted text replacement of the file
name in `report.json` (not a full `ConvertFrom-Json`/`ConvertTo-Json`, see the
rationale above) → deleting the old theme file. Sanity check before any
write: if the old theme file name does not appear in `report.json` even once —
the script stops without touching anything (protection against desync if the
structure of `report.json` has unexpectedly changed).

If the old and new theme file names are the same (only the
**content** of an already deployed theme is being updated, without renaming) — the script is **not
suitable** (it deliberately throws a "nothing to rename" error): in that
case it is enough to back up and copy the theme file directly (`Copy-Item`),
without editing `report.json` — the file-name references do not change.

Used on `Collector Assignment.Report` 2026-09-19: replacing
`Classroom7947196837311171.json` → `ThemeWarm.json` when deploying a new
theme with the `Warm` Style Preset (see the next section on the `Warm` preset itself).
