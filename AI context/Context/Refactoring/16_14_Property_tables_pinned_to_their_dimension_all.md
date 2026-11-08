Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 14. Property tables pinned to their dimension (all projects, user 2026-10-28)

Consider re-pinning `CustomerProperties` → `Customers` and `ItemProperties` → `Items` (snowflake), instead of a
many-to-many link straight to the fact (`Sales`). Target: `CustomerProperties[BP_KEY]` *→1 `Customers[BP_Key]`,
`ItemProperties[Item_KEY]` *→1 `Items[Item_KEY]`, both directions (the property table is on the many side: a key can have
several property rows); the old property ↔ fact relationships are deleted. Checks before:
- every property key exists in the dimension (else blank row); dimension key unique;
- measures that iterate / count the dimension (`AVERAGEX ( Customers, … )`, `DISTINCTCOUNT ( Customers[…] )`) — with the
  old link a property slicer did not filter the dimension, after the re-pin it does (BLANK-skipping averages stay equal;
  counts of dimension rows change = fix);
- property slicers: the old both-directions link to the fact narrowed their lists to values with sales in the current
  filters; after the re-pin they list every value (add a visual filter on a sales measure if needed);
- no ambiguous paths (RLS / role-playing calendars); values before = after by property value.
