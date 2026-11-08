Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: report translation En / He (2026-10-18)

### ⚠️ RULE: culture translation by default, no renaming in visuals (user, 2026-10-21)

Field names are translated in the **model** (cultures), not by renaming fields in visuals:
- every visible measure, column and table gets an **he-IL** caption and an **en-US** caption with the
  business name (`On Hand #` → "On Hand Quantity", `ItmsGrpNam` → "Item Group"); the model name stays
  technical English. Written via TOM (see "Captions" below); check: no visible field without an he-IL caption;
- model measure names (= what Desktop shows) use `#` instead of `Qty` (`On Hand #`, `Sales # 6M`; user,
  2026-10-21); captions keep the full words. A TOM rename does **not** rewrite `[Old Name]` in other
  measures or `visual.json` (`Property`, `queryRef`, `nativeQueryRef`) — fix both, grep the old name → 0.
  Same for moving a measure to another table (TOM: remove + add a copy): `visual.json` keeps the old
  `SourceRef.Entity` (incl. `filter.From[].Entity` of visual filters) and Desktop saves it unchanged — repoint it;
- **no `displayName` on visual fields by default** — remove the ones that exist so the field shows its
  caption (the Hebrew text of a manual rename becomes the he-IL caption, rule 1 below). A visual rename
  only on the user's explicit request;
- exceptions: field-parameter labels (rows per language, below) and texts that are not field names
  (slicer / visual `title.text`, DAX label measures);
- ⚠️ Desktop always shows **model names** (`On Hand Qty`) — captions show only in the Service, in the
  viewer's browser language. A Desktop screenshot cannot verify captions; check the culture files /
  `INFO.OBJECTTRANSLATIONS ()`.
Applied first: ClientB Inventory Coverage (2026-10-21: 44 objects, 10 matrix `displayName`s removed).
Rules 3 and 5 below (pinning / keeping manual names) are the older approach — only on request.

### ⚠️ RULE: slicer names = title from a language measure (user, 2026-10-21)

As in Sales Channels (`CT_DocStatus[Slicer Document Status]`, `CT_PeriodGrain[Slicer Period Grain]`):
1. **Title, not header:** `objects.header.show = false`, the name goes into
   `visualContainerObjects.title` (`show = true`) — only the title can be aligned.
2. **Centered:** `title.alignment = 'center'` (in the theme `visualStyles.slicer.*.title`; a local `left`
   is removed).
3. **Text from a measure:** `title.text` = `{"expr": {"Measure": {"Expression": {"SourceRef": {"Entity":
   "_Measures"}}, "Property": "Slicer Item"}}}` — never a literal.
4. **Follows the language switcher:** hidden measure `Slicer <Name>` (display folder `Labels`; folders are never numbered —
   `BP_DISPLAY_FOLDERS_NO_NUMBERING`):
   ```dax
   VAR __CheckCulture = COALESCE ( [Selected Culture], USERCULTURE () )
   RETURN
       SWITCH ( TRUE ()
           , __CheckCulture = "he-IL", "קבוצת פריט"  -- Item Group
           , "Item Group"
       )
   ```
   Needs `CT_Language` + `[Selected Culture]` + the report filter (see "Language switcher" below).
ClientB Inventory Coverage (2026-10-21): `Slicer Period` / `Slicer Item` / `Slicer Item Group`.

⚠️ **Selector slicer with a measure default (ClientB Open / All, 2026-10-25):** use `singleSelect` true +
`strictSingleSelect` **false**. A strict single-select slicer selects its first item, and Desktop then writes it as a
saved selection (`objects.general.filter`) on every save of a displayed page — on a UserContext display column that
literal is one language's label (no match for the other). Non-strict starts empty, shows "All", and the measure default
(`SELECTEDVALUE ( …, 2 )`) applies.

Reference implementations: `Agency\Fitness\ClientF\Sales Channels` (origin) and
`Agency\ClientB\Sales Report\Sales_ClientB` (all three parts below). Three independent parts — each is
driven by a different "language" signal:

| Part | What is translated | Driven by |
|---|---|---|
| Language switcher | texts returned by DAX measures (titles, labels) | the `CT_Language` report filter, fallback `USERCULTURE ()` |
| Measure captions | field names (measure / column / table) | the viewer's UI language (browser / Desktop), **not** the switcher |
| Column translation | column **values** (e.g. customer group names) | `USERCULTURE ()` only — a column cannot see the switcher |

