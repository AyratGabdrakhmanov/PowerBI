Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## Sales_ClientB — step 2 findings (2026-10-24)

Legacy M `Date` already swapped on 2026-10-18. Left:

- **2a ✅ `'Dates - Period B'` → `'Calendar Comparison'`** = `CALCULATETABLE ( SELECTCOLUMNS ( 'Calendar', "Date",
  'Calendar'[Date] ), 'Calendar'[Year ID] <= 0 )` (was `SELECTCOLUMNS ( FILTER ( 'Calendar', … ) )`; rule
  `BP_CALCULATETABLE_NOT_FILTER_TABLE`, 2026-10-28) — up to 31 Dec of the current year (user: no future dates)
  (only `[Date]` is used: 3 `ComparativeIndex_PeriodB*` measures, 6 slicers, 7 bookmarks — all re-pointed; was
  `CALENDAR ( MINX DocDate, MAXX DueDate )` + 12 unused `FORMAT` text columns). Inactive 1:1 both-directions
  relationship from `Calendar` — removed 2026-10-24: the 3 measures use
  `TREATAS ( VALUES ( 'Calendar Comparison'[Date] ), 'Calendar'[Date] )`, the table is disconnected. Values equal before / after. Gotcha: removing columns via TOM fails while culture
  translations reference them — remove those first.
- **2b ✅ `DocsPurchs[DocDate]` / `[DueDate]`:** matrices Page17 `Charges3`, Page18 `pivotTable10`, hidden Page2
  `Charges`, Page8 `Charges2` — row levels under `DocNum` (per-document), kept. Page17 (settlement detail) filters by
  two dates at once: "תקופה" = `Calendar[Date]` (document date, active) + "תאריך ערך" `slicer141` (due date). So the
  due date got its own role-playing calendar (user, 2026-10-24): **`'Calendar Due Date'`** =
  `SELECTCOLUMNS ( 'Calendar', "Date", 'Calendar'[Date] )`, active `DocsPurchs[DueDate] → 'Calendar Due Date'[Date]`;
  `slicer141` re-pointed + visual filter `[Show Existing DocsPurchs] = 1` (new measure, 148 due dates listed).
  Values equal to filtering the fact column. Backup `ClientB\BackUp\DueDateCalendar_2026-10-24_203905`.
- Both copies marked as date tables + descriptions (BPA). Main `Calendar` stays to 2029: due dates run to Feb 2027
  (99 purchase rows) and Jun 2028 (84 sales rows).
- **2c ✅ DAX:** `SalesVal_LY_YTD_Partial`, `SalesVal_LY_MTD_Partial` → `'Calendar'[Closed Period] = TRUE ()`;
  `Sales Last Period`, `Last Date On Previous Period` → `'Calendar'[Today] = TRUE ()` + `REMOVEFILTERS ( 'Calendar' )`
  ("today" = the date of the last refresh, not the query date). Values equal before / after. Kept: `New1 Customers`,
  10 `DATESMTD` measures.
