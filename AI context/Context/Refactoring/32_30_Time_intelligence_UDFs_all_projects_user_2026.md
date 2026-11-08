Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 30. Time-intelligence UDFs (all projects, user 2026-10-31)

Source: `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\DAX PRO Solutions\TI_UDF.tmdl` — 46 `TI.*` functions:
13 comparisons (absolute `TI.<name>` + % `TI.<name>Pct`) and their 20 building blocks. Tested source and checks:
`DAX PRO Solutions\TI UDF Sample\` + `Scripts\TI_Checks.dax` (105 checks). Rules, catalog, gotchas: `Context\PBIP\TI_UDF.md`.
- **Needs:** `'Calendar'[Date]` marked as date table, fact relationships on `Calendar.Date`, compatibility level 1705
  (a model at 1606 needs the upgrade first — user decision).
- **Apply:** closed PBIP → `definition\functions.tmdl` = the script without the `createOrReplace` line and one tab of
  indent (no `ref` in `model.tmdl`, no refresh); open model → paste the script into TMDL view.
- **Check:** `INFO.USERDEFINEDFUNCTIONS ()` — every `TI.*` `[State] = 1`; one comparison per pattern = the same value
  computed by hand on a base measure (e.g. `TI.YOY` = month − same month last year).
- Formats: functions carry none — absolute `+#,##0;-#,##0`, % `+#,0%;-#,0%;0%` on the measure.
