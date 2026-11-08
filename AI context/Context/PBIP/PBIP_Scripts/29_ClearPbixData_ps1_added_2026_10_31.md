Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `ClearPbixData.ps1` (added 2026-10-31)

`Scripts\ClearPbixData.ps1 [-Pbix <file>]` — empties a `.pbix` (smaller file to publish / share / sync; the report is
empty until the next refresh): opens it (or uses its open window), TOM `RequestRefresh(ClearValues)` on the model,
`SaveDesktop.ps1` with the `.pbix` as the timestamp target, closes the window it opened. Copies next to the `.pbix` in
ClientB `Sales Report` / `Stock Report`, ClientC `Sales New` / `RAN NEW` (no `-Pbix` = the only `.pbix` in its folder).
Tested on a copy of `Sales_ClientB.pbix` (3.6 → 1.0 MB). A refresh is not faster after it; only the peak memory is lower.
Change the master in `Scripts\`, then re-copy.

**`ConvertPbixToPbip.ps1`** (2026-10-31) — launcher copied next to the same four `.pbix` (master in `Scripts\`):
`pwsh -File ConvertPbixToPbip.ps1 [-Pbix <file>] [-Force]`. The user only refreshes data in the `.pbix` and never edits its
report (user 2026-10-31), so with a PBIP of the same name next to it the launcher **updates that PBIP: model + data only** —
`<Name>.SemanticModel\definition\` and `.pbi\cache.abf` from the `.pbix`; report, `diagramLayout.json`, `.platform`,
`.pbism` and `.pbi` settings stay. Steps: guards → `PbixToPbip.ps1` into `%TEMP%` (hidden engine) → report compared by JSON
content (differences only listed, never written; `pages.json` = start page, ignored) → changed TMDL files listed → backup
to `<project>\BackUp\PbixToPbip_<time>\` → replace. Guards: Desktop must not have the PBIP open; no PBIP model file may be
newer than the `.pbix` (the ClientB 2026-10-19 loss) unless `-Force`. No PBIP yet → full conversion into the folder.
Tested 2026-10-31 on a copy of ClientB `Inventory Coverage` (guard stopped: 15 newer files; `-Force`: 3 model files changed,
report same, backup written). Used for ClientC `Sales NEW` 2026-10-31 (user's `.pbix` with `Items[Family]` from SQL).
