Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `CopyVisualSetup.py` (added 2026-10-15)

`ClientA\_Documentation\Scripts\CopyVisualSetup.py` — copies the setup of a template visual to
other visuals of the same type. Parts (`--parts`, default all): `fields` (`visual.query` +
expansion-state levels; each target keeps its own expanded/selected `root`; field-well filter
cards follow the fields, filters with a condition stay), `measure` (visual-level measure
filters, replaced by measure name), `size` (width, height), `x` (y, z, tabOrder stay).

```
python -I CopyVisualSetup.py <X.Report> --template Page7/slicer57 --targets slicer88,slicer94 --apply
```

Dry run by default; backup `CopyVisualSetup_<timestamp>`; CRLF kept. Applied on ClientB 2026-10-15:
the 11 "לקוח" slicers got `slicer57`'s fields, the `Show Existing DocsSales = 1` filter and
165 × 55 at x = 1115 (check after: 1 distinct setup across 12 slicers,
`CheckBookmarkSlicers.py` 0 / 124).
