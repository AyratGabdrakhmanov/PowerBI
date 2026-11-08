Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 39. Tables without a data source are not refreshed (all projects, user 2026-11-02)

Every Power Query (M partition) table whose M reads **no external source** (no `Sql.Database`, `Odbc`, `OleDb`, `Excel` /
`Csv` / `File` / `Folder`, `Web`, `SharePoint`, `PowerPlatform`, other connectors, and no other query that reads one) gets
`excludeFromModelRefresh` (Desktop: Power Query → table → **Include in report refresh** off). Typical cases: `_Measures`
(`#table({},{})`, already in 1b), "Enter data" tables (`Binary.Decompress` / `Json.Document` literals), M `#table` /
`Table.FromRows` selector and label tables. Nothing to compute, so a report refresh only wastes time on them.
**Keep in the refresh:** tables whose M calls `DateTime.LocalNow` / `DateTime.FixedLocalNow` / `DateTimeZone.*Now` /
`Date.From ( DateTime.LocalNow () )` — last-refresh flags (`Date Last Refreshed`) and M date tables that roll with today.
**Out of scope:** DAX calculated tables (field parameters, `DATATABLE` selectors, DAX Calendar) — Desktop recalculates them
itself and `Calculate` stays allowed; excluding them would freeze a later edit.
⚠️ After an excluded table's M is edited, refresh that table by hand once (right-click → Refresh data), or it keeps the old rows.
Check: script — every M partition without a source function and without a `…Now` call has `excludeFromModelRefresh`, and no
table with a source or `…Now` has it. The flag does not touch the data, so it is safe on closed files.
