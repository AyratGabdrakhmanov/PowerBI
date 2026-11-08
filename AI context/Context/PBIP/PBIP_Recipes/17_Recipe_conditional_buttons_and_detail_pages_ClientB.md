Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: conditional buttons and detail pages (ClientB Inventory Coverage, 2026-10-30)

- **Button active only when there is something to show:** text = measure (count in He / En), page navigation target
  `navigationSection` = measure returning the page **name** or BLANK. ⚠️ Desktop does **not** grey a button whose target is
  blank — bind fill / text colours to measures (`IF ( [N] > 0, [Blue Logo], [Grey] )`, `[Light]` / `[Grey Dark]`); every
  colour measure used must exist in the model (a missing `[Grey]` breaks the visual: "See details").
- **Invisible link:** same pattern, fill off, text measure returns `""` at 0 → nothing visible and nothing to click
  (`LinkDQ` → data-quality page).
- **Detail page = hidden page** (`visibility: HiddenInViewMode`; page name = display name, so the measure matches either),
  copy of the main matrix + back button; keep the main page's slicer selection with **synced hidden slicer copies**
  (`visual.syncGroup` `{groupName, fieldChanges, filterChanges}` on the main slicer, copies with the same group and
  `"isHidden": true` on the detail pages) — otherwise the detail page shows every group.
- **Conditional formatting by rule (no colour measure):** `objects.values` entry with
  `backColor.solid.color.expr.Conditional.Cases[{Condition: Comparison(ComparisonKind 3 = less than, Left: Measure, Right: 0D),
  Value: Literal '#F7E8E5'}]` and selector `{data: [{dataViewWildcard: {matchingOption: 1}}], metadata: '_Measures.X'}`
  (1 = values, not totals). "Red at 90 % transparency" = the red blended 10 % on the row background (`#C0392B` on
  `#FDFCFA` → `#F7E8E5`); CF rules have no transparency setting.
- **Data-quality page:** checks as a DAX table (`CT_DQCheck`: CheckID, IsIssue) + `[DQ Items #]` evaluating the selected
  checks per item + `[DQ Item Flag]` as the item matrix's visual filter (clicking a check filters the items); headers via an FP
  per language; the corner link counts issues only (`IsIssue = 1`), info checks never trigger it.
- ⚠️ **A user's Desktop window saves its current Language selection as the report default** (happened 3× on 2026-10-30):
  before publishing check `report.json` → `CT_Language` filter = `'He'`.
