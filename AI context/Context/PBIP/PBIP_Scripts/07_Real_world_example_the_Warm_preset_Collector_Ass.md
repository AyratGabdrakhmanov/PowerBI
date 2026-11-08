Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## Real-world example: the `Warm` preset (`Collector Assignment`, 2026-09-19)

An illustration of the method from "Step 2 must not be done "by eye"" above on a real
transfer of the formatting of the `SalesSummary` visual (page `Overview`,
`pivotTable`) into the `ThemeWarm.json` theme.

**In `visualStyles.pivotTable.*`/`visualStyles.tableEx.*` (the shared default for
ALL tables in the report)** — properties that matched one-to-one across all ~15
`pivotTable` visuals in the report: `columnHeaders` (`bold`, `autoSizeColumnWidth`,
`columnAdjustment: 'fixedWidth'`, `titleAlignment: 'Left'`), `grid`
(`gridHorizontal(Weight)`, `gridVertical: false`, `gridHorizontalColor:
'#F3F3F3'`, `outlineColor`), `subTotals.perRowLevel`, `rowTotal.applyToHeaders`
+ the default `backColor`, `rowHeaders.steppedLayoutIndentation`,
`values.wordWrap: false`. `subTotals`/`rowTotal`/`rowHeaders` exist only in
`pivotTable` (see "`tableEx` and `pivotTable` — different sets of allowed keys" above);
`tableEx.*` got only the overlapping subset.

**In the named preset `Warm` (optional, via `stylePreset`)** —
properties unique to `SalesSummary` specifically and not found in any
other visual of the same type: `columnHeaders.alignment: 'Right'` +
`defaultColumnWidth: 100`, `grid.rowPadding: 5` + `textSize: 13`,
`rowHeaders.expandCollapseButtonsSize: 12` + `backColor`/`alignment: 'Left'`,
`rowTotal.backColor: '#E0DED9'` (overrides the default `ThemeDataColor` from
`*`), `values` (`backColorPrimary`/`backColorSecondary: '#FDFCFA'`,
`bandedRowHeaders: true`), `title` (`fontFamily: 'Calibri'`, `fontSize: 15`,
`titleWrap: true`), `subTitle` (`show: true`, `fontFamily`, `fontSize: 12`).
Every key mentioned by the preset (`columnHeaders`/`grid`/`rowHeaders`/`values`)
also fully repeats inside itself what has already been promoted to `*` — otherwise visuals
on the `Warm` preset would lose those properties (see "all or nothing" above).

**Remained only in `visual.json` (not themeable in principle)** —
`columnWidth`/`columnFormatting` with `selector.metadata` targeting specific measures
(`Measure.Assignment Cure %`, `CT_Delinquency.Delinquency` etc.) and title text/
visibility (`title.text`/`show`/`alignment`/`bold`) — a theme cannot
reference specific measures (see "A theme fundamentally cannot reference
measures" above), and the title text is unique to each visual.

After the transfer, the `SalesSummary`/`Overview` visual specifies
`visualContainerObjects.stylePreset.name: 'Warm'` — the only visual in
the report actually using this preset at the time of writing; the other
`pivotTable`/`tableEx` visuals continue to use only the base `*` and
their own local overrides, as before (the transfer to the theme/preset is
purely additive; no other visual in the report changed visually).