### Language switcher (`CT_Language` + filter on all pages)

- Table `CT_Language` (calculated, **hidden** — `BP_CT_LANGUAGE_HIDDEN`; DAX layout per `BP_MANUAL_DAX_TABLE_LAYOUT`):
  `DATATABLE ( "Language_long", STRING, "Language", STRING, "Culture", STRING, { { "English", "En", "en-US" }, { "Hebrew", "He", "he-IL" } } )`
  + measure `[Selected Culture] = SELECTEDVALUE ( 'CT_Language'[Culture] )`.
  ⚠️ Added via TOM to an open Desktop, the table stays empty ("needs to be recalculated or refreshed") —
  `RequestRefresh('Calculate')` on it (`DATATABLE`, no source — a `Calculate` is always allowed, rule
  2026-10-22). Until then do not save / reload the report part.
- Report-level filter (`report.json` → `filterConfig.filters`): `CT_Language[Language]`, `Categorical`,
  default `'He'`, `objects.general.requireSingleSelect = true`. Copy the JSON block from Sales Channels.
- Label measures read it with the user culture as fallback:
  ```dax
  VAR __CheckCulture = COALESCE ( SELECTEDVALUE ( 'CT_Language'[Culture] ), USERCULTURE () )
  RETURN
      SWITCH ( TRUE()
          , __CheckCulture = "he-IL", "לקוח"
          , "Customer"
      )
  ```
  A measure with a hard-coded Hebrew text does not react to the switcher until it is rewritten this way.

### Captions — measures and columns (cultures)

- `cultures\en-US.tmdl` and `cultures\he-IL.tmdl`, `translations → model Model → table → measure → caption`.
  In `en-US` the `translations` block goes **before** `linguisticMetadata`. Names stay English
  (`BP_MEASURE_NAMES_ENGLISH`); the English caption may fix typos (`Vareity` → "Item Variety").
- Desktop open → write them via TOM: `$model.Cultures['he-IL'].ObjectTranslations.SetTranslation($measure,
  [Microsoft.AnalysisServices.Tabular.TranslatedProperty]::Caption, '<text>')`. Check:
  `INFO.OBJECTTRANSLATIONS ()` grouped by `[CultureID]`. Avoid duplicate captions within a table.
- **Columns** get captions the same way (TOM object = the column; `ObjectType` 4 in
  `INFO.OBJECTTRANSLATIONS ()`, measures = 8). ClientB: all 323 columns + 149 measures.

**Rules for the he-IL caption (user, 2026-10-18):**

1. **Manual names win.** Source order: the name typed in visuals (`projections[].displayName`, the most
   used one) → the field parameter label (`( "label", NAMEOF ( 'T'[C] ), … )`) → our own translation.
2. **Context-dependent manual names are not captions.** A name that only fits its visual (`תקופה א` for a
   period-A date slicer, `שם` for a supplier name, `לקוח` on the supplier table) → the caption gets our
   translation, the visual keeps its own `displayName`. The list is kept by hand (`CONTEXT` in the script).
3. **No change for a Hebrew viewer.** A `displayName` always overrides the caption, but a visual field
   **without** one shows the caption — so a new he-IL caption would change what a Hebrew viewer sees
   (`ItemGroup` → `קבוצת פריט`). Every such field gets `displayName` = the text a Hebrew viewer saw before
   (the old caption, else the model name). `displayName` is the same in every language, so existing visuals
   stay unchanged for everyone; the captions show in the field list, new visuals and Q&A.
4. Clash inside a table (vs another column or a measure caption): the column with more manual uses keeps
   the name, the other gets our translation.
5. **A manual name equal to the he-IL caption is removed** (user, 2026-10-18): the field then shows the
   model caption — the same text for a Hebrew viewer, the en-US caption for an English one. Only exact
   matches; a different name (incl. near matches like `:סוג מסמך`) and the pinned model names (rule 3) stay.
   ClientB: 127 of 573 manual names (44 fields) removed.

