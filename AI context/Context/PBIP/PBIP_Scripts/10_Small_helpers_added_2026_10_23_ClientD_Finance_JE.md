Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## Small helpers added 2026-10-23 (ClientD Finance JE → JEC migration)
All in `ClientA\_Documentation\Scripts\`.
- **`TableUsage.py`** — which visuals depend on given tables: a column / level / measure hosted there, or a measure
  whose DAX transitively references them. `python -X utf8 TableUsage.py "<...\Report>" --tables "JournalEntries" [--fields "DoceDate,Memo"] [--pages]`.
  Use before replacing or dropping a table; `--pages` gives a per-page count.
- **`PbirEdit.py`** — import helpers for `visual.json` edits that keep the rest of the file byte-identical:
  `save_visual_keys(path, j, ['query', 'expansionStates'])` rewrites only those blocks (positions keep their digits),
  `replace_text(path, [(old, new, expected_count)])` with counts checked, `col()` / `lvl()` field builders. Write
  Python that uses it into a file, not a bash heredoc — the heredoc mangled `\\` and `\n` three times.
- **`RestoreOpenModelFromTmdl.ps1 -Port -Backup <definition> [-Apply]`** — puts back into the open model what a TMDL
  backup has and the model lacks (tables, columns, measures, relationships; Clone + Calculate). M tables return empty:
  reopen the `.pbip` to load data from `.pbi\cache.abf` (Desktop's engine is diskless — `Server.Restore` of the
  abf is "not supported in Diskless mode").
- **`SaveDesktop.ps1 -DesktopPid -SemanticModel`** — Ctrl+S to the verified Desktop window, confirmed by file timestamps.
- **`SetYearSlicersDescending.py "<...\Report>" [--write]`** — every year slicer (column `Year`, or a hierarchy whose
  first level is `Year`) sorted Descending; rewrites only the `query` block, keeps CRLF (`read_text()` turns CRLF into LF —
  read bytes).
- **`MoveMeasureRefs.py "<...\Report>" --from <Table> --to <Table> --measures "A" "B" [--apply]`** — after moving
  measures to another home table, repoints the report: `Measure.SourceRef.Entity`, aliased `Source` refs (adds a
  `From` entry for the new table), `queryRef` / metadata strings `Old.Measure` (also inside `Sum(...)`), bookmarks;
  backup `BackUp\MoveMeasureRefs_<ts>`, keeps line endings. Dry run first: the file list = the visuals that break.
  The model part via TOM: `$new = $old.Clone(); $src.Measures.Remove($old); $new.Expression = …; $dst.Measures.Add($new)`
  — the clone keeps name and lineage tag; a removed object itself **cannot be re-added** ("removed from the Model tree
  cannot be modified or reattached"). Order: TOM move → this script → bridge reload → Ctrl+S (`SaveDesktop.ps1`).
  A reload right after a TOM change can time out ("status": "error") — run it again before assuming anything broke.
