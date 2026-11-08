Project: SAP Business One + TSQL + Power BI

SQL formatting rules:
- commas before the column name, at the start of the line, with no indent before
  the comma; after the comma - one space before the column (", column"); the very
  first line of the list (without a comma) gets a two-space indent - so that
  the column names start vertically aligned (two spaces = the width of
  ", ")
- the space after a leading comma is mandatory: `, [C].[CardName]`, never
  `,[C].[CardName]`
- a column qualified with a table: the column and the table are both wrapped in [] for TSQL, e.g. [bd].[column]
- after END  always one space before AS, e.g. END AS [ReportType]
- if  WHERE contains more than one condition, add the 1=1 placeholder to the WHERE line, e.g. 
WHERE 1=1
AND [bd].[account] = 5
AND [bd].[sum] >4
- the ANDs under  WHERE must end at the same level (two spaces before AND)
Use 'AS' always before name of the object, e.g.  [bd].[DocTypeDoc] AS [DocType]
- align AS vertically relative to the lines above/below, where possible

When $ is used, do not add square brackets. E.g. $KEY([OSLP].[SlpCode])  - must be without square brackets.

- Columns without AS (bare identifiers) at the start of SELECT: the key column
  (e.g. ItemCode) - first, the rest - alphabetically.
- Columns with AS (not derived from CASE WHEN, i.e. plain/NULLIF-wrapped
  columns of a single table) - sort first by the order in which the table appears
  in FROM/JOIN (t1, t4, t6, ...), within one table - alphabetically by
  column name.
- If paired columns of different types are generated from the same list (e.g. ListNum 1..N)
  (e.g. price and currency via
  CASE WHEN) - group by type: first the whole block of one type (all
  _cur), then the whole block of the other type (all prices), rather than alternating pairs.
- In JOIN ON conditions - align the = sign vertically across all
  JOIN lines.
- In CASE WHEN [col] = N THEN - align THEN vertically (extra spaces
  after single-digit numbers so they line up with two-digit ones).
- Write function names in UPPERCASE (NULLIF, CAST, SUM, ISNULL,
  LTRIM, RTRIM, etc.).
- `<>` instead of `!=`.
- In a JOIN's `ON`: the reference (lookup) table — on the right, the driving/fact table —
  on the left.
- Power Loader **expands** SAP `$` macros (`$KEY`, `$COMPANY_ID`, `$DB`,
  `$SIGN`, `$LINE`, `$DOC`, `$CURRENCYLOCAL`) — not to be confused with plain SQL
  Server, where `$DB.OCRD` is invalid without expansion.
- `$DB` — only for native SAP tables (`OITM`, `OCRD`, `OSLP`, etc.).
  ETL tables (`ETL_SA_*`, `ETL_MD_*`, `ETL_ST_*`) — without the `$DB.` prefix,
  only `[dbo].[...]` or the short name. Mixing them is a frequent source of the
  `Invalid object name` error.

SQL content rules (queries for Power Loader / Power BI):
- **Change log in every query** (user, 2026-10-27): the header comment `/* ... */` names the table / task and ends with
  `Change log:` — one line per change, newest first: `YYYY-MM-DD  (N) what changed and why`. Add the line with the change.
