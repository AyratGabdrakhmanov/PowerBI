Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `CopyDiagramLayout.py` (added 2026-10-15)

`ClientA\_Documentation\Scripts\CopyDiagramLayout.py` — copies the **Model view** layout
(`<X>.SemanticModel\diagramLayout.json`: per table box `location`, `size`, `zIndex`,
`expandedHeight`) from one model to another, e.g. from an archive copy with a tidy diagram.

```
python -I CopyDiagramLayout.py <source.SemanticModel> <target.SemanticModel>            # dry run
python -I CopyDiagramLayout.py <source.SemanticModel> <target.SemanticModel> --apply    # backup + write
```

- Diagram tabs matched by name (`--diagram "All tables"` limits it); `--view` also copies
  zoom / scroll position.
- Tables matched by name, then by `lineageTag` — from the diagram node, or, when the node has
  none (Desktop often omits `nodeLineageTag`: 26 of 37 ClientB nodes), from the target model's
  `tables\*.tmdl`. So renamed tables keep their place.
- Target tables missing from the source go into a grid (6 per row) under the copied boxes;
  source-only tables are listed.
- Backup `CopyDiagramLayout_<timestamp>` (nearest `BackUp`). A second run changes nothing.
- ⚠️ Desktop keeps the diagram in memory and writes it on Ctrl+S. **`powerbi-desktop reload`
  does NOT re-read `diagramLayout.json`** (checked on ClientB 2026-10-16: after apply + reload the
  Model view was unchanged and the user's Ctrl+S wrote back the old layout, 37 of 37 positions).
  Order: the user closes the file in Desktop (save first if needed) → `--apply` on the closed
  file → the user reopens it.
- ClientB test on a copy (source: archive `C:\DAX\ClientB TEST\10.07.2026\…_7_09_2026.SemanticModel`):
  "All tables" — 31 tables copied (2 renamed Field Parameters matched by lineageTag:
  `FP_Aggregation Level` → `FP_Aggregation_Level`, `FP_Choose Aggregation Level - Technician
  Report` → `FP_Aggregation_Level_Technician`), 6 new placed below (`Aggregate`, `הובלה`,
  `MeasureTable`, `Target`, `_Measures`, `CustomersSmall`), `Departments` only in the archive;
  "Layout 1" is not in the archive — left as is.
