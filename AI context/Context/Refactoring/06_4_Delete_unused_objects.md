Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 4. Delete unused objects

Delete only what the scripts flag (`CleanUnused.ps1`, `FindUnusedColumns.py` UNUSED) — an object they count as used stays,
even if it looks dead (user 2026-10-27); report doubts as findings. `CleanUnused.ps1` counts relationship-key columns
as used and column cleanup no longer deletes relationships (fixed 2026-10-28, version `2026-10-28.1`; it used to delete
the ClientC `TargetFamily` keys).


Full backup of the project folder; close the report (no unsaved changes) → `ClientA\_Documentation\Scripts\CleanUnused.ps1
-RootPath <project>` (files only, never `-Port`) → review the log (kept: `Color` measures, culture-aware `USERCULTURE` columns; deleted measures / columns / tables / custom visuals)
→ check report fields exist → reopen (`powerbi-desktop open`) → no errors, values equal to the snapshot.
