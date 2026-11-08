Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 47. One company → no company slicer / filter (⚠️ RULE, all projects, user 2026-11-05)

When the model has one company (`COUNTROWS ( Companies ) = 1` and all fact rows belong to it — check by DAX first), the
report has no company slicer, no company filter on any level (report / page / visual) and no company state in bookmarks.
The `Companies` table and its measures stay (currency, labels). Check: script finds 0 report references to `Companies`
outside measures. ClientC `Sales NEW` ✅ 2026-11-05 (1 slicer on `דשבורד מכירות` (Sales dashboard), report filter
`חברות` (Companies) = `קנט-לי (1997) בע"מ (07)` (Kant-Li (1997) Ltd (07)), 28 bookmark states — 4 of them still held other companies).
