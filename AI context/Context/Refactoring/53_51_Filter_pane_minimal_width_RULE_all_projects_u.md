Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 51. Filter pane minimal width (⚠️ RULE, all projects, user 2026-11-05)

The filter pane opens at the minimal width: theme `visualStyles.page.*.outspacePane[0].width = 160` (theme, not per page
— step-22 waterfall; ThemeWarm master has it since 2026-11-05, `*/*` too since 2026-11-06). Desktop accepts 160
(checked 2026-11-06). Remove per-page `page.json` → `objects.outspacePane[0].width` (it beats the theme; keep other
pane properties). ClientC `Sales NEW` 2026-11-05 (custom theme `Classroom…json`); 2026-11-06 the theme had lost it —
re-added, 20 page widths (186–390) removed, backup `FilterPaneWidth_2026-11-06_052352`.
**Hidden from viewers** (user 2026-11-05): `report.json` → `objects.outspacePane[0].visible = false` (the pane stays in
Desktop / edit mode; viewers in the Service do not see it — the panel slicers are their filters). ClientC `Sales NEW` ✅.
**Then filters use the English columns** (⚠️ RULE, user 2026-11-05): with the pane hidden, every report / page / visual
filter (not slicers — users see their values; not empty drill-through fields) on a Hebrew column that has an `_En` twin
→ the twin + English values (bookmark copies too), and a hand-typed card title (`displayName`, e.g. `פתוח/הכל`) is
removed so the card shows the English field. Check the value map 1:1 by DAX first (rows matching old = new
condition). Script `ClientC\Sales New\Refactoring\HiddenFiltersToEn.py` (map inside). ClientC `Sales NEW` 2026-11-05: 34
filters (report: currency, doc status; page: area agent ×8, family ×11, item group ×2, doc agent, salesperson ×1;
visual: family ×12) + 28 bookmark states; 13 conditions equal by DAX.
