Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## Matrix total row color — `pivotTable` (Collector Assignment, 2026-10-16)

User: total row background of all matrices = that of `DPDMatrix` = **`#E0DED9`** (the `Warm`
preset's value). Before: `pivotTable.*` `rowTotal.backColor` = `ThemeDataColor 0 / −0.1`
(`#E6E6E6`, cooler grey), so the 16 matrices without the `Warm` preset (13 have it) differed.
Now `pivotTable.*` `rowTotal.backColor` = literal `#E0DED9` (same form as `Warm`) in the project
theme and the master `ThemeWarm.json`; the **local** `rowTotal` overrides on 9 matrices (8 copies
of the old default + `DPDMatrix`' own literal) were removed — a local value would mask the
theme (same rule as the preset section above). Result: 29 of 29 matrices take the color from the
theme (preset or base), none locally.
