Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## Editing the open model "on the fly" (TOM) — rule since 2026-10-06

**Rule (user's decision 2026-10-06):** if an SQL/logic edit
affects Power BI (column renaming, a measure, a filter by value) —
make the edit in Power BI **right away, in the same task**, without waiting for
the user to close Desktop.

⛔ **Never close the user's Desktop (rule 2026-10-14).** All changes — model
and report — are made while Desktop stays open: model via TOM / MS MCP, report via
files on disk + `powerbi-desktop reload` (or the user's Apply external changes).
⚠️ **Not the Model view layout:** `powerbi-desktop reload` does NOT update the diagram Desktop holds in memory — the
next save on close writes the old positions back (ClientB 2026-10-24: my edit survived one Ctrl+S, then was lost). Edit
`<Name>.SemanticModel/diagramLayout.json` only with the file closed (node `location`; collapsed card = `size.height`
72 + `expandedHeight`), or let the user drag the tables.
No `CloseMainWindow`, no "close → edit TMDL → reopen", even if there are no unsaved
changes (ClientB 2026-10-14: closed to rename a Field Parameter — the user objected).

**How — depends on whether the file is open in Desktop** (check:
`Get-Process PBIDesktop | Select MainWindowTitle`):

| | Model (columns, measures, sourceColumn) | Report (`visual.json`, pages) |
|---|---|---|
| Desktop **open** | TOM into the open model (below) | edit `visual.json` **directly in the folder** + the same renamings in the TMDL on disk; the user clicks **Apply external changes** in Desktop (pulls in the edits from disk, without closing) → Refresh if needed (see "Fixing a visual…" below) |
| Desktop **closed** | edit the TMDL files, as before | edit the JSON files, as before |

⚠️ **Desktop is open → edits on disk live only until Ctrl+S.** Desktop
holds the model and the report in memory and on save will overwrite the files with its own
version. Case 2026-10-09: the user accidentally saved before Apply external
changes — the latest TMDL edits were rolled back (the `"Moved"` fix,
`CT_AssignmentState`, deletion of a measure), while what had already been pulled in via
Apply was kept. After an accidental save — check all of the session's edits
in the files (grep for key lines) and re-apply the rolled-back ones. Therefore:
- edits to the **model only** — via TOM (Desktop itself writes them to TMDL on
  Ctrl+S) → the user saves;
- the **report** is affected — edit the files on disk (report + model, so the folder
  is consistent) → the user does **not save**, but clicks
  **Apply external changes** in Desktop — Desktop pulls in the changed
  files from disk without closing the project (since 2026-10-08 instead of "close without
  saving → reopen"). Remind about this explicitly in the reply.
