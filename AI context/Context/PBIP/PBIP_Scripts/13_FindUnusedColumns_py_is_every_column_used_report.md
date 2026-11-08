Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `FindUnusedColumns.py` — is every column used? (report only, 2026-10-23)
File: `ClientA\_Documentation\Scripts\FindUnusedColumns.py`. Changes nothing. Covers what `CleanUnused.ps1` does not:
**data (M) columns and calculated-table columns** (CleanUnused removes only calculated DAX columns).
```powershell
python -X utf8 FindUnusedColumns.py "<...\Report>" [--csv out.csv] [--all]
```
Verdict per column: `USED` (report field incl. via alias / hierarchy level, or `'Table'[Column]` in DAX — measures,
calculated columns / tables, NAMEOF, calculation items, RLS; DAX comments ignored, nesting-aware), `STRUCTURE` (only a
relationship, sort-by target of a used column, level of an unused hierarchy, `groupByColumn`, date-table `isKey` — keep
or review), `M` (only Power Query: another query — a table's M partition or an `expressions.tmdl` query — references
this table's query, `#"Name"` / `Name`, and names the column `"Col"` / `[Col]` or its `sourceColumn`; a same-named
local step is not a reference), `MAYBE` (only an unqualified `[Column]` in DAX), `UNUSED`. Notes columns referenced
only from bookmarks. For an UNUSED calculated-table column the `How` hint says how to drop it: an own `"Col"` entry in
the table DAX (delete it), inherited from the source table (wrap in `SELECTCOLUMNS` without it), or a field parameter
column (internal, keep). Limits: M matching is textual (over-protects); a reference from an unused measure still
counts (run CleanUnused first).
ClientD Finance (after CleanUnused): 429 columns — USED 200, STRUCTURE 39, M 7 (`Accounts` columns merged into the two
dynamic-hierarchy tables, `BP[CompanyID]` into `JournalEntries`), UNUSED 183.
