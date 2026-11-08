Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## Sales NEW (ClientC) — steps 1–3 (2026-10-26)

Server unreachable all day: Desktop Save was blocked by "pending changes in your queries" (Excel / join removals and
the deleted M `Date`), so every model step was written to the PBIP by **serializing the live model**
(`TmdlSerializer.SerializeDatabaseToFolder` → copy into `definition\` except `database.tmdl`, which would get the
workspace id; files of deleted tables moved to the backup — `Scripts\SyncTmdl.py`) → `ValidateTmdl.ps1` → `powerbi-desktop reload` (Desktop
then shows "project's files were changed externally" — the files equal the live model). `cache.abf` is not
rewritten this way: after the next open, run `Calculate` on the DAX tables added since 10:28 (`Calendar Comparison`,
`CT_*`). Backups `ClientC\BackUp\Refactor_Start_2026-10-26_102203` (whole project) + one folder per step.

- **1a** `Calendar` = `Calendar.json` + new reference column **`Month Year Current`** (user 2026-10-26: the current
  month is a fixed label — `VAR __Language = "He"` (default) / `"En"` → `חודש נוכחי` / `Current Month`; other months
  `FORMAT ( [Date], "mmmm yyyy", he-IL / en-US )`; sorted by `Month SortBack`). Replaces the old dynamic
  `IS MONTH`, so slicers saved on the current month keep moving.
- **1b** `KeyData` (empty "Enter data" M, 98 measures) renamed `_Measures` (gotcha #28); 5 measures with
  `KeyData[…]` refs rewritten; report `MoveMeasureRefs.py --whole-table`.
- **2** M `Date` (2002 – Oct 2027, Hebrew text columns) → `Calendar`; `Dates - Period B` → `Calendar Comparison`
  (disconnected, `TREATAS` in `ComparativeIndex_PeriodB`). Map: `Year` (text) → `Year` (int, `'2026'` → `2026L`),
  `IS MONTH` → `Month Year Current`, `MonthName` → `Month Name`, `QuarterName` → `Quarter Name`,
  `MonthInCalendarName` / `FirstDayOfMonth` → `Month Year`, `Show This Year` → `Year ID = 0`, `Show Months` →
  `Current Month`, `Show This Quarter` → `Current Quarter`. No visual compares months across years, so no
  year-less month column was kept (user). Year-less saved months got the year saved next to them (stale 2021
  bookmarks → 2021). Literal conversion is **structural** (only conditions on the swapped columns: `'יוני'` is also
  the agent Yoni) and position-exact; 219 literals type-checked. ClientC working days = Sunday–Friday (old
  `IsWorkingDay`), kept inside `CountWorkingDays` — not `Calendar[IsWorking]` (Fri + Sat). ⚠️ A `CALCULATE` filter on
  `'Calendar'[Date]` of a marked date table drops every other Calendar filter (year) — count with `FILTER`.
  Values equal for 2023–2026 except "till today" measures (old `IsHistory` froze at the last refresh, `Closed
  Period` follows `TODAY ()`); totals without a date filter differ by range (2002–2027 vs 2023–2029). The old M
  `Date` stays as a not-loaded expression (gotcha #29) — delete at the next client refresh.
- **3** "Enter data" M → DAX (`EnterDataToDax.ps1`), then `CT_`: `CT_DateType`, `CT_DocumentTypes`,
  `CT_CurrencyType`, `CT_MeasureType`, `CT_OpenAll`, `CT_TopN`, `CT_Period`, `CT_SelectedPercent`,
  `CT_AgentCompare`, `CT_CardAgents`, `CT_GroupAreas`, `CT_Family`, `CT_ItemPareto` (ex `Aggregate`).
  `Compare Period` (10 measures) and `Aggregate`'s 2 measures → `_Measures`. DAX renamed token-aware (`[…]`,
  strings, comments skipped). ⚠️ `MoveMeasureRefs.py --whole-table --from Tbl_Family` also renamed the **column**
  `Items[Tbl_Family.קבוצת אב סופית]` (402 `Property` strings, the "old table name + dot" gotcha) — reverted; run
  `--whole-table` only for tables whose name is not a prefix of other columns.
- **5** Currency: `DocsSales` amounts / profits / VAT / discount / payments / `QtyFactor` + calc `DocTotalTotal`,
  `LIneFactor`; `Customers` `CreditLine` / `Balance` / `DebtLine`; `Items[IONHand]`; `Salespersons[CommissionRate]`;
  `Targets` / `TargetFamily[DailyTarget]`. Whole: `DocsSales` `Quantity` / `OpenQty`, `CT_DocumentTypes[Custom]`;
  `*Index*` Summarize None. Date: `Customers[CardCreatedate]`, `[First Order]`, `[Last Order]`, `Items[CreateDate]`.
  Column sums equal (≤ 2e-7). **`Items[PriceList]` stays Double** (unit price, up to 8 decimals × quantities up to
  250,000 in the cost measures). Measure differences, by design: ratios of Currency inputs come back with 4 decimals
  (`Target Achivment` 14.8634154 → 14.8634, `avgDisc` 0.53015 → 0.5302 — invisible at `0.0%`);
  `AvergePerCustomer` +0.2% (`AVERAGEX ( Customers, [SalesValue] )`: customers whose lines net to exactly 0 now give
  BLANK instead of a 1e-10 float residue, so they leave the average); `CostValueTest` / `OpenCostValueTest` /
  `TestCostValue` / `TEST11` / `TEST12` (test measures): their `SalesVal > 1 || < -1` filter loses rows at ±1.0000x.
  Not changed: `Date Last Refreshed` (real time), `CT_SelectedPercent` (what-if, typed slicer literals),
  `CT_ItemPareto` (unused → step 4).
- **6** (closed PBIP, user 2026-10-26: "work with closed pbip by default") — offline TOM:
  `TmdlSerializer.DeserializeDatabaseFromFolder` → move → `SerializeDatabaseToFolder` (temp) → sync into
  `definition\` (skip `database.tmdl`, `cultures\*.tmdl`) → `ValidateTmdl.ps1`. 39 measures (`Targets`,
  `TargetFamily`, `CT_*`, `Companies`, `Date Last Refreshed`) → `_Measures`; report `MoveMeasureRefs.py` per table
  with explicit names. ⚠️ A measure moved out of its table loses **bare column references**: `Targets = SUM ( [Target] )`
  failed in `_Measures` (+ 7 dependents) — qualify `[Col]` of the old home table before moving (fixed:
  `SUM ( Targets[Target] )`, `SUM ( TargetFamily[Target] )`).
- **4** `CleanUnused.ps1 -RootPath` (closed): 38 measures (incl. broken `Measure 2`, `TEST*`, `Cost*` test measures),
  8 calc columns, tables `ProfitCenter1–5`, `Projects`, `CT_ItemPareto`, `CT_SelectedPercent`, 11 bookmarks,
  147 hidden visuals, Q&A schema. ⚠️ It deleted `Customers[קוד סוכן]` and `Items[Tbl_Family.קוד אב]` — calculated
  columns used **only as relationship keys** (`TargetFamily[SLPCode]` / `[GroupItem]` → family targets by agent /
  family): relationship-only use counts as unused. Restored from the backup with their relationships. Missing report
  fields 12 → 1 (`Customers[CustomeGroup]` in 2 old bookmarks).
- **Final check** (PBIP reopened, port of the new instance): 0 objects in error; 24 tables, 113 measures, 15
  relationships; values vs the start baseline (2023–2026) differ only as explained in steps 2 and 5; BPA 1059 → 731
  (391 fixed; 63 "new" = reference `Calendar`, disconnected `CT_` selectors, `Month Year Current`,
  `USERELATIONSHIP` false positive, 2 `CT_GroupAreas` agent columns kept until the client decides area targets).
  `Projects` is gone, so `Project_KEY` is not needed in `ETL_SA_Sales.sql` any more.
- **1a trim** (full reference DAX, unused columns commented; `TrimCalendar.py`, 2026-10-26): ClientC 29 → 14 columns,
  ClientB `Sales_ClientB` 27 → 14 (incl. its unused `Month To Date`). ClientB also needed its he-IL / en-US captions of the removed
  columns dropped (a dangling translation blocks the model load) — the tool does it now. Both reopened: 0 errors, ClientB
  0 missing report fields, ClientC values identical.
- **9** (closed PBIP; scripts `ClientA\_Documentation\Refactoring\ClientC\Translation\` — `captions_ClientC.py` / `.json` (282 objects),
  `apply_captions.ps1` (offline TOM: `CT_Language`, `[Selected Culture]` in `_Measures` (hidden, folder `Labels`),
  culture he-IL + en-US captions), `report_language.py` (report filter `CT_Language[Language] = 'He'`, rule 5)).
  he-IL = most used manual visual name, else our translation; context names (`תקופה א` on the period slicers) stay on
  their visuals. 772 `displayName`s equal to the he-IL caption removed (250 visuals) — Hebrew viewers see the same
  text, English viewers the en-US caption. ⚠️ A table and its column with the same name (`Date Last Refreshed`) share
  one `(table, name)` key — keep the table caption apart. Not done yet: slicer titles from language measures (rule
  2026-10-21), column **value** translations (`USERCULTURE`), 325 visual names that differ from the caption (210 visuals; they override the caption in both languages).
- **9, round 2** (user 2026-10-26: "do what is not conflicting with existing data"; "slicer VALUES stay Hebrew"):
  - Visual names: only exact caption matches removed (+15 `DocsSales[Quantity]` "כמות" inside `Sum(...)`); the
    other differing names wait for ClientC — review file `Refactoring\ClientC\Translation\ClientC_Translation_Review.xlsx`.
  - Slicer titles: 205 literal titles → hidden `_Measures[Slicer …]` (22, folder `Labels`, He text unchanged, En
    added); header / alignment untouched.
  - Column values: **per-viewer columns** (`expressionContext: userContext`, compatibility level **1705** — raised from
    1606, as ClientB) `<X> Display` (hidden, same captions as X) = `SWITCH ( culture, X, X_En )`; `X_En` = `LOOKUPVALUE` in
    hidden `CT_ValueTranslation` (Key / He / En, 380 rows; missing value → Hebrew). Slicers, page / visual filters
    and bookmarks stay on the Hebrew X (their saved literals keep matching); only the display fields of visuals with
    no literal condition on X (own or in a bookmark, all copies of the visual name) are repointed
    (`Translation\display_targets.py` → `ReportFields.py replace --visuals`). Columns: `Customers[סוכן]`,
    `[תת שיוך]`, `[CardGroup]`, `Salespersons[SalespersonName]`, `[סוכן מסמך]`, `Items[ItemGroup]`,
    `[Tbl_Family.קבוצת אב סופית]`, `CT_DocumentTypes[DocumentType]`.
  - Result (reopened): 0 objects in error; values identical; 8 columns repointed in 343 visual / bookmark files, 0 saved
    literals on any `… Display` column, 0 slicers on them. ⚠️ Per-viewer columns follow the viewer's **UI / browser
    language** (`USERCULTURE`), not the `CT_Language` switcher — a Hebrew user with an English Power BI UI sees English
    values in those visuals. ⚠️ `AVERAGEX ( Customers, … )` over a table that holds per-viewer columns failed at the
    grand total ("An unexpected exception occurred") — iterate the key: `AVERAGEX ( VALUES ( Customers[BP_Key] ), … )`
    (`AvergePerCustomer`, `VarietyPerCustomer`; values identical).
- **Open items, 26.10 after the client refresh** (report saved as PBIP by the user, data to 25.10): not-loaded M `Date`
  removed (`ClientC\remove_expression.ps1`); last stale bookmark field (`Customers[CustomeGroup]` in 2 matrix expansion
  states → `CardGroup Display`) — report fields missing 0. `Doc_BPCode` / `Doc_ItemCode` → `Customers[CardCode]` /
  `Items[ItemCode]` (0 differing lines of 493,666; `Items[ItemCode]` he-IL caption → `קוד פריט`, the 2 old fields
  pinned `מס' פריט`); `VareityPerItem` = `DISTINCTCOUNT ( DocsSales[Item_KEY] )`. **Names stay on `Doc_BPName` /
  `Doc_ItemName`**: they are the names printed on the document (120 customers / 389 items differ from the master,
  e.g. renamed later) — ClientC decides; until then Sales v3 must output them.
- **Allocation back to the original (user 2026-10-26: "as it was at the beginning, client did not confirm any change in
  data allocation, except new excel file"; Yossi "according to excel"):** `Customers[סוכן]` / `[קוד סוכן]` = area
  agent / code from `CT_GroupAreas` (the Excel area table — the file in `ClientC\Excel Files\` equals it), not the SAP
  card agent of 22.10. Restored from backups by `ClientC\revert_area_report.py`: 37 agent / team filters (pre-22.10,
  incl. the original team name lists → **step 10 reverted**, `Team` / `Manager` removed), 24 invoice-agent slicer
  selections (pre-25.10), page `דרור` → `יוסי`; pages `השוואת שיוך סוכנים`, `כפיר (לפי מסמך)` hidden. Kept: refactoring
  1–6, calendar, He / En, month slicers on the current month, bookmark `suppressData`, codes from the dimensions,
  names as on the document. Check: Kfir 1–21.10 = 445,554.09 (= the area figure of 25.10); 0 errors.
