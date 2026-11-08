Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 43. Data-freshness block top-right: 3 times + ⓘ tooltip (⚠️ RULE, all projects, user 2026-11-02 / 03)

Every report page shows, top right, when the data was last updated. Model: table `Date Last Refreshed` = SQL native
query from the template `Power Loader\PROD\BI_DataFreshness_Sales.sql` (project copy, e.g.
`PROD\ClientB\BI_DataFreshness_Sales_ClientB.sql`; not a Power Loader task), 3 columns, Israel time via `AT TIME ZONE` (M
`DateTime.LocalNow` = UTC in the Service): `Date Last Refreshed` (report refresh), `Power Loader Loaded` (last load of the
fact staging table, `sys.dm_db_index_usage_stats` — needs VIEW SERVER STATE), `Last Doc Entered` (last SAP invoice /
credit note). Stays in the refresh (step 39 exception). Measures in `_Measures`, hidden:
- `[Label Data Freshness]` (folder `Labels`): 3 lines `text: dd/MM/yy HH:mm`, `-` when a time is missing, He / En by
  `[Selected Culture]`. Labels En / He: Power BI Refresh / SQL load / Last Sales Doc = רענון Power BI (Power BI refresh) /
  טעינת SQL (SQL load) / מסמך מכירה אחרון (last sales document). He line = RLE … PDF (`UNICHAR` 8235 / 8236), date
  inside = LTR isolate (8294 / 8297); on screen the He line reads "text: date" left to right — accepted (user 03.11).
- `[Tooltip Data Freshness]`: what each time means + the refresh schedule (Israel time), He / En.

Source of the table + both measures: reference `DAX PRO Solutions\DataFreshness.json` (2026-11-03; fill the SQL
placeholders and the refresh times).

Report: on every page an `actionButton` (text = `[Label Data Freshness]`, all states set, no visual tooltip) and right of
it the ⓘ icon `InfoDataFreshness` = button slicer on `CT_BlankTable[Info]` (step 42), white, `visualTooltip` → page
`TTDataFreshness` (tooltip page 650 × 250, hidden; one `actionButton` filling the page, text `[Tooltip Data Freshness]`,
padding 15 top / bottom **local on that button, never in the theme** — `PBIP_Theme.md`). Position (1280 px page,
Sales_ClientB page 1, user 03.11): button x 1085.5, y 0, 172.8 × 50; icon x 1260, y 13, 20 × 20; 1920 px pages ×1.5. Copy the
position from one page set by hand to all pages by script. Replaces old "last update" cards / text boxes (delete them,
re-point bookmarks).
After 42 and 24 (icon recipe), before 22 (colors come from the theme). Check: script — every page (not tooltip pages)
has both visuals at the agreed position; the measures and the SQL table exist, `[State] = 1`.
ClientB `Sales_ClientB`: ✅ 2026-11-02 / 03 (19 pages; `ClientB\ClientB_History.md` → "Data freshness").
