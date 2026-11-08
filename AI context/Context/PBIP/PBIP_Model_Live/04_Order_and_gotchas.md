Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## Order and gotchas

1. **Backup before editing** — a copy of `*.SemanticModel` + `*.Report` to
   `ClientA\BackUp\` (this is the last saved state on disk).
2. **Before TOM — make sure the port = the right file**
   (`EVALUATE SELECTCOLUMNS(INFO.TABLES(), "Name", [Name])`).
3. **Name swap** — step by step with `SaveChanges()` in between: first
   free up the name (`A` → `B`), then take it (`C` → `A`).
4. **Rewrite references in measures explicitly.** Do not rely on automatic formula fixing on
   renaming — after renaming, update the
   `Expression` of the relevant measures and check.
5. **`SourceColumn`** — change together with `Name` if the column is also renamed
   in the source. The data in memory stays until Refresh, but Refresh will fail
   until the source (SQL in the Dataflow) is updated — source first, then
   Refresh.
6. **Check** — with a query via `QueryOpenModel.ps1` (the columns exist, the measures
   calculate).
7. **Visuals break.** Desktop does **not** pick up a column/measure renamed via TOM in the
   report: the visual keeps referencing the old name and
   shows a field error (verified 2026-10-06). Therefore, **before**
   a TOM renaming — find all visuals with this field
   (`Select-String` over `*.Report\**\*.json` for `"Name"`/`.Name"`) and tell
   the user right away which visuals will break. Fix — see "Fixing a
   visual after renaming" below.
8. **Saving.** If the report is not affected — remind the user to press
   Ctrl+S (until then the TOM edits live only in the open model). If
   a visual is affected and it has already been fixed on disk (see below) — the opposite:
   **do not save**; click **Apply external changes**.
9. **TOM model edits + report edit on disk — Ctrl+S first** (ClientB,
   2026-10-13). If the model has already been changed via TOM and now
   `visual.json` needs editing: the user first presses Ctrl+S (the TOM edits go into
   TMDL), then `visual.json` is edited, then Apply external changes. Otherwise
   Ctrl+S will overwrite `visual.json`, and Apply will reload the model from disk without the
   TOM edits. Sign that it was not saved: no new `tables\<Table>.tmdl`
   / the measure on disk has the old expression.
10. **New calculated table + relationship via TOM** (ClientB `Target`,
    2026-10-13): after `Tables.Add` → `SaveChanges` → `RequestRefresh
    (Calculate)` on the table, the columns appear, but a query through the new relationship
    fails with "…relationship … does not hold any data because it needs to be
    recalculated" — another `Model.RequestRefresh(Calculate)` +
    `SaveChanges` is needed. Check the calculated table's expression with a query first
    (`EVALUATE VAR __T = <expression> RETURN GROUPBY(...)`) — before writing it to the
    model.
11. **CRLF inside DAX in TMDL.** After saving in Desktop, lines inside
    a multi-line expression may be CRLF while the rest of the file is LF
    (`Customers.tmdl`, ClientB). A text edit anchored on `\n` then does not
    find the spot — search with `\r\n` or check both variants.
12. **Swapping a table live** (ClientB `Customers`, 2026-10-16) — use `ReplaceModelTable.ps1 -Port`
    (`PBIP_Scripts.md`). Learned there: after `Tables.Remove(old)` + renaming the new table to the
    old name, DAX text `Old[Column]` binds to the new table — no measure rewrite for shared columns;
    a relationship that would be ambiguous while another one exists is activated in the **same**
    `SaveChanges` that removes the other; `RequestRefresh(Calculate)` afterwards recalculates field
    parameters (`NAMEOF`) on the renamed table.
13. **TMDL has no `dataType` for calculated columns** — a tool comparing column types from TMDL must
    treat a missing type as "unknown", not as a mismatch.
