Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `ReorderThemeColors.ps1` (added 2026-10-16)

File: [`ClientA\_Documentation\Scripts\ReorderThemeColors.ps1`](<../../../Scripts/ReorderThemeColors.ps1>),
self-contained, PowerShell 7. Reorders the theme palette (`dataColors` = default series colors)
**and** renumbers every `ThemeDataColor.ColorId ≥ 2` (`= dataColors[ColorId − 2]`; `0`/`1` =
background/foreground are never touched — see `PBIP_Theme.md`) so fixed palette references keep
their colors; only the series order changes.

```powershell
# project: the customTheme from report.json + every *.json of the *.Report (visuals, pages, bookmarks)
.\ReorderThemeColors.ps1 -RootPath "<project folder>" -Order 0,3,2,6,1,4,7,5 [-DryRun]
# standalone theme file (master copy) - its own visualStyles references too
.\ReorderThemeColors.ps1 -ThemeFile "<theme.json>" -Order '#C0392B','#099078',... [-DryRun]
```

- `-Order` — the **old** position (0-based) or the HEX of each color in its **new** place; may
  cover only the first K entries (a theme with generated shades keeps the rest).
- Text-level edits (formatting kept; diff = only the moved HEX lines and the ColorId numbers),
  JSON validated before each write; backup to the nearest parent `BackUp` folder
  (`ClientA\BackUp\ReorderThemeColors_<timestamp>\`); after writing it re-checks every reference:
  old color of the old ColorId = new color of the new ColorId.
- Desktop open on the report → `powerbi-desktop reload` (report files only).
- **Applying the ThemeWarm fix to another report** (same 8 colors): use the HEX form —
  `-Order '#C0392B','#0087B6','#F7BE0F','#6A4C93','#E85423','#099078','#B84A9C','#01238E'` — it
  works whatever order that report's palette is in now; `-DryRun` first. (This is the **final**
  ThemeWarm order of 2026-10-16: red, blue, yellow, purple, orange, teal, magenta, navy.)
- Runs 2026-10-16: Collector Assignment — 1st: 46 references in 37 files (`5→3` ×44, `7→9`
  ×2); 2nd (blue ↔ teal, user: red and green must not be neighbours): 44 references (`3→7` ×44);
  the master `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\Maket\ThemeWarm.json` — 0 palette references (only `0`/`1`), both runs.
