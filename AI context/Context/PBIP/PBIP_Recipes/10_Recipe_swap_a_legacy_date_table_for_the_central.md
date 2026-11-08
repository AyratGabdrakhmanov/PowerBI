Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: swap a legacy date table for the central `Calendar` (ClientB, 2026-10-18)

Reference implementation: `Agency\ClientB\CentralCalendar\` (mapping inside is ClientB's). Desktop open, three
phases so the report never points at a missing table:

1. **Inventory.** Every old column used in DAX code (skip comments) and in the report (`Entity` + saved
   literals: `Categorical` filters, slicer selections incl. `decomposedIdentities` / `valueMap`); map each
   to a template column. Text / flag columns map to ID / boolean columns — `Show This Year = true` →
   `Year ID = 0` (`0L`), `Show Months = '<this month>'` → `Current Month = true`; year-less text
   selections (`'Q-2'`, `'April'`) need a year (`datetime'2026-04-02T00:00:00'` — `Quarter Name` is
   `DATE ( Y, first month, Q )`).
2. **Snapshot** every measure at the total and in one month (`measure_snapshot.ps1`, `snap_ctx.ps1`).
3. **Phase 1 (TOM, `phase1.ps1`):** `Calendar` from `Calendar.json` via
   `JsonSerializer.DeserializeObject[Table]`, `DataCategory = 'Time'`, `Date.IsKey`; DAX rewritten by a
   regex that skips comments / strings and stops on an unmapped column; measures of the old table moved
   (translations removed first, names are model-wide unique); relationships re-created on
   `Calendar[Date]` in one `SaveChanges`; captions; `RequestRefresh(Calculate)` → save.
4. **Report:** `ReportFields.py replace` per column, then the literal conversion (`fix_literals.py`),
   `he_visible_diff.py` (pin `displayName` where the He text changed) → `powerbi-desktop reload`.
5. **Phase 3 (`phase3.ps1`):** old table's translations → table → its M parameters if nothing else uses them.
6. **Checks:** `check_model.ps1`, snapshots compared, report field references vs TMDL (`refcheck.py`),
   `CheckBookmarks.py --ref <backup>`.

Gotchas:
- **Not `ReplaceModelTable.ps1`:** it copies the old columns' `FormatString` / `SummarizeBy` onto the new
  table (`Year` int would get "Long Date") and does not remove translations before deleting the table.
- **Range anchor:** a legacy table ending on 31 Dec of the current year made YTD / QTD / "today" measures
  work without a date filter; the template runs 1 year ahead, so they go blank there. Snapshot differences
  appear only at the total — find visuals that use those measures without a date filter (`ctx.py`) and
  give the page `Calendar[Closed Period] = TRUE`.
- `ISFILTERED` on a column changes meaning when several old columns map to one (`YearOfDate` and `Year`
  → `Year`).
