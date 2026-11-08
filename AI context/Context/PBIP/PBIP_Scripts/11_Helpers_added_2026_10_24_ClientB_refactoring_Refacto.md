Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## Helpers added 2026-10-24 (ClientB refactoring, `Refactoring.md`)
All in `ClientA\_Documentation\Scripts\`, all against the **open** model (port: `QueryOpenModel.ps1 -ListInstances`).
Lists are **one string split by `;`** — `pwsh -File` passes `"a","b"` as a single string.
- **`SnapshotMeasures.ps1 -Port -Out <file> [-Measures "[A];[B]"] [-By "'Calendar'[Year];T[Col]"] [-Filter "TREATAS ( { 2 }, 'CT_Currency'[CurrencyID] )"]`** (`-Filter` since 2026-10-28: CALCULATETABLE filter for every query — one snapshot per selector state; labels stay the same, so snapshots taken on old / new selector columns compare section by section) — values of the
  measures (default: all) at the total and per `-By` column, read-only; a measure in error becomes an `ERROR` line.
  Take one before and one after every model change.
- **`CompareReportViews\`** (2026-10-25) — do two report versions show the viewer the same figures: trace the visuals'
  queries, rerun, compare per page, diff saved selections. Steps — `PBIP_Recipes.md` (same title).
- **`CompareSnapshots.py before.txt after.txt [--tol 1e-6]`** — numbers within a relative tolerance (float noise,
  Double → Currency), text exact; prints differing sections, exit 1 on a real difference.
- **`CompareBPA.ps1 -Port -Baseline "<backup>\X.SemanticModel\definition" [-RenameMap "Old=New;…"]`** — BPA
  (`BPARules_ClientA.json`, TE2 CLI) on the live model vs the pre-change backup; prints only NEW violations + count fixed.
  Run after every model change. `-RenameMap` for renamed tables, so their old violations are not "new".
  `-Report <X.Report>` (2026-10-25): BPA sees only the model, so "Remove unnecessary measures / columns" hits for
  objects used in the report (any `"Property"` in its JSON) are dropped and counted — always pass it.
  False "new" (by design): renamed partitions (their old per-partition violations reappear under the new name), and
  calculated-table columns without a `dataType` line in TMDL (e.g. `DATATABLE` columns — the file baseline does not see
  them as numeric, the live model does). Confirm with a file diff against the backup.
- **`RenamePartitions.ps1 -Port [-Tables "A;B"] [-Apply]`** (2026-10-25) — single-partition tables: partition name →
  table name (BPA `PARTITION_NAME_SHOULD_MATCH…`; Desktop default `Table-<guid>`); `-Tables` omitted = all mismatched.
  Metadata only — partitions stay `Ready`, Desktop saves with no "pending changes" banner. Then `SaveDesktop.ps1 -Expect`.
- **`ScanDataTypes.ps1 -Port [-SkipTables "Calendar;…"]`** — Double columns (non-integer count = can it be Whole
  number; max loss at 4 decimals = what Currency cuts) and Date/time columns (values with a time part = can it be Date).
- **`MoveMeasures.ps1 -Port -From T1 -To T2 [-Measures "A;B"] [-Hide] [-DeleteSource] [-Apply]`** — model part of a
  measure move: Clone → Remove → Add, captions carried over (a caption on the removed measure blocks SaveChanges),
  `'T1'[Measure]` refs rewritten to `[Measure]`, `-DeleteSource` only for a pure measure table (throws otherwise). Dry
  run by default. Then `MoveMeasureRefs.py` (report), `CheckReportRefs.py`, bridge reload, `SaveDesktop.ps1`.
- **`Refactoring\ClientE\rename_dax_live.ps1 -Port -Map "Old=New;…" [-ColMap "NewTable|OldCol=NewCol;…"] [-Apply]`**
  (2026-10-27) — after a live TOM table / column rename (the engine does not fix references): rewrites every DAX
  expression (measures, calculated columns / tables, RLS), skipping "strings" and [names]; dry run by default, then
  `Calculate` + error count. Report side: `Refactoring\ClientB\rename_model_objects.py <project> <map.json>` (diff the model after).
  ⚠️ Before `2026-11-01.1` it skipped `groupByColumn:` lines (field parameter label → its `Fields` column): renaming `FP Fields`
  left dangling refs and Desktop silently opened an empty "Untitled" window (ClientF Sales v2). After any rename on closed files
  run `ValidateTmdl.ps1` before opening — it names the unresolved reference.
- `CheckReportRefs.py` needs `<X.Report> --model <X.SemanticModel>` (with only the project folder it reports false misses);
  `--before <old X.Report> --new-only` shows only new misses.
- Updated: **`MoveMeasureRefs.py`** — also `Old.Measure` followed by `,` (visual calculations
  `Divide(T.M, ScopedEval(T.M, …))`), drops `From` aliases of the old table nothing uses; **`--whole-table`** when the
  old table held only measures and is deleted (every remaining `Entity` / `Old.` string → new table).
  **`SaveDesktop.ps1 -Expect "definition\tables\X.tmdl|regex;…"`** — content check after the save; one automatic
  second save when a check fails (a Ctrl+S right after a TOM edit can write the old value with a new timestamp).
  Tested for real 2026-10-25 (ClientB, 1 + 10 checks, both passed at the first save).
- TOM script rules (memory `tom-script-safety`): `Set-StrictMode -Version Latest`; no Tabular Editor-only members
  (`Model.AllMeasures`, `ReferencedBy` … — missing in TOM, `$null` silently); assert the expected count before any
  destructive step; a `[string]` parameter stays a string — split into a new variable. PowerShell names are
  case-insensitive: `$m` (model) / `$M` (measures), `$T` (namespace) / `foreach ($t in …)`, `$Ms` / `foreach ($ms …)` are
  one variable — use distinct names (ClientC 2026-10-28, three failed dry runs, nothing saved).
