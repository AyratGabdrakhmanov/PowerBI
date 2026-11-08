Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## Style level hierarchy and precedence rule

For one and the same visual property in PBIP there are up to **four** places where it
can be set, in increasing order of "generality":

1. `visual.json → objects` (object level, local, a specific instance)
2. `visual.json → visualContainerObjects` (container level, local)
3. `visualStyles.<type>.<PresetName>` — a named Style preset (theme)
4. `visualStyles.<type>.*` — the shared level for **all** visuals of this type
   (theme), applied automatically even if no preset is selected for the visual
5. `visualStyles.*.*` — the global level for **all** visual types (theme)

A higher level takes effect only if nothing is overridden at a lower
level (taking into account the "all or nothing" rule for arrays — see below). The working
rule is to move a setting as high up this list as possible:

> We move from the specific (local in visual.json) to the shared (named
> preset), from the shared preset to the theme (`*` for the visual type, then `*.*`
> globally). At each step — as far as possible, logical and without
> contradictions: if moving up changes the behavior of other visuals in
> the wrong direction (see the warnings below) or the value technically cannot live
> at a higher level (binding to a measure, text unique to the instance,
> etc.) — it stays at the current level.

Order of checks for a report-wide formatting change ("theme → visual type → style → visual"):
1. the theme's `visualStyles.<type>.*` (and `*.*`); 2. named presets of that type; 3. local
`objects` in each `visual.json` that override it — remove them so the theme value applies.
Examples:
- slicer hierarchy indentation — `visualStyles.slicer.*.items[0].steppedLayoutIndentation`
  (number; ClientB = 8, 2026-10-15; `advancedSlicerVisual` / custom slicers have no such property);
- slicer values without a background — `visualStyles.slicer.*.items[0].background =
  {"solid":{"color":"#FFFFFF00"}}` (8-digit hex with alpha 00 = transparent; the schema has no
  transparency property for `items`). A theme cannot target one slicer mode (vertical list vs
  dropdown) — it applies to all slicers; a local `items.background` in `visual.json` still wins.
  In the master `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\Maket\ThemeWarm.json` and ClientB Inventory Coverage (2026-10-21);
- slicer text sizes — values `visualStyles.slicer.*.items[0].textSize = 14`, title
  `visualStyles.slicer.*.title[0].fontSize = 15` (centered, bold; `header.show = false` — slicer names
  are titles, see the slicer-name rule in `PBIP_Recipes.md`). Local `items` `textSize` / `title`
  settings in `visual.json` win — remove them so the theme applies. Master + ClientB Inventory Coverage (2026-10-21);
- table / matrix text 14, title 15 — `visualStyles.tableEx` and `pivotTable`, in **every** style (`*` and
  presets such as `Warm`): `grid[0].textSize = 14` and `fontSize = 14` in `values`, `columnHeaders`, `total`
  (+ matrix: `rowHeaders`, `subTotals`, `rowTotal`, `columnTotal`); `title[0].fontSize = 15`. A visual
  without `stylePreset` uses `*`. Master + ClientB Inventory Coverage (2026-10-21);
- page vertical alignment — `visualStyles.page.*.displayArea[0].verticalAlignment = "Middle"`
  (default for new pages; `RenameObjects.ps1` adds it, see `PBIP_Scripts.md`).
