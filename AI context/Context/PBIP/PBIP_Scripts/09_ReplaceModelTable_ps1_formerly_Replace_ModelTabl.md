Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `ReplaceModelTable.ps1` (formerly `Replace-ModelTable.ps1`)
File: [`ClientA\_Documentation\Scripts\ReplaceModelTable.ps1`](<../../../Scripts/ReplaceModelTable.ps1>)
(version `2026-10-16.3`). The single entry point for a table swap — model and report. The report
side is `ReportFields.py` (below; `replace`, `drop-filters`, `refs`). Three modes:

| Mode | When | Does |
|---|---|---|
| default | Desktop **closed** | TMDL on disk: `relationships.tmdl` (`fromColumn`/`toColumn`), `model.tmdl` `ref table` list, `cultures\*.tmdl` (`"ConceptualEntity"`, exact match only), report, deletes the old `.tmdl` (`-KeepOldTableFile` to keep). Built for `_LID` → `LID` (Model_v2). |
| `-ReportOnly` | report only | drop-filters + replace; the old table may already be gone from the TMDL → rename mode |
| `-Port N` | Desktop **open** | the whole swap live, never closes Desktop (steps below) |

```
pwsh -File ReplaceModelTable.ps1 -OldTable _LID -NewTable LID -RootPath <...>
pwsh -File ReplaceModelTable.ps1 -OldTable CustomersSmall -NewTable Customers -RootPath <...> -ReportOnly
pwsh -File ReplaceModelTable.ps1 -OldTable Customers -NewTable CustomersSmall -RootPath <...\ClientB\Report> -Port 52992 `
     -KeepName -DropFilters CardType -SkipRelationships DocsPurchs.CastLicTradNum `
     -ActivateRelationships 'DocsPurchs.CastLicTradNum->ETL_MD_LicTradNum.LicTradkEY' -DryRun
```

**`-Port` steps.** Order matters: a Ctrl+S after TOM writes Desktop's in-memory report over the
files, so report edits are applied in Desktop before any TOM change.
0. Checks: both tables in the model on this port (wrong port / file → stop); DAX (comments
   stripped) and report fields (`ReportFields.py refs`) that use columns only the old table has →
   **stop** unless `-Force` (columns in `-DropFilters` are fine); Desktop found by the `.pbip` path
   (`-DesktopPid` to override); unsaved changes → Ctrl+S.
1. Backup `*.SemanticModel` + `*.Report` → `<RootPath>\..\BackUp\ReplaceModelTable_<ts>\` (the
   sub-tools' own backups go inside it).
2. Report: `drop-filters` on `-DropFilters` (list → `-FilterList`, default
   `<RootPath>\DroppedFilters_<Old>_<ts>.md`), then `replace Old → New`.
3. `powerbi-desktop reload` (apply external changes).
4. TOM (reconnected after the apply): column properties Old → New for shared columns
   (`SortByColumn`, `FormatString`, `IsHidden`, `DisplayFolder`, `Description`, `DataCategory`,
   `SummarizeBy`); Old's relationships dropped and re-created on New with the same cardinality /
   direction / active flag — except `-SkipRelationships` (by the other side's column) or a column New
   lacks; `-ActivateRelationships` (a path that would be ambiguous while Old's are there); Old
   deleted; `-KeepName`: New → Old's name (+ partition); `RequestRefresh(Calculate)`.
5. Objects in error via `QueryOpenModel.ps1` (`INFO.MEASURES / COLUMNS / RELATIONSHIPS`).
6. Ctrl+S — `Save-Desktop`: the window is brought forward via user32 and the foreground pid is
   checked before the keys are sent (plain `AppActivate` sent them to another window when two ClientB
   windows were open); waits for a SemanticModel file newer than the start.
7. `-KeepName`: `replace New → Old` in the report (rename mode), `reload`.

Before a `-Port` run: rewrite DAX that uses Old-only columns (TOM / MS MCP) and move report fields on
Old-only columns other than filters (`ReportFields.py replace`) — step 0 lists them. Do it as
TOM → Ctrl+S → report edits on disk (a Ctrl+S after disk edits overwrites them). With `-KeepName`, DAX
text `Old[...]` stays valid — no rewrite for shared columns. `-DryRun` = checks + report preview +
the relationship plan, nothing written.

**Tested 2026-10-16** on a ClientB copy open in Desktop (state before the manual swap): step 0 stopped on
exactly the 3 items handled by hand (2 measures on `CardType`, `CodeNameBP` in the report); after
those, the run gave the same report, `Customers.tmdl`, `KeyData.tmdl` and relationships as the manual
swap on the real ClientB file (only `.pbi/localSettings.json` differed).

**Not for swapping in a template table under a new name** (ClientB `Date` → central `Calendar`, 2026-10-18):
step 4 copies the old columns' `FormatString` / `SummarizeBy` / … onto the new table (the template's
formats are lost; an int `Year` would get the old date column's "Long Date"), and the old table is deleted
without removing its culture translations first (TOM refuses: "The translation … references an object …
that has been deleted"). Use the recipe "swap a legacy date table" in `PBIP_Recipes.md` instead.

The default mode first compares the columns / types of both tables and warns, without blocking
(a calculated column shows as `(calculated)`). Used for `_LID` (calculated table, `LID` string) →
`LID` (dataflow, `LID` int64), which also fixed a hidden type mismatch in existing relationships.

**Drillthrough fields (verified 2026-09-15):** a page's drillthrough field is stored in `page.json`
twice — `filterConfig.filters[].field` (the filter card) and `pageBinding.parameters[].fieldExpr`
(the parameter binding). `ReportFields.py replace` walks every JSON object, so both are replaced in
one pass with no special handling (as the old regex version did).
