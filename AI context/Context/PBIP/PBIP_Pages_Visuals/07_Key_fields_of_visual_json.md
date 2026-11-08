Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## Key fields of visual.json

```json
{
  "name": "315af1bd8ce67df05186",   ← must match the folder name (same principle as for pages)
  "position": {
    "x": 0,
    "y": 496.66666666666669,        ← Power BI itself creates fractional pixels
    "z": 17000,
    "height": 87.222222222222214,
    "width": 300,
    "tabOrder": 20000
  },
  "visual": {
    "visualType": "tableEx",        ← visual type (slicer, shape, actionButton, tableEx, ...)
    ...
  }
}
```

- `name` in `visual.json` works **exactly the same way** as `name` in `page.json`:
  it must match the visual's folder name. Verified on 207 visuals —
  renaming the folder without synchronizing `name` was not tested (we always
  change both at once), but by analogy with pages it is reasonable to assume that
  Power BI looks up a visual by `name`, not by folder name.
- `position.x/y/height/width` in Power BI are almost always **fractional** (the result
  of visual dragging in the UI) — they can safely be rounded to integers,
  the key thing is to change the type to `[long]` before serialization (see below).
- `visualType` — the machine name of the visual type (`shape`, `slicer`, `actionButton`,
  `tableEx`, `cardVisual`, `pivotTable`, `lineChart`, `kpi`, `gauge`, etc.),
  with no spaces by construction.