**Scripts** — the ClientB folder `Agency\ClientB\Translation\` is no longer on disk (2026-10-26). Current set, closed PBIP
(offline TOM on the TMDL folder): `Agency\ClientC\Translation\` — `captions_*.py` / `.json` (table → he / en),
`apply_captions.ps1` (`CT_Language`, `[Selected Culture]`, cultures + captions), `report_language.py` (report language
filter + rule 5). Measures only, live TOM (ClientE 2026-10-28): `ClientA\_Documentation\Refactoring\ClientE\` —
`measure_inventory.py` (uses, manual names, ClientC caption of the same name), `captions_measures_ClientE.py`,
`report_measure_names.py` (rules 3 + 5 with a He-text before / after check; **run `--apply` once** — a rerun pins the
fields whose name rule 5 removed). Older ClientB scripts (table below, live TOM):

| Script | What it does |
|---|---|
| `col_translations.py` | Our en / he translation per column (the fallback) — add a line for a new column |
| `build_col_captions.py <Sales Report>` | Applies rules 1, 2, 4 → `col_captions.json`; prints sources, manual names that differ from ours, clashes |
| `tom_col_captions.ps1 -Port -Json` | Writes the captions from the JSON into the open model (TOM) |
| `save_desktop.ps1 -DesktopPid -Folder` | Desktop **Save** via UI Automation, confirms by file timestamps |
| `pin_display_names.py <Sales Report> <baseline he-IL.tmdl> [--apply]` | Rule 3: pins `displayName` on visual fields whose He text would change; dry run without `--apply` |
| `he_impact.py <Sales Report> <baseline he-IL.tmdl>` | Check: what a Hebrew viewer sees before vs after, per visual field — must report 0 changes |
| `tom_fp_culture_rows.ps1 -Port` | Field parameters: language rows + `Culture` + relationship + `Locale Match` measure (see below). It calls `RequestRefresh('Calculate')` — allowed (DAX-only recalculation, rule 2026-10-22). Its row regex does not parse escaped quotes in labels (`מק""ט`) — write such rows explicitly |
| `add_locale_filter.py <Sales Report> [--apply]` | Adds the slicer filter `[Locale Match <FP>] = 1` to the parameter slicers |
| `check_model.ps1 -Port [-Extra <DAX>]` | Health check, summary only: object states + every measure evaluated + extra queries |
| `drop_matching_display_names.py <Sales Report> [--apply]` | Rule 5: removes `displayName` = he-IL caption; dry run prints the counts and the near matches it keeps |
| `he_visible_diff.py <Report before> <Report after> <he-IL.tmdl> [<he-IL.tmdl after>]` | Check for any report edit: He text per visual field (`displayName`, else caption, else model name) before vs after — must be 0. `he_impact.py` compares only with the pre-translation baseline (fields without a manual name) and flags rule-5 removals falsely. ⚠️ Fields are matched by table + column, so a field moved to another column (table swap, `ReportFields.py replace`) shows only as "only before / only after", never as a difference — pair those by file + role + position (ClientB `Date` → `Calendar`: 30 such fields, 2 changed) |

⚠️ **Rerun-safe builder:** after the pin step, visuals carry `displayName` = the model name (`ItemGroup`);
the builder must not count those as manual names (skip `displayName` equal to the model name), and must
read only **measure** captions from the cultures as "taken" names (the column captions there are its own
output — otherwise every column clashes with itself). Check after a rerun: the JSON equals the applied
captions, `he_impact.py` = 0.

**Field parameters — rows per language** (as Sales Channels `FP_Analytic_Groups`; ClientB 2026-10-18,
`BP_FIELD_PARAMETER_COLUMN_FP`). A translated column does **not** work for a parameter (it cannot follow the
switcher, and visuals must bind through the parameter's own label column) — translate the **rows** instead:
- every field twice, same `NAMEOF` and `Order`, the language in the last column:
  ```dax
  {
      ( "קבוצת לקוח",           NAMEOF ( 'Customers'[CardGroup] ), 4, "he-IL" ),
      ( "Customer Group (SAP)", NAMEOF ( 'Customers'[CardGroup] ), 4, "en-US" ),
  }
  ```
  column `Culture` (hidden) — ClientB: the former `En` column (`[Value4]`) renamed; its English labels became
  the `en-US` rows.
- relationship `FP_X[Culture]` (many) → `CT_Language[Culture]` (one), single direction: the single-select
  `CT_Language` report filter leaves one row per field — this **does** follow the switcher (a filter, not a
  column).
- measure `[Locale Match FP_X]` (hidden) = `INT ( SELECTEDVALUE ( 'FP_X'[Culture] ) = COALESCE ( [Selected Culture],
  USERCULTURE () ) )` as the slicer's visual filter `= 1` — keeps one language when no language is selected.
- slicers and matrices stay on `FP`: the matrices bind through `queryState/Rows/fieldParameters[0]/parameterExpr`
  (must be the column with `relatedColumnDetails groupByColumn: Fields`). Desktop stores the current (Hebrew)
  label as `displayName` on the role's projections, but with `fieldParameters` the **FP label wins** — the header
  follows the language (checked ClientB Inventory Coverage 2026-10-30, Rows and Values).
- **Matrix total row label per language** (2026-11-02): `objects.subTotals` →
  `rowSubtotalsLabel: { expr: { Measure: '_Measures'[Label Total] } }` (He `סה"כ` / En "Total", same culture check as
  the other label measures). A measure works here (fx); it also renames the grand total row. A theme cannot hold it
  (no measures in themes) — set it on each matrix.
