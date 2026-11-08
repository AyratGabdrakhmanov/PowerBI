Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 28. Business row filters = SQL flag + hidden page filter (all projects, user 2026-10-30)

A rule that hides rows (e.g. "items with no stock and no open orders") is **not** a change of the SQL `WHERE`: the SQL
outputs a flag column (**INT 1 / 0**, e.g. `HasStockOrOrders` — flag rule, BPA `BP_FLAG_COLUMNS_INT_1_0`: whole number,
format `0` - shown as 1 / 0, no True / False format (user 2026-11-04), never Boolean), the model loads it (hidden) and a page filter
`= 1` applies it — **hidden + locked** in view mode. The row-header info icon (step 24) says what is hidden. Totals then
exclude those rows (tell the client). ⚠️ Until the first refresh with the new SQL the flag is empty — a Desktop save then
drops the filter value; set the filter after the refresh.
