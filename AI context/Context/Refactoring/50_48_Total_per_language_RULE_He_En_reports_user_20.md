Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 48. "Total" per language (⚠️ RULE, He / En reports, user 2026-11-05)

Every matrix row / column subtotal label (`subTotals.rowSubtotalsLabel` / `columnSubtotalsLabel`) = measure
`[Label Total]` (`_Measures`, folder `_Labels`, hidden: He `סה"כ` / En `Total` by the language switcher, as the `Title *`
measures; first used in ClientB `Inventory Coverage`). No literal "Total" / `סה"כ`. ⚠️ **Tables: not possible** — a measure
in the table total label (`total.label`) renders an **empty** total cell in Desktop 2.159 (ClientC `Sales NEW`
2026-11-05, seen on `ניתוח עולם המכירות`); tables keep the default label (no `label` property). Check: script lists
matrices whose label is not the measure = 0; He + En view in Desktop. ClientC `Sales NEW` 2026-11-05: 22 matrices
(`Refactoring\Batch2_2026-11-05.py`).