- bookmarks store slicer selections as label values (Hebrew) — with `En` selected they do not match.
- **Button slicer that switches an FP (group column):** keep the group names **Hebrew in both language rows** (user
  2026-10-30, ClientC step 29) — only the FP labels (headers) are per language. With translated group names the saved
  selection (Desktop writes the shown value on every save) is missing in the other language: no button selected, and
  an FP filtered to zero rows leaves the table **without its row field** (totals only). Strict single select does not
  re-pick when a stale value is saved.
- **Combined header label** (user, ClientB Inventory Coverage 2026-10-21): matrix rows from an FP in the
  **stepped layout** show only the **first** level's label as the row header — so the first label names all
  levels (`Group / Name / Code`), in both language rows; the other rows keep plain labels:
  ```dax
  {
      ( "קוד פריט / שם פריט / קבוצת פריט",    NAMEOF ( 'Inventory'[ItmsGrpNam] ), 0, "he-IL" ),
      ( "Item Group / Item Name / Item Code", NAMEOF ( 'Inventory'[ItmsGrpNam] ), 0, "en-US" ),
      ( "פריט",                               NAMEOF ( 'Inventory'[ItemName] ),   1, "he-IL" ),
      ( "Item Name",                          NAMEOF ( 'Inventory'[ItemName] ),   1, "en-US" ),
      ( "מק""ט",                              NAMEOF ( 'Inventory'[ItemCode] ),   2, "he-IL" ),
      ( "Item Code",                          NAMEOF ( 'Inventory'[ItemCode] ),   2, "en-US" )
  }
  ```
  ⚠️ **Word order of a mixed-direction label:** the he-IL text is stored `Code / Name / Group` and Power BI
  shows it so a Hebrew reader (right to left) reads Group → Name → Code. Never copy the stored order into the
  English row — write English in drill-down order. An editor / console shows Hebrew reordered (and `?` in a
  non-UTF-8 console): check the logical order by splitting the string in a script, not by eye.
- **Changing an FP expression** (labels, rows) via TOM empties the table until the user refreshes it (Data
  view → right-click → Refresh data; no source is read) — batch label changes into one refresh.
- check: `CALCULATE ( COUNTROWS ( FP_X ), CT_Language[Culture] = "he-IL" )` = number of fields, the he-IL labels
  equal the old ones in the same order, all measures evaluate.
- ⚠️ TOM: remove a column's culture translations before removing the column ("The translation for culture
  'en-US' references an object … that has been deleted").
- Replaced the first attempt `FP_Trans` (a `UserContext` column: blank `SELECTEDVALUE` → `USERCULTURE ()` only).

Order: build → TOM → save → pin (`--apply`) → apply external changes (bridge) → `he_impact.py`. The baseline
`he-IL.tmdl` is the one from **before** any caption work (ClientB: `BackUp\Translation_2026-10-18_092006`).
⚠️ Rewriting `visual.json` with Python `json` changes float text (Desktop writes 17 digits:
`615.16678012253226` → `615.1667801225323`) — load with `parse_float` into a placeholder and put the
original text back (done in `pin_display_names.py`); check the round trip is byte-identical before writing.

### English comments in measures — Hebrew and codes (2026-10-18)

