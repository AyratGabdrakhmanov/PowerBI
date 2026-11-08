Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 15. Sales Channels measure pattern (all projects, user 2026-10-28)

Reference: Sales Channels (`Agency\Fitness\ClientF\Sales Channels`) and ClientB (`ClientB\ClientB_Context.md`, item 21).
1. **Selectors by ID:** **every** `CT_` selector — `CT_Currency` (`CurrencyID` 1 Local / 2 System), `CT_DocStatus` (1 Open / 2 All),
   `CT_TransactionDateType` (`DateTypeID` 1 Doc / 2 Due / 3 Tax Date), `CT_MeasureType`, … — gets `<X>ID` / `<X>_He` / `<X>_En`
   in the Sales Channels layout, also when it is already keyed by an index (`DateTypeInx` → `DateTypeID`) or not on any page
   (user 2026-10-28); + the UserContext display column once the model has `CT_Language` (step 9). `[Selected_*]` return the ID
   with a default; measures compare IDs; slicers / filters on `_He` (saved values unchanged) and bookmarks re-pointed.
   **`CT_DocumentType`** (user 2026-10-28) — the full Sales Channels table, **29 rows** (all SAP object types: 6 sales,
   purchases, payments / deposits, journal entry, stock, opening / closing balance -2 / -3), copied from
   `Sales Channels.SemanticModel\definition\tables\CT_DocumentType.tmdl`; layout `DocumentTypeCode` (Whole number) /
   `DocumentType_He` / `DocumentType_En` / `DocumentTypeID`, relationship `Sales[DocIntType]` (Whole number — a type change,
   converted in place, no refresh) → `CT_DocumentType[DocumentTypeCode]`. Old layouts to replace: `TransType` (text) /
   `DocumentType` / `E_TableName`. Every document-type slicer gets the visual filter `[Show Existing Sales] = 1` (only
   types that occur in the data are listed); saved selections / filters / bookmarks → `DocumentType_He` (Hebrew values
   unchanged); measures that test codes (`TransType = "13"`) → `DocumentTypeCode = 13 /* A/R Invoices */`.
2. **Sales measures:** `SalesValue` / `Profit` / `Quantities` in the Sales Channels pattern — inline `SELECTEDVALUE` of the
   IDs, guard-divide branches over the `*_BySelectedDate` base measures, `__Result * DIVIDE ( __Result, __Result )` instead of
   `IF ( x = 0, BLANK (), x )`. Without Sales Channels' `ROUND ( …, 2 )` (it blanks near-zero customers, ClientB 2026-10-25).
   **One UDF for the selector pattern** (user 2026-11-02): the currency × doc status × date type branches live in
   `Sales.BySelectors ( localAll, systemAll, localOpen, systemOpen : EXPR )`; `Sales Data` / `Profit Data` (and every other
   amount with the same selectors) = one call with four `SUM`s. **Date type = the whole document by one date** (SAP logic:
   Posting / Due / Document date filter all amounts) — sales and profit both follow `CT_TransactionDateType` via
   `USERELATIONSHIP` on `DueDate` / `TaxDate`. Script / reference: ClientF Sales v2 `Refactoring\SelectorUDF.py`.
3. **Check:** every measure × every selector state × total / doc type / month equal before and after.
Does not need step 7 (works on the existing base measures).