14. **Deleting an M query / parameter (`Model.Expressions.Remove`) is undone by Desktop's save** (ClientB
    `WorkingDays`, `dStart`, `dEnd`, 2026-10-18). The engine drops it (`INFO.EXPRESSIONS ()` no longer
    lists it), but Desktop's own Power Query list keeps it and Ctrl+S writes it back to
    `expressions.tmdl`. Delete it in the files too — the `expression` block in `expressions.tmdl` and the
    name in `model.tmdl` `annotation PBI_QueryOrder` — then `powerbi-desktop reload` → save → check the
    file. The same for a **whole M table** removed with `Tables.Remove` (ClientB `Compare Period`,
    2026-10-18: `tables\Compare Period.tmdl`, `ref table`, culture blocks came back) — remove the table
    file, `ref table`, `PBI_QueryOrder` entry and its `table` blocks in `cultures\*.tmdl` too. Not needed when
    a DAX table takes over the same name (`tom_to_dax_tables.ps1` below — saved as `calculated`).
    **Not consistent:** the same day `Technicians_UsersAndSalespersons` (M / SQL) removed via TOM did **not**
    come back on the next save. Always check the files after the save instead of assuming either way.
    **Where "Desktop's query list" lives: `<Name>.SemanticModel\.pbi\unappliedChanges.json`** — the Power Query
    editor state (`queries[].text` = the M as lines, `lastLoadedAsTableFormulaText` = what was loaded last).
    Desktop restores it on open; a stale copy there re-introduces removed steps: ClientB 2026-10-18 — `DocsSales`
    fixed in TOM + `.tmdl`, but `unappliedChanges.json` still merged the dropped table → on refresh / apply
    "Expression.Error: The import Technicians_UsersAndSalespersons matches no exports". Fix with Desktop
    **closed**: patch the query's `text` lines the same way (leave `lastLoadedAsTableFormulaText` — Desktop
    then shows a pending change and applies the fixed M). After any M edit outside Desktop, grep
    `unappliedChanges.json` for the old names. A clean Ctrl+S (no pending Power Query edits) **deletes** the file —
    absent = nothing to patch.
18. **M edited in the files → the table opens empty** (ClientB `DocsSales`, 2026-10-18): Desktop drops the data of a
    partition whose M changed (`INFO.PARTITIONS ()` `[State] = 3`, no error message; every measure on it blank).
    A TOM `RequestRefresh(Full)` fails with "Credentials are required to connect to the SQL source" — SQL credentials
    live in Desktop's UI; the user refreshes in Desktop. Take value snapshots **before** the edit and compare after
    that refresh.
17. **Before deleting a table, search the other tables' M for it** — TOM checks DAX dependencies, not M.
    ClientB `DocsSales` merged `Technicians_UsersAndSalespersons` (`Table.NestedJoin ( …, Technicians_…, … )` +
    `ExpandTableColumn` → `Department_Code`); the delete went through, the next refresh of `DocsSales` would
    have failed. Check: `$_.Partitions | ? SourceType -eq 'M' | ? { $_.Source.Expression -match '\b<Table>\b' }`
    and `$model.Expressions`. Fix = drop the merge steps, re-wire the next step to the previous one, drop the
    expanded column (if unused) — live via TOM, in the `.tmdl` on disk **and** in `.pbi\unappliedChanges.json`
    (gotcha 14). Also grep `DAXQueries\*.dax` (saved DAX query tabs) — they are not checked by the model and
    fail when run (ClientB `Query 3.dax` still uses `DateTypeTbl`).
16. **"Enter data" M table → DAX `DATATABLE` live** (ClientB, 2026-10-18,
    `Agency\ClientB\Translation\tom_to_dax_tables.ps1`): build the DAX twin under a temp name, check column
    names / types, remove the old table's translations and measures, then in **one** `SaveChanges` remove the
    old table and rename the twin (+ its partition) to the old name — DAX and report references keep working
    (as gotcha 12); re-add measures, column properties (sort-by, format, summarize), captions. Take the rows
    from `EVALUATE 'Table'`, not from the encoded M source — later M steps rename / add / drop columns.
15. **Moving a measure to another table:** measure names are unique model-wide, so it cannot exist in
    both tables at once — remove its culture translations, remove it, `SaveChanges`, add the new one,
    set captions again. The report references it by table (`Entity`) — repoint `SourceRef.Entity` and
    `queryRef` / `nativeQueryRef` (`Old.Measure` → `New.Measure`).
19. **Calculated column → data column with the same name** (ClientB Power Loader v2, 2026-10-19,
    `Agency\ClientB\Translation\v2_switch.ps1`): TOM cannot change a column's type in place. Save format, folder,
    summarize, hidden, sort-by and translations; remove translations + column; add a `DataColumn` with the same name
    and `SourceColumn`; restore the properties, translations, then sort-by (after all columns are added) — all in
    **one** `SaveChanges` together with the new partition M. Measures referencing the name keep working.
    PowerShell gotcha in such scripts: variable names are case-insensitive — `$T` (namespace) and `$t` (table) are the
    same variable.
