Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 32. Column names in English (all projects, user 2026-10-31)

Every model column name is English; the other language (Hebrew) is kept only as a comment. Data values stay as they are
(Hebrew values, saved slicer / filter selections, RLS keep matching), and he-IL / en-US captions are unchanged.
1. **Rename:** `column`, `sourceColumn`, `DATATABLE` header strings, relationships, culture entries, every DAX reference,
   report / bookmark refs (`Property`, `Table.Column` in `queryRef` / `metadata` / `queryRefs`, `nativeQueryRef`).
   Variants follow the base name (`X_En`, `X Display`, `Excel X`).
2. **Comments:** the column description starts with `He: <old name>.` (`/// He: <old name>` when there was none); every
   DAX line with a renamed reference (and each `DATATABLE` header line) ends with `-- <old name>` (several: `; `),
   replacing the English translation comment that was there.
3. **How:** calculated tables / columns only → closed files are safe: snapshot (open) → close → file script → `ValidateTmdl.ps1`
   + `CheckReportRefs.py` → open → `RequestRefresh(Calculate)` → snapshot compare → `SaveDesktop.ps1 -Expect`. An **import**
   column rename needs the source alias renamed too and a refresh — do it in the phase that is refreshed anyway (step 4 of
   "How every step is done"). ClientC scripts: `Agency\ClientC\Refactoring\Step32_rename_en.py` (map at the top) + `Step32_restore_eol.py` (Python rewrites CRLF as LF).
