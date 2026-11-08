Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 12. Retention policy check (all projects, user 2026-10-27)

How much history each report keeps, and that every layer agrees. Record the agreed policy in the project context file.
- **Need:** the oldest period any page / bookmark / saved filter shows (saved year filters older than the data =
  stale pages; ClientC RAN NEW: year filters 2019–2023, data from 2024).
- **Load:** the SQL date filters (11a "Rows") load exactly that history (hardcoded, not Power Loader `$Param_$YearsBack`).
- **Model:** `Calendar` range (reference: 2 years back / 1 forward) covers the data; no fact rows outside it.
- **Service:** incremental refresh / archive partitions if the history is large; how long old snapshots / exports
  (`BackUp\` folders, Excel extracts) are kept.
- Agree the policy with the client (years kept, closed periods frozen or reloaded) before changing any filter.
- **Policy (user 2026-11-01, replaces 2026-10-28 "current year + 3 back / 3 forward"):**
  - **Facts:** current year + 2 full years back (from 1 Jan of TODAY year − 2; 2024-01-01 in 2026). Fact SQL filters
    `[DocHeader].[DocDate] >= DATEFROMPARTS ( YEAR ( GETDATE() ) - 2, 1, 1 )` — `PROD\ETL_SA_Sales.sql`,
    `ETL_SA_DocsSales_ClientB.sql`, `ETL_PU_Purch_ClientB.sql` (was `$Param_$YearsBack`). No upper limit (future-dated documents stay).
  - **Calendar:** history = the same 2 full years back; + 1 full year forward for forecast / targets (window TODAY year
    −2 … +1, 2024–2027 in 2026). Reference `Calendar.json` and every project copy: `DATE ( YEAR ( __TodayDate ) - 2, 01, 01 )`
    … `DATE ( YEAR ( __TodayDate ) + 1, 12, 31 )`; after the TMDL edit open the PBIP → TOM `RequestRefresh(Calculate)` → save.
  - Applied 2026-11-01: ClientB (Sales_ClientB, Inventory Coverage), ClientC (Sales NEW, RAN NEW). Other projects keep −3 / +3
    until the policy is applied there (status table, column 12).
  - Saved years / dates outside the window in slicers, bookmarks, page / visual filters are stale: move them by whole
    years to the latest year in which every selected month has started (period A / B pairs move together → previous
    vs current year; a full-year selection → last full year); exclusion lists drop the stale years; a bookmark slicer
    state with a stale year gets the visual's saved state. Script: `Scripts\RetentionStaleDates.py` (generic, 2026-11-01);
    the earlier ClientC-only `Refactoring\ClientC\step18_followup.py` also saved empty month slicers on `חודש נוכחי`.