- **No client names in shared queries** (user, 2026-10-26): `Power Loader\PROD\*.sql` without a client suffix serve all clients — no client names in the header, comments or code (`PowerLoader_<client>`, `<model>` as placeholders). Client facts (task numbers, which report uses it, history) go to `<Client>_Context.md`. Only client queries (`*_ClientB.sql`, `*_ClientC.sql`) carry the client name, and they live in a client subfolder: `Power Loader\PROD\<CLIENT>\` (`PROD\ClientB\`, `PROD\ClientC\`, since 2026-11-01); shared queries stay in `PROD\`. Some older refactoring scripts still read client queries from `PROD\` directly — fix the path when one is reused. **No version suffix** in PROD file / table names (since 2026-11-01): `ETL_SA_Sales_v3` → `ETL_SA_Sales`, `ETL_MD_Items_v2` / `_ItemProperties_v2` / `_CardProperties_v2` / `_Projects_v2` / `_Targets_v2` → without `_v2`; a change goes to the file's Change log, not into its name. Reports navigate to the unsuffixed table (ClientC Sales NEW + RAN NEW switched 2026-11-01).
- **Retention (user, 2026-11-01):** fact queries load the current year + 2 full years back:
  `AND [DocHeader].[DocDate] >= DATEFROMPARTS ( YEAR ( GETDATE() ) - 2, 1, 1 )` (sargable; not the Power Loader
  `$Param_$YearsBack`). Policy and Calendar range: `Refactoring.md` step 12.
- No `DECLARE` / variables. Queries are fixed, not parameterised; filters are
  hardcoded. When converting a SAP B1 user query, drop the B1 parameter
  syntax (`[%N]`, the commented `/*SELECT FROM ...*/` picker trick) together
  with every condition that uses the variable.
- No `ORDER BY`. Power Loader / Power BI do not keep row order, so it is
  wasted work. Drop it when converting existing queries. (`FOR BROWSE`,
  a B1 Query Manager trick, goes too.)
- No `ISNULL(x, 0)` / `COALESCE(x, 0)` on output columns — NULL is preferred in
  Power BI (missing ≠ zero). Keep NULL handling only where it changes logic,
  not presentation: inside arithmetic (`a - b` where `b` may be NULL),
  division guards (`NULLIF(x, 0)`), and `WHERE` / `JOIN` conditions.
- Column names (aliases) — in English, PascalCase, e.g. `AS [OnHandQty]`.
  The original Hebrew name goes into a trailing comment on the same line:
  `AS [OnHandQty] -- כמות במלאי`. Hebrew stays only as data (literals such
  as warehouse codes `N'מוקפא'`) and in comments.
- Name a column once. A column computed in a subquery / derived table gets its
  final name there; the outer SELECT references it without a new `AS`
  (`[T3].[OnHandQty]`, not `[T3].[TotalOnHand] AS [OnHandQty]`). `AS` in the
  outer SELECT only for columns computed there.

SQL Server version (2026-10-27):
- Shared PROD queries and scripts must run on SQL Server 2016 (ClientC `SAP-Server-1` = 2016 RTM, DB level 130).
  Not available before 2017: STRING_AGG (use STUFF + FOR XML PATH), TRIM (use LTRIM ( RTRIM ( x ) )), CONCAT_WS,
  TRANSLATE; before 2022: GREATEST / LEAST, DATETRUNC, GENERATE_SERIES. ORDER BY inside FOR XML PATH is allowed
  (it sets the list order, not row order).
- Check a server: SELECT SERVERPROPERTY ( 'ProductVersion' ) (13 = 2016, 14 = 2017, 15 = 2019, 16 = 2022) and
  sys.databases.compatibility_level (a 2017+ function also fails when the DB level is below 140).

SAP B1 data notes (2026-10-30, ClientB Inventory Coverage):
- Cancelled documents stay in SAP twice: the original (`CANCELED = 'Y'`) and its cancellation document (`'C'`). Sales,
  returns, receipts: read `CANCELED = 'N'` only.
- Net sales = invoices (`INV1`) − credit notes (`RIN1`); skip price-only credit notes (`RIN1.NoInvtryMv = 'Y'`, no goods back).
- Item cost may be absent: with `OADM.ContInvnt = 'N'` (no perpetual inventory) `OITW.StockValue`, `OITW.AvgPrice`,
  `OITM.AvgPrice` are 0. Stock value then needs a price waterfall (`OITM.LastPurPrc` → latest goods receipt PO `PDN1.Price`
  → purchase price list), foreign currency × latest `ORTT` rate (local currency `OADM.MainCurncy` = 1, no `ORDER BY`:
  `MAX(RateDate)` per currency + join). `OITM.LastPurPrc` is **not** updated by a goods receipt PO — new items can have
  stock and no last purchase price.
- Delivery / service items can be held as stock items with on-hand quantities (ClientB `הובלה…`, group 140) — check before
  using item counts.
