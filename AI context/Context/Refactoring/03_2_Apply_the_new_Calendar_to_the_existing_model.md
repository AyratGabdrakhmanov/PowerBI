Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 2. Apply the new Calendar to the existing model

Each item listed per report and agreed before applying.

- **2a. Legacy date tables** (M / DAX, `LocalDateTable_*`): relationships → `Calendar`, rewrite DAX, re-point
  visuals / filters / bookmarks, delete. Recipe: `PBIP_Recipes.md` "swap a legacy date table".
- **2b. Fact date columns as time axes / slicers** → `Calendar` (+ `USERELATIONSHIP` for inactive dates). When a
  page filters by two dates at once, the second date gets its own calendar
  (`SELECTCOLUMNS ( 'Calendar', "Date", 'Calendar'[Date] )`, active relationship) instead. Per-document dates stay.
- **2c. DAX duplicating `Calendar`** (`<= TODAY ()`, own MTD cut-offs) → flags / IDs (`Closed Period`,
  `Month To Date`, `Year ID` …); values compared before / after.
- ⚠️ **Saved slicer selections and visual date filters must move too** (ClientB 2026-10-25, found only by comparing the
  reports a viewer sees): repointed fields kept their old literals — `'4 - 2026'` on the date column
  `Calendar[Month Year]` (must be `datetime'2026-04-01'`), and some selections / date ranges were dropped (Page3 /
  Page4). Desktop silently skips a selection that matches nothing → the visual shows all data. After the swap, diff
  `objects.general.filter` + `filterConfig` against the backup (literal types must fit the new column) — a values
  snapshot of measures does not catch it.