Rules `BP_MANUAL_ENGLISH_FOR_NON_ENGLISH_TERMS` (measures → comment) and `BP_MANUAL_COMMENT_CODES`. A
`--` comment is appended at the end of each line; nothing else in the expression changes:

```dax
[Selected_CurrType] = "מקומי" && [Selected_Open/All] = "פתוח", [SalesAmountOpen_BySelectedDate],  -- Local; Open
CALCULATE ( [SalesValue], DocumentTypes[TransType] IN { "13", "14" } )  -- 13 = A/R Invoices; 14 = A/R Credit Memos
1, SUM ( 'DocsSales'[SalesVal] ),  -- 1 = Document Date
```

- Hebrew: every line with a Hebrew literal or comment (`//כמויות לפי תאריך מקומי  -- quantities by local
  date`); several phrases on one line → one comment, `;`-separated; a line that already has a Latin comment
  after the Hebrew is left alone.
- Codes: a digit literal compared with a column (`=`, `<>`, `IN {`, also `SELECTEDVALUE ( T[C] ) =`), and the
  numeric branches of `SWITCH ( FIRSTNONBLANK ( T[C], 0 ), 1, …`. The meaning comes from the model's lookup
  table (`DocumentTypes`, `Customers`, `DocsPurchs`, `DateTypeTbl`), never guessed; commented-out code is skipped.
