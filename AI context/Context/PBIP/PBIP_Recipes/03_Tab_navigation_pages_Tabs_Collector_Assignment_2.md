Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Tab-navigation pages `Tabs *` (Collector Assignment, 2026-10-16)

A new page design: a horizontal tab menu on top instead of the column of navigation buttons
in the left panel. Template — `Tabs Overview` (folder `a98d284b46eac8ae4cc7`, visible; built
by the user from `Overview`). Copies, all `HiddenInViewMode`, right after it in `pages.json`:

| Page (folder) | displayName | Source page (content) |
|---|---|---|
| `TabsDetails1` | Tabs Details 1 | `Details1` |
| `TabsDetails2` | Tabs Details 2 | `Details2` |
| `TabsDailyTrend` | Tabs Daily Trend | `DailyTrend` |
| `TabsByCollector` | Tabs By Collector | `da771340baa5906002a0` (By Collector) |
| `TabsDPDByDate` | Tabs DPD By Date | new (2026-10-16, Azure #49, contract `C-CA-49`): matrix + 2 charts, no cards |

The old source pages stay as they were.

**Second tab set: Overview (Scorecard) + Bucket Summary + Roll Rate MTD (2026-10-24, for review, top-down:
department → bucket → individual).** Its own 3-tab row (not linked to the
6 tabs above): `TabScorecard` (copy of the first tab `4165c3f08162d25718c1`, `x 299 w 242`, text `[Page Name
Overview]` — the existing measure, user 2026-10-24) + `TabBucketSummary` (copy of `4a51cb676dd3af151965`, `x 540 w 228`, `[Page Name Bucket Summary]`,
folder `Navigation`); presets as in the table below. Top-left button = the page's own "Scorecard" button
`4cd20746e9664e6d54d8` (20/20 260×45).

| Report | Pages |
|---|---|
| Semantic Model | `TabsScorecard` "Tabs Scorecard" (visible, after `CollectorScorecard`; copy of it) + `TabsBucketSummary` (hidden; from the test copy's `BucketSummary`) + `TabsRollRateMTD` (hidden; from the test copy's `RollRateMTD`, third tab `TabRollRateMTD` `x 768 w 228`, `[Page Name Roll Rate MTD]`) + `TabsRollRate` "Tabs Roll Rate" (hidden; copy of `TabsRollRateMTD`, 2026-10-26, fourth tab `TabRollRate` `x 996 w 228`, `[Page Name Roll Rate]`, on all four `Tabs*` pages of this set; `RRMDays` → `[Roll Rate Assign MTD Value]`, its `State` visual filter moved into the measure; `RRMTitle` → `[Roll Rate Assign MTD Title]`) + `TabsRollRateOverview` (hidden **drillthrough** target, from `RollRateOverview`); the old `CollectorScorecard` page unchanged |
| Thin Scorecard | the whole tab set of the main report (2026-10-28, user: "Apply Tabs design to thin report"; the earlier port reverted in `e565bf8` waited for the main report): `CollectorScorecard` (keeps its name and displayName = main `TabsScorecard`, every `'TabsScorecard'` link repointed to it) + `TabsScorecardDetails` (Details, re-port 2026-10-28) + `TabsBucketSummary` / `TabsRollRateMTD` / `TabsRollRate` (hidden, as in main) + drillthrough `TabsRollRateOverview`, all 19 `TTSc*` tooltip pages, `Background_tabs…svg`, the main `ThemeWarm…json`. Re-port = copy the main pages again with the same rename |

Scorecard on the grid: 7 cards as below; `TeamComparison` `320/266 1581×385` (no `ScoreBreakdown` since 2026-10-27, its data = Score step columns); header info icons
keep their offset from the matrix top (+76); `ScoreTrend` `y 682 h 378`; `MonthPeriod` / `MonthPeriodInfo` keep
their offset from the chart top. Bucket Summary (no cards, like DPD by Date): `BucketTable 320/80 1180×980` with title =
`[Bucket Summary Title]` (no Bucket column, no separate title card — user 2026-10-24); the test page's left navigation buttons
(`Page1`, `NavRollRate`, `NavByBucket`, `Page4`, `PageDD13`, `PageDD1`) and `BSTitle` are dropped.
Left panel of Bucket Summary / Roll Rate MTD: Reporting Month, the bucket buttons `TeamSlicer` (one column, Units/USD
style, `CT_Delinquency` without `Current`), Collector Name, Units/USD — positions set by the user in Desktop.
Roll Rate MTD: `RRMTitle 320/80 1180×70`, `RRMRate 1520/80 380×70`, `RRMAvg 320/170 420×890`, `RRMDays 760/170
1140×890`. Roll Rate Overview (drill page): `BackButton` (Loan Details' Back button) `20/20 260×45`, `RRTitle
320/80 1580×70`, `RRByDay 320/170 1000×890`, `RRSummary 1340/170 560×470`, `RRTrend 1340/660 560×400`; drillthrough
field `Calendar[Date Short]` (= the day columns of `RRMDays`; `pageBinding` type `Drillthrough` + a filter with
`howCreated: Drillthrough`, as `LoanDetails`), keep-all-filters default → the bucket buttons and Collector Name pass
through; no bucket slicer on the drill page (it would AND with the passed bucket).

**2026-10-28 (user): tabs Summary | Details | Team Summary.** `TabScorecard` text → `[Page Name Summary]` (on all
`Tabs*` pages of this set; `[Page Name Overview]` stays for the first tab set). New tab `TabDetails` (copy of
`TabBucketSummary`, `x 540 w 228`, `[Page Name Scorecard Details]`) → new hidden page `TabsScorecardDetails` (copy of
`TabsScorecard`); `TabBucketSummary` moved to `x 768`; `TabRollRateMTD` / `TabRollRate` `isHidden` on the three
pages (Roll Rate pages themselves untouched). Presets: own tab `…Active` (first tab `GreyShadeTabFirstActive`).
Summary left panel: `Queue` dropdown → `TeamSlicer` (3 columns × 2 rows, `0/356 300×170`), the slicers below moved
down 80. Info icons: x = column right edge + 2 (edge = matrix x + row header width + column widths). Built by one
script (scratch, not kept) — re-run by hand if the tab set is rebuilt.

⚠️ **Copying a button slicer copies its sync group.** `TeamSlicer` was built from `HieParameter` (Units/USD) and
kept `syncGroup.groupName = "Type"` — the bucket buttons were synced with Units/USD (2026-10-24). They now have
their own group **`Bucket`** (Bucket Summary ↔ Roll Rate MTD share the selected bucket). After copying any slicer,
check `visual.syncGroup`.

### ⚠️ The first tab (Overview) is different from all other tabs (user design, 2026-10-16)

The first tab of every `Tabs *` page — visual `4165c3f08162d25718c1`, text `Page Name Overview`, link → `Tabs Overview` — is built differently from the other five (`Details 1`, `Details 2`, `Daily Trend`, `By Collector`, `DPD by Date`). Do not "unify" it with them, and when adding a new tab page copy the first tab from `a98d284b46eac8ae4cc7`, not a neighbour:

| | First tab | Other tabs |
|---|---|---|
| Style presets | **`GreyShadeTabFirstActive`** (only on Tabs Overview) / **`GreyShadeTabFirstInactive`** (all other pages) | `GreyShadeTabActive` (own page) / `GreyShadeTabInactive` |
| Shape (in the style) | `tileShape: tabRoundCorner`, "Rounded top right corner" **35 %** (`tabRoundCornerTopRight: 35`) — a different setting from the other tabs | `tabRoundTopCorners`, "Rounded top corners" **35 %** (`tabRoundCornerTop: 35`; user: "35% as default") |
| Position | `x 299`, `width 242`, `z` high — wider by 1 px each side: it overlaps `Details 1` (`540`) by 1 px and sits on top of it | `x 540 / 768 / 996 / 1224 / 1452`, `width 228` |
| Container settings, **local** | `dropShadow` (`Custom`, angle 270, blur 3, transp. 86, `show: false`), `background` (`show: false`), `padding.top: 0` | none |

The first-tab styles are full copies of the tab styles (the "whole array" rule) that differ only in `shape`; the container-level settings stay local on purpose (a preset merges the object and container levels under one key — see `PBIP_Theme.md`). Which tab looks "selected" is decided only by the preset (`…Active` on the page's own tab), not by shape or geometry. Source of the design: the first tab of `Tabs Overview`, backup `ClientA\BackUp\2026-10-16_TabsDesign_CollectorAssignment`; the first-tab styles were added 2026-10-16 after the presets' `roundEdge` became 35 and changed the first tab (backup before: `ClientA\BackUp\2026-10-16_FirstTabStyle_CollectorAssignment`).

**Layout** (differs from the 2026-10-10 grid: the content starts lower):

| Element | Values |
|---|---|
| Background | `Background tabs.svg` (`Background_tabs5945256581416164.svg`): grey left panel `0–300`, white top band `x 300–1920, y 0–55` |
| Tabs (6, `actionButton`, presets `GreyShadeTab*`) | 6th tab `DPD by Date` (visual `TabDPDByDate`, `x 1452`, width 228, measure `Page Name DPD by Date`) added 2026-10-16 on all 6 pages. `y 20`, height 36. Tab *k* ends in the **middle of the gap between card k and k+1**: Overview `300/240`, then `540, 768, 996, 1224` width 228. Text — measures `Page Name Overview / Details 1 / …`; the page's own tab is `GreyShadeTabActive`, the rest `GreyShadeTabInactive`; **the FIRST tab is different from the others — see "⚠️ The first tab is different" below the table;** Overview tab → `Tabs Overview`, others → the `Tabs*` pages |
| Left panel buttons | `Collector Assignment` (`GreyShadeActive`, → Tabs Overview) `20/20 260×45`; `Assign. Details` (drillthrough) `20/80` |
| Cards (7) | `y 80`, height 140, **equal width 212, gap 16**, `x = 320 + i·228` → `320…1900` |
| Main content | `x 320…1900`, `y 266…1060`; the source page's content block is scaled into this box keeping its relative layout |
| Slicers (left panel) | stacked without gaps from `y 266`, **height 90**; pairs `0/150` + `150/150` kept as rows; `Hie Parameter` (`advancedSlicerVisual`) `0/1025 300×35` |
| Slicer formatting ("new, bigger") | `header.textSize` 14, `items.textSize` 14, `items.padding` 3 → 1.5 (only where it was 3) |

**How the copies were built** (one Python script, 2026-10-16): `page.json` from Tabs Overview
(background) + the source's `filterConfig` (`Closed Period`) and `visualInteractions`; visual
folder names kept from the source (so interactions stay valid); tabs and the two left
buttons copied from Tabs Overview. Not copied: the old navigation buttons (Overview, Details,
Promise To Pay, Scorecard, PTP Details) and the 3 separator `shape`s of By Collector (the
slicers moved to the new grid). Content slicers ("Choose Measure to Show") keep their old
formatting.

**Matrix column width on these pages:** the theme sets `pivotTable.columnHeaders.columnAdjustment =
fixedWidth` (`defaultColumnWidth` 100) — a new matrix gets narrow columns with cut values
(`15,404,2...`); `autoSizeColumnWidth` in the visual does not help. Set the widths in
`objects.columnWidth`, `selector.metadata` = the field's `queryRef` (as on Overview):
`DPDMatrix` — row header 110, values 112 (`#,0` up to 99,999,999 at 14 pt).

Open points: `Tabs Overview` itself has **no** `Closed Period` page filter (Overview and the
copies have it) — ask whether it was removed on purpose.
