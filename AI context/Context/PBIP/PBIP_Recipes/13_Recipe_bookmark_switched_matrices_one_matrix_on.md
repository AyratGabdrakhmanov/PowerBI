Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: bookmark-switched matrices → one matrix on a field parameter (ClientD P&L with Cost centers, 2026-10-23)

When N stacked visuals differ only in the column (or row) fields and are switched by buttons + bookmarks:
1. Compare them: fields per role, filters, formatting (a script diffing `objects` per card / selector) — only the
   field sets may differ; pick one visual whose formatting stays; agree on filters that differ (one rule for all sets).
2. Field parameter with a group column, cloned from an existing one (`Tables['FP_X'].Clone()`, new name, expression,
   lineage tags — keeps `ParameterMetadata`, sort-by, `groupByColumn`): rows `( label, NAMEOF ( field ), groupOrder,
   "Group name", detailOrder )`, group names = the old button texts. Calculate, save.
3. The kept visual: add `fieldParameters: [{ parameterExpr: FP[FP Fields], index, length }]` to the role; the role's
   projections must be the fields of the default group (Desktop rewrites them on selection).
4. Button slicer on `FP_Name`: copy an existing one (advancedSlicerVisual — the home page "Profit and Loss" has the
   reference one, top-left), repoint the Entity, put it where the buttons were, saved selection = default group.
   More buttons than the source: set **`layout.maxTiles`** (a 3-button copy keeps `maxTiles = 3` and hides the 4th
   behind a scrollbar; `columnCount` alone does nothing while `autoGrid = true`) and widen it (~105–115 px per button).
5. Delete the other visuals, the buttons, their bookmarks and the bookmark group in `bookmarks.json`; grep that no
   file still names them. Check every group: rewrite the slicer's saved selection, bridge apply, screenshot; restore.
   Full-page bookmarks that stay (e.g. a pop-up's open / close pair): drop the deleted visuals, add the new ones.
- Gotchas (ClientB Page2 / Page3, 2026-10-25): a visual copied from a tab-switched one keeps `"isHidden": true` — remove it.
  The same field in several groups with different `Order` values works (labels and `NAMEOF` repeat, no sort-by error
  after `Calculate`). Matrix tabular layout = `objects.general.layout = 'Tabular'`. Many columns + `autoSizeColumnWidth`
  push the right-hand (RTL) columns off screen — set fixed widths that add up to the visual width.
  Language rows (rows per language, see below): clone `FP_Aggregation_Level`, keep the `Culture` relationship and
  `Locale Match` slicer filter.
