Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `ReportFields.py` — report fields and filters (added 2026-10-16)

`ClientA\_Documentation\Scripts\ReportFields.py` — one tool with sub-commands, merged on
2026-10-16 from `ReplaceReportField.py` (`2026-10-16.3`), `DropReportFilters.py` and
`CleanReportFilters.py` (the three old files are in `ClientA\BackUp\2026-10-16_ToolTest\old_scripts\`).
Checked: on two copies of ClientB the old scripts and the new tool gave byte-identical reports for all
three operations (drop 88 filters, `CodeNameBP` → `CardName`, whole table, clean 27 cards).

```
python -I ReportFields.py replace <X.Report> --from "Customers[CodeNameBP]" --to "Customers[CardName]" [--apply]
python -I ReportFields.py replace <X.Report> --from "Customers[CardName]" --to "Customers[CardHierarchy][CardName]" --visuals slicer57,slicer88
python -I ReportFields.py replace <X.Report> --from Customers --to CustomersSmall [--skip CardCode]
python -I ReportFields.py drop-filters <X.Report> --field "Customers[CardType]" --list Dropped.md [--apply]
python -I ReportFields.py clean-filters <X.Report> [--pages Page2,Page3] [--no-visuals] [--no-pages] [--apply]
python -I ReportFields.py refs <X.Report> --table Customers
```

Shared by all sub-commands: dry run by default, `--apply` writes; backup of the report to the
nearest `BackUp` folder above it (`--backup-dir`) — `ReplaceField_<x>` / `DropFilters_<x>` /
`CleanReportFilters_<ts>` (characters invalid in Windows paths in `<x>` → `_` since 2026-10-18: a column
`SalesVal - Is 0?` crashed the backup and nothing was written — check the summary line printed after each run); `pbir validate` before / after; only changed files are written, CRLF /
BOM / trailing newline kept (a plain `json.dump` rewrote every line of a CRLF file — 3 430
"changed" lines for a one-word edit). After `--apply` with Desktop open:
`powerbi-desktop status` → `reload`. Whole-table swaps go through `ReplaceModelTable.ps1` (above),
which calls this tool.

#### `replace`

Replaces a column (or a hierarchy level) with another column or level everywhere: visual queries
(projections, `queryRef`, `nativeQueryRef`, sort), expansion states, slicer saved search
(`selfFilter`), visual / page / report filters, formatting selectors (e.g. column widths) and
bookmark states.

- `--from` may be a column or a **hierarchy level**; `--to` may be in **another table**. A `--from`
  level also replaces its column where Desktop writes the column, not the level (`identityKeys`,
  saved slicer selection). Moving a hierarchy slicer to another table = one run per level.
- Another table inside a filter with a `"Source"` alias: the new table gets its own `From` entry
  (`c` taken → `c1`), a `From` entry nothing references any more is dropped.
- **Table mode**: bare table names = every shared column / level in one run; `dataType` mismatch →
  skipped (saved literals would no longer match), a calculated column (no `dataType` in TMDL) is not
  checked; `--skip a,b`. **Rename mode**: `--from` no longer in the model (deleted / renamed via
  TOM) → every column / level of `--to`. It does **not** move the table's **measures** — run
  `MoveMeasureRefs.py --from <old> --to <new>` for them, then `CheckReportRefs.py` (ClientD 2026-10-23:
  `AR Periods` → `CT_AR Periods`, 2 measures left behind).
- Table names with characters Windows forbids in file names: Desktop writes `P&L|X` as `P&L%7CX.tmdl`;
  since `2026-10-23.1` the tool encodes the same way (before: "Table mode needs … in the sibling model").
- A column whose name contains the old table name + dot (a merged M column `JournalEntries[Accounts.AccountCodeName]`
  → queryRef `JournalEntries.Accounts.AccountCodeName`) is hit by the `queryRef` text match of
  `Accounts[AccountCodeName]` — dry-run lines with `0 fields` and refs only are such hits; limit with `--visuals`.
- Names match **case-insensitively**, as in Power BI (a TopN filter written as `CardCreateDate` was
  missed for the column `CardCreatedate`). A `queryRef` match may not continue with a space / dot /
  dash (`Customers.CardGroup` must not hit `Customers.CardGroup Category`); `nativeQueryRef` is
  renamed only in the projection whose field was replaced.
- Hierarchy target: projections become `HierarchyLevel`, `identityKeys` stay a `Column`.
- Checks that the target exists in the sibling `X.SemanticModel`; lists files still referencing the
  old field; warns when the new field ends up twice in one visual. `--visuals a,b` /
  `--visual-type slicer` limit the run (page / report filters skipped); `--no-bookmarks`.
- Stale `queryRef` labels from old renames (`Customers.CardName2`, `Customers.CustomerName`) are
  only names — they are not fields and do not break anything.

#### `drop-filters`

Drops every filter **with or without a condition** on a column: visual / page / report
`filterConfig` and bookmark filter states (`byExpr` / `byName` at report, page and visual level).
`--list` writes what was dropped (page, visual, type / title, kept values, `NOT`) as Markdown — a test
checklist. For a column the new table of a swap does not have (ClientB: `Customers[CardType]`, 88 filters
in 44 files). `--field` repeatable. A field also used in a query / sort / formatting is listed as
"still used" and left alone.

#### `clean-filters`

Removes Filters-pane cards that filter nothing. A card is unused when it has **no condition** (no
`"filter"` key) and: on a **visual** — its field is not in the visual's query (projections / sort; a
hierarchy level counts for its column); on a **page** — no bookmark applies a condition to it.
Bookmark entries for the removed page cards (same filter name, no condition) are removed too. Cards
with a condition are never touched; report-level cards are only listed. Warns when the Filters pane
is visible to viewers (`report.json` → `objects.outspacePane.visible`): then empty page cards may be
a tool for them. Files whose JSON would not round-trip byte-identically are skipped. Difference from
`CleanUnused.ps1` Step 9: runs without the model analysis and also removes page cards on existing
fields. ClientB 2026-10-15 (dry run): 28 page cards on 8 pages, 9 bookmarks.

#### `refs`

Read-only: report references per column / hierarchy level / measure of one table (all JSON incl.
bookmarks), with file counts. `ReplaceModelTable.ps1 -Port` uses it to stop when the report still
uses a column the new table lacks.
