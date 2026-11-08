Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 22. Reference theme as an exact copy (all projects, user 2026-10-30)

The report theme file (`StaticResources\RegisteredResources\<name>.json`) = an **exact copy** of
`Reference\Maket\ThemeWarm.json` (same file name kept → `report.json` unchanged; diff the two first — palette order,
`ColorId` references only 0 / 1 or remapped with `ReorderThemeColors.ps1`). Report-specific looks do not stay in the theme:
a page background image (e.g. `Agency_Background_1920x1080.svg`) moves to `page.json` → `objects.background` (+ the SVG
registered as `Image` in `RegisteredResources`). The theme carries matrix / table **column headers aligned Right**
(`columnHeaders.alignment`, not `titleAlignment`). Check: theme file byte-equal to the master; screenshot before / after.
ClientB Inventory Coverage 2026-10-30.
