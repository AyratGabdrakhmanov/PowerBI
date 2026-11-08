Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## `GreyShadeInactive` default fill — opaque since 2026-10-16 (Collector Assignment)

The user disliked the 50% transparency of the inactive navigation buttons. `fill` `$id:
"default"` changed from `#C4C1BB` + `transparency: 50` to **`#D2CFC9` + `transparency: 0`**
— the color actually rendered (sampled from a screenshot), so the look stays the same.
The same HEX is the measure `Measure[Grey Shade Inactive]` (folder `Color`) for fx use —
the theme itself cannot reference measures (see above).
- 89 buttons use the preset; **13 override `fill` default locally** (`ThemeDataColor` 4/5,
  `Percent` 0.6 / 0) — the colored drillthrough buttons to `Details1` ("Assign. Details" on
  10 pages, + "PTP Details" / "Status Change" on Tree). User 2026-10-16: they are fine as
  they are (colored, a slightly different mode) — no change needed.
- Master copy `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\Maket\ThemeWarm.json` updated the same way (2026-10-16).
- Method for "make it opaque, keep the look": opaque = color × (1 − t) + background × t;
  simplest exact source is the pixel color of a screenshot (`System.Drawing` `GetPixel`,
  no PIL installed).
