Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 52. No forecast → `Closed Period` at report level (⚠️ RULE, all projects, user 2026-11-05)

Report-level filter `'Calendar'[Closed Period] = TRUE` (hidden + locked; one place, no page-level copies): future days
/ months never appear in slicers, axes or tables. Before applying, check the model for what really reads future
Calendar rows:
- **Target / budget tables with a relationship to `Calendar`** → a year's plan would lose its future months → no report
  filter; page-level only on pages without such measures (`ClientC\Sales New\Refactoring\Step52_ClosedPeriodPages.py`,
  dependency closure over the TMDL). Targets **without** a Calendar relationship (ClientC `Targets` / `TargetFamily`:
  `SUM`, linked only to customers / agents / items) are not affected — not a reason to skip.
- **"Remaining days" measures** (working days of the month − till today) → make them ignore the date-limit filters:
  `CALCULATE ( COUNTROWS ( FILTER ( 'Calendar', <working day> ) ), REMOVEFILTERS ( 'Calendar'[Closed Period],
  'Calendar'[Year To Date] ) )`, and the "till today" one = the same with `&& 'Calendar'[Closed Period]` inside the FILTER
  (not a CALCULATE filter — the REMOVEFILTERS would drop it). Check the daily balance with / without the filter by DAX.
- `NEXTMONTH` / `NEXTYEAR` / positive `DATEADD` / `> TODAY ()` windows → real forecast → page level only.
ClientC `Sales NEW` 2026-11-05: first page-level (7 pages) because of the daily target balances; then (user) the
working-day measures fixed (daily balance 90,032 with month only / + Year To Date / + Closed Period — it was **blank**
before on `דוח יעדי סוכנים`, whose `Year To Date` page filter had the same effect) → **report level**, the 7 page copies
removed; no future-date DAX in the model.
