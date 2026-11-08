Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 24. Info icons on matrix headers (all projects, user 2026-10-26 / 30)

Every matrix column whose meaning is not obvious gets an info icon at the **top-right corner** of its header: a 20×20
copy of the `Info*` visual → hidden tooltip page `TT<Key>` → hidden He / En measure `[Tooltip <Name>]` (folder `_Tooltip`).
The **row header** gets one too when rows are filtered (what is hidden and why). Icon color = `[Blue Logo]` (color measure,
step 17), never a literal. Fixed column widths (`columnWidth`) so icons stay in place; widths + row header add up to the
visual width (last column not cut by the scrollbar). Rename a measure → rename its tooltip measure / page / icon text.
**Tooltip text must fit its page — in both languages** (⚠️ RULE, user 2026-10-30): after any tooltip text / page change run
`Scripts\CheckTooltipFit.py "<X.Report>"` with the report open, once per language (switch the `CT_Language` default +
`reload`, restore He after); every page `ok`. Fix = shorter lines (≤ ~45 characters) and a taller tooltip page + its box.
ClientB Inventory Coverage 14 tooltip pages, He + En 0 problems (2026-10-30).
**Icon position check** (user 2026-11-05): `Scripts\CheckInfoIcons.py "<X.Report>" [--fix]` — y = table y + 27 (title
on; a table / matrix title is off unless set on) or + 1, x = table x + 10 + column widths − 8 (first `columnWidth` entry);
`--fix` snaps icons within 10 / 15 px. Matrices are reported off by the row-header width — check them on a screenshot.
ClientC `Sales NEW` 2026-11-05: 74 snapped, 270 / 274 on the rule (4 matrix icons right on screen).
