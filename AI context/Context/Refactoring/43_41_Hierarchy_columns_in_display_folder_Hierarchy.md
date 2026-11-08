Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 41. Hierarchy columns in display folder `__Hierarchy` (⚠️ RULE, all projects, user 2026-11-02)

Every column used as a level of a user hierarchy goes into the display folder `__Hierarchy` of its table (the
hierarchy itself stays at the table root). Not for `Calendar`, `_Measures`, `CT_*` and `FP_*` tables (Calendar keeps
the reference folders `__Year` / `__Month` …). A level column already in a `_He` / `_En` / `_Trans` folder moves too.
After 27 (folders). Check: script — every level column of a non-excluded table has `displayFolder: __Hierarchy`.
