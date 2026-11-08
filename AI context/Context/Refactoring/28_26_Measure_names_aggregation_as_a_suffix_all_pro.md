Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 26. Measure names: aggregation as a suffix (all projects, user 2026-10-30)

`AVG` at the end in capitals (`Avg Monthly Sales #` → `Monthly Sales # AVG`) so related measures sort together
(`Sales`, `Sales #`, `Sales # AVG`). BPA `BP_MEASURE_AGGREGATION_SUFFIX_AVG`. Rename = measure + `[refs]` + cultures + FP
`NAMEOF` + `visual.json` (`Property`, `queryRef`) + tooltip measure / page / literal texts; grep the old name → 0.
