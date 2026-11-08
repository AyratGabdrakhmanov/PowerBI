Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️ Keeping formatting when a visual's fields change (2026-10-22)

Rule (user): when a visual gets new fields or a new model structure behind it, keep its visual
formatting wherever possible — column widths, per-column fills/fonts, conditional formatting,
number formats, header labels, sort, totals. Anything that cannot be kept — say so **before** the
change and agree on it; never drop it silently.

Per-field formatting in `visual.json` is keyed by **selectors**, so replacing a field orphans it:
`metadata` selector = a field in the well (`"Measure.Assignment Cured"`, `"CT_Delinquency.Delinquency"`);
`data` + `scopeId` = one **value** of a field on an axis (`CT_OverviewMetric[Metric] = 'Cured Total'`,
the form Desktop writes when you format a single column / data point). How to carry it over:

1. Before the change — list `objects.columnWidth` / `columnFormatting` / `values` / `columnHeaders`
   (and `dataPoint` etc. on charts) with their selectors and properties.
2. After it — map each old selector to the new one. Measures in Values → one measure + a metric
   column on Columns (Overview matrix, `CT_OverviewMetric`): `metadata: "Measure.X"` →
   `data: [{ scopeId: Comparison ( CT_OverviewMetric.Metric = '<label of X>' ) }]`
   (`ComparisonKind 0`, string literal in single quotes; NBSP spacer labels = U+00A0 x n inside the quotes).
3. Diff before/after (widths, fills, formats of the value measure vs the old measures, header labels).

What works on a matrix column-axis value (tested in Desktop 2026-10-22 on a copy):

- `columnWidth` with a `scopeId` selector — **works** (Desktop writes this form itself when you drag a
  column edge).
- `values.backColor` / `columnHeaders.backColor` with a `scopeId` selector — **ignored** (no fill).
- fx fill (`values.backColor` = a color measure, `dataViewWildcard`) — works, but **only on cells that
  have a value**: Desktop skips blank cells. So an all-BLANK spacer column cannot be filled at all.
  Fix used on Overview (2026-10-22): the value measure returns a hidden `0` in spacer columns
  (`SWITCH` else branch; spacer format `";;;"` in `CT_Metric[Format]`), only on rows that show data,
  and the color measure (`CT_Metric[Color Metric Column]`) returns `[Grey]` for spacer columns. Column headers
  have no fx fill — the spacer header stays light.
- A CF (color) measure does **not** add rows: Desktop puts it into the visual query wrapped in
  `IGNORE ( … )`, which excludes it from the non-blank row check (trace 2026-10-22; with / without the
  color measure — the same 161 rows). So a color measure needs no "row has data" guard. The **value**
  measure does: a spacer `0` returned on every row would add empty rows — return it only where the row
  has data. (A plain `SUMMARIZECOLUMNS` in DAX Studio without `IGNORE` does show the extra rows — don't
  judge the visual by it.)

Example: Overview matrix `f6e7806c5ba4e72ba91d` (Collector Assignment) — the switch to
`CT_OverviewMetric` dropped 22 per-measure widths and the dark spacer fill (`columnFormatting` on
`Measure.Blank`). Widths restored 2026-10-22 (`columnWidth` per `Metric` value, Delinquency 205,
`growToFit` removed — the theme's `fixedWidth` as before); the spacer fill — grey via the hidden `0`
(see above). Backup before — `ClientA\BackUp\2026-10-22_1949_OverviewMatrixVisual\`; test copy —
`ClientA\BackUp\2026-10-22_SpacerTest\`.
