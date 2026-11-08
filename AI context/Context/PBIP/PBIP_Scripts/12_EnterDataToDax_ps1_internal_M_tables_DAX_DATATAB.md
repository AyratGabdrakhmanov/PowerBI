Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `EnterDataToDax.ps1` — internal M tables → DAX `DATATABLE`, live (2026-10-23)
File: `ClientA\_Documentation\Scripts\EnterDataToDax.ps1` (generalised `Translation\tom_to_dax_tables.ps1`). For "Enter data"
/ `#table` tables: reads the rows from the open model (the final M result, so later M steps — renames, conditional
columns — are included), generates an aligned `DATATABLE` (`{` on its own line), builds it under a temp name, compares
types / row count / values both ways (`EXCEPT`) and stops on any difference, then swaps in one `SaveChanges`
(translations, measures and relationships of the old table out; table out; temp renamed; measures and relationships
back), restores column properties incl. sort-by and **lineage tags** (table / columns / measures keep their tags), captions,
`Calculate`. `-Columns @{ 'T' = 'A','B' }` keeps only those columns (stops if dropping them would merge rows).
Run it in-process — `pwsh -File` turns the hashtable into a string:
```powershell
& "...\EnterDataToDax.ps1" -Port 60519 -Tables 'AR Periods','DocumentTypes' -Columns @{ 'P&L|Balance Sheet Labels' = @('ProfitLossSection','ProfitLossSectionID') } [-DryRun]
```
Check which columns are used first (`FindUnusedColumns.py`). Then save Desktop. ClientD Finance 2026-10-23: `AR Periods`
(10 rows, 2 measures), `DocumentTypes` (30 rows, 4 relationships), `P&L|Balance Sheet Labels` (14 rows, 2 of 4 columns —
`Mark`, `ProfitLossaCategory` unused) — values matched, 0 model errors.
