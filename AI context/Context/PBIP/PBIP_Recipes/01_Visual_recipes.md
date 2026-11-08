Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Visual recipes

### Padding 0 + title indent with the `⠀` character (U+2800) (2026-10-08)

The user's style for charts (example — `CollectorScorecard`:
`ScoreBreakdown`, `ScoreTrend`): `visualContainerObjects.padding` —
`left`/`right` = `0D`, so that the chart takes up the full width of the container. But then
the title sticks to the left edge — the title has no padding of its own, so
it is shifted right by two `⠀⠀` characters (Braille Pattern Blank, U+2800) at the
start of `title.text`: `'⠀⠀Collector Score in …'`. Regular spaces do not
work — Power BI trims them at the start of the string. When copying the title into
JSON, check that it really is U+2800 (`[hex(ord(c)) for c in t[:2]]`).

### "i" icons above table column headers (2026-10-08)

⚠️ In `Semantic Model.pbip` the tooltip pages were removed 2026-11-06 (user; see `ClientA_Context.md` → "Collector
Score"). The recipe stays as a how-to. Removing tooltip pages: delete the `type: Tooltip` page folders, drop them from
`pages.json` `pageOrder`, and remove `section` (and `type`) from `visualTooltip` of every visual that points to them.

On `CollectorScorecard`, above the `TeamComparison` columns there are 7
`advancedSlicerVisual` visuals, 20×20 (tooltip pages `TTScRank`…`TTScPTPKept`) —
like footnotes to the column names. Their position is not tied to the table: when the
width of the table/columns changes, the icons shift and have to be recalculated:

`icon x = table x + column right edge + 2`

where the right edge is the sum of the column widths from left to right (`columnWidth` in
the table's `visual.json`; for the rest — `columnHeaders.defaultColumnWidth`).
This way the icon ends exactly at the end of the column (confirmed by the
user). The visible icon is narrower than the 20 px frame (~10 px), so a shift by
the frame width looks like a shift by two icons.

**Header height varies with the language** (ClientB Inventory Coverage, 2026-10-26): translated captions wrap to a
different number of lines, so an icon at the header bottom or on the first text line collides in some
language. Put it **above the first line** (superscript): y = matrix.y + 1, x = column right edge − 17. Other
prerequisites: the model needs `CT_BlankTable[Info]` (copy from Collector Assignment, hidden); a theme with
`*.*.visualTooltip.show: false` (ThemeWarm) — the icon must set `visualTooltip.show: true` locally (the copied
icon does).

**Adding / reordering columns with icons (ClientB Inventory Coverage, 2026-10-29):** one script run does it all — reorder
`Values.projections`, add a `filterConfig` entry (`type: Advanced`, new 20-hex `name`) per new measure, recompute every
icon x, set icon `z` / `tabOrder` in column order, copy an icon + tooltip page per new column, rewrite `pages.json`
`pageOrder`. Width check: row header + n × column width must fit the matrix width minus the scrollbar — else narrow the
row header (`columnWidth` on the first row field). Tooltip pages: the text button gets padding top / bottom 15 (container `padding`, no blank spacer rows); page height = 30 + 22 × text lines (ClientB 2026-11-02; replaces the legacy 86 + 22 × lines).
**Renaming a measure** that has an icon: also rename the icon folder + `name` + title, the tooltip page folder + `name` +
`displayName`, `visualTooltip.section`, the tooltip measure, both culture blocks and the linguistic-metadata key /
`ConceptualProperty`. Verify: `pbir validate` per-visual counts vs the backup, `CheckReportRefs.py --before`,
`ValidateTmdl.ps1`.

**Collector Assignment Scorecard icons (header top-right corner, 2026-10-27):** `x = round ( visual x + 10 (left
padding) + sum of the widths up to and including the column − 8 )`; y = the top of the header text: matrix
`TeamComparison` (title, default font) `y 266 → 305` (+39), `tableEx` `BucketTable` (title, font 12) `y 86 → 137`
(+51). Set an explicit `columnWidth` on every column the icons follow — a default-width column moves them all when the
default changes. One icon per column: copy an existing icon (new 20-hex `name`, `z` / `tabOrder` above the page max)
and change only `visualTooltip.section`; one tooltip page per column (copy of `TTScCure` 460 px, height `22 × lines +
20`, `title.text` → its `Tooltip Scorecard …` measure; the text has 2 blank lines in it, count them as lines). The same
measure on two pages (Team Comparison, Team Summary) uses the same tooltip page. Reorder / add columns by script and
recompute all icon x's in the same run; verify with a screenshot (Desktop zoom differs between windows — compare
icon vs header text, not absolute pixels).

"i" icons inside a KPI card (page `PTP`, 2026-10-09) — in the top right
corner of the card: `x = card x + width − 26`, `y = card y + 6`,
`z` above the card. Icon → tooltip page link: `visualTooltip.section`
= page name (`TTPtp…`); on the tooltip page — an `actionButton` whose
`title.text` = a text measure (`Tooltip PTP …`, lines separated by `UNICHAR(10)`),
page height ≈ 30 + 22 × number of lines. Reference sample — `TTScRank` /
icon `92dedd0d24c17798a8ab` on `CollectorScorecard`.

### Combo chart: column color — three gotchas (2026-10-08)

On `lineClusteredColumnComboChart` (`CollectorScorecard/ScoreTrend`):
1. **Column color via a series `metadata` selector is ignored**
   (`"selector": {"metadata": "Measure.Collector Score"}`) — the columns
   stayed in the theme color. The working option is `dataPoint.fill` **without a
   selector** (this is how Desktop writes "Columns → Color → Apply settings to:
   All"). Line colors via `metadata` selectors do work in this case and
   override the shared one.
2. **A shared fill without a selector overrides the fx fill by measure**
   (`fill` = `Measure` with a `dataViewWildcard` selector). If you need the color from
   the measure, remove the shared fill entirely; the measure itself provides the default color.
   The border (`borderShow`/`borderColor` by measure) had no competitor and
   worked right away.
3. **Formatting a single column in Desktop writes a hard `scopeId`
   selector** on a specific axis value (`Year = 2026` AND `Month Name =
   2026-10-01`) — it takes precedence over the measure and does not "shift" to the next
   month by itself. Check `visual.json` for `scopeId` after manual color edits.

### Recipe: highlight the current (partial) month with an outlined column

Two measures based on the `Calendar[Current Month]` flag (recalculated on Refresh):
`Score Column Fill` (current month — light fill `#E6E6E6`, the rest —
the main color `#B3B3B3`) and `Score Column Border` (current — dark border
`[Grey Dark]`, the rest — the fill color, so the border is invisible). In the visual —
`dataPoint` with a `dataViewWildcard` selector (`matchingOption: 1`): `fill` and
`borderColor` = the measures, `borderShow: true`, `borderSize: 2D`; there must be no shared fill
without a selector (gotcha 2 above). The flag via
`NOT ISEMPTY ( FILTER ( VALUES ( Calendar[Current Month] ), Calendar[Current Month] ) )`
(`MAX` over a boolean column does not work).

### "i" icons above `SalesSummary` columns (page `PTP`, 2026-10-09)

18 icons (`PtpColInfo…`, a copy of the Scorecard icon, 20×20) — at the bottom of the header
of each column, centered; `Blank` columns (0,5) are skipped. Coordinates:
x = table.x + 10 (padding left) + width of the row headers (`columnWidth`
selector `CT_Delinquency.Delinquency`, 142) + sum of the widths of the preceding columns
(`columnWidth` by `metadata` = the column's `queryRef`, default 110) +
width / 2 − 10; y = 263 (picked by the user on screen: table.y
186 + 77; my estimate "+ 66 − 20" was higher). ⚠️ The user changes column and row-header
widths in Desktop (row headers 142 → 161) —
after such a save, recalculate the icons from the current `columnWidth`. ⚠️ The `queryRef`s of the `SalesSummary` columns
are old measure names (`Measure.PTP NotReal`, `PTP Promise Kept` …), the Property values are
current; `columnWidth` is looked up by `queryRef`. Tooltips: for the columns with
percentages and PTP Taken — the existing card pages (`TTPtpImmediate`,
`TTPtpTaken`, `TTPtpResolved`, `TTPtpPartKept`, `TTPtpKeptTotal`,
`TTPtpBroken`); for the rest — `TTPtpCol…` (520 px) with the measures `Tooltip PTP
Col …` (folder `Tooltip`).

**Tooltip text vertically centered** (the user's sample,
2026-10-09): the text measure starts with `UNICHAR(10240) & UNICHAR(10)` (an empty
first line — the U+2800 character; a regular space/empty line gets trimmed) and
ends with `& UNICHAR(10) & UNICHAR(10)`. Tooltip page height =
22 × lines (UNICHAR(10) + 1) + 20. **Hebrew lines** (ClientB 2026-10-26): Power BI lays each title line out
left-to-right, so "=", commas and brackets at a Hebrew line's edges land on the wrong side — wrap every
Hebrew line in `UNICHAR ( 8207 )` (RLM) on both ends (`VAR __RLM`). Applied to every `Tooltip …` measure of Collector Assignment (PTP since 2026-10-09; Scorecard and
`Tooltip Cured %` since 2026-10-23).

**"Immediate" → "Instant" (2026-10-09)** — report labels only:
column `displayName`s, card titles "Instant Promise %", tooltip
texts, the displayName of page `TTPtpImmediate` ("TT PTP Instant"). Measure names
(`PTP Immediate`, `PTP Immediate %`), page names and `queryRef`s were not changed.

### Visual name in the Selection pane (layers)

The **Selection** pane (Layers) in Power BI Desktop shows a name for each visual.
The source of this name is **`visualContainerObjects.title.text`**, not some separate
"layer name" or `general.altText` (that was the first, mistaken assumption — it was not
confirmed). Verified experimentally: renaming a layer in the Selection pane
(double-click → type text) is written precisely to `title.text`:

```json
"title": [
  {
    "properties": {
      "text": { "expr": { "Literal": { "Value": "'Page1'" } } }
    }
  }
]
```

This happens **regardless** of `title.show` — i.e. the container title can
be visually hidden on the canvas (`show: false` or no `show` set at all, which
by default is also hidden for most visuals), but the Selection pane will still
display the text from `title.text`. If `title.text` is not set explicitly,
Power BI shows a generic name based on `visualType` (`"Button"` for `actionButton`,
`"Slicer"` for a slicer) or on the name of the bound field (for slicers — if
several slicers have the same field, they will all have the same label in the layer list).

### Visual header icons (`visualHeader`) — full list of properties

`visualHeader` is an object that controls both the visibility of the header itself
(`show`) and the visibility of **each individual icon** in it (what the Format
pane groups into the **Icons** section). It is set at two levels with different
syntax:

- **In `visual.json`** (`visual.visualContainerObjects.visualHeader`) —
  wrapped in the standard `properties`/`expr`/`Literal` (like any other
  visual object):
  ```json
  "visualHeader": [
    {
      "properties": {
        "show": { "expr": { "Literal": { "Value": "true" } } },
        "showCopyVisualImageButton": { "expr": { "Literal": { "Value": "false" } } }
      }
    }
  ]
  ```
- **In the theme** (`visualStyles.<type>.<preset>.visualHeader`) — flat boolean
  values without a wrapper:
  ```json
  "visualHeader": [
    { "show": false, "showCopyVisualImageButton": false }
  ]
  ```

Full list of properties (in the order of the Icons section of the Format pane),
confirmed by a diff of `visual.json` before/after flipping the toggle in Power BI
Desktop (at the time the `developer.microsoft.com/.../visualContainer/2.12.0/schema.json`
link returned 404 — that URL is only an id. **Since 2026-10-15** 2.12.0 is published on
GitHub, local copies: [visualContainerSchema-2.13.0.json](../Schemas/visualContainerSchema-2.13.0.json),
[visualConfigurationSchema-2.8.0.json](../Schemas/visualConfigurationSchema-2.8.0.json) — check names
there first; flipping the toggle in Desktop and comparing the file is still the fallback
for versions not published yet):

| Icon in Format pane | Property |
|---|---|
| Visual information | `showVisualInformationButton` |
| Visual warning | `showVisualWarningButton` |
| Visual error | `showVisualErrorButton` |
| Drill on dropdown | `showDrillRoleSelector` |
| Drill up | `showDrillUpButton` |
| Drill down | `showDrillToggleButton` |
| Show next level | `showDrillDownLevelButton` |
| Expand to next level | `showDrillDownExpandButton` |
| Pin | `showPinButton` |
| Focus mode | `showFocusModeButton` |
| See data layout | `showSeeDataLayoutToggleButton` |
| More options | `showOptionsMenu` |
| Filter | `showFilterRestatementButton` |
| Help tooltip | `showTooltipButton` |
| Comment button | `showCommentButton` |
| Personalize visual | `showPersonalizeVisualButton` |
| Copy icon | `showCopyVisualImageButton` |
| Smart narrative | `showSmartNarrativeButton` |
| Set alert button | `showSetAlertButton` |

In the project, the global default for all visual types is set in
`visualStyles["*"]["*"].visualHeader` (`Classroom*.json`): `show: false`
(header hidden by default), but `showDrillUpButton`/`showDrillToggleButton`/
`showFocusModeButton`/`showOptionsMenu` = `true` — so if a specific
visual has `visualHeader.show` turned on locally (as `DetailsSummary` does), it
will inherit exactly this set of icons unless it overrides them individually.
