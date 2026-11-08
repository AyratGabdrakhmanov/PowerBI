Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 13. Model view: tables without relationships top-left (all projects, user 2026-10-28)

Every table with no relationship (`_Measures`, `CT_*`, `FP_*`, disconnected calendars) goes into one column in the top-left
corner, one under another (`_Measures` first, then by name). Connected tables go right of it, top-down (rule below).
**Script (2026-11-07): `Scripts\ArrangeModelView.py <X.SemanticModel> [--remove-tabs] [--apply]`** (dry run first;
details `PBIP_Scripts.md`) does the whole step: cards collapsed, the unconnected column, connected tables top-down
(rule below: dimensions row, tables on both sides row, facts row; each dimension above its facts) and the fit zoom -
no Fit to page click. `--remove-tabs` keeps only the main tab (on request). ⚠️ Only with the report **closed** -
Desktop writes its in-memory layout back on save (`reload` does not re-read `diagramLayout.json`). A table renamed
via TOM keeps its old `nodeIndex` - rename the node first (ClientC 2026-10-28). The Properties pane state is not saved
anywhere (not in the PBIP, not in `User.zip`) - nothing to do for it. `StackDisconnectedTables.py` (left column only)
is superseded.
**Connected tables top-down** (⚠️ RULE, user 2026-10-30): right of the unconnected column, the
**dimensions** (one side of the relationships) form the **top row**, the **fact** tables (many side) the **second row**
below them - relationship lines run top -> down. Reference: ClientB Inventory Coverage as saved by the user 2026-10-30.
Done: ClientA Semantic Model 2026-11-07 (also 13 tabs removed on request).
**Display folders start with `__` in every table** (⚠️ RULE, user 2026-10-30; BPA `BP_DISPLAY_FOLDERS_DOUBLE_UNDERSCORE`,
was Calendar only): `__Value`, `__Key`, `__Filter`, `__Stock`, `__Color` … so the hierarchies (`_Item Group`, `_Year-Month`)
are listed below the folders. `CleanUnused.ps1` keeps measures in `Color` and `__Color`. ClientB Inventory Coverage done 2026-10-30.
