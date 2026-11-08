Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## Fixing a visual after renaming — directly in the folder (decision 2026-10-06)

The report cannot be edited via TOM, so the visual is edited **right away in the
PBIP files on disk**, without waiting for Desktop to close. To keep the folder
consistent, the model on disk is edited together with `visual.json` — the same
renamings in TMDL (`tables/*.tmdl`: `column`, `sourceColumn`, references in
measures); otherwise the fixed visual would reference columns that do not yet exist in the
saved model.

1. Backup of the affected files (`*.tmdl`, `visual.json`) to `ClientA\BackUp\`.
2. TMDL: rename `column` + `sourceColumn`, update references in measures
   (the same as already done via TOM in the open model).
3. `visual.json`: replace names with a regex only in quoted tokens
   `(?<=[".])Name(?=")` — covers `Property`, `queryRef`,
   `nativeQueryRef`, `selector.metadata`, `expansionStates.queryRefs`,
   filters. For a name swap — via a temporary name (`A`→`__tmp__`,
   `C`→`A`, `__tmp__`→`B`). Check that the JSON parses
   (`ConvertFrom-Json`).
4. User: **close Desktop WITHOUT saving** ("Don't save") →
   reopen the `.pbip` → **Refresh**. If Ctrl+S is pressed before closing —
   Desktop will overwrite `visual.json` with its own (broken) version from memory,
   and step 3 will have to be repeated.

Refresh after reopening is needed because the saved data cache is from
the last Ctrl+S, with the old column names.
