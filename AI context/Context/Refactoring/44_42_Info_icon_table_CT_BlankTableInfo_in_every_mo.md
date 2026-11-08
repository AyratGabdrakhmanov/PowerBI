Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 42. Info-icon table `CT_BlankTable[Info]` in every model (⚠️ RULE, all projects, user 2026-11-02)

Every model has the hidden DAX table `CT_BlankTable` (columns `Blank` = "" and `Info` = `UNICHAR ( 128712 )` = 🛈) — the
source of the ⓘ icons (button slicer on `CT_BlankTable[Info]` → tooltip page, recipe `PBIP_Recipes.md` "info icons").
Source: reference `DAX PRO Solutions\CT_BlankTable.json` (2026-11-03; was copied from ClientB `Inventory Coverage`). **`CleanUnused.ps1` never deletes it**
(since 2026-11-02.1), even when no icon uses it yet. DAX calculated table — out of scope of step 39; `Calculate` fills it.
Before 29 / 9 (info icons are added in phase D). Check: script — `tables\CT_BlankTable.tmdl` exists with column `Info`.
ClientB `Sales_ClientB`: ✅ 2026-11-02 (added with the data-freshness ⓘ icon).
