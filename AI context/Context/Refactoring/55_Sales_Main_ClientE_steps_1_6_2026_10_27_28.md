Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## Sales Main (ClientE) — steps 1–6 (2026-10-27 / 28)

Same template as ClientC. Scripts `Refactoring\ClientE\` (README there); baseline + snapshots
`ClientE\BackUp\Refactor_Start_2026-10-27_231701\`.
- **1a + 2** (closed files, `calendar_ClientE.py`): M `Date` → `Calendar`, `Dates - Period B` → `Calendar Comparison`
  (`TREATAS`), 10 `LocalDateTable_*` + template removed, Auto date/time off. Map: `Year`, `MonthName` → `Month Name`,
  `QuarterName` → `Quarter Name`, `MonthInCalendarName` → `Month Year` ('אוק 2026' → date), `QuarterInCalendar` →
  `Quarter Year`, `Show This Year` → `Year ID = 0`, `Show Months` → `Current Month`, `IsHistory` → `Closed Period`,
  `IsWorkingDay` (Sun–Fri) inside `CountWorkingDays`; label cards `*.yearR` → standard columns (user); the
  "same month last year" cards → new `[Month Year PY]`, `[Last Quarter.yearR]` = same quarter last year (`yyyy Qn`; the old one
  used today's quarter). Values 2024–2026 by year equal, except 2024 working days 313 → 314 (old table started at the first
  document) and "till today" (old `IsHistory` froze at the refresh). Totals / 2027+ differ by range (old table ended Oct 2026).
- **1b, 3, 6** (live TOM): `KeyData` → `_Measures`, `Doc_ItemName` → `Sales`, `CardProperties` → `CustomerProperties`;
  "Enter data" → `DATATABLE` (`EnterDataToDax.ps1`); `DateTypeTbl` → `CT_TransactionDateType`, `DocumentTypes` →
  `CT_DocumentType`, `DynamicSelected_*` → `CT_Currency` / `CT_MeasureType` / `CT_DocStatus`, `Period` → `CT_Period`,
  field parameters → `FP_LeadingSales_View` / `FP_Agent_View` / `FP_Comparative_Level` / `FP_SalesWorld_View`
  (columns `FP` / `Fields` / `Order`); all 25 measures → `_Measures`; `Compare Period`, `Aggregate` deleted. Values identical.
- **4**: nothing unused (cleaned 06.10) except `Date Last Refreshed` (no visual; fed only an auto date table).
- **5**: 30 Double → Currency (incl. non-integer quantities), 8 date columns → Date `dd mmm yyyy`, `*Index*` Summarize None.
  By design: `AvergePerCustomer` +0.13 %, `AvergePerDoc - No zero deals` +0.01 % (lines netting to exactly 0 give BLANK, no
  float residue).
- **Result**: 21 tables, 95 measures, 11 relationships, 0 objects in error, 0 missing report fields; BPA 908 → 594 (36 "new" =
  reference Calendar / disconnected `CT_` / rename false positives / step 7).
- ⚠️ **Closed-file edits drop cached import data:** a renamed import table, or any change to an M partition's text (incl. a
  `queryGroup` line or a parameter swap in a query it merges), opens **empty** until a refresh. Rename import tables live (TOM),
  and leave M edits (1c, Power Query = navigation) for the phase that is refreshed anyway.
- ⚠️ **A live TOM table rename does not fix DAX references** (89 objects in error) — `Refactoring\ClientE\rename_dax_live.ps1`
  rewrites them (token-aware, skips "strings" and [names]); then `rename_model_objects.py` for the report only (check its model diff).
- ⚠️ `rename_model_objects.py` before 2026-10-28.1 renamed a table name **inside other quoted names** (table `Period` →
  `'Sales Last CT_Period'`, 9 measures) and in `///` descriptions — fixed; still diff the model after every run.
- **Label cards:** the "same month / quarter last year" labels must follow the selection (`[Month Year PY]`, `[Last Quarter.yearR]`
  from `MAX ( 'Calendar'[…] )`), not `TODAY ()`. Month names show in English (`mmm`, model culture en-US).
- **9 (measures only, 2026-10-28)**: he-IL + en-US captions on the 83 visible measures (live TOM; `captions_measures_ClientE.py`),
  report rules 3 + 5 (`report_measure_names.py`: 50 manual names = caption removed, 49 fields pinned to the model name, 22
  kept; He text before = after). Desktop shows model names, so removed names show as `SalesValue` there — the Service shows
  the caption. Open: columns / tables, `CT_Language`, slicer titles, field-parameter rows.
- **11 / 12 (prepared 2026-10-28)**: table ↔ report map, keep-list draft, Service alert clicks, monthly update due, DQ note,
  retention facts + proposed policy — `ClientE_Context.md`; RDP run list `ClientE\PowerLoader\RDP_Checks_Step11.md`.