19a. **Copying an object block in TMDL keeps its `lineageTag`s** — give the copy new GUIDs (table, column,
    measure, hierarchy **and every level**). Collector Assignment `Calendar` had it twice: `Year-Month Slicer`
    copied from `Year-Month` (≤ 2026-10-07, fixed later) and `_Month-Date` / `_Month-Date Slicer` (created
    2026-10-16…20, levels shared tags until 2026-10-22). Desktop accepts duplicates, but deployment / compare /
    merge tools match objects by `lineageTag`. Check: `grep -o 'lineageTag: [0-9a-f-]*' <table>.tmdl | sort | uniq -d`.
    Fix live: TOM `Level.LineageTag = [guid]::NewGuid()` + save (visuals reference levels by name — unaffected).
20. **The PBIP folder is the source — never "Save as .pbip" from an older `.pbix` into it** (ClientB, 2026-10-19: wiped a
    day of work, restored from `BackUp\`). A pbix with changes → `PbixToPbip.ps1 -OutDir <separate folder>`, diff,
    copy only the changes. Since 2026-10-31 the launcher `ConvertPbixToPbip.ps1` next to the `.pbix` does exactly this for
    the model + data (report never written, backup first, stops when the PBIP model is newer than the `.pbix`). Restoring from a backup with Desktop closed: copy the backup over the folders, then delete
    the files the backup does not have (`.tmdl` of dropped tables, removed visuals), diff to confirm identical.
21. **A Desktop refresh rebuilds an M table's columns from what the source returns** (ClientB, 2026-10-19). After
    repointing a table to a new SQL table, the SQL deployed there must be the new query *before* the refresh.
    Otherwise Desktop drops every model column the source lacks and re-adds the source's columns. On ClientB the old
    query was loaded into the new table: 93 / 151 measures broke, relationships on the dropped key columns were
    deleted, and formats / folders / sort-by / captions of the rebuilt columns were reset. Re-running the refresh with
    the right SQL does not bring them back. Fix: restore the semantic model from the backup taken before the switch,
    re-run the switch script, refresh once. Check the source shape before the refresh: the columns of the SQL table
    must equal the model's data columns.
22. **TOM edit of a partition's M → Desktop blocks Save** with the banner "There are pending changes in your queries
    that haven't been applied" (Save does nothing). "Apply changes" loads data. **Claude never clicks it and never
    refreshes:** the data is on the client's server, so hand over to the user, who applies / refreshes; then save.
    A model annotation (e.g. `PBI_QueryOrder`) can be fixed through TOM before that, and the save writes it.
23. **MCP `partition_operations Update` reports "failed" with `state: Incomplete`** (ClientC, 2026-10-22). With
    `useTransaction: false` the new M **is** applied (check with `Get`); with a transaction it is rolled back. The
    partition then stays `Incomplete` even after the original M is put back: the data is still queryable, but a
    table-level `Calculate` refresh tries to process the partition and fails with "Credentials are required to connect
    to the SQL source" (nothing is loaded). Calculated columns / tables added by TOM got their values anyway, and
    Ctrl+S saved normally. Prefer the DAX route below to M edits when the data must not be refreshed.
24. **Changing a lookup column without a data refresh — rename + calculated column with the old name** (ClientC
    `Customers[סוכן]`, 2026-10-22). Rename the data column (`סוכן` → `סוכן אזור`; `sourceColumn` stays `סוכן`, the M is
    untouched), add a hidden DAX `DATATABLE` mapping and a calculated column with the **old** name
    (`COALESCE ( LOOKUPVALUE ( … ), <fallback> )`), then `Calculate` refresh of the mapping table. Visuals, page
    filters and bookmarks bind by name and keep working. A relationship on the renamed column follows the rename —
    MCP cannot change a relationship's columns ("Delete and recreate"), so delete it and create it on the new column
    with the same cardinality / direction (the new one gets an auto name `From_Col_To_Col`).
25. **Refresh rule (user, 2026-10-22):** a `Calculate` refresh (`Table.RequestRefresh('Calculate')`,
    `Model.RequestRefresh('Calculate')`) is **always allowed** — it recalculates calculated tables / columns,
    relationships and field parameters without touching the source. Never a type that reads the source (`Full`,
    `DataOnly`, `Automatic` on M partitions) — see #22.
26. **Copying objects from one open model to another** (prototype copy → production Collector Assignment,
    2026-10-22): connect TOM to both ports, `$dst.Tables.Add($src.Tables['X'].Clone())` (whole calculated table with
    columns, sort-by, `groupByColumn`, `ParameterMetadata`, description), `Measures.Add($m.Clone())` into the target
    table. A relationship cannot be cloned (its columns belong to the source model) — create a new
    `SingleColumnRelationship` on the target's columns. Then `Calculate` per table + model (#10), save, check the TMDL.
27. **A script that fails half-way still saves what it built** (2026-10-22): `New-Object` errors left a table with no
    columns / partition, and the `SaveChanges` further down saved it as an empty table. Start TOM scripts with
    `$ErrorActionPreference = 'Stop'`, and if one failed, check the model (`Tables.Find(...)`, `Partitions.Count`)
    before re-running. Same run: the `$T` / `$t` clash from #19.
28. **`_Measures` without a refresh** (ClientD Finance, 2026-10-23): a new import table needs a `Full` refresh of its
    partition (not allowed on client reports, #25). If the model already has an M table that is only an empty
    `#table({},{})` holding measures (`Query`, `Measures`…), rename it instead — `$t.Name = '_Measures'`, partition
    name too, `ExcludeFromModelRefresh = $true`: the partition stays `Ready`, measures keep their lineage tags. Then
    repoint the report (`MoveMeasureRefs.py --from <old> --to _Measures`) and fix the old name in the model annotation
    `PBI_QueryOrder`.
29. **Deleting an M table that another query merges** (ClientD `Accounts`, merged into the `JournalEntries` M): deleting
    the table breaks the other query at the next refresh, and editing that query's M needs a refresh. Keep the query
    **not loaded** instead: in one `SaveChanges` delete the table's relationships and the table, and add a
    `NamedExpression` with the same name (`Kind = 'M'`, only the steps the merge needs, the table's `QueryGroup`,
    annotation `PBI_ResultType = Table`) — it lands in `expressions.tmdl`, the other table's data is untouched, Desktop
    saves without a "pending changes" banner. Drop the merge and the expression at the next client refresh.
30. **Renaming a partition** (ClientB 2026-10-25, 9 M + 2 field-parameter partitions): `$p.Name = $t.Name` via TOM is
    metadata only — the partition stays `Ready`, no refresh, no "pending changes" banner, Ctrl+S works at once
    (`Scripts\RenamePartitions.ps1`). Unlike editing the partition M (Save blocked until changes are applied).
31. **`powerbi-desktop reload` does not apply MODEL edits** (ClientA Semantic Model 2026-11-07): after TMDL edits on disk the
    reload reported success, but the engine kept the old partition / columns (checked with `INFO.PARTITIONS`), and the
    next Ctrl+S would have written the old model back. With Desktop open, model edits go through TOM (section 2); a
    small TOM script can deserialize the edited TMDL folder (`TmdlSerializer`, also a parse check) and copy the changed
    objects into the open model.
32. **TOM `RequestRefresh(Full)` of an M (`Sql.Database`) partition in an open Desktop** right after TOM edits of that
    partition failed with a Desktop frown "Could not find a PackageSession for the given sessionID" and loaded nothing;
    after closing and reopening the .pbip the same TOM refresh worked (BBack, LID, LoanData 2026-11-07). Dataflow
    partitions refresh fine through TOM in a freshly opened Desktop.
33. **Desktop adds new source columns by itself** (LID 2026-11-07): when a dataflow entity gained columns and the table
    was refreshed in the Desktop UI, Desktop added all new columns to the model table with default properties
    (`Long Date`, `"TRUE";"TRUE";"FALSE"`, no folders). Moving formatted columns into that table then needs the default
    copies replaced, not duplicated (check `LID already has ...`).
34. **Text NULLs from a dataflow arrive as empty strings** (CSV storage): `NOT ISBLANK ( col )` counts them as filled -
    test `col <> ""` / `LEN ( col ) > 0` for text columns of dataflow tables.
35. **Python `re.sub` replacement `"\1LID\2"` written through a Bash heredoc** became raw bytes 0x01 / 0x02 in
    `relationships.tmdl` (Collateral 2026-11-07, "Unexpected line type: Other!" on open). Write scripts with the Write
    tool, use `\g<1>` in replacements, and run `ValidateTmdl.ps1` before opening a model edited on disk.
