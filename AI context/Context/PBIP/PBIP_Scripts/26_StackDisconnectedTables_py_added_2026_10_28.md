Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `StackDisconnectedTables.py` (added 2026-10-28)

`ClientA\_Documentation\Scripts\StackDisconnectedTables.py <X.SemanticModel> [--apply]` — refactoring step 13: in
`diagramLayout.json` every table without a relationship goes into one column at the top left (`_Measures` first, then
by name, 20 px gaps), every expanded card is collapsed (`expandedHeight` keeps the open height); connected tables move
right only if they overlap the column. Dry run by default; `--apply` backs up to `<project>\BackUp\StackDisconnectedTables_<ts>`.
**Report closed only** — `powerbi-desktop reload` does not re-read the layout and Desktop writes its own back on save.
Then open → Model view → Fit to page → collapse the Properties pane (mouse click, see `AI_Tools_MCP_CLI.md`) →
`SaveDesktop.ps1` (the zoom is stored in `diagramLayout.json`).
