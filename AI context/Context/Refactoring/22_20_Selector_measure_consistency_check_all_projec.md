Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 20. Selector measure consistency check (all projects, user 2026-10-28)

Every `SWITCH` / `DIVIDE` branch over selector IDs (currency, doc status, measure type, date type) must return the
measure that matches its condition: Local → Local measure (no `Sys`), System → `Sys…`, Open → `…Open…`, All → no
`Open`, Sales / Quantity / Profit → the matching measure. Check: `python -I -X utf8
Refactoring\ClientC\check_selector_branches.py "<X.SemanticModel>"` (tokens from the ID comments `/* Local */` or the
variable names `__Local`; prints flagged branches). A fix is a **bug fix that changes values** — snapshot all selector
states before / after, report the changed values; every other branch must stay equal.
