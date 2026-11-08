Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Page layout and ordering rules (2026-10-10)

The user's rules; first applied to `Collector Assignment` when
moving the `Collateral` pages (see the example below).

### ⚠️ RULE: integer position and size for every visual (user, 2026-10-16)

`position.x / y / width / height` in every `visual.json` are **integers** — for every visual
created or moved, and fractional values found in a report are rounded. Round **by edges**,
not each number: `x = round(x)`, `width = round(x + width) − x` (same for `y`/`height`), so
visuals that touched still touch exactly (no hairline gaps/overlaps); `floor(v + 0.5)`, not
Python's banker's `round`. Collector Assignment 2026-10-16: 228 values in 140 visuals on 23
pages (e.g. `20.20685297859634`, a tab of height `35.555…`), backup
`ClientA\BackUp\2026-10-16_RoundPositions_CollectorAssignment`. Tabs then: no gaps on any `Tabs *`
page; the first tab (`299 + 242`) overlaps `Details 1` (`540`) by 1 px on purpose (design
2026-10-16, it sits on top).

### Grid (background `Background*.svg`, 1920×1080)

The background draws a grid: left panel `0–300` (grey `#E0DED9`), main area
`300–1920`, lines — horizontal `y = 175` (`330–1890`), horizontal
`y = 627.5` (two halves), vertical `x = 1110`.

| Rule | Values |
|---|---|
| **20 px from the canvas / section edge** (was 30, changed 2026-10-10) | main area `x 320…1900`, `y 20…1060`; left panel buttons `x 20…280` (width 260) |
| **15 px to the canvas lines** | `y 175` → a visual above ends at `160`, below starts at `190`; `y 627.5` → `612` / `643`; `x 1110` → left half up to `1095`, right half from `1125` |
| **Filters (slicers) — full section width** | `x 0`, width `300` |
| **Exception — half width** | slicers: `0/150` and `150/150`; buttons: `20/125` and `155/125`; the right element of a pair — at the `y` of the left one (do not touch the height) |
| **Cards** | in a row with the same `y` and height (`20…160`); stretch the widths proportionally so the row fills the section, gaps ≤ 30 px (currently ~20) |
| **Visual spanning several sections** | the edges that are near lines/edges (± 40 px) get aligned; the other edge stays in place — the size barely changes |
| **Small overlays** ("i" icons 20×20, TT icons 100×100) | are not aligned on their own, but move together with the host visual: above a table — from its left edge (fixed-width columns), above a card at the right edge — from the right |
| **Helper shapes** | hidden `shape`s ≈ 15×15 / 20×20 / 15×45 (served as alignment anchors) — delete |

Test pages (they get hidden anyway) are not aligned.

### Page order and visibility

- A report with several "sub-reports" is divided by hidden empty pages
  `<<< Report name >>>` (folder `Sep<Name>`, `visibility: HiddenInViewMode`, no
  visuals) — at the start of each section.
- Tooltips (`type: Tooltip`) — at the end of their section.
- Test pages — hidden: the name contains `Page`, `test`, `data quality`,
  `Details` (and drafts such as `Tree`, `Duplicate of …`, `Scope`).

### Example: `Collector Assignment` + `Collateral` pages (2026-10-10)

The `Collateral` pages were copied into `Collector Assignment` (folder `Overview`
→ `CollateralOverview`, displayName `Collateral Overview` — a name collision;
navigation to it was rewritten). 7 Collateral tables were added to the model
(`CollateralAction`, `CollateralActionFee`, `CollateralActionType`,
`CollateralWorkflow`, `DealerData`, `LoanData`, `LastDatabaseUpdate`), their
measures, 18 relationships, `ref table` + `PBI_QueryOrder` in `model.tmdl`. Shared
tables (`Calendar`, `Measure`, `CT_ReportType`…) — the
`Collector Assignment` versions. The `Collateral` report-level filters (`LID[LID]`,
`LID[LoanID]`, `LoanData[Portfolio]`) became page filters on the Collateral pages.
The source `Collateral` report was not touched.

⚠️ A measure's result type (text/number) cannot be determined either via TOM
(`Measure.DataType` = Variant) or via `INFO.MEASURES()`/
`MDSCHEMA_MEASURES` (all Variant) — only from the value of
`EVALUATE ROW("v", [MeasureName])` (for blank ones — from the expression). This is needed so as not to
apply a numeric format to text measures.
