Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 21. Active visual filters last (all projects, user 2026-10-28)

In the filter pane of a visual, the filters that have a selection / condition (not `is (All)`) go **last** in "Filters
on this visual" — directly above "Filters on this page" / "on all pages", so the active filters of all three levels are
seen together. Unfiltered field cards (`is (All)`) stay above, in their current order. PBIR `visual.json` →
`filterConfig.filters`: the array order is the pane order (`filterSortOrder` = `Custom` when present); move the entries
with a `filter` expression to the end, nothing else changes. Check: script lists visuals where an active filter
precedes an `is (All)` one = 0, `pbir validate`, values unchanged. ⚠️ **v2 (user 2026-11-05):** the visual's own fields
that are not listed in `filterConfig.filters` are shown by Desktop **after** the listed entries — a visual whose only
entry is the active filter still shows it first (ClientC `1ccd62d5…`). So: add the missing query fields as idle entries
before the active ones and set `filterSortOrder = Custom` — script `ClientA\_Documentation\Refactoring\step21_filters_last_v2.py`.
ClientC `Sales NEW` 2026-11-05: 170 visuals, 274 field cards added. ⚠️ **v2.1:** every card gets `ordinal` = its position —
with `Custom` order Desktop sorts by `ordinal`, and mixed cards (some numbered from older edits, most not) still showed the
active filter first (`c8cae899…`); re-run: 173 visuals renumbered.
