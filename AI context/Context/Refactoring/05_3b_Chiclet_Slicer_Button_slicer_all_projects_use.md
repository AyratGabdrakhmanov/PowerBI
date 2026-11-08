Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 3b. Chiclet Slicer → Button slicer (all projects, user 2026-10-28)

Every custom `ChicletSlicer…` visual becomes a native Button slicer (`advancedSlicerVisual`), **before step 4** — then
`CleanUnused.ps1` step 11 drops the Chiclet custom visual from `report.json` as unused. Per visual keep: name / folder
(bookmarks and interactions keep pointing at it), position / size / z, field(s), saved selection (filter), single /
multi select, orientation and rows × columns, fonts, colors per state (default / hover / selected — `_Measures` Color
measures where they exist), border / radius, title / header, sync group, visual-level filters. Reference result: ClientB
`Page13` / `Page14` (`ClientB\ClientB_History.md` → "Aggregation buttons"). Check: screenshots before / after per page
(`CompareScreens.py`), `pbir validate`, `CheckReportRefs.py`, bookmarks still apply the same selection.
