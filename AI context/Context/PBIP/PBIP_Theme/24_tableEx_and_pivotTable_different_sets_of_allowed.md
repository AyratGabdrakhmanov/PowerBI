Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️ `tableEx` and `pivotTable` — different sets of allowed keys in `visualStyles`, not interchangeable

Both schemas (`visual-tableEx`, `visual-pivotTable` in `reportThemeSchema-*.json`)
have `additionalProperties: false` — an attempt to add to `visualStyles.tableEx.*`
a key that is not in the `tableEx` schema breaks validation. Verified against
`allOf[1].properties` of each of the two schemas:

- **Shared** (valid for both): `columnHeaders`, `grid`, `values`,
  `columnWidth`, `columnFormatting`, `general`, `accessibility`, `sparklines`,
  `total` — but in `tableEx` this is `total` (a single one), while `pivotTable` instead has
  separate `rowTotal`/`columnTotal`.
- **`pivotTable` only** (row/column grouping concepts that the
  flat `tableEx` physically lacks): `rowHeaders`, `subTotals`, `rowTotal`,
  `columnTotal`, `blankRows`, `annotationTemplate`.
- **`tableEx` only**: `clustering`.

**Practical consequence:** when moving formatting from a `pivotTable` visual
(matrix/pivot table) into the theme, you **cannot** mechanically duplicate the same
keys in `visualStyles.tableEx` "for uniformity" — `rowHeaders`/`subTotals`/
`rowTotal` are invalid there. A named preset with the same name (for example
`Warm`) can be created under both types at once, but with a reduced set
of keys in the `tableEx` version (only what is valid for both: `columnHeaders`,
`grid`, `values`, and if needed `title`/`subTitle` from `commonCards`).
