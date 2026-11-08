Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## Checking the model for errors after edits (2026-10-13)

The Desktop error report is not visible (the UI is not accessible), so there are two checks:

- **In the open model — object state:** `INFO.MEASURES()`,
  `INFO.COLUMNS()`, `INFO.PARTITIONS()`, `INFO.RELATIONSHIPS()` have `[State]`
  (1 = OK) and `[ErrorMessage]`. Query via `QueryOpenModel.ps1`:
  ```dax
  EVALUATE FILTER ( INFO.MEASURES (), [State] <> 1 || NOT ISBLANK ( [ErrorMessage] ) )
  ```
  (likewise for columns — excluding `[Type] = 3`, that is the internal RowNumber; partitions,
  relationships). Empty = no DAX errors.
- **In the open model — evaluation (2026-10-18):** `[State]` covers only syntax / references. Runtime
  errors (a wrong argument type, an engine exception) show up only when the measure is calculated —
  ClientB `[AvergePerCustomer]` ("An unexpected exception occurred.") and `[SalesValue PQ]` (`DATEADD` on a
  non-date column) both had `[State] = 1`. Evaluate every measure at the total, **one query per
  measure** (in one `UNION` / `ROW` batch a single failure fails the whole query and hides which one):
  ```powershell
  foreach ($m in $measureNames) {   # from TOM: $model.Tables | % { $_.Measures } | % Name
      $r = & $q -Port $port -Query "EVALUATE ROW ( ""v"", [$($m.Replace(']', ']]'))] )" *>&1
      if ($r -match 'Exception') { "ERROR $m" }
  }
  ```
  149 measures ≈ 1–2 min. Blank at the total is not an error (date-dependent measures). Compare with the
  backup's TMDL to separate new failures from old ones.
- **Value snapshot before / after an edit that must not change results** (comments, formatting, renames):
  the value of every measure at the total into a JSON before, the same after, compare — 0 differences
  expected. ClientB script: `Agency\ClientB\Translation\measure_snapshot.ps1 -Port -Out [-CompareTo]` (+
  `check_model.ps1` = states + evaluation in one summary). Differences only in the 15th significant digit
  (`0.872422409503915` → `…914`, a ratio after a table drop, 2026-10-18) are floating-point noise from a
  different evaluation order, not a change. A month-context variant (`Agency\ClientB\CentralCalendar\snap_ctx.ps1`,
  every measure in Sep 2026) catches changes that a total-only snapshot hides, and vice versa (anchor-on-last-date
  measures differ only at the total).
- **TOM: remove an object's culture translations before removing the object** — otherwise `SaveChanges`
  fails: "The translation for culture 'en-US' references an object of type 'Column' with name … but that
  object has been deleted." (`$cul.ObjectTranslations | Where-Object { $_.Object -eq $col }` → `Remove`).
- **In the report files — field references:** check every `Measure`/`Column` with a
  `SourceRef` in all of the report's `*.json` files (visuals, filters, sorts,
  bookmarks, conditional formatting) against the list of tables/columns/measures
  from the TMDL. A missing field = what Desktop shows as a broken
  visual / a warning in the filters. Compare with the "before" backup (by file +
  field pair) to separate new breakage from long-broken references. Name comparison is
  case-insensitive (Power BI does the same; `groupcode` = `GroupCode`). Since 2026-10-13, junk of this
  kind is removed by `CleanUnused.ps1` Step 10 (`PBIP_Scripts.md`). Read-only check with the NEW / old split
  against a backup — `CheckReportRefs.py` (2026-10-20).
- **TMDL on disk — does it load:** `ValidateTmdl.ps1 -Path <X.SemanticModel>` (offline TOM loader, handles the
  zero-width Calendar levels in a scratch copy) — before opening / reloading in Desktop.
