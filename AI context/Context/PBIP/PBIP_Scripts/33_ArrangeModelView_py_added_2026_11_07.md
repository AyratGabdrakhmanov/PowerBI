Part of [PBIP_Scripts.md](../PBIP_Scripts.md).

## `ArrangeModelView.py` (added 2026-11-07)

`python -I -X utf8 ClientA\_Documentation\Scripts\ArrangeModelView.py <X.SemanticModel> [--remove-tabs] [--apply]` -
refactoring step 13, the whole Model view layout of the main tab (first diagram in `diagramLayout.json`):
- every card collapsed (`expandedHeight` keeps the open height);
- tables without relationships - one column top-left (`_Measures` / `Measure` first, then by name);
- connected tables top-down right of that column: dimensions (one side only) row 1, tables on both sides row 2, facts
  (many side only) row 3; each dimension sits above the tables it links to (fewer crossing lines);
- zoom fitted to the whole layout and scroll reset - no Fit to page click needed.

`--remove-tabs` also deletes every other Model view tab. Dry run by default (prints the rows); `--apply` writes and keeps
`diagramLayout.json.bak_<ts>` next to the file. **Report closed only** - Desktop holds the layout in memory and writes it
back on save. A table renamed via TOM keeps its old `nodeIndex`; the script warns when a related table has no node.
Supersedes `StackDisconnectedTables.py` (which only did the left column). First run: ClientA Semantic Model 2026-11-07
(13 tabs removed, 21 / 11 / 1 / 8 tables).