- Done by script on the open model (ClientB `Agency\ClientB\Translation\`): `tom_measures_io.ps1 -Mode export` →
  `he_comments.py scan` (distinct phrases) → dictionary `he_en.py` → `he_comments.py apply` /
  `code_comments.py scan|apply` with `codes.json` → `tom_measures_io.ps1 -Mode import` (writes only measures
  whose live expression still equals the exported one) → `measure_snapshot.ps1` before / after (every
  measure's value must be identical) → `save_desktop.ps1`. ClientB: 96 Hebrew lines in 20 measures, 42 code lines
  in 18 measures, 0 value differences.

### Column translation (culture-aware column)

Translates the **values** of a text column (customer group names, categories) — not its caption. Reference:
ClientB `Customers[CardGroup]`, `[CardGroup Category]`, `[CardGroup Subcategory]`, `[HagitCustomerGroup]`.

**Three layers — each object lives in exactly one place:**

| Layer | Objects | Display folder |
|---|---|---|
| SQL (source query) | `X_He` — the Hebrew value; `X_En` — its English translation. **Nothing else** | — |
| Model, data columns | `X_He`, `X_En` (`sourceColumn: X_He` / `X_En`) | `_He` / `_En` |
| Model, DAX | `X` — the culture-aware column, **original name**, user context ON | `_Trans` |

The culture-aware column is never created in SQL: `USERCULTURE ()` exists only in DAX, and only a
`UserContext` column is evaluated per viewer.

#### 1. SQL — `X_He` + `X_En`

Reference: `Agency\Power Loader\PROD\ClientB\ETL_MD_Customers_ClientB.sql`, block `[TR]`.

- Rename the output alias `X` → `X_He`; the internal names used by the CASE logic stay.
- A column computed by a CASE in the outer SELECT moves into its own `CROSS APPLY` first, so that it can be
  translated (ClientB `[SUB]` for `CardGroup Subcategory`).
- **One** Hebrew → English list for all translated columns: the row's values are unpivoted into `[K]` and
  joined to the list `[V]`:

  ```sql
  CROSS APPLY (
      SELECT
            MAX ( CASE WHEN [K].[Col] = 1 THEN COALESCE ( [V].[En], [K].[He] ) END ) AS [CardGroup_En]
          , MAX ( CASE WHEN [K].[Col] = 2 THEN COALESCE ( [V].[En], [K].[He] ) END ) AS [CardGroup Category_En]
      FROM ( VALUES
            ( 1, [C].[CardGroup] )
          , ( 2, [CAT].[CardGroup Category] )
      ) AS [K] ( [Col], [He] )
      LEFT JOIN ( VALUES
            ( N'לקוחות מסחרי' , N'Commercial Customers' )
          , ( N'מחלקת ביוטי'  , N'Beauty Department'    )
      ) AS [V] ( [He], [En] ) ON [K].[He] = [V].[He]
  ) AS [TR]
  ```

- Not in the list → the Hebrew value (customer names, a group added later); NULL stays NULL. `COALESCE`
  here is logic, not the forbidden NULL → 0 presentation.
- Put **every** Hebrew literal of the query into the list, not only the values present today; a new value
  in the data = one line in the list.
- Values that come from a name (ClientB `CardGroup Subcategory` = `ELSE [CardName]`) are translated case by
  case — only where they appear as a group row in small categories (ClientB: ECOM sites, brand stores, a B2B
  customer); thousands of customer names stay Hebrew. Find them: `X_En = X_He` per category
  (`GROUPBY` on the model), then list the small categories.
- ⚠️ Not `MAX ( CASE WHEN [V].[He] = [C].[X] … )` straight over the list: SQL Server — "Multiple columns
  are specified in an aggregated expression containing an outer reference". Hence the `[K]` unpivot.

#### 2. Model — `X_He`, `X_En`, `X`

Desktop open → TOM into the open model (`PBIP_Model_Live.md`), `SaveChanges()` after each step.

1. Data column `X` → **rename** to `X_He`, `sourceColumn: X_He`, display folder `_He`.
2. Data column **`X_En`** (`sourceColumn: X_En`), display folder `_En`.
3. **`X`** (the original name) — calculated column, **user context ON** (TMDL
   `expressionContext: userContext`, TOM `ExpressionContext = 'UserContext'`), the same culture check as the
   Sales Channels `CT_*` columns and label measures:
   ```dax
   VAR __CheckCulture = COALESCE ( SELECTEDVALUE ( 'CT_Language'[Culture] ), USERCULTURE () )
   RETURN
       SWITCH ( TRUE ()
           , __CheckCulture = "he-IL"
           , 'Customers'[CardGroup_He]
           , 'Customers'[CardGroup_En]
       )
   ```
   In a column the `SELECTEDVALUE` part returns blank (see gotchas: the switcher does not reach columns), so
   the value follows `USERCULTURE ()`; the check is kept identical to the measures so that one pattern
   is used everywhere.
4. Dependencies:
   - `sortByColumn` — set on `X` and `X_En` too (same sort column as `X_He`).
   - Hierarchy levels → `X_He` (a level cannot use a `UserContext` column, see gotchas).
   - Lookups by value (`TREATAS` / joins to a table with Hebrew keys) → `X_He`.
   - `ISFILTERED` / field parameters (`NAMEOF`) → the column the visuals use: `X` by default; if the
     visuals are repointed to `X_He` (ClientB 2026-10-20, values stay Hebrew in both languages), repoint
     **all three together** — visuals, `NAMEOF` in the field parameter tables, `ISFILTERED` in measures.
     A mismatch fails silently or loudly:
     - `ISFILTERED ( T[X] )` while the visual groups by `X_He` → FALSE → wrong branch (ClientB
       `[Monthly Sales Target]` gave every subcategory its whole category's target);
     - a field-parameter matrix groups by the `NAMEOF` column, so an expansion state whose
       `identityKeys` name `X_He` → "Error fetching data… The InstanceFilters have a column
       expression that cannot be matched to any existing grouping expression". Desktop does not even
       send the query (nothing in a trace); read the text via UI Automation (`See details` → search
       the window's element names).
     - Changing `NAMEOF` changes the `Fields` values: field-parameter filters saved with a literal
       `'''T''[X]'` (`Condition.In.Values`, `decomposedIdentities`) no longer match, and Desktop's next
       save drops those fields from the visuals — repoint the literals to `X_He` in the same pass.
       Sequence with Desktop open: TOM edit → the user recalculates the two FP tables → Ctrl+S →
       edit the report JSON → `powerbi-desktop reload` → save.
5. Refresh the table (data) + model-wide `RequestRefresh('Calculate')`, then save in Desktop.

Order: deploy the query → load (Power Loader) → model steps → refresh. A `sourceColumn` that the
deployed query does not return yet breaks the refresh.

#### 3. Report — nothing to change

`X` keeps the original name, so visuals, slicers, bookmarks, filters and field parameters bind to it by name.

#### Checks

- SQL without access to the client's server (ClientB: `Translation\test_sql_translation.ps1 -Port`): run the `[TR]` block verbatim on LocalDB
  (`(localdb)\MSSQLLocalDB`, a `#temp` table filled from the open model with a DAX query + `SqlBulkCopy`):
  no duplicate keys in the list, row count unchanged, no untranslated value except customer names,
  NULL stays NULL.
- Model: `INFO.MEASURES ()` / `INFO.COLUMNS ()` / `INFO.PARTITIONS ()` without errors;
  `SUMMARIZECOLUMNS ( T[X], T[X_He], T[X_En] )` — a DAX query runs as `en-US`, so `X` = `X_En` there.
- **Evaluate every measure** at the total (`EVALUATE ROW ( "v", [M] )`, one query per measure): a failing
  iteration over the table is invisible to `INFO.MEASURES ()` (see gotchas).
- TMDL after the save: `expressionContext: userContext` on `X`, folders `_He` / `_En` / `_Trans`.

#### Gotchas (ClientB 2026-10-18)

- **Compatibility level ≥ 1705** for `UserContext` ("… 1606 is below the minimal … 1705"). TOM:
  `$db.CompatibilityLevel = 1705; $db.Update()` — one-way (back only by restoring a backup); afterwards
  every calculated object needs `Calculate`.
- **A calculated table cannot reference a `UserContext` column** — also indirectly:
  `SUMMARIZE ( DocsSales, DocsSales[Item_KEY], … )` reads the expanded fact table (incl. `Customers`).
  Group by the column only: `ADDCOLUMNS ( VALUES ( DocsSales[Item_KEY] ), "…", CALCULATE ( [M] ) )`
  (ClientB `Aggregate`: identical 438 rows). Field parameters with `NAMEOF` are fine.
- **Iterating the table fails**: `AVERAGEX ( Customers, [SalesValue] )` (context transition over whole
  rows, incl. the `UserContext` columns) → "An unexpected exception occurred." Iterate the key:
  `AVERAGEX ( VALUES ( Customers[BP_Key] ), [SalesValue] )` — same result when the key is unique (ClientB
  `[AvergePerCustomer]`, 18 884.28 both ways). It is not reported by `INFO.MEASURES ()` — only by evaluating.
- **Renaming in SQL first, then refreshing** (instead of changing `sourceColumn` via TOM first): Desktop
  drops the columns whose source column vanished and creates new data columns — a name clash gets the
  suffix `_` (old DAX `X_En` → `X_En_`), and the dropped columns take their **hierarchy levels** and
  **sort by** with them. After such a refresh: re-add the levels (old `lineageTag` keeps the visuals), the
  sorts, repoint `X` to the data `X_En`, delete `X_En_`.
- **A hierarchy level cannot use a `UserContext` column** — calculation fails with
  `XMUserHierarchyLevelAggDataCache::InitDC`. When `X` is added, a level re-binds to it **by name**, so
  point it back to `X_He` explicitly. The hierarchy then shows Hebrew in every language.
- **Lookups by value use `X_He`** — ClientB `[Monthly Sales Target]`:
  `TREATAS ( VALUES ( Customers[CardGroup Category_He] ), Target[Category] )`; with `X` an English viewer
  gets no match.
- Saved filter values (slicer selections in bookmarks, filters with a literal) are Hebrew — for an English
  viewer they do not match the English values of `X`.
- **The `CT_Language` switcher does not reach a `UserContext` column** — tested (ClientB 2026-10-18):
  `CALCULATETABLE ( VALUES ( Customers[CardGroup Category] ), CT_Language[Culture] = "he-IL" )` in an
  en-US query still returns the English values (also `FP_Trans`). The column is evaluated per viewer
  session, before any report filter, so `SELECTEDVALUE ( 'CT_Language'[Culture] )` sees both rows → blank →
  `USERCULTURE ()`. The same holds for the Sales Channels `CT_*` columns. Only measures follow the switcher.
- A failed `SaveChanges` rolls back only its own batch — re-read the server state before retrying.

#### Fallback: `X_En` in DAX (the source query cannot be changed)

Keep `X_He` as the renamed data column and make `X_En` a calculated column (`Standard` context):

```dax
SWITCH (
    'Customers'[CardGroup_He],
    "לקוחות מסחרי",  "Commercial Customers",
    "לקוחות פרטי",   "Private Customers",
    'Customers'[CardGroup_He]
)
```

Distinct values from the model (`SUMMARIZECOLUMNS ( T[X_He] )`), `"` escaped as `""`. Move it to SQL when
the query can be changed (ClientB did this 2026-10-18).
