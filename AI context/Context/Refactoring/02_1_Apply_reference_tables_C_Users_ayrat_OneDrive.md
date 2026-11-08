Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 1. Apply reference tables (`C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\DAX PRO Solutions\`)

Merge as an addition: keep what the report has (columns, measures, hierarchies, sort-by, names used by visuals),
add what is missing; change existing objects only with the user's agreement.

- **1a. `Calendar` ← `Calendar.json`** (approach: user, 2026-10-26). The project's `Calendar` partition holds the
  **FULL reference DAX** (every column definition, `VAR`s, comments). **All columns are optional except the hierarchy
  level columns, `Date` and `Closed Period`**: a column the project does not use stays in the DAX but **commented out**
  (`-- ` on each of its lines inside `ADDCOLUMNS`), and its column object is not in the table. Turning a column on =
  uncomment its lines + add the column (format / folder / sort-by from the reference). Optional reference columns such
  as `Month Year Current` (current month = `חודש נוכחי` / `Current Month`) are added the same way, only where needed.
  Flag `Year To Date` (INT 1 / 0, 1 Jan → today of the current year; reference 2026-11-01) = one hidden page filter for a
  page that must always show the current YTD (ClientC `דוח יעדי סוכנים` (Agent targets report)) instead of a saved month list.
  `Month Year Current` language = `VAR __Language` in the table DAX, not per viewer (`USERCULTURE ()` / userContext):
  saved slicer filters hold the Hebrew label, so an English-UI viewer would get blank visuals (user, 2026-10-29).
  "Used" = DAX anywhere, report fields / saved filters / bookmarks (Entity or `From` alias), relationships, sort-by
  of a kept column, hierarchy levels. Tool: `Scripts\TrimCalendar.py "<project>" [--apply]` (closed PBIP; dry run
  lists kept / commented columns). Keep hierarchies, level names (NBSP, `_` prefix — `BP_HIERARCHY_PREFIX_UNDERSCORE`),
  `dataCategory: Time`, `Date` key. Project extras (e.g. ClientB `Today Date`) stay. `Calculate` after opening.
- ⚠️ **+1 forward year and "current year = MAX ( Year ID )" logic** (ClientF Sales v2 2026-11-01): calc items / measures that take
  the current year as `MAX ( 'Calendar…'[Year ID] )` over an unfiltered calendar get the forward year (+1) and return blank.
  After 1a, grep the model for `MAX ( 'Calendar` + `Year ID` / `Month ID` / `Quarter ID`; for a comparison copy limit it to
  `'Calendar'[Year ID] <= 0`, and build tables related to that copy from the copy (else a "(Blank)" member appears).
- **1b. `_Measures` ← `MeasuresTable.json`:** `#table({},{})` partition, `excludeFromModelRefresh`, annotations
  `PBI_ResultType = Table` / `PBI_NavigationStepName = Navigation`; skip `Test Measure`. Missing → create via TOM;
  client reports → rename an empty `#table` (gotcha #28). Never delete `Color` measures.

- **1c. Parameters + query groups ← `Parameters.json`** (user 2026-10-27): `Server` / `DB` text parameters (group
  `Parameters`), query groups `Parameters` (0) / `Fact` (1) / `Dimension` (2); set the client values, then every
  `Sql.Database("<server>", "<db>"` → `Sql.Database(Server, DB` and each M query into Fact or Dimension. Closed-PBIP
  implementation: `Refactoring\ClientB\model_conventions.py` (ClientB 2026-10-27).
- **1d. `CT_Language` ← `CT_Language.json`** (user 2026-10-30; He / En reports only): hidden `DATATABLE` table
  (`Language_long` / `Language` / `Culture`) + hidden `[Selected Culture]`; `Calculate` after adding; the file's
  `reportFilter` block goes into `report.json` → `filterConfig.filters` (default `'He'`, single select). Column
  headers = culture captions (step 23).
