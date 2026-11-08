Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `CaptureDesktopWindow.ps1` (added 2026-10-20)

`ClientA\_Documentation\Scripts\CaptureDesktopWindow.ps1` — PNG of the **whole** Desktop window (ribbon,
panes, banners such as "Some of the tables have incomplete or no data", dialogs) plus the process's top-level
windows / dialogs by name. `powerbi-desktop screenshot` captures only the report canvas.

```
pwsh -File CaptureDesktopWindow.ps1 -ProcessId <pid> [-Out <file.png>]     # or -Title "Model - Power BI Desktop"
```

- `PrintWindow` with full content: works when the window is behind others, not when minimized. Read-only —
  nothing is clicked. Default output `%TEMP%\Desktop_<pid>_<timestamp>.png`; read the PNG or run
  `OcrImage.ps1` on it. Pid → file: `powerbi-desktop status`.
- Use after `powerbi-desktop reload` / reopening to see what Desktop actually shows (ModelWork 2026-10-20:
  the old field list after a "successful" reload; after the reopen the merged parameter list + the
  incomplete-data banner).

- **`TrimCalendar.py "<project>" [--apply]`** (2026-10-26, `Refactoring.md` 1a) — closed PBIP: keeps the full
  reference DAX in `Calendar`, comments out (`-- `) the `ADDCOLUMNS` entries of unused columns and removes their column
  objects. Kept: `Date`, `Closed Period`, hierarchy levels, sort-by targets, anything used in DAX / relationships /
  report (alias-aware). Dry run by default; backup `BackUp\TrimCalendar_<ts>`. Open the PBIP afterwards (calculated
  table recalculates).
- **`RetentionStaleDates.py "<X.Report>" "<backup dir>" [--apply]`** (2026-11-01, `Refactoring.md` 12) — closed PBIP:
  saved selections older than the retention window (current year − 2) move by whole years to the latest year in which
  every selected month has started — date-range slicers (pairs together), page `Calendar[Year]` + `[Month Name]`
  filters; `Year` exclusion lists drop stale years; bookmark slicer states → the visual's saved state. Prints
  `UNHANDLED` for anything else. Dry run by default; `--apply` backs up each changed file first.
- **`SyncTmdl.py <serialized folder> <X.SemanticModel\definition> <backup> [skip…]`** (2026-10-26) — closed-PBIP model
  edits: write a TMDL folder produced by offline TOM (`TmdlSerializer.DeserializeDatabaseFromFolder` → edit →
  `SerializeDatabaseToFolder`) or by serializing a live model into the PBIP. Copies changed / new files, moves files of
  deleted tables to the backup, keeps `database.tmdl` (the serializer writes the workspace id there; raise
  `compatibilityLevel` in it by hand), refuses an incomplete source. Then `ValidateTmdl.ps1`.
- **`CompareSnapshotsKeys.py before.txt after.txt [--keys 2023,2024] [--tol 1e-6]`** (2026-10-26) — like
  `CompareSnapshots.py`, but compares only the keys both snapshots have (and optionally only the listed ones) and lists
  totals apart; for date-table swaps where the year range changes.
- **`SqlQuery.ps1 -Server <srv> -Database <db> -Query "<SELECT …>" [-QueryFile] [-Timeout]`** (2026-10-26) — read-only SQL
  from this workstation (`System.Data.SqlClient`, Windows sign-in, TSV); refuses INSERT / UPDATE / DROP / EXEC etc.
  The client server must be reachable (its VPN connected).
