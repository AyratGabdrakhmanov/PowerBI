Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 45. A visual filter shared by every data visual → one page filter (all projects, user 2026-11-05)

When every data visual on a page has the same visual-level filter (same field, same values), or the visuals without it
already show a subset of it (e.g. `Year ID = 0` on 10 visuals, `Current Month` / `Current Quarter` = true on the others),
remove it from the visuals and set it **once as a page filter** (hidden + locked when it was hidden on the visuals). One
place to change, nothing to forget on a new visual. Move it only if no other visual changes:
- the visuals without the filter: their own filters fall inside it, and their measures get the same result: time
  intelligence on `'Calendar'[Date]` of a **marked date table** drops the extra Calendar filter (PY, previous month /
  quarter); a measure that filters other Calendar columns (`Calendar[Month ID] = -1` etc.) would be cut by it → stay;
- slicers: a dimension slicer is not affected; a slicer with a measure filter (`[Show Existing Sales] = 1`) lists
  only items that have data inside the new page filter — say so to the user;
- bookmarks on the page with data state: they keep the new page filter (it is not in their state) — check them.
Visual filters that differ per visual (team / family tables) stay. Check: script lists pages where one filter
condition is on every data visual = 0; values per visual before = after (snapshot / screenshot). ClientC `Sales NEW` ✅
2026-11-05: `דשבורד מכירות` (Sales dashboard) `Year ID = 0` from 10 visuals → page filter (as on `דשבורד יעדים`, Targets
dashboard); the other 6 visuals = current month / quarter, all TI on `'Calendar'[Date]`; no other page qualifies
(`ClientC\Sales New\Refactoring\Step45_PageFilter.py`).
