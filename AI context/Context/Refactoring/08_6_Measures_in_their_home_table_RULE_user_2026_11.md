Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 6. Measures in their home table (⚠️ RULE, user 2026-11-01 — replaces "every measure in `_Measures`")

**A measure related to one table stays in its mother table** — it reads only that table (its columns and its own
measures): `Sales[Sales Value]`, `Sales[Sales YTD]`, `Targets[Targets Value]`, `Calendar[Remaining Working Days]`,
`Customers[Customers New]` (reference: Sales Channels, the user's layout). **`_Measures`** (step 1b) keeps what belongs
to no single table: measures combining several tables, the Color palette (`_Color`), labels / titles / tooltips / page
names, selector switches over several facts. A measure in a table it does not belong to (e.g. a sales measure in
`Calendar`, measures in a pure measure table such as `KeyData` / `Compare Period`) → move it to its mother table or
`_Measures`; a table that holds only measures is deleted after the move.
A ratio of two tables (`Target Achievement` = Sales ÷ Targets) lives in the table that gives it its meaning —
`Targets` (user 2026-11-01, as Sales Channels).
**Helper measures stay in their own table** (user 2026-10-30): `CT_Language[Selected Culture]`, `FP_X[Locale Match FP_X]`,
`<Table>[Show Existing <Table>]` (slicer visual filter), `CT_X[Selected_X]` selector values — hidden plumbing of that table.
Keep the display folders (`__` in tables, `_` in `_Measures`, step 27); keep measures hidden if their old table was hidden.
Moving either way: `MoveMeasures.ps1 -From X -To Y` (model) → `MoveMeasureRefs.py` (report) → `CheckReportRefs.py` →
bridge reload → save. ClientF `Sales.pbip` 2026-11-01 was moved the old way (26 into `_Measures`) — superseded by Sales v2.
