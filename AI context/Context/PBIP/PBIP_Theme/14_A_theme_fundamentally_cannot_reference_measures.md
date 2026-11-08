Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️ A theme fundamentally cannot reference measures (DAX)

`ThemeDataColor` and any other values in a theme are static references to the
palette or literal values. A theme **does not support** expressions of the form
`{"Measure": {...}}` — i.e. if a color/text/number must change dynamically
depending on the data (the "Grey", "Light" measures, conditional formatting,
etc.), it **must** stay local in `visual.json`, regardless
of how "shared" the property looks. This is the most common reason
why a seemingly identical property (for example `dividerColor`) does not get moved into the
preset, even when everything else around it has already been unified.
