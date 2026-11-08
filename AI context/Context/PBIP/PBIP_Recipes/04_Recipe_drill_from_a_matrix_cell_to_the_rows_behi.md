Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: drill from a matrix cell to the rows behind it (metric axis, 2026-10-22)

Client request (call 2026-10-13): click a number in the Overview matrix (e.g. Eduardo Mendoza,
1 - 10, *PTP Cured By Other Collector* = 66) and see exactly those loans. Prototype with five
variants: `ClientA\BackUp\2026-10-22_OverviewDrill\Overview Drill.pbip` (sections
`<<< A · Measure + SWITCH >>>` … `<<< D · CG + UDF >>>`, `<<< E · FP filtered by CT_OverviewMetric >>>`,
pages `DrillOverviewA-E` / `DrillDetailsA-E`). **Variant E is in the real report** (2026-10-22, E is the
fastest on the detail page — see "Benchmark" below): model objects `CT_OverviewMetric`, `FP_OverviewMetric`,
`[Overview Metric Switch]` (display folder `Collection\Overview Drill`) and the relationship
`FP_OverviewMetric[FP Order]` → `CT_OverviewMetric[Order]`; on the tabbed `Overview` page
(`a98d284b46eac8ae4cc7`) the matrix `f6e7806c5ba4e72ba91d` and the left button `df0e4ff40c98ed7e0b27`
(`Assign. Details` → `Loan Details`, target `LoanDetails`; on the other tab pages it still drills to
`DetailsPTPDD`); new drillthrough page `LoanDetails` ("Loan Details", after `TabsDPDByDate`). Backup
before: `ClientA\BackUp\2026-10-22_DrillE_CollectorAssignment\`.

### Why a plain matrix cannot do it

Drillthrough (and cross-filtering) from a matrix cell passes only the **columns** in the cell's
filter context: the row headers (Delinquency, Employee) and any column-axis field. A matrix whose
columns are separate measures has no column-axis field, so "which measure was clicked" is not
passed. The fix: put the metric on the column axis as a **column** — one value measure, columns =
a table row per metric — then the clicked metric travels with the drillthrough like any other
field.

### Why not a field parameter (SQLBI, checked 2026-10-22)

A field parameter looks like the obvious "metric axis", but it cannot carry the clicked metric:

- **Power BI resolves the field parameter on the client, before the visual query runs.** The
  report first queries the parameter table (`TREATAS ( { "'T'[M1]", … }, 'FP'[FP Fields] )` with
  the slicer selection), reads the selected field names, and then sends the visual query with
  those **fields themselves** — the visual query no longer references the parameter table at all.
  Seen in Performance Analyzer as two queries (sqlbi.com, "Fields parameters in Power BI").
- So in the model there is no filter on the parameter table inside a cell: DAX cannot tell which
  parameter row a cell belongs to, and drillthrough has nothing to pass. A measure field parameter
  in Values simply expands into the separate measures — the same situation as the plain matrix.
- A field parameter column in the **Columns** well does not help either: there it switches which
  field is used, it does not become a category.
- Consequence: the metric axis must be a **plain disconnected table** (`CT_…`), not a field
  parameter — no `ParameterMetadata` extended property, no GroupBy column. Then
  `CT_…[Metric]` is an ordinary column in the cell's filter context, and drillthrough passes it.

**`MAX` vs `SELECTEDVALUE` on such a column.** On a real field-parameter column `SELECTEDVALUE`
**errors**: the visible column is grouped by the hidden `Fields` column (GroupBy columns /
"composite key"), and `SELECTEDVALUE` relies on `VALUES`, which does not support them — that is
why SQLBI reads field parameters with `MAX ( 'FP'[Fields] )` ("Using field parameters and
calculation groups for conditional formatting"). Our `CT_OverviewMetric` has **no** GroupBy
columns, so `SELECTEDVALUE` would work; `MAX` is used only because of `BP_USE_MAX_MIN_INSTEAD_OF_SELECTEDVALUE`.
Inside one matrix cell there is exactly one metric row, so `MAX` and `SELECTEDVALUE` give the same
result; on a total across metrics (column subtotal) `MAX` returns the last metric — keep column
subtotals off on this matrix.

### Model (prototype objects)

- **`CT_OverviewMetric`** (calculated table, one row per matrix column): `Metric` (visible label,
  sorted by `Order`), `Measure` = `NAMEOF ( [measure] )` (hidden, rename-safe key), `Order`
  (hidden), `Format` (hidden, format string of the measure). Spacer columns are rows with blank
  `Measure`/`Format`.
  - ⚠️ Spacer labels must be unique **and not plain spaces**: the engine ignores trailing spaces in
    string comparison, so `" "`, `"  "`, … collide (sort-by-column then fails). Use
    `REPT ( UNICHAR ( 160 ), n )` (non-breaking spaces, as the Calendar slicer levels do).
- **DAX cannot evaluate a measure from its name in a column** — the measure list is always written
  in code once; `NAMEOF` only makes the key rename-safe. Two ways:
  - `SWITCH ( MAX ( CT_OverviewMetric[Measure] ), NAMEOF ( [M1] ), [M1], NAMEOF ( [M2] ), [M2], … )`;
  - UDF `Collection.PickOverviewMetric ( metricMeasure : MEASUREREF ) => IF ( MAX ( CT_OverviewMetric[Measure] ) = NAMEOF ( metricMeasure ), metricMeasure )`,
    chained with `+` in `Collection.OverviewMetricValue ()` (each measure written once; the
    non-matching calls return BLANK and the measure is not evaluated). Parameter type — see
    `PBIP_Model_Live.md` → "Parameter types" (`MEASUREREF`, not plain `EXPR`).
- **Value measure** with a dynamic format string `MAX ( CT_OverviewMetric[Format] )`
  (variants A, C), or a placeholder `[Overview Metric CG] = BLANK ()` swapped by a calculation
  item (variants B, D, `CG Overview Metric`, precedence 10):
  `IF ( ISSELECTEDMEASURE ( [Overview Metric CG] ), <value>, SELECTEDMEASURE () )` — the guard
  keeps every other measure untouched, also on the drillthrough page where the item stays active.
  Same guard pattern as SQLBI's conditional-formatting calculation group. The item must be active
  by a filter on the matrix **and** on the drillthrough page (otherwise the placeholder is BLANK
  and the drill table is empty).

### Report

- Matrix: Rows unchanged; `Columns` = `CT_OverviewMetric[Metric]` with `"showAll": true` on the
  projection state (spacer columns are all BLANK and would disappear); `Values` = the one value
  measure. Per-measure `columnWidth` / `columnFormatting` / `values` selectors no longer apply
  (removed in the copies).
- Drillthrough page: `pageBinding.type = "Drillthrough"`, parameters bound to Drillthrough filters
  on `CT_Delinquency[Delinquency]`, `Employee[EmployeeName]`, `CT_OverviewMetric[Metric]`;
  `acceptsFilterContext = "Default"` (keep all filters: month, Units / USD). Detail table with a
  visual filter "value measure is not blank". The left-panel drillthrough button
  (`Assign. Details`, renamed `Loan Details`) points to the page via `drillthroughSection`; it
  is enabled as soon as a matrix cell is selected (the cell supplies all three fields).

### Trade-offs vs. the current matrix

- No sort by clicking a metric column header (a matrix with a column axis sorts only by row
  headers / totals).
- One width for all columns; spacer columns lose their dark fill (per-column formatting worked by
  measure selector).
- Drill-table grain: the count = distinct assignment IDs (`[Assignment #/USD]`), so
  `LID[LoanID]` + `CollectorAssignmentSnapshot[ID]` is exact for every metric; adding the PTP
  columns (date, amount, payment) splits non-PTP metrics into several rows (Possible: 614 rows vs
  554) — exact only for the PTP metrics.

### Checks done (prototype, September 2026, Units)

- 811 cells (bucket × collector × metric): variant A = each original measure called directly,
  0 differences; A = B = C = D, 0 differences.
- Drill table for Eduardo / 1 - 10 / PTP Cured By Other Collector: 66 rows, 66 distinct
  assignment IDs = the cell.
- Cold-cache matrix query: 0.8–1.1 s for all four variants, 299 SE queries each — speed does not
  decide.

### Variant E · field parameter filtered by CT_OverviewMetric (2026-10-22)

Matrix = variant A (`[Overview Metric Switch]`). Only the detail page differs: the table shows
**`FP_OverviewMetric[FP]`** (field parameter, 24 metric rows, no spacers) instead of the value
measure, and has no "not blank" visual filter. Relationship `FP_OverviewMetric[FP Order]` (many)
→ `CT_OverviewMetric[Order]` (one), single direction: the drillthrough filter on
`CT_OverviewMetric[Metric]` leaves one parameter row, so the table runs with the plain measure.
Pages `DrillSepE` / `DrillOverviewE` / `DrillDetailsE`; in PBIR the table keeps the resolved
measure in `projections` plus `Values.fieldParameters` (`parameterExpr` = `FP_OverviewMetric.FP`,
`index` 2, `length` 1).

- **No `Measure` key column in the `CT_` table (real report, 2026-10-22).** With the field parameter
  in place, the `NAMEOF` key is already in `FP_…[FP Fields]`, and inside a matrix cell the `CT_` filter
  reaches it through the relationship — so the value measure reads `MAX ( FP_Metric[FP Fields] )`
  and the `CT_` table keeps only `Metric` (axis + drillthrough field), `Order` (sort + relationship key),
  `Format`. A `CT_` row without a matching parameter row (or with `[Blank]` there) falls into the
  `SWITCH` else branch — the spacer `0` (grey fill, `PBIP_Pages_Visuals.md` → "Keeping formatting when a
  visual's fields change"); a metric row must therefore have its parameter row, or it shows as a spacer.
  Tables in the real report were renamed by the user: `CT_Metric`, `FP_Metric`.
  Checked: 1,595 cells (Units + USD, Sep–Oct 2026) — 0 differences before / after.

- **Tried and rejected: a calculation group as the axis** (2026-10-22, test copy
  `ClientA\BackUp\2026-10-22_CGAxisTest\`). `CG Overview Metric` (precedence 10), one item per column
  `IF ( ISSELECTEDMEASURE ( [Overview Metric CG] ), [<metric>], SELECTEDMEASURE () )` + format string per item,
  placeholder `[Overview Metric CG]` in Values, the CG column on Columns and as the drillthrough field — would
  replace `CT_Metric` + `FP_Metric` + the SWITCH measure. Works: same 5,118 cells, same 1,343 detail rows,
  drillthrough from a cell passes the CG column (user's click test); the saved drillthrough value on a CG column
  is dropped on load (page opened directly is empty). **Rejected — slow:** Overview matrix query cold / warm
  7.5 / 6.0 s vs 3.4 / 2.5 s with `CT_` + SWITCH; with the grey-spacer color measure 19 / 18 s (FE-bound,
  ~2.5k SE queries). Also: inside a color measure the CG does not swap the placeholder — check data with the
  base measures.

- **Why it works although a field parameter cannot be the matrix axis** (see above): here it is
  not on the matrix, only on the target page, and the filter reaches it through a relationship.
  Desktop resolves the parameter with `CALCULATETABLE ( SUMMARIZE ( FP_OverviewMetric, [FP Fields],
  [FP Order], [FP] ), <drillthrough filters> )` (seen in a trace) — that form honours the
  relationship.
- ⚠️ **Testing it by hand:** `SUMMARIZECOLUMNS ( FP_OverviewMetric[FP], … , <filter on CT_OverviewMetric> )`
  **without a measure** returns all 24 rows — `SUMMARIZECOLUMNS` filter arguments do not reduce group-by
  columns of another table unless a measure is evaluated. Use `CALCULATETABLE` (as Desktop does).

### Benchmark (DAX Studio `dscmd benchmark`, 5 cold + 5 warm, September 2026, Units)

| Query | Cold, ms | Warm, ms |
|---|---|---|
| Matrix, current (24 measures) | 687 | 257 |
| Matrix A / B / C / D | 1 172 / 1 207 / 1 311 / 1 036 | 710 / 702 / 666 / 633 |
| Drill table A / B / C / D (value measure) | 5 333 / 6 452 / 6 079 / 6 149 | 5 902 / 5 813 / 5 497 / 6 451 |
| Drill table E (plain measure) + FP resolve | 316 + 3 | 88 + 4 |

- A–D differ by noise. The drill page is slow in all four (≈ 5–6 s, almost all formula engine):
  the SWITCH / UDF value measure is evaluated for every detail row. Not caused by `NAMEOF`: the same
  SWITCH on string literals took the same time.
- E removes it: the detail table is as fast as a table with the measure itself (~20× faster).
