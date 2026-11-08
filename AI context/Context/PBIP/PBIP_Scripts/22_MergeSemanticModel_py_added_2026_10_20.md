Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `MergeSemanticModel.py` (added 2026-10-20)

`ClientA\_Documentation\Scripts\MergeSemanticModel.py` — carries model changes from one PBIP semantic
model into another (a dev copy → the main model) at the TMDL level, plus the report-side measure renames.

```
python -I -X utf8 MergeSemanticModel.py compare <src.SemanticModel> <dst.SemanticModel> [--report <dst.Report>]
python -I -X utf8 MergeSemanticModel.py merge   <src.SemanticModel> <dst.SemanticModel> --exclude "Measure/Measure 2" --keep "Measure/DDC #" [--skip-table BalanceHistory] [--apply]
python -I -X utf8 MergeSemanticModel.py rename-measures <dst.Report> --map "Interest Rate Avg=APR Avg" [--map ...] [--apply]
```

- **`compare`** — tables only in one model; per table `+` / `-` / `~` measures, columns, partitions,
  calculation items (`lineageTag` and line endings ignored) and `~ table header / annotations`;
  relationships by id. `--report` lists target-report pages using measures the source lacks.
  "Closest source measure by DAX" helps spot renames (`identical` = same DAX after stripping comments /
  properties) — a heuristic: a high ratio is not a match (`DDC #` vs `Deferments #` = 0.996, only the
  `_ChangeType` constant differs; short measures match anything). Check before treating it as a rename.
- **`merge`** — every table file that is new or differs is copied from the source (whole file: its line
  endings, lineageTags), then `--exclude Table/Object` drops source junk and `--keep Table/Object`
  re-inserts a target object the source no longer has (e.g. a measure still on a visual with no
  replacement). New tables get `ref table` in `model.tmdl`; missing source relationships whose tables both
  exist are appended. Target-only tables / relationships are listed, never removed; `cultures\*.tmdl`
  (linguistic metadata only — Q&A is off), `diagramLayout.json`, model annotations are not touched.
  `--skip-table` for tables that differ only in Desktop state (`annotation PBI_ResultType`).
- **`rename-measures`** — replaces quoted tokens `(?<=[".])Old(?=")` in all report JSON (Property,
  `queryRef`, `nativeQueryRef`, filters, bookmarks), text-only, so CRLF / BOM are kept. Needed because
  `ReportFields.py replace` handles columns / levels only.
- Dry run by default; `--apply` backs up to the nearest `BackUp` (`MergeSemanticModel_<timestamp>`).
- Check afterwards: `ValidateTmdl.ps1 -Path <dst.SemanticModel>` (the folder loads) and
  `CheckReportRefs.py <dst.Report> --before <backup .Report>` (no NEW missing fields) — both below.
- **Desktop open on the target:** `powerbi-desktop reload` did **not** apply such a merge (ModelWork,
  2026-10-20: 88 measures + 8 tables + LoanData M). The first call timed out after 30 s; the second
  returned `success`, but the open model still had the old measure count (`INFO.MEASURES ()`), and each
  reload set `hasUnsavedChanges = true` — a Ctrl+S then would have written the old model over the merged
  files. Way that works: the user closes the file **without saving** and reopens the `.pbip`;
  then refresh (new calc tables, M changes) — by the user. Always check the live model after `reload`.
- ModelWork 2026-10-20 (`Model dev` → `Model`): 18 tables (8 new), 2 relationships, `Measure` = dev minus
  `Measure 2` plus `Total Loss % Cum Yr` / `DDC #` kept for visuals; 8 visuals renamed
  (`Early Default *` → `Default *`, `Interest Rate Avg` → `APR Avg`, `Net Chargeoff % Cum Yr2` →
  `Net Chargeoff % Cum Yr`). Result checked byte-for-byte against a hand-made merge.
