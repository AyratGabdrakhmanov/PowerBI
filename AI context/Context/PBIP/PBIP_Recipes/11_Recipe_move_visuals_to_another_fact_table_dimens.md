Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: move visuals to another fact table / dimension, page by page (ClientD Finance JE → JEC, 2026-10-23)

Live, Desktop open, one page at a time; the model is changed only where a measure itself must change.
1. **Inventory**: `TableUsage.py --tables "<old tables>"` (visuals, incl. measures that depend on them),
   `FindUnusedColumns.py` (which columns of the old table are really used), the page's slicers and their saved
   selections, the bookmarks that show the page's visuals (`explorationState.sections.<page>.visualContainers`).
2. **Prove the numbers first** — DAX query with the visual's saved selections as `TREATAS`, old measure vs the
   replacement side by side (`DEFINE MEASURE` for a rewritten one), cell by cell / `EXCEPT` both ways. Watch context
   that only exists in the old layout: `SELECTEDVALUE ( OldDim[GroupMask] )` was blank where the old dim was not in
   rows, so a condition on it never fired — the replacement must keep that behaviour (use the plain measure there).
3. **Prefer existing measures** (user rule: no new measures); a missing behaviour often is a visual filter
   (`DocumentTypes[TransType] ≠ -3` instead of a "without closing" measure).
4. **Fields**: `ReportFields.py replace --visuals <page's visuals>` per pair (columns, hierarchy levels → column or
   level; it also fixes alias `From` lists, `identityKeys`, saved selections and the bookmark states of those
   visuals). Then a page-specific post-step for what it does not do: measures (`Measure` Entity + `queryRef` /
   `metadata` strings + filter aliases), removing helper fields (sort columns like `GrpLine`, index measures) from
   projections / sort / `objects` selectors / filters, empty filter cards on dropped fields, new filters — **in the
   visual AND in each bookmark state** (`filters.byExpr`, `orderBy`, `activeProjections`), or a bookmark click drops
   the new filter. Check duplicates (two old fields mapping to one new field — drop one first).
5. Run steps 4 on a **copy** of the report first; print every leftover reference path; then on the live files with a
   full backup; `powerbi-desktop reload`; screenshot before / after and compare (visible matrices).
6. Restore visible labels: a hierarchy level showed its level name (`_`) — set `displayName` on the new field.
7. Model last: move measures hosted in tables that go (same name, lineage tag, format — TOM `Clone` + Remove + Add,
   report refs with `MoveMeasureRefs.py`), save, then delete the tables;
   clean `PBI_QueryOrder` and the Q&A blob via TOM (`Culture.LinguisticMetadata = $null`), save, check the files.
8. Filters on an old dimension's attribute columns (e.g. `Accounts[FaterAcc3] = "100000000000000"`): map each value to
   the new dimension on data first (`SUMMARIZECOLUMNS ( old col, new col, COUNTROWS )` — one-to-one?, rows missing in
   the old table?), then prove old vs new filter on the visual's measure. A KPI whose trend axis is such a constant
   column: put a column that is single-valued under the page slicers (`Calendar Date[Year]` with a single-select year
   slicer) — never a column with several values in the filter (the KPI shows only the last point). Screenshot twice: the
   first one after a reload can catch visuals still rendering blank.
Details of the ClientD run — `ClientD_Context.md`.
