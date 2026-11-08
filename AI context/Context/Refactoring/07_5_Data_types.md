Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 5. Data types

- Double → **Currency** (Fixed decimal, 4 places; money, rates, factors) or **Whole number** (columns whose values are all
  integers - quantities, codes). Scan first: rounding loss `MAXX ( DISTINCT ( c ), ABS ( c - ROUND ( c, 4 ) ) )`.
  TOM `Column.DataType` + `ChangedProperty DataType` (keeps it after Power Query edits). The engine converts import
  data in place - no refresh needed (ClientB 2026-10-24). DAX tables: type the expression (`CURRENCY ( … )`) and set the
  column's `DataType`, then `Calculate`. ⚠️ A type set by a **TMDL text edit** needs `changedProperty = DataType` on the
  column too — without it the next refresh re-types the column from the source (SQL `DECIMAL` → double; ClientB
  `Inventory[StockValue]` 2026-10-30; fixed with `changedProperty` + an M typing step `Currency.Type`).
- **No `double`, ever** (user, 2026-10-27; BPA rule) — not even to fix precision. **No stored ratios:** a line share
  (`LIneFactor` = line / document total) at 4 decimals loses money (ClientB: 87.93 on the commission page). Compute the
  final amount in SQL instead — `PayNoVatLoc` / `PayNoVatSys` = document payment × line share ÷ (1 + VAT %), in
  `ETL_SA_Sales.sql` and `ETL_SA_DocsSales_ClientB.sql` (2026-10-27); measures = `SUM`; drop `VatX`, `IT_PayLoc`, `IT_PaySc`,
  `LIneFactor` and the EARLIER column `DocTotalTotal` from the model.
- Count measures → format `#,0` (whole numbers with a thousands separator); flags, averages, selector values excluded.
- Columns named `*Index*` → **Whole number**, Summarize by None (user, 2026-10-25; BPA `BP_INDEX_COLUMN_INTEGER`).
- **ID and code columns → Summarize by None** (user, 2026-10-28): keys, document IDs / numbers, SAP codes (`*ID`, `*Key`,
  `*Code`, `DocEntry`, `TransID`, territory / group codes), numeric or text — Desktop sets them to Count / Sum
  automatically (`SummarizationSetBy = Automatic`). Amounts and quantities keep their summarization. Before the change
  check that no visual aggregates such a column implicitly (`"Aggregation"` over the column in `visual.json`); if one
  does, give it an explicit measure first so the visual shows the same number.
- Date/time columns with no time part → **Date** (`UnderlyingDateTimeDataType = Date` annotation; `General Date`
  format → `dd mmm yyyy`). Metadata only. Columns that keep a real time (refresh timestamp) stay Date/time.
- Compare before / after: per-column SUM / rows / non-blank + the measure snapshot.
